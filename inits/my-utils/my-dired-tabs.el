;;; my-dired-tabs.el --- ファイラ専用のタブ -*- lexical-binding: t; -*-

;; ブラウザと同じ意味のタブを dired に与える。
;;
;;   タブ = 「現在地 + 戻るスタック + 進むスタック」
;;
;; タブはバッファではなく**自前のデータ**であることが肝心。dirvish は同じ
;; ディレクトリのバッファを `dv-roots' で再利用するので、「タブ = バッファ」に
;; すると、既に別タブで開いているフォルダへ移動したときにそのタブへ飛んでしまう。
;; タブを切り離しておけば、バッファが共有されても現在地だけが変わる。
;;
;; 戻る/進むも dirvish-history-go-* は使わない。あちらは「セッションの訪問済み
;; ディレクトリの固定リストをインデックス移動する」実装で、タブをまたいで飛ぶ。
;;
;; ウィンドウ単位ではなく Emacs 全体で 1 組だけ持つ。bufferlo の tab-bar とは
;; 別レイヤー (こちらは tab-line) なので互いに干渉しない。

(require 'cl-lib)
(require 'dired)
(require 'tab-line)

(cl-defstruct (my/dired-tab (:constructor my/dired-tab--make)
                            (:conc-name my/dired-tab--)
                            (:copier nil))
  "ファイラのタブ 1 つぶん。"
  (dir nil)      ; 現在地 (末尾スラッシュ付きの絶対パス)
  (back nil)     ; 戻るスタック (新しいものが先頭)
  (forward nil)  ; 進むスタック (新しいものが先頭)
  (window nil))  ; このタブを映しているウィンドウ (履歴の取り違え防止用)

(defvar my/dired-tabs nil
  "タブのリスト。表示順。")

(defvar my/dired-tab-current nil
  "選択中のタブ。")

(defvar my/dired-tab--navigating nil
  "戻る・進む・タブ切替の最中は非 nil。
この間は移動を履歴に記録しない (二重記録の防止)。")

;;; 基本操作

(defun my/dired-tab--norm (dir)
  "DIR を比較用に正規化する。"
  (file-name-as-directory (expand-file-name dir)))

(defun my/dired-tab--ensure ()
  "タブが無ければ今の場所で 1 つ作る。カレントが外れていれば直す。"
  (unless my/dired-tabs
    (let ((tab (my/dired-tab--make :dir (my/dired-tab--norm default-directory))))
      (setq my/dired-tabs (list tab)
            my/dired-tab-current tab)))
  (unless (memq my/dired-tab-current my/dired-tabs)
    (setq my/dired-tab-current (car my/dired-tabs)))
  my/dired-tab-current)

(defun my/dired-tab--side-window-p (&optional window)
  "WINDOW がサイドウィンドウなら非 nil。
`dirvish-side' や Bookmark サイドバーはファイラ本体ではないので、
タブの現在地としては扱わない。"
  (window-parameter (or window (selected-window)) 'window-side))

(defun my/dired-tab--claim-window (tab)
  "今のウィンドウを TAB の持ち主にする。"
  (unless (my/dired-tab--side-window-p)
    (setf (my/dired-tab--window tab) (selected-window))))

(defun my/dired-tab--own-window-p (tab)
  "今のウィンドウが TAB の持ち主なら非 nil。
持ち主がまだ無い / 閉じられた / dired を映さなくなった場合は、
今のウィンドウが引き継ぐ。2 画面 dired で、片方を覗いただけの移動を
もう片方の履歴に混ぜないための判定。"
  (let ((owner (my/dired-tab--window tab)))
    (cond
     ((eq owner (selected-window)) t)
     ((or (null owner)
          (not (window-live-p owner))
          (not (with-current-buffer (window-buffer owner)
                 (derived-mode-p 'dired-mode))))
      (my/dired-tab--claim-window tab)
      t))))

(defun my/dired-tab--visit (dir)
  "DIR へ移動する。履歴には記録しない (呼び出し側が面倒を見る)。"
  (let ((my/dired-tab--navigating t))
    (dired dir))
  (when my/dired-tab-current
    (my/dired-tab--claim-window my/dired-tab-current))
  (force-mode-line-update t))

(defun my/dired-tab--sync ()
  "今いる場所をカレントタブに反映する。dired バッファの `post-command-hook' 用。
どの経路 (RET / l / ^ / パンくず / subtree / dired-jump / consult-dir) で
移動しても拾えるよう、コマンドのたびに `default-directory' を突き合わせる。

`post-command-hook' はバッファローカルなので、**移動していなくても**別の
dired バッファへフォーカスが移っただけで走る。そのままだとサイドバーを覗いたり
2 画面 dired を行き来しただけで戻るスタックが伸びるので、
「今のウィンドウがこのタブの持ち主か」を確かめてから記録する。"
  (when (and (derived-mode-p 'dired-mode)
             (not my/dired-tab--navigating)
             ;; post-command-hook は選択されていないウィンドウのバッファでも
             ;; 走りうるので、実際に見ている一覧だけを対象にする
             (eq (current-buffer) (window-buffer (selected-window)))
             (not (my/dired-tab--side-window-p)))
    ;; タブがまだ無ければここで作る。`my/dired-tabs' が非 nil であることを
    ;; 条件にすると、起動直後の 1 回目が拾えない。
    (let ((tab (my/dired-tab--ensure))
          (dir (my/dired-tab--norm default-directory)))
      (when (and (my/dired-tab--own-window-p tab)
                 (not (equal dir (my/dired-tab--dir tab))))
        (push (my/dired-tab--dir tab) (my/dired-tab--back tab))
        (setf (my/dired-tab--forward tab) nil)
        (setf (my/dired-tab--dir tab) dir)
        (force-mode-line-update t)))))

;;; コマンド

(defun my/dired-tab-open-dir-in-new-tab (dir)
  "DIR を新しいタブで開く。今のタブは残る。"
  (let* ((dir (my/dired-tab--norm dir))
         (tab (my/dired-tab--make :dir dir))
         (pos (1+ (or (cl-position my/dired-tab-current my/dired-tabs) -1))))
    ;; 今のタブの隣に挿す (ブラウザと同じ)
    (setq my/dired-tabs (append (seq-take my/dired-tabs pos)
                                (list tab)
                                (seq-drop my/dired-tabs pos)))
    (setq my/dired-tab-current tab)
    (my/dired-tab--visit dir)))

(defun my/dired-tab-goto (tab)
  "TAB へ切り替える。"
  (my/dired-tab--ensure)
  (setq my/dired-tab-current tab)
  (my/dired-tab--visit (my/dired-tab--dir tab)))

(defun my/dired-tab-go-back ()
  "今のタブで一つ戻る。"
  (interactive)
  (let ((tab (my/dired-tab--ensure)))
    (unless (my/dired-tab--back tab)
      (user-error "これ以上戻れません"))
    (push (my/dired-tab--dir tab) (my/dired-tab--forward tab))
    (setf (my/dired-tab--dir tab) (pop (my/dired-tab--back tab)))
    (my/dired-tab--visit (my/dired-tab--dir tab))))

(defun my/dired-tab-go-forward ()
  "今のタブで一つ進む。"
  (interactive)
  (let ((tab (my/dired-tab--ensure)))
    (unless (my/dired-tab--forward tab)
      (user-error "これ以上進めません"))
    (push (my/dired-tab--dir tab) (my/dired-tab--back tab))
    (setf (my/dired-tab--dir tab) (pop (my/dired-tab--forward tab)))
    (my/dired-tab--visit (my/dired-tab--dir tab))))

(defun my/dired-tab-close (tab)
  "TAB を閉じる。バッファは消さない (他のタブや dirvish の履歴が使っている)。"
  ;; tab-line のクロージャは描画時のタブを掴んだままなので、既に閉じたタブが
  ;; 渡ってくることがある。そのまま進むと cl-position が nil を返して落ちる。
  (unless (memq tab my/dired-tabs)
    (user-error "そのタブは既に閉じられています"))
  (when (<= (length my/dired-tabs) 1)
    (user-error "最後のタブは閉じられません"))
  (let ((pos (cl-position tab my/dired-tabs))
        (was-current (eq tab my/dired-tab-current)))
    (setq my/dired-tabs (delq tab my/dired-tabs))
    (when was-current
      (my/dired-tab-goto (nth (min pos (1- (length my/dired-tabs))) my/dired-tabs)))
    (force-mode-line-update t)))

(defun my/dired-tab-close-current ()
  "今のタブを閉じる。"
  (interactive)
  (my/dired-tab-close (my/dired-tab--ensure)))

(defun my/dired-tab--step (n)
  "N 個先のタブへ移る (負なら手前)。"
  (my/dired-tab--ensure)
  (let* ((len (length my/dired-tabs))
         (pos (cl-position my/dired-tab-current my/dired-tabs)))
    (my/dired-tab-goto (nth (mod (+ pos n) len) my/dired-tabs))))

(defun my/dired-tab-next ()
  "次のタブへ移る。"
  (interactive)
  (my/dired-tab--step 1))

(defun my/dired-tab-prev ()
  "前のタブへ移る。"
  (interactive)
  (my/dired-tab--step -1))

;;; tab-line への受け渡し

(defun my/dired-tab--label (tab)
  "TAB の表示名。カレントが一目で分かるよう印を付ける。"
  (let* ((dir (my/dired-tab--dir tab))
         (base (file-name-nondirectory (directory-file-name dir)))
         (base (if (string-empty-p base) "/" base)))
    (if (eq tab my/dired-tab-current)
        (concat " ▶ " base " ")
      (concat "   " base " "))))

(defun my/dired-tab-line-tabs ()
  "`tab-line-tabs-function' 用。バッファではなく alist のタブを返す。
`buffer' キーを付けないのは、付けると tab-line がバッファ切替に落ちて
dirvish のバッファ再利用に引きずられるため。"
  (my/dired-tab--ensure)
  ;; mapcar のラムダ引数は呼び出しごとに別の束縛なので、そのまま閉じ込めてよい
  (mapcar (lambda (tab)
            `(tab
              (name . ,(my/dired-tab--label tab))
              (selected . ,(eq tab my/dired-tab-current))
              (select . ,(lambda () (my/dired-tab-goto tab)))
              (close . ,(lambda () (my/dired-tab-close tab)))))
          my/dired-tabs))

;;; 有効化

(defun my/dired-tab--setup ()
  "この dired バッファでタブを有効にする。`dired-mode-hook' から呼ぶ。"
  (my/dired-tab--ensure)
  (setq-local tab-line-tabs-function #'my/dired-tab-line-tabs)
  (add-hook 'post-command-hook #'my/dired-tab--sync nil t)
  (tab-line-mode 1))

(defun my/dired-tab--set-faces ()
  "今いるタブを見分けられるようにする。テーマによっては差が出ないため。"
  (set-face-attribute 'tab-line-tab-current nil
                      :weight 'bold :underline t)
  (set-face-attribute 'tab-line-tab-inactive nil
                      :weight 'normal :underline nil :inherit 'shadow))

(defun my/dired-tab--set-faces-on-theme (&rest _)
  "`enable-theme-functions' 用。匿名 lambda を hook に入れると外せないため。"
  (my/dired-tab--set-faces))

(defun my/dired-tabs-setup ()
  "ファイラのタブを有効にする。"
  (add-hook 'dired-mode-hook #'my/dired-tab--setup)
  (my/dired-tab--set-faces)
  ;; テーマを読み直しても効くようにしておく
  (add-hook 'enable-theme-functions #'my/dired-tab--set-faces-on-theme)
  ;; タブの前後移動。tab-line 標準の switch-to-next/prev-tab は buffer キーを
  ;; 持つタブしか対象にしないので使えない (tab-line.el:808-810)。
  ;; M-] / M-[ は使わない。端末では矢印キー等が ESC [ ... で届き、
  ;; `input-decode-map' は「そこまでの列が未定義のとき」しか参照されないので、
  ;; M-[ に完結した束縛があると TTY で矢印キーが壊れる。
  (define-key dired-mode-map (kbd "M-n") #'my/dired-tab-next)
  (define-key dired-mode-map (kbd "M-p") #'my/dired-tab-prev)
  ;; tab-bar (bufferlo) 側の閉じるは C-x t 0 なので k は衝突しない
  (define-key dired-mode-map (kbd "C-x t k") #'my/dired-tab-close-current))

(provide 'my-dired-tabs)
;;; my-dired-tabs.el ends here
