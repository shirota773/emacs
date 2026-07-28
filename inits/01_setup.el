;;; 01_setup.el --- 基本設定 -*- lexical-binding: t; -*-
(leaf no-littering
  :ensure t
  :require t
  :config
  (with-eval-after-load 'recentf
    (add-to-list 'recentf-exclude no-littering-var-directory)
    (add-to-list 'recentf-exclude no-littering-etc-directory)))

(leaf *auto-save-files
  :config
  ;; オートセーブファイルの保存先を var/auto-save/ にまとめる
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))
  :custom
  (make-backup-files . nil)
  (auto-save-default . t)
  (create-lockfiles . nil)
  (backup-inhibited . t)
  (delete-auto-save-files . t) ;; 終了時にオートセーブファイルを消す
  )

(leaf *no-message-recentf
  :config
  (defun my/silent-function (original-function &rest args)
    "Wrap ORIGINAL-FUNCTION to prevent it from displaying messages in the minibuffer."
    (let ((inhibit-message t))
      (apply original-function args)))
  (advice-add 'auto-save-visited-file-name :around #'my/silent-function)
  (advice-add 'do-auto-save :around #'my/silent-function)
)

;; transient は 06_magit.el で :ensure + 履歴ファイル設定済み

(leaf whitespace
  :blackout (whitespace-mode global-whitespace-mode)
  :leaf-defer nil
  :custom
  (whitespace-style . '(face tabs spaces tab-mark trailing))
  ;; スペースは全角のみを可視化
  (whitespace-space-regexp . "\\(\u3000+\\)")
  (whitespace-trailing-regexp . "\\([\t\s　]+$\\)")
  (whitespace-display-mappings . '((tab-mark ?\t [?\u00bb?\t] [?\\ ?\t])))
  ;; 保存前に自動でクリーンアップ
  (whitespace-action . '(auto-cleanup))

  :init
  (global-whitespace-mode 1)
  (setq show-trailing-whitespace nil)
  :custom-face
  (whitespace-trailing . '((t (:background unspecified :foreground "gray40" :underline t :inherit nil))))
  (whitespace-tab      . '((t (:background unspecified :foreground "gray40" :underline t))))
  (whitespace-space    . '((t (:background unspecified :foreground "gray40" :underline nil :inherit nil))))
  )

;;bookmark C-x r mでブックマーク、C-x r l で一覧、C-x r b でジャンプ(consult-bookmark)
;; dired バッファで C-x r m するとディレクトリをブックマークできる。
;; ブックマークは consult-buffer (C-;) の m 絞り込みと consult-dir (C-x C-d) にも出る。
(setq bookmark-save-flag 1)
(setq bookmark-sort-flag nil)
;; ジャンプしたブックマークをリスト先頭へ (最近使った順に並ぶ)
(defun my/bookmark-arrange-latest-top (bookmark-name &rest _)
  "ジャンプした BOOKMARK-NAME を `bookmark-alist' の先頭へ移動して保存する。"
  (let ((latest (bookmark-get-bookmark bookmark-name)))
    (setq bookmark-alist (cons latest (delq latest bookmark-alist))))
  (bookmark-save))
(advice-add 'bookmark-jump :after #'my/bookmark-arrange-latest-top)
;; 一覧 (C-x r l) も j/k で移動できるように
(with-eval-after-load 'bookmark
  (define-key bookmark-bmenu-mode-map (kbd "j") #'next-line)
  (define-key bookmark-bmenu-mode-map (kbd "k") #'previous-line))

(if (version<= "26.0.50" emacs-version)
    (leaf display-line-numbers
      :init
      (global-display-line-numbers-mode)
      :custom-face
      (line-number . '((t (:foreground "DarkOliveGreen" :background "#202020"))))
      (line-number-current-line . '((t (:foreground "gold"))))))

(leaf *setup
  :config
  (electric-pair-mode 1)                ;補完
  (setq fill-column 72)
  (setq-default line-spacing 0.1)         ; 行間設定
  ;;基本インデント量4
  (setq-default c-basic-offset 4
                tab-width 4
                indent-tabs-mode nil)

  ;;
  (global-hl-line-mode 1)

  ;;; ツ ールバーの有無
  (tool-bar-mode 0)
  (menu-bar-mode 0)

  (blink-cursor-mode 0)                   ;; カーソルの点滅を止める
  (column-number-mode 1)                  ;; カーソルの位置が何文字目かを表示する
  (line-number-mode 1)                    ;; カーソルの位置が何行目かを表示する

  ;; 矩形編集
  (cua-mode t)
  (setq cua-enable-cua-keys nil)          ;;; C-cやC-vの乗っ取りのを防止
  )


;;emacsclient / with-editor (magit の commit にも必要)
(require 'server)
(unless (server-running-p)
  (server-start))

(setq visible-bell t)                   ;;; 警告音の代わりに画面フラッシュ
(setq ring-bell-function 'ignore)       ;;; ビープ音を消す

;; (setq-default indent-tabs-mode t)       ;tabをタブにする
(setq scroll-conservatively 2)  ;画面端から自動で中央にこないようにする


(if window-system
    (progn
      (set-frame-parameter nil 'alpha 96)))

(winner-mode)                           ;; windowのundo, redo
(fset 'yes-or-no-p 'y-or-n-p)           ;; "yes or no" の選択を "y or n" にする

(set-scroll-bar-mode 'nil)
(setq-default case-fold-search t)
;; コード補完 (corfu) は大文字小文字を区別、ファイル名/バッファ名は無視
(setq completion-ignore-case nil)
(setq read-file-name-completion-ignore-case t)
(setq read-buffer-completion-ignore-case t)
(setq-default dabbrev-case-fold-search t)
(setq-default dabbrev-case-replace nil)
(setq-default dabbrev-case-distinction nil)

;; テンプレートの自動挿入
(auto-insert-mode)
(setq auto-insert-directory "~/.emacs.d/insert/")
(define-auto-insert "\\.py$" "~/.emacs.d/insert/python")
(define-auto-insert "\\.sh$" "~/.emacs.d/insert/sh")
(define-auto-insert "\\.plt$" "~/.emacs.d/insert/plt")

(setq inhibit-startup-message t)        ;; スタート時のメッセージ表示オフ
(setq initial-scratch-message nil)

(set-locale-environment nil)            ;; Localeに合わせた環境の設定

;; モードラインの総行数表示は 03_modeline.el (doom-modeline) へ移した。
;; doom-modeline は mode-line-format ごと差し替えるため、ここで
;; mode-line-position を書き換えても表示されない (2026-07-28)。

;;; スクロールを一行ずつにする
(setq scroll-step 1)

;;; タイトルバーにファイル名を表示する
;; (setq frame-title-format (format "emacs@%s : %%f" (system-name)))
;; 上をコメントアウトしたとき format の引数だけが残っていた
;; (byte-compile が「0 個の書式指定に 1 引数」と警告する)。%f はモードライン
;; 構造の書式指定なので format を通す必要は無い
(setq frame-title-format "%f")
;;; 画像ファイルを表示する
(auto-image-file-mode t)

                                        ; 頭が #! だったら自動でchmod +x
(add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p)

                                        ; 前回編集していたとこの保存
(save-place-mode 1)

                                        ; 改行も含めて\C-kする。
(setq kill-whole-line t)

;; region内の置換を行う
(setq transient-mark-mode t)

;; 日本のカレンダー
(leaf calendar
  :custom
  (diary-number-of-entries . 31)
  (calendar-mark-holidays-flag . t))

(leaf japanese-holidays
  :ensure t
  :custom
  (calendar-holidays
   . (append japanese-holidays holiday-local-holidays holiday-other-holidays))
  (calendar-weekend . '(0 6))
  (calendar-weekend-marker
   . '(my-calendar-sunday-face nil nil nil nil nil my-calendar-saturday-face))
  :hook
  (today-visible-calendar-hook . calendar-mark-weekend)
  (today-invisible-calendar-hook . calendar-mark-weekend)
  )

;; 翻訳は go-translate (30_test-new.el) に移行

;;;;;;;;;;;;;;;;; OS毎のlisp ;;;;;;;;;;;;;;;;;
                                        ; OS毎の設定
(defconst darwin-p        (eq system-type 'darwin))
(defconst windows-nt-p    (eq system-type 'windows-nt))
(defconst linux-p         (eq system-type 'gnu/linux))
(defconst cygwin-p        (eq system-type 'cygwin))
(defconst berkeley-unix-p (eq system-type 'berkeley-unix))
(defconst nt-p            (eq system-type 'windows-nt))

;; (when darwin-p
;;   (load "~/.emacs.d/unix.el"))
;; (when berkeley-unix-p
;;   (load "~/.emacs.d/unix.el"))
(when windows-nt-p
  (load "~/.emacs.d/inits/win.el"))

(remove-hook
 'kill-buffer-query-functions
 'server-kill-buffer-query-function)

(put 'downcase-region 'disabled nil)

;; font-lock は自動ロードされるため明示ロードは不要
;; フォント関連の警告を抑制
(setq display-warning-suppressed-classes '(font))

;; ここにあった IME 切替連動のカーソル色制御は廃止した。
;; mac-input-source による日本語/英数の判定が実運用で安定せず、read-only 表示
;; (03_view-visual.el) と同じ set-cursor-color を奪い合うため。
;; カーソル色は read-only かどうかだけで決まる (red / cyan)。

(when (functionp 'mac-auto-ascii-mode)  ;; ミニバッファに入力時、自動的に英語モード
  (mac-auto-ascii-mode 1))

;; =============================================================================
;; Startup Screen
;; =============================================================================

(defun my/startup-screen ()
  "起動時に bookmark 一覧を表示する。
B-Tab 行が bufferlo の保存済みタブ (RET で復元)。j/k 移動は上で設定済み。
タブの自動復元 (bufferlo-bookmarks-load-at-emacs-startup) はこの後の
window-setup-hook で走る。"
  (interactive)
  (require 'bookmark)
  (bookmark-bmenu-list)
  (switch-to-buffer "*Bookmark List*")
  (delete-other-windows))

(add-hook 'emacs-startup-hook #'my/startup-screen)

(provide '01_setup)
;;; 01_setup.el ends here
