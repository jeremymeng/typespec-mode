;;; typespec-compile-test.el --- Tests for typespec-compile -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Jeremy Meng

;;; Commentary:
;; Tests for typespec-compile.el

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'typespec-compile)

(ert-deftest typespec-compile-project-root-test ()
  "Test project root detection from tspconfig.yaml."
  (let ((temp-dir (make-temp-file "typespec-test-" t)))
    (unwind-protect
        (let ((tspconfig (expand-file-name "tspconfig.yaml" temp-dir)))
          (with-temp-file tspconfig
            (insert "# test config\n"))
          (let ((default-directory temp-dir))
            (should (file-equal-p (typespec-project-root) temp-dir))))
      (delete-directory temp-dir t))))

(ert-deftest typespec-compile-project-root-from-subdir-test ()
  "Test project root detection from subdirectory."
  (let ((temp-dir (make-temp-file "typespec-test-" t)))
    (unwind-protect
        (let* ((subdir (expand-file-name "sub" temp-dir))
               (tspconfig (expand-file-name "tspconfig.yaml" temp-dir)))
          (make-directory subdir)
          (with-temp-file tspconfig
            (insert "# test config\n"))
          (let ((default-directory subdir))
            (should (file-equal-p (typespec-project-root) temp-dir))))
      (delete-directory temp-dir t))))

(ert-deftest typespec-compile-resolve-tsp-fallback-test ()
  "Test that typespec--resolve-tsp returns npx fallback when command is missing."
  (let ((typespec-tsp-command "nonexistent-command-12345"))
    (should (equal (typespec--resolve-tsp) '("npx" "tsp")))))

(ert-deftest typespec-compile-build-command-string-test ()
  "`typespec--build-command' must return a string when given string TSP-CMD."
  (let ((cmd (typespec--build-command "tsp" "compile" "--no-emit" ".")))
    (should (stringp cmd))
    (should (string-match-p "tsp" cmd))
    (should (string-match-p "compile" cmd))
    (should (string-match-p "--no-emit" cmd))))

(ert-deftest typespec-compile-build-command-list-test ()
  "`typespec--build-command' must return a string when given list TSP-CMD (npx fallback)."
  (let ((cmd (typespec--build-command '("npx" "tsp") "compile" ".")))
    (should (stringp cmd))
    (should (string-match-p "npx" cmd))
    (should (string-match-p "tsp" cmd))))

(ert-deftest typespec-compile-extra-args-splat-regression-test ()
  "Regression: `typespec-compile-extra-args' must be spliced, not passed as a list.
Previously, callers in `typespec-compile' and `typespec-compile-no-emit'
passed `(append typespec-compile-extra-args (list \".\"))' as a single
argument to `typespec--build-command', which made the trailing element a
list and caused `shell-quote-argument' to error with
\"wrong-type-argument stringp (\\\".\\\")\".  The fix uses `apply' so the
list is splatted into &rest args.

This test exercises the real production code path (`typespec-compile-no-emit')
with `compilation-start' stubbed out so no external process is spawned."
  (let* ((temp-dir (make-temp-file "typespec-regression-" t))
         (captured-cmd nil))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "tspconfig.yaml" temp-dir)
            (insert "# test config\n"))
          (let ((default-directory temp-dir)
                (typespec-compile-extra-args '("--option" "value"))
                (typespec-tsp-command "nonexistent-command-12345"))
            ;; Stub compilation-start so it does not actually spawn a process.
            (cl-letf (((symbol-function 'compilation-start)
                       (lambda (cmd &rest _) (setq captured-cmd cmd) nil)))
              ;; The buggy version raised (wrong-type-argument stringp ...) here.
              (typespec-compile-no-emit))
            (should (stringp captured-cmd))
            (should (string-match-p "--option" captured-cmd))
            (should (string-match-p "value" captured-cmd))
            (should (string-match-p "--no-emit" captured-cmd))
            ;; The trailing "." must be a quoted argument, not the printed
            ;; representation of a list `(".")'.
            (should-not (string-match-p "(" captured-cmd))))
      (delete-directory temp-dir t))))

(provide 'typespec-compile-test)
;;; typespec-compile-test.el ends here
