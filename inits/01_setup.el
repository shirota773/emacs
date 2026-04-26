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
  (advice-add 'recentf-cleanup :around #'my/silent-function)
  (advice-add 'auto-save-visited-file-name :around #'my/silent-function)
  (advice-add 'do-auto-save :around #'my/silent-function)
)

(leaf transient
  :ensure t)

(leaf whitespace
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
  (whitespace-trailing . '((t (:background nil :foreground "gray40" :underline t :inherit nil))))
  (whitespace-tab      . '((t (:background nil :foreground "gray40" :underline t))))
  (whitespace-space    . '((t (:background nil :foreground "gray40" :underline nil :inherit nil))))
  )

;;bookmark C-x r mでブックマーク、C-x r l でブックマークを開く
(setq bookmark-save-flag 1)
(progn
  (setq bookmark-sort-flag nil)
  (defun bookmark-arrange-latest-top ()
    (let ((latest (bookmark-get-bookmark bookmark)))
      (setq bookmark-alist (cons latest (delq latest bookmark-alist))))
    (bookmark-save))
  (add-hook 'bookmark-after-jump-hook 'bookmark-arrange-latest-top))

(if (version<= "26.0.50" emacs-version)
    (leaf display-line-numbers
      :init
      (global-display-line-numbers-mode)
      :custom-face
      (line-number . '((t (:foreground "DarkOliveGreen" :background "#202020"))))
      (line-number-current-line . '((t (:foreground "gold"))))))

;;; 一行が72字以上になった時には自動改行 する
(leaf *setup
  :config
  (electric-pair-mode 1)                ;補完
  (setq fill-column 72)
  (setq-default auto-fill-mode t)
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


;;emacsclient
(when (eq window-system 'w32)
  (when (require 'server nil t)
    (server-start)))

(defun iconify-emacs-when-server-is-done ()
  (unless server-clients (iconify-frame)))

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
(setq-default completion-ignore-case t)
(setq-default read-file-name-completion-ignore-case t)
(setq-default read-buffer-completion-ignore-case t)
(setq-default dabbrev-case-fold-search t)
(setq-default dabbrev-case-replace nil)
(setq-default dabbrev-case-distinction nil)
(setq completion-ignore-case nil)
(setq read-file-name-completion-ignore-case t)

;; テンプレートの自動挿入
(auto-insert-mode)
(setq auto-insert-directory "~/.emacs.d/insert/")
(define-auto-insert "\\.py$" "~/.emacs.d/insert/python")
(define-auto-insert "\\.sh$" "~/.emacs.d/insert/sh")
(define-auto-insert "\\.plt$" "~/.emacs.d/insert/plt")

(setq inhibit-startup-message t)        ;; スタート時のメッセージ表示オフ
(setq initial-scratch-message nil)

(set-locale-environment nil)            ;; Localeに合わせた環境の設定

(defvar my-lines-page-mode t)           ;; モードラインの割合表示を総行数表示
(defvar my-mode-line-format)

(when my-lines-page-mode
  (setq my-mode-line-format "%d")
  (if size-indication-mode
      (setq my-mode-line-format (concat my-mode-line-format " of %%I")))
  (cond ((and (eq line-number-mode t) (eq column-number-mode t))
         (setq my-mode-line-format (concat my-mode-line-format " (%%l,%%c)")))
        ((eq line-number-mode t)
         (setq my-mode-line-format (concat my-mode-line-format " L%%l")))
        ((eq column-number-mode t)
         (setq my-mode-line-format (concat my-mode-line-format " C%%c"))))

  (setq mode-line-position
        '(:eval (format my-mode-line-format
                        (count-lines (point-max) (point-min))))))

;;; スクロールを一行ずつにする
(setq scroll-step 1)

;;; タイトルバーにファイル名を表示する
;; (setq frame-title-format (format "emacs@%s : %%f" (system-name)))
(setq frame-title-format (format "%%f" (system-name)))
;;; 画像ファイルを表示する
(auto-image-file-mode t)

                                        ; 頭が #! だったら自動でchmod +x
(add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p)

                                        ; 前回編集していたとこの保存
(load "saveplace")
(setq-default save-place t)

                                        ; 改行も含めて\C-kする。
(setq kill-whole-line t)

;; region内の置換を行う
(setq transient-mark-mode t)

;; regionの文字数をカウント
(autoload 'count-chars-region "wc" nil t)

;; elの場所を探す
(autoload 'where-is-in "where" "where *.el" t)

;; regionの全角数字を半角数字に
(autoload 'replace-zen-to-ascii-region "replace-zen-to-ascii-region" nil t)

;; regionの全角数字を半角数字に
(autoload 'eperiodic "eperiodic" nil t)

;; yen
(autoload 'yen-region "yen" "yen-" t nil)

;; Riece
(autoload 'riece "riece" "Start Riece" t)

;; Color palette
(autoload 'palette "palette" "Palette" t)
                                        ;色見本
(autoload 'list-hexadecimal-colors-display "color-selection"
  "Display hexadecimal color codes, and show what they look like." t)


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

(leaf text-translator
  :config
  :bind (("C-x M-t" . text-translator-all-by-auto-selection))
  )


;; 自動選択に使用する関数を設定
(setq text-translator-auto-selection-func
      'text-translator-translate-by-auto-selection-enja)
;; グローバルキーを設定
(global-set-key "\C-xt" 'text-translator-translate-by-auto-selection)

;;;;;;;;;;;;;;;;; OS毎のlisp ;;;;;;;;;;;;;;;;;
                                        ; OS毎の設定
(setq darwin-p        (eq system-type 'darwin)
      windows-nt-p    (eq system-type 'windows-nt)
      linux-p         (eq system-type 'gnu/linux)
      cygwin-p        (eq system-type 'cygwin)
      berkeley-unix-p (eq system-type 'berkeley-unix-p)
      nt-p            (eq system-type 'windows-nt))

;; (when darwin-p
;;   (load "~/.emacs.d/unix.el"))
;; (when berkeley-unix-p
;;   (load "~/.emacs.d/unix.el"))
(when windows-nt-p
  (load "~/.emacs.d/inits/win.el"))

(setq max-specpdl-size 60000000)
(setq max-lisp-eval-depth 10000000)

(remove-hook
 'kill-buffer-query-functions
 'server-kill-buffer-query-function)

(put 'downcase-region 'disabled nil)

;; ;; font-lock をロード(色付けを行う)
(load-library "font-lock")
;; ;;fot-qarningなし
(setq display-warning-suppressed-classes '(font))

(when (fboundp 'mac-input-source)
  (defun my-mac-selected-keyboard-input-source-chage-function ()
    (let ((mac-input-source (mac-input-source)))
      (set-cursor-color
        (if (string-match "com.google.inputmethod.Japanese.Roman" mac-input-source)
            "cyan" "Red"))))
  (add-hook 'mac-selected-keyboard-input-source-change-hook
            'my-mac-selected-keyboard-input-source-chage-function))

(when (functionp 'mac-auto-ascii-mode)  ;; ミニバッファに入力時、自動的に英語モード
  (mac-auto-ascii-mode 1))
