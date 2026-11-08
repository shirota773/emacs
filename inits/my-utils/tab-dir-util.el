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
  "全プロセス共通でよく使うディレクトリの alist (コードで書く分)。
各要素は (ラベル . 絶対パス)。機種ごとの値は ~/.emacs.local-inits に書く。
hydra (C-f) の ga / gc で登録した分は別ファイルに保存され、両方を合わせたものが
`my/global-dirs-all' になる。custom-file が null-device なので Customize では
保存できない (init.el)。"
  :type '(alist :key-type string :value-type string)
  :group 'convenience)

;; ---------------------------------------------------------------------------
;; 永続ストア (タブ名 → (:process-root STR :directories ALIST))
;; ---------------------------------------------------------------------------

(defun my/tab-dir--var-file (name)
  "保存用ファイル NAME の絶対パスを返す (no-littering があれば var/ 配下)。"
  (expand-file-name name (or (bound-and-true-p no-littering-var-directory)
                             user-emacs-directory)))

(defun my/tab-dir--read-file (file)
  "FILE に保存した Lisp データを読む。無ければ nil。"
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (read (current-buffer)))))

(defun my/tab-dir--write-file (file data)
  "DATA を FILE へ書き出す。"
  (with-temp-file file
    (prin1 data (current-buffer))))

(defvar my/tab-dir-store-file (my/tab-dir--var-file "tab-dirs.eld")
  "タブ別ディレクトリ設定の保存先ファイル。")

(defvar my/tab-dir--table 'unloaded
  "タブ名 → 設定 plist の alist キャッシュ。`unloaded' は未読込を表す。")

(defun my/tab-dir--load ()
  "ストアファイルを (初回のみ) 読み込み、テーブルを返す。"
  (when (eq my/tab-dir--table 'unloaded)
    (setq my/tab-dir--table (my/tab-dir--read-file my/tab-dir-store-file)))
  my/tab-dir--table)

(defun my/tab-dir--save ()
  "テーブルをストアファイルへ書き出す。"
  (my/tab-dir--write-file my/tab-dir-store-file my/tab-dir--table))

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
  (interactive (my/tab-dir--read-label-and-dir))
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

(defconst my/tab-dir--root-label "[root]"
  "`my/tab-dir-remove' の候補でプロセスルートを表すラベルの接頭辞。")

(defun my/tab-dir-remove (label)
  "現タブの登録ディレクトリを LABEL で削除する。
個別登録 (pa / pc) に加えて、pr で決めたプロセスルートも選べる。ルートは
「[root] パス」の形で候補に出る。ルートを消すとテンプレートから導出していた
work / release などもまとめて候補から消える (2026-11-08)。"
  (interactive
   (list (let* ((data (my/tab-dir--get (my/tab-dir--current-name)))
                (root (plist-get data :process-root))
                (cands (append (mapcar #'car (plist-get data :directories))
                               (when root
                                 (list (format "%s %s" my/tab-dir--root-label
                                               (abbreviate-file-name root)))))))
           (unless cands (user-error "このタブには登録ディレクトリがありません"))
           (completing-read "Remove: " cands nil t))))
  (let* ((name (my/tab-dir--current-name))
         (data (copy-sequence (or (my/tab-dir--get name) '()))))
    (if (string-prefix-p my/tab-dir--root-label label)
        (my/tab-dir--put name (plist-put data :process-root nil))
      (my/tab-dir--put name
                       (plist-put data :directories
                                  (assoc-delete-all
                                   label (copy-alist (plist-get data :directories))))))
    (message "Tab '%s' - %s" name label)))

;; ---------------------------------------------------------------------------
;; グローバル起点 (どのタブからでも使うディレクトリ。ドキュメント・KB など)
;; ---------------------------------------------------------------------------
;; タブ用 (pa / pc) と同じ操作で登録し、機種ごとの別ファイルに保存する
;; (2026-11-09)。会社と自宅で中身が違うので var/ 側 (git 管理外) に置く。

(defvar my/global-dir-store-file (my/tab-dir--var-file "global-dirs.eld")
  "hydra で登録したグローバル起点の保存先ファイル。中身は (ラベル . パス) の alist。")

(defvar my/global-dir--table 'unloaded
  "グローバル起点のキャッシュ。`unloaded' は未読込を表す。")

(defun my/global-dir--load ()
  "グローバル起点のストアを (初回のみ) 読み込んで返す。"
  (when (eq my/global-dir--table 'unloaded)
    (setq my/global-dir--table (my/tab-dir--read-file my/global-dir-store-file)))
  my/global-dir--table)

(defun my/global-dir--put (alist)
  "グローバル起点のストアを ALIST に置き換えて即保存する。"
  (setq my/global-dir--table alist)
  (my/tab-dir--write-file my/global-dir-store-file alist))

(defun my/global-dirs-all ()
  "グローバル起点の実効 (ラベル . パス) alist を返す。
hydra で登録した分を先に、`my/global-dirs' (コードで書く分) を後ろに並べる。
ラベルが重なったら登録した分を採る。実在確認はしない。リモートのパスを
登録したとき、一覧を出すたびに TRAMP の接続が走るのを避けるため。"
  (let ((stored (mapcar (lambda (e) (cons (car e) (my/tab-dir--norm-dir (cdr e))))
                        (my/global-dir--load)))
        (coded (mapcar (lambda (e) (cons (car e) (my/tab-dir--norm-dir (cdr e))))
                       my/global-dirs)))
    (append stored (seq-remove (lambda (c) (assoc (car c) stored)) coded))))

(defun my/tab-dir--read-label-and-dir (&optional dir)
  "登録用に (LABEL DIR) を読む。DIR を渡すとディレクトリは聞かない。
ラベルは空 RET でディレクトリ名 (basename) を使う。"
  (let* ((dir (or dir (read-directory-name "Directory: ")))
         (base (file-name-nondirectory (directory-file-name dir)))
         (label (read-string (format "Label (default %s): " base) nil nil base)))
    (list label dir)))

(defun my/global-dir-add (label dir)
  "DIR をグローバル起点として LABEL で登録する。"
  (interactive (my/tab-dir--read-label-and-dir))
  (let ((alist (copy-alist (my/global-dir--load))))
    (setf (alist-get label alist nil nil #'equal) (expand-file-name dir))
    (my/global-dir--put alist)
    (message "Global + dir [%s] %s" label dir)))

(defun my/global-dir-add-current (label dir)
  "今の `default-directory' をグローバル起点として登録する。"
  (interactive (my/tab-dir--read-label-and-dir default-directory))
  (my/global-dir-add label dir))

(defun my/global-dir-remove (label)
  "hydra で登録したグローバル起点を LABEL で削除する。
`my/global-dirs' (コードで書いた分) はここでは消せないので候補に出さない。"
  (interactive
   (let ((labels (mapcar #'car (my/global-dir--load))))
     (unless labels (user-error "登録したグローバル起点がありません (hydra ga/gc で登録)"))
     (list (completing-read "Remove global: " labels nil t))))
  (my/global-dir--put (assoc-delete-all label (copy-alist (my/global-dir--load))))
  (message "Global - dir [%s]" label))

;; ---------------------------------------------------------------------------
;; ラベルで選ぶ専用ジャンプ (consult-dir は category=file 固定でラベルを出せないため)
;; ---------------------------------------------------------------------------

(defvar my/tab-dir-jump-include-global t
  "非 nil なら C-f f (`my/tab-dir-jump') の候補にグローバル起点も出す。
hydra の pg で切り替える。どちらが使いやすいか試している段階 (2026-11-09)。
グローバル起点だけから選ぶのは gj。")

(defun my/tab-dir-toggle-jump-global ()
  "C-f f にグローバル起点を出すかどうかを切り替える。"
  (interactive)
  (setq my/tab-dir-jump-include-global (not my/tab-dir-jump-include-global))
  (message "C-f f にグローバル起点を%s" (if my/tab-dir-jump-include-global "出す" "出さない")))

(defun my/tab-dir--jump-read (prompt groups)
  "GROUPS = ((見出し . ((ラベル . パス) ...)) ...) からラベルで 1 つ選び、パスを返す。
見出しごとにまとめて表示し、注釈に実パスを出す。ラベルが重なったら
先の見出しの方を採る (タブ優先)。"
  (let ((all '()))
    (dolist (g groups)
      (dolist (e (cdr g))
        (unless (assoc (car e) all)
          (push (list (car e) (cdr e) (car g)) all))))
    (setq all (nreverse all))
    (unless all
      (user-error "登録ディレクトリがありません (タブ用は pr/pa/pc、グローバルは ga/gc)"))
    (let* ((annotate (lambda (s)
                       (when-let* ((p (nth 1 (assoc s all))))
                         (concat "  " (propertize p 'face 'completions-annotations)))))
           (group (lambda (s transform)
                    (if transform s (nth 2 (assoc s all)))))
           (table (lambda (str pred action)
                    (if (eq action 'metadata)
                        `(metadata (annotation-function . ,annotate)
                                   (group-function . ,group)
                                   (display-sort-function . ,#'identity))
                      (complete-with-action action (mapcar #'car all) str pred))))
           (choice (completing-read prompt table nil t)))
      (nth 1 (assoc choice all)))))

(defun my/tab-dir-jump ()
  "現タブの登録ディレクトリをラベルで選び、そこから find-file を始める。
`my/tab-dir-jump-include-global' が非 nil ならグローバル起点も後ろに出す。"
  (interactive)
  (my/find-file-in-dir
   (my/tab-dir--jump-read
    "Jump to dir: "
    (append (list (cons (format "タブ: %s" (my/tab-dir--current-name)) (my/tab-dirs)))
            (when my/tab-dir-jump-include-global
              (list (cons "グローバル" (my/global-dirs-all))))))))

(defun my/global-dir-jump ()
  "グローバル起点だけからラベルで選び、そこから find-file を始める。"
  (interactive)
  (my/find-file-in-dir
   (my/tab-dir--jump-read "Jump to global dir: "
                          (list (cons "グローバル" (my/global-dirs-all))))))

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
    :items    ,(lambda () (mapcar #'cdr (my/global-dirs-all)))
    :annotate ,(lambda (path) (car (rassoc path (my/global-dirs-all)))))
  "グローバル起点 (`my/global-dirs-all') を返す consult-dir ソース。")

(with-eval-after-load 'consult-dir
  ;; add-to-list は先頭に追加するので、global → tab の順で入れるとタブが最優先になる
  (add-to-list 'consult-dir-sources 'my/consult-dir--global-source)
  (add-to-list 'consult-dir-sources 'my/consult-dir--tab-source))

(provide 'tab-dir-util)
;;; tab-dir-util.el ends here
