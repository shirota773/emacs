;; test
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
[_s_]:  save-tab-session       [_C-s_]: load-tab-session     | [_d_]:delete-tab-session

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
          ("C-K" tabspaces-kill-buffers-close-workspace )
          ("j" tab-bar-select-tab-by-name)
          ("s" my/tabspace-save-tab-session)
          ("C-s" my/tabspace-load-tab-session)
          ("d" my/tabspace-delete-tab-session)
          ("q" nil "exit"))
  :config
  (tab-bar-mode 1)
  (leaf tab-bar
    :custom
    (tab-bar-auto-width-min . '((10) 2))
    (tab-bar-auto-width-max . '((100) 10))
    (tab-bar-auto-width . t)
    (tab-bar-show . 1)
    :custom-face
    (tab-bar-tab . '((t ( :foreground "yellow" :box nil))))
    )

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

;; Old implementation removed below - replaced by 04_tabspace_bufferlist.el
;; (defun my/tabspaces-list-tabs-and-buffers ()
;;   "List all tabspaces (tab-bar tabs) and their buffers, clickable."
;;   (interactive)
;;   (let ((buf (get-buffer-create "*Tabspaces Buffers*"))
;;         (i 1))
;;     (with-current-buffer buf
;;       (let ((inhibit-read-only t))
;;         (erase-buffer)
;;         (insert (format "Tabspaces and Buffers\n%s\n\n"
;;                         (make-string 60 ?-)))
;;         ;; ���ׂẴ^�u�𑖍�
;;         (dolist (tab (tab-bar-tabs))
;;           (let* ((tab-name (alist-get 'name tab))
;;                  (current (eq tab (tab-bar--current-tab)))
;;                  (buffers (alist-get 'wc-bl tab)))
;;             ;; �^�u�s
;;             (insert-text-button
;;              (format "[%d] %s%s\n" i tab-name (if current "  <== current" ""))
;;              'action `(lambda (_)
;;                         (tab-bar-switch-to-tab ,tab-name))
;;              'follow-link t)
;;             ;; �o�b�t�@�s
;;             (if buffers
;;                 (dolist (b buffers)
;;                   (when (buffer-live-p b)
;;                     (insert "   ")
;;                     ;; �o�b�t�@���J���Ƃ��Ƀ^�u�ؑւ��s��
;;                     (insert-text-button
;;                      (buffer-name b)
;;                      'action `(lambda (_)
;;                                 (tab-bar-switch-to-tab ,tab-name)
;;                                 (switch-to-buffer ,b))
;;                      'follow-link t)
;;                     (insert "\n")))
;;               (insert "   (no buffers)\n"))
;;             (insert "\n")
;;             (setq i (1+ i)))))
;;       (goto-char (point-min))
;;       (special-mode))
;;     (pop-to-buffer buf)))
;; 
;; ;; Helper function to get buffers in a tab
;; (defun tabspaces--buffers-in-tab (tab)
;;   "Return a list of buffers belonging to TAB."
;;   (let* ((tab-name (alist-get 'name tab))
;;          (tab-space (tabspaces--workspace tab-name)))
;;     (when tab-space
;;       (seq-filter #'buffer-live-p (alist-get 'buffers tab-space)))))

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
  "Save the current tab's session (buffers and window configuration).
If TAB-NAME is nil, use the current tab.
Only saves file-visiting buffers, excluding special buffers."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let* ((current-tab (tab-bar--current-tab))
         (tab-name (or tab-name (alist-get 'name current-tab)))
         (session-file (my/tabspace--session-file tab-name))
         ;; Get all buffers belonging to this tab from frame-parameter
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
                            :special (not (buffer-file-name buf)))))  ; Mark special buffers
                  file-buffers))
         (session-data
          (list :tab-name tab-name
                :buffers buffer-info
                :window-state (window-state-get (frame-root-window) t))))

    (with-temp-file session-file
      (prin1 session-data (current-buffer)))
    (message "Tab session '%s' saved (%d buffers) to %s"
             tab-name (length buffer-info) session-file)))

(defun my/tabspace-load-tab-session (&optional tab-name)
  "Load a saved tab session.
If TAB-NAME is nil, prompt for a session to load."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let* ((session-files
          (directory-files my/tabspace-sessions-dir nil "\.el$"))
         (session-names
          (mapcar (lambda (f)
                    (replace-regexp-in-string "_" " "
                                              (file-name-sans-extension f)))
                  session-files))
         (selected-name
          (or tab-name
              (completing-read "Load tab session: " session-names nil t)))
         (session-file (my/tabspace--session-file selected-name)))
    (if (not (file-exists-p session-file))
        (message "No session found for tab '%s'" selected-name)
      (let* ((session-data
              (with-temp-buffer
                (insert-file-contents session-file)
                (read (current-buffer))))
             (saved-tab-name (plist-get session-data :tab-name))
             (buffer-info (plist-get session-data :buffers))
             (window-state (plist-get session-data :window-state)))

        ;; Create new tab or switch to existing one
        (let ((existing-tab
               (seq-find (lambda (tab)
                           (string= (alist-get 'name tab) saved-tab-name))
                         (tab-bar-tabs))))
          (if existing-tab
              (tab-bar-switch-to-tab saved-tab-name)
            (progn
              (tab-bar-new-tab)
              (tab-bar-rename-tab saved-tab-name))))

        ;; Clear current buffers in the tab
        (tabspaces-clear-buffers)

        ;; Restore buffers - open them without displaying yet
        (let ((loaded-buffers '()))
          (dolist (buf-data buffer-info)
            (let ((file (plist-get buf-data :file))
                  (name (plist-get buf-data :name))
                  (is-special (plist-get buf-data :special)))
              (cond
               ;; Handle file-visiting buffers
               ((and file (not is-special))
                (when (file-exists-p file)
                  (let ((buf (find-file-noselect file)))
                    (with-current-buffer buf
                      (goto-char (plist-get buf-data :point)))
                    (push buf loaded-buffers))))
               ;; Handle special buffers (like *Ibuffer*)
               (is-special
                (let ((buf (get-buffer-create name)))
                  (push buf loaded-buffers))))))

          ;; Add all loaded buffers to the frame's buffer-list to register them with the tab
          (dolist (buf (reverse loaded-buffers))
            (set-frame-parameter nil 'buffer-list
                                 (cons buf (delq buf (frame-parameter nil 'buffer-list))))))

        ;; Restore window configuration
        (when window-state
          (window-state-put window-state (frame-root-window) 'safe))

        (message "Tab session '%s' loaded (%d buffers)" saved-tab-name (length buffer-info))))))

(defun my/tabspace-delete-tab-session (&optional tab-name)
  "Delete a saved tab session.
If TAB-NAME is nil, prompt for a session to delete."
  (interactive)
  (my/tabspace--ensure-sessions-dir)
  (let* ((session-files
          (directory-files my/tabspace-sessions-dir nil "\.el$"))
         (session-names
          (mapcar (lambda (f)
                    (replace-regexp-in-string "_" " "
                                              (file-name-sans-extension f)))
                  session-files))
         (selected-name
          (or tab-name
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
         (directory-files my/tabspace-sessions-dir nil "\.el$")))
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

(provide '04_tabspace)
