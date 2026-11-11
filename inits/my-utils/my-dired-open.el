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
  "ブラウザで開く拡張子。"
  :type '(repeat string)
  :group 'dired)

(defcustom my/dired-open-browser-app nil
  "ブラウザで開くときに名指しするアプリ。nil なら拡張子の既定アプリに委ねる。

nil のとき md が開くアプリは OS の関連付けで決まる。macOS は .md の既定が
エディタなので、ブラウザで見るにはブラウザを名指しする (05_dired.el で Vivaldi)。
Windows で .md の関連付けがブラウザ (Edge など) なら nil のままでよい。

値は `my/open-externally' の APP に渡す (macOS はアプリ名、Windows は実行ファイル名)。"
  :type '(choice (const :tag "OS の既定アプリに委ねる" nil) string)
  :group 'dired)

(defvar my/dired-open--inhibit nil
  "非 nil の間は振り分けをやめて Emacs で開く。
`my/dired-open-in-emacs' が束縛する。")

(defun my/dired-open--ext (file)
  "FILE の拡張子を小文字で返す。無ければ空文字列。
`downcase' して比較するのは dirvish 内で統一されている作法 (dirvish.el:801)。"
  (downcase (or (file-name-extension file) "")))

;; ブラウザへは `browse-url-of-file' を使わずに渡す (2026-11-11、#8 / #10)。
;; - リモートのファイルは `browse-url-of-file' が一時コピーを作るが、その記録
;;   `browse-url-temp-file-name' がバッファローカルで dired バッファに残る。
;;   同じ dired から 2 つ目を開くとコピーが作られず、リモートのパスが
;;   ftp://sshx/host:/... という URL になってブラウザに空のタブが開いていた
;; - `browse-url' の既定のハンドラは .html で終わらない file:// URL を
;;   `browse-url-emacs' で Emacs に開く。Windows では md がブラウザに行かず、
;;   リモートの md は一時コピーが書ける状態で Emacs に開いていた
;; 手元に一時コピーを作ってから `my/open-externally' に渡せば、どちらも起きない。
;; 一時コピーは html / md 単体なので、相対パスの CSS・画像は出ない。

(defvar my/dired-open--temp-files nil
  "ブラウザに渡すために作ったリモートファイルの一時コピー。終了時に消す。")

(defun my/dired-open--delete-temp-files ()
  "`my/dired-open--temp-files' を消す。`kill-emacs-hook' 用。"
  (dolist (f my/dired-open--temp-files)
    (ignore-errors (delete-file f)))
  (setq my/dired-open--temp-files nil))

(add-hook 'kill-emacs-hook #'my/dired-open--delete-temp-files)

(defun my/dired-open--local-file (file)
  "FILE が手元にあれば絶対パスを、リモートなら手元の一時コピーのパスを返す。
一時コピーは拡張子を保つ (tramp.XXXXXX.html) ので、関連付けはそのまま効く。"
  (if (not (file-remote-p file))
      (expand-file-name file)
    (let ((copy (file-local-copy file)))
      (push copy my/dired-open--temp-files)
      copy)))

(defun my/dired-open-in-browser (file)
  "FILE をブラウザ (`my/dired-open-browser-app'、nil なら既定アプリ) で開く。
リモートのファイルは手元に一時コピーを作ってから開く。"
  (my/open-externally (my/dired-open--local-file file) my/dired-open-browser-app))

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
      (my/dired-open-in-browser file)
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
