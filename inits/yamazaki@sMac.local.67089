(require 'smie)

;; 予約語の設定
(defvar mylang-mode-keywords
  '("if" "then" "else" "fi" "begin" "end"))

;; font-lockの設定
(defvar mylang-font-lock-keywords
  (list
   `(,(concat "\\_<" (regexp-opt mylang-mode-keywords) "\\_>") . font-lock-keyword-face)
   '("//.*" . font-lock-comment-face)
   '("\"[^\"]*\"" . font-lock-string-face)))

;; SMIEの設定
(defconst mylang-smie-grammar
  (smie-prec2->grammar
   (smie-bnf->prec2
    '((id)
      (exp (exp "+" exp)
           (exp "-" exp))
      (insts (insts ";" insts)
             (exp))
      (prog (insts)))
    '((assoc ";") (assoc "+" "-")))))

(defun mylang-smie-rules (kind token)
  (pcase (cons kind token)
    (`(:elem . basic) mylang-indent-offset)
    (`(:before . ,(or `"(" `"{" `"["))
     (if (smie-rule-hanging-p) (smie-rule-parent 0)))))

;; メジャーモードの定義
(define-derived-mode mylang-mode prog-mode "mylang"
  "Major mode for editing mylang code."
  :syntax-table mylang-mode-syntax-table
  (setq font-lock-defaults '(mylang-font-lock-keywords))
  (set (make-local-variable 'comment-start) "//")
  (set (make-local-variable 'comment-end) "")
  (smie-setup mylang-smie-grammar #'mylang-smie-rules))

(add-to-list 'auto-mode-alist '("\\.mylang\\'" . mylang-mode))

(defvar mylang-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; "は文字列引用記号です
    (modify-syntax-entry ?\" "\"" table)

    ;; 'は文字列引用記号です
    (modify-syntax-entry ?\' "\"" table)

    ;; ;はコメント開始記号です
    (modify-syntax-entry ?\; "<" table)

    ;; 改行はコメント終了記号です
    (modify-syntax-entry ?\n ">" table)

    ;; \はエスケープ文字です
    (modify-syntax-entry ?\\ "\\" table)

    ;; (){}[]はそれぞれ対応する括弧です
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?a "(b" table)
    (modify-syntax-entry ?b ")a" table)

    table)
  "Syntax table for `mylang-mode'.")

(define-derived-mode mylang-mode prog-mode "mylang"
  "Major mode for editing mylang code."
  :syntax-table mylang-mode-syntax-table
  ;; 他の設定...
  )

(smie-prec2->grammar
  (smie-bnf->prec2
   '((id)
     (inst ("begin" insts "end")
           ("if" exp "then" inst "else" inst)
           (id ":=" exp)
           (exp))
     (insts (insts ";" insts) (inst))
     (exp (exp "+" exp)
          (exp "*" exp)
          ("(" exps ")"))
     (exps (exps "," exps) (exp)))
   '((assoc ";"))
   '((assoc ","))
   '((assoc "+") (assoc "*"))))
