;;; 20_org.el --- Minimalist Org-mode Configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; This file contains the bare essentials for viewing and light editing
;; of Org files, as Obsidian has become the primary note-taking tool.
;; Original extensive configuration is stored in inits/disabled/20_org.el.

;;; Code:

(leaf org
  :ensure t
  :init
  (add-to-list 'auto-mode-alist '("\\.org$" . org-mode))
  :custom
  ((org-directory . "~/org_icloud")
   (org-startup-indented . t)
   (org-startup-folded . 'content)
   (org-startup-with-inline-images . t)
   (org-hide-leading-stars . t)
   (org-hide-emphasis-markers . t)
   (org-pretty-entities . t)
   (org-ellipsis . "…")
   (org-image-actual-width . '(330)))
  :bind
  ((org-mode-map
    ("M-j" . outline-next-visible-heading)
    ("M-k" . outline-previous-visible-heading)
    ("C-c n" . org-toggle-narrow-to-subtree)
    ("C-c i" . org-toggle-inline-images)))
  :config
  (add-hook 'org-mode-hook 'org-indent-mode))

;; Modern styling for a cleaner look
(leaf org-modern
  :ensure t
  :after org
  :config
  (global-org-modern-mode 1))

(provide '20_org)
;;; 20_org.el ends here
