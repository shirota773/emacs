;;; navigation-util.el --- Navigation and Minibuffer utilities -*- lexical-binding: t; -*-

(defvar my/c-r-state 'recentf
  "State of C-r toggle: either 'recentf or 'tabspaces.")

(defun my/tabspaces-switch-or-recentf ()
  "Toggle between recentf and tabspaces buffer with C-r.
Inside minibuffer: switch between commands.
Outside minibuffer: Trigger tabspaces switch."
  (interactive)
  (if (not (minibufferp))
      (progn
        (setq my/c-r-state 'tabspaces)
        (if (commandp 'my/tabspaces-switch-to-buffer)
            (call-interactively 'my/tabspaces-switch-to-buffer)
          (my/tabspaces-switch-to-buffer)))
    ;; Inside minibuffer: Exit with empty input and trigger next command via timer
    (setq my/c-r-state (if (eq my/c-r-state 'recentf) 'tabspaces 'recentf))
    (let ((cmd (if (eq my/c-r-state 'recentf)
                   (if (fboundp 'consult-recentf) #'consult-recentf #'consult-buffer)
                 #'my/tabspaces-switch-to-buffer)))
      (run-at-time 0.05 nil 
                   (lambda (c) 
                     (if (commandp c) (call-interactively c) (funcall c)))
                   cmd))
    (delete-minibuffer-contents)
    (condition-case nil (exit-minibuffer) (error nil))))

(defun my/vertico-select-directory-from-candidates ()
  "Extract unique directories from current candidates and select one."
  (interactive)
  (if (not (minibufferp))
      (message "Not in minibuffer")
    (let* ((content (minibuffer-contents-no-properties))
           (table minibuffer-completion-table)
           (pred minibuffer-completion-predicate)
           (all-cands (all-completions content table pred))
           (dirs (delete-dups
                  (seq-filter (lambda (d) (and (stringp d) (file-directory-p d)))
                              (mapcar (lambda (x)
                                        (let ((p (if (consp x) (car x) x)))
                                          (if (and (stringp p) (not (file-directory-p p)))
                                              (file-name-directory p)
                                            p)))
                                      all-cands))))
           (len (length dirs)))
      (if (zerop len)
          (message "No directories found")
        (let ((action (lambda (d-list d-len)
                         (let ((target (if (= d-len 1) (car d-list) (completing-read "Select directory: " d-list nil t))))
                           (find-file target)))))
          (run-at-time 0.05 nil action dirs len)
          (delete-minibuffer-contents)
          (condition-case nil (exit-minibuffer) (error nil)))))))

(provide 'navigation-util)
