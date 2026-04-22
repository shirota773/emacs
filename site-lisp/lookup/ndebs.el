;;; ndebs.el --- Another eblook interface
;; Copyright (C) 2006-2011  Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; Author: Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; ndebs.el is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; ndebs.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with Lookup; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Commentary:
;; ndebs.el is copied and modified from ndeb.el included in Lookup.

;;; Code:

(require 'ndeb)

(defconst ndebs-version "0.1")

;;;
;;; Customizable variables
;;;

(defgroup ndebs nil
  "Lookup ndebs interface."
  :group 'lookup-agents)

(defcustom ndebs-program-arguments '("-q" "-e" "euc-jp" "-i")
  "*A list of arguments for eblook."
  :type '(repeat (string :tag "option"))
  :group 'ndebs)

(defcustom ndebs-process-coding-system
  (if (featurep 'mule) 'euc-jp)
  "*Coding system for eblook process."
  :type 'symbol
  :group 'ndebs)

(defcustom ndebs-title-use-ascii t
  "*Non-nil, convert title to one that use ascii characters."
  :type 'boolean
  :group 'ndebs)


;;;
;;; Internal variables
;;;

(defvar ndebs-process nil
  "Process object for ndebs agents.")

(defvar ndebs-status nil
  "process stataus cache.")

(defvar ndebs-vars nil
  "process variables cache.")


;;;
;:: types
;;;

(defun ndebs-agent-coding (agent)
  (or (lookup-agent-option agent ':coding)
      ndebs-process-coding-system))

(put 'ndebs ':methods (get 'ndeb ':methods))
(put 'ndebs ':gaiji-regexp (get 'ndeb ':gaiji-regexp))
(put 'ndebs ':reference-pattern (get 'ndeb ':reference-pattern))
(put 'ndebs ':reference-regexp (get 'ndeb ':reference-regexp))
(put 'ndebs ':ignore-regexp  (get 'ndeb ':ignore-regexp))
(put 'ndebs ':headings (get 'ndeb ':headings))
(put 'ndebs ':arranges (get 'ndeb ':arranges))
(put 'ndebs ':adjusts (get 'ndeb ':adjusts))
(put 'ndebs ':xbm-regexp (get 'ndeb ':xbm-regexp))
(put 'ndebs ':bmp-regexp (get 'ndeb ':bmp-regexp))
(put 'ndebs ':jpeg-regexp (get 'ndeb ':jpeg-regexp))
(put 'ndebs ':wave-regexp (get 'ndeb ':wave-regexp))
(put 'ndebs ':mpeg-regexp (get 'ndeb ':mpeg-regexp))

;;;
;:: macros
;;;

(put 'ndebs-cache-try-with-agent 'lisp-indent-function 2)
(defmacro ndebs-cache-try-with-agent (agent key form &optional stamp)
  `(ndeb-cache-try-agent ,agent ,key
     (progn (ndebs-select-book ,agent) ,form) ,stamp))

(put 'ndebs-cache-try-with-dictionary 'lisp-indent-function 2)
(defmacro ndebs-cache-try-with-dictionary (dictionary key form &optional stamp)
  `(ndeb-cache-try-dictionary
       ,dictionary ,key
     (progn (ndebs-select-dictionary ,dictionary) ,form) ,stamp))


;;;
;:: Interface functions
;;;

(put 'ndebs 'setup 'ndebs-setup)
(defun ndebs-setup (agent)
  (unless (string-match "^ebnet://" (lookup-agent-location agent))
    (lookup-package-autoload agent)
    ;; Set :alternates option automatically.
    (ndeb-setup-alternates agent))
  (ndebs-start-process)
  ;; Set :coding and :charsets option automatically.
  (ndebs-setup-coding agent)
  ;; Get list of subbooks.
  (let ((coding (ndebs-agent-coding agent))
	(index 0) string name title dicts dictionary)
    (setq string
	  (ndebs-cache-try-with-agent agent 'list
	    (progn
	      (setq coding (or (unless (string-match "utf"
						     (symbol-name coding))
				 coding)
			       ndebs-process-coding-system))
	      (set-process-coding-system ndebs-process coding coding)
	      (prog1 (ndebs-require "list")
		(setq coding (ndebs-agent-coding agent))
		(set-process-coding-system ndebs-process coding coding)))))
    (while (string-match "^[^.]+\\. \\([^\t]+\\)\t\\(.*\\)" string index)
      (setq name (match-string 1 string)
	    title (match-string 2 string)
	    index (match-end 0))
      (when ndebs-title-use-ascii
	(setq title (japanese-hankaku title t)))
      (setq dicts (cons (lookup-new-dictionary agent name name title) dicts)))
    (nreverse dicts)))

(defun ndebs-setup-coding (agent)
  (unless (or (lookup-agent-option agent ':coding)
	      (null ndeb-set-coding-automatically))
    (let (string coding)
      (set-process-coding-system ndebs-process ndebs-process-coding-system
				 ndebs-process-coding-system)
      (setq string (ndebs-cache-try-with-agent agent 'info
		     (ndebs-require "info")))
      (when (string-match "character code: \\(.+\\)$" string)
	(let* ((elt (assoc (match-string 1 string) ndeb-coding-systems-table))
	       (coding (nth 1 elt))
	       (charsets (nth 2 elt)))
	  (lookup-agent-set-default
	   agent ':coding (or coding ndebs-process-coding-system))
	  ;; Set :charsets option when not set.
	  (when (and (> emacs-major-version 22)
		     (null (lookup-agent-option agent ':charsets))
		     charsets)
	    (lookup-agent-set-default agent ':charsets charsets)))))))

(put 'ndebs 'setup-dictionary 'ndebs-setup-dictionary)
(defun ndebs-setup-dictionary (dictionary)
  ;; Set :gaiji-table option automatically.
  (ndeb-setup-gaiji-table dictionary)
  ;; Set :methods option automatically.
  (let* ((subinfo (ndebs-require-subinfo dictionary))
	 (string (if (string-match "^ search methods:\\( .+\\)$" subinfo)
		     (match-string 1 subinfo)
		   ""))
	 (index 0)
	 methods)
    (while (string-match "[a-zA-Z_]+" string index)
      (setq index (match-end 0))
      (add-to-list 'methods
		   (lookup-assoc-ref
		    ndeb-subinfo-method-table (match-string 0 string))))
    (when (memq 'wild methods)
      (add-to-list 'methods 'substring))
    (setq methods (or (delq nil methods) '(nil)))
    (when methods
      (lookup-dictionary-set-default dictionary ':methods methods))))

(put 'ndebs 'clear 'ndebs-clear)
(defun ndebs-clear (agent)
  (when ndebs-process
    (when (eq (process-status ndebs-process) 'run)
      (process-send-string ndebs-process "quit\n"))
    (lookup-process-kill ndebs-process)))

(put 'ndebs 'menu 'ndebs-dictionary-menu)
(defun ndebs-dictionary-menu (dictionary)
  (let ((rtn (ndebs-require-subinfo dictionary))
	entries)
    (setq rtn (and (string-match "^ search methods:\\( .+\\)$" rtn)
		   (match-string 1 rtn)))
    (when rtn
      (when (string-match  " menu\\($\\| \\)" rtn)
	(setq entries (list (lookup-make-entry dictionary "menu" "[Menu]"))))
      (when (string-match  " image_menu\\($\\| \\)" rtn)
	(setq entries
	      (append entries
		      (list
		       (lookup-make-entry dictionary
					  "image_menu" "[Graphic menu]"))))))
    entries))

(put 'ndebs 'copyright 'ndebs-dictionary-copyright)
(defun ndebs-dictionary-copyright (dictionary)
  (ndebs-select-dictionary dictionary)
  (list (lookup-make-entry dictionary "copyright" "[Copyright]")))

(put 'ndebs 'search 'ndebs-dictionary-search)
(defun ndebs-dictionary-search (dictionary query)
  (ndebs-select-dictionary dictionary)
  (if lookup-max-hits (ndebs-require-set "max-hits" lookup-max-hits))
  (let ((method (lookup-query-method query))
	(string (lookup-query-string query))
	cmd)
    (cond
     ((eq method 'keyword)
      (let (qstring)
	(setq qstring string)
	(while (string-match "[ \t　]+" qstring)
	  (setq qstring (replace-match "=" nil t qstring)))
	(setq cmd 
	      (format "set search-method keyword\nsearch \"=%s\"\n"
		      (ndeb-escape-query qstring)))
	(setq qstring string)
	(while (string-match "[ \t　]+" qstring)
	  (setq qstring (replace-match "&" nil t qstring)))
	(setq cmd 
	      (concat cmd (format "set search-method cross\nsearch \"&%s\""
				  (ndeb-escape-query qstring))))
	(ndebs-vars-set "search-method" "cross")))
     (t
      (when (eq method 'substring)
	(setq method 'wild
	      string (concat "*" string "*")))
      (ndebs-require-set "search-method"
			 (lookup-assq-ref ndeb-method-table method))
      (setq cmd (format "search \"%s\"" (ndeb-escape-query string)))))
    (ndebs-require cmd
      (lambda (process)
	(let ((backward (memq method (lookup-dictionary-option
				      dictionary ':backward-methods t)))
	      (backward-regexp (lookup-dictionary-option
				dictionary ':backward-heading t))
	      code heading entries dupchk)
	  (while (re-search-forward "^[^.]+\\. \\([^\t]+\\)\t\\(.*\\)" nil t)
	    (setq code (match-string 1) heading (match-string 2))
	    (when (or backward
		      (and backward-regexp
			   (string-match backward-regexp heading)))
	      (setq code (concat "-" code)))
	    ;; 同じエントリがあるかチェックする。
	    ;; これがけっこうあるんだ・・
	    (unless (member (cons code heading) dupchk)
	      (setq entries
		    (cons (lookup-make-entry dictionary code heading) entries))
	      (setq dupchk (cons (cons code heading) dupchk))))
	  (nreverse entries))))))

(put 'ndebs 'content 'ndebs-dictionary-content)
(defun ndebs-dictionary-content (dictionary entry)
  (ndebs-select-dictionary dictionary)
  (if lookup-max-text (ndebs-require-set "max-text" lookup-max-text))
  (ndebs-require-set "stop-code"
		     (lookup-dictionary-option dictionary ':stop-code t))
  (let ((code (lookup-entry-code entry)))
    (if (member code '("menu" "image_menu" "copyright"))
	(ndebs-require code)
      (ndebs-require (concat "content "
			     (lookup-entry-code entry))))))

(put 'ndebs 'gaiji 'ndebs-dictionary-gaiji)
(defun ndebs-dictionary-gaiji (dictionary code)
  (ndebs-select-dictionary dictionary)
  (when (null lookup-use-bitmap)
    (let (height tmp)
      (unless (setq height
		    (lookup-dictionary-option dictionary ':gaiji-size t))
	(with-temp-buffer
	  (insert-string (ndebs-require-subinfo dictionary))
	  (when (search-backward "font sizes:")
	    (while (re-search-forward "[0-9]+" nil t)
	      (setq tmp (string-to-number (match-string 0)))
	      (if (eq tmp ndeb-gaiji-size)
		  (progn
		    (setq height tmp)
		    (goto-char (point-max)))
		(when (and (> ndeb-gaiji-size tmp)
			   (or (null height)
			       (< height tmp)))
		  (setq height tmp))))))
	(setq height (or height ndeb-gaiji-default-size))
	(lookup-dictionary-set-default dictionary :gaiji-size height))
      (ndebs-require-set "font" (number-to-string height))))
  (let ((xbm (ndebs-require (concat "font " code))))
    (catch ':done
      (when (string-match "default_width" xbm)
	(throw ':done xbm))
      (when (or lookup-use-bitmap
		(equal (ndebs-vars-get "font") "16"))
	(throw ':done nil))
      (ndebs-require-set "font" "16")
      (setq xbm (ndebs-require (concat "font " code)))
      (when  (string-match "default_width" xbm)
	xbm))))

;;;
;;; Internal functions
;;;

(defun ndebs-start-process ()
  "eblookが起動していなければ起動する。"
  (unless (and (processp ndebs-process)
	       (eq (process-status ndebs-process) 'run))
    (let ((buffer (or (lookup-open-process-buffer " *ndebs*")
		      (lookup-temp-buffer))))
      (setq ndebs-process (apply 'start-process "ndebs" buffer
				 ndeb-program-name ndebs-program-arguments)
	    ndebs-status nil
	    ndebs-vars nil)
      (set-process-coding-system ndebs-process
				 ndebs-process-coding-system
				 ndebs-process-coding-system)
      (process-kill-without-query ndebs-process)
      (with-current-buffer buffer
	(catch 'started
	  (while (accept-process-output ndebs-process 10)
	    (save-excursion
	      (goto-char (point-min))
	      (when (search-forward ndeb-prompt-string nil t)
		(throw 'started t))))
	  (error "Failed start process")))
      (unless lookup-debug-mode
	(set-process-buffer ndebs-process nil)
	(kill-buffer buffer)))
    (ndebs-require-set "prompt" "")
    (ndebs-require-set "decorate-mode" "on")
    (ndebs-require-set "escape-text" "on")))

(defun ndebs-select-book (agent)
  "eblookのbookをagentに変更する。既に選択されている場合は何もしない。"
  (let ((book (lookup-agent-location agent))
	(appendix (lookup-agent-option agent ':appendix)))
    (unless (and (equal (ndebs-status-get 'book) book)
		 (equal (ndebs-status-get 'appendix) appendix))
      (ndebs-send (concat "book " book " " appendix))
      (ndebs-status-set 'book book)
      (ndebs-status-set 'appendix appendix)
      (ndebs-status-set 'subbook nil)
      (let ((coding (ndebs-agent-coding agent)))
	(set-process-coding-system ndebs-process coding coding)))))

(defun ndebs-select-dictionary (dictionary)
  "辞書をdictionaryに変更する。既に選択されている場合は何もしない。"
  (ndebs-select-book (lookup-dictionary-agent dictionary))
  (let ((subbook (lookup-dictionary-code dictionary)))
    (unless (equal (ndebs-status-get 'subbook) subbook)
      (ndebs-send (concat "select " subbook))
      (ndebs-status-set 'subbook subbook))))

(defun ndebs-status-get (key)
  (lookup-assq-ref ndebs-status key))

(defun ndebs-status-set (key value)
  (setq ndebs-status
	(lookup-assq-set ndebs-status key value)))

(defun ndebs-vars-get (var)
  (lookup-assoc-ref ndebs-vars var))

(defun ndebs-vars-set (var value)
  (setq ndebs-vars
	(lookup-assoc-set ndebs-vars var value)))

(put 'ndebs-require 'lisp-indent-function 1)
(defun ndebs-require (string &optional filter)
  "eblookにコマンドを送信し、出力された文字列を返す。lookup-process-requireを参照。"
  (let ((lookup-process-output-separator-lines 0))
    (lookup-process-require ndebs-process
			    (concat string "\nset prompt \""
				    ndeb-prompt-string "\"\nset prompt\n")
			    (concat "^" ndeb-prompt-string) filter)))

(defun ndebs-require-subinfo (dictionary)
  (ndebs-cache-try-with-dictionary dictionary 'subinfo
    (let* ((agent (lookup-dictionary-agent dictionary))
	   (coding (ndebs-agent-coding agent)))
      (setq coding (or (unless (string-match "utf"
					     (symbol-name coding))
			 coding)
		       ndebs-process-coding-system))
      (set-process-coding-system ndebs-process coding coding)
      (prog1 (ndebs-require "subinfo")
	(setq coding (ndebs-agent-coding agent))
	(set-process-coding-system ndebs-process coding coding)))))

(defun ndebs-send (string)
  "eblookにコマンドを送信する。実行終了は待たない。"
  (lookup-process-send ndebs-process (concat string "\n")))

(defun ndebs-require-set (var value)
  "eblookの変数をsetまたは(unset)する。既にsetされている場合は何もしない。"
  (unless (and (equal (ndebs-vars-get var) value) value)
    (ndebs-vars-set var value)
    (if value
	(ndebs-send (format "set %s \"%s\"" var value))
      (ndebs-send (format "unset %s" var)))))

(provide 'ndebs)

;;; ndebs.el ends here
