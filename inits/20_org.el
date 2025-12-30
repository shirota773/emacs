
(setq org-agenda-custom-commands
      '(("h" "Daily habits"
         ((agenda ""))
         ((org-agenda-show-log t)
          (org-agenda-ndays 7)
          (org-agenda-log-mode-items '(state))
          (org-agenda-skip-function '(org-agenda-skip-entry-if 'notregexp ":daily:"))))
        ;; other commands here
        ))

(leaf *my/org
  :config
  ;; (add-hook 'org-mode-hook
  ;;           '((set-fill-column 64)
  ;;             (display-fill-column-indicator-mode 1)))
  ;; (remove-hook 'org-mode-hook
  ;;           '((set-fill-column 64)
  ;;             (display-fill-column-indicator-mode 1)))
  (defun my/extract-headlines ()
    "Extract headlines from the current org file."
    (interactive)
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
              (push (list (concat headline ":" (mapconcat 'identity tags ":")) date tags position) headlines))))
        (nreverse headlines))))


  (defun my/select-headline ()
    "Select a headline using ivy and navigate to its position."
    (interactive)
    (let ((ivy-re-builders-alist '((t . ivy--regex-ignore-order))))
      (ivy-read "Select a headline: "
                (mapcar (lambda (x)
                          (cons (format "%s" (nth 0 x))
                                (nth 3 x)))
                        (my/extract-headlines))
                :action (lambda (x)
                          (goto-char (cdr x))
                          (crux-move-beginning-of-line nil)
                          (outline-show-subtree)))))

  (defun my/collect-all-tags ()
    "Collects all tags from the headlines in the current buffer."
    (save-excursion
      (goto-char (point-min))
      (let ((all-tags '()))
        (while (re-search-forward org-complex-heading-regexp nil t)
          (let* ((tags (org-get-tags)))
            (dolist (tag tags)
              (add-to-list 'all-tags tag))))
        all-tags)))

  (defun my/ivy-add-tags-to-headline ()
    "Select tags using ivy and add them to the current headline."
    (interactive)
    (let* ((tags (my/collect-all-tags))
           (selected-tags (ivy-read "Select tags: " tags :multi-action 'identity)))
      (org-back-to-heading t)
      (org-set-tags (append (org-get-tags nil t) (split-string selected-tags)))))
  (defface ivy-multiselect
    '((t (:background "sea green")))
    "Face used by Ivy for highlighting the selected items.")

  (defun my/org-screenshot ()
    "Save a clipboard's screenshot into a unique-named file
   in a specified directory and insert a link to this file."
    (interactive)
    (let* ((temporary-file (expand-file-name "tmp.png" org-directory))
           (default-directory (concat org-directory "/images"))
           (filename "")
           (file-exists-p t))
      ;; クリップボードの画像を一時的なファイルに保存する
      (if (not (eq 0 (call-process "pngpaste" nil nil nil temporary-file)))
          (message "Error: Cannnot save image-file from clipboard.")
        ;; 一時ファイルの保存が成功した場合、ユーザーに新しいファイル名を尋ね、存在するファイル名が指定されるまで繰り返す
        (while file-exists-p
          (setq filename (read-string
                          (concat "image-file name [" org-directory "/images]/ {.png}: ") filename))
          (setq file-exists-p (file-exists-p (expand-file-name (concat filename ".png") default-directory)))
          (when file-exists-p
            (message "Error: Aleady exist file.")
            (sit-for 1)))
        (rename-file temporary-file (expand-file-name filename default-directory) t)
        (insert (concat "[[file:" (expand-file-name filename default-directory) "]]"))
        (org-display-inline-images))))
  (global-set-key (kbd "C-c C-x C-^") 'my/org-screenshot)


  ;; insert template
  (defvar my/org-insert-template-list
    '("#+startup: "
      "#+attr_html:"
      "#+caption: "))

  (defun my/org-insert-template ()
    (interactive)
    (let ((template (ivy-read "Choose template: " my/org-insert-template-list)))
      (insert template)))


  (defvar my/org-memo-file "~/org_icloud/memo.org")
  (defun my/org-memo-open ()
    (interactive)
    (find-file my/org-memo-file)
    (when (org-buffer-narrowed-p)
      (org-toggle-narrow-to-subtree))
    (beginning-of-buffer)
    (search-forward "* memo")
    (org-content 2)
    )

  (defun my/org-memo-new-entry ()
    (interactive)
    ;; (beginning-of-line)
    ;; (search-forward "* memo")
    (my/org-memo-open)
    (crux-smart-open-line nil)
    (insert "** ")
    (insert (format-time-string my/org-time-stamp-formats (current-time)))
    ;; (crux-smart-open-line nil)
    (open-line 1)

    ;; (backward-char)
    (org-toggle-narrow-to-subtree)
    )

  (defun my/org-meta-return ()
    (interactive)
    (crux-smart-open-line nil)
    (org-meta-return))

  (defvar my/org-time-stamp-formats "[%Y-%m-%d %a] ")
  ;; time stampの挿入
  (defun my/org-insert-current-date-time ()
    (interactive)
    (insert (format-time-string my/org-time-stamp-formats (current-time))))
  (setq org-time-stamp-formats '("[%Y-%m-%d %a]" . "[%Y-%m-%d %a %H:%M]"))

  ;; タイムスタンプ

  (defvar current-date-time-format "[%Y-%B %d %H:%M]"
    "Format of date to insert with `insert-current-date-time' func
See help of `format-time-string' for possible replacements")
  (setq current-date-time-format "%Y %m %d %H:%M")
  ;; %a 曜日, %b 月, %m 月(数字のみ), %H 24時間, %I 12時間, %M 分, %S 秒, %z jstタイムゾーン,

  (defvar current-time-format "%a %H:%M:%S"
    "Format of date to insert with `insert-current-time' func.
Note the weekly scope of the command's precision.")

  (defun insert-current-date-time ()
    "insert the current date and time into current buffer.
Uses `current-date-time-format' for the formatting the date/time."
    (interactive)
                                        ;       (insert "==========\n")
                                        ;       (insert (let () (comment-start)))
    (insert (format-time-string current-date-time-format (current-time)))
    )
  (defun insert-current-time ()
    "insert the current time (1-week scope) into the current buffer."
    (interactive)
    (insert (format-time-string current-time-format (current-time)))
    (insert "\n")
    )

  (defun my/get-org-startup-level ()
    "Set initial headline visibility based on `#+STARTUP_LEVEL:' setting.
  Default level is 1 if the setting is not specified."
    (interactive)
    (let* ((startup-levels (org-collect-keywords '("STARTUP_LEVEL")))
           (level-keyword (cadr (assoc "STARTUP_LEVEL" startup-levels)))
           (level (if level-keyword
                      (string-to-number level-keyword)
                    1)))
      (outline-hide-sublevels level))
    )

  (defvar my/org-startup-level 2
    "Default starting level for cycling visibility in Org mode.")

  (defun my/org-cycle ()
    "Cycle visibility in an entry, taking startup level into account.
Cycling starts at `my/org-startup-level'."
    (interactive)
    (let* ((startup-levels (org-collect-keywords '("STARTUP_LEVEL")))
           (level-keyword (cadr (assoc "STARTUP_LEVEL" startup-levels)))
           (level (if level-keyword
                      (string-to-number level-keyword)
                    my/org-startup-level)))
      (if (eq last-command this-command)
          (org-cycle)
        (outline-hide-sublevels level))))

  (defun my/org-global-cycle (&optional arg)
    "Cycle the state of the outline tree globally, taking startup level into account.
Cycling starts at `my/org-startup-level'."
    (interactive "P")
    (let* ((startup-levels (org-collect-keywords '("STARTUP_LEVEL")))
           (level-keyword (cadr (assoc "STARTUP_LEVEL" startup-levels)))
           (level (if level-keyword
                      (string-to-number level-keyword)
                    my/org-startup-level)))
      (if (eq last-command this-command)
          (org-global-cycle arg)
        (progn (org-overview)
               (outline-hide-sublevels level)))))

  ;; )
  ;; (add-hook 'org-mode-hook #'my/org-startup-level)
  (remove-hook 'org-mode-hook #'my/org-startup-level)

  (defun ladicle/task-clocked-time ()
    "Return a string with the clocked time and effort, if any"
    (interactive)
    (let* ((clocked-time (org-clock-get-clocked-time))
           (h (truncate clocked-time 60))
           (m (mod clocked-time 60))
           (work-done-str (format "%d:%02d" h m)))
      (if org-clock-effort
          (let* ((effort-in-minutes
                  (org-duration-to-minutes org-clock-effort))
                 (effort-h (truncate effort-in-minutes 60))
                 (effort-m (truncate (mod effort-in-minutes 60)))
                 (effort-str (format "%d:%02d" effort-h effort-m)))
            (format "🪶%s/%s" work-done-str effort-str))
        (format "☕️%s" work-done-str))))

  (defvar my/org-structure-template-alist
    '(("a" . "export ascii")
      ("c" . "center")
      ("C" . "comment")
      ("e" . "example")
      ("E" . "export")
      ("h" . "export html")
      ("l" . "export latex")
      ("q" . "quote")
      ("s" . "src")
      ("v" . "verse"))
    "Alist of structure templates.
Each element is (KEY . DESCRIPTION). KEY is the prompt string and
DESCRIPTION is the description shown in the prompt.")

  (defvar my/org-structure-template-text-alist
    '(("a" . "#+BEGIN_EXPORT ascii\n?\n#+END_EXPORT")
      ("c" . "#+BEGIN_CENTER\n?\n#+END_CENTER")
      ("C" . "#+BEGIN_COMMENT\n?\n#+END_COMMENT")
      ("e" . "#+BEGIN_EXAMPLE\n?\n#+END_EXAMPLE")
      ("E" . "#+BEGIN_EXPORT\n?\n#+END_EXPORT")
      ("h" . "#+BEGIN_EXPORT html\n?\n#+END_EXPORT")
      ("l" . "#+BEGIN_EXPORT latex\n?\n#+END_EXPORT")
      ("q" . "#+BEGIN_QUOTE\n?\n#+END_QUOTE")
      ("s" . "#+BEGIN_SRC\n?\n#+END_SRC")
      ("v" . "#+BEGIN_VERSE\n?\n#+END_VERSE"))
    "Alist of structure templates.
Each element is (KEY . TEXT). KEY is the prompt string and
TEXT is the template inserted. The character `?' in
TEXT is the point."
    )

  (defun my/org-insert-structure-template ()
    "Prompt for a structure template to insert."
    (interactive)
    (let* ((formatted-alist (mapcar (lambda (x)
                                      (format "%s) %s" (car x) (cdr x)))
                                    my/org-structure-template-alist))
           (template-text (mapconcat 'identity formatted-alist "\n"))
           (choice (completing-read (concat template-text "\nSelect key: ") formatted-alist nil t))
           (template-key (substring choice 0 1))
           ;; 選択されたテンプレートに対応するテキストを取得します。
           (template-text (cdr (assoc template-key my/org-structure-template-text-alist)))
           ;; "?"の位置を取得します。
           (pos (string-match "\\?" template-text)))
      ;; "?"を空文字に置き換えます。
      (setq template-text (replace-match "" t t template-text))
      ;; テンプレートを挿入します。
      (insert template-text)
      ;; カーソルを挿入位置に移動します。
      (if pos (backward-char (- (length template-text) pos)))))

  (leaf org
    :after org
    :custom
    ;; '(org-completion-use-ido t)
    ;;  '(org-export-author-info nil)
    ;;  '(org-export-backends '(ascii html latex odt))
    ;;  '(org-export-creator-info nil)
    ;;  '(org-export-html-coding-system 'utf-8 t)
    ;;  '(org-export-latex-classes "jsarticle" t)
    ;;  '(org-export-latex-date-format "%Y-%m-%d" t)
    ;;  '(org-hide-leading-stars t)
    ;;  '(org-latex-default-class "jsarticle" t)
    ;;  '(org-latex-pdf-process nil t)
    ;;  '(org-log-done 'time)
    ;;  '(org-startup-folded 'content)
    ;;  '(org-startup-truncated t)

    :config
    (setq org-image-actual-width '(330))
    (setq org-startup-with-inline-images t)

    (custom-set-faces
     '(org-level-1 ((t (:foreground "#ffa7d9" :weight normal :height 1.0))))
     ;; '(org-level-2 ((t (:foreground "springGreen" :weight normal :height 1.0))))
     '(org-level-3 ((t (:foreground "#ffa7d9" :weight normal :height 1.0))))
     '(org-level-4 ((t (:foreground "#d4b8fb" :weight normal :height 1.0))))
     ;; '(org-level-5 ((t (:foreground "#7070cc" :weight normal :height 1.0))))
     )

    ;; (smartrep-define-key org-mode-map "C-c"
    ;;   ;; :package org-mode
    ;;   '(("C-n" . org-next-visible-heading)
    ;;     ("C-p" . org-previous-isible-heading)
    ;;     ("C-u" . outline-up-heading)
    ;;     ("C-f" . org-forward-heading-same-level)
    ;;     ("C-b" . org-backward-heading-same-level)))

    :bind
    ((org-mode-map
      ("C-c n" . org-toggle-narrow-to-subtree)
      ("C-c s" . org-show-subtree)
      ("C-M-<return>" . org-insert-heading)
      ("S-<return>" . org-insert-heading-respect-content)
      ("M-k" . outline-previous-visible-heading)
      ("M-j" . outline-next-visible-heading)
      ("M-p" . org-backward-heading-same-level)
      ("M-n" . org-forward-heading-same-level)
      ("M-h" . org-metaleft)
      ("M-l" . org-metaright)
      ("C-c C-d" . org-deadline)
      ("C-c t" . my/org-insert-current-date-time)
      ("S-<tab>" . my/org-cycle)
      ("C-c C-," . my/org-insert-structure-template)
      ("C-c C-q" . my/ivy-add-tags-to-headline)
      ;; keybind candidate
      ;; org-metadaow/metaup
      )
     )
    )

  (leaf org-pomodoro
    :after org
    :custom
    (org-pomodoro-ask-upon-killing . t)
    (org-pomodoro-format . "%s")
    (org-pomodoro-short-break-format . "%s")
    (org-pomodoro-long-break-format  . "%s")
    :custom-face
    ;; (org-pomodoro-mode-line ((t (:foreground "#ff5555"))))
    ;; (org-pomodoro-mode-line-break   ((t (:foreground "#50fa7b"))))
    :hook
    (org-pomodoro-started . (lambda () (notifications-notify
                                        :title "org-pomodoro"
                                        :body "Let's focus for 25 minutes!"
                                        :app-icon "~/.emacs.d/img/001-food-and-restaurant.png")))
    (org-pomodoro-finished . (lambda () (notifications-notify
                                         :title "org-pomodoro"
                                         :body "Well done! Take a break."
                                         :app-icon "~/.emacs.d/img/004-beer.png")))
    :config
    :bind ((org-agenda-mode-map
            ("p" . org-pomodoro))))

  (leaf org-modern
    :after org
    :custom
    (org-modern-star . '("◆" "♠" "♥" "♣" "♤" "♡" "♧"))
    ;; 文字候補 ➤ ➢ ➣ 〉》»  ♦ ♥ ♠ ♣§❖•◦ ▻▸▹✧⦒⦊⟫aa
    (org-modern-list . '((43 . "›") (45 . "-") (42 . "◦")))
    (org-modern-progress . '("☑︎"))
    ;; (global-org-modern-mode . 1)
    ;; (org-modern-mode . 1)
    )

  )








(setq org-html-link-up t)
(setq org-modern-hide-stars nil)
;; (setq org-indent-boundary-char 32)




(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))


(set-face-background 'fringe (face-attribute 'default :background))

;; (setq org-blank-before-new-entry '((heading . nil) (plain-list-item . auto)))
(setq org-blank-before-new-entry '((heading . auto) (plain-list-item . nil)))
;; (setq org-blank-before-new-entry
;;       nil)
(setq-default tab-width 4 indent-tabs-mode nil)
(setq
 ;; Edit settings
 org-auto-align-tags nil
 org-tags-column 0
 org-catch-invisible-edits 'show-and-error
 org-special-ctrl-a/e t
 org-insert-heading-respect-content t

 ;; Org styling, hide markup etc.
 org-hide-emphasis-markers t
 org-pretty-entities t
 org-ellipsis "…"

 ;; Agenda styling
 org-agenda-tags-column 0
 org-agenda-block-separator ?─
 org-agenda-time-grid
 '((daily today require-timed)
   (800 1000 1200 1400 1600 1800 2000)
   " ┄┄┄┄┄ " "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")
 org-agenda-current-time-string
 "⭠ now ─────────────────────────────────────────")
;; 曜日を英語表記
(setq system-time-locale "C")
;; アスタリスクはかくす
(setq org-hide-leading-stars t)
;; 初期状態は見出しを表示
(setq org-startup-folded 'content)
(setq org-startup-indented t)
(setq org-indent-indentation-per-level 2)
;; 折り返さない
(setq org-startup-truncated t)

(setq org-directory "~/org_icloud")
(setq org-memo "~/org_icloud/memo.org")
(setq org-todo "~/org_icloud/todo.org")

(defun org-caputure-set-target ()
  (setq org-capture-target-diary (today-time-string)
        org-capture-target-journal "fuga")
  )
(defun today-time-string ()
  (format-time-string "%Y-%m-%d %a" (current-time)))

;; org-captureで2種類のメモを扱うようにする
(setq org-capture-templates
      '(("m" "✍️ Memo" entry (file+headline "~/org_icloud/memo.org" "memo")
         "* %U %? \n%i" :prepend t :unnarrowed nil :empty-lines-after 1)
        ;; ("t" "📘 TODO (Journal)" (entry file+headline my_journal) )
        ("T" "📚 TODO (GTD)" entry (file+headline "~/org_icloud/journal/gtd.org" "Inbox")
         "* TODO %?\n\n" :prepend t :unnarrowed t)
        ("M" "📚 MEMO (GTD)" entry (file+headline "~/org_icloud/journal/gtd.org" "Inbox")
         "* %?\n\n" :prepend t :unnarrowed t)
        ("S" "📗 SCHEDULE(GTD)" entry (file+headline "~/org_icloud/journal/gtd.org" "schedule")
         "* %?\n\n")
        ;; ("j" "📖 Journal" entry (file+olp+datetree "~/org_icloud/journal.org")
         ;; "%?\n- good :%?\n- bad  :\n- try  :\n")
        ;; ("e" "🔠 English" entry (file+headline "~/org_icloud/english.org" "word")
        ;;  "* %? %U\n%i\n" :prepend T)
        ))

;; org-agendaでaを押したら予定表とTODOリストを表示
(setq org-agenda-custom-commands
      '(("a" "Agenda and TODO"
         ((tags "routine")
          (agenda "")
          (alltodo "")))))

;; アジェンダ表示対象ファイル
(setq org-agenda-files
      '(;; "~/Dropbox/org/mygtd.org"
        ;; days-works-file
        "~/org_icloud/todo.org"
        "~/org_icloud/journal/gtd.org"
        "~/org_icloud/journal/inbox.org"
        ;; "~/org/days-works.org"
        ;; "~/org_icloud/daily-routine.org"
        ))

;; TODOリストに日付つきTODOを表示しない
;; (setq org-agenda-todo-ignore-with-date t)
;; 30日分の予定を表示させる
(setq org-agenda-span 30)
;; 今日から予定を表示させる
(setq org-agenda-start-on-weekday nil)

;; TODO状態
(setq org-todo-keywords
      '((sequence "TODO(t)" "WAIT(w)" "|" "DONE(d)" "SOMEDAY(s)")))
;; DONEの時刻を記録
(setq org-log-done 'time)


(setq org-export-html-coding-system 'utf-8)
(setq org-export-latex-date-format "%Y-%m-%d")
(setq org-latex-pdf-process '("pdflatex %f" "pdflatex %f" "pdflatex %f"))
(setq org-latex-default-class "jsarticle")
(setq org-export-latex-classes "jsarticle")
;; (org-export-latex-classes nil)



;; org-mode
(autoload 'org-mode "org" "Org Mode." t)
(add-to-list 'auto-mode-alist '("\\.org$" . org-mode))
(add-hook 'org-mode-hook 'turn-on-font-lock)
;; (add-hook 'org-mode-hook 'org-mode-keybinds)
(add-hook 'org-mode-hook 'org-indent-mode)
;; (add-to-list 'org-export-latex-classes
;;    '("jsarticle"
;;  "\\documentclass[a4j]{jarticle}"
;;  ("\\section{%s}" . "\\section*{%s}")
;;  ("\\subsection{%s}" . "\\subsection*{%s}")
;;  ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
;;  ("\\paragraph{%s}" . "\\paragraph*{%s}")
;;  ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

(defun inset-daily-routin ()
  (interactive "")
  (insert
   (format "** [%s]\n\n- Daily Routin [/]\n  + [ ] Burpee jump\n  + [ ] English study" (today-time-string))))

(defvar days-works-file "~/Dropbox/org/days-works.org")
;; (setq days-works-file nil)
(defun get-tommorow-string ()
  (format-time-string "%y-%m-%d %a" (time-add (current-time) (* 24 60 60))))
(defun get-yesterday-string ()
  (format-time-string "%y-%m-%d %a" (time-subtract (current-time) (* 24 60 60))))

(defun org-toggle-link-display ()
  "Toggle the literal or descriptive display of links."
  (interactive)

  (if org-descriptive-links
      (progn (org-remove-from-invisibility-spec '(org-link))
             (org-restart-font-lock)
             (setq org-descriptive-links nil))
    (progn (add-to-invisibility-spec '(org-link))
           (org-restart-font-lock)
           (setq org-descriptive-links t))))

;; (defun insert-date-headline-to-days-works (&optional date)
;;   (let* ((date-string ""))
;;     (case date
;;       ('tommorow (setq date-string (get-tommorow-string)))
;;       ('yesterday (setq date-string (get-yesterday-string)))
;;       (t (setq date-string (get-today-string))))
;;     (with-temp-buffer
;;       (insert-file-contents days-works-file)
;;       (if (re-search-forward (format "^\\* %s.*" date-string) nil t)
;;           ();すでにある場合は何もしない
;;         (if (re-search-forward "^\\* [0-9]+-[0-9]+-[0-9]+.*" nil t)
;;             (progn
;;               (beginning-of-line)
;;               (open-line 1))
;;           (end-of-buffer));何もないときはbufferの最後
;;         (insert (format "* %s\n" date-string))
;;         (insert "** achievement\n")
;;         (insert "** duty list")
;;         (write-file days-works-file)))))

(defun open-days-work-file ()
  (interactive)
  (find-file days-works-file)
  (when (re-search-forward (format "^\\* %s" (get-today-string)) nil t)
    (beginning-of-line)
    (org-show-subtree)))

(defun open-days-work-file-tommorow ()
  (interactive)
  (find-file days-works-file)
  (insert-date-headline-to-days-works 'tommorow)
  (when (re-search-forward (format "^\\* %s" (get-tommorow-string)) nil t)
    (beginning-of-line)
    (org-show-subtree)))



;; (defun insert-date-headline-to-days-works (&optional date)
;; (let* ((date-string ""))
;;   (case date
;;     ('tommorow (setq date-string (get-tommorow-string)))
;;     ('yesterday (setq date-string (get-yesterday-string)))
;;     (t (setq date-string (get-today-string))))
;;   (with-temp-buffer
;;     (insert-file-contents days-works-file)
;;     (if (re-search-forward (format "^\\* %s.*" date-string) nil t)
;;         ();すでにある場合は何もしない
;;       (if (re-search-forward "^\\* [0-9]+-[0-9]+-[0-9]+.*" nil t)
;;           (progn
;;             (beginning-of-line)
;;             (open-line 1))
;;         (end-of-buffer));何もないときはbufferの最後
;;       (insert (format "* %s\n" date-string))
;;       (insert "** achievement\n")
;;       (insert "** duty list")
;;       (write-file days-works-file)))))

(defun org-capture-extend ()
  (interactive)
  "org-capptureの実行前に他の関数を実行したい"
  (insert-date-headline-to-days-works)
  (org-capture))

(defun gtd ()
  (interactive)
  (find-file "~/Dropbox/org/mygtd.org"))
(setq org-log-done t)
(setq org-export-with-LaTeX-fragments t)
;; org-rememberを使う
                                        ;(org-remember-insinuate)
;; org-rememberのテンプレート
(setq org-remember-templates
      '(("Note" ?n "* %?\n  %i\n  %a" nil "Tasks")
        ("Todo" ?t "* TODO %?\n  %i\n  %a" nil "Tasks")))
                                        ; TODOにWAITを追加
(setq org-todo-keywords '("TODO"  "DONE") org-todo-interpretation 'sequence)
(setq org-todo-keyword-faces
      '(("TODO"    . org-warning)
        ("WAIT" . shadow)))
(setq org-startup-truncated nil)

(defun change-truncation()
  (interactive)
  (cond ((eq truncate-lines nil)
         (setq truncate-lines t))
        (t
         (setq truncate-lines nil))))


;; japanese-holiday
(with-eval-after-load "calendar"
  (require 'japanese-holidays)
  (setq calendar-holidays ; 他の国の祝日も表示させたい場合は適当に調整
        (append japanese-holidays holiday-local-holidays holiday-other-holidays))
  (setq calendar-mark-holidays-flag t)    ; 祝日をカレンダーに表示
  ;; 土曜日・日曜日を祝日として表示する場合、以下の設定を追加します。
  ;; 変数はデフォルトで設定済み
  (setq japanese-holiday-weekend '(0 6)    ; 土日を祝日として表示
        japanese-holiday-weekend-marker    ; 土曜日を水色で表示
        '(holiday nil nil nil nil nil japanese-holiday-saturday))
  (add-hook 'calendar-today-visible-hook 'japanese-holiday-mark-weekend)
  (add-hook 'calendar-today-invisible-hook 'japanese-holiday-mark-weekend)
  ;; “きょう”をマークするには以下の設定を追加します。
  (add-hook 'calendar-today-visible-hook 'calendar-mark-today)
  ;; org-agendaで祝日を表示する
  (setq org-agenda-include-diary t))


