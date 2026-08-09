;;; 94_keybinds.el --- グローバルキーバインド -*- lexical-binding: t; -*-

;; ★ キー割り当ての前提 (身体的制約。好みではない)
;;
;;   Emacs pinky で左小指を痛めた経緯がある。現在はカスタムキーボードで
;;   - Space を oneshot 化し、Space に Control modifier と Space 入力を兼ねさせている
;;     → Ctrl 修飾は親指で押す。C- 和音を避ける必要は無い
;;   - mod + h/j/k/l に vim 形式の矢印を割り当てている
;;     → カーソル移動は右手ホームポジションから出る。1 文字移動コマンドが要らない
;;
;;   このため C-f / C-b / C-h は**意図的に**潰し、空いた一等地を主要機能に充てている。
;;   ミスではないので標準に戻さないこと。
;;     C-f = hydra-buffer-primary (04_bufferlo.el) / C-b = hydra-puni (05_editing.el)
;;     C-h = delete-backward-char (下記。帰結は 02_packages.el:147 を参照)
;;
;;   作業姿勢は右手マウス・左手キーボード。**マウス経路が無い操作**のキーは
;;   左手側に寄せる。マウスで 1 クリックで済む操作のキーは右手側でもよい
;;   (両手がキーボードにあるときの副経路にすぎない)。判断軸は使用頻度ではなく
;;   その操作にマウス経路があるか。
;;
;;   詳細: ~/obsidian/my-vault/30_Knowledge/2026-08-09-入力環境と身体的制約.md
;;   変遷: review-notes.md §5

;; (require 'bind-key)
(leaf bind-key
  :ensure t)
(when (fboundp 'mac-input-source)
  (bind-key (kbd "<f13>")
            #'(lambda ()(interactive) (deactivate-input-method)))
  (bind-key (kbd "<f14>")
            #'(lambda ()(interactive) (activate-input-method 'japanese))))
;; 複数のキーをまとめて登録
;; (bind-keys :map dired-mode-map ("o" . dired-omit-mode)("a" . some-custom-dired-function))
;; モードに依存しないキーの割当 bind-key → bind-key*
;; (keyboard-translate ?\C-h ?\C-?)
;; (bind-key (kbd "M-n") '(lambda () (interactive "")(forward-line 1)(scroll-up 1) ))
;; (bind-key (kbd "M-p") '(lambda () (interactive "")(previous-line 1)(scroll-up -1 )))
;; (bind-key (kbd "M-g")  'goto-line)
(bind-key* (kbd "C-3")
           #'(lambda () (interactive)
              (delete-other-windows)
              (split-window-right)
              (other-window 1)
              (switch-to-prev-buffer)
              (other-window 1)))
(bind-keys*
 ("<zenkaku-hankaku>" . toggle-input-method)
 ("C-0"     . delete-window)
 ("<f9>"    . delete-other-windows)
 ("C-^"     . enlarge-window)
 ("C-."     . my/dabbrev-expand-or-completing-read)
 ("<f12>"   . shell)
 ("C-x C-q" . view-mode)
 ("C-x k"   . kill-current-buffer)
 ;; カレントのファイル (dired ならポイント下) を OS 既定のアプリで開く。
 ;; アプリを選んで開くのは M-x my/open-externally-with-app、embark の候補に
 ;; 対しては M-o a。実体は my-defuns.el。
 ("C-c o"   . my/open-externally-dwim)
 ;; 同じ対象を OS のファイラ (Finder / エクスプローラー) で選択状態にして表示する。
 ;; 「開く」の C-c o に対して「置き場所を見せる」側。
 ("C-c O"   . my/reveal-in-file-manager)
 ("C-c c"   . org-capture)
 ("C-c a"   . org-agenda)
 ("C-o"     . other-window)
 ("C-h"     . delete-backward-char)
 ("M-f"     . right-word)
 ("M-b"     . left-word)
 ("C-x C-b" . ibuffer)
 ;; (bind-key* "C-@" 'crux-smart-open-line)
 ;; (bind-key* "C-S-@" 'crux-smart-open-line-above)

 ;; ("M-o" . iflipb-next-buffer)
 ; ; ("M-O" . iflipb-previous-buffer)

 ;; ("M-g" . goto-line)

 :map ((Buffer-menu-mode-map
       help-mode-map)
       ("j" . next-line)
       ("J" . next-line)
       ("k" . previous-line))
 )

(with-eval-after-load 'grep
  (bind-keys :map grep-mode-map
             ("j" . next-line)
             ("k" . previous-line)))

;; C-t: local/TRAMPを判定して接続単位のterminalを開く (my/term-here)。
;; macOSはmistty (TUI対応)、native Windowsはshellに自動分岐。
;; Windows localのshellはGit Bashをフルパス指定で固定 (inits/win.el参照)。
;; パス無しの"bash"はPATH順でSystem32\bash.exe=WSLを引くための対策。
;; WSLを使いたいときは C-c T w (my/terminal-wsl) で明示的に起動する。
;; eatはRosetta実行のEmacsでTUI出力によりフリーズするため不採用 (31参照)。
;; minibufferではvertico-mapのC-t (ディレクトリジャンプ) を優先させるため、
;; override (bind-keys*) ではなく通常のglobal-mapに置く。
(bind-key "C-t" #'my/term-here)

(when darwin-p
   (bind-key (kbd "C-M-o") 'other-window))
;;マクロ
                                        ;M-x name-last-kbd-macro で直前のマクロに名前をつける
                                        ;M-x insert-kbd-macro で保存したマクロの定義を挿入する
;; (fset 'insert_space
;;    "    ")
(leaf mykie
  :ensure t
  :defun (mykie:global-set-key)
  :custom
  (mykie:use-major-mode-key-override . t)

  :config
  (mykie:initialize)

  ;; ウィンドウ構成の undo/redo はタブごと (tab-bar-history-mode)。
  ;; 旧 winner-undo/redo はフレーム単位でタブをまたいで復元してしまうため
  ;; 2026-07-30 に置き換えた (winner-mode は 01_setup.el から撤去済み)。
  (mykie:global-set-key "M-w"
    :default tab-bar-history-back
    :region copy-region-as-kill)
  (bind-key* (kbd "M-s M-w") 'tab-bar-history-forward)

  (mykie:global-set-key "C-@"
    :default crux-smart-open-line
    :C-u crux-smart-open-line-above)

  (mykie:global-set-key "C-k"
    :default kill-line
    :eolp    crux-kill-whole-line)

  (mykie:global-set-key "C-w"
    :default move-to-mark
    :region kill-region)

  (mykie:global-set-key "C-a"
    :default crux-move-beginning-of-line
    ;; :bolp    beginning-of-buffer
    )
  (mykie:global-set-key "C-e"
    :default move-end-of-line
    :repeat    end-of-buffer
    )

  (mykie:global-set-key "M-f"
    :default forward-to-word
    :region forward-word)
  )

(provide '94_keybinds)


