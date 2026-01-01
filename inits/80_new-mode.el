;;; new-mode.el --- Template for creating a new major mode

;; Author: Your Name
;; Version: 0.2.0
;; Keywords: languages

;;; Commentary:
;; This is a template for creating a new major mode in Emacs.
;; It demonstrates:
;; - Syntax highlighting for keywords
;; - String literals ("")
;; - Comments (// and /* */ and @)
;; - Parentheses and braces matching
;; - Automatic indentation
;;
;; To customize this mode for your language:
;; 1. Update the customization variables section
;; 2. Modify the syntax table for your language's syntax
;; 3. Add/remove keywords in the keyword lists
;; 4. Adjust the font-lock patterns for syntax highlighting
;; 5. Customize the indentation rules
;; 6. Update the file extension association

;;; Code:

(require 'prog-mode)

;;; ============================================================================
;;; Customization Variables (User-configurable settings)
;;; ============================================================================

(defgroup new-mode nil
  "Major mode for editing new-mode files."
  :group 'languages
  :prefix "new-mode-")

;; Indentation
(defcustom new-mode-indent-offset 2
  "Number of spaces for each indentation level.
Typical values: 2, 4, or 8."
  :type 'integer
  :safe 'integerp
  :group 'new-mode)

;; Comments
(defcustom new-mode-comment-start "//"
  "String to insert to start a new comment."
  :type 'string
  :safe 'stringp
  :group 'new-mode)

(defcustom new-mode-comment-end ""
  "String to insert to end a comment."
  :type 'string
  :safe 'stringp
  :group 'new-mode)

;; File extension
(defcustom new-mode-file-extension "\\.new\\'"
  "Regular expression for file extensions that should use new-mode.
Examples: \"\\\\.new\\\\'\" or \"\\\\.\\\\(new\\\\|mynew\\\\)\\\\'\"."
  :type 'string
  :safe 'stringp
  :group 'new-mode)

;; Faces (for syntax highlighting customization)
(defcustom new-mode-use-custom-faces nil
  "If non-nil, use custom faces instead of standard font-lock faces."
  :type 'boolean
  :group 'new-mode)

;; Automatic features
(defcustom new-mode-enable-electric-pair t
  "If non-nil, automatically insert closing brackets and quotes."
  :type 'boolean
  :group 'new-mode)

(defcustom new-mode-enable-auto-indent t
  "If non-nil, automatically indent after pressing RET."
  :type 'boolean
  :group 'new-mode)

;;; ============================================================================
;;; Syntax Table (Character syntax definitions)
;;; ============================================================================
;; This defines how Emacs treats different characters (comments, strings, etc.)
;; See: (info "(elisp) Syntax Tables")

(defvar new-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; -----------------------------------------------------------------
    ;; Comments
    ;; -----------------------------------------------------------------
    ;; C-style // comments
    ;; "." = punctuation, "1" = comment start A, "2" = comment start B
    (modify-syntax-entry ?/ ". 12" table)
    (modify-syntax-entry ?\n ">" table)  ; ">" = comment end

    ;; @ comments (line comments starting with @)
    ;; "<" = comment start
    (modify-syntax-entry ?@ "< " table)

    ;; Note: /* ... */ comments are handled separately in font-lock

    ;; -----------------------------------------------------------------
    ;; Strings
    ;; -----------------------------------------------------------------
    (modify-syntax-entry ?\" "\"" table)  ; " = string quote
    (modify-syntax-entry ?\\ "\\" table)  ; \ = escape character

    ;; To add single-quote strings, uncomment:
    ;; (modify-syntax-entry ?' "\"" table)

    ;; -----------------------------------------------------------------
    ;; Brackets and Parentheses
    ;; -----------------------------------------------------------------
    (modify-syntax-entry ?\( "()" table)  ; () = paired parenthesis
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)  ; {} = paired braces
    (modify-syntax-entry ?\} "){" table)

    ;; To add square brackets, uncomment:
    ;; (modify-syntax-entry ?\[ "(]" table)
    ;; (modify-syntax-entry ?\] ")[" table)

    ;; -----------------------------------------------------------------
    ;; Operators and Symbols
    ;; -----------------------------------------------------------------
    ;; "." = punctuation (not part of words)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)

    ;; To make some characters part of words (e.g., underscore), use:
    ;; (modify-syntax-entry ?_ "w" table)  ; "w" = word constituent

    table)
  "Syntax table for `new-mode'.")

;;; ============================================================================
;;; Keywords (for syntax highlighting)
;;; ============================================================================
;; Add or remove keywords here to match your language

;; Control flow keywords
(defconst new-mode-keywords-control
  '("if" "else" "elif" "endif"
    "while" "for" "do" "foreach"
    "switch" "case" "default"
    "break" "continue" "return" "goto")
  "Control flow keywords for `new-mode'.")

;; Declaration keywords
(defconst new-mode-keywords-declaration
  '("function" "def" "fn"
    "class" "struct" "interface" "enum"
    "var" "let" "const"
    "static" "final" "abstract")
  "Declaration keywords for `new-mode'.")

;; Visibility keywords
(defconst new-mode-keywords-visibility
  '("public" "private" "protected" "internal")
  "Visibility keywords for `new-mode'.")

;; Module keywords
(defconst new-mode-keywords-module
  '("import" "export" "package" "namespace" "module" "use")
  "Module-related keywords for `new-mode'.")

;; Exception handling keywords
(defconst new-mode-keywords-exception
  '("try" "catch" "finally" "throw" "raise")
  "Exception handling keywords for `new-mode'.")

;; Other keywords
(defconst new-mode-keywords-other
  '("new" "delete" "this" "super" "self"
    "true" "false" "null" "nil" "undefined"
    "and" "or" "not")
  "Other keywords for `new-mode'.")

;; Combine all keywords
(defconst new-mode-keywords
  (append new-mode-keywords-control
          new-mode-keywords-declaration
          new-mode-keywords-visibility
          new-mode-keywords-module
          new-mode-keywords-exception
          new-mode-keywords-other)
  "All keywords for `new-mode'.")

;; Type keywords
(defconst new-mode-types
  '("int" "integer" "long" "short" "byte"
    "float" "double" "decimal" "number"
    "char" "string" "str"
    "bool" "boolean"
    "void" "any" "object"
    "array" "list" "map" "dict" "set" "tuple")
  "Type keywords for `new-mode'.")

;; Built-in functions/constants (add your language's built-ins)
(defconst new-mode-builtins
  '("print" "println" "printf"
    "len" "length" "size"
    "append" "push" "pop"
    "typeof" "instanceof")
  "Built-in functions and constants for `new-mode'.")

;;; ============================================================================
;;; Font Lock (Syntax Highlighting Rules)
;;; ============================================================================
;; Order matters: earlier patterns take precedence

(defvar new-mode-font-lock-keywords
  `(
    ;; -----------------------------------------------------------------
    ;; Comments
    ;; -----------------------------------------------------------------
    ;; Block comments /* ... */
    ("/\\*\\([^*]\\|\\*[^/]\\)*\\*/" . font-lock-comment-face)

    ;; -----------------------------------------------------------------
    ;; Keywords (by category)
    ;; -----------------------------------------------------------------
    (,(regexp-opt new-mode-keywords 'words) . font-lock-keyword-face)
    (,(regexp-opt new-mode-types 'words) . font-lock-type-face)
    (,(regexp-opt new-mode-builtins 'words) . font-lock-builtin-face)

    ;; -----------------------------------------------------------------
    ;; Function definitions: "function name(" or "def name("
    ;; -----------------------------------------------------------------
    ("\\<\\(?:function\\|def\\|fn\\)\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
     1 font-lock-function-name-face)

    ;; -----------------------------------------------------------------
    ;; Function calls: "name("
    ;; -----------------------------------------------------------------
    ("\\<\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*("
     1 font-lock-function-name-face)

    ;; -----------------------------------------------------------------
    ;; Constants
    ;; -----------------------------------------------------------------
    ;; ALL_CAPS_IDENTIFIERS
    ("\\<[A-Z_][A-Z0-9_]+\\>" . font-lock-constant-face)

    ;; Numbers (integers and floats)
    ("\\<[0-9]+\\(\\.[0-9]+\\)?\\>" . font-lock-constant-face)

    ;; Hexadecimal numbers: 0x1234
    ("\\<0[xX][0-9a-fA-F]+\\>" . font-lock-constant-face)

    ;; -----------------------------------------------------------------
    ;; Variables (catch-all for remaining identifiers)
    ;; -----------------------------------------------------------------
    ;; This should be last to avoid overriding other patterns
    ;; ("\\<[a-z_][a-zA-Z0-9_]*\\>" . font-lock-variable-name-face)
    )
  "Font lock keywords for `new-mode'.

To add custom highlighting patterns, use this format:
  (MATCHER . FACE)
or
  (MATCHER SUBEXP FACE)

Examples:
  ;; Highlight TODO in comments
  (\"\\\\<TODO\\\\>\" . font-lock-warning-face)

  ;; Highlight @annotations
  (\"@[a-zA-Z_][a-zA-Z0-9_]*\" . font-lock-preprocessor-face)
")

;;; ============================================================================
;;; Indentation
;;; ============================================================================
;; Customize these rules based on your language's indentation requirements

(defun new-mode-indent-line ()
  "Indent current line for `new-mode'.

Indentation rules:
1. Lines starting with } or ) are dedented
2. Lines after { or ( are indented
3. Lines after 'if' without braces are indented
4. Other lines use the same indentation as the previous line

To customize, modify the patterns in the cond statement below."
  (interactive)
  (let ((indent-col 0)
        (current-indent (current-indentation))
        (point-offset (- (current-column) current-indent)))
    (save-excursion
      (beginning-of-line)
      (if (bobp)
          ;; First line: no indentation
          (setq indent-col 0)
        (let ((not-indented t)
              cur-line)
          ;; Get current line text
          (setq cur-line (buffer-substring-no-properties
                          (line-beginning-position)
                          (line-end-position)))

          (cond
           ;; -----------------------------------------------------------------
           ;; Rule 1: Closing brackets - decrease indent
           ;; -----------------------------------------------------------------
           ((string-match "^\\s-*[)}]" cur-line)
            (save-excursion
              (forward-line -1)
              (setq indent-col (- (current-indentation) new-mode-indent-offset))
              (when (< indent-col 0)
                (setq indent-col 0))))

           ;; -----------------------------------------------------------------
           ;; Rule 2: Normal lines - look at previous lines
           ;; -----------------------------------------------------------------
           (t
            (save-excursion
              (while not-indented
                (forward-line -1)
                (if (bobp)
                    (setq not-indented nil)
                  (let ((prev-line (buffer-substring-no-properties
                                    (line-beginning-position)
                                    (line-end-position))))
                    (cond
                     ;; Previous line ends with opening bracket: increase indent
                     ((string-match "[({]\\s-*$" prev-line)
                      (setq indent-col (+ (current-indentation) new-mode-indent-offset))
                      (setq not-indented nil))

                     ;; Previous line is a closing bracket: use its indentation
                     ((string-match "^\\s-*[)}]" prev-line)
                      (setq indent-col (current-indentation))
                      (setq not-indented nil))

                     ;; Previous line is 'if' without braces: increase indent
                     ;; (Add more keywords as needed: while, for, etc.)
                     ((string-match "\\<\\(if\\|while\\|for\\)\\>.*[^{]\\s-*$" prev-line)
                      (setq indent-col (+ (current-indentation) new-mode-indent-offset))
                      (setq not-indented nil))

                     ;; Empty line: keep searching
                     ((string-match "^\\s-*$" prev-line)
                      t)

                     ;; Default: use same indentation as previous line
                     (t
                      (setq indent-col (current-indentation))
                      (setq not-indented nil)))))))))))))

    ;; Apply the indentation
    (indent-line-to indent-col)

    ;; Restore cursor position relative to indentation
    (when (> point-offset 0)
      (forward-char point-offset))))

;;; ============================================================================
;;; Keybindings
;;; ============================================================================

(defvar new-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Auto-indent on RET (controlled by customization variable)
    (when new-mode-enable-auto-indent
      (define-key map (kbd "RET") 'newline-and-indent))

    ;; Add custom keybindings here:
    ;; (define-key map (kbd "C-c C-c") 'new-mode-compile)
    ;; (define-key map (kbd "C-c C-r") 'new-mode-run)

    map)
  "Keymap for `new-mode'.")

;;; ============================================================================
;;; Mode Definition
;;; ============================================================================

;;;###autoload
(define-derived-mode new-mode prog-mode "New"
  "Major mode for editing new-mode files.

This mode provides:
- Syntax highlighting for keywords, types, and built-in functions
- Support for // and /* */ and @ comments
- String literals with \"\"
- Automatic indentation
- Bracket/parenthesis matching

\\{new-mode-map}

Customization:
  See `M-x customize-group RET new-mode RET` for available options.

Key variables:
  `new-mode-indent-offset'        - Indentation width (default: 2)
  `new-mode-comment-start'        - Comment start string (default: \"//\")
  `new-mode-enable-electric-pair' - Auto-close brackets (default: t)
  `new-mode-enable-auto-indent'   - Auto-indent on RET (default: t)"

  :syntax-table new-mode-syntax-table

  ;; -----------------------------------------------------------------
  ;; Comment settings
  ;; -----------------------------------------------------------------
  (setq-local comment-start new-mode-comment-start)
  (setq-local comment-end new-mode-comment-end)
  (setq-local comment-start-skip "\\(?://+\\|@\\)\\s-*")
  (setq-local comment-multi-line t)

  ;; For /* */ style comments
  (setq-local comment-use-syntax t)

  ;; -----------------------------------------------------------------
  ;; Syntax highlighting
  ;; -----------------------------------------------------------------
  (setq-local font-lock-defaults '(new-mode-font-lock-keywords))

  ;; -----------------------------------------------------------------
  ;; Indentation
  ;; -----------------------------------------------------------------
  (setq-local indent-line-function 'new-mode-indent-line)
  (setq-local tab-width new-mode-indent-offset)

  ;; -----------------------------------------------------------------
  ;; Electric pair mode (auto-close brackets)
  ;; -----------------------------------------------------------------
  (when new-mode-enable-electric-pair
    (electric-pair-local-mode 1))

  ;; -----------------------------------------------------------------
  ;; Additional features
  ;; -----------------------------------------------------------------
  ;; Enable syntax highlighting
  (font-lock-mode 1)

  ;; Show matching parentheses
  (setq-local show-paren-mode t))

;;; ============================================================================
;;; File Association
;;; ============================================================================

;;;###autoload
(add-to-list 'auto-mode-alist
             (cons new-mode-file-extension 'new-mode))

;;; ============================================================================
;;; Customization Variables Summary
;;; ============================================================================
;;
;; All customization variables available in this mode:
;;
;; Variable Name                      | Type    | Default | Description
;; -----------------------------------|---------|---------|---------------------------
;; new-mode-indent-offset             | integer | 2       | Spaces per indent level
;; new-mode-comment-start             | string  | "//"    | Comment start string
;; new-mode-comment-end               | string  | ""      | Comment end string
;; new-mode-file-extension            | string  | "\\.new\\'" | File extension pattern
;; new-mode-use-custom-faces          | boolean | nil     | Use custom faces
;; new-mode-enable-electric-pair      | boolean | t       | Auto-close brackets
;; new-mode-enable-auto-indent        | boolean | t       | Auto-indent on RET
;;
;; Keyword Lists (add/remove keywords to customize highlighting):
;;
;; new-mode-keywords-control          - Control flow (if, while, for, etc.)
;; new-mode-keywords-declaration      - Declarations (function, class, var, etc.)
;; new-mode-keywords-visibility       - Visibility (public, private, etc.)
;; new-mode-keywords-module           - Module system (import, export, etc.)
;; new-mode-keywords-exception        - Exceptions (try, catch, throw, etc.)
;; new-mode-keywords-other            - Other keywords (true, false, null, etc.)
;; new-mode-types                     - Type keywords (int, string, bool, etc.)
;; new-mode-builtins                  - Built-in functions (print, len, etc.)
;;
;; To customize interactively:
;;   M-x customize-group RET new-mode RET

;;; ============================================================================
;;; Usage Examples and Quick Start Guide
;;; ============================================================================

;; QUICK START:
;; 1. Load this file: (load "~/.emacs.d/inits/80_new-mode.el")
;; 2. Open a .new file or run: M-x new-mode
;;
;; CUSTOMIZATION EXAMPLES:
;;
;; 1. Change indentation to 4 spaces:
;;    (setq new-mode-indent-offset 4)
;;
;; 2. Use different comment style (e.g., Python-style):
;;    (setq new-mode-comment-start "#")
;;
;; 3. Add custom file extensions:
;;    (add-to-list 'auto-mode-alist '("\\.mynew\\'" . new-mode))
;;    (add-to-list 'auto-mode-alist '("\\.custom\\'" . new-mode))
;;
;; 4. Add mode hooks for automatic setup:
;;    (add-hook 'new-mode-hook
;;              (lambda ()
;;                (setq indent-tabs-mode nil)           ; Use spaces, not tabs
;;                (setq show-trailing-whitespace t)     ; Show trailing spaces
;;                (setq require-final-newline t)))      ; Add newline at EOF
;;
;; 5. Add custom keywords to highlight:
;;    (add-to-list 'new-mode-keywords-control "unless")
;;    (add-to-list 'new-mode-types "HashMap")
;;
;; 6. Customize syntax highlighting colors:
;;    (custom-set-faces
;;     '(font-lock-keyword-face ((t (:foreground "#569cd6" :weight bold))))
;;     '(font-lock-type-face ((t (:foreground "#4ec9b0"))))
;;     '(font-lock-function-name-face ((t (:foreground "#dcdcaa")))))
;;
;; 7. Add custom keybindings:
;;    (define-key new-mode-map (kbd "C-c C-c") 'compile)
;;    (define-key new-mode-map (kbd "C-c C-r") 'recompile)
;;
;; 8. Disable auto-features if needed:
;;    (setq new-mode-enable-electric-pair nil)
;;    (setq new-mode-enable-auto-indent nil)
;;
;; ADVANCED CUSTOMIZATION:
;;
;; To add custom syntax highlighting patterns:
;;    (add-to-list 'new-mode-font-lock-keywords
;;                 '("\\<TODO\\>" . font-lock-warning-face))
;;
;; To modify indentation rules:
;;    Edit the 'new-mode-indent-line' function (see line ~284)
;;
;; For more information:
;; - Customization UI: M-x customize-group RET new-mode RET
;; - Emacs Lisp manual: (info "(elisp) Major Modes")
;; - Font Lock manual: (info "(elisp) Font Lock Mode")

(provide 'new-mode)

;;; new-mode.el ends here
