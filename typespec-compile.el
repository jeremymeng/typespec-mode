;;; typespec-compile.el --- TypeSpec compilation support -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Jeremy Meng
;; Author: Jeremy Meng
;; URL: https://github.com/jeremymeng/typespec-mode
;; Keywords: languages, tools
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Integration with the TypeSpec compiler and tsp CLI.
;; Provides commands for compiling, formatting, and project management.

;;; Code:

(require 'cl-lib)

;; Forward declarations
(defvar compilation-error-regexp-alist)
(defvar compilation-error-regexp-alist-alist)
(declare-function compilation-start "compile")
(declare-function project-root "project")

;;; Customization

(defcustom typespec-tsp-command "tsp"
  "Command to run the TypeSpec compiler.
Can be a simple command name or an absolute path.
Project-local binaries in node_modules/.bin/ are checked first."
  :type 'string
  :group 'typespec)

(defcustom typespec-format-on-save nil
  "Whether to format TypeSpec buffers automatically on save.
This is a global default; use `typespec-format-on-save-mode'
to toggle on a per-buffer basis."
  :type 'boolean
  :group 'typespec)

(defcustom typespec-compile-extra-args nil
  "Extra arguments to pass to `tsp compile'.
Each element should be a string."
  :type '(repeat string)
  :group 'typespec)

;;; Project root detection

(defun typespec-project-root ()
  "Find the TypeSpec project root from `default-directory'.
Searches upward for directories containing tspconfig.yaml, main.tsp,
or package.json with @typespec/compiler dependency.
Returns the absolute path to the project root, or nil if not found."
  (let ((dir (locate-dominating-file
              default-directory
              (lambda (d)
                (or (file-exists-p (expand-file-name "tspconfig.yaml" d))
                    (file-exists-p (expand-file-name "main.tsp" d))
                    (let ((pkg (expand-file-name "package.json" d)))
                      (and (file-exists-p pkg)
                           (with-temp-buffer
                             (insert-file-contents pkg)
                             (goto-char (point-min))
                             (re-search-forward "@typespec/compiler" nil t)))))))))
    (when dir
      (expand-file-name dir))))

(defun typespec-project-try (dir)
  "Try to find a TypeSpec project starting from DIR.
Returns a project instance cons cell (typespec . ROOT) or nil."
  (when-let* ((root (let ((default-directory dir))
                      (typespec-project-root))))
    (cons 'typespec root)))

(with-eval-after-load 'project
  (cl-defmethod project-root ((project (head typespec)))
    "Return the root directory of a TypeSpec PROJECT."
    (cdr project))
  (add-hook 'project-find-functions #'typespec-project-try))

;;; TypeSpec command resolution

(defun typespec--resolve-tsp ()
  "Resolve the tsp command to use.
Returns either a string (single command) or a list of strings (command + args).
Resolution order:
1. Absolute path in `typespec-tsp-command' if it exists
2. Project-local node_modules/.bin/tsp (or tsp.cmd on Windows)
3. `typespec-tsp-command' via `executable-find'
4. Fallback to npx tsp"
  (or
   ;; 1. Absolute path
   (and (file-name-absolute-p typespec-tsp-command)
        (file-executable-p typespec-tsp-command)
        typespec-tsp-command)
   ;; 2. Project-local binary
   (when-let* ((root (typespec-project-root)))
     (let* ((bin-name (if (eq system-type 'windows-nt) "tsp.cmd" "tsp"))
            (local-bin (expand-file-name (concat "node_modules/.bin/" bin-name) root)))
       (and (file-executable-p local-bin)
            local-bin)))
   ;; 3. Executable on PATH
   (executable-find typespec-tsp-command)
   ;; 4. Fallback to npx
   (list "npx" "tsp")))

(defun typespec--build-command (tsp-cmd &rest args)
  "Build a shell command string from TSP-CMD and ARGS.
TSP-CMD can be a string or list of strings."
  (let ((cmd-parts (if (listp tsp-cmd) tsp-cmd (list tsp-cmd))))
    (mapconcat #'shell-quote-argument (append cmd-parts args) " ")))

;;; Interactive commands

;;;###autoload
(defun typespec-compile ()
  "Compile the current TypeSpec project using `tsp compile'.
Runs the compilation at the project root via `compile'."
  (interactive)
  (let* ((root (or (typespec-project-root)
                   (error "Not in a TypeSpec project")))
         (default-directory root)
         (tsp (typespec--resolve-tsp))
         (cmd (apply #'typespec--build-command
                     tsp "compile"
                     (append typespec-compile-extra-args (list ".")))))
    (compilation-start cmd)))

;;;###autoload
(defun typespec-compile-no-emit ()
  "Compile the current TypeSpec project without emitting output.
Runs `tsp compile --no-emit' at the project root via `compile'."
  (interactive)
  (let* ((root (or (typespec-project-root)
                   (error "Not in a TypeSpec project")))
         (default-directory root)
         (tsp (typespec--resolve-tsp))
         (cmd (apply #'typespec--build-command
                     tsp "compile" "--no-emit"
                     (append typespec-compile-extra-args (list ".")))))
    (compilation-start cmd)))

;;;###autoload
(defun typespec-init ()
  "Initialize a new TypeSpec project in the current directory.
Runs `tsp init' interactively."
  (interactive)
  (let* ((tsp (typespec--resolve-tsp))
         (cmd (typespec--build-command tsp "init")))
    (compilation-start cmd)))

;;;###autoload
(defun typespec-install ()
  "Install dependencies for the current TypeSpec project.
Runs `npm install' at the project root."
  (interactive)
  (let* ((root (or (typespec-project-root)
                   (error "Not in a TypeSpec project")))
         (default-directory root))
    (compilation-start "npm install")))

;;;###autoload
(defun typespec-format-buffer ()
  "Format the current TypeSpec buffer using `tsp format'.
Pipes the buffer contents through `tsp format -' and replaces
the buffer with the formatted output on success.
Point position is preserved.

On failure the buffer is left unchanged and the error message
from `tsp format' is signalled."
  (interactive)
  (let* ((tsp (typespec--resolve-tsp))
         (cmd-parts (if (listp tsp) tsp (list tsp)))
         (input (buffer-substring-no-properties (point-min) (point-max)))
         (original-point (point))
         (stdout-buffer (generate-new-buffer " *tsp-format-out*"))
         (stderr-file (make-temp-file "tsp-format-stderr")))
    (unwind-protect
        (let ((exit-code
               (with-temp-buffer
                 (insert input)
                 (apply #'call-process-region
                        (point-min) (point-max)
                        (car cmd-parts)
                        nil            ; do not delete input region
                        (list stdout-buffer stderr-file)
                        nil            ; no display
                        (append (cdr cmd-parts) (list "format" "-"))))))
          (if (zerop exit-code)
              (let ((formatted (with-current-buffer stdout-buffer
                                 (buffer-string))))
                ;; Only mutate the user's buffer if formatting succeeded.
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert formatted))
                (goto-char (min original-point (point-max)))
                (message "Buffer formatted"))
            (let ((errors (with-temp-buffer
                            (insert-file-contents stderr-file)
                            (buffer-string))))
              (if (string-empty-p errors)
                  (error "Tsp format failed with exit code %d" exit-code)
                (error "Tsp format failed: %s" errors)))))
      (when (buffer-live-p stdout-buffer) (kill-buffer stdout-buffer))
      (when (file-exists-p stderr-file) (delete-file stderr-file)))))

;;; Format on save minor mode

;;;###autoload
(define-minor-mode typespec-format-on-save-mode
  "Minor mode to format TypeSpec buffers on save.
When enabled, `typespec-format-buffer' is run before saving."
  :lighter " TspFmt"
  (if typespec-format-on-save-mode
      (add-hook 'before-save-hook #'typespec-format-buffer nil t)
    (remove-hook 'before-save-hook #'typespec-format-buffer t)))

;;; Compilation error regexps

(with-eval-after-load 'compile
  (add-to-list 'compilation-error-regexp-alist 'typespec)
  (add-to-list 'compilation-error-regexp-alist-alist
               '(typespec
                 ;; Greedy `.+' so Windows paths like C:\foo\bar.tsp match
                 ;; cleanly; backtracks until ":LINE:COL - (error|warning)"
                 ;; matches at the end.
                 "^\\(.+\\):\\([0-9]+\\):\\([0-9]+\\) - \\(error\\|warning\\)"
                 1 2 3 (4 . nil))))

;;; Keymap

;;;###autoload
(defvar typespec-compile-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'typespec-compile)
    (define-key map (kbd "n") #'typespec-compile-no-emit)
    (define-key map (kbd "f") #'typespec-format-buffer)
    (define-key map (kbd "i") #'typespec-init)
    (define-key map (kbd "I") #'typespec-install)
    map)
  "Prefix keymap for TypeSpec compilation commands.
Bind this to a prefix key in `typespec-mode-map', for example:
  (define-key typespec-mode-map (kbd \"C-c C-t\") typespec-compile-prefix-map)")

(provide 'typespec-compile)
;;; typespec-compile.el ends here
