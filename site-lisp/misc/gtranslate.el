;;; gtranslate.el --- Use google translate api to perform translations
;;; $Id: gtranslate.el,v 0.1 [2009-11-28 23:57] Bruno Tavernier $

;; Copyright (C) 2009 Free Software Foundation, Inc.

;; Author:        Bruno Tavernier <tavernier.bruno@gmail.com>
;; Maintainer:    Bruno Tavernier <tavernier.bruno@gmail.com>
;; Created:       2009-11-28
;; Last-Updated:  $Date: [2009-11-28 23:24] $
;; Revision:      $Revision: 0.1 $
;; Keywords:      words, translation, language
;; Compatibility: GNU Emacs 23.x

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary;
;;
;; Inspired by text-translator.el
;; This utility allows for translation via the google translation api.
;;
;; Note: Feel free to replace gtranslate-region-or-input in the example
;; below by any function of your choice that return a string.
;;
;;; Configuration;
;;
;; A configuration sample for your .emacs is as follows.
;;
;; ; Load the module
;; (require 'gtranslate)
;; 
;; ; Or use autoload instead
;; (autoload 'gtranslate-translate "gtranslate" nil t)
;; (autoload 'gtranslate-translate-auto "gtranslate" nil t)
;; 
;; ; Create a user function
;; ; (ex: English -> French)
;;
;; (defun my-en-fr ()
;;   (interactive)
;;   (gtranslate-translate (gtranslate-region-or-input) "en" "fr"))
;;
;; Alternatively you can define one function that choose automatically
;; in which direction the translation ought to be done.
;; Works for a Roman alphabet / Non-Roman alphabet pair of language
;; (ex: French <-> Japanese)
;;
;; (defun my-fr-ja ()
;;   (interactive)
;;   (gtranslate-translate-auto (gtranslate-region-or-input) "fr" "ja"))
;;
;; ; Assign shortcut to the user function
;; (global-set-key "\M-1" 'my-fr-ja)
;; (global-set-key "\M-2" 'my-en-fr)
(defun my-en-ja ()
  (interactive)
  (gtranslate-translate-auto (gtranslate-test) "en" "ja"))

(defun gtranslate-test ()
  "Select region if active or ask user input for translation."
  (read-string "String to translate: "))

;;; Code:

; Constants
(defconst gtranslate-version "0.1"
  "version number of this version of gtranslate.")

; Variables
(defcustom gtranslate-buffer "*translated*"
  "Buffer name that displays translation result.")

(defvar gtranslate-service "ajax.googleapis.com"
  "Service to use for translation.")

(defvar gtranslate-service-port 80
  "Port number of the service used for translation.")

(defvar gtranslate-user-agent "Python-urllib/2.6"
  "User agent displayed.")

; Core functions
(defun gtranslate-make-url (text fl tl)
  "Generate the url to send to the translation service."
  (concat
   "v=1.0"
   (format "&q=%s" (url-hexify-string (encode-coding-string text 'utf-8)))
   (format "&langpair=%s" (url-hexify-string (encode-coding-string (format "%s|%s" fl tl) 'utf-8)))
   ))

(defun gtranslate-filter (proc str)
  "Remove the cruft from the service answer."
  (string-match "translatedText\":\"\\(\.*\\)\"\}" str)
  (with-current-buffer (process-buffer proc)
    (insert (match-string 1 str))))

(defun gtranslate-translate (text fl tl)
  "Translate 'text' from language 'fl' to language 'tl'"
  (get-buffer-create gtranslate-buffer)
  (let ((proc (open-network-stream "translation" gtranslate-buffer gtranslate-service gtranslate-service-port))
	(str (gtranslate-make-url text fl tl))
	(window (get-buffer-window gtranslate-buffer))
	(original-split-width-threshold split-width-threshold))
    (set-process-filter proc 'gtranslate-filter)
    (process-send-string proc (concat
			       "GET /ajax/services/language/translate?" str " HTTP/1.1\r\n"
			       "Accept-Encoding: identity\r\n"
			       "Host: " gtranslate-service "\r\n"
			       "Connection: Keep-Alive\r\n"
			       "Keep-Alive: 300\r\n"
			       "User-Agent: " gtranslate-user-agent "\r\n" "\r\n"
			       ))
    (message "Translating...")
    (save-selected-window
      (setq split-width-threshold nil) ; Split window horizontally
      (pop-to-buffer gtranslate-buffer)
      (setq split-width-threshold original-split-width-threshold) ; Restore setting
      (erase-buffer)
      (shrink-window-if-larger-than-buffer window)) ; Adjust window size
    ))

(defun gtranslate-translate-auto (text roman nonroman)
  "Choose automatically which translation to perform between one Roman alphabet and a non-roman alphabet language.
   Alphabet ration is 40%."
  (if (> (/ (* (length (replace-regexp "[^A-Za-z]+" "" text)) 100) (length text)) 40)
      (gtranslate-translate text roman nonroman)
      (gtranslate-translate text nonroman roman)))

(defun gtranslate-region-or-input ()
  "Select region if active or ask user input for translation."
  (if (not mark-active)
      (read-string "String to translate: ")
    (buffer-substring (region-beginning) (region-end))))

(provide 'gtranslate)

;;; gtranslate.el ends here.
