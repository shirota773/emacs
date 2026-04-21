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
  (tabspaces-session-file . "~/.cache/emacs/.tabsession.el")
  (tabspaces-session-include . '("main" "work" "org")) ; resotre tab(test)

  :bind
  (("C-f" . hydra-buffer-primary/body)
   ("C-j" . tabspaces-switch-to-buffer)
   )
  :bind*
  ("C-r" . my/tabspaces-switch-or-recentf)

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

(defvar my/c-t-state 'recentf
  "State of C-t toggle: either 'recentf or 'tabspaces.")
(defun my/tabspaces-switch-or-recentf ()
  "Toggle between recentf and tabspaces buffer with C-t."
  (interactive)
  (message "Current state: %s" my/c-t-state)
    (cond
     ((and (active-minibuffer-window)
           (eq my/c-t-state 'recentf))
      (setq my/c-t-state 'tabspaces)
      (ivy-quit-and-run
        (my/tabspaces-switch-to-buffer)))
     ((and (active-minibuffer-window)
           (eq my/c-t-state 'tabspaces))
      (setq my/c-t-state 'recentf)
      (ivy-quit-and-run
         (counsel-buffer-or-recentf)))
     (t
      (setq my/c-t-state 'tabspaces)
         (my/tabspaces-switch-to-buffer)
         )))
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
  (expand-file-name "~/.cache/emacs/tabspace-sessions/")
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

(defun my/tabspace-list-saved-sessions ()
  "List all saved tab sessions."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let ((session-files
         (directory-files my/tabspace-sessions-dir nil "\\.el$")))
    (if (null session-files)
        (message "No saved tab sessions found")
      (with-output-to-temp-buffer "*Tab Sessions*"
        (princ "Saved Tab Sessions:\n")
        (princ "==================\n\n")
        (dolist (file session-files)
          (let ((session-name
                 (replace-regexp-in-string "_" " "
                                           (file-name-sans-extension file))))
            (princ (format "  - %s\n" session-name))))))))

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
