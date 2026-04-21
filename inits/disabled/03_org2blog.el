;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; org2blog
(leaf org2blog
  :config
  ;; ブログorgファイルのセーブ先
  (setq my-blog-directory "~/org/blog/")

  ;; 投稿設定
  (setq org2blog/wp-blog-alist
		`(("local"
		   :url "https://shirotablog.org/xmlrpc.php"
		   ;; :username "user"
		   :url "http://localhost:8888/wordpress/xmlrpc.php"
		   :username "shirota.tsubasa"
		   ;; :password "ai045nn3aws"
		   :password "ai045nn3"
		   :default-title ""
		   :default-categories nil ;カテゴリーはデフォルト
		   :track-posts (,(concat my-blog-directory ".org2blog.org") "Posts") ;.org2blogの保存先を変える
		   )))

  (setq org2blog/wp-show-post-in-browser t)
  (setq org2blog/wp-default-categories '()) ;カテゴリーは使わないので空

  (setq org2blog/wp-buffer-template
		"#+INCLUDE: ~/.emacs.d/org-macros/org-macros.setup
#+INCLUDE: ~/.emacs.d/org-macros/macro_original.setup
#+DATE: %s
#+OPTIONS: toc:t tags:t num:nil todo:nil pri:nil ^:t @:t
#+CATEGORY: %s
#+TAGS:
#+PERMALINK:
#+TITLE: %s\n

#+begin_export html
<div style=\"display:none\">
#キーワード：
1. 読者の目的・悩みとそれに対する解決方法

2. 結果の明示、記事を読んで得られるもの

3. 結果の根拠

4. 読者の行動は？（マネタイズ設計）

※常に読者のための文章を心がける
</div>
#end_export

* タイトル

" )


  ;; セーブ時のファイル名生成
  (defun my-blog-get-buffer-post-file-name ()
	"現在のバッファのファイル名を作成します。
directory/YYYY-MM-DD-permalink_or_title.orgの形式です。
directoryはmy-blog-directory変数を使います。"
	(let* ((date (org2blog/wp-get-option "DATE"))
		   (title (org2blog/wp-get-option "TITLE"))
		   (permalink (org2blog/wp-get-option "PERMALINK"))
		   (filename-date (format-time-string "%Y-%m-%d"
											  (if date (apply #'encode-time (org-parse-time-string date))
												(current-time)))))
	  (concat my-blog-directory filename-date "-" (if (> (length permalink) 0) permalink title) ".org")))

  (defun my-blog-set-buffer-file-name ()
	"デフォルトのファイル名をバッファに設定します。"
	(if (not (buffer-file-name))
		(let ((filename (my-blog-get-buffer-post-file-name)))
		  (if (y-or-n-p (format "set filename to '%s'?" filename))
			  (set-visited-file-name filename)))))

  (defun my-blog-save ()
	"バッファをセーブします。まだバッファにファイル名が設定されていないとき、
セーブする前にデフォルトのファイル名を設定するかどうかを訪ねます。"
	(interactive)
	(my-blog-set-buffer-file-name)
	(save-buffer))

  (defun blog-new ()
	"ブログの新しいエントリーを作成します。"
	(interactive)
	(org2blog/wp-new-entry)
	(local-set-key "\C-x\C-s" 'my-blog-save))

  ;; ブログディレクトリ下のファイルを開くときはorg2blogを有効にする。
  (add-hook
   'org-mode-hook
   (lambda ()
	 (if (and (buffer-file-name)
			  (string-prefix-p (expand-file-name my-blog-directory) (buffer-file-name)))
		 (org2blog/wp-mode t)))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; org2blog end
