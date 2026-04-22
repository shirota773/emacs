;;; lookup-utils.el --- Lookup various utilities
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: lookup-utils.el,v 1.1.1.1.4.12 2011-06-08 12:57:11 kazuhiro Exp $

;; This file is part of Lookup.

;; Lookup is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; Lookup is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with Lookup; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Code:

(require 'evi)

;; alist by assq

(defsubst lookup-assq-ref (alist key)
  "Return the value associated with KEY in ALIST.
This compares keys with `eq'.  See `assq'."
  (cdr (assq key alist)))

(defsubst lookup-assq-del (alist key)
  "Delete any entry in ALIST associated with KEY.
This compares keys with `eq'.  See `assq'."
  (delq (assq key alist) alist))

(defun lookup-assq-set (alist key value)
  "Associate KEY in ALIST with VALUE.
This compares keys with `eq'.  See `assq'."
  (if value
      (cons (cons key value) (lookup-assq-del alist key))
    (lookup-assq-del alist key)))

;; alist by assoc

(defsubst lookup-assoc-ref (alist key)
  "Return the value associated with KEY in ALIST.
This compares keys with `equal'.  See `assoc'."
  (cdr (assoc key alist)))

(defsubst lookup-assoc-del (alist key)
  "Delete any entry in ALIST associated with KEY.
This compares keys with `equal'.  See `assoc'."
  (delq (assoc key alist) alist))

(defun lookup-assoc-set (alist key value)
  "Associate KEY in ALIST with VALUE.
This compares keys with `equal'.  See `assoc'."
  (if value
      (cons (cons key value) (lookup-assoc-del alist key))
    (lookup-assoc-del alist key)))

;; alist set/ref

(defsubst lookup-alist-ref (symbol key)
  "Like `lookup-assq-ref', except SYMBOL should be a symbol.
SYMBOL's value must be an alist."
  (lookup-assq-ref (symbol-value symbol) key))

(defsubst lookup-alist-set (symbol key value)
  "Like `lookup-assq-set', except SYMBOL should be a symbol.
SYMBOL's value will be modified by this function."
  (set symbol (lookup-assq-set (symbol-value symbol) key value)))

;; multi put/get

(defsubst lookup-multi-put (symbol &rest args)
  "`put' に似ているが、任意の数の属性キーを取ることが出来る。
例えば (lookup-multi-put SYMBOL KEY1 KEY2 VALUE) という式は、
SYMBOL における KEY1 と KEY2 というキーに対する値として VALUE を設定する。
設定された値は `lookup-multi-get' により参照出来る。"
  (set symbol (lookup-multi-put-1 (symbol-value symbol) args)))

(defun lookup-multi-put-1 (alist args)
  ;; `lookup-multi-put' の内部関数。
  (if (cddr args)
      (lookup-assq-set alist (car args)
		       (lookup-multi-put-1 (lookup-assq-ref alist (car args))
					   (cdr args)))
    (lookup-assq-set alist (car args) (cadr args))))

(defsubst lookup-multi-get (symbol &rest args)
  "`get' に似ているが、任意の数の属性キーを取ることが出来る。
例えば (lookup-multi-put SYMBOL KEY1 KEY2) という式は、
SYMBOL における KEY1 と KEY2 というキーに対する値を参照する。
`lookup-multi-put' を参照。"
  (lookup-multi-get-1 (symbol-value symbol) args))

(defun lookup-multi-get-1 (alist args)
  ;; `lookup-multi-get' の内部関数。
  (if args
      (lookup-multi-get-1 (lookup-assq-ref alist (car args)) (cdr args))
    alist))

;; misc

(defun lookup-repq (list from to)
  "LIST の中で FROM に一致するオブジェクトを TO で置き換えたリストを生成する。
オブジェクトの比較は `eq' によって行なわれる。"
  (mapcar (lambda (elt)
	    (if (eq elt from) to elt))
	  list))

(defun lookup-nunique (list &optional predicate remove-nil)
  "LIST の中で重複するオブジェクトを取り除き一つにする。
オブジェクトの比較は PREDICATE によって行なわれる。省略された場合には
`equal' が用いられる。LIST は上書き変更される。
REMOVE-NIL が ron-nilの場合は LIST に含まれる nil を `delq' を使って取り除く。

 (lookup-nunique '(a a b c b c a))  => (a b c)"
  (when (consp list) ;; Remove case that list is nil.
    (setq predicate (or predicate 'equal))
    (cond
     ((eq predicate 'equal)
      (let (result)
	(mapc (lambda (elt)
		(if (null (member elt result))
		    (setq result (cons elt result)))) list)
	(when remove-nil (setq result (delq nil result)))
	(setq result (nreverse result))
	(setcar list (car result))
	(setcdr list (cdr result))
	result))
     ((eq predicate 'eq)
      (let (result)
	(mapc (lambda (elt)
		(if (null (memq elt result))
		    (setq result (cons elt result)))) list)
	(when remove-nil (setq result (delq nil result)))
	(setq result (nreverse result))
	(setcar list (car result))
	(setcdr list (cdr result))
	result))
     (t
      (let ((top list)
	    (list list)
	    first rest)
	(while list
	  (setq first (car list)
		rest list)
	  (while (cdr rest)
	    (if (funcall predicate first (cadr rest))
		(setcdr rest (cddr rest))
	      (setq rest (cdr rest))))
	  (setq list (cdr list)))
	(when remove-nil (setq top (delq nil top)))
	top)))))

(defalias 'lookup-foreach 'mapc)

(defun lookup-grep (predicate list)
  "LIST の全ての要素に対して (funcall PREDICATE ELEMENT) を実行し、
non-nil を返したものだけを新たにリストとして生成する。

 (lookup-grep 'symbolp '(1 a \"b\" c))  => (a c)"
  (let (result)
    (mapc (lambda (elt)
	    (when (funcall predicate elt)
	      (setq result (cons elt result))))
	  list)
    (nreverse result)))

(defun lookup-map-until (predicate list)
  "LIST の全ての要素に対して (funcall PREDICATE ELEMENT) を実行し、
最初に non-nil を返した要素を返す。"
  (let ((value nil))
    (while list
      (if (funcall predicate (car list))
	  (setq value (car list) list nil)
	(setq list (cdr list))))
    value))

(defun lookup-reverse-string (string)
  "STRING の前後の順を入れ替えた文字列を生成する。"
  (concat (nreverse (string-to-list string))))

(defun lookup-oneline-string (string)
  "STRING 内の改行をスペース一文字で置き換え、一行にする。"
  (while (string-match "\n *" string)
    (setq string (replace-match " " t t string)))
  string)

(defun lookup-read-string (prompt &optional init history default inherit)
  "`read-string' に似ているが、オプション DEFAULT が指定されば場合、
プロンプトにその値を (defaut DEFAULT) のように表示する。PROMPT には
自動的に \": \" が付加される。"
  (read-string (if default
		   (concat prompt " (default " default "): ")
		 (concat prompt ": "))
	       init history default inherit))

(defun lookup-map-over-property (from to prop func &optional object)
  "FROM から TO までのリージョンにある各 PROP に対して、FUNC を実行する。
FUNC は (funcall FUNC START END VALUE) のように呼び出される。START は
PROP の開始地点。END は終了地点。VALUE は property の値。
オプションの OBJECT が指定されて場合、current-buffer ではなく OBJECT の
中から PROP を探し出す。"
  (let ((beg from) end value)
    (while (setq value (get-text-property beg prop object)
		 end (text-property-not-all beg to prop value object))
      (if value (funcall func beg end value))
      (setq beg end))
    (if value (funcall func beg to value))))

(put 'lookup-with-coding-system 'lisp-indent-function 1)
(defmacro lookup-with-coding-system (coding &rest body)
  "入出力の文字コードを CODING に設定して BODY を実行する。"
  `(let (;; for GNU Emacs 20 and XEmacs 20
	   (coding-system-for-read ,coding)
	   (coding-system-for-write ,coding)
	   ;; for XEmacs
	   (file-name-coding-system ,coding))
       ,@body))

(put 'lookup-with-buffer-and-window 'lisp-indent-function 1)
(defmacro lookup-with-buffer-and-window (buffer &rest body)
  "current-buffer を BUFFER に設定し、更に selected-window を BUFFER の
window に設定した状態で BODY を実行する。"
  `(with-current-buffer ,buffer
       (save-selected-window
	 (if (get-buffer-window ,buffer)
	     (select-window (get-buffer-window ,buffer))
	   (error "No window for buffer `%s'" ,buffer))
	 ,@body)))

(defun lookup-parse-table (func start end)
  (let ((table nil) value)
    (goto-char start)
    (while (re-search-forward " *\\([^:\n]+\\): *\\(.*\\)" end t)
      (if (setq value (funcall func (match-string 1) (match-string 2)))
	  (setq table (cons value table))))
    (nreverse table)))

(defun lookup-table-insert (format args-list)
  (let ((width-alist nil)
	(n 0)
	(start 0))
    ;; convert the format string so that it can be passed to `format'
    ;; function. the width of %t field will be manyally calculated to
    ;; avoid undesirable behavior on XEmacs (see [lookup 2132]).
    (while (string-match "%\\(-?[0-9]*\\)." format start)
      (unless (eq (aref format (match-end 1)) ?%)
	(if (eq (aref format (match-end 1)) ?t)
	    (let ((width (string-to-number (match-string 1 format))))
	      (setq start (+ (match-beginning 0) 2)
		    format (replace-match "%s" t t format))
	      (lookup-alist-set 'width-alist n (cons width (abs width))))
	  (setq start (match-end 0)))
	(setq n (1+ n))))
    ;; get the max width.
    (lookup-foreach (lambda (args)
		      (lookup-foreach (lambda (pair)
					(let ((width (string-width
						      (nth (car pair) args))))
					  (if (< (cddr pair) width)
					      (setcdr (cdr pair) width))))
				      width-alist))
		    args-list)
    ;; adjust each argument in the list if necessary.
    ;; FIXME: this process directly modifies args-list -- possibly better
    ;; not to do so.
    (setq args-list
	  (mapcar (lambda (args)
		    (lookup-foreach (lambda (pair)
				      (let* ((arg (nth (car pair) args))
					     (width (string-width
						     (nth (car pair) args)))
					     (filler (make-string
						      (- (cddr pair) width)
						      ? )))
					(setcar (nthcdr (car pair) args)
						(if (< (cadr pair) 0)
						    (concat arg filler)
						  (concat filler arg)))))
				    width-alist)
		    args)
		  args-list))
    ;; insert the table.
    (while args-list
      (insert (apply 'format format (car args-list)))
      (setq args-list (cdr args-list)))))

(defsubst lookup-plist-get (plist prop)
  "More safe plist-get."
  (and (> (length plist) 1)
       (plist-get plist prop)))

(defun lookup-expand-file-name (name &optional dir)
  "Same as expand-file-name, but fix directory-sep-char to ?/."
  ;; This function will be obsoleted in future.
  ;; Because directory-sep-char was obsoleted since 21.1
  (let ((directory-sep-char ?/))
    (expand-file-name name dir)))

;;;
;:: Lookup current-word
;;;

(defun lookup-current-word (&optional strict)
  "バッファのカーソル位置かその周辺にある単語を文字列として返す。
オプションの引数 STRICT に non-nil が指定された場合、カーソルが単語と
重なっている場合のみを対象とする。
変数 `lookup-use-kakasi' が non-nil に指定された場合、日本語の単語も
それなりに判定して切り出す。"
  (save-excursion
    (unless (or strict (eq (char-syntax (or (char-after (point)) 0)) ?w))
      (let ((syntax "^w>"))
	(skip-syntax-backward syntax)
	(if (bolp) (skip-syntax-forward syntax) (backward-char))))
    (let* ((ch (or (char-after (point)) 0)))
      (cond ((eq (char-charset ch) 'ascii) (lookup-current-word-ascii))
	    ((aref (char-category-set ch) ?j) (lookup-current-word-japanese))
	    (t (lookup-current-word-general))))))

(defun lookup-current-word-general ()
  ;; `lookup-current-word' の内部関数。
  ;; syntax が "w" である文字の連なりを単語として切り出す。
  (if (fboundp 'thing-at-point)
      (thing-at-point 'word)
    (buffer-substring-no-properties
     (progn (skip-syntax-backward "w") (point))
     (progn (skip-syntax-forward "w") (point)))))

(defun lookup-current-word-ascii ()
  ;; `lookup-current-word' の内部関数。
  ;; アルファベットあるいは数字の連なりを単語として切り出す。
  ;; もし単語の末尾が `-' であり、更にそれが行末であるならば(つまり、
  ;; スペルが区切られているようなら)、次の行の最初のワードと連結する。
  (let ((word (buffer-substring-no-properties
	       (progn (skip-chars-backward "a-zA-Z0-9") (point))
	       (progn (skip-chars-forward "a-zA-Z0-9") (point)))))
    (if (not (looking-at "-\n"))
	word
      (forward-line)
      (concat word (buffer-substring-no-properties
		    (progn (skip-chars-forward "^a-zA-Z0-9\n") (point))
		    (progn (skip-chars-forward "a-zA-Z0-9") (point)))))))

(defun lookup-current-word-japanese ()
  ;; `lookup-current-word' の内部関数。
  ;; `lookup-use-kakasi' が non-nil に設定されている場合、KAKASI を用いて
  ;; 日本語の単語をそれなりに切り出す。そうでない場合は、
  ;; `lookup-current-word-general' を呼び出す。
  (if (null (and lookup-use-kakasi
		 (functionp (get 'lookup-kanji :wakati))))
      (lookup-current-word-general)
    (require 'lookup-kanji)
    (let ((function (get 'lookup-kanji :wakati))
	  (syntax "w")
	  (start (point)) (n 1) regexp string)
      (setq string (funcall function
			    (buffer-substring
			     (progn (skip-syntax-backward syntax) (point))
			     (progn (skip-syntax-forward syntax) (point)))))
      (with-temp-buffer
	(insert string)
	(goto-char (point-min))
	(while (search-forward " " nil t)
	  (replace-match "\\)\\(" nil t))
	(setq regexp (concat "\\(" (buffer-string) "\\)")))
      (if (re-search-backward regexp nil t)
	  (progn
	    (while (and (match-end n) (<= (match-end n) start))
	      (setq n (1+ n)))
	    (buffer-substring-no-properties
	     (match-beginning n) (match-end n)))
	(lookup-current-word-general)))))

;;;
;:: Lookup process
;;;

;; Description:
;; 
;; Lookup のいくつかの agent が用いているプロセス操作関数。
;; これを使うことは必須ではないが、コマンドを発行して出力を受け取る
;; ようなよくあるタイプの入出力を簡略化するのに便利。

;; Functions:
;;
;; lookup-process-require - プロセスに文字列を送信し、出力を待つ。
;; lookup-process-kill - プロセスを終了する。

(defvar lookup-process-output-separator-lines 2)

(defun lookup-process-require (process string separator &optional filter)
  "PROCESS に対して STRING を送り、その出力を待つ。
出力終了の合図は、PROCESS が特定の終了コードを返したかどうかを判定する
ことによって行なう。SEPARATOR には終了コードとマッチするような正規表現を
指定する。
オプション FILTER が設定された場合、出力終了と同時に FILTER を呼び出す。
FILTER は (funcall FILTER PROCESS) のように呼び出される。そのときの
current-buffer はプロセスの出力が書き込まれたバッファであり、出力部分に
対して narrowing されいる。SEPARATOR 自体は narrow 部分に含まれない。
FILTER の返却値が関数の値として返される。FILTER が省略された場合には、
プロセスの出力をそのまま文字列として返す。"
  (let (temp-buffer)
    (unless (process-buffer process)
      (setq temp-buffer (lookup-temp-buffer))
      (set-process-buffer process temp-buffer))
    (prog1
	(save-excursion
	  (set-buffer (process-buffer process))
	  (save-restriction
	    (save-match-data
	      (widen)
	      (goto-char (point-max))
	      ;; 送信文字列をバッファに保持してから、プロセスに送信する。
	      ;; これはデバッグ等のときに役立つ。
	      (insert string)
	      (narrow-to-region (point-max) (point-max))
	      (process-send-string process string)
	      (catch 'finished
		(while (accept-process-output process 20)
		  (goto-char (point-max))
		  (forward-line (- lookup-process-output-separator-lines))
		  (when (re-search-forward separator nil t)
		    (throw 'finished t)))
		(error "Failed to receive output"))
	      (if filter
		  (save-current-buffer
		    (narrow-to-region (point-min) (match-beginning 0))
		    (goto-char (point-min))
		    (funcall filter process))
		(buffer-substring (point-min) (match-beginning 0))))))
      ;; 一時バッファを用いた場合、kill-buffer する。
      (when temp-buffer
	(set-process-buffer process nil)
	(kill-buffer temp-buffer)))))

(defun lookup-process-send (process string)
  "PROCESS に対して STRING を送る。実行終了は待たない。返り値は不定。"
  (when (process-buffer process)
    (save-excursion
      (set-buffer (process-buffer process))
      (save-restriction
	(widen)
	(goto-char (point-max))
	;; 送信文字列をバッファに保持してから、プロセスに送信する。
	;; これはデバッグ等のときに役立つ。
	(insert string))))
  (process-send-string process string))

(defun lookup-process-kill (process)
  "PROCESS を終了する。
プロセスにバッファが設定されている場合、それも kill-buffer する。"
  (set-process-filter process nil)
  (condition-case err
      ;; XEmacs on Windows always raises an unexpected error...
      (delete-process process)
    (error (message "Warning: delete-process: %S" err)))
  (if (process-buffer process)
      (kill-buffer (process-buffer process))))

(defun lookup-split-string (string &optional separators)
  (let ((rexp (or separators "[ \f\t\n\r\v]+"))
	(start 0) (list nil))
    (while (string-match rexp string start)
      (or (eq (match-beginning 0) 0)
	  (setq list (cons (substring string start (match-beginning 0))
			   list)))
      (setq start (match-end 0)))
    (or (eq start (length string))
	(setq list (cons (substring string start) list)))
    (nreverse list)))

(provide 'lookup-utils)

;;; lookup-utils.el ends here
