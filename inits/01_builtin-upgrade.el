;;; 01_builtin-upgrade.el --- 同梱パッケージを ELPA の新しい版に上げる -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs に同梱されているパッケージのうち、ELPA の新しい版を使いたいものを入れる。
;;
;; leaf の :ensure t では上げられない。`package-installed-p' が同梱版を見て
;; 「導入済み」と答えるため、何もしないまま同梱版で動き続ける。そこで最低
;; バージョンを決め、それより古ければ ELPA 版の package-desc を
;; `package-install' に直接渡す (Emacs 29.4 の package.el は package-desc を
;; 渡されるとそれを入れる。シンボルだと同梱版を見て止まる)。
;;
;; 01_setup より前に読ませている理由:
;;   31_terminal.el と 32_tramp.el が (require 'tramp) する。古い TRAMP を
;;   読み込んだ後で新しい版を入れると、そのセッションは古い版のまま動き、
;;   バイトコンパイルも古い定義を読み込んだ状態で走る。読み込み前に入れれば
;;   同じセッションのうちに新しい版が使われる。
;;
;; 入れられなかったとき (オフライン、プロキシ等) は警告だけ出して
;; 同梱版のまま起動を続ける。

;;; Code:

(require 'package)

(defconst my/builtin-upgrade-packages
  '(;; Emacs 29.4 同梱は 2.6.3、30.1 同梱は 2.7.1。2.8 で入るもの:
    ;; 接続失敗を remote-file-error で通知、使っていない接続の一括片付け
    ;; (tramp-cleanup-bufferless-connections)、多段接続での scp、
    ;; dired の @ で sudo を付けて開く、など (Emacs 31 の NEWS と同じ内容)
    (tramp . "2.8"))
  "ELPA 版に上げる同梱パッケージと、求める最低バージョンの alist。")

(defun my/builtin-upgrade--archive-desc (pkg)
  "PKG の ELPA 版の package-desc を返す。手元のアーカイブ一覧に無ければ取り直す。"
  (or (cadr (assq pkg package-archive-contents))
      (progn (package-refresh-contents)
             (cadr (assq pkg package-archive-contents)))))

(defun my/builtin-upgrade-ensure (pkg min-version)
  "PKG が MIN-VERSION より古ければ ELPA 版を入れる。失敗しても起動は止めない。"
  (let ((min (version-to-list min-version)))
    (unless (package-installed-p pkg min)
      (condition-case err
          (let ((desc (my/builtin-upgrade--archive-desc pkg)))
            (cond
             ((null desc)
              (error "アーカイブに %s がありません" pkg))
             ;; アーカイブ側も古いと、起動のたびに入れ直すことになる
             ((version-list-< (package-desc-version desc) min)
              (error "アーカイブの %s は %s で、%s に届きません"
                     pkg (package-version-join (package-desc-version desc))
                     min-version))
             (t (package-install desc))))
        (error
         (display-warning
          'my/builtin-upgrade
          (format "%s を ELPA 版に上げられませんでした (同梱版で続行): %s"
                  pkg (error-message-string err))
          :warning))))))

(dolist (entry my/builtin-upgrade-packages)
  (my/builtin-upgrade-ensure (car entry) (cdr entry)))

(provide '01_builtin-upgrade)
;;; 01_builtin-upgrade.el ends here
