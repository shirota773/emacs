# Emacs 設定レビュー・修正記録

> **次回セッションの開始地点:** 現状の詳細採点、既知の問題、改善優先順位、
> 検証・引き継ぎ手順は [`CONFIG_REVIEW.md`](CONFIG_REVIEW.md) を先に参照する。
> このファイルは過去の修正経緯と確定済み判断の記録として使う。

- 日付: 2026-07-03
- ブランチ: `refactor/config-cleanup`(main へは squash merge 予定)
- コミット: `0755189`(一括整理)、`2ae4314`(swiper 復帰)
- 用途: 今後の修正・レビューの参照用(git 管理、リポジトリに含める)

---

## 1. この設定の性格(レビューでの評価)

- 中核は自作 tabspace 群(タブ=プロセス単位のワークスペース運用、約1,000行)。
  セッション/レイアウト永続化、ダッシュボード起動画面、タブ単位ディレクトリジャンプ。
- 補完系はモダン(vertico/consult/embark/orderless/corfu/cape)。
- 日本語・クロスプラットフォーム対応が丁寧(IME カーソル色、全角空白、CRLF 対策)。
- view-mode(読む操作)重視。03_view-visual.el は品質が高い。
- 弱点だったのは「コードを書く支援」(LSP/tree-sitter)、window 配置制御、TRAMP チューニング。

## 2. ユーザーの不満点と対応結果

| 不満 | 原因 | 対応 | 状態 |
|---|---|---|---|
| magit で commit できない | git-commit-mode-hook の廃止パッケージ fci-mode がエラー + server 未起動(Windows のみ start していた) | fci → 組み込み display-fill-column-indicator-mode、server-start を全 OS 化、magit-commit への advice 等の回避策を全撤去 | **解決確認済み** |
| 別ディレクトリのファイルを開くのが手間 | 仕組み(consult-dir/my/global-dirs/dirvish quick-access)はあるが分散、my/global-dirs は custom-file=null-device のため Customize で永続化不能 | 未対応。bookmark(dired バッファの C-x r m)か my/global-dirs の setq 運用を推奨 | **未対応・検討中** |
| 新規バッファの window 挙動 | display-buffer-alist がほぼ未設定 | popper + 基本ルールを 30_test-new.el に追加 | 試用中 |
| TRAMP が遅い/不安定 | 設定ゼロ。recentf の kill-emacs cleanup がリモート stat でハング | 30_test-new.el にチューニング一式、recentf cleanup 廃止 | 試用中 |
| emacs から git が見えない | status ヘッダー削除・magit-git-debug 等 | 撤去 + diff-hl 追加 | 試用中 |
| macOS でタブバーが表示されない | `tab-bar-auto-width-min/max` に Emacs 30 形式 `((N) M)` を設定していた。29 は `(N M)` 形式のため redisplay 中の幅計算が黙って型エラー → tab-bar-lines が 0 に戻され常に非表示 (emacs-mac は無実、-Q 最小再現で特定) | バージョン分岐の setq に修正 (04_tabspace.el)。**leaf の :custom は値の式を評価できない**(シンボルを変数として nil 設定する)ので式が要る値は :init で setq する | **解決 (2026-07-24)** |

## 3. swiper vs consult-line の結論(重要・再挑戦しないこと)

**C-s は swiper を維持する。consult-line への移行は一度失敗済み(2ae4314 で revert)。**

理由(ソースレベルで確認済み):
- consult-line は候補を「現在行→末尾、先頭→現在行」に**回転**させる
  (`consult--line-candidates`)。バッファの行順にならない。
  `consult-line-start-from-top t` で行順にはなるが開始位置が常にバッファ先頭になる。
- vertico は入力のたびに選択が先頭候補にリセットされ、さらに default 候補を
  リスト先頭へ移動する実装。swiper の「入力中も現在位置付近に留まる」
  「C-s C-s で前回検索を再実行」は再現不能。
- 作者 minad の公式見解: consult-line は isearch/swiper の置き換えではない
  (consult#318, consult#417, emacs-bedrock ML)。要望は繰り返し出て却下されている。
- 代替案があるとすれば swiper でなく**素の isearch**(C-s C-s 再検索・バッファ順は
  isearch の設計そのもの)。近代化するなら isearch-mb + consult-isearch-history。
- vertico-map の C-s → vertico-next は consult-grep 等で有用なので残した。

## 4. 削除したもの(復活させない・理由つき)

| 削除対象 | 理由 |
|---|---|
| orgmode.org/elpa アーカイブ | 2022 年閉鎖。package-refresh が毎回失敗していた。nongnu を追加 |
| autoload 群 (riece/eperiodic/palette/yen/wc/where 等) | auto-install 時代の遺物、ファイル実体も使途もない |
| text-translator | Google 側変更で動作しない。gt (旧 go-translate) へ移行 |
| key-chord | インストールのみで mode 未有効・定義ゼロ |
| smart-tab | TAB を補完/インデント切替するパッケージ。未有効化。corfu があり不要 |
| windata + sdic defadvice | sdic はもう存在しない |
| igrep 残骸 / grep-a-lot / color-moccur (occur-by-moccur) | consult-grep/ripgrep + wgrep に一本化。M-s o は組み込み occur に戻った |
| esup + noflet 計測機構 | 常用設定に不要。必要時に手動 eval で足りる |
| fill-column-indicator (fci-mode) | 廃止パッケージ。**magit commit 不能の原因だった** |
| max-specpdl-size / max-lisp-eval-depth の異常値 | 無限再帰の検出を殺すだけ。specpdl は Emacs 29 で廃止 |
| (setq-default auto-fill-mode t) | auto-fill-mode は変数でないため無効果だった |
| win:other-frame / win-resume-menu (C-x 5 5, C-c 6) | windows.el 未ロードで押すとエラーになるだけだった |
| my/tabspaces-open-project-tree | treemacs 未インストールの死にコード |
| magit-commit への advice / status ヘッダー間引き / magit-git-debug | commit 問題の対症療法。真因解決により不要。Windows の間引きのみ windows-nt-p 分岐で維持 |
| swiper (→ 後に復帰) | 上記 §3 参照。**削除しないこと** |

## 5. キーバインドの決定事項

- `C-.` = my/dabbrev-expand-or-completing-read(embark-act は M-o のみ)
- `C-x C-b` = ibuffer に一本化
- `M-s h` は dirvish-history-jump / puni-beginning-of-sexp とも削除(両方未使用)
  - puni の M-s l と *puni-repeat も同時に削除
- `M-s o` = 組み込み occur(moccur 廃止に伴い標準に戻った)
- `C-s`(vertico-map 内)= vertico-next
- `C-x M-t` = gt-do-translate(翻訳)

## 6. 構造変更

- tabspace-util.el (818行) を分割:
  - `tabspace-util.el` … コア(session save/load/delete, layout, winner 同期, advice)
  - `tabspace-list-ui.el` … *Tab Sessions* / *Tabspaces Buffers* の special-mode 2つ
  - ASCII アートヘッダーは `my/tab-util--insert-ascii-header` に共通化
  - 01_setup.el の my/startup-screen は tabspace-list-ui を require するよう変更
- 各 inits ファイルに (provide 'NN_name) を補完(02_packages, 05_dired, 05_editting, 94_keybinds)
- web-mode の対象を html/php に縮小(js/json/css は組み込みモードへ)
- bookmark: 自由変数 `bookmark` 依存の hook → bookmark-jump への :after advice
- completion-ignore-case の矛盾(t→nil の二重設定)を整理: コード補完=区別する、
  ファイル名/バッファ名=区別しない

## 7. 試用中 — 判定待ち

セクション単位で「定着なら NN_name.el へ昇格 / 不要なら削除」する。

1. **exec-path-from-shell** (macOS) — GUI Emacs の PATH を fish と一致させる
2. **TRAMP チューニング** — locks 抑止 / vc 無効化 / recentf・save-place の終了時
   ハング対策 / リモートで whitespace auto-cleanup 無効化。
   さらに高速化: ~/.ssh/config に ControlMaster auto + ControlPersist 10m
3. **popper** — C-` トグル / M-` 巡回 / C-M-` 種別切替。JIS 配列だとキーが押し
   にくい可能性 → 不評ならキー変更
4. **treesit-auto + eglot** — LSP サーバーは別途 (pyright, typescript-language-server)。
   treesit-autoのautoload不足は `:require t` で解消済み (2026-07-14)
5. **diff-hl** — fringe に git 変更表示、magit 連動
6. **gt** (旧 go-translate、2024年頃改名) — C-x M-t
7. **terminal比較 (`inits/31_terminal-test.el`)** — 2026-07-14追加。
   主用途をnative Windows Emacs→TRAMP remote workstationと確定し、既存F12を
   維持したままGhostel (`C-c T g`)、MisTTY (`C-c T m`)、shell+coterm
   (`C-c T c`)を同じremote bufferから比較する。`C-c T r`で採点表、
   `C-c T ?`でHelp。Windows仕事PCでの接続・resize・TUI・日本語・終了処理を
   実機採点してから本採用を決める。
   2026-07-23: eat (NonGNU ELPA 0.9.4) を追加 (`C-c T e`)。macOS local/TRAMP/
   claude等TUIの本命候補として、常用キー `C-t` (`my/eat-here`、default-directory
   でlocal/remoteを判定し接続単位バッファを再利用) も最初から割当。
   native Windows非対応のためコマンド側でガード。

8. **bufferlo (GNU ELPA 1.2)** — 2026-07-23移行。tabspaces + 自作 tabspace 群の
   置き換え。GUI で実機確認してから判定する項目:
   - タブ bookmark 運用: hydra `s`/`C-s`/`d` (保存/読込/削除)、`S` 一括保存、
     閉じ時 when-bookmarked 自動保存、起動時 'all 復元、600秒自動保存
   - `C-;` の Local Buffers ソース最優先表示、`C-r` トグル、`C-f` hydra 新構成
   - レイアウト切替 (同一タブで別名 bookmark をロード) の使用感
   - bufferlo-anywhere-mode は未使用 (素の C-x b はフィルタされない)。
     厳密なフィルタが欲しくなったら試す
   - 旧データ: var/tabspace-sessions/ と var/tabspaces-session.eld は
     動作確認後に手動削除してよい (テストデータのみ)

## 8. 未対応・保留リスト(次回レビューの候補)

- [x] 別ディレクトリ問題の本命対応: **bookmark 運用で整備 (2026-07-04)**。
      dired で C-x r m → ディレクトリをブックマーク、C-x r b (consult-bookmark、
      プレビュー付き) でジャンプ。consult-dir (C-x C-d) にもブックマークが出る。
      あわせて dired/dirvish を拡充: C-x C-j (dired-jump)、dwim-target、ゴミ箱削除、
      dired-mode-map に a (quick-access) / "/" (narrow) / s (quicksort) / H (履歴) /
      E (OSで開く) / l (find-file)。
      (my/global-dirs の ~/.emacs.local-inits setq 案は不採用のまま保留)
- [x] bookmark のタブ/レイアウトスコープ化 **(2026-07-04)**。
      tabspace-bookmark-util.el 新設: bookmark-set 時に現タブ名・現レイアウト名を
      props (tabspace / tabspace-layout) へ自動記録し、hydra (C-f) の
      bj (現タブ) / bl (現レイアウト) / bm (登録) でスコープ付きジャンプ。
      「現在のレイアウト」は save/load-layout の直近の名前を
      tabspace-util.el の my/tabspace--active-layout で追跡 (起動直後は nil)。
      保存先は従来どおりグローバル1ファイルで C-x r b は全件のまま。
      既存 bookmark はどのタブにも属さないグローバル扱い。
- [x] `M-.` の競合を解消 **(2026-07-14)**。`xref-find-definitions` へ戻し、
      xrefの定義・参照候補表示を `consult-xref` へ統一。
- [x] tabspaces 組み込みセッション自動復元と自作セッション機構の二重管理
      **(2026-07-23 解消)**。tabspaces と自作セッション/レイアウト/winner 同期
      (tabspace-util.el)・ダッシュボード UI (tabspace-list-ui.el) を全撤去し、
      bufferlo のタブ bookmark に一本化 (`refactor/tabspaces-to-bufferlo`)。
      - セッション/レイアウト = タブ bookmark。レイアウトは
        「タブ名/レイアウト名」(例 work/dev) の別名保存で表現する
      - winner タブ同期 → 標準 tab-bar-history-mode (copy-tree の vector 共有
        バグも同時解消)。日本語タブ名のセッションファイル衝突も消滅
      - 起動画面 → bookmark-bmenu-list (B-Tab 行を RET で復元)
      - dir-util は tab-dir-util.el として独立 (var/tab-dirs.eld)、bookmark
        スコープは tab-bookmark-util.el (アクティブタブ bookmark 名を参照)
- [ ] custom-file = null-device の副作用: package-selected-packages が保存されず
      package-autoremove / 新マシン一括導入が機能しない
- [ ] 不要になったパッケージ実体の掃除(key-chord, smart-tab, color-moccur,
      grep-a-lot, esup, noflet, fill-column-indicator 等)。
      **ivy/swiper は削除しないこと**(C-s で使用中)
- [ ] whitespace-action auto-cleanup はローカルでも共有リポジトリでは diff 汚染の
      リスク(現状リモートのみ無効化)
- [ ] 05_editting.el の isearch-mode-map C-t (visual-regexp-steroids) は C-s が
      swiper のため実質死にバインド
- [ ] インストール済みだが古いもの: minor-mode-hack, viewer 等は動いているので現状維持

## 9. 検証方法(この修正で使ったコマンド)

2026-07-14のP0修正後、`init-loader-error-log` が空であること、`M-.` と
`consult-xref` の配線、`global-treesit-auto-mode`、
`init-loader-show-log-after-init=error-only` をバッチで確認済み。
GUIでの操作感は次回の通常起動時に確認する。

```sh
# フルロード + init-loader エラーログ確認(新パッケージも自動インストールされる)
emacs --batch -l ~/.emacs.d/init.el \
  --eval '(princ (concat "ERRORS:\n" (or (init-loader-error-log) "") "\n"))'

# 括弧整合性のみの簡易チェック
emacs --batch --eval '(with-temp-buffer (insert-file-contents "FILE") (emacs-lisp-mode) (check-parens))'
```

- init-loader はファイル単位でエラーを握って続行するため、起動できても
  エラーログの確認が必須。
- MELPA のパッケージ名は変わることがある(go-translate → gt で実際に遭遇)。
  `package-archive-contents` で存在確認してから leaf を書く。

## 10. 参考リンク

- consult#318 (n/N 移動の要望・却下): https://github.com/minad/consult/issues/318
- consult#417 (swiper-isearch 相当の要望): https://github.com/minad/consult/issues/417
- emacs-bedrock「consult-line を isearch 代替に勧めるのをやめては」:
  https://lists.sr.ht/~ashton314/emacs-bedrock/%3CCAKdxknyKAd4fjOWw=MXpjFeqHHgXaDpZ=N2wfjZsNnhN_VGVpg@mail.gmail.com%3E
- isearch-mb: https://elpa.gnu.org/packages/isearch-mb.html
