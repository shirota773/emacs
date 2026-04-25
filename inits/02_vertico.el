;; -*- lexical-binding: t; -*-

;; Unified Vertico Configuration & Navigation Logic
;; Ported from Ivy configurations with modern Vertico/Consult alternatives.

;; =============================================================================
;; 1. State Variables
;; =============================================================================

(defvar my/c-r-state 'recentf
  "State of C-r toggle: either 'recentf or 'tabspaces.")

;; =============================================================================
;; 2. Core Navigation Functions
;; =============================================================================

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

;; =============================================================================
;; 3. Keybindings
;; =============================================================================

;; Global Bindings
(global-set-key (kbd "C-r") #'my/tabspaces-switch-or-recentf)
(global-set-key (kbd "C-s") 'consult-line)
(global-set-key (kbd "M-s g") 'consult-grep)
(global-set-key (kbd "M-s r") 'consult-ripgrep)
(global-set-key (kbd "M-x") 'execute-extended-command)
(global-set-key (kbd "M-o") 'embark-act)

;; Vertico-map specific bindings
(with-eval-after-load 'vertico
  (require 'vertico-directory)
  (define-key vertico-map (kbd "C-r") #'my/tabspaces-switch-or-recentf)
  (define-key vertico-map (kbd "C-t") #'my/vertico-select-directory-from-candidates)
  (define-key vertico-map (kbd "RET") #'vertico-directory-enter)
  (define-key vertico-map (kbd "DEL") #'vertico-directory-delete-char)
  (define-key vertico-map (kbd "M-DEL") #'vertico-directory-delete-word))

;; Embark configuration
(with-eval-after-load 'embark
  (define-key embark-file-map (kbd "d") (lambda (f) (interactive "f") (find-file (file-name-directory f))))
  (define-key embark-buffer-map (kbd "d") (lambda (b) (interactive "b") 
                                           (let ((f (buffer-file-name (get-buffer b))))
                                             (if f (find-file (file-name-directory f)) (message "No file"))))))

;; =============================================================================
;; 4. Utility Functions
;; =============================================================================

(defun sort-windows-by-top-left ()
  (sort (window-list) (lambda (w1 w2)
                        (let ((edges1 (window-edges w1)) (edges2 (window-edges w2)))
                          (or (< (car edges1) (car edges2))
                              (and (= (car edges1) (car edges2)) (< (cadr edges1) (cadr edges2))))))))

(defun activate-sorted-window-by-index (index)
  (let* ((sorted-windows (sort-windows-by-top-left)) (target-window (nth index sorted-windows)))
    (when target-window (select-window target-window))))

(defun my/file-open-in-nth-window (file nth)
  (let* ((sorted-windows (sort-windows-by-top-left)) (window-count (length sorted-windows)))
    (if (< nth window-count)
        (progn (activate-sorted-window-by-index nth) (find-file file))
      (progn (activate-sorted-window-by-index (1- window-count))
             (dotimes (_ (- (1+ nth) window-count)) (split-window-right))
             (activate-sorted-window-by-index nth) (find-file file)))))
