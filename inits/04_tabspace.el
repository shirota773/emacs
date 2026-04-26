 (leaf tabspaces
  :ensure t
  :hook
  (after-init . tabspaces-mode)
  :custom
  (tabspaces-use-filtered-buffers-as-default . t) ; separate buffer respectively from tab
  (tabspaces-default-tab . "main")                ; default tab-name
  (tabspaces-remove-to-default . t)               ; return default-tab when close tab
  (tabspaces-session-auto-restore . t)            ; restoretabspace when rebooted
  (tabspaces-session . t)
  (tabspaces-session-include . '("main" "work" "org")) ; resotre tab(test)

  :bind
  (("C-f" . hydra-buffer-primary/body)
   ("C-j" . tabspaces-switch-to-buffer)
   )

  :hydra (hydra-buffer-primary
          (:color blue :hint nil :exit nil)
          "
^buffer & tabspace^
[_h_]: prev-tab [_n_]: new-tab   [_L_]: move-tab-left  |
[_l_]: next-tab [_k_]: close-tab [_H_]: move-tab-right |
[_j_]: select-tab
----------------------------- -----------------------------------------
[_f_]:  switch-buffer          [_r_]: remove-buffer-current  | [_C-k_]:close-workspace
[_C-f_]:switch-buffer&tab      [_R_]: remove-buffer-selected | [_C-K_]:close-buffers&kill-buffers
[_s_]:  save-session           [_C-s_]: load-session         | [_d_]:delete-session
[_ws_]: save-layout            [_wl_]: load-layout           | [_wd_]:delete-layout

 "
          ("h" tab-bar-switch-to-prev-tab :exit nil)
          ("l" tab-bar-switch-to-next-tab :exit nil)
          ("H" tab-bar-move-tab-backward :exit nil)
          ("L" tab-bar-move-tab :exit nil)
          ("n" my/tab-bar-new-tab-with-name)
          ("k" tab-bar-close-tab)
          ("f" tabspaces-switch-to-buffer)
          ("C-f" tabspaces-switch-buffer-and-tab)
          ("r" tabspaces-remove-current-buffer)
          ("R" tabspaces-remove-selected-buffer)
          ("C-k" tabspaces-close-workspace)
          ("C-K" tabspaces-kill-buffers-close-workspace)
          ("j" tab-bar-select-tab-by-name)
          ("s" my/tabspace-save-tab-session)
          ("C-s" my/tabspace-load-tab-session)
          ("d" my/tabspace-delete-tab-session)
          ("ws" my/tabspace-save-layout)
          ("wl" my/tabspace-load-layout)
          ("wd" my/tabspace-delete-layout)
          ("q" nil "exit"))
  :config
  (leaf tab-bar
    :custom
    (tab-bar-auto-width-min . '((10) 2))
    (tab-bar-auto-width-max . '((100) 10))
    (tab-bar-auto-width . t)
    (tab-bar-show . 1)          ; tab-bar-mode より先に設定
    :custom-face
    (tab-bar . '((t (:inherit default))))
    (tab-bar-tab . '((t (:foreground "yellow" :weight bold :box nil))))
    (tab-bar-tab-inactive . '((t (:foreground "gray60" :box nil))))
    )
  (tab-bar-mode 1)

   (advice-add 'project-switch-project :around #'my/project-switch-advice)

  (defun my/project-switch-advice (orig-fn &rest args)
    "create project automaticaly after new tab created"
    (let* ((project-dir (car args))
           (project-name (file-name-nondirectory (directory-file-name project-dir))))
      (tab-bar-new-tab)
      (tab-bar-rename-tab project-name)
      (apply orig-fn args)))

  (defun my/tab-bar-new-tab-with-name ()
    "create new-tab with input form minibuffer"
    (interactive)
    (let ((tab-name (read-string "New tab name: ")))
      (tab-bar-new-tab-to -1)
      (tab-bar-rename-tab tab-name))
    (ibuffer)
    (tabspaces-clear-buffers))

  (defun my/tabspaces-open-project-tree ()
    "Tabspaces �ɉ����� treemacs ���J���B"
    (interactive)
    (let ((proj (project-current)))
      (when proj
        (let ((proj-root (project-root proj)))
          (unless (treemacs-current-visibility)
            (treemacs))
          (treemacs-add-project-to-workspace proj-root (project-name proj))
          (treemacs-select-window)))))

  (defun my/tabspaces-switch-to-buffer (&optional norecord force-same-window)
    "Prompt for buffer and switch using tabspaces-switch-to-buffer, like M-x does."
    (let* ((blst (cl-remove (buffer-name) (mapcar #'buffer-name (tabspaces--buffer-list))))
           (buffer (read-buffer
                    "Switch to local buffer: " nil nil
                    (lambda (b) (member (if (stringp b) b (car b)) blst)))))
      (tabspaces-switch-to-buffer buffer norecord force-same-window))
    )

)

(leaf consult
  :ensure t
  :after tabspaces
  :config
  (defun consult-tabspaces-switch ()
    (interactive)
    (let ((tab (consult--read
                (mapcar #'car (tab-bar-tabs))
                :prompt "Switch to tab: ")))
      (tab-bar-switch-to-tab tab)))

  (global-set-key (kbd "C-c t") #'consult-tabspaces-switch))

;; Note: Enhanced buffer list implementation is in 04_tabspace_bufferlist.el
;; which will be loaded automatically by init-loader after this file.

;; ========================================
;; Per-tab session save/load functionality
;; ========================================

(defvar my/tabspace-sessions-dir
  (no-littering-expand-var-file-name "tabspace-sessions/")
  "Directory to store per-tab session files.")

(defcustom my/tabspace-session-include-buffers '((regexp . "\\*Ibuffer\\*"))
  "List of buffer name patterns to include in session saves.
These buffers are saved even if they match exclude patterns or are special buffers.
Each element can be:
  - A string: exact buffer name match
  - (regexp . PATTERN): regexp pattern match
  - (string . NAME): explicit exact match (same as string)

Examples:
  '(\"*Ibuffer*\")                    ; Exact match
  '((regexp . \"\\\\*Ibuffer\\\\*\"))      ; Regexp match
  '(\"*scratch*\" (regexp . \"\\\\*.*\\\\*\")) ; Mixed"
  :type '(repeat (choice string
                         (cons (const regexp) string)
                         (cons (const string) string)))
  :group 'tabspaces)

(defcustom my/tabspace-session-exclude-buffers '((regexp . "\\*scratch\\*")
                                                   (regexp . "\\*Messages\\*")
                                                   (regexp . "\\*Warnings\\*"))
  "List of buffer name patterns to exclude from session saves.
Each element can be:
  - A string: exact buffer name match
  - (regexp . PATTERN): regexp pattern match
  - (string . NAME): explicit exact match (same as string)
Note: Include patterns take precedence over exclude patterns."
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
  "Return non-nil if BUFFER-NAME matches PATTERN.
PATTERN can be:
  - A string: exact match
  - (regexp . REGEXP): regexp match
  - (string . STRING): exact match"
  (cond
   ;; Plain string - exact match
   ((stringp pattern)
    (string= buffer-name pattern))
   ;; (regexp . "pattern") - regexp match
   ((and (consp pattern) (eq (car pattern) 'regexp))
    (string-match-p (cdr pattern) buffer-name))
   ;; (string . "name") - exact match
   ((and (consp pattern) (eq (car pattern) 'string))
    (string= buffer-name (cdr pattern)))
   ;; Unknown format - ignore
   (t nil)))

(defun my/tabspace--buffer-matches-patterns-p (buffer-name patterns)
  "Return non-nil if BUFFER-NAME matches any pattern in PATTERNS."
  (seq-some (lambda (pattern)
              (my/tabspace--buffer-matches-pattern-p buffer-name pattern))
            patterns))

(defun my/tabspace--should-save-buffer-p (buf)
  "Return non-nil if BUF should be saved in a session.
Priority:
1. Include patterns (highest priority)
2. File-visiting buffers (excluding special buffers and exclude patterns)
3. Exclude patterns and special buffers are filtered out"
  (let ((name (buffer-name buf)))
    (and (buffer-live-p buf)
         (or
          ;; Priority 1: Explicitly included buffers
          (my/tabspace--buffer-matches-patterns-p name my/tabspace-session-include-buffers)
          ;; Priority 2: File-visiting buffers (excluding special buffers and exclude patterns)
          (and (buffer-file-name buf)
               (not (string-match-p "^\\*" name))  ; Exclude buffers starting with *
               (not (string-match-p "^ " name))    ; Exclude buffers starting with space
               (not (my/tabspace--buffer-matches-patterns-p name my/tabspace-session-exclude-buffers)))))))

(defun my/tabspace-save-tab-session (&optional tab-name)
  "Save the current tab's session (open buffer list only).
If TAB-NAME is nil, use the current tab.
Only saves file-visiting buffers, excluding special buffers.
Window layout is managed separately via `my/tabspace-save-layout'."
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
                :layouts (plist-get existing :layouts))))  ; 既存レイアウトを保持
    (my/tabspace--write-session tab-name session-data)
    (message "Tab session '%s' saved (%d buffers)" tab-name (length buffer-info))))

(defun my/tabspace-load-tab-session (&optional tab-name)
  "Load a saved tab session (buffer list only).
If TAB-NAME is nil, prompt for a session to load.
To restore window layout, use `my/tabspace-load-layout' afterwards."
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

        ;; Create new tab or switch to existing one
        (if (seq-find (lambda (tab) (string= (alist-get 'name tab) saved-tab-name))
                      (tab-bar-tabs))
            (tab-bar-switch-to-tab saved-tab-name)
          (tab-bar-new-tab)
          (tab-bar-rename-tab saved-tab-name))

        (tabspaces-clear-buffers)

        ;; Restore buffers
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
  "Delete a saved tab session file entirely.
If TAB-NAME is nil, prompt for a session to delete."
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

(defvar-local my/tabspace-session-list--expanded nil
  "Alist of (session-name . expanded-p) controlling file-list visibility.")

(defvar-local my/tabspace-session-list--marked-sessions nil
  "List of session names marked for deletion.")

(defvar-local my/tabspace-session-list--marked-files nil
  "List of (session-name . file-path) cons cells marked for removal.")

(defun my/tabspace-list-saved-sessions ()
  "Show an interactive list of saved tab sessions."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let ((buf (get-buffer-create "*Tab Sessions*")))
    (with-current-buffer buf
      (my/tabspace-session-list-mode)
      (my/tabspace-session-list-refresh))
    (pop-to-buffer buf)))

(defun my/tabspace-session-list-refresh ()
  "Redraw the session list buffer."
  (interactive)
  (let ((inhibit-read-only t)
        (saved-point (point))
        (header-start (point-min)))
    (erase-buffer)
    (setq header-start (point))
    ;; Title is rendered in `header-line-format'; body starts with the separator.
    (insert (propertize (make-string 60 ?=) 'face '(:foreground "gray50")) "\n")
    (insert (propertize
             "[a]dd [r]ename [+]add-file [d]mark-delete [u]nmark [U]nmark-all [x]execute\n"
             'face '(:foreground "gray50")))
    (insert (propertize
             "[RET]visit/load  [TAB/SPC]toggle  [g]refresh  [q]uit\n\n"
             'face '(:foreground "gray50")))
    (add-text-properties header-start (point) '(cursor-intangible t))
    (let ((files (directory-files my/tabspace-sessions-dir nil "\\.el\\'")))
      (if (null files)
          (insert (propertize "  (no saved sessions)\n"
                              'face '(:foreground "gray60")))
        (dolist (f files)
          (let* ((session-name (replace-regexp-in-string
                                "_" " " (file-name-sans-extension f)))
                 (data (my/tabspace--read-session session-name))
                 (buffers (plist-get data :buffers))
                 (expanded (alist-get session-name
                                      my/tabspace-session-list--expanded
                                      nil nil #'equal))
                 (marker (if expanded "▼" "▶"))
                 (session-marked (member session-name
                                         my/tabspace-session-list--marked-sessions))
                 (smark (if session-marked "D" " ")))
            (insert (propertize
                     (format "%s %s %s  (%d files)\n"
                             smark marker session-name (length buffers))
                     'face (if session-marked
                              'font-lock-warning-face
                            '(:foreground "cyan" :weight bold))
                     'session-name session-name
                     'line-type 'session))
            (when expanded
              (if (null buffers)
                  (insert (propertize "      (no files)\n"
                                      'face '(:foreground "gray60")
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
                             'face (when file-marked 'font-lock-warning-face)
                             'session-name session-name
                             'file-path file
                             'line-type 'file))))))))))
    (let ((first (or (text-property-any (point-min) (point-max)
                                        'line-type 'session)
                     (point-min))))
      (goto-char (max first (min saved-point (point-max)))))))

(defun my/tabspace-session-list--line-type ()
  (get-text-property (point) 'line-type))

(defun my/tabspace-session-list--session-at-point ()
  (get-text-property (point) 'session-name))

(defun my/tabspace-session-list--file-at-point ()
  (get-text-property (point) 'file-path))

(defun my/tabspace-session-list--ensure-on-item ()
  "Bounce point off header lines onto the nearest item line.
Works around the known `cursor-intangible-mode' edge case at point-min
where the upward bounce cannot cross buffer start."
  (when (and (eq major-mode 'my/tabspace-session-list-mode)
             (null (my/tabspace-session-list--line-type)))
    (let ((target (or (text-property-not-all (point) (point-max) 'line-type nil)
                      (text-property-not-all (point-min) (point) 'line-type nil))))
      (when target (goto-char target)))))

(defun my/tabspace-session-list-toggle ()
  "Toggle file-list visibility for the session at point."
  (interactive)
  (let ((name (my/tabspace-session-list--session-at-point)))
    (when name
      (let ((cur (alist-get name my/tabspace-session-list--expanded
                            nil nil #'equal)))
        (setf (alist-get name my/tabspace-session-list--expanded
                         nil nil #'equal)
              (not cur)))
      (my/tabspace-session-list-refresh))))

(defun my/tabspace-session-list-visit ()
  "On session line, load the session. On file line, open the file."
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (my/tabspace-load-tab-session (my/tabspace-session-list--session-at-point)))
    ('file
     (let ((file (my/tabspace-session-list--file-at-point)))
       (if (and file (file-exists-p file))
           (find-file file)
         (message "File not found: %s" file))))
    (_ (message "Nothing to visit at point"))))

(defun my/tabspace-session-list-add-session ()
  "Create a new empty session."
  (interactive)
  (let ((name (read-string "New session name: ")))
    (cond
     ((or (null name) (string-empty-p name))
      (message "Canceled"))
     ((file-exists-p (my/tabspace--session-file name))
      (message "Session '%s' already exists" name))
     (t
      (my/tabspace--write-session
       name (list :tab-name name :buffers nil :layouts nil))
      (my/tabspace-session-list-refresh)
      (message "Created session '%s'" name)))))

(defun my/tabspace-session-list-rename-session ()
  "Rename the session at point."
  (interactive)
  (let ((old (my/tabspace-session-list--session-at-point)))
    (if (not old)
        (message "No session at point")
      (let ((new (read-string (format "Rename '%s' to: " old) old)))
        (cond
         ((or (null new) (string-empty-p new) (string= old new))
          (message "Canceled"))
         ((file-exists-p (my/tabspace--session-file new))
          (message "Session '%s' already exists" new))
         (t
          (let* ((data (my/tabspace--read-session old))
                 (updated (plist-put (copy-tree data) :tab-name new)))
            (my/tabspace--write-session new updated)
            (delete-file (my/tabspace--session-file old))
            (let ((was (alist-get old my/tabspace-session-list--expanded
                                  nil nil #'equal)))
              (setq my/tabspace-session-list--expanded
                    (assoc-delete-all old my/tabspace-session-list--expanded))
              (when was
                (setf (alist-get new my/tabspace-session-list--expanded
                                 nil nil #'equal) t)))
            (my/tabspace-session-list-refresh)
            (message "Renamed '%s' → '%s'" old new))))))))

(defun my/tabspace-session-list-mark-delete ()
  "Mark the session or file at point for deletion."
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (let ((name (my/tabspace-session-list--session-at-point)))
       (when name
         (cl-pushnew name my/tabspace-session-list--marked-sessions
                     :test #'equal)
         (my/tabspace-session-list-refresh)
         (forward-line 1))))
    ('file
     (let ((name (my/tabspace-session-list--session-at-point))
           (file (my/tabspace-session-list--file-at-point)))
       (when (and name file)
         (cl-pushnew (cons name file) my/tabspace-session-list--marked-files
                     :test #'equal)
         (my/tabspace-session-list-refresh)
         (forward-line 1))))
    (_ (message "Nothing to mark at point"))))

(defun my/tabspace-session-list-unmark ()
  "Unmark the item at point."
  (interactive)
  (pcase (my/tabspace-session-list--line-type)
    ('session
     (let ((name (my/tabspace-session-list--session-at-point)))
       (setq my/tabspace-session-list--marked-sessions
             (delete name my/tabspace-session-list--marked-sessions))))
    ('file
     (let ((name (my/tabspace-session-list--session-at-point))
           (file (my/tabspace-session-list--file-at-point)))
       (setq my/tabspace-session-list--marked-files
             (delete (cons name file)
                     my/tabspace-session-list--marked-files)))))
  (my/tabspace-session-list-refresh)
  (forward-line 1))

(defun my/tabspace-session-list-unmark-all ()
  "Clear all delete marks."
  (interactive)
  (setq my/tabspace-session-list--marked-sessions nil)
  (setq my/tabspace-session-list--marked-files nil)
  (my/tabspace-session-list-refresh))

(defun my/tabspace-session-list-execute ()
  "Execute all pending delete marks.
Sessions marked for deletion take precedence: any file marks pointing
to those sessions are skipped since the whole session will be removed."
  (interactive)
  (let ((sessions my/tabspace-session-list--marked-sessions)
        (files (seq-remove
                (lambda (cell)
                  (member (car cell)
                          my/tabspace-session-list--marked-sessions))
                my/tabspace-session-list--marked-files)))
    (if (and (null sessions) (null files))
        (message "No marks to execute")
      (when (yes-or-no-p
             (format "Execute: delete %d session(s), remove %d file entry(ies)? "
                     (length sessions) (length files)))
        ;; Remove file entries, grouped by session to minimize writes.
        (dolist (entry (seq-group-by #'car files))
          (let* ((sname (car entry))
                 (paths (mapcar #'cdr (cdr entry)))
                 (data (my/tabspace--read-session sname))
                 (buffers (plist-get data :buffers))
                 (new-buffers (seq-remove
                               (lambda (b)
                                 (member (plist-get b :file) paths))
                               buffers)))
            (my/tabspace--write-session
             sname (plist-put (copy-tree data) :buffers new-buffers))))
        ;; Delete sessions.
        (dolist (sname sessions)
          (let ((file (my/tabspace--session-file sname)))
            (when (file-exists-p file)
              (delete-file file)))
          (setq my/tabspace-session-list--expanded
                (assoc-delete-all sname my/tabspace-session-list--expanded)))
        (setq my/tabspace-session-list--marked-sessions nil)
        (setq my/tabspace-session-list--marked-files nil)
        (my/tabspace-session-list-refresh)
        (message "Executed: %d session(s), %d file(s)"
                 (length sessions) (length files))))))

(defun my/tabspace-session-list-add-file ()
  "Register a file into the session at point."
  (interactive)
  (let ((name (my/tabspace-session-list--session-at-point)))
    (if (not name)
        (message "No session at point")
      (let* ((path (read-file-name "Add file to session: " nil nil t))
             (abspath (expand-file-name path))
             (data (or (my/tabspace--read-session name)
                       (list :tab-name name :buffers nil :layouts nil)))
             (buffers (plist-get data :buffers)))
        (if (seq-find (lambda (b) (equal (plist-get b :file) abspath)) buffers)
            (message "Already registered: %s" abspath)
          (let ((new-buffers
                 (append buffers
                         (list (list :name (file-name-nondirectory abspath)
                                     :file abspath
                                     :major-mode nil
                                     :point 1
                                     :special nil)))))
            (my/tabspace--write-session
             name (plist-put (copy-tree data) :buffers new-buffers))
            (setf (alist-get name my/tabspace-session-list--expanded
                             nil nil #'equal) t)
            (my/tabspace-session-list-refresh)
            (message "Added '%s' to '%s'" abspath name)))))))

(defvar my/tabspace-session-list-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "<tab>") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "SPC") #'my/tabspace-session-list-toggle)
    (define-key map (kbd "RET") #'my/tabspace-session-list-visit)
    (define-key map (kbd "a") #'my/tabspace-session-list-add-session)
    (define-key map (kbd "r") #'my/tabspace-session-list-rename-session)
    (define-key map (kbd "+") #'my/tabspace-session-list-add-file)
    (define-key map (kbd "d") #'my/tabspace-session-list-mark-delete)
    (define-key map (kbd "u") #'my/tabspace-session-list-unmark)
    (define-key map (kbd "U") #'my/tabspace-session-list-unmark-all)
    (define-key map (kbd "x") #'my/tabspace-session-list-execute)
    (define-key map (kbd "g") #'my/tabspace-session-list-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `my/tabspace-session-list-mode'.")

(set-keymap-parent my/tabspace-session-list-mode-map special-mode-map)

(define-derived-mode my/tabspace-session-list-mode special-mode "Tab-Sessions"
  "Major mode for browsing and editing saved tab sessions.

Key bindings:
  TAB / SPC - Toggle file list visibility for session at point
  RET       - Load session (on session line) or open file (on file line)
  a         - Add a new empty session
  r         - Rename session at point
  +         - Add a file to session at point
  d         - Mark session or file at point for deletion
  u         - Unmark at point
  U         - Unmark all
  x         - Execute all pending delete marks
  g         - Refresh the list
  q         - Quit window

\\{my/tabspace-session-list-mode-map}"
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (setq-local my/tabspace-session-list--expanded nil)
  (setq-local my/tabspace-session-list--marked-sessions nil)
  (setq-local my/tabspace-session-list--marked-files nil)
  (setq-local header-line-format
              (propertize "Saved Tab Sessions" 'face 'bold))
  (cursor-intangible-mode 1)
  (add-hook 'post-command-hook
            #'my/tabspace-session-list--ensure-on-item nil t))

;; Hide in-mode commands from M-x (still reachable via their key bindings).
(dolist (cmd '(my/tabspace-session-list-mode
               my/tabspace-session-list-refresh
               my/tabspace-session-list-toggle
               my/tabspace-session-list-visit
               my/tabspace-session-list-add-session
               my/tabspace-session-list-rename-session
               my/tabspace-session-list-mark-delete
               my/tabspace-session-list-unmark
               my/tabspace-session-list-unmark-all
               my/tabspace-session-list-execute
               my/tabspace-session-list-add-file))
  (put cmd 'completion-predicate #'ignore))

;; ========================================
;; Per-tab named layout save/load
;; ========================================

(defun my/tabspace-save-layout (&optional layout-name)
  "Save current window arrangement as LAYOUT-NAME for the current tab.
If LAYOUT-NAME is nil or omitted, uses \"default\"."
  (interactive (list (read-string "Layout name (default: \"default\"): " nil nil "default")))
  (let* ((layout-name (or (and (stringp layout-name) (not (string-empty-p layout-name))
                               layout-name)
                          "default"))
         (tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (or (my/tabspace--read-session tab-name)
                      (list :tab-name tab-name :buffers nil :layouts nil)))
         (layouts (plist-get session :layouts))
         (window-state (window-state-get (frame-root-window) t))
         (new-layouts (cons (cons layout-name window-state)
                            (cl-remove layout-name layouts :key #'car :test #'equal))))
    (my/tabspace--write-session tab-name
      (plist-put (copy-tree session) :layouts new-layouts))
    (message "Layout '%s' saved for tab '%s'" layout-name tab-name)))

(defun my/tabspace-load-layout (&optional layout-name)
  "Load a named layout for the current tab.
If LAYOUT-NAME is nil, prompt with completion."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name)))
    (if (not session)
        (message "No session found for tab '%s'" tab-name)
      (let* ((layouts (or (plist-get session :layouts)
                          ;; 後方互換: 旧 :window-state を "default" として扱う
                          (when (plist-get session :window-state)
                            (list (cons "default" (plist-get session :window-state))))))
             (names (mapcar #'car layouts))
             (selected (or layout-name
                           (completing-read "Load layout: " names nil t)))
             (state (cdr (assoc selected layouts))))
        (if state
            (progn
              (window-state-put state (frame-root-window) 'safe)
              (message "Layout '%s' loaded" selected))
          (message "Layout '%s' not found for tab '%s'" selected tab-name))))))

(defun my/tabspace-delete-layout (&optional layout-name)
  "Delete a named layout for the current tab."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name)))
    (if (not session)
        (message "No session found for tab '%s'" tab-name)
      (let* ((layouts (plist-get session :layouts)))
        (if (not layouts)
            (message "No layouts saved for tab '%s'" tab-name)
          (let* ((names (mapcar #'car layouts))
                 (selected (or layout-name
                               (completing-read "Delete layout: " names nil t))))
            (when (y-or-n-p (format "Delete layout '%s'? " selected))
              (my/tabspace--write-session tab-name
                (plist-put (copy-tree session) :layouts
                           (cl-remove selected layouts :key #'car :test #'equal)))
              (message "Layout '%s' deleted" selected))))))))

(defun my/tabspace-list-layouts ()
  "List all saved layouts for the current tab."
  (interactive)
  (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
         (session (my/tabspace--read-session tab-name))
         (layouts (plist-get session :layouts)))
    (if (not layouts)
        (message "No layouts saved for tab '%s'" tab-name)
      (message "Layouts for '%s': %s"
               tab-name (mapconcat #'car layouts ", ")))))

;; ========================================
;; Per-tab winner-mode
;; ========================================

(defvar my/winner-tab-rings (make-hash-table :test 'equal)
  "Hash table mapping tab names to their winner-mode ring state.")

(defun my/winner-save-for-tab ()
  "Save current winner-mode state for the current tab."
  (when (and (boundp 'winner-mode) winner-mode
             (boundp 'winner-ring-alist))
    (let ((tab-name (alist-get 'name (tab-bar--current-tab))))
      (puthash tab-name
               (list :ring (copy-tree winner-ring-alist)
                     :pending (and (boundp 'winner-pending-alist)
                                   (copy-tree winner-pending-alist)))
               my/winner-tab-rings))))

(defun my/winner-restore-for-tab ()
  "Restore winner-mode state for the current tab."
  (when (and (boundp 'winner-mode) winner-mode
             (boundp 'winner-ring-alist))
    (let* ((tab-name (alist-get 'name (tab-bar--current-tab)))
           (state (gethash tab-name my/winner-tab-rings)))
      (if state
          (progn
            (setq winner-ring-alist (plist-get state :ring))
            (when (boundp 'winner-pending-alist)
              (setq winner-pending-alist (or (plist-get state :pending) nil))))
        (setq winner-ring-alist nil)
        (when (boundp 'winner-pending-alist)
          (setq winner-pending-alist nil))))))

(add-hook 'tab-bar-tab-pre-change-functions #'my/winner-save-for-tab)
(add-hook 'tab-bar-tab-post-change-functions #'my/winner-restore-for-tab)

(provide '04_tabspace)
