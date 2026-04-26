(require 'my-defuns)

(leaf *my-search
  :bind
  (("M-s s" . my/search-word-store)
   ("M-s r" . my/search-word-regex-store)
   ("C-S-s" . my/search-forward-stored-word)
   ("C-S-r" . my/search-forward-regex-stored)))

(bind-key (kbd "C-]") 'my/jump-brace)

(bind-key* (kbd "C-c C-r") 'revert-buffer-no-confirm)

(global-auto-revert-mode 1)

(global-set-key "\C-xb" 'switch-to-buffer-extension)

(provide '22_defun)
