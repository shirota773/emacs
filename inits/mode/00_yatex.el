;; yatex
(define-obsolete-variable-alias 'last-command-char 'last-command-event "at least 19.34")
(autoload 'yatex-mode "yatex" "Yet Another LaTeX mode" t nil)
(setq auto-mode-alist
   (cons (cons "\\.tex$" 'yatex-mode) auto-mode-alist))
(setq YaTeX-kanji-code 4)          ; 1:shift_jis 3:euc 4:utf-8
(setq YaTeX-auto-math-mode nil)    ; 動作が少し速くなるかも。
(setq YaTeX-no-begend-shortcut t)  ; すぐに環境補完に入る。
(setq section-name "documentclass"); section コマンドのデフォルト
(setq YaTeX-template-file "~/tex/template.tex")
(setq YaTeX-hilit-sectioning-face '(slateblue/gainsboro))
(setq dviprint-command-format "dvipdfmx %s")
(setq dvi2-command "xdvi")
(setq tex-command "latexmk.pl")
(define-key YaTeX-mode-map (kbd "C-c d") '(lambda () (interactive "")(shell-command "latexmk -c")))

(add-hook 'yatex-mode-hook 'turn-on-reftex)
