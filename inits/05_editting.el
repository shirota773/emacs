(leaf puni
  :ensure t
  :preface
  (defun my/puni-forward-extend ()
    "Extend region forward. Jump to mark if point is before mark."
    (interactive)
    (when (and (region-active-p) (< (point) (mark)))
      (exchange-point-and-mark))
    (puni-forward-sexp))

  (defun my/puni-backward-extend ()
    "Extend region backward. Jump to mark if point is after mark."
    (interactive)
    (when (and (region-active-p) (> (point) (mark)))
      (exchange-point-and-mark))
    (puni-backward-sexp))

  (defun my/puni-selection-start ()
    "Start region selection and puni hydra."
    (interactive)
    (set-mark-command nil)
    (hydra-puni/body))

  (defvar-keymap my/puni-region-map
    :doc "選択中だけ有効になる Puni の一時キーマップ。"
    "e" #'expreg-expand
    "f" #'puni-forward-sexp
    "b" #'puni-backward-sexp
    "r" #'exchange-point-and-mark)

  (defun my/puni-region-selection-start ()
    "範囲選択を開始し、選択中だけ `my/puni-region-map' を有効にする。"
    (interactive)
    (set-mark-command nil)
    (set-transient-map my/puni-region-map
                       (lambda () (region-active-p))))

  (defun my/hydra-puni-quit-and-pass-key ()
    "Quit puni hydra and pass the pressed key to Emacs."
    (interactive)
    (hydra-keyboard-quit)
    ;; this-command-keys は ASCII 入力時に文字列を返し、修飾ビット (Meta/Control)
    ;; が再注入時に化けて「Ctrl 押しっぱなし」状態を招く。ベクタ版で回避する。
    (setq unread-command-events
          (append (listify-key-sequence (this-command-keys-vector))
                  unread-command-events)))
  :config
  (puni-global-mode 1)
  (add-hook 'minibuffer-setup-hook #'hydra-keyboard-quit)
  :bind (("C-SPC" . my/puni-region-selection-start)
         ("C-b" . hydra-puni/body))
  :hydra
  (hydra-puni
   (:color pink :hint nil :foreign-keys run)
   "
  [Move(Extend)]  [Select/Edit]          [Structure]
 --------------------------------------------------
  _f_: forward    _e_: expand(expreg)    _s_: slurp
  _b_: backward   _w_: wrap              _B_: barf
  _a_: begin      _p_: splice            _S_: squeeze
  _c_: clone      _d_: delete-word       _x_: exchange-point
"
   ("f" my/puni-forward-extend)
   ("b" my/puni-backward-extend)
   ("a" puni-beginning-of-sexp)
   ("e" expreg-expand)
   ("w" puni-wrap-round)
   ("p" puni-splice)
   ("s" hydra-puni-slurp/body)
   ("B" puni-barf-forward)
   ("S" puni-squeeze)
   ("c" puni-clone-thing-at-point)
   ("d" puni-forward-kill-word)
   ("l" puni-mark-list-around-point)
   ("x" exchange-point-and-mark)
   
   ;; Quit and pass keys to Emacs
   ("M-w" my/hydra-puni-quit-and-pass-key "copy" :exit t)
   ("C-w" my/hydra-puni-quit-and-pass-key "kill" :exit t)
   ("DEL" my/hydra-puni-quit-and-pass-key "backspace" :exit t)
   ("<backspace>" my/hydra-puni-quit-and-pass-key "backspace" :exit t)
   ("<delete>" my/hydra-puni-quit-and-pass-key "delete" :exit t)
   ("(" my/hydra-puni-quit-and-pass-key "(" :exit t)
   (")" my/hydra-puni-quit-and-pass-key ")" :exit t)
   ("[" my/hydra-puni-quit-and-pass-key "[" :exit t)
   ("]" my/hydra-puni-quit-and-pass-key "]" :exit t)
   ("{" my/hydra-puni-quit-and-pass-key "{" :exit t)
   ("}" my/hydra-puni-quit-and-pass-key "}" :exit t)
   ("\"" my/hydra-puni-quit-and-pass-key "\"" :exit t)
   ("'" my/hydra-puni-quit-and-pass-key "'" :exit t)
   ("C-;" my/hydra-puni-quit-and-pass-key "comment" :exit t)

   ("RET" nil "finish" :exit t)
   ("C-g" (progn (deactivate-mark) (setq quit-flag t)) "cancel" :exit t))

  (hydra-puni-slurp
   (:color blue :hint nil)
   "
puni-slurp
[_q_]: exit
[_f_]: puni-slurp-forward [_b_]: puni-slurp-backward
[_F_]: puni-barf-forward [_B_]: puni-barf-backward
"
   ("f" puni-slurp-forward)
   ("b" puni-slurp-backward)
   ("F" puni-barf-forward)
   ("B" puni-barf-backward)
   ("q" nil ))
  )

;; 構造的な範囲選択の強化
(leaf expreg
  :ensure t
  :bind ("C-=" . expreg-expand))

;; =============================================================================
;; 2. Navigation & Search Enhancement
;; =============================================================================

;; avy 本体と M-s j バインドは 02_packages.el に統合済み

(leaf symbol-overlay
  :ensure t
  :bind (("M-s s" . symbol-overlay-put)
         ("M-s n" . symbol-overlay-jump-next)
         ("M-s p" . symbol-overlay-jump-prev)
         ("M-s R" . symbol-overlay-remove-all))
  :config
  (leaf *symbol-overlay-repeat
    :after repeat
    :config
    (defvar-keymap symbol-overlay-repeat-map
      :doc "Repeat map for symbol-overlay-jump"
      :repeat t
      "n" #'symbol-overlay-jump-next
      "p" #'symbol-overlay-jump-prev)))

;; =============================================================================
;; 3. File & Revert Settings
;; =============================================================================

(global-auto-revert-mode 1)

(leaf repeat
  :tag "builtin"
  :global-minor-mode repeat-mode)

(provide '05_editting)
