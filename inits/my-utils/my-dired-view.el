;;; my-dired-view.el --- 一覧の見え方を 1 キーで切り替える -*- lexical-binding: t; -*-

;; ソートとドットファイルの表示は**マウスに経路が無い**操作なので、左手側の 1 打鍵で
;; 完結させる (キー割り当ての前提は 94_keybinds.el の冒頭を参照)。
;;
;; 細かい指定 (拡張子順・サイズ順・アクセス時刻順など) は従来どおり `s'
;; (dirvish-quicksort) のメニューを使う。こちらは日常的に往復する 2 軸だけを持つ。

(require 'cl-lib)
(require 'dired)

;;; 並び順

(defconst my/dired-sort-cycle
  '((""                     . "名前 (a-z)")
    ("--reverse"            . "名前 (z-a)")
    ("--sort=time"          . "更新時間 (新しい順)")
    ("--sort=time --reverse" . "更新時間 (古い順)"))
  "`my/dired-sort-next' が巡回する並び順。
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

(defun my/dired-sort-next ()
  "並び順を 名前↑ → 名前↓ → 更新時間↓ → 更新時間↑ の順に切り替える。
`s' (dirvish-quicksort) で拡張子順やサイズ順にした後にこれを押すと、
巡回の先頭 (名前 a-z) へ戻る。"
  (interactive)
  (let* ((cur (my/dired--sort-key (or dired-actual-switches "")))
         (pos (cl-position cur my/dired-sort-cycle
                           :key (lambda (e) (my/dired--sort-key (car e)))
                           :test #'equal))
         (next (nth (if pos (mod (1+ pos) (length my/dired-sort-cycle)) 0)
                    my/dired-sort-cycle)))
    (my/dired--apply-sort (car next))
    (message "並び順: %s" (cdr next))))

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
