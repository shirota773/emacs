;;; my-markdown-preview.el --- Markdown を Emacs 内で閲覧する -*- lexical-binding: t; -*-

;; .md をブラウザに投げずに Emacs の中で読むための道具立て。手段を 2 つ用意する。
;; 速さと忠実さのトレードオフが逆なので、どちらか一方に寄せずに併置する。
;;
;;   1. `markdown-view-mode' — markdown-mode 同梱。記法を隠し見出しを拡大して
;;      テキストのまま読む。外部プロセスを起こさないので即座に開き、TRAMP 越し
;;      でも動く。表の罫線や引用の見た目は素のテキストのまま。
;;      `my/markdown-view-toggle' で編集モードと往復する。
;;   2. `my/markdown-preview-xwidget' — pandoc で HTML にして xwidget-webkit に
;;      描画する。表・脚注・チェックボックスまでブラウザと同じ見た目になるが、
;;      pandoc の起動ぶん遅く、Emacs が XWIDGETS 付きビルドである必要がある。
;;
;; 2 は markdown-mode の `markdown-preview' をそのまま使い、開き先だけ差し替える。
;;
;;   markdown-preview → browse-url-of-buffer → browse-url → browse-url-browser-function
;;
;; と辿るので、`browse-url-browser-function' を let で束縛すれば経路ごと奪える。
;; HTML 生成 (`markdown-standalone' と `markdown-xhtml-header-content' の差し込み)
;; を書き直さずに済むので、markdown-mode 側の変更に追随できる。

(require 'browse-url)

(declare-function markdown-mode "markdown-mode")
(declare-function markdown-view-mode "markdown-mode")
(declare-function gfm-mode "markdown-mode")
(declare-function gfm-view-mode "markdown-mode")
(declare-function markdown-preview "markdown-mode")
(declare-function xwidget-webkit-browse-url "xwidget")

(defconst my/markdown-preview-css
  "<style>
:root { color-scheme: light dark; }
body {
  max-width: 46rem; margin: 2.5rem auto; padding: 0 1.5rem;
  font-family: -apple-system, 'Hiragino Sans', 'Yu Gothic UI', 'Meiryo', sans-serif;
  font-size: 16px; line-height: 1.85;
  color: #24292f; background: #ffffff;
}
h1, h2, h3, h4 { line-height: 1.3; margin: 2em 0 0.6em; font-weight: 600; }
h1 { font-size: 1.9em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
h2 { font-size: 1.45em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
h3 { font-size: 1.2em; }
p, ul, ol, blockquote, table, pre { margin: 0 0 1.1em; }
a { color: #0969da; }
code {
  font-family: 'SF Mono', Menlo, Consolas, monospace; font-size: 0.88em;
  background: rgba(129,139,152,0.15); padding: 0.2em 0.4em; border-radius: 4px;
}
pre { background: #f6f8fa; padding: 1em; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: 0.85em; }
blockquote {
  border-left: 3px solid #d0d7de; padding-left: 1em; margin-left: 0; color: #57606a;
}
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid #d0d7de; padding: 0.45em 0.9em; }
th { background: rgba(129,139,152,0.12); }
img { max-width: 100%; }
hr { border: none; border-top: 1px solid #d0d7de; margin: 2em 0; }
/* 横並び。md 側は pandoc の fenced div で ::: cols … ::: と囲む。
   直下の子 (段落でも ::: col の塊でも) が自動で列になる。 */
.cols {
  display: grid; gap: 0 2rem; align-items: start;
  grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
}
.cols-2 { grid-template-columns: 1fr 1fr; }
.cols-3 { grid-template-columns: 1fr 1fr 1fr; }
.cols > * { min-width: 0; }
.cols > * > :first-child, .cols > :first-child { margin-top: 0; }
/* 折りたたみ。md 側は <details><summary>…</summary> … </details> (GFM 標準) */
details {
  border: 1px solid #d0d7de; border-radius: 6px;
  padding: 0.6em 1em; margin-bottom: 1.1em;
}
details > summary { cursor: pointer; font-weight: 600; }
details[open] > summary { margin-bottom: 0.8em; }
@media (prefers-color-scheme: dark) {
  body { color: #c9d1d9; background: #0d1117; }
  h1, h2, hr { border-color: #30363d; }
  a { color: #58a6ff; }
  pre { background: #161b22; }
  blockquote { border-left-color: #30363d; color: #8b949e; }
  th, td { border-color: #30363d; }
  details { border-color: #30363d; }
}
</style>"
  "xwidget プレビューの HTML に差し込むスタイルシート。
`markdown-xhtml-header-content' へ設定して使う。素の HTML は行長が画面幅一杯に
なって日本語が読めたものではないので、行長・行間・コードブロックだけ整える。
`prefers-color-scheme' で明暗に両対応させるのは、xwidget が OS のテーマに従い
Emacs 側のテーマを見ないため。")

(defun my/markdown--base-tag ()
  "編集中のファイルの位置を指す <base> タグを返す。ファイル以外を見ているなら空文字列。

これが無いと**相対パスの画像が表示されない**。`markdown-preview' は
`browse-url-of-buffer' 経由で一時ファイル (/var/folders/.../burlXXXX.html) に
HTML を書き出すため、`![](img/foo.png)' の基準ディレクトリが元の .md ではなく
一時ディレクトリになってしまう。<base> で基準を元ファイルへ戻す。

`browse-url-file-url' を使うのは、パスに空白や日本語が入っても正しく URL
エンコードさせるため。TRAMP 越しのリモートファイルは file:// にできないので諦める。"
  (let ((dir (and buffer-file-name
                  (not (file-remote-p buffer-file-name))
                  (file-name-directory buffer-file-name))))
    (if dir
        (format "<base href=\"%s\" />\n" (browse-url-file-url dir))
      "")))

(defun my/markdown--header-content ()
  "プレビュー HTML の <head> に差し込む内容を返す。
`markdown-xhtml-header-content' を let で束縛して使う。基準パスはバッファごとに
違うので、defcustom の静的な値では足りない。"
  (concat (my/markdown--base-tag) my/markdown-preview-css))

(defun my/markdown--ensure-xwidget ()
  "xwidget が使えないなら分かるエラーを出す。
XWIDGETS 無しでビルドされた Emacs だと `xwidget-webkit-browse-url' が
void-function になり、原因が分かりにくい形で失敗する。"
  (unless (featurep 'xwidget-internal)
    (user-error "この Emacs は XWIDGETS 無しでビルドされている (C-c C-c p でブラウザへ)"))
  (require 'xwidget))

(defun my/markdown-preview-xwidget ()
  "現在の Markdown を pandoc で HTML にし、xwidget-webkit で Emacs 内に表示する。
`markdown-preview' の開き先を差し替えるだけなので、変換の設定
 (`markdown-command') はそのまま効く。"
  (interactive)
  (my/markdown--ensure-xwidget)
  (let ((markdown-xhtml-header-content (my/markdown--header-content))
        (browse-url-browser-function #'xwidget-webkit-browse-url))
    (markdown-preview)))

(defun my/markdown-preview-browser ()
  "現在の Markdown をブラウザでプレビューする。
`markdown-preview' そのままでは相対パスの画像が出ないので、<base> を足すぶんだけ
包んである。開き先は `browse-url-browser-function' に従う。"
  (interactive)
  (let ((markdown-xhtml-header-content (my/markdown--header-content)))
    (markdown-preview)))

(defun my/markdown-view-toggle ()
  "閲覧モードと編集モードを往復する。ポイント位置は保つ。
GFM 版を使っているバッファは GFM 版のまま往復する。判定は派生の深い順に見る
 (gfm-view-mode ⊂ gfm-mode ⊂ markdown-mode、markdown-view-mode ⊂ markdown-mode)。"
  (interactive)
  (let ((pos (point)))
    (cond
     ((derived-mode-p 'gfm-view-mode) (gfm-mode))
     ((derived-mode-p 'markdown-view-mode) (markdown-mode))
     ((derived-mode-p 'gfm-mode) (gfm-view-mode))
     ((derived-mode-p 'markdown-mode) (markdown-view-mode))
     (t (user-error "Markdown バッファではない")))
    (goto-char (min pos (point-max)))))

(provide 'my-markdown-preview)
;;; my-markdown-preview.el ends here
