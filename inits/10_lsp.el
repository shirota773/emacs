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
    (setq lsp-keymap-prefi x "C-c l")
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


(global-company-mode t)

;; DAP
(use-package dap-mode
  ;; Uncomment the config below if you want all UI panes to be hidden by default!
  ;; :custom
  ;; (lsp-enable-dap-auto-configure nil)
  ;; :config
  ;; (dap-ui-mode 1)
  :commands dap-debug
  :config
  ;; Set up Node debugging
  (require 'dap-node)
  (dap-node-setup) ;; Automatically installs Node debug adapter if needed
  (require 'dap-go)
  (dap-go-setup)
  (require 'dap-hydra)
  (require 'dap-gdb-lldb)
  (dap-gdb-lldb-setup)

  ;; Bind `C-c l d` to `dap-hydra` for easy access
  (general-define-key
   :keymaps 'lsp-mode-map
   :prefix lsp-keymap-prefix
   "d" '(dap-hydra t :wk "debugger")))

;; '(lsp-auto-guess-root t)
;;  '(lsp-completion-enable nil)
;;  '(lsp-document-sync-method 'incremental)
;;  '(lsp-log-io nil)
;;  '(lsp-prefer-flymake 'flymake)
;;  '(lsp-print-performance nil)
;;  '(lsp-response-timeout 5)
;;  '(lsp-trace nil t)
;;  '(lsp-ui-doc-enable t)
;;  '(lsp-ui-doc-header t)
;;  '(lsp-ui-doc-include-signature t)
;;  '(lsp-ui-doc-max-height 30)
;;  '(lsp-ui-doc-max-width 150)
;;  '(lsp-ui-doc-position 'top)
;;  '(lsp-ui-doc-use-childframe t)
;;  '(lsp-ui-doc-use-webkit t)
;;  '(lsp-ui-flycheck-enable nil t)
;;  '(lsp-ui-imenu-enable nil)
;;  '(lsp-ui-imenu-kind-position 'top)
;;  '(lsp-ui-peek-enable t)
;;  '(lsp-ui-peek-fontify 'on-demand)
;;  '(lsp-ui-peek-list-width 50)
;;  '(lsp-ui-peek-peek-height 20)
;;  '(lsp-ui-sideline-enable nil)
;;  '(lsp-ui-sideline-ignore-duplicate t)
;;  '(lsp-ui-sideline-show-code-actions nil)
;;  '(lsp-ui-sideline-show-diagnostics nil)
;;  '(lsp-ui-sideline-show-hover t)
;;  '(lsp-ui-sideline-show-symbol t)

;; (use-package dap-LANGUAGE) to load the dap adapter for your language



;; (leaf lsp-python
;;   :after (lsp-mode python-mode)
;;   ;; :custom (lsp-python-language-server-flags '(
;;     ;; "-gocodecompletion"
;;     ;; "-diagnostics"
;;     ;; "-lint-tool=golint"))
;;   :hook (python-mode . lsp-python-enable)
;;   :commands lsp-python-enable)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; lsp
;; (leaf lsp-mode
;;   :custom
;;   ; debug
;;   (lsp-print-io . nil)
;;   (lsp-trace . nil)
;;   (lsp-print-performance . nil)
;;   ; general
;;   (lsp-auto-guess-root . t)
;;   (lsp-document-sync-method . 'incremental) ;; always send incremental document
;;   (lsp-response-timeout . 5)
;;   (lsp-prefer-flymake . 'flymake)
;;   (lsp-enable-completion-at-point . nil)

;;   :hook ((python-mode . lsp))
;;   :bind ((python-mode-map
;;   ("C-c r" . lsp-rename)))
;;   )

;; (leaf lsp-ui
;;   :custom
;;   ;; lsp-ui-doc
;;   (lsp-ui-doc-enable . t)
;;   (lsp-ui-doc-header . t)
;;   (lsp-ui-doc-include-signature . t)
;;   (lsp-ui-doc-position . 'top) ;; top, bottom, or at-point
;;   (lsp-ui-doc-max-width . 150)
;;   (lsp-ui-doc-max-height . 30)
;;   (lsp-ui-doc-use-childframe . t)
;;   (lsp-ui-doc-use-webkit . t)
;;   ;; lsp-ui-flycheck
;;   (lsp-ui-flycheck-enable . nil)
;;   ;; lsp-ui-sideline
;;   (lsp-ui-sideline-enable . nil)
;;   (lsp-ui-sideline-ignore-duplicate . t)
;;   (lsp-ui-sideline-show-symbol . t)
;;   (lsp-ui-sideline-show-hover . t)
;;   (lsp-ui-sideline-show-diagnostics . nil)
;;   (lsp-ui-sideline-show-code-actions . nil)
;;   ;; lsp-ui-imenu
;;   (lsp-ui-imenu-enable . nil)
;;   (lsp-ui-imenu-kind-position . 'top)
;;   ;; lsp-ui-peek
;;   (lsp-ui-peek-enable . t)
;;   (lsp-ui-peek-peek-height . 20)
;;   (lsp-ui-peek-list-width . 50)
;;   (lsp-ui-peek-fontify .'on-demand) ;; never, on-demand, or always
;;   :preface
;;   (defun ladicle/toggle-lsp-ui-doc ()
;; (interactive)
;; (if lsp-ui-doc-mode
;;         (progn
;;           (lsp-ui-doc-mode -1)
;;           (lsp-ui-doc--hide-frame))
;;   (lsp-ui-doc-mode 1)))
;;   :bind ((lsp-mode-map
;;   ("C-c C-r" . lsp-ui-peek-find-references)
;;   ("C-c C-j" . lsp-ui-peek-find-definitions)
;;   ("C-c i"   . lsp-ui-peek-find-implementation)
;;   ("C-c m"   . lsp-ui-imenu)
;;   ("C-c s"   . lsp-ui-sideline-mode)
;;   ("C-c d"   . ladicle/toggle-lsp-ui-doc)))
;;   :hook
;;   (lsp-mode . lsp-ui-mode))

;; ;; Lsp completion
;; (use-package company-lsp
;;   :custom
;;   (company-lsp-cache-candidates t) ;; always using cache
;;   (company-lsp-async t)
;;   (company-lsp-enable-recompletion nil))


;; (leaf company
;;   :hook (((emacs-lisp-mode-hook python-mode) . company-mode))
;;   :config
;;   )

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
