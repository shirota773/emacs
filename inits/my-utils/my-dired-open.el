;;; my-dired-open.el --- 拡張子ごとに開き方を振り分ける -*- lexical-binding: t; -*-

;; 動画のように Emacs で開けないファイルをクリックすると、Emacs がバイナリを
;; 読み込んでしまう。OS のファイラなら VLC が立ち上がるところで、ファイラとして
;; 使う前提が崩れる。拡張子を見て開き先を振り分ける。
;;
;; 振り分けは `dirvish-find-entry-hook' に 1 つ関数を足すだけで済む。
;; `dirvish-override-dired-mode' が `dired--find-file' を `dirvish--find-entry' で
;; :override しているため (dirvish.el:1553)、
;;
;;   dired-find-file → dired--find-possibly-alternative-file → dired--find-file
;;                                                              → dirvish--find-entry
;;                                                              → このフック
;;
;; という連鎖になり、RET / l / マウス左クリック / 中クリック / パンくず / subtree /
;; 履歴ジャンプが**すべて 1 箇所を通る**。フックは (FILENAME FIND-FN) で呼ばれ、
;; 非 nil を返すと以降の処理を打ち切る。
;;
;; 外部アプリの起動は `my/open-externally' (my-defuns.el) に任せる。OS 分岐・
;; TRAMP ガード・アプリ指定が実装済みで、review-notes.md §5 に「プラットフォーム
;; 分岐を再度散らかさない」という確定判断がある。ここで call-process を書かない。

(require 'dired)
(require 'dirvish)
(require 'browse-url)

(declare-function my/open-externally "my-defuns")

(defcustom my/dired-open-external-exts
  (append dirvish-image-exts dirvish-video-exts dirvish-audio-exts
          dirvish-font-exts dirvish-archive-exts
          '("pdf" "epub" "gif" "icns"
            "doc" "docx" "xls" "xlsx" "ppt" "pptx" "key" "numbers" "pages"))
  "OS の既定アプリで開く拡張子。Emacs で開いても読めないものを並べる。
既定は dirvish が持っている一覧 (`dirvish-binary-exts' と同じ内訳) に Office 系を
足したもの。値をベタ書きせず dirvish の定数から組むので、上流が拡張子を足せば追随する。
Emacs で開きたいときは `v' (`my/dired-open-in-emacs') か C-u を前置する。"
  :type '(repeat string)
  :group 'dired)

(defcustom my/dired-open-browser-exts '("html" "htm" "md" "markdown")
  "ブラウザで開く拡張子。
md をブラウザで開いても素のテキストが出るだけ (Chrome も Safari も Markdown を
整形しない)。整形して読みたいなら md をここから外し
`my/dired-open-external-exts' へ移すと、OS の既定アプリ (Marked 等) で開く。"
  :type '(repeat string)
  :group 'dired)

(defvar my/dired-open--inhibit nil
  "非 nil の間は振り分けをやめて Emacs で開く。
`my/dired-open-in-emacs' が束縛する。")

(defun my/dired-open--ext (file)
  "FILE の拡張子を小文字で返す。無ければ空文字列。
`downcase' して比較するのは dirvish 内で統一されている作法 (dirvish.el:801)。"
  (downcase (or (file-name-extension file) "")))

(defun my/dired-open-dispatch (file find-fn)
  "FILE を拡張子に応じて外部で開く。開いたら非 nil を返す。
`dirvish-find-entry-hook' 用。非 nil を返すと dirvish は以降の処理をやめる。"
  (let ((ext (my/dired-open--ext file)))
    (cond
     ;; ディレクトリと、dired バッファの初回生成は素通し
     ((file-directory-p file) nil)
     ((eq find-fn 'dired) nil)
     ;; エスケープハッチ。v からと C-u 前置から
     (my/dired-open--inhibit nil)
     (current-prefix-arg nil)
     ((member ext my/dired-open-browser-exts)
      (browse-url-of-file (expand-file-name file))
      t)
     ((member ext my/dired-open-external-exts)
      (my/open-externally file)
      t))))

(defun my/dired-open-in-emacs ()
  "ポイント下のファイルを、振り分けを無視して Emacs で開く。
md を編集したい、画像を image-mode で見たい、といったとき用。
C-u を前置した RET / クリックでも同じことができる。"
  (interactive)
  (let ((my/dired-open--inhibit t))
    (dired-find-file)))

(provide 'my-dired-open)
;;; my-dired-open.el ends here
