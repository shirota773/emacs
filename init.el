(prog1 "prepare leaf"
  (prog1 "package"
    (custom-set-variables
     '(package-archives '(("org"   . "https://orgmode.org/elpa/")
                          ("melpa" . "https://melpa.org/packages/")
                          ("gnu"   . "https://elpa.gnu.org/packages/"))))
    (package-initialize))

  (prog1 "leaf"
    (unless (package-installed-p 'leaf)
      (unless (assoc 'leaf package-archive-contents)
        (package-refresh-contents))
      (condition-case err
          (package-install 'leaf)
        (error
         (package-refresh-contents)       ; renew local melpa cache if fail
         (package-install 'leaf))))

    (leaf leaf-keywords
      :ensure t
      :custom (leaf-keywords-packages-list
               . (remove 'key-combo leaf-keywords-packages-list))

      :config (leaf-keywords-init)
    )

  (prog1 "optional packages for leaf-keywords"
    ;; optional packages if you want to use :hydra, :el-get,,,
      (leaf hydra :ensure t)
      (leaf el-get :ensure t)
      (leaf blackout :ensure t)
      (leaf bind-key :ensure t)
      ;; (leaf key-combo :ensure t)
      )
  ))

(setq gc-cons-threshold (*   128 1024 1024))
(setq load-prefer-newer t)
(when (fboundp 'normal-top-level-add-subdirs-to-load-path)
  (cd "~/.emacs.d/site-lisp/")
  (normal-top-level-add-subdirs-to-load-path)
  (cd "~"))
;;Warning: `mapcar' called for effect; use `mapc' or `dolist' instead を防ぐ
(setq byte-compile-warnings
      '(free-vars unresolved
                  callargs
                  redefine
                  obsolete
                  noruntime
                  cl-functions
                  interactive-only
                  make-local))
(add-to-list 'load-path "~/.emacs.d/auto-install" t)
(add-to-list 'load-path "~/.emacs.d/my-utils" t)


;; theme
(leaf doom-themes
  :ensure t
  :custom-face
  (doom-modeline-bar . '((t (:background "#6272a4"))))
  (region . '((t (:background "gray25"))))
  (mode-line . '((t (:background "#483d8b" :foreground "yellow"))))
  (mode-line-inactive . '((t (:background "gray30" :foreground "gray70"))))
  (mode-line-buffer-id . '((t (:foreground "yellow"))))
  :config
  (load-theme 'doom-dracula t)
  (doom-themes-org-config)
  )

;; load inits files ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(leaf init-loader
  :ensure t
  :custom
  (init-loader--show-log-after-init . 'error-only)
  :config
  (init-loader-load "~/.emacs.d/inits")
  ;; local
  (let ((local-file (expand-file-name "~/.emacs.local-inits")))
    (when (file-exists-p local-file)
      (init-loader-load local-file)))
  )
;; finished inits files ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(add-hook 'input-method-activate-hook
          (lambda() (set-cursor-color "DarkOrange")))
(add-hook 'input-method-inactivate-hook
          (lambda() (set-cursor-color "cyan")))

;; フォントサイズの変更
;; (add-to-list default-frame-alist '(font . "Ricty diminished"))
;; (set-frame-font "Ricty diminished-12" nil t)
;; (set-face-attribute 'default nil :height 150)
(put 'erase-buffer 'disabled nil)

(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(setq custom-file "~/.emacs.d/custom-set-variables.el")

