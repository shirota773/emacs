;;; lookup-kanji-kakasi.el --- KAKASI interface for lookup-kanji.el
;; Copyright (C) 2010 Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; Author: Kazuhiro Ito <kzhr@d1.dion.ne.jp>
;; Version: $Id: lookup-kanji-kakasi.el,v 1.1.2.2 2010-04-07 10:23:19 kazuhiro Exp $

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

;; Customizable variables
(defgroup lookup-kanji-kakasi nil
  "KAKASI interface for lookup-kanji features."
  :group 'lookup-kanji)

(defcustom lookup-kanji-kakasi-program-name "kakasi"
  "*Program name of KAKASI"
  :type 'string
  :group 'lookup-kanji-kakasi)

(defcustom lookup-kanji-kakasi-coding-system lookup-process-coding-system
  "Coding system for KAKASI process"
  :type 'symbol
  :group 'lookup-kanji-kakasi)

(defcustom lookup-kanji-kakasi-program-args
  nil
  "Optional arguments for KAKASI program"
  :type '(choice (repeat (string :tag "option")) (const nil))
  :group 'lookup-kanji-kakasi)

(defcustom lookup-kanji-kakasi-program-args-for-wakati
  '("-w")
  "Optional arguments for KAKASI program for wakatigaki"
  :type '(choice (repeat (string :tag "option")) (const nil))
  :group 'lookup-kanji-kakasi)

(defcustom lookup-kanji-kakasi-program-args-for-hiragana
  '("-JH" "-p" "-u")
  "Optional arguments for KAKASI program for getting hiragana readings."
  :type '(choice (repeat (string :tag "option")) (const nil))
  :group 'lookup-kanji-kakasi)

(defcustom lookup-kanji-kakasi-content-format
  '(t "\n" ("-JH" "-u") "\n" "【振り仮名】" ("-JH" "-f" "-p" "-u") "\n")
  "ndkks 辞書が出力するエントリ内容のフォーマット。
リストの各要素として、文字列、文字列のリスト、及び `t' を指定できる。
文字列の場合、それがそのまま挿入される。
リストの場合、それを引数として KAKASI が呼び出され、その結果が挿入される。
`t' の場合、検索語が挿入される。"
  :type '(repeat (radio :tag "出力内容"
			(const :tag "検索語" t)
			(string :tag "文字列")
			(repeat :tag "KAKASI 呼び出し"
				(string :tag "option"))))
  :group 'lookup-kanji-kakasi)

;; Define interface
(put 'lookup-kanji-kakasi :wakati 'lookup-kanji-kakasi-wakati)
(put 'lookup-kanji-kakasi :hiragana 'lookup-kanji-kakasi-hiragana)
(put 'lookup-kanji-kakasi :content 'lookup-kanji-kakasi-content)

;; Interface functions
(defun lookup-kanji-kakasi-wakati (string)
  (lookup-kanji-kakasi-require
   string lookup-kanji-kakasi-program-args-for-wakati))

(defun lookup-kanji-kakasi-hiragana (string)
  (lookup-kanji-kakasi-hiragana-internal
   (lookup-kanji-kakasi-require
    string lookup-kanji-kakasi-program-args-for-hiragana)))

(defun lookup-kanji-kakasi-hiragana-internal (string)
  (let* ((result (list string))
	 (tmp result)
	 tmp2)
    (while tmp
      (while (string-match "{\\([^}]+\\)}" (car tmp))
	(let ((head (substring (car tmp) 0 (match-beginning 0)))
	      (tail (substring (car tmp) (match-end 0))))
	  (setq tmp2 (mapcar
		      (lambda (s) (concat head s tail))
		      (lookup-split-string
		       (substring (car tmp) (match-beginning 1) (match-end 1))
		       "|")))
	  (setcar tmp (car tmp2))
	  (setcdr tmp (nconc (cdr tmp2) (cdr tmp)))))
      (setq tmp (cdr tmp)))
    result))

(defun lookup-kanji-kakasi-content (string)
  (mapconcat (lambda (element)
	       (cond ((eq element t) string)
		     ((stringp element) element)
		     ((listp element)
		      (lookup-kanji-kakasi-require string element))
		     (t (error "Invalid format element: %S" element))))
	     lookup-kanji-kakasi-content-format ""))

;; Internal functions
(defun lookup-kanji-kakasi-require (string args &optional filter)
  (let* ((args (delq nil (append lookup-kanji-kakasi-program-args args)))
	 (process (lookup-kanji-kakasi-process args)))
    (lookup-process-require process (concat string "\n") "\n" filter)))

(defun lookup-kanji-kakasi-process (args)
  (lookup-kanji-process
   lookup-kanji-kakasi-program-name args lookup-kanji-kakasi-coding-system))

(provide 'lookup-kanji-kakasi)
