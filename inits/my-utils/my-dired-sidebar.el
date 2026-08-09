;;; my-dired-sidebar.el --- Bookmark サイドバー -*- lexical-binding: t; -*-

;; Windows エクスプローラー左ペインの「クイックアクセス」に相当する常駐サイドバー。
;; 登録済みのディレクトリを一覧する。
;;
;;   クリック / RET / l   そこを dired で開く
;;   中クリック           新しいタブで開く (dired 側と揃えてある)
;;   j / k (n / p)        次 / 前の項目へ
;;   q / g                閉じる / 作り直す
;;
;; 一覧の出所は既にある3つをそのまま束ねる。新しい登録簿は作らない。
;;   - Bookmark            … C-x r m と右クリックの「Bookmark に追加」で増える
;;   - `dirvish-quick-access-entries' (05_dired.el)  … キーボードの a と共通
;;   - `my/global-dirs' (tab-dir-util.el)            … consult-dir と共通
;;
;; ツリー表示が要るときは dirvish-side (M-s d) を併用する。こちらは
;; 「ピン留めした場所の一覧」に徹する。

(require 'bookmark)
(require 'dirvish-quick-access)

(declare-function my/dired-tab-open-dir-in-new-tab "my-dired-tabs")

(defvar my/quick-access-buffer-name "*Bookmark*")

(defvar my/quick-access-width 24
  "サイドバーの幅 (桁)。
本文側を広く取りたいので、項目名が収まる最小限にしてある。行番号を消した分も
効いている (`my/quick-access-mode' を参照)。")

(defvar-keymap my/quick-access-mode-map
  :doc "クイックアクセスサイドバーのキーマップ。
移動は dired と同じ j/k でもできるようにしてある (n/p も残す)。"
  "q" #'quit-window
  "g" #'my/quick-access-refresh
  "n" #'forward-button
  "p" #'backward-button
  "j" #'forward-button
  "k" #'backward-button
  ;; RET は button-map 由来で既に push-button だが、l でも開けるようにする
  ;; (dired の l = dired-find-file と揃える)
  "l" #'push-button)

(define-derived-mode my/quick-access-mode special-mode "QuickAccess"
  "登録ディレクトリを一覧するサイドバー。"
  ;; カーソルは消すが、代わりに行を highlight する。両方無いとキーボードで
  ;; 動いたときに今どこに居るのか分からず、クリックでしか使えなくなる
  (setq-local cursor-type nil)
  (hl-line-mode 1)
  (setq-local mode-line-format nil))

(defun my/quick-access--dirs ()
  "表示するディレクトリを ((見出し . ((ラベル . パス) ...)) ...) で返す。"
  (bookmark-maybe-load-default-file)
  (list
   ;; 右クリックの「Bookmark に追加」で増えるのはここ
   (cons "Bookmark"
         (delq nil
               (mapcar (lambda (b)
                         (let ((fn (bookmark-get-filename b)))
                           (when (and fn (file-directory-p fn))
                             (cons (car b) fn))))
                       bookmark-alist)))
   (cons "クイックアクセス"
         (mapcar (lambda (e)
                   (let ((path (nth 1 e)))
                     (cons (or (nth 2 e) path) path)))
                 dirvish-quick-access-entries))
   (cons "登録ディレクトリ"
         (and (boundp 'my/global-dirs) my/global-dirs))))

(defun my/dired-bookmark-add ()
  "この場所を Bookmark に登録する。
ポイント下がディレクトリならそれを、そうでなければ今開いているディレクトリを
登録する。`dirvish-quick-access-entries' や `my/global-dirs' と違って
Customize を経由しないので、そのままファイルに保存されて次回も残る。"
  (interactive)
  (let* ((at-point (and (derived-mode-p 'dired-mode) (dired-get-filename nil t)))
         (dir (file-name-as-directory
               (expand-file-name
                (if (and at-point (file-directory-p at-point))
                    at-point
                  default-directory))))
         (name (read-string
                "Bookmark 名: "
                (file-name-nondirectory (directory-file-name dir)))))
    (when (string-empty-p name)
      (user-error "名前が空です"))
    (bookmark-store name `((filename . ,dir)) nil)
    (bookmark-save)
    (when (get-buffer my/quick-access-buffer-name)
      (my/quick-access-refresh))
    (message "Bookmark に追加しました: %s → %s" name (abbreviate-file-name dir))))

(defvar my/quick-access-button-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map button-map)
    ;; 中クリックは dired 側と同じく「新しいタブで開く」
    (define-key map [mouse-2] #'my/quick-access-open-in-new-tab)
    (define-key map (kbd "C-<return>") #'my/quick-access-open-in-new-tab)
    map)
  "サイドバーの項目に付けるキーマップ。")

(defun my/quick-access--open (path &optional new-tab)
  "PATH を dired で開く。サイドバーではなく本文側のウィンドウを使う。
NEW-TAB が非 nil なら新しいタブとして開く。"
  ;; サイドバーではなく直前に使っていた本文側のウィンドウを選ぶ。
  ;; window-list の先頭一致だと並び順で拾ってしまい、意図しない側が開く。
  (let ((win (or (get-mru-window nil nil t)
                 (seq-find (lambda (w) (not (window-parameter w 'window-side)))
                           (window-list)))))
    (when win (select-window win))
    (if new-tab
        (my/dired-tab-open-dir-in-new-tab (expand-file-name path))
      (dired (expand-file-name path)))))

(defun my/quick-access-open-in-new-tab (&optional event)
  "クリックした項目を新しいタブで開く。
EVENT が無ければポイント位置の項目を対象にする (キーからも呼べるように)。"
  (interactive (list last-nonmenu-event))
  (when (listp event)
    (let ((pt (posn-point (event-start event))))
      (when pt (goto-char pt))))
  (let ((path (get-text-property (point) 'my/quick-access-path)))
    (unless path (user-error "ここには開ける場所がありません"))
    (my/quick-access--open path t)))

(defun my/quick-access-refresh ()
  "サイドバーの内容を作り直す。"
  (interactive)
  (with-current-buffer (get-buffer-create my/quick-access-buffer-name)
    (unless (derived-mode-p 'my/quick-access-mode)
      (my/quick-access-mode))
    ;; 行番号を消す。幅の節約で、一覧に行番号は意味が無い。
    ;; モード本体に置いても効かない。global-display-line-numbers-mode は
    ;; after-change-major-mode-hook でオンにするので、モード本体やモードフックより
    ;; **後**に走る (run-mode-hooks の順序)。ここで消すのが確実。
    (display-line-numbers-mode -1)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (dolist (section (my/quick-access--dirs))
        (when (cdr section)
          (insert (propertize (concat (car section) "\n") 'face 'bold))
          (dolist (entry (cdr section))
            ;; dolist の変数は全周回で同じ束縛なので、閉じ込める前に捕まえ直す
            (let ((path (cdr entry)))
              (insert "  ")
              (insert-text-button
               (car entry)
               'action (lambda (_) (my/quick-access--open path))
               ;; follow-link を付けるとシングルクリック (mouse-1) で開ける
               'follow-link t
               'keymap my/quick-access-button-map
               ;; 中クリック用のハンドラが対象を知るために持たせる
               'my/quick-access-path path
               'help-echo (format "%s  (中クリックで新しいタブ)"
                                  (expand-file-name path)))
              (insert "\n")))
          (insert "\n")))
      (goto-char (point-min)))))

;;;###autoload
(defun my/quick-access-sidebar ()
  "クイックアクセスのサイドバーを開閉する。"
  (interactive)
  (let ((win (get-buffer-window my/quick-access-buffer-name)))
    (if win
        (delete-window win)
      (my/quick-access-refresh)
      (select-window
       (display-buffer-in-side-window
        (get-buffer my/quick-access-buffer-name)
        `((side . left)
          (slot . 0)
          (window-width . ,my/quick-access-width)
          (window-parameters . ((no-delete-other-windows . t)))))))))

;;; どのバッファからでも右クリックで開けるようにする

(defun my/quick-access-context-menu (menu _click)
  "MENU にクイックアクセスの項目を足して返す。
dired に限らずどのバッファの右クリックからでも開けるようにするため、
`context-menu-functions' にモード非依存で登録する。"
  (define-key-after menu [my-quick-access-separator] menu-bar-separator)
  (define-key-after menu [my-quick-access]
    '(menu-item "Bookmark サイドバー" my/quick-access-sidebar))
  menu)

(defun my/quick-access-setup ()
  "クイックアクセスを有効にする。"
  (add-hook 'context-menu-functions #'my/quick-access-context-menu))

(provide 'my-dired-sidebar)
;;; my-dired-sidebar.el ends here
