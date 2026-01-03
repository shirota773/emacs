(leaf json-mode
  :mode "\\.json"
  :custom
  (js-indent-level . 2)
  )

(leaf magit
  :ensure t
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch)))

(leaf visual-basic-mode
  ;; :ensure t
  :hook
  (visual-baisc-mode-hook . (lambda () (display-line-numbers-mode t)))
  )

(leaf ace-link
  :ensure t
  :config
  (ace-link-setup-default)
  (set-face-attribute 'avy-lead-face nil
                    :foreground "black"
                    :background "cyan"
                    :weight 'bold)
)

(leaf ibuffer
  :bind
  ("C-x C-b" . ibuffer)
  :hook
  (ibuffer-hook
   . (lambda ()
       (ibuffer-switch-to-saved-filter-groups "custom")
       ;; (ibuffer-do-sort-by-recency)
       (ibuffer-do-sort-by-major-mode)))

  :custom
  (ibuffer-saved-filter-groups
         . '(("custom"
           ("Default" (not (or (mode . help-mode)
                               (mode . Info-mode)
                               (mode . dired-mode)
                               (name . "^\*.*\*$"))))
           ("Dired" (mode . dired-mode))
           ("Help/Info" (or (mode . help-mode)
                            (mode . Info-mode)))
           ("Special Buffers" (name . "^\*.*\*$")))))

  (ibuffer-formats
        . '((mark modified read-only locked " "
                (name 30 25 :left :elide)
                " "
                (size 9 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " "
                filename)))
  (ibuffer-show-empty-filter-groups . nil)
  (ibuffer-display-summary . t)

  :config
  (define-ibuffer-column size
    (:name "Size" :inline t)
    (format "%6dk" (/ (buffer-size) 1024)))
)



(leaf all-the-icons
  :ensure t
  :config
  ;; (all-the-icons-install-fonts)  ;;初回のみ
  ;; :bind (("C-b" . hydra-b-primary/body))
  :hydra
  (hydra-all-the-icons
   (:color blue :hint nil :exit nil)
   "
^all-the-icons^
Insert:
------------------
[_a_]: All the icons   [_f_]: File icons [_F_]: FontAwsome
[_m_]: Material        [_o_]: Octicon    [_w_]: weather
[_*_]: ALL"
   ("a" all-the-icons-insert-alltheicon :exit nil)
   ("f" all-the-icons-insert-fileicons :exit nil)
   ("F" all-the-icons-insert-faicons :exit nil)
   ("m" all-the-icons-insert-material :exit nil)
   ("o" all-the-icons-insert-oction :exit nil)
   ("w" all-the-icons-insert-wicon :exit nil)
   ("*" all-the-icons-insert :exit nil)
   ))


(leaf nerd-icons)

(leaf puni
  :ensure t
  :config
  ;; (smartrep-define-key global-map "C-c v"
  :bind (("C-b" . hydra-b-primary/body))
  :hydra
  (hydra-b-primary
   (:color blue :hint nil :exit nil)
   "
^puni^
------------------
[_c_]: puni-list-around  [_e_]: puni-expand
"
   ("c" puni-mark-list-around-point :exit nil)
   ("e" puni-expand-region :exit nil)
   ("l" puni-forward-sexp-or-up-list :exit nil)
   ("f" puni-forward-sexp :exit nil)
   ("b" puni-backward-sexp-or-up-list :exit nil)
   ("d" puni-forward-kill-word :exit nil)
   ("a" puni-beginning-of-sexp :exit nil)
   ("s" hydra-puni-slurp/body))
  (hydra-puni-slurp
   (:color bleu :hint nil)
   "
puni-slurp
[_q_]: exit
[_f_]: puni-slurp-forward [_b_]: puni-slurp-forward
[_F_]: puni-barf-forward [_B_]: puni-barf-forward
"
   ("f" puni-slurp-forward)
   ("b" puni-slurp-backward)
   ("F" puni-barf-forward)
   ("B" puni-barf-backward)
   ("q" nil )
   )
  )

(setq auto-save-file-name-tranforms
      `((".*", (expand-file-name "~/.emacs.d/backup/") )))


;; (leaf windmove
;;   :after smartrep
;;   :custom
;;   (windmove-mode . nil)
  ;; :config
  ;; :smartrep
  ;; (smartrep-define-key global-map "C-c"
  ;; ("C-c"
  ;;   (("<left>" . windmove-left)
  ;;     ("<right>" . windmove-right)
  ;;     ("<up>" . windmove-up)
  ;;     ("<down>" . windmove-down)
  ;;     ("o" . other-window)
  ;;     ))
  ;; )

(leaf org-ql
  :ensure t)

(leaf deft
  :ensure t
  :custom
  (deft-extensions . '(org))
  )

(leaf org-appear
:hook
(org-mode-hook . org-appear-mode)
:custom
(org-hidden-keywords . '(title author date begin_scr begin property email))
(org-appear-trigger . 'always)

(org-appear-autoemphasis . t)
(org-appear-autolinks . t)
(org-appear-autosubmarkers . nil)
(org-appear-autoentities . nil)
(org-appear-autokeywords . t)
(org-appear-inside-latex . nil)
(org-appear-delay . 0.2)

(org-pretty-entities . t)
(org-hide-emphasis-markers . t)
(org-link-descriptive . t)
)


;; <2023-11-19 Sun>
(defun my-silent-function (original-function &rest args)
  "Wrap ORIGINAL-FUNCTION to prevent it from displaying messages in the minibuffer."
  (let ((inhibit-message t))
    (apply original-function args)))

(advice-add 'recentf-cleanup :around #'my-silent-function)
(advice-add 'auto-save-visited-file-name :around #'my-silent-function)
(advice-add 'do-auto-save :around #'my-silent-function)


;;;;

(defun reorder-window-list ()
  "ウィンドウリストを再配置して、main-windowをリストの先頭に持ってきます。"
  (let* ((windows (window-list))
         (main-window (car (cl-remove-if-not (lambda (win)
                                              (let ((edges (window-edges win)))
                                                (and (= (car edges) 0) (= (cadr edges) 0))))
                                            windows))))
    (if main-window
        (let ((post-main-windows (cdr (memq main-window windows)))
              (pre-main-windows (reverse (cdr (memq main-window (reverse windows))))))
          (append (list main-window) post-main-windows pre-main-windows))
      windows)))

(leaf lua-mode
  :config
  )


(defun my-org-screenshot ()
  "Save a clipboard's screenshot into a time stamped unique-named file
   in a specified directory and insert a link to this file."
  (interactive)
  (setq filename
        ;; (concat
        ;; (make-temp-name
        (concat
         ;; org-directory
         "/Users/yamazaki/org_icloud"
         "/images/"
         (buffer-name)
         "_"
         (format-time-string "%Y%m%d_")  ".png"))
  (call-process "pngpaste" nil nil nil filename)
  (insert (concat "[[" filename "]]"))
  (org-display-inline-images))


(defun my-switch-buffer ()
  (interactive)
  (let ((current-window (selected-window))
        (current-buffer (current-buffer))
        (next-window (next-window))
        (third-window (get-buffer-window "*scratch*"))) ; 仮に3番目のウィンドウを特定するために*scratch*バッファを使うことにします。
    (cond ((eq current-window (get-buffer-window "*scratch*")) ; 3番目のウィンドウがアクティブなら
           (switch-to-buffer (window-buffer (next-window third-window))) ; 3番目のウィンドウに2番目のバッファを移す
           (select-window next-window) ; 2番目のウィンドウを選択
           (switch-to-buffer current-buffer)) ; 現在のバッファを2番目のウィンドウに移す
          ((eq current-window next-window) ; 2番目のウィンドウがアクティブなら
           (switch-to-buffer (window-buffer third-window)) ; 2番目のウィンドウに3番目のバッファを移す
           (select-window third-window) ; 3番目のウィンドウを選択
           (switch-to-buffer current-buffer)) ; 現在のバッファを3番目のウィンドウに移す
          (t ; 1番目のウィンドウがアクティブなら
           (switch-to-buffer (window-buffer next-window)) ; 1番目のウィンドウに2番目のバッファを移す
           (select-window next-window) ; 2番目のウィンドウを選択
           (switch-to-buffer current-buffer)))) ; 現在のバッファを2番目のウィンドウに移す
  (other-window 1))


(leaf doom-modeline
  :custom
  ;; (doom-modeline-buffer-file-name-style . truncate-with-project)
  (doom-modeline-icon . t)
  (doom-modeline-major-mode-icon . nil)
  (doom-modeline-minor-modes . nil)
  :hook
  (after-init . doom-modeline-mode)
  :config
  67  (line-number-mode 0)
  (column-number-mode 0)
  (doom-modeline-def-modeline
   'main
   '(bar workspace-number window-number evil-state god-state ryo-modal xah-fly-keys matches buffer-info remote-host buffer-position parrot selection-info)
   '(misc-info persp-name lsp github debug minor-modes input-method major-mode process vcs checker)))


(leaf *my/window-buffer
  :config
  (defun my/display-buffer-action (buffer alist)
    (let ((current-buffer (current-buffer))
          (window-list (my/window-list))
          (existing-window (get-buffer-window buffer (selected-frame)))
          (active-window (selected-window)))
      (neotree-hide)
      (cond
       ;; Bufferが既に存在するウィンドウがある場合
       (existing-window
        (select-window existing-window))
       ;; Windowが1つ（もしくはそれ以下）のとき
       ((<= (length window-list) 1)
        (set-window-buffer (split-window-right) buffer))
       ;; Windowが2つのとき
       ((= (length window-list) 2)
        (select-window (nth 1 (window-list)))
        (split-window-below)
        (set-window-buffer (nth 1 window-list) buffer)
        )
       ;; Windowが3つ以上のとき
       (t
        (set-window-buffer (nth 2 window-list) buffer)
        ;; (select-window (nth 0 window-list))
        )
       )
      (select-window active-window)
      ))

  (defun my/sidplay-buffer-action (buffer alist)
    (let
        ((curent-buffer (current-buffer))
         (window-list (window-list)))
      (cond ((<= (lingth window-list) 1)
             (set-window-buffer (split=window-right) buffer))
            ((= (length window-list) 2)
                (select-window (nth 1 window-list))
                (split-window-below)
                (set-window-buffer (nth 1 (window-list)) buffer)
                (select-window (nth 0 window-list)))
            (t (set-window-buffer (nth 2 window-list) buffer)
               (select=window (nth 0 window-list))
               )));let
    ) ;defun


  (defun my/display-buffer-action-open-in-2nd-window (buffer alist)
    (let ((current-buffer (current-buffer))
          (window-list (my/window-list))
          (active-window (selected-window)))
      (set-window-buffer (nth 0 window-list) buffer)
      (select-window active-window)
      )
    )

  (setq display-buffer-alist
        '(
          ;; ("\\*Org Select\\*" display-buffer-in-child-frame)
          ("\\*Org Select\\*" display-buffer-same-window)
          ;; ("\\*.*\\*"  my/display-buffer-action)
          ("\\*Help\\*"  my/display-buffer-action)
          ("\\*grep\\*"  my/display-buffer-action)
          ("\\*message\\*"  my/display-buffer-action)
          ("\\*Warnings\\*"  my/display-buffer-action)
          (".*" display-buffer-same-window)
          ;; (".*"  my/display-buffer-action-open-in-2nd-window))
          ))

  (defun my/window-list ()
    "Return a list of windows, ordered from top-left to bottom-right."
    (let ((windows (window-list))
          (compare-fn (lambda (w1 w2)
                        (let ((edge1 (window-edges w1))
                              (edge2 (window-edges w2)))
                          (or (< (car edge1) (car edge2))
                              (and (= (car edge1) (car edge2))
                                   (< (cadr edge1) (cadr edge2))))))))
      (sort windows compare-fn)))

  )


(defun my/org-collaspe-current-headline ()
  (interactive)
  (let ((current-outline-level (org-current-level)))
    (org-previous-visible-heading 1)
    (if (= current-outline-level (org-current-level))
        (org-cycle)
      (outline-up-heading 1)
      (org-cycle)
      )))


(window-list)


;; バッファの開き方
;; 使える関数
;; display-buffer-pop-up-window  新しいウィンドウが作られる(分割される)
;; display-buffer-pop-up-frame 使ったらフリーズした
;; display-buffer-reuse-window 既存ウィンドウを再利用. 利用できないときは新規
;; isplay-bufer-use-some-window 既存ウィンドウを再利用. 新規には作成しない



(defun my/org-startup-level ()
  "Set initial headline visibility based on `#+STARTUP_LEVEL:' setting.
Default level is 1 if the setting is not specified."
  (interactive)
  (let* ((startup-levels (org-collect-keywords '("STARTUP_LEVEL")))
         (level-keyword (cadr (assoc "STARTUP_LEVEL" startup-levels)))
         (level (if level-keyword
                    ;; (string-to-number (cdr level-keyword))
                    (string-to-number level-keyword)
                  1)))
    (outline-hide-sublevels level)))
(add-hook 'org-mode-hook #'my/org-startup-level)
(remove-hook 'org-mode-hook 'org-mode-keybinds)


;(leaf twittering-mode
;  :ensure t)

(leaf google-translate
  :config
  (defvar google-translate-english-chars "[:ascii:]’“”–"
    "これらの文字が含まれているときは英語とみなす")
  (defun google-translate-enja-or-jaen (&optional string)
    "regionか、現在のセンテンスを言語自動判別でGoogle翻訳する。"
    (interactive)
    (setq string
          (cond ((stringp string) string)
                (current-prefix-arg
                 (read-string "Google Translate: "))
                ((use-region-p)
                 (buffer-substring (region-beginning) (region-end)))
                (t
                 (save-excursion
                   (let (s)
                     (forward-char 1)
                     (backward-sentence)
                     (setq s (point))
                     (forward-sentence)
                     (buffer-substring s (point)))))))
    (let* ((asciip (string-match
                    (format "\\`[%s]+\\'" google-translate-english-chars)
                    string)))
      (run-at-time 0.1 nil 'deactivate-mark)
      (google-translate-translate
       (if asciip "en" "ja")
       (if asciip "ja" "en")
       string)))
  ;; (global-set-key (kbd "C-c t") 'google-translate-enja-or-jaen)
  :bind* (("C-c t" . google-translate-enja-or-jaen)
          ("C-c g" . google-translate-at-point))
  )

;; (leaf vimish-fold
;;   :custom
;;   (vimish-fold-global-mode . t)
;;   (vimish-fold-indication-mode . 'right-fringe)
;;   (vimish-fold-header-width . 90)
;;   ;; (vimish-fold-blank-fold-header . )
;;   :bind (("M-s a" . vimish-fold-avy)
;;          ("M-s u" . vimish-fold-unfold)
;;          ("M-s r" . vimish-fold-refold)
;;          ("M-s t" . vimish-fold-toggle)
;;          ("M-s d" . vimish-fold-delete)
;;          ("M-s p" . vimish-fold-previous-fold)
;;          ("M-s n" . vimish-fold-next-fold))
;;   )

(leaf ace-window
  :custom
  ;; (ace-window-mode . 1)
  (aw-keys . '(?j ?k ?l ?i ?o ?h ?y ?u ?p))
  (aw-char-position . 'left)
  (aw-scope . 'global)
  :config
  :bind
  ()
  )


;; neotree
(leaf neotree
  :ensure t)
;;   :config
;;   (defun my/neotree-enter-and-hide ()
;;     (interactive)
;;     (neotree-enter)
;;     (neotree-hide))
;;   (defun my/neotree-enter-ace-window-and-hide ()
;;     (interactive)
;;     (neotree-enter-ace-window)
;;     (neotree-hide))

;;   (defun my/other-window-skip-neotree (&optional n)
;;     (other-window n)
;;     (if (string= (buffer-name) " *NeoTree*")
;;         (other-window n)))
;;   (defun my/next-window-skip-neotree ()
;;     (interactive)
;;     (my/other-window-skip-neotree 1))
;;   (defun my/previous-window-skip-neotree ()
;;     (interactive)
;;     (my/other-window-skip-neotree -1))

;;   :custom
;;   (neo-window-position . "right")
;;   (neo-window-width . 40)

;;   :bind (("<f8>" . neotree-toggle)
;;          ("M-<f8>" . neotree-hide)
;;          ("C-M-o" . my/next-window-skip-neotree)
;;          ("C-S-o" . my/previous-window-skip-neotree)
;;          ;; ("C-c M-C-o" . neotree-show)
;;          ;; ("C-c C-S-o" . neotree-toggle)
;;          ("C-c C-M-o" . neotree-toggle)
;;          ("C-c C-d" . neotree-dir)
;;          (neotree-mode-map
;;           ("j" . neotree-next-line)
;;           ("k" . neotree-previous-line)
;;           ("J" . neotree-select-next-sibling-node)
;;           ("K" . neotree-select-previous-sibling-node)
;;           ;; ("f" . neotree-enter)
;;           ;; ("F" . neotree-enter-ace-window)
;;           ("f" . my/neotree-enter-and-hide)
;;           ("F" . my/neotree-enter-ace-window-and-hide)
;;           ("+" . neotree-create-node)
;;           ("r" . neotree-rename-node)))
;;   )

;; ivy
;; https://takaxp.github.io/articles/qiita-helm2ivy.html
;; https://qiita.com/takaxp/items/2fde2c119e419713342b helmを背にivyの門を叩く



(setq magit-process-log-max 100)
(setq magit-git-debug t)
