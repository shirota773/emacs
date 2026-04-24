;;; 03_view-visual.el --- view-mode / read-only バッファの見た目をはっきり区別する -*- lexical-binding: t; -*-
;;
;; 使い方:
;;   下の「設定テンプレ」セクションの色/形状を書き換えるだけで、
;;   read-only (view-mode) 中のバッファ表示が切り替わります。
;;
;;   対象になる条件: `buffer-read-only' が t のバッファ
;;   （`read-only-mode' でも `view-mode' でも同じ）
;;
;;   背景 / hl-line は face-remap で buffer-local に適用
;;   カーソル色は IME 切替と競合するため、形状 (`cursor-type') で区別する
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

;; ---- カーソル形状 (色は IME フックと競合するので触らない) ----
(defcustom my/view-visual-cursor-type-default t
  "書込可能バッファでのカーソル形状。
`t' (デフォルト), `box', `hollow', `bar', `hbar', `(bar . 2)' など。"
  :type 'sexp :group 'my/view-visual)

(defcustom my/view-visual-cursor-type-readonly 'hollow
  "read-only バッファでのカーソル形状。"
  :type 'sexp :group 'my/view-visual)

;; ------------------------------------------------------------------
;; 実装 — 背景 / hl-line / cursor-type (buffer-local)
;; ------------------------------------------------------------------

(defvar-local my/view-visual--cookies nil
  "このバッファに適用した face-remap の cookie リスト。")

(defvar-local my/view-visual--hl-line-was-on nil
  "もとから `hl-line-mode' が有効だったか。")

(defvar-local my/view-visual--cursor-type-saved nil
  "元の cursor-type を退避。")

(defvar-local my/view-visual--cursor-saved-p nil
  "cursor-type を退避済みかどうか (nil を退避値と区別するため)。")

(defun my/view-visual--apply ()
  "現在のバッファを read-only スタイルにする。"
  (unless my/view-visual--cookies
    (setq my/view-visual--cookies
          (list
           (face-remap-add-relative 'default
                                    :background my/view-visual-background)
           (face-remap-add-relative 'hl-line
                                    :background my/view-visual-hl-line)))
    (unless my/view-visual--cursor-saved-p
      (setq my/view-visual--cursor-type-saved cursor-type
            my/view-visual--cursor-saved-p t))
    (setq-local cursor-type my/view-visual-cursor-type-readonly)
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
    (when my/view-visual--cursor-saved-p
      (setq-local cursor-type my/view-visual--cursor-type-saved)
      (setq my/view-visual--cursor-saved-p nil
            my/view-visual--cursor-type-saved nil))
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

(defun my/view-visual--sync ()
  "現在のバッファを同期 (read-only-mode/view-mode フック用)。"
  (my/view-visual--sync-buffer (current-buffer)))

(defun my/view-visual--sync-visible (&rest _)
  "いま表示されている全ウィンドウのバッファを同期する。"
  (dolist (win (window-list nil 'no-mini))
    (my/view-visual--sync-buffer (window-buffer win))))

;; ------------------------------------------------------------------
;; フック接続
;; ------------------------------------------------------------------

(add-hook 'read-only-mode-hook #'my/view-visual--sync)
(add-hook 'view-mode-hook #'my/view-visual--sync)
(add-hook 'window-selection-change-functions #'my/view-visual--sync-visible)
(add-hook 'window-buffer-change-functions #'my/view-visual--sync-visible)

;; 既に read-only 状態で開かれているバッファにも反映
(dolist (buf (buffer-list))
  (my/view-visual--sync-buffer buf))

(provide '03_view-visual)
;;; 03_view-visual.el ends here
