# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal Emacs configuration using the [`leaf`](https://github.com/conao3/leaf.el) package manager for declarative package configuration. The entry point is `init.el`, which bootstraps `leaf`/`leaf-keywords` and then delegates to `init-loader` to load all files under `inits/`.

## Loading Order

`init-loader` loads files in `inits/` **alphabetically**. Naming conventions:

- Files loaded normally: `01_setup.el`, `02_ivy.el`, `04_tabspace.el`, etc.
- Files prefixed with `_` (e.g., `_10_mew.el`) are **disabled/skipped** by init-loader
- `inits/mode/` contains major-mode-specific configurations

## Key Architecture

### Package Management
- `leaf` is the primary package configurator (similar to `use-package`)
- `leaf-keywords` extends leaf with `:hydra`, `:el-get`, `:blackout`, `:bind-key` support
- `el-get` is available as an alternative install method for packages not on ELPA/MELPA

### Core Configuration Files
| File | Purpose |
|------|---------|
| `init.el` | Bootstrap: initializes leaf, loads doom-dracula theme, runs init-loader |
| `inits/01_setup.el` | Base settings: whitespace, display, OS detection variables, auto-insert |
| `inits/02_ivy.el` | ivy/counsel/swiper completion framework with custom window actions |
| `inits/04_tabspace.el` | tabspaces workspace management with hydra UI (`C-f`) |
| `inits/10_lsp.el` | flycheck + lsp-mode + company for language-server features |
| `inits/20_org.el` | org-mode, org-agenda, org-capture configuration |
| `inits/33_org-journal.el` | org-journal setup |
| `inits/75_org-roam.el` | org-roam knowledge base |
| `inits/80_new-mode.el` | Reusable template for creating new major modes |
| `inits/94_keybinds.el` | Global keybindings via `bind-key` and `mykie` |

### OS Detection
`01_setup.el` sets these variables for conditional config:
```elisp
darwin-p        ; macOS
windows-nt-p    ; Windows (loads inits/win.el)
linux-p         ; Linux
```

### Custom Major Mode Template (`80_new-mode.el`)
`new-mode` serves as a fully documented template for building new major modes. When creating a language mode, copy and adapt:
- Keyword lists: `new-mode-keywords-control`, `-declaration`, `-visibility`, `-module`, `-exception`, `-other`, `-types`, `-builtins`
- Syntax table: `new-mode-syntax-table`
- Font-lock rules: `new-mode-font-lock-keywords`
- Indentation: `new-mode-indent-line`
- Customization group: `new-mode` (all `defcustom` variables)

## Emacs Lisp Conventions

- Use `leaf` blocks for all package configuration; avoid bare `require`/`use-package`
- Byte-compile warnings are suppressed for specific categories in `init.el` — keep this list intentional
- Cache/state files go to `~/.cache/emacs/` (configured in `01_setup.el`)
- Indent: 2 spaces, no tabs (`indent-tabs-mode nil`)

## Testing Changes

Load a single init file interactively:
```
M-x load-file RET ~/.emacs.d/inits/<file>.el RET
```

Byte-compile to check for errors:
```
M-x byte-compile-file RET ~/.emacs.d/inits/<file>.el RET
```

Check startup errors:
```bash
emacs --batch -l ~/.emacs.d/init.el 2>&1 | head -50
```
