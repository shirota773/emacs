;;; 03_modeline.el --- モードライン (doom-modeline) -*- lexical-binding: t; -*-

;;; Commentary:
;; doom-themes は init.el で読んでいたが doom-modeline は入っていなかった。
;; init.el:62 の `doom-modeline-bar' の :custom-face だけが残っていて
;; ずっと空振りしていたので、本体を入れて有効化する (2026-07-28)。
;;
;; 01_setup.el にあった `mode-line-position' の総行数表示 (my-mode-line-format)
;; はここへ移した。doom-modeline は `mode-line-format' ごと差し替えるため
;; mode-line-position を書き換えても効かず、同じことは
;; `doom-modeline-total-line-number' で表現できる。
;;
;; 色: init.el の :custom-face (mode-line / mode-line-inactive /
;; mode-line-buffer-id / doom-modeline-bar) をそのまま使う。doom-modeline は
;; 背景に mode-line face を使うので、既存の紫背景 + 黄文字は維持される。

;;; Code:

(leaf nerd-icons
  :ensure t
  :config
  ;; nerd-icons の既定ファミリは "Symbols Nerd Font Mono"。macOS には
  ;; 別名の Nerd Font (MesloLG* 系) しか入っていないことがあり、その場合
  ;; 既定のままだと豆腐 (□) になる。入っているファミリを順に探して使う。
  ;;
  ;; GUI フレームが無いと font-family-list が nil を返すので、バッチや
  ;; --daemon の初回起動では判定できない。フレームができてから 1 度だけ
  ;; 走らせる。emacsclient 運用でも server-after-make-frame-hook で拾う。
  (defun my/nerd-icons-pick-font-family ()
    "使える Nerd Font を選ぶ。見つからなければアイコン表示自体をやめる。"
    (when (display-graphic-p)
      (let* ((families (font-family-list))
             (found (seq-find (lambda (f) (member f families))
                              '("Symbols Nerd Font Mono"
                                "Symbols Nerd Font"
                                "MesloLGM Nerd Font Mono"
                                "MesloLGS Nerd Font Mono"
                                "MesloLGL Nerd Font Mono"))))
        (if found
            (setq nerd-icons-font-family found)
          ;; フォントが無い環境 (仕事の Windows 機など) でアイコンを出すと
          ;; モードラインが豆腐だらけになる。文字だけの表示に落とす。
          (setq doom-modeline-icon nil))
        (remove-hook 'server-after-make-frame-hook #'my/nerd-icons-pick-font-family)
        (remove-hook 'window-setup-hook #'my/nerd-icons-pick-font-family))))
  (add-hook 'window-setup-hook #'my/nerd-icons-pick-font-family)
  (add-hook 'server-after-make-frame-hook #'my/nerd-icons-pick-font-family))

(leaf doom-modeline
  :ensure t
  :custom
  ;; 01_setup.el の my-lines-page-mode (総行数表示) の後継。
  ;; "現在行/総行数" の形で出る
  (doom-modeline-total-line-number . t)
  ;; プロジェクトルートからの相対パスでバッファ名を出す。
  ;; 同名ファイルを別プロジェクトで開いたときに区別がつく
  (doom-modeline-buffer-file-name-style . 'relative-from-project)
  ;; major-mode のアイコンは出す。バッファ状態 (未保存/読み取り専用) の
  ;; アイコンも出す — read-only を色で示す 03_view-visual.el と補い合う
  (doom-modeline-major-mode-icon . t)
  (doom-modeline-buffer-state-icon . t)
  ;; エンコーディングは常時表示する。utf-8/CRLF まわりで Windows と
  ;; やり取りする設定 (win.el) を入れている以上、ここは見えていた方がよい
  (doom-modeline-buffer-encoding . t)
  ;; LSP・checker の状態は eglot が入っているので出す
  (doom-modeline-lsp . t)
  ;; リモート作業が多いので host 表示は残す
  (doom-modeline-display-misc-in-all-mode-lines . t)
  :config
  (doom-modeline-mode 1))

(provide '03_modeline)
;;; 03_modeline.el ends here
