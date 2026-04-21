(leaf flycheck
  :ensure t
  :init (global-flycheck-mode 0)
  ;; :mode (
  ;; ("\\.org$" . org-mode))
  :hook  ((python-mode-hook . flycheck-mode))
  :config
  (setq flycheck-display-errors-delay 1.0)
  )


;; Reference by https://emacs-lsp.github.io/lsp-mode/page/installation/
(leaf *lsp
  :disabled nil

  ;; https://alpha2phi.medium.com/emacs-lsp-and-dap-7c1786282324
  (leaf lsp-mode
    :init
    (setq lsp-keymap-prefix "C-c l")
    :hook ((python-mode . lsp-deferred))
    :commands (lsp lsp-deferred)
    )

  (leaf lsp-ui
    :hook (lsp-mode . lsp-ui-mode)
    :custom
    (lsp-ui-doc-position 'bottom))

  (leaf lsp-ivy
    :commands lsp-ivy-workspace-symbol)

  ;; (leaf lsp-treemacs
  ;;   :commands lsp-treemacs-errors-list)
  )


(leaf company  :ensure t

  ;; :mode (("\\.html\\'" "\\.el\\'" "\\.css\\'" "\\.py\\'" "\\.js\\'") . company-mode)
  :custom
  (company-idle-delay . 0.1)
  (company-minimum-prefix-length . 2)
  (company-selection-wrap-around . t)
  (company-show-numbers . t)

  :config
  (global-company-mode t)
  ;; (define-key company-active-map [tab] 'company-complete-selection)

  (set-face-attribute 'company-tooltip-selection nil
                      :foreground "#a1ffcd" :background "#007771")
  ;; 選択項目&一致文字
  (set-face-attribute 'company-tooltip-common-selection nil
                      :foreground "white" :background "#007771")
  ;; (push 'company-lsp company-backends))
  (defun my/company-insert-common ()
    "Insert the common part of all candidates."
    (interactive)
    (when (company-manual-begin)
      (company--insert-common)))

  :commands company-lsp
  :bind
  (:company-active-map
   ("<return>" . nil)
   ("RET" . nil)
   ;; ([tab] . company-complete-selection)
   ("<tab>" . nil)
   ("TAB" . nil)
   ("M-n" . company-select-next)
   ("M-p" . company-select-previous)
   ("<up>" . nil)
   ("<down>" . nil)
   ("C-j" . my/company-insert-common))

  )


;; (define-key company-active-map (kbd "C-j") #'my/company-insert-common)

;; DAP
(leaf dap-mode
  :ensure t
  :commands dap-debug
  :config
  (require 'dap-node)
  (dap-node-setup)
  (require 'dap-go)
  (dap-go-setup)
  (require 'dap-hydra)
  (require 'dap-gdb-lldb)
  (dap-gdb-lldb-setup)
  (when (fboundp 'general-define-key)
    (general-define-key
     :keymaps 'lsp-mode-map
     :prefix lsp-keymap-prefix
     "d" '(dap-hydra t :wk "debugger"))))

;; ein
(leaf ein
  :ensure t
  :config
  (eval-when-compile
    (require 'ein)
    (require 'ein-notebook)
    (require 'ein-notebooklist)
    (require 'ein-markdown-mode)
    ;; (require 'smartrep)
    )


;; (add-hook 'ein:notebook-mode-hook 'electric-pair-mode) ;; お好みで
;; (add-hook 'ein:notebook-mode-hook 'undo-tree-mode) ;; お好みで

;; undoを有効化 (customizeから設定しておいたほうが良さげ)
(setq ein:worksheet-enable-undo t)

;; 画像をインライン表示 (customizeから設定しておいたほうが良さげ)
(setq ein:output-area-inlined-images t)

;; markdownパーサー
;; M-x ein:markdown →HTMLに翻訳した結果を*markdown-output*バッファに出力
(require 'ein-markdown-mode)

;; pandocと markdownコマンドは入れておく
;; brew install pandoc
;; brew install markdown
(setq ein:markdown-command "pandoc --metadata pagetitle=\"markdown preview\" -f markdown -c ~/.pandoc/github-markdown.css -s --self-contained --mathjax=https://raw.githubusercontent.com/ustasb/dotfiles/b54b8f502eb94d6146c2a02bfc62ebda72b91035/pandoc/mathjax.js")

;; markdownをhtmlに出力してブラウザでプレビュー
(defun ein:markdown-preview ()
  (interactive)
  (ein:markdown-standalone)
  (browse-url-of-buffer ein:markdown-output-buffer-name))

;; smartrepを入れておく。
;; C-c C-n C-n C-n ... で下のセルに連続で移動、
;; その途中でC-p C-p C-pで上のセルに連続で移動など
;; セル間の移動がスムーズになってとても便利
;; (declare-function smartrep-define-key "smartrep")
;; (with-eval-after-load "ein-notebook"
;;   (smartrep-define-key ein:notebook-mode-map "C-c"
;;     '(("C-n" . 'ein:worksheet-goto-next-input-km)
;;       ("C-p" . 'ein:worksheet-goto-prev-input-km))))
)
