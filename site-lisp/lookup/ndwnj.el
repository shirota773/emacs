;;; ndwnj.el --- search inferface for Japanese WordNet
;; Copyright (C) 2009  Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; Author: Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; ndwnj.el is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; ndwnj.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with Lookup; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Commentary:

;;; Code:

(defconst ndwnj-version "0.1")

;;;
;;; Customizable variables
;;;

(defgroup ndwnj nil
  "Lookup ndwnj interface."
  :group 'lookup-agents)

(defcustom ndwnj-program-name "sqlite3"
  "*Program name of sqlite3."
  :type 'string
  :group 'ndeb)

(defcustom ndwnj-program-arguments '("-interactive")
  "*A list of arguments for sqlite3."
  :type '(repeat (string :tag "option"))
  :group 'ndwnj)

(defcustom ndwnj-prompt-string "sqlite> "
  "*Prompt string of sqlite3."
  :type 'string
  :group 'ndeb)

(defcustom ndwnj-process-coding-system
  'utf-8
  "*Coding system for sqlite3 process."
  :type 'symbol
  :group 'ndwnj)


;;;
;;; Internal variables
;;;


;;;
;:: types
;;;

(defun ndwnj-agent-coding (agent)
  (or (lookup-agent-option agent ':coding)
      ndwnj-process-coding-system))

(put 'ndwnj ':methods '(exact prefix suffix substring wild))
(put 'ndwnj ':reference-pattern '("<\\([0-9]+-[a-z]+\\):\\([^>]+\\)>" 2 2 1))
(put 'ndwnj ':arranges
     '(lookup-arrange-default-headings
       ndwnj-arrange-headings
       lookup-arrange-references
       lookup-arrange-fill-lines))
(put 'ndwnj ':adjusts
     '(lookup-adjust-check-references
       lookup-adjust-goto-min))
(put 'ndwnj ':normalizers
     '((lookup-normalizer-wrapper downcase)
       ndwnj-normalizer-space-to-underscore))


;;;
;:: Interface functions
;;;

(put 'ndwnj 'setup 'ndwnj-setup)
(defun ndwnj-setup (agent)
  (ndwnj-start-process agent)
  (list (lookup-new-dictionary agent "wnj" "wnj" "日本語WordNet")))

(put 'ndwnj 'clear 'ndwnj-clear)
(defun ndwnj-clear (agent)
  (let ((process (lookup-agent-get-property agent 'process)))
    (when process
      (when (eq (process-status process) 'run)
	(process-send-string process ".exit\n"))
      (lookup-process-kill process))))

(put 'ndwnj 'search 'ndwnj-dictionary-search)
(defun ndwnj-dictionary-search (dictionary query)
  (let ((method (lookup-query-method query))
	(string (ndwnj-escape-string (lookup-query-string query)))
	cmd)
    (cond
     ((eq method 'exact)
      (setq cmd (concat "= '" string)))
     ((eq method 'prefix)
      (setq cmd (concat "GLOB '" string "*")))
     ((eq method 'suffix)
      (setq cmd (concat "GLOB '*" string)))
     ((eq method 'substring)
      (setq cmd (concat "GLOB '*" string "*")))
     ((eq method 'wild)
      (setq cmd (concat "GLOB '" string))))
    (ndwnj-require
	(lookup-dictionary-agent dictionary)
      (concat "SELECT synset, name, pos_def.def "
	      "FROM synset, pos_def ON synset.pos = pos_def.pos "
	      "WHERE synset IN "
	      "(SELECT synset FROM sense WHERE wordid IN "
	      "(SELECT wordid FROM word WHERE lemma "
	      cmd
	      "')) AND pos_def.lang = 'jpn' "
	      (when (and (numberp lookup-max-hits)
			 (> lookup-max-hits 0))
		(concat "LIMIT " (number-to-string lookup-max-hits)))
	      ";")
      (lambda (process)
	(let (code heading entries)
	  (while (re-search-forward "^\\(.+\\)|\\(.+\\)|\\(.+\\)$" nil t)
	    (setq code (match-string 1)
		  heading (concat (match-string 2)
				  " (" (match-string 3) ")"))
	    (setq entries
		  (cons (lookup-make-entry dictionary code heading) entries)))
	  (nreverse entries))))))

(put 'ndwnj 'content 'ndwnj-dictionary-content)
(defun ndwnj-dictionary-content (dictionary entry)
  (let ((agent (lookup-dictionary-agent dictionary))
	(code (lookup-entry-code entry))
	heading def word link)
    (setq heading (concat (lookup-entry-code entry)
			  " "
			  (lookup-entry-heading entry))
	  def (ndwnj-get-definition agent code)
	  word (ndwnj-get-words agent code)
	  link (ndwnj-get-links agent code))
    (concat heading "\n" def "\n" word "\n" link "\n")))



;;;
;;; Arrange functions
;;;

(defun ndwnj-arrange-headings (string)
  (while (re-search-forward
	  "^\\( *\\)\\(\\(\\[[^][]+\\]\\)\\|\\([a-zA-Z]+:\\)\\)" nil t)
    (cond
     ((match-beginning 3)
      (lookup-make-region-heading (match-beginning 3) (match-end 3) 2))
     ((match-beginning 4)
      (lookup-make-region-heading (match-beginning 4) (match-end 4) 3)))))



;;;
;;; Normalizers
;;;

(defun ndwnj-normalizer-space-to-underscore (string)
  (list (apply 'string (mapcar (lambda (elt) (if (eq elt ? ) ?_ elt))
			       string))))


;;;
;;; Internal functions
;;;

(defun ndwnj-escape-string (string)
  (apply 'concat (mapcar (lambda (elt) (if (eq elt ?') "''" (list elt)))
			 string)))

(defun ndwnj-get-words (agent code)
  (ndwnj-require agent
    (concat "SELECT lemma, lang FROM word WHERE wordid IN "
	    "(SELECT wordid FROM sense WHERE synset = '"
	    (ndwnj-escape-string code)
	    "') ORDER BY lang DESC;")
    (lambda (process)
      (let (lemma lang elt results result)
	(while (re-search-forward "^\\(.+\\)|\\(.+\\)$" nil t)
	  (setq lemma (match-string 1)
		lang (match-string 2))
	  (setq elt (concat (lookup-assoc-ref results lang) ", " lemma))
	  (setq results (lookup-assoc-set results lang elt)))
	(while results
	  (setq elt (car results))
	  (setq result (concat result "  " (car elt) ": "
			       (substring (cdr elt) 2) "\n"))
	  (setq results (cdr results)))
	result))))

(defun ndwnj-get-definition (agent code)
  (ndwnj-require agent
    (concat "SELECT lang, def FROM synset_def WHERE synset = '"
	    (ndwnj-escape-string code)
	    "' ORDER BY lang;")
    (lambda (process)
      (while (re-search-forward "^\\(.+\\)|\\(.+\\)$" nil t)
	(replace-match
	 (concat (match-string 1) ": " (match-string 2)) t t))
      (buffer-string))))

(defun ndwnj-get-links (agent code)
  (ndwnj-require agent
    (concat "SELECT synlink.synset2, synset.name, link_def.def "
	    "FROM synlink, synset ON synlink.synset2 = synset.synset "
	    ", link_def ON synlink.link = link_def.link "
	    "WHERE synlink.synset1 = '"
	    (ndwnj-escape-string code)
	    "' ORDER BY synlink.link DESC, synset.name;")
    (lambda (process)
      (let (target name syn elt results result)
	(while (re-search-forward "^\\(.+\\)|\\(.+\\)|\\(.+\\)$" nil t)
	  (setq target (match-string 1)
		name (match-string 2)
		syn (match-string 3))
	  (setq elt (concat 
		     (lookup-assoc-ref results syn)
		     " <" target ":" name ">"))
	  (setq results (lookup-assoc-set results syn elt)))
	(while results
	  (setq elt (car results))
	  (setq result (concat result " [" (car elt) "]" (cdr elt) "\n"))
	  (setq results (cdr results)))
	result))))

(defun ndwnj-start-process (agent)
  "Start sqlite3 process if it does not start."
  (let ((process (lookup-agent-get-property agent 'process)))
    (unless (and (processp process)
		 (eq (process-status process) 'run))
      (let* ((file (expand-file-name (lookup-agent-location agent)))
	     (buffer (or (lookup-open-process-buffer
			  (concat " *ndwnj+" file "*"))
			 (lookup-temp-buffer)))
	     (coding (ndwnj-agent-coding agent)))
	(setq process (apply 'start-process "ndwnj" buffer
			     ndwnj-program-name
			     (append ndwnj-program-arguments (list file)))
	      ndwnj-status nil
	      ndwnj-vars nil)
	(set-process-coding-system process coding coding)
	(process-kill-without-query process)
	(with-current-buffer buffer
	  (catch 'started
	    (while (accept-process-output process 10)
	      (save-excursion
		(goto-char (point-min))
		(when (search-forward ndwnj-prompt-string nil t)
		  (throw 'started t))))
	    (error "Failed start process")))
	(unless lookup-debug-mode
	  (set-process-buffer process nil)
	  (kill-buffer buffer)))
      (lookup-agent-put-property agent 'process process))))

(put 'ndwnj-require 'lisp-indent-function 1)
(defun ndwnj-require (agent string &optional filter)
  "Send string to sqlite3 process and return output. Cf. `lookup-process-require'"
  (let ((lookup-process-output-separator-lines 0))
    (lookup-process-require (lookup-agent-get-property agent 'process)
			    (concat string "\n")
			    (concat "^" ndwnj-prompt-string) filter)))
  
(provide 'ndwnj)

;;; ndwnj.el ends here
