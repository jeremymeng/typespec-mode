;;; typespec-flymake.el --- Flymake backend for TypeSpec -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Jeremy Meng
;; Author: Jeremy Meng
;; URL: https://github.com/jeremymeng/typespec-mode
;; Keywords: languages, tools
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Flymake backend for on-the-fly TypeSpec syntax checking.
;; Runs `tsp compile --no-emit' in the project root and reports diagnostics
;; for the current buffer.
;; Enable it with `(add-hook 'typespec-mode-hook #'typespec-flymake-setup)`.

;;; Code:

(require 'flymake)
(require 'typespec-compile)

;; Forward declarations
(declare-function flymake-make-diagnostic "flymake")
(declare-function flymake-diag-region "flymake")
(defvar flymake-diagnostic-functions)

;; Buffer-local variable to track the running tsp process
(defvar-local typespec-flymake--process nil
  "The current typespec-flymake tsp process for this buffer.")

;;; Regex for parsing tsp output
(defconst typespec-flymake--output-regex
  ;; Greedy `.+' so Windows paths like C:\foo\bar.tsp match cleanly;
  ;; backtracks until ":LINE:COL - (error|warning) CODE: MSG" matches at the
  ;; end.  The simpler `[^:\n]+' stops at the drive-letter colon and loses
  ;; all diagnostics on Windows.
  "^\\(.+\\):\\([0-9]+\\):\\([0-9]+\\) - \\(error\\|warning\\) [A-Za-z0-9]+: \\(.*\\)$"
  "Regex to match tsp compile diagnostic lines.")

;;; Process and output handling

(defun typespec-flymake--normalize-path (path)
  "Normalize PATH for cross-platform comparison.
Converts to absolute path and handles Windows path separators."
  (expand-file-name path))

(defun typespec-flymake--parse-diagnostics (output source-buffer source-path project-root)
  "Parse tsp output and build diagnostics for SOURCE-BUFFER.
OUTPUT is the combined stdout/stderr.
SOURCE-PATH is the buffer's file path (absolute).
PROJECT-ROOT is the project root (absolute).
Returns a list of flymake-diagnostic objects."
  (let ((diagnostics nil)
        (lines (split-string output "\n" t)))
    (dolist (line lines)
      (when (string-match typespec-flymake--output-regex line)
        (let* ((diag-path (match-string 1 line))
               (line-num (string-to-number (match-string 2 line)))
               (col-num (string-to-number (match-string 3 line)))
               (severity (match-string 4 line))
               (message (match-string 5 line))
               ;; Resolve the diagnostic path relative to project root
               (abs-diag-path (typespec-flymake--normalize-path
                               (if (file-name-absolute-p diag-path)
                                   diag-path
                                 (expand-file-name diag-path project-root)))))
          ;; Only report diagnostics for the source buffer's file
          (when (file-equal-p abs-diag-path source-path)
            (let* ((type (if (string= severity "error") :error :warning))
                   ;; Build region for the diagnostic.  `flymake-diag-region'
                   ;; returns nil if the line is out of range (e.g., the
                   ;; buffer was edited since tsp ran); skip those rather
                   ;; than handing nil positions to `flymake-make-diagnostic'.
                   (region (flymake-diag-region source-buffer line-num col-num)))
              (when region
                (push (flymake-make-diagnostic source-buffer
                                               (car region) (cdr region)
                                               type
                                               message)
                      diagnostics)))))))
    (nreverse diagnostics)))

(defun typespec-flymake--handle-process-finish (process _event report-fn source-buffer
                                                  source-path project-root)
  "Handle process finish for tsp compilation.
PROCESS is the tsp process.
REPORT-FN is the flymake report function.
SOURCE-BUFFER, SOURCE-PATH, PROJECT-ROOT are snapshots from check start."
  (let ((output-buffer (process-buffer process)))
    (unwind-protect
        (if (and output-buffer (buffer-live-p output-buffer))
            (with-current-buffer output-buffer
              (let ((output (buffer-string)))
                ;; Parse output and build diagnostics
                (let ((diagnostics (typespec-flymake--parse-diagnostics
                                    output source-buffer source-path project-root)))
                  ;; Report diagnostics (always call to clear old ones)
                  (funcall report-fn diagnostics))))
          ;; Process buffer was killed
          (funcall report-fn nil))
      ;; Clean up process buffer
      (when (buffer-live-p output-buffer)
        (kill-buffer output-buffer)))))

;;; Main backend function

(defun typespec-flymake-backend (report-fn &rest _args)
  "Flymake backend for TypeSpec.
Runs `tsp compile --no-emit' in the project root and reports diagnostics
for the current buffer.

REPORT-FN is the flymake diagnostic reporting callback.
Additional arguments are ignored."
  ;; Get the source buffer, path, and directory (snapshot now, before any
  ;; directory changes)
  (let* ((source-buffer (current-buffer))
         (source-path (buffer-file-name))
         (source-dir default-directory)
         (project-root (or (typespec-project-root) source-dir)))
    ;; Kill any previous process for this buffer
    (when (and typespec-flymake--process
               (process-live-p typespec-flymake--process))
      (kill-process typespec-flymake--process))
    ;; If no source file, report panic
    (if (not source-path)
        (funcall report-fn :panic
                 :explanation "No file associated with current buffer")
      ;; Resolve tsp command
      (let ((tsp-cmd (typespec--resolve-tsp)))
        (if (not tsp-cmd)
            (funcall report-fn :panic
                     :explanation "Could not resolve tsp command")
          ;; Build the command
          (let* ((cmd-parts (if (listp tsp-cmd) tsp-cmd (list tsp-cmd)))
                 (output-buffer (generate-new-buffer " *typespec-flymake*"))
                 (process-args (append cmd-parts (list "compile" "--no-emit"))))
            ;; Start the process
            (condition-case err
                (let ((default-directory project-root))
                  (let ((process (make-process
                                  :name "typespec-flymake"
                                  :buffer output-buffer
                                  :command process-args
                                  :noquery t
                                  :sentinel (lambda (proc event)
                                              (typespec-flymake--handle-process-finish
                                               proc event report-fn
                                               source-buffer source-path project-root)))))
                    ;; Store the process in the buffer-local variable
                    (setq typespec-flymake--process process)))
              ;; Handle errors starting the process
              (file-error
               (kill-buffer output-buffer)
               (funcall report-fn :panic
                        :explanation (format "Failed to start tsp: %s"
                                            (error-message-string err)))))))))))

;;; Setup function

;;;###autoload
(defun typespec-flymake-setup ()
  "Enable the TypeSpec Flymake backend for the current buffer.
Add to `typespec-mode-hook' to enable by default:
  (add-hook \\='typespec-mode-hook #\\='typespec-flymake-setup)"
  (add-hook 'flymake-diagnostic-functions #'typespec-flymake-backend nil t))

(provide 'typespec-flymake)
;;; typespec-flymake.el ends here
