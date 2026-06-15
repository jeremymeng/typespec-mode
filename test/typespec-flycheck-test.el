;;; typespec-flycheck-test.el --- Tests for typespec-flycheck -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Jeremy Meng

;;; Commentary:
;; Tests for typespec-flycheck.el.  The checker definition itself depends on
;; Flycheck being installed; tests that need it are gated with `skip-unless'.

;;; Code:

(require 'ert)
(require 'typespec-flycheck)

;; Forward declarations so byte-compile is clean without Flycheck installed.
(declare-function flycheck-valid-checker-p "flycheck")
(defvar flycheck-checkers)

(ert-deftest typespec-flycheck-setup-exists-test ()
  "`typespec-flycheck-setup' must be defined and autoloaded."
  (should (fboundp 'typespec-flycheck-setup))
  (should (commandp 'typespec-flycheck-setup)))

(ert-deftest typespec-flycheck-setup-without-flycheck-test ()
  "Calling setup when Flycheck is absent must warn, not error."
  (skip-unless (not (featurep 'flycheck)))
  (let ((warning-minimum-level :emergency))
    ;; Should return nil (or any value) without signalling.
    (should-not (condition-case err
                    (progn (typespec-flycheck-setup) nil)
                  (error err)))))

(ert-deftest typespec-flycheck-checker-registered-test ()
  "When Flycheck is installed, the `typespec' checker must be registered."
  (skip-unless (require 'flycheck nil t))
  (should (memq 'typespec flycheck-checkers))
  (should (flycheck-valid-checker-p 'typespec)))

(provide 'typespec-flycheck-test)
;;; typespec-flycheck-test.el ends here
