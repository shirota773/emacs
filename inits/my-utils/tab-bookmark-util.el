;;; tab-bookmark-util.el --- タブ/レイアウトスコープ付き bookmark -*- lexical-binding: t; -*-

;;; Commentary:
;; 標準の bookmark はグローバルに1つの alist だが、`bookmark-set' した時点の
;; 「どのタブ・どのレイアウトか」を bookmark の props に自動記録し、
;; 現在のタブ/レイアウトに合う bookmark だけからジャンプできるようにする。
;;
;; - 保存先は従来どおり `bookmark-default-file' 1つ (グローバル)。
;;   C-x r b (consult-bookmark) は全件対象のまま変わらない。ローカルな
;;   「見え方」を `my/bookmark-jump-local' で足すだけなので、既存の
;;   bookmark 資産はそのまま「どのタブにも属さないグローバル」として残る。
;;   props のキー名 (tabspace / tabspace-layout) も旧実装から変えない。
;; - 「現在のレイアウト」は bufferlo が現タブに紐付けているタブ bookmark 名
;;   (タブ alist の `bufferlo-bookmark-tab-name')。命名規約「タブ名/レイアウト名」。
;;   タブ bookmark 未紐付けのタブでは nil (= レイアウト未確定) 扱い。
;;   旧実装の my/tabspace--active-layout ハッシュ追跡からの付け替え (2026-07-23)。

;;; Code:

(require 'bookmark)
(require 'tab-bar)
(require 'seq)

(defun my/bookmark--current-tab-name ()
  "現在のタブ名を返す。"
  (alist-get 'name (tab-bar--current-tab)))

(defun my/tab-bookmark--active-name ()
  "現タブでアクティブな bufferlo タブ bookmark 名を返す。無ければ nil。
タブ alist の `bufferlo-bookmark-tab-name' キーは bufferlo の内部仕様のため、
参照はこの関数1箇所に隔離する。"
  (alist-get 'bufferlo-bookmark-tab-name (tab-bar--current-tab)))

;; ---------------------------------------------------------------------------
;; bookmark-set 時にタブ/レイアウトを自動記録
;; ---------------------------------------------------------------------------

(defun my/bookmark--stamp-context (&rest _)
  "直前に設定した bookmark に現タブ名・現レイアウト名を記録する。"
  (let ((tab (my/bookmark--current-tab-name)))
    (when (and bookmark-current-bookmark tab)
      (bookmark-prop-set bookmark-current-bookmark 'tabspace tab)
      (let ((layout (my/tab-bookmark--active-name)))
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
         (layout (my/tab-bookmark--active-name))
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
                      (format "レイアウト '%s' " (or (my/tab-bookmark--active-name)
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

(provide 'tab-bookmark-util)
;;; tab-bookmark-util.el ends here
