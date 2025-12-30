(leaf wl
  :config
  ('wl-draft "wl" "Write draft with Wanderlust." t)
  ;; パスワードの保存
  ;; 一度ログインして以下を実行
  ;; M-x elmo-passwd-alist-save
  ;; http://wanderlust.github.io/wl-docs/wl-ja.html#Summary
  ;; サマリ行の形式
  ;; 番号 一時マーク 永続マーク 日付 枝 [(子の数) 差出人] 件名
  (setq wl-summary-line-format "%02n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
  ;; フォルダ毎に指定可能
  (setq wl-folder-summary-line-format-alist
		'(("%MM/るびきち" . "%02n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
		  ))
  ;; 通知
  (setq wl-biff-check-folder-list '("%inbox:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
									"%mg2/るびきち:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
									"%mg2/堀江:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
									"%inbox:mna778@gmail.com" /clear@imap.gmail.com:993!))
  ;; (setq wl-biff-check-interval '60)

  ;; folderモードのカスタマイズ変数
  (setq wl-summary-move-order 'unread)	;メッセージの優先度 new:新期

  (setq wl-use-petname nil)						;fromをあだ名にする
  (setq wl-summary-skip-mark-list '("D" "d"))		;マークがついてるメッセージは移動の際にスキップ

  ;; メッセージバッファのカスタマイズ変数
  (setq wl-message-window-size '(1 . 3))	; サマリ:メッセージのウィンドウサイズ 初期値(1 . 4)
  (setq wl-message-ignored-field-list '("^.*")) ;いったんすべてのヘッダを非表示
  (setq wl-message-visible-field-list '("^To:" "^Date:" "^From:" "^Subject:" "^Cc" "^Replay-To:"))
  (setq wl-message-sort-field-list '("^Date:" "^From:" "^Subject:" "^To:" "^Cc:" "^Replay-To:"))
  (setq wl-message-use-he7ader-narrowing 'Non-nil)

  ;; 曜日の英語表記
  (setq wl-summary-weekday-name-lang "en")
  ;; あだ名表記の有無
  (setq wl-use-petname t)
  ;; キャッシュの数
  (setq wl-message-buffer-cache-size '100)
  ;; 先読みするメッセージ数
  (setq wl-message-buffer-prefetch-depth '5)
  ;; フォルダの最初のメッセージを自動で先読みする
  (setq wl-auto-prefetch-first 'Non-nil)

  ;; サマリの形式
  ;; (setq wl-summary-line-format "%n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
  ;; %n 番号, %T 一時マーク, %P 永続マーク,

  ;; 終了時に確認する
  (setq wl-interactive-exit t)
										; 起動時にチェックしない
  ;; (setq wl-auto-check-folder-name "none")
  (setq wl-auto-check-folder-name nil)
  ;; スレッドの見た目を変える
  (setq wl-thread-indent-level 2)
  (setq wl-thread-have-younger-brother-str "+"
		wl-thread-youngest-child-str	 "+"
		wl-thread-vertical-str		 "|"
		wl-thread-horizontal-str		 "-"
		wl-thread-space-str		 " ")
										; ;; 添付ファイルに@マーク
  (setq elmo-msgdb-extra-fields
		(cons "content-type" elmo-msgdb-extra-fields))
  (setq wl-summary-line-format-spec-alist
		(append wl-summary-line-format-spec-alist
				'((?@ (wl-summary-line-attached)))))
  (setq wl-summary-line-format "%n%T%P%1@%M/%D(%W)%h:%m %t%[%17(%c %f%) %] %s")

  ;; samarryの移動を速く?
  (setq-default bidi-paragraph-direction 'left-to-right)
  ;; http://smartphone24365.blogspot.jp/2016/06/emacsimapwanderlust.html
  ;; モードライン着信通知＋ビープ音
  (setq wl-biff-check-folder-list '("%inbox"))
  (setq wl-biff-notify-hook '(ding))
  ;; http://d.hatena.ne.jp/buzztaiki/touch/searchdiary?word=%2A%5BWanderlust%5D

  :bind (wl-summary-mode-map
		 ("SPC" . wl-summary-next-line-content)
		 ("b" . wl-summary-mode-map))
  )

;; ;; (require 'wl)
;; ;; (autoload 'wl "wl" "Wanderlust" t)
;; (autoload 'wl-draft "wl" "Write draft with Wanderlust." t)
;; ;; key-bindings
;; ;; summary-mode
;; (define-key wl-summary-mode-map (kbd "SPC") 'wl-summary-next-line-content)
;;   ;; '(lambda()(interactive)(wl-summary-next-line-content)(wl-summary-next-line-content)))
;; (define-key wl-summary-mode-map (kbd "b")
;;   '(lambda()(interactive)(wl-summary-prev-line-content)(wl-summary-prev-line-content)))
;; (define-key wl-summary-mode-map (kbd "M-w") 'nil)
;; ;; folder-mode
;; (define-key wl-folder-mode-map (kbd "M-w") 'winner-undo)
;; ;; draft-moede


;; ;; パスワードの保存
;; ;; 一度ログインして以下を実行
;; ;; M-x elmo-passwd-alist-save
;; ;; http://wanderlust.github.io/wl-docs/wl-ja.html#Summary
;; ;; サマリ行の形式
;; ;; 番号 一時マーク 永続マーク 日付 枝 [(子の数) 差出人] 件名
;; (setq wl-summary-line-format "%02n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
;; ;; フォルダ毎に指定可能
;; (setq wl-folder-summary-line-format-alist
;;       '(("%MM/るびきち" . "%02n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
;; 		))
;; ;; 通知
;; (setq wl-biff-check-folder-list '("%inbox:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
;; 								  "%mg2/るびきち:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
;; 								  "%mg2/堀江:sma.yama73@gmail.com" /clear@imap.gmail.com:993!
;; 								  "%inbox:mna778@gmail.com" /clear@imap.gmail.com:993!))
;; ;; (setq wl-biff-check-interval '60)

;; ;; folderモードのカスタマイズ変数
;; (setq wl-summary-move-order 'unread)	;メッセージの優先度 new:新期

;; (setq wl-use-petname nil)						;fromをあだ名にする
;; (setq wl-summary-skip-mark-list '("D" "d"))		;マークがついてるメッセージは移動の際にスキップ

;; ;; メッセージバッファのカスタマイズ変数
;; (setq wl-message-window-size '(1 . 3))	; サマリ:メッセージのウィンドウサイズ 初期値(1 . 4)
;; (setq wl-message-ignored-field-list '("^.*")) ;いったんすべてのヘッダを非表示
;; (setq wl-message-visible-field-list '("^To:" "^Date:" "^From:" "^Subject:" "^Cc" "^Replay-To:"))
;; (setq wl-message-sort-field-list '("^Date:" "^From:" "^Subject:" "^To:" "^Cc:" "^Replay-To:"))
;; (setq wl-message-use-he7ader-narrowing 'Non-nil)

;; ;; 曜日の英語表記
;; (setq wl-summary-weekday-name-lang "en")
;; ;; あだ名表記の有無
;; (setq wl-use-petname t)
;; ;; キャッシュの数
;; (setq wl-message-buffer-cache-size '100)
;; ;; 先読みするメッセージ数
;; (setq wl-message-buffer-prefetch-depth '5)
;; ;; フォルダの最初のメッセージを自動で先読みする
;; (setq wl-auto-prefetch-first 'Non-nil)

;; ;; サマリの形式
;; ;; (setq wl-summary-line-format "%n%T%P%M/%D(%W) %t%[%17(%c %f%) %] %s")
;; ;; %n 番号, %T 一時マーク, %P 永続マーク,

;; ;; 終了時に確認する
;; (setq wl-interactive-exit t)
;; ; 起動時にチェックしない
;; ;; (setq wl-auto-check-folder-name "none")
;; (setq wl-auto-check-folder-name nil)
;; ;; スレッドの見た目を変える
;; (setq wl-thread-indent-level 2)
;; (setq wl-thread-have-younger-brother-str "+"
;;       wl-thread-youngest-child-str	 "+"
;;       wl-thread-vertical-str		 "|"
;;       wl-thread-horizontal-str		 "-"
;;       wl-thread-space-str		 " ")
;; ; ;; 添付ファイルに@マーク
;; (setq elmo-msgdb-extra-fields
;; (cons "content-type" elmo-msgdb-extra-fields))
;; (setq wl-summary-line-format-spec-alist
;; (append wl-summary-line-format-spec-alist
;; '((?@ (wl-summary-line-attached)))))
;; (setq wl-summary-line-format "%n%T%P%1@%M/%D(%W)%h:%m %t%[%17(%c %f%) %] %s")

;; ;; samarryの移動を速く?
;; (setq-default bidi-paragraph-direction 'left-to-right)
;; ;; http://smartphone24365.blogspot.jp/2016/06/emacsimapwanderlust.html
;; ;; モードライン着信通知＋ビープ音
;; (setq wl-biff-check-folder-list '("%inbox"))
;; (setq wl-biff-notify-hook '(ding))
;; ;; http://d.hatena.ne.jp/buzztaiki/touch/searchdiary?word=%2A%5BWanderlust%5D
