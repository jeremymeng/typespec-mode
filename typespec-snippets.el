;;; typespec-snippets.el --- Yasnippet snippets for TypeSpec -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Jeremy Meng
;; Author: Jeremy Meng
;; URL: https://github.com/jeremymeng/typespec-mode
;; Keywords: languages, tools
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Yasnippet snippet definitions for TypeSpec code templates.

;;; Code:

(declare-function yas-load-directory "yasnippet")
(defvar yas-snippet-dirs)

(defconst typespec-snippets-directory
  (file-name-directory
   (or load-file-name buffer-file-name))
  "Directory containing bundled yasnippet snippets for TypeSpec.")

;;;###autoload
(defun typespec-snippets-initialize ()
  "Initialize yasnippet snippets for TypeSpec.

If yasnippet is not installed, warns and returns nil.
Otherwise, adds the bundled snippets directory to `yas-snippet-dirs'
\(idempotent) and calls `yas-load-directory', returning t."
  (if (not (require 'yasnippet nil t))
      (progn
        (display-warning 'typespec-snippets
                         "yasnippet is not installed. Install it to use TypeSpec snippets."
                         :warning)
        nil)
    (let ((snippets-dir (file-name-as-directory
                         (concat typespec-snippets-directory "snippets"))))
      (unless (member snippets-dir yas-snippet-dirs)
        (setq yas-snippet-dirs (cons snippets-dir yas-snippet-dirs)))
      (yas-load-directory snippets-dir)
      t)))

(provide 'typespec-snippets)
;;; typespec-snippets.el ends here
