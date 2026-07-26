;;; win.el --- Windows 固有設定 -*- lexical-binding: t; -*-
(leaf *coding
  :config
  ;; 言語環境を先に設定する。set-language-environment は coding 優先順位を
  ;; 日本語既定へリセットするため、UTF-8 を最優先にする prefer-coding-system は
  ;; 必ずその後に呼ぶ (順序を逆にすると UTF-8 優先が打ち消され文字化けの原因)。
  (set-language-environment "Japanese")
  (prefer-coding-system 'utf-8-unix)
  ;; 新規ファイルは UTF-8 / LF を既定にする。
  (setq-default buffer-file-coding-system 'utf-8-unix)
  (set-terminal-coding-system 'utf-8-unix)
  (set-keyboard-coding-system 'utf-8-unix)
  ;; Windows のクリップボードは UTF-16LE。日本語コピペの文字化け対策。
  (set-clipboard-coding-system 'utf-16le-dos)
  (set-selection-coding-system 'utf-16le-dos)
  (set-frame-font "Ricty diminished-12" nil t)

  ;; ---- 改行コード (CRLF を使わず LF に統一する) ----
  ;; 新規ファイル: 上の utf-8-unix 既定により LF。
  ;; 既存 CRLF ファイル: 保存時に確認してから LF へ変換する。

  (defun my/buffer-uses-crlf-p ()
    "現在のバッファが CRLF (DOS) で保存される、または CR を含む場合に非 nil。
正しく DOS と判別されたファイルは buffer 内に CR を持たないため、
coding-system の EOL 種別 (1 = dos) も確認する。"
    (or (and buffer-file-coding-system
             (eq (coding-system-eol-type buffer-file-coding-system) 1))
        (save-excursion
          (save-restriction
            (widen)
            (goto-char (point-min))
            (search-forward "\r" nil t)))))

  (defun my/strip-crlf-from-string (string)
    "STRING 中の CRLF / 単独 CR を LF に変換する。"
    (replace-regexp-in-string "\r\n?" "\n" string))

  (defun my/strip-crlf-in-yank (orig-fun &rest args)
    "貼り付けテキストから CR を除去してから挿入する (コピペの改行混入対策)。"
    (let ((first-arg (car args)))
      (if (stringp first-arg)
          (apply orig-fun
                 (cons (my/strip-crlf-from-string first-arg)
                       (cdr args)))
        (apply orig-fun args))))

  (defun my/confirm-strip-crlf-on-save ()
    "既存ファイルが CRLF のとき、確認のうえ LF へ変換して保存する。"
    (when (and buffer-file-name (my/buffer-uses-crlf-p))
      (when (y-or-n-p
             (format "%s は CRLF です。LF に変換して保存しますか? "
                     (file-name-nondirectory buffer-file-name)))
        ;; 保存時の改行を LF にする
        (set-buffer-file-coding-system
         (coding-system-change-eol-conversion
          (or buffer-file-coding-system 'utf-8) 'unix))
        ;; buffer 内に残る単独 CR も除去する
        (save-excursion
          (save-restriction
            (widen)
            (goto-char (point-min))
            (while (search-forward "\r" nil t)
              (replace-match "")))))))

  (advice-add 'insert-for-yank :around #'my/strip-crlf-in-yank)
  (add-hook 'before-save-hook #'my/confirm-strip-crlf-on-save)
  )

(leaf *IME
  :config
  ;; IME
  (setq default-input-method "W32-IME")
  ;; (w32-ime-initialize)

  (advice-add 'ime-force-on
              :before (lambda (&rest args)
                        (set-cursor-color "blue")))
  (advice-add 'ime-force-off
              :before (lambda (&rest args)
                        (set-cursor-color "cyan")))
  (add-hook 'input-method-activate-hook
            (lambda() (set-cursor-color "blue")))
  (add-hook 'input-method-inactivate-hook
            (lambda() (set-cursor-color "cyan")))
  (setq w32-ime-buffer-switch-p t)
  )

(leaf *SHELL
  ;; SHELL
  :config
  ;; ---- Windows local の shell は Git Bash をフルパスで固定する ----
  ;; パス無しの "bash" にすると PATH 解決になり、machine PATH の
  ;; C:\WINDOWS\system32 が user PATH の Git より先に来るため
  ;; C:\Windows\System32\bash.exe (WSL 起動プロキシ) が引かれる。
  ;; 結果 M-x shell も shell-command / compile / grep / magit も WSL になる。
  ;; これを避けるため絶対パスで指定する。
  ;; 候補は usr/bin/bash.exe ではなく bin/bash.exe を使う。後者は MSYS 環境
  ;; (PATH, MSYSTEM 等) をセットアップしてから bash を起動するラッパーで、
  ;; Git for Windows の正しい入口。usr/bin/ の方は素の bash で環境が揃わない。
  ;; WSL を使いたいときは C-c T w (my/terminal-wsl) で明示的に起動する。
  (defcustom my/windows-git-bash-file-name
    (seq-find #'file-executable-p
              '("C:/Program Files/Git/bin/bash.exe"
                "C:/Program Files (x86)/Git/bin/bash.exe"
                "C:/Users/smaya/AppData/Local/Programs/Git/bin/bash.exe"))
    "Windows local で使う Git Bash の絶対パス。見つからないときは nil。"
    :type '(choice (const :tag "見つからない" nil) file)
    :group 'shell)

  ;; shell.el は引数変数名を
  ;;   (intern-soft (concat "explicit-" (file-name-nondirectory prog) "-args"))
  ;; で作る。フルパス指定だと basename が "bash.exe" になるので
  ;; explicit-bash-args だけでは効かない。両方定義しておく。
  ;; 値は shell.el の explicit-bash-args 既定と同じ ("--noediting" "-i")。
  ;; --noediting で bash 側の readline を切り、行編集を comint に任せる
  ;; (これが無いと comint 内でエスケープ列や二重エコーが出る)。
  ;; win.el は shell.el より先に読まれ、defcustom は既に値のある変数を
  ;; 上書きしないので、ここで値を変えると shell.el の既定を潰すことになる。
  (defvar explicit-bash-args '("--noediting" "-i"))
  (defvar explicit-bash.exe-args '("--noediting" "-i"))

  (if my/windows-git-bash-file-name
      (progn
        (setq shell-file-name my/windows-git-bash-file-name)
        ;; cmdproxy 由来の "/c" ではなく bash の "-c" にする
        (setq shell-command-switch "-c")
        (setenv "SHELL" shell-file-name)
        (setq explicit-shell-file-name my/windows-git-bash-file-name))
    ;; 見つからないときは何も触らない。中途半端な値を握らせるより
    ;; Windows 既定の cmdproxy.exe のまま残す方が安全。
    (display-warning
     'my/windows
     "Git Bash (bin/bash.exe) が見つかりません。shell 系は Windows 既定 (cmdproxy.exe) のままにします"
     :warning))

  ;; ---- comint の表示ノイズ対策 (Windows 専用) ----
  ;; macOS 側の端末は mistty (本物の pty) を使っていて comint 経路を
  ;; 通らないので、以下は Windows 専用の win.el に置く。
  ;; init.el 共通部や 31_terminal.el に書くと mac 側に無駄な
  ;; フックが増えるだけになる。

  ;; (1) OSC エスケープ列。Git Bash の既定 PS1 は
  ;;     ESC ] 0 ; MINGW64:/c/Users/smaya BEL
  ;;     をウィンドウタイトル用に吐く。comint は素通しするので生テキストで
  ;;     見えてしまう。comint-osc-process-output は comint.el 本体の関数で
  ;;     (ansi-osc.el ではない。comint.el が ansi-osc を require している)、
  ;;     Emacs 30.1 に標準搭載。ハンドラの無い OSC 0 も含め列自体は必ず
  ;;     削除されるうえ、OSC 7 を吐く設定にすればカレントディレクトリ追従も
  ;;     効くようになる。shell-mode が走る時点で comint はロード済みなので
  ;;     追加の require は不要。

  ;; (2) 起動直後の 2 行
  ;;       bash: cannot set terminal process group (-1): ...
  ;;       bash: no job control in this shell
  ;;     Windows の Emacs には pty が無く、bash -i をパイプ越しに起動する
  ;;     以上これは原理的に避けられない bash 自身のメッセージ。表示だけ
  ;;     preoutput filter で落とす。
  ;;     この 2 行は起動直後の先頭出力にしか現れないので、常時正規表現を
  ;;     回すと大量出力時に効いてくる。役目を終えたら自分をフックから
  ;;     外す作りにしてある。
  (defconst my/shell--bash-startup-noise-regexp
    (concat "\\`bash: \\(?:cannot set terminal process group"
            "\\|no job control in this shell\\)")
    "抑止対象の bash 起動メッセージ。行頭から一致させる。")

  (defvar-local my/shell--bash-noise-pending ""
    "行の途中で切れたチャンクを次の呼び出しまで持ち越すバッファ。")

  (defun my/shell--strip-bash-startup-noise (string)
    "bash 起動直後のジョブ制御メッセージ 2 行を STRING から取り除く。
`comint-preoutput-filter-functions' 用。対象行を吐き終わったと判断した
時点で自分自身をフックから外す。"
    (let ((text (concat my/shell--bash-noise-pending string))
          (out "")
          (done nil))
      (setq my/shell--bash-noise-pending "")
      (while (not done)
        (cond
         ;; 全部さばけた
         ((string-empty-p text)
          (setq done t))
         ;; "bash: " 以外が来た = ノイズ区間は終わり。以降は素通しでよい
         ((not (string-prefix-p "bash: " text))
          (setq out (concat out text)
                done t)
          (my/shell--stop-stripping-bash-noise))
         ;; 行が揃っている
         ((string-match "\n" text)
          (let* ((eol (1+ (string-match "\n" text)))
                 (line (substring text 0 eol)))
            (if (string-match-p my/shell--bash-startup-noise-regexp line)
                (setq text (substring text eol))
              ;; bash: で始まるが対象外のメッセージ。巻き込まない
              (setq out (concat out text)
                    done t)
              (my/shell--stop-stripping-bash-noise))))
         ;; "bash: ..." が改行前で切れた。次のチャンクを待つ
         (t
          (setq my/shell--bash-noise-pending text
                done t))))
      out))

  (defun my/shell--stop-stripping-bash-noise ()
    "起動ノイズ除去フィルタを自分のバッファから外す。"
    (setq my/shell--bash-noise-pending "")
    (remove-hook 'comint-preoutput-filter-functions
                 #'my/shell--strip-bash-startup-noise t))

  (defun my/shell-mode-setup-osc ()
    "Windows の `shell-mode' 用に OSC 処理と起動ノイズ除去を仕込む。"
    (setq my/shell--bash-noise-pending "")
    (add-hook 'comint-output-filter-functions
              #'comint-osc-process-output nil t)
    (add-hook 'comint-preoutput-filter-functions
              #'my/shell--strip-bash-startup-noise nil t))

  (add-hook 'shell-mode-hook #'my/shell-mode-setup-osc)
)
