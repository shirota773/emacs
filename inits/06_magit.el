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
  ;; ★ 入口のキーは Alt を使わないものに寄せてある (2026-11-08)
  ;;   既定は C-x M-g = magit-dispatch / C-c M-g = magit-file-dispatch だが、
  ;;   Ctrl も Alt も左親指で押す配列なので 1 つのキー列の中で親指を押し替える
  ;;   ことになり、押しづらい (前提は 94_keybinds.el の冒頭)。magit 自身が
  ;;   'recommended として用意している C-c g / C-c f に移した。どちらも
  ;;   Ctrl 1 回 + 素の英字で、左手だけで打てる。
  ;;   単打鍵の一等地には移せない: 左手側で空いているのは C-q / C-z だけで、
  ;;   どちらも痛めた左小指を使う (C-v は cua-scroll-up、C-d は delete-char)。
  :bind (("C-x g" . magit-status)
         ("C-c g" . magit-dispatch)
         ;; 開いているファイルの diff / log / blame / 旧リビジョン表示。
         ;; 閲覧運用の主入口なので左手ホームポジションの f に置く。
         ("C-c f" . magit-file-dispatch))
  :custom
  (magit-diff-refine-hunk . t)          ; hunk 内の単語単位差分を表示
  ;; 'recommended にすると magit 側が C-x M-g / C-c M-g を足さなくなる
  ;; (magit.el の magit-maybe-define-global-key-bindings)。上の :bind と
  ;; 同じ 3 つを入れる値なので、二重定義にはならない。
  (magit-define-global-key-bindings . 'recommended)
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
