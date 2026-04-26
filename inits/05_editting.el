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
  :config
  (puni-global-mode 1)
  :bind (("C-SPC" . my/puni-selection-start)
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
