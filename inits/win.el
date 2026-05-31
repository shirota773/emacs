(leaf *coding
  :config
  (prefer-coding-system 'utf-8-unix)
  (set-language-environment "Japanese")
  (setq default-buffer-file-coding-system 'utf-8-unix)
  (set-buffer-file-coding-system 'utf-8-unix)
  (set-terminal-coding-system 'utf-8-unix)
  (set-keyboard-coding-system 'utf-8-unix)
  (set-clipboard-coding-system 'utf-16le-dos)
  (set-selection-coding-system 'utf-16le-dos)
  (set-terminal-coding-system 'utf-8-unix)
  (set-frame-font "Ricty diminished-12" nil t)

  (defun my/has-crlf-p ()
    "Return non-nil when the current buffer contains CRLF line endings."
    (save-restriction
      (widen)
      (goto-char (point-min))
      (re-search-forward "\r$" nil t)))

  (defun my/warn-crlf-before-save ()
    "Warn when the current buffer still contains CRLF line endings."
    (when (and buffer-file-name (my/has-crlf-p))
      (display-warning
       'my/crlf
       (format "CRLF detected in %s; saving will normalize it to LF."
               (file-name-nondirectory buffer-file-name))
       :warning)))

  (defun my/force-unix-eol-on-save ()
    "Save visited files with LF line endings."
    (when buffer-file-name
      (let ((coding-system (or buffer-file-coding-system 'utf-8-unix)))
        (set-buffer-file-coding-system
         (coding-system-change-eol-conversion coding-system 'unix) t))))

  (defun my/strip-crlf-from-string (string)
    "Convert CRLF and lone CR characters in STRING to LF."
    (replace-regexp-in-string "\r\n?" "\n" string))

  (defun my/strip-crlf-in-yank (orig-fun &rest args)
    "Strip CR characters from pasted text before inserting it."
    (let ((first-arg (car args)))
      (if (stringp first-arg)
          (apply orig-fun
                 (cons (my/strip-crlf-from-string first-arg)
                       (cdr args)))
        (apply orig-fun args))))

  (advice-add 'insert-for-yank :around #'my/strip-crlf-in-yank)
  (add-hook 'before-save-hook #'my/warn-crlf-before-save)
  (add-hook 'before-save-hook #'my/force-unix-eol-on-save)
  )

(leaf *IME
  :config
  ;; IME
  (setq default-input-method "W32-IME")
  ;; (w32-ime-initialize)

  (advice-add 'ime-force-on
              :before (lambda (&rest args)
                        (set-cursor-color "blue")))
  (advice-add 'ime-force-off
              :before (lambda (&rest args)
                        (set-cursor-color "cyan")))
  (add-hook 'input-method-activate-hook
            (lambda() (set-cursor-color "blue")))
  (add-hook 'input-method-inactivate-hook
            (lambda() (set-cursor-color "cyan")))
  (setq w-32-ime-buffer-switch-p t)
  )

(leaf *SHELL
  ;; SHELL
  :config
  (setq shell-file-name "bash")
  (setenv "SHELL" shell-file-name)
  (setq explicit-shell-file-name shell-file-name)
)
