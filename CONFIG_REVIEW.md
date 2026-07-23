# Emacs 設定 詳細評価・改善引き継ぎレポート

- 評価日: 2026-07-13
- 評価対象: `init.el`、`inits/` の有効設定、`inits/my-utils/`
- 評価時ブランチ: `refactor/config-cleanup`
- 評価時 HEAD: `cfbc0a8`
- 実行環境: GNU Emacs 29.4 development build (`new-ver-30` branch)、macOS
- 総合評価: **6.3 / 10**
- 最終更新: 2026-07-14（Windows/TRAMP優先のterminal比較設定を追加。仕事PCで実機判定待ち）
- 文書の役割: 現状評価、技術的根拠、改善方針、次回セッションの開始地点を1ファイルに集約する

この文書は、次回以降の作業者が過去の会話を読めない状態でも、調査をやり直さずに
改善作業へ入れることを目的とする。過去に実施した変更の時系列と確定事項は
`review-notes.md` も参照すること。

---

## 1. 最初に読む要約

この設定は、補完・検索、Dired、日本語入力、クロスプラットフォーム対応が強い。
一方、現在不満が出やすい領域は「機能不足」よりも、標準機能・外部パッケージ・
独自実装の責任範囲が重なっていることが原因である。

特に重要な結論は次のとおり。

1. **関数・変数ジャンプの不満には設定上の明確な原因があった。**
   評価時は標準の `M-.` (`xref-find-definitions`) が `embark-dwim` で上書きされていた。
   2026-07-14にxrefへ戻し、候補表示を `consult-xref` へ接続済み。
2. **tree-sitter は設定されていたが、評価時は起動エラーで有効化されなかった。**
   2026-07-14に `treesit-auto` の明示ロードを追加し、
   `global-treesit-auto-mode` が有効になることをバッチ検証済み。
3. **tabspace は使いこなし不足ではなく、操作モデルが複雑すぎる。**
   tabspaces標準セッションと独自セッション、独自レイアウト、独自bookmark、
   独自Winner履歴、独自一覧UIが重なっている。
4. **ターミナルはWindows/TRAMPを最優先に比較試験中。**
   `<f12>` の既存 `shell` をfallbackとして維持し、`31_terminal-test.el` で
   Ghostel、MisTTY、shell+cotermを同じTRAMP bufferから比較できる。
5. **Diredはすでに高水準。**
   新しいファイラーを追加するより、操作発見性とTRAMP時の軽量化を改善すべき。
6. **Windowの予測しづらさは広すぎる `display-buffer-base-action` が一因になり得る。**
   Popper対象外のバッファまで同じwindowを再利用しやすい。

最初の改善単位として挙げた以下の3つは、2026-07-14に実装・バッチ検証を完了した。

- `M-.` をxrefへ戻し、xref候補表示をConsultにする
- `treesit-auto` のロードエラーを直す
- init-loaderの誤った変数名を直し、起動エラーを確実に見えるようにする

tabspaceの大規模整理やActivitiesへの移行は、その後に独立した実験として行う。

---

## 2. 評価方法

### 2.1 点数の意味

| 点数 | 判定 | 意味 |
|---:|---|---|
| 9–10 | 卓越 | 一貫した操作モデルがあり、エラー耐性・保守性も高い |
| 7–8 | 良好 | 日常利用に十分強く、小さな整理で安定する |
| 5–6 | 実用 | 動くが、競合・認知負荷・保守上の弱点がある |
| 3–4 | 要改善 | 機能はあるが、期待どおり使えない場面が多い |
| 1–2 | 未整備 | 最低限の設定だけ、または実質利用経路がない |

### 2.2 評価観点

- 実際にロードでき、設定が有効になるか
- 頻出操作が少ない判断回数で実行できるか
- Emacs標準機能と外部パッケージの責任範囲が明確か
- パッケージ更新時に壊れにくいか
- macOS / Windows / TRAMPで挙動を予測できるか
- 次回の作業者が変更理由を追跡できるか

総合点は単純平均ではない。現在の日常機能の豊富さを加点しつつ、起動時エラー、
tabspaceの認知負荷、主要ジャンプキーの消失を強く減点して **6.3** とした。

---

## 3. 採点一覧

| 評価領域 | 点数 | 現状の短評 | 改善後の目標 |
|---|---:|---|---:|
| 起動・堅牢性 | 5.5 | 全体はロード可能だがtreesit-autoがエラー。init-loader設定名にも誤り | 8.0 |
| 構造・保守性 | 5.0 | 番号順・leaf・utils分割は明快。独自tabspace層が大きい | 7.5 |
| 補完・検索 | 8.0 | Vertico / Consult / Embark / Orderless / Corfu / Swiperが充実 | 9.0 |
| 編集支援 | 8.0 | Puni、Expreg、Undo、Diff表示などが強い | 8.5 |
| 関数・変数ジャンプ | 4.0 | Eglotはあるが `M-.` がxrefでなく、treesitも未稼働 | 8.5 |
| Dired・ファイル操作 | 8.0 | Dirvish、絞り込み、履歴、bookmark連携が高水準 | 9.0 |
| TRAMP | 6.5 | 主要な高速化策はあるが全接続一律、安全性と交換 | 8.0 |
| ターミナル | 3.5 | 3候補の比較導線を追加。Windows→TRAMPの実機採点と本採用は未完了 | 8.0 |
| Window構成 | 5.5 | Popper / Ace Windowは良いが表示規則と履歴が重複 | 8.0 |
| tabspace・作業環境 | 4.0 | 高機能だが二重管理と独自概念が多い | 8.0 |
| 日本語・OS対応 | 7.5 | IME、カーソル、Windows改行コード対応が丁寧 | 8.5 |
| 新しいEmacs機能の採用 | 8.0 | Eglot、tree-sitter、Dirvish等を採用。ただし一部試用のまま | 9.0 |

---

## 4. 領域別の詳細評価

### 4.1 起動・堅牢性 — 5.5 / 10

#### 良い点

- `init.el` はブートストラップと `init-loader` に集中している。
- `inits/NN_name.el` の番号順ロードは理解しやすい。
- `no-littering` により生成物の保存先が整理されている。
- `leaf` に宣言を統一しており、パッケージの所在を追いやすい。

#### 問題

1. `inits/30_test-new.el` の `global-treesit-auto-mode` が現在エラーになる。
   インストール済み `treesit-auto` のautoloadに関数定義が登録されておらず、
   `:config` 実行前に明示的な `require` が必要な状態だった。
2. `init.el` は `init-loader--show-log-after-init` を設定しているが、正しい公開変数は
   `init-loader-show-log-after-init` である。現在の記述では意図した `error-only` が効かない。
3. init-loaderはファイル単位のエラーを記録して次へ進むため、Emacsが起動できたことは
   設定がすべて有効になったことを意味しない。
4. パッケージ版を固定していないため、MELPA更新でautoloadやAPIが変わると
   起動時に一部だけ無効になる可能性がある。今回のtreesit-autoが実例。
5. `custom-file` が `null-device` なのでCustomizeによる変更や
   `package-selected-packages` は永続化されない。これは意図的方針だが、
   新しい端末への再構築性を下げている。

#### 改善方針

- treesit-autoを明示ロードする。
- init-loaderの変数名を訂正する。
- バッチロード検証を変更ごとに実行する。
- 将来的には最低限のERTまたは起動smoke testを用意する。
- パッケージ固定を導入する場合は、全面移行より重要パッケージから始める。

### 4.2 構造・保守性 — 5.0 / 10

#### 良い点

- `01_setup`、`02_vertico`、`04_tabspace`、`05_dired` の責任範囲は概ね分かる。
- 大きな自作関数は `inits/my-utils/` へ抽出されている。
- 各ファイル末尾の `provide` 規則が整備されている。
- コメントは日本語中心で、意図を追いやすい。

#### 問題

- 有効なElispは約3,127行。
- tabspace関連だけで約1,100行あり、設定全体の約3分の1を占める。
- `tabspace-list-ui.el` は518行あり、一部の関数が1行へ高密度に記述されている。
- `30_test-new.el` にPATH、TRAMP、Window、tree-sitter、Eglot、diff、翻訳が同居する。
  試用期間が長くなるほど、どれが正式採用か判断しづらい。
- `tabspaces--buffer-list`、`tab-bar--current-tab`、Winner内部変数など、
  パッケージ・Emacsの内部APIへの依存が多い。

#### 改善方針

- 試用が確定した設定を領域別ファイルへ昇格する。
- tabspaceの公開APIと独自データ構造を整理する。
- 1変更1テーマでコミットし、レポートの変更履歴も更新する。

### 4.3 補完・検索 — 8.0 / 10

#### 良い点

- Vertico / Marginalia / Orderless / Consult / Embark の構成は現代的。
- `consult-buffer`、`consult-ripgrep`、`consult-imenu`、`consult-bookmark` が揃う。
- Corfu / Capeによりbuffer内補完も整備されている。
- `C-s` にSwiperを維持した判断は、現在位置付近からの検索を重視する要件と一致する。
- `consult-dir` とbookmark、tabspaceのprocess rootを結びつけている。

#### 問題

- IvyはSwiperのためだけに残り、Verticoと2つのminibuffer UIが共存する。
  これは許容可能だが、今後「統一のためだけ」にSwiperを外さないこと。
- `C-r` はminibuffer状態に応じてrecentfとtabspaceを切り替える独自状態機械で、
  初見では挙動を予測しにくい。
- `consult-xref` がxref表示へ接続されていない。

#### 確定事項

- **`C-s` はSwiperを維持する。** `consult-line` への置換は再提案しない。
- Embarkの主要操作は `M-o` とし、`M-.` を占有させない。

### 4.4 編集支援 — 8.0 / 10

#### 良い点

- PuniとExpregによる構造編集・範囲選択が充実。
- undo-fu / undo-fu-session / vundo の役割分担が明確。
- symbol-overlayとrepeat-modeを利用している。
- diff-hl、Magit、wgrepがあり、変更確認と一括編集がしやすい。
- read-only表示を独自face remapで明確化する `03_view-visual.el` は品質が高い。

#### 問題

- HydraとMykie、通常のkeymap、repeat-mapが混在し、同じ操作領域に複数の操作方式がある。
- `whitespace-action` の `auto-cleanup` は保存時に変更を発生させるため、
  リモート以外でも共有リポジトリのdiffを意図せず広げる可能性がある。

### 4.5 関数・変数ジャンプ — 4.0 / 10

#### 現在の状態

- `M-s i` は `consult-imenu`。
- EglotはPython、JavaScript、TypeScript系hookで `eglot-ensure`。
- `M-.` は `embark-dwim`。
- `M-,` は標準の `xref-go-back` が残っている。
- xref候補UIはConsultへ接続されていない。
- treesit-autoが起動エラーのため、期待した `*-ts-mode` 移行が成立していない。

#### 評価

戻るキーだけxrefで、行くキーが別機能になっているため、コード移動の基本往復が崩れている。
これは「使いこなせていない」のではなく、設定上の競合である。

#### 推奨する最小構成

- `M-.` → `xref-find-definitions`
- `M-,` → `xref-go-back`
- `M-?` または適切なキー → `xref-find-references`
- `xref-show-xrefs-function` → `consult-xref`
- `xref-show-definitions-function` → `consult-xref`
- 同一buffer内の構造移動 → `consult-imenu`
- 複数bufferを横断する場合 → `consult-imenu-multi`
- 言語意味論を使うジャンプ → Eglot/xref

Elispの関数・変数はxref backendで扱えるため、まず追加パッケージより標準経路を復旧する。

### 4.6 Dired・ファイル操作 — 8.0 / 10

#### 良い点

- DirvishをDiredの表示強化として正しく利用している。
- `dired-dwim-target` により2画面コピー・移動が便利。
- recursive copy/delete、auto revert、buffer再利用、ゴミ箱、wdiredを設定済み。
- subtree、narrow、quicksort、history、quick accessが揃う。
- `C-x C-j` の `dired-jump`、bookmark、consult-dirにより
  「現在地から開く」「登録場所へ移動する」の両方がある。
- OS既定アプリで開く関数はmacOS / Windows / Linuxに対応。

#### 問題

- Peep DiredとDirvishが一部同じプレビュー領域を担い、キーも複数ある。
- quick access、bookmark、consult-dir、tabspace directoryの4経路があり、
  「どこを恒久登録するか」のルールが明文化されていない。
- Dirvish属性取得はTRAMP上で追加のリモート処理を増やす可能性がある。

#### 推奨する役割分担

- 一時的な移動: `consult-dir`
- 長期的な場所登録: bookmark
- 現在のファイル位置: `dired-jump`
- project内移動: `project.el` / Consult
- tab専用のprocess root: terminalやcompileの起点だけに限定

### 4.7 TRAMP — 6.5 / 10

#### 良い点

- `tramp-verbose 1` で通常時ログを抑えている。
- SSH ControlMasterはユーザーの `~/.ssh/config` を尊重する。
- VCがリモートで自動実行される遅延を抑止している。
- recentf / save-placeが終了時にリモートstatして固まる対策がある。
- リモートbufferではwhitespace自動cleanupを止める。

#### リスク

- `remote-file-name-inhibit-locks t` は他セッションとの編集競合検知を失う。
- `01_setup.el` でも `create-lockfiles nil` のため、remote限定設定以前に
  ローカルを含めlockが全面無効になっている。
- VC除外が全リモートに適用され、リモートMagit/VCを使いたい接続も対象になる。
- ホストや接続方式ごとの差を扱っていない。
- Diredのlisting switchesとDirvish属性がリモートOSに最適とは限らない。

#### 改善方針

- Emacs 30以降ではconnection-local variablesでホスト別設定に寄せる。
- 競合があり得る環境ではlockを復活させる。
- SSH ControlPersistはEmacs設定ではなく `~/.ssh/config` で管理する。
- TRAMP用Diredでは重いDirvish属性を減らす。
- 実測せずにcache設定を増やさない。

### 4.8 ターミナル — 3.5 / 10

#### 現在の状態

- `<f12>` はfallbackとして組み込み `shell` のまま維持。
- `exec-path-from-shell` によりGUI EmacsのPATHをfishと合わせる設定はある。
- Popperは `shell-mode` / `eshell-mode` bufferを対象にできる。
- `31_terminal-test.el` でGhostel、MisTTY、shell+cotermを試験導入済み。
- `C-c T g/m/c` で、選択中bufferの `default-directory` を起点に比較できる。
- `C-c T r` は環境情報入りの採点表、`C-c T ?` は操作Helpを生成する。
- projectごとのterminal生成・再利用規則はない。

#### 確定した利用条件

- privateはmacOS、仕事はnative Windows Emacs。
- 主用途はWindowsからremote workstation上のファイルをTRAMPで編集すること。
- Windows local terminalは約10%。
- 優先順位はWindows→TRAMPの接続安定性と自然な操作、次にlocal terminal。

#### 不足している体験

- fishのネイティブ補完・autosuggestion
- full-screen TUI
- Claude Code等の大量再描画
- terminalのリサイズ・reflow
- project単位のbuffer命名と再利用
- tabspace/process rootとの明確な連携
- TRAMP先で同じ操作によるterminal生成

#### 比較対象

1. **Ghostel**
   - libghostty-vtベースで、Windows→POSIX TRAMPを明示対応。
   - Windows対応は0.43.0 (2026-07-11) で追加されたばかり。
   - Windows→TRAMPでは動的window resizeが未対応。
   - native moduleのdownloadが仕事PCの制限下で可能かも評価対象。
   - https://dakra.github.io/ghostel/
2. **MisTTY**
   - TRAMP `default-directory` からremote shellを直接起動できる。
   - shell操作とEmacs編集を混ぜやすいが、公式動作確認OSはLinux/macOS。
   - native Windows Emacsでの成否を実機で判定する。
   - https://mistty.readthedocs.io/en/latest/
3. **shell + coterm**
   - TRAMP標準のremote `M-x shell` を基準経路にする保守案。
   - comintの編集性を維持し、TUI時だけ自動char modeへ切り替える。
   - https://elpa.gnu.org/packages/coterm.html
4. **eat**(2026-07-23追加)
   - 純Elispのterminal emulator。`start-file-process` 経由でTRAMP全メソッド透過。
   - claude-code.el等のTUI用途で実績。native Windows非対応。
   - macOS local/TRAMPの本命候補として常用キー `C-t` (`my/eat-here`) も割当済み。
   - https://codeberg.org/akib/emacs-eat

試験コマンドは以下。必ず比較したいTRAMPファイルbufferから実行する。

| キー | 操作 |
|---|---|
| `C-c T g` | Ghostel |
| `C-c T m` | MisTTY |
| `C-c T c` | shell + coterm |
| `C-c T e` | eat (常用: `C-t`) |
| `C-c T r` | 編集可能な比較採点表 |
| `C-c T x` | global coterm-mode停止 |
| `C-c T ?` | 使用方法・環境情報 |

現段階では圧倒的な1位を確定しない。仕事PCで同じremote hostに対し、接続・再接続、
入力遅延、TUI、resize、copy/paste、日本語幅、cwd追跡、終了処理を採点して決める。

### 4.9 Window構成 — 5.5 / 10

#### 良い点

- `winner-mode` を有効化している。
- `ace-window` を `C-x o` に割り当てている。
- 矢印Metaキーのwindmoveがある。
- Popperで一時bufferを下部へまとめる試みがある。
- Embark Collectは右side windowへ固定している。
- `03_view-visual.el` はwindow切替時のread-only見分けを補助する。

#### 問題

- `C-o`、`C-x o`、Meta矢印でwindow移動方法が3系統ある。
- `display-buffer-base-action` が全bufferに対して
  `reuse-window` / `same-window` を適用するため、対象外bufferの表示先が強引。
- `switch-to-buffer-obey-display-actions t` により影響範囲が広い。
- tabごとの履歴のためにWinner内部変数をコピーしている。
- 標準 `tab-bar-history-mode` は未使用。
- `window-util.el` の一部関数は定義されるが、日常キーから到達しにくい。

#### 改善方針

- window移動はAce Windowと隣接移動の2系統に限定する。
- Help、xref、compilation、terminal、Org、Dired side windowなどを
  `display-buffer-alist` へ用途別に定義する。
- `display-buffer-base-action` は保守的な既定へ戻す。
- tab内履歴は `tab-bar-history-mode` を第一候補とする。
- Popperは一時bufferのトグルだけに責任を限定する。

### 4.10 tabspace・作業環境 — 4.0 / 10

> **2026-07-23 更新**: 改善案A/Bに代わり **bufferlo (GNU ELPA 1.2) への移行を実施済み**
> (`refactor/tabspaces-to-bufferlo`)。tabspaces・自作session/layout/winner同期・
> ダッシュボードUI (計約900行) を撤去し、タブbookmarkへ一本化。dir-utilは
> tab-dir-util.el (専用ストア)、bookmarkスコープはtab-bookmark-util.elとして存続。
> 以下の記述は移行前の評価。GUI実機確認は review-notes.md §7 を参照。

#### 現在実装されている概念

- tabspacesによるtabごとのbuffer絞り込み
- tabspaces標準sessionとauto restore
- 独自tab session save/load/delete
- 独自named layout save/load/delete
- tabごとのprocess root
- tabごとの追加directory
- tab/layoutスコープ付きbookmark
- tabごとのWinner ring同期
- 起動時 `*Tab Sessions*` UI
- tab×buffer一覧UI
- Hydraによる20個以上の操作

#### 主な問題

1. **セッションが二重管理。**
   tabspaces標準sessionと独自sessionが同時に有効。
2. **現在のtabspacesに存在しない設定。**
   `tabspaces-session-include` はインストール版に定義がなく、効果がない。
3. **tab名がデータID。**
   rename、重複名、表記ゆれでsession/layout/bookmark/Winnerの関連がずれる。
4. **日本語tab名のsession file衝突。**
   英数字とハイフン以外を `_` にするため、複数の日本語名が同じfile名になり得る。
5. **操作判断が多い。**
   sessionとlayoutの違い、bookmarkのglobal/tab/layoutの違い、
   directoryとprocess rootの違いを毎回思い出す必要がある。
6. **内部API依存。**
   tabspaces、tab-bar、Winner更新の影響を受けやすい。

#### 評価上の結論

ユーザーがtabspaceを使いこなせていないのではない。現在の設計は、熟練しても
「どの保存・移動コマンドを使うか」の選択コストが高い。

#### 改善案A: tabspacesを残して縮小する（最初の推奨）

- buffer isolationだけtabspacesへ任せる。
- sessionはtabspaces標準か独自のどちらか一方にする。
- Window履歴は `tab-bar-history-mode`。
- directoryはbookmark / consult-dirへ寄せる。
- process rootはterminal / compile用だけ残す。
- tabspace一覧UIはConsultベースの薄いUIへ縮小する。

長所: 現在の操作を壊す範囲が小さい。

#### 改善案B: Activitiesへ段階移行する

Activitiesはtab/frame、window構成、bufferを目的単位で保存・中断・再開する。
default stateとlast-used stateを分け、bookmarkを復元基盤として使う。

- https://elpa.gnu.org/packages/activities.html
- https://github.com/alphapapa/activities.el

長所: 現在の独自session/layout/bookmark層を大幅に減らせる可能性がある。

注意: いきなり置換せず、1つの作業用途で試して復元精度を確認する。

#### 推奨する最終責任分担

| 関心事 | 担当 |
|---|---|
| 複数windowを含む仕事単位 | tab-bar + Activities、または簡略化したtabspaces |
| tab内window履歴 | tab-bar-history-mode |
| buffer選択 | consult-buffer / consult-project-buffer |
| project識別 | project.el |
| 長期保存する場所 | bookmark |
| 一時的なdirectory移動 | consult-dir |
| terminal / compileのcwd | project root、必要ならtab単位process root |
| 一時window | Popper + display-buffer-alist |

### 4.11 日本語・OS対応 — 7.5 / 10

#### 良い点

- macOSの入力ソースとcursor色を連動。
- minibufferで自動ASCII入力を使う。
- WindowsではW32-IME、日本語clipboard、CRLF対策がある。
- OS外部アプリ起動を分岐している。
- ファイル名・buffer名の大文字小文字設定が整理されている。

#### 注意点

- terminalを導入する場合、日本語IME入力、幅、copy/pasteをmacOSとWindowsで別々に確認する。
- Ghostel等のnative moduleはOSごとの差が大きいため、Windows確認前に既存 `shell` を削除しない。

---

## 5. 重要度別の課題一覧

### P0: 小さく直せて、日常操作への効果が大きい

- [x] `M-.` を `xref-find-definitions` へ戻す（2026-07-14）
- [x] xref表示を `consult-xref` へ接続する（2026-07-14）
- [x] treesit-autoを明示ロードし、起動エラーを解消する（2026-07-14）
- [x] `init-loader--show-log-after-init` の変数名を訂正する（2026-07-14）
- [x] 修正後にフルバッチロードで `init-loader-error-log` が空であることを確認する（2026-07-14）

### P1: Window・tabspaceの予測可能性を上げる

- [x] `tabspaces-session-include` の削除または現行APIへの置換(2026-07-23 tabspaces撤去で解消)
- [x] 標準sessionと独自sessionのどちらを残すか決定する(2026-07-23 bufferloタブbookmarkへ一本化)
- [x] `tab-bar-history-mode` を試し、独自Winner同期と比較する(2026-07-23 採用。独自同期は
      copy-treeのvector共有バグ持ちだったため削除)
- [ ] `display-buffer-base-action` を外して回帰を確認する
- [ ] Help / xref / compilation / terminalの表示規則を個別定義する
- [x] tab名を永続データIDに使う設計を見直す(2026-07-23 ほぼ解消。永続IDは標準bookmark名になり
      日本語名のファイル名衝突も消滅。tab-dirs.eldのタブ名キーのみ残存=軽微)

### P2: 新しい操作体験を試す

- [x] Ghostel / MisTTY / shell+cotermを同条件で比較する試験設定を追加する（2026-07-14）
- [ ] 仕事PCのWindows→TRAMPで3候補を採点し、本採用または併用方針を決める
- [ ] 採用候補をWindows local bashとmacOS local fishでも確認する
- [ ] Emacs 30.1以降へ更新後、Casual Diredを試す
- [ ] Activitiesを1用途だけで試し、tabspace独自復元との比較表を作る

### P3: 長期的な保守改善

- [ ] `30_test-new.el` の採用品を正式ファイルへ移す
- [ ] 未使用packageと死にコードを整理する
- [ ] tabspace UIの長い1行関数を整形・分割する
- [ ] 起動smoke testをスクリプト化する
- [ ] `custom-file` とpackage再構築方針を再検討する

---

## 6. 次回セッションの開始手順

次回の作業者は、以下の順で開始すること。

1. `AGENTS.md` と参照先 `/Users/shirota/.codex/RTK.md` を読む。
2. `CLAUDE.md` を読む。
3. 本ファイル `CONFIG_REVIEW.md` を読む。
4. 過去の変更判断が必要なら `review-notes.md` を読む。
5. Gitのbranchとdirty状態を確認する。
6. ユーザーの未追跡ファイルを勝手に追加・変更しない。
7. 変更前のフルロード結果を記録する。
8. P0から1テーマずつ変更し、検証後にコミットする。
9. 作業完了時に本ファイルのcheckboxと変更履歴を更新する。

評価時点では次の未追跡directoryが存在する。ユーザーまたはツール管理の可能性があるため、
明示的な依頼なしにstageしないこと。

- `.agents/`
- `.claude/`
- `.codex/`

現在は `main` ではなく `refactor/config-cleanup` branchで作業中。
`main` へ直接変更せず、統合時はsquash mergeするという `AGENTS.md` の規則を守る。

---

## 7. 検証手順

### 7.1 フルロード

検査環境ではserver socket作成が制限される場合がある。その場合のみ
`server-running-p` を検証プロセス内で上書きして、残りの設定を評価する。

```sh
rtk emacs --batch \
  --eval "(require 'server)" \
  --eval "(advice-add 'server-running-p :override (lambda (&rest _) t))" \
  -l init.el \
  --eval "(princ (format \"INIT-ERRORS:\\n%s\\n\" (init-loader-error-log)))"
```

合格条件:

- `INIT-ERRORS:` の後が空
- `Warning (leaf)` が出ない
- `treesit-auto` のvoid-functionが出ない

### 7.2 括弧・reader確認

```sh
rtk emacs --batch -Q --eval \
  '(with-temp-buffer
     (insert-file-contents "対象ファイル.el")
     (emacs-lisp-mode)
     (check-parens))'
```

### 7.3 領域別の手動受け入れ確認

#### xref / Eglot

- Elispの関数名・変数名上で `M-.` が定義へ移動する
- 複数候補ではConsult previewが出る
- `M-,` で元の位置へ戻る
- Python / JavaScript / TypeScriptでEglotが接続する
- rename、code action、formatが実行できる

#### tabspace / Window

- tabを切り替えてbuffer候補が混ざらない
- Window分割後、履歴back/forwardがtab内だけで動く
- Help、xref、compilationが編集windowを予期せず置き換えない
- Emacs再起動後、採用した1つのsession機構だけで復元できる
- tab rename後も永続データが失われない

#### Dired / TRAMP

- ローカルDiredでcopy/moveのDWIM targetが動く
- bookmarkからdirectoryへ移動できる
- TRAMP Dired表示に極端な待ち時間がない
- Emacs終了時にremote recentf確認で止まらない
- lockを無効にする場合、そのリスクをユーザーが了承している

#### Terminal

- native Windows Emacsから、TRAMP file bufferの接続情報を保って起動できる
- 接続断後に再接続でき、別hostのterminalと混ざらない
- remote bashのhistory / completion
- `top`、`less`、`tmux`、Claude Code等のTUI
- Window resize後のreflow（Ghostel Windows→TRAMPは既知の未対応項目）
- kill ringとのcopy/paste
- 日本語入力・日本語幅
- cwdがTRAMP pathとして追跡される
- Windows local bashとmacOS local fishも起動できる
- 既存 `<f12>` の `shell` fallbackが残る

---

## 8. 変更時に維持する決定事項

以下は過去に検証・決定済み。新しい根拠なしに再変更しない。

- `C-s` はSwiper。`consult-line` へ置換しない。
- `C-.` は `my/dabbrev-expand-or-completing-read`。
- Embark Actは `M-o`。
- `C-x C-b` はibuffer。
- fci-modeを復活させない。組み込み `display-fill-column-indicator-mode` を使う。
- Magit commit問題に対する古いadviceを復活させない。
- orgmode.org/elpaをpackage archiveへ戻さない。
- Windowsの日本語clipboardとCRLF対策を、macOSだけの確認で変更しない。
- Customizeの保存は現在 `null-device` へ破棄する方針。変更する場合は再構築方法も同時に決める。
- 設定・コメント・ドキュメントは日本語を基本とする。

---

## 9. 新しいパッケージの評価順位

| 優先度 | Package | 対象課題 | 判定 |
|---:|---|---|---|
| 1 | shell + coterm | Windows / TRAMP terminal | 標準TRAMP経路を使う安定性の基準候補 |
| 1 | MisTTY | TRAMP shellとEmacs編集の融合 | Windowsは公式確認外のため実機判定 |
| 1 | Ghostel | Windows / TRAMP / TUI | 最も高機能だがWindows対応が新しくresize制限あり |
| 1 | eat | macOS local / TRAMP / TUI | 2026-07-23導入済み。`C-c T e` + 常用 `C-t` で試用中 |
| 2 | Activities | tabspace / session / layout | 不採用 — 2026-07-23、レイアウトモデル適合の理由でbufferloを採用し移行済み |
| 3 | Casual Suite | Dired等の操作発見性 | Emacs 30.1更新後に試す |
| 5 | Breadcrumb | 大規模projectの現在位置表示 | xref復旧後に必要性を判断 |

補足:

- Dired本体を別ファイラーへ置き換える優先度は低い。
- xrefのために新packageを増やす前に、標準xref + Consult + Eglotを正常化する。
- tabspaceへさらに別のworkspace packageを重ねない。Activitiesを試す場合は置換候補として扱う。

参考:

- Ghostel: https://dakra.github.io/ghostel/
- MisTTY: https://mistty.readthedocs.io/en/latest/
- coterm: https://elpa.gnu.org/packages/coterm.html
- Activities: https://elpa.gnu.org/packages/activities.html
- Casual: https://github.com/kickingvegas/casual
- Emacs Tab Bar: https://www.gnu.org/software/emacs/manual/html_node/emacs/Tab-Bars.html
- Consult: https://elpa.gnu.org/packages/doc/consult/consult.html
- Eglot: https://elpa.gnu.org/devel/doc/eglot.html
- TRAMP FAQ: https://www.gnu.org/software/emacs/manual/html_node/tramp/Frequently-Asked-Questions.html

---

## 10. 目標状態

改善が完了した状態は「package数が多い」ことではなく、以下を満たすこと。

- `M-.` / `M-,` で定義へ行って戻る操作が全言語で一貫する
- tab、session、layoutの違いを日常的に意識しなくてよい
- Help、xref、terminal、compilationが予測した場所に出る
- FishとTUIがEmacs内で自然に動く
- Diredの強みを維持し、remoteでは重くならない
- 起動時エラーが自動検出される
- macOSとWindowsの既存日本語対応を維持する
- 独自Elispを減らしても、現在の主要ワークフローを失わない

点数目標は総合 **8.0以上**。P0修正だけで6点台後半、Windowとtabspaceの責任分担を
整理すると7点台後半、terminalと検証自動化まで整うと8点台を見込む。

---

## 11. レポート変更履歴

| 日付 | 内容 | 備考 |
|---|---|---|
| 2026-07-23 | tabspaces+自作tabspace群をbufferloへ移行 | `refactor/tabspaces-to-bufferlo`。session/layout=タブbookmark一本化、tab-bar-history-mode採用、自作UI 33KB削除、tab-bar-show=t |
| 2026-07-23 | eatを比較枠(C-c T e)と常用キーC-tに追加 | `feat/eat-terminal`、macOS local/TRAMP本命候補 |
| 2026-07-14 | Windows/TRAMP優先でGhostel・MisTTY・shell+cotermの比較設定を追加 | `31_terminal-test.el`、仕事PC実機採点待ち |
| 2026-07-14 | init-loaderの公開変数名を修正し、P0全項目のフルロードを再検証 | P0完了・GUI実機確認待ち |
| 2026-07-14 | treesit-auto本体をmode有効化前に明示ロード | P0 treesit-auto完了 |
| 2026-07-14 | `M-.` をxrefへ戻し、定義・参照候補表示をConsultへ統一 | P0 xref完了 |
| 2026-07-13 | 初版。詳細採点、根拠、改善順、検証・引き継ぎ手順を作成 | `refactor/config-cleanup` |
