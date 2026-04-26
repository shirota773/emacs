;;; 03_undo.el --- Modern Undo/Redo Environment -*- lexical-binding: t; -*-

;; undo-fu: シンプルかつ安定した Undo/Redo を提供
(leaf undo-fu
  :ensure t
  :bind
  (("C-/"   . undo-fu-only-undo)
   ("C-\\"  . undo-fu-only-redo))
  :config
  (setq undo-limit 67108864) ; 64mb
  (setq undo-strong-limit 100663296) ; 96mb
  (setq undo-outer-limit 1006632960) ; 960mb
  )

;; undo-fu-session: 再起動後も履歴を保存
(leaf undo-fu-session
  :ensure t
  :config
  (setq undo-fu-session-incompatible-major-modes '(term-mode comint-mode))
  (setq undo-fu-session-directory
        (expand-file-name "undo-fu-session/"
                          (if (boundp 'no-littering-var-directory)
                              no-littering-var-directory
                            user-emacs-directory)))
  (undo-fu-session-global-mode 1))

;; vundo: 履歴をツリー形式で可視化
(leaf vundo
  :ensure t
  :bind
  ("C-x u" . vundo)
  :config
  ;; パッケージ読み込み後に見た目を設定
  (setq vundo-glyph-alist vundo-unicode-glyphs))

(provide '03_undo)
