# mac (Emacs 29.4) 動作確認の引き継ぎ

このファイルは **確認が終わったら削除する一時的な引き継ぎ資料**。
branch `fix/windows-shell-and-tramp` を main にマージする前の作業指示。

- 作業した環境: Windows 11 / Emacs 30.1 / Tramp 2.7.1.30.1
- 確認したい環境: macOS / **Emacs 29.4** / Tramp 2.6 系
- main は 1 コミットも進んでいないので **fast-forward 可能、コンフリクトなし**

---

## このブランチで何をしたか

主眼は **Windows の shell まわりと TRAMP**。mistty / C-t の設計自体は元々 mac 側で
詰めたもので、このブランチでは触っていない (リネームで関数名だけ変わっている)。

| コミット | 内容 | mac への影響 |
|---|---|---|
| `fix:` Git Bash フルパス固定 | `inits/win.el`。`shell-file-name` が PATH 解決で WSL を引いていたのを修正。comint の OSC 処理と起動ノイズ除去も | **無し** (win.el は `01_setup.el:223-224` の `windows-nt-p` ガードでしか読まれない) |
| `feat:` `C-c T w` で WSL 起動 | `inits/31_terminal.el` | 押しても「WSLはWindows専用です」と断るだけ |
| `docs:` C-t のコメント更新 | `inits/94_keybinds.el` | 無し |
| `fix:` TRAMP ssh ハングをホスト単位で回避 | `inits/30_test-new.el` 2-1節 | **無し** (`(when (eq system-type 'windows-nt) ...)` ガードあり) |
| `refactor:` `31_terminal-test.el` → `31_terminal.el` | シンボルも `my/terminal-test-*` → `my/terminal-*` | **あり** (後述の落とし穴) |
| `feat:` pty 回避ホストを local-inits から設定可能に | `inits/30_test-new.el` 2-1節 | 無し (同上のガード内) |
| `feat:` TRAMP ホスト補完の整理 + `C-x C-d` 導線 | `inits/30_test-new.el` 2-2/2-3/2-4節 | **あり。ガード無しで mac にも効く** |
| `chore:` gitignore 追加 | `.gitignore` | 3 つとも未追跡なのでそのまま効く |
| `fix:` Emacs 29.4 対応 | `inits/30_test-new.el` | **これが今回の本題** |

---

## Emacs 29.4 で問題になった 2 件 (修正済み・未実機検証)

Windows 側で 29.4 の Tramp ソース (emacs-mirror/emacs の `emacs-29.4` タグ) を
実際に取得して全使用 API を照合した。実機では動かせていないので、**確認をお願いしたい**。

### 1. `tramp-set-completion-function` が自前 parse を捨てる (致命的だった)

30.1 の FILE 検査には「FILE がメソッド名と同一の文字列なら通す」分岐があるが
(30.1 `tramp.el:2226-2227`)、29.4 の Tramp 2.6 系には**無い** (29.4 `tramp.el:2529-2542`)。

読むファイルを持たない自前 parse 関数は FILE にメソッド名を渡して登録するため、
29.4 では `(file-exists-p "ssh")` が nil になって 3 本とも黙って捨てられる。
エラーも警告も出ない。`~/.ssh/config` だけが残り、`my/tramp-extra-hosts` も
キャッシュ候補も永久に効かなくなる。

29.4 の実装を 30.1 に移植して実行し、実際に消えることを確認済み。
対処として `tramp-completion-function-alist` を直接組み立てる
`my/tramp--set-completion-function` に差し替えた。

### 2. `tramp-use-connection-share` が 29.4 に存在しない

30.1 で `tramp-use-ssh-controlmaster-options` からリネームされた変数。
29.4 には旧名しか無いので、新名へ素で `setq` すると誰も読まないゴミ変数が
生えるだけで、旧変数が既定 `t` のまま残る。**macOS の既定は `t`** なので
`~/.ssh/config` の `Control*` 設定が Emacs 側の `-o ControlMaster=auto` に
上書きされる。main では効いていた設定がサイレントに死ぬ。

`boundp` による機能検出で分岐するようにした
(`my/tramp-disable-connection-share`)。

---

## 確認チェックリスト

優先度順。`git switch fix/windows-shell-and-tramp` して確認する
(**マージ前に確認したい**。壊れていたら `git switch main` で戻れる)。

### 0. 起動前の掃除 (これを忘れると原因不明の二重定義になる)

```sh
ls ~/.emacs.d/inits/31_terminal-test.elc
```

`.elc` は `.gitignore` 済みなので **git が消してくれない**。過去に `inits/` を
バイトコンパイルしていると、リネーム前の `31_terminal-test.elc` が残る。
init-loader は数字 2 桁始まりのファイルを全部読むので、旧 `my/terminal-test-*` 入りの
`.elc` と新 `31_terminal.el` の両方がロードされ、`C-c T` が二重に設定される。
**あれば削除する。**

### 1. 起動してエラーが無いこと

- `M-x init-loader-show-log` / `*Messages*` にエラーが無い
- 特に `void-variable` / `void-function` が出ていないこと

### 2. `tramp-use-connection-share` の分岐 (29.4 対応 #2 の確認)

一度 `C-x C-f /ssh:` を触って `tramp-sh` をロードさせてから:

- `C-h v tramp-use-connection-share` → **29.4 なら「void」が正解**
- `C-h v tramp-use-ssh-controlmaster-options` → **`nil` になっていること**
  - `t` のままなら分岐が効いていない

### 3. 補完ソースの登録 (29.4 対応 #1 の確認。**ここが一番重要**)

- `C-h v tramp-completion-function-alist` → `ssh` のエントリが **4 本**あること
  (`tramp-parse-sconfig` + `my/tramp-parse-*` 3 本)
  - **1 本しか無ければ 29.4 対応 #1 が効いていない**
- `M-:` で `(setq my/tramp-extra-hosts '("test.example"))` を評価 → `C-x C-f /ssh:` で
  `test.example` が候補に出ること
  - 修正前の 29.4 では絶対に出ない。ここが通れば #1 は解決している

### 4. 補完候補の中身

- `C-x C-f /ssh:` → 候補が `~/.ssh/config` の Host エントリだけ
  - **`known_hosts` 由来が消えているのが正解** (意図した変更)
  - mac の `~/.ssh/config` が薄いと候補がほぼ空になる。困るなら
    `~/.ssh/config` に Host を書くか、`~/.emacs.local-inits/` で
    `my/tramp-extra-hosts` を設定する
- どこかへ 1 回繋いだあと `/ssh:` を打ち直し → `user@host` が **1 候補**に
  まとまって出ること (2 分割されないこと)

### 5. terminal (リネームの確認)

mistty / C-t の設計自体は元々 mac で確認済み。リネームで壊れていないかだけ見る。

- `C-t` → `*mistty:local*` が開いて fish が動く
  - `*shell:local*` になったらリネーム経路の破損
- `C-c T ?` → Help が出る。`C-c T w` の行が見える
- `C-c T w` → 「WSLはWindows専用です」と断られる

### 6. 新機能 (mac でも効くもの)

- `C-x C-d` → `h` で narrow → 「Remote dirs」ソースが出る
- リモートファイル候補上で `M-o X` (embark) → その接続のキャッシュが消える。
  ローカルファイル上なら「リモートパスではありません」と断られる

### 7. バイトコンパイル

- `M-x byte-compile-file` を `inits/30_test-new.el` に対して 1 回 → 新規警告が無いこと
- **確認したら `.elc` は消すこと** (0. と同じ理由)

---

## 未検証・リスクとして残っているもの

正直に列挙する。

1. **29.4 実機での実行は一度もしていない。** 上記はすべて「29.4 のソースを読んだ」+
   「29.4 の実装を 30.1 に移植して動かした」であって、本物の 29.4 バイナリでは
   動かしていない。
2. `my/tramp--set-completion-function` は `tramp-completion-function-alist` を
   直接書いており、公式セッターを迂回している。29.4 と 30.1 で alist の形式が
   同一であることは確認済みだが、将来 Tramp が内部表現を変えたら壊れる。
3. 29.4 では `/fcp:` の補完ソースも差し替え対象に入る。`/fcp:` を常用していないなら無害。
4. mac の `~/.ssh/config` と `~/.emacs.local-inits/` の中身は不明。
   `~/.emacs.local-inits/` は **git 管理外なので手で持っていく必要がある**
   (Windows 側には `50_local-tramp-hosts.el` を置いてある)。
5. `~/.bashrc` の `bind` ガード (Git Bash のノイズ対策) は Windows のホーム
   ディレクトリにあり、リポジトリ外。mac には無関係。

---

## マージ計画

1. 上のチェックリストを mac で通す
2. 落ちた項目があれば **このブランチ上で修正**する (main は触らない)
3. 全部通ったら:
   ```sh
   git switch main
   git merge --ff-only fix/windows-shell-and-tramp
   git push origin main
   ```
   fast-forward できるはず。できなければ main が進んでいるので、その時点で
   コンフリクトを確認する
4. **このファイル (`HANDOFF-mac-verify.md`) を削除してコミットする**
5. ブランチを削除する:
   ```sh
   git branch -d fix/windows-shell-and-tramp
   git push origin --delete fix/windows-shell-and-tramp
   ```

---

## 積み残し (このブランチの範囲外)

- `inits/30_test-new.el` というファイル名が実態と合っていない。TRAMP 設定の本体
  (2-1〜2-4 で約 900 行) がここにあり、`exec-path-from-shell` / `popper` / `diff-hl` /
  `treesit-auto` / `gt` と同居している。`31_terminal.el` と同じ理由で
  `32_tramp.el` あたりに切り出す価値がある。別ブランチで。
- 仕事の Linux ホストへの TRAMP は未検証。Windows からハングしたら
  `my/tramp-windows-force-pty-hosts` にホストの正規表現を足す。それでもダメなら
  プロンプトが解析不能なので `my/tramp-windows-login-shell-hosts` にも足す。
  詳細は `inits/30_test-new.el` の 2-1 節のコメントに書いてある。
