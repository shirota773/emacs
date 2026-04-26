;; -*- lexical-binding: t; -*-

(require 'navigation-util)
(require 'window-util)

;; =============================================================================
;; 1. Global Keybindings
;; =============================================================================
(global-set-key (kbd "C-r") #'my/tabspaces-switch-or-recentf)
(global-set-key (kbd "C-s") 'consult-line)
(global-set-key (kbd "M-s g") 'consult-grep)
(global-set-key (kbd "M-s r") 'consult-ripgrep)
(global-set-key (kbd "M-x") 'execute-extended-command)
(global-set-key (kbd "M-o") 'embark-act)

;; =============================================================================
;; 2. Vertico & Related Packages
;; =============================================================================

(leaf vertico
  :ensure t
  :hook (after-init-hook . vertico-mode)
  :custom
  (vertico-count . 20)
  (vertico-cycle . t)
  :config
  (require 'vertico-directory)
  :bind
  (:vertico-map
   ("C-r" . my/tabspaces-switch-or-recentf)
   ("C-t" . my/vertico-select-directory-from-candidates)
   ("RET" . vertico-directory-enter)
   ("DEL" . vertico-directory-delete-char)
   ("M-DEL" . vertico-directory-delete-word)))

(leaf marginalia
  :ensure t
  :hook (after-init-hook . marginalia-mode))

(leaf consult
  :ensure t
  :bind (("C-s" . consult-line)
         ("M-y" . consult-yank-pop)
         ("C-;" . consult-buffer)))

(leaf embark
  :ensure t
  :bind (("C-." . embark-act)
         ("M-." . embark-dwim)
         ("C-h B" . embark-bindings))
  :config
  (add-to-list 'display-buffer-alist
               '("\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 (display-buffer-in-side-window)
                 (side . right)
                 (window-width . 0.3))))

(leaf embark-consult
  :ensure t
  :after (embark consult)
  :hook (embark-collect-mode-hook . embark-consult-preview-minor-mode))

(with-eval-after-load 'embark
  (define-key embark-file-map (kbd "d") (lambda (f) (interactive "f") (find-file (file-name-directory f))))
  (define-key embark-buffer-map (kbd "d") (lambda (b) (interactive "b") 
                                           (let ((f (buffer-file-name (get-buffer b))))
                                             (if f (find-file (file-name-directory f)) (message "No file"))))))

(provide '02_vertico)
