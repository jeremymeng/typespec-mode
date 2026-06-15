# Contributing to typespec-mode

Thank you for your interest in contributing to typespec-mode!

## Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jeremymeng/typespec-mode.git
   cd typespec-mode
   ```

2. **Install Eldev:**
   
   [Eldev](https://github.com/doublep/eldev) is a build tool for Emacs Lisp projects. Install it by following the instructions at https://github.com/doublep/eldev#installation.

   After installation, the `eldev` executable will be available in your PATH (or `~/.eldev/bin/eldev` on Unix-like systems).

3. **Install dependencies:**
   ```bash
   eldev prepare
   ```

## Running Tests

Run the full test suite with:

```bash
eldev -p -dtT test
```

The flags mean:
- `-p`: Print full backtraces on errors
- `-d`: Load source files directly (not byte-compiled)
- `-t`: Print elapsed time
- `-T`: Enable test tracing

To run a single test file:

```bash
eldev -p -dtT test test/typespec-mode-test.el
```

Or a specific test:

```bash
eldev -p -dtT test typespec-mode-indentation
```

## Byte-Compile Check

Before submitting a pull request, ensure all source files byte-compile cleanly:

```bash
emacs -Q --batch -L . -f batch-byte-compile typespec-*.el
```

There must be no warnings or errors.

## Linting

Run the package linters to catch common issues:

```bash
eldev lint
```

This runs:
- **package-lint**: Checks for MELPA compliance and packaging best practices
- **checkdoc**: Verifies documentation strings follow Emacs conventions

**Errors must be fixed.** Warnings should be addressed where possible, but minor style warnings may be acceptable if they improve readability.

## Release Checklist (for maintainers)

### First Release (MELPA submission)

1. **Bump the version** in `typespec-mode.el`:
   ```elisp
   ;; Version: 0.1.0
   ```

2. **Update CHANGELOG** (future addition):
   
   Once a CHANGELOG file is added to the repository, document all user-facing changes for the release.

3. **Tag the release:**
   ```bash
   git tag v0.1.0
   git push --tags
   ```

4. **Submit to MELPA (first release only):**
   
   a. Fork https://github.com/melpa/melpa
   
   b. Copy `recipes/typespec-mode` from this repository into the `recipes/` directory of your MELPA fork
   
   c. Open a pull request following the guidelines at https://github.com/melpa/melpa/blob/master/CONTRIBUTING.org
   
   d. After the PR is merged, update the MELPA badge URL in `README.md` from the placeholder to:
      ```markdown
      [![MELPA](https://melpa.org/packages/typespec-mode-badge.svg)](https://melpa.org/#/typespec-mode)
      ```

### Subsequent Releases

For releases after the initial MELPA submission:

1. Bump the version in `typespec-mode.el`
2. Update the CHANGELOG
3. Tag the release and push the tag:
   ```bash
   git tag v0.2.0
   git push --tags
   ```

MELPA-stable will automatically rebuild the package when it detects a new tag.

## Questions or Issues?

- **Bug reports and feature requests:** Open an issue on GitHub
- **Questions:** Open a discussion on GitHub or mention in an issue
- **Pull requests:** Always welcome! Please run tests and linting before submitting.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).
