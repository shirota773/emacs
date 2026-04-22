;;; ndeb.el --- Lookup eblook interface
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: ndeb.el,v 1.2.4.48 2012-06-10 01:31:41 kazuhiro Exp $

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

(require 'lookup)

(defconst ndeb-version "1.2")

;;;
;:: Customizable variables
;;;

(defgroup ndeb nil
  "Lookup eblook interface."
  :group 'lookup-agents)

(defcustom ndeb-program-name "eblook"
  "*Program name of eblook."
  :type 'string
  :group 'ndeb)

(defcustom ndeb-program-arguments '("-q" "-e" "euc-jp" "-i")
  "*A list of arguments for eblook."
  :type '(repeat (string :tag "option"))
  :group 'ndeb)

(defcustom ndeb-prompt-string "eblook> "
  "*Prompt string of eblook."
  :type 'string
  :group 'ndeb)

(defcustom ndeb-process-coding-system
  (if (featurep 'mule) 'euc-jp)
  "*Coding system for eblook process."
  :type 'symbol
  :group 'ndeb)

(defcustom ndeb-max-image-size 1048576
  "*ndeb 検索時に表示する画像の最大サイズ (バイト)。
デフォルトは 1MB。nil を指定すると、無制限になる。"
  :type '(choice integer (const nil))
  :group 'ndeb)

(defcustom ndeb-gaiji-size 16
  "デフォルトで使用する外字のサイズ。指定したサイズの外字が存在しない場合は指定値を越えない最大サイズを、それも存在しない場合は16ドットの外字を使用する。"
  :type '(choice :tag "size"
		 (const 16)
		 (const 24)
		 (const 30)
		 (const 48))
  :group 'ndeb)

(defcustom ndeb-minimum-indent 1
  "指定した数字を越えた分だけ字下げ処理を行う。通常は0または1。"
  :type 'integer
  :group 'ndeb)

(defcustom ndeb-default-script-height 0.8
  "Default height of super/subscript letters.
1 or 0 mean height is not set."
  :type '(choice 
	  (list :tag "step" (const -) (integer :tag "count" :value 2))
	  (number :tag "scale factor" :value 0.8)
	  (function :tag "function")
	  (sexp :tag "other"))
  :group 'ndeb)

(defcustom ndeb-set-coding-automatically t
  "*Non-nil, set agent option :coding and :charset automatically.
This affects only ndebs agent at present."
  :type 'boolean
  :group 'ndeb)

(defcustom ndeb-set-alternates-automatically t
  "*Non-nil, set agent option :alternates automatically."
  :type 'boolean
  :group 'ndeb)

(defcustom ndeb-set-gaiji-table-automatically t
  "*Non-nil, set agent option :gaiji-table automatically."
  :type 'boolean
  :group 'ndeb)

(defface ndeb-bold-face
  '((t (:weight bold)))
  "Face used to bold text."
  :group 'ndeb
  :group 'lookup-faces)

(defface ndeb-italic-face
  '((t (:slant italic)))
  "Face used to italic text."
  :group 'ndeb
  :group 'lookup-faces)

(defface ndeb-emphasis-face
  '((t (:slant italic :weight bold)))
  "Face used to emphasized text."
  :group 'ndeb
  :group 'lookup-faces)


;;;
;:: Internal varialbes
;;;

(defvar ndeb-current-agent nil)
(defvar ndeb-current-dictionary nil)
(defvar ndeb-current-process nil)

(defconst ndeb-method-table
  '((exact . "exact")
    (prefix . "word")
    (suffix . "endword")
    (wild . "wild")))

(defconst ndeb-subinfo-method-table
  '(("word" . prefix)
    ("endword" . suffix)
    ("exactword" . exact)
    ("wild" . wild)
    ("keyword" . keyword)
    ("cross" . keyword)))

(defconst ndeb-gaiji-default-size 16)

(defconst ndeb-entities-table
  '(("amp" . "&")
    ("lt" . "<")
    ("gt" . ">")))

(defconst ndeb-faces-table
  '(("italic" . ndeb-italic-face)
    ("bold" . ndeb-bold-face)
    ("em" . ndeb-emphasis-face)))

(defconst ndeb-coding-systems-table
  '(("UTF-8" utf-8 (unicode))
    ("ISO 8859-1" iso-8859-1 (ascii latin-iso8859-1))
    ("JIS X 0208" euc-jp (ascii japanese-jisx0208-1978 japanese-jisx0208))))

;;;
;:: inline functions
;;;

(defsubst ndeb-ebnet-uri-p (string)
  "Return non-nil if STRING is ebnet uri."
  (save-match-data
    (let ((case-fold-search t))
      (string-match "^ebnet://" string))))

;;;
;:: types
;;;

;; ndeb agent:
;;
;;   (ndeb DIRECTORY :appendix APPENDIX)
;;
;; DIRECTORY - dictionary directory
;; APPENDIX  - appendix directory
;;
;; [property]
;; ndeb-process - eblook process related with agent
;; ndeb-dict    - last used dictionary
;; ndeb-method  - last used value of search-method
;; ndeb-stop    - last used value of stop-code

(defun ndeb-agent-directory (agent)
  (let ((dir (lookup-agent-location agent)))
    (if dir 
	(if (ndeb-ebnet-uri-p dir)
	    dir
	  (expand-file-name dir))
      (error "You should specify a dictionary directory"))))

(defun ndeb-agent-appendix (agent)
  (let ((dir (lookup-agent-option agent ':appendix)))
    (if dir
	(if (ndeb-ebnet-uri-p dir)
	    dir
	  (expand-file-name dir)))))

(defun ndeb-agent-coding (agent)
  (or (lookup-agent-option agent ':coding)
      ndeb-process-coding-system))

(require 'ndeb-binary)

(put 'ndeb ':methods '(exact prefix suffix keyword substring wild))
(put 'ndeb ':gaiji-regexp "<gaiji=\\([^>]*\\)>")
(put 'ndeb ':reference-pattern '("<reference>\\(→?\\(\\(.\\|\n\\)*\\)\\)</reference=\\([^>]+\\)>" 1 2 4))
(put 'ndeb ':reference-regexp '("<reference>" . "</reference=[^>]+>"))
(put 'ndeb ':ignore-regexp "<\\(/?\\(su[pb]\\|em\\|font\\(=[a-z]+\\)?\\|no-newline\\)\\|ind=[0-9]\\)>")

(put 'ndeb ':headings
     '(ndeb-arrange-unicode
       ndeb-arrange-scripts
       ndeb-arrange-faces
       ndeb-arrange-ignore
       lookup-arrange-gaijis
       ndeb-arrange-decode-entity))

(put 'ndeb ':arranges
     '(ndeb-arrange-auto-jump-reference
       ndeb-arrange-xbm
       ndeb-arrange-bmp
       ndeb-arrange-jpeg
       ndeb-arrange-image-page
       ndeb-arrange-wave
       ndeb-arrange-mpeg
       ndeb-arrange-indent
       ndeb-arrange-unicode
       ndeb-arrange-scripts
       ndeb-arrange-faces
       ndeb-arrange-ignore
       ndeb-arrange-no-newline
       ndeb-arrange-prev-next
       ndeb-arrange-paged-reference
       lookup-arrange-references
       lookup-arrange-gaijis
       ndeb-arrange-decode-entity
       lookup-arrange-squeezed-references
       lookup-arrange-default-headings
       ndeb-arrange-fill-lines
       ndeb-arrange-snd-autoplay))

(put 'ndeb ':adjusts
     '(lookup-adjust-check-references
       lookup-adjust-show-gaijis
       lookup-adjust-goto-min))

;; ndeb dictionary:
;;
;; CODE - same as NAME below
;; NAME - given by eblook `list' command
;; 
;; [option]
;; :coding    - process coding system
;; :stop-code - stop-code used by eblook

(defun ndeb-new-dictionary (name title)
  (lookup-new-dictionary ndeb-current-agent name name title))

(defun ndeb-dictionary-stopcode (dictionary)
  (lookup-dictionary-option dictionary ':stop-code t))

;; ndeb entry:
;;
;; CODE    - entry specific code (e.g. "2c00:340") by eblook `search' command
;; HEADING - given by eblook `search' command

(defun ndeb-make-entry (code heading)
  (lookup-make-entry ndeb-current-dictionary code heading))

;;;
;:: macros
;;;

(put 'ndeb-with-agent 'lisp-indent-function 1)
(defmacro ndeb-with-agent (agent &rest body)
  `(let ((ndeb-current-agent ,agent)
	 (ndeb-current-process (ndeb-agent-process ,agent)))
     ,@body))

(put 'ndeb-with-dictionary 'lisp-indent-function 1)
(defmacro ndeb-with-dictionary (dictionary &rest body)
  `(ndeb-with-agent (lookup-dictionary-agent ,dictionary)
     (let ((ndeb-current-dictionary ,dictionary))
       (unless (eq ,dictionary
		   (lookup-agent-get-property ndeb-current-agent 'ndeb-dict))
	 ;; 必要なときだけ辞書を select する。
	 ;; 外部プロセスとやりとりするよりこの方が高速だろうし、
	 ;; デバッグのときバッファがごちゃごちゃするのはうざったい。
	 (ndeb-process-send
	  (concat "select " (lookup-dictionary-code ,dictionary)))
	 (lookup-agent-put-property ndeb-current-agent 'ndeb-dict
				    ,dictionary))
       ,@body)))

(defun ndeb-agent-process (agent)
  (let ((process (lookup-agent-get-property agent 'ndeb-process)))
    (unless (and process (eq (process-status process) 'run))
      (if process (lookup-process-kill process))
      (setq process (ndeb-process-open (ndeb-agent-directory agent)
				       (ndeb-agent-appendix agent)))
      ;; コマンドの実行毎に行なう必要のある処理。
      (let ((ndeb-current-process process))
	(if lookup-max-hits (ndeb-require-set "max-hits" lookup-max-hits))
	(if lookup-max-text (ndeb-require-set "max-text" lookup-max-text)))
      (lookup-agent-put-property agent 'ndeb-process process)
      (lookup-agent-put-property agent 'ndeb-dict nil)
      (lookup-agent-put-property agent 'ndeb-method nil)
      (lookup-agent-put-property agent 'ndeb-stop nil))
    process))

(defun ndeb-agent-kill-process (agent)
  (let ((process (lookup-agent-get-property agent 'ndeb-process)))
    (when process
      (if (eq (process-status process) 'run)
	  (process-send-string process "quit\n"))
      (lookup-process-kill process)
      (lookup-agent-put-property agent 'ndeb-process nil))))

(put 'ndeb-cache-try-agent 'lisp-indent-function 2)
(defmacro ndeb-cache-try-agent (agent key form &optional stamp)
  `(lookup-cache-try
    'ndeb (lookup-agent-location ,agent) nil ,key ,form
    ,(or stamp
	 '(unless (ndeb-ebnet-uri-p (lookup-agent-location agent))
	    (nth 5 (file-attributes (lookup-agent-location agent)))))))

(put 'ndeb-cache-try-dictionary 'lisp-indent-function 2)
(defmacro ndeb-cache-try-dictionary (dictionary key form &optional stamp)
  `(lookup-cache-try
    'ndeb (lookup-agent-location (lookup-dictionary-agent ,dictionary))
    (lookup-dictionary-code ,dictionary) ,key
    ,form
    ,(or stamp
	 '(let* ((agent (lookup-dictionary-agent dictionary))
		 (location (lookup-agent-location agent))
		 (files (ndeb-agent-location-files agent))
		 (case-fold-search t)
		 (regexp
		  (format "^%s$"
			  (regexp-quote (lookup-dictionary-code dictionary))))
		 attr)
	    ;; Search real directory name from dictionary code, which never contains upper case.
	    (catch :done
	      (while files
		(when (and (string-match regexp (car files))
			   (car (setq attr (file-attributes
					    (expand-file-name (car files)
							      location)))))
		  (throw :done (nth 5 attr)))
		(setq files (cdr files))))))))


;;;
;:: Interface functions
;;;

(put 'ndeb 'setup 'ndeb-setup)
(defun ndeb-setup (agent)
  (unless (ndeb-ebnet-uri-p (lookup-agent-location agent))
    (lookup-package-autoload agent)
    ;; Set :alternates option automatically.
    (ndeb-setup-alternates agent))
  (ndeb-with-agent agent
    (let ((coding (ndeb-agent-coding agent))
	  dictionaries)
      (setq coding (or (unless (string-match "utf" (symbol-name coding))
			 coding)
		       ndeb-process-coding-system))
      (set-process-coding-system ndeb-current-process coding coding)
      (setq dictionaries
	    (ndeb-process-require "list"
	      (lambda (process)
		(let (name title dicts)
		  (while (re-search-forward
			  "^[^.]+\\. \\([^\t]+\\)\t\\(.*\\)" nil t)
		    (setq name (match-string 1) title (match-string 2))
		    (setq dicts (cons (ndeb-new-dictionary name title) dicts)))
		  (nreverse dicts)))))
      (setq coding (ndeb-agent-coding agent))
      (set-process-coding-system ndeb-current-process coding coding)
      dictionaries)))

(defun ndeb-setup-alternates (agent)
  (let ((file (expand-file-name "alternate.ini"
				(lookup-agent-location agent))))
    (unless (or (lookup-agent-option agent ':alternates)
		(null ndeb-set-alternates-automatically)
		(null (file-readable-p file)))
      (lookup-agent-set-default
       agent ':alternates
       (ndeb-make-alternates-from-list
	(ndeb-cache-try-agent agent 'alternates
	  (ndeb-make-alternates-list-from-file file)
	  (nth 5 (file-attributes file))))))))

(put 'ndeb 'setup-dictionary 'ndeb-setup-dictionary)
(defun ndeb-setup-dictionary (dictionary)
  ;; Set :gaiji-table option automatically.
  (ndeb-setup-gaiji-table dictionary))

(defun ndeb-setup-gaiji-table (dictionary)
  (let* ((case-fold-search t)
	 (regexp (format
		  "^%s\\.map$"
		  (regexp-quote (lookup-dictionary-code dictionary))))
	 (agent (lookup-dictionary-agent dictionary))
	 (directory (lookup-agent-location agent))
	 (files (ndeb-agent-location-files agent))
	 file)
    (while files
      (if (string-match regexp (car files))
	  (setq file (expand-file-name (car files) directory)
		files nil)
	(setq files (cdr files))))
    (unless (or (lookup-dictionary-option dictionary ':gaiji-table nil)
		(null ndeb-set-gaiji-table-automatically)
		(null (and file (file-readable-p file))))
      (message "Loading gaiji map file %s" file)
      (lookup-dictionary-set-default
       dictionary ':gaiji-table
       (ndeb-make-gaiji-table-from-list
        (ndeb-cache-try-dictionary dictionary 'gaiji-list
	  (ndeb-make-gaiji-list-from-file file)
	  (nth 5 (file-attributes file))))))))

(put 'ndeb 'clear 'ndeb-clear)
(defun ndeb-clear (agent)
  (ndeb-agent-kill-process agent)
  (ndeb-binary-clear agent))

(put 'ndeb 'menu 'ndeb-dictionary-menu)
(defun ndeb-dictionary-menu (dictionary)
  (ndeb-with-dictionary dictionary
    (let ((rtn (ndeb-process-require "subinfo"))
	  entries)
      (setq rtn (and (string-match "^ search methods:\\( .+\\)$" rtn)
		     (match-string 1 rtn)))
      (when rtn
	(when (string-match  " menu\\($\\| \\)" rtn)
	  (setq entries (list (ndeb-make-entry "menu" "[Menu]"))))
	(when (string-match  " image_menu\\($\\| \\)" rtn)
	  (setq entries
		(append entries
			(list
			 (ndeb-make-entry "image_menu" "[Graphic menu]"))))))
      entries)))


(put 'ndeb 'copyright 'ndeb-dictionary-copyright)
(defun ndeb-dictionary-copyright (dictionary)
  (ndeb-with-dictionary dictionary
    (list (ndeb-make-entry "copyright" "[Copyright]"))))

(put 'ndeb 'search 'ndeb-dictionary-search)
(defun ndeb-dictionary-search (dictionary query)
  (ndeb-with-dictionary dictionary
    (let ((method (lookup-query-method query))
	  (string (lookup-query-string query))
	  (last (lookup-agent-get-property ndeb-current-agent 'ndeb-method))
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
	  (lookup-agent-put-property ndeb-current-agent 'ndeb-method "cross")))
       (t
	(when (eq method 'substring)
	  (setq method 'wild
		string (concat "*" string "*")))
	(unless (eq method last)
	  ;; 必要のあるときだけ search-method を設定する。ndeb-dict に同じ。
	  (ndeb-require-set "search-method"
			    (lookup-assq-ref ndeb-method-table method))
	  (lookup-agent-put-property ndeb-current-agent 'ndeb-method method))
	(setq cmd (format "search \"%s\"" (ndeb-escape-query string)))))
      (ndeb-process-require cmd
        (lambda (process)
	  (let ((backward (memq method (lookup-dictionary-option
					dictionary ':backward-methods t)))
		(backward-regexp (lookup-dictionary-option
				  dictionary ':backward-heading t))
		code heading dupchk entries)
	    (while (re-search-forward "^[^.]+\\. \\([^\t]+\\)\t\\(.*\\)" nil t)
	      (setq code (match-string 1) heading (match-string 2))
	      (when (or backward
			(and backward-regexp
			     (string-match backward-regexp heading)))
		(setq code (concat "-" code)))
	      ;; 同じエントリがあるかチェックする。
	      ;; これがけっこうあるんだ・・
	      (unless (member (cons code heading) dupchk)
		(setq entries (cons (ndeb-make-entry code heading) entries))
		(setq dupchk (cons (cons code heading) dupchk))))
	    (nreverse entries)))))))

(put 'ndeb 'content 'ndeb-dictionary-content)
(defun ndeb-dictionary-content (dictionary entry)
  (ndeb-with-dictionary dictionary
    (let ((stop (ndeb-dictionary-stopcode dictionary))
          (last (lookup-agent-get-property ndeb-current-agent 'ndeb-stop)))
      (unless (eq stop last)
        ;; 必要のあるときだけ stop-code を設定する。ndeb-dict に同じ。
        (ndeb-require-set "stop-code" stop)
        (lookup-agent-put-property ndeb-current-agent 'ndeb-stop stop)))
    (let ((code (lookup-entry-code entry)) return)
      (setq return
	    (if (member code '("menu" "image_menu" "copyright"))
		(ndeb-process-require code)
	      (ndeb-process-require (concat "content "
					    (lookup-entry-code entry)))))
      return)))
	  

(put 'ndeb 'gaiji 'ndeb-dictionary-gaiji)
(defun ndeb-dictionary-gaiji (dictionary code)
  (ndeb-with-dictionary dictionary
    (when (null lookup-use-bitmap)
      (let (height tmp)
	(setq height (lookup-dictionary-option dictionary ':gaiji-size t))
	(unless height
	  (with-temp-buffer
	    (insert-string (ndeb-process-require "subinfo"))
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
	(ndeb-require-set "font" (number-to-string height))))
    (let ((xbm (ndeb-process-require (concat "font " code))))
      (catch ':done
	(when (string-match "default_width" xbm)
	  (throw ':done xbm))
	(when (or lookup-use-bitmap
		  (equal (ndeb-process-require "show font") "16"))
	  (throw ':done nil))
	(ndeb-require-set "font" "16")
	(setq xbm (ndeb-process-require (concat "font " code)))
	(when  (string-match "default_width" xbm)
	  xbm)))))


;;;
;:: Internal functions
;;;

(defun ndeb-require-set (var value)
  (if value
      (ndeb-process-send (format "set %s \"%s\"" var value))
    (ndeb-process-send (format "unset %s" var))))

(defun ndeb-escape-query (string)
  (let ((start 0))
    (while (string-match "\\\\" string start)
      (setq string (replace-match "\\\\" t t string)
	    start (1+ (match-end 0)))))
  string)

(defun ndeb-arrange-no-newline (entry)
  (while (search-forward "<no-newline>" nil t)
    (let ((beg-beg (match-beginning 0))
	  (beg-end (match-end 0)))
      (if (and (re-search-forward "<\\(/?\\)no-newline>" nil t)
	       (equal (match-string 1) "/"))
	  (let ((end-beg (match-beginning 0)))
	    (goto-char end-beg)
	    (skip-chars-backward "\t " beg-end)
	    (when (> (point) (point-min))
	      (backward-char))
	    (when (< beg-end (point))
	      (add-text-properties beg-end (point) '(read-only t)))
	    (delete-region end-beg (match-end 0))
	    (delete-region beg-beg beg-end))
	(goto-char beg-beg)
	(delete-region beg-beg beg-end)))))

(defun ndeb-arrange-prev-next (entry)
  (while (re-search-forward "\\(<prev>\\|<next>\\)" nil t)
    (if (equal (match-string 0) "<prev>")
	(replace-match "\n(前項目⇒")
      (replace-match "(次項目⇒"))
    (if (re-search-forward "\\(</prev>\\|</next>\\)" nil t)
	(replace-match ")"))))

(defun ndeb-arrange-ignore (entry)
  (let ((regexp (lookup-dictionary-option dictionary ':ignore-regexp t)))
    (while (re-search-forward regexp nil t)
      (replace-match ""))))

(defalias 'ndeb-arrange-fill-lines 'lookup-arrange-fill-lines)

(defun ndeb-arrange-paged-reference (entry)
  (while (re-search-forward "<paged-reference=\\([0-9]+:[0-9]+\\)>" nil t)
    (let ((pos (match-string 1))
	  (start (match-beginning 0))
	  (end (match-end 0)))
      (condition-case nil
	  (progn
	    (search-forward "</paged-reference>")
	    (replace-match (format "</reference=%s>" pos))
	    (delete-region start end)
	    (goto-char start)
	    (insert "<reference>"))
	(error nil)))))

(defun ndeb-arrange-auto-jump-reference (entry)
  (when (re-search-forward "<auto-jump-reference></auto-jump-reference=\\([0-9]+:[0-9]+\\)>" nil t)
    (let ((code (match-string 1)))
      (erase-buffer)
      (insert
       (if (eq (lookup-agent-class (lookup-dictionary-agent dictionary)) 'ndeb)
	   (ndeb-dictionary-content dictionary (ndeb-make-entry code nil))
	 (ndebs-dictionary-content
	  dictionary (lookup-make-entry dictionary code nil)))))))

(defun ndeb-arrange-indent (entry)
  (while (re-search-forward "<ind=\\([0-9]\\)>" nil t)
    (let ((beg-beg (match-beginning 0))
	  (beg-end (match-end 0))
	  (level (- (string-to-number (match-string 1))
		    (or 
		     (lookup-dictionary-option dictionary ':minimum-indent t)
		     ndeb-minimum-indent)))
	  indent-end point)
      (delete-region beg-beg (point))
      (when (> level 0)
	(setq point (point))
	(setq indent-end
	      (or (and (re-search-forward "<ind=[0-9]>" nil t)
		       (match-beginning 0))
		  (point-max)))
	(set-left-margin point indent-end level)
	(goto-char point)))))

(defun ndeb-arrange-scripts (entry)
  (while (re-search-forward "<\\(su[bp]\\)>" nil t)
    (let ((beg-beg (match-beginning 0))
	  (tag (match-string 1)))
      (delete-region beg-beg (match-end 0))
      (if (and (re-search-forward (concat "<\\(/?\\)" tag ">") nil t)
	       (equal (match-string 1) "/"))
	  (let ((end-beg (match-beginning 0))
		(height (or (lookup-dictionary-option
			     dictionary ':script-height t)
			    ndeb-default-script-height)))
	    (goto-char end-beg)
	    (add-text-properties
	     beg-beg (point) `(display ,(delq nil
					      `((raise ,(if (equal tag "sub")
							    -0.3
							  0.3))
						,(if (or (eq height 0)
							 (eq height 1))
						     nil
						   `(height ,height))))))
	    (delete-region end-beg (match-end 0)))
	(goto-char beg-beg)))))

(defun ndeb-arrange-faces (entry)
  (while (re-search-forward "<\\(/?\\)em>" nil t)
    (if (equal (match-string 1) "/")
	(replace-match "</font>" t t)
      (replace-match "<font=em>" t t)))
  (goto-char (point-min))
  (while (re-search-forward "<font=\\([a-z]+\\)>" nil t)
    (let ((beg-beg (match-beginning 0))
	  (beg-end (match-end 0))
	  (class (match-string 1)))
      (if (and (re-search-forward
		"<\\(/?\\)font\\(=[a-z]+\\)?>" nil t)
	       (equal (match-string 1) "/"))
	  (let ((end-beg (match-beginning 0))
		(end-end (match-end 0)))
	    (add-text-properties beg-end end-beg
				 `(face ,(or (lookup-assoc-ref
					      ndeb-faces-table class)
					     default)))
	    (delete-region end-beg end-end)
	    (delete-region beg-beg beg-end))
	(goto-char beg-beg)
	(delete-region beg-beg beg-end)))))

(defvar ndeb-arrange-unicode-insert-function
  (cond
   ;; Emacs 23 and later
   ((eval-when-compile
      (null (and (stringp mule-version)
		 (string< mule-version "6.0"))))
    (lambda (ucs) (char-to-string (string-to-number ucs 16))))
   ;; mule-ucs
   ((functionp 'ucs-to-char)
    (lambda (ucs) (char-to-string (ucs-to-char (string-to-number ucs 16)))))
   ;; Unsupported environment
   (t
    (lambda (ucs) (format "[U+%s]" ucs)))))

(defun ndeb-arrange-unicode (entry)
  (while (re-search-forward "<unicode>\\([0-9A-Fa-f]+\\)</unicode>" nil t)
    (replace-match
     (funcall ndeb-arrange-unicode-insert-function (match-string 1)) t t)))
    
(defun ndeb-arrange-decode-entity (entry)
  (while (re-search-forward "&\\(amp\\|lt\\|gt\\);" nil t)
    (let* ((pos (match-beginning 0))
	   (properties (text-properties-at pos)))
      (replace-match (lookup-assoc-ref
		      ndeb-entities-table (match-string 1)) t t)
      (set-text-properties pos (1+ pos) properties)
      (goto-char (1+ pos)))))

(defun ndeb-make-alternates-from-list (list)
  "Return alternates generated from alternate list LIST.  Alternate list is made by `ndeb-make-alternates-list-from-file'."
  (when (eval-when-compile (and (functionp 'decode-char)
				(decode-char 'ucs ?A)))
    (delq nil 
	  (let (char)
	    (mapcar (lambda (elt)
		      (when (setq char (decode-char 'ucs (car elt)))
			(cons char (cdr elt))))
		    list)))))

(defun ndeb-make-alternates-list-from-file (inifile)
  "Return alternate list generated from INIFILE.  INIFILE is alternate.ini for EBWin."
  (let (table)
    (message "Making alternate list from %s..." inifile)
    (with-temp-buffer
      (insert-file-contents inifile)
      (set-text-properties (point-min) (point-max) nil)
      (while (re-search-forward
	      "^[ \t]*u\\([0-9a-fA-F]+\\)\t\\([^\t\n]+\\)" nil t)
	(add-to-list 'table
		     (cons (string-to-number (match-string 1) 16)
			   (match-string 2)))))
    (message "Making alternate list from %s...done" inifile)
    table))

(defun ndeb-make-gaiji-table-from-list (list)
  (when (eval-when-compile (and (functionp 'decode-char)
				(decode-char 'ucs ?A)))
    (lookup-new-gaiji-table
     (delq nil
	   (let (chars result)
	     (mapcar
	      (lambda (elt)
		(if (stringp (cdr elt))
		    (list (car elt) (cdr elt) nil)
		  (setq result (mapcar (lambda (char)
					 (decode-char 'ucs char))
				       (cdr elt)))
		  (unless (memq nil result)
		    (list (car elt) (apply 'string result) nil))))
	      list))))))

(defun ndeb-make-gaiji-list-from-file (mapfile)
  (let (table char)
    (message "Making gaiji list from %s..." mapfile)
    (with-temp-buffer
      (insert-file-contents mapfile)
      (set-text-properties (point-min) (point-max) nil)
      (while (re-search-forward
	      "^[ \t]*\\([hzcg][0-9a-fA-F]+\\)\t\\([^\t]+\\)\\(\t\\([^\t\n]*\\)\\)" nil t)
	(setq char (or (save-match-data
			 (ndeb-make-gaiji-list-from-file-internal
			  (match-string 2)))
		       (unless (eq (length (match-string 4)) 0)
			 (match-string 4))))
	(when char
	  (add-to-list 'table (cons (downcase (match-string 1))
				    char)))))
    (message "Making gaiji list from %s...done" mapfile)
    (nreverse table)))

(defun ndeb-make-gaiji-list-from-file-internal (string)
  (if (or (equal "-" string)
	  (equal "null" string))
      ""
    (let ((index 0) result char)
      (while (string-match "u\\([0-9A-Fa-f]+\\)" string index)
	(setq index (match-end 1)
	      char (string-to-number (match-string 1 string) 16)
	      result (cons char result)))
      (nreverse result))))

(defun ndeb-agent-location-files (agent)
  (let ((location (lookup-agent-location agent)))
    (unless (ndeb-ebnet-uri-p location)
      (ndeb-cache-try-agent agent 'files
	(directory-files location)))))

;;;
;:: eblook process
;;;

(defun ndeb-process-open (directory appendix)
  (let* ((args (append ndeb-program-arguments
		       (cons directory (if appendix (list appendix)))))
	 (buffer (lookup-open-process-buffer (concat " *ndeb+" directory "*")))
	 (process (apply 'start-process "ndeb"
			 (or buffer (lookup-temp-buffer))
			 ndeb-program-name args)))
    (set-process-coding-system
     process ndeb-process-coding-system ndeb-process-coding-system)
    (process-kill-without-query process)
    (with-current-buffer (process-buffer process)
      (catch 'started
	(while (accept-process-output process 20)
	  (save-excursion
	    (goto-char (point-min))
	    (when (search-forward ndeb-prompt-string nil t)
	      (throw 'started t))))
	(error "Failed to start process"))
      (save-excursion
	(goto-char (point-min))
	(if (search-forward "Warning: invalid book directory" nil t)
	    (error "Invalid dictionary directory: %s" directory))
	(goto-char (point-min))
	(if (search-forward "Warning: invalid appendix directory" nil t)
	    (error "Invalid appendix directory: %s" appendix)))
      (let ((string (concat "set prompt\n"
			    "set decorate-mode on\n"
			    "set escape-text on\n")))
	(process-send-string process string)
	(insert string))
      (unless buffer
	(set-process-buffer process nil)
	(kill-buffer (current-buffer))))
    process))

(put 'ndeb-process-require 'lisp-indent-function 1)
(defun ndeb-process-require (command &optional filter)
  (let ((lookup-process-output-separator-lines 0))
    (lookup-process-require ndeb-current-process
			    (concat command "\nset prompt \""
				    ndeb-prompt-string "\"\nset prompt\n")
			    (concat "^" ndeb-prompt-string) filter)))

(defun ndeb-process-send (string)
  (lookup-process-send ndeb-current-process (concat string "\n")))

(provide 'ndeb)

;;; ndeb.el ends here
