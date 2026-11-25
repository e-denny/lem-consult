(defsystem "lem-consult"
  :description "Consult-style search and navigation commands for Lem."
  :author "Lem contributors"
  :license "MIT"
  :depends-on ("lem/core" "alexandria" "cl-ppcre")
  :serial t
  :components ((:file "package")
               (:file "core")
               (:file "buffer")
               (:file "search")
               (:file "navigate")
               (:file "edit")
               (:file "keys")))
