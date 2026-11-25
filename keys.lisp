(in-package :lem-consult)

;;; Consult commands share one prefix, so each is reachable without M-x.
;;;
;;; The prefix is bound in init.lisp rather than here: a user extension should
;;; not take a global key merely by being loaded.  C-c h is free in Lem's global
;;; map; local maps (lsp-mode's C-c h, for one) still win inside their buffers.

(defvar *consult-keymap*
  (make-keymap :description '*consult-keymap*)
  "Prefix keymap for the Consult commands.")

(define-key *consult-keymap* "b" 'consult-buffer)
(define-key *consult-keymap* "p" 'consult-project-buffer)
(define-key *consult-keymap* "r" 'consult-recent-file)
(define-key *consult-keymap* "m" 'consult-bookmark)
(define-key *consult-keymap* "l" 'consult-line)
(define-key *consult-keymap* "L" 'consult-line-multi)
(define-key *consult-keymap* "g" 'consult-grep)
(define-key *consult-keymap* "G" 'consult-ripgrep)
(define-key *consult-keymap* "f" 'consult-find)
(define-key *consult-keymap* "F" 'consult-fd)
(define-key *consult-keymap* "i" 'consult-imenu)
(define-key *consult-keymap* "I" 'consult-imenu-multi)
(define-key *consult-keymap* "o" 'consult-outline)
(define-key *consult-keymap* "O" 'consult-org-heading)
(define-key *consult-keymap* "j" 'consult-goto-line)
(define-key *consult-keymap* "y" 'consult-yank-from-kill-ring)
(define-key *consult-keymap* "h" 'consult-history)
(define-key *consult-keymap* "t" 'consult-theme)
(define-key *consult-keymap* "c" 'consult-mode-command)
(define-key *consult-keymap* "n" 'consult-minor-mode-menu)
