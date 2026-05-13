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
;; 2. UI & Frame Utilities
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
;; 3. Editing Utilities
;; =============================================================================

(defun my/dabbrev-expand-or-completing-read ()
  "Perform normal `dabbrev-expand` on the first call.
If executed consecutively, narrow down candidates with Vertico/completing-read."
  (interactive)
  (require 'dabbrev)
  (if (and (eq last-command 'my/dabbrev-expand-or-completing-read)
           (boundp 'dabbrev--last-expansion)
           dabbrev--last-expansion)
      ;; [Second consecutive execution]
      (let* ((abbrev dabbrev--last-abbreviation) ; Original input before expansion (e.g., "aaa")
             (expansion dabbrev--last-expansion) ; First expansion string (e.g., "aaaccc")
             ;; Accurately calculate the start position of the first expansion
             (start-pos (- (point) (length expansion)))
             ;; Set a marker at the start position (including buffer info)
             (abbrev-location (copy-marker start-pos))
             (success nil)
             (selected nil))
        ;; Clear dabbrev internal state (scan position, previous buffer, etc.) for a clean scan
        (dabbrev--reset-global-variables)
        ;; Revert the first expansion back to the original input
        (delete-region start-pos (point))
        (insert abbrev)
        ;; Respect user case-fold settings
        (let* ((ignore-case (if (eq dabbrev-case-fold-search 'case-fold-search)
                                case-fold-search
                              dabbrev-case-fold-search))
               ;; Retrieve expansions from all buffers and remove duplicates
               (candidates (delete-dups (dabbrev--find-all-expansions abbrev ignore-case))))
          (if (null candidates)
              (progn
                (set-marker abbrev-location nil)
                (message "No dabbrev candidates found for \"%s\"" abbrev))
            (unwind-protect
                (progn
                  ;; Launch Vertico (completing-read) to select a candidate
                  (setq selected (completing-read (format "Dabbrev (%s): " abbrev)
                                                   candidates nil t abbrev))
                  (setq success t))
              ;; Cleanup process (always run on both success and cancellation)
              ;; Safely perform buffer operations only on the marker's buffer
              (let ((target-buf (marker-buffer abbrev-location)))
                (when (buffer-live-p target-buf)
                  (with-current-buffer target-buf
                    (if success
                        ;; [On successful selection]
                        (progn
                          (delete-region abbrev-location (point))
                          (insert selected)
                          (setq dabbrev--last-expansion nil))
                      ;; [On cancellation (C-g)] Restore back to the original prefix
                      (delete-region abbrev-location (point))
                      (insert abbrev)
                      (message "Dabbrev selection cancelled. Restored to \"%s\"" abbrev)))))
              ;; Release the marker to help garbage collection
              (set-marker abbrev-location nil)))))
    ;; [First execution] Call standard dabbrev-expand
    (dabbrev-expand nil)))

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
