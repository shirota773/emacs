(leaf windmove
  :ensure t
  ;; 矢印でwindow移動
  ;; (setq windmove-wrap-around nil)
  ;; (windmove-default-keybindings)
  :bind
  ("M-<right>" . windmove-right)
  ("M-<left>"  . windmove-left)
  ("M-<up>"    . windmove-up)
  ("M-<down>"  . windmove-down)
)

(leaf viewer
  :require t
  :custom
  (view-read-only . t)
  (viewer-modeline-color-view . "darkblue")
  (viewer-modeline-color-default . "black")
  (viewer-modeline-color-unwritable . "red")
  (view-mode-by-default-regexp . "\\.log$\\|\\.data$")

  :config
  (viewer-change-modeline-color-setup)
  (viewer-stay-in-setup)
  :bind ((:view-mode-map
          ("h" . backward-char)
          ("l" . recenter-top-bottom)
          ("o" . other-window)
          ("J" . next-line)
          ("K" . previous-line)
          ("G" . View-goto-percent)
          ("j" . View-scroll-line-forward)
          ("k" . View-scroll-line-backward)
          ("b" . View-scroll-half-page-forward)
          ("u" . View-scroll-half-page-backward)
          ("SPC" . View-scroll-page-backward)
          ))
  )

(leaf avy
  :ensure t
  :bind
  ("C-:" . avy-goto-char)
  ("M-g l" . avy-goto-line)
  ("M-g w" . avy-goto-word-1)
  ("M-g r" . avy-mark-region)
  )

(leaf web-mode
  :ensure t
  :defun
  web-mode-map
  :config
  (defun web-mode-hook ()
    "Hooks for Web mode."
    (setq time-stamp-line-limit -200)
    (if (not (memq 'time-stamp write-file-hooks))
        (setq write-file-hooks
              (cons 'time-stamp write-file-hooks))))
  :mode "\\.html"  "\\.json" "\\.js" "\\.php" "\\.css"
  :custom ((web-mode-markup-indent-offset . 2)
           (web-mode-css-indent-offset . 2)
           (web-mode-code-indent-offset . 2)
           (web-mode-indentless-elements . '("code" "pre" "textarea" "style"))
           (web-mode-offsetless-elements . '("html" "body" "tbody" "head")))

  :bind ((:web-mode-map
         ("C-c /" . web-mode-element-close)
         ("C-c a" . web-mode-element-beginning)
         ("C-c e" . web-mode-element-end)
         ("C-c i" . web-mode-element-insert)))
  :hydra
  :config
  (with-eval-after-load 'web-mode
    (require 'smartrep)
    (smartrep-define-key
        web-mode-map "C-c"
      '(("n" . web-mode-element-next)
        ("p" . web-mode-element-previous)
        ("a" . web-mode-element-beginning)
        ("e" . web-mode-element-end)
        )))
  )

(leaf highlight-indent-guides
  :ensure t
  ;;   ;; (defface highlight-indent-guides-odd-face "highlight-indent-guides")
  ;;   ;; :preface (defface highlight-indent-guides-odd-face "highlight-indent-guides")
  ;;   ;; :defvar (highlight-indent-guides . highlight-indent-guides-odd-face)
  :hook
  (((python-mode-hook web-mode-hook) . highlight-indent-guides-mode))
  :custom
  (highl
   ight-indent-guides-method . 'column)
   ;; (highlight-indent-guides-method . 'character)

  ;; (highlight-indent-guides-auto-enabled . t)
   (highlight-indent-guides-responsive . 'top)
   (highlight-indent-guides-delay . 0)
   ;; (highlight-indent-guides-character . ?\|)
   (highlight-indent-guides-auto-odd-face-perc . 15)
   (highlight-indent-guides-auto-even-face-perc . 15)
   ;; (highlight-indent-guides-auto-character-face-perc . 15)

  :config
  ;; (highlight-indent-guides-mode t)
  (set-face-background 'highlight-indent-guides-odd-face "#666666")
  (set-face-background 'highlight-indent-guides-even-face "#666666")
  (set-face-background 'highlight-indent-guides-top-even-face "#888866")
  (set-face-background 'highlight-indent-guides-top-odd-face "#888866")
  (defun my-highlighter (level responsive display)
    (if (> 1 level)
        nil
      (highlight-indent-guides--highlighter-default level responsive display)))

  (setq highlight-indent-guides-highlighter-function 'my-highlighter)
  )

(leaf crux
  :ensure t
  :config
  :bind (("C-a" . crux-move-beginning-of-line)
         ("<home>" . crux-move-beginning-of-line)
         ("M-o" . crux-smart-open-line)
         ("M-O" . crux-smart-open-line-above)
         ("<f11>" . crux-transpose-windows))
  )

(leaf comment-dwim-2
  :ensure t
  :bind (("M-;" . comment-dwim-2)))

(leaf visual-regexp-steroids
  :ensure t
  :bind (("M-%" . query-replace-regexp)
         ("C-c m" . vr/mc-mark)
         (isearch-mode-map
          ("C-t" . isearch-toggle-regexp)))
  :setq (vr/engine quote python))

(leaf key-chord
  :ensure t
  :custom (key-chord-two-keys-delay . 0.06)
  )

(leaf which-key
  :ensure t
  :config
  (which-key-mode 1))

(leaf beacon
  :ensure t
  :custom
  (beacon-color . "white")
  (beacon-blink-when-window-scrolls . nil)
  :config
  (beacon-mode 1))

(leaf fill-column-indicator
  :ensure t
  :hook
  ((markdown-mode
    git-commit-mode) . fci-mode))

(leaf minor-mode-hack              ;;;マイナーモード衝突を解決する
  :ensure t)


(leaf undohist
  :ensure t
  :config
  (undohist-initialize)
  )

(leaf smart-tab
  :ensure t)


(leaf *esup
    :defun (esup-init-loader)
    :config
    (leaf esup :ensure t)
    (leaf noflet
      :ensure t
      :config
      (defun esup-init-loader ()
        (interactive)
        (let ((files)
              (esup-user-init-file "/tmp/esup-init.el"))
          (noflet ((load (file &rest _) (push (locate-library file) files)))
                  (init-loader-load "~/.emacs.d/inits/"))
    (with-current-buffer (find-file-noselect esup-user-init-file)
      (erase-buffer)
      (dolist (file (reverse files))
        (insert-file-contents file)
        (goto-char (point-max)))
      (save-buffer))
    (esup)))))

(leaf color-moccur
  :ensure t
  :custom (moccur-split-word . t))

(leaf rainbow-delimiters
  :ensure t
  :defun (rainbow-delimiters-using-stronger-colors)
  :hook (((prog-mode-hook python-mode-hook). rainbow-delimiters-mode)
         (emacs-startup-hook . rainbow-delimiters-using-stronger-colors))
  :config
  (rainbow-delimiters-mode t)
  (defun rainbow-delimiters-using-stronger-colors ()
    (interactive)
    (cl-loop
     for index from 1 to rainbow-delimiters-max-face-count
     do
     (let ((face (intern (format "rainbow-delimiters-depth-%d-face" index))))
       (cl-callf color-saturate-name (face-foreground face) 30))))
  )

(leaf yasnippet
  :ensure t
  ;; :require yasnippet-config
  :load-path "~/.emacs.d/elpa/yasnippet"
  :config
  (setq yas-snippet-dirs
        '("~/.emacs.d/snippets/mysnippets"
          "~/.emacs.d/snippets/yasnippets"
          "~/.emacs.d/snippets/snippets"))
  (yas-global-mode 1)
  :bind* (("C-x i y" . yas/register-oneshot-snippet)
          ("C-x y" . yas/expand-oneshot-snippet)
          ;; :bind ((yas-minor-mode-map
          ("C-x i i" . yas-insert-snippet)
          ("C-x i n" . yas-new-snippet)
          ("C-x i v" . yas-visit-snippet-file)
          ("C-<tab>" . yas/expand))
  :hydra ((hydra-yas-primary
           (:hint nil)
           "yas-primary"
           ("i" yas-insert-snippet)
           ("n" yas-new-snippet)
           ("v" yas-visit-snippet-file))
          (hydra-yas
           (:color blue :hint "a")
           "
              ^YASnippets^
--------------------------------------------
  Modes:    Load/Visit:    Actions:

 _g_lobal  _d_irectory    _i_nsert

 _m_inor   _f_ile         _t_ryout
 _e_xtra   _l_ist         _n_ew
         _a_ll
"
           ("d" yas-load-directory)
           ("e" yas-activate-extra-mode)
           ("i" yas-insert-snippet)
           ("f" yas-visit-snippet-file :color blue)
           ("n" yas-new-snippet)
           ("t" yas-tryout-snippet)
           ("l" yas-describe-tables)
           ("g" yas/global-mode)
           ("m" yas/minor-mode)
           ("a" yas-reload-all)))

  )

(leaf recentf-ext
  :ensure t
  :init
  (defvar my-recentf-list-prev nil)
  (defadvice recentf-save-list
      (around no-message activate)
    "If `recentf-list' and previous recentf-list are equal,
do nothing. And suppress the output from `message' and
`write-file' to minibuffer."
    (unless (equal recentf-list my-recentf-list-prev)
      (cl-flet ((message (format-string &rest args)
                         (eval `(format ,format-string ,@args)))
                (write-file (file &optional confirm)
                            (let ((str (buffer-string)))
                              (with-temp-file file
                                (insert str)))))
        ad-do-it
        (setq my-recentf-list-prev recentf-list))))
  ;; https://masutaka.net/chalow/2011-10-30-2.html

  ;; エコーエリアに表示しない
  (defmacro with-suppressed-message (&rest body)
    (declare (indent 0))
    (let ((message-log-max nil))
      `(with-temp-message (or (current-message) "") ,@body)))


  :config
  (setq recentf-save-file "~/.recentf") ;; 保存先
  (setq recentf-max-saved-items 1000)   ;; recentf に保存するファイルの数
  (setq recentf-exclude ;; recentfに含めいないファイルの指定
        '(".recentf"
          ".ido.*"
          ".ipa"))
  (setq recentf-auto-cleanup 10)
  (setq recentf-auto-save-timer
        (run-with-idle-timer 30 t
                             '(lambda () (with-suppressed-message (recentf-save-list)))))
  (recentf-mode 1))

;; (recentf-load-list)


(leaf windata
  ;; (setq helm-windata '(frame bottom 0.4 nil))
  ;; (defun my/helm-display-buffer (buffer)
  ;;   (apply 'windata-display-buffer buffer helm-windata))
  ;; (setq helm-display-function 'my/helm-display-buffer)
  :config
  (defadvice sdic-other-window (around sdic-other-normalize activate)
    "sdic のバッファ移動を普通にする。"
    (other-window 1))
  (defadvice sdic-close-window (around sdic-close-normalize activate)
    "sdic のバッファクローズを普通にする。"
    (bury-buffer sdic-buffer-name)))


;; (leaf igrep
;;   ;; lgrepに0u8オプションをつけると出力がUTF-8になる
;;   :ensure t
;;   ;; :require t
;;   :defun igrep igrep-define igrep-find-define
;;   :config
;;   (setq grep-save-buffers nil)
;;   ;; (igrep-define lgrep (igrep-use-zgrep nil)(igre-regex-option "-n -0u8"))
;;   ;; (igrep-find-define igrep (igrep-use-zgrep nil)(igrep-regex-option "-n -0u8"))
;;   )

;; 複数*grep*バッファを使う
(leaf grep-a-lot
  :ensure t
  :config
  (grep-a-lot-advise igrep))
;; コマンド
;; grep-a-lot-restart-context現在のgrepバッファを開くM-g =
;; grep-a-lot-goto-nextgrepバッファを開くM-g ]
;; grep-a-lot-goto-prevgrepバッファを開くM-g [
;; grep-a-lot-pop-stack現在のgrepバッファを削除するM-g -
;; grep-a-lot-clear-stack全grepバッファを削除するM-g _

(leaf open-junk-file
  (setq open-junk-file-format "~/junk/%Y-%m-%d-%H.")
  (setq ediff-window-stup-function 'ediff-setup-windows-plain))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; dired


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; dired end
(leaf ace-window
  :ensure t
  :bind ("C-x o" . ace-window)
  :custom
  (aw-keys . '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  :custom-face
  (aw-leading-char-face . '((t (:height 4.0 :foreground "#f1fa8c"))))
  )


(leaf eww
  :custom
  (eww-search-prefix . "https://www.google.com/search?q=")
  :bind
  (eww-mode-map
   ("j" . next-line)
   ("k" . previous-line))
  )


(leaf ahk-mode
  :ensure t)
