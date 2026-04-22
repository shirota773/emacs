(leaf org-journal
  :ensure t
  :defun (org-journal-file-header-func
          org-journal-date-location
          journal-test-created-header-hook)
  :defvar (org-journal-dir
           org-journal-date-format
           org-journal-find-file
           org-journal-file-type
           org-journal-file-header
           org-journal-hide-entries-p
           org-journal-time-prefix
           org-journal-prefix-key)
;;  :hook (org-journal-after-entry-create-hook . )
  :config
  (defun org-journal-file-header-func (time)
    "Custom function to create journal header."
    (concat
     (pcase org-journal-file-type
       (`daily "#+TITLE: Daily Journal\n#+STARTUP: showeverything")
       (`weekly "#+TITLE: Weekly Journal\n#+STARTUP: folded")
       (`monthly "#+TITLE: Monthly Journal\n#+STARTUP: folded\n#+filetags: Project")
       (`yearly "#+TITLE: Yearly Journal\n#+STARTUP: folded"))))

  (defun org-journal-date-location (&optional scheduled-time)
    (let ((scheduled-time (or scheduled-time (org-read-date nil nil nil "Date:"))))
      (setq org-journal--date-location-scheduled-time scheduled-time)
      (org-journal-new-entry t (org-time-string-to-time scheduled-time))
      (unless (eq org-journal-file-type 'daily)
        (org-narrow-to-subtree))
      (goto-char (point-max))))

  (defun journal-test-created-header-hook ()
    (message "called created-hook")
    ;; (goto-char (point-max))
    (search-forward-regexp ":properties:\n.*\n:end:")
    (insert test-txt))

  :custom
  (org-journal-dir . "~/org_icloud/journal/")
  ;; (org-journal-carryover-items)
  (org-journal-date-format . "%a %d-%m-%Y")
  (org-journal-file-format . "journal_%Y%m%d.org")
  (org-journal-find-file . 'find-file)
  ;; (org-extend-today-until . )
  (org-journal-file-type . 'monthly)
  ;; (org-journal-file-header . "")
  (org-journal-file-header . #'org-journal-file-header-func)
  (org-journal-hide-entries-p . t)
  (org-journal-time-prefix . "*** ")
  (org-journal-prefix-key . "C-c j"))

;; entryのテンプレート
(setq test-txt "\n** Good & New\n\n** Habit\n- [ ] HIIT\n- [ ] Meditation\n- [ ] Diary\n\n** Diary\n\n*** 一番良くなかったこと\n\n*** 一番良かったこと\n\n*** 次の日の目標\n\n** Life-log")
(add-hook 'org-journal-after-header-create-hook 'journal-test-created-header-hook)


(setq org-agenda-file-regexp "\\`\\\([^.].*\\.org\\\|[0-9]\\\{8\\\}\\\(\\.gpg\\\)?\\\)\\'")
(add-to-list 'org-agenda-files org-journal-dir)

(setq org-journal-enable-agenda-integration t
      org-icalendar-store-UID t
      org-icalendar-include-todo "all"
      org-icalendar-combined-agenda-file "~/org/.ics/org-journal.ics")

(add-to-list 'org-capture-templates
             '("j" "Journal entry" plain (function org-journal-date-location)
                "** TODO %?\n <%(princ org-journal--date-location-scheduled-time)>\n"
                :jump-to-captured t))
