;;; 30_test-new.el --- 試用中: 不足していた設定のテスト -*- lexical-binding: t; -*-*-

;;; Commentary:
;; レビューで「不足」と判断した設定の試用ファイル。
;; セクション単位で動作確認し、定着したら適切な NN_name.el へ移す。
;; 合わなければセクションごと削除する。
;;
;;   1. exec-path-from-shell — GUI Emacs の PATH を shell (fish) と一致させる
;;   2. TRAMP チューニング   — リモート編集の高速化と終了時ハング対策
;;   3. popper               — ポップアップ系バッファの window 制御
;;   4. treesit / eglot      — tree-sitter ハイライトと LSP
;;   5. diff-hl              — バッファ左端に git の変更表示
;;   6. go-translate         — text-translator の後継 (翻訳)

;;; Code:

;; =============================================================================
;; 1. exec-path-from-shell (macOS)
;; Dock から起動した GUI Emacs は PATH が最小構成になり、
;; git / rg / LSP サーバーの解決が shell と食い違うのを防ぐ。
;; =============================================================================

(leaf exec-path-from-shell
  :ensure t
  :when darwin-p
  :custom
  (exec-path-from-shell-variables . '("PATH" "MANPATH" "LANG"))
  :config
  (exec-path-from-shell-initialize))

;; =============================================================================
;; 2. TRAMP チューニング
;; さらに速くしたい場合は ~/.ssh/config に以下を追加 (接続の再利用):
;;   Host *
;;     ControlMaster auto
;;     ControlPath ~/.ssh/cm-%r@%h:%p
;;     ControlPersist 10m
;; =============================================================================

(leaf tramp
  :tag "builtin"
  :config
  (setq tramp-verbose 1)                       ; ログを抑制 (デバッグ時は 6)
  (setq remote-file-name-inhibit-locks t)      ; リモートに .#lock を作らない
  ;; ~/.ssh/config の ControlMaster 設定をそのまま使う
  (setq tramp-use-ssh-controlmaster-options nil)
  ;; vc (vc-git) がリモートで git を走らせて固まるのを防ぐ。git 操作は magit で行う
  (setq vc-ignore-dir-regexp
        (format "%s\\|%s" vc-ignore-dir-regexp tramp-file-name-regexp)))

;; recentf: リモートエントリは stat せず保持する (終了時ハング対策)
(setq recentf-keep '(file-remote-p file-readable-p))

;; save-place: 終了時に全ファイルの可読性チェックをしない (リモートで固まる)
(setq save-place-forget-unreadable-files nil)

;; whitespace の保存時自動クリーンアップはリモート/共有ファイルでは
;; diff を汚す事故になるため、リモートバッファでは無効化する
(defun my/whitespace-disable-cleanup-on-remote ()
  "リモートファイルでは `whitespace-action' の auto-cleanup を無効にする。"
  (when (file-remote-p default-directory)
    (setq-local whitespace-action nil)))
(add-hook 'find-file-hook #'my/whitespace-disable-cleanup-on-remote)

;; =============================================================================
;; 3. popper — ポップアップ系バッファを下部に集約し、1キーでトグル/巡回
;;   C-`   : ポップアップの表示/非表示
;;   M-`   : 複数ポップアップの巡回
;;   C-M-` : 現在のバッファをポップアップ扱いにする/外す
;; =============================================================================

(leaf popper
  :ensure t
  :bind (("C-`" . popper-toggle)
         ("M-`" . popper-cycle)
         ("C-M-`" . popper-toggle-type))
  :custom
  (popper-reference-buffers . '("\\*Messages\\*"
                                "\\*Warnings\\*"
                                "\\*Backtrace\\*"
                                "Output\\*$"
                                "\\*Async Shell Command\\*"
                                help-mode
                                helpful-mode
                                compilation-mode
                                grep-mode
                                occur-mode
                                "^\\*eshell.*\\*$" eshell-mode
                                "^\\*shell.*\\*$" shell-mode))
  (popper-window-height . 0.35)
  :config
  (popper-mode 1)
  (popper-echo-mode 1))                 ; 非表示ポップアップをエコーエリアに表示

;; 新しいバッファ表示の基本ルール
;; switch-to-buffer 系も display-buffer-alist のルールに従わせる
(setq switch-to-buffer-obey-display-actions t)
;; 既に同じバッファを表示している window があればそれを再利用する
(setq display-buffer-base-action
      '((display-buffer-reuse-window display-buffer-same-window)))

;; =============================================================================
;; 4. tree-sitter + eglot (どちらも Emacs 29+ 組み込み)
;; treesit-auto: 対応言語の major-mode を自動で *-ts-mode に読み替え、
;; 文法 (grammar) が無ければインストールを提案する。
;; eglot: LSP クライアント。サーバーは別途インストールが必要:
;;   python: pip install pyright  /  typescript: npm i -g typescript-language-server
;; =============================================================================

(leaf treesit-auto
  :ensure t
  ;; 現行版のautoloadには `global-treesit-auto-mode' のautoload定義が
  ;; 含まれないため、modeを有効化する前に本体を明示ロードする。
  :require t
  :custom
  (treesit-auto-install . 'prompt)      ; grammar が無いときに確認してインストール
  :config
  (global-treesit-auto-mode))

(leaf eglot
  :tag "builtin"
  :hook ((python-mode-hook
          python-ts-mode-hook
          js-mode-hook
          js-ts-mode-hook
          typescript-ts-mode-hook) . eglot-ensure)
  :custom
  (eglot-autoshutdown . t)              ; 最後のバッファを閉じたらサーバー停止
  :bind ((:eglot-mode-map
          ("C-c l r" . eglot-rename)
          ("C-c l a" . eglot-code-actions)
          ("C-c l f" . eglot-format))))

;; =============================================================================
;; 5. diff-hl — バッファ左端 (fringe) に git の追加/変更/削除を表示
;; magit と連動して commit/stage 後に即更新される
;; =============================================================================

(leaf diff-hl
  :ensure t
  :hook ((magit-pre-refresh-hook . diff-hl-magit-pre-refresh)
         (magit-post-refresh-hook . diff-hl-magit-post-refresh)
         (dired-mode-hook . diff-hl-dired-mode))
  :config
  (global-diff-hl-mode 1)
  ;; 保存を待たず編集中に反映
  (diff-hl-flydiff-mode 1))

;; =============================================================================
;; 6. gt (旧 go-translate) — text-translator の後継 (メンテナンス継続中)
;; C-x M-t : region または単語を翻訳 (en <-> ja 自動判定)
;; =============================================================================

(leaf gt
  :ensure t
  :bind ("C-x M-t" . gt-do-translate)
  :config
  (setq gt-langs '(en ja))
  (setq gt-default-translator
        (gt-translator :engines (gt-google-engine)
                       :render (gt-buffer-render))))

(provide '30_test-new)
;;; 30_test-new.el ends here
