(in-package :lem-consult)

;;; ---------------------------------------------------------------------------
;;; Line search: consult-line and consult-line-multi
;;; ---------------------------------------------------------------------------

(defun buffer-lines (buffer)
  "Return (LINE-NUMBER . TEXT) for the lines of BUFFER."
  (with-current-buffer buffer
    (let ((point (copy-point (buffer-start-point buffer) :temporary))
          (lines '())
          (number 0))
      (loop
        (incf number)
        (push (cons number (line-string point)) lines)
        (unless (line-offset point 1)
          (return)))
      (nreverse lines))))

(defun line-candidates (buffer &optional prefix)
  "Candidates for the non-blank lines of BUFFER.
PREFIX is prepended to each label, for searches across several buffers."
  (let ((buffer buffer)
        (candidates '()))
    (dolist (entry (buffer-lines buffer))
      (let* ((number (car entry))
             (text (string-trim '(#\Space #\Tab) (cdr entry))))
        (unless (zerop (length text))
          (push (make-candidate
                 (if prefix
                     (format nil "~A~A:~D: ~A" prefix (buffer-name buffer)
                             number text)
                     text)
                 (lambda () (goto-location buffer number))
                 :detail (format nil "line ~D" number))
                candidates))))
    (nreverse candidates)))

(define-command consult-line () ()
  "Search the lines of the current buffer."
  (consult-read "Line: " (line-candidates (current-buffer))
                :history-symbol 'consult-line))

(define-command consult-line-multi () ()
  "Search the lines of every switchable buffer."
  (let ((candidates '()))
    (dolist (buffer (buffer-list))
      (unless (not-switchable-buffer-p buffer)
        (setf candidates (nconc candidates (line-candidates buffer)))))
    (unless candidates
      (editor-error "No lines"))
    (consult-read "Line (all buffers): " candidates
                  :history-symbol 'consult-line-multi)))

;;; ---------------------------------------------------------------------------
;;; Grep and file search
;;; ---------------------------------------------------------------------------

(defvar *consult-grep-command*
  '("grep" "-rnI" "--exclude-dir=.git" "--exclude-dir=.hg"
    "--exclude-dir=node_modules")
  "Command and arguments for consult-grep, before the pattern and directory.")

(defvar *consult-ripgrep-command*
  '("rg" "--line-number" "--no-heading" "--color=never" "--smart-case")
  "Command and arguments for consult-ripgrep, before the pattern and directory.")

(defvar *consult-git-grep-command*
  '("git" "grep" "-n" "-I" "--no-color")
  "Command and arguments for consult-git-grep, before the pattern.")

(defvar *consult-find-command*
  '("find" "." "-type" "f" "-not" "-path" "*/.git/*")
  "Command and arguments for consult-find.")

(defvar *consult-fd-command*
  '("fd" "--type" "f" "--color" "never" "--exclude" ".git")
  "Command and arguments for consult-fd.")

(defun program-output (command directory)
  "Run COMMAND in DIRECTORY and return its standard output.
A non-zero exit status is not an error: grep and friends use one to mean no
matches.  The command is bounded by *CONSULT-COMMAND-TIMEOUT*, so a search in a
large tree cannot freeze the editor.  A missing program is reported as an
editor error."
  (handler-case
      (uiop:run-program (append (list "timeout"
                                      "-k" "1"
                                      (princ-to-string *consult-command-timeout*))
                                command)
                        :directory directory
                        :output :string
                        :error-output :string
                        :ignore-error-status t)
    (error (condition)
      (editor-error "~A" condition))))

(defun parse-grep-output (output)
  "Parse FILE:LINE:CONTENT lines from OUTPUT into (FILE LINE CONTENT) triples."
  (let ((result '())
        (limit (* 2 *consult-max-candidates*)))
    (dolist (line (uiop:split-string output :separator '(#\Newline)))
      (when (>= (length result) limit)
        (return))
      (multiple-value-bind (match groups)
          (ppcre:scan-to-strings "^(.*?):([0-9]+):(.*)$" line)
        (when match
          (push (list (aref groups 0)
                      (parse-integer (aref groups 1))
                      (aref groups 2))
                result))))
    (nreverse result)))

(defun grep-candidates (output directory)
  "Candidates for the grep matches in OUTPUT, relative to DIRECTORY."
  (let ((candidates '()))
    (dolist (match (parse-grep-output output))
      (destructuring-bind (file line content) match
        (let ((filename (merge-pathnames file directory))
              (line line)
              (content (string-trim '(#\Space #\Tab) content)))
          (push (make-candidate
                 (format nil "~A:~D: ~A" file line content)
                 (lambda () (visit-file-line filename line))
                 :detail (namestring filename))
                candidates))))
    (nreverse candidates)))

(defun consult-grep-run (command prompt history-symbol &key search-directory-p)
  "Ask for a pattern, run COMMAND, and prompt with the matches.
This is Consult's two-step shape without the asynchronous pipeline: the
pattern is read first, then the file:line candidates are listed."
  (let* ((root (project-root-or-buffer-directory))
         (pattern (prompt-for-string prompt :history-symbol history-symbol)))
    (when (or (null pattern) (zerop (length pattern)))
      (editor-error "Empty search pattern"))
    (let* ((arguments (append command
                              (list "--" pattern)
                              (when search-directory-p (list "."))))
           (candidates (grep-candidates (program-output arguments root) root)))
      (unless candidates
        (editor-error "No matches"))
      (consult-read "Match: " candidates
                    :history-symbol (intern (format nil "~A-RESULT" history-symbol)
                                            :lem-consult)))))

(define-command consult-grep () ()
  "Search files with grep, starting at the project root."
  (consult-grep-run *consult-grep-command* "Grep: " 'consult-grep
                    :search-directory-p t))

(define-command consult-ripgrep () ()
  "Search files with ripgrep, starting at the project root."
  (consult-grep-run *consult-ripgrep-command* "Ripgrep: " 'consult-ripgrep
                    :search-directory-p t))

(define-command consult-git-grep () ()
  "Search tracked files with git grep, starting at the project root."
  (consult-grep-run *consult-git-grep-command* "Git grep: " 'consult-git-grep))

(defun file-candidates (output directory)
  "Candidates for the file names in OUTPUT, relative to DIRECTORY."
  (let ((candidates '()))
    (dolist (name (uiop:split-string output :separator '(#\Newline)))
      (when (>= (length candidates) *consult-max-files*)
        (return))
      (unless (zerop (length name))
        (let* ((relative (enough-namestring name directory))
               (filename (merge-pathnames name directory)))
          (push (make-candidate
                 relative
                 (lambda () (find-file filename))
                 :detail (namestring filename))
                candidates))))
    (nreverse candidates)))

(defun consult-files-source (command prompt history-symbol)
  "Prompt with one of COMMAND's files, run from the project root."
  (let* ((root (project-root-or-buffer-directory))
         (candidates
           (file-candidates (program-output command root) root)))
    (unless candidates
      (editor-error "No files"))
    (consult-read prompt candidates :history-symbol history-symbol)))

(define-command consult-find () ()
  "Find a file with find, starting at the project root."
  (consult-files-source *consult-find-command* "Find file: " 'consult-find))

(define-command consult-fd () ()
  "Find a file with fd, starting at the project root."
  (consult-files-source *consult-fd-command* "fd: " 'consult-fd))
