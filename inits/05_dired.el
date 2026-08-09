;;; 05_dired.el --- dired / dirvish 設定 -*- lexical-binding: t; -*-

(leaf dired
  :custom
  ;; 2画面 dired 時、コピー/移動先をもう一方の dired ウィンドウに自動設定
  (dired-dwim-target . t)
  ;; ディレクトリの再帰コピーは常に許可、削除は最上位のみ確認
  (dired-recursive-copies . 'always)
  (dired-recursive-deletes . 'top)
  ;; 再訪時にディレクトリ内容を自動で最新化
  (dired-auto-revert-buffer . t)
  ;; ディレクトリ移動で dired バッファを増やさない
  (dired-kill-when-opening-new-dired-buffer . t)
  ;; dired から他アプリへファイルをドラッグできる (Emacs 29)
  (dired-mouse-drag-files . t)
  ;; 削除は rm ではなくゴミ箱へ
  (delete-by-moving-to-trash . t)
  ;; wdired でパーミッションも編集可能に
  (wdired-allow-to-change-permissions . t)
  :config
  ;; ゴミ箱の行き先は `move-file-to-trash' が決める。分岐の先頭が
  ;; `system-move-file-to-trash' (C 実装) で、macOS では Finder のゴミ箱
  ;; ("戻す" が効く)、Windows ではごみ箱に入る。`trash-directory' は
  ;; その関数が無い環境 (Linux 等) 用のフォールバックなので、ここでは設定しない
  ;; (設定しても参照されない)。2026-08-08 に誤設定を削除。
  ;; dired-find-alternate-file の有効化
  (put 'dired-find-alternate-file 'disabled nil)

  ;; 既定アプリで開く処理は my-defuns.el の my/open-externally-dwim に統合した
  ;; (2026-07-31)。dired ならポイント下のファイルを対象にするので E はそのまま。

  :bind (("C-x C-j" . dired-jump)        ; 今のファイルの位置で dired を開く
         (dired-mode-map
          ("<tab>" . dirvish-subtree-toggle)
          ("r" . wdired-change-to-wdired-mode)
          ("h" . dired-up-directory)
          ("j" . next-line)
          ("k" . previous-line)
          ("l" . dired-find-file)        ; hjkl を完成させる
          ("a" . dirvish-quick-access)   ; 登録ディレクトリへ1キーでジャンプ
          ("/" . dirvish-narrow)         ; 入力で絞り込み
          ;; マウスに経路が無い操作を左手側の1打鍵に置く (94_keybinds.el 冒頭の前提)。
          ;; e / f はどちらも dired-find-file の重複だった (l が残るので困らない)。
          ("f" . my/dired-sort-next)     ; 名前↑→名前↓→更新時間↓→更新時間↑ を巡回
          ("e" . my/dired-toggle-dotfiles) ; "." 始まりの表示切替
          ("s" . dirvish-quicksort)      ; ソート切替メニュー (拡張子順・サイズ順など)
          ("H" . dirvish-history-jump)   ; 訪問履歴からジャンプ
          ("E" . my/open-externally-dwim)
          ("(" . dired-hide-details-mode)
          ("z" . peep-dired)
          ))
  )

;; diredでチラ見
(leaf peep-dired
  :ensure t
  :custom
  (peep-dired-cleanup-on-disable . t)
  (peep-dired-enable-on-directories . nil)
  :bind ((dired-mode-map
          ("p" . peep-dired)
          ("b" . peep-dired-scroll-page-up)
          ))
  )

(leaf dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :bind
  ("M-s d" . dirvish-side)
  :config
  ;; 一覧の見た目を macOS と Windows で揃える。
  ;; macOS の BSD ls は --group-directories-first を持たないので GNU ls (gls,
  ;; Homebrew の coreutils) があればそちらを使う。Windows は ls-lisp が長オプションを
  ;; 短縮形に変換し (--almost-all→-A 等)、--group-directories-first も解釈するので
  ;; 同じ文字列がそのまま通る。gls が無い Mac では BSD ls のままになる。
  (when (and darwin-p (executable-find "gls"))
    (setq insert-directory-program "gls"))
  (setq dired-listing-switches
        "-l --almost-all --human-readable --group-directories-first --no-group")
  ;; dired-use-ls-dired は既定の 'unspecified のままにする。初回の dired 表示時に
  ;; ls が --dired を受けるか自分で判定して結果を保存するため、手で決め打つ必要がない。
  (setq dirvish-hide-details t)
  (setq dirvish-side-display-alist '((side . right) (slot . -1)))
  (setq dirvish-use-header-line 'global)
  (setq dirvish-header-line-height '(25 . 35))
  ;; collapse: 一本道のディレクトリを1行にまとめて表示
  ;; nerd-icons はファイル種別ごとのアイコン。03_modeline.el で導入済みで、
  ;; フォントは Symbols Nerd Font Mono を自動選択している。
  ;; 属性の実体は dirvish-icons 拡張にあり、attributes に名前を書くだけでは
  ;; 読み込まれないので明示的に require する。使えない環境ではアイコン抜きにする。
  (setq dirvish-attributes
        (if (and (require 'dirvish-icons nil t) (require 'nerd-icons nil t))
            '(subtree-state nerd-icons collapse file-time file-size)
          '(subtree-state collapse file-time file-size)))
  ;; アイコンを少しだけ大きく。行の高さは行内で一番大きい文字で決まるので、
  ;; 上げすぎると行間が広がる。行が広がったらこの値を 1.0 に戻す。
  (setq dirvish-nerd-icons-height 1.1)
  ;; 開閉印 (▾ / ▸) はアイコンではなく素の文字。dirvish-subtree-state-style は
  ;; 既定 chevron だが all-the-icons が無いと arrow (文字) に落ちる
  ;; (dirvish-subtree.el:62)。大きさはフェイスの :height で決まる。
  ;; フェイスは dirvish-subtree が読まれるまで存在しないので、遅らせる
  ;; (未定義フェイスに set-face-attribute すると以降の :config が止まる)。
  (with-eval-after-load 'dirvish-subtree
    (set-face-attribute 'dirvish-subtree-state nil :height 1.15))
  (setq dirvish-side-attributes '(git-msg file-modes file-time file-size))
  (setq dirvish-large-directory-threshold 20000)
  (setq dirvish-header-line-format '(:left (path) :right (free-space)))
  (setq dirvish-mode-line-format
        '(:left (sort file-time " " file-size symlink) :right (omit yank index)))
  ;; `a' (dirvish-quick-access) で飛べる登録ディレクトリ
  (setq dirvish-quick-access-entries
        '(("h" "~/"          "Home")
          ("d" "~/Downloads" "Downloads")
          ("e" "~/.emacs.d/" "emacs")
          ("o" "~/Documents" "Documents")
          ("t" "~/Desktop"   "Desktop")))
  ;; dired-find-alternate-file の有効化は leaf dired 側に集約した

  ;; 一覧の見え方の切り替え (ソート巡回 / ドットファイル)。キーは leaf dired の :bind。
  (require 'my-dired-view)
  ;; マウス操作 (ダブルクリック / 戻る・進む / 右クリックメニュー)。
  ;; dirvish の履歴と quick-access を使うのでこの位置で読む。
  (require 'my-dired-mouse)
  (my/dired-mouse-setup)
  ;; Bookmark サイドバー (エクスプローラー左ペイン相当)。
  ;; ツリーが要るときは dirvish-side (M-s d) を使う。
  (require 'my-dired-sidebar)
  (my/quick-access-setup)
  (bind-key "M-s q" #'my/quick-access-sidebar)
  ;; ファイラ専用のタブ (tab-line)。bufferlo の tab-bar とは別物。
  (require 'my-dired-tabs)
  (my/dired-tabs-setup)
  )

(provide '05_dired)
