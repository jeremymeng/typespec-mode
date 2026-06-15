;;; typespec-flymake-test.el --- Tests for typespec-flymake -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Jeremy Meng

;;; Commentary:
;; Tests for typespec-flymake.el

;;; Code:

(require 'ert)
(require 'typespec-flymake)

(ert-deftest typespec-flymake-backend-exists-test ()
  "Test that typespec-flymake-backend function exists."
  (should (fboundp 'typespec-flymake-backend)))

(ert-deftest typespec-flymake-setup-exists-test ()
  "Test that typespec-flymake-setup function exists."
  (should (fboundp 'typespec-flymake-setup)))

(ert-deftest typespec-flymake-output-regex-unix-path-test ()
  "Diagnostic regex must match POSIX-style paths."
  (let ((line "src/main.tsp:10:5 - error TS123: Bad thing"))
    (should (string-match typespec-flymake--output-regex line))
    (should (string= (match-string 1 line) "src/main.tsp"))
    (should (string= (match-string 2 line) "10"))
    (should (string= (match-string 3 line) "5"))
    (should (string= (match-string 4 line) "error"))
    (should (string= (match-string 5 line) "Bad thing"))))

(ert-deftest typespec-flymake-output-regex-windows-path-test ()
  "Regression: diagnostic regex must match Windows paths with drive letters.
The earlier `[^:\\n]+' filename pattern stopped at `C:' and dropped every
diagnostic on Windows.  The fix uses a greedy `.+' that backtracks until
`:LINE:COL - severity CODE: msg' matches at the end of the line."
  (let ((line "C:\\Users\\foo\\bar.tsp:42:7 - warning TS9001: Suspicious"))
    (should (string-match typespec-flymake--output-regex line))
    (should (string= (match-string 1 line) "C:\\Users\\foo\\bar.tsp"))
    (should (string= (match-string 2 line) "42"))
    (should (string= (match-string 3 line) "7"))
    (should (string= (match-string 4 line) "warning"))
    (should (string= (match-string 5 line) "Suspicious"))))

(provide 'typespec-flymake-test)
;;; typespec-flymake-test.el ends here
