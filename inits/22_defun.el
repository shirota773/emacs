(leaf *my-search
  :defvar my/word-stored my/word-regex-stored
  :config

  ;; 24/05/07 added
  (defun open-file-in-external-app ()
    "Open a file in the default external application using a find-file-like interface."
    (interactive)
    (let* ((file (expand-file-name (read-file-name "Open file: "))
                 (command (cond
                            (windows-nt-p (list "cmd.exe" "/c" "start" "" file))
                            (darwin-p (list "open" file))
                            (linux-p (list "xdg-open" file)))))
           (apply 'start-process "external-app" nil (car command) (cdr command)))))


  (defun my/search-word-store (str)
    (interactive "sStore worl: ")
    (setq word-stored str))

  (defun my/search-word-regex-store (str)
    (interactive "sStore regex: ")
    (setq regex-stored str))

  (defun my/search-forward-regex-stored ()
    (interactive)
    (let ((word-point (point))
          (atmark-offset (string-match "@" regex-stored))
          (word-regex-stored-replaced (replace-regexp-in-string "@" "" regex-stored)))
      (search-forward-regexp word-regex-stored-replaced)
      (backward-char (length word-regex-stored-replaced))
      (forward-char atmark-offset)))

  (defun my/search-word-stored-word (i)
    ;; (interactive)
    (search-forward my/word-stored))
  (defun my/search-word-stored-word-forward ()
    ;; (interactive)
    (search-forward my/word-stored))
  (defun my/search-word-stored-word (i)
    ;; (interactive)
    (search-backrward my/word-stored))

  :bind
  (("M-s s" . my/search-word-store)
   ("M-s r" . my/search-word-regex-store)
   ("C-S-s" . my/search-forward-stored-word)
   ("C-S-r" . my/search-forward-regex-stored))
  )

;; Toggle window-alpha
(defvar my/alpha-on-flag nil)
(defun my/alpha-toggle()
  (interactive)
  (if (equal my/alpha-on-flag t)
      (progn
        (set-frame-parameter nil 'alpha 98)
        (setq my/alpha-on-flag nil)
        (message "alpha-off"))
    (progn
      (set-frame-parameter nil 'alpha 85)
      (setq my/alpha-on-flag t)
      (message "alpha-on"))))

(defun my/get-buffer-create-junk ()
  (interactive)
  (switch-to-buffer (get-buffer-create "*junk*"))
  (emacs-lisp-mode))

(defvar my/monitor-alist
  '(("Built-in Retina Display" . ((top . 25) (left . 840) (width . 117) (height . 66)))
    ("LG HDR 4K" . ((top . 25) (left . 1550) (width . 206) (height . 90))))
  )

(defun my/adjust-frame-size-and-position ()
  (interactive)
  (let* ((monitor-name (cdr (assq 'name (frame-monitor-attributes))))
         (params (cdr (assoc monitor-name my/monitor-alist))))
    (when params
      (modify-frame-parameters nil params))))
(add-hook 'emacs-startup-hook 'my/adjust-frame-size-and-position)


(defun my/jump-brace()
  "対応括弧へジャンプ"
  (interactive)
  (let ((c (following-char))
        (p (preceding-char)))
    (if (eq (char-syntax c) 40) (forward-list)
      (if (eq (char-syntax p) 41) (backward-list)
        (backward-up-list)))))
(bind-key (kbd "C-]") 'my/jump-brace)

;; 10-file.el 編集中バッファのファイル名を変更する
(defun rename-file-and-buffer (new-name)
  "Renames both current buffer and file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file name new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))

;; カーソルをmarkポイントに戻す
(defun move-to-mark ()
  (interactive)
  (let ((pos (point)))
    (goto-char (mark))
    (push-mark pos)))

;; sudo でバッファを開き直す
(defun reopen-with-sudo ()
  "Reopen current buffer-file with sudo using tramp."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if file-name
        (find-alternate-file (concat "/sudo::" file-name))
      (error "Cannot get a file name"))))

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







(defadvice cua-sequence-rectangle (around my-cua-sequence-rectangle activate)
  "連番を挿入するとき、紫のところの文字を上書きしないで左にずらす"
  (interactive
   (list (if current-prefix-arg
             (prefix-numeric-value current-prefix-arg)
           (string-to-number
            (read-string "Start value: (0) " nil nil "0")))
         (string-to-number
          (read-string "Increment: (1) " nil nil "1"))
         (read-string (concat "Format: (" cua--rectangle-seq-format ") "))))
  (if (= (length format) 0)
      (setq format cua--rectangle-seq-format)
    (setq cua--rectangle-seq-format format))
  (cua--rectangle-operation 'clear nil t 1 nil
                            '(lambda (s e l r)
                               (kill-region s e)
                               (insert (format format first))
                               (yank)
                               (setq first (+ first incr)))))




(leaf *my/mode-line-cleaner
  :config
  ;; モードラインをコンパクトにする
  ;; http://syohex.hatenablog.com/entry/20130131/1359646452
  (defvar mode-line-cleaner-alist
    '( ;; For minor-mode, first char is 'space'
      (yas-minor-mode . " Ys")
      (paredit-mode . " Pe")
      (eldoc-mode . "")
      (abbrev-mode . "")
      (undo-tree-mode . "")
      (elisp-slime-nav-mode . " EN")
      (helm-gtags-mode . " HG")
      (flymake-mode . " Fm")
      (counsel . "")
      (ivy . "")


      ;; Major modes
      (lisp-interaction-mode . "Li")
      (shell-script-mode . "sh")
      (sh-mode . "sh")
      (python-mode . "Py")
      (ruby-mode   . "Rb")
      (emacs-lisp-mode . "El")
      (markdown-mode . "Md")
      (company-capf . "comp.")
      (counsel . "")
      (helm-mode) ))

  (defun my/clean-mode-line ()
    ;; (interactive)
    ;; (loop for (mode . mode-str) in mode-line-cleaner-alist
    (cl-loop for (mode . mode-str) in mode-line-cleaner-alist
             do
             (let ((old-mode-str (cdr (assq mode minor-mode-alist))))
               (when old-mode-str
                 (setcar old-mode-str mode-str))
               ;; major mode
               (when (eq mode major-mode)
                 (setq mode-name mode-str)))))

  (add-hook 'after-change-major-mode-hook 'my/clean-mode-line)
  )

;; window-resize
(defun window-resizer ()
  "Control window size and position."
  (interactive)
  (let ((window-obj (selected-window))
        (current-width (window-width))
        (current-height (window-height))
        (dx (if (= (nth 0 (window-edges)) 0) 1
              -1))
        (dy (if (= (nth 1 (window-edges)) 0) 1
              -1))
        c)
    (catch 'end-flag
      (while t
        (message "size[%dx%d]"
                 (window-width) (window-height))
        (setq c (read-char))
        (cond ((= c ?l)
               (enlarge-window-horizontally dx))
              ((= c ?h)
               (shrink-window-horizontally dx))
              ((= c ?j)
               (enlarge-window dy))
              ((= c ?k)
               (shrink-window dy))
              ;; otherwise
              (t
               (message "Quit")
               (throw 'end-flag t)))))))

(defun revert-buffer-no-confirm ()      ;;; 変更されたファイルを自動的に読み込む
  "Revert buffer without confirmation."
  (interactive) (revert-buffer t t))
(bind-key* (kbd "C-c C-r") 'revert-buffer-no-confirm)
(global-auto-revert-mode 1)
;; sdic-display-buffer 書き換え
(defadvice sdic-display-buffer (around sdic-display-buffer-normalize activate)
  "sdic のバッファ表示を普通にする。"
  (setq ad-return-value (buffer-size))
  (let ((p (or (ad-get-arg 0)
               (point))))
    (and sdic-warning-hidden-entry
         (> p (point-min))
         (message "この前にもエントリがあります。"))
    (goto-char p)
    (display-buffer (get-buffer sdic-buffer-name))
    (set-window-start (get-buffer-window sdic-buffer-name) p)))

;; switch-to-buffer で 存在しないバッファ名を指定した時に新規バッファとして開けるようにする。
(defun switch-to-buffer-extension (prompt)
  (interactive
   (list (read-buffer "Switch to buffer: " (other-buffer (current-buffer)))))
  (switch-to-buffer prompt))
(global-set-key "\C-xb" 'switch-to-buffer-extension)







