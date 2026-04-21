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
(bind-key* (kbd "C-x 5 5")
           #'(lambda () (interactive)
              (make-frame-command)
              (win:other-frame)
              (list-buffers)))
(bind-key* (kbd "C-x C-b")
           #'(lambda () (interactive)
              (list-buffers)
              (other-window 1)))
(bind-keys*
 ("<zenkaku-hankaku>" . toggle-input-method)
 ("C-0"     . delete-window)
 ("<f9>"    . delete-other-windows)
 ("C-^"     . enlarge-window)
 ("C-."     . dabbrev-expand)
 ("<f12>"   . shell)
 ("M-/"     . undo-tree-redo)
 ("C-x C-q" . view-mode)
 ("C-x k"   . kill-current-buffer)
 ("M-s o"   . occur-by-moccur)
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
       help-mode-map
       grep-mode-map)
       ("j" . next-line)
       ("J" . next-line)
       ("k" . previous-line))

 :map help-mode-map
 ("j" . next-line)
 ("k" . previous-line)
 :map grep-mode-map
 ("j" . next-line)
 ("k" . previous-line)
 )

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

  (mykie:global-set-key "M-w"
    :default winner-undo
    :region copy-region-as-kill)
  (bind-key* (kbd "M-s M-w") 'winner-redo)

  (mykie:global-set-key "C-@"
    :default crux-smart-open-line
    :C-u crux-smart-open-line-above)

  (mykie:global-set-key "C-k"
    :default kill-line
    :eolp    crux-kill-whole-line)

  (mykie:global-set-key "C-c 6"
    :default win-resume-menu
    :C-u win-resume-local)
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

;; (setq-default sp-highlight-wrap-overlay nil)
(setq-default sp-highlight-pair-overlay nil)


