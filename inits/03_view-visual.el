;;; 03_view-visual.el --- view-mode / read-only バッファの見た目をはっきり区別する -*- lexical-binding: t; -*-
;;
;; 使い方:
;;   下の「設定テンプレ」セクションの色を書き換えるだけで表示が切り替わります。
;;
;;   対象になる条件: `buffer-read-only' が t のバッファ
;;   （`read-only-mode' でも `view-mode' でも同じ）
;;
;;   背景 / hl-line … face-remap でバッファ単位に適用
;;   カーソル色     … `set-cursor-color' はフレーム単位でしか効かないため、
;;                     選択中ウィンドウのバッファの状態を見てフレームに設定する
;;
;;     read-only → red
;;     書込可    → cyan
;;
;; カーソル色をこのファイルに一本化した理由:
;;   以前は macOS の IME 切替フック (01_setup.el) が入力ソースに応じて
;;   cyan/Red を直接 `set-cursor-color' していた。read-only もカーソル色で
;;   示すとなると、両者が同じフレームパラメータを奪い合って
;;   「最後に走った方が勝つ」になる。
;;   IME の判定 (mac-input-source の戻り値) が実運用で安定しなかったため
;;   IME 連動そのものを廃止し、カーソル色は read-only かどうかだけで決める。
;;   色を触るのは `my/cursor-color-update' だけになっている。
;;

;; ------------------------------------------------------------------
;; 設定テンプレ — ここだけ書き換えれば OK
;; ------------------------------------------------------------------

(defgroup my/view-visual nil
  "read-only / view-mode バッファの視覚強調設定。"
  :group 'convenience)

;; ---- 背景 / カーソル行 ----
(defcustom my/view-visual-background "#2a2233"
  "read-only バッファの背景色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-hl-line "#3d2b4a"
  "read-only バッファでのカーソル行 (hl-line) の色。"
  :type 'color :group 'my/view-visual)

;; ファイルを開いているバッファだけ強調を変えられるようにしてある。
;; dired / bookmark / *Messages* も `buffer-read-only' なので、全部を派手にすると
;; 常時うるさい。一方で事故るのは「ファイルを開いていて編集できると思っている」
;; ときだけなので、強い合図 (行番号列の帯とヘッダの READ-ONLY) はそこにだけ出す。
;;
;; 背景そのものは強調しない方針を選んだので、既定値は下の
;; `my/view-visual-background' と同じにしてある。濃くしたければここを変える。
(defcustom my/view-visual-background-file "#2a2233"
  "read-only かつファイルを開いているバッファの背景色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-hl-line-file "#3d2b4a"
  "read-only かつファイルを開いているバッファでの hl-line の色。"
  :type 'color :group 'my/view-visual)

;; ---- 行番号列 (主役の合図) ----
;; 視線は常に左端の行番号を通るので、背景のわずかな差より確実に目に入る。
;; 本文の色を一切汚さないのも利点。
(defcustom my/view-visual-line-number-background "#1e4620"
  "read-only かつファイルを開いているバッファでの行番号列の背景色。
nil なら行番号列を変えない。"
  :type '(choice color (const nil)) :group 'my/view-visual)

(defcustom my/view-visual-line-number-foreground "#cfe8cf"
  "同じく行番号列の文字色。"
  :type 'color :group 'my/view-visual)

;; ---- モードラインの READ-ONLY 表示 ----
;; header-line には置かない。付け外しでウィンドウの中身が1行ぶん上下にずれ、
;; C-x C-q のたびに読んでいる行を見失う。モードラインなら行数が変わらない。
;; doom-modeline は `mode-line-format' ごと持っているので、こちらは face の
;; 差し替えと `mode-line-misc-info' への追記だけにする。
(defcustom my/view-visual-mode-line-badge t
  "非 nil なら read-only のファイルバッファのモードラインに READ-ONLY を出す。"
  :type 'boolean :group 'my/view-visual)

(defcustom my/view-visual-mode-line-background "#1e4620"
  "read-only のファイルバッファでのモードラインの背景色。nil なら変えない。"
  :type '(choice color (const nil)) :group 'my/view-visual)

(defcustom my/view-visual-mode-line-foreground "#d7f0d7"
  "READ-ONLY バッジの文字色。"
  :type 'color :group 'my/view-visual)

;; ---- カーソルの形 ----
;; 色 (下の `my/cursor-color-readonly') はフレーム単位でしか設定できないので、
;; ウィンドウを分割して片方だけ read-only のとき、もう片方に対して嘘をつく。
;; `cursor-type' はバッファローカルにできる (実測: `local-variable-if-set-p' = t)
;; ので、形は常に正しい。形は色より周辺視で気づきやすくもある。
(defcustom my/view-visual-cursor-type 'hbar
  "read-only バッファでのカーソルの形。nil ならカーソル形状を変えない。"
  :type 'symbol :group 'my/view-visual)

(defcustom my/view-visual-enable-hl-line t
  "非 nil なら read-only バッファで `hl-line-mode' を自動で有効化する。"
  :type 'boolean :group 'my/view-visual)

;; ---- カーソル色 ----
(defcustom my/cursor-color-readonly "red"
  "read-only バッファでのカーソル色。"
  :type 'color :group 'my/view-visual)

(defcustom my/cursor-color-writable "cyan"
  "書込可能バッファでのカーソル色。"
  :type 'color :group 'my/view-visual)

;; ------------------------------------------------------------------
;; 実装 — 背景 / hl-line (バッファ単位)
;; ------------------------------------------------------------------

(defvar-local my/view-visual--cookies nil
  "このバッファに適用した face-remap の cookie リスト。")

(defvar-local my/view-visual--hl-line-was-on nil
  "もとから `hl-line-mode' が有効だったか。")

(defvar-local my/view-visual--misc-info-set nil
  "このバッファの `mode-line-misc-info' を自分で差し替えたか。")

(defvar-local my/view-visual--cursor-type-was-local nil
  "もとから `cursor-type' がバッファローカルだったか。")

(defvar-local my/view-visual--cursor-type-orig nil
  "バッファローカルだった場合の、もとの `cursor-type'。")

(defun my/view-visual--colors ()
  "このバッファに使う (背景 . hl-line) を返す。
ファイルを開いているバッファだけ濃い方を使う。"
  (if buffer-file-name
      (cons my/view-visual-background-file my/view-visual-hl-line-file)
    (cons my/view-visual-background my/view-visual-hl-line)))

(defun my/view-visual--apply ()
  "現在のバッファを read-only スタイルにする。"
  (unless my/view-visual--cookies
    (let ((colors (my/view-visual--colors)))
      (setq my/view-visual--cookies
            (list
             (face-remap-add-relative 'default
                                      :background (car colors))
             (face-remap-add-relative 'hl-line
                                      :background (cdr colors)))))
    ;; 強い合図はファイルを開いているバッファだけ。dired や *Messages* に
    ;; READ-ONLY と出しても情報量が無く、常時うるさいだけになる。
    (when buffer-file-name
      (when my/view-visual-line-number-background
        (dolist (face '(line-number line-number-current-line))
          (push (face-remap-add-relative
                 face
                 :background my/view-visual-line-number-background
                 :foreground my/view-visual-line-number-foreground)
                my/view-visual--cookies)))
      (when my/view-visual-mode-line-background
        ;; 選択中と非選択中で使われる face が違う。両方に当てないと、
        ;; ウィンドウを移った瞬間に緑が消えて嘘をつく。
        (dolist (face '(mode-line mode-line-active mode-line-inactive))
          (when (facep face)
            (push (face-remap-add-relative
                   face :background my/view-visual-mode-line-background)
                  my/view-visual--cookies))))
      (when my/view-visual-mode-line-badge
        ;; 元のリストは壊さず、新しいリストを作って buffer-local に置く。
        (setq-local mode-line-misc-info
                    (cons (propertize " READ-ONLY "
                                      'face `(:foreground ,my/view-visual-mode-line-foreground
                                              :weight bold))
                          mode-line-misc-info))
        (setq my/view-visual--misc-info-set t)))
    (when my/view-visual-enable-hl-line
      (setq my/view-visual--hl-line-was-on
            (bound-and-true-p hl-line-mode))
      (hl-line-mode 1))
    (when my/view-visual-cursor-type
      ;; もとの状態を憶えてから変える。ローカル値が無かったバッファに
      ;; `setq-local' で値を作ってしまうと、解除時にグローバル値へ戻せなくなる。
      (setq my/view-visual--cursor-type-was-local
            (local-variable-p 'cursor-type))
      (setq my/view-visual--cursor-type-orig
            (and my/view-visual--cursor-type-was-local cursor-type))
      (setq-local cursor-type my/view-visual-cursor-type))))

(defun my/view-visual--remove ()
  "read-only スタイルを解除する。"
  (when my/view-visual--cookies
    (dolist (cookie my/view-visual--cookies)
      (face-remap-remove-relative cookie))
    (setq my/view-visual--cookies nil)
    (when (and my/view-visual-enable-hl-line
               (not my/view-visual--hl-line-was-on)
               (bound-and-true-p hl-line-mode))
      (hl-line-mode -1))
    (if my/view-visual--cursor-type-was-local
        (setq-local cursor-type my/view-visual--cursor-type-orig)
      (kill-local-variable 'cursor-type))
    (when my/view-visual--misc-info-set
      (kill-local-variable 'mode-line-misc-info)
      (setq my/view-visual--misc-info-set nil))))

(defun my/view-visual--sync-buffer (buf)
  "BUF の read-only 状態に合わせて適用/解除する。"
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (if buffer-read-only
          (my/view-visual--apply)
        (my/view-visual--remove)))))

;; ------------------------------------------------------------------
;; 実装 — カーソル色 (フレーム単位)
;; ------------------------------------------------------------------

(defun my/cursor-color--desired ()
  "選択中ウィンドウのバッファに対して表示すべきカーソル色を返す。
カーソルは選択中ウィンドウにしか描かれないので、判定もそのバッファで行う。"
  (with-current-buffer (window-buffer (selected-window))
    (if buffer-read-only
        my/cursor-color-readonly
      my/cursor-color-writable)))

(defun my/cursor-color-update (&optional frame &rest _)
  "FRAME (省略時は選択中のフレーム) のカーソル色を現在の状態に合わせる。
色が変わらないときは何もしない。`set-cursor-color' はフレーム全体の
再描画を伴うので、ウィンドウ切替のたびに無条件で呼ぶと無駄が大きい。

FRAME を受け取るのは `after-make-frame-functions' 対策。新しいフレームは
作成時点でまだ選択されていないことがあり、そのままだと別のフレームに
色を当ててしまう。フレーム以外を渡してくるフック (window 変更系は
ウィンドウを渡す場合がある) もあるので `framep' で選り分ける。"
  (let ((frame (if (framep frame) frame (selected-frame))))
    (when (display-graphic-p frame)
      (with-selected-frame frame
        (let ((color (my/cursor-color--desired)))
          (unless (equal color (frame-parameter frame 'cursor-color))
            (set-cursor-color color)))))))

;; ------------------------------------------------------------------
;; フック接続
;; ------------------------------------------------------------------

(defun my/view-visual--sync ()
  "現在のバッファを同期 (read-only-mode/view-mode フック用)。"
  (my/view-visual--sync-buffer (current-buffer))
  (my/cursor-color-update))

(defun my/view-visual--sync-visible (&rest _)
  "いま表示されている全ウィンドウのバッファを同期する。"
  (dolist (win (window-list nil 'no-mini))
    (my/view-visual--sync-buffer (window-buffer win)))
  (my/cursor-color-update))

(add-hook 'read-only-mode-hook #'my/view-visual--sync)
(add-hook 'view-mode-hook #'my/view-visual--sync)
(add-hook 'window-selection-change-functions #'my/view-visual--sync-visible)
(add-hook 'window-buffer-change-functions #'my/view-visual--sync-visible)

;; 既に read-only 状態で開かれているバッファにも反映
(dolist (buf (buffer-list))
  (my/view-visual--sync-buffer buf))

;; 初期色。init 実行中はまだフレームが整っていないことがあるので起動後に一度、
;; 新しいフレーム (daemon 運用など) にも作成時に一度当てる。
(add-hook 'emacs-startup-hook #'my/cursor-color-update)
(add-hook 'after-make-frame-functions #'my/cursor-color-update)

;; ------------------------------------------------------------------
;; 実装 — 編集しようとしたときに知らせる
;; ------------------------------------------------------------------

;; view-mode では DEL (物理 BS) が `View-scroll-page-backward' に割り当たっている。
;; そのため選択して BS で消そうとすると**エラーも音も出ずに 1 画面戻る**。
;; 「消えなかった」ではなく「表示が飛んだ」になるので事故る。
;; 後方スクロールは 02_packages.el で SPC にも割り当ててあるため、DEL を潰しても
;; 機能は失われない。
;;
;; この関数はバッファを一切変更しないので、押しても選択 (region) が消えない。
;; E で編集可能にして、そのまま消し直せる。

(defun my/view-refuse-edit ()
  "read-only で編集できないことだけを知らせる。何も動かさない。
`view-mode-map' の DEL に割り当てて使う (02_packages.el)。"
  (interactive)
  (message "%s" (propertize "read-only です  (E: 編集開始 / C-x C-q: 切替)"
                            'face 'error)))

(provide '03_view-visual)
;;; 03_view-visual.el ends here
