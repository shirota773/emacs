(add-to-list 'load-path (expand-file-name "inits/my-utils" user-emacs-directory))
(require 'tabspace-util)

(leaf tab-bar
  :custom
  (tab-bar-auto-width-min . '((10) 2))
  (tab-bar-auto-width-max . '((100) 10))
  (tab-bar-auto-width . t)
  (tab-bar-show . 1)          ; tab-bar-mode より先に設定
  :custom-face
  (tab-bar . '((t (:inherit default))))
  (tab-bar-tab . '((t (:foreground "yellow" :weight bold :box nil))))
  (tab-bar-tab-inactive . '((t (:foreground "gray60" :box nil))))
  :config
  (tab-bar-mode 1))

(leaf tabspaces
  :ensure t
  :hook
  (after-init . tabspaces-mode)
  :custom
  (tabspaces-use-filtered-buffers-as-default . t) ; separate buffer respectively from tab
  (tabspaces-default-tab . "main")                ; default tab-name
  (tabspaces-remove-to-default . t)               ; return default-tab when close tab
  (tabspaces-session-auto-restore . t)            ; restoretabspace when rebooted
  (tabspaces-session . t)
  (tabspaces-session-include . '("main" "work" "org")) ; resotre tab(test)

  :bind
  (("C-f" . hydra-buffer-primary/body)
   ("C-j" . tabspaces-switch-to-buffer))

  :hydra (hydra-buffer-primary
          (:color blue :hint nil :exit nil)
          "
^buffer & tabspace^
[_h_]: prev-tab [_n_]: new-tab   [_L_]: move-tab-left  |
[_l_]: next-tab [_k_]: close-tab [_H_]: move-tab-right |
[_j_]: select-tab
----------------------------- -----------------------------------------
[_f_]:  switch-buffer          [_r_]: remove-buffer-current  | [_C-k_]:close-workspace
[_C-f_]:switch-buffer&tab      [_R_]: remove-buffer-selected | [_C-K_]:close-buffers&kill-buffers
[_s_]:  save-session           [_C-s_]: load-session         | [_d_]:delete-session
[_ws_]: save-layout            [_wl_]: load-layout           | [_wd_]:delete-layout

 "
          ("h" tab-bar-switch-to-prev-tab :exit nil)
          ("l" tab-bar-switch-to-next-tab :exit nil)
          ("H" tab-bar-move-tab-backward :exit nil)
          ("L" tab-bar-move-tab :exit nil)
          ("n" my/tab-bar-new-tab-with-name)
          ("k" tab-bar-close-tab)
          ("f" tabspaces-switch-to-buffer)
          ("C-f" tabspaces-switch-buffer-and-tab)
          ("r" tabspaces-remove-current-buffer)
          ("R" tabspaces-remove-selected-buffer)
          ("C-k" tabspaces-close-workspace)
          ("C-K" tabspaces-kill-buffers-close-workspace)
          ("j" tab-bar-select-tab-by-name)
          ("s" my/tabspace-save-tab-session)
          ("C-s" my/tabspace-load-tab-session)
          ("d" my/tabspace-delete-tab-session)
          ("ws" my/tabspace-save-layout)
          ("wl" my/tabspace-load-layout)
          ("wd" my/tabspace-delete-layout)
          ("q" nil "exit"))
  :config
  (advice-add 'project-switch-project :around #'my/project-switch-advice)
  (add-hook 'tab-bar-tab-pre-change-functions #'my/winner-save-for-tab)
  (add-hook 'tab-bar-tab-post-change-functions #'my/winner-restore-for-tab))

(leaf consult
  :after tabspaces
  :bind
  ("C-c t" . consult-tabspaces-switch))

(provide '04_tabspace)
