(leaf dired
  :config
  ;; direddi-find-alternate-file の有効化
  (put 'dired-find-alternate-file 'disabled nil)

  :bind ((dired-mode-map
          ("<tab>" . dirvish-subtree-toggle)
          ("r" . wdired-change-to-wdired-mode)
          ("h" . dired-up-directory)
          ("j" . next-line)
          ("k" . previous-line)
          ("(" . dired-hide-details-mode)
          ("z" . peep-dired)
          ))
  )

;; diredでチラ見
(leaf peep-dired
  :ensure t
  :custom
  (peep-dired-cleanup-on-disable . t)
  (peep-dired-enable-on-directories . nil)
  :bind ((dired-mode-map
          ("p" . peep-dired)
          ("b" . peep-dired-scroll-page-up)
          ))
  )

(leaf dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :hook

  :custom
  (dired-use-ls-dired . (not darwin-p))
  (dired-listing-switches
   . (if darwin-p
         "-lAh"
       "-l --almost-all --human-readable --group-directories-first --no-group"))
  (dirvish-preview-disabled-exts . '("mp4" "pdf" "mkv"))
  (dirvish-hide-details . t)
  (dirvish-side-display-alist . '((side . right) (slot . -1)))
  ;; (dirvish-use-mode-line . nil)
  (dirvish-use-header-line . 'global)
  (dirvish-header-line-height . '(25. 35))
  ;; (dirvish-attributes . ;(append
                         ;; The order of these attributes is insignificant, they are always
                         ;; displayed in the same position.
                         ;; '(vc-state subtree-state nerd-icons collapse))
                         ;; Other attributes are displayed in the order they appear in this list.
  (dirvish-side-attributes . '(git-msg file-modes file-time file-size))
  (dirvish-large-directory-threshold . 20000)

  ;; Segments
  ;; 1. the order of segments *matters* here
  ;; 2. it's ok to place raw strings in it as separators
  (dirvish-header-line-format
   . '(:left (path) :right (free-space)))
  (dirvish-mode-line-format
   . '(:left (sort file-time " " file-size symlink) :right (omit yank index)))

  (dirvish-quick-access-entries
   . '(("h" "~/"          "Home")
       ("d" "~/Downloads" "Downloads")
       ("e" "~/.emacs.d/" "emacs")))

  :bind
  ("M-s d" . dirvish-side)
  ("M-s h" . #'dirvish-history-jump)

  :config
;  (setq dirvish-path-separators (list
;                                 (format "  %s " (nerd-icons-codicon "nf-cod-home"))
;                                 (format "  %s " (nerd-icons-codicon "nf-cod-root_folder"))
;                                 (format " %s " (nerd-icons-faicon "nf-fa-angle_right"))))

  ;; this command is useful when you want to close the window of `dirvish-side'
  ;; automatically when opening a file
  (put 'dired-find-alternate-file 'disabled nil)
  )

