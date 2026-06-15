;;; typespec-flycheck.el --- Flycheck backend for TypeSpec -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Jeremy Meng
;; Author: Jeremy Meng
;; URL: https://github.com/jeremymeng/typespec-mode
;; Keywords: languages, tools
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Flycheck backend for on-the-fly TypeSpec syntax checking.
;; Runs `tsp compile --no-emit' in the project root and reports diagnostics
;; via Flycheck.  Flycheck is a soft dependency: this file does nothing at
;; load time unless Flycheck is loaded.
;;
;; Enable it with:
;;
;;   (add-hook 'typespec-mode-hook #'typespec-flycheck-setup)
;;
;; or, if you already have Flycheck running globally, just M-x
;; typespec-flycheck-setup in a `.tsp' buffer.

;;; Code:

(require 'typespec-compile)
(require 'typespec-mode)

;; Make Flycheck macros available at compile time when Flycheck is installed
;; on the build machine.  This is a soft dependency: at runtime we still gate
;; the checker definition behind `with-eval-after-load' so users without
;; Flycheck can `(require 'typespec-flycheck)' without error.
(eval-when-compile
  (require 'flycheck nil t))

;; Forward declarations so byte-compile is clean without Flycheck installed.
(declare-function flycheck-define-checker "flycheck")
(declare-function flycheck-def-executable-var "flycheck")
(declare-function flycheck-mode "flycheck")
(declare-function flycheck-error-filename "flycheck")
(declare-function flycheck-valid-checker-p "flycheck")
(defvar flycheck-checkers)
(defvar flycheck-typespec-executable)

;; The checker is registered only after Flycheck loads, so the user can
;; `(require 'typespec-flycheck)' even on Emacs sessions without Flycheck.
(with-eval-after-load 'flycheck
  (flycheck-def-executable-var typespec "tsp")

  (flycheck-define-checker typespec
    "A TypeSpec syntax checker using the TypeSpec compiler.

See URL `https://typespec.io/'."
    :command ("tsp" "compile" "--no-emit"
              (eval typespec-compile-extra-args)
              ".")
    :error-patterns
    ((error line-start (file-name) ":" line ":" column " - error "
            (one-or-more (any alphanumeric)) ": " (message) line-end)
     (warning line-start (file-name) ":" line ":" column " - warning "
              (one-or-more (any alphanumeric)) ": " (message) line-end))
    :error-filter
    (lambda (errors)
      ;; tsp emits paths relative to the project root; resolve to absolute
      ;; so Flycheck can route diagnostics to the right buffer.
      (let ((root (or (typespec-project-root) default-directory)))
        (dolist (err errors)
          (let ((fname (flycheck-error-filename err)))
            (when (and fname (not (file-name-absolute-p fname)))
              (setf (flycheck-error-filename err)
                    (expand-file-name fname root))))))
      errors)
    :modes (typespec-mode typespec-ts-mode)
    :working-directory (lambda (_checker)
                         (or (typespec-project-root) default-directory)))

  (add-to-list 'flycheck-checkers 'typespec))

;;;###autoload
(defun typespec-flycheck-setup ()
  "Enable the TypeSpec Flycheck checker for the current buffer.

Resolves the `tsp' binary via `typespec--resolve-tsp' and sets
`flycheck-typespec-executable' buffer-locally.  Then enables
`flycheck-mode' in the current buffer.

If Flycheck is not installed, emits a warning and does nothing.
If `tsp' cannot be resolved as a single binary (only the
`npx tsp' fallback is available), emits a warning and does not
enable Flycheck — Flycheck's command model does not support
prepending an extra argument the way Flymake's does.  Install
`tsp' on PATH or in `node_modules/.bin/' to use Flycheck.

Add to your init to enable automatically:

  (add-hook \\='typespec-mode-hook #\\='typespec-flycheck-setup)"
  (interactive)
  (cond
   ((not (require 'flycheck nil t))
    (display-warning 'typespec-flycheck
                     "Flycheck is not installed; cannot enable."))
   (t
    (let ((tsp (typespec--resolve-tsp)))
      (cond
       ((stringp tsp)
        (setq-local flycheck-typespec-executable tsp)
        (flycheck-mode 1))
       ((and (consp tsp) (string-equal (car tsp) "npx"))
        (display-warning
         'typespec-flycheck
         "tsp not found on PATH or in project; the npx fallback is not \
supported by Flycheck.  Install tsp or customize \
`flycheck-typespec-executable'."))
       (t
        (display-warning
         'typespec-flycheck
         (format "Unexpected tsp resolution: %S" tsp))))))))

(provide 'typespec-flycheck)
;;; typespec-flycheck.el ends here
