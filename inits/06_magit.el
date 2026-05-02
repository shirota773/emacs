(leaf magit
  :ensure t
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch))
  :config
  ;; --- 基本デバッグ設定 ---
  (setq magit-process-log-max 100)
  (setq magit-git-debug t)
  
  ;; --- コミットメニューが出ない問題の回避策 ---
  ;; 既存の編集バッファ（COMMIT_EDITMSG等）を探す機能を無効化し、誤判定を防ぐ
  (setq magit-commit-use-existing-edit-buffer nil)
  
  ;; 関数呼び出しを強制的にTransientメニュー表示にバイパスする（最優先の解決策）
  (advice-add 'magit-commit :around
              (lambda (orig-fun &rest args)
                (interactive)
                (transient-setup 'magit-commit)))

  ;; --- Windows環境向けの高速化設定 ---
  ;; ステータス画面で読み込む項目を最小限にして、Gitコマンドの呼び出し回数を減らす
  (remove-hook 'magit-status-sections-hook 'magit-insert-tags-header)
  (remove-hook 'magit-status-sections-hook 'magit-insert-status-headers)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpushed-to-upstream-or-recent)
  (remove-hook 'magit-status-sections-hook 'magit-insert-unpulled-from-upstream)

  ;; バッファ切り替え時の自動更新を抑制（重い場合は手動の 'g' で更新するようにする）
  ;; (setq magit-refresh-status-buffer nil)

  ;; 詳細なパフォーマンスログを出力（もし重い原因をさらに探す場合に有効化）
  ;; (setq magit-refresh-verbose t)
  )

(leaf transient
  :ensure t
  :config
  ;; transientの履歴保存先ディレクトリを確実に作成する
  (let ((dir (expand-file-name "transient/" no-littering-var-directory)))
    (unless (file-exists-p dir)
      (make-directory dir t)))
  (setq transient-history-file (expand-file-name "transient/history.el" no-littering-var-directory)))

(provide '06_magit)
