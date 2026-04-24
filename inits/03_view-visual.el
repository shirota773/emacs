;;; 03_view-visual.el --- view-mode / read-only バッファの見た目をはっきり区別する -*- lexical-binding: t; -*-
;;
;; 使い方:
;;   下の「設定テンプレ」セクションの色を書き換えるだけで、
;;   read-only (view-mode) 中のバッファ表示が切り替わります。
;;
;;   対象になる条件: `buffer-read-only' が t のバッファ
;;   （`read-only-mode' でも `view-mode' でも同じ）
;;

;; ------------------------------------------------------------------
;; 設定テンプレ — ここだけ書き換えれば OK
;; ------------------------------------------------------------------

(defgroup my/view-visual nil
  "read-only / view-mode バッファの視覚強調設定。"
  :group 'convenience)

(defcustom my/view-visual-background "#2a2233"
  "read-only バッファの背景色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-cursor "#ff79c6"
  "read-only バッファでのカーソル色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-hl-line "#3d2b4a"
  "read-only バッファでのカーソル行 (hl-line) の色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-mode-line-bg "#6272a4"
  "read-only バッファのモードライン背景色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-mode-line-fg "#f8f8f2"
  "read-only バッファのモードライン前景色。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-cursor-default "cyan"
  "書込可能バッファでのカーソル色 (デフォルト)。"
  :type 'color :group 'my/view-visual)

(defcustom my/view-visual-enable-hl-line t
  "非 nil なら read-only バッファで `hl-line-mode' を自動で有効化する。"
  :type 'boolean :group 'my/view-visual)

;; ------------------------------------------------------------------
;; 実装
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
                                    :background my/view-visual-hl-line)
           (face-remap-add-relative 'mode-line
                                    :background my/view-visual-mode-line-bg
                                    :foreground my/view-visual-mode-line-fg)))
    (when my/view-visual-enable-hl-line
      (setq my/view-visual--hl-line-was-on
            (bound-and-true-p hl-line-mode))
      (hl-line-mode 1))
    (force-mode-line-update t)))

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
    (force-mode-line-update t)))

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

;; 表示中の全バッファを同期 (ウィンドウ切替対応)
(defun my/view-visual--sync-visible (&rest _)
  "いま表示されている全ウィンドウのバッファを同期する。"
  (dolist (win (window-list nil 'no-mini))
    (my/view-visual--sync-buffer (window-buffer win))))

;; カーソル色は選択ウィンドウのバッファに合わせる (frame 属性なので動的に追従)
(defun my/view-visual--update-cursor (&rest _)
  (let* ((buf (window-buffer (selected-window)))
         (ro (and (buffer-live-p buf)
                  (buffer-local-value 'buffer-read-only buf)))
         (target (if ro
                     my/view-visual-cursor
                   my/view-visual-cursor-default)))
    (unless (equal (frame-parameter nil 'cursor-color) target)
      (set-cursor-color target))))

(defun my/view-visual--on-window-change (&rest _)
  "ウィンドウ選択/バッファ変更時に、表示バッファとカーソルを同期する。"
  (my/view-visual--sync-visible)
  (my/view-visual--update-cursor))

;; ------------------------------------------------------------------
;; フック接続
;; ------------------------------------------------------------------

;; モード切替時
(add-hook 'read-only-mode-hook #'my/view-visual--sync)
(add-hook 'view-mode-hook #'my/view-visual--sync)

;; ウィンドウ/バッファ切替時 (選択ウィンドウと表示バッファを確実に反映)
(add-hook 'window-selection-change-functions #'my/view-visual--on-window-change)
(add-hook 'window-buffer-change-functions #'my/view-visual--on-window-change)

;; 既に read-only 状態で開かれているバッファにも反映
(dolist (buf (buffer-list))
  (my/view-visual--sync-buffer buf))

(provide '03_view-visual)
;;; 03_view-visual.el ends here
