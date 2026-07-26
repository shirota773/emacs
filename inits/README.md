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
| 2 | TRAMP チューニング (2-1〜2-4) | 検証済み (下記) |
| 3 | popper | 試用中 |
| 4 | treesit / eglot | 試用中 |
| 5 | diff-hl | 試用中 |
| 6 | go-translate (gt) | 試用中。byte-compile で警告 5 件が既知 |

### セクション 2 (TRAMP) の検証状況 — 2026-07-27 時点

- Windows 11 / Emacs 30.1 / Tramp 2.7.1: 実機検証済み
- macOS / Emacs 29.4 / Tramp 2.6 系: 実機検証済み
  (補完ソース 4 本登録、`tramp-use-ssh-controlmaster-options` の boundp 分岐、
  `my/tramp-extra-hosts`、`C-x C-d` の Remote dirs ソース、byte-compile 新規警告なし)

未検証で残っているもの:

- 実 SSH 接続後に `user@host` が 1 候補にまとまるか (mac では実接続で未確認)
- embark のキャッシュ削除 (`M-o X`) の実リモート候補上での動作
  (ローカルパスでの拒否は確認済み)
- 仕事の Linux ホストへの Windows からの TRAMP 接続。ハングしたら
  `my/tramp-windows-force-pty-hosts` に正規表現を足す。それでもダメなら
  `my/tramp-windows-login-shell-hosts` にも足す (詳細は 2-1 節のコメント)

### 積み残し

- ファイル名が実態と合っていない。TRAMP 設定の本体 (約 900 行) がここにあるので、
  `32_tramp.el` あたりへの切り出しを別ブランチで行う。

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
