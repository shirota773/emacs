;;; 31_terminal.el --- Terminal settings and backend comparison -*- lexical-binding: t; -*-

;;; Commentary:
;; 常用のterminal設定 (C-t -> `my/term-here'、C-c T プレフィックス) と、
;; Ghostel、MisTTY、shell + coterm を同じ作業ディレクトリから比較するための
;; コマンドをまとめる。既存の <f12> -> `shell' は変更しない。
;;
;; 主対象:
;;   native Windows Emacs -> TRAMP -> POSIX remote workstation
;; 副対象:
;;   Windows local (Git Bashをフルパス指定。WSLは別コマンド C-c T w) /
;;   macOS local (現在は fish)
;;
;; 基本手順:
;;   1. 比較したいTRAMPファイルを開き、そのbufferを選択する。
;;   2. 次の4コマンドを同じbufferから順に実行する。
;;        C-c T g  Ghostel
;;        C-c T m  MisTTY
;;        C-c T c  shell + coterm
;;        C-c T e  eat
;;        C-c T w  WSL (Windows専用。比較対象外の実用コマンド)
;;   3. C-c T r で評価用bufferを作り、候補ごとに結果を記入する。
;;   4. C-c T ? で、この説明と既知の制約を再表示する。
;;
;; 初回だけ必要な操作:
;;   Ghostelは最初の起動時にnative moduleのdownloadを確認する。仕事PCで
;;   downloadが禁止・遮断される場合は、それ自体を導入性の評価結果とする。
;;
;; Remote shell:
;;   試験時は既定で /bin/bash -i を使う。remote workstationが異なるshellを
;;   使う場合は `my/terminal-remote-shell' と
;;   `my/terminal-remote-shell-args' をCustomizeする。
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
;;   - Windows local: パス無しの "bash" はPATH順で C:\Windows\System32\bash.exe
;;     (WSL起動プロキシ) を引いてしまうため、`inits/win.el' で Git Bash を
;;     フルパス指定して `shell-file-name' / `explicit-shell-file-name' に固定
;;     している。C-t (`my/term-here') のWindows local分岐はそれを継承する。
;;     WSLが必要なときは C-c T w (`my/terminal-wsl') で明示的に起動する。
;;
;; 採用判定では、見た目より次を優先する:
;;   接続成功、再接続、入力遅延、resize、TUI、copy/paste、日本語幅、
;;   current directory追跡、Emacs全体の応答性、終了時のprocess処理。

;;; Code:

(require 'subr-x)
(require 'tramp)

(defgroup my/terminal nil
  "Windows/TRAMP用terminal backendの比較試験。"
  :group 'terminals)

(defcustom my/terminal-remote-shell "/bin/bash"
  "比較試験でremote host上に起動するinteractive shell。"
  :type 'string
  :group 'my/terminal)

(defcustom my/terminal-remote-shell-args '("-i")
  "`my/terminal-remote-shell'へ渡す引数。"
  :type '(repeat string)
  :group 'my/terminal)

(defcustom my/terminal-wsl-distro "Ubuntu"
  "`my/terminal-wsl'が起動するWSLのdistribution名。"
  :type 'string
  :group 'my/terminal)

;; shell.el は引数変数を
;;   (intern-soft (concat "explicit-" (file-name-nondirectory prog) "-args"))
;; で探すので、wsl.exeをフルパスで起動する場合はこの名前が必要。
;; 実際の値は `my/terminal-wsl' がlet-bindする。
(defvar explicit-wsl.exe-args nil
  "`M-x shell'がwsl.exeを起動するときに渡す引数。")

;; パッケージは起動時にインストールするが、試験コマンドを押すまでloadしない。
(leaf ghostel
  :ensure t)

;; mistty の fullscreen (tmux等のTUIが起動している間) では、keymapが
;; `mistty-fullscreen-map' に切り替わる。その親 `term-raw-map' は全キーに対する
;; catch-all (t . term-send-raw) を持つので、キー検索が必ずそこで確定して
;; global-mapまで届かない = M-xもC-fも素通りで端末へ送られる。適用形態は
;; local-mapなので bind-key* なら勝てるが、それでは全major modeへ影響が出る。
;; mistty自身が案内しているとおり `mistty-fullscreen-map' へ個別に足す。
(defun my/mistty-global-binding ()
  "押されたキーのEmacs側 (override-global-map / global-map) の割り当てを実行する。
`mistty-fullscreen-map'からこれを呼ぶ形にして、キーとコマンドの対応は
94_keybinds.el等の一箇所に残す (コマンド名をこのファイルへ写さない)。
割り当てを変えてもこちらの追従漏れが起きない。"
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (cmd (or (and (boundp 'override-global-map)
                       (lookup-key override-global-map keys))
                  (lookup-key global-map keys))))
    (unless (commandp cmd)
      (user-error "%s にEmacs側の割り当てがありません" (key-description keys)))
    (setq this-command cmd)
    (call-interactively cmd)))

(leaf mistty
  :ensure t
  ;; `:config'ではなく`:defer-config' (= eval-after-load)。leafの`:config'は
  ;; ロードを待たず即時実行されるので、mistty-fullscreen-mapがまだvoidになる。
  :defer-config
  ;; fullscreen中も端末へ渡さずEmacs側で処理するキー。
  ;; 本来のキーを端末へ送りたいときは C-q <key> (mistty-send-last-key)。
  ;;   C-f は tmux の prefix と衝突する。tmux側は prefix2 = C-b (tmux既定) を
  ;;   併設して逃がしてある (~/.config/tmux/tmux.conf)。ここに足さないキーは
  ;;   catch-all で端末へ素通りするので、Emacs側で使用中のC-bでも tmux に届く。
  ;;   iTermでは従来どおりC-fが使える。
  (dolist (key '("M-x" "C-o" "C-r" "C-t" "C-f"))
    (keymap-set mistty-fullscreen-map key #'my/mistty-global-binding)))

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

(defun my/terminal--remote-p ()
  "現在の`default-directory'がremoteならnon-nilを返す。"
  (file-remote-p default-directory))

(defun my/terminal--scope-name ()
  "現在のlocal/remote接続をbuffer名用の短い文字列にする。"
  (if-let* ((remote (my/terminal--remote-p)))
      (replace-regexp-in-string "[/:*]" "_" remote)
    "local"))

(defun my/terminal--assert-directory ()
  "Terminalを起動する`default-directory'を検査する。"
  (unless (and (stringp default-directory)
               (not (string-empty-p default-directory)))
    (user-error "このbufferには有効なdefault-directoryがありません")))

(defun my/terminal-ghostel ()
  "現在地でGhostelを起動する。TRAMP bufferならremote terminalになる。"
  (interactive)
  (my/terminal--assert-directory)
  (unless (require 'ghostel nil t)
    (user-error "ghostelをloadできません。package install結果を確認してください"))
  (call-interactively #'ghostel))

(defun my/terminal-mistty ()
  "現在地に新しいMisTTYを作る。TRAMP bufferではremote shellを起動する。"
  (interactive)
  (my/terminal--assert-directory)
  (unless (require 'mistty nil t)
    (user-error "misttyをloadできません。package install結果を確認してください"))
  ;; Windows側のexplicit-shell-file-nameはbashなので、そのままremote hostへ
  ;; 持ち込まず、比較用のremote shellを明示する。
  (let ((mistty-shell-command
         (when (my/terminal--remote-p)
           (cons my/terminal-remote-shell
                 my/terminal-remote-shell-args))))
    (call-interactively #'mistty-create)))

(defun my/terminal-coterm ()
  "現在地でcoterm付き`M-x shell'を起動または再表示する。"
  (interactive)
  (my/terminal--assert-directory)
  (unless (require 'coterm nil t)
    (user-error "cotermをloadできません。package install結果を確認してください"))
  (require 'shell)
  (coterm-mode 1)
  (let ((buffer-name
         (format "*terminal-coterm:%s*"
                 (my/terminal--scope-name)))
        (explicit-shell-file-name
         (if (my/terminal--remote-p)
             my/terminal-remote-shell
           explicit-shell-file-name))
        ;; 現在の比較対象はbash。別shellを採用する場合はconnection-local
        ;; variablesへ昇格し、hostごとに設定する。
        (explicit-bash-args
         (if (my/terminal--remote-p)
             my/terminal-remote-shell-args
           explicit-bash-args)))
    (shell buffer-name)))

(defun my/terminal-disable-coterm ()
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
  (my/terminal--assert-directory)
  (unless (require 'eat nil t)
    (user-error "eatをloadできません。package install結果を確認してください"))
  (let* ((buf-name (format "*eat:%s*" (my/terminal--scope-name)))
         (existing (get-buffer buf-name)))
    (if (and existing (get-buffer-process existing) (not arg))
        (pop-to-buffer existing)
      (let ((eat-buffer-name buf-name)
            (shell (if (my/terminal--remote-p)
                       my/terminal-remote-shell
                   (or explicit-shell-file-name shell-file-name))))
        (eat shell arg)))))

(defun my/terminal-eat ()
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
  (my/terminal--assert-directory)
  (let* ((use-mistty (and (not (eq system-type 'windows-nt))
                          (require 'mistty nil t)))
         (buf-name (format "*%s:%s*" (if use-mistty "mistty" "shell")
                           (my/terminal--scope-name)))
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
                  (if (my/terminal--remote-p)
                      (cons my/terminal-remote-shell
                            my/terminal-remote-shell-args)
                    mistty-shell-command))
                 (buf (mistty-create)))
            (when (buffer-live-p buf)
              (with-current-buffer buf
                (rename-buffer
                 (if arg (generate-new-buffer-name buf-name) buf-name) t))))
        (let ((explicit-shell-file-name
               (if (my/terminal--remote-p)
                   my/terminal-remote-shell
                 explicit-shell-file-name)))
          (shell (if arg (generate-new-buffer-name buf-name) buf-name)))))))

(defun my/terminal--wsl-program ()
  "起動するwsl.exeの絶対パスを返す。見つからなければuser-error。"
  (or (and (file-executable-p "C:/Windows/System32/wsl.exe")
           "C:/Windows/System32/wsl.exe")
      (executable-find "wsl.exe")
      (user-error "wsl.exeが見つかりません。WSLが有効か確認してください")))

(defun my/terminal-wsl (&optional arg)
  "WSL (`my/terminal-wsl-distro') のshellを現在地で開く。
Windows local専用。C-t (`my/term-here') の既定はGit Bashなので、WSLが必要な
ときだけこちらを使う。distro単位のbuffer名 (*shell:wsl-Ubuntu* など) で
生存プロセスのbufferを再利用する。
C-u (ARG) 付きで新しいbufferを追加する。"
  (interactive "P")
  (unless (eq system-type 'windows-nt)
    (user-error "WSLはWindows専用です。C-t か C-c T m を使ってください"))
  (my/terminal--assert-directory)
  ;; WSL経由でTRAMP先のfile systemへは行けない (wsl.exeはWindows側のcwdしか
  ;; 引き継がない)。remote bufferからは黙って別の場所を開かず拒否する。
  (when (my/terminal--remote-p)
    (user-error "TRAMP bufferからはWSLを起動できません。C-t か C-c T m を使ってください"))
  (require 'shell)
  (let* ((buf-name (format "*shell:wsl-%s*" my/terminal-wsl-distro))
         (existing (get-buffer buf-name)))
    (if (and existing (get-buffer-process existing) (not arg))
        (pop-to-buffer existing)
      ;; wsl.exeはWindows側のcwd (C:\...) を /mnt/c/... へ自動変換して起動する
      ;; ため、default-directoryをこちら側で変換する必要はない。
      (let* ((explicit-shell-file-name (my/terminal--wsl-program))
             ;; "-d DISTRO" だけではbufferに何も出ない。Emacsはprocessをpipeで
             ;; 繋ぐためstdinがptyにならず、wsl.exeは既定shellを非対話modeで
             ;; 起動する = PS1を出さない (2026-07-26実測。processは生きていて
             ;; uname -o等の応答は返るが、promptだけが永久に出ない)。
             ;; "-- bash -i" で対話modeを明示するとPS1が出てcomintが成立する。
             ;; -l (login) は付けない。Ubuntuのmotdとlandscape-sysinfoの
             ;; python tracebackが数十行流れてpromptが埋もれるだけで、PATHは
             ;; .bashrcとWSL interopで既に揃っている (同日実測)。
             (explicit-wsl.exe-args
              (list "-d" my/terminal-wsl-distro "--" "bash" "-i"))
             ;; WSL側の出力はUTF-8。processのcoding systemは生成時に確定する
             ;; ので、生成後の`set-process-coding-system'では初回出力 (PS1を
             ;; 含む) の復号に間に合わない。必ず生成前にlet-bindする。
             (coding-system-for-read 'utf-8-unix)
             (coding-system-for-write 'utf-8-unix)
             ;; wsl.exe自身の診断message (distro名の誤り等) だけは既定で
             ;; UTF-16LE。上のutf-8指定のまま読むと化けるのでWSL_UTF8=1で
             ;; UTF-8に揃える。globalな`setenv'は他のprocessにも波及するため
             ;; ここだけのlet-bindで渡す。
             (process-environment (cons "WSL_UTF8=1" process-environment)))
        (shell (if arg (generate-new-buffer-name buf-name) buf-name))))))

(defun my/terminal--environment-summary ()
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
   (or (my/terminal--remote-p) "local")
   (or (file-remote-p default-directory 'method) "-")
   (or (file-remote-p default-directory 'user) "-")
   (or (file-remote-p default-directory 'host) "-")
   my/terminal-remote-shell
   (mapconcat #'identity my/terminal-remote-shell-args " ")
   (if (locate-library "ghostel") "installed" "missing")
   (if (locate-library "mistty") "installed" "missing")
   (if (locate-library "coterm") "installed" "missing")
   (if (locate-library "eat") "installed" "missing")))

(defun my/terminal-report ()
  "現在の環境情報と比較チェックリストを編集可能bufferに作る。"
  (interactive)
  (let ((summary (my/terminal--environment-summary))
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

(defun my/terminal-help ()
  "Terminal比較試験の使い方と現在の環境を表示する。"
  (interactive)
  (let ((summary (my/terminal--environment-summary)))
    (with-help-window "*Terminal Test Help*"
      (princ "Windows/TRAMP terminal comparison\n\n")
      (princ summary)
      (princ "\nTRAMPファイルのbufferから実行してください。\n\n")
      (princ "  C-c T g  Ghostelを現在地で起動\n")
      (princ "  C-c T m  新しいMisTTYを現在地で起動\n")
      (princ "  C-c T c  shell + cotermを接続単位で起動/再表示\n")
      (princ "  C-c T e  eatを接続単位で起動/再表示 (emacs-macではフリーズガード中)\n")
      (princ "  C-c T w  WSLのshellをdistro単位で起動/再表示 (Windows専用)\n")
      (princ "  C-c T r  編集可能な比較表を作成\n")
      (princ "  C-c T x  global coterm-modeを停止\n")
      (princ "  C-c T ?  このHelpを表示\n\n")
      (princ "既存の <f12> は従来どおりM-x shellです。\n")
      (princ "GhostelのWindows->TRAMPは動的resize未対応です。\n")
      (princ "MisTTYのnative Windows利用は公式確認外なので、失敗も評価結果です。\n")
      (princ "eatはnative Windows非対応、Rosetta実行のEmacsではTUIでフリーズのためガード中です。\n")
      (princ "常用のC-tは接続単位shell (my/term-here) です。TUIはmistty (C-c T m) が無事です。\n")
      (princ "Windows localのshellはGit Bashにフルパス固定 (inits/win.el)。WSLはC-c T wです。\n"))))

(defvar-keymap my/terminal-prefix-map
  :doc "Terminal backend comparison commands."
  "g" #'my/terminal-ghostel
  "m" #'my/terminal-mistty
  "c" #'my/terminal-coterm
  "e" #'my/terminal-eat
  "w" #'my/terminal-wsl
  "r" #'my/terminal-report
  "x" #'my/terminal-disable-coterm
  "?" #'my/terminal-help)

(keymap-global-set "C-c T" my/terminal-prefix-map)

(provide '31_terminal)
;;; 31_terminal.el ends here
