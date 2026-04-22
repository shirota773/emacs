;;
;; $Id: replace-zen-to-ascii-region.el,v 1.2 2003/09/19 14:15:53 yamauchi Exp $
;; Copyright (C) 2000-2003 YAMAUCHI Hitoshi »³Æâ ÀÆ
;;
;; Original name is replaceNum 1999-5-9
;;
(defun replace-zen-to-ascii-region (b e)
  "Replace Zenkaku (what we called) numbers to ASCII characters"
  ;; "¤¤¤ï¤æ¤ëÁ´³Ñ±Ñ¿ô»ú¤ò replace-string ¤Ç ascii ¿ô»ú¤ËÊÑ´¹¤¹¤ë"
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region b e)
      (let ((num-list (list '("£±" "1")	; ¤Ê¤¼¤«ºÇ½é¤ÎÍ×ÁÇ¤À¤±¼ºÇÔ¤¹¤ë
		       '("£±" "1") '("£²" "2") '("£³" "3") '("£´" "4") 
		       '("£µ" "5") '("£¶" "6") '("£·" "7") '("£¸" "8")
		       '("£¹" "9") '("£°" "0") '("¡Ê" "(") '("¡Ë" ")")
		       '("¡¤" "¡¢") '("¡¥" "¡£") '("¡È" "``") '("¡É" "''")
		       '("¡¡" " ") 
		       '("¡Ô" "<<") '("¡Õ" ">>") '("¡ã" "<") '("¡ä" ">") 
		       '("¡Î" "[") '("¡Ï" "]") '("¡Ð" "{") '("¡Ñ" "}")
		       '("¡¿" "/") '("¡À" "\\") '("¡Ü" "+") '("¡á" "=")
		       '("¡Ý" "-") '("¡¾" "-")
		       )))
	(while num-list
	  (let ((org (car (car num-list)))
		(dst (car (cdr (car num-list)))))
	    (goto-char b)
	    (replace-string org dst)
	    (setq num-list (cdr num-list))))))))
