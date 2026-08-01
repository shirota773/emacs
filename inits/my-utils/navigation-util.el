;;; navigation-util.el --- Navigation utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; C-r で「タブローカルのバッファリスト (bufferlo)」と「recentf」をトグルし、
;; C-t で選択中の候補の位置から find-file を開始する。
;; M-j は入力位置以下を一括で候補にした補完へ、C-x C-j は同じ範囲を
;; 外部プロセスで絞り込む検索へ切り替える (両者の使い分けは下の節を参照)。

;;; Code:

;; consult の内部関数を使う。autoload が無いのでバイトコンパイル用に宣言する。
(declare-function consult--read "consult")

(defvar my/c-r-state 'recentf "State of C-r toggle: 'recentf or 'local.")

(defun my/minibuffer-exit-run (func &rest args)
  "minibuffer を閉じ、抜けた直後に FUNC を ARGS で実行する。
minibuffer 内から別の補完 UI へ開き直すため、exit 後の次のイベント
ループまで実行を遅らせる。
以前は 0.05 秒待っていたが、その待ち時間に届いたキー入力が
`minibufferp' で「minibuffer の外」と誤判定され、C-r 連打で開く UI が
安定しない原因になっていた (2026-07-31 に 0 へ短縮)。"
  (run-at-time 0 nil (lambda () (apply func args)))
  (delete-minibuffer-contents)
  (ignore-errors (exit-minibuffer)))

(defun my/find-file-in-dir (dir)
  "Start interactive `find-file` with default directory set to DIR."
  (let ((default-directory dir)) (call-interactively 'find-file)))

(defun my/consult-jump-file-command (&optional dir initial)
  "DIR 以下を再帰的にたどって 1 つのリストから絞り込み、find-file する。
`consult-dir-jump-file' (find-file 中の C-x C-j / M-j) の実体として使う。
INITIAL は入力済みのファイル名部分。

ローカルは fd を使う。find より速く、.gitignore を尊重するので
node_modules のような巨大ツリーが候補に混ざらない。fd が無い環境と
リモート (TRAMP) は consult-find (find コマンド) に落とす。リモートに
fd が入っている保証は無く、無いときに何も出ないより find の方がまし。"
  (if (and (not (file-remote-p (or dir default-directory)))
           (my/recursive-file--program))
      (consult-fd dir initial)
    (consult-find dir initial)))

;; =============================================================================
;; 起点ディレクトリ以下を一括候補にして絞り込む (M-j)
;; =============================================================================
;; find-file の「一段ずつ降りる」操作から、起点以下のファイル/ディレクトリを
;; 全部候補にした通常の補完へ切り替える。候補は起点からの相対パスなので、
;; パスの断片を空白区切りで並べて絞り込める (ivy の counsel-file-jump に近い)。
;;
;; 一括列挙で足りるかどうかは 2026-08-01 に実測した:
;;   ~/.emacs.d      53 件 / fd 0.08 秒 / 絞り込みは体感即時
;;   ~/work      18,054 件 / fd 0.11 秒 / 絞り込み 1 キーあたり 16-30ms
;;   ~ 全体     610,236 件 / fd 10.2 秒 / 実用外
;; プロジェクト単位なら一括で十分軽い。破綻するのはホーム全体のような起点だけ。
;;
;; 上限を超えたときは絞り込み検索 (C-x C-j 相当) には落とさない。あちらは
;; 「先に文字を打たないと候補が出ない」方式なので、~ のように見当が付かない
;; 起点では何を打てばいいのか分からなくなる。代わりに直下のディレクトリだけを
;; 候補に出して 1 段降りてもらい、扱える件数になるまでこれを繰り返す。
;;
;; 使い分け:
;;   M-j     一括候補 (この節)。候補は起動した時点で全部見えている。
;;   C-x C-j 絞り込み検索 (my/consult-jump-file-command)。入力を fd に渡して
;;           プロセス側で絞るので、起点がどれだけ大きくても候補を保持しない。
;;           代わりに consult-async-min-input (既定 3) 文字打つまで候補は出ない。

(defvar my/recursive-file-max 20000
  "一括候補にする上限件数。超えたら直下のディレクトリを選んで 1 段降りる。
18,054 件で 1 キーあたり 16-30ms だったので、2 万件までは体感が保てる。")

(defvar my/recursive-file-fd-args
  '("--hidden" "--exclude" ".git" "--color=never")
  "一括列挙に使う fd の共通引数。
隠しファイルは候補に含め、.git 配下と .gitignore 対象は除外する。
候補数を現実的に保つのが目的なので --no-ignore は付けない。")

(defun my/recursive-file--program ()
  "fd の実行ファイルを返す。無ければ nil。"
  (or (executable-find "fd") (executable-find "fdfind")))

(defun my/recursive-file--fd (dir type limit &optional depth)
  "DIR 以下の TYPE (\"f\" か \"d\") を相対パスで最大 LIMIT 件返す。
DEPTH を渡すとその深さまでに限る (1 なら直下だけ)。
読めないディレクトリがあると fd は非 0 で終わるが、取れた分は使う。"
  (apply #'process-lines-ignore-status
         (my/recursive-file--program)
         (append my/recursive-file-fd-args
                 (list "--base-directory" dir
                       "--type" type
                       "--max-results" (number-to-string limit))
                 (and depth (list "--max-depth" (number-to-string depth)))
                 (list "."))))

(defun my/recursive-file--subdirs (dir)
  "DIR 直下のディレクトリを末尾 / 付きの相対名で返す。"
  (mapcar (lambda (d) (if (string-suffix-p "/" d) d (concat d "/")))
          (my/recursive-file--fd dir "d" (1+ my/recursive-file-max) 1)))

(defun my/recursive-file--collect (dir)
  "DIR 以下の候補を集めて (CANDIDATES . TRUNCATED) を返す。
TRUNCATED が非 nil なら `my/recursive-file-max' を超えたということ
(候補は捨てて 1 段降りる操作に切り替える)。
ディレクトリは末尾 / でファイルと見分けられるようにする。fd 8.3 以降は
自分で付けてくるので、無いときだけ足す。

ファイルだけで上限を超えたらディレクトリは列挙しない。ホーム全体のような
起点で fd を 2 回走らせずに済み、切り替え判定が 0.5 秒 → 0.2 秒になる。"
  (let* ((limit (1+ my/recursive-file-max))
         (files (my/recursive-file--fd dir "f" limit)))
    (if (> (length files) my/recursive-file-max)
        (cons nil t)
      (let* ((dirs (mapcar (lambda (d) (if (string-suffix-p "/" d) d (concat d "/")))
                           (my/recursive-file--fd dir "d" limit)))
             (cands (append files dirs)))
        (if (> (length cands) my/recursive-file-max)
            (cons nil t)
          (cons cands nil))))))

(defun my/recursive-file--read (prompt cands &optional initial)
  "PROMPT で CANDS から 1 つ選ぶ。INITIAL は初期入力。
consult--read は内部関数で autoload されないため、ここで consult を
require してから使う。これが無いと consult 未ロードのまま M-j を押したとき
void-function consult--read で落ちる。"
  (require 'consult)
  (consult--read cands
                 :prompt prompt
                 :category 'file
                 :require-match t
                 :initial initial
                 :history 'file-name-history))

(defun my/recursive-file--descend (dir initial)
  "DIR 直下のディレクトリを 1 つ選ばせ、その下で一括候補をやり直す。
起点が広すぎて一括では扱えないときの操作。いきなり絞り込み検索に落とすと
「まず何か打たないと候補が出ない」状態になり、~ のように見当の付かない
起点では手掛かりが無くなるので、代わりに 1 段ずつ降りて件数を落とす。

直下にディレクトリが無いのに超過している (1 ディレクトリにファイルが
2 万件以上ある) ときだけ、絞り込み検索に頼る。"
  (let ((subdirs (my/recursive-file--subdirs dir)))
    (if (null subdirs)
        (progn
          (message "No subdirectory under %s, falling back to search"
                   (abbreviate-file-name dir))
          (my/consult-jump-file-command dir initial))
      (let* ((default-directory dir)
             (choice (my/recursive-file--read
                      (format "Descend under %s (over %d entries): "
                              (abbreviate-file-name dir) my/recursive-file-max)
                      subdirs)))
        (my/find-file-recursive (expand-file-name choice dir) initial)))))

(defun my/find-file-recursive (&optional dir initial)
  "DIR 以下のファイルとディレクトリを一括で候補にして開く。
INITIAL は初期入力。候補は DIR からの相対パスなので、パスの断片を
空白区切りで並べて絞り込める。ディレクトリを選べば dired が開く。

候補が `my/recursive-file-max' を超えたら `my/recursive-file--descend' で
1 段降りてやり直す。リモート (TRAMP) と fd 不在のときだけ
`my/consult-jump-file-command' (絞り込み検索) に委譲する。"
  (interactive)
  (let ((dir (file-name-as-directory (expand-file-name (or dir default-directory)))))
    (if (or (file-remote-p dir) (not (my/recursive-file--program)))
        ;; リモートは一括列挙が遅すぎるうえ fd がある保証も無い
        (my/consult-jump-file-command dir initial)
      (let* ((result (my/recursive-file--collect dir))
             (cands (car result)))
        (cond
         ((cdr result) (my/recursive-file--descend dir initial))
         ((null cands)
          (user-error "No files under %s" (abbreviate-file-name dir)))
         (t
          ;; default-directory を起点に束縛してから consult--read を呼ぶ。
          ;; 候補が相対パスなので、選択後の展開がこれで揃う。
          ;;
          ;; プレビューは付けない。候補にディレクトリが混ざる以上、カーソルが
          ;; 乗るたびに dired バッファが作られてウィンドウが切り替わり、C-g で
          ;; 抜けてもバッファが残る。選ぶ前に中身を見たい場面より邪魔な場面の
          ;; 方が多いと判断した。
          ;;
          ;; 絞り込みスタイルは触らない。この設定は file カテゴリを
          ;; basic/partial-completion に上書きしている (02_packages.el) が、
          ;; completion--styles は override を completion-styles と「置き換え」ではなく
          ;; 「前置して結合」するので、パス区切りの部分補完が効きつつ
          ;; orderless の空白 AND 検索も後段で効く (実測確認済み)。
          (let* ((default-directory dir)
                 (choice (my/recursive-file--read
                          (format "Find file under %s: " (abbreviate-file-name dir))
                          cands initial)))
            (find-file (expand-file-name choice dir)))))))))

(defun my/vertico-find-file-recursive ()
  "find-file の入力位置以下を一括候補にした補完へ切り替える。
プロンプトのディレクトリ部分を起点、ファイル名部分を初期入力として引き継ぐ。"
  (interactive)
  (unless (minibufferp) (user-error "Not in minibuffer"))
  (let* ((content (substitute-in-file-name (minibuffer-contents)))
         (dir (or (file-name-directory content) default-directory))
         (initial (file-name-nondirectory content)))
    (my/minibuffer-exit-run #'my/find-file-recursive dir initial)))

(defun my/local-buffer-or-recentf ()
  "Toggle between recentf and tab-local (bufferlo) buffer list."
  (interactive)
  (if (not (minibufferp))
      (progn (setq my/c-r-state 'local) (call-interactively 'bufferlo-switch-to-buffer))
    (setq my/c-r-state (if (eq my/c-r-state 'recentf) 'local 'recentf))
    (my/minibuffer-exit-run
     (if (eq my/c-r-state 'recentf) (if (fboundp 'consult-recentf) #'consult-recentf #'consult-buffer)
       #'bufferlo-switch-to-buffer))))

(defun my/candidate-directory (cand)
  "補完候補 CAND から find-file の起点ディレクトリを求める。決まらなければ nil。
候補の形だけで判定するので、recentf とバッファリストのどちらを開いて
いても同じ意味で動く。
以前は `my/c-r-state' で分岐していたが、状態変数と実際に開いている UI が
ズレるとバッファ名を `expand-file-name' に渡してしまい、カーソル位置と
無関係なディレクトリ (default-directory 基準) を返していた。"
  (when (and (stringp cand) (not (string-empty-p cand)))
    (cond
     ;; recentf / consult-recentf の候補。"~/..." も絶対パス扱いになる
     ((file-name-absolute-p cand)
      (file-name-directory (expand-file-name cand)))
     ;; bufferlo-switch-to-buffer の候補 (バッファ名)
     ((get-buffer cand)
      (buffer-local-value 'default-directory (get-buffer cand))))))

(defun my/recentf-directories ()
  "recentf に含まれるディレクトリを重複なしで返す。"
  (let ((files (and (boundp 'recentf-list) recentf-list)))
    (delete-dups (seq-filter #'file-directory-p
                             (mapcar #'file-name-directory files)))))

(defun my/vertico-select-directory-from-candidates ()
  "選択中の候補の位置から find-file を開始する。
候補から起点が決められないときは recentf のディレクトリ一覧から選ぶ。"
  (interactive)
  (unless (minibufferp) (user-error "Not in minibuffer"))
  (let ((dir (my/candidate-directory (vertico--candidate))))
    (if dir
        (my/minibuffer-exit-run #'my/find-file-in-dir dir)
      (let ((dirs (my/recentf-directories)))
        (if (null dirs)
            (message "No dirs found")
          (my/minibuffer-exit-run
           (lambda (ds) (my/find-file-in-dir
                         (if (= (length ds) 1) (car ds)
                           (completing-read "Select directory: " ds nil t))))
           dirs))))))

(provide 'navigation-util)
;;; navigation-util.el ends here
