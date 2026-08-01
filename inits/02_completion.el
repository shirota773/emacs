;;; 02_completion.el --- 補完・検索 UI 一式 -*- lexical-binding: t; -*-
;; swiper (C-s) / vertico / marginalia / consult / consult-dir / embark。
;; 補完スタイル (orderless) と補完 UI (corfu/cape) は 02_packages.el 側にある。

(require 'navigation-util)
(require 'window-util)

(file-name-shadow-mode 1)

;; =============================================================================
;; 1. Global Keybindings
;; =============================================================================
;; M-x は既定 (execute-extended-command) のため省略
(global-set-key (kbd "C-r") #'my/local-buffer-or-recentf)
(global-set-key (kbd "M-s g") 'consult-grep)
(global-set-key (kbd "M-s r") 'consult-ripgrep)
(global-set-key (kbd "M-s i") 'consult-imenu)
(global-set-key (kbd "M-o") 'embark-act)

;; C-s は swiper を維持する (consult-line では代替不可と確認済み)。
;;   - consult-line は候補を現在行起点に回転させるためバッファの行順にならない
;;   - vertico は入力のたびに選択が先頭候補へ戻るため、swiper の
;;     「入力中も現在位置付近のマッチに留まる」「C-s C-s で前回検索」を再現できない
(leaf swiper
  :ensure t
  :bind (("C-s" . swiper))
  :custom
  (ivy-count-format . "%d/%d ")
  (ivy-height . 15)
  (ivy-wrap . t))

;; =============================================================================
;; 2. Vertico & Related Packages
;; =============================================================================

(leaf vertico
  :ensure t
  :hook ((after-init-hook . vertico-mode)
         (rfn-eshadow-update-overlay-hook . vertico-directory-tidy))
  :custom
  (vertico-count . 20)
  (vertico-cycle . t)
  :config
  (require 'vertico-directory)
  :bind
  (:vertico-map
   ("C-s" . vertico-next)               ; isearch 風に C-s 連打で次候補へ
   ("C-r" . my/local-buffer-or-recentf)
   ("C-t" . my/vertico-select-directory-from-candidates)
   ;; 入力位置以下を一括候補にした補完へ切り替える (navigation-util.el)。
   ;; consult-dir に依存しないので vertico 側に置く。
   ("M-j" . my/vertico-find-file-recursive)
   ("RET" . vertico-directory-enter)
   ("C-j" . vertico-exit-input)
   ("DEL" . vertico-directory-delete-char)
   ("<backspace>" . vertico-directory-delete-char)
   ("M-DEL" . vertico-directory-delete-word)
   ("M-<backspace>" . vertico-directory-delete-word)
   ("M-h" . vertico-directory-up)))

(leaf marginalia
  :ensure t
  :hook (after-init-hook . marginalia-mode))

(leaf consult
  :ensure t
  :init
  ;; Consult 本体の遅延ロード前でも、xref 読み込み時に表示設定を適用する。
  (with-eval-after-load 'xref
    (setq xref-show-xrefs-function #'consult-xref
          xref-show-definitions-function #'consult-xref))
  :custom
  ;; find-file 中の C-x C-j (consult-dir-jump-file) が使う fd の引数。
  ;;   --hidden      : .emacs.d 配下や dotfiles など先頭ドットのファイルも候補にする
  ;;   --exclude .git: .git 配下の大量のオブジェクトを候補から外す
  ;; .gitignore は fd の既定どおり尊重する。候補数を現実的に保つのが目的なので
  ;; --no-ignore は付けない (ignore されたファイルを開きたいときは通常の find-file)。
  (consult-fd-args . '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
                       "--full-path --color=never --hidden --exclude .git"))
  :bind (("M-." . xref-find-definitions)
         ("M-y" . consult-yank-pop)
         ("C-;" . consult-buffer)
         ;; 既定の bookmark-jump をプレビュー付きに置き換え
         ("C-x r b" . consult-bookmark)))

;; consult-dir: ディレクトリを起点に find-file を切り替える。
;; 現タブのプロセス用ディレクトリを最優先候補にする (tab-dir-util.el)。
;;
;; find-file の「一段ずつ降りる」挙動はそのまま。その下をまとめて探したくなったら
;; 入力位置から 2 通りの切り替え口がある (どちらも起点とファイル名部分を引き継ぐ)。
;;
;;   M-j     起点以下を一括で候補にした通常の補完 (my/vertico-find-file-recursive)。
;;           起動した時点で候補が全部見えていて、相対パス込みで絞り込める。
;;           2 万件を超える起点では、まず直下のディレクトリだけを候補に出して
;;           1 段降りてもらい、扱える件数になるまでそれを繰り返す。
;;   C-x C-j 入力を fd に渡してプロセス側で絞る検索 (consult-dir-jump-file)。
;;           候補を保持しないので起点がどれだけ大きくても軽い。代わりに
;;           consult-async-min-input (既定 3) 文字打つまで候補は出ない。
;;           起点の見当が付いていて名前も分かっているとき向け。
;;
;; 戻りたいときは C-g で抜けて find-file し直す。
(leaf consult-dir
  :ensure t
  :custom
  ;; 既定の consult-find (find コマンド) ではなく fd/find を状況で使い分ける。
  (consult-dir-jump-file-command . #'my/consult-jump-file-command)
  ;; :package vertico が要る。省略すると leaf は「consult-dir をロードしたら
  ;; vertico-map に入れる」と解釈するので、起動直後の find-file では
  ;; C-x C-j が無反応になる (C-x C-d を一度使うまで効かなかった)。
  :bind (("C-x C-d" . consult-dir)        ; 既定の list-directory を上書き
         (:vertico-map
          :package vertico
          ("C-x C-d" . consult-dir)
          ("C-x C-j" . consult-dir-jump-file))))

;; C-. は my/dabbrev-expand-or-completing-read (94_keybinds.el) に譲る
(leaf embark
  :ensure t
  :bind (("C-h B" . embark-bindings))
  :config
  (add-to-list 'display-buffer-alist
               '("\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 (display-buffer-in-side-window)
                 (side . right)
                 (window-width . 0.3))))

(leaf embark-consult
  :ensure t
  :after (embark consult)
  :hook (embark-collect-mode-hook . embark-consult-preview-minor-mode))

(with-eval-after-load 'embark
  (define-key embark-file-map (kbd "d") (lambda (f) (interactive "f") (find-file (file-name-directory f))))
  (define-key embark-buffer-map (kbd "d") (lambda (b) (interactive "b")
                                           (let ((f (buffer-file-name (get-buffer b))))
                                             (if f (find-file (file-name-directory f)) (message "No file")))))
  ;; a: アプリを選んで開く (md をブラウザや専用ビューアーで見る等)。
  ;; 既定アプリで開くだけなら embark 標準の x (embark-open-externally) がある。
  ;; 実体は my-defuns.el の my/embark-open-with-app。
  (define-key embark-file-map (kbd "a") #'my/embark-open-with-app))

(provide '02_completion)
