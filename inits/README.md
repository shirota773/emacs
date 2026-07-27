# inits/ の試用・検証中ファイルについて

このディレクトリには**定着済みの設定**と**試用・検証中の設定**が混在している。
このファイルは後者がどれか、いまどういう状態かを記録するもの。
状態が変わったら(定着・削除・切り出し)ここも更新する。

## 30_test-new.el — 試用中 (セクション単位で評価)

レビューで「不足」と判断した設定の試用ファイル。**セクション単位で動作確認し、
定着したら適切な `NN_name.el` へ移す。合わなければセクションごと削除する**という
運用。現在のセクション:

| # | 内容 | 状態 |
|---|---|---|
| 1 | exec-path-from-shell | 試用中 (macOS のみ) |
| 2 | TRAMP チューニング (2-1〜2-6) | 検証済み (下記) |
| 3 | popper | 試用中 |
| 4 | treesit / eglot | 試用中 |
| 5 | diff-hl | 試用中 |
| 6 | go-translate (gt) | 試用中。byte-compile で警告 5 件が既知 |

### セクション 2 (TRAMP) の検証状況 — 2026-07-27 時点

- Windows 11 / Emacs 30.1 / Tramp 2.7.1: 実機検証済み
- macOS / Emacs 29.4 / Tramp 2.6 系: 実機検証済み
  (補完ソース 4 本登録、`tramp-use-ssh-controlmaster-options` の boundp 分岐、
  `my/tramp-extra-hosts`、`C-x C-d` の Remote dirs ソース、byte-compile 新規警告なし)

- 2-5 節 (リモートバッファの git 情報を遅延表示、2026-07-27 追加):
  ブランチ表示は実リモートで検証済み。同日に変更量表示を追加した
  (`Git@main +12-3 [4]` = ブランチ / このファイルの追加・削除行数 /
  リポジトリの変更ファイル数)。**変更量部分は実リモートで未確認。**
  ブランチ切替後や他端末の変更を反映したいときは
  `M-x my/tramp-branch-refresh` (結果をエコーエリアに報告するので
  切り分けにも使う)。数字が要らなければ `my/tramp-branch-show-stats` を nil に。

  既知の挙動: **更新が走るとき 1 秒程度固まる** (2026-07-27 実測、許容と判断)。
  バグではなく TRAMP の仕様で、非同期プロセス 1 個ごとに ssh セッションが
  1 本増え、その確立部分が同期のため。だから定期タイマーは入れていない
  (詳細は 2-5 節冒頭)。気になるようになったら TRAMP の
  direct-async-process (接続プロパティ) でシェル初期化を飛ばす手がある

未検証で残っているもの:

- 2-6 節 (リモートファイルを view-mode で開く、2026-07-27 追加)。
  ロジックは検証済みだが**実リモートでは未確認**。確認手順: リモートの既存
  ファイルを開いて読み取り専用 (背景色が変わりカーソルが赤) になるか、
  `C-x C-q` 1 回で編集に移れるか、新規パスは書ける状態で開くか。
  やめたいときは `my/tramp-open-read-only` を nil に
- 実 SSH 接続後に `user@host` が 1 候補にまとまるか (mac では実接続で未確認)
- embark のキャッシュ削除 (`M-o X`) の実リモート候補上での動作
  (ローカルパスでの拒否は確認済み)
- 仕事の Linux ホストへの Windows からの TRAMP 接続。ハングしたら
  `my/tramp-windows-force-pty-hosts` に正規表現を足す。それでもダメなら
  `my/tramp-windows-login-shell-hosts` にも足す (詳細は 2-1 節のコメント)

### 積み残し

- ファイル名が実態と合っていない。TRAMP 設定の本体 (約 900 行) がここにあるので、
  `32_tramp.el` あたりへの切り出しを別ブランチで行う。

## 03_view-visual.el — カーソル色を一本化 (2026-07-27)

試用ファイルではないが、2-6 節と対になる変更なのでここに記録する。

read-only の目印を「カーソル形状 (hollow)」から「カーソル色」に変えた。

| 状態 | 色 |
|---|---|
| read-only | red |
| 書込可 | cyan |

あわせて **IME 連動のカーソル色制御 (01_setup.el) を廃止した**。
`mac-input-source` による日本語/英数の判定が実運用で安定しなかったのが理由。
`set-cursor-color` はフレーム単位でしか効かないので、IME 連動を残すと
read-only 表示と同じフレームパラメータを奪い合うことになる。
現在カーソル色を触るのは `my/cursor-color-update` だけ。

背景色と hl-line は従来どおり残す。カーソル形状は触らなくなった。
GUI での実表示は未確認 (バッチでは色の決定と `set-cursor-color` の
呼ばれ方まで検証済み)。

## 05_save-buffers.el — 未保存バッファの一括処理 (2026-07-27 追加・試用中)

終了時や `M-x grep` (compile 系) で走る `save-some-buffers` が未保存バッファを
1 個ずつ聞いてくるのをやめ、**対象が 2 個以上のときだけ dired 風の一覧
`*Unsaved Buffers*` に差し替える**。件数の内訳とキーの説明はヘッダー行に
常時出る (`保存N 破棄N 無視N / 全N`)。

| キー | 動作 |
|---|---|
| `s` / `d` / `u` | 保存マーク / 破棄 (kill) マーク / 解除 |
| `S` / `D` / `U` | 全部にマーク / 全解除 |
| `x` | マークを実行して先へ進む (破棄がある場合のみ 1 回確認) |
| `q` / `C-g` | 中止 (終了や grep そのものを取りやめる) |
| `RET` / `=` | 別ウィンドウに表示 / ファイルとの差分 |
| `j` / `k` | 上下移動 (Buffer-menu・grep-mode と同じ) |

**先へ進めるのは `x` だけ**。マークを付けずに `x` を押せば「全部そのまま
無視して先へ」になる。`q` を「無視して続行」にすると、終了しようとして
`q` を押した人から見て Emacs がいきなり終わるように見えるため中止に割り当てた
(2026-07-27 の実使用で指摘を受けて変更)。素の `C-g` (`keyboard-quit`) は
再帰編集を抜けないので、モードのキーマップで `abort-recursive-edit` に潰してある。
一覧から他のバッファへ移ってしまったときの最後の逃げ道は `C-]`。

`M-x my/list-unsaved-buffers` で単独でも呼べる。やめたいときは
`my/unsaved-buffers-menu-enabled` を nil に、常に一覧にしたいときは
`my/unsaved-buffers-threshold` を 1 に。

- 実装上の注意は冒頭 Commentary 参照 (`recursive-edit` を使う理由、
  元の `save-some-buffers` を潰さず後段で呼び直す理由)
- **無視を残したまま `x` で進んだ場合、終了時に "Modified buffers exist;
  exit anyway?" が 1 回だけ出る**。これは Emacs 側の最終確認なので残してある
- バッチ検証済み: 候補収集 / マーク表示・集計 / `x` の保存・kill・無視の
  振り分け / 無視分が元関数に二重で聞かれないこと / 中止が呼び出し元まで伝わり
  元関数が呼ばれないこと / 中止時の後片付け / byte-compile 警告なし。
  **GUI での操作感 (一覧の出方、`recursive-edit` からの復帰) は未確認**

## 31_terminal.el — terminal backend の比較検証中

常用の terminal 設定 (`C-t` → `my/term-here`) と、Ghostel / MisTTY /
shell + coterm / eat を同じ作業ディレクトリから比較するためのテストベンチ
(`C-c T` プレフィックス)。使い方と既知の制約はファイル冒頭の Commentary と
`C-c T ?` の Help を参照。

現在の採用状況:

- **採用中**: `C-t` = `my/term-here` (macOS では mistty、native Windows では
  接続単位 shell)。mistty は fzf/tmux 等の TUI で実証済み
- **ガード中**: eat は Rosetta 実行 (x86_64 Emacs) で TUI 出力によりフリーズ
  するため使用不可 (2026-07-24 実測)。arm64 ネイティブ Emacs へ乗り換えたら
  ガードは自動解除される
- **評価対象**: native Windows Emacs → TRAMP → POSIX remote での各 backend の
  比較が主目的。採用判定基準は Commentary 末尾を参照

補足: Commentary に「macOS local (現在は fish)」とあるが、macOS の
ログインシェルは現在 zsh。`my/term-here` はローカルでは `$SHELL` に従うので
動作には影響しない (コメントが古いだけ)。
