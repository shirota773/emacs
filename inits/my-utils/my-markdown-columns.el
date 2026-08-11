;;; my-markdown-columns.el --- 閲覧モードで ::: cols を横に並べる -*- lexical-binding: t; -*-

;; ★ 試作 (2026-08-11)。うまくいかなければファイルごと消してよい。
;;
;; Markdown に横並びの手段が表しか無いのが最大のネック、という判断への対応。
;; プレビュー (HTML) 側は `::: cols' を grid にすれば済むが、Emacs のバッファは
;; 行単位なので同じことはできない。ただし**複数行のブロックを行単位でマージして
;; 1 本のテキストに組み直し、overlay で元の領域に被せる**ことはできる。
;; HTML の再現ではないが、対比を横に置いて読むことはできるようになる。
;;
;; 仕組みは 3 段。
;;   1. `::: cols' … `:::' の範囲と、その中の子ブロックを見つける
;;   2. 子ブロックそれぞれを「画面に見えているとおりの文字列」に写して折り返す
;;      (`invisible' は捨て、`display' が文字列ならそれに差し替える。だから
;;       記法を隠した後・箇条書きが ● になった後の姿がそのまま列に入る)
;;   3. 行ごとに幅を揃えて連結し、overlay の `before-string' として元の行に
;;      載せる (元の行は `display ""' で消す)
;;
;; **載せ先は `before-string' でなければならない。** overlay の `display' に
;; 入れた文字列の中では入れ子の `display' が一切効かず、`(space :width …)' も
;; `:align-to' も無視されて空白 1 個に潰れる。`before-string' なら効く (実測)。
;; ピクセル指定の空白が使えるかどうかで桁揃えの精度が変わり、`display' 側では
;; セルごとに半角半分 (5px) まで、罫線の行では 7px の誤差が残っていた。
;;
;; **写せない内容がある。** その `::: cols' は諦めて縦積みのまま残す。
;;   - 画像    … display プロパティの画像を連結すると位置が壊れる
;;   - コードブロック … 折り返すと意味が変わる
;;
;; 表は写せる。ただし valign の桁揃えは overlay と text property なので文字列には
;; 乗らず、`--align-table' で自前に組み直している。
;;
;; 横並びの中だけ等幅・等倍にする。プロポーショナルフォントと見出しの拡大
;; (`markdown-header-scaling') は「文字数」と「表示幅」を一致させなくするので、
;; そのままでは列の右端が揃わない。
;;
;; 副作用: overlay の display で行数が変わるため、`display-line-numbers' の
;; 番号は元のファイルの行番号のまま飛ぶ。

(require 'markdown-mode)

(defgroup my/markdown-columns nil
  "閲覧モードで fenced div を横に並べる。"
  :group 'markdown)

(defcustom my/markdown-columns-gap 2
  "列と列のあいだに空ける桁数。"
  :type 'integer
  :group 'my/markdown-columns)

(defcustom my/markdown-columns-width-margin 2
  "横並び全体の幅から差し引く桁数。

`:align-to' の基準やフリンジのぶんで 1〜2 桁ずれることがあり、本文幅ぴったりに
組むとウィンドウ側でもう一度折り返されて**列の順番が混ざって見える**。
組んだ行が折り返されるようなら増やす。"
  :type 'integer
  :group 'my/markdown-columns)

(defcustom my/markdown-columns-min-width 24
  "1 列に必要な最小の桁数。これを割る幅しか取れないときは横並びをやめる。
狭い列に日本語を流し込むと 1 行あたり数文字になって、縦積みより読みにくい。"
  :type 'integer
  :group 'my/markdown-columns)

(defconst my/markdown-columns--fence-open "^:::+[ \t]*\\({[^}]*}\\|[^ \t\n]+\\)[ \t]*$"
  "開始フェンス。pandoc の fenced div は属性の有無で開始と終了を見分ける。
グループ 1 が属性 (`cols' や `{.cols}')。")

(defconst my/markdown-columns--fence-close "^:::+[ \t]*$"
  "終了フェンス。属性を持たない `:::' の行。")

(defconst my/markdown-columns--unrenderable
  "^\\(?:```\\|~~~\\|    [^ \t\n]\\)\\|!\\["
  "これを含む列は文字列に写せない。コードブロックと画像。

表は写せる。valign の桁揃えは文字列に乗らないので `--align-table' で組み直す。")

;;; 範囲を見つける ------------------------------------------------------------

(defun my/markdown-columns--fence-name ()
  "現在行の開始フェンスのクラス名を返す。開始フェンスでなければ nil。"
  (when (looking-at my/markdown-columns--fence-open)
    (let ((raw (match-string-no-properties 1)))
      (if (string-prefix-p "{" raw)
          ;; ::: {.cols} のかたち。ドット付きのクラス名を取り出す
          (when (string-match "\\.\\([^ \t}]+\\)" raw) (match-string 1 raw))
        raw))))

(defun my/markdown-columns--block-end ()
  "現在行の開始フェンスに対応する終了フェンスの行頭を返す。無ければ nil。"
  (save-excursion
    (forward-line 1)
    (let ((depth 1) (found nil))
      (while (and (> depth 0) (not (eobp)))
        (cond
         ((looking-at my/markdown-columns--fence-close)
          (setq depth (1- depth))
          (when (zerop depth) (setq found (point))))
         ((looking-at my/markdown-columns--fence-open)
          (setq depth (1+ depth))))
        (forward-line 1))
      found)))

(defun my/markdown-columns--children (beg end)
  "BEG..END (フェンスの内側) を列に分ける。各列は (START . END) で返す。
`::: col' で明示的に区切ってあればそれを使い、無ければ空行区切りの段落を列にする。"
  (save-excursion
    (goto-char beg)
    (let ((cols nil))
      (while (< (point) end)
        (if (my/markdown-columns--fence-name)
            ;; 明示的な子ブロック。中身だけを列にする
            (let ((child-end (my/markdown-columns--block-end)))
              (if (and child-end (<= child-end end))
                  (progn
                    (push (cons (line-beginning-position 2) child-end) cols)
                    (goto-char child-end)
                    (forward-line 1))
                (forward-line 1)))
          (forward-line 1)))
      (if cols
          (nreverse cols)
        ;; 明示的な区切りが無いので段落で割る
        (my/markdown-columns--paragraphs beg end)))))

(defun my/markdown-columns--paragraphs (beg end)
  "BEG..END を空行区切りの段落に割って (START . END) のリストで返す。"
  (save-excursion
    (goto-char beg)
    (let ((paras nil) (start nil))
      (while (< (point) end)
        (cond
         ((looking-at "^[ \t]*$")
          (when start (push (cons start (point)) paras) (setq start nil)))
         ((null start) (setq start (point))))
        (forward-line 1))
      (when start (push (cons start (min (point) end)) paras))
      (nreverse paras))))

;;; 見えているとおりの文字列に写す ---------------------------------------------

(defun my/markdown-columns--visible-string (beg end)
  "BEG..END を画面に見えているとおりの文字列にして返す。フェイスは保つ。

`invisible' で消えている部分は落とし、`display' が文字列ならその文字列に
差し替える。閲覧モードは記法を隠したり `-' を ● にしたりしているので、
生のバッファ文字列をそのまま使うと列の中身が元の記法に戻ってしまう。"
  (let ((parts nil) (pos beg))
    (while (< pos end)
      (let* ((next (or (next-property-change pos nil end) end))
             (inv (get-text-property pos 'invisible))
             (disp (get-text-property pos 'display)))
        (cond
         ((and inv (invisible-p inv)) nil)
         ((stringp disp)
          (push (propertize disp 'face (get-text-property pos 'face)) parts))
         (t (push (buffer-substring pos next) parts)))
        (setq pos next)))
    (apply #'concat (nreverse parts))))

(defun my/markdown-columns--join-needs-space-p (a b)
  "A の末尾と B の先頭をつなぐときに空白を挟むべきか。
どちらかが全角なら挟まない。日本語の行末改行を空白に変えると字間が空いてしまう
(`fill' の日本語処理と同じ作法)。"
  (and (> (length a) 0) (> (length b) 0)
       (= (char-width (aref a (1- (length a)))) 1)
       (= (char-width (aref b 0)) 1)))

(defconst my/markdown-columns--standalone-line
  "^[ \t]*\\(?:[-*+][ \t]\\|[0-9]+[.)][ \t]\\|#\\|>\\||\\|$\\)"
  "前の行につないではいけない行。リスト・見出し・引用・表・空行。")

(defun my/markdown-columns--block-text (beg end)
  "BEG..END を、列に流し込める 1 本の文字列にして返す。

Markdown の単一改行は段落の続きなので、そのまま持ち込むと**元の折り返し位置で
列が改行されてしまう**。行頭を見て「新しいブロックの始まり」でなければ前の行に
つなぎ、折り返しは列幅で決め直す。"
  (let ((parts nil))
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (goto-char (line-beginning-position))
        (let* ((lb (point))
               (le (min end (line-end-position)))
               (text (my/markdown-columns--visible-string lb le))
               (standalone (looking-at my/markdown-columns--standalone-line)))
          (if (or (null parts) standalone)
              (push text parts)
            (let* ((prev (pop parts))
                   (sep (if (my/markdown-columns--join-needs-space-p prev text) " " "")))
              (push (concat prev sep text) parts))))
        (forward-line 1)))
    (my/markdown-columns--align-tables
     (my/markdown-columns--squeeze-blank
      (mapconcat #'identity (nreverse parts) "\n")))))

(defun my/markdown-columns--squeeze-blank (s)
  "S の先頭と末尾の空行を落とし、続いた空行を 1 つにまとめる。

`::: col' の中身をそのまま列にすると、見出しと本文のあいだの空行や、閉じフェンス
の手前の空行がそのまま列に入って**行が無駄に空く**。段落の区切りとしての空行は
1 つ残す。"
  (let ((out nil) (prev-blank t))
    (dolist (line (split-string s "\n"))
      (let ((blank (string-empty-p (string-trim line))))
        (unless (and blank prev-blank)
          (push line out))
        (setq prev-blank blank)))
    (while (and out (string-empty-p (string-trim (car out))))
      (pop out))
    (mapconcat #'identity (nreverse out) "\n")))

;;; 表の桁揃え --------------------------------------------------------------
;;
;; valign は overlay で桁を揃えているので、`--visible-string' で文字列に写すと
;; 生の `| a | b |' に戻ってしまう。横並びの中では自前で揃え直す。
;;
;; 罫線は罫線素片 (`│' `─' `┼') で引く。ASCII の `+---+' でも桁は合うものの、
;; 読み物としては罫線のほうが締まる。
;;
;; 幅は必ず `fixed-pitch' で実測する (この設定では半角 10px・`─' 10px・全角 17px。
;; ただし `variable-pitch' で測ると `─' が 17px、`┼' が 12px とばらつく)。
;; **全角は半角 2 つ分ではない**ので、空白の個数で詰めると誤差が残る。詰め物は
;; `--spacer' のピクセル指定に任せ、枠の幅だけ `─' の倍数に切り上げて罫線が
;; ちょうど敷けるようにしてある。

(defun my/markdown-columns--table-row-p (line)
  "LINE が表の行なら非 nil。"
  (string-prefix-p "|" (string-trim-left line)))

(defun my/markdown-columns--split-row (line)
  "表の行 LINE をセルのリストにする。フェイスは保つ。"
  (let* ((s (string-trim line))
         (beg (if (string-prefix-p "|" s) 1 0))
         (end (if (and (> (length s) beg) (string-suffix-p "|" s))
                  (1- (length s))
                (length s))))
    (mapcar #'string-trim (split-string (substring s beg end) "|"))))

(defun my/markdown-columns--separator-row-p (cells)
  "CELLS が区切り行 (`---' や `:---:') なら非 nil。"
  (and cells
       (seq-every-p (lambda (c) (string-match-p "\\`:?-+:?\\'" c)) cells)))

(defun my/markdown-columns--spacer (px)
  "幅 PX ピクセルちょうどの空白を返す。

**載せ先が `before-string' だからピクセル指定が使える。** overlay の `display' に
入れた文字列の中では入れ子の `display' が一切効かず、`(space :width …)' も
`:align-to' も無視されて空白 1 個に潰れる。`before-string' なら入れ子の `display'
がそのまま効く (実測: 40px 指定がそのまま 40px になった)。組んだ行を
`before-string' で載せているのはこのためで、`display' に戻すと桁揃えが全部壊れる。

半角空白を並べて近似していたときは、半角 1 つ分の半分 (実測 5px) までの誤差が
セルごとに残り、とくに罫線の行が 7px ずれて `┼' が `│' の下に来なかった。"
  (if (<= px 0)
      ""
    (propertize " " 'display `(space :width (,px)) 'face 'fixed-pitch)))

(defun my/markdown-columns--divider (ch width-px)
  "仕切りの文字 CH を、幅 WIDTH-PX ちょうどの 1 桁にして返す。

`│' と `┼' の幅が同じとは限らないので、広いほうに合わせて詰める。ここを揃えないと
罫線の行だけ以降の列が横にずれる。"
  (concat (char-to-string ch)
          (my/markdown-columns--spacer
           (- width-px (my/markdown-columns--char-width ch)))))

(defun my/markdown-columns--align-table (rows)
  "表の行 ROWS (文字列のリスト) を桁揃えして返す。

セルの幅はピクセルで測り、`--spacer' のピクセル指定で詰める。

**枠の幅は `─' 1 本の幅の倍数に切り上げる。** 罫線の行は `─' を敷き詰めて作る
ので、枠がその倍数でないと端数が空いて `┼' が `│' の下から外れる (実測で全角セル
の列が 7px ずれた)。切り上げたぶんはセル側も同じだけ広げるので、上下の行と罫線が
同じ位置で切り替わる。"
  (let* ((space-px (my/markdown-columns--char-width ?\s))
         (rule-px (my/markdown-columns--char-width ?─))
         (div-px (max (my/markdown-columns--char-width ?│)
                      (my/markdown-columns--char-width ?┼)))
         (cells (mapcar #'my/markdown-columns--split-row rows))
         (ncol (apply #'max (mapcar #'length cells)))
         (widths (make-list ncol 0)))
    ;; 区切り行 (`---') は幅の基準にしない。ダッシュの数だけ列が太くなってしまう
    (dolist (row cells)
      (unless (my/markdown-columns--separator-row-p row)
        (dotimes (i (length row))
          (let ((w (my/markdown-columns--text-width (nth i row))))
            (when (> w (nth i widths)) (setf (nth i widths) w))))))
    ;; 枠 (左右の空白を含めた 1 列ぶん) の幅。`─' の倍数に切り上げる
    (let ((slots (mapcar (lambda (w)
                           (* rule-px (ceiling (+ w (* 2 space-px)) rule-px)))
                         widths)))
      (mapcar
       (lambda (row)
         (propertize
          (if (my/markdown-columns--separator-row-p row)
              (mapconcat (lambda (slot)
                           (make-string (/ slot rule-px) ?─))
                         slots
                         (my/markdown-columns--divider ?┼ div-px))
            (mapconcat
             (lambda (i)
               (let ((cell (or (nth i row) "")))
                 (concat " " cell
                         (my/markdown-columns--spacer
                          (- (nth i slots) (* 2 space-px)
                             (my/markdown-columns--text-width cell)))
                         " ")))
             (number-sequence 0 (1- ncol))
             (my/markdown-columns--divider ?│ div-px)))
          ;; 表の行は途中で折らない。折ると桁が意味を失う
          'my/markdown-columns-nowrap t))
       cells))))

(defun my/markdown-columns--align-tables (s)
  "S の中の表をすべて桁揃えした文字列を返す。"
  (let ((out nil) (table nil))
    (dolist (line (split-string s "\n"))
      (if (my/markdown-columns--table-row-p line)
          (push line table)
        (when table
          (dolist (r (my/markdown-columns--align-table (nreverse table))) (push r out))
          (setq table nil))
        (push line out)))
    (when table
      (dolist (r (my/markdown-columns--align-table (nreverse table))) (push r out)))
    (mapconcat #'identity (nreverse out) "\n")))

(defun my/markdown-columns--normalize-face (s)
  "S のフェイスに等幅・等倍を被せる。破壊的に S を変えて S を返す。

列の右端を揃えるには「測った幅」と「描かれる幅」が一致していないといけない。
`variable-pitch' と見出しの拡大 (`markdown-header-scaling') はこれを崩す。

高さを `default' の**絶対値**で上書きするのが要点。`:height 1.0' では打ち消せない
 (相対指定は親の値に乗算されるので、1.7 倍の見出しは 1.0 を掛けても 1.7 倍のまま
残り、その行だけ列の位置がずれる)。"
  (let ((h (face-attribute 'default :height nil t)))
    (add-face-text-property 0 (length s) `(:height ,h) nil s))
  (add-face-text-property 0 (length s) 'fixed-pitch nil s)
  s)

(defun my/markdown-columns--neutralize-face (s)
  "S に「下の行のフェイスを打ち消す既定値」を**最も弱い優先度で**被せて返す。

`before-string' の文字のフェイスは、**その overlay が張られている元の行の
フェイスと合成される。** 組んだ行は元の行と 1 対 1 で対応させているだけで中身は
無関係なのに、`::: cols' の行 (`shadow') に載った行は文字が青灰色、`### 見出し'
の行に載った行は赤い太字、というふうに**中身と無関係な色が付く**。

打ち消しは APPEND で足す。`markdown-list-face' の ● の赤や見出しの赤は、S が
自分で持っているぶんのほうが優先度が高いので残る。残るのは色や太さを何も
指定していない素の文字だけで、そこが `default' の見た目になる。"
  (add-face-text-property
   0 (length s)
   `(:foreground ,(face-attribute 'default :foreground nil t)
     :weight normal :slant normal
     :underline nil :overline nil :strike-through nil :box nil)
   t s)
  s)

(defvar my/markdown-columns--char-width-cache (make-hash-table :test #'eq)
  "文字 → 表示ピクセル幅のキャッシュ。
`string-pixel-width' は毎回 temp buffer を作るので、1 文字ずつ呼ぶと重い。")

(defun my/markdown-columns--char-width (ch)
  "文字 CH の表示ピクセル幅を返す。

`fixed-pitch' で測るのは、`my/markdown-columns--normalize-face' が横並びの中を
`fixed-pitch' にするため。**測るフェイスと描くフェイスが違うと幅が合わない。**
閲覧モードの既定は variable-pitch なので、素の文字で測ると実際の描画より狭く
見積もり、列がはみ出してウィンドウ側で折り返されてしまう。"
  (or (gethash ch my/markdown-columns--char-width-cache)
      (puthash ch (string-pixel-width
                   (propertize (char-to-string ch) 'face 'fixed-pitch))
               my/markdown-columns--char-width-cache)))

(defun my/markdown-columns--text-width (s)
  "S の表示ピクセル幅を返す。

`--spacer' が入れたピクセル指定の空白は、文字としての幅ではなく指定された幅で
数える。ここを見落とすと、詰めたぶんが幅に反映されず列の位置が累積でずれる。"
  (let ((w 0) (i 0) (n (length s)))
    (while (< i n)
      (let* ((disp (get-text-property i 'display s))
             (px (and (eq (car-safe disp) 'space)
                      (car-safe (plist-get (cdr disp) :width)))))
        (setq w (+ w (or px (my/markdown-columns--char-width (aref s i))))))
      (setq i (1+ i)))
    w))

(defun my/markdown-columns--wrap (s width-px)
  "S を表示幅 WIDTH-PX (ピクセル) 以内に折り返し、行のリストにして返す。

`fill-region' を使わず自前で折るのは、**桁数ではなくピクセルで測らないと
列がはみ出す**ため。日本語の全角は半角ちょうど 2 つ分の幅とは限らず (macOS の
既定フォントの組み合わせがまさにそう)、`string-width' で 80 桁に収めた行が
実際には 80 桁分より広くなり、ウィンドウ側でもう一度折り返されてしまう。

切ってよい位置は空白の直後。日本語は空白が無いので文字単位で切れる。
表の行 (`my/markdown-columns-nowrap' が付いた行と、生の `|' で始まる行) は
折り返さない。途中で折ると桁が意味を失うため。"
  (let* ((lines nil) (start 0) (break nil) (width 0) (i 0) (n (length s))
         (nowrap-p (lambda (pos)
                     (and (< pos n)
                          (or (eq (aref s pos) ?|)
                              (get-text-property
                               pos 'my/markdown-columns-nowrap s)))))
         (no-wrap (funcall nowrap-p 0)))
    (while (< i n)
      (let* ((ch (aref s i))
             (cw (my/markdown-columns--char-width ch)))
        (cond
         ((eq ch ?\n)
          (push (substring s start i) lines)
          (setq start (1+ i) break nil width 0
                no-wrap (funcall nowrap-p start)))
         ((and (not no-wrap) (> (+ width cw) width-px) (> i start))
          (let ((cut (or break i)))
            (push (substring s start cut) lines)
            (setq start cut break nil)
            (setq width (my/markdown-columns--text-width (substring s start (1+ i))))))
         (t (setq width (+ width cw))))
        (when (memq ch '(?\s ?\t)) (setq break (1+ i))))
      (setq i (1+ i)))
    (when (< start n) (push (substring s start) lines))
    (nreverse lines)))

(defun my/markdown-columns--compose (blocks total-px)
  "BLOCKS (文字列のリスト) を横に連結した文字列を返す。全体の幅は TOTAL-PX。

列の境目はピクセル指定の空白 (`--spacer') で送る。空白を何個並べるかで近似すると
半角 1 つ分未満の誤差が列ごとに残るが、`(space :width …)' なら誤差ゼロで揃う。

最後に `--neutralize-face' を通すのは、載せ先の行のフェイスを拾わせないため。"
  (let* ((n (length blocks))
         (space-px (my/markdown-columns--char-width ?\s))
         (gap-px (* my/markdown-columns-gap space-px))
         (col-px (/ (- total-px (* gap-px (1- n))) n))
         (cols (mapcar (lambda (b)
                         (my/markdown-columns--wrap
                          (my/markdown-columns--normalize-face b) col-px))
                       blocks))
         (rows (apply #'max (mapcar #'length cols))))
    (my/markdown-columns--neutralize-face
     (mapconcat
      (lambda (i)
        (let ((parts nil) (acc 0) (k 0))
          (dolist (col cols)
            (let ((line (or (nth i col) "")))
              (push line parts)
              (setq acc (+ acc (my/markdown-columns--text-width line)))
              (setq k (1+ k))
              (when (< k n)
                ;; 次の列の開始位置までピクセル指定で送る
                (let* ((target (* k (+ col-px gap-px)))
                       (pad (my/markdown-columns--spacer (- target acc))))
                  (push pad parts)
                  (setq acc (+ acc (my/markdown-columns--text-width pad)))))))
          (string-trim-right (apply #'concat (nreverse parts)))))
      (number-sequence 0 (1- rows))
      "\n"))))

;;; overlay を張る ------------------------------------------------------------

(defun my/markdown-columns--renderable-p (beg end)
  "BEG..END を文字列に写せるなら非 nil。表・コードブロック・画像があれば nil。"
  (save-excursion
    (goto-char beg)
    (not (re-search-forward my/markdown-columns--unrenderable end t))))

(defun my/markdown-columns--total-pixel-width ()
  "横並びに使える全体のピクセル幅。**ウィンドウから実測する。**

桁数に `frame-char-width' を掛けて求めてはいけない。マージンや行番号のぶんだけ
本文はそれより狭く、推定した幅で組むと行がはみ出してウィンドウ側で折り返され、
**左右の列が交互に並んで順番がめちゃくちゃに見える**。

ウィンドウに出ていないバッファ (batch での検証など) では測れないので、そのときだけ
`fill-column' からの当て推量に落とす。"
  (let ((win (get-buffer-window (current-buffer))))
    (if win
        (max 100 (- (window-body-width win t)
                    ;; **行番号は本文と同じ領域に描かれる。** `window-body-width'
                    ;; はマージンとフリンジしか引かないので、ここで引かないと
                    ;; 行番号のぶんだけはみ出してウィンドウ側で折り返され、
                    ;; 右の列の先頭行だけが次の行へ落ちる (実測で 30px 足りず、
                    ;; 769px に組んだ行が 790px の本文に入らなかった)
                    (with-selected-window win
                      (line-number-display-width 'pixel))
                    (* my/markdown-columns-width-margin (frame-char-width))))
      (* (max 1 (- fill-column my/markdown-columns-width-margin))
         (frame-char-width)))))

(defun my/markdown-columns-remove ()
  "このバッファに張った横並びの overlay を全部消す。"
  (interactive)
  (remove-overlays (point-min) (point-max) 'my/markdown-columns t))

(defun my/markdown-columns--put-text (ov lb le text)
  "OV に TEXT を表示させる。LB..LE はその行の範囲。

**`display' ではなく `before-string' に載せる。** `display' に入れた文字列の中では
入れ子の `display' が一切効かず、`--spacer' のピクセル指定が空白 1 個に潰れて桁が
揃わない (`:align-to' も同じ)。`before-string' なら効く。元の行は `display \"\"'
で消す (空行はもともと消す対象が無いので何もしない)。"
  (overlay-put ov 'before-string text)
  (unless (= lb le)
    (overlay-put ov 'display "")))

(defun my/markdown-columns--lay-out (beg close composed)
  "BEG から CLOSE (終了フェンスの行頭) までを COMPOSED の各行に差し替える。

**元の 1 行に overlay 1 枚**を張る。ブロック全体を 1 枚の overlay で覆うと、
`display' で置き換えた領域が丸ごと 1 つの表示単位になり、その中ではカーソルが
どこにいても同じ位置に描かれる。ポイントを入れないよう `cursor-intangible' で
弾くと、今度は C-n がそこで進まなくなる (実測で 3 回続けて同じ行に留まった)。

行ごとに張れば元の行と表示行が 1 対 1 で対応するので、上下移動が素直に効く。
組んだ行のほうが少ないときは余った行を隠し、多いときは最後の行にまとめる。

対応を崩さないために、**この範囲の行は font-lock で隠さない**約束にしてある
 (21_markdown.el の `:::' 行の扱いを参照)。隠れた行に `display' を載せても
`invisible' が勝って何も出ず、対応が 1 つずれて上下移動が 2 行を往復する。"
  (let* ((lines (split-string composed "\n"))
         (nlines (length lines))
         (rows (1+ (count-lines beg close)))
         (i 0))
    ;; valign はバッファ全体では止めない。**横並びの外にある表は valign に
    ;; 揃えてもらう**ため (バッファごと切ると、そちらが生の | a | b | に戻る)。
    ;; 重なった部分はこちらの overlay に `priority' を持たせて勝たせる。
    ;; 消すだけでは valign が塗り直して罫線の残骸が復活する。
    (dolist (ov (overlays-in beg (min (point-max) (1+ close))))
      (when (overlay-get ov 'valign)
        (delete-overlay ov)))
    (save-excursion
      (goto-char beg)
      (while (< i rows)
        (let* ((lb (line-beginning-position))
               (le (line-end-position))
               (spill (>= i nlines))
               ;; 畳む行は**改行まで含めて**隠す。行末で切ると中身だけが消えて
               ;; 改行が残り、そのぶん空行が並ぶ (元 10 行を 2 行に組むと空行が
               ;; 8 行できていた)。display を載せる行は逆に改行を残す。
               ;; それが次の行との区切りになる
               (ov (make-overlay lb (if spill (min (point-max) (1+ le)) le))))
          (overlay-put ov 'my/markdown-columns t)
          ;; valign が同じ行に張る overlay より前に出す。priority が無いと
          ;; 畳んだ行の上に valign の罫線だけが描かれて残骸になる
          (overlay-put ov 'priority 100)
          (cond
           ;; 最後の行に、あふれたぶんをまとめて載せる
           ((and (= i (1- rows)) (< i nlines))
            (my/markdown-columns--put-text
             ov lb le (mapconcat #'identity (nthcdr i lines) "\n")))
           ((< i nlines)
            (my/markdown-columns--put-text ov lb le (nth i lines)))
           (t
            ;; `invisible' ではなく空文字列への `display' で消す。行頭記号を
            ;; ● に差し替えている行を `invisible' にすると、**その display が
            ;; 残って ● だけの行が並ぶ**ことがある (実測でブロックごとに 1 つ
            ;; ずつ漏れた)。改行まで含めて空文字列に置き換えれば確実に消える。
            (overlay-put ov 'display "")
            (overlay-put ov 'cursor-intangible t))))
        (forward-line 1)
        (setq i (1+ i))))))

(defun my/markdown-columns-refresh (&optional clear-cache)
  "バッファ中の `::: cols' を横並びに差し替える。

font-lock が終わった後に呼ぶこと。`invisible' や `display' が確定していないと
列の中身が記法つきのまま写る。

CLEAR-CACHE (C-u 前置) で文字幅のキャッシュを捨ててから組み直す。フォントや
文字サイズを変えた後、幅の見積もりが古いままで列がずれるときに使う。"
  (interactive "P")
  (when clear-cache
    (clrhash my/markdown-columns--char-width-cache))
  (my/markdown-columns-remove)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((name (my/markdown-columns--fence-name)))
        (if (not (and name (string-prefix-p "cols" name)))
            (forward-line 1)
          (let* ((fence-beg (point))
                 (close (my/markdown-columns--block-end)))
            (if (null close)
                (forward-line 1)
              (let* ((inner-beg (line-beginning-position 2))
                     (children (my/markdown-columns--children inner-beg close))
                     (n (length children))
                     ;; 幅の判定も**ピクセルで**する。組むのは実測ピクセルなのに
                     ;; 判定だけ固定の桁数でしていたため、ウィンドウを狭めても
                     ;; 「幅は足りている」と誤判定し、1 列 5 文字のような潰れた
                     ;; 2 列になっていた
                     (total-px (my/markdown-columns--total-pixel-width))
                     (gap-px (* my/markdown-columns-gap (frame-char-width)))
                     (col-px (if (> n 0) (/ (- total-px (* gap-px (1- n))) n) 0))
                     (min-px (* my/markdown-columns-min-width (frame-char-width))))
                (if (or (< n 2)
                        (< col-px min-px)
                        (not (my/markdown-columns--renderable-p inner-beg close)))
                    ;; 写せない。縦積みのまま残す
                    (goto-char close)
                  (let* ((body (mapcar (lambda (c)
                                         (my/markdown-columns--block-text
                                          (car c) (cdr c)))
                                       children))
                         (composed (my/markdown-columns--compose
                                    body (my/markdown-columns--total-pixel-width))))
                    (my/markdown-columns--lay-out fence-beg close composed))
                  (goto-char close)
                  (forward-line 1))))))))))

(defun my/markdown-columns-present-p ()
  "このバッファに `::: …' のブロックがあれば非 nil。

横並びが要らないファイルに `font-lock-ensure' の代金を払わせないための門番。"
  (save-excursion
    (goto-char (point-min))
    (re-search-forward my/markdown-columns--fence-open nil t)))

(defun my/markdown-columns-setup ()
  "閲覧モードのセットアップから呼ぶ入口。

**組む契機はここでは持たない。** ウィンドウの大きさが確定してから組むのは
21_markdown.el の `my/markdown-view--settle' の仕事で、そこから
`my/markdown-columns-refresh' が呼ばれる。以前は最初の
`window-configuration-change-hook' を契機にしていたが、**閲覧モードに入った
だけでは構成が変わらないことがあり、幅を動かすまで縦積みのままだった。**

幅に追従させるのは**やめた**。組み直すと行数が変わり、それでスクロールバーの
要否が変わって使える幅が数ピクセル動く。「組む → 幅が動く → また組む」の振動が
止まらず、再入ガードとしきい値を入れても固まった。幅を変えたときは
`my/markdown-columns-refresh' (C-c l) を打つ。"
  ;; overlay はメジャーモードを変えても残る。編集モードに戻ったときに生の
  ;; テキストが overlay で隠れたままにならないよう、自分で片付ける
  (add-hook 'change-major-mode-hook #'my/markdown-columns-remove nil t))

(provide 'my-markdown-columns)
;;; my-markdown-columns.el ends here
