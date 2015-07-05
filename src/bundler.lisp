(in-package :cl-user)
(defpackage ceramic.bundler
  (:use :cl)
  (:import-from :ceramic.util
                :copy-directory)
  (:import-from :ceramic.file
                :*ceramic-directory*)
  (:import-from :ceramic.resource
                :copy-resources)
  (:export :bundle)
  (:documentation "Release applications."))
(in-package :ceramic.bundler)

(defun bundle (system-name &key output)
  (asdf:load-system system-name)
  (let* ((application-name (string-downcase
                            (symbol-name system-name)))
         (bundle (make-pathname :name application-name
                                :type "zip"))
         (bundle-pathname (or output
                              (asdf:system-relative-pathname system-name
                                                             bundle)))
         (work-directory (merge-pathnames #p"working/"
                                          *ceramic-directory*))
         (executable-pathname (merge-pathnames (make-pathname :name application-name)
                                               work-directory)))
    ;; We do everything inside the work directory, then zip it up and delete it
    (ensure-directories-exist work-directory)
    (unwind-protect
         (progn
           (format t "~&Copying resources...")
           ;; Copy application resources
           (copy-resources (merge-pathnames #p"resources/"
                                            work-directory))
           ;; Copy the electron directory
           (copy-directory (ceramic.electron:release-directory)
                           (merge-pathnames #p"electron/"
                                            work-directory))
           ;; Compile the app
           (format t "~&Compiling app...")
           (ceramic.build:build :system-name system-name
                                :eval "(push :ceramic-release *features*)"
                                :output-pathname executable-pathname
                                :entry-point (concatenate 'string
                                                          "ceramic-entry::"
                                                          (string-downcase
                                                           (symbol-name system-name))))
           ;; Zip up the folder
           (format t "~&Compressing...")
           (when (probe-file bundle-pathname)
             (format t "~&Found existing bundle, deleting...")
             (delete-file bundle-pathname))
           (zip:zip bundle-pathname work-directory))
      (uiop:delete-directory-tree work-directory :validate t)
      bundle-pathname)))
