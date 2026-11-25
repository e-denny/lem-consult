(in-package :lem-consult)

;;; A small candidate model on top of the prompt.
;;;
;;; Consult commands are all the same shape: collect a list of CANDIDATE, let
;;; the user filter and choose one, then run its action.  The prompt machinery
;;; gives us the filtering UI (with lem-vertico's popup and an automatic list)
;;; and the completion items give us labels and annotations.  CANDIDATE keeps
;;; the parts Lem's completion items do not: what to do with the selection.

(defvar *consult-max-candidates* 1000
  "Most candidates handed to the prompt at once.
The prompt itself shows at most LEM/COMPLETION-MODE::*LIMIT-NUMBER-OF-ITEMS*
rows; this is about how much is built and filtered for every keystroke.")

(defvar *consult-async-min-input* 2
  "Reserved for the asynchronous search commands; unused by the synchronous
grep and find commands.")

(defvar *consult-command-timeout* 10
  "Seconds a shell-backed search may run before it is killed.")

(defvar *consult-max-files* 5000
  "Most files collected by consult-find and consult-fd.")

(defstruct (candidate (:constructor make-candidate (label action &key detail)))
  label
  detail
  action)

(defun uniquify-candidates (candidates)
  "CANDIDATES with duplicate labels made distinct.
A selection comes back from the prompt as its label, so two candidates with the
same label could not be told apart.  Repeated labels gain \"  (N)\"; the first
one keeps the plain label."
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (candidate candidates (nreverse result))
      (let* ((label (candidate-label candidate))
             (count (gethash label seen 0)))
        (setf (gethash label seen) (1+ count))
        (push (if (zerop count)
                  candidate
                  (make-candidate
                   (format nil "~A  (~D)" label (1+ count))
                   (candidate-action candidate)
                   :detail (candidate-detail candidate)))
              result)))))

(defun filter-candidates (input candidates)
  "CANDIDATES matching INPUT, best match first.
With empty input the producer's order is kept: the first candidate is the one
the command put first (the first line, the first grep match, the first buffer),
not whichever label happens to be shortest."
  (if (zerop (length input))
      candidates
      (let ((matched
              (if (find-package :lem-orderless)
                  (funcall (find-symbol "ORDERLESS-FILTER" :lem-orderless)
                           input candidates
                           :key #'candidate-label)
                  (completion-strings input candidates :key #'candidate-label))))
        (if (> (length matched) *consult-max-candidates*)
            (subseq matched 0 *consult-max-candidates*)
            matched))))

(defun candidate-completion-items (candidates)
  "CANDIDATES as completion items for the prompt."
  (mapcar (lambda (candidate)
            (lem/completion-mode:make-completion-item
             :label (candidate-label candidate)
             :detail (or (candidate-detail candidate) "")))
          candidates))

(defun call-without-history-ordering (function)
  "Call FUNCTION with lem-vertico's history-first ordering turned off.
Consult candidates are already in the order the command chose -- buffer
sources, buffer lines, grep matches, files -- and a previously selected
candidate must not jump in front of them just because it is in the prompt
history.  When lem-vertico is not installed there is nothing to bind."
  (let ((symbol (find-symbol "*HISTORY-ORDERING-P*" :lem-vertico)))
    (if (and symbol (boundp symbol))
        (progv (list symbol) (list nil) (funcall function))
        (funcall function))))

(defun read-candidates (prompt candidates
                        &key history-symbol initial-value (filter t))
  "Prompt with PROMPT for one of CANDIDATES and return it, or NIL.
CANDIDATES is a list.  It is filtered with FILTER-CANDIDATES, or with the
input untouched when FILTER is NIL."
  (let ((shown '()))
    (let ((input
            (call-without-history-ordering
             (lambda ()
               (prompt-for-string
                prompt
                :initial-value initial-value
                :history-symbol history-symbol
                :completion-function
                (lambda (string)
                  (let* ((all (if filter
                                  (filter-candidates string candidates)
                                  candidates))
                         (all (if (> (length all) *consult-max-candidates*)
                                  (subseq all 0 *consult-max-candidates*)
                                  all)))
                    (setf shown (uniquify-candidates all))
                    (candidate-completion-items shown)))
                :test-function
                (lambda (string)
                  (and (find string shown
                             :key #'candidate-label
                             :test #'string=)
                       t)))))))
      (when input
        (find input shown :key #'candidate-label :test #'string=)))))

(defun run-candidate (candidate)
  "Run CANDIDATE's action, if there is one."
  (when candidate
    (funcall (candidate-action candidate))))

(defun consult-read (prompt candidates &key history-symbol initial-value (filter t))
  "READ-CANDIDATES and run the selection."
  (run-candidate (read-candidates prompt candidates
                                  :history-symbol history-symbol
                                  :initial-value initial-value
                                  :filter filter)))

;;; ---------------------------------------------------------------------------
;;; Locations, used by every command that jumps.
;;; ---------------------------------------------------------------------------

(defun goto-location (buffer line &optional column)
  "Switch to BUFFER and put point on LINE (1-based), COLUMN (0-based)."
  (switch-to-buffer buffer)
  (move-to-line (current-point) (max 1 line))
  (when column
    (move-to-column (current-point) (max 0 column))))

(defun visit-file-line (filename line &optional column)
  "Open FILENAME and move to LINE, COLUMN."
  (let ((buffer (find-file-buffer filename)))
    (goto-location buffer line column)))

(defun project-root-or-buffer-directory ()
  "The current project root, or the buffer's directory when there is none.
LEM-CORE/COMMANDS/PROJECT:FIND-ROOT returns the home directory (or /) when it
finds no project marker, which would make a grep search all of home.  Those two
answers are treated as no project here."
  (let* ((directory (buffer-directory))
         (root (ignore-errors
                 (funcall (find-symbol "FIND-ROOT" :lem-core/commands/project)
                          directory))))
    (if (and root
             (not (uiop:pathname-equal root (user-homedir-pathname)))
             (not (uiop:pathname-equal root #P"/")))
        root
        directory)))

(defun under-directory-p (filename directory)
  "True when FILENAME is inside DIRECTORY."
  (and filename directory
       (ignore-errors
         (uiop:subpathp (uiop:ensure-pathname filename)
                        (uiop:ensure-directory-pathname directory)))))
