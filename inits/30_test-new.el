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
  ;; ~/.ssh/config の ControlMaster 設定をそのまま使う。
  ;; Emacs 30.1 で tramp-use-ssh-controlmaster-options は obsolete になり
  ;; tramp-use-connection-share にリネームされた (tramp-sh.el:105-106)。
  ;; 後継の既定値は (not (eq system-type 'windows-nt)) (tramp-sh.el:108) なので
  ;; Windows では元から nil。macOS では t なので、ここで nil にする意味がある。
  ;; tramp-sh.el のロード前に setq しても defcustom は既存値を上書きしない。
  (setq tramp-use-connection-share nil)
  ;; vc (vc-git) がリモートで git を走らせて固まるのを防ぐ。git 操作は magit で行う
  (setq vc-ignore-dir-regexp
        (format "%s\\|%s" vc-ignore-dir-regexp tramp-file-name-regexp)))

;; -----------------------------------------------------------------------------
;; 2-1. Windows のみ: ホスト単位の ssh ハング回避
;;
;; 症状: native Windows Emacs で C-x C-f /ssh:user@host:/ がエラーも出さず無限ハング。
;;
;; 原因A: pty が無い。
;;   native Windows Emacs は子プロセスに pty を渡せず start-process は必ずパイプ。
;;   ssh は stdin が tty でないとリモート側の pty を確保しないため、リモートシェルが
;;   プロンプトを 1 バイトも出さない。TRAMP は tramp-actions-before-shell
;;   (tramp-sh.el:596) のプロンプト正規表現マッチを永久に待ち続ける。
;;   → ssh の login-args に -t -t を足して pty を強制する。
;;
;; 原因B: プロンプトが解析不能。
;;   192.168.0.10 は macOS でログインシェルが /usr/local/bin/fish。greeting +
;;   OSC 7 + OSC 133 セマンティックプロンプトマーカー + 24bit カラー + ❯ を出し、
;;   これらは tramp-shell-prompt-pattern の許容文字集合外。-t -t で pty を強制しても
;;   検出できず 100 秒でタイムアウトする。
;;   → login-args の末尾に /bin/sh -i を足して fish 自体を迂回する。
;;
;; なぜグローバルに適用しないか:
;;   仕事で常用している Windows -> Linux の TRAMP 接続はこの環境から疎通テストできない。
;;   -t -t を全ホストに当てるとリモート bash が完全な対話シェルになり .bashrc を読む。
;;   色付き・多行プロンプトの Linux ホストでは、今動いている接続を壊す恐れがある。
;;   よって tramp-methods (ssh / scp の method 定義) は一切書き換えず、
;;   tramp-connection-properties で該当ホストの vec にだけ "login-args" を上書きする。
;;   tramp-get-method-parameter (tramp.el:1600-1607) は tramp-methods より先に
;;   connection property を見る実装なので、これで method 定義を汚さずに済む。
;;   下のリストに載っていないホストの挙動は素の TRAMP と 1 バイトも変わらない。
;;
;; 新しいホストで同じ症状が出たときの追加方法:
;;   原因A だけ (pty が無いだけ) なら my/tramp-windows-force-pty-hosts に
;;   ホスト名の正規表現を 1 行足す。
;;   さらに原因B (fish / 凝った zsh theme などプロンプトが解析不能) なら
;;   my/tramp-windows-login-shell-hosts に (正規表現 . "/bin/sh") を足す。
;;   原因A と原因B は別問題なので、必要な方だけを足せばよい。
;;
;;   ハマりどころ: リストを編集したら M-x tramp-cleanup-all-connections が必須。
;;   tramp-dump-connection-properties (tramp-cache.el:551-583) は "login-args" を
;;   var/tramp/persistency.el に永続化する。一方 tramp-get-hash-table
;;   (tramp-cache.el:131-141) が tramp-connection-properties から seed するのは
;;   そのホストのハッシュテーブルを新規作成するときだけ。よって永続化キャッシュに
;;   古い login-args が残っていると、リストを直しても古い値が勝ち続ける。
;;   何も知らずに踏むと「設定したのに直らない」原因不明のハングに逆戻りする。
;;   cleanup で tramp-cache-data を空にしてから繋ぎ直すこと。
;;   それでも直らないときは var/tramp/persistency.el を直接消す。
;; -----------------------------------------------------------------------------

(defcustom my/tramp-windows-force-pty-hosts '("192\\.168\\.0\\.10")
  "ssh に -t -t (pty 強制) を付けるホスト名の正規表現リスト。
Windows の Emacs から接続したときだけ適用される。原因A への対処。
編集したら M-x tramp-cleanup-all-connections を実行すること。
永続化キャッシュ (var/tramp/persistency.el) に残った古い login-args が
優先され、直したはずの設定が効かないため。"
  :type '(repeat regexp)
  :group 'tramp)

(defcustom my/tramp-windows-login-shell-hosts '(("192\\.168\\.0\\.10" . "/bin/sh"))
  "ログインシェルを迂回するホストの alist。原因B への対処。
CAR はホスト名の正規表現、CDR はリモート上の POSIX シェルの絶対パス。
ssh のリモートコマンドとして SHELL -i を渡し、プロンプトが解析不能な
ログインシェル (fish など) を経由しないようにする。
Windows の Emacs から接続したときだけ適用される。
編集したら M-x tramp-cleanup-all-connections を実行すること。
永続化キャッシュ (var/tramp/persistency.el) に残った古い login-args が
優先され、直したはずの設定が効かないため。"
  :type '(alist :key-type regexp :value-type string)
  :group 'tramp)

(defvar my/tramp-windows-workaround-methods '("ssh" "scp")
  "ホスト単位ワークアラウンドを適用する TRAMP method 名のリスト。")

(defun my/tramp--login-args-force-pty (args)
  "ARGS の \"%h\" の直前に (\"-t\") (\"-t\") を挿入した新しいリストを返す。
ARGS は `tramp-login-args' と同じ形式。既に -t を含むときはそのまま返す。"
  (if (seq-find (lambda (a) (member "-t" a)) args)
      args
    (let ((acc nil) (inserted nil))
      (dolist (a args)
        (when (and (not inserted) (member "%h" a))
          (setq inserted t)
          (push (list "-t") acc)
          (push (list "-t") acc))
        (push a acc))
      ;; "%h" が無い method 形式のときは末尾に付ける
      (unless inserted
        (push (list "-t") acc)
        (push (list "-t") acc))
      (nreverse acc))))

(defun my/tramp--login-args-append-shell (args shell)
  "ARGS の末尾に (SHELL) (\"-i\") を足した新しいリストを返す。"
  (append args (list (list shell) (list "-i"))))

(defun my/tramp-apply-windows-host-workarounds ()
  "ホスト単位の login-args 上書きを `tramp-connection-properties' に登録する。
`tramp-methods' は変更しない。login-args の値はハードコードせず
`tramp-methods' の現在値から加工するので、TRAMP の版が上がって既定の
login-args が変わっても設定が腐らない。"
  (let ((hosts (delete-dups
                (append (copy-sequence my/tramp-windows-force-pty-hosts)
                        (mapcar #'car my/tramp-windows-login-shell-hosts)))))
    (dolist (method my/tramp-windows-workaround-methods)
      (when-let* ((entry (assoc method tramp-methods))
                  (stock (cadr (assq 'tramp-login-args entry))))
        (dolist (host hosts)
          ;; tramp-methods 側のリストを破壊しないよう copy-tree してから加工する
          (let ((args (copy-tree stock)))
            (when (member host my/tramp-windows-force-pty-hosts)
              (setq args (my/tramp--login-args-force-pty args)))
            (when-let* ((shell (cdr (assoc host my/tramp-windows-login-shell-hosts))))
              (setq args (my/tramp--login-args-append-shell args shell)))
            (unless (equal args stock)
              ;; 正規表現は (tramp-make-tramp-file-name vec 'noloc) すなわち
              ;; "/ssh:user@host:" に対して照合される (tramp-cache.el:136-140)
              (add-to-list
               'tramp-connection-properties
               (list (format "\\`/%s:\\(?:[^@|:]+@\\)?%s\\(?:#[0-9]+\\)?:"
                             (regexp-quote method) host)
                     "login-args" args)))))))))

(when (eq system-type 'windows-nt)
  (with-eval-after-load 'tramp
    (my/tramp-apply-windows-host-workarounds)))

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
