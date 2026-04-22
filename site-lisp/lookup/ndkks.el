;;; ndkks.el --- Lookup KAKASI interface
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: ndkks.el,v 1.1.1.1.4.2 2010-04-02 12:44:23 kazuhiro Exp $

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
(require 'lookup-kanji)

(defconst ndkks-version "2.0")

;;;
;:: Customizable variables
;;;

(defgroup ndkks nil
  "Lookup KAKASI interface."
  :group 'lookup-agents)

(defcustom ndkks-dictionary-title "漢字かな辞典"
  "*ndkks 辞書のタイトル。"
  :type 'string
  :group 'ndkks)


;;;
;:: Internal variables
;;;

;;;
;:: types
;;;

;; ndkks agent:
;;
;;   (ndkks)

(put 'ndkks ':methods '(exact))

(put 'ndkks ':arranges
     '(lookup-arrange-default-headings
       lookup-arrange-fill-lines))

(put 'ndkks ':adjusts 
     '(lookup-adjust-goto-min))

;; ndkks dictionary:
;;
;; CODE  - none
;; NAME  - same as `ndkks-program-name'

;; ndkks entry:
;;
;; CODE    - input string
;; HEADING - same as CODE above


;;;
;:: Interface functions
;;;

(put 'ndkks 'setup 'ndkks-setup)
(defun ndkks-setup (agent)
  (unless (featurep 'mule)
    (error "ndkks requires `mule' feauture."))
  (list (lookup-new-dictionary agent nil (symbol-name lookup-kanji-scheme)
			       ndkks-dictionary-title)))

(put 'ndkks 'clear 'ndkks-clear)
(defun ndkks-clear (agent))

(put 'ndkks 'search 'ndkks-dictionary-search)
(defun ndkks-dictionary-search (dictionary query)
  (let ((string (lookup-query-string query)))
    (when (catch 'done
	    (mapc (lambda (ch)
		    (and (aref (char-category-set ch) ?C)
			 (aref (char-category-set ch) ?j)
			 (throw 'done t)))
		  string)
	    nil)
      ;; Return entry only when string contains Japanese Kanji character.
      (list (lookup-make-entry dictionary string string)))))

(put 'ndkks 'content 'ndkks-dictionary-content)
(defun ndkks-dictionary-content (dictionary entry)
  (let ((string (lookup-entry-code entry))
	(function (get 'lookup-kanji :content)))
    (funcall function string)))


;;;
;:: KAKASI process
;;;

(provide 'ndkks)

;;; ndkks.el ends here
