;; gnuplot
(autoload 'gnuplot-mode "gnuplot" "Gnuplot mode" t nil)
(setq auto-mode-alist
(cons (cons "\\.plt$" 'gnuplot-mode) auto-mode-alist))

;; lammpsモード
(autoload 'lammps-mode "lammps" "Lammps mode" t nil)
(setq auto-mode-alist
(cons (cons "\\.in$" 'lammps-mode) auto-mode-alist))

;; rietanモード
(autoload 'rietan-mode "rietan" "Rietan mode" t nil)
(setq auto-mode-alist
(cons (cons "\\.ins$" 'rietan-mode) auto-mode-alist))
