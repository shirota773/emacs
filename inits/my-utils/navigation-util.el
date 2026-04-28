;;; navigation-util.el --- Navigation utilities -*- lexical-binding: t; -*-

(defvar my/c-r-state 'recentf "State of C-r toggle: 'recentf or 'tabspaces.")

(defun my/minibuffer-exit-run (func &rest args)
  "Delete content, exit minibuffer, and run FUNC with ARGS after 0.05s."
  (run-at-time 0.05 nil (lambda () (apply func args)))
  (delete-minibuffer-contents)
  (ignore-errors (exit-minibuffer)))

(defun my/find-file-in-dir (dir)
  "Start interactive `find-file` with default directory set to DIR."
  (let ((default-directory dir)) (call-interactively 'find-file)))

(defun my/tabspaces-switch-or-recentf ()
  "Toggle between recentf and tabspaces buffer list."
  (interactive)
  (if (not (minibufferp))
      (progn (setq my/c-r-state 'tabspaces) (call-interactively 'my/tabspaces-switch-to-buffer))
    (setq my/c-r-state (if (eq my/c-r-state 'recentf) 'tabspaces 'recentf))
    (my/minibuffer-exit-run
     (if (eq my/c-r-state 'recentf) (if (fboundp 'consult-recentf) #'consult-recentf #'consult-buffer)
       #'my/tabspaces-switch-to-buffer))))

(defun my/vertico-select-directory-from-candidates ()
  "Context-aware directory jump with C-t."
  (interactive)
  (unless (minibufferp) (user-error "Not in minibuffer"))
  (let ((cand (vertico--candidate)) (state my/c-r-state))
    (if (and (eq state 'recentf) cand)
        (let ((dir (file-name-directory (expand-file-name cand))))
          (if dir (my/minibuffer-exit-run #'my/find-file-in-dir dir) (message "No dir")))
      (let* ((files (and (boundp 'recentf-list) recentf-list))
             (dirs (delete-dups (seq-filter #'file-directory-p (mapcar #'file-name-directory files)))))
        (if (null dirs) (message "No dirs found")
          (my/minibuffer-exit-run
           (lambda (ds) (my/find-file-in-dir
                         (if (= (length ds) 1) (car ds) (completing-read "Select directory: " ds nil t))))
           dirs))))))

(provide 'navigation-util)
