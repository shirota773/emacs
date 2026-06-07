;;; win.el --- Windows 固有設定 -*- lexical-binding: t; -*-
(leaf *coding
  :config
  ;; 言語環境を先に設定する。set-language-environment は coding 優先順位を
  ;; 日本語既定へリセットするため、UTF-8 を最優先にする prefer-coding-system は
  ;; 必ずその後に呼ぶ (順序を逆にすると UTF-8 優先が打ち消され文字化けの原因)。
  (set-language-environment "Japanese")
  (prefer-coding-system 'utf-8-unix)
  ;; 新規ファイルは UTF-8 / LF を既定にする。
  (setq-default buffer-file-coding-system 'utf-8-unix)
  (set-terminal-coding-system 'utf-8-unix)
  (set-keyboard-coding-system 'utf-8-unix)
  ;; Windows のクリップボードは UTF-16LE。日本語コピペの文字化け対策。
  (set-clipboard-coding-system 'utf-16le-dos)
  (set-selection-coding-system 'utf-16le-dos)
  (set-frame-font "Ricty diminished-12" nil t)

  ;; ---- 改行コード (CRLF を使わず LF に統一する) ----
  ;; 新規ファイル: 上の utf-8-unix 既定により LF。
  ;; 既存 CRLF ファイル: 保存時に確認してから LF へ変換する。

  (defun my/buffer-uses-crlf-p ()
    "現在のバッファが CRLF (DOS) で保存される、または CR を含む場合に非 nil。
正しく DOS と判別されたファイルは buffer 内に CR を持たないため、
coding-system の EOL 種別 (1 = dos) も確認する。"
    (or (and buffer-file-coding-system
             (eq (coding-system-eol-type buffer-file-coding-system) 1))
        (save-excursion
          (save-restriction
            (widen)
            (goto-char (point-min))
            (search-forward "\r" nil t)))))

  (defun my/strip-crlf-from-string (string)
    "STRING 中の CRLF / 単独 CR を LF に変換する。"
    (replace-regexp-in-string "\r\n?" "\n" string))

  (defun my/strip-crlf-in-yank (orig-fun &rest args)
    "貼り付けテキストから CR を除去してから挿入する (コピペの改行混入対策)。"
    (let ((first-arg (car args)))
      (if (stringp first-arg)
          (apply orig-fun
                 (cons (my/strip-crlf-from-string first-arg)
                       (cdr args)))
        (apply orig-fun args))))

  (defun my/confirm-strip-crlf-on-save ()
    "既存ファイルが CRLF のとき、確認のうえ LF へ変換して保存する。"
    (when (and buffer-file-name (my/buffer-uses-crlf-p))
      (when (y-or-n-p
             (format "%s は CRLF です。LF に変換して保存しますか? "
                     (file-name-nondirectory buffer-file-name)))
        ;; 保存時の改行を LF にする
        (set-buffer-file-coding-system
         (coding-system-change-eol-conversion
          (or buffer-file-coding-system 'utf-8) 'unix))
        ;; buffer 内に残る単独 CR も除去する
        (save-excursion
          (save-restriction
            (widen)
            (goto-char (point-min))
            (while (search-forward "\r" nil t)
              (replace-match "")))))))

  (advice-add 'insert-for-yank :around #'my/strip-crlf-in-yank)
  (add-hook 'before-save-hook #'my/confirm-strip-crlf-on-save)
  )

(leaf *IME
  :config
  ;; IME
  (setq default-input-method "W32-IME")
  ;; (w32-ime-initialize)

  (advice-add 'ime-force-on
              :before (lambda (&rest args)
                        (set-cursor-color "blue")))
  (advice-add 'ime-force-off
              :before (lambda (&rest args)
                        (set-cursor-color "cyan")))
  (add-hook 'input-method-activate-hook
            (lambda() (set-cursor-color "blue")))
  (add-hook 'input-method-inactivate-hook
            (lambda() (set-cursor-color "cyan")))
  (setq w32-ime-buffer-switch-p t)
  )

(leaf *SHELL
  ;; SHELL
  :config
  (setq shell-file-name "bash")
  (setenv "SHELL" shell-file-name)
  (setq explicit-shell-file-name shell-file-name)
)
