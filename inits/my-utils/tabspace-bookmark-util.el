;;; tabspace-bookmark-util.el --- tabspace/layout スコープ付き bookmark -*- lexical-binding: t; -*-

;;; Commentary:
;; 標準の bookmark はグローバルに1つの alist だが、`bookmark-set' した時点の
;; 「どのタブ (tabspace)・どのレイアウトか」を bookmark の props に自動記録し、
;; 現在のタブ/レイアウトに合う bookmark だけからジャンプできるようにする。
;;
;; - 保存先は従来どおり `bookmark-default-file' 1つ (グローバル)。
;;   C-x r b (consult-bookmark) は全件対象のまま変わらない。ローカルな
;;   「見え方」を `my/bookmark-jump-local' で足すだけなので、既存の
;;   bookmark 資産はそのまま「どのタブにも属さないグローバル」として残る。
;; - 「現在のレイアウト」は my/tabspace-save-layout / load-layout した直近の
;;   名前 (tabspace-util.el の `my/tabspace--active-layout' で追跡)。
;;   起動直後はどのタブも nil (= レイアウト未確定) 扱い。

;;; Code:

(require 'bookmark)
(require 'tab-bar)
(require 'seq)
(require 'tabspace-util)

(defun my/bookmark--current-tab-name ()
  "現在のタブ名を返す。"
  (alist-get 'name (tab-bar--current-tab)))

;; ---------------------------------------------------------------------------
;; bookmark-set 時にタブ/レイアウトを自動記録
;; ---------------------------------------------------------------------------

(defun my/bookmark--stamp-context (&rest _)
  "直前に設定した bookmark に現タブ名・現レイアウト名を記録する。"
  (let ((tab (my/bookmark--current-tab-name)))
    (when (and bookmark-current-bookmark tab)
      (bookmark-prop-set bookmark-current-bookmark 'tabspace tab)
      (let ((layout (my/tabspace-current-layout)))
        (when layout
          (bookmark-prop-set bookmark-current-bookmark
                             'tabspace-layout layout))))))
(advice-add 'bookmark-set :after #'my/bookmark--stamp-context)

;; ---------------------------------------------------------------------------
;; スコープ付きジャンプ
;; ---------------------------------------------------------------------------

(defun my/bookmark--local-bookmarks (&optional layout-only)
  "現タブに紐付く bookmark レコードのリストを返す。
現レイアウトに紐付くものを先頭に並べる。LAYOUT-ONLY なら現レイアウト分のみ。"
  (let* ((tab (my/bookmark--current-tab-name))
         (layout (my/tabspace-current-layout))
         (tab-bms (seq-filter
                   (lambda (bm) (equal (bookmark-prop-get bm 'tabspace) tab))
                   bookmark-alist))
         (layout-bms
          (and layout
               (seq-filter
                (lambda (bm)
                  (equal (bookmark-prop-get bm 'tabspace-layout) layout))
                tab-bms))))
    (if layout-only
        layout-bms
      (append layout-bms
              (seq-remove (lambda (bm) (memq bm layout-bms)) tab-bms)))))

(defun my/bookmark-jump-local (&optional layout-only)
  "現タブに紐付いた bookmark を選んでジャンプする。
C-u 付き (LAYOUT-ONLY) で現レイアウトに紐付いたものだけに絞る。
候補は現レイアウトのものが先頭。注釈に [レイアウト名] と実体パスを出す。
全 bookmark からのジャンプは従来どおり C-x r b (consult-bookmark)。"
  (interactive "P")
  (let* ((bms (my/bookmark--local-bookmarks layout-only))
         (names (mapcar #'bookmark-name-from-full-record bms)))
    (unless names
      (user-error "%sに紐付いた bookmark がありません (C-x r m で登録)"
                  (if layout-only
                      (format "レイアウト '%s' " (or (my/tabspace-current-layout)
                                                     "(未確定)"))
                    (format "タブ '%s' " (my/bookmark--current-tab-name)))))
    (let* ((annotate
            (lambda (name)
              (let* ((bm (assoc name bms))
                     (layout (bookmark-prop-get bm 'tabspace-layout))
                     (file (bookmark-get-filename bm)))
                (propertize
                 (concat (when layout (format "  [%s]" layout)) "  " file)
                 'face 'completions-annotations))))
           (table (lambda (str pred action)
                    (if (eq action 'metadata)
                        `(metadata (display-sort-function . ,#'identity)
                                   (annotation-function . ,annotate))
                      (complete-with-action action names str pred))))
           (choice (completing-read "Local bookmark: " table nil t)))
      (bookmark-jump choice))))

(defun my/bookmark-jump-layout ()
  "現レイアウトに紐付いた bookmark を選んでジャンプする。"
  (interactive)
  (my/bookmark-jump-local t))

(provide 'tabspace-bookmark-util)
;;; tabspace-bookmark-util.el ends here
