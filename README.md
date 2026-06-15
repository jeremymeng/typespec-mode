# typespec-mode

A full-featured Emacs major mode for [TypeSpec](https://typespec.io/) files.

[![CI](https://github.com/jeremymeng/typespec-mode/actions/workflows/test.yml/badge.svg)](https://github.com/jeremymeng/typespec-mode/actions/workflows/test.yml)
[![MELPA](https://melpa.org/packages/typespec-mode-badge.svg)](https://melpa.org/#/typespec-mode)

## Features

- **Syntax highlighting** — Full TypeSpec keyword and type support, including triple-quoted strings and `@@` augment decorators
- **Indentation** — Regex-based indentation respecting nesting depth
- **Navigation** — Imenu/outline for namespaces, models, interfaces, operations, unions, enums, scalars, and aliases
- **Compilation & formatting** — Interactive commands for `tsp compile`, `tsp init`, `npm install`, and `tsp format`
- **Format on save** — Optional minor mode for automatic buffer formatting
- **Project support** — Automatic detection of TypeSpec projects via `project.el`
- **Flymake backend** — Optional on-the-fly linting via `tsp compile --no-emit`
- **Flycheck backend** — Optional on-the-fly linting via the [Flycheck](https://www.flycheck.org/) framework
- **LSP integration** — Built-in `eglot` registration; works with `lsp-mode` via `lsp-typespec`
- **Yasnippet snippets** — Optional snippet bundle with common TypeSpec templates
- **Tree-sitter support** — Optional `typespec-ts-mode` for improved parsing and font-lock (requires grammar)
- **Electric pairs & prettify symbols** — Customizable minor features for TypeSpec syntax

## Requirements

- **Emacs 29.1 or later**
- Optional: `tsp` CLI (TypeScript/Node.js) on `PATH` or in project-local `node_modules/.bin/`
- Optional: `tsp-server` for LSP support (used by both `eglot` and `lsp-mode`)
- Optional: [yasnippet](https://github.com/joaotavora/yasnippet) for snippet support
- Optional: Tree-sitter grammar for TypeSpec (for `typespec-ts-mode`): `M-x treesit-install-language-grammar RET typespec RET`

## Installation

### From MELPA (placeholder)

Once available on MELPA:

```elisp
M-x package-install RET typespec-mode RET
```

### Via `use-package` and `:vc`

```elisp
(use-package typespec-mode
  :vc (:url "https://github.com/jeremymeng/typespec-mode"))
```

### Via `straight.el`

```elisp
(straight-use-package
 '(typespec-mode :type git :host github :repo "jeremymeng/typespec-mode"))
```

### Manual installation

Clone the repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/typespec-mode")
(require 'typespec-mode)
```

## LSP Setup

### Eglot (built-in)

`typespec-mode` automatically registers `tsp-server --stdio` with `eglot`. Simply open a `.tsp` file and run `M-x eglot` to start the server.

To override the server command:

```elisp
(with-eval-after-load 'eglot
  (setf (alist-get 'typespec-mode eglot-server-programs)
        '("tsp-server" "--stdio")))
```

### lsp-mode

The package is compatible with [lsp-mode](https://emacs-lsp.github.io/lsp-mode/) via the upstream [`lsp-typespec`](https://emacs-lsp.github.io/lsp-mode/page/lsp-typespec/) configuration. No additional setup is required beyond what `lsp-typespec` documents.

## Compilation, Formatting & Project Management

Loading the compile module is enough to get the default `C-c C-c` prefix
binding in `typespec-mode' buffers:

```elisp
(with-eval-after-load 'typespec-mode
  (require 'typespec-compile))
```

This binds the following commands under `C-c C-c`:

| Command | Binding | Description |
| --- | --- | --- |
| `typespec-compile` | `C-c C-c c` | Compile the current TypeSpec project |
| `typespec-compile-no-emit` | `C-c C-c n` | Compile without emitting output |
| `typespec-format-buffer` | `C-c C-c f` | Format the current buffer using `tsp format` |
| `typespec-init` | `C-c C-c i` | Initialize a new TypeSpec project |
| `typespec-install` | `C-c C-c I` | Run `npm install` at project root |

To use a different prefix, rebind in your config:

```elisp
(with-eval-after-load 'typespec-compile
  (define-key typespec-mode-map (kbd "C-c C-t") typespec-compile-prefix-map))
```

### Format on Save

Enable automatic formatting of TypeSpec buffers on save:

```elisp
(with-eval-after-load 'typespec-compile
  (add-hook 'typespec-mode-hook #'typespec-format-on-save-mode))
```

Or enable globally via the `typespec-format-on-save` custom variable.

## Flymake

Enable on-the-fly linting via Flymake (opt-in):

```elisp
(add-hook 'typespec-mode-hook #'typespec-flymake-setup)
```

The backend runs `tsp compile --no-emit` at the project root and reports diagnostics for the current buffer.

## Flycheck

Alternatively, use [Flycheck](https://www.flycheck.org/) for on-the-fly linting (opt-in):

```elisp
(add-hook 'typespec-mode-hook #'typespec-flycheck-setup)
```

Customize the executable if `tsp` is not on `PATH`:

```elisp
(setq flycheck-typespec-executable "/path/to/tsp")
```

Flymake and Flycheck are mutually exclusive — pick one.

**Note:** The Flycheck checker requires a direct path to `tsp`. If only `npx tsp`
is available, `typespec-flycheck-setup` will warn and fall back gracefully
(use the Flymake backend in that case).

## Yasnippet Snippets

Initialize the bundled yasnippet snippets (only needed if using yasnippet):

```elisp
(with-eval-after-load 'typespec-snippets
  (typespec-snippets-initialize))
```

Yasnippet is optional and will gracefully disable snippets if not installed.

## Tree-sitter Support

A tree-sitter-based major mode `typespec-ts-mode` is available for improved performance and syntax support (requires tree-sitter Emacs module and the TypeSpec grammar).

### Enable Tree-sitter Mode

Optionally remap `typespec-mode` to `typespec-ts-mode`:

```elisp
(add-to-list 'major-mode-remap-alist '(typespec-mode . typespec-ts-mode))
```

### Install the TypeSpec Grammar

Run:

```
M-x treesit-install-language-grammar RET typespec RET
```

The grammar source (`https://github.com/happenslol/tree-sitter-typespec`) is pre-registered in `typespec-mode` and will be automatically fetched during installation.

## Customization

All customization variables are in the `typespec` group. Customize via `M-x customize-group RET typespec RET` or set manually in your configuration.

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `typespec-indent-offset` | integer | `2` | Indentation width for nested structures |
| `typespec-prettify-symbols` | boolean | `nil` | Enable prettier symbol display (`=>` → `⇒`) |
| `typespec-tsp-command` | string | `"tsp"` | Command or path to the TypeSpec compiler; auto-detects project-local binaries |
| `typespec-format-on-save` | boolean | `nil` | Enable automatic formatting on buffer save globally |
| `typespec-compile-extra-args` | list of strings | `nil` | Extra arguments to pass to `tsp compile` |

## Contributing

Contributions are welcome! To run the test suite:

```bash
eldev test
```

File issues or PRs at https://github.com/jeremymeng/typespec-mode/. See `CONTRIBUTING.md` for the release process.

## License

Licensed under GPL-3.0-or-later. See `LICENSE`.
