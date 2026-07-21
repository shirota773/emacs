;;; 05_dired.el --- dired / dirvish 設定 -*- lexical-binding: t; -*-

(leaf dired
  :custom
  ;; 2画面 dired 時、コピー/移動先をもう一方の dired ウィンドウに自動設定
  (dired-dwim-target . t)
  ;; ディレクトリの再帰コピーは常に許可、削除は最上位のみ確認
  (dired-recursive-copies . 'always)
  (dired-recursive-deletes . 'top)
  ;; 再訪時にディレクトリ内容を自動で最新化
  (dired-auto-revert-buffer . t)
  ;; ディレクトリ移動で dired バッファを増やさない
  (dired-kill-when-opening-new-dired-buffer . t)
  ;; dired から他アプリへファイルをドラッグできる (Emacs 29)
  (dired-mouse-drag-files . t)
  ;; 削除は rm ではなくゴミ箱へ
  (delete-by-moving-to-trash . t)
  ;; wdired でパーミッションも編集可能に
  (wdired-allow-to-change-permissions . t)
  :config
  ;; Finder のゴミ箱と共有する (未設定だと ~/.local/share/Trash になる)
  (when darwin-p
    (setq trash-directory "~/.Trash"))
  ;; dired-find-alternate-file の有効化
  (put 'dired-find-alternate-file 'disabled nil)

  (defun my/dired-open-externally ()
    "ポイントのファイルを OS 既定のアプリケーションで開く。"
    (interactive)
    (let ((file (dired-get-filename nil t)))
      (unless file (user-error "ここにファイルがありません"))
      (cond (darwin-p (call-process "open" nil 0 nil file))
            (windows-nt-p (w32-shell-execute "open" file))
            (t (call-process "xdg-open" nil 0 nil file)))))

  :bind (("C-x C-j" . dired-jump)        ; 今のファイルの位置で dired を開く
         (dired-mode-map
          ("<tab>" . dirvish-subtree-toggle)
          ("r" . wdired-change-to-wdired-mode)
          ("h" . dired-up-directory)
          ("j" . next-line)
          ("k" . previous-line)
          ("l" . dired-find-file)        ; hjkl を完成させる
          ("a" . dirvish-quick-access)   ; 登録ディレクトリへ1キーでジャンプ
          ("/" . dirvish-narrow)         ; 入力で絞り込み
          ("s" . dirvish-quicksort)      ; ソート切替メニュー
          ("H" . dirvish-history-jump)   ; 訪問履歴からジャンプ
          ("E" . my/dired-open-externally)
          ("(" . dired-hide-details-mode)
          ("z" . peep-dired)
          ))
  )

;; diredでチラ見
(leaf peep-dired
  :ensure t
  :custom
  (peep-dired-cleanup-on-disable . t)
  (peep-dired-enable-on-directories . nil)
  :bind ((dired-mode-map
          ("p" . peep-dired)
          ("b" . peep-dired-scroll-page-up)
          ))
  )

(leaf dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :bind
  ("M-s d" . dirvish-side)
  :config
  (setq dired-use-ls-dired (not darwin-p))
  (setq dired-listing-switches
        (if darwin-p
            "-lAh"
          "-l --almost-all --human-readable --group-directories-first --no-group"))
  (setq dirvish-hide-details t)
  (setq dirvish-side-display-alist '((side . right) (slot . -1)))
  (setq dirvish-use-header-line 'global)
  (setq dirvish-header-line-height '(25 . 35))
  ;; collapse: 一本道のディレクトリを1行にまとめて表示
  (setq dirvish-attributes '(subtree-state collapse file-time file-size))
  (setq dirvish-side-attributes '(git-msg file-modes file-time file-size))
  (setq dirvish-large-directory-threshold 20000)
  (setq dirvish-header-line-format '(:left (path) :right (free-space)))
  (setq dirvish-mode-line-format
        '(:left (sort file-time " " file-size symlink) :right (omit yank index)))
  ;; `a' (dirvish-quick-access) で飛べる登録ディレクトリ
  (setq dirvish-quick-access-entries
        '(("h" "~/"          "Home")
          ("d" "~/Downloads" "Downloads")
          ("e" "~/.emacs.d/" "emacs")
          ("o" "~/Documents" "Documents")
          ("t" "~/Desktop"   "Desktop")))
  (put 'dired-find-alternate-file 'disabled nil)
  )

(provide '05_dired)
