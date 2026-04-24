;; ========================================
;; Tabspace buffer list (ibuffer-like)
;; ========================================

(require 'tabspaces)

(defvar-local my/tabspaces-buffer-marks nil
  "Alist of (buffer-name . mark-type) for marked buffers.
Mark types: 'delete 'save 'mark 'kill")

(defvar-local my/tabspaces-filter-mode 'file
  "Current filter mode: nil (all), 'modified, 'file (default, no special buffers), 'special, or 'current-tab.")

(defvar-local my/tabspaces-sort-mode 'name
  "Current sort mode: 'name, 'modified, or 'size.")

(defvar-local my/tabspaces-buffer-list--collapsed nil
  "List of tab names currently collapsed in the buffer list.")

(defun my/tabspaces-list-tabs-and-buffers ()
  "List all tabspaces (tab-bar tabs) and their buffers with ibuffer-like operations."
  (interactive)
  (let ((buf (get-buffer-create "*Tabspaces Buffers*")))
    (with-current-buffer buf
      (my/tabspaces-buffer-list-mode)
      (my/tabspaces-refresh-buffer-list))
    (pop-to-buffer buf)))

(defun my/tabspaces--buffer-tab-count (buffer)
  "Return the number of tabs that contain BUFFER."
  (let ((count 0))
    (dolist (tab (tab-bar-tabs))
      (let ((buffers (alist-get 'wc-bl tab)))
        (when (memq buffer buffers)
          (setq count (1+ count)))))
    count))

(defun my/tabspaces--get-buffer-tabs (buffer)
  "Return list of tab names that contain BUFFER."
  (let ((tabs '()))
    (dolist (tab (tab-bar-tabs))
      (let ((tab-name (alist-get 'name tab))
            (buffers (alist-get 'wc-bl tab)))
        (when (memq buffer buffers)
          (push tab-name tabs))))
    (nreverse tabs)))

(defun my/tabspaces--should-show-buffer-p (buffer)
  "Return non-nil if BUFFER should be shown based on current filter."
  (cond
   ((null my/tabspaces-filter-mode) t)
   ((eq my/tabspaces-filter-mode 'modified)
    (buffer-modified-p buffer))
   ((eq my/tabspaces-filter-mode 'file)
    (buffer-file-name buffer))
   ((eq my/tabspaces-filter-mode 'special)
    (not (buffer-file-name buffer)))
   ((eq my/tabspaces-filter-mode 'current-tab)
    (let ((current-tab-name (alist-get 'name (tab-bar--current-tab))))
      (member current-tab-name (my/tabspaces--get-buffer-tabs buffer))))
   (t t)))

(defun my/tabspaces--sort-buffers (buffers)
  "Sort BUFFERS according to current sort mode."
  (cl-sort buffers
           (cond
            ((eq my/tabspaces-sort-mode 'name)
             (lambda (a b) (string< (buffer-name a) (buffer-name b))))
            ((eq my/tabspaces-sort-mode 'modified)
             (lambda (a b)
               (let ((time-a (or (buffer-modified-tick a) 0))
                     (time-b (or (buffer-modified-tick b) 0)))
                 (> time-a time-b))))
            ((eq my/tabspaces-sort-mode 'size)
             (lambda (a b)
               (> (buffer-size a) (buffer-size b))))
            (t (lambda (a b) (string< (buffer-name a) (buffer-name b)))))))

(defun my/tabspaces-refresh-buffer-list ()
  "Refresh the tabspaces buffer list display."
  (interactive)
  (let ((inhibit-read-only t)
        (saved-point (point))
        (header-start (point-min))
        (i 1))
    (erase-buffer)
    (setq header-start (point))
    ;; Title is rendered in `header-line-format'; body starts with the separator.
    (insert (propertize (make-string 80 ?=) 'face '(:foreground "gray50")) "\n")
    (insert (propertize "Mark:   " 'face '(:foreground "gray50"))
            (propertize "[d]elete [k]ill [s]ave [m]ark [u]nmark [U]nmark-all [t]oggle [x]execute\n" 'face '(:foreground "gray50")))
    (insert (propertize "Filter: " 'face '(:foreground "gray50"))
            (propertize "[/ m]odified [/ f]ile [/ s]pecial [/ t]current-tab [/ /]clear\n" 'face '(:foreground "gray50")))
    (insert (propertize "Sort:   " 'face '(:foreground "gray50"))
            (propertize "[o n]ame [o m]odified [o s]ize\n" 'face '(:foreground "gray50")))
    (insert (propertize "Other:  " 'face '(:foreground "gray50"))
            (propertize "[RET]visit [TAB/SPC]toggle [M]ove-to-tab [g]refresh [% n]regexp [* m]modified [q]uit\n\n" 'face '(:foreground "gray50")))
    (add-text-properties header-start (point) '(cursor-intangible t))

    ;; Iterate through all tabs
    (let ((current-tab-name (alist-get 'name (tab-bar--current-tab))))
      (dolist (tab (tab-bar-tabs))
        (let* ((tab-name (alist-get 'name tab))
               (current (string= tab-name current-tab-name))
               (collapsed (member tab-name my/tabspaces-buffer-list--collapsed))
               (marker (if collapsed "▶" "▼"))
               ;; アクティブタブは wc-bl を持たないため frame の buffer-list から取得する
               (all-buffers (seq-filter #'buffer-live-p
                                        (if current
                                            (frame-parameter nil 'buffer-list)
                                          (or (alist-get 'wc-bl tab) '()))))
               (filtered-buffers (seq-filter #'my/tabspaces--should-show-buffer-p all-buffers))
               (sorted-buffers (my/tabspaces--sort-buffers filtered-buffers)))
          ;; Tab header line
          (insert (propertize
                   (format "%s [%d] %s%s (%d/%d buffers)\n"
                           marker i tab-name
                           (if current " <== current" "")
                           (length filtered-buffers)
                           (length all-buffers))
                   'face '(:foreground "cyan" :weight bold)
                   'tab-name tab-name
                   'line-type 'tab))

          ;; Buffer lines (only when expanded)
          (unless collapsed
            (if sorted-buffers
                (dolist (b sorted-buffers)
                  (when (buffer-live-p b)
                    (let* ((buf-name (buffer-name b))
                           (mark-type (alist-get buf-name my/tabspaces-buffer-marks nil nil #'equal))
                           (mark-char (cond
                                       ((eq mark-type 'delete) "D")
                                       ((eq mark-type 'kill) "K")
                                       ((eq mark-type 'save) "S")
                                       ((eq mark-type 'mark) "*")
                                       (t " ")))
                           (modified (buffer-modified-p b))
                           (file (buffer-file-name b))
                           (tab-count (my/tabspaces--buffer-tab-count b))
                           (multi-tab (> tab-count 1))
                           (tabs-info (when multi-tab
                                        (format " [%d tabs: %s]"
                                                tab-count
                                                (mapconcat 'identity
                                                           (my/tabspaces--get-buffer-tabs b)
                                                           ", "))))
                           (size (buffer-size b))
                           (face (cond
                                  ((eq mark-type 'delete) 'font-lock-warning-face)
                                  ((eq mark-type 'kill) 'error)
                                  (multi-tab '(:foreground "yellow"))
                                  (t 'default))))
                      (insert (propertize
                               (format "    %s %s %-40s %6s%s%s\n"
                                       mark-char
                                       (if modified "*" " ")
                                       buf-name
                                       (file-size-human-readable size)
                                       (if file (format " (%s)" (abbreviate-file-name file)) "")
                                       (or tabs-info ""))
                               'face face
                               'buffer-name buf-name
                               'tab-name tab-name
                               'line-type 'buffer)))))
              (insert (propertize "      (no buffers)\n"
                                  'face '(:foreground "gray60")
                                  'tab-name tab-name
                                  'line-type 'empty))))
          (insert (propertize "\n" 'cursor-intangible t))
          (setq i (1+ i)))))
    ;; Restore cursor: prefer previous point, fall back to first tab line.
    (let ((first (or (text-property-any (point-min) (point-max)
                                        'line-type 'tab)
                     (point-min))))
      (goto-char (max first (min saved-point (point-max)))))))

;; ----------------------------------------
;; Line-type accessors
;; ----------------------------------------

(defun my/tabspaces-buffer-list--line-type ()
  "Return the line-type symbol at point ('tab, 'buffer, 'empty, or nil)."
  (get-text-property (point) 'line-type))

(defun my/tabspaces-buffer-list--tab-at-point ()
  "Return the tab name attached to the current line, or nil."
  (get-text-property (point) 'tab-name))

(defun my/tabspaces-buffer-at-point ()
  "Return the live buffer object at point, or nil if the line is not a buffer line."
  (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
    (let ((name (get-text-property (point) 'buffer-name)))
      (and name (get-buffer name)))))

(defun my/tabspaces-buffer-list--ensure-on-item ()
  "Bounce point off header lines onto the nearest item line.
Works around the known `cursor-intangible-mode' edge case at point-min
where the upward bounce cannot cross buffer start."
  (when (and (eq major-mode 'my/tabspaces-buffer-list-mode)
             (null (my/tabspaces-buffer-list--line-type)))
    (let ((target (or (text-property-not-all (point) (point-max) 'line-type nil)
                      (text-property-not-all (point-min) (point) 'line-type nil))))
      (when target (goto-char target)))))

;; ----------------------------------------
;; Expand / collapse
;; ----------------------------------------

(defun my/tabspaces-toggle-tab ()
  "Toggle buffer-list visibility for the tab at point."
  (interactive)
  (let ((name (my/tabspaces-buffer-list--tab-at-point)))
    (when name
      (if (member name my/tabspaces-buffer-list--collapsed)
          (setq my/tabspaces-buffer-list--collapsed
                (delete name my/tabspaces-buffer-list--collapsed))
        (push name my/tabspaces-buffer-list--collapsed))
      (my/tabspaces-refresh-buffer-list))))

;; ----------------------------------------
;; Mark commands
;; ----------------------------------------

(defun my/tabspaces-mark-buffer (mark-type)
  "Mark the buffer at point with MARK-TYPE."
  (let ((buf (my/tabspaces-buffer-at-point)))
    (when buf
      (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) mark-type)
      (my/tabspaces-refresh-buffer-list)
      (forward-line 1))))

(defun my/tabspaces-unmark-buffer ()
  "Unmark the buffer at point."
  (interactive)
  (let ((buf (my/tabspaces-buffer-at-point)))
    (when buf
      (setq my/tabspaces-buffer-marks
            (assoc-delete-all (buffer-name buf) my/tabspaces-buffer-marks))
      (my/tabspaces-refresh-buffer-list)
      (forward-line 1))))

(defun my/tabspaces-mark-delete ()
  "Mark buffer at point for deletion from tab."
  (interactive)
  (my/tabspaces-mark-buffer 'delete))

(defun my/tabspaces-mark-kill ()
  "Mark buffer at point to be killed."
  (interactive)
  (my/tabspaces-mark-buffer 'kill))

(defun my/tabspaces-mark-save ()
  "Mark buffer at point to be saved."
  (interactive)
  (my/tabspaces-mark-buffer 'save))

(defun my/tabspaces-mark ()
  "Mark buffer at point."
  (interactive)
  (my/tabspaces-mark-buffer 'mark))

(defun my/tabspaces-execute ()
  "Execute all marked operations."
  (interactive)
  (let ((delete-list '())
        (kill-list '())
        (save-list '()))
    ;; Collect marked buffers
    (dolist (entry my/tabspaces-buffer-marks)
      (let* ((name (car entry))
             (buf (get-buffer name))
             (mark-type (cdr entry)))
        (when (buffer-live-p buf)
          (cond
           ((eq mark-type 'delete) (push buf delete-list))
           ((eq mark-type 'kill)   (push buf kill-list))
           ((eq mark-type 'save)   (push buf save-list))))))

    (when save-list
      (dolist (buf save-list)
        (with-current-buffer buf
          (when (buffer-modified-p)
            (save-buffer)))
        (message "Saved: %s" (buffer-name buf))))

    (when delete-list
      (when (yes-or-no-p (format "Remove %d buffer(s) from tab? " (length delete-list)))
        (dolist (buf delete-list)
          (tabspaces-remove-selected-buffer buf)
          (message "Removed from tab: %s" (buffer-name buf)))))

    (when kill-list
      (when (yes-or-no-p (format "Kill %d buffer(s)? " (length kill-list)))
        (dolist (buf kill-list)
          (kill-buffer buf)
          (message "Killed: %s" (buffer-name buf)))))

    (setq my/tabspaces-buffer-marks nil)
    (my/tabspaces-refresh-buffer-list)))

(defun my/tabspaces-unmark-all ()
  "Unmark all buffers."
  (interactive)
  (setq my/tabspaces-buffer-marks nil)
  (my/tabspaces-refresh-buffer-list))

;; ----------------------------------------
;; Visit (dispatch on line type)
;; ----------------------------------------

(defun my/tabspaces-visit-buffer ()
  "Visit the tab or buffer at point.
On a tab line, switch to that tab. On a buffer line, switch to the tab
that owns the buffer and then select the buffer."
  (interactive)
  (pcase (my/tabspaces-buffer-list--line-type)
    ('tab
     (let ((name (my/tabspaces-buffer-list--tab-at-point)))
       (when name (tab-bar-switch-to-tab name))))
    ('buffer
     (let ((buf (my/tabspaces-buffer-at-point))
           (tab-name (my/tabspaces-buffer-list--tab-at-point)))
       (when (and buf tab-name)
         (tab-bar-switch-to-tab tab-name)
         (switch-to-buffer buf))))
    (_ (message "Nothing to visit at point"))))

;; ----------------------------------------
;; Filter commands
;; ----------------------------------------

(defun my/tabspaces-filter-modified ()
  "Filter to show only modified buffers."
  (interactive)
  (setq my/tabspaces-filter-mode 'modified)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-filter-file ()
  "Filter to show only file buffers."
  (interactive)
  (setq my/tabspaces-filter-mode 'file)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-filter-special ()
  "Filter to show only special buffers."
  (interactive)
  (setq my/tabspaces-filter-mode 'special)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-filter-clear ()
  "Clear all filters and show all buffers."
  (interactive)
  (setq my/tabspaces-filter-mode nil)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-filter-current-tab ()
  "Filter to show only buffers belonging to the current tab."
  (interactive)
  (setq my/tabspaces-filter-mode 'current-tab)
  (my/tabspaces-refresh-buffer-list))

;; ----------------------------------------
;; Move buffer to another tab
;; ----------------------------------------

(defun my/tabspaces-move-buffer-to-tab ()
  "Move buffer at point to another tab."
  (interactive)
  (let* ((buf (my/tabspaces-buffer-at-point))
         (current-tab-name (my/tabspaces-buffer-list--tab-at-point))
         (other-tabs (seq-remove
                      (lambda (name) (string= name current-tab-name))
                      (mapcar (lambda (tab) (alist-get 'name tab)) (tab-bar-tabs))))
         (target-tab (and buf current-tab-name
                          (completing-read "Move to tab: " other-tabs nil t))))
    (when (and buf target-tab)
      (let ((orig-tab (alist-get 'name (tab-bar--current-tab)))
            (tab-bar-tab-pre-change-functions nil)
            (tab-bar-tab-post-change-functions nil))
        (tab-bar-switch-to-tab target-tab)
        (set-frame-parameter nil 'buffer-list
                             (cons buf (delq buf (frame-parameter nil 'buffer-list))))
        (tab-bar-switch-to-tab orig-tab))
      (tabspaces-remove-selected-buffer buf)
      (my/tabspaces-refresh-buffer-list)
      (message "Moved '%s' → '%s'" (buffer-name buf) target-tab))))

;; ----------------------------------------
;; Sort commands
;; ----------------------------------------

(defun my/tabspaces-sort-by-name ()
  "Sort buffers by name."
  (interactive)
  (setq my/tabspaces-sort-mode 'name)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-sort-by-modified ()
  "Sort buffers by modification time."
  (interactive)
  (setq my/tabspaces-sort-mode 'modified)
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-sort-by-size ()
  "Sort buffers by size."
  (interactive)
  (setq my/tabspaces-sort-mode 'size)
  (my/tabspaces-refresh-buffer-list))

;; ----------------------------------------
;; Bulk operations
;; ----------------------------------------

(defun my/tabspaces-toggle-marks ()
  "Toggle marks on all visible buffer lines."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
        (let ((buf (my/tabspaces-buffer-at-point)))
          (when buf
            (let ((name (buffer-name buf)))
              (if (alist-get name my/tabspaces-buffer-marks nil nil #'equal)
                  (setq my/tabspaces-buffer-marks
                        (assoc-delete-all name my/tabspaces-buffer-marks))
                (setf (alist-get name my/tabspaces-buffer-marks nil nil #'equal) 'mark))))))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-by-name-regexp (regexp)
  "Mark all visible buffers whose names match REGEXP."
  (interactive "sMark buffers matching regexp: ")
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
        (let ((buf (my/tabspaces-buffer-at-point)))
          (when (and buf (string-match-p regexp (buffer-name buf)))
            (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) 'mark))))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-modified-buffers ()
  "Mark all visible modified buffers."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (eq (my/tabspaces-buffer-list--line-type) 'buffer)
        (let ((buf (my/tabspaces-buffer-at-point)))
          (when (and buf (buffer-modified-p buf))
            (setf (alist-get (buffer-name buf) my/tabspaces-buffer-marks nil nil #'equal) 'mark))))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

;; ----------------------------------------
;; Keymap + mode
;; ----------------------------------------

(defvar my/tabspaces-buffer-list-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Mark commands
    (define-key map (kbd "d") #'my/tabspaces-mark-delete)
    (define-key map (kbd "k") #'my/tabspaces-mark-kill)
    (define-key map (kbd "s") #'my/tabspaces-mark-save)
    (define-key map (kbd "m") #'my/tabspaces-mark)
    (define-key map (kbd "u") #'my/tabspaces-unmark-buffer)
    (define-key map (kbd "U") #'my/tabspaces-unmark-all)
    (define-key map (kbd "t") #'my/tabspaces-toggle-marks)
    (define-key map (kbd "x") #'my/tabspaces-execute)
    ;; Filter commands
    (define-key map (kbd "/ m") #'my/tabspaces-filter-modified)
    (define-key map (kbd "/ f") #'my/tabspaces-filter-file)
    (define-key map (kbd "/ s") #'my/tabspaces-filter-special)
    (define-key map (kbd "/ t") #'my/tabspaces-filter-current-tab)
    (define-key map (kbd "/ /") #'my/tabspaces-filter-clear)
    ;; Move to tab
    (define-key map (kbd "M") #'my/tabspaces-move-buffer-to-tab)
    ;; Sort commands
    (define-key map (kbd "o n") #'my/tabspaces-sort-by-name)
    (define-key map (kbd "o m") #'my/tabspaces-sort-by-modified)
    (define-key map (kbd "o s") #'my/tabspaces-sort-by-size)
    ;; Bulk operations
    (define-key map (kbd "% n") #'my/tabspaces-mark-by-name-regexp)
    (define-key map (kbd "* m") #'my/tabspaces-mark-modified-buffers)
    ;; Expand / collapse
    (define-key map (kbd "TAB")   #'my/tabspaces-toggle-tab)
    (define-key map (kbd "<tab>") #'my/tabspaces-toggle-tab)
    (define-key map (kbd "SPC")   #'my/tabspaces-toggle-tab)
    ;; Other commands
    (define-key map (kbd "g") #'my/tabspaces-refresh-buffer-list)
    (define-key map (kbd "RET") #'my/tabspaces-visit-buffer)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap for `my/tabspaces-buffer-list-mode'.")

(set-keymap-parent my/tabspaces-buffer-list-mode-map special-mode-map)

(define-derived-mode my/tabspaces-buffer-list-mode special-mode "Tabspaces-List"
  "Major mode for managing tabspace buffers.

Key bindings:

Mark commands:
  d - Mark buffer for deletion from tab
  k - Mark buffer to be killed
  s - Mark buffer to be saved
  m - Mark buffer
  u - Unmark buffer at point
  U - Unmark all buffers
  t - Toggle marks on all buffers
  x - Execute all marked operations

Filter commands:
  / m - Show only modified buffers
  / f - Show only file buffers
  / s - Show only special buffers
  / t - Show only buffers in current tab
  / / - Clear all filters

Sort commands:
  o n - Sort by name
  o m - Sort by modification time
  o s - Sort by size

Bulk operations:
  % n - Mark buffers matching regexp
  * m - Mark all modified buffers

Move commands:
  M   - Move buffer at point to another tab

Navigation:
  TAB / SPC - Toggle expansion of tab at point
  RET       - Visit: on tab line switch to tab; on buffer line open buffer
  g         - Refresh the buffer list
  q         - Quit window
  ?         - Show help

Special features:
- Buffers belonging to multiple tabs are highlighted in yellow
- Shows tab count and tab names for multi-tab buffers
- Displays buffer size in human-readable format
- Shows file paths (abbreviated)

\\{my/tabspaces-buffer-list-mode-map}"
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (setq-local my/tabspaces-buffer-marks nil)
  (setq-local my/tabspaces-filter-mode 'file)  ; Default: hide special buffers
  (setq-local my/tabspaces-sort-mode 'name)
  (setq-local my/tabspaces-buffer-list--collapsed nil)
  (setq-local header-line-format
              '(:eval (concat
                       (propertize "Tabspaces and Buffers" 'face 'bold)
                       (when my/tabspaces-filter-mode
                         (format " [Filter: %s]" my/tabspaces-filter-mode))
                       (format " [Sort: %s]" my/tabspaces-sort-mode))))
  (cursor-intangible-mode 1)
  (add-hook 'post-command-hook
            #'my/tabspaces-buffer-list--ensure-on-item nil t))

;; Hide in-mode commands from M-x (still reachable via their key bindings).
(dolist (cmd '(my/tabspaces-buffer-list-mode
               my/tabspaces-refresh-buffer-list
               my/tabspaces-visit-buffer
               my/tabspaces-toggle-tab
               my/tabspaces-mark
               my/tabspaces-mark-delete
               my/tabspaces-mark-kill
               my/tabspaces-mark-save
               my/tabspaces-unmark-buffer
               my/tabspaces-unmark-all
               my/tabspaces-toggle-marks
               my/tabspaces-execute
               my/tabspaces-filter-modified
               my/tabspaces-filter-file
               my/tabspaces-filter-special
               my/tabspaces-filter-current-tab
               my/tabspaces-filter-clear
               my/tabspaces-sort-by-name
               my/tabspaces-sort-by-modified
               my/tabspaces-sort-by-size
               my/tabspaces-move-buffer-to-tab
               my/tabspaces-mark-by-name-regexp
               my/tabspaces-mark-modified-buffers))
  (put cmd 'completion-predicate #'ignore))

(provide '04_tabspace_bufferlist)
