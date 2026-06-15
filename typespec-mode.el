;;; typespec-mode.el --- Major mode for TypeSpec files -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Jeremy Meng
;; Author: Jeremy Meng
;; URL: https://github.com/jeremymeng/typespec-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, tools
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Major mode for TypeSpec (https://typespec.io/) files.
;; This package provides syntax highlighting, indentation, imenu, and integration
;; with language servers.

;;; Code:

(require 'treesit nil t)

;; Forward declarations for treesit symbols
(declare-function treesit-parser-create "treesit")
(declare-function treesit-ready-p "treesit")
(declare-function treesit-font-lock-rules "treesit")
(declare-function treesit-major-mode-setup "treesit")
(defvar treesit-font-lock-settings)
(defvar treesit-font-lock-feature-list)
(defvar treesit-simple-indent-rules)
(defvar treesit-simple-imenu-settings)
(defvar treesit-language-source-alist)

(defgroup typespec nil
  "Major mode for TypeSpec."
  :group 'languages
  :prefix "typespec-")

;;; Customization

(defcustom typespec-indent-offset 2
  "Indentation offset for `typespec-mode'."
  :type 'integer
  :safe #'integerp
  :group 'typespec)

(defcustom typespec-prettify-symbols nil
  "Non-nil if `typespec-mode' should set up prettify-symbols."
  :type 'boolean
  :group 'typespec)

(defconst typespec-mode-keywords
  '("import" "using" "namespace" "model" "scalar" "interface" "op"
    "union" "enum" "alias" "extends" "is" "extern" "dec" "fn"
    "const" "if" "else" "projection" "return" "void")
  "Keywords in the TypeSpec language.")

(defconst typespec-mode-builtin-types
  '("string" "boolean" "bytes" "url" "unknown" "never" "null"
    "int8" "int16" "int32" "int64"
    "uint8" "uint16" "uint32" "uint64" "safeint"
    "float" "float32" "float64" "decimal" "decimal128" "integer" "numeric"
    "plainDate" "plainTime" "utcDateTime" "offsetDateTime" "duration"
    "Record" "Array")
  "Built-in scalar types in TypeSpec.")

(defconst typespec-mode-font-lock-keywords
  (list
   ;; Decorators (including @@ augment) - must come before type identifiers
   '("\\(@@?[A-Za-z_][A-Za-z0-9_]*\\)" 1 'font-lock-preprocessor-face)
   ;; Keywords
   (cons (regexp-opt typespec-mode-keywords 'symbols) 'font-lock-keyword-face)
   ;; Builtin types
   (cons (regexp-opt typespec-mode-builtin-types 'symbols) 'font-lock-type-face)
   ;; Declaration name captures: model, interface, union, enum, scalar, alias
   '("\\_<\\(model\\|interface\\|union\\|enum\\|scalar\\|alias\\)\\_>\\s-+\\([A-Za-z_][A-Za-z0-9_]*\\)"
     2 'font-lock-type-face)
   ;; Operation name after 'op'
   '("\\_<op\\_>\\s-+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1 'font-lock-function-name-face)
   ;; Namespace name
   '("\\_<namespace\\_>\\s-+\\([A-Za-z_][A-Za-z0-9_.]*\\)" 1 'font-lock-constant-face)
   ;; Capitalized type identifiers (catch-all, last)
   '("\\_<\\([A-Z][A-Za-z0-9_]*\\)\\_>" 1 'font-lock-type-face)
   ;; Numbers
   '("\\_<[0-9]+\\(?:\\.[0-9]+\\)?\\_>" . 'font-lock-constant-face))
  "Font-lock keywords for TypeSpec mode.")

(defconst typespec-mode--triple-quote-re
  "\"\"\""
  "Regular expression matching triple-quote delimiters.")

(defun typespec-mode-syntax-propertize (start end)
  "Apply `syntax-table' properties to triple-quoted strings between START and END."
  (goto-char start)
  (funcall
   (syntax-propertize-rules
    ;; Triple-quoted strings: mark the first quote of each """ as a string fence.
    ;; Emacs will pair them up: first fence opens, next fence closes, etc.
    ("\"\"\""
     (0 (ignore
         (let ((ppss (save-excursion (syntax-ppss (match-beginning 0)))))
           ;; If we're inside a comment, do nothing
           (unless (nth 4 ppss)
             ;; Always mark the first quote char as a generic string fence.
             ;; Don't check (nth 3 ppss) because the previous """ might have
             ;; opened a string that this one should close.
             (put-text-property (match-beginning 0) (1+ (match-beginning 0))
                                'syntax-table (string-to-syntax "|"))))))))
   start end))

(defvar typespec-mode-syntax-table
  (let ((table (make-syntax-table prog-mode-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\\\" table)
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?@ "'" table)
    (modify-syntax-entry ?? "." table)
    table)
  "Syntax table for TypeSpec mode.")

;;; Indentation

(defun typespec-indent-line ()
  "Indent the current line for `typespec-mode'."
  (interactive)
  (let* ((ppss (syntax-ppss))
         (in-string-or-comment (or (nth 3 ppss) (nth 4 ppss))))
    (if in-string-or-comment
        ;; Leave indentation alone inside strings/comments
        nil
      (let* ((depth (car ppss))
             (current-line-start (save-excursion
                                   (beginning-of-line)
                                   (skip-chars-forward " \t")
                                   (point)))
             (closing-brace (save-excursion
                              (goto-char current-line-start)
                              (looking-at "[]})]")))
             (target-indent (if closing-brace
                                (* (max 0 (1- depth)) typespec-indent-offset)
                              (* depth typespec-indent-offset))))
        (indent-line-to target-indent)))))

;;; Navigation (Imenu, Outline, Defun)

(defconst typespec-imenu-generic-expression
  '(("Namespaces" "^[ \t]*namespace[ \t]+\\([A-Za-z_][A-Za-z0-9_.]*\\)" 1)
    ("Models" "^[ \t]*model[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Interfaces" "^[ \t]*interface[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Ops" "^[ \t]*op[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Unions" "^[ \t]*union[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Enums" "^[ \t]*enum[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Scalars" "^[ \t]*scalar[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1)
    ("Aliases" "^[ \t]*alias[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1))
  "Imenu expression for TypeSpec mode.")

(defconst typespec-outline-regexp
  "^[ \t]*\\(namespace\\|model\\|interface\\|op\\|union\\|enum\\|scalar\\|alias\\|dec\\|fn\\)\\b"
  "Outline regexp for TypeSpec mode.")

(defun typespec-beginning-of-defun (&optional arg)
  "Move backward to the beginning of a TypeSpec declaration.
With ARG, move backward ARG declarations."
  (interactive "^p")
  (unless arg (setq arg 1))
  (let ((search-fn (if (>= arg 0) #'re-search-backward #'re-search-forward))
        (count (abs arg)))
    (dotimes (_ count)
      (funcall search-fn typespec-outline-regexp nil t))
    (when (and (>= arg 0) (looking-at typespec-outline-regexp))
      (goto-char (match-beginning 0)))))

(defun typespec-end-of-defun (&optional arg)
  "Move forward to the end of a TypeSpec declaration.
With ARG, move forward ARG declarations.

For declarations with a body (`{...}'), jumps past the matching
closing brace via `forward-sexp'.  For statement-like declarations
\(`alias', `scalar' without body, `using', `import'), advances past
the terminating semicolon."
  (interactive "^p")
  (unless arg (setq arg 1))
  (when (> arg 0)
    (dotimes (_ arg)
      ;; Find the next defun start at or after point.
      (unless (looking-at typespec-outline-regexp)
        (re-search-forward typespec-outline-regexp nil 'move))
      (beginning-of-line)
      (let ((line-end (line-end-position)))
        (cond
         ;; Body: jump to matching close brace.
         ((search-forward "{" line-end t)
          (backward-char 1)
          (condition-case nil
              (forward-sexp 1)
            (error (goto-char (point-max)))))
         ;; Statement-style: find terminating semicolon.
         ((search-forward ";" nil t))
         (t (end-of-line)))))))

;;; Prettify symbols

(defconst typespec-prettify-symbols-alist
  '(("=>" . ?⇒))
  "Prettify symbols alist for TypeSpec mode.")

;;; Eglot integration

(defvar eglot-server-programs)  ; silence byte-compiler

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(typespec-mode . ("tsp-server" "--stdio"))))

;;; Keymap

(defvar typespec-mode-map (make-sparse-keymap)
  "Keymap for `typespec-mode'.
Loading `typespec-compile' adds a binding for `C-c C-c' that
serves as a prefix for `typespec-compile-prefix-map'.")

;; Auto-bind the compile prefix map when `typespec-compile' is loaded.
;; Users who do not load `typespec-compile' get no binding (and can avoid
;; the dependency entirely).
(with-eval-after-load 'typespec-compile
  (define-key typespec-mode-map (kbd "C-c C-c")
              (symbol-value 'typespec-compile-prefix-map)))

;;;###autoload
(define-derived-mode typespec-mode prog-mode "typespec"
  "Major mode for TypeSpec files."
  :syntax-table typespec-mode-syntax-table
  (setq-local indent-tabs-mode nil)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*\\|/\\*+\\s-*")
  (setq-local comment-use-syntax t)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local font-lock-defaults '(typespec-mode-font-lock-keywords))
  (setq-local syntax-propertize-function #'typespec-mode-syntax-propertize)
  ;; Indentation
  (setq-local indent-line-function #'typespec-indent-line)
  (setq-local tab-width typespec-indent-offset)
  ;; Navigation
  (setq-local imenu-generic-expression typespec-imenu-generic-expression)
  (setq-local outline-regexp typespec-outline-regexp)
  (setq-local outline-level (lambda () 1))
  (setq-local beginning-of-defun-function #'typespec-beginning-of-defun)
  (setq-local end-of-defun-function #'typespec-end-of-defun)
  ;; Electric pair
  (setq-local electric-pair-text-pairs '((?\" . ?\") (?\` . ?\`)))
  ;; Prettify symbols
  (when typespec-prettify-symbols
    (setq-local prettify-symbols-alist
                (append typespec-prettify-symbols-alist
                        prettify-symbols-alist))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.tsp\\'" . typespec-mode))

;;; Tree-sitter support

(when (featurep 'treesit)
  
  ;; Register the grammar source for easy installation
  (with-eval-after-load 'treesit
    (add-to-list 'treesit-language-source-alist
                 '(typespec "https://github.com/happenslol/tree-sitter-typespec")))
  
  (defconst typespec-ts-mode--font-lock-settings
    (when (fboundp 'treesit-font-lock-rules)
      (treesit-font-lock-rules
       :language 'typespec
       :feature 'comment
       '((comment) @font-lock-comment-face)
       
       :language 'typespec
       :feature 'string
       '((string) @font-lock-string-face)
       
       :language 'typespec
       :feature 'number
       '((number) @font-lock-constant-face)
       
       :language 'typespec
       :feature 'keyword
       `([(keyword) @font-lock-keyword-face
          ;; Explicit keyword list for coverage
          "import" "using" "namespace" "model" "scalar" "interface" "op"
          "union" "enum" "alias" "extends" "is" "extern" "dec" "fn"
          "const" "if" "else" "projection" "return" "void"] @font-lock-keyword-face)
       
       :language 'typespec
       :feature 'type
       `([;; Builtin scalar types
          "string" "boolean" "bytes" "url" "unknown" "never" "null"
          "int8" "int16" "int32" "int64"
          "uint8" "uint16" "uint32" "uint64" "safeint"
          "float" "float32" "float64" "decimal" "decimal128" "integer" "numeric"
          "plainDate" "plainTime" "utcDateTime" "offsetDateTime" "duration"
          "Record" "Array"] @font-lock-type-face
         (identifier) @font-lock-type-face)
       
       :language 'typespec
       :feature 'decorator
       '((decorator) @font-lock-preprocessor-face)))
    "Tree-sitter font-lock settings for `typespec-ts-mode'.
Note: The node names used here are conservative starter patterns.
Contributions to expand coverage are welcome.")
  
  (defconst typespec-ts-mode--indent-rules
    `((typespec
       ((parent-is "source_file") column-0 0)
       ((node-is "}") parent-bol 0)
       ((node-is ")") parent-bol 0)
       ((node-is "]") parent-bol 0)
       ((parent-is "object") parent-bol typespec-indent-offset)
       ((parent-is "block") parent-bol typespec-indent-offset)
       ((parent-is "array") parent-bol typespec-indent-offset)
       (catch-all parent-bol typespec-indent-offset)))
    "Tree-sitter indentation rules for `typespec-ts-mode'.
Conservative starter set; can be expanded based on actual grammar nodes.")
  
  (defconst typespec-ts-mode--imenu-settings
    '(("Namespaces" "\\`namespace_declaration\\'" nil nil)
      ("Models" "\\`model_declaration\\'" nil nil)
      ("Interfaces" "\\`interface_declaration\\'" nil nil)
      ("Ops" "\\`operation_declaration\\'" nil nil)
      ("Unions" "\\`union_declaration\\'" nil nil)
      ("Enums" "\\`enum_declaration\\'" nil nil)
      ("Scalars" "\\`scalar_declaration\\'" nil nil)
      ("Aliases" "\\`alias_declaration\\'" nil nil))
    "Tree-sitter imenu settings for `typespec-ts-mode'.
Conservative patterns based on likely grammar node names.")
  
  ;;;###autoload
  (define-derived-mode typespec-ts-mode typespec-mode "TypeSpec[ts]"
    "Major mode for TypeSpec files, using tree-sitter for parsing.

This mode derives from `typespec-mode' and adds tree-sitter-based
font-lock, indentation, and imenu support.  It requires the tree-sitter
grammar for TypeSpec to be installed.

To install the grammar, run:
  M-x treesit-install-language-grammar RET typespec RET

The grammar will be fetched from:
  https://github.com/happenslol/tree-sitter-typespec

Note: The font-lock and indentation rules are a conservative starter set.
Contributions to expand coverage are welcome.

\\{typespec-ts-mode-map}"
    (if (not (treesit-ready-p 'typespec))
        (error "Tree-sitter grammar for typespec is not installed.  Run M-x treesit-install-language-grammar RET typespec RET.  Recipe: https://github.com/happenslol/tree-sitter-typespec")
      ;; Tree-sitter is ready, set it up
      (treesit-parser-create 'typespec)
      
      ;; Font-lock
      (setq-local treesit-font-lock-settings typespec-ts-mode--font-lock-settings)
      (setq-local treesit-font-lock-feature-list
                  '((comment string number)
                    (keyword type)
                    (decorator)))
      
      ;; Indentation
      (setq-local treesit-simple-indent-rules typespec-ts-mode--indent-rules)
      
      ;; Imenu
      (setq-local treesit-simple-imenu-settings typespec-ts-mode--imenu-settings)
      
      ;; Activate tree-sitter
      (treesit-major-mode-setup))))

(provide 'typespec-mode)
;;; typespec-mode.el ends here
