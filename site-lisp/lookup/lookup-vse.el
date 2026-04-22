;;; lookup-vse.el --- Lookup Virtual Search Engine
;; Copyright (C) 1999 Lookup Development Team <lookup@ring.gr.jp>

;; Author: Keisuke Nishida <kei@psn.net>
;; Version: $Id: lookup-vse.el,v 1.2.4.20 2011-10-14 23:45:32 kazuhiro Exp $

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
(require 'lookup-text)

;;;;;;;;;;;;;;;;;;;;
;: Search Query
;;;;;;;;;;;;;;;;;;;;

(defun lookup-vse-search-query (dictionary query)
  ;; DICTIONARY から QUERY を検索する。
  ;; 変数 `lookup-force-update' が non-nil の場合、キャッシュを無視する。
  ;; 実際に検索を行なうのは `lookup-vse-search-query-internal'.
  (let ((expanders (lookup-dictionary-option dictionary ':expanders t))
	(string (lookup-query-string query))
	(method (lookup-query-method query))
	strings entries)
    (when (eq method 'default)
      (setq method (lookup-dictionary-default-method dictionary)
	    query (lookup-make-query method string)))
    (setq entries (lookup-vse-search-query-internal dictionary query))

    (when (and (null entries)
	       (memq method (or (lookup-dictionary-option
				 dictionary ':expansion-methods t)
				lookup-query-expansion-methods)))
      ;; Emulate :hiragana and :stemmer options.
      (mapc (lambda (fn) (when (and (funcall (car fn) dictionary)
				    (null (member (cdr fn) expanders)))
			   (setq expanders (cons (cdr fn) expanders))))
	    `((lookup-dictionary-hiragana
	       . (lookup-kanji-get-readings . lookup-kanji-filter))
	      (lookup-dictionary-stemmer
	       . (,(lookup-dictionary-stemmer dictionary) . nil))))
      ;; Run expanders.
      (while expanders
	(setq entries
	      (lookup-vse-run-expander dictionary query (car expanders))
	      expanders (unless entries (cdr expanders)))))
    (unless (eq entries 'no-exists)
      entries)))

(defvar lookup-normalizers-cache nil)

(defsubst lookup-normalizers-cache-get (string normalizer)
  (lookup-assoc-ref (lookup-assoc-ref lookup-normalizers-cache string)
		    normalizer))

(defsubst lookup-normalizers-cache-put (string normalizer value)
  (let* ((elt (assoc string lookup-normalizers-cache))
	 (elt2 (assoc normalizer (cdr elt))))
    (if elt
	(setcdr elt (delq nil (cons (cons normalizer value)
				    (delq elt2 (cdr elt)))))
      (add-to-list 'lookup-normalizers-cache
		   (cons string (list (cons normalizer value)))))))

(defun lookup-normalizers-cache-clear ()
  (setq lookup-normalizers-cache nil))

(defun lookup-vse-run-normalizers (string normalizers)
  (let ((strings (if (stringp string) (list string)
		   string)))
    (while (and normalizers strings)
      (let ((normalizer (car normalizers)))
	(setq strings
	      (lookup-nunique
	       (apply 'nconc (mapcar
			      (lambda (elt)
				(lookup-vse-call-normalizer elt normalizer))
			      strings))))
	(setq normalizers (cdr normalizers))))
    (delq nil strings)))

(defun lookup-vse-call-normalizer (string normalizer)
  (when (and (stringp string) normalizer)
    (let ((result (and (null lookup-force-update)
		       (lookup-normalizers-cache-get string normalizer))))
      (if result
	  (if (eq result 0) (setq result nil))
	(setq result 
	      (cond
	       ((functionp normalizer)
		(funcall normalizer string))
	       ((and (listp normalizer)
		     (functionp (car normalizer)))
		(apply (car normalizer) string (cdr normalizer)))
	       (t (list string))))
	(lookup-normalizers-cache-put string normalizer (if result result 0)))
      result)))

(defun lookup-vse-run-expander (dictionary query expander)
  (let ((string (lookup-query-string query))
	(method (lookup-query-method query))
	(filter (cdr expander))
	(expanders (car expander))
	entries strings tmp)
    (unless (listp expanders) (setq expanders (list expanders)))
    ;; Expand word.
    (setq strings (lookup-vse-run-normalizers string expanders))
    ;; Search with expanded words.
    (setq entries
    	  (lookup-nunique
    	   (apply 'nconc
		  (mapcar (lambda (elt)
			    (setq tmp
				  (lookup-vse-search-query-internal
				   dictionary (lookup-make-query method elt)))
			    (if filter (funcall filter string tmp)
			      tmp))
			  strings))
    	   nil t))
    ;; Add prefix to entries.
    (let ((prefix (format lookup-expanded-heading-prefix string)))
      (mapcar (lambda (elt)
		(lookup-make-entry dictionary (lookup-entry-code elt) 
				   (concat prefix (lookup-entry-heading elt))))
    	      entries))))

(defvar lookup-entries-cache nil)

(defun lookup-entries-cache-get (dictionary query)
  (lookup-multi-get 'lookup-entries-cache dictionary
 		    (lookup-query-method query)
 		    (lookup-intern-string (lookup-query-string query))))
  
(defun lookup-entries-cache-put (dictionary query entries)
  (lookup-multi-put 'lookup-entries-cache dictionary
   		    (lookup-query-method query)
   		    (lookup-intern-string (lookup-query-string query))
   		    entries))

(defun lookup-entries-cache-clear ()
  (setq lookup-entries-cache nil))

(defvar lookup-vse-cache-no-exists 'no-exists)

(defun lookup-vse-search-query-internal (dictionary query)
  (let ((charsets (lookup-dictionary-option dictionary ':charsets t))
	(coding (lookup-dictionary-option dictionary ':coding t))
	(alternates (lookup-dictionary-option dictionary ':alternates t))
	(normalizers (lookup-dictionary-option dictionary ':normalizers t))
	(method (lookup-query-method query))
	(string (lookup-query-string query))
	strings tmp)
    (when alternates
      (setq normalizers
	    (delq nil
		  (nreverse
		   (cons `(lookup-normalizer-wrapper
			   lookup-text-replace-with-alternates ,alternates)
			 (reverse normalizers))))))
    (setq strings (lookup-vse-run-normalizers string normalizers))
    (lookup-nunique
     (apply 'nconc
	    (delq lookup-vse-cache-no-exists
		  (mapcar
		   (lambda (string)
		     (let ((query (lookup-make-query method string)))
		       (or (and (null lookup-force-update)
				(lookup-entries-cache-get dictionary query))
			   (when (lookup-text-charsets-or-coding-p
				  string charsets coding)
			     (setq tmp (lookup-dictionary-command
					dictionary 'search query))
			     (lookup-foreach 'lookup-arrange-heading tmp)
			     (lookup-entries-cache-put
			      dictionary query
			      (or tmp lookup-vse-cache-no-exists))
			     tmp))))
		   strings))))))

;;;;;;;;;;;;;;;;;;;;
;: Insert content
;;;;;;;;;;;;;;;;;;;;

(defun lookup-vse-insert-content (entry)
  ;; ENTRY の内容をバッファに挿入し、整形処理を行なう。
  ;; 変数 `lookup-force-update' が non-nil の場合、キャッシュを無視する。
  (let ((cache (lookup-contents-cache-get entry lookup-enable-format)))
    (if (or (not cache) lookup-force-update)
	;; insert content
	(let ((lookup-proceeding-message
	       (format "Inserting `%s'" (lookup-entry-heading entry)))
	      (dictionary (lookup-entry-dictionary entry)))
	  (lookup-proceeding-message nil)
	  (insert (lookup-dictionary-command dictionary 'content entry))
	  (if lookup-enable-format (lookup-arrange-content entry))
	  (lookup-contents-cache-put entry lookup-enable-format
				     (buffer-string))
	  (if lookup-enable-format (lookup-adjust-content entry))
	  (lookup-proceeding-message t))
      ;; use cache
      (insert cache)
      (if lookup-enable-format (lookup-adjust-content entry)))))

(defvar lookup-contents-cache nil)

(defun lookup-contents-cache-put (entry formatted content)
  (lookup-multi-put
   'lookup-contents-cache (lookup-entry-dictionary entry) formatted
   (lookup-assoc-set (lookup-multi-get 'lookup-contents-cache
				       (lookup-entry-dictionary entry)
				       formatted)
		     (lookup-entry-code entry) content)))

(defun lookup-contents-cache-get (entry formatted)
  (lookup-assoc-ref (lookup-multi-get 'lookup-contents-cache
				      (lookup-entry-dictionary entry)
				      formatted)
		    (lookup-entry-code entry)))

(defun lookup-contents-cache-clear ()
  (setq lookup-contents-cache nil))

;;;
;:: Interface functions
;;;

(defun lookup-arrange-heading (entry)
  (let* ((dictionary (lookup-entry-dictionary entry))
	 (funcs (lookup-dictionary-headings dictionary)))
    (when funcs
      (with-temp-buffer
	(insert (lookup-entry-heading entry))
	(lookup-foreach (lambda (func)
			  (goto-char (point-min))
			  (funcall func entry))
			funcs)
	(lookup-entry-set-heading entry (buffer-string))))))

(defun lookup-arrange-content (entry)
  (let* ((dictionary (lookup-entry-dictionary entry))
	 (arranges (lookup-dictionary-option dictionary ':arranges t)))
    (lookup-format entry arranges "formatting")))

(defun lookup-adjust-content (entry)
  (let* ((dictionary (lookup-entry-dictionary entry))
	 (adjusts (lookup-dictionary-option dictionary ':adjusts t))
	 (arranges (lookup-dictionary-option dictionary ':arranges t))
	 (work (concat "formatting" (make-string (length arranges) ?.))))
    (lookup-format entry adjusts work)))

;;;
;:: Internal functions
;;;

(defun lookup-format (entry functions work)
  (let ((n 1))
    (lookup-foreach (lambda (func)
		      (lookup-proceeding-message
		       (concat work (make-string (setq n (1+ n)) ?.)))
		      (widen)
		      (goto-char (point-min))
		      (funcall func entry))
		    functions)))

(defun lookup-heading-face (level)
  (or (nth (1- level) '(lookup-heading-1-face
			lookup-heading-2-face lookup-heading-3-face
			lookup-heading-4-face lookup-heading-5-face))
      'lookup-heading-low-face))

;;;
;:: Arrange functions
;;;

(defsubst lookup-make-region-heading (start end level)
  (add-text-properties start end (list 'face (lookup-heading-face level)
				       'lookup-heading level)))

(defun lookup-arrange-default-headings (entry)
  (lookup-make-region-heading
   (point)
   (next-single-property-change (point-min) 'face nil
				(line-end-position)) 1))

(defun lookup-arrange-references (entry)
  (let* ((case-fold-search nil)
	 (dictionary (lookup-entry-dictionary entry))
	 (pattern (lookup-dictionary-option dictionary ':reference-pattern t))
	 (e-regexp (lookup-dictionary-option dictionary ':reference-regexp t))
	 (regexp (car pattern)) (region-field (nth 1 pattern))
	 (heading-field (nth 2 pattern)) (code-field (nth 3 pattern))
	 region heading code reference)
    (while (if e-regexp
	       (catch ':done
		 (while (and (re-search-forward (car e-regexp) nil t)
			     (goto-char (match-beginning 0))
			     (save-excursion
			       (re-search-forward (cdr e-regexp) nil t)))
		   (when (re-search-forward regexp (match-end 0) 1)
		     (throw ':done t))))
	     (re-search-forward regexp nil t))
      (save-match-data
	(when (equal "" (setq region (if (integerp region-field)
					 (match-string region-field)
				       (eval region-field))))
	  (setq region lookup-reference-default-caption))
	(when (equal "" (setq heading (if (integerp heading-field)
					  (match-string heading-field)
					(eval heading-field))))
	  (setq heading lookup-reference-default-caption))
	(if (integerp code-field)
	    (setq code (match-string code-field)
		  reference (lookup-make-entry dictionary code heading))
	  (setq reference (lookup-make-reference dictionary heading heading))
	  (lookup-reference-make-dynamic reference code-field)))
      (replace-match region t t)
      (lookup-set-link (match-beginning 0) (point) reference)
      (lookup-arrange-heading reference))))

(defun lookup-dynamic-code-search (reference)
  "リファレンスのコードをダイナミックに検索する。"
  (let ((dictionary (lookup-entry-dictionary reference))
	(query (lookup-make-query 'exact (lookup-entry-code reference))))
    (lookup-vse-search-query dictionary query)))

(defun lookup-arrange-gaijis (entry)
  (let* ((case-fold-search t)
	 (dictionary (lookup-entry-dictionary entry))
	 (regexp (lookup-dictionary-option dictionary ':gaiji-regexp t))
	 start end gaiji)
    (while (re-search-forward regexp nil t)
      (setq start (match-beginning 0) end (match-end 0))
      (when (and (null (get-text-property start 'display))
		 (setq gaiji (lookup-vse-get-gaiji
			      dictionary (match-string 1))))
	(let ((props (text-properties-at start)))
	  (delete-region start end)
	  (lookup-gaiji-insert gaiji)
	  (add-text-properties start (point) props))))))

(defun lookup-arrange-fill-lines (entry)
  (let ((inhibit-read-only nil)
	(buffer-read-only nil)
	(fill-column (if (integerp lookup-fill-column)
			 lookup-fill-column
		       (round (* (window-width) lookup-fill-column)))))
    (while (not (eobp))
      (let ((start (point))
	    (end (progn (end-of-line) (point)))
	    (fill-column fill-column))
	(when (> (current-column) fill-column)
	  ;; Emacs 21.3: fill-region may or may not move the point.
	  (save-restriction
	    (narrow-to-region start end)
	    ;; read-only 属性がついた部分で改行しようとすると失敗するので
	    ;; 応急的に対策。
	    ;; 失敗した部分から行末までは fill-column を切り詰めて
	    ;; fill-region を呼び出す。
	    (catch ':done
	      (while (> fill-column 0)
		(condition-case  nil
		    (progn 
		      (fill-region start end)
		      (goto-char (point-max))
		      (throw ':done t))
		  (error nil))
		(goto-char (point-min))
		(unless (eq (save-excursion (end-of-line) (point))
			    end)
		  (throw ':done t))
		(setq fill-column (1- fill-column)))
	      (goto-char (point-max)))))
	(forward-line)))))

(defun lookup-arrange-fill-paragraphs (entry)
  (text-mode)
  (let ((fill-column (if (integerp lookup-fill-column)
			 lookup-fill-column
		       (round (* (window-width) lookup-fill-column)))))
    (while (not (eobp))
      (fill-paragraph nil)
      (forward-paragraph))))

(defun lookup-arrange-squeezed-references (entry)
  (if (lookup-dictionary-option
       (lookup-entry-dictionary entry) ':squeezed nil)
      (while (search-forward-regexp "→□\\(#0001\\|<gaiji:z0001>\\)?" nil t)
	(replace-match ""))))

;;;
;:: Adjust functions
;;;

(defun lookup-adjust-show-gaijis (entry)
  (lookup-map-over-property
   (point-min) (point-max) 'lookup-gaiji 'lookup-gaiji-glyph-paste))

(defun lookup-adjust-check-references (entry)
  (lookup-map-over-property
   (point-min) (point-max) 'lookup-reference
   (lambda (start end reference)
     (if (if (lookup-reference-p reference)
	     (lookup-reference-refered-p reference)
	   (lookup-entry-refered-p reference))
	 (put-text-property start end 'face 'lookup-refered-face)
       (put-text-property start end 'face 'lookup-reference-face)))))

(defun lookup-adjust-goto-min (entry))


;;;;;;;;;;;;;;;;;;;;
;: Other Functions
;;;;;;;;;;;;;;;;;;;;

(defun lookup-vse-get-menu (dictionary)
  (let ((entries (lookup-dictionary-get-property dictionary 'menu-entries)))
    (unless entries
      (when (lookup-dictionary-command-p dictionary 'menu)
	(setq entries (lookup-dictionary-command dictionary 'menu))
	(lookup-foreach 'lookup-arrange-heading entries)
	(lookup-dictionary-put-property dictionary 'menu-entries entries)))
    entries))

(defun lookup-vse-get-copyright (dictionary)
  (let ((entries (lookup-dictionary-get-property dictionary 'copyright-entries)))
    (unless entries
      (when (lookup-dictionary-command-p dictionary 'copyright)
	(setq entries (lookup-dictionary-command dictionary 'copyright))
	(lookup-foreach 'lookup-arrange-heading entries)
	(lookup-dictionary-put-property dictionary 'copyright-entries entries)))
    entries))

(defun lookup-vse-open-entry (entry)
  (let ((dictionary (lookup-entry-dictionary entry)))
    (when (lookup-dictionary-command-p dictionary 'open)
      (lookup-dictionary-command dictionary 'open entry)
      t)))

(defun lookup-vse-get-gaiji (dictionary code)
  (let* ((table (lookup-dictionary-gaiji-table dictionary))
	 (gaiji (lookup-gaiji-table-ref table code))
	 (glyph (and gaiji (lookup-gaiji-glyph gaiji)))
	 (alter (and gaiji (lookup-gaiji-alternate gaiji))))
    (unless (and gaiji glyph alter)
      (unless alter
	(setq alter (format lookup-gaiji-alternate code)))
      (unless glyph
	(if (and lookup-enable-gaiji
		 (lookup-gaiji-glyph-possible-p)
		 (setq glyph
		       (lookup-xbm-normalize
			(lookup-dictionary-command dictionary 'gaiji code))))
	    (setq glyph (lookup-gaiji-glyph-compose glyph))
	  (setq glyph alter)))
      (setq gaiji (lookup-make-gaiji glyph alter))
      (lookup-gaiji-table-set table code gaiji))
    gaiji))

(defun lookup-xbm-normalize (xbm)
  "Normalize xbm image. An Argument is xbm image.
Return normalized xbm image."
  (when (stringp xbm)
    (with-temp-buffer
      (insert xbm)
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*\n" nil t)
	(replace-match ""))
      (goto-char (point-min))
      (while (re-search-forward
	      "#define[ \t\n]+[^ \t\n]+_\\(width\\|height\\)" nil t)
	(replace-match (concat "#define default_" (match-string 1))))
      (while (re-search-forward
	      "char[ \t\n]+[^ \t\n]+_bits" nil t)
	(replace-match (concat "char default_bits" (match-string 1))))
      (while 
	  (re-search-forward "\\\\\\(x[0-9a-fA-F][0-9a-fA-F]\\)" nil t)
	(replace-match (concat "0" (match-string 1))))
      (buffer-string))))

(provide 'lookup-vse)

;;; lookup-vse.el ends here
