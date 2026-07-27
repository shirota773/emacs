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

;; ControlMaster 関連の変数はどちらも tramp-sh.el にしかなく、
;; 片方の Emacs にしか存在しない。バイトコンパイル時の free-vars 警告を
;; 出さないための宣言だけ置く (値は作らないので boundp 判定に影響しない)。
(defvar tramp-use-connection-share)          ; Emacs 30.1 以降のみ
(defvar tramp-use-ssh-controlmaster-options) ; Emacs 29.4 系のみ (30.1 では alias)

(defun my/tramp-disable-connection-share ()
  "ssh の ControlMaster オプションを TRAMP に足させない。
~/.ssh/config の Control* 設定をそのまま使うための設定。

★ なぜ boundp 分岐と `with-eval-after-load' が要るか (素の setq では片方が死ぬ)
  Emacs 30.1 (Tramp 2.7.1) で `tramp-use-ssh-controlmaster-options' は
  obsolete になり `tramp-use-connection-share' にリネームされた
  (30.1 tramp-sh.el:105-108)。Emacs 29.4 が同梱する Tramp 2.6 系には
  新しい名前が一切存在せず、旧名の defcustom だけがある
  (29.4 tramp-sh.el:103)。よって新しい名前へ素で setq すると、29.4 では
  誰も読まないゴミ変数が生えるだけで、エラーも警告も出ないまま旧変数が
  既定値 t のまま残る。macOS の既定は t なので ~/.ssh/config の
  Control* 設定が Emacs 側の -o ControlMaster=auto 等に上書きされる。

  どちらの名前が生きているかは tramp-sh.el がロードされるまで判定できない。
  両方の defcustom とも ;;;###tramp-autoload されておらず、
  (require \\='tramp) の直後は 29.4 / 30.1 のどちらでも両方 boundp が nil
  (実測)。よって判定は `with-eval-after-load' \\='tramp-sh の中で行う。

  tramp-sh.el のロード「前」に旧名へ setq してはいけない。30.1 では
  `define-obsolete-variable-alias' (30.1 tramp-sh.el:105-106) が旧名を
  新名の alias に付け替えるので、先に旧名へ入れた値は捨てられる。
  これがそもそもリネーム時の落とし穴で、`with-eval-after-load' \\='tramp-sh に
  置けばこの順序問題自体が消える。

  30.1 では旧名も alias 経由で boundp が真になるので、新しい名前から先に
  調べること。順序を入れ替えると 30.1 で obsolete な旧名へ書くことになる。

  遅らせても間に合う: この変数を読むのは `tramp-ssh-controlmaster-options'
  だけで (30.1 tramp-sh.el:4895- / 29.4 tramp-sh.el:4962-)、
  呼ばれるのは接続を張るとき。tramp-sh のロード完了直後で十分早い。

  なお既定値は両版とも (not (eq system-type \\='windows-nt)) なので、
  Windows では元から nil。この関数に意味があるのは macOS 側。"
  (with-eval-after-load 'tramp-sh
    (cond
     ;; Emacs 30.1 以降 (Tramp 2.7.1 以降)
     ((boundp 'tramp-use-connection-share)
      (setq tramp-use-connection-share nil))
     ;; Emacs 29.4 (Tramp 2.6 系)。新しい名前が無いため旧名を使う
     ((boundp 'tramp-use-ssh-controlmaster-options)
      (setq tramp-use-ssh-controlmaster-options nil)))))

(leaf tramp
  :tag "builtin"
  :config
  (setq tramp-verbose 1)                       ; ログを抑制 (デバッグ時は 6)
  (setq remote-file-name-inhibit-locks t)      ; リモートに .#lock を作らない
  ;; ~/.ssh/config の ControlMaster 設定をそのまま使う (詳細は上の関数を参照)
  (my/tramp-disable-connection-share)
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
;;   どのホストが該当するかは環境ごとに違う。private の mac と、仕事で使う
;;   Windows -> Linux では必要なワークアラウンドが別物で、後者はこの環境から
;;   疎通テストできない。よって値は git 管理下のこのファイルではなく
;;   ~/.emacs.local-inits/NN_*.el 側に置く。書き方は素の
;;
;;     (setq my/tramp-windows-force-pty-hosts '("..."))
;;
;;   だけでよく、再適用関数を呼ぶ必要はない (理由は下記)。
;;   my/tramp-windows-workaround-methods も同じタイミングで読み直される。
;;
;; ★ なぜ after-init-hook でもう一度適用するのか (ここを消すと local-inits が死ぬ)
;;   tramp-connection-properties は「値」を持つ静的なデータで、2-2 節の補完の
;;   ように参照時評価にする余地が無い。よって「いつ適用するか」で解決するしかない。
;;   tramp の require は inits/31_terminal.el:58 で起きる。つまり
;;   with-eval-after-load 'tramp は inits/ を読んでいる途中で発火してしまい、
;;   init.el:81-83 が ~/.emacs.local-inits を読むより前に終わっている。
;;   そこで after-init-hook (startup.el:1570 = init ファイル読み込み完了直後、
;;   local-inits より後) でもう一度適用し、local-inits の setq を反映させる。
;;   起動中に接続が起きても効くよう、tramp ロード時の 1 回目も残してある。
;;
;;   2 回走るので my/tramp-apply-windows-host-workarounds は冪等にしてある。
;;   前回自分が登録したエントリを my/tramp--windows-workaround-properties に
;;   控えておき、再適用時に eq で特定して取り除いてから登録し直す。
;;   eq 比較なので他所が入れた tramp-connection-properties のエントリは消さない。
;;   リストからホストを削除した場合も、古い上書きが残らず stock の
;;   login-args に戻る。
;;
;;   ハマりどころ: 起動後にリストを編集したときは
;;   M-x my/tramp-apply-windows-host-workarounds で再適用したうえで、
;;   さらに M-x tramp-cleanup-all-connections が必須。
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

環境ごとに違う値なので ~/.emacs.local-inits/NN_*.el 側で
素の setq で上書きしてよい。after-init-hook で再適用されるため
`my/tramp-apply-windows-host-workarounds' を呼ぶ必要はない。

起動後に編集した場合だけは、M-x で再適用したうえで
M-x tramp-cleanup-all-connections も実行すること。
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

環境ごとに違う値なので ~/.emacs.local-inits/NN_*.el 側で
素の setq で上書きしてよい。after-init-hook で再適用されるため
`my/tramp-apply-windows-host-workarounds' を呼ぶ必要はない。

起動後に編集した場合だけは、M-x で再適用したうえで
M-x tramp-cleanup-all-connections も実行すること。
永続化キャッシュ (var/tramp/persistency.el) に残った古い login-args が
優先され、直したはずの設定が効かないため。"
  :type '(alist :key-type regexp :value-type string)
  :group 'tramp)

(defvar my/tramp-windows-workaround-methods '("ssh" "scp")
  "ホスト単位ワークアラウンドを適用する TRAMP method 名のリスト。
これも ~/.emacs.local-inits/ 側から素の setq で変えてよい。")

(defvar my/tramp--windows-workaround-properties nil
  "自分が `tramp-connection-properties' に登録したエントリの実体リスト。
再適用時にこの中の cons を eq で特定して取り除くためだけに持つ。
値ではなく実体で覚えるので、他所が登録したエントリは巻き添えにしない。")

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
login-args が変わっても設定が腐らない。

何度呼んでも同じ結果になる (冪等)。前回自分が登録した分を先に取り除くので、
リストからホストを消した場合も古い上書きが残らない。tramp のロード後に
呼ぶこと。呼ばれた時点の変数の値を読むので、~/.emacs.local-inits/ 側で
setq した値も拾う。"
  (interactive)
  ;; 前回自分が入れた分だけを取り除く。delq (eq 比較) なので、たまたま同じ値の
  ;; エントリを他所が登録していても、そちらは消さない。
  (dolist (prop my/tramp--windows-workaround-properties)
    (setq tramp-connection-properties
          (delq prop tramp-connection-properties)))
  (setq my/tramp--windows-workaround-properties nil)
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
              (let ((prop (list (format "\\`/%s:\\(?:[^@|:]+@\\)?%s\\(?:#[0-9]+\\)?:"
                                        (regexp-quote method) host)
                                "login-args" args)))
                ;; 同値のエントリが既にあるなら足さない。その場合は自分の登録分
                ;; として控えないので、次回の掃除でも他所のエントリを消さない。
                (unless (member prop tramp-connection-properties)
                  (push prop tramp-connection-properties)
                  (push prop my/tramp--windows-workaround-properties))))))))))

(defun my/tramp-reapply-windows-host-workarounds ()
  "`after-init-hook' から ~/.emacs.local-inits/ の値で登録し直す。
`with-eval-after-load' を挟むのは、tramp が未ロードのまま after-init を
迎えた場合に `tramp-methods' 未定義で落ちないようにするため。
ロード済みなら即時に実行される。"
  (with-eval-after-load 'tramp
    (my/tramp-apply-windows-host-workarounds)))

(when (eq system-type 'windows-nt)
  ;; 1 回目: tramp のロード直後。inits/ の途中 (31_terminal.el:58) で走る。
  ;; 起動処理中に接続が発生しても効くようにするための保険。
  (with-eval-after-load 'tramp
    (my/tramp-apply-windows-host-workarounds))
  ;; 2 回目: 全 init 読み込み後。ここで初めて ~/.emacs.local-inits/ の setq が
  ;; 見える。シンボルで登録するので init-loader が再ロードしても重複しない。
  (add-hook 'after-init-hook #'my/tramp-reapply-windows-host-workarounds))

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

;; -----------------------------------------------------------------------------
;; 2-2. ホスト補完のソースを絞り、環境固有ホストは外から注入する
;;
;; なぜ known_hosts を外すか:
;;   素の TRAMP は ssh 系メソッドに tramp-completion-function-alist-ssh
;;   (tramp-sh.el:402-433) を割り当てる。この中に ~/.ssh/known_hosts があるため、
;;   ssh で一度でも繋いだ相手が全部ホスト補完の候補になる。この環境では
;;   github.com / localhost / 127.0.0.1 / 127.0.0.2 / 172.29.91.20 のように
;;   TRAMP で開く気の無いホストが 8 件並び、実際に開きたい 2 件が埋もれていた。
;;   known_hosts は「鍵を検証した相手」の記録であって「編集したいホスト」の
;;   一覧ではない。用途が違うものを補完ソースにしているのが元凶。
;;   → 補完ソースを ~/.ssh/config と下の defcustom だけに差し替える。
;;
;; tramp-methods は触らない:
;;   差し替えるのは tramp-completion-function-alist だけで、接続時に使われる
;;   tramp-methods や 2-1 節の tramp-connection-properties には一切影響しない。
;;   補完に出なくなったホストも、フルパスを手で打てば今まで通り繋がる。
;;
;; (FUNCTION FILE) の FILE にメソッド名を渡している理由:
;;   自前の parse 関数は読むファイルを持たない。一方 TRAMP は補完時に
;;   (funcall (nth 0 x) (nth 1 x)) と FILE を唯一の引数として渡してくる
;;   (30.1 tramp.el:2886 / 29.4 tramp.el:3156)。2-3 節の
;;   my/tramp-parse-cached-connections はメソッド名で候補を絞る必要があるので、
;;   FILE の位置にメソッド名を入れて受け取る。TRAMP 自身も
;;   tramp-parse-default-user-host などで同じ手を使っている
;;   (tramp-get-completion-function)。
;;
;; ★ 登録に tramp-set-completion-function を使わない理由 (Emacs 29.4 対応)
;;   あの関数は FILE を検査し、条件に合わないエントリを黙って捨てる。
;;   Emacs 30.1 の検査には「FILE がメソッド名と同一の文字列なら通す」分岐が
;;   あるが (30.1 tramp.el:2226-2227 の ;; Method.)、Emacs 29.4 が同梱する
;;   Tramp 2.6 系にはその分岐が無く、実在ファイル / HKEY_CURRENT_USER 始まり /
;;   DNS-SD サービス名 のいずれでもない FILE は (file-exists-p "ssh") が nil に
;;   なって捨てられる (29.4 tramp.el:2529-2542 で確認)。
;;   つまり 29.4 であの関数を使うと、下に並べた自前 parse 関数 3 本が全部
;;   登録されずに消え、エラーも警告も出ないまま ~/.ssh/config だけが残る。
;;   my/tramp-extra-hosts も 2-3 節のキャッシュ候補も永久に効かなくなる。
;;
;;   tramp-completion-function-alist の形式 (METHOD . ((FUNCTION FILE) ...)) と
;;   読み出し側の tramp-get-completion-function は 29.4 と 30.1 で完全に同一
;;   (両版のソースを突き合わせて確認) なので、alist を直接組み立てれば
;;   どちらの Emacs でも同じ結果になる。バージョン分岐を持たない 1 本道に
;;   できるので、29.4 で実行検証できない経路が生まれないのも利点。
;;   捨てられていた「~/.ssh/config が無いときは登録しない」判定は、
;;   tramp-parse-file 側が file-readable-p で守っている (両版とも) ため
;;   自前で持つ必要が無い。むしろ登録後に ~/.ssh/config を作った場合も
;;   即座に効くようになり、この節の遅延評価の方針とも揃う。
;;
;; ★ 遅延評価にしてある理由 (ここを知らずに触ると壊れる)
;;   init.el:81-83 は inits/ を全部読んだ「後」に ~/.emacs.local-inits を
;;   init-loader-load する。つまりこのファイルより local-inits の方が後に走る。
;;   登録時に my/tramp-extra-hosts の値を焼き込むと、local-inits 側の setq が
;;   間に合わず永久に反映されない。そこで parse 関数の中で変数を読む形にし、
;;   補完が呼ばれたその瞬間の値を使う。local-inits 側は setq するだけでよく、
;;   補完ソースの再登録も Emacs の再起動も要らない。
;;   同じ理由で ~/.ssh/config の編集も即時反映される。tramp-parse-file には
;;   キャッシュが無く、parse は補完のたびにファイルを読み直すため。
;; -----------------------------------------------------------------------------

;; tramp を先読みせずにバイトコンパイルを通すための宣言のみ。実体は tramp.el。
(declare-function tramp-parse-sconfig "tramp" (filename))
(defvar tramp-completion-function-alist)

(defcustom my/tramp-extra-hosts nil
  "ホスト補完に足すホストのリスト。要素は文字列か cons。
  \"host\"             ユーザー名を指定しない
  (\"user\" . \"host\")   ユーザー名を固定する
~/.ssh/config に Host エントリを作るほどでもないホスト
(IP 直打ちの検証機など) を環境ごとに足すための口。

環境固有の値なのでこのファイルには書かず
~/.emacs.local-inits/NN_*.el 側に書く。設定例:

  (setq my/tramp-extra-hosts
        \\='(\"192.168.0.10\"
          (\"yamazaki\" . \"192.168.0.10\")
          \"build01.example.internal\"))

値は補完のたびに読み直される (遅延評価) ので、
setq するだけでよく再登録も再起動も要らない。"
  :type '(repeat (choice (string :tag "ホスト名のみ")
                         (cons :tag "ユーザー名付き"
                               (string :tag "ユーザー名")
                               (string :tag "ホスト名"))))
  :group 'tramp)

(defcustom my/tramp-extra-ssh-config-files nil
  "追加で読む ssh_config 形式ファイルのパスのリスト。
TRAMP は ~/.ssh/config の Include ディレクティブを解釈しない。
仕事環境で ~/.ssh/conf.d/ のように設定を分割している場合は、
実ファイルをここに列挙する (ワイルドカードは展開しない)。
読めないパスは黙って飛ばすので、共通設定に書きっぱなしでもよい。

~/.emacs.local-inits/NN_*.el 側での設定例:

  (setq my/tramp-extra-ssh-config-files
        \\='(\"~/.ssh/conf.d/work\" \"~/.ssh/conf.d/lab\"))

値は補完のたびに読み直される (遅延評価) ので、
setq するだけでよく再登録も再起動も要らない。"
  :type '(repeat file)
  :group 'tramp)

(defvar my/tramp-ssh-completion-methods
  '("ssh" "sshx" "scp" "scpx" "rsync" "sshfs" "fcp" "plink" "pscp" "psftp")
  "ホスト補完ソースを差し替える TRAMP method 名のリスト。
既定で tramp-completion-function-alist-ssh を受け取るメソッドを並べたもの。
Emacs 30.1 では tramp-sh.el:460-479 と tramp-sshfs.el:70-71、
Emacs 29.4 では tramp-sh.el:493-517 と tramp-sshfs.el:73-74。

fcp を入れてあるのは 29.4 対応。29.4 は fcp を無条件に登録するが
(29.4 tramp-sh.el:517)、30.1 は tramp-enable-fcp-method を呼ぶまで
登録しない (30.1 tramp-sh.el:577)。未登録のメソッド名は
`my/tramp-set-host-completion-sources' 側のガードで素通りするので、
両版に同じリストを渡してよい。")

(defun my/tramp-ssh-config-file ()
  "ユーザーの ~/.ssh/config の絶対パスを返す。
TRAMP 本体 (tramp-sh.el:426-430) と同じ解決方法に揃えてある。
Windows では HOME が未設定でも動くよう USERPROFILE を基準にし、
macOS など他の OS では ~/ を基準にする。"
  (expand-file-name
   ".ssh/config"
   (or (and (eq system-type 'windows-nt) (getenv "USERPROFILE")) "~/")))

(defun my/tramp-parse-extra-hosts (&optional _method)
  "`my/tramp-extra-hosts' を TRAMP の ((USER HOST) ...) 形式で返す。
引数のメソッド名は使わない。TRAMP は (FUNCTION FILE) の FILE を
そのまま渡してくる (tramp.el:2886) ため受け取るだけ。
変数はこの関数が呼ばれた時点で読む (遅延評価)。"
  (mapcar (lambda (entry)
            (if (consp entry)
                (list (car entry) (cdr entry))
              (list nil entry)))
          my/tramp-extra-hosts))

(defun my/tramp-parse-extra-ssh-config-files (&optional _method)
  "`my/tramp-extra-ssh-config-files' を順に読んで (USER HOST) を集める。
各ファイルの解析は TRAMP 本体の `tramp-parse-sconfig' に任せる。
存在しない・読めないパスは飛ばす。
変数はこの関数が呼ばれた時点で読む (遅延評価)。"
  (let (result)
    (dolist (file my/tramp-extra-ssh-config-files)
      (let ((path (expand-file-name file)))
        (when (and (not (file-remote-p path)) (file-readable-p path))
          (setq result (append result (tramp-parse-sconfig path))))))
    result))

(defun my/tramp--set-completion-function (method function-list)
  "METHOD のホスト補完ソースを FUNCTION-LIST に差し替える。
FUNCTION-LIST は ((FUNCTION FILE) ...) 形式で、TRAMP 本体の
`tramp-set-completion-function' に渡すものと同じ。

`tramp-set-completion-function' を通さず `tramp-completion-function-alist' を
直接書き換える。理由は 2-2 節の頭のコメント (★ 登録に
tramp-set-completion-function を使わない理由) に書いてある。要点は
Emacs 29.4 の同関数には FILE にメソッド名を許す分岐が無く、自前 parse 関数の
登録が黙って全部消えること。

置き換えの手順は `tramp-set-completion-function' の末尾と同じで、
既存の METHOD のエントリを取り除いてから新しいものを載せる。
FUNCTION-LIST の中身はこちらが組み立てた固定のリストなので、
あちらが行う functionp / FILE の検査は要らない。"
  (setq tramp-completion-function-alist
        (cons (cons method function-list)
              (delete (assoc method tramp-completion-function-alist)
                      tramp-completion-function-alist))))

(defun my/tramp-set-host-completion-sources ()
  "ssh 系メソッドのホスト補完ソースを差し替える。
known_hosts を外し、~/.ssh/config と `my/tramp-extra-hosts' /
`my/tramp-extra-ssh-config-files' だけを見るようにする。
`tramp-methods' には触らないので接続時の挙動は変わらない。"
  (let ((config (my/tramp-ssh-config-file)))
    (dolist (method my/tramp-ssh-completion-methods)
      ;; 既定ソースが登録されているメソッドだけを対象にする。
      ;; 未登録のメソッド名に対して新規エントリを作らないためのガード。
      ;; Emacs 29.4 と 30.1 で fcp の登録有無が違うのもここで吸収される。
      (when (assoc method tramp-completion-function-alist)
        (my/tramp--set-completion-function
         method
         ;; ~/.ssh/config が無い環境でも登録はそのまま残す。
         ;; tramp-parse-sconfig の中身 (tramp-parse-file) が file-readable-p で
         ;; 守られており、読めなければ nil を返すだけ (29.4 / 30.1 とも同じ)。
         `((tramp-parse-sconfig ,config)
           (my/tramp-parse-extra-hosts ,method)
           (my/tramp-parse-extra-ssh-config-files ,method)
           ;; 2-3 節。組み込みの tramp-parse-connection-properties の代替。
           (my/tramp-parse-cached-connections ,method)))))))

;; この関数を実際に呼ぶ with-eval-after-load は 2-3 節の末尾にある。
;; 補完のたびに (funcall (nth 0 x) (nth 1 x)) されるので、登録自体は
;; parse 関数が未定義でも通るが、順序を追いにくくなるだけなので
;; 上に並べた parse 関数が全部定義された後で行う。

;; -----------------------------------------------------------------------------
;; 2-3. 接続キャッシュ由来の候補を user@host の 1 候補にまとめ、要らない分を消す
;;
;; 何が不満だったか:
;;   tramp-get-completion-function (tramp.el:2237-2248) は
;;   tramp-completion-function-alist の中身より前に 3 つの parse 関数を必ず
;;   前置する。そのうち tramp-parse-connection-properties (tramp-cache.el:615-627)
;;   は接続履歴 (tramp-cache-data) から (USER HOST) のタプルを返すので、
;;   一度でも繋いだ /sshx:yamazaki@192.168.0.10: が候補に載る。
;;   ここは有用なので消したくない。問題は「出方」で、
;;   tramp-get-completion-user-host (tramp.el:3043-3070) が USER と HOST の
;;   両方を持つタプルを "yamazaki@" と "192.168.0.10:" の 2 候補に割ってしまう。
;;   どちらを選んでももう一段補完が必要で、しかも一覧に並んだ "yamazaki@" は
;;   どのホストの話なのか分からない。割り方はハードコードで設定変更できない。
;;   → USER を持たず HOST に "yamazaki@192.168.0.10" と書いた 1 タプルを返す
;;     自前 parse 関数に差し替える。TRAMP 側は触らず、渡す値の形で解決する。
;;
;; ★ USER を nil ではなく "" にしてある理由 (ここを nil に直すと壊れる)
;;   HOST に "yamazaki@192.168.0.10" を入れると、手で "/sshx:yamazaki@" まで
;;   打った状態で tramp.el:3049-3054 の分岐 (partial-user と partial-host が
;;   両方ある) に入る。この分岐の判定は
;;   (string-equal partial-user (or user partial-user)) なので、USER が nil だと
;;   必ず真になって USER に partial-user が代入され、
;;   "/sshx:yamazaki@yamazaki@192.168.0.10:" という壊れた候補が出る (実測済み)。
;;   USER を空文字列にしておくと (or user partial-user) が "" になって
;;   string-equal が偽になり、この候補は黙って捨てられる。
;;   代償は "/sshx:yamazaki@" まで打った後にキャッシュ由来の候補が出ないこと。
;;   ただし素の TRAMP でもその状態では "yamazaki@" までしか埋まらないので
;;   実質の劣化は無い。"/sshx:ya" のように @ を打つ前なら 1 発で確定する。
;;
;; 組み込みの前置を止める手段 (tramp-completion-use-cache の影響範囲):
;;   tramp-completion-use-cache (tramp-cache.el:605-612) を nil にする。
;;   この変数を参照しているのは tramp-cache.el:619、すなわち
;;   tramp-parse-connection-properties の中の 1 箇所だけ (grep 実測)。
;;   persistency ファイルの読み込み (tramp-cache.el:636-670) と書き出し
;;   (tramp-cache.el:551-595)、接続情報の再利用
;;   (tramp-get-connection-property / with-tramp-connection-property) には
;;   一切関与しない。つまり「補完の候補ソースとして使うのをやめる」以上の
;;   意味は無く、2 回目のアクセスが速いことにも影響しない。
;;
;;   my/tramp-merge-cached-user-host を nil に戻したときに素の挙動へ戻せるよう、
;;   書き換える前の値を覚えておく (2-1 節の「自分が入れた分だけ戻す」と同じ思想)。
;;
;; 要らなくなったエントリの削除:
;;   M-x my/tramp-forget-cached-connections 。削除自体は公式 API の
;;   tramp-cleanup-connection (tramp-cmds.el:86-153) に任せる。
;;   TRAMP 標準の M-x tramp-cleanup-connection では消せない。あちらの
;;   interactive 部は候補を tramp-list-connections (tramp-cache.el:540-549) で
;;   作るが、あの関数は "process-buffer" プロパティを持つ接続 = 今まさに
;;   繋がっている接続しか返さないため、前回の起動で作られて persistency
;;   ファイルから読み直しただけのエントリは一覧に出てこない (実測で nil)。
;;   なので候補は tramp-cache-data を自分で走査して作る。
;;
;;   削除後は tramp-dump-connection-properties (tramp-cache.el:551-595) を
;;   その場で呼んで var/tramp/persistency.el に書き戻す。
;;   kill-emacs-hook (tramp-cache.el:597-598) 任せにすると、Emacs が
;;   異常終了したときに次回起動でそのエントリが復活する。
;; -----------------------------------------------------------------------------

;; tramp-cache.el / tramp-cmds.el は (require 'tramp) では読まれない (実測)。
;; 実体は autoload 経由で来るので、ここはバイトコンパイル用の宣言だけ。
(defvar tramp-cache-data)
(defvar tramp-completion-use-cache)
(declare-function tramp-make-tramp-file-name "tramp" (&rest args))
(declare-function tramp-dissect-file-name "tramp" (name &optional nodefault))
(declare-function tramp-cleanup-connection "tramp-cmds"
                  (vec &optional keep-debug keep-password keep-processes))
(declare-function tramp-flush-connection-properties "tramp-cache" (key))
(declare-function tramp-dump-connection-properties "tramp-cache" ())
;; cl-defstruct tramp-file-name (tramp.el:1122-1130) のアクセサ。
;; 2-3 節の照合と 2-4 節の候補生成で使うだけなので宣言だけしておく。
(declare-function tramp-file-name-p "tramp" (cl-x))
(declare-function tramp-file-name-method "tramp" (cl-x))
(declare-function tramp-file-name-user "tramp" (cl-x))
(declare-function tramp-file-name-host "tramp" (cl-x))
(declare-function tramp-file-name-port "tramp" (cl-x))
(declare-function tramp-file-name-localname "tramp" (cl-x))
(declare-function tramp-tramp-file-p "tramp" (name))
(defvar tramp-postfix-user-format)

;; ★ ここから下では TRAMP パスの判定・分解に file-remote-p を使わない
;;   (2-3 / 2-4 節共通の掟。ローカルパスに対して呼ぶ分には無害)
;;   file-remote-p はリモートパスかどうかを調べるだけに見えて、内部で
;;   tramp-get-hash-table (tramp-cache.el:125-141) を呼び、tramp-cache-data に
;;   そのホストのハッシュテーブルを新規作成する副作用がある (実測)。
;;   しかも新規作成時は tramp-connection-properties から seed するので、
;;   2-1 節で login-args を登録した 192.168.0.10 に対して呼ぶと、
;;   一度も繋いでいないのにプロパティ 1 件を持つキーが生える。
;;   my/tramp-cached-connection-vectors の「プロパティ 0 件は落とす」ガードを
;;   すり抜けるため、繋いだ覚えの無い /scp:192.168.0.10: が補完候補と
;;   M-x my/tramp-forget-cached-connections の一覧に出てしまう (実測)。
;;   tramp-tramp-file-p (正規表現照合のみ) と tramp-dissect-file-name は
;;   どちらもハッシュを作らない (実測) ので、判定と分解はこの 2 つで行う。

(defun my/tramp--dissect (name)
  "NAME が TRAMP パスなら `tramp-file-name' 構造体を、そうでなければ nil を返す。
接続もキャッシュへの書き込みも起こさない。上のコメントを参照。
tramp 未ロードのまま呼ばれても動くよう、ここで require しておく
\(ロード済みなら memq 1 回で済むので繰り返し呼んでも安い)。"
  (require 'tramp)
  (when (and (stringp name) (tramp-tramp-file-p name))
    (ignore-errors (tramp-dissect-file-name name))))

(defcustom my/tramp-merge-cached-user-host t
  "接続キャッシュ由来のホスト補完候補を user@host の 1 候補にまとめるか。

non-nil (既定):
  組み込みの `tramp-parse-connection-properties' を止め
  (`tramp-completion-use-cache' を nil にする)、代わりに
  `my/tramp-parse-cached-connections' を補完ソースに使う。
  /sshx:yamazaki@192.168.0.10: が 1 候補として出る。

nil:
  素の TRAMP の挙動に戻す。同じ履歴が \"yamazaki@\" と
  \"192.168.0.10:\" の 2 候補に割れて出る。

キャッシュを補完に使うのを完全にやめたいときは、この変数ではなく
TRAMP 本体の `tramp-completion-use-cache' を nil にする
(この変数が nil のときは書き換えないので、素の setq がそのまま効く)。

~/.emacs.local-inits/NN_*.el 側での設定例:

  (setq my/tramp-merge-cached-user-host nil)

候補の中身は補完のたびに読み直される (遅延評価)。
この変数自体は after-init-hook で読み直されるので、
local-inits 側は setq するだけでよい。"
  :type 'boolean
  :group 'tramp)

(defvar my/tramp--completion-use-cache-original 'unset
  "自分が書き換える前の `tramp-completion-use-cache' の値。
シンボル unset は「まだ書き換えていない」ことを表す。
nil / t と区別する必要があるので専用のシンボルを使う。")

(defun my/tramp-apply-cache-completion-source ()
  "`tramp-completion-use-cache' を `my/tramp-merge-cached-user-host' に合わせる。
まとめる設定のときは組み込みの前置 parse 関数を止め、
戻す設定のときは自分が書き換える前の値に復元する。
何度呼んでも同じ状態になる (冪等)。"
  (if my/tramp-merge-cached-user-host
      (progn
        (when (eq my/tramp--completion-use-cache-original 'unset)
          (setq my/tramp--completion-use-cache-original tramp-completion-use-cache))
        (setq tramp-completion-use-cache nil))
    (unless (eq my/tramp--completion-use-cache-original 'unset)
      (setq tramp-completion-use-cache my/tramp--completion-use-cache-original)
      (setq my/tramp--completion-use-cache-original 'unset))))

(defun my/tramp-cached-connection-vectors ()
  "接続キャッシュに載っている接続の `tramp-file-name' 構造体を集めて返す。
キーの判定条件は組み込みの `tramp-parse-connection-properties'
(tramp-cache.el:615-627) と `tramp-list-connections' (tramp-cache.el:540-549)
に揃えてある。ただし \"process-buffer\" の有無は見ない。見てしまうと
今まさに繋がっている接続しか拾えず、persistency ファイルから読み直した
過去のエントリが対象外になる。

ホストが nil のキーと `tramp-methods' に無いメソッドのキーを外すのは、
接続ではない内部用のキー (tramp-cache.el:53-63 の tramp-null-hop や
method \"cache\" のバージョン記録) を混ぜないため。

プロパティが 0 件のキーも外す。tramp-get-hash-table (tramp-cache.el:125-141)
は問い合わせの副作用で空のハッシュを作るので、file-remote-p や
tramp-get-method-parameter をリモートパスに対して呼んだだけで、繋いでも
いない接続のキーが生える。組み込みの `tramp-parse-connection-properties'
はそれも候補にするが、履歴として意味が無いのでここでは落とす。

`tramp-cache-data' を読むためにここで tramp-cache を require する。
tramp.el 側は tramp-cache を require していないので、この 1 箇所に集約する。"
  (require 'tramp-cache)
  (let ((tramp-verbose 0))
    (delq nil
          (mapcar
           (lambda (key)
             (and (tramp-file-name-p key)
                  (not (tramp-file-name-localname key))
                  (tramp-file-name-host key)
                  (assoc (tramp-file-name-method key) tramp-methods)
                  (let ((props (gethash key tramp-cache-data)))
                    (and (hash-table-p props)
                         (not (zerop (hash-table-count props)))))
                  key))
           (hash-table-keys tramp-cache-data)))))

(defun my/tramp-parse-cached-connections (method)
  "接続キャッシュの METHOD のエントリを ((\"\" \"user@host\") ...) 形式で返す。
USER を空文字列にしてホスト側に user@host をまとめて書くのが要点。
理由は 2-3 節の頭のコメントに書いてある。
`my/tramp-merge-cached-user-host' が nil のときは何も返さない
(そのときは組み込みの `tramp-parse-connection-properties' が働く)。
変数もキャッシュもこの関数が呼ばれた時点で読む (遅延評価)。"
  (when my/tramp-merge-cached-user-host
    (mapcar
     (lambda (vec)
       (let ((user (tramp-file-name-user vec))
             (host (tramp-file-name-host vec)))
         (list "" (if user
                      ;; "@" は直書きせず TRAMP の書式変数から取る。
                      ;; tramp-syntax によって区切りが変わるため。
                      (concat user tramp-postfix-user-format host)
                    host))))
     (seq-filter (lambda (vec)
                   (string-equal method (tramp-file-name-method vec)))
                 (my/tramp-cached-connection-vectors)))))

(defun my/tramp-forget-cached-connections (names)
  "接続キャッシュのエントリを選んで消す。
NAMES は \"/sshx:user@host:\" 形式の文字列のリスト。
対話的に呼ぶとキャッシュ済みの接続を一覧し、カンマ区切りで複数選べる。

消えるもの: その接続のファイルキャッシュ・接続プロパティ・
プロセス・バッファ・パスワードキャッシュ。
`tramp-clear-passwd' (tramp.el:6863-6876) は auth-source の
キャッシュを忘れるだけで ~/.authinfo 自体は書き換えない。

消えないもの: ~/.ssh/config と `my/tramp-extra-hosts' 由来の補完候補。
あれはキャッシュではないので、消したいならそちらを編集する。"
  (interactive
   (let ((names (mapcar (lambda (vec) (tramp-make-tramp-file-name vec 'noloc))
                        (my/tramp-cached-connection-vectors))))
     (list (and names
                (completing-read-multiple
                 "忘れる接続 (カンマ区切りで複数可): " names nil t)))))
  (require 'tramp-cmds)
  ;; completing-read-multiple は空入力に対して ("") を返しうるので落とす
  (setq names (delete "" (delq nil names)))
  (if (null names)
      (message "消せる接続キャッシュがありません")
    (dolist (name names)
      (let ((vec (tramp-dissect-file-name name)))
        ;; tramp-dissect-file-name の結果は localname が "" になるが、
        ;; tramp-cleanup-connection の先の tramp-file-name-unify
        ;; (tramp.el:1565-1584) が localname と hop を落とすので、
        ;; tramp-cache-data のキーと equal になる (実測済み)。
        (tramp-cleanup-connection vec)
        ;; ここでもう一度流す理由 (これが無いと消えない。実測で確認済み):
        ;;   tramp-cleanup-connection は最後に
        ;;   tramp-cleanup-connection-hook を走らせる (tramp-cmds.el:152)。
        ;;   このフックには tramp-recentf-cleanup (tramp-integration.el:166-171,
        ;;   180-181) が入っていて recentf-cleanup を呼ぶ。recentf に
        ;;   今消したホストのファイルが残っていると、その判定のために
        ;;   リモートパスへ問い合わせが飛び、tramp-get-hash-table の副作用で
        ;;   空のキーが生え直す。結果 remhash した直後に復活して
        ;;   persistency ファイルにも (キー nil) の形で書き戻されてしまう。
        (tramp-flush-connection-properties vec)))
    ;; メモリ上から消しただけでは足りない。その場で書き戻す。
    (tramp-dump-connection-properties)
    (message "接続キャッシュから %d 件消しました: %s"
             (length names) (mapconcat #'identity names " "))))

;; -----------------------------------------------------------------------------
;; 2-3-1. embark から 1 件だけ消す (M-o X)
;;
;; 何がしたいか:
;;   C-x C-f /sshx: と打って補完候補が並んでいるとき、要らないホストにカーソルを
;;   合わせて M-o X で消す。M-x my/tramp-forget-cached-connections を呼んで
;;   もう一度ホスト名を選び直す手間が無くなる。
;;
;; なぜラッパーが要るか (直接バインドすると壊れる):
;;   embark は「アクションが commandp なら、対象文字列をミニバッファに流し込んで
;;   そのコマンドを普通に実行する」という作りになっている (embark.el:embark--act の
;;   inject クロージャ)。流し込んだ直後に post-command-hook で exit-minibuffer を
;;   走らせるので、アクション側の interactive が読むミニバッファは 1 個だけ、
;;   しかも入力は対象文字列そのもの、という前提になる。
;;   my/tramp-forget-cached-connections の interactive は completing-read-multiple
;;   を REQUIRE-MATCH t で使っている。ここに "/sshx:..." が流し込まれても、
;;   候補集合に無い文字列だと exit-minibuffer が弾かれてミニバッファに居座る。
;;   → 単一の文字列を受け、REQUIRE-MATCH を要求しないラッパーを別に用意し、
;;     受け取った文字列を検証してから本体にリストで渡す。
;;
;; なぜガードが要るか:
;;   embark-file-map は file カテゴリの候補「全部」に効く。つまりローカルの
;;   ただのファイル上で X を押される場面が普通にある。そのまま
;;   tramp-dissect-file-name に渡すと "Not a Tramp file name" の user-error に
;;   なる (実測) が、メッセージが TRAMP 内部の話で何をしろと言われているのか
;;   分からない。キャッシュに載っていないリモートパスに至っては
;;   tramp-cleanup-connection が黙って成功してしまい、消えていないのに
;;   「消しました」と出る。どちらも自前で判定して穏当に断る。
;;
;; 照合を method / user / host / port の 4 つでやる理由:
;;   キャッシュのキーは localname も hop も持たない vec (2-3 節の
;;   my/tramp-cached-connection-vectors 参照)。一方 embark の対象は
;;   /sshx:user@host:/path/to/file のようにファイル名まで含みうる。
;;   そこで file-remote-p でリモート部分だけ取り出し、接続を一意に決める
;;   4 フィールドだけを比べる。おかげでリモートのファイル候補の上で X を
;;   押しても、その接続のキャッシュが消せる。
;;
;; キー選定:
;;   X は embark-file-map にも親の embark-general-map にも未使用 (実測)。
;;   小文字の x は embark-open-externally で埋まっているので大文字を使う。
;; -----------------------------------------------------------------------------

;; embark を先読みせずにバイトコンパイルを通すための宣言のみ。実体は embark.el。
(defvar embark-file-map)

(defun my/tramp--cached-connection-for (name)
  "NAME に対応する接続キャッシュの vec を返す。該当が無ければ nil。
NAME は \"/sshx:user@host:\" でも \"/sshx:user@host:/path/file\" でもよい。
localname は無視し、接続を一意に決める method / user / host / port の
4 つだけで照合する。接続もキャッシュへの書き込みも起こさない。"
  (let ((cached (my/tramp-cached-connection-vectors))
        (vec (my/tramp--dissect name)))
    (when vec
      (seq-find
       (lambda (c)
         (and (equal (tramp-file-name-method vec) (tramp-file-name-method c))
              (equal (tramp-file-name-user vec) (tramp-file-name-user c))
              (equal (tramp-file-name-host vec) (tramp-file-name-host c))
              (equal (tramp-file-name-port vec) (tramp-file-name-port c))))
       cached))))

(defun my/tramp-forget-cached-connection (name)
  "NAME の接続キャッシュを 1 件だけ消す。`embark-act' から呼ぶ用。
削除そのものは `my/tramp-forget-cached-connections' に丸投げするので、
消える範囲も persistency ファイルへの書き戻しもあちらと同じ。

NAME がリモートパスでないとき、リモートでもキャッシュに無いときは
`user-error' で断る。embark-file-map は file カテゴリの候補全部に効くため、
ローカルファイルの上で誤って押される前提で作ってある。

M-x で直接呼ぶこともできる。その場合はキャッシュ済みの接続を候補に出すが、
REQUIRE-MATCH は要求しない (embark が候補集合の外の文字列を流し込むため)。"
  (interactive
   (list (completing-read
          "忘れる接続: "
          (mapcar (lambda (vec) (tramp-make-tramp-file-name vec 'noloc))
                  (my/tramp-cached-connection-vectors)))))
  (unless (my/tramp--dissect name)
    (user-error "リモートパスではありません: %s" name))
  (let ((vec (my/tramp--cached-connection-for name)))
    (unless vec
      (user-error "接続キャッシュに載っていません: %s" name))
    (my/tramp-forget-cached-connections
     (list (tramp-make-tramp-file-name vec 'noloc)))))

(with-eval-after-load 'embark
  (keymap-set embark-file-map "X" #'my/tramp-forget-cached-connection))

;; 既定ソースの登録は tramp.el 末尾の tramp--startup-hook で走る
;; (tramp-sh.el:459-479 が tramp-loaddefs 経由で仕込まれる)。
;; with-eval-after-load 'tramp はそのさらに後なので、こちらの上書きが勝つ。
;; 2-2 節の parse 関数も 2-3 節の parse 関数もここで初めて登録される。
(with-eval-after-load 'tramp
  (my/tramp-set-host-completion-sources)
  (my/tramp-apply-cache-completion-source))

;; my/tramp-merge-cached-user-host は「値」なので、2-1 節の
;; tramp-connection-properties と同じく after-init-hook で読み直す。
;; ~/.emacs.local-inits/ が読まれるのは inits/ を全部読んだ後
;; (init.el:81-83) なので、ここを通らないと local-inits 側の setq が
;; 間に合わない。冪等なので 2 回走っても問題ない。
(defun my/tramp-reapply-cache-completion-source ()
  "`my/tramp-apply-cache-completion-source' を after-init から呼ぶ。
`with-eval-after-load' を挟むのは、tramp が未ロードのまま after-init を
迎えた場合に `tramp-completion-use-cache' 未定義で落ちないようにするため。"
  (with-eval-after-load 'tramp
    (my/tramp-apply-cache-completion-source)))

(add-hook 'after-init-hook #'my/tramp-reapply-cache-completion-source)

;; -----------------------------------------------------------------------------
;; 2-4. consult-dir にリモートディレクトリのソースを足す
;;
;; 何が不満だったか:
;;   リモートで作業を始めるには C-x C-f /sshx: と打ってホストを補完し、
;;   さらに開始ディレクトリを手で掘る必要がある。よく行く先は決まっているのに
;;   毎回同じ道順を打っている。C-x C-d (consult-dir) には「ディレクトリを選んで
;;   そこから始める」導線が既にあるので、そこにリモートを流し込めば済む。
;;   → consult-dir-sources に独自ソースを 1 本足す。キーバインドは増やさない。
;;
;; なぜ consult-dir 同梱の consult-dir--source-tramp-ssh を使わないか:
;;   あれは ~/.ssh/config しか見ず (consult-dir.el:207-209)、
;;   2-2 節で用意した my/tramp-extra-hosts / my/tramp-extra-ssh-config-files を
;;   拾わない。開始ディレクトリもホスト共通で 1 つ (consult-dir.el:201-204) しか
;;   持てず、「このホストはここから」を書き分けられない。
;;   そもそも consult-dir-sources の既定値 (consult-dir.el:142-147) に
;;   入っていないので、有効にするには結局こちらで add-to-list する必要がある。
;;   同じ手間なら補完ソースの定義が 2-2 節と食い違わない自前のものを足す。
;;
;; 明示指定 (my/tramp-remote-entries) と自動生成の二階建てにした理由:
;;   ~/.ssh/config に Host エントリがあるホストは、書かなくても候補に出てほしい。
;;   一方でよく行く先は "/sshx:yamazaki@192.168.0.10:/Users/yamazaki/src/" のように
;;   ディレクトリまで込みで一発で開きたい。前者を自動生成、後者を明示指定にして、
;;   同じホストが両方から出たときは明示指定を優先する (ホスト名で重複を落とす)。
;;
;; 自動生成分の method に tramp-default-method を使う理由:
;;   1. 真実を 1 箇所に寄せる。method を変えたいときに触る変数が増えない。
;;   2. consult-dir 本体の consult-dir--tramp-parse-config (consult-dir.el:201) も
;;      tramp-default-method を使っており、既定ソースと挙動が揃う。
;;   3. これが決定的。2-1 節の Windows 向け login-args 上書きは
;;      my/tramp-windows-workaround-methods (既定 '("ssh" "scp")) のメソッドにしか
;;      登録されない。この環境の tramp-default-method は "scp" なので上書きが効く。
;;      ここで method を固定値 (例えば "sshx") にすると 2-1 節の対象から外れ、
;;      せっかく直したハングが候補経由の接続でだけ再発する。
;;   固定したい場合は my/tramp-remote-default-method に文字列を入れる。その際は
;;   my/tramp-windows-workaround-methods にも同じ method を足すこと。
;;
;; ★ 遅延評価にしてある理由 (2-2 / 2-3 節と同じ話)
;;   consult-dir-sources に入れるのは「シンボル」で、consult--multi は毎回
;;   symbol-value で plist を引き直し、:items の関数をその場で呼ぶ。
;;   よって :items の中で defcustom を読めば、~/.emacs.local-inits/ 側の setq が
;;   後から効く。ここで候補リストを焼き込むと 2-2 節と同じ理由で
;;   local-inits が間に合わなくなる (init.el:81-83 の方が後に走るため)。
;;   ~/.ssh/config の編集も同じ理由で即時反映される。
;;
;; narrow key に ?h を選んだ理由:
;;   既に埋まっているのは ?t (Tab dirs) ?g (Global dirs) ?m (Bookmarks)
;;   ?. (This directory/project) ?p (Projects) ?r (Recentf dirs) ?l (Local) の 7 つ。
;;   ?s は consult-dir 同梱の consult-dir--source-tramp-ssh (consult-dir.el:352) が
;;   使う予約席で、今は consult-dir-sources に入っていないが、後で有効にされたときに
;;   ぶつかるので避ける。残りから host の h を取った。
;;
;; プレビューでリモートに繋がる心配はない:
;;   consult-dir のソースはどれも :state を持たない (実測) のでプレビュー自体が
;;   起きない。仮に起きても consult-preview-excluded-files の既定値
;;   '("\\`/[^/|:]+:" "\\.gpg\\'") の 1 本目がリモートパス全部を弾く。
;;   ここで作る候補文字列は必ず "/METHOD:" で始まるので確実にマッチする。
;; -----------------------------------------------------------------------------

;; consult-dir / tramp を先読みせずにバイトコンパイルを通すための宣言のみ。
(defvar consult-dir-sources)
(defvar tramp-default-method)
(defvar tramp-prefix-format)
(defvar tramp-postfix-method-format)
(defvar tramp-postfix-host-format)

(defcustom my/tramp-remote-entries nil
  "consult-dir (C-x C-d) に出すリモートディレクトリの alist。
要素は (LABEL . TRAMP-DIR) 。LABEL は一覧の右側に出る注釈で、
TRAMP-DIR は開始ディレクトリまで込みの TRAMP パス。

ここに書いたホストは自動生成分より優先される (同じホストの
自動生成候補は落とされる)。method も開始ディレクトリも 1 件ずつ
自由に決められるので、下記の defcustom の影響を受けない。

環境固有の値なのでこのファイルには書かず
~/.emacs.local-inits/NN_*.el 側に書く。設定例:

  (setq my/tramp-remote-entries
        \\='((\"mac mini: src\" . \"/sshx:yamazaki@192.168.0.10:/Users/yamazaki/src/\")
          (\"s26: /var/log\"  . \"/scp:s26:/var/log/\")))

値は C-x C-d のたびに読み直される (遅延評価) ので、
setq するだけでよく再登録も再起動も要らない。"
  :type '(alist :key-type (string :tag "ラベル")
                :value-type (string :tag "TRAMP ディレクトリ"))
  :group 'tramp)

(defcustom my/tramp-remote-default-method nil
  "自動生成分の候補に使う TRAMP method 名。
nil (既定) なら `tramp-default-method' に従う。

固定したいときだけ文字列を入れる。その場合は 2-1 節の
`my/tramp-windows-workaround-methods' にも同じ method を足すこと。
足さないと Windows 向けの login-args 上書きが効かず、
この候補から繋いだときだけ ssh がハングする。

~/.emacs.local-inits/NN_*.el 側での設定例:

  (setq my/tramp-remote-default-method \"sshx\")

値は C-x C-d のたびに読み直される (遅延評価)。"
  :type '(choice (const :tag "tramp-default-method に従う" nil)
                 (string :tag "method 名"))
  :group 'tramp)

(defcustom my/tramp-remote-default-path "~/"
  "自動生成分の候補の開始ディレクトリ (リモート側のパス)。
末尾の / は付けたままにしておくこと。consult-dir は選んだ文字列を
ミニバッファのプレフィックスとして差し込むので、/ が無いと
続けて打ったファイル名がホームの名前とくっついてしまう。

~/.emacs.local-inits/NN_*.el 側での設定例:

  (setq my/tramp-remote-default-path \"/var/log/\")

値は C-x C-d のたびに読み直される (遅延評価)。"
  :type 'string
  :group 'tramp)

(defun my/tramp--remote-make-dir (method user host path)
  "METHOD / USER / HOST / PATH から TRAMP のディレクトリ文字列を組み立てる。
区切り記号は直書きせず TRAMP の書式変数から取る。`tramp-syntax' を
default 以外にすると区切りが変わるため。USER が nil か空文字列なら省く。"
  (concat tramp-prefix-format method tramp-postfix-method-format
          (if (and (stringp user) (not (string-empty-p user)))
              (concat user tramp-postfix-user-format)
            "")
          host tramp-postfix-host-format path))

(defun my/tramp--remote-auto-dirs ()
  "~/.ssh/config と 2-2 節の 2 変数からリモートディレクトリ候補を自動生成する。
解析は 2-2 節の parse 関数をそのまま再利用する。あちらは引数が
&optional なので引数無しで呼べる (実測済み)。

`tramp-parse-sconfig' は Host 行以外を (nil nil) として返すので、
ホスト名を持たない要素を落とす。全ての変数をこの関数が呼ばれた
時点で読む (遅延評価)。"
  (require 'tramp)
  (let ((method (or my/tramp-remote-default-method tramp-default-method))
        (path (or my/tramp-remote-default-path ""))
        (config (my/tramp-ssh-config-file)))
    (delete-dups
     (delq nil
           (mapcar
            (lambda (entry)
              (let ((user (car entry))
                    (host (cadr entry)))
                (when (and (stringp host) (not (string-empty-p host)))
                  (my/tramp--remote-make-dir method user host path))))
            (append (when (and (not (file-remote-p config))
                               (file-readable-p config))
                      (tramp-parse-sconfig config))
                    (my/tramp-parse-extra-hosts)
                    (my/tramp-parse-extra-ssh-config-files)))))))

(defun my/tramp--remote-host (dir)
  "DIR のホスト名を返す。TRAMP パスでなければ nil。
file-remote-p を使わないのは 2-3 節の頭に書いた副作用のため。
C-x C-d は候補全部に対してこれを呼ぶので、file-remote-p のままだと
一覧を開くたびに tramp-cache-data が汚れる。"
  (when-let* ((vec (my/tramp--dissect dir)))
    (tramp-file-name-host vec)))

(defun my/tramp-remote-dirs ()
  "consult-dir ソースの :items 。リモートディレクトリの文字列リストを返す。
`my/tramp-remote-entries' に書いたものを先に並べ、その後ろに
自動生成分のうち「まだ出ていないホスト」だけを足す。
全ての変数をこの関数が呼ばれた時点で読む (遅延評価)。"
  (require 'tramp)
  (let* ((explicit (delq nil
                         (mapcar (lambda (entry)
                                   (and (consp entry) (stringp (cdr entry))
                                        (cdr entry)))
                                 my/tramp-remote-entries)))
         (hosts (delq nil (mapcar #'my/tramp--remote-host explicit))))
    (append explicit
            (seq-remove (lambda (dir)
                          (member (my/tramp--remote-host dir) hosts))
                        (my/tramp--remote-auto-dirs)))))

(defun my/tramp-remote-dir-annotation (dir)
  "DIR に対応する `my/tramp-remote-entries' のラベルを返す。
自動生成分にはラベルが無いので nil を返す (注釈が出ないだけ)。"
  (car (rassoc dir my/tramp-remote-entries)))

(defvar my/consult-dir--remote-source
  `( :name     "Remote dirs"
     :narrow   ?h
     :category file
     :face     consult-file
     :history  file-name-history
     :items    ,#'my/tramp-remote-dirs
     :annotate ,#'my/tramp-remote-dir-annotation)
  "リモートディレクトリを返す consult-dir ソース。
:items も :annotate も関数で持つので、呼ばれるたびに defcustom を
読み直す (遅延評価)。詳細は 2-4 節の頭のコメントに書いてある。")

;; 末尾に足す (add-to-list の APPEND 引数 t)。ローカルの候補を押しのけないため。
;; inits/my-utils/tab-dir-util.el:213-216 も同じ with-eval-after-load で
;; 先頭に 2 本足しているが、あちらは 02_vertico.el 経由で先に読まれる。
;; init-loader はファイル名順なので 30_ はどちらより後で、順序の心配は要らない。
(with-eval-after-load 'consult-dir
  (add-to-list 'consult-dir-sources 'my/consult-dir--remote-source t))

;; -----------------------------------------------------------------------------
;; 2-5. リモートバッファの git 情報 (ブランチ / 変更量) を遅延表示
;;
;; 2 節冒頭 (leaf tramp) で vc をリモート無効化した代償として、モードラインの
;; ブランチ表示が消える。遅さの原因は「開く/保存のたびに vc-git が同期で
;; ssh 越しの git を何回も走らせる」ことなので、こうする:
;;   - 開いた直後は何もしない (体感ゼロ)
;;   - アイドルタイマーで git を非同期に 1 回だけ実行
;;   - 結果を vc-mode にただの文字列として入れる (デフォルトのモードラインは
;;     (vc-mode vc-mode) を表示するので、vc 本体が動かなくても文字列は出る)
;;
;; 表示例: " Git@main +12-3 [4]"
;;   Git@main … ブランチ名。vc 本来の "Git-main"(未変更)/"Git:main"(変更あり)
;;               と記号を変えてあり、vc ではないと分かるようにしている
;;   +12-3    … このファイルの HEAD からの変更行数 (追加/削除)
;;   [4]      … リポジトリ全体の変更ファイル数 (untracked は数えない)
;;
;; ★ なぜ 3 つの値を 1 コマンドにまとめるか (ここが性能の肝)
;;   TRAMP の start-file-process は「既存の ssh 接続でコマンドを 1 本流す」
;;   ものではない。tramp-sh-handle-make-process (tramp-sh.el:3065-) は
;;   process-name/process-buffer を差し替えたうえで接続を開くので、
;;   非同期プロセス 1 個につき ssh セッションが 1 本増え、TRAMP のシェル
;;   初期化 (プロンプト設定・stty・echo $$ など) が毎回走る。ControlMaster が
;;   効いていても TCP/認証が省けるだけで、この初期化の往復は省けない。
;;   しかも接続確立部分は同期で、その間 Emacs は待たされる。
;;   → プロセスを起こす回数がそのままコストなので、git を 3 回呼ぶとしても
;;     sh -c で 1 プロセスにまとめる。リモート側の git 実行自体は安い
;;     (この程度の repo なら 3 コマンド合計で 30ms 程度)。
;;
;; ★ なぜ定期更新 (タイマー) をしないか
;;   上のとおり 1 回の更新が「ssh セッション 1 本 + 同期の待ち」なので、
;;   数十秒おきに回すと編集中に不定期な引っかかりが出る。しかも TRAMP は
;;   ホスト単位で処理が直列化されるため、裏の git が走っている間は
;;   C-x C-f などの操作がその後ろに並ぶ。
;;   数字が変わるのは基本的に自分が保存したときなので、after-save-hook で
;;   取り直せば十分かつ正確。他端末で入った変更を反映したいときだけ
;;   M-x my/tramp-branch-refresh を手で叩く。
;;
;; キャッシュはファイル単位。変更行数はファイルごとに違うのでディレクトリ単位に
;; できない。同じ repo の別ファイルを開くと git はもう一度走るが、代わりに
;; 表示は常にそのファイルのものになる。
;;
;; ここでの file-remote-p は 2-3 節で避けた話と違い問題ない。あちらは未接続の
;; 「候補文字列」に対して呼ぶと tramp-cache-data が汚れるという話で、
;; ここで呼ぶ相手は接続済みバッファの buffer-file-name。
;; -----------------------------------------------------------------------------

(defvar my/tramp-branch-idle-delay 1
  "git 情報の取得を始めるまでのアイドル秒数。
開いた直後/保存直後ではなくアイドルまで待つのは、TRAMP のプロセス起動が
接続確立の間だけ同期で止まるため。操作の手が止まってから走らせる。")

(defcustom my/tramp-branch-show-stats t
  "非 nil なら変更行数とリポジトリの変更ファイル数も表示する。
nil ならブランチ名だけになる (git の実行回数は変わらない)。"
  :type 'boolean
  :group 'tramp)

(defvar my/tramp-branch--cache (make-hash-table :test #'equal)
  "リモートファイル名 → 表示情報のキャッシュ。
値は plist (:branch :added :deleted :files)、pending (取得中)、
none (リポジトリ外・git 不在・接続不可) のいずれか。")

;; 区切りに @@ の行を挟んで 3 ブロックを 1 回の出力で受け取る。
;;
;; exec 2>/dev/null はリポジトリ外のときの git のエラー文を混ぜないため
;; (stderr は start-file-process だと同じバッファに来てしまう)。
;; git diff に HEAD を付けるのは index に上げた分も変更として数えるため。
;; git status の -uno は untracked を数えない指定。作業ツリー全体を歩く
;; untracked 探索が status の一番重い部分なので、大きい repo では効く。
;;
;; --no-pager と color.ui=false が要る理由 (実測で踏んだ):
;;   プロセスに pty が付くと git は「端末に出力している」と判断し、
;;   ページャを起動して色も付ける。すると出力に less の制御シーケンスが
;;   混ざり ("\e[?1h=" や "\e[K\e[?1l>")、区切りの @@ が行頭に来なくなって
;;   パースが必ず失敗する。--fetch 側で pty を切って (process-connection-type)
;;   根本を断ってあるが、リモートの git 設定が pager.diff や
;;   color.ui=always を強制している場合に備えてコマンド側でも殺しておく。
(defconst my/tramp-branch--command
  (concat "exec 2>/dev/null; "
          "git --no-pager rev-parse --abbrev-ref HEAD; echo @@; "
          "git --no-pager -c color.ui=false diff HEAD --numstat -- %s; echo @@; "
          "git --no-pager status --porcelain -uno | wc -l")
  "git 情報を 1 度に取るシェルコマンド。%s にファイル名が入る。")

(defun my/tramp-branch--parse (output)
  "git の OUTPUT を plist にする。解釈できなければ nil を返す。"
  (let ((parts (split-string output "^@@$")))
    (when (= (length parts) 3)
      (let* ((branch (string-trim (nth 0 parts)))
             (numstat (string-trim (nth 1 parts)))
             (files (string-to-number (string-trim (nth 2 parts))))
             ;; numstat は "追加\t削除\tパス"。変更が無ければ空。
             ;; バイナリは "-" が入るが string-to-number が 0 にしてくれる。
             (fields (unless (string-empty-p numstat)
                       (split-string numstat "[ \t\n]+" t))))
        (unless (string-empty-p branch)
          (list :branch  branch
                :added   (if fields (string-to-number (nth 0 fields)) 0)
                :deleted (if fields (string-to-number (nth 1 fields)) 0)
                :files   files))))))

(defun my/tramp-branch--format (info)
  "INFO (plist) をモードラインに出す文字列にする。"
  (let ((added   (plist-get info :added))
        (deleted (plist-get info :deleted))
        (files   (plist-get info :files)))
    (concat " Git@" (plist-get info :branch)
            (when my/tramp-branch-show-stats
              (concat (when (or (> added 0) (> deleted 0))
                        (format " +%d-%d" added deleted))
                      (when (> files 0)
                        (format " [%d]" files)))))))

(defun my/tramp-branch--display (file info)
  "FILE を訪問しているバッファのモードラインに INFO を反映する。"
  (let ((text (my/tramp-branch--format info)))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (equal buffer-file-name file)
          (setq vc-mode text)
          (force-mode-line-update))))))

(defun my/tramp-branch--sentinel (proc _event)
  "git の終了を受けてキャッシュとモードラインを更新する。"
  (when (memq (process-status proc) '(exit signal))
    (let ((file   (process-get proc 'my/tramp-branch-file))
          (report (process-get proc 'my/tramp-branch-report))
          (buf    (process-buffer proc)))
      (unwind-protect
          (let* ((output (and (buffer-live-p buf)
                              (with-current-buffer buf (buffer-string))))
                 (info (and output (my/tramp-branch--parse output))))
            (cond (info
                   (puthash file info my/tramp-branch--cache)
                   (my/tramp-branch--display file info)
                   (when report
                     (message "my/tramp-branch: %s →%s"
                              file (my/tramp-branch--format info))))
                  ;; リポジトリ外・git 不在など。再試行はしない
                  (t (puthash file 'none my/tramp-branch--cache)
                     (when report
                       (message "my/tramp-branch: git 失敗 (exit %s): %s"
                                (process-exit-status proc)
                                (if output (string-trim output) "(出力なし)"))))))
        (when (buffer-live-p buf)
          (kill-buffer buf))))))

(defun my/tramp-branch--fetch (file &optional report)
  "FILE の git 情報を非同期に取得する。取得済み/取得中なら何もしない。
REPORT が非 nil なら結果をエコーエリアに報告する (refresh 用)。"
  (unless (gethash file my/tramp-branch--cache)
    (puthash file 'pending my/tramp-branch--cache)
    (condition-case err
        (let* ((default-directory (file-name-directory file))
               ;; pty を付けない。付けると git がページャと色を有効にして
               ;; 出力に制御シーケンスが混ざる (--command のコメント参照)。
               ;; TRAMP 側も connection-type が pipe なら CR→LF 変換を
               ;; 行わない (tramp-sh.el:3099-) ので、解析にはこちらが素直。
               (process-connection-type nil)
               (proc (start-file-process
                      "my/tramp-branch" (generate-new-buffer " *my/tramp-branch*")
                      "sh" "-c"
                      (format my/tramp-branch--command
                              (shell-quote-argument
                               (file-name-nondirectory file))))))
          (process-put proc 'my/tramp-branch-file file)
          (process-put proc 'my/tramp-branch-report report)
          (set-process-sentinel proc #'my/tramp-branch--sentinel))
      ;; 接続が切れている等でプロセスを起こせない場合。再試行しない
      (error (puthash file 'none my/tramp-branch--cache)
             (when report
               (message "my/tramp-branch: プロセス起動に失敗: %S" err))))))

(defun my/tramp-branch--schedule (file)
  "FILE の git 情報取得をアイドル時に予約する。"
  (run-with-idle-timer my/tramp-branch-idle-delay nil
                       #'my/tramp-branch--fetch file))

(defun my/tramp-branch--after-find-file ()
  "`find-file-hook': リモートファイルなら git 情報を遅延表示する。"
  (when (and buffer-file-name (file-remote-p buffer-file-name))
    (let ((cached (gethash buffer-file-name my/tramp-branch--cache)))
      (cond ((consp cached)                     ; 取得済み → 即表示
             (setq vc-mode (my/tramp-branch--format cached)))
            ((null cached)                      ; 未取得 → アイドル時に取得
             (my/tramp-branch--schedule buffer-file-name))
            ;; pending 中に開いたバッファは sentinel の --display が拾う。
            ;; none は何もしない (再試行は my/tramp-branch-refresh で)
            ))))

(defun my/tramp-branch--after-save ()
  "`after-save-hook': 保存で変わった変更量を取り直す。
保存処理そのものを待たせないよう、取得はアイドルまで遅らせる。"
  (when (and buffer-file-name (file-remote-p buffer-file-name))
    (remhash buffer-file-name my/tramp-branch--cache)
    (my/tramp-branch--schedule buffer-file-name)))

(add-hook 'find-file-hook #'my/tramp-branch--after-find-file)
(add-hook 'after-save-hook #'my/tramp-branch--after-save)

(defun my/tramp-branch-refresh ()
  "現在のバッファの git 情報を取り直し、結果を報告する。
リモート側でブランチを切り替えた後、他端末で入った変更を反映したいとき、
表示が出ないときの切り分けに使う。"
  (interactive)
  (unless (and buffer-file-name (file-remote-p buffer-file-name))
    (user-error "リモートファイルのバッファで実行してください"))
  (remhash buffer-file-name my/tramp-branch--cache)
  (message "my/tramp-branch: %s で git を実行中..." buffer-file-name)
  (my/tramp-branch--fetch buffer-file-name t))
;; -----------------------------------------------------------------------------
;; 2-6. リモートファイルは既定で read-only (view-mode) で開く
;;
;; 狙い: リモートは「まず読む」場所。ローカルと同じ気軽さで書けてしまうと
;;   うっかり編集の被害が大きいので、開いた時点で一段ブレーキを掛けておく。
;;   編集したくなったら C-x C-q を 1 回。
;;
;; read-only-mode ではなく view-mode を使う理由:
;;   1. C-x C-q (94_keybinds.el:31) は view-mode に割り当ててある。
;;      read-only-mode で読み取り専用にすると、C-x C-q はまだ off の
;;      view-mode を「有効化」するだけで読み取り専用のまま。編集に移るのに
;;      2 回押すことになる。最初から view-mode で開けば 1 回で済む。
;;   2. 02_packages.el の viewer 設定で view-mode に vim 風の移動キー
;;      (j/k/b/u など) を入れてあるので、読むだけなら view-mode の方が速い。
;;   3. 見た目は 03_view-visual.el が buffer-read-only 全般を見ているので、
;;      read-only-mode でも view-mode でも同じ (背景色 + カーソル赤) になる。
;;
;; viewer.el の view-mode-by-default-regexp (02_packages.el:20) に TRAMP の
;; パターンを足す手もあるが、あれは正規表現 1 本で拡張子の話と混ざって
;; 読みにくくなるうえ、下の「新規作成は除外」を表現できないので独立させた。
;;
;; 書込不可ファイルの扱い:
;;   viewer-stay-in-setup (02_packages.el:24) の advice が view-mode からの
;;   離脱を止めるのは file-writable-p が nil のときだけ (viewer.el:283-291)。
;;   普通に書けるリモートファイルなら C-x C-q でそのまま編集に移れる。
;; -----------------------------------------------------------------------------

(defcustom my/tramp-open-read-only t
  "非 nil ならリモートファイルを view-mode (読み取り専用) で開く。
編集に移るには C-x C-q 。"
  :type 'boolean
  :group 'tramp)

(defun my/tramp--find-file-read-only ()
  "`find-file-hook': リモートの既存ファイルを view-mode で開く。

新規作成 (まだ存在しないパス) を除くのは、書くために開いたのが明らかだから。
file-exists-p の追加コストは無視できる。find-file がここに来るまでに同じ
属性を引いており TRAMP のキャッシュに乗っているため、通信は発生しない。"
  (when (and my/tramp-open-read-only
             buffer-file-name
             (file-remote-p buffer-file-name)
             (file-exists-p buffer-file-name)
             (not (bound-and-true-p view-mode)))
    (view-mode 1)))

(add-hook 'find-file-hook #'my/tramp--find-file-read-only)

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
