;;; evi.el --- Emacs version integrator
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: evi.el,v 1.1.1.1.4.2 2011-06-08 12:57:11 kazuhiro Exp $

;; This file is part of `evi'.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Code:

(when (or (string< emacs-version "20") (featurep 'xemacs))
  (defvar evi-orig-read-string (symbol-function 'read-string))
  (defun read-string (prompt &optional initial history default inherit)
    (let ((input (funcall evi-orig-read-string prompt initial)))
      (if (and default (equal input ""))
	  default
	input)))

  (defvar evi-orig-completing-read (symbol-function 'completing-read))
  (defun completing-read (prompt table &optional predicate require-match
				 initial histry default inherit)
    (let ((input (funcall evi-orig-completing-read prompt table predicate
			  require-match initial histry)))
      (if (and default (equal input ""))
	  default
	input)))

  (when (string< emacs-version "20.3")
    (defvar evi-orig-string-to-number (symbol-function 'string-to-number))
    (defun string-to-number (string &optional base)
      (if (not base)
	  (funcall evi-orig-string-to-number string)
	(let ((len (length string))
	      (number 0) (i 0) c)
	  (if (or (< base 2) (< 16 base))
	      (error "Args out of range: %d" base)
	    (while (< i len)
	      (setq number (* number base))
	      (setq c (aref string i))
	      (cond
	       ((and (<= ?0 c) (<= c ?9)) (setq number (+ number (- c ?0))))
	       ((and (<= ?a c) (<= c ?f)) (setq number (+ number (- c ?a -10))))
	       ((and (<= ?A c) (<= c ?F)) (setq number (+ number (- c ?A -10))))
	       (t (setq i len)))
	      (setq i (1+ i)))
	    number)))))
  )

(provide 'evi)

;;; evi.el ends here
