;;; doc.lisp --- Items documentation

;; Copyright (C) 2010, 2011 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>

;; This file is part of Declt.

;; Declt is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License version 3,
;; as published by the Free Software Foundation

;; Declt is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:

;; Contents management by FCM version 0.1.


;;; Code:

(in-package :com.dvlsoft.declt)


;; ==========================================================================
;; Documentation Protocols
;; ==========================================================================

(defgeneric title (item &optional relative-to)
  (:documentation "Return ITEM's title."))

(defgeneric index (item &optional relative-to)
  (:documentation "Render ITEM's indexing command."))

(defgeneric reference (item &optional relative-to)
  (:documentation "Render ITEM's reference."))

(defgeneric document (item system &key &allow-other-keys)
  (:documentation "Render SYSTEM's ITEM's documentation."))



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

(defvar *link-files* t
  "Whether to create links to files or directories in the reference manual.
When true (the default), pathnames are made clickable although the links are
specific to the machine on which the manual was generated.

Setting this to NIL is preferable for creating reference manuals meant to put
online, and hence independent of any specific installation.")

;; #### NOTE: the use of PROBE-FILE below has two purposes:
;; 1/ making sure that the file does exist, so that it can actually be linked
;;    properly,
;; 2/ dereferencing an (ASDF 1) installed system file symlink (what we get) in
;;    order to link the actual file (what we want).
;; #### FIXME: not a Declt bug, but currently, SBCL sets the source file of
;; COPY-<struct> functions to its own target-defstruct.lisp file.
(defun render-location (pathname relative-to
			&optional (title "Location")
			&aux (probed-pathname (probe-file pathname))
			     (link-files (and *link-files* probed-pathname)))
  "Render an itemized location line for PATHNAME, RELATIVE-TO.
Rendering is done on *standard-output*."
  (@tableitem title
    (format t "~@[@url{file://~A, ignore, ~]@t{~A}~:[~;}~]~%"
      (when link-files
	(escape probed-pathname))
      (escape (if probed-pathname
		  (enough-namestring probed-pathname relative-to)
		(concatenate 'string (namestring pathname)
			     " (not found)")))
      link-files)))

(defun render-source (object system &aux (source (source object)))
  "Render an itemized source line for SYSTEM's OBJECT.
Rendering is done on *standard-output*."
  (when source
    (cond
      ;; First, try the system definition file.
      ((equal source (system-definition-pathname system))
       ;; #### NOTE: Probing the pathname as the virtue of dereferencing
       ;; symlinks. This is good because when the system definition file is
       ;; involved, it is the installed symlink which is seen, whereas we want
       ;; to advertise the original one.
       (let ((location
	      (escape (enough-namestring (probe-file source)
					 (system-directory system)))))
	 (@tableitem "Source"
	   ;; #### FIXME: somewhat ugly. We fake a cl-source-file anchor name.
	   (format t "@ref{go to the ~A file, , @t{~(~A}~)} (Lisp file)~%"
	     location
	     location))))
      (t
       ;; Next, try a SYSTEM's cl-source-file.
       (let ((cl-source-file
	      (loop :for file :in (lisp-components system)
		    :when (equal source (component-pathname file))
		      :return file)))
	 (if cl-source-file
	     (@tableitem "Source"
	       (reference cl-source-file (system-directory system)))
	   ;; Otherwise, the source file does not belong to the system. This
	   ;; may happen for automatically generated sources (sb-grovel does
	   ;; this for instance). So let's just reference the file itself.
	   (render-location source (system-directory system) "Source")))))))


;;; doc.lisp ends here
