;; (autoload 'mew "mew" nil t)
;; (autoload 'mew-send "mew" nil t)

;; ;; Optional setup (Read Mail menu):
;; (setq read-mail-command 'mew)

;; ;; Optional setup (e.g. C-xm for sending a message):
;; (autoload 'mew-user-agent-compose "mew" nil t)
;; (if (boundp 'mail-user-agent)
;;     (setq mail-user-agent 'mew-user-agent))
;; (if (fboundp 'define-mail-user-agent)
;;     (define-mail-user-agent
;;       'mew-user-agent
;;       'mew-user-agent-compose
;;       'mew-draft-send-message
;;       'mew-draft-kill
;;       'mew-send-hook))
;; (setq mew-smtp-server "/clear@imap.gmail.com:993!")
;; ;; (setq mew-pop-server "/clear@imap.gmail.com:993!")

;; Optional setup (Read Mail menu):
(setq read-mail-command 'mew)

(autoload 'mew "mew" nil t)
(autoload 'mew-send "mew" nil t)
(setq mew-fcc "+outbox")
(setq exec-path (cons "/usr/bin" exec-path))

(setq user-mail-address "sma.yama73@gmail.com")
(setq user-full-name "yamayama")
(setq mew-smtp-server "smtp.gmail.com")
(require 'mew)
(setq mail-user-agent 'mew-user-agent)
(define-mail-user-agent
  'mew-user-agent
  'mew-user-agent-compose
  'mew-draft-send-message
  'mew-draft-kill
  'mew-send-hook)
