;;; my-dired-mouse.el --- dired をマウス中心で操作する -*- lexical-binding: t; -*-

;; OS 標準のファイラを置き換えられる程度のマウス操作を dired に与える。
;;
;;   ▶ / ▾ をクリック   展開 / 折りたたみ (TAB と同じ)
;;   名前をクリック      フォルダに入る / ファイルを開く (1 クリック)
;;   中クリック          新しいタブで開く (フォルダのときだけタブが増える)
;;   サイドボタン        今のタブの戻る / 進む (mouse-4/5 と mouse-8/9 の両方)
;;   右クリック          コンテキストメニュー
;;                       このアプリで開く / OS のファイラで表示 / 新しいタブ /
;;                       戻る・進む・上へ / Bookmark / Bookmark に追加 /
;;                       新規フォルダ / リネーム・コピー・ゴミ箱へ / パスをコピー
;;                       (「開く」「別ウィンドウで開く」は dired 本体が足す)
;;
;; 「戻る/進む」はタブごとの自前スタック (my-dired-tabs.el)。サイドボタンの無いマウスでも
;; 右クリックメニューから辿れるようにしてある。
;; 「Bookmark」の中身は my-dired-sidebar.el と同じ関数から作るので、
;; サイドバーと右クリックで見えるものがずれない。

;; dirvish-history / dirvish-quick-access はここでは使わない (戻る・進むは
;; my-dired-tabs.el の自前スタック、登録ディレクトリは my-dired-sidebar.el)。
;; どちらも autoload 済みなのでキー割り当て側で困ることもない。
(require 'dired)
(require 'dirvish)
(require 'dirvish-subtree)

;; プラットフォーム判定は 01_setup.el の defconst。バイトコンパイル時の
;; 未定義警告を避けるためだけの宣言。
(defvar linux-p)

(declare-function my/open-externally "my-defuns")
(declare-function my/reveal-in-file-manager "my-defuns")
(declare-function my/open-externally-with-app "my-defuns")
(declare-function dirvish-copy-file-path "dirvish-extras")
(declare-function my/dired-bookmark-add "my-dired-sidebar")
(declare-function my/quick-access--dirs "my-dired-sidebar")
(declare-function my/dired-tab-open-dir-in-new-tab "my-dired-tabs")
(declare-function my/dired-tab-go-back "my-dired-tabs")
(declare-function my/dired-tab-go-forward "my-dired-tabs")

(defcustom my/dired-open-with-apps nil
  "右クリックの「このアプリで開く」に直接並べるアプリ。
macOS はアプリ名 (例 \"Preview\")、Windows は実行ファイル名を書く。
ここに無いアプリは同じメニューの「その他のアプリ…」から選ぶ。
インストール済みを全部並べると数が多すぎて選べないため、常用分だけを持つ。"
  :type '(repeat string)
  :group 'dired)

;;; クリック位置の解決

;; マウスから呼ぶコマンドは (interactive (list last-nonmenu-event)) 方式で統一する。
;; tab-line 自身がこの形 (tab-line.el:871-877)。(interactive "e") はキーからも
;; メニューからも呼べなくなるので使わない。この方式なら EVENT が nil のとき
;; ポイント位置にフォールバックできる。

(defun my/dired--goto-click (event)
  "EVENT がマウスイベントなら、クリックした行へポイントを移す。
`(listp nil)' は t なので、EVENT が nil のときに通さないよう `and' で見ること。
通してしまうと `event-start' が合成した posn を返し、ポイントが意図せず動く。"
  (when (and event (listp event))
    (let* ((posn (event-start event))
           (win (posn-window posn))
           (pt (posn-point posn)))
      (when (windowp win) (select-window win))
      (when pt (goto-char pt)))))

(defun my/dired--click-on-arrow-p (event)
  "EVENT が subtree の開閉印 (▶ / ▾) の上でのクリックなら非 nil。
印は行頭のオーバーレイの after-string として描かれている
\(`dirvish-subtree.el' の subtree-state 属性)。オーバーレイ由来の文字列は
`posn-string' で取れるので、それが印と一致するかで判定する。"
  ;; nil を通さない。(listp nil) は t で、event-start が合成 posn を返すため
  (when (and event (listp event))
    (let* ((posn (event-start event))
           (str (car-safe (posn-string posn)))
           (icons (and (boundp 'dirvish-subtree--state-icons)
                       dirvish-subtree--state-icons)))
      ;; 列位置での判定は併用しない。名前の上のクリックを誤って印と見なし、
      ;; 「入る」が「展開」になってしまうため。印はオーバーレイの文字列なので
      ;; posn-string で確実に取れる。
      (and (stringp str) icons
           (member (substring-no-properties str)
                   (list (substring-no-properties (car icons))
                         (substring-no-properties (cdr icons))))
           t))))

(defun my/dired--click-on-mark-column-p (event)
  "EVENT が行頭のマーク桁 (アイコンより左) でのクリックなら非 nil。
dired の行は [マーク 1 桁][詳細列][ファイル名] の並びで、詳細列は
`dired-hide-details-mode' により不可視なので、見た目では**行頭の 2 桁がそのまま
マーク領域**になる (実測: ファイル名は行頭から 42 桁目)。
開閉印の判定より後に呼ぶこと。印のオーバーレイも行頭側に描かれるため。"
  ;; nil を通さない。(listp nil) は t で、event-start が合成 posn を返すため
  (when (and event (listp event))
    (let ((pt (posn-point (event-start event))))
      (when pt
        (save-excursion
          (goto-char pt)
          (<= pt (1+ (line-beginning-position))))))))

(defun my/dired--toggle-mark ()
  "ポイント行のマークを付け外しする。ポイントは動かさない。"
  (let ((p (point))
        (marked (eq (char-after (line-beginning-position)) dired-marker-char)))
    ;; dired-mark / dired-unmark は処理後に次の行へ進むので戻す
    (if marked (dired-unmark 1) (dired-mark 1))
    (goto-char p)))

(defun my/dired-mouse-mark (&optional event)
  "クリックした行のマークを付け外しする。
Alt (Option) + クリック、および行頭のマーク桁のクリックから呼ばれる。
Ctrl + クリックは macOS がコンテキストメニューに使っている
\(`C-down-mouse-1' = mac-mouse-context-menu) ので割り当てない。"
  (interactive (list last-nonmenu-event))
  (my/dired--goto-click event)
  (when (dired-get-filename nil t)
    (my/dired--toggle-mark)))

;;; マウスカーソルの形

(defun my/dired--decorate-subtree-icons ()
  "▶ / ▾ に手の形のマウスカーソルと説明を付ける。
印は `dirvish-subtree--state-icons' の文字列をそのまま使って描かれるので
(dirvish-subtree.el:289-294)、元の文字列に属性を足しておけば反映される。"
  (when (and (boundp 'dirvish-subtree--state-icons)
             (consp dirvish-subtree--state-icons))
    (setq dirvish-subtree--state-icons
          (cons (propertize (car dirvish-subtree--state-icons)
                            'pointer 'hand 'help-echo "クリックで折りたたむ")
                (propertize (cdr dirvish-subtree--state-icons)
                            'pointer 'hand 'help-echo "クリックで展開する")))))

(defcustom my/dired-pointer-shape-max-lines 5000
  "マウスカーソルの形を付ける一覧の行数の上限。
1 行ずつ走査するので、桁違いに大きいディレクトリでは表示のたびに
体感できる待ちになる。超えたら諦めて既定の I ビームのままにする
\(2 万行でおよそ 0.14 秒)。"
  :type 'integer
  :group 'dired)

(defun my/dired--apply-pointer-shape ()
  "一覧のマウスカーソルを I ビームから変える。
ファイル名の上は手の形 (クリックできる)、それ以外は矢印。
テキストエディタではなくファイラとして触っていることが分かるように。
`dired-after-readin-hook' から呼ぶ。"
  (when (<= (line-number-at-pos (point-max)) my/dired-pointer-shape-max-lines)
    (my/dired--apply-pointer-shape-1)))

(defun my/dired--apply-pointer-shape-1 ()
  "`my/dired--apply-pointer-shape' の本体。"
  (with-silent-modifications
    (put-text-property (point-min) (point-max) 'pointer 'arrow)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((beg (dired-move-to-filename)))
          (when beg
            (let ((end (dired-move-to-end-of-filename t)))
              (when end (put-text-property beg end 'pointer 'hand)))
            ;; 行頭のマーク桁もクリックできる (マークの付け外し)。
            ;; 詳細列が不可視なので、ここが見た目の「アイコンより左」にあたる
            (let ((bol (line-beginning-position)))
              (put-text-property bol (min (+ bol 2) (line-end-position))
                                 'pointer 'hand)
              (put-text-property bol (min (+ bol 2) (line-end-position))
                                 'help-echo "クリックでマークの付け外し"))))
        (forward-line 1)))))

;;; 左クリック / 中クリック

(defun my/dired-mouse-open (&optional event)
  "クリックした行を開く。
▶ / ▾ の上なら展開・折りたたみ。フォルダならその中に入り、ファイルは開く。
EVENT が無ければポイント位置を対象にする。"
  (interactive (list last-nonmenu-event))
  (my/dired--goto-click event)
  (cond
   ;; ▶ / ▾ の上 → 展開・折りたたみ。印の判定を必ず先にやる
   ((and (my/dired--click-on-arrow-p event)
         (when-let* ((f (dired-get-filename nil t))) (file-directory-p f)))
    (dirvish-subtree-toggle))
   ;; アイコンより左 (マーク桁) → マークの付け外し。
   ;; 名前の上のクリックで開かれると w (ファイル名コピー) の前に選べないため
   ((and (my/dired--click-on-mark-column-p event)
         (dired-get-filename nil t))
    (my/dired--toggle-mark))
   ((dired-get-filename nil t)
    (dired-find-file))))

(defun my/dired-mouse-open-in-new-tab (&optional event)
  "クリックした行を新しいタブで開く。
フォルダのときだけタブが増える。ファイルは普通に開く。"
  (interactive (list last-nonmenu-event))
  (my/dired--goto-click event)
  (let ((target (dired-get-filename nil t)))
    (cond
     ((null target)
      ;; ファイルの無いところをクリックしただけ。左クリックと同じく黙って
      ;; ポイントを移すだけにする。キーから呼ばれたときだけ理由を伝える。
      (unless (listp event)
        (user-error "ここには開けるものがありません")))
     ((file-directory-p target)
      (my/dired-tab-open-dir-in-new-tab target))
     (t (dired-find-file)))))

;;; 右クリックメニュー

(defun my/dired--apps-menu (file)
  "FILE を開くアプリの選択サブメニューを返す。"
  (let ((map (make-sparse-keymap "このアプリで開く")))
    ;; define-key は後入れが上に来るので、末尾に置きたいものから先に入れる
    (define-key map [my-dired-app-other]
      `(menu-item "その他のアプリ…"
                  ,(lambda () (interactive) (my/open-externally-with-app))))
    (dolist (app (reverse my/dired-open-with-apps))
      ;; dolist の変数は全周回で同じ束縛なので、閉じ込める前に let で捕まえ直す
      (let ((app app))
        (define-key map (vector (intern (concat "my-dired-app-" app)))
          `(menu-item ,app
                      ,(lambda () (interactive) (my/open-externally file app))))))
    map))

(defun my/dired--favorites-menu ()
  "登録済みディレクトリのサブメニューを返す。
中身は `my/quick-access--dirs' (Bookmark / クイックアクセス / 登録ディレクトリ)
と同じなので、サイドバーと右クリックで見えるものがずれない。"
  (let ((map (make-sparse-keymap "Bookmark"))
        ;; メニューのキーはラベルから作ると、節をまたいで同じ名前があったときに
        ;; 後勝ちで上書きされ、項目が黙って消える (Bookmark の \"emacs\" と
        ;; クイックアクセスの \"emacs\" など)。通し番号で必ず別のキーにする。
        (n 0))
    (dolist (section (reverse (my/quick-access--dirs)))
      (dolist (entry (reverse (cdr section)))
        ;; dolist の変数は全周回で同じ束縛なので、閉じ込める前に捕まえ直す
        (let ((path (cdr entry))
              (label (car entry)))
          (setq n (1+ n))
          (define-key map (vector (intern (format "my-dired-fav-%d" n)))
            `(menu-item ,label
                        ,(lambda () (interactive) (dired (expand-file-name path))))))))
    map))

(defun my/dired-context-menu (menu click)
  "dired の右クリックメニューを MENU に足して返す。
CLICK はマウスイベント。`context-menu-functions' に入れて使う。"
  (when (derived-mode-p 'dired-mode)
    ;; OS のファイラと同じく、右クリックした行を対象にする
    (mouse-set-point click)
    (let ((file (dired-get-filename nil t)))
      (define-key-after menu [my-dired-separator] menu-bar-separator)
      (when file
        ;; 「開く」「別ウィンドウで開く」は dired 本体の `dired-context-menu' が
        ;; Find This File / Find in Other Window として足すので、ここでは作らない。
        (define-key-after menu [my-dired-open-with]
          `(menu-item "このアプリで開く" ,(my/dired--apps-menu file)))
        (define-key-after menu [my-dired-open-default]
          '(menu-item "OS 既定のアプリで開く" my/open-externally-dwim))
        (define-key-after menu [my-dired-reveal]
          '(menu-item "OS のファイラで表示" my/reveal-in-file-manager))
        (define-key-after menu [my-dired-new-tab]
          '(menu-item "新しいタブで開く" my/dired-mouse-open-in-new-tab))
        (when (file-directory-p file)
          (define-key-after menu [my-dired-subtree]
            '(menu-item "展開 / 折りたたみ" dirvish-subtree-toggle)))
        (define-key-after menu [my-dired-separator-2] menu-bar-separator))
      (define-key-after menu [my-dired-back]
        '(menu-item "戻る" my/dired-tab-go-back))
      (define-key-after menu [my-dired-forward]
        '(menu-item "進む" my/dired-tab-go-forward))
      (define-key-after menu [my-dired-up]
        '(menu-item "上のディレクトリへ" dired-up-directory))
      (define-key-after menu [my-dired-favorites]
        `(menu-item "Bookmark" ,(my/dired--favorites-menu)))
      (define-key-after menu [my-dired-bookmark-add]
        '(menu-item "Bookmark に追加" my/dired-bookmark-add))
      ;; サイドバーの開閉は my-dired-sidebar.el が全バッファに足すので
      ;; ここでは作らない
      (define-key-after menu [my-dired-separator-3] menu-bar-separator)
      (define-key-after menu [my-dired-mkdir]
        '(menu-item "新規フォルダ…" dired-create-directory))
      (when file
        (define-key-after menu [my-dired-rename]
          '(menu-item "名前を変更…" dired-do-rename))
        (define-key-after menu [my-dired-copy]
          '(menu-item "コピー…" dired-do-copy))
        (define-key-after menu [my-dired-trash]
          '(menu-item "ゴミ箱へ" dired-do-delete))
        (define-key-after menu [my-dired-copy-path]
          '(menu-item "パスをコピー" dirvish-copy-file-path)))))
  menu)

;;; 有効化

(defun my/dired-mouse-setup ()
  "dired のマウス操作を有効にする。"
  ;; 右クリックメニューは Emacs 全体の機能。dired 以外でも mouse-3 が
  ;; コンテキストメニューになる (従来の mouse-save-then-kill は置き換わる)。
  (context-menu-mode 1)
  (add-hook 'context-menu-functions #'my/dired-context-menu)
  ;; ボタンとイベントの対応は describe-key で確認済み:
  ;;   左 = mouse-1 / 中 = mouse-2 / 右 = mouse-3 / 戻る = mouse-4 / 進む = mouse-5
  ;;
  ;; ただし dired は `dired-mode-map' に <follow-link> → mouse-face を持ち
  ;; (dired.el:2165)、ファイル名には mouse-face が付いている (dired.el:1910)。
  ;; そのため `mouse-1-click-follows-link' (既定 450ms) が働き、名前の上での
  ;; 短い左クリックが mouse-1 から mouse-2 へ**変換されて**しまう。
  ;; 左と中が同じ動作になる原因はこれなので、dired ではリンク扱いをやめる。
  ;; グローバル設定は触らない (Info や org のリンクでは有用なため)。
  (define-key dired-mode-map [follow-link] nil)
  ;; マウスカーソルの形。I ビームだとテキスト編集に見えるため
  (my/dired--decorate-subtree-icons)
  (add-hook 'dired-after-readin-hook #'my/dired--apply-pointer-shape)
  ;;
  ;; 左クリックは 1 回で「入る / 開く」。▶ の上だけ展開・折りたたみになる。
  (define-key dired-mode-map [mouse-1] #'my/dired-mouse-open)
  ;; 中クリックは「新しいタブで開く」。dired 既定の
  ;; dired-mouse-find-file-other-window はクリックのたびにウィンドウを
  ;; 分割するので置き換える。
  (define-key dired-mode-map [mouse-2] #'my/dired-mouse-open-in-new-tab)
  (define-key dired-mode-map (kbd "C-<return>") #'my/dired-mouse-open-in-new-tab)
  ;; ダブルクリックは何もしない。Emacs は 2 回目の押下で
  ;; down-mouse-1 → mouse-1 → down-mouse-1 → double-mouse-1 を送るので、
  ;; 1 回目のクリックは必ず配送される。double-mouse-1 にも開く動作を割り当てると
  ;; 「入った先の同じ文字位置にある行」をもう一度開いてしまう。
  ;; 未割り当てにするとシングルの束縛へフォールバックして同じことが起きるため、
  ;; 明示的に ignore を置く必要がある。
  (define-key dired-mode-map [double-mouse-1] #'ignore)
  (define-key dired-mode-map [double-mouse-2] #'ignore)
  ;; マークの付け外し。行頭のマーク桁のクリック (my/dired-mouse-open 内で分岐) に加えて
  ;; Alt (Option) + クリックでも付け外しできるようにする。
  ;; Ctrl + クリックは使わない。macOS では C-down-mouse-1 が mac-mouse-context-menu
  ;; (＝右クリック相当) に割り当てられていて衝突するため。
  ;; down 側も潰さないと mouse-drag-secondary (副選択のドラッグ) が先に走る。
  (define-key dired-mode-map [M-down-mouse-1] #'ignore)
  (define-key dired-mode-map [M-mouse-1] #'my/dired-mouse-mark)
  ;; サイドボタン。macOS (NS) と Windows (w32) は 3 番目以降のボタンを
  ;; mouse-4 / mouse-5 として渡す。mouse-8 / mouse-9 を送るマウスもあるので
  ;; 両方に割り当てておく。
  ;; ただし X11 (Linux) では mouse-4 / mouse-5 がホイールそのものなので
  ;; (mwheel.el の `mouse-wheel-down-event' 既定値)、そこでは割り当てない。
  ;; 割り当てるとスクロールが「戻る/進む」になってしまう。
  ;; 効かないときは dired 上で C-h k を押してからボタンを押すと
  ;; 実際のイベント名が分かる。
  (let ((back '([mouse-8])) (forward '([mouse-9])))
    (unless linux-p
      (setq back (cons [mouse-4] back)
            forward (cons [mouse-5] forward)))
    (dolist (key back)
      (define-key dired-mode-map key #'my/dired-tab-go-back))
    (dolist (key forward)
      (define-key dired-mode-map key #'my/dired-tab-go-forward))))

(provide 'my-dired-mouse)
;;; my-dired-mouse.el ends here
