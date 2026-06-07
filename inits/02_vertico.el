;; -*- lexical-binding: t; -*-

(require 'navigation-util)
(require 'window-util)

(file-name-shadow-mode 1)

;; =============================================================================
;; 1. Global Keybindings
;; =============================================================================
;; C-s は下の leaf swiper、M-x は既定 (execute-extended-command) のため省略
(global-set-key (kbd "C-r") #'my/tabspaces-switch-or-recentf)
(global-set-key (kbd "M-s g") 'consult-grep)
(global-set-key (kbd "M-s r") 'consult-ripgrep)
(global-set-key (kbd "M-s i") 'consult-imenu)
(global-set-key (kbd "M-o") 'embark-act)

;; Swiper (Minimal config)
(leaf swiper
  :ensure t
  :bind (("C-s" . swiper))
  :custom
  (ivy-count-format . "%d/%d ")
  (ivy-height . 15)
  (ivy-wrap . t))

;; =============================================================================
;; 2. Vertico & Related Packages
;; =============================================================================

(leaf vertico
  :ensure t
  :hook ((after-init-hook . vertico-mode)
         (rfn-eshadow-update-overlay-hook . vertico-directory-tidy))
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
   ("C-j" . vertico-exit-input)
   ("DEL" . vertico-directory-delete-char)
   ("<backspace>" . vertico-directory-delete-char)
   ("M-DEL" . vertico-directory-delete-word)
   ("M-<backspace>" . vertico-directory-delete-word)
   ("M-h" . vertico-directory-up)))

(leaf marginalia
  :ensure t
  :hook (after-init-hook . marginalia-mode))

(leaf consult
  :ensure t
  :bind (("M-y" . consult-yank-pop)
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
