;;; ndict.el --- Lookup DICT client
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: ndict.el,v 1.1.1.1.4.7 2011-06-08 12:57:11 kazuhiro Exp $

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

(defconst ndict-version "1.1")


;;;
;:: Internal variables
;;;

(defvar ndict-current-agent nil)
(defvar ndict-current-dictionary nil)
(defvar ndict-current-process nil)
(defvar ndict-match-exact nil)

(defconst ndict-system-info-alist
  '(;; dictd-1.4.x
    (dictd
     (methods . ((exact . "exact") (prefix . "prefix") (suffix . "suffix")
		 (substring . "substring") (wild . "re") (regexp . "re"))))
    ;; minimum feature defined in RFC2229
    (t
     (methods . ((exact . "exact") (prefix . "prefix"))))))

(defconst ndict-process-coding-system
  (cond
   ((coding-system-p 'utf-8) 'utf-8)
   (t 'iso-8859-1)))

;;;
;:: types
;;;

;; ndict agent:
;;
;;   (ndict SERVER)
;;
;; SERVER  - host name of DICT server
;;
;; [option]
;; :service - same as SERVICE above
;; :port    - same as PORT above
;; :coding  - same as `ndict-process-coding-system'
;; :auth    - cons of username and authentication-string
;; :method-table - table to transfer a search method from Lookup internal
;;                 to DICT server defined
;; 
;; [property]
;; ndict-process - DICT connection related with agent

(defalias 'ndict-agent-server 'lookup-agent-location)

(defun ndict-agent-service (agent)
  (or (lookup-agent-option agent ':port)
      (lookup-agent-option agent ':service)
      "dict"))

(defun ndict-agent-coding (agent)
  (or (lookup-agent-option agent ':coding)
      ndict-process-coding-system))

(defun ndict-agent-auth (agent)
  (lookup-agent-option agent ':auth))

(defun ndict-agent-method-table (agent)
  (lookup-agent-option agent ':method-table))

(put 'ndict ':arranges '(lookup-arrange-default-headings))
(put 'ndict ':adjusts '(lookup-adjust-goto-min))

;; ndict dictionary:
;;
;; CODE  - same as NAME below
;; NAME  - given by server `SHOW DB' command
;; TITLE - given by server `SHOW DB' command

(defun ndict-make-dictionary (name title)
  (lookup-new-dictionary ndict-current-agent name name title))

;; ndict entry:
;;
;; CODE    - returned value of `MATCH' command
;; HEADING - given by server `MATCH' command

(defsubst ndict-make-entry (code heading)
  (lookup-make-entry ndict-current-dictionary code heading))

;;;
;:: macros
;;;

(put 'ndict-with-agent 'lisp-indent-function 1)
(defmacro ndict-with-agent (agent &rest body)
  `(let ((ndict-current-agent ,agent)
	 (ndict-current-process (ndict-agent-process ,agent)))
     ,@body))

(put 'ndict-with-dictionary 'lisp-indent-function 1)
(defmacro ndict-with-dictionary (dictionary &rest body)
  `(ndict-with-agent (lookup-dictionary-agent ,dictionary)
     (let ((ndict-current-dictionary ,dictionary))
       ,@body)))

(defun ndict-agent-process (agent)
  (let ((process (lookup-agent-get-property agent 'ndict-process)))
    (unless (and process (eq (process-status process) 'open))
      (if process (lookup-process-kill process))
      (setq process (ndict-process-open (ndict-agent-server agent)
					(ndict-agent-service agent)))
      ;; initial setup
      (when (featurep 'mule)
	(let ((coding (ndict-agent-coding agent)))
	  (set-process-coding-system process coding coding)))
      (let ((ndict-current-process process)
	    (auth (ndict-agent-auth agent)))
	(ndict-process-require (concat "CLIENT ndict " ndict-version))
	(when auth
	  (ndict-process-require (concat "AUTH" (car auth) (cdr auth)))))
      (lookup-agent-put-property agent 'ndict-process process))
    process))

(defun ndict-agent-kill-process (agent)
  (let ((process (lookup-agent-get-property agent 'ndict-process)))
    (when process
      (if (eq (process-status process) 'open)
	  (process-send-string process "QUIT\n"))
      (lookup-process-kill process))))

(put 'ndict-cache-try-agent 'lisp-indent-function 2)
(defmacro ndict-cache-try-agent (agent key body &optional stamp)
  `(lookup-cache-try
    'ndict (concat (ndict-agent-server ,agent) ":" service) nil ,key
    (ndict-with-agent ,agent ,body)
    ,stamp))


;;;
;:: Interface functions
;;;

(put 'ndict 'setup 'ndict-setup)
(defun ndict-setup (agent)
    (let ((service (ndict-agent-service agent))
	  cache-location)
      (when (numberp service)
	(setq service (number-to-string service)))
      ;; Get server information.
      (let* ((string (ndict-cache-try-agent agent 'server-name 
		       (ndict-process-require "SHOW SERVER"
			 (lambda (process)
			   (or (and (re-search-forward
				     "\\`114[^\n]+\n\\([^\n]+\\)" nil t)
				    (match-string 1)))))))
	     (table (lookup-assq-ref
		     ndict-system-info-alist
		     (cond
		      ((string-match "^dictd " string) 'dictd)
		      (t t))))
	     (methods (lookup-assq-ref table 'methods)))
	;; Set methods and method-table
	(lookup-agent-set-default agent ':methods (mapcar 'car methods))
	(lookup-agent-set-default agent ':method-table methods))
      ;; get dictionary list
      (mapcar (lambda (dict)
		(lookup-new-dictionary
		 agent (car dict) (car dict) (cdr dict)))
	      (ndict-cache-try-agent agent 'dicts
		(ndict-process-require "SHOW DB"
		  (lambda (process)
		    (when (re-search-forward "^110 [^\n]+\n" nil t)
		      (let (result)
			(narrow-to-region (match-end 0)
					  (re-search-forward "^\\.$"))
			(while (re-search-backward
				"^\\([^ ]+\\) \\(.*\\)" nil t)
			  (setq result (cons (cons (match-string 1)
						   (read (match-string 2)))
					     result)))
			result))))))))

(put 'ndict 'clear 'ndict-clear)
(defun ndict-clear (agent)
  (ndict-agent-kill-process agent))

(put 'ndict 'search 'ndict-dictionary-search)
(defun ndict-dictionary-search (dictionary query)
  (ndict-with-dictionary dictionary
    (let* ((method (lookup-query-method query))
	   (string (if (eq method 'wild)
		       (lookup-query-to-regexp query)
		     (lookup-query-string query)))
	   (db (lookup-dictionary-code dictionary))
	   (table (ndict-agent-method-table ndict-current-agent))
	   (strategy (lookup-assq-ref table method))
	   (ndict-match-exact (if (eq method 'exact) (concat "^" string "$"))))
      (ndict-process-require (format "MATCH %s %s '%s'" db strategy string)
	(lambda (process)
	  (when (looking-at "152")
	    (forward-line)
	    (narrow-to-region (point) (re-search-forward "^\\.$"))
	    (let ((case-fold-search t) code heading entries)
	      (while (re-search-backward "^[^ ]+ \\(.*\\)" nil t)
		(setq code (match-string 1) heading (read code))
		(if (or (not ndict-match-exact)
			(string-match ndict-match-exact heading))
		    (setq entries (cons (ndict-make-entry code heading)
					entries))))
	      entries)))))))

(put 'ndict 'content 'ndict-dictionary-content)
(defun ndict-dictionary-content (dictionary entry)
  (ndict-with-dictionary dictionary
    (let ((db (lookup-dictionary-code dictionary))
	  (word (lookup-entry-code entry)))
      (ndict-process-require (format "DEFINE %s %s" db word)
	(lambda (process)
	  (when (looking-at "150")
	    (forward-line 2)
	    (buffer-substring (point) (progn (re-search-forward "^\\.$")
					     (match-beginning 0)))))))))


;;;
;:: ndict process
;;;

(defun ndict-process-open (server service)
  (lookup-proceeding-message (format "connecting to %s..." server))
  (let* ((buffer (lookup-open-process-buffer " *ndict*"))
	 (process (open-network-stream "ndict" buffer server service)))
    (accept-process-output process)
    (process-kill-without-query process)
    process))

(put 'ndict-process-require 'lisp-indent-function 1)
(defun ndict-process-require (command &optional filter)
  (lookup-process-require ndict-current-process (concat command "\n")
			  "^[245][0-8][0-9] .*\n" filter))

(provide 'ndict)

;;; ndict.el ends here
