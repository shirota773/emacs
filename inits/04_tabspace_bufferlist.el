;; ========================================
;; Tabspace buffer list (ibuffer-like)
;; ========================================

(require 'tabspaces)

(defvar-local my/tabspaces-buffer-marks nil
  "Alist of (buffer . mark-type) for marked buffers.
Mark types: 'delete 'save 'mark 'kill")

(defvar-local my/tabspaces-filter-mode 'file
  "Current filter mode: nil (all), 'modified, 'file (default, no special buffers), or 'special.")

(defvar-local my/tabspaces-sort-mode 'name
  "Current sort mode: 'name, 'modified, or 'size.")

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
        (current-line (line-number-at-pos))
        (i 1))
    (erase-buffer)
    ;; Header - with dimmed text
    (insert (propertize "Tabspaces and Buffers" 'face 'bold))
    (when my/tabspaces-filter-mode
      (insert (format " [Filter: %s]" my/tabspaces-filter-mode)))
    (insert (format " [Sort: %s]\n" my/tabspaces-sort-mode))
    (insert (propertize (make-string 80 ?-) 'face '(:foreground "gray50")) "\n")
    (insert (propertize "Mark: " 'face '(:foreground "gray50"))
            (propertize "[d]elete [k]ill [s]ave [m]ark [u]nmark [U]nmark-all [t]oggle [x]execute\n" 'face '(:foreground "gray50")))
    (insert (propertize "Filter: " 'face '(:foreground "gray50"))
            (propertize "[/ m]odified [/ f]ile [/ s]pecial [/ /]clear\n" 'face '(:foreground "gray50")))
    (insert (propertize "Sort: " 'face '(:foreground "gray50"))
            (propertize "[o n]ame [o m]odified [o s]ize  " 'face '(:foreground "gray50")))
    (insert (propertize "Other: " 'face '(:foreground "gray50"))
            (propertize "[g]refresh [RET]visit [% n]ame-regexp [* m]ark-modified\n\n" 'face '(:foreground "gray50")))

    ;; Iterate through all tabs
    (dolist (tab (tab-bar-tabs))
      (let* ((tab-name (alist-get 'name tab))
             (current (eq tab (tab-bar--current-tab)))
             (all-buffers (seq-filter #'buffer-live-p (or (alist-get 'wc-bl tab) '())))
             (filtered-buffers (seq-filter #'my/tabspaces--should-show-buffer-p all-buffers))
             (sorted-buffers (my/tabspaces--sort-buffers filtered-buffers)))
        ;; Tab header
        (insert (propertize
                 (format "[%d] %s%s (%d/%d buffers)\n"
                         i tab-name
                         (if current " <== current" "")
                         (length filtered-buffers)
                         (length all-buffers))
                 'face '(:foreground "cyan" :weight bold)
                 'tab-name tab-name))

        ;; Buffer list
        (if sorted-buffers
            (dolist (b sorted-buffers)
              (when (buffer-live-p b)
                (let* ((buf-name (buffer-name b))
                       (mark-type (alist-get b my/tabspaces-buffer-marks))
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
                           (format "  %s %s %-40s %6s%s%s\n"
                                   mark-char
                                   (if modified "*" " ")
                                   buf-name
                                   (file-size-human-readable size)
                                   (if file (format " (%s)" (abbreviate-file-name file)) "")
                                   (or tabs-info ""))
                           'face face
                           'buffer b
                           'tab-name tab-name)))))
          (insert "   (no buffers)\n"))
        (insert "\n")
        (setq i (1+ i))))
    ;; Move cursor to first buffer line (skip header and tab name)
    (goto-char (point-min))
    (when (re-search-forward "^  [DKS\\* ]" nil t)
      (beginning-of-line))))

(defun my/tabspaces-buffer-at-point ()
  "Return the buffer object at point, or nil."
  (get-text-property (point) 'buffer))

(defun my/tabspaces-mark-buffer (mark-type)
  "Mark the buffer at point with MARK-TYPE."
  (let ((buf (my/tabspaces-buffer-at-point)))
    (when buf
      (setf (alist-get buf my/tabspaces-buffer-marks) mark-type)
      (my/tabspaces-refresh-buffer-list)
      (forward-line 1))))

(defun my/tabspaces-unmark-buffer ()
  "Unmark the buffer at point."
  (interactive)
  (let ((buf (my/tabspaces-buffer-at-point)))
    (when buf
      (setq my/tabspaces-buffer-marks
            (assq-delete-all buf my/tabspaces-buffer-marks))
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
      (let ((buf (car entry))
            (mark-type (cdr entry)))
        (when (buffer-live-p buf)
          (cond
           ((eq mark-type 'delete)
            (push buf delete-list))
           ((eq mark-type 'kill)
            (push buf kill-list))
           ((eq mark-type 'save)
            (push buf save-list))))))

    ;; Execute operations
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

    ;; Clear marks and refresh
    (setq my/tabspaces-buffer-marks nil)
    (my/tabspaces-refresh-buffer-list)))

(defun my/tabspaces-visit-buffer ()
  "Visit the buffer at point."
  (interactive)
  (let ((buf (my/tabspaces-buffer-at-point))
        (tab-name (get-text-property (point) 'tab-name)))
    (when (and buf tab-name)
      (tab-bar-switch-to-tab tab-name)
      (switch-to-buffer buf))))

(defun my/tabspaces-unmark-all ()
  "Unmark all buffers."
  (interactive)
  (setq my/tabspaces-buffer-marks nil)
  (my/tabspaces-refresh-buffer-list))

;; Filter commands
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

;; Sort commands
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

;; Bulk operations
(defun my/tabspaces-toggle-marks ()
  "Toggle marks on all buffers."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((buf (my/tabspaces-buffer-at-point)))
        (when buf
          (if (alist-get buf my/tabspaces-buffer-marks)
              (setq my/tabspaces-buffer-marks
                    (assq-delete-all buf my/tabspaces-buffer-marks))
            (setf (alist-get buf my/tabspaces-buffer-marks) 'mark))))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-by-name-regexp (regexp)
  "Mark all buffers whose names match REGEXP."
  (interactive "sMark buffers matching regexp: ")
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((buf (my/tabspaces-buffer-at-point)))
        (when (and buf (string-match-p regexp (buffer-name buf)))
          (setf (alist-get buf my/tabspaces-buffer-marks) 'mark)))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

(defun my/tabspaces-mark-modified-buffers ()
  "Mark all modified buffers."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((buf (my/tabspaces-buffer-at-point)))
        (when (and buf (buffer-modified-p buf))
          (setf (alist-get buf my/tabspaces-buffer-marks) 'mark)))
      (forward-line 1)))
  (my/tabspaces-refresh-buffer-list))

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
    (define-key map (kbd "/ /") #'my/tabspaces-filter-clear)
    ;; Sort commands
    (define-key map (kbd "o n") #'my/tabspaces-sort-by-name)
    (define-key map (kbd "o m") #'my/tabspaces-sort-by-modified)
    (define-key map (kbd "o s") #'my/tabspaces-sort-by-size)
    ;; Bulk operations
    (define-key map (kbd "% n") #'my/tabspaces-mark-by-name-regexp)
    (define-key map (kbd "* m") #'my/tabspaces-mark-modified-buffers)
    ;; Other commands
    (define-key map (kbd "g") #'my/tabspaces-refresh-buffer-list)
    (define-key map (kbd "RET") #'my/tabspaces-visit-buffer)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap for `my/tabspaces-buffer-list-mode'.")

;; Set parent keymap before defining the derived mode
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
  / / - Clear all filters

Sort commands:
  o n - Sort by name
  o m - Sort by modification time
  o s - Sort by size

Bulk operations:
  % n - Mark buffers matching regexp
  * m - Mark all modified buffers

Other commands:
  RET - Visit buffer at point
  g   - Refresh the buffer list
  q   - Quit window
  ?   - Show help

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
  (setq-local my/tabspaces-sort-mode 'name))

(provide '04_tabspace_bufferlist)
