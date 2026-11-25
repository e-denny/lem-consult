(in-package :lem-consult)

;;; ---------------------------------------------------------------------------
;;; Kill ring
;;; ---------------------------------------------------------------------------

(defun killring-strings ()
  "The items of the current kill ring, most recent first."
  (let* ((killring (current-killring))
         (ring (lem/common/killring::killring-ring killring))
         (length (lem/common/ring:ring-length ring))
         (strings '()))
    (dotimes (i length)
      (let ((item (lem/common/ring:ring-ref ring i)))
        (push (lem/common/killring::item-string item) strings)))
    (nreverse strings)))

(defun killring-label (string)
  "A one-line label for a kill ring item."
  (let ((line (subseq string 0 (or (position #\Newline string) (length string)))))
    (cond ((zerop (length line)) "(empty line)")
          ((> (length line) 120)
           (concatenate 'string (subseq line 0 117) "..."))
          (t line))))

(define-command consult-yank-from-kill-ring () ()
  "Insert an item from the kill ring."
  (let ((strings (killring-strings)))
    (unless strings
      (editor-error "Kill ring is empty"))
    (consult-read
     "Kill ring: "
     (mapcar (lambda (string)
               (let ((string string))
                 (make-candidate
                  (killring-label string)
                  (lambda () (insert-string (current-point) string))
                  :detail (format nil "~D characters" (length string)))))
             strings)
     :history-symbol 'consult-yank
     :filter t)))

(define-command consult-yank-pop () ()
  "Insert an item from the kill ring.
Lem's yank-pop replaces the previous yank; this command does not, it inserts
the selected item at point."
  (consult-yank-from-kill-ring))

;;; ---------------------------------------------------------------------------
;;; Histories
;;; ---------------------------------------------------------------------------

(defun history-candidates ()
  "Candidates for every prompt history entry."
  (let ((candidates '()))
    (maphash
     (lambda (name history)
       (dolist (entry (lem/common/history:history-data-list history))
         (when (and (stringp entry) (plusp (length entry)))
           (let ((entry entry))
             (push (make-candidate
                    (killring-label entry)
                    (lambda () (insert-string (current-point) entry))
                    :detail (format nil "~A" name))
                   candidates)))))
     lem/prompt-window::*history-table*)
    (nreverse candidates)))

(define-command consult-history () ()
  "Insert a string from a prompt history.
Lem cannot open a second prompt while one is active, so this command works
outside a prompt.  It lists every prompt history and inserts the chosen entry
at point."
  (when (lem/prompt-window:current-prompt-window)
    (editor-error "Cannot open a prompt from inside a prompt"))
  (let ((candidates (history-candidates)))
    (unless candidates
      (editor-error "No prompt history"))
    (consult-read "History: " candidates
                  :history-symbol 'consult-history
                  :filter t)))

;;; ---------------------------------------------------------------------------
;;; Themes
;;; ---------------------------------------------------------------------------

(defun theme-candidates ()
  "Candidates for the available color themes."
  (let ((all-color-themes (find-symbol "ALL-COLOR-THEMES" :lem-core))
        (candidates '()))
    (when (and all-color-themes (fboundp all-color-themes))
      (dolist (name (sort (copy-list (funcall all-color-themes)) #'string<))
        (let ((name name))
          (push (make-candidate
                 name
                 (lambda () (load-theme name))
                 :detail "color theme")
                candidates))))
    (nreverse candidates)))

(define-command consult-theme () ()
  "Load a color theme."
  (let ((candidates (theme-candidates)))
    (unless candidates
      (editor-error "No color themes"))
    (consult-read "Theme: " candidates
                  :history-symbol 'consult-theme)))

;;; ---------------------------------------------------------------------------
;;; Mode commands and minor modes
;;; ---------------------------------------------------------------------------

(defun keymap-command-names (keymap)
  "Command symbols bound in KEYMAP and its base keymaps."
  (let ((names '()))
    (loop :for map := keymap :then (ignore-errors (keymap-base map))
          :while map
          :do (ignore-errors
                (traverse-keymap
                 map
                 (lambda (keys command)
                   (declare (ignore keys))
                   (when (and command (symbolp command))
                     (pushnew command names :test #'eq))))))
    names))

(defun mode-command-candidates ()
  "Candidates for commands belonging to the active major and minor modes."
  (let ((seen (make-hash-table :test #'eq))
        (candidates '()))
    (labels ((add (name detail)
               (unless (gethash name seen)
                 (setf (gethash name seen) t)
                 (push (make-candidate
                        (string name)
                        (lambda ()
                          (alexandria:when-let (command (find-command name))
                            (call-command command nil)))
                        :detail detail)
                       candidates))))
      (dolist (mode (all-active-modes (current-buffer)))
        (let ((detail (format nil "~A" (mode-name mode))))
          (dolist (command (lem-core::mode-commands mode))
            (add (command-name command) detail))
          (dolist (name (keymap-command-names (ignore-errors (mode-keymap mode))))
            (add name detail)))))
    (nreverse candidates)))

(define-command consult-mode-command () ()
  "Run a command belonging to an active mode."
  (let ((candidates (mode-command-candidates)))
    (unless candidates
      (editor-error "No mode commands"))
    (consult-read "Mode command: " candidates
                  :history-symbol 'consult-mode-command)))

(defun minor-mode-candidates ()
  "Candidates for the known minor modes, annotated on or off."
  (let ((buffer (current-buffer))
        (candidates '()))
    (dolist (mode (minor-modes))
      (let ((active (mode-active-p buffer mode))
            (mode mode))
        (push (make-candidate
               (mode-name mode)
               (lambda ()
                 (if active
                     (disable-minor-mode mode)
                     (enable-minor-mode mode)))
               :detail (if active "on" "off"))
              candidates)))
    (nreverse candidates)))

(define-command consult-minor-mode-menu () ()
  "Enable or disable a minor mode."
  (let ((candidates (minor-mode-candidates)))
    (unless candidates
      (editor-error "No minor modes"))
    (consult-read "Minor mode: " candidates
                  :history-symbol 'consult-minor-mode-menu)))
