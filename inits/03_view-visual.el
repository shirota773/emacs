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

(defun my/view-visual--apply ()
  "現在のバッファを read-only スタイルにする。"
  (unless my/view-visual--cookies
    (setq my/view-visual--cookies
          (list
           (face-remap-add-relative 'default
                                    :background my/view-visual-background)
           (face-remap-add-relative 'hl-line
                                    :background my/view-visual-hl-line)))
    (when my/view-visual-enable-hl-line
      (setq my/view-visual--hl-line-was-on
            (bound-and-true-p hl-line-mode))
      (hl-line-mode 1))))

(defun my/view-visual--remove ()
  "read-only スタイルを解除する。"
  (when my/view-visual--cookies
    (dolist (cookie my/view-visual--cookies)
      (face-remap-remove-relative cookie))
    (setq my/view-visual--cookies nil)
    (when (and my/view-visual-enable-hl-line
               (not my/view-visual--hl-line-was-on)
               (bound-and-true-p hl-line-mode))
      (hl-line-mode -1))))

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

(provide '03_view-visual)
;;; 03_view-visual.el ends here
