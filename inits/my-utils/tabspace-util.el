;;; tabspace-util.el --- Utilities for tab-bar and tabspaces mode -*- lexical-binding: t; -*-

;;; Commentary:
;; タブ単位のセッション保存・レイアウト管理・winner 同期のコア実装。
;; 対話的なリスト UI (*Tab Sessions* / *Tabspaces Buffers*) は
;; tabspace-list-ui.el に分離した。
;; 利用側の設定は `inits/04_tabspace.el' に置く。

;;; Code:

(require 'tabspaces)
(require 'tab-bar)
(require 'cl-lib)

;; =============================================================================
;; 1. Global Utilities & Advice
;; =============================================================================

(defun my/project-switch-advice (orig-fn &rest args)
  "Create project automatically after new tab created."
  (let* ((project-dir (car args))
         (project-name (file-name-nondirectory (directory-file-name project-dir))))
    (tab-bar-new-tab)
    (tab-bar-rename-tab project-name)
    (apply orig-fn args)))

(defun my/tab-bar-new-tab-with-name ()
  "Create new-tab with input from minibuffer."
  (interactive)
  (let ((tab-name (read-string "New tab name: ")))
    (tab-bar-new-tab-to -1)
    (tab-bar-rename-tab tab-name))
  (ibuffer)
  (tabspaces-clear-buffers))

(defun my/tabspaces-switch-to-buffer (&optional norecord force-same-window)
  "Prompt for buffer and switch using tabspaces-switch-to-buffer."
  (interactive)
  (let* ((blst (cl-remove (buffer-name) (mapcar #'buffer-name (tabspaces--buffer-list))))
         (buffer (read-buffer
                  "Switch to local buffer: " nil nil
                  (lambda (b) (member (if (stringp b) b (car b)) blst)))))
    (tabspaces-switch-to-buffer buffer norecord force-same-window)))

(defun consult-tabspaces-switch ()
  "Switch to tab using consult interface."
  (interactive)
  (let ((tab (consult--read
              (mapcar #'car (tab-bar-tabs))
              :prompt "Switch to tab: ")))
    (tab-bar-switch-to-tab tab)))

;; =============================================================================
;; 2. Per-tab Session Management
;; =============================================================================

(defvar my/tabspace-sessions-dir
  (expand-file-name "tabspace-sessions/" (or (bound-and-true-p no-littering-var-directory) user-emacs-directory))
  "Directory to store per-tab session files.")

(defcustom my/tabspace-session-include-buffers '((regexp . "\\*Ibuffer\\*"))
  "List of buffer name patterns to include in session saves."
  :type '(repeat (choice string
                         (cons (const regexp) string)
                         (cons (const string) string)))
  :group 'tabspaces)

(defcustom my/tabspace-session-exclude-buffers '((regexp . "\\*scratch\\*")
                                                 (regexp . "\\*Messages\\*")
                                                 (regexp . "\\*Warnings\\*"))
  "List of buffer name patterns to exclude from session saves."
  :type '(repeat (choice string
                         (cons (const regexp) string)
                         (cons (const string) string)))
  :group 'tabspaces)

(defun my/tabspace--ensure-sessions-dir ()
  "Ensure the sessions directory exists."
  (unless (file-directory-p my/tabspace-sessions-dir)
    (make-directory my/tabspace-sessions-dir t)))

(defun my/tabspace--session-file (tab-name)
  "Return the session file path for TAB-NAME."
  (expand-file-name
   (concat (replace-regexp-in-string "[^a-zA-Z0-9-]" "_" tab-name) ".el")
   my/tabspace-sessions-dir))

(defun my/tabspace--read-session (tab-name)
  "Read session data for TAB-NAME from disk. Returns plist or nil."
  (let ((file (my/tabspace--session-file tab-name)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (read (current-buffer))))))

(defun my/tabspace--write-session (tab-name session-data)
  "Write SESSION-DATA for TAB-NAME to disk."
  (my/tabspace--ensure-sessions-dir)
  (with-temp-file (my/tabspace--session-file tab-name)
    (prin1 session-data (current-buffer))))

(defun my/tabspace--buffer-matches-pattern-p (buffer-name pattern)
  "Return non-nil if BUFFER-NAME matches PATTERN."
  (cond
   ((stringp pattern) (string= buffer-name pattern))
   ((and (consp pattern) (eq (car pattern) 'regexp))
    (string-match-p (cdr pattern) buffer-name))
   ((and (consp pattern) (eq (car pattern) 'string))
    (string= buffer-name (cdr pattern)))
   (t nil)))

(defun my/tabspace--buffer-matches-patterns-p (buffer-name patterns)
  "Return non-nil if BUFFER-NAME matches any pattern in PATTERNS."
  (seq-some (lambda (pattern)
              (my/tabspace--buffer-matches-pattern-p buffer-name pattern))
            patterns))

(defun my/tabspace--should-save-buffer-p (buf)
  "Return non-nil if BUF should be saved in a session."
  (let ((name (buffer-name buf)))
    (and (buffer-live-p buf)
         (or
          (my/tabspace--buffer-matches-patterns-p name my/tabspace-session-include-buffers)
          (and (buffer-file-name buf)
               (not (string-match-p "^\\*" name))
               (not (string-match-p "^ " name))
               (not (my/tabspace--buffer-matches-patterns-p name my/tabspace-session-exclude-buffers)))))))

(defun my/tabspace-save-tab-session (&optional tab-name)
  "Save the current tab's session (open buffer list only)."
  (interactive)
  (let* ((tab-name (or tab-name (alist-get 'name (tab-bar--current-tab))))
         (existing (my/tabspace--read-session tab-name))
         (tab-buffers (seq-filter #'buffer-live-p
                                  (frame-parameter nil 'buffer-list)))
         (file-buffers (seq-filter #'my/tabspace--should-save-buffer-p tab-buffers))
         (buffer-info
          (mapcar (lambda (buf)
                    (with-current-buffer buf
                      (list :name (buffer-name buf)
                            :file (buffer-file-name buf)
                            :major-mode major-mode
                            :point (point)
                            :special (not (buffer-file-name buf)))))
                  file-buffers))
         (session-data
          (list :tab-name tab-name
                :buffers buffer-info
                :layouts (plist-get existing :layouts)
                ;; tabspace-dir-util.el が持つフィールドを保存時に消さない
                :process-root (plist-get existing :process-root)
                :directories (plist-get existing :directories))))
    (my/tabspace--write-session tab-name session-data)
    (message "Tab session '%s' saved (%d buffers)" tab-name (length buffer-info))))

(defun my/tabspace-load-tab-session (&optional tab-name)
  "Load a saved tab session (buffer list only)."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let* ((session-files (directory-files my/tabspace-sessions-dir nil "\\.el$"))
         (session-names (mapcar (lambda (f)
                                  (replace-regexp-in-string
                                   "_" " " (file-name-sans-extension f)))
                                session-files))
         (selected-name (or tab-name
                            (completing-read "Load tab session: " session-names nil t)))
         (session-data (my/tabspace--read-session selected-name)))
    (if (not session-data)
        (message "No session found for tab '%s'" selected-name)
      (let* ((saved-tab-name (plist-get session-data :tab-name))
             (buffer-info (plist-get session-data :buffers)))
        (if (seq-find (lambda (tab) (string= (alist-get 'name tab) saved-tab-name))
                      (tab-bar-tabs))
            (tab-bar-switch-to-tab saved-tab-name)
          (tab-bar-new-tab)
          (tab-bar-rename-tab saved-tab-name))
        (tabspaces-clear-buffers)
        (let ((loaded-buffers '()))
          (dolist (buf-data buffer-info)
            (let ((file (plist-get buf-data :file))
                  (name (plist-get buf-data :name))
                  (is-special (plist-get buf-data :special)))
              (cond
               ((and file (not is-special))
                (when (file-exists-p file)
                  (let ((buf (find-file-noselect file)))
                    (with-current-buffer buf
                      (goto-char (plist-get buf-data :point)))
                    (push buf loaded-buffers))))
               (is-special
                (push (get-buffer-create name) loaded-buffers)))))
          (dolist (buf (reverse loaded-buffers))
            (set-frame-parameter nil 'buffer-list
                                 (cons buf (delq buf (frame-parameter nil 'buffer-list))))))
        (message "Tab session '%s' loaded (%d buffers)" saved-tab-name (length buffer-info))))))

(defun my/tabspace-delete-tab-session (&optional tab-name)
  "Delete a saved tab session file entirely."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let* ((session-files (directory-files my/tabspace-sessions-dir nil "\\.el$"))
         (session-names (mapcar (lambda (f)
                                  (replace-regexp-in-string
                                   "_" " " (file-name-sans-extension f)))
                                session-files))
         (selected-name (or tab-name
                            (completing-read "Delete tab session: " session-names nil t)))
         (session-file (my/tabspace--session-file selected-name)))
    (if (not (file-exists-p session-file))
        (message "No session found for tab '%s'" selected-name)
      (when (y-or-n-p (format "Delete session '%s'? " selected-name))
        (delete-file session-file)
        (message "Tab session '%s' deleted" selected-name)))))

;; =============================================================================
;; 3. Per-tab Named Layout Management
;; =============================================================================

(defvar my/tabspace--active-layout (make-hash-table :test 'equal)
  "タブ名 → 直近に保存/読込したレイアウト名。
tabspace-bookmark-util.el が bookmark のスコープ付けに使う。起動直後は空。")

(defun my/tabspace-current-layout (&optional tab-name)
  "TAB-NAME (省略時は現タブ) でアクティブなレイアウト名を返す。無ければ nil。"
  (gethash (or tab-name (alist-get 'name (tab-bar--current-tab)))
           my/tabspace--active-layout))

(defun my/tabspace-save-layout (&optional layout-name)
  "Save current window arrangement as LAYOUT-NAME for the current tab."
  (interactive (list (read-string "Layout name (default: \"default\"): " nil nil "default")))
  (let* ((layout-name (or (and (stringp layout-name) (not (string-empty-p layout-name)) layout-name) "default"))
         (tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (or (my/tabspace--read-session tab-name) (list :tab-name tab-name :buffers nil :layouts nil)))
         (layouts (plist-get session :layouts))
         (window-state (window-state-get (frame-root-window) t))
         (new-layouts (cons (cons layout-name window-state) (cl-remove layout-name layouts :key #'car :test #'equal))))
    (my/tabspace--write-session tab-name (plist-put (copy-tree session) :layouts new-layouts))
    (puthash tab-name layout-name my/tabspace--active-layout)
    (message "Layout '%s' saved for tab '%s'" layout-name tab-name)))

(defun my/tabspace-load-layout (&optional layout-name)
  "Load a named layout for the current tab."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name)))
    (if (not session) (message "No session found for tab '%s'" tab-name)
      (let* ((layouts (or (plist-get session :layouts)
                          (when (plist-get session :window-state) (list (cons "default" (plist-get session :window-state))))))
             (names (mapcar #'car layouts))
             (selected (or layout-name (completing-read "Load layout: " names nil t)))
             (state (cdr (assoc selected layouts))))
        (if state (progn (window-state-put state (frame-root-window) 'safe)
                         (puthash tab-name selected my/tabspace--active-layout)
                         (message "Layout '%s' loaded" selected))
          (message "Layout '%s' not found for tab '%s'" selected tab-name))))))

(defun my/tabspace-delete-layout (&optional layout-name)
  "Delete a named layout for the current tab."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name)))
    (if (not session) (message "No session found for tab '%s'" tab-name)
      (let* ((layouts (plist-get session :layouts)))
        (if (not layouts) (message "No layouts saved for tab '%s'" tab-name)
          (let* ((names (mapcar #'car layouts))
                 (selected (or layout-name (completing-read "Delete layout: " names nil t))))
            (when (y-or-n-p (format "Delete layout '%s'? " selected))
              (my/tabspace--write-session tab-name
                                          (plist-put (copy-tree session) :layouts (cl-remove selected layouts :key #'car :test #'equal)))
              (when (equal selected (gethash tab-name my/tabspace--active-layout))
                (remhash tab-name my/tabspace--active-layout))
              (message "Layout '%s' deleted" selected))))))))

(defun my/tabspace-list-layouts ()
  "List all saved layouts for the current tab."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name))
         (layouts (plist-get session :layouts)))
    (if (not layouts) (message "No layouts saved for tab '%s'" tab-name)
      (message "Layouts for '%s': %s" tab-name (mapconcat #'car layouts ", ")))))

;; =============================================================================
;; 4. Winner-mode Tab Synchronization
;; =============================================================================

(defvar my/winner-tab-rings (make-hash-table :test 'equal)
  "Hash table mapping tab names to their winner-mode ring state.")

(defun my/winner-save-for-tab ()
  "Save current winner-mode state for the current tab."
  (when (and (boundp 'winner-mode) winner-mode (boundp 'winner-ring-alist))
    (let ((tab-name (alist-get 'name (tab-bar--current-tab))))
      (puthash tab-name (list :ring (copy-tree winner-ring-alist)
                              :pending (and (boundp 'winner-pending-alist) (copy-tree winner-pending-alist)))
               my/winner-tab-rings))))

(defun my/winner-restore-for-tab ()
  "Restore winner-mode state for the current tab."
  (when (and (boundp 'winner-mode) winner-mode (boundp 'winner-ring-alist))
    (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
           (state (gethash tab-name my/winner-tab-rings)))
      (if state
          (progn (setq winner-ring-alist (plist-get state :ring))
                 (when (boundp 'winner-pending-alist) (setq winner-pending-alist (or (plist-get state :pending) nil))))
        (setq winner-ring-alist nil)
        (when (boundp 'winner-pending-alist) (setq winner-pending-alist nil))))))

(provide 'tabspace-util)

;;; tabspace-util.el ends here
