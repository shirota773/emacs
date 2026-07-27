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

- 2-5 節 (リモートバッファのブランチ遅延表示、2026-07-27 追加):
  実リモートで検証済み (同日)。vc をリモート無効化した代償のブランチ非表示を、
  開いた後に非同期 `git rev-parse` で補い `Git@ブランチ名` と表示する。
  ブランチ切替後や表示されないときは `M-x my/tramp-branch-refresh`
  (結果をエコーエリアに報告するので切り分けにも使う)

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
