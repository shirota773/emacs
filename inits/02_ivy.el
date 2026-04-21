(leaf ivy
    :ensure t
    :defvar (ivy-initial-inputs-alist)
    :config
    (leaf smex :ensure t)
    (leaf counsel :ensure t)
    (leaf ivy-rich
      :ensure t
      :config
      (ivy-rich-mode 1)
      )
    (ivy-add-actions
     'my/counsel-buffer-or-recentf
     '(("j" find-file-other-window "other window")))

    (defun sort-windows-by-top-left ()
      "Sort windows by their top-left corner position, closest to (0, 0) first."
      (sort (window-list) (lambda (w1 w2)
                            (let ((edges1 (window-edges w1))
                                  (edges2 (window-edges w2)))
                              (or (< (car edges1) (car edges2))
                                  (and (= (car edges1) (car edges2))
                                       (< (cadr edges1) (cadr edges2))))))))

    (defun activate-sorted-window-by-index (index)
      "Activate the window at INDEX after sorting by the top-left corner."
      ;; (interactive "nEnter window index to activate: ")
      (let* ((sorted-windows (sort-windows-by-top-left))
             (target-window (nth index sorted-windows)))
        (when target-window
          (select-window target-window))))

    (defun my/file-open-in-nth-window (file nth)
    "n”Ô–Ú‚Ìwindow‚Åƒtƒ@ƒCƒ‹‚ðŠJ‚­B‚È‚¢ê‡‚Íì‚é"
    (let* ((sorted-windows (sort-windows-by-top-left))
           (window-count (length sorted-windows)))
      (if (< nth window-count)
          ;; window‚ª‘¶Ý‚·‚éê‡
          (progn
            (activate-sorted-window-by-index nth)
            (find-file file))
        ;; window‚ª‘¶Ý‚µ‚È‚¢ê‡‚Í•ªŠ„‚µ‚Äì‚é
        (progn
          (activate-sorted-window-by-index (1- window-count))
          (dotimes (_ (- (1+ nth) window-count))
            (split-window-right))
          (activate-sorted-window-by-index nth)
          (find-file file)))))

  ;; counsel-recentf‚ÌƒL[ƒ}ƒbƒvÝ’è
  (defun my/counsel-recentf-setup ()
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map ivy-minibuffer-map)

      ;; C-t‚ÅƒfƒBƒŒƒNƒgƒŠ‚ðŠJ‚­
      (define-key map (kbd "C-t")
        (lambda ()
          (interactive)
          (ivy-exit-with-action
           (lambda (file)
             (counsel-find-file (file-name-directory file))))))

      ;; M-1‚Å1”Ô–Ú‚Ìwindow‚ÅŠJ‚­
      (define-key map (kbd "M-1")
        (lambda ()
          (interactive)
          (ivy-exit-with-action
           (lambda (file)
             (my/file-open-in-nth-window file 0)))))

      ;; M-2‚Å2”Ô–Ú‚Ìwindow‚ÅŠJ‚­
      (define-key map (kbd "M-2")
        (lambda ()
          (interactive)
          (ivy-exit-with-action
           (lambda (file)
             (my/file-open-in-nth-window file 1)))))

      ;; M-3‚Å3”Ô–Ú‚Ìwindow‚ÅŠJ‚­
      (define-key map (kbd "M-3")
        (lambda ()
          (interactive)
          (ivy-exit-with-action
           (lambda (file)
             (my/file-open-in-nth-window file 2)))))
      ))

    (defun my/file-open-in-nth-window (file nth)
      "nç•ªç›®ãŒãªã„å ´åˆã¯æœ€å¾Œã®windowã‚’åˆ†å‰²ã™ã‚‹"
      (activate-sorted-window-by-index nth)
      (find-file file))

    (setq ivy-initial-inputs-alist
          '((org-agenda-refile . "^")
            (org-capture-refile . "^")
            (counsel-descbinds-function . "^")
            (counsel-delete-variable . "^")
            (counsel-M-x . "")
            ))

    (defun my/counsel-recentf-dired ()
      "Select a file from `recentf' and open find-file in tis directory"
      (interactive)
      (let* ((file (counsel-recentf))
             (dir (and file (file-name-directory file))))
        (when dir
          (counsel-find-file dir))))
    (defun my/counsel-recentf-setup ()
      (define-key
       recentf-mode-map (kbd "C-t")
       (lambda ()
         (interactive)
         (ivy-exit-with-action
          (lambda (file)
            (counsel-find-file (file-name-directory file))))))
      )
    (add-hook 'recentf-mode-hook #'my/counsel-recentf-setup)

    :custom ((ivy-read-action-function . #'ivy-hydra-read-action)
             (ivy-use-virtual-buffers . t)
             (ivy-wrap . t)
             (ivy-mode . t)
             (counsel-mode . t)
             (ivy-height . 25)
             (counsel-yank-pop-separator . "\n-------\n")
             (ivy-count-format . "(%d/%d) ")
             (ivy-initial-inputs-alist . '((org-agenda-refile . "^")
                                           (org-capture-refile . "^")
                                           (counsel-descbinds-function . "^")
                                           (counsel-delete-variable . "^")
                                           (counsel-M-x . "")
                                           )))

    :bind (("M-x" . counsel-M-x)
           ("M-y" . counsel-yank-pop)
           ;; ("C-;" . my/counsel-buffer-or-recentf)
           ("C-;" . counsel-buffer-or-recentf)
           (:ivy-minibuffer-map
            ("<return>" . ivy-alt-done)
            ("C-m" . ivy-alt-done)
            ("C-z" . ivy-call)
            ("M-r" . ivy-dispatching-done)
            ))
    )

(leaf swiper
  :ensure t
  :bind
  (("C-s" . swiper)
   (isearch-mode-map
    ("C-t" . swiper-from-isearch)))
  )

(defun my/ivy-cacito-with-arg (x)
  (message "Selected item: %s" x))
;; (define-key ivy-minibuffer-map (kbd "C-c c") 'my/ivy-cacito-with-arg)
