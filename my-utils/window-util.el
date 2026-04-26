;;; window-util.el --- Window management utilities -*- lexical-binding: t; -*-

(defun sort-windows-by-top-left ()
  "Return a list of windows, ordered from top-left to bottom-right."
  (let ((windows (window-list))
        (compare-fn (lambda (w1 w2)
                      (let ((edge1 (window-edges w1))
                            (edge2 (window-edges w2)))
                        (or (< (car edge1) (car edge2))
                            (and (= (car edge1) (car edge2))
                                 (< (cadr edge1) (cadr edge2))))))))
    (sort windows compare-fn)))

(defun activate-sorted-window-by-index (index)
  "Select the sorted window at INDEX."
  (let* ((sorted-windows (sort-windows-by-top-left))
         (target-window (nth index sorted-windows)))
    (when target-window (select-window target-window))))

(defun my/file-open-in-nth-window (file nth)
  "Open FILE in the NTH window (sorted by position)."
  (let* ((sorted-windows (sort-windows-by-top-left))
         (window-count (length sorted-windows)))
    (if (< nth window-count)
        (progn (activate-sorted-window-by-index nth) (find-file file))
      (progn (activate-sorted-window-by-index (1- window-count))
             (dotimes (_ (- (1+ nth) window-count)) (split-window-right))
             (activate-sorted-window-by-index nth) (find-file file)))))

(defun window-resizer ()
  "Control window size and position interactively."
  (interactive)
  (let ((window-obj (selected-window))
        (current-width (window-width))
        (current-height (window-height))
        (dx (if (= (nth 0 (window-edges)) 0) 1
              -1))
        (dy (if (= (nth 1 (window-edges)) 0) 1
              -1))
        c)
    (catch 'end-flag
      (while t
        (message "size[%dx%d]" (window-width) (window-height))
        (setq c (read-char))
        (cond ((= c ?l) (enlarge-window-horizontally dx))
              ((= c ?h) (shrink-window-horizontally dx))
              ((= c ?j) (enlarge-window dy))
              ((= c ?k) (shrink-window dy))
              (t (message "Quit") (throw 'end-flag t)))))))

(provide 'window-util)
