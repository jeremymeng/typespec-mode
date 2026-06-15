;;; typespec-mode-test.el --- Tests for typespec-mode -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Jeremy Meng

;;; Commentary:
;; Tests for typespec-mode.el

;;; Code:

(require 'ert)
(require 'typespec-mode)

(defvar eglot-server-programs)  ; silence byte-compiler
(declare-function imenu--make-index-alist "imenu")

(defconst typespec-mode-test-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Path to test fixtures directory.")

(ert-deftest typespec-mode-syntax-test ()
  "Test syntax table setup."
  (with-temp-buffer
    (typespec-mode)
    (should (equal (char-syntax ?/) ?.))
    (should (equal (char-syntax ?@) ?'))))

(ert-deftest typespec-mode-comment-test ()
  "Test comment variables."
  (with-temp-buffer
    (typespec-mode)
    (should (string= comment-start "// "))))

(ert-deftest typespec-mode-font-lock-test ()
  "Test font-lock highlighting."
  (let ((sample-file (expand-file-name "sample.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents sample-file)
      (typespec-mode)
      (font-lock-ensure)
      ;; Test keyword "import"
      (goto-char (point-min))
      (should (search-forward "import" nil t))
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (should (or (eq face 'font-lock-keyword-face)
                    (and (listp face) (memq 'font-lock-keyword-face face)))))
      ;; Test decorator "@get"
      (goto-char (point-min))
      (should (search-forward "@get" nil t))
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (should (or (eq face 'font-lock-preprocessor-face)
                    (and (listp face) (memq 'font-lock-preprocessor-face face)))))
      ;; Test type "int32"
      (goto-char (point-min))
      (should (search-forward "int32" nil t))
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (should (or (eq face 'font-lock-type-face)
                    (and (listp face) (memq 'font-lock-type-face face))))))))

(ert-deftest typespec-mode-triple-quote-test ()
  "Test triple-quoted string syntax-ppss."
  (let ((sample-file (expand-file-name "sample.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents sample-file)
      (typespec-mode)
      (font-lock-ensure)
      ;; Find a position inside the triple-quoted string
      (goto-char (point-min))
      (should (search-forward "Multi-line" nil t))
      (should (nth 3 (syntax-ppss))))))

(ert-deftest typespec-mode-indent-test ()
  "Test indentation."
  (let ((input-file (expand-file-name "indent-input.tsp" typespec-mode-test-fixtures-dir))
        (expected-file (expand-file-name "indent-expected.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents input-file)
      (typespec-mode)
      (indent-region (point-min) (point-max))
      (let ((actual (buffer-string))
            (expected (with-temp-buffer
                        (insert-file-contents expected-file)
                        (buffer-string))))
        (should (string= actual expected))))))

(ert-deftest typespec-mode-imenu-test ()
  "Test imenu indexing."
  (let ((sample-file (expand-file-name "sample.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents sample-file)
      (typespec-mode)
      (let ((index (imenu--make-index-alist)))
        (should (assoc "Models" index))
        (should (assoc "Ops" index))))))

(ert-deftest typespec-mode-beginning-of-defun-test ()
  "Test beginning-of-defun navigation."
  (let ((sample-file (expand-file-name "sample.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents sample-file)
      (typespec-mode)
      ;; Go to the "name: string" line
      (goto-char (point-min))
      (should (search-forward "name: string" nil t))
      (beginning-of-defun)
      (should (looking-at ".*model Thing")))))

(ert-deftest typespec-mode-eglot-registration-test ()
  "Test eglot server registration."
  (skip-unless (require 'eglot nil t))
  (should (assoc 'typespec-mode eglot-server-programs))
  (let ((prog (cdr (assoc 'typespec-mode eglot-server-programs))))
    (should (equal prog '("tsp-server" "--stdio")))))

(ert-deftest typespec-mode-end-of-defun-test ()
  "`typespec-end-of-defun' must land past the closing brace of the body."
  (let ((sample-file (expand-file-name "sample.tsp" typespec-mode-test-fixtures-dir)))
    (with-temp-buffer
      (insert-file-contents sample-file)
      (typespec-mode)
      (goto-char (point-min))
      (should (re-search-forward "^model Thing" nil t))
      (beginning-of-line)
      (let ((closing-brace-pos
             (save-excursion
               (search-forward "}")
               (point))))
        (typespec-end-of-defun 1)
        ;; Point should be at or past the closing `}' that terminates the
        ;; model body — definitely past `count: 42'.
        (should (>= (point) closing-brace-pos))
        (should (> (point)
                   (save-excursion
                     (goto-char (point-min))
                     (search-forward "count: 42")
                     (point))))))))

(provide 'typespec-mode-test)
;;; typespec-mode-test.el ends here
