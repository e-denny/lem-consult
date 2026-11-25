(in-package :lem-consult)

;;; ---------------------------------------------------------------------------
;;; consult-goto-line
;;; ---------------------------------------------------------------------------

(defun parse-line-column (input)
  "Parse \"LINE\" or \"LINE:COLUMN\" into two values, or NIL."
  (when (and input (plusp (length input)))
    (multiple-value-bind (match groups)
        (ppcre:scan-to-strings "^(\\d+)(?::(\\d+))?$" input)
      (when match
        (values (parse-integer (aref groups 0))
                (and (aref groups 1)
                     (parse-integer (aref groups 1))))))))

(define-command consult-goto-line () ()
  "Go to a line, or to a line and column."
  (let ((input (prompt-for-string "Go to line[:column]: "
                                  :history-symbol 'consult-goto-line)))
    (multiple-value-bind (line column) (parse-line-column input)
      (unless line
        (editor-error "Expected LINE or LINE:COLUMN"))
      (goto-location (current-buffer) line column))))

;;; ---------------------------------------------------------------------------
;;; consult-outline and consult-org-heading
;;; ---------------------------------------------------------------------------

(defun mode-name-string (buffer)
  "BUFFER's major mode name, downcased, or an empty string."
  (string-downcase (or (ignore-errors (mode-name (buffer-major-mode buffer)))
                       "")))

(defun buffer-heading-pattern (buffer)
  "The heading regexp for BUFFER's mode, or NIL.
Organ and Org buffers use stars, Markdown buffers hashes; no other mode is
guessed at, because a line of stars in a C comment is not a heading."
  (let ((name (mode-name-string buffer)))
    (cond ((or (search "organ" name) (search "org" name))
           "^(\\*+)\\s+(.*)$")
          ((search "markdown" name)
           "^(#+)\\s+(.*)$")
          (t nil))))

(defun heading-candidates (buffer &optional (pattern (buffer-heading-pattern buffer)))
  "Candidates for the headings of BUFFER."
  (when pattern
    (let ((buffer buffer)
          (candidates '()))
      (dolist (entry (buffer-lines buffer))
        (multiple-value-bind (match groups)
            (ppcre:scan-to-strings pattern (cdr entry))
          (when match
            (let* ((number (car entry))
                   (level (length (aref groups 0)))
                   (title (string-trim '(#\Space #\Tab) (aref groups 1))))
              (push (make-candidate
                     title
                     (lambda () (goto-location buffer number))
                     :detail (format nil "L~D · line ~D" level number))
                    candidates)))))
      (nreverse candidates))))

(define-command consult-outline () ()
  "Jump to a heading of the current outline, Org or Markdown buffer."
  (let ((candidates (heading-candidates (current-buffer))))
    (unless candidates
      (editor-error "No headings in this buffer"))
    (consult-read "Heading: " candidates
                  :history-symbol 'consult-outline)))

(define-command consult-org-heading () ()
  "Jump to a heading of the current Org or Organ buffer."
  (let ((candidates (heading-candidates (current-buffer) "^(\\*+)\\s+(.*)$")))
    (unless candidates
      (editor-error "No Org headings in this buffer"))
    (consult-read "Org heading: " candidates
                  :history-symbol 'consult-org-heading)))

;;; ---------------------------------------------------------------------------
;;; consult-imenu
;;;
;;; Lem has no Imenu.  These rules are deliberately a small regexp table rather
;;; than a per-mode API: they find the lines a language's definition forms start
;;; with, which is what Imenu's flat list shows for the common modes here.
;;; *CONSULT-IMENU-RULES* is a list of plists with :MODES (substrings matched
;;; against the downcased major mode name), :REGEX (first capture group is the
;;; name) and :DESCRIPTION.  The last rule is the generic fallback.
;;; ---------------------------------------------------------------------------

(defvar *consult-imenu-rules*
  '((:description "Lisp"
     :modes ("lisp" "clojure" "scheme" "coalton")
     :regex "^\\(\\s*(?:def\\S+|define-\\S+)\\s+(?:\\(\\s*)?([^\\s()]+)")
    (:description "Python"
     :modes ("python")
     :regex "^\\s*(?:class|def)\\s+([^\\s(:]+)")
    (:description "Ruby"
     :modes ("ruby")
     :regex "^\\s*(?:class|module|def)\\s+([^\\s(;]+)")
    (:description "JavaScript"
     :modes ("javascript" "typescript" "ecmascript")
     :regex "^\\s*(?:export\\s+)?(?:default\\s+)?(?:async\\s+)?(?:function|class|const|let|var)\\s+([A-Za-z_$][\\w$]*)")
    (:description "Go"
     :modes ("go")
     :regex "^\\s*func\\s+(?:\\([^)]*\\)\\s*)?([A-Za-z_]\\w*)")
    (:description "Rust"
     :modes ("rust")
     :regex "^\\s*(?:pub(?:\\([^)]*\\))?\\s+)?(?:async\\s+)?(?:fn|struct|enum|trait|impl|mod|const|static)\\s+([A-Za-z_]\\w*)")
    (:description "Generic"
     :modes ()
     :regex "^\\s*(?:def|class|function|fn|func|sub|proc|struct|enum)\\s+([A-Za-z_][\\w-]*)"))
  "Definition forms recognized by consult-imenu, in matching order.")

(defun imenu-rule-for-buffer (buffer)
  "The first *CONSULT-IMENU-RULES* entry matching BUFFER's major mode."
  (let ((name (mode-name-string buffer)))
    (or (find-if (lambda (rule)
                   (some (lambda (mode) (search mode name))
                         (getf rule :modes)))
                 *consult-imenu-rules*)
        (car (last *consult-imenu-rules*)))))

(defun imenu-candidates (buffer &optional prefix)
  "Candidates for definitions in BUFFER, using its major mode's rule.
PREFIX is prepended to the label, for a scan across several buffers."
  (let* ((rule (imenu-rule-for-buffer buffer))
         (regex (getf rule :regex))
         (description (getf rule :description))
         (buffer buffer)
         (candidates '()))
    (dolist (entry (buffer-lines buffer))
      (multiple-value-bind (match groups)
          (ppcre:scan-to-strings regex (cdr entry))
        (when match
          (let* ((number (car entry))
                 (name (string-trim '(#\Space #\Tab) (aref groups 0))))
            (unless (zerop (length name))
              (push (make-candidate
                     (if prefix
                         (format nil "~A~A: ~A" prefix (buffer-name buffer) name)
                         name)
                     (lambda () (goto-location buffer number))
                     :detail (format nil "~A · line ~D" description number))
                    candidates))))))
    (nreverse candidates)))

(define-command consult-imenu () ()
  "Jump to a definition in the current buffer."
  (let ((candidates (imenu-candidates (current-buffer))))
    (unless candidates
      (editor-error "No definitions found"))
    (consult-read "Definition: " candidates
                  :history-symbol 'consult-imenu)))

(define-command consult-imenu-multi () ()
  "Jump to a definition in a project buffer with the same major mode."
  (let* ((root (project-root-or-buffer-directory))
         (major-mode (buffer-major-mode (current-buffer)))
         (candidates '()))
    (dolist (buffer (buffer-list))
      (when (and (not (not-switchable-buffer-p buffer))
                 (eq (buffer-major-mode buffer) major-mode)
                 (let ((filename (ignore-errors (buffer-filename buffer))))
                   (or (null filename) (under-directory-p filename root))))
        (setf candidates (nconc candidates (imenu-candidates buffer)))))
    (unless candidates
      (editor-error "No definitions found"))
    (consult-read "Definition (project): " candidates
                  :history-symbol 'consult-imenu-multi)))
