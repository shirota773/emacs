;;; 02_completion.el --- 補完・検索 UI 一式 -*- lexical-binding: t; -*-
;; swiper (C-s) / vertico / marginalia / consult / consult-dir / embark。
;; 補完スタイル (orderless) と補完 UI (corfu/cape) は 02_packages.el 側にある。

(require 'navigation-util)
(require 'window-util)

(file-name-shadow-mode 1)

;; =============================================================================
;; 1. Global Keybindings
;; =============================================================================
;; M-x は既定 (execute-extended-command) のため省略
(global-set-key (kbd "C-r") #'my/local-buffer-or-recentf)
(global-set-key (kbd "M-s g") 'consult-grep)
(global-set-key (kbd "M-s r") 'consult-ripgrep)
(global-set-key (kbd "M-s i") 'consult-imenu)
(global-set-key (kbd "M-o") 'embark-act)

;; C-s は swiper を維持する (consult-line では代替不可と確認済み)。
;;   - consult-line は候補を現在行起点に回転させるためバッファの行順にならない
;;   - vertico は入力のたびに選択が先頭候補へ戻るため、swiper の
;;     「入力中も現在位置付近のマッチに留まる」「C-s C-s で前回検索」を再現できない
(leaf swiper
  :ensure t
  :bind (("C-s" . swiper))
  :custom
  (ivy-count-format . "%d/%d ")
  (ivy-height . 15)
  (ivy-wrap . t))

;; =============================================================================
;; 2. Vertico & Related Packages
;; =============================================================================

(leaf vertico
  :ensure t
  :hook ((after-init-hook . vertico-mode)
         (rfn-eshadow-update-overlay-hook . vertico-directory-tidy))
  :custom
  (vertico-count . 20)
  (vertico-cycle . t)
  :config
  (require 'vertico-directory)
  :bind
  (:vertico-map
   ("C-s" . vertico-next)               ; isearch 風に C-s 連打で次候補へ
   ("C-r" . my/local-buffer-or-recentf)
   ("C-t" . my/vertico-select-directory-from-candidates)
   ("RET" . vertico-directory-enter)
   ("C-j" . vertico-exit-input)
   ("DEL" . vertico-directory-delete-char)
   ("<backspace>" . vertico-directory-delete-char)
   ("M-DEL" . vertico-directory-delete-word)
   ("M-<backspace>" . vertico-directory-delete-word)
   ("M-h" . vertico-directory-up)))

(leaf marginalia
  :ensure t
  :hook (after-init-hook . marginalia-mode))

(leaf consult
  :ensure t
  :init
  ;; Consult 本体の遅延ロード前でも、xref 読み込み時に表示設定を適用する。
  (with-eval-after-load 'xref
    (setq xref-show-xrefs-function #'consult-xref
          xref-show-definitions-function #'consult-xref))
  :bind (("M-." . xref-find-definitions)
         ("M-y" . consult-yank-pop)
         ("C-;" . consult-buffer)
         ;; 既定の bookmark-jump をプレビュー付きに置き換え
         ("C-x r b" . consult-bookmark)))

;; consult-dir: ディレクトリを起点に find-file を切り替える。
;; 現タブのプロセス用ディレクトリを最優先候補にする (tab-dir-util.el)。
(leaf consult-dir
  :ensure t
  :bind (("C-x C-d" . consult-dir)        ; 既定の list-directory を上書き
         (:vertico-map
          ("C-x C-d" . consult-dir)
          ("C-x C-j" . consult-dir-jump-file))))

;; C-. は my/dabbrev-expand-or-completing-read (94_keybinds.el) に譲る
(leaf embark
  :ensure t
  :bind (("C-h B" . embark-bindings))
  :config
  (add-to-list 'display-buffer-alist
               '("\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 (display-buffer-in-side-window)
                 (side . right)
                 (window-width . 0.3))))

(leaf embark-consult
  :ensure t
  :after (embark consult)
  :hook (embark-collect-mode-hook . embark-consult-preview-minor-mode))

(with-eval-after-load 'embark
  (define-key embark-file-map (kbd "d") (lambda (f) (interactive "f") (find-file (file-name-directory f))))
  (define-key embark-buffer-map (kbd "d") (lambda (b) (interactive "b") 
                                           (let ((f (buffer-file-name (get-buffer b))))
                                             (if f (find-file (file-name-directory f)) (message "No file"))))))

(provide '02_completion)
