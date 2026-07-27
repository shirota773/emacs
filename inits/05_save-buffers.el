;;; 05_save-buffers.el --- 未保存バッファの一括処理 -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs の終了時や M-x grep / compile の実行時に走る `save-some-buffers' は、
;; 未保存バッファを 1 個ずつミニバッファで聞いてくる。数が多いと「あと何個
;; 残っているのか」が分からないまま y/n を打ち続けることになるので、対象が
;; 複数あるときだけ dired 風の一覧 (*Unsaved Buffers*) に差し替える。
;;
;;   s     保存する            (マーク S)
;;   d     変更を捨てて kill   (マーク D)
;;   u     マーク解除
;;   x     マークを実行して先へ進む
;;   q C-g 中止 (終了や grep そのものを取りやめる)
;;
;; マークを付けなかったバッファは「無視」= 変更を残したまま何もしない。
;; したがって x をマーク無しで押せば「全部そのままで先へ進む」になる。
;; 件数の内訳とキーの説明はヘッダー行に出しているので、残りが何個かは一覧を
;; 見れば分かる (これが元の不満点への回答)。
;;
;; ★ q は「中止」であって「続行」ではない
;;   一覧 UI の q は普通そこから抜けるキーなので、続行 (= 終了処理が先へ
;;   進む) に割り当てると、終了しようとして q を押した人から見て Emacs が
;;   いきなり終わったように見える。先へ進めるのは x だけにしてある。
;;
;; ★ なぜ recursive-edit を使うか
;;   `save-some-buffers' は同期関数で、呼び出し元 (`save-buffers-kill-emacs'
;;   や `compilation-start') はその戻りを待って処理を続ける。一覧 UI で操作を
;;   待つには制御を返さずにコマンドループを回すしかないので `recursive-edit'
;;   を使う。モードラインの [] が再帰編集中の目印。
;;   一覧の中では C-g を `abort-recursive-edit' に割り当ててある (素の C-g =
;;   `keyboard-quit' は再帰編集を抜けないため、押しても何も起きない)。
;;   一覧から別のバッファへ移ってしまった場合の最後の逃げ道は、どこでも効く
;;   C-] か M-x abort-recursive-edit 。
;;
;; ★ なぜ元の `save-some-buffers' を潰さないか
;;   一覧で処理した後に元関数を呼び直している。abbrev の保存
;;   (`save-some-buffers-functions') や `buffer-save-without-query' の自動保存を
;;   落とさないため。一覧で無視したバッファは述語で除外して、元関数に二重で
;;   聞かれないようにしている。
;;
;; ★ 終了時にもう 1 回だけ聞かれるのは仕様
;;   無視したバッファを残したまま x で先へ進んだ場合、`save-buffers-kill-emacs'
;;   が最後に "Modified buffers exist; exit anyway?" を聞く。これは Emacs 側の
;;   最終確認で 1 回だけなので残してある (N 個聞かれるのが問題であって、
;;   1 個は安全側)。

;;; Code:

(require 'tabulated-list)
(require 'seq)

(defgroup my/unsaved-buffers nil
  "未保存バッファを一覧でまとめて処理する。"
  :group 'files
  :prefix "my/unsaved-buffers-")

(defcustom my/unsaved-buffers-menu-enabled t
  "非 nil なら `save-some-buffers' を一覧 UI に差し替える。
nil にすると Emacs 標準の 1 個ずつ聞く挙動に戻る。"
  :type 'boolean
  :group 'my/unsaved-buffers)

(defcustom my/unsaved-buffers-threshold 2
  "一覧 UI に切り替える未保存バッファ数のしきい値。
これ未満なら標準の y-or-n-p のままにする (1 個なら一覧を出すより速いため)。"
  :type 'integer
  :group 'my/unsaved-buffers)

(defconst my/unsaved-buffers--name "*Unsaved Buffers*"
  "一覧バッファの名前。")

(defvar my/unsaved-buffers--active nil
  "一覧 UI の実行中は非 nil。advice の再入防止に使う。")

(defvar-local my/unsaved-buffers--targets nil
  "一覧に出しているバッファのリスト。")

(defvar-local my/unsaved-buffers--marks nil
  "バッファ → `save' / `kill' のマークを保持するハッシュ表。")

;; -----------------------------------------------------------------------------
;; 対象バッファの収集
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--normalize-pred (pred)
  "PRED を `save-some-buffers' と同じ規則で正規化する。
nil なら `save-some-buffers-default-predicate' を採用する。元関数の
先頭にある処理と同じことをしている (元関数へ渡し直す前に確定させたい)。"
  (or pred
      (if (and (symbolp save-some-buffers-default-predicate)
               (get save-some-buffers-default-predicate
                    'save-some-buffers-function))
          (funcall save-some-buffers-default-predicate)
        save-some-buffers-default-predicate)))

(defun my/unsaved-buffers--candidates (pred)
  "PRED のもとで保存を聞かれるバッファのリストを返す。

対象の判定は `files--buffers-needing-to-be-saved' に任せる。同じ条件
(modified / indirect でない / ファイル訪問 or buffer-offer-save) を自前で
書くと本体の変更に追従できないため。
`buffer-save-without-query' のバッファは元関数が問答無用で保存するので、
一覧に出しても意味がなく除く。"
  (seq-remove (lambda (buf)
                (buffer-local-value 'buffer-save-without-query buf))
              (files--buffers-needing-to-be-saved pred)))

;; -----------------------------------------------------------------------------
;; 一覧バッファ (tabulated-list-mode)
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--mark-string (buffer)
  "BUFFER のマーク列の表示文字列を返す。"
  (pcase (gethash buffer my/unsaved-buffers--marks)
    ('save (propertize "S" 'face 'success))
    ('kill (propertize "D" 'face 'error))
    (_ " ")))

(defun my/unsaved-buffers--place-string (buffer)
  "BUFFER の場所 (ファイルパス) の表示文字列を返す。"
  (let ((file (buffer-file-name buffer)))
    (if file
        (abbreviate-file-name file)
      (propertize "(ファイル無し)" 'face 'shadow))))

(defun my/unsaved-buffers--entries ()
  "`tabulated-list-entries' 用の行データを返す。

関数として登録しておくと `tabulated-list-print' のたびに呼ばれるので、
マークを付け替えた後の再描画で表示が自動的に追いつく。
ついでに死んだバッファをここで一覧から落とす。"
  (setq my/unsaved-buffers--targets
        (seq-filter #'buffer-live-p my/unsaved-buffers--targets))
  (mapcar (lambda (buf)
            (list buf
                  (vector (my/unsaved-buffers--mark-string buf)
                          (buffer-name buf)
                          (file-size-human-readable (buffer-size buf))
                          (my/unsaved-buffers--place-string buf))))
          my/unsaved-buffers--targets))

(defconst my/unsaved-buffers--key-hint
  "s:保存  d:破棄  u:解除  x:実行して先へ  q/C-g:中止  =:差分"
  "ヘッダー行に常時出すキーの説明。")

(defun my/unsaved-buffers--summary ()
  "マークの内訳文字列を返す。"
  (let ((save 0) (kill 0) (total 0))
    (dolist (buf my/unsaved-buffers--targets)
      (when (buffer-live-p buf)
        (setq total (1+ total))
        (pcase (gethash buf my/unsaved-buffers--marks)
          ('save (setq save (1+ save)))
          ('kill (setq kill (1+ kill))))))
    (format "保存%d 破棄%d 無視%d / 全%d"
            save kill (- total save kill) total)))

(defun my/unsaved-buffers--update-header ()
  "ヘッダー行に内訳とキーの説明を出す。

`:eval' を使わず、マークを変えるたびに文字列を作り直して入れている。
モードライン/ヘッダー行の構文は変数が risky でないと `:eval' を評価しない
という条件があり、そこに依存したくないため。"
  (setq header-line-format
        (concat " " (my/unsaved-buffers--summary)
                "   " my/unsaved-buffers--key-hint))
  (force-mode-line-update))

(defvar my/unsaved-buffers-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s")   #'my/unsaved-buffers-mark-save)
    (define-key map (kbd "d")   #'my/unsaved-buffers-mark-kill)
    (define-key map (kbd "u")   #'my/unsaved-buffers-unmark)
    (define-key map (kbd "DEL") #'my/unsaved-buffers-unmark-backward)
    (define-key map (kbd "S")   #'my/unsaved-buffers-mark-all-save)
    (define-key map (kbd "D")   #'my/unsaved-buffers-mark-all-kill)
    (define-key map (kbd "U")   #'my/unsaved-buffers-unmark-all)
    (define-key map (kbd "x")   #'my/unsaved-buffers-execute)
    ;; 中止は q と C-g の両方で。素の C-g (keyboard-quit) は再帰編集を
    ;; 抜けないので、ここで明示的に潰しておかないと押しても何も起きない
    (define-key map (kbd "q")   #'my/unsaved-buffers-abort)
    (define-key map (kbd "C-g") #'my/unsaved-buffers-abort)
    (define-key map (kbd "RET") #'my/unsaved-buffers-show)
    (define-key map (kbd "o")   #'my/unsaved-buffers-show)
    (define-key map (kbd "=")   #'my/unsaved-buffers-diff)
    ;; j/k での移動は Buffer-menu / grep-mode と揃える (94_keybinds.el 参照)
    (define-key map (kbd "j")   #'next-line)
    (define-key map (kbd "k")   #'previous-line)
    map)
  "`my/unsaved-buffers-mode' のキーマップ。")

(define-derived-mode my/unsaved-buffers-mode tabulated-list-mode "Unsaved"
  "未保存バッファを一覧して保存 / 破棄 / 無視をまとめて指定するモード。

\\{my/unsaved-buffers-mode-map}"
  (setq tabulated-list-format
        [("M" 1 nil)
         ("Buffer" 30 t)
         ("Size" 8 nil :right-align t)
         ("File" 0 t)])
  (setq tabulated-list-padding 1)
  (setq tabulated-list-sort-key '("Buffer" . nil))
  (setq tabulated-list-entries #'my/unsaved-buffers--entries)
  ;; ヘッダー行は件数とキーの説明に使いたいので、列見出しはバッファ本文へ回す
  (setq-local tabulated-list-use-header-line nil)
  (tabulated-list-init-header))

;; -----------------------------------------------------------------------------
;; マーク操作
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--forward-line (n)
  "N 行移動する。移動先が行データの無い行 (列見出しや末尾) なら動かない。"
  (let ((start (point)))
    (forward-line n)
    (unless (tabulated-list-get-id)
      (goto-char start))))

(defun my/unsaved-buffers--set-mark (mark)
  "カーソル行のバッファに MARK を付け (nil なら外し)、次の行へ移る。"
  (let ((buf (tabulated-list-get-id)))
    (unless buf
      (user-error "この行にバッファがありません"))
    (if mark
        (puthash buf mark my/unsaved-buffers--marks)
      (remhash buf my/unsaved-buffers--marks))
    (tabulated-list-set-col 0 (my/unsaved-buffers--mark-string buf) t)
    (my/unsaved-buffers--update-header)
    (my/unsaved-buffers--forward-line 1)))

(defun my/unsaved-buffers-mark-save ()
  "カーソル行のバッファを保存対象にする。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-mark 'save))

(defun my/unsaved-buffers-mark-kill ()
  "カーソル行のバッファを「変更を捨てて kill」の対象にする。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-mark 'kill))

(defun my/unsaved-buffers-unmark ()
  "カーソル行のマークを外す (= 無視する)。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-mark nil))

(defun my/unsaved-buffers-unmark-backward ()
  "1 行戻ってマークを外す。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--forward-line -1)
  (my/unsaved-buffers--set-mark nil)
  (my/unsaved-buffers--forward-line -1))

(defun my/unsaved-buffers--set-all (mark)
  "一覧の全バッファに MARK を付ける (nil なら全解除)。"
  (dolist (buf my/unsaved-buffers--targets)
    (if mark
        (puthash buf mark my/unsaved-buffers--marks)
      (remhash buf my/unsaved-buffers--marks)))
  (tabulated-list-print t)
  (my/unsaved-buffers--update-header))

(defun my/unsaved-buffers-mark-all-save ()
  "全部を保存対象にする。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-all 'save))

(defun my/unsaved-buffers-mark-all-kill ()
  "全部を kill 対象にする。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-all 'kill))

(defun my/unsaved-buffers-unmark-all ()
  "全部のマークを外す。"
  (interactive nil my/unsaved-buffers-mode)
  (my/unsaved-buffers--set-all nil))

;; -----------------------------------------------------------------------------
;; 中身の確認
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers-show ()
  "カーソル行のバッファを別ウィンドウに表示する (一覧に留まる)。"
  (interactive nil my/unsaved-buffers-mode)
  (let ((buf (tabulated-list-get-id)))
    (unless (buffer-live-p buf)
      (user-error "このバッファはもうありません"))
    (display-buffer buf)))

(defun my/unsaved-buffers-diff ()
  "カーソル行のバッファとファイルの差分を表示する。"
  (interactive nil my/unsaved-buffers-mode)
  (let ((buf (tabulated-list-get-id)))
    (unless (buffer-live-p buf)
      (user-error "このバッファはもうありません"))
    (unless (buffer-file-name buf)
      (user-error "ファイルを訪問していないので差分が取れません"))
    (with-current-buffer buf
      (diff-buffer-with-file))))

;; -----------------------------------------------------------------------------
;; 実行 / 終了
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--finish ()
  "一覧を閉じて呼び出し元 (終了処理や grep) を先へ進める。"
  (if my/unsaved-buffers--active
      (exit-recursive-edit)
    (quit-window t)))

(defun my/unsaved-buffers--marked (mark)
  "MARK が付いた生存バッファのリストを返す。"
  (seq-filter (lambda (buf)
                (and (buffer-live-p buf)
                     (eq (gethash buf my/unsaved-buffers--marks) mark)))
              my/unsaved-buffers--targets))

(defun my/unsaved-buffers-execute ()
  "マークを実行して先へ進む。マークの無いバッファは何もしない (無視)。
マークが 1 つも無ければ「全部そのままで先へ進む」になる。"
  (interactive nil my/unsaved-buffers-mode)
  (let* ((saves (my/unsaved-buffers--marked 'save))
         (kills (my/unsaved-buffers--marked 'kill))
         (ignored (- (length (seq-filter #'buffer-live-p
                                         my/unsaved-buffers--targets))
                     (length saves) (length kills)))
         (killed 0))
    ;; 破棄は取り返しがつかないのでまとめて 1 回だけ確認する
    (when (and kills
               (not (yes-or-no-p
                     (format "%d 個のバッファの変更を破棄して kill します。よろしいですか? "
                             (length kills)))))
      (user-error "中止しました"))
    (dolist (buf saves)
      (with-current-buffer buf
        (save-buffer)))
    (dolist (buf kills)
      ;; modified フラグを落とさないと kill-buffer が 1 個ずつ確認してくる。
      ;; kill に失敗した (hook に止められた) ときはフラグを戻す。落としたまま
      ;; 放置すると、次に終了するとき警告なしで変更が消えてしまうため
      (with-current-buffer buf (set-buffer-modified-p nil))
      (if (kill-buffer buf)
          (setq killed (1+ killed))
        (with-current-buffer buf (set-buffer-modified-p t))))
    (message "保存 %d 件 / kill %d 件 / 無視 %d 件"
             (length saves) killed ignored))
  (my/unsaved-buffers--finish))

(defun my/unsaved-buffers-abort ()
  "何もせずに中止する。呼び出し元 (Emacs の終了や grep) も取りやめになる。"
  (interactive nil my/unsaved-buffers-mode)
  (if my/unsaved-buffers--active
      (abort-recursive-edit)
    (quit-window t)))

;; -----------------------------------------------------------------------------
;; 入口
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--display (targets)
  "TARGETS を一覧バッファに用意して表示し、そのバッファを返す。"
  (let ((buf (get-buffer-create my/unsaved-buffers--name)))
    (with-current-buffer buf
      ;; derived mode は kill-all-local-variables を通るので、状態の代入は
      ;; モードを立ち上げた後に行う
      (my/unsaved-buffers-mode)
      (setq my/unsaved-buffers--targets targets)
      (setq my/unsaved-buffers--marks (make-hash-table :test #'eq))
      (tabulated-list-print)
      (my/unsaved-buffers--update-header)
      ;; 列見出しをバッファ本文に出しているので、1 行目ではなく最初の
      ;; データ行にカーソルを置く
      (goto-char (point-min))
      (unless (tabulated-list-get-id)
        (forward-line 1)))
    (pop-to-buffer buf '((display-buffer-at-bottom)
                         (window-height . 0.4)))
    buf))

(defun my/unsaved-buffers--run (targets)
  "TARGETS の一覧を出し、操作が終わるまで待つ。
戻った時点で生きていて変更が残っているものが「無視されたバッファ」。"
  (let ((config (current-window-configuration))
        (my/unsaved-buffers--active t)
        (buf nil))
    (unwind-protect
        (progn
          (setq buf (my/unsaved-buffers--display targets))
          (recursive-edit))
      (set-window-configuration config)
      (when (buffer-live-p buf)
        (kill-buffer buf)))))

;;;###autoload
(defun my/list-unsaved-buffers ()
  "未保存バッファの一覧を出して、保存 / 破棄 / 無視をまとめて指定する。"
  (interactive)
  (let ((targets (my/unsaved-buffers--candidates
                  (my/unsaved-buffers--normalize-pred nil))))
    (unless targets
      (user-error "未保存のバッファはありません"))
    (my/unsaved-buffers--run targets)))

;; -----------------------------------------------------------------------------
;; save-some-buffers への接続
;; -----------------------------------------------------------------------------

(defun my/unsaved-buffers--pred-excluding (pred buffers)
  "PRED に BUFFERS を除外する条件を足した述語を返す。

一覧で「無視」を選んだものを元の `save-some-buffers' がもう一度聞いてくる
のを防ぐためのもの。PRED が nil のときにファイル訪問バッファへ絞り直して
いるのは、ここで関数を渡すと PRED が非 nil になり、本来対象外だった
`buffer-offer-save' のバッファまで対象に入ってしまうため。"
  (lambda ()
    (and (not (memq (current-buffer) buffers))
         (cond ((functionp pred) (funcall pred))
               ((null pred) (and buffer-file-name t))
               (t t)))))

(defun my/unsaved-buffers--use-menu-p (arg)
  "一覧 UI に差し替えてよい状況なら非 nil を返す。ARG は保存の前置引数。"
  (and my/unsaved-buffers-menu-enabled
       (null arg)                       ; C-u 付きは「全部保存」なので聞かない
       (not noninteractive)             ; バッチでは recursive-edit できない
       (not executing-kbd-macro)
       (not my/unsaved-buffers--active) ; 一覧の中からの再入を防ぐ
       (zerop (minibuffer-depth))       ; ミニバッファ内からは標準動作のまま
       (fboundp 'files--buffers-needing-to-be-saved)))

(defun my/unsaved-buffers--save-some-buffers (orig &optional arg pred)
  "`save-some-buffers' を一覧 UI に差し替える :around advice。
ORIG は元の関数、ARG と PRED はその引数。"
  (if (not (my/unsaved-buffers--use-menu-p arg))
      (funcall orig arg pred)
    (let* ((pred (my/unsaved-buffers--normalize-pred pred))
           (targets (my/unsaved-buffers--candidates pred)))
      (if (< (length targets) my/unsaved-buffers-threshold)
          (funcall orig arg pred)
        (my/unsaved-buffers--run targets)
        ;; 一覧で無視されたもの = まだ生きていて変更が残っているもの。
        ;; これを除外したうえで元関数を通し、abbrev の保存などを任せる
        (funcall orig arg
                 (my/unsaved-buffers--pred-excluding
                  pred (seq-filter #'buffer-live-p targets)))))))

(advice-add 'save-some-buffers :around #'my/unsaved-buffers--save-some-buffers)

(provide '05_save-buffers)
;;; 05_save-buffers.el ends here
