;;; typespec-snippets-test.el --- Tests for typespec-snippets -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Jeremy Meng

;;; Commentary:
;; Tests for typespec-snippets.el

;;; Code:

(require 'ert)
(require 'typespec-snippets)

(ert-deftest typespec-snippets-initialize-without-yasnippet-test ()
  "Test typespec-snippets-initialize returns nil when yasnippet is not loaded."
  ;; This test assumes yasnippet is not loaded initially
  ;; If yasnippet is loaded, this test will be skipped
  (skip-unless (not (featurep 'yasnippet)))
  (should (null (typespec-snippets-initialize))))

(ert-deftest typespec-snippets-directory-exists-test ()
  "Test that the snippets directory exists."
  (let ((snippets-dir (file-name-as-directory
                       (concat typespec-snippets-directory "snippets"))))
    (should (file-directory-p snippets-dir))))

(ert-deftest typespec-snippets-initialize-with-yasnippet-test ()
  "Test typespec-snippets-initialize with yasnippet loaded."
  (skip-unless (require 'yasnippet nil t))
  (should (typespec-snippets-initialize)))

(provide 'typespec-snippets-test)
;;; typespec-snippets-test.el ends here
