;;; doc.lisp --- Items documentation

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
;; Documentation Contexts
;; ==========================================================================

(defstruct context
  "The documentation context structure."
  systems
  packages
  external-definitions
  internal-definitions
  hyperlinksp)


;; This is used rather often so it is worth a shortcut
(defun context-directory (context)
  "Return CONTEXT's main system directory."
  (system-directory (car (context-systems context))))



;; ==========================================================================
;; Documentation Protocols
;; ==========================================================================

(defgeneric title (item &optional relative-to)
  (:documentation "Return ITEM's title."))

(defgeneric index (item &optional relative-to)
  (:documentation "Render ITEM's indexing command."))

;; #### FIXME: methods on this function contain Texinfo code. There should be
;; an @ref function in ../utils/texi.lisp.
(defgeneric reference (item &optional relative-to)
  (:documentation "Render ITEM's reference."))

(defgeneric document (item context &key &allow-other-keys)
  (:documentation "Render ITEM's documentation in CONTEXT."))



;; ==========================================================================
;; Utilities
;; ==========================================================================

;; Since node references are boring in Texinfo, we prefer to create custom
;; anchors for our items and link to them instead.
(defun anchor-name (item &optional relative-to)
  "Return ITEM's anchor name."
  (format nil "go to ~A" (title item relative-to)))

(defun anchor (item &optional relative-to)
  "Render ITEM's anchor."
  (@anchor (anchor-name item relative-to)))

(defun anchor-and-index (item &optional relative-to)
  "Anchor and index ITEM."
  (anchor item relative-to)
  (index item relative-to))


;; #### NOTE: the use of PROBE-FILE below has two purposes:
;; 1/ making sure that the file does exist, so that it can actually be linked
;;    properly,
;; 2/ dereferencing an (ASDF 1) installed system file symlink (what we get) in
;;    order to link the actual file (what we want).
;; #### FIXME: not a Declt bug, but currently, SBCL sets the source file of
;; COPY-<struct> functions to its own target-defstruct.lisp file.
(defun render-location
    (pathname context
     &optional (title "Location")
     &aux (probed-pathname (probe-file pathname))
	  (relative-to (context-directory context))
	  (hyperlinkp (and (context-hyperlinksp context) probed-pathname)))
  "Render an itemized location line for PATHNAME in CONTEXT.
Rendering is done on *standard-output*."
  (@tableitem title
    (format t "~@[@url{file://~A, ignore, ~]@t{~A}~:[~;}~]~%"
      (when hyperlinkp
	(escape probed-pathname))
      (escape (if probed-pathname
		  (enough-namestring probed-pathname relative-to)
		(concatenate 'string (namestring pathname)
			     " (not found)")))
      hyperlinkp)))

(defun render-source (item context)
  "Render an itemized source line for ITEM in CONTEXT.
Rendering is done on *standard-output*."
  (when-let ((source-pathname (source item)))
    (let* ((systems (context-systems context))
	   (relative-to (context-directory context))
	   ;; Remember that a source can be a system, although systems are not
	   ;; actual cl-source-file's.
	   (source-component
	     (loop :for component
		     :in (append systems (mapcan #'lisp-components systems))
		   :when (equal source-pathname
				(component-pathname component))
		     :return component)))
      (if source-component
	  (@tableitem "Source" (reference source-component relative-to))
	  ;; Otherwise, the source does not belong to the system. This may
	  ;; happen for automatically generated sources (sb-grovel does this
	  ;; for instance). So let's just reference the file itself.
	  (render-location source-pathname context "Source")))))

(defun render-docstring (item)
  "Render ITEM's documentation string.
Rendering is done on *standard-output*."
  (when-let ((docstring (docstring item)))
    (render-text docstring)))

(defun render-references (list title &aux (length (length list)))
  "Render references to a LIST of items.
References are rendered in a table item named TITLE as a list, unless there is
only one item in LIST.

Rendering is done on *standard-output*."
  (unless (zerop length)
    (@tableitem title
      (if (= length 1)
	  (reference (first list))
	(@itemize-list list :renderer #'reference)))))


;;; doc.lisp ends here
