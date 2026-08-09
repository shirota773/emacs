;;; my-dired-view.el --- 一覧の見え方を 1 キーで切り替える -*- lexical-binding: t; -*-

;; ソートとドットファイルの表示は**マウスに経路が無い**操作なので、左手側の 1 打鍵で
;; 完結させる (キー割り当ての前提は 94_keybinds.el の冒頭を参照)。
;;
;; 細かい指定 (拡張子順・サイズ順・アクセス時刻順など) は従来どおり `s'
;; (dirvish-quicksort) のメニューを使う。こちらは日常的に往復する 2 軸だけを持つ。

(require 'cl-lib)
(require 'seq)
(require 'dired)

;;; 並び順

;; 軸と昇降順は別の操作なので、キーも分ける。1 キーで 4 状態を巡回させると
;; 目的の並びまで最大 3 回押すことになり、今どこにいるかを覚えていないと当てられない。
;;
;;   f    軸を切り替える (名前 ⇄ 更新時間)。昇降順は保つ
;;   M-f  今の軸の昇順 / 降順を切り替える

(defconst my/dired-sort-axes
  '((nil          . "名前")
    ("--sort=time" . "更新時間"))
  "`my/dired-sort-toggle-key' が往復する並び替えの軸。
スイッチの綴りは `dirvish-ls-quicksort-keys' と揃えてある。ずらすとモードラインの
ソート表示と食い違う。")

(defconst my/dired--sort-regexp "\\(--time=\\w+\\|--sort=\\w+\\|--reverse\\)\\( \\)?"
  "並び順を表す ls スイッチ。`dirvish-ls--quicksort-do-sort' と同じもの。
内部関数を直接呼ばずに写しているのは、`--' 付きの private な関数に依存すると
パッケージ更新で黙って壊れるため。")

(defun my/dired--sort-key (switches)
  "SWITCHES から並び順に関わる指定だけを取り出して正規化する。
順序を揃えるので、\"--reverse --sort=time\" と \"--sort=time --reverse\" が
同じものとして比較できる。"
  (let (found (start 0))
    (while (string-match my/dired--sort-regexp switches start)
      (push (match-string 1 switches) found)
      (setq start (match-end 0)))
    (mapconcat #'identity (sort found #'string<) " ")))

(defun my/dired--apply-sort (switches)
  "SWITCHES で並べ替える。既存の並び順指定は落としてから足す。"
  (let ((others (string-trim
                 (replace-regexp-in-string my/dired--sort-regexp ""
                                           (or dired-actual-switches "")))))
    (setq dired-actual-switches (string-trim (concat others " " switches)))
    (revert-buffer)))

(defun my/dired--reversed-p ()
  "今の並びが降順なら非 nil。"
  (and (string-match-p "--reverse" (or dired-actual-switches "")) t))

(defun my/dired--axis ()
  "今の軸を `my/dired-sort-axes' の要素で返す。
`s' (dirvish-quicksort) で拡張子順やサイズ順にしてある場合は nil を返す。"
  (let ((key (my/dired--sort-key (or dired-actual-switches ""))))
    (cond ((string-match-p "--sort=time" key) (assoc "--sort=time" my/dired-sort-axes))
          ;; --sort=extension などが入っていたら「どちらの軸でもない」
          ((string-match-p "--sort=" key) nil)
          (t (assoc nil my/dired-sort-axes)))))

(defun my/dired--sort-describe ()
  "今の並び順を人が読める形で返す。`dired-actual-switches' を見るので、
並べ替えた**後**に呼ぶこと。"
  (let* ((axis (my/dired--axis))
         (time (equal (car-safe axis) "--sort=time"))
         (rev (my/dired--reversed-p)))
    (format "%s (%s)"
            (or (cdr axis) "その他")
            (cond ((and time rev) "古い順") (time "新しい順")
                  (rev "z-a") (t "a-z")))))

(defun my/dired-sort-toggle-key ()
  "並び替えの軸を 名前 ⇄ 更新時間 で切り替える。昇順 / 降順は保つ。
`s' (dirvish-quicksort) で拡張子順やサイズ順にした後にこれを押すと、名前順に落ちる。"
  (interactive)
  (let* ((cur (my/dired--axis))
         (axis (cond
                ;; どちらの軸でもない (s で拡張子順やサイズ順にした後) → まず名前へ落とす。
                ;; ここで更新時間へ跳ばすと、どちらに行くか予測できない
                ((null cur) nil)
                ((equal (car cur) "--sort=time") nil)
                (t "--sort=time"))))
    (my/dired--apply-sort
     (string-trim (concat (or axis "") (if (my/dired--reversed-p) " --reverse" ""))))
    (message "並び順: %s" (my/dired--sort-describe))))

(defun my/dired-sort-toggle-reverse ()
  "今の軸のまま昇順 / 降順を切り替える。
軸には触らないので、`s' で拡張子順やサイズ順にした後でもその軸のまま反転する。"
  (interactive)
  (let* ((rev (my/dired--reversed-p))
         ;; 今の並び順指定から --reverse だけ抜いたもの
         (base (mapconcat #'identity
                          (seq-remove (lambda (s) (equal s "--reverse"))
                                      (split-string
                                       (my/dired--sort-key (or dired-actual-switches ""))
                                       " " t))
                          " ")))
    (my/dired--apply-sort (string-trim (concat base (if rev "" " --reverse"))))
    (message "並び順: %s" (my/dired--sort-describe))))

;;; ドットファイル

(defconst my/dired--dotfile-regexp "\\(--almost-all\\|--all\\)\\( \\)?"
  "\".\" 始まりを表示させる ls スイッチ。
短縮形 (-A / -a) は扱わない。この設定は `dired-listing-switches' も
`dirvish-ls-switches-menu' も長い綴りで統一しているため。")

(defun my/dired-toggle-dotfiles ()
  "\".\" で始まるファイルの表示を切り替える。
ls の --almost-all を出し入れして再読込する。gls (macOS) も ls-lisp (Windows) も
この綴りを解釈するので、両プラットフォームで同じ動きになる。"
  (interactive)
  (let* ((sw (or dired-actual-switches ""))
         (shown (string-match-p my/dired--dotfile-regexp sw)))
    (setq dired-actual-switches
          (string-trim
           (if shown
               (replace-regexp-in-string my/dired--dotfile-regexp "" sw)
             (concat sw " --almost-all"))))
    (revert-buffer)
    (message "ドットファイル: %s" (if shown "非表示" "表示"))))

(provide 'my-dired-view)
;;; my-dired-view.el ends here
