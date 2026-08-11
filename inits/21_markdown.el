;;; 21_markdown.el --- Markdown の閲覧と編集 -*- lexical-binding: t; -*-

;;; Commentary:
;; ★ 試用中 (2026-08-10 導入)。定着しなければ丸ごと削除してよい。
;;
;; これまで .md は Emacs に持ち込まず dired から Vivaldi に投げていた
;; (`my/dired-open-browser-exts')。Emacs 内で読めるようにするのがこのファイルの
;; 目的で、閲覧手段を 3 つ併置する。トレードオフが逆なのでどれかには寄せない。
;;
;;   C-c C-v   `my/markdown-view-toggle'      記法を隠したテキスト表示。外部プロセス
;;                                            無しで即座に開く。TRAMP 越しでも動く
;;   C-c C-c x `my/markdown-preview-xwidget'  pandoc + xwidget で Emacs 内に HTML
;;                                            描画。表や脚注まで忠実だが起動が遅い
;;   C-c C-c p `my/markdown-preview-browser'  ブラウザ (markdown-mode 標準に <base>
;;                                            を足したもの)
;;   C-c p     プロポーショナル表示のトグル
;;   C-c l     表と横並びを組み直す (幅を変えた後に打つ)
;;
;; 素の markdown-mode が表示に何もしない箇所は外から補っている。**表** は valign
;; (桁を一切揃えないので日本語セルで罫線が崩れる)、**チェックボックス** は
;; prettify-symbols で ☐/☑ (角括弧のまま)、**数式** は `markdown-enable-math'
;; (既定で無効なので素通しだった)。
;;
;; dired からクリックしたときの開き先は今回変えていない (.md はブラウザのまま)。
;; 使ってみてから決める。review-notes.md §7 の「dired のファイラ化は仮仕様」参照。
;;
;; プレビューの実体は inits/my-utils/my-markdown-preview.el。

;;; Code:

(require 'my-markdown-preview)
(require 'my-markdown-columns)
(require 'my-markdown-fold)

;; 表の桁をピクセル単位で揃える。markdown-mode は表に `markdown-table-face' を
;; 当てるだけで**桁は一切揃えない**ので、日本語セルが混じると罫線がガタガタになる。
;; 全角幅とプロポーショナルフォントの両方を考慮して揃えられるのがこれ。
;; 編集中も有効にしてあるのは、打ちながら揃ってくれないと表を書く気にならないため。
(leaf valign
  :ensure t
  :custom ((valign-fancy-bar . t))
  :hook (markdown-mode-hook . valign-mode))

(declare-function markdown-display-inline-images "markdown-mode")

(defcustom my/markdown-view-variable-pitch t
  "閲覧モードで本文をプロポーショナルフォントにするか。

見た目は一番大きく変わるが、日本語のフォールバックフォント次第では字面が不揃いに
見えることがある。合わなければ nil にする。コードブロックと表は `markdown-code-face'
が `fixed-pitch' を継承しているので、これを t にしても等幅のまま崩れない。"
  :type 'boolean
  :group 'markdown)

(defcustom my/markdown-view-fill-width 80
  "閲覧モードの本文の折り返し幅 (桁)。nil ならウィンドウの幅いっぱいまで使う。

指定した桁数ぶんの幅を**きっちり**本文に使う。`visual-fill-column' には任せない。
あれは variable-pitch のバッファだと桁の見積もりを外し、実測で 121 桁の
ウィンドウに 80 桁を指定したのに 56 桁ぶんのマージンを取って本文が 64 桁に
なっていた。**余った 16 桁ぶんが右の死んだ余白になり、そのせいで本文が要らない
ところで折り返されていた。**"
  :type '(choice (const :tag "ウィンドウ幅いっぱい" nil) integer)
  :group 'markdown)

(defun my/markdown-view--apply-margin ()
  "本文が `my/markdown-view-fill-width' 桁ぶんに収まる右マージンを設定する。

`window-total-width' は `frame-char-width' 基準の桁数なので、そこから希望の桁数を
引けば必要なマージンがそのまま出る。左は 0 のまま (中央寄せはしない。ウィンドウが
広いと左にも同じ幅の空白帯ができて、何のための余白か分からなくなる)。"
  (dolist (win (get-buffer-window-list (current-buffer) nil t))
    (if (null my/markdown-view-fill-width)
        (set-window-margins win 0 0)
      (set-window-margins
       win 0 (max 0 (- (window-total-width win) my/markdown-view-fill-width))))))

(defvar-local my/markdown-view--relayout-timer nil
  "組み直しを待っているタイマー。二重に積まないための札。")

(declare-function valign-reset-buffer "valign")

(defun my/markdown-view-relayout ()
  "表の桁揃えと横並びを、いまのウィンドウの大きさで組み直す。

**モードのフックの時点では組めない。** そこはまだバッファがウィンドウに出て
いない (dired やタブから開くと `find-file-noselect' の中でフックが走る) 段階で、
幅もフェイスも確定していない。そのせいで 2 つ壊れていた。

  - valign は**バッファがウィンドウに出ていないと桁を揃えない**
    (`valign-region' が `get-buffer-window' を見て黙って何もしない)。それでも
    jit-lock は「塗り終えた」印を付けるので、**その表は二度と揃えられない**。
    ここで `valign-reset-buffer' を呼んで測り直させる。実測で、確定してから
    測ると列の幅が 5〜9px 変わった
  - 横並びは最初の `window-configuration-change-hook' を契機にしていたが、
    閲覧モードに入っただけでは構成が変わらないことがあり、**幅を動かすまで
    縦積みのまま**だった

幅を変えた後もこれを打てば組み直せる (C-c l)。自動で追従はさせない
 (`my/markdown-columns-setup' の説明を参照)。"
  (interactive)
  (setq my/markdown-view--relayout-timer nil)
  (when (derived-mode-p 'markdown-view-mode 'gfm-view-mode)
    ;; 表は valign に測り直させる。横並びの中の表だけは
    ;; `my/markdown-columns--align-table' が自前で組む
    (when (bound-and-true-p valign-mode)
      (valign-reset-buffer))
    (when (my/markdown-columns-present-p)
      ;; 列の中身は「画面に見えているとおり」を写すので font-lock の確定を待つ。
      ;; どの行が隠れているかが決まっていないと、隠れた行にも組んだ行を載せて
      ;; しまい、元の行と表示行の対応が 1 つずれて上下移動が 2 行を往復する
      (font-lock-ensure)
      (my/markdown-columns-refresh))))

(defun my/markdown-view--relayout-soon ()
  "再表示が済んでから `my/markdown-view-relayout' を 1 回だけ走らせる。

idle timer にするのは、コマンドが終わって再表示まで済んだところで走るため。
この時点なら `get-buffer-window' もマージンも確定している。"
  (unless my/markdown-view--relayout-timer
    (let ((buffer (current-buffer)))
      (setq my/markdown-view--relayout-timer
            (run-with-idle-timer
             0.05 nil
             (lambda ()
               (when (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (my/markdown-view-relayout)))))))))

(defun my/markdown-view-setup ()
  "閲覧モードの表示を整える。

素の `markdown-view-mode' は記法を隠すだけで、行は画面幅一杯まで伸び、行間も
編集時のままになる。それだと読み物として開く理由が無いので、組版の側を寄せる。

  - 右マージン — 本文を `my/markdown-view-fill-width' 桁に抑える。横長の
    ウィンドウで1行が長くなりすぎるのを防ぐ (`my/markdown-view--apply-margin')
  - `line-spacing' — 行間を空ける。日本語は字面が詰まるので効き目が大きい
  - `markdown-hide-urls' — URL を記号1文字に畳んでリンクテキストだけ見せる
  - `variable-pitch-mode' — 本文をプロポーショナルに (`my/markdown-view-variable-pitch')

`display-images-p' で守るのは、`markdown-display-inline-images' が画像を出せない
端末で `error' を投げる仕様のため。emacs -nw や --batch でフックごと落ちてしまう。"
  (visual-line-mode 1)
  (setq-local line-spacing 0.35)
  (setq-local markdown-hide-urls t)
  ;; チェックボックスを記号にする。markdown-mode は `[ ]' `[x]' をボタン化する
  ;; (クリックでトグルできる) が、見た目は角括弧のままで一覧性が無い。
  (setq-local prettify-symbols-alist
              '(("[ ]" . ?☐) ("[x]" . ?☑) ("[X]" . ?☑)))
  (prettify-symbols-mode 1)
  ;; 幅を絞るのは `my/markdown-view-fill-width' が数値のときだけ。マージンは
  ;; 自前で計算する (理由は defcustom の説明を参照)。ウィンドウの大きさが
  ;; 変わったら測り直す
  (my/markdown-view--apply-margin)
  (add-hook 'window-configuration-change-hook
            #'my/markdown-view--apply-margin nil t)
  ;; markdown-mode が知らない記法を畳む。`invisible' に `markdown-markup' を使う
  ;; ので、`markdown-hide-markup' が有効な閲覧モードでだけ消え、編集モードでは
  ;; そのまま見える (`**' などの記法と同じ扱いになる)。
  ;;
  ;;   ::: cols … :::      pandoc の fenced div。プレビュー用のレイアウト指定で
  ;;                       あって読む中身ではないので行ごと消す
  ;;   <details> <summary> 折りたたみのタグ。中身は読ませたいのでタグだけ消す
  ;;
  ;; `::: ' の行は**隠さない**。横並びが成立する `::: cols' はブロックごと
  ;; overlay の `display' で組み直した行に差し替わるので、そこで見えなくなる。
  ;; ここで invisible にしてしまうと、その行に display を載せても invisible が
  ;; 勝って何も出ず、元の行と表示行の対応が 1 つずれて**上下移動が 2 行を往復
  ;; する**。横並びにできなかったブロックでだけ `:::' が残るので、色を落とす。
  ;;
  ;; <details> のタグは display で差し替える相手がいないので invisible のまま。
  ;; `cursor-intangible' を添えるのは、不可視位置にポイントが入るとカーソルが
  ;; 動かなくなるため (`font-lock-extra-managed-props' に足さないと font-lock が
  ;; プロパティを設定してくれない)。
  (add-to-list 'font-lock-extra-managed-props 'cursor-intangible)
  (font-lock-add-keywords
   nil
   '(("^:::.*$" 0 'shadow t)
     ("</?\\(?:details\\|summary\\)>" 0
      '(face nil invisible markdown-markup cursor-intangible t) t))
   'append)
  (cursor-intangible-mode 1)
  (when my/markdown-view-variable-pitch
    (variable-pitch-mode 1))
  (when (display-images-p)
    (markdown-display-inline-images))
  ;; hide-urls は font-lock の段階で効くので、モード起動後に変えたぶんを塗り直す
  (font-lock-flush)
  ;; 横並びの片付け (編集モードへ戻すときの overlay 削除) を仕掛ける。
  ;; 実際に組むのは幅が確定してから (`my/markdown-view--settle')
  (my/markdown-columns-setup)
  ;; <details> を Notion のトグルリストのように開閉できるようにする
  (my/markdown-fold-setup)
  ;; 表の桁揃えと横並びは、ウィンドウの大きさが確定してから組む
  (my/markdown-view--relayout-soon))

(defun my/markdown-edit-setup ()
  "編集モードの表示を整える。

見出しの拡大 (`markdown-header-scaling') を編集中だけ打ち消す。**狭いウィンドウ
では拡大したぶんだけ見出しが余計に折り返され**、`## 塊ごとに並べる' が 3 行に
割れて読めなくなる。読むときは大きいほうがよいので、閲覧モードでは拡大したまま。

`face-remap-add-relative' に `default' の高さを**絶対値**で渡すのが要点。
`:height 1.0' は相対指定で親に乗算されるため、1.4 倍の見出しを打ち消せない。"
  (unless (derived-mode-p 'markdown-view-mode 'gfm-view-mode)
    (let ((h (face-attribute 'default :height nil t)))
      (dolist (n (number-sequence 1 6))
        (let ((face (intern (format "markdown-header-face-%d" n))))
          (when (facep face)
            (face-remap-add-relative face `(:height ,h))))))))

(defun my/markdown-view-toggle-variable-pitch ()
  "閲覧中にプロポーショナル表示を切り替える。既定値は
`my/markdown-view-variable-pitch' で決める。"
  (interactive)
  (variable-pitch-mode 'toggle))

;; メジャーモードは gfm-mode (markdown-mode の GFM 派生) を既定にする。読む対象が
;; Obsidian の vault と GitHub のリポジトリなので、表・チェックボックス・取り消し線
;; が効く GFM 方言のほうが実態に合う。pandoc 側の --from=gfm とも揃う。
(leaf markdown-mode
  :ensure t
  :mode (("\\.md\\'" . gfm-mode)
         ("\\.markdown\\'" . gfm-mode))
  :custom
  (;; --standalone を付けない。付けると pandoc が完全な HTML を出してしまい、
   ;; markdown-mode が `markdown-xhtml-header-content' を差し込む余地が無くなる
   ;; (`markdown-output-standalone-p' が真になり骨組みの付与をやめる)。
   ;; +fenced_divs で `::: cols' ... `:::' を <div class="cols"> に変換できる。
   ;; Markdown 本体には横並びの手段が表しか無いので、段組・並置はこれで書く。
   ;; 対応する CSS は `my/markdown-preview-css' 側にある。
   (markdown-command . "pandoc --from=gfm+fenced_divs --to=html5")
   (markdown-xhtml-header-content . my/markdown-preview-css)
   ;; 閲覧のための表示設定
   (markdown-header-scaling . t)                    ; 見出しを大きく
   (markdown-fontify-code-blocks-natively . t)      ; コードブロックを各言語で着色
   (markdown-fontify-whole-heading-line . t)
   ;; `markdown-marginalize-headers' は入れない。# を左マージンへ出す機能だが、
   ;; 閲覧モードでは hide-markup が # を消すので得るものが無く、代わりに本文の
   ;; 左に 6 桁の空白帯と裸の `###' が並んで何の表示か分からなくなる。
   ;; Obsidian の [[wiki link]] を辿れるようにする。既定は無効。
   ;; 探索範囲に project を入れると project.el のルート (= vault の git ルート)
   ;; 以下を探すので、フォルダ分けされた vault でもリンクが解決する。
   (markdown-enable-wiki-links . t)
   (markdown-wiki-link-search-type . '(sub-directories parent-directories project))
   ;; $x^2$ / $$...$$ に markdown-math-face を当てる。既定は無効で、数式は完全に
   ;; 素通しだった
   (markdown-enable-math . t))
  :bind ((markdown-mode-map
          ;; 見出し移動は org-mode-map (20_org.el) と同じ M-j / M-k に揃える。
          ;; mod+h/j/k/l が矢印なので、j/k が縦移動という対応が指に入っている。
          ("M-j" . markdown-outline-next)
          ("M-k" . markdown-outline-previous)
          ("C-c C-v" . my/markdown-view-toggle)
          ("C-c C-c x" . my/markdown-preview-xwidget)
          ;; 標準の markdown-preview を包んだもの。相対パス画像を出すために
          ;; <base> を足すぶんだけ違う
          ("C-c C-c p" . my/markdown-preview-browser)
          ;; C-c C-p は markdown-outline-previous が使っているので C-c p にする
          ("C-c p" . my/markdown-view-toggle-variable-pitch)
          ;; 表と横並びはウィンドウ幅を見て一度組むだけなので、幅を変えたら打つ
          ("C-c l" . my/markdown-view-relayout)
          ;; 画像のインライン表示。org の C-c i (org-toggle-inline-images) に対応
          ("C-c i" . markdown-toggle-inline-images)))
  :hook
  (;; 編集中も折り返しは visual-line-mode に任せる。既定の folding は単語や
   ;; タグの途中で切るので、ウィンドウを狭めた途端に読めなくなる。
   ;; 幅の制限 (visual-fill-column) は閲覧モードだけ。編集中に本文が中途半端な
   ;; 幅で止まると表やコードを直しにくい
   (markdown-mode-hook . visual-line-mode)
   (markdown-mode-hook . my/markdown-edit-setup)
   ((markdown-view-mode-hook gfm-view-mode-hook) . my/markdown-view-setup))
  :config
  (define-advice markdown--project-root
      (:around (orig-fn &rest args) my/markdown-no-project-prompt)
    "プロジェクトが特定できないときに「Select project:」を聞かせない。

`markdown--project-root' は .git/.hg/.svn が見つからないと `project-current' を
MAYBE-PROMPT 付きで呼ぶ。そのため **バージョン管理外のディレクトリにある .md を
開くと、`[[wiki link]]' の font-lock のたびにミニバッファでプロジェクトを聞かれて
操作が止まる** (`markdown-wiki-link-search-type' に project を入れているため)。

返り値は `directory-files-recursively' にそのまま渡されるので nil を返すわけには
いかない。特定できなければ現在のディレクトリを基準にする。`ignore-errors' で
握り潰しているのは、プロンプトを抑止した `project-current' が nil を返し
`project-root' がその nil で失敗する経路を「プロジェクト無し」に写すため。"
    (let ((project-current-inhibit-prompt t))
      (or (ignore-errors (apply orig-fn args))
          default-directory))))

(provide '21_markdown)
;;; 21_markdown.el ends here
