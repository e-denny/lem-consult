(defpackage :lem-consult
  (:use :cl :lem)
  (:documentation "Consult-style search and navigation commands for Lem.
Each command collects candidates, shows them in the ordinary Vertico prompt,
and acts on the selected one.")
  (:export
   ;; knobs
   #:*consult-max-candidates*
   #:*consult-async-min-input*
   #:*consult-command-timeout*
   #:*consult-max-files*
   #:*consult-grep-command*
   #:*consult-ripgrep-command*
   #:*consult-git-grep-command*
   #:*consult-find-command*
   #:*consult-fd-command*
   #:*consult-imenu-rules*
   #:*consult-keymap*
   ;; virtual buffers
   #:consult-buffer
   #:consult-project-buffer
   #:consult-recent-file
   #:consult-bookmark
   ;; search
   #:consult-line
   #:consult-line-multi
   #:consult-grep
   #:consult-ripgrep
   #:consult-git-grep
   #:consult-find
   #:consult-fd
   ;; navigation
   #:consult-goto-line
   #:consult-outline
   #:consult-org-heading
   #:consult-imenu
   #:consult-imenu-multi
   ;; editing and histories
   #:consult-yank-from-kill-ring
   #:consult-yank-pop
   #:consult-history
   #:consult-theme
   #:consult-mode-command
   #:consult-minor-mode-menu))
