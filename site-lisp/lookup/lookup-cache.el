;;; lookup-cache.el --- lookup cache management.
;; Copyright (C) 2010  Kazuhiro Ito <kzhr@d1.dion.ne.jp>

;; Author: Kazuhiro Ito <kzhr@d1.dion.ne.jp>
;; Version: $Id: lookup-cache.el,v 1.1.2.9 2012-09-14 00:43:25 kazuhiro Exp $

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

;; Customizable variables.
(defcustom lookup-cache-file-name
  (concat "~" init-file-user "/.lookup-cache")
  "File name for Lookup cache.  When nil file is not used."
  :type '(choice file
		 (const nil))
  :group 'lookup-setup-variables)

(defcustom lookup-cache-file-coding-system
  (or (and (coding-system-p 'utf-8-emacs-unix)
	   'utf-8-emacs-unix)
      'emacs-mule)
  "Coding system for Lookup cache file."
  :type 'coding-system
  :group 'lookup-setup-variables)

(defcustom lookup-enable-cache
  t
  "Whether enable Lookup cache system.  Storing and saving cache data are always going on even if value is nil."
  :type 'boolean
  :group 'lookup-setup-variables)

;; Internal variables.
(defvar lookup-cache-cache nil
  "Lookup cache data")

(defvar lookup-cache-version 2)

;; Interface functinos.
(defun lookup-cache-get (class location dictionary key)
  "Check cache data of specified storage and key, then return a cons of cache stamp and cached value.  Return nil when not cached.  If `lookup-enable-cache' is nil, always return nil.
CLASS, LOCATION, DICTIONARY are combination of (symbol, string, string), (symbol, string, nil), (symbol, nil, nil), or (nil, nil, nil).  KEY is a symbol."
  (let* ((class-cache (cdr (assoc (symbol-name class) lookup-cache-cache)))
	 (location-cache (cdr (assoc location class-cache)))
	 (dictionary-cache (cdr (assoc dictionary location-cache)))
	 result)
    (cond
     ((null lookup-enable-cache)
      (setq result nil))
     (dictionary
      (setq result (assq key dictionary-cache)))
     (location
      (setq result (assq key location-cache)))
     (class
      (setq result (assq key class-cache)))
     (t
      (setq result (assq key lookup-cache-cache))))
    (cdr result)))

(defun lookup-cache-put (class location dictionary key value &optional stamp)
  "Store cache data in specified storage and key.
CLASS, LOCATION, DICTIONARY are combination of (symbol, string, string), (symbol, string, nil), (symbol, nil, nil), or (nil, nil, nil).  KEY is symbol."
  (let ((class (or (and class (symbolp class) (symbol-name class)) class))
	(value (cons key (cons stamp value)))
	class-cache location-cache dictionary-cache)
    (when (and class (null (setq class-cache
				 (assoc class lookup-cache-cache))))
      (setq lookup-cache-cache `((,class . nil) . ,lookup-cache-cache)
	    class-cache (assoc class lookup-cache-cache)))
    (when (and location (null (setq location-cache
				    (assoc location (cdr class-cache)))))
      (setcdr class-cache `((,location . nil) . ,(cdr class-cache)))
      (setq location-cache (assoc location (cdr class-cache))))
    (when (and dictionary (null (setq dictionary-cache
				      (assoc dictionary (cdr location-cache)))))
      (setcdr location-cache `((,dictionary . nil) . ,(cdr location-cache)))
      (setq dictionary-cache (assoc dictionary (cdr location-cache))))
    (cond
     (dictionary
      (setcdr dictionary-cache
	      (cons value (delq (assq key (cdr dictionary-cache))
				(cdr dictionary-cache)))))
     (location
      (setcdr location-cache
	      (cons value (delq (assq key (cdr location-cache))
				(cdr location-cache)))))
     (class
      (setcdr class-cache
	      (cons value (delq (assq key (cdr class-cache))
				(cdr class-cache)))))
     (t (setq lookup-cache-cache
 	      (cons value (delq (assq key lookup-cache-cache)
 				lookup-cache-cache))))))
  value)

(defun lookup-cache-clear (&optional class location dictionary key)
  "Clear Lookup cache data.  You can clear only specific storage by optional arguments."
  (interactive)
  (let ((class (or (and class (symbolp class) (symbol-name class)) class))
	class-cache location-cache dictionary-cache result)
    (unless key
      (cond
       (dictionary (setq key dictionary
			 dictionary nil))
       (location (setq key location
		       location nil))
       (class (setq key class
		    class nil))))
    (setq class-cache (assoc class lookup-cache-cache)
	  location-cache (assoc location (cdr class-cache))
	  dictionary-cache (assoc dictionary (cdr location-cache)))
    (unless (or (and dictionary (null dictionary-cache))
		(and location (null location-cache))
		(and class (null class-cache)))
      (cond
       (dictionary
	(setq result (delq (assoc key (cdr dictionary-cache))
			   (cdr dictionary-cache)))
	(if result (setcdr dictionary-cache result)
	  (lookup-cache-clear class location dictionary nil)))
       (location
	(setq result (delq (assoc key (cdr location-cache))
			   (cdr location-cache)))
	(if result (setcdr location-cache result)
	  (lookup-cache-clear class location nil nil)))
       (class
	(setq result (delq (assoc key (cdr class-cache))
			   (cdr class-cache)))
	(if result (setcdr class-cache result)
	  (lookup-cache-clear class nil nil nil)))
       (key (setq lookup-cache-cache (delq (assoc key lookup-cache-cache)
					   lookup-cache-cache)))
       (t (setq lookup-cache-cache nil))))))

(defun lookup-cache-save ()
  "Save Lookup cache data to file specified by `lookup-cache-file-name' unless it is nil."
  (interactive)
  (lookup-cache-put nil nil nil 'version lookup-cache-version)
  (when lookup-cache-file-name
    (let ((coding-system-for-write lookup-cache-file-coding-system)
	  (lookup-proceeding-message "Saving cache file"))
      (lookup-proceeding-message nil)
      (with-temp-file (expand-file-name lookup-cache-file-name)
	(insert (format ";; -*- mode: emacs-lisp; coding: %s -*-\n"
			lookup-cache-file-coding-system))
	(insert ";; This file is generated automatically by Lookup.\n\n")
	(prin1 lookup-cache-cache (current-buffer)))
      (lookup-proceeding-message t))))

(defun lookup-cache-load ()
  "Load Lookup cache data from file specified by `lookup-cache-file-name' unless it is nil."
  (when lookup-cache-file-name
    (let ((file-name (expand-file-name lookup-cache-file-name))
	  tmp)
      (when (file-readable-p file-name)
	(setq tmp (read (with-temp-buffer
			  (insert-file-contents file-name)
			  (buffer-string))))
	(cond
	 ((null (assq 'version tmp))
	  (message "lookup-cache: Cache file's version is too old, ignored"))
	 ((> (cddr (assq 'version tmp)) lookup-cache-version)
	  (message "lookup-cache: Cache file's version is too new, ignored"))
	 (t (setq lookup-cache-cache tmp)))))))

(defmacro lookup-cache-try (class location dictionary key form &optional stamp)
  "Try `lookup-cache-get' and return cached value if cached.  When not cached or `lookup-enable-cache' is nil, evaluate FORM and cache, return result."
  `(let ((result (lookup-cache-get ,class ,location ,dictionary ,key))
	 (stamp ,stamp))
     (if (and result
	      (equal stamp (car result)))
	 (cdr result)
       (lookup-cache-put ,class ,location ,dictionary ,key
			 ,form stamp))))

;;;

(provide 'lookup-cache)

;;; lookup-cache.el ends here
