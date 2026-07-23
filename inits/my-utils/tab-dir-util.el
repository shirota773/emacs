;;; tab-dir-util.el --- タブ単位のプロセス用ディレクトリ高速ジャンプ -*- lexical-binding: t; -*-

;;; Commentary:
;; タブ (= プロセス/作業単位) ごとに「よく使うディレクトリ集合」を持たせ、
;; consult-dir の候補として現タブのディレクトリを最優先で提示する。
;;
;; ディレクトリ集合の構成:
;;   - :process-root + `my/pdk-dir-template' から導出する規則的サブディレクトリ
;;   - :directories で個別登録した散在ディレクトリ
;; 保存先は専用ファイル `my/tab-dir-store-file'
;; (タブ名 → (:process-root STR :directories ALIST) の alist)。
;; 登録・変更時に即座に書き込んで永続化する。
;; 旧 tabspace-dir-util.el のセッション plist 相乗り保存から分離 (2026-07-23)。

;;; Code:

(require 'seq)
(require 'tab-bar)
(require 'navigation-util)              ; my/find-file-in-dir

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
;; 永続ストア (タブ名 → (:process-root STR :directories ALIST))
;; ---------------------------------------------------------------------------

(defvar my/tab-dir-store-file
  (expand-file-name "tab-dirs.eld"
                    (or (bound-and-true-p no-littering-var-directory)
                        user-emacs-directory))
  "タブ別ディレクトリ設定の保存先ファイル。")

(defvar my/tab-dir--table 'unloaded
  "タブ名 → 設定 plist の alist キャッシュ。`unloaded' は未読込を表す。")

(defun my/tab-dir--load ()
  "ストアファイルを (初回のみ) 読み込み、テーブルを返す。"
  (when (eq my/tab-dir--table 'unloaded)
    (setq my/tab-dir--table
          (when (file-exists-p my/tab-dir-store-file)
            (with-temp-buffer
              (insert-file-contents my/tab-dir-store-file)
              (read (current-buffer))))))
  my/tab-dir--table)

(defun my/tab-dir--save ()
  "テーブルをストアファイルへ書き出す。"
  (with-temp-file my/tab-dir-store-file
    (prin1 my/tab-dir--table (current-buffer))))

(defun my/tab-dir--get (tab-name)
  "TAB-NAME の設定 plist を返す。無ければ nil。"
  (alist-get tab-name (my/tab-dir--load) nil nil #'equal))

(defun my/tab-dir--put (tab-name plist)
  "TAB-NAME の設定を PLIST に置き換えて即保存する。"
  (let ((rest (assoc-delete-all tab-name
                                (copy-alist (or (my/tab-dir--load) '())))))
    (setq my/tab-dir--table (cons (cons tab-name plist) rest))
    (my/tab-dir--save)))

;; ---------------------------------------------------------------------------
;; タブのディレクトリ集合
;; ---------------------------------------------------------------------------

(defun my/tab-dir--current-name ()
  "現在のタブ名を返す。"
  (alist-get 'name (tab-bar--current-tab)))

(defun my/tab-dir--norm-dir (path &optional base)
  "PATH を BASE 基準で展開し、末尾スラッシュ付きに正規化する。"
  (file-name-as-directory (expand-file-name path base)))

(defun my/tab-dirs (&optional tab-name)
  "TAB-NAME (省略時は現タブ) の実効ディレクトリ (ラベル . パス) alist を返す。
:process-root からテンプレ導出したものと :directories の個別登録を合わせ、
実在するディレクトリだけを返す。パスは展開・末尾スラッシュ付きに正規化する。"
  (let* ((name (or tab-name (my/tab-dir--current-name)))
         (data (and name (my/tab-dir--get name)))
         (root (plist-get data :process-root))
         (explicit (plist-get data :directories))
         (result '()))
    (when (stringp root)
      (dolist (tpl my/pdk-dir-template)
        (let ((p (my/tab-dir--norm-dir (cdr tpl) root)))
          (when (file-directory-p p)
            (push (cons (car tpl) p) result)))))
    (dolist (e explicit)
      (let ((p (my/tab-dir--norm-dir (cdr e))))
        (when (file-directory-p p)
          (push (cons (car e) p) result))))
    (nreverse result)))

;; ---------------------------------------------------------------------------
;; 登録・変更コマンド (即時にストアファイルへ書き込む)
;; ---------------------------------------------------------------------------

(defun my/tab-dir-set-process-root (root)
  "現タブのプロセスルート ROOT を設定する。
`my/pdk-dir-template' のサブディレクトリがここから自動導出される。"
  (interactive "DProcess root: ")
  (let* ((name (my/tab-dir--current-name))
         (data (my/tab-dir--get name)))
    (my/tab-dir--put name (plist-put (copy-sequence (or data '()))
                                     :process-root (expand-file-name root)))
    (message "Tab '%s' process root → %s" name root)))

(defun my/tab-dir-add-dir (label dir)
  "現タブに個別ディレクトリ DIR を LABEL で登録する (散在dir用)。
ラベルは空 RET でディレクトリ名 (basename) を自動採用する。"
  (interactive
   (let* ((dir (read-directory-name "Directory: "))
          (base (file-name-nondirectory (directory-file-name dir)))
          (label (read-string (format "Label (default %s): " base) nil nil base)))
     (list label dir)))
  (let* ((name (my/tab-dir--current-name))
         (data (my/tab-dir--get name))
         (dirs (copy-alist (plist-get data :directories))))
    (setf (alist-get label dirs nil nil #'equal) (expand-file-name dir))
    (my/tab-dir--put name (plist-put (copy-sequence (or data '()))
                                     :directories dirs))
    (message "Tab '%s' + dir [%s] %s" name label dir)))

(defun my/tab-dir-add-current (&optional label)
  "現在の `default-directory' を現タブに登録する。
LABEL 省略時はディレクトリ名を既定値にして確認入力する。"
  (interactive)
  (let* ((dir default-directory)
         (base (file-name-nondirectory (directory-file-name dir)))
         (label (or label
                    (read-string (format "Label (default %s): " base)
                                 nil nil base))))
    (my/tab-dir-add-dir label dir)))

(defun my/tab-dir-remove (label)
  "現タブの個別登録ディレクトリを LABEL で削除する。"
  (interactive
   (list (let* ((name (my/tab-dir--current-name))
                (dirs (plist-get (my/tab-dir--get name) :directories)))
           (unless dirs (user-error "このタブには個別登録ディレクトリがありません"))
           (completing-read "Remove label: " (mapcar #'car dirs) nil t))))
  (let* ((name (my/tab-dir--current-name))
         (data (my/tab-dir--get name))
         (dirs (assoc-delete-all label (copy-alist (plist-get data :directories)))))
    (my/tab-dir--put name (plist-put (copy-sequence (or data '()))
                                     :directories dirs))
    (message "Tab '%s' - dir [%s]" name label)))

;; ---------------------------------------------------------------------------
;; ラベルで選ぶ専用ジャンプ (consult-dir は category=file 固定でラベルを出せないため)
;; ---------------------------------------------------------------------------

(defun my/tab-dir-jump ()
  "現タブ + `my/global-dirs' の登録ディレクトリをラベルで選び find-file する。
候補はラベル表示、注釈に実パスを出す。タブ側を優先 (ラベル衝突時はタブ採用)。"
  (interactive)
  (let* ((tab (my/tab-dirs))
         (glob (mapcar (lambda (e) (cons (car e) (my/tab-dir--norm-dir (cdr e))))
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
    :items    ,(lambda () (mapcar #'cdr (my/tab-dirs)))
    :annotate ,(lambda (path) (car (rassoc path (my/tab-dirs)))))
  "現タブのプロセス用ディレクトリを返す consult-dir ソース。")

(defvar my/consult-dir--global-source
  `(:name     "Global dirs"
    :narrow   ?g
    :category file
    :face     consult-file
    :items    ,(lambda ()
                 (mapcar (lambda (e) (my/tab-dir--norm-dir (cdr e))) my/global-dirs))
    :annotate ,(lambda (path)
                 (car (rassoc path
                              (mapcar (lambda (e)
                                        (cons (car e) (my/tab-dir--norm-dir (cdr e))))
                                      my/global-dirs)))))
  "`my/global-dirs' を返す consult-dir ソース。")

(with-eval-after-load 'consult-dir
  ;; add-to-list は先頭に追加するので、global → tab の順で入れるとタブが最優先になる
  (add-to-list 'consult-dir-sources 'my/consult-dir--global-source)
  (add-to-list 'consult-dir-sources 'my/consult-dir--tab-source))

(provide 'tab-dir-util)
;;; tab-dir-util.el ends here
