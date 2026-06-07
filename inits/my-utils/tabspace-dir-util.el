;;; tabspace-dir-util.el --- タブ単位のプロセス用ディレクトリ高速ジャンプ -*- lexical-binding: t; -*-

;;; Commentary:
;; tabspace (= プロセス/作業単位) ごとに「よく使うディレクトリ集合」を持たせ、
;; consult-dir の候補として現タブのディレクトリを最優先で提示する。
;;
;; ディレクトリ集合の構成:
;;   - :process-root + `my/pdk-dir-template' から導出する規則的サブディレクトリ
;;   - :directories で個別登録した散在ディレクトリ
;; いずれも既存のセッション plist (~/.emacs.d/var/tabspace-sessions/{タブ名}.el)
;; に保存し、登録・変更時に即座に書き込んで永続化する。

;;; Code:

(require 'tabspace-util)

(defcustom my/pdk-dir-template
  '(("work"    . "work")
    ("release" . "release")
    ("assura"  . "assura")
    ("rules"   . "rules"))
  "プロセスルート配下の規則的サブディレクトリ。
各要素は (ラベル . ルートからの相対パス)。
タブに :process-root が設定されていると、ここから実在するものを自動導出する。"
  :type '(alist :key-type string :value-type string)
  :group 'convenience)

(defcustom my/global-dirs nil
  "全プロセス共通でよく使うディレクトリの alist。
各要素は (ラベル . 絶対パス)。タブ候補の後ろに提示される。"
  :type '(alist :key-type string :value-type string)
  :group 'convenience)

;; ---------------------------------------------------------------------------
;; タブのディレクトリ集合
;; ---------------------------------------------------------------------------

(defun my/tabspace--current-name ()
  "現在のタブ名を返す。"
  (alist-get 'name (tab-bar--current-tab)))

(defun my/tabspace--norm-dir (path &optional base)
  "PATH を BASE 基準で展開し、末尾スラッシュ付きに正規化する。"
  (file-name-as-directory (expand-file-name path base)))

(defun my/tabspace-dirs (&optional tab-name)
  "TAB-NAME (省略時は現タブ) の実効ディレクトリ (ラベル . パス) alist を返す。
:process-root からテンプレ導出したものと :directories の個別登録を合わせ、
実在するディレクトリだけを返す。パスは展開・末尾スラッシュ付きに正規化する。"
  (let* ((name (or tab-name (my/tabspace--current-name)))
         (data (and name (my/tabspace--read-session name)))
         (root (plist-get data :process-root))
         (explicit (plist-get data :directories))
         (result '()))
    (when (stringp root)
      (dolist (tpl my/pdk-dir-template)
        (let ((p (my/tabspace--norm-dir (cdr tpl) root)))
          (when (file-directory-p p)
            (push (cons (car tpl) p) result)))))
    (dolist (e explicit)
      (let ((p (my/tabspace--norm-dir (cdr e))))
        (when (file-directory-p p)
          (push (cons (car e) p) result))))
    (nreverse result)))

;; ---------------------------------------------------------------------------
;; 登録・変更コマンド (即時にセッションファイルへ書き込む)
;; ---------------------------------------------------------------------------

(defun my/tabspace--session-or-new (name)
  "NAME のセッション plist を読み込む。無ければ空の plist を返す。"
  (or (my/tabspace--read-session name)
      (list :tab-name name :buffers nil :layouts nil)))

(defun my/tabspace-set-process-root (root)
  "現タブのプロセスルート ROOT を設定する。
`my/pdk-dir-template' のサブディレクトリがここから自動導出される。"
  (interactive "DProcess root: ")
  (let* ((name (my/tabspace--current-name))
         (data (my/tabspace--session-or-new name)))
    (my/tabspace--write-session
     name (plist-put (copy-tree data) :process-root (expand-file-name root)))
    (message "Tab '%s' process root → %s" name root)))

(defun my/tabspace-add-dir (label dir)
  "現タブに個別ディレクトリ DIR を LABEL で登録する (散在dir用)。
ラベルは空 RET でディレクトリ名 (basename) を自動採用する。"
  (interactive
   (let* ((dir (read-directory-name "Directory: "))
          (base (file-name-nondirectory (directory-file-name dir)))
          (label (read-string (format "Label (default %s): " base) nil nil base)))
     (list label dir)))
  (let* ((name (my/tabspace--current-name))
         (data (my/tabspace--session-or-new name))
         (dirs (copy-alist (plist-get data :directories))))
    (setf (alist-get label dirs nil nil #'equal) (expand-file-name dir))
    (my/tabspace--write-session
     name (plist-put (copy-tree data) :directories dirs))
    (message "Tab '%s' + dir [%s] %s" name label dir)))

(defun my/tabspace-add-current-dir (&optional label)
  "現在の `default-directory' を現タブに登録する。
LABEL 省略時はディレクトリ名を既定値にして確認入力する。"
  (interactive)
  (let* ((dir default-directory)
         (base (file-name-nondirectory (directory-file-name dir)))
         (label (or label
                    (read-string (format "Label (default %s): " base)
                                 nil nil base))))
    (my/tabspace-add-dir label dir)))

(defun my/tabspace-remove-dir (label)
  "現タブの個別登録ディレクトリを LABEL で削除する。"
  (interactive
   (list (let* ((name (my/tabspace--current-name))
                (dirs (plist-get (my/tabspace--read-session name) :directories)))
           (unless dirs (user-error "このタブには個別登録ディレクトリがありません"))
           (completing-read "Remove label: " (mapcar #'car dirs) nil t))))
  (let* ((name (my/tabspace--current-name))
         (data (my/tabspace--read-session name))
         (dirs (assoc-delete-all
                label (copy-alist (plist-get data :directories)) #'equal)))
    (my/tabspace--write-session
     name (plist-put (copy-tree data) :directories dirs))
    (message "Tab '%s' - dir [%s]" name label)))

;; ---------------------------------------------------------------------------
;; ラベルで選ぶ専用ジャンプ (consult-dir は category=file 固定でラベルを出せないため)
;; ---------------------------------------------------------------------------

(defun my/tabspace-jump-dir ()
  "現タブ + `my/global-dirs' の登録ディレクトリをラベルで選び find-file する。
候補はラベル表示、注釈に実パスを出す。タブ側を優先 (ラベル衝突時はタブ採用)。"
  (interactive)
  (let* ((tab (my/tabspace-dirs))
         (glob (mapcar (lambda (e) (cons (car e) (my/tabspace--norm-dir (cdr e))))
                       my/global-dirs))
         (all (append tab (seq-remove (lambda (g) (assoc (car g) tab)) glob))))
    (unless all
      (user-error "登録ディレクトリがありません (hydra pr/pa/pc で登録)"))
    (let* ((annotate (lambda (s)
                       (let ((p (cdr (assoc s all))))
                         (when p
                           (concat "  " (propertize p 'face 'completions-annotations))))))
           (completion-extra-properties (list :annotation-function annotate))
           (choice (completing-read "Jump to dir: " (mapcar #'car all) nil t)))
      (my/find-file-in-dir (cdr (assoc choice all))))))

;; ---------------------------------------------------------------------------
;; consult-dir ソース (タブ優先 → グローバル)
;; ---------------------------------------------------------------------------

(defvar my/consult-dir--tab-source
  `(:name     "Tab dirs"
    :narrow   ?t
    :category file
    :face     consult-file
    :items    ,(lambda () (mapcar #'cdr (my/tabspace-dirs)))
    :annotate ,(lambda (path) (car (rassoc path (my/tabspace-dirs)))))
  "現タブのプロセス用ディレクトリを返す consult-dir ソース。")

(defvar my/consult-dir--global-source
  `(:name     "Global dirs"
    :narrow   ?g
    :category file
    :face     consult-file
    :items    ,(lambda ()
                 (mapcar (lambda (e) (my/tabspace--norm-dir (cdr e))) my/global-dirs))
    :annotate ,(lambda (path)
                 (car (rassoc path
                              (mapcar (lambda (e)
                                        (cons (car e) (my/tabspace--norm-dir (cdr e))))
                                      my/global-dirs)))))
  "`my/global-dirs' を返す consult-dir ソース。")

(with-eval-after-load 'consult-dir
  ;; add-to-list は先頭に追加するので、global → tab の順で入れるとタブが最優先になる
  (add-to-list 'consult-dir-sources 'my/consult-dir--global-source)
  (add-to-list 'consult-dir-sources 'my/consult-dir--tab-source))

(provide 'tabspace-dir-util)
;;; tabspace-dir-util.el ends here
