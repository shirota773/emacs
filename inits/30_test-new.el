;;; 30_test-new.el --- 試用中: 不足していた設定のテスト -*- lexical-binding: t; -*-

;;; Commentary:
;; レビューで「不足」と判断した設定の試用ファイル。
;; セクション単位で動作確認し、定着したら適切な NN_name.el へ移す。
;; 合わなければセクションごと削除する。
;;
;;   1. exec-path-from-shell — GUI Emacs の PATH を shell (fish) と一致させる
;;   2. (欠番) TRAMP チューニング — 定着したので 32_tramp.el へ分離 (2026-07-28)
;;   3. popper               — ポップアップ系バッファの window 制御
;;   4. treesit / eglot      — tree-sitter ハイライトと LSP
;;   5. diff-hl              — バッファ左端に git の変更表示
;;   6. go-translate         — text-translator の後継 (翻訳)
;;   7. カーソル位置の履歴    — mark-ring を遡る (2026-09-13 試用開始)
;;
;; 番号を詰めないのは inits/README.md と review-notes.md がこの番号で
;; 各セクションを参照しているため。

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

;; ★ treesit-auto-install を 'prompt にしない (2026-07-27)
;;   'prompt にしていると、grammar の無い言語のファイルを開くたびに
;;   "Tree-sitter grammar for X is missing. Install it?" が出る。y を押すと
;;   git clone + コンパイルが同期で走って Emacs が数十秒止まり、そのうえ
;;   macOS では最後に必ず警告が出て失敗する。原因はアーキテクチャの不一致:
;;
;;     Emacs.app             … x86_64 (Apple Silicon 上で Rosetta 実行)
;;     生成される grammar    … arm64 (spawn された /usr/bin/cc がネイティブで動くため)
;;
;;   dlopen で直接確認済み (2026-07-27):
;;     "mach-o file, but is an incompatible architecture (have 'arm64',
;;      need 'x86_64')"
;;   x86_64 プロセスからは開けず、arm64 プロセスからは開ける。
;;   つまり **今の Emacs では何度入れ直しても grammar は絶対に読めない**。
;;   eat のフリーズ (31_terminal.el) と同じ Rosetta 由来の問題で、
;;   根治は arm64 ネイティブ Emacs への移行 (review-notes.md 7-7 参照)。
;;
;;   そこで自動インストールは切る (nil = 提案もしない)。treesit-auto は
;;   grammar が無い言語では黙って元のモード (sh-mode 等) のままにするので、
;;   実害はプロンプトが出なくなることだけ。arm64 Emacs に移ったあと、
;;   あるいは grammar が読める環境では M-x treesit-auto-install-all で
;;   明示的にまとめて入れる。
(leaf treesit-auto
  :ensure t
  ;; 現行版のautoloadには `global-treesit-auto-mode' のautoload定義が
  ;; 含まれないため、modeを有効化する前に本体を明示ロードする。
  :require t
  :config
  (setq treesit-auto-install nil)
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

;; =============================================================================
;; 7. カーソル位置の履歴 (試用 2026-09-13)
;; 「さっき居た場所に戻る」手段が pop-global-mark (C-x C-SPC) しか無かった。
;; しかも C-SPC は 05_editing.el で my/puni-region-selection-start に割り当たって
;; おり prefix を見ないため、標準の C-u C-SPC (ローカル mark を遡る) が使えない。
;;
;; 新しいパッケージは入れず、まず組み込みの mark-ring + consult で足りるか試す。
;; キーはマウス経路の無い操作なので左手側の M-g (goto-map) 配下に置く。
;; m/k/b は goto-map で空いている (r w l i g c p n TAB は使用済み)。
;;
;; **限界**: mark-ring に積まれるのはジャンプ系の操作 (isearch / avy / consult-line /
;; goto-line / beginning-of-buffer など) だけで、普通のカーソル移動は積まれない。
;; 「移動した場所を全部たどる」感覚が要るなら dogears や better-jumper が要る。
;; =============================================================================

(defun my/pop-mark-back ()
  "直前のマーク位置へ戻る。連続して押すとさらに遡る (repeat-mode)。"
  (interactive)
  (set-mark-command '(4)))

(defvar-keymap my/pop-mark-repeat-map
  :doc "`my/pop-mark-back' を b の連打で繰り返すための repeat-map。"
  :repeat t
  "b" #'my/pop-mark-back)

(bind-keys :map goto-map
           ("b" . my/pop-mark-back)      ; 直前の位置へ戻る (b 連打で遡る)
           ("m" . consult-mark)          ; このバッファのマーク履歴を一覧
           ("k" . consult-global-mark))  ; バッファをまたいだマーク履歴を一覧

(provide '30_test-new)
;;; 30_test-new.el ends here
