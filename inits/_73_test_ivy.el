;; 特定のorg fileのヘッドラインとタグを取得
;; ヘッドラインまたはtagからivyインターフェースで絞り込んでそこに飛ぶ

(require 'ivy)
(require 'org)



;; (global-set-key (kbd "C-c C-j") 'select-headline)

(setq cands '(
              ("2023-08-03 headline1 [tag1, tag2]" . 100)
              ("2023-08-02 headline2 [tag3, tag4]" . 200)
              ("2023-08-01 headline3 [tag5, tag6]" . 300)
              ("2023-08-03 headline4 [tag7, tag8]" . 400)
              ("2023-07-31 headline5 [tag9, tag10]" . 500)
              ))

(defun ivy-open-in-other-window ()
  (interactive)
  (ivy-exit-with-action
   (lambda (path)
     (if (= (length (window-list)) 1)
         (progn
           (split-window-horizontally)
           (other-window 1))
       (other-window 1))
     (if (bufferp path)
         (switch-to-buffer path)
       (find-file path)))))

(defun create-file-in-same-dir-from-ivy ()
  (interactive)
  (ivy-exit-with-action
   (lambda (path)
     (let ((dir (if (bufferp path)
                    (with-current-buffer path (file-name-directory (buffer-file-name)))
                  (file-name-directory path)))
           (new-file (read-string "New filename: ")))
       (find-file (concat dir new-file))))))

(define-key ivy-minibuffer-map (kbd "M-c") 'create-file-in-same-dir-from-ivy)
(define-key ivy-minibuffer-map (kbd "M-o") 'ivy-open-in-other-window)


(require 'ivy)
(my-ivy-format-function cands)
(defun my-ivy-format-function (cands)
  "Custom ivy formatter that changes color of certain items."
  (interactive)
  (let ((today (format-time-string "%Y-%m-%d")))
    (ivy--format-function-generic
     (lambda (str)
       (let* ((item (get-text-property 0 'ivy-index str))
              (date (nth 1 item)))
         (if (string= date today)
             (ivy-append-face str 'ivy-highlight-face)
           str)))
     (lambda (str)
       str)
     cands
     "\n")))

(setq ivy-format-function 'my-ivy-format-function)


;; ver2

(defun extract-headlines (level)
  "Extract headlines of a given LEVEL from the current org file."
  (save-excursion
    (goto-char (point-min))
    (let (headlines)
      (while (re-search-forward (format "^\\*\\{%d\\} " level) nil t)
        (let* ((headline (org-get-heading t t t t))
               (tags (org-get-tags))
               (date (org-entry-get (point) "TIMESTAMP_IA"))
               (position (point)))
          (push (list headline date tags position) headlines)))
      (nreverse headlines))))

(defun select-headline-level-one ()
  "Select a level 1 headline using ivy and navigate to its position."
  (interactive)
  (ivy-read "Select a level 1 headline: "
            (mapcar (lambda (x)
                      (cons (format "%s %s %s" (nth 0 x) (nth 1 x) (nth 2 x))
                            (nth 3 x)))
                    (extract-headlines 1))
            :action (lambda (x)
                      (goto-char (cdr x))
                      (select-headline-level-2))))

(defun select-headline-level-2 ()
  "Select a level 2 headline under the chosen level 1 headline using ivy."
  (let ((headlines (extract-headlines 2)))
    (when headlines
      (ivy-read "Select a level 2 headline: "
                (mapcar (lambda (x)
                          (cons (format "%s %s %s" (nth 0 x) (nth 1 x) (nth 2 x))
                                (nth 3 x)))
                        headlines)
                :action (lambda (x)
                          (goto-char (cdr x)))))))

(global-set-key (kbd "C-c C-j") 'select-headline-level-1)

;; ver2.1
(require 'ivy)
(require 'org)

(defun extract-headlines ()
  "Extract headlines from the current org file."
  (save-excursion
    (goto-char (point-min))
    (let (headlines)
      (while (re-search-forward org-complex-heading-regexp nil t)
        (let* ((headline (match-string-no-properties 4))
               (tags (org-get-tags))
               (date (org-entry-get (point) "TIMESTAMP_IA"))
               (level (org-current-level))
               (position (point)))
          (when (= level 2)
          (push (list headline date tags level position) headlines))))
      (nreverse headlines))))

(defun select-headline ()
  "Select a headline using ivy and navigate to its position."
  (interactive)
  (ivy-read "Select a headline: "
            (mapcar (lambda (x)
                      (cons (format "%s %s %s" (nth 0 x) (nth 1 x) (nth 2 x))
                            (list (nth 3 x)))); (nth 4 x))))
                    (extract-headlines))
            :action (lambda (x)
                      (if (= (car x) 1)
                          (select-subheadline (cdr x))
                        (goto-char (cdr x))
                        (crux-move-beginning-of-line nil)
                        (outline-show-subtree)))))

(defun select-subheadline (position)
  "Select a level 2 headline under the chosen level 1 headline using ivy."
  (save-excursion
    (goto-char position)
    (let ((headlines (org-map-entries (lambda () (list (org-get-heading t t t t)
                                                       (org-current-level)
                                                       (point)))
                                      nil 'tree)))
      (ivy-read "Select a level 2 headline: "
                (mapcar (lambda (x)
                          (cons (car x) (nth 2 x)))
                        (seq-filter (lambda (x) (= (nth 1 x) 2)) headlines))
                :action (lambda (x)
                          (goto-char x)
                          )))))

(global-set-key (kbd "C-c C-j") 'select-headline)

(defun select-headline ()
  "Select a headline using ivy and navigate to its position."
  (interactive)
  (ivy-read "Select a headline: "
            (mapcar (lambda (x)
                      (cons (format "%s %s %s" (nth 0 x) (nth 1 x) (nth 2 x))
                            (list (nth 3 x) (nth 4 x))))
                    (extract-headlines))
            :action (lambda (x)
                      (if (= (nth 1 x) 1)
                          (select-subheadline (nth 1 x))
                      (message (int-to-string (nth 2 x)))
                      (goto-char (nth 2 x))
                      (crux-move-beginning-of-line nil)
                      (outline-show-subtree)))))



(require 'cl-lib)

(defun collect-all-tags ()
  "Collects all tags from the headlines in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((all-tags '()))
      (while (re-search-forward org-complex-heading-regexp nil t)
        (let* ((tags (org-get-tags)))
          (dolist (tag tags)
            (add-to-list 'all-tags tag))))
      all-tags)))

(defun ivy-add-tags-to-headline ()
  "Select tags using ivy and add them to the current headline."
  (interactive)
  (let* ((tags (collect-all-tags))
         (selected-tags (ivy-read "Select tags: " tags :multi-action #'identity)))
    (save-excursion
      (org-back-to-heading t)
      (org-set-tags (cl-union (org-get-tags) selected-tags)))))


(require 'cl-lib)

