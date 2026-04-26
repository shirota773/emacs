;;; my-defuns.el --- Miscellaneous custom functions -*- lexical-binding: t; -*-

;; =============================================================================
;; 1. File & Application Utilities
;; =============================================================================

(defun open-file-in-external-app ()
  "Open a file in the default external application using a find-file-like interface."
  (interactive)
  (let* ((file (expand-file-name (read-file-name "Open file: ")))
         (command (cond
                    (windows-nt-p (list "cmd.exe" "/c" "start" "" file))
                    (darwin-p (list "open" file))
                    (linux-p (list "xdg-open" file)))))
    (apply 'start-process "external-app" nil (car command) (cdr command))))

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
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))

(defun reopen-with-sudo ()
  "Reopen current buffer-file with sudo using tramp."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if file-name
        (find-alternate-file (concat "/sudo::" file-name))
      (error "Cannot get a file name"))))

(defun revert-buffer-no-confirm ()
  "Revert buffer without confirmation."
  (interactive)
  (revert-buffer t t))

;; =============================================================================
;; 2. Search & Text Utilities
;; =============================================================================

(defvar my/word-stored nil)
(defvar my/word-regex-stored nil)

(defun my/search-word-store (str)
  (interactive "sStore word: ")
  (setq my/word-stored str))

(defun my/search-word-regex-store (str)
  (interactive "sStore regex: ")
  (setq my/word-regex-stored str))

(defun my/search-forward-regex-stored ()
  (interactive)
  (let ((word-point (point))
        (atmark-offset (string-match "@" my/word-regex-stored))
        (word-regex-stored-replaced (replace-regexp-in-string "@" "" my/word-regex-stored)))
    (search-forward-regexp word-regex-stored-replaced)
    (backward-char (length word-regex-stored-replaced))
    (forward-char atmark-offset)))

(defun my/search-forward-stored-word ()
  (interactive)
  (search-forward my/word-stored))

(defun my/search-backward-stored-word ()
  (interactive)
  (search-backward my/word-stored))

;; =============================================================================
;; 3. UI & Frame Utilities
;; =============================================================================

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
    ("LG HDR 4K" . ((top . 25) (left . 1550) (width . 206) (height . 90)))))

(defun my/adjust-frame-size-and-position ()
  (interactive)
  (let* ((monitor-name (cdr (assq 'name (frame-monitor-attributes))))
         (params (cdr (assoc monitor-name my/monitor-alist))))
    (when params
      (modify-frame-parameters nil params))))

;; =============================================================================
;; 4. Editing Utilities
;; =============================================================================

(defun my/jump-brace()
  "対応括弧へジャンプ"
  (interactive)
  (let ((c (following-char))
        (p (preceding-char)))
    (if (eq (char-syntax c) 40) (forward-list)
      (if (eq (char-syntax p) 41) (backward-list)
        (backward-up-list)))))

(defun move-to-mark ()
  (interactive)
  (let ((pos (point)))
    (goto-char (mark))
    (push-mark pos)))

(defun switch-to-buffer-extension (prompt)
  (interactive
   (list (read-buffer "Switch to buffer: " (other-buffer (current-buffer)))))
  (switch-to-buffer prompt))

(provide 'my-defuns)
