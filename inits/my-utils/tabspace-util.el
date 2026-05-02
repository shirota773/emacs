;;; tabspace-util.el --- Utilities for tab-bar and tabspaces mode -*- lexical-binding: t; -*-

;;; Commentary:
;; This file contains the implementation details for tab-specific session saving,
;; layout management, and buffer management.
;; Utilization and user configuration should be kept in `inits/04_tabspace.el`.

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

(defun my/tabspaces-open-project-tree ()
  "Open treemacs project tree associated with current tabspaces project."
  (interactive)
  (let ((proj (project-current)))
    (when proj
      (let ((proj-root (project-root proj)))
        (unless (treemacs-current-visibility)
          (treemacs))
        (treemacs-add-project-to-workspace proj-root (project-name proj))
        (treemacs-select-window)))))

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
                :layouts (plist-get existing :layouts))))
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
;; 2.5 Common List Utilities
;; =============================================================================

(defun my/tab-util--ensure-on-item ()
  "Ensure point is on an item with 'line-type property."
  (when (and (memq major-mode '(my/tabspaces-buffer-list-mode my/tabspace-session-list-mode))
             (null (get-text-property (point) 'line-type)))
    (let* ((pos (point))
           (next (text-property-not-all pos (point-max) 'line-type nil))
           (prev (previous-single-property-change pos 'line-type)))
      ;; If prev found a transition, we need to check if the property before it is non-nil
      (when (and prev (> prev (point-min)) (null (get-text-property (1- prev) 'line-type)))
        (setq prev (previous-single-property-change (1- prev) 'line-type)))
      
      (let ((target (cond
                     ((and next prev) (if (<= (- next pos) (- pos prev)) next prev))
                     (next next)
                     (prev prev)
                     (t (text-property-not-all (point-min) (point-max) 'line-type nil)))))
        (when target (goto-char target))))))

;; =============================================================================
;; 3. Tab Session List Mode Implementation (Dashboard-like)
;; =============================================================================

(defface my/tabspace-session-header
  '((t (:inherit font-lock-function-name-face :weight bold :height 1.4)))
  "Face for the session list header."
  :group 'tabspaces)

(defface my/tabspace-session-name
  '((t (:inherit font-lock-keyword-face :weight bold)))
  "Face for session names in the list."
  :group 'tabspaces)

(defface my/tabspace-session-file
  '((t (:inherit font-lock-string-face)))
  "Face for file paths in the session list."
  :group 'tabspaces)

(defface my/tabspace-session-meta
  '((t (:inherit font-lock-comment-face :italic t)))
  "Face for metadata/counts in the session list."
  :group 'tabspaces)

(defvar-local my/tabspace-session-list--expanded nil)
(defvar-local my/tabspace-session-list--marked-sessions nil)
(defvar-local my/tabspace-session-list--marked-files nil)
(defvar-local my/tabspace-session-list--marked-open nil)

(defun my/tabspace-list-saved-sessions ()
  "Show an interactive list of saved tab sessions."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let ((buf (get-buffer-create "*Tab Sessions*")))
    (with-current-buffer buf
      (my/tabspace-session-list-mode)
      (my/tabspace-session-list-refresh))
    (pop-to-buffer buf)))

(defun my/tabspace-session-list--insert-header ()
  "Insert a decorative header for the session list."
  (let ((inhibit-read-only t))
    (insert (propertize "  _____      _                               \n" 'face 'my/tabspace-session-header))
    (insert (propertize " |_   _|_ _ | |__  ___ _ __   __ _  ___ ___ \n" 'face 'my/tabspace-session-header))
    (insert (propertize "   | |/ _` || '_ \\/ __| '_ \\ / _` |/ __/ _ \\\n" 'face 'my/tabspace-session-header))
    (insert (propertize "   | | (_| || |_) \\__ \\ |_) | (_| | (_|  __/\n" 'face 'my/tabspace-session-header))
    (insert (propertize "   |_|\\__,_||_.__/|___/ .__/ \\__,_|\\___\___|\n" 'face 'my/tabspace-session-header))
    (insert (propertize "                      |_|                    \n" 'face 'my/tabspace-session-header))
    (insert "\n")
    (insert (propertize "  Manage and Restore your Saved Tabspaces\n" 'face 'my/tabspace-session-meta))
    (insert (propertize (make-string 60 ?─) 'face 'shadow) "\n\n")))

(defun my/tabspace-session-list-refresh ()
  "Redraw the session list buffer."
  (interactive)
  (let ((inhibit-read-only t)
        (saved-point (point))
        (header-start (point-min)))
    (erase-buffer)
    (my/tabspace-session-list--insert-header)
    (insert (propertize
             " [m] Mark Open   [d] Mark Delete   [u] Unmark   [x] Execute   [a] Add   [r] Rename\n"
             'face 'shadow))
    (insert (propertize
             " [RET] Load      [TAB] Toggle      [g] Refresh  [q] Quit\n\n"
             'face 'shadow))
    
    (let ((files (directory-files my/tabspace-sessions-dir nil "\\.el\\'")))
      (if (null files)
          (insert (propertize "  (no saved sessions)\n"
                               'face 'shadow))
        (dolist (f files)
          (let* ((session-name (replace-regexp-in-string
                                "_" " " (file-name-sans-extension f)))
                 (data (my/tabspace--read-session session-name))
                 (buffers (plist-get data :buffers))
                 (expanded (alist-get session-name
                                      my/tabspace-session-list--expanded
                                      nil nil #'equal))
                 (marker (if expanded "▼" "▶"))
                 (session-marked-del (member session-name
                                             my/tabspace-session-list--marked-sessions))
                 (session-marked-open (member session-name
                                              my/tabspace-session-list--marked-open))
                 (smark (cond (session-marked-del "D")
                              (session-marked-open "*")
                              (t " "))))
            (insert (propertize
                     (format " %s %s %-20s "
                             smark marker session-name)
                     'face (cond (session-marked-del 'font-lock-warning-face)
                                 (session-marked-open 'success)
                                 (t 'my/tabspace-session-name))
                     'session-name session-name
                     'line-type 'session))
            (insert (propertize (format "(%d files)\n" (length buffers))
                                'face 'my/tabspace-session-meta))
            (when expanded
              (if (null buffers)
                  (insert (propertize "      (no files)\n"
                                      'face 'shadow
                                      'session-name session-name
                                      'line-type 'file-empty))
                (dolist (b buffers)
                  (let* ((file (plist-get b :file))
                         (name (plist-get b :name))
                         (file-marked (member (cons session-name file)
                                               my/tabspace-session-list--marked-files))
                         (fmark (if file-marked "D" " ")))
                    (insert (propertize
                             (format "    %s %s\n"
                                     fmark
                                     (or (and file (abbreviate-file-name file))
                                         name))
                             'face (if file-marked 'font-lock-warning-face 'my/tabspace-session-file)
                             'session-name session-name
                             'file-path file
                             'line-type 'file))))))))))
    (insert "\n" (propertize (make-string 60 ?─) 'face 'shadow) "\n")
    (let ((first (or (text-property-any (point-min) (point-max)
                                        'line-type 'session)
                     (point-min))))
      (goto-char (max first (min saved-point (point-max)))))))

(defun my/tabspace-session-list--line-type () (get-text-property (point) 'line-type))
(defun my/tabspace-session-list--session-at-point () (get-text-property (point) 'session-name))
(defun my/tabspace-session-list--file-at-point () (get-text-property (point) 'file-path))

(defun my/tabspace-session-list--ensure-on-item ()
  (my/tab-util--ensure-on-item))

(defun my/tabspace-session-list-toggle ()
  (interactive)
  (let ((name (my/tabspace-session-list--session-at-point)))
    (when name
      (let ((cur (alist-get name my/tabspace-session-list--expanded nil nil #'equal)))
        (setf (alist-get name my/tabspace-session-list--expanded nil nil #'equal) (not cur)))
      (my/tabspace-session-list-refresh))))

(defun my/tabspace-session-list-visit ()
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session (my/tabspace-load-tab-session (my/tabspace-session-list--session-at-point)))
    ('file
     (let ((file (my/tabspace-session-list--file-at-point)))
       (if (and file (file-exists-p file)) (find-file file) (message "File not found: %s" file))))
    (_ (message "Nothing to visit at point"))))

(defun my/tabspace-session-list-add-session ()
  (interactive)
  (let ((name (read-string "New session name: ")))
    (cond
     ((or (null name) (string-empty-p name)) (message "Canceled"))
     ((file-exists-p (my/tabspace--session-file name)) (message "Session '%s' already exists" name))
     (t
      (my/tabspace--write-session name (list :tab-name name :buffers nil :layouts nil))
      (my/tabspace-session-list-refresh)
      (message "Created session '%s'" name)))))

(defun my/tabspace-session-list-rename-session ()
  (interactive)
  (let ((old (my/tabspace-session-list--session-at-point)))
    (if (not old) (message "No session at point")
      (let ((new (read-string (format "Rename '%s' to: " old) old)))
        (cond
         ((or (null new) (string-empty-p new) (string= old new)) (message "Canceled"))
         ((file-exists-p (my/tabspace--session-file new)) (message "Session '%s' already exists" new))
         (t
          (let* ((data (my/tabspace--read-session old))
                 (updated (plist-put (copy-tree data) :tab-name new)))
            (my/tabspace--write-session new updated)
            (delete-file (my/tabspace--session-file old))
            (let ((was (alist-get old my/tabspace-session-list--expanded nil nil #'equal)))
              (setq my/tabspace-session-list--expanded (assoc-delete-all old my/tabspace-session-list--expanded))
              (when was (setf (alist-get new my/tabspace-session-list--expanded nil nil #'equal) t))))
          (my/tabspace-session-list-refresh)
          (message "Renamed '%s' → '%s'" old new)))))))

(defun my/tabspace-session-list-mark-delete ()
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (let ((name (my/tabspace-session-list--session-at-point)))
       (when name
         (setq my/tabspace-session-list--marked-open (delete name my/tabspace-session-list--marked-open))
         (cl-pushnew name my/tabspace-session-list--marked-sessions :test #'equal)
         (my/tabspace-session-list-refresh) (forward-line 1))))
    ('file
     (let ((name (my/tabspace-session-list--session-at-point))
           (file (my/tabspace-session-list--file-at-point)))
       (when (and name file) (cl-pushnew (cons name file) my/tabspace-session-list--marked-files :test #'equal)
             (my/tabspace-session-list-refresh) (forward-line 1))))
    (_ (message "Nothing to mark at point"))))

(defun my/tabspace-session-list-mark-open ()
  "Mark the session at point for opening."
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (let ((name (my/tabspace-session-list--session-at-point)))
       (when name
         (setq my/tabspace-session-list--marked-sessions (delete name my/tabspace-session-list--marked-sessions))
         (cl-pushnew name my/tabspace-session-list--marked-open :test #'equal)
         (my/tabspace-session-list-refresh) (forward-line 1))))
    (_ (message "Can only mark sessions for opening"))))

(defun my/tabspace-session-list-unmark ()
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (let ((name (my/tabspace-session-list--session-at-point)))
       (setq my/tabspace-session-list--marked-sessions (delete name my/tabspace-session-list--marked-sessions))
       (setq my/tabspace-session-list--marked-open (delete name my/tabspace-session-list--marked-open))))
    ('file
     (let ((name (my/tabspace-session-list--session-at-point))
           (file (my/tabspace-session-list--file-at-point)))
       (setq my/tabspace-session-list--marked-files (delete (cons name file) my/tabspace-session-list--marked-files)))))
  (my/tabspace-session-list-refresh) (forward-line 1))

(defun my/tabspace-session-list-unmark-all ()
  (interactive)
  (setq my/tabspace-session-list--marked-sessions nil)
  (setq my/tabspace-session-list--marked-files nil)
  (setq my/tabspace-session-list--marked-open nil)
  (my/tabspace-session-list-refresh))

(defun my/tabspace-session-list-execute ()
  (interactive)
  (let ((sessions-del my/tabspace-session-list--marked-sessions)
        (sessions-open my/tabspace-session-list--marked-open)
        (files-del (seq-remove (lambda (cell) (member (car cell) my/tabspace-session-list--marked-sessions))
                               my/tabspace-session-list--marked-files)))
    (if (and (null sessions-del) (null files-del) (null sessions-open))
        (message "No marks to execute")
      ;; 1. Handle Opening
      (when sessions-open
        (dolist (sname sessions-open)
          (my/tabspace-load-tab-session sname))
        (setq my/tabspace-session-list--marked-open nil)
        (message "Opened %d session(s)" (length sessions-open)))
      ;; 2. Handle Deletion
      (when (or sessions-del files-del)
        (when (yes-or-no-p (format "Execute: delete %d session(s), remove %d file entry(ies)? "
                                   (length sessions-del) (length files-del)))
          (dolist (entry (seq-group-by #'car files-del))
            (let* ((sname (car entry))
                   (paths (mapcar #'cdr (cdr entry)))
                   (data (my/tabspace--read-session sname))
                   (buffers (plist-get data :buffers))
                   (new-buffers (seq-remove (lambda (b) (member (plist-get b :file) paths)) buffers)))
              (my/tabspace--write-session sname (plist-put (copy-tree data) :buffers new-buffers))))
          (dolist (sname sessions-del)
            (let ((file (my/tabspace--session-file sname))) (when (file-exists-p file) (delete-file file)))
            (setq my/tabspace-session-list--expanded (assoc-delete-all sname my/tabspace-session-list--expanded)))
          (setq my/tabspace-session-list--marked-sessions nil) (setq my/tabspace-session-list--marked-files nil)
          (message "Executed deletions: %d session(s), %d file(s)" (length sessions-del) (length files-del))))
      (my/tabspace-session-list-refresh))))

(defun my/tabspace-session-list-add-file ()
  (interactive)
  (let ((name (my/tabspace-session-list--session-at-point)))
    (if (not name) (message "No session at point")
      (let* ((path (read-file-name "Add file to session: " nil nil t))
             (abspath (expand-file-name path))
             (data (or (my/tabspace--read-session name) (list :tab-name name :buffers nil :layouts nil)))
             (buffers (plist-get data :buffers)))
        (if (seq-find (lambda (b) (equal (plist-get b :file) abspath)) buffers) (message "Already registered: %s" abspath)
          (let ((new-buffers (append buffers (list (list :name (file-name-nondirectory abspath) :file abspath :major-mode nil :point 1 :special nil)))))
            (my/tabspace--write-session name (plist-put (copy-tree data) :buffers new-buffers))
            (setf (alist-get name my/tabspace-session-list--expanded nil nil #'equal) t)
            (my/tabspace-session-list-refresh) (message "Added '%s' to '%s'" abspath name)))))))

(defvar my/tabspace-session-list-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "<tab>") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "SPC") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "RET") #'my/tabspace-session-list-visit)
    (define-key map (kbd "a") #'my/tabspace-session-list-add-session)
    (define-key map (kbd "r") #'my/tabspace-session-list-rename-session)
    (define-key map (kbd "+") #'my/tabspace-session-list-add-file)
    (define-key map (kbd "m") #'my/tabspace-session-list-mark-open)
    (define-key map (kbd "d") #'my/tabspace-session-list-mark-delete)
    (define-key map (kbd "u") #'my/tabspace-session-list-unmark)
    (define-key map (kbd "U") #'my/tabspace-session-list-unmark-all)
    (define-key map (kbd "x") #'my/tabspace-session-list-execute)
    (define-key map (kbd "g") #'my/tabspace-session-list-refresh)
    (define-key map (kbd "q") #'quit-window)
    map))

(define-derived-mode my/tabspace-session-list-mode special-mode "Tab-Sessions"
  "Major mode for browsing and editing saved tab sessions."
  (setq truncate-lines t) (setq buffer-read-only t)
  (setq-local my/tabspace-session-list--expanded nil)
  (setq-local my/tabspace-session-list--marked-sessions nil)
  (setq-local my/tabspace-session-list--marked-files nil)
  (setq-local my/tabspace-session-list--marked-open nil)
  (setq-local header-line-format (propertize "Saved Tab Sessions" 'face 'bold))
  (cursor-intangible-mode 1)
  (add-hook 'post-command-hook #'my/tab-util--ensure-on-item nil t))

(dolist (cmd '(my/tabspace-session-list-mode my/tabspace-session-list-refresh my/tabspace-session-list-toggle
               my/tabspace-session-list-visit my/tabspace-session-list-add-session my/tabspace-session-list-rename-session
               my/tabspace-session-list-mark-delete my/tabspace-session-list-mark-open
               my/tabspace-session-list-unmark my/tabspace-session-list-unmark-all
               my/tabspace-session-list-execute my/tabspace-session-list-add-file))
  (put cmd 'completion-predicate #'ignore))

;; =============================================================================
;; 4. Per-tab Named Layout Management
;; =============================================================================

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
        (if state (progn (window-state-put state (frame-root-window) 'safe) (message "Layout '%s' loaded" selected))
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
;; 5. Winner-mode Tab Synchronization
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

;; =============================================================================
;; 6. Tabspace Buffer List (ibuffer-like) Implementation
;; =============================================================================

(defvar-local my/tabspaces-buffer-marks nil)
(defvar-local my/tabspaces-filter-mode 'file)
(defvar-local my/tabspaces-sort-mode 'name)
(defvar-local my/tabspaces-buffer-list--collapsed nil)

(defun my/tabspaces-list-tabs-and-buffers ()
  "List all tabspaces and their buffers."
  (interactive)
  (let ((buf (get-buffer-create "*Tabspaces Buffers*")))
    (with-current-buffer buf
      (my/tabspaces-buffer-list-mode)
      (my/tabspaces-refresh-buffer-list))
    (pop-to-buffer buf)))

(defun my/tabspaces--get-buffer-tabs (buffer)
  "Return a list of tab names that contain BUFFER."
  (let ((tabs '())
        (current-tab-name (alist-get 'name (tab-bar--current-tab))))
    (dolist (tab (tab-bar-tabs))
      (let* ((tab-name (alist-get 'name tab))
             (buffers (if (string= tab-name current-tab-name)
                          (tabspaces--buffer-list)
                        (alist-get 'wc-bl tab))))
        (when (memq buffer buffers)
          (push tab-name tabs))))
    (nreverse tabs)))

(defun my/tabspaces--buffer-tab-count (buffer)
  "Return the number of tabs that contain BUFFER."
  (length (my/tabspaces--get-buffer-tabs buffer)))

(defun my/tabspaces--should-show-buffer-p (buffer)
  (cond ((null my/tabspaces-filter-mode) t)
        ((eq my/tabspaces-filter-mode 'modified) (buffer-modified-p buffer))
        ((eq my/tabspaces-filter-mode 'file) (buffer-file-name buffer))
        ((eq my/tabspaces-filter-mode 'special) (not (buffer-file-name buffer)))
        ((eq my/tabspaces-filter-mode 'current-tab) (let ((current-tab-name (alist-get 'name (tab-bar--current-tab)))) (member current-tab-name (my/tabspaces--get-buffer-tabs buffer))))
        (t t)))

(defun my/tabspaces--sort-buffers (buffers)
  (cl-sort buffers (cond ((eq my/tabspaces-sort-mode 'name) (lambda (a b) (string< (buffer-name a) (buffer-name b))))
                         ((eq my/tabspaces-sort-mode 'modified) (lambda (a b) (let ((time-a (or (buffer-modified-tick a) 0)) (time-b (or (buffer-modified-tick b) 0))) (> time-a time-b))))
                         ((eq my/tabspaces-sort-mode 'size) (lambda (a b) (> (buffer-size a) (buffer-size b))))
                         (t (lambda (a b) (string< (buffer-name a) (buffer-name b)))))))

(defun my/tabspaces-refresh-buffer-list ()
  (interactive)
  (let ((inhibit-read-only t) (saved-point (point)) (header-start (point-min)) (i 1))
    (erase-buffer) (setq header-start (point))
    (insert (propertize "  _____      _                               \n" 'face 'my/tabspace-session-header))
    (insert (propertize " |_   _|_ _ | |__  ___ _ __   __ _  ___ ___ \n" 'face 'my/tabspace-session-header))
    (insert (propertize "   | |/ _` || '_ \\/ __| '_ \\ / _` |/ __/ _ \\\n" 'face 'my/tabspace-session-header))
    (insert (propertize "   | | (_| || |_) \\__ \\ |_) | (_| | (_|  __/\n" 'face 'my/tabspace-session-header))
    (insert (propertize "   |_|\\__,_||_.__/|___/ .__/ \\__,_|\\___\___|\n" 'face 'my/tabspace-session-header))
    (insert (propertize "                      |_|                    \n" 'face 'my/tabspace-session-header))
    (insert "\n")
    (insert (propertize "  Manage your Tabspaces and active Buffers\n" 'face 'my/tabspace-session-meta))
    (insert (propertize (make-string 60 ?─) 'face 'shadow) "\n\n")
    (insert (propertize " [m] mark [u] unmark [d] del [k] kill [x] execute [TAB] toggle\n" 'face 'shadow))
    (insert (propertize " [/] filter [o] sort [%/*] mark-by [g] refresh [RET] visit [q] quit\n\n" 'face 'shadow))
    (let ((current-tab-name (alist-get 'name (tab-bar--current-tab))))
      (dolist (tab (tab-bar-tabs))
        (let* ((tab-name (alist-get 'name tab)) (current (string= tab-name current-tab-name)) (collapsed (member tab-name my/tabspaces-buffer-list--collapsed))
               (marker (if collapsed "▶" "▼")) (all-buffers (seq-filter #'buffer-live-p (if current (tabspaces--buffer-list) (or (alist-get 'wc-bl tab) '()))))
               (filtered-buffers (seq-filter #'my/tabspaces--should-show-buffer-p all-buffers)) (sorted-buffers (my/tabspaces--sort-buffers filtered-buffers)))
          (insert (propertize (format "%s [%d] %s%s (%d/%d buffers)\n" marker i tab-name (if current " <== current" "") (length filtered-buffers) (length all-buffers))
                              'face '(:foreground "cyan" :weight bold) 'tab-name tab-name 'line-type 'tab))
          (unless collapsed (if sorted-buffers (dolist (b sorted-buffers) (when (buffer-live-p b)
                                                                           (let* ((buf-name (buffer-name b)) (mark-type (alist-get buf-name my/tabspaces-buffer-marks nil nil #'equal))
                                                                                  (mark-char (cond ((eq mark-type 'delete) "D") ((eq mark-type 'kill) "K") ((eq mark-type 'save) "S") ((eq mark-type 'mark) "*") (t " ")))
                                                                                  (modified (buffer-modified-p b)) (file (buffer-file-name b)) (tab-count (my/tabspaces--buffer-tab-count b)) (multi-tab (> tab-count 1))
                                                                                  (tabs-info (if multi-tab (format " [%d tabs: %s]" tab-count (mapconcat 'identity (my/tabspaces--get-buffer-tabs b) ", ")) ""))
                                                                                  (size (buffer-size b)) (face (cond ((eq mark-type 'delete) 'font-lock-warning-face) ((eq mark-type 'kill) 'error) (multi-tab '(:foreground "yellow")) (t 'default))))
                                                                             (insert (propertize (format "    %s %s %-40s %6s%s%s\n" mark-char (if modified "*" " ") buf-name (file-size-human-readable size) (if file (format " (%s)" (abbreviate-file-name file)) "") (or tabs-info ""))
                                                                                                 'face face 'buffer-name buf-name 'tab-name tab-name 'line-type 'buffer)))))
                              (insert (propertize "      (no buffers)\n" 'face '(:foreground "gray60") 'tab-name tab-name 'line-type 'empty))))
          (setq i (1+ i)))))
    (let ((first (or (text-property-any (point-min) (point-max) 'line-type 'tab) (point-min)))) (goto-char (max first (min saved-point (point-max)))))))

(defun my/tabspaces-buffer-list--line-type () (get-text-property (point) 'line-type))
(defun my/tabspaces-buffer-list--tab-at-point () (get-text-property (point) 'tab-name))
(defun my/tabspaces-buffer-at-point () (when (eq (my/tabspaces-buffer-list--line-type) 'buffer) (let ((name (get-text-property (point) 'buffer-name))) (and name (get-buffer name)))))
(defun my/tabspaces-buffer-list--ensure-on-item ()
  (my/tab-util--ensure-on-item))
(defun my/tabspaces-toggle-tab () (interactive) (let ((name (my/tabspaces-buffer-list--tab-at-point))) (when name (if (member name my/tabspaces-buffer-list--collapsed) (setq my/tabspaces-buffer-list--collapsed (delete name my/tabspaces-buffer-list--collapsed)) (push name my/tabspaces-buffer-list--collapsed)) (my/tabspaces-refresh-buffer-list))))
(defun my/tabspaces-mark-buffer (mark-type) (let ((buf (my/tabspaces-buffer-at-point))) (when buf (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) mark-type) (my/tabspaces-refresh-buffer-list) (forward-line 1))))
(defun my/tabspaces-unmark-buffer () (interactive) (let ((buf (my/tabspaces-buffer-at-point))) (when buf (setq my/tabspaces-buffer-marks (assoc-delete-all (buffer-name buf) my/tabspaces-buffer-marks)) (my/tabspaces-refresh-buffer-list) (forward-line 1))))
(defun my/tabspaces-mark-delete () (interactive) (my/tabspaces-mark-buffer 'delete))
(defun my/tabspaces-mark-kill () (interactive) (my/tabspaces-mark-buffer 'kill))
(defun my/tabspaces-mark-save () (interactive) (my/tabspaces-mark-buffer 'save))
(defun my/tabspaces-mark () (interactive) (my/tabspaces-mark-buffer 'mark))

(defun my/tabspaces-execute ()
  (interactive)
  (let (delete-list kill-list save-list)
    (dolist (entry my/tabspaces-buffer-marks) (let* ((name (car entry)) (buf (get-buffer name)) (mark-type (cdr entry)))
                                               (when (buffer-live-p buf) (cond ((eq mark-type 'delete) (push buf delete-list)) ((eq mark-type 'kill) (push buf kill-list)) ((eq mark-type 'save) (push buf save-list))))))
    (when save-list (dolist (buf save-list) (with-current-buffer buf (when (buffer-modified-p) (save-buffer))) (message "Saved: %s" (buffer-name buf))))
    (when delete-list (when (yes-or-no-p (format "Remove %d buffer(s) from tab? " (length delete-list))) (dolist (buf delete-list) (tabspaces-remove-selected-buffer buf) (message "Removed from tab: %s" (buffer-name buf)))))
    (when kill-list (when (yes-or-no-p (format "Kill %d buffer(s)? " (length kill-list))) (dolist (buf kill-list) (kill-buffer buf) (message "Killed: %s" (buffer-name buf)))))
    (setq my/tabspaces-buffer-marks nil) (my/tabspaces-refresh-buffer-list)))

(defun my/tabspaces-unmark-all () (interactive) (setq my/tabspaces-buffer-marks nil) (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-visit-buffer ()
  (interactive)
  (pcase (my/tabspaces-buffer-list--line-type)
    ('tab (let ((name (my/tabspaces-buffer-list--tab-at-point))) (when name (tab-bar-switch-to-tab name))))
    ('buffer (let ((buf (my/tabspaces-buffer-at-point)) (tab-name (my/tabspaces-buffer-list--tab-at-point))) (when (and buf tab-name) (tab-bar-switch-to-tab tab-name) (switch-to-buffer buf))))
    (_ (message "Nothing to visit at point"))))

(defun my/tabspaces-filter-modified () (interactive) (setq my/tabspaces-filter-mode 'modified) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-filter-file () (interactive) (setq my/tabspaces-filter-mode 'file) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-filter-special () (interactive) (setq my/tabspaces-filter-mode 'special) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-filter-clear () (interactive) (setq my/tabspaces-filter-mode nil) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-filter-current-tab () (interactive) (setq my/tabspaces-filter-mode 'current-tab) (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-move-buffer-to-tab ()
  (interactive)
  (let* ((buf (my/tabspaces-buffer-at-point)) (current-tab-name (my/tabspaces-buffer-list--tab-at-point))
         (other-tabs (seq-remove (lambda (name) (string= name current-tab-name)) (mapcar (lambda (tab) (alist-get 'name tab)) (tab-bar-tabs))))
         (target-tab (and buf current-tab-name (completing-read "Move to tab: " other-tabs nil t))))
    (when (and buf target-tab)
      (let ((orig-tab (alist-get 'name (tab-bar--current-tab))) (tab-bar-tab-pre-change-functions nil) (tab-bar-tab-post-change-functions nil))
        (tab-bar-switch-to-tab target-tab) (set-frame-parameter nil 'buffer-list (cons buf (delq buf (frame-parameter nil 'buffer-list))))
        (tab-bar-switch-to-tab orig-tab))
      (tabspaces-remove-selected-buffer buf) (my/tabspaces-refresh-buffer-list) (message "Moved '%s' → '%s'" (buffer-name buf) target-tab))))

(defun my/tabspaces-sort-by-name () (interactive) (setq my/tabspaces-sort-mode 'name) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-sort-by-modified () (interactive) (setq my/tabspaces-sort-mode 'modified) (my/tabspaces-refresh-buffer-list))
(defun my/tabspaces-sort-by-size () (interactive) (setq my/tabspaces-sort-mode 'size) (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-toggle-marks ()
  (interactive)
  (save-excursion (goto-char (point-min)) (while (not (eobp)) (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
                                                               (let ((buf (my/tabspaces-buffer-at-point))) (when buf (let ((name (buffer-name buf)))
                                                                                                                      (if (alist-get name my/tabspaces-buffer-marks nil nil #'equal)
                                                                                                                          (setq my/tabspaces-buffer-marks (assoc-delete-all name my/tabspaces-buffer-marks))
                                                                                                                        (setf (alist-get name my/tabspaces-buffer-marks nil nil #'equal) 'mark)))))) (forward-line 1))) (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-by-name-regexp (regexp)
  (interactive "sMark buffers matching regexp: ")
  (save-excursion (goto-char (point-min)) (while (not (eobp)) (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
                                                               (let ((buf (my/tabspaces-buffer-at-point))) (when (and buf (string-match-p regexp (buffer-name buf))) (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) 'mark)))) (forward-line 1))) (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-modified-buffers ()
  (interactive)
  (save-excursion (goto-char (point-min)) (while (not (eobp)) (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
                                                               (let ((buf (my/tabspaces-buffer-at-point))) (when (and buf (buffer-modified-p buf)) (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) 'mark)))) (forward-line 1))) (my/tabspaces-refresh-buffer-list))

(defvar my/tabspaces-buffer-list-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "d") #'my/tabspaces-mark-delete) (define-key map (kbd "k") #'my/tabspaces-mark-kill) (define-key map (kbd "s") #'my/tabspaces-mark-save)
    (define-key map (kbd "m") #'my/tabspaces-mark) (define-key map (kbd "u") #'my/tabspaces-unmark-buffer) (define-key map (kbd "U") #'my/tabspaces-unmark-all)
    (define-key map (kbd "t") #'my/tabspaces-toggle-marks) (define-key map (kbd "x") #'my/tabspaces-execute) (define-key map (kbd "/ m") #'my/tabspaces-filter-modified)
    (define-key map (kbd "/ f") #'my/tabspaces-filter-file) (define-key map (kbd "/ s") #'my/tabspaces-filter-special) (define-key map (kbd "/ t") #'my/tabspaces-filter-current-tab)
    (define-key map (kbd "/ /") #'my/tabspaces-filter-clear) (define-key map (kbd "M") #'my/tabspaces-move-buffer-to-tab) (define-key map (kbd "o n") #'my/tabspaces-sort-by-name)
    (define-key map (kbd "o m") #'my/tabspaces-sort-by-modified) (define-key map (kbd "o s") #'my/tabspaces-sort-by-size) (define-key map (kbd "% n") #'my/tabspaces-mark-by-name-regexp)
    (define-key map (kbd "* m") #'my/tabspaces-mark-modified-buffers) (define-key map (kbd "TAB") #'my/tabspaces-toggle-tab) (define-key map (kbd "<tab>") #'my/tabspaces-toggle-tab)
    (define-key map (kbd "SPC") #'my/tabspaces-toggle-tab) (define-key map (kbd "g") #'my/tabspaces-refresh-buffer-list) (define-key map (kbd "RET") #'my/tabspaces-visit-buffer)
    (define-key map (kbd "q") #'quit-window) (define-key map (kbd "?") #'describe-mode) map))

(define-derived-mode my/tabspaces-buffer-list-mode special-mode "Tabspaces-List"
  "Major mode for managing tabspace buffers."
  (setq truncate-lines t) (setq buffer-read-only t)
  (setq-local my/tabspaces-buffer-marks nil) (setq-local my/tabspaces-filter-mode 'file) (setq-local my/tabspaces-sort-mode 'name) (setq-local my/tabspaces-buffer-list--collapsed nil)
  (setq-local header-line-format '(:eval (concat (propertize "Tabspaces and Buffers" 'face 'bold) (when my/tabspaces-filter-mode (format " [Filter: %s]" my/tabspaces-filter-mode)) (format " [Sort: %s]" my/tabspaces-sort-mode))))
  (cursor-intangible-mode 1) (add-hook 'post-command-hook #'my/tab-util--ensure-on-item nil t))

(dolist (cmd '(my/tabspaces-buffer-list-mode my/tabspaces-refresh-buffer-list my/tabspaces-visit-buffer my/tabspaces-toggle-tab
               my/tabspaces-mark my/tabspaces-mark-delete my/tabspaces-mark-kill my/tabspaces-mark-save my/tabspaces-unmark-buffer
               my/tabspaces-unmark-all my/tabspaces-toggle-marks my/tabspaces-execute my/tabspaces-filter-modified my/tabspaces-filter-file
               my/tabspaces-filter-special my/tabspaces-filter-current-tab my/tabspaces-filter-clear my/tabspaces-sort-by-name
               my/tabspaces-sort-by-modified my/tabspaces-sort-by-size my/tabspaces-move-buffer-to-tab my/tabspaces-mark-by-name-regexp
               my/tabspaces-mark-modified-buffers))
  (put cmd 'completion-predicate #'ignore))

(provide 'tabspace-util)

;;; tabspace-util.el ends here
