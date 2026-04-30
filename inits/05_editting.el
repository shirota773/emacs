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

  (defun my/hydra-puni-quit-and-pass-key ()
    "Quit puni hydra and pass the pressed key to Emacs."
    (interactive)
    (hydra-keyboard-quit)
    (setq unread-command-events
          (append (listify-key-sequence (this-command-keys))
                  unread-command-events)))
  :config
  (puni-global-mode 1)
  (leaf *puni-repeat
    :after repeat
    :config
    (defvar-keymap puni-repeat-map
      :repeat t
      "h" #'puni-beginning-of-sexp
      "l" #'puni-end-of-sexp))
  :bind (("C-SPC" . my/puni-selection-start)
         ("C-b" . hydra-puni/body)
         ("M-s h" . puni-beginning-of-sexp)
         ("M-s l" . puni-end-of-sexp))
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
   ("B" puni-barf-forward)
   ("q" nil ))
  )

;; 構造的な範囲選択の強化
(leaf expreg
  :ensure t
  :bind ("C-=" . expreg-expand))

;; =============================================================================
;; 2. Navigation & Search Enhancement
;; =============================================================================

(leaf avy
  :ensure t
  :bind (("M-s j" . avy-goto-char-timer)))

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
