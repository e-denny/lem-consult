(in-package :lem-consult)

;;; ---------------------------------------------------------------------------
;;; consult-buffer and the virtual buffer sources.
;;;
;;; Lem's C-x b completion already searches buffers.  consult-buffer adds the
;;; sources Consult mixes into the same prompt: buffers first, then recently
;;; opened files and bookmarks.  A candidate's detail says which source it came
;;; from, and the action is the source's own way of visiting it.
;;; ---------------------------------------------------------------------------

(defun bookmark-package ()
  "The bookmark extension's package, or NIL when it is not installed."
  (find-package :lem-bookmark))

(defun buffer-candidate-detail (buffer)
  "A one-line annotation for BUFFER."
  (let ((filename (ignore-errors (buffer-filename buffer)))
        (mode (ignore-errors (mode-name (buffer-major-mode buffer)))))
    (format nil "~@[~A~]~:[~; · ~]~@[~A~]"
            mode (and filename mode) (and filename (namestring filename)))))

(defun buffer-candidates (&optional predicate)
  "Candidates for every switchable buffer satisfying PREDICATE."
  (let ((candidates '()))
    (dolist (buffer (buffer-list))
      (when (and (not (not-switchable-buffer-p buffer))
                 (or (null predicate) (funcall predicate buffer)))
        (let ((buffer buffer))
          (push (make-candidate (buffer-name buffer)
                                (lambda () (switch-to-buffer buffer))
                                :detail (buffer-candidate-detail buffer))
                candidates))))
    (nreverse candidates)))

(defun recent-file-candidates (&optional predicate)
  "Candidates for recently opened files satisfying PREDICATE."
  (let ((recent-files (find-symbol "RECENT-FILES" :lem-core/commands/file)))
    (if (or (null recent-files) (not (fboundp recent-files)))
        '()
        (let ((candidates '()))
          (dolist (filename (funcall recent-files))
            (when (or (null predicate) (funcall predicate filename))
              (let ((filename filename))
                (push (make-candidate
                       (namestring filename)
                       (lambda () (find-file filename))
                       :detail "recent file")
                      candidates))))
          (nreverse candidates)))))

(defun bookmark-candidates (&optional predicate)
  "Candidates for bookmarks satisfying PREDICATE."
  (let ((package (bookmark-package)))
    (if (null package)
        '()
        (let ((table (find-symbol "*BOOKMARK-TABLE*" package))
              (name (find-symbol "BOOKMARK-NAME" package))
              (filename (find-symbol "BOOKMARK-FILENAME" package))
              (jump (find-symbol "BOOKMARK-JUMP" package))
              (candidates '()))
          (when (and table name filename (fboundp jump) (boundp table))
            (maphash
             (lambda (key bookmark)
               (declare (ignore key))
               (let ((bookmark-filename (funcall filename bookmark)))
                 (when (or (null predicate)
                           (funcall predicate bookmark-filename))
                   (let ((bookmark-name (funcall name bookmark)))
                     (push (make-candidate
                            bookmark-name
                            (lambda () (funcall jump bookmark-name))
                            :detail (format nil "bookmark · ~A"
                                            (namestring bookmark-filename)))
                           candidates)))))
             (symbol-value table)))
          (nreverse candidates)))))

(define-command consult-buffer () ()
  "Switch to a buffer, recent file or bookmark."
  (consult-read "Buffer: "
                (append (buffer-candidates)
                        (recent-file-candidates)
                        (bookmark-candidates))
                :history-symbol 'consult-buffer))

(define-command consult-project-buffer () ()
  "Switch to a buffer or file of the current project."
  (let ((root (project-root-or-buffer-directory)))
    (consult-read
     "Project buffer: "
     (append (buffer-candidates
              (lambda (buffer)
                (under-directory-p (ignore-errors (buffer-filename buffer))
                                   root)))
             (recent-file-candidates
              (lambda (filename) (under-directory-p filename root)))
             (bookmark-candidates
              (lambda (filename) (under-directory-p filename root))))
     :history-symbol 'consult-project-buffer)))

(define-command consult-recent-file () ()
  "Open a recently opened file."
  (let ((candidates (recent-file-candidates)))
    (unless candidates
      (editor-error "No recent files"))
    (consult-read "Recent file: " candidates
                  :history-symbol 'consult-recent-file)))

(define-command consult-bookmark () ()
  "Jump to a bookmark."
  (unless (bookmark-package)
    (editor-error "The bookmark extension is not loaded"))
  (let ((candidates (bookmark-candidates)))
    (unless candidates
      (editor-error "No bookmarks"))
    (consult-read "Bookmark: " candidates
                  :history-symbol 'consult-bookmark)))
