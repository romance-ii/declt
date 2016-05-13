;;; texi.lisp --- Texinfo format utilities

;; Copyright (C) 2010-2013 Didier Verna

;; Author: Didier Verna <didier@didierverna.net>

;; This file is part of Declt.

;; Permission to use, copy, modify, and distribute this software for any
;; purpose with or without fee is hereby granted, provided that the above
;; copyright notice and this permission notice appear in all copies.

;; THIS SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


;;; Commentary:


;;; Code:

(in-package :net.didierverna.declt)
(in-readtable :net.didierverna.declt)


;; ==========================================================================
;; Rendering Protocols
;; ==========================================================================

(defgeneric name (object)
  (:documentation "Return OBJECT's name as a string.")
  (:method (object)
    "Princ object to a string."
    (princ-to-string object))
  (:method ((symbol symbol))
    "Return SYMBOL's name."
    (symbol-name symbol))
  (:method ((string string))
    "Return STRING."
    string)
  (:method ((pathname pathname))
    "Return PATHNAME's name."
    (namestring pathname)))



;; ==========================================================================
;; Utilities
;; ==========================================================================

(defun escape (object &optional other-chars)
  "When OBJECT, escape its name for Texinfo.
The escaped characters are @, {, } and optionally a list of OTHER-CHARS."
  (when object
    (coerce (loop :for char across (name object)
		  :if (member char (append '(#\@ #\{ #\}) other-chars))
		    :collect #\@
		  :collect char)
	    'string)))

(defun first-word-length (string)
  "Return the length of the first word in STRING.
Initial whitespace characters are skipped."
  (or (position-if (lambda (char) (member char '(#\space #\tab #\newline)))
		   (string-trim '(#\space #\tab #\newline) string))
      (length string)))

(defun read-next-line (stream)
  "Read one line from STREAM.
Return a list of two values:
- the line itself, or STREAM,
- whether a newline character is missing at the end of the line."
  (multiple-value-list (read-line stream nil stream)))

(defun render-text (text)
  "Render TEXT for Texinfo.
Rendering is done on *standard-output*.
TEXT is assumed to be plain 80 columns.
The rendering takes care of escaping the text for Texinfo, and attempts to
embellish the output by detecting potential paragraphs from standalone lines."
  (when text
    (with-input-from-string (stream text)
      (loop :for (ln1 mnl1p) :=    (read-next-line stream)
			     :then (list ln2 mnl2p)
	    :for (ln2 mnl2p) :=    (read-next-line stream)
			     :then (read-next-line stream)
	    :until (eq ln1 stream)
	    :if (zerop (length ln1))
	      :do (terpri)
	    :else
	      :if (eq ln2 stream)
		:do (format t "~A~@[~%~]" (escape ln1) (not mnl1p))
	    :else
	      :if (> (- 78 (length ln1)) (first-word-length ln2))
		:do (format t "~A@*~%" (escape ln1))
	    :else
	      :do (format t "~A~%" (escape ln1))))))

(defun @anchor (anchor)
  "Render ANCHOR as an @anchor.
ANCHOR is escaped for Texinfo prior to rendering.
Rendering is done on *standard-output*."
  (format t "@anchor{~A}@c~%" (escape anchor)))

(defmacro @tableitem (title &body body)
  "Execute BODY within a table @item TITLE.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@item ~A~%" ,title)
     ,@body))

(defmacro @table ((&optional (kind :@strong)) &body body)
  "Execute BODY within a @table KIND environment.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@table ~(~A~)~%" ,kind)
     ,@body
     (format t "~&@end table~%")))

(defmacro @multitable ((&rest fractions) &body body)
  "Execute BODY within a @multitable environment.
FRACTIONS is the list of column fractions to use.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@multitable @columnfractions~{ ~S~}~%" ',fractions)
     ,@body
     (format t "~&@end multitable~%")))

(defmacro @item (&body body)
  "Execute BODY within an itemize @item.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@item~%")
     ,@body))

(defmacro @itemize ((&optional (kind :@bullet)) &body body)
  "Execute BODY within an @itemize KIND environment.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@itemize ~(~A~)~%" ,kind)
     ,@body
     (format t "~&@end itemize~%")))

(defun @itemize-list
    (list &key renderer (kind :@bullet) (format "~A") (key #'identity))
  "Render a LIST of items within an @itemize KIND environment.
If RENDERER is non-nil, it must be a function of one argument (every LIST
element) that performs the rendering on *standard-output* directly. Otherwise,
the rendering is done by calling format, as explained below.

- FORMAT is the format string to use for every LIST element.
- KEY is a function of one argument (every LIST element) used to provide
  the necessary arguments to the FORMAT string. If multiple arguments are
  needed, they should be returned by KEY as multiple values."
  (@itemize (kind)
    (dolist (elt list)
      (@item
	(if renderer
	    (funcall renderer elt)
	  (apply #'format t format
		 (multiple-value-list (funcall key elt))))))))

(defmacro @defvr (category name &body body)
  "Execute BODY within a @defvr {CATEGORY} NAME environment.
CATEGORY and NAME are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@defvr {~A} ~A~%" (escape ,category) (escape ,name))
     ,@body
     (format t "~&@end defvr~%")))

(defmacro @defconstant (name &body body)
  "Execute BODY within a @defvr {Constant} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@defvr "Constant" ,name ,@body))

(defmacro @defspecial (name &body body)
  "Execute BODY within a @defvr {Special Variable} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@defvr "Special Variable" ,name ,@body))

(defmacro @defsymbolmacro (name &body body)
  "Execute BODY within a @defvr {Symbol Macro} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@defvr "Symbol Macro" ,name ,@body))

(defmacro @defslot (name &body body)
  "Execute BODY within a @defvr {Slot} Name environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@defvr "Slot" ,name ,@body))

(defgeneric pretty-specializer (specializer)
  (:documentation "Return a printable form of SPECIALIZER.")
  (:method (specializer)
    "Return either SPECIALIZER itself, or its class name when appropriate."
    (or (ignore-errors (class-name specializer))
	specializer))
  ;; #### PORTME.
  (:method ((specializer sb-mop:eql-specializer))
    "Return the (eql object) list corresponding to SPECIALIZER in a string."
    (format nil "~A" `(eql ,(sb-mop:eql-specializer-object specializer)))))

;; Based on Edi Weitz's write-lambda-list* from documentation-template.
(defun render-lambda-list (lambda-list &optional specializers
				       &aux (firstp t)
					    after-required-args-p)
  "Render LAMBDA-LIST with potential SPECIALIZERS.
LAMBDA-LIST and SPECIALIZERS are escaped for Texinfo prior to rendering.
Rendering is done on *standard-output*."
  (dolist (part lambda-list)
    (when (and (consp part) after-required-args-p)
      (setq part (first part)))
    (unless firstp
      (write-char #\Space))
    (setq firstp nil)
    (cond ((listp part)
	   (write-char #\()
	   (when (consp part) (render-lambda-list part))
	   (write-char #\)))
	  ((member part '(&optional &rest &key &allow-other-keys
			  &aux &environment &whole &body))
	   (setq after-required-args-p t)
	   (format t "~(~A~)" part))
	  (t
	   (let ((specializer (pretty-specializer (pop specializers))))
	     (if (and specializer (not (eq specializer t)))
		 (format t "(~A @t{~(~A~)})"
		   (escape part)
		   (escape specializer))
	       (write-string (escape part))))))))

(defmacro @deffn ((category name lambda-list &optional specializers qualifiers)
		  &body body)
  "Execute BODY within a @deffn CATEGORY NAME LAMBDA-LIST environment.
CATEGORY, NAME, LAMBDA-LIST, SPECIALIZERS and QUALIFIERS are escaped for
Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@deffn {~A} ~A " (escape ,category) (escape ,name '(#\ )))
     (render-lambda-list ,lambda-list ,specializers)
     (format t "~(~{ @t{~A}~^~}~)~%" (mapcar #'escape ,qualifiers))
     ,@body
     (format t "~&@end deffn~%")))

(defun @deffnx (category name lambda-list &optional specializers qualifiers)
  "Render @deffnx CATEGORY NAME LAMBDA-LIST on *standard-output*.
CATEGORY, NAME, LAMBDA-LIST, SPECIALIZERS and QUALIFIERS are escaped for
Texinfo prior to rendering."
  (format t "~&@deffnx {~A} ~A " (escape category) (escape name '(#\ )))
  (render-lambda-list lambda-list specializers)
  (format t "~(~{ @t{~A}~^~}~)~%" (mapcar #'escape qualifiers)))

(defmacro @defun (name lambda-list &body body)
  "Execute BODY within a @deffn Function NAME LAMBDA-LIST environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  ;; #### NOTE: @DEFUN is implemented in terms of @deffn instead of @defun
  ;; because Texinfo doesn't allow mixing of heterogeneous @def and @defx
  ;; environments. This limitation gets in the way of definition merging
  ;; (e.g. I couldn't nest @defun and @defsetfx).
  `(@deffn ("Function" ,name ,lambda-list)
     ,@body))

(defun @defunx (name lambda-list)
  "Render @deffnx Function NAME LAMBDA-LIST on *standard-output*."
  (@deffnx "Function" name lambda-list))

(defmacro @defmacro (name lambda-list &body body)
  "Execute BODY within a @deffn Macro NAME LAMBDA-LIST environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  ;; #### NOTE: @DEFMACRO is implemented in terms of @deffn instead of @defmac
  ;; because Texinfo doesn't allow mixing of heterogeneous @def and @defx
  ;; environments. This limitation gets in the way of definition merging
  ;; (e.g. I couldn't nest @defmac and @defsetfx).
  `(@deffn ("Macro" ,name ,lambda-list)
     ,@body))

(defmacro @defsetf (name lambda-list &body body)
  "Execute BODY within a @deffn {Setf Expander} NAME LAMBDA-LIST environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deffn ("Setf Expander" ,name ,lambda-list)
     ,@body))

(defun @defsetfx (name lambda-list)
  "Render @deffnx {Setf Expander} NAME LAMBDA-LIST on *standard-output*"
  (@deffnx "Setf Expander" name lambda-list))

(defmacro @defcompilermacro (name lambda-list &body body)
  "Execute BODY within a @deffn {Compiler Macro} NAME LAMBDA-LIST environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deffn ("Compiler Macro" ,name ,lambda-list)
     ,@body))

(defmacro @defgeneric (name lambda-list &body body)
  "Execute BODY within a @deffn {Generic Function} NAME LAMBDA-LIST environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deffn ("Generic Function" ,name ,lambda-list)
     ,@body))

(defun @defgenericx (name lambda-list)
  "Render @deffnx {Generic Function} NAME LAMBDA-LIST on *standard-output*"
  (@deffnx "Generic Function" name lambda-list))

(defmacro @defmethod (name lambda-list specializers qualifiers &body body)
  "Execute BODY within a @deffn {Method} NAME LAMBDA-LIST environment.
NAME, LAMBDA-LIST, SPECIALIZERS and QUALIFIERS are escaped for Texinfo prior
to rendering.
BODY should render on *standard-output*."
  `(@deffn ("Method" ,name ,lambda-list ,specializers ,qualifiers)
     ,@body))

(defun @defmethodx (name lambda-list specializers qualifiers)
  "Render @deffnx {Method} NAME LAMBDA-LIST on *standard-output*.
NAME, LAMBDA-LIST, SPECIALIZERS and QUALIFIERS are escaped for Texinfo prior
to rendering."
  (@deffnx "Method" name lambda-list specializers qualifiers))

(defmacro @deftp ((category name &optional lambda-list) &body body)
  "Execute BODY within a @deftp {CATEGORY} NAME [LAMBDA-LIST] environment.
CATEGORY, NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(progn
     (format t "~&@deftp {~A} ~A "  (escape ,category) (escape ,name '(#\ )))
     (render-lambda-list ,lambda-list)
     (fresh-line)
     ,@body
     (format t "~&@end deftp~%")))

(defmacro @defcombination (name kind &body body)
  "Execute BODY within a @deftp {KIND Method Combination} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deftp (,(format nil "~@(~A~) Method Combination" kind) ,name) ,@body))

(defmacro @defstruct (name &body body)
  "Execute BODY within a @deftp {Structure} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deftp ("Structure" ,name) ,@body))

(defmacro @defcond (name &body body)
  "Execute BODY within a @deftp {Condition} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deftp ("Condition" ,name) ,@body))

(defmacro @defclass (name &body body)
  "Execute BODY within a @deftp {Class} NAME environment.
NAME is escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deftp ("Class" ,name) ,@body))

(defmacro @deftype ((name &optional lambda-list) &body body)
  "Execute BODY within a @deftp {Type} NAME [LAMBDA-LIST] environment.
NAME and LAMBDA-LIST are escaped for Texinfo prior to rendering.
BODY should render on *standard-output*."
  `(@deftp ("Type" ,name ,lambda-list) ,@body))

(defmacro render-to-string (&body body)
  "Execute BODY with *standard-output* redirected to a string.
Return that string."
  `(with-output-to-string (*standard-output*)
     ,@body))



;; ==========================================================================
;; Node Implementation
;; ==========================================================================

(defparameter *section-names*
  '((:numbered   nil
     "chapter"    "section"       "subsection"       "subsubsection")
    (:unnumbered "top"
     "unnumbered" "unnumberedsec" "unnumberedsubsec" "unnumberedsubsubsec")
    (:appendix   nil
     "appendix"   "appendixsec"   "appendixsubsec"   "appendixsubsubsec" ))
  "The numbered, unumbered and appendix section names sorted by level.")

;; #### NOTE: all contents in the NODE structure must be already escaped for
;; Texinfo.
(defstruct node
  "The NODE structure.
This structure holds Texinfo nodes."
  name                      ;; node name
  synopsis                  ;; node menu description
  (section-type :numbered)  ;; see *section-names*
  section-name              ;; alternate name for section
  next                      ;; next node
  previous                  ;; previous node (or up)
  up                        ;; parent node
  children                  ;; list of sub-nodes
  before-menu-contents      ;; contents before the menu
  after-menu-contents)      ;; contents after the menu

#i(add-child 1)
(defun add-child (parent child
		  &aux (previous (car (last (node-children parent)))))
  "Add CHILD node to PARENT node and return CHILD."
  (cond (previous
	 (setf (node-next previous) child)
	 (endpush child (node-children parent)))
	(t
	 (setf (node-children parent) (list child))))
  (setf (node-previous child) previous)
  (setf (node-up child) parent)
  child)

(defun render-node (node level)
  "Render NODE at LEVEL and all its children at LEVEL+1."
  (cond ((<= level 1)
	 (format t "


@c ====================================================================
@c ~A
@c ====================================================================~%"
	   (node-name node)))
	((= level 2)
	 (let ((separator (make-string (length (node-name node))
			    :initial-element #\-)))
	   (format t
		   "

@c ~A
@c ~A
@c ~A~%"
	     separator (node-name node) separator)))
	(t (terpri)))
  (when (= level 0)
    (format t "@ifnottex~%"))
  (format t "@node ~A, ~@[~A~], ~@[~A~], ~A~%"
    (node-name node)
    (or (when (= level 0)
	  (node-name (first (node-children node))))
	(when (node-next node)
	  (node-name (node-next node))))
    (or (when (= level 0)
	  "(dir)")
	(when (node-previous node)
	  (node-name (node-previous node)))
	(node-name (node-up node)))
    (if (= level 0)
	"(dir)"
      (node-name (node-up node))))
  (format t "@~A ~A~%"
    (nth level (cdr (assoc (node-section-type node) *section-names*)))
    (or (node-section-name node) (node-name node)))
  (when (node-before-menu-contents node)
    (write-string (node-before-menu-contents node))
    (fresh-line))
  (when (node-children node)
    (when (node-before-menu-contents node)
      (terpri))
    (format t "@menu~%")
    (dolist (child (node-children node))
      ;; #### FIXME: this could be improved with proper alignment of synopsis.
      (format t "* ~A::~@[ ~A~]~%" (node-name child) (node-synopsis child)))
    (format t "@end menu~%"))
  (when (node-after-menu-contents node)
    (when (or (node-children node) (node-before-menu-contents node))
      (terpri))
    (write-string (node-after-menu-contents node))
    (fresh-line))
  (when (= level 0)
    (format t "@end ifnottex~%"))
  (dolist (child (node-children node))
    (render-node child (1+ level))))

(defun render-top-node (node)
  "Render the whole nodes hierarchy starting at toplevel NODE."
  (render-node node 0)
  (values))

;;; texi.lisp ends here