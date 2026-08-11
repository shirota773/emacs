---
id: 001-builder-markdown-viewer
date: 2026-08-11
role: builder
pipeline: markdown-viewer
status: needs-review
reads: []
next: builder(残課題の続き) / ユーザー判断待ち1件
---

# 要約
`.md` を Emacs 内で読めるようにした。markdown-mode 導入 + 閲覧モードの組版に加え、
Markdown に無い**横並び (`::: cols`) と折りたたみ (`<details>`)** を閲覧モードで実装。
ブランチ `feature/markdown-viewer` に 24 コミット。main へは未マージ。

# 事実(何をした・何が起きた)
- 新規 `inits/21_markdown.el` — markdown-mode(gfm-mode) の leaf 設定。キーは
  `C-c C-v`(閲覧⇄編集) `C-c C-c x`(xwidget preview) `C-c C-c p`(ブラウザ) `C-c l`(組み直し)
  `C-c p`(プロポーショナル切替) `C-c i`(画像) `M-j`/`M-k`(見出し移動)
- 新規 `inits/my-utils/my-markdown-preview.el` — pandoc+xwidget プレビュー、CSS、`<base>` 注入
- 新規 `inits/my-utils/my-markdown-columns.el` — `::: cols` を横に組み直す(本体)
- 新規 `inits/my-utils/my-markdown-fold.el` — `<details>` の開閉
- 変更 `inits/02_packages.el` — crux の C-a に visual-line 対応 advice(`:init` に置く)、
  markdown から fill-column 縦線を撤去
- 導入パッケージ: markdown-mode / visual-fill-column(現在は未使用) / valign
- 外部: `brew install pandoc` 済み
- 検証用 `docs/` 外の一時物: `/private/tmp/claude-503/.../scratchpad/` に
  `layout.md` `cols2.md` `fold.md` `syntax.md` と撮影スクリプト `shoot.sh`(セッション消滅で失われる)

# 判断(なぜそうしたか)
- 閲覧手段を 3 つ併置(view-mode / xwidget / ブラウザ)。トレードオフが逆なので一本化しない
- 横並びは「複数行を行単位でマージし overlay の `display` で差し替える」方式。
  **元の 1 行に overlay 1 枚**を張る(ブロック全体を 1 枚で覆うとカーソルが領域先頭に
  貼り付き、`cursor-intangible` で弾くと今度は C-n が進まなくなる)
- 幅は**必ずウィンドウから実測**する。桁数 × `frame-char-width` の推定は外れる
- `visual-fill-column` は不採用。variable-pitch のバッファで桁を外し、121 桁のウィンドウに
  80 桁指定で 56 桁のマージンを取った。`window-total-width` から引いて自前で設定している

# 未解決・要確認
- [x] ~~表の桁が横並びの中で 3px ずれる~~ → 解決 (7415a29)。**`face-font-rescale-alist` は
      不要だった。** 組んだ行を overlay の `display` ではなく `before-string' に載せると
      入れ子の `display` が効き、`(space :width (px))` で 1px の誤差もなく詰められる。
      罫線の行の 7px ずれも同時に解消
- [x] ~~横並びで畳んだ行に valign の罫線が薄く残る~~ → 解決 (7415a29)。元の行を
      `display ""` で消すので下の text property が透けない
- [ ] 横並びの左右で同じリストの色が違う(片方グレー、片方青)。font-lock の適用タイミング差が疑わしいが**未調査**
- [ ] 極端に狭い幅(実質 2-3 文字)では何をしても潰れる。`truncate-lines` 案は未提案のまま
- [ ] `review-notes.md` §7 に試用中と記録済みだが、横並び/折りたたみの記述は未追記

# 次工程への注意点
- 最初に読む: `inits/my-utils/my-markdown-columns.el` の冒頭コメント(方式と限界が書いてある)
- **overlay の `display` に入れた文字列の中では入れ子の `display` が一切効かないが、
  `before-string` なら効く**(実測: 40px 指定が `display` では 7px、`before-string` では
  40px になった)。組んだ行は `before-string` に載せ、元の行を `display ""` で消す方式に
  変えた。`display` に戻すと桁揃えが全部壊れる
- **表示を整える処理をメジャーモードのフックで走らせない。** その時点ではまだ
  ウィンドウに出ていない(dired から開くと `find-file-noselect` の中でフックが走る)。
  valign はウィンドウが無いと黙って桁を揃えず、jit-lock は塗り終えた印を付ける。
  `my/markdown-view--relayout-soon` の idle timer で確定後に組む
- **batch では `frame-char-width` が 1 になりピクセル検証が全部素通りする。** GUI フレームを
  起動して測ること。`emacs -Q -l init.el --eval "(add-hook 'emacs-startup-hook (lambda () …) t)"`
  で起動画面(Bookmark List)より後に処理を積む
- 画面撮影は可能(画面収録権限を `claude`(小文字)に付与済み)。ただし**撮る直前に対象 PID を
  最前面へ出し、最前面が本当にそれかを確認してから撮ること**。座標だけ指定して別アプリの
  画面を撮る事故を起こした
- 撮影用 Emacs は自爆タイマー + trap で必ず落とす。大量に残してユーザーに迷惑をかけた

# KB 候補
- ~~pitfall: overlay の display 文字列内では入れ子の display が効かない~~ → KB へ記録済み
  (`pitfall-nested-display-is-ignored-in-overlay-display-string-but-works-in-before-string`
  / `pitfall-valign-silently-skips-alignment-when-buffer-has-no-live-window`
  / `pitfall-window-body-width-does-not-subtract-the-line-number-column`)
- pitfall: batch では frame-char-width=1 なのでピクセル起因のバグが検証をすり抜ける
- pitfall: 空行に張った overlay は範囲が空なので display が表示されない(before-string を使う)
- pitfall: invisible にした行の display(行頭記号)が残ることがある。改行込みの `display ""` で消す
- pitfall: visual-fill-column は variable-pitch のバッファで桁を外す
- decision: 横並びは元の 1 行に overlay 1 枚。ブロック全体を 1 枚で覆わない
