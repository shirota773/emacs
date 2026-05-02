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
