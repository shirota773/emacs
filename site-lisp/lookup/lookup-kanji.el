;;; lookup-kanji.el --- Lookup Kanji-Kana Converter
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: TSUCHIYA Masatoshi <tsuchiya@pine.kuee.kyoto-u.ac.jp>
;; Version: $Id: lookup-kanji.el,v 1.1.1.1.4.4 2011-06-08 12:57:11 kazuhiro Exp $

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
(require 'lookup-utils)
(require 'lookup-vars)

;; Custamizable variables.
(defgroup lookup-kanji nil
  "Kanji-Kana converter interface for lookup."
  :group 'lookup-general-options)

(defcustom lookup-kanji-scheme nil
  "*Scheme of kanji processor implementation."
  :type '(choice (const :tag "none" nil)
		 (const :tag "KAKASI" kakasi)
		 (const :tag "Chasen" chasen)
		 (const :tag "MECAB" mecab))
  :group 'lookup-kanji)

;; Internal variables.
(defvar lookup-kanji-process-alist nil
  "漢字ひらがな変換プログラムのプロセス(内部変数)")

;; Functions.
(defun lookup-kanji-process (name args coding)
  "Return process started by name and args.  New process is started when required."
  (let* ((key (cons name args))
	 (elt (assoc key lookup-kanji-process-alist)))
    (unless (and elt (eq (process-status (cdr elt)) 'run))
      (when elt
	(setq lookup-kanji-process-alist
	      (delq elt lookup-kanji-process-alist)))
      (add-to-list 'lookup-kanji-process-alist
		   (cons key (lookup-kanji-start-process name args coding)))
      (setq elt (assoc key lookup-kanji-process-alist)))
    (cdr elt)))

(defun lookup-kanji-start-process (name args coding)
  (let ((buffer (generate-new-buffer " *lookup-kanji*"))
	process)
    (add-to-list 'lookup-buffer-list buffer)
    (buffer-disable-undo buffer)
    (setq process (apply 'start-process "lookup-kanji"  buffer name args))
    (process-kill-without-query process)
    (when coding
      (set-process-coding-system process coding coding))
    (unless (eq (process-status process) 'run)
      (sleep-for 0.1))
    process))

;; Expander and filter functions
(defun lookup-kanji-get-readings (str)
  "STR を漢字ひらがな変換して得られた結果のリストを返す関数"
  (let ((function (get 'lookup-kanji :hiragana)))
    (when (functionp function)
      (funcall function str))))

(defun lookup-kanji-filter (str entries)
  "STR が見出しに含まれているようなエントリのみを取り出すフィルタ関数"
  (let ((regex (mapconcat 'char-to-string str ".?.?.?")))
    (delq nil (mapcar
	       (lambda (entry)
		 (if (string-match regex (lookup-entry-heading entry)) entry))
	       entries))))

;; Initialization

(defun lookup-kanji-initialize ()
  (when (and (boundp 'lookup-kanji-scheme)
	     lookup-kanji-scheme
	     (null (get 'lookup-kanji :wakati)))
    (let ((scheme (intern (concat "lookup-kanji-"
				  (symbol-name lookup-kanji-scheme)))))
      (require scheme)
      (put 'lookup-kanji :wakati (get scheme :wakati))
      (put 'lookup-kanji :hiragana (get scheme :hiragana))
      (put 'lookup-kanji :content (get scheme :content)))))

(lookup-kanji-initialize)

(provide 'lookup-kanji)
;;; lookup-kanji.el ends here
