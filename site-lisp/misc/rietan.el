;; RIETAN auto-mode
;; define several keyword classes

(setq rietan-int
  '("NBEAM" "NMODE" "NPRINT" "NTARG" "NSURFR"
    "NTRAN" "LPAIR1" "INDIV1" "IHA1" "IKA1"
    "ILA1" "IHP1" "IKP1" "ILP1" "IHP2"
    "IKP2" "ILP2" "IHP3" "IKP3" "ILP3"
    "NPRFN" "NASYM" "NSHIFT" "NCUT" "NPAT"
    "IWIDTH" "IHEIGHT" "LBG" "IPIZE" "IFSIZE"
    "ILSIZE" "NEXC" "NINT" "NRANGE" "NPICKUP"
    "NREPEAT" "NPAT" "IWIDTH" "IHEIGHT" "IYMIN"
    "IYMAX" "LBG" "LDEL" "IOFFSETD" "IPSIZE"
    "IFSIZE" "ILSIZE" "INDREF" "IOFFSET1" "NDA"
    "NSFF" "NCONST" "NOPT" "MREG" "NLESQ"
    "NESD" "NAUTO" "NCYCL" "NCONV" "NC"
    "MITER" "NC" "LSER" "LPAIR" "LTRIP"
    "LQUART" "NUPDT" "NFR" "NMEM" "NDA"
    "NPIXAF" "NPIXBF" "NPIXCF" "LANOM" "NPIXA"
    "NPIXB" "NPIXC" "LGR" "LFOFC"))
(setq rietan-float
  '("XLMDN" "RADIUS" "ABSORP" "ABSORP" "ABSORP"
    "R12" "CTHM1" "DSANG" "RGON" "SWIDTH"
    "PCOR1" "SABS" "XMUR1" "XLMDX" "PCOR2"
    "CTHM2" "XMUR2" "PHNAME1" "VNS1" "HKLM1"
    "HKLM1" "SHIFT0" "SHIFTN" "ROUGH" "BKGD"
    "SCALE" "GAUSS01" "ASYM01" "ANISTR01" "GAUSS00"
    "ASYM00" "ANISTR00" "FWHM12" "ASYM12" "ETA12"
    "ANISOBR12" "DUMMY12" "FWHM3" "ASYM3" "ANISOBR3"
    "DUMMY3" "PREF" "CELLQ" "DEG1" "DEG2"
    "USTP" "CURVATURE" "PC" "PC" "PC"
    "CHGPC" "RWID" "XMAX" "WNEG" "CONV"
    "TK" "FINC" "STEP" "ACC" "STEP"
    "ACC" "TK" "TSCAT" "EPSD" "TSCAT1"
    "TSCAT2" "ORFFE" "LORENTZ01" "LORENTZ00" "M3"))
(setq rietan-key
  '("Select" "case" "end" "select" "if" "If" "then" "else"))

;; create the regex string for each class of keywords
(setq rietan-int-regexp (regexp-opt rietan-int 'words))
(setq rietan-float-regexp (regexp-opt rietan-float 'words))
(setq rietan-key-regexp (regexp-opt rietan-key 'words))

;; Add some more classes using explicit regexp
(setq rietan-comment-regexp  "[!#].*\n")
(setq rietan-switch-regexp  " [0-2]+ *\n")

(setq 
 rietan-font-lock-keywords
 `((,rietan-comment-regexp . font-lock-comment-face)
   (,rietan-int-regexp . font-lock-builtin-face)
   (,rietan-float-regexp . font-lock-variable-name-face)
   (,rietan-key-regexp . font-lock-keyword-face)
   (,rietan-switch-regexp . font-lock-constant-face)
   ))


;; clear memory
(setq rietan-int nil)
(setq rietan-float nil)
(setq rietan-key nil)

;; create the list for font-lock.
;; each class of keyword is given a particular face
(defun revert-buffer-force ()
  "save the current position to tmp, then call revert-buffer, then goto-char(position)"
  (interactive)
  (defvar tmp)
  (setq tmp (point))
  (revert-buffer t t)
  (goto-char tmp)
  (kill-local-variable 'tmp))

(add-hook 'rietan-mode-hook
	  '(lambda ()
	     (define-key rietan-mode-map "\C-c\C-c" 'revert-buffer-force)))

;; define the mode
(define-derived-mode rietan-mode text-mode
  "rietan mode"
  "Major mode for editing RIETAN input scripts ..."
  ;; ...
  ;; code for syntax highlighting
  (setq font-lock-defaults '((rietan-font-lock-keywords)))
  ;; clear memory
  (setq rietan-int-regexp nil)
  (setq rietan-float-regexp nil)
  (setq rietan-key-regexp nil)
  (setq rietan-comment-regexp nil)
  (setq rietan-switch-regexp nil))
