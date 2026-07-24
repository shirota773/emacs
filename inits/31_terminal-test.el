;;; 31_terminal-test.el --- Windows/TRAMP terminal comparison -*- lexical-binding: t; -*-

;;; Commentary:
;; Ghostel、MisTTY、shell + coterm を同じ作業ディレクトリから比較するための
;; 試験設定。既存の <f12> -> `shell' は変更しない。
;;
;; 主対象:
;;   native Windows Emacs -> TRAMP -> POSIX remote workstation
;; 副対象:
;;   Windows local (現在は bash) / macOS local (現在は fish)
;;
;; 基本手順:
;;   1. 比較したいTRAMPファイルを開き、そのbufferを選択する。
;;   2. 次の4コマンドを同じbufferから順に実行する。
;;        C-c T g  Ghostel
;;        C-c T m  MisTTY
;;        C-c T c  shell + coterm
;;        C-c T e  eat
;;   3. C-c T r で評価用bufferを作り、候補ごとに結果を記入する。
;;   4. C-c T ? で、この説明と既知の制約を再表示する。
;;
;; 初回だけ必要な操作:
;;   Ghostelは最初の起動時にnative moduleのdownloadを確認する。仕事PCで
;;   downloadが禁止・遮断される場合は、それ自体を導入性の評価結果とする。
;;
;; Remote shell:
;;   試験時は既定で /bin/bash -i を使う。remote workstationが異なるshellを
;;   使う場合は `my/terminal-test-remote-shell' と
;;   `my/terminal-test-remote-shell-args' をCustomizeする。
;;
;; 既知の制約:
;;   - Ghostel: Windows -> TRAMPはPOSIX remoteのみ。remote terminalの動的な
;;     window resizeはWindowsでは未対応。
;;   - MisTTY: TRAMP remote shell機能はあるが、公式の動作確認対象は
;;     Linux/macOS。native Windows Emacsからの利用は今回の実機評価対象。
;;   - coterm: 起動時にはglobal `coterm-mode'を有効にする。C-c T xで
;;     新規comint bufferへの適用を停止できる。
;;   - eat: native Windowsでは動作しない。さらにRosetta実行 (x86_64 Emacs)
;;     ではfzf等のTUI連続出力に処理が追いつかずライブロック=フリーズする
;;     ためガード中 (2026-07-24実測。arm64ネイティブなら正常、misttyは
;;     x86_64でも無事)。C-t は当面 `my/term-here' (接続単位shell)。
;;
;; 採用判定では、見た目より次を優先する:
;;   接続成功、再接続、入力遅延、resize、TUI、copy/paste、日本語幅、
;;   current directory追跡、Emacs全体の応答性、終了時のprocess処理。

;;; Code:

(require 'subr-x)
(require 'tramp)

(defgroup my/terminal-test nil
  "Windows/TRAMP用terminal backendの比較試験。"
  :group 'terminals)

(defcustom my/terminal-test-remote-shell "/bin/bash"
  "比較試験でremote host上に起動するinteractive shell。"
  :type 'string
  :group 'my/terminal-test)

(defcustom my/terminal-test-remote-shell-args '("-i")
  "`my/terminal-test-remote-shell'へ渡す引数。"
  :type '(repeat string)
  :group 'my/terminal-test)

;; パッケージは起動時にインストールするが、試験コマンドを押すまでloadしない。
(leaf ghostel
  :ensure t)

(leaf mistty
  :ensure t)

(leaf coterm
  :ensure t)

;; eat: macOS local + TRAMP + TUI (claude/tmux) の本命候補。NonGNU ELPA。
;; native Windowsでは動作しないため my/eat-here 側でガードする。
(leaf eat
  :ensure t
  :custom
  ;; TRAMP先にeatのterminfoが無い環境でも表示が壊れないよう汎用TERMを使う
  (eat-term-name . "xterm-256color")
  ;; プロセス終了でbufferも消す (再利用判定は生存プロセスのみが対象になる)
  (eat-kill-buffer-on-exit . t)
  :config
  ;; M-x eat 直接起動でも Rosetta フリーズ (my/eat-here のコメント参照) を
  ;; 踏まないよう確認を挟む。arm64 ネイティブ Emacs では何も出ない
  (define-advice eat (:before (&rest _) my/eat-rosetta-guard)
    (when (and (eq system-type 'darwin)
               (string-prefix-p "x86_64" system-configuration)
               (not (y-or-n-p "eatはこの環境 (Rosetta) でTUI表示によりフリーズする既知問題があります。起動しますか? ")))
      (user-error "eat の起動を中止しました"))))

(defun my/terminal-test--remote-p ()
  "現在の`default-directory'がremoteならnon-nilを返す。"
  (file-remote-p default-directory))

(defun my/terminal-test--scope-name ()
  "現在のlocal/remote接続をbuffer名用の短い文字列にする。"
  (if-let* ((remote (my/terminal-test--remote-p)))
      (replace-regexp-in-string "[/:*]" "_" remote)
    "local"))

(defun my/terminal-test--assert-directory ()
  "Terminalを起動する`default-directory'を検査する。"
  (unless (and (stringp default-directory)
               (not (string-empty-p default-directory)))
    (user-error "このbufferには有効なdefault-directoryがありません")))

(defun my/terminal-test-ghostel ()
  "現在地でGhostelを起動する。TRAMP bufferならremote terminalになる。"
  (interactive)
  (my/terminal-test--assert-directory)
  (unless (require 'ghostel nil t)
    (user-error "ghostelをloadできません。package install結果を確認してください"))
  (call-interactively #'ghostel))

(defun my/terminal-test-mistty ()
  "現在地に新しいMisTTYを作る。TRAMP bufferではremote shellを起動する。"
  (interactive)
  (my/terminal-test--assert-directory)
  (unless (require 'mistty nil t)
    (user-error "misttyをloadできません。package install結果を確認してください"))
  ;; Windows側のexplicit-shell-file-nameはbashなので、そのままremote hostへ
  ;; 持ち込まず、比較用のremote shellを明示する。
  (let ((mistty-shell-command
         (when (my/terminal-test--remote-p)
           (cons my/terminal-test-remote-shell
                 my/terminal-test-remote-shell-args))))
    (call-interactively #'mistty-create)))

(defun my/terminal-test-coterm ()
  "現在地でcoterm付き`M-x shell'を起動または再表示する。"
  (interactive)
  (my/terminal-test--assert-directory)
  (unless (require 'coterm nil t)
    (user-error "cotermをloadできません。package install結果を確認してください"))
  (require 'shell)
  (coterm-mode 1)
  (let ((buffer-name
         (format "*terminal-test-coterm:%s*"
                 (my/terminal-test--scope-name)))
        (explicit-shell-file-name
         (if (my/terminal-test--remote-p)
             my/terminal-test-remote-shell
           explicit-shell-file-name))
        ;; 現在の比較対象はbash。別shellを採用する場合はconnection-local
        ;; variablesへ昇格し、hostごとに設定する。
        (explicit-bash-args
         (if (my/terminal-test--remote-p)
             my/terminal-test-remote-shell-args
           explicit-bash-args)))
    (shell buffer-name)))

(defun my/terminal-test-disable-coterm ()
  "Global `coterm-mode'を止め、新規comint bufferへの適用を解除する。"
  (interactive)
  (if (fboundp 'coterm-mode)
      (progn
        (coterm-mode -1)
        (message "coterm-modeを無効にしました"))
    (message "cotermはまだloadされていません")))

(defun my/eat-here (&optional arg)
  "現在の`default-directory'でeatを開く。TRAMP bufferならremote shellを起動する。
接続単位のbuffer名 (*eat:local* など) で生存プロセスのbufferを再利用する。
C-u (ARG) 付きで同じ接続に新しいbufferを追加する。"
  (interactive "P")
  (when (eq system-type 'windows-nt)
    (user-error "eatはnative Windows非対応。C-c T g/m/c を使ってください"))
  ;; eat の出力処理はキューが空くまでイベントループへ戻らないため、
  ;; Rosetta (x86_64 Emacs を Apple Silicon で実行) では fzf/tmux 等の
  ;; 連続出力に処理が追いつかず、ライブロック = 完全フリーズする。
  ;; 2026-07-24 実測: x86_64 では -Q でも「eat + zsh + fzf」で確実に再現、
  ;; arm64 ネイティブ (emacs-plus) では同手順で正常。mistty/shell は
  ;; x86_64 でも無事。arm64 版 Emacs に乗り換えればこのガードは自動解除。
  (when (and (eq system-type 'darwin)
             (string-prefix-p "x86_64" system-configuration))
    (user-error "eatはRosetta実行のEmacsではTUI出力でフリーズします。C-t (shell) か C-c T m (mistty) を使ってください"))
  (my/terminal-test--assert-directory)
  (unless (require 'eat nil t)
    (user-error "eatをloadできません。package install結果を確認してください"))
  (let* ((buf-name (format "*eat:%s*" (my/terminal-test--scope-name)))
         (existing (get-buffer buf-name)))
    (if (and existing (get-buffer-process existing) (not arg))
        (pop-to-buffer existing)
      (let ((eat-buffer-name buf-name)
            (shell (if (my/terminal-test--remote-p)
                       my/terminal-test-remote-shell
                   (or explicit-shell-file-name shell-file-name))))
        (eat shell arg)))))

(defun my/terminal-test-eat ()
  "現在地でeatを起動する (`my/eat-here'の試験枠向けエイリアス)。"
  (interactive)
  (call-interactively #'my/eat-here))

(defun my/term-here (&optional arg)
  "現在の`default-directory'でterminalを開く。TRAMP bufferならremote shellになる。
macOSではmistty (TUIも捌ける。fzf/tmuxで実証済み)、native Windowsでは
shell (唯一の確実な経路) を使う。接続単位のbuffer名 (*mistty:local* /
*shell:local* など) で生存プロセスのbufferを再利用する。
C-u (ARG) 付きで同じ接続に新しいbufferを追加する。"
  (interactive "P")
  (my/terminal-test--assert-directory)
  (let* ((use-mistty (and (not (eq system-type 'windows-nt))
                          (require 'mistty nil t)))
         (buf-name (format "*%s:%s*" (if use-mistty "mistty" "shell")
                           (my/terminal-test--scope-name)))
         (existing (get-buffer buf-name))
         ;; misttyはプロセスをbuffer-localのmistty-procに持つ
         ;; (get-buffer-processでは取れない) ため生存判定を分ける
         (existing-live
          (and existing
               (if use-mistty
                   (with-current-buffer existing
                     (and (bound-and-true-p mistty-proc)
                          (process-live-p mistty-proc)))
                 (get-buffer-process existing)))))
    (if (and existing-live (not arg))
        (pop-to-buffer existing)
      (if use-mistty
          (let* ((mistty-shell-command
                  (if (my/terminal-test--remote-p)
                      (cons my/terminal-test-remote-shell
                            my/terminal-test-remote-shell-args)
                    mistty-shell-command))
                 (buf (mistty-create)))
            (when (buffer-live-p buf)
              (with-current-buffer buf
                (rename-buffer
                 (if arg (generate-new-buffer-name buf-name) buf-name) t))))
        (let ((explicit-shell-file-name
               (if (my/terminal-test--remote-p)
                   my/terminal-test-remote-shell
                 explicit-shell-file-name)))
          (shell (if arg (generate-new-buffer-name buf-name) buf-name)))))))

(defun my/terminal-test--environment-summary ()
  "現在の比較環境を文字列で返す。"
  (format
   (concat "Emacs: %s\n"
           "system-type: %S\n"
           "default-directory: %s\n"
           "remote: %s\n"
           "remote method/user/host: %s / %s / %s\n"
           "test remote shell: %s %s\n"
           "libraries: ghostel=%s, mistty=%s, coterm=%s, eat=%s\n")
   emacs-version
   system-type
   default-directory
   (or (my/terminal-test--remote-p) "local")
   (or (file-remote-p default-directory 'method) "-")
   (or (file-remote-p default-directory 'user) "-")
   (or (file-remote-p default-directory 'host) "-")
   my/terminal-test-remote-shell
   (mapconcat #'identity my/terminal-test-remote-shell-args " ")
   (if (locate-library "ghostel") "installed" "missing")
   (if (locate-library "mistty") "installed" "missing")
   (if (locate-library "coterm") "installed" "missing")
   (if (locate-library "eat") "installed" "missing")))

(defun my/terminal-test-report ()
  "現在の環境情報と比較チェックリストを編集可能bufferに作る。"
  (interactive)
  (let ((summary (my/terminal-test--environment-summary))
        ;; 再実行時に記入済みの採点を消さない。
        (report-buffer (generate-new-buffer "*Terminal Comparison*")))
    (with-current-buffer report-buffer
      (let ((inhibit-read-only t))
        (insert "Terminal comparison: Windows/TRAMP first\n"
                "========================================\n\n"
                summary "\n"
                "採点: 1=使えない / 3=許容 / 5=非常に良い\n\n"
                "| 項目 | Ghostel | MisTTY | shell+coterm | eat | メモ |\n"
                "|---|---:|---:|---:|---:|---|\n"
                "| 初回導入・起動 |  |  |  |  |  |\n"
                "| TRAMP接続・再接続 |  |  |  |  |  |\n"
                "| 通常入力・履歴・補完 |  |  |  |  |  |\n"
                "| 入力遅延・大量出力 |  |  |  |  |  |\n"
                "| less/top/tmux |  |  |  |  |  |\n"
                "| Claude Code等のTUI |  |  |  |  |  |\n"
                "| window resize/reflow |  |  |  |  |  |\n"
                "| copy/paste・kill-ring |  |  |  |  |  |\n"
                "| 日本語入力・表示幅 |  |  |  |  |  |\n"
                "| cwd追跡・fileを開く |  |  |  |  |  |\n"
                "| process終了・Emacs終了 |  |  |  |  |  |\n"
                "| Windows local shell |  |  |  | n/a |  |\n\n"
                "致命的問題:\n\n"
                "採用したい候補と理由:\n"))
      (goto-char (point-min))
      (text-mode)
      (pop-to-buffer (current-buffer)))))

(defun my/terminal-test-help ()
  "Terminal比較試験の使い方と現在の環境を表示する。"
  (interactive)
  (let ((summary (my/terminal-test--environment-summary)))
    (with-help-window "*Terminal Test Help*"
      (princ "Windows/TRAMP terminal comparison\n\n")
      (princ summary)
      (princ "\nTRAMPファイルのbufferから実行してください。\n\n")
      (princ "  C-c T g  Ghostelを現在地で起動\n")
      (princ "  C-c T m  新しいMisTTYを現在地で起動\n")
      (princ "  C-c T c  shell + cotermを接続単位で起動/再表示\n")
      (princ "  C-c T e  eatを接続単位で起動/再表示 (emacs-macではフリーズガード中)\n")
      (princ "  C-c T r  編集可能な比較表を作成\n")
      (princ "  C-c T x  global coterm-modeを停止\n")
      (princ "  C-c T ?  このHelpを表示\n\n")
      (princ "既存の <f12> は従来どおりM-x shellです。\n")
      (princ "GhostelのWindows->TRAMPは動的resize未対応です。\n")
      (princ "MisTTYのnative Windows利用は公式確認外なので、失敗も評価結果です。\n")
      (princ "eatはnative Windows非対応、Rosetta実行のEmacsではTUIでフリーズのためガード中です。\n")
      (princ "常用のC-tは接続単位shell (my/term-here) です。TUIはmistty (C-c T m) が無事です。\n"))))

(defvar-keymap my/terminal-test-prefix-map
  :doc "Terminal backend comparison commands."
  "g" #'my/terminal-test-ghostel
  "m" #'my/terminal-test-mistty
  "c" #'my/terminal-test-coterm
  "e" #'my/terminal-test-eat
  "r" #'my/terminal-test-report
  "x" #'my/terminal-test-disable-coterm
  "?" #'my/terminal-test-help)

(keymap-global-set "C-c T" my/terminal-test-prefix-map)

(provide '31_terminal-test)
;;; 31_terminal-test.el ends here
