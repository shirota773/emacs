;; -*- lexical-binding: t; -*-
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
    (defun my/ivy-find-file-in-candidate-directory ()
      "Open `counsel-find-file' in the directory of the current Ivy candidate."
      (interactive)
      (let* ((x (ivy-state-current ivy-last))
             (path (cond ((consp x) (cdr x)) ; virtual buffer (recentf)
                         ((and (stringp x) (get-buffer x)) (buffer-file-name (get-buffer x)))
                         ((stringp x) x) ; likely a file path
                         (t nil))))
        (if (and path (stringp path))
            (let ((dir (file-name-directory path)))
              (if (and dir (file-directory-p dir))
                  (ivy-exit-with-action
                   (lambda (_) (counsel-find-file dir)))
                (message "Directory does not exist: %s" dir)))
          (message "No file path for current candidate"))))

    (ivy-add-actions
     'counsel-buffer-or-recentf
     '(("j" find-file-other-window "other window")
       ("d" (lambda (x) (counsel-find-file (file-name-directory (if (consp x) (cdr x) x)))) "find file in directory")))

    (ivy-add-actions
     'counsel-recentf
     '(("d" (lambda (x) (counsel-find-file (file-name-directory x))) "find file in directory")))

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
    "n�Ԗڂ�window�Ńt�@�C�����J���B�Ȃ��ꍇ�͍��"
    (let* ((sorted-windows (sort-windows-by-top-left))
           (window-count (length sorted-windows)))
      (if (< nth window-count)
          ;; window�����݂���ꍇ
          (progn
            (activate-sorted-window-by-index nth)
            (find-file file))
        ;; window�����݂��Ȃ��ꍇ�͕������č��
        (progn
          (activate-sorted-window-by-index (1- window-count))
          (dotimes (_ (- (1+ nth) window-count))
            (split-window-right))
          (activate-sorted-window-by-index nth)
          (find-file file)))))


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
           ("C-;" . counsel-buffer-or-recentf)
           (:ivy-minibuffer-map
            ("<return>" . ivy-alt-done)
            ("C-m" . ivy-alt-done)
            ("C-z" . ivy-call)
            ("C-r" . my/tabspaces-switch-or-recentf)
            ("C-t" . my/ivy-find-file-in-candidate-directory)
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
