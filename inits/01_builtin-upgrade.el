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

(defun my/builtin-upgrade--install (pkg min)
  "手元のアーカイブ一覧にある PKG を入れる。MIN (バージョンのリスト) に届かなければエラー。"
  (let ((desc (cadr (assq pkg package-archive-contents))))
    (cond
     ((null desc)
      (error "アーカイブに %s がありません" pkg))
     ;; アーカイブ側も古いと、起動のたびに入れ直すことになる
     ((version-list-< (package-desc-version desc) min)
      (error "アーカイブの %s は %s で、%s に届きません"
             pkg (package-version-join (package-desc-version desc))
             (package-version-join min)))
     (t (package-install desc)))))

(defun my/builtin-upgrade-ensure (pkg min-version)
  "PKG が MIN-VERSION より古ければ ELPA 版を入れる。失敗しても起動は止めない。

最初は手元のアーカイブ一覧 (elpa/archives/) のまま試し、失敗したら一覧を
取り直して 1 回だけやり直す。一覧が古いと、そこに載っている版が ELPA から
消えていて 404 になる (2026-11-11 に Windows で発生。一覧は 2026-09-11 付で
tramp-2.8.2.2.tar を指していたが、ELPA は 2.8.2.4 に進んでいた)。一覧に
載っているかどうかだけで取り直しを決めると、起動のたびに同じ 404 を踏む。"
  (let ((min (version-to-list min-version)))
    (unless (package-installed-p pkg min)
      (condition-case err
          (condition-case nil
              (my/builtin-upgrade--install pkg min)
            (error
             (package-refresh-contents)
             (my/builtin-upgrade--install pkg min)))
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
