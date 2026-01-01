;;; new-mode.el --- A new major mode with syntax highlighting and indentation

;; Author: Your Name
;; Version: 0.1.0
;; Keywords: languages

;;; Commentary:
;; A basic major mode demonstrating:
;; - Syntax highlighting for keywords
;; - String literals ("")
;; - Comments (// and /* */ and @)
;; - Parentheses and braces matching
;; - Automatic indentation

;;; Code:

(require 'prog-mode)

;;; Customization

(defgroup new-mode nil
  "Major mode for editing new-mode files."
  :group 'languages)

(defcustom new-mode-indent-offset 2
  "Number of spaces for each indentation level."
  :type 'integer
  :safe 'integerp
  :group 'new-mode)

;;; Syntax Table

(defvar new-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; C-style // comments
    (modify-syntax-entry ?/ ". 12" table)
    (modify-syntax-entry ?\n ">" table)

    ;; @ comments (like // comments)
    (modify-syntax-entry ?@ "< " table)

    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)

    ;; Parentheses and braces
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)

    ;; Operators and symbols
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)

    table)
  "Syntax table for `new-mode'.")

;;; Font Lock (Syntax Highlighting)

(defconst new-mode-keywords
  '("if" "else" "while" "for" "do" "switch" "case" "default"
    "break" "continue" "return" "goto"
    "function" "def" "class" "struct" "interface"
    "var" "let" "const" "static" "final"
    "public" "private" "protected"
    "import" "export" "package" "namespace"
    "try" "catch" "finally" "throw"
    "new" "delete" "this" "super"
    "true" "false" "null" "nil" "undefined")
  "Keywords for `new-mode'.")

(defconst new-mode-types
  '("int" "float" "double" "char" "string" "bool" "void"
    "byte" "short" "long" "array" "list" "map" "set")
  "Type keywords for `new-mode'.")

(defvar new-mode-font-lock-keywords
  `(
    ;; Comments (/* ... */)
    ("/\\*\\([^*]\\|\\*[^/]\\)*\\*/" . font-lock-comment-face)

    ;; Keywords
    (,(regexp-opt new-mode-keywords 'words) . font-lock-keyword-face)

    ;; Type keywords
    (,(regexp-opt new-mode-types 'words) . font-lock-type-face)

    ;; Function calls: word followed by (
    ("\\<\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*(" 1 font-lock-function-name-face)

    ;; Constants (all caps identifiers)
    ("\\<[A-Z_][A-Z0-9_]+\\>" . font-lock-constant-face)

    ;; Numbers
    ("\\<[0-9]+\\(\\.[0-9]+\\)?\\>" . font-lock-constant-face)

    ;; Variables (simple heuristic)
    ("\\<[a-z_][a-zA-Z0-9_]*\\>" . font-lock-variable-name-face))
  "Font lock keywords for `new-mode'.")

;;; Indentation

(defun new-mode-indent-line ()
  "Indent current line for `new-mode'."
  (interactive)
  (let ((indent-col 0)
        (current-indent (current-indentation))
        (point-offset (- (current-column) current-indent)))
    (save-excursion
      (beginning-of-line)
      (if (bobp)
          (setq indent-col 0)
        (let ((not-indented t)
              cur-line)
          ;; Check current line for closing brackets
          (setq cur-line (buffer-substring-no-properties
                          (line-beginning-position)
                          (line-end-position)))

          (cond
           ;; If current line starts with } or ), decrease indent
           ((string-match "^\\s-*[)}]" cur-line)
            (save-excursion
              (forward-line -1)
              (setq indent-col (- (current-indentation) new-mode-indent-offset))
              (when (< indent-col 0)
                (setq indent-col 0))))

           ;; Otherwise, calculate based on previous lines
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
                     ;; Previous line ends with { or (, increase indent
                     ((string-match "[({]\\s-*$" prev-line)
                      (setq indent-col (+ (current-indentation) new-mode-indent-offset))
                      (setq not-indented nil))

                     ;; Previous line starts with }, use its indentation
                     ((string-match "^\\s-*[)}]" prev-line)
                      (setq indent-col (current-indentation))
                      (setq not-indented nil))

                     ;; If statement without braces, increase indent for next line
                     ((string-match "\\<if\\>.*[^{]\\s-*$" prev-line)
                      (setq indent-col (+ (current-indentation) new-mode-indent-offset))
                      (setq not-indented nil))

                     ;; Empty line, keep searching
                     ((string-match "^\\s-*$" prev-line)
                      t)

                     ;; Default: use same indentation as previous line
                     (t
                      (setq indent-col (current-indentation))
                      (setq not-indented nil)))))))))))))

    ;; Apply the indentation
    (indent-line-to indent-col)

    ;; Restore point position
    (when (> point-offset 0)
      (forward-char point-offset))))

;;; Mode Definition

(defvar new-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'newline-and-indent)
    map)
  "Keymap for `new-mode'.")

;;;###autoload
(define-derived-mode new-mode prog-mode "New"
  "Major mode for editing new-mode files.

Key bindings:
\\{new-mode-map}"
  :syntax-table new-mode-syntax-table

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?://+\\|@\\)\\s-*")
  (setq-local comment-multi-line t)

  ;; Font lock
  (setq-local font-lock-defaults '(new-mode-font-lock-keywords))

  ;; Indentation
  (setq-local indent-line-function 'new-mode-indent-line)

  ;; Automatically insert closing brackets
  (setq-local electric-pair-mode t)

  ;; Enable syntax highlighting
  (font-lock-mode 1))

;;; File Association

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.new\\'" . new-mode))

(provide 'new-mode)

;;; new-mode.el ends here
