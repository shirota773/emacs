;;; 04_tabspace.el --- tab-bar / bufferlo 設定 -*- lexical-binding: t; -*-
;; タブローカルなバッファリストとタブ bookmark (セッション/レイアウト) は
;; bufferlo に任せる。旧 tabspaces + 自作セッション/レイアウト/winner 同期
;; (tabspace-util.el) からの移行 (2026-07-23)。
;;   - セッション/レイアウト = タブ bookmark。レイアウトは
;;     「タブ名/レイアウト名」の別名保存で表現する
;;   - タブ内のウィンドウ履歴は tab-bar-history-mode (標準)
(require 'tab-dir-util)
(require 'tab-bookmark-util)

(leaf tab-bar
  :init
  ;; 値の形式は Emacs 29 が (PIXELS COLUMNS)、30+ が ((PIXELS) COLUMNS)。
  ;; 形式を誤ると redisplay 中の幅計算が黙って失敗し、tab-bar-lines が 0 に
  ;; 戻されてタブバーが一切表示されなくなる (macOS で長年の非表示の真因)。
  ;; leaf の :custom は値の式を評価できないため setq で分岐する。
  (setq tab-bar-auto-width-min (if (>= emacs-major-version 30) '((10) 2) '(10 2)))
  (setq tab-bar-auto-width-max (if (>= emacs-major-version 30) '((100) 10) '(100 10)))
  :custom
  (tab-bar-auto-width . t)
  ;; 1 (2タブ以上で表示) は復元経路で tab-bar-lines の再計算が漏れると
  ;; 非表示のままになる (emacs-mac で確認済み)。常時表示に固定する。
  (tab-bar-show . t)
  :custom-face
  (tab-bar . '((t (:inherit default))))
  (tab-bar-tab . '((t (:foreground "yellow" :weight bold :box nil))))
  (tab-bar-tab-inactive . '((t (:foreground "gray60" :box nil))))
  :bind
  ("C-c t" . tab-bar-switch-to-tab)
  :config
  (tab-bar-mode 1)
  ;; タブごとのウィンドウ構成履歴 (自作 winner 同期の後継)
  (tab-bar-history-mode 1))

(leaf bufferlo
  :ensure t
  ;; 起動時復元フックは init 読み込み中 (after-init-time が nil のうち) に
  ;; bufferlo-mode を有効化した場合しか登録されないため、遅延せず即ロードする
  :require t
  :preface
  (defun my/tab-bar-new-tab-with-name ()
    "Create new-tab with input from minibuffer."
    (interactive)
    (let ((tab-name (read-string "New tab name: ")))
      (tab-bar-new-tab-to -1)
      (tab-bar-rename-tab tab-name))
    (ibuffer)
    (bufferlo-clear))
  (defun my/project-switch-advice (orig-fn &rest args)
    "Create project automatically after new tab created."
    (let* ((project-dir (car args))
           (project-name (file-name-nondirectory (directory-file-name project-dir))))
      (tab-bar-new-tab)
      (tab-bar-rename-tab project-name)
      (apply orig-fn args)))
  (defun my/bufferlo-remove-current-buffer ()
    "現在のバッファをこのタブのローカルリストから外す。"
    (interactive)
    (bufferlo-remove (current-buffer)))
  :custom
  (bufferlo-prefer-local-buffers . t)
  ;; タブ bookmark の自動保存・復元
  (bufferlo-bookmarks-load-at-emacs-startup . 'all)
  (bufferlo-bookmarks-save-at-emacs-exit . 'all)
  (bufferlo-bookmarks-auto-save-interval . 600)
  (bufferlo-bookmark-tab-save-on-close . 'when-bookmarked)
  :bind
  (("C-f" . hydra-buffer-primary/body)
   ("C-j" . bufferlo-switch-to-buffer))
  :hydra (hydra-buffer-primary
          (:color blue :hint nil :exit nil)
          "
^buffer & tab (bufferlo)^
[_h_]: prev-tab [_n_]: new-tab   [_L_]: move-tab-left  |
[_l_]: next-tab [_k_]: close-tab [_H_]: move-tab-right |
[_j_]: select-tab
-----------------------------------------------------------------------------
[_f_]:  switch-buffer      [_r_]: remove-buffer-current  | [_C-K_]: close-tab&kill-buffers
[_C-f_]:find-buffer&tab    [_R_]: remove-buffer-selected | [_i_]:   isolate-project
[_s_]:  save-tab-bookmark  [_C-s_]: load-tab-bookmark    | [_d_]:   delete-bookmark
[_S_]:  save-all-active    [_B_]: local-ibuffer          |
-----------------------------------------------------------------------------
[_pr_]: set-proc-root  [_pa_]: add-dir  [_pc_]: add-current  [_pD_]: remove-dir  [_pj_]: jump-dir
[_bm_]: bookmark-set   [_bj_]: bookmark-jump(tab)  [_bl_]: bookmark-jump(layout)
layout = タブ bookmark の別名保存 (命名: タブ名/レイアウト名)

 "
          ("h" tab-bar-switch-to-prev-tab :exit nil)
          ("l" tab-bar-switch-to-next-tab :exit nil)
          ("H" tab-bar-move-tab-backward :exit nil)
          ("L" tab-bar-move-tab :exit nil)
          ("n" my/tab-bar-new-tab-with-name)
          ("k" tab-bar-close-tab)
          ("j" tab-bar-select-tab-by-name)
          ("f" bufferlo-switch-to-buffer)
          ("C-f" bufferlo-find-buffer-switch)
          ("r" my/bufferlo-remove-current-buffer)
          ("R" bufferlo-remove)
          ("C-K" bufferlo-tab-close-kill-buffers)
          ("s" bufferlo-bookmark-tab-save)
          ("C-s" bufferlo-bookmark-tab-load)
          ("d" bookmark-delete)
          ("S" bufferlo-bookmarks-save)
          ("B" bufferlo-ibuffer)
          ("i" bufferlo-isolate-project)
          ("pr" my/tab-dir-set-process-root)
          ("pa" my/tab-dir-add-dir)
          ("pc" my/tab-dir-add-current)
          ("pD" my/tab-dir-remove)
          ("pj" my/tab-dir-jump)
          ("bm" bookmark-set)
          ("bj" my/bookmark-jump-local)
          ("bl" my/bookmark-jump-layout)
          ("q" nil "exit"))
  :config
  (bufferlo-mode 1)
  (advice-add 'project-switch-project :around #'my/project-switch-advice))

;; consult-buffer (C-;) の先頭にタブローカルバッファのソースを足す
(with-eval-after-load 'consult
  (defvar my/consult--source-local-buffers
    `(:name "Local Buffers"
      :narrow ?l
      :category buffer
      :face consult-buffer
      :history buffer-name-history
      :state ,#'consult--buffer-state
      :default t
      :items ,(lambda ()
                (consult--buffer-query :predicate #'bufferlo-local-buffer-p
                                       :sort 'visibility
                                       :as #'buffer-name)))
    "現タブの bufferlo ローカルバッファを返す consult ソース。")
  (add-to-list 'consult-buffer-sources 'my/consult--source-local-buffers))

(provide '04_tabspace)
