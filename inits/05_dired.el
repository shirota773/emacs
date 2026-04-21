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
  :bind
  (("M-s d" . dirvish-side)
   ("M-s h" . dirvish-history-jump))
  :config
  (setq dired-use-ls-dired (not darwin-p))
  (setq dired-listing-switches
        (if darwin-p
            "-lAh"
          "-l --almost-all --human-readable --group-directories-first --no-group"))
  (setq dirvish-hide-details t)
  (setq dirvish-side-display-alist '((side . right) (slot . -1)))
  (setq dirvish-use-header-line 'global)
  (setq dirvish-header-line-height '(25 . 35))
  (setq dirvish-side-attributes '(git-msg file-modes file-time file-size))
  (setq dirvish-large-directory-threshold 20000)
  (setq dirvish-header-line-format '(:left (path) :right (free-space)))
  (setq dirvish-mode-line-format
        '(:left (sort file-time " " file-size symlink) :right (omit yank index)))
  (setq dirvish-quick-access-entries
        '(("h" "~/"          "Home")
          ("d" "~/Downloads" "Downloads")
          ("e" "~/.emacs.d/" "emacs")))
  (put 'dired-find-alternate-file 'disabled nil)
  )

