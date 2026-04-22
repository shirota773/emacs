;;; lookup-text.el --- normalizer and expander for search word
;; Copyright (C) 2009 Kazuhiro Ito

;; Author: Kazuhiro Ito <kzhr@d1.dion.ne.jp>
;; Version: $Id: lookup-text.el,v 1.1.2.8 2011-05-12 01:42:50 kazuhiro Exp $

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

;;; Commentary:

;;; Code:

(require 'lookup-text-table)

(defun lookup-text-charsets-or-coding-p (string charsets coding)
  (cond
   ((and (> emacs-major-version 22) charsets)
    (lookup-text-charsets-p string charsets))
   (coding
    (lookup-text-coding-p string coding))
   (t t)))

(defun lookup-text-charsets-p (string charsets)
  "Determines if all of chars in STRING belongs to any of CHARSETS list.
If CHARSETS if function, then result of applying the function to
the string will be returned.  If CHARSETS is null, returns t."
  (cond
   ((or (< emacs-major-version 23) (null charsets))
    t)
   ((functionp charsets)
    (funcall charsets string))
   (t
    (let ((charsets (or (and (listp charsets) charsets)
			(list charsets))))
      (catch 'done
	(mapc (lambda (char)
		(or (char-charset char charsets)
		    (throw 'done nil)))
	      string))))))

(defun lookup-text-coding-p (string coding)
  "Determines if all of chars in STRING belongs to CODING."
  (catch 'done
    (mapc (lambda (char)
	    (or (encode-coding-char char coding)
		(throw 'done nil)))
	  string)))

(defun lookup-text-any-charsets-or-coding-p (string charsets coding)
  (cond
   ((and (> emacs-major-version 22) charsets)
    (lookup-text-any-charsets-p string charsets))
   (coding
    (lookup-text-any-coding-p string coding))
   (t t)))

(defun lookup-text-any-charsets-p (string charsets)
  "Return nil if none of chars in STRING belongs to any of CHARSETS list.
If CHARSETS if function, then result of applying the function to
the string will be returned.  If CHARSETS is null, returns t."
  (cond
   ((or (< emacs-major-version 23) (null charsets))
    t)
   ((functionp charsets)
    (funcall charsets string))
   (t
    (let ((charsets (or (and (listp charsets) charsets)
			(list charsets))))
      (catch 'done
	(mapc (lambda (char)
		(and (char-charset char charsets)
		     (throw 'done t)))
	      string)
	nil)))))

(defun lookup-text-any-coding-p (string coding)
  "Return nil if none of chars in STRING belongs to CODING."
  (catch 'done
    (mapc (lambda (char)
	    (and (encode-coding-char char coding)
		 (throw 'done t)))
	  string)
    nil))

(defun lookup-text-replace-with-alternates (string alternates)
  ;; ALTERNATES is a list of cons of character and string.
  (apply 'string
	 (apply 'nconc
		(mapcar (lambda (char)
			  (let ((result (cdr (assq char alternates))))
			    (if result (string-to-list result)
			      (list char))))
			string))))

;; normalizer specifications
;; Receive string and return list of strings.
;; Optional arguments are available.

(defun lookup-normalizer-strip-chars (string chars)
  "Remove characters contained by string or list of characters CHARS from STRING."
  (when (stringp chars)
    (setq chars (string-to-list chars)))
  (let (result)
    (setq result (delq nil
		       (mapcar
			(lambda (char)
			  (unless (memq char chars) char))
			string)))
    (if result
	(list (apply 'string result))
      nil)))

(defun lookup-normalizer-japanese-new-to-old (string)
  "新字を旧字に変える。"
  (lookup-normalizer-replace-with-table string lookup-text-new-old-alist))

(defun lookup-normalizer-japanese-old-to-new (string)
  "旧字を新字に変える。"
  (lookup-normalizer-replace-with-table string lookup-text-old-new-alist))

(defun lookup-normalizer-strip-latin-alphabet-accent (string)
  "Strip accents of latin alphabet."
  (lookup-normalizer-replace-with-table
   string lookup-latin-alphabet-accent-alist))

(defun lookup-normalizer-replace-with-table (string table)
  ;; TABLE is a list of cons of characters (MULE 6 and later) or a
  ;; list of cons of utf-8 encoded unibyte strings (MULE 5 and
  ;; earlier).
  (list
   (cond
    ((string-lessp "6" mule-version)
     (apply 'string
	    (mapcar (lambda (char)
		      (or (cdr (assq char table)) char))
		    string)))
    ((coding-system-p 'utf-8-unix)
     (apply 'string
	    (mapcar
	     (lambda (char)
	       (let ((result (cdr (assoc (encode-coding-string
					  (char-to-string char) 'utf-8-unix)
					 table))))
		 (if result
		     (string-to-char
		      (decode-coding-string result 'utf-8-unix))
		   char)))
	     string)))
    (t string))))

(defun lookup-normalizer-wrapper (string function &rest rest)
  (list (apply function string rest)))

(provide 'lookup-text)
