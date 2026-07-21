;;; 06_magit.el --- Magit 設定 -*- lexical-binding: t; -*-
;;
;; かつて「commit メニューが出ない」対策の advice 等が入っていたが、
;; 原因は git-commit-mode-hook で古い fci-mode がエラーになり
;; セットアップが中断されていたこと (02_packages.el で組み込みの
;; display-fill-column-indicator-mode に置換済み)。
;; あわせて commit には emacsclient/server が必要なため、
;; 01_setup.el で全プラットフォーム server-start するようにした。
;; commit できない症状が再発したら M-x with-editor-debug で診断する。

(leaf magit
  :ensure t
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch))
  :custom
  (magit-diff-refine-hunk . t)          ; hunk 内の単語単位差分を表示
  :config
  ;; Windows はプロセス起動が遅いので status のセクションを間引く
  (when windows-nt-p
    (remove-hook 'magit-status-sections-hook 'magit-insert-tags-header)
    (remove-hook 'magit-status-sections-hook 'magit-insert-unpushed-to-upstream-or-recent)
    (remove-hook 'magit-status-sections-hook 'magit-insert-unpulled-from-upstream)))

(leaf transient
  :ensure t
  :config
  ;; transientの履歴保存先ディレクトリを確実に作成する
  (let ((dir (expand-file-name "transient/" no-littering-var-directory)))
    (unless (file-exists-p dir)
      (make-directory dir t)))
  (setq transient-history-file (expand-file-name "transient/history.el" no-littering-var-directory)))

(provide '06_magit)
