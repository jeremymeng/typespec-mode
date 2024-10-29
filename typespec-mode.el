;;; typespec-mode.el --- major mode for typespec  -*- lexical-binding: t; -*-

;;;###autoload
(define-derived-mode typespec-mode prog-mode "typespec"
  "Major mode for TypeSpec (https://typespec.io/) files."
  (setq-local indent-tabs-mode nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.tsp" . typespec-mode))
