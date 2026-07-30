;;; 05_editing.el --- 編集操作 (puni / expreg / symbol-overlay / repeat) -*- lexical-binding: t; -*-

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
  :custom
  ;; change/copy-inner の区切り文字を read-char で聞く (既定の read-string は
  ;; minibuffer を開くため、上の minibuffer-setup-hook の hydra-keyboard-quit が
  ;; 発火して hydra が閉じてしまう)。vim の ci と同じ 1 文字入力になる。
  ;; 引き換えに複数文字の区切りは使えないが、実用上 ( [ { " ' で足りる。
  (puni-read-char-for-change-inner . t)
  :config
  (puni-global-mode 1)
  (add-hook 'minibuffer-setup-hook #'hydra-keyboard-quit)
  :bind (("C-SPC" . my/puni-region-selection-start)
         ("C-b" . hydra-puni/body))
  :hydra
  (hydra-puni
   (:color pink :hint nil :foreign-keys run)
   "
  [Move(Extend)]  [Select/Edit]          [Structure]          [Inner/Outer]
 --------------------------------------------------------------------------
  _f_: forward    _e_: expand(expreg)    _s_: slurp           _ci_: change-inner
  _b_: backward   _w_: wrap              _B_: barf            _co_: change-outer
  _a_: begin      _p_: splice            _S_: squeeze         _yi_: copy-inner
  _r_: raise      _d_: delete-word       _x_: exchange-point  _yo_: copy-outer
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
   ;; 囲みを捨てて中身を昇格 (paredit の M-r 相当)。
   ;; 旧 "c" は puni-clone-thing-at-point を指していたが、このコマンドは
   ;; puni に存在せず押すと void-function になっていた (2026-07-30 に置換)。
   ("r" puni-raise)
   ("d" puni-forward-kill-word)
   ("l" puni-mark-list-around-point)
   ("x" exchange-point-and-mark)
   ;; vim の ci / ca / yi / ya 相当。区切り文字を 1 文字聞いてから
   ;; その内側 (inner) か区切りを含む全体 (outer) を kill / copy する。
   ("ci" puni-change-inner)
   ("co" puni-change-outer)
   ("yi" puni-copy-inner)
   ("yo" puni-copy-outer)
   
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

(provide '05_editing)
