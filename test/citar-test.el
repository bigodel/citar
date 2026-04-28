;;; citar-file-test.el --- Tests for citar.el  -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(require 'ert)
(require 'citar)
(require 'map)

(ert-deftest citar-test--check-notes-sources ()
  ;; This should run without signalling an error
  (should-not (ignore (map-do #'citar--check-notes-source citar-notes-sources))))

(ert-deftest citar-test--bibliography-files-global-only ()
  "Existing global bibliography is returned."
  (let ((tmp (make-temp-file "citar-test-global" nil ".bib")))
    (unwind-protect
         (let ((citar-bibliography (list tmp))
               (citar-major-mode-functions
                '((t . ((local-bib-files . ignore))))))
           (should (member (file-truename tmp)
                           (citar--bibliography-files))))
      (delete-file tmp))))

(ert-deftest citar-test--bibliography-files-missing-global-errors ()
  "Missing global bibliography signals a `user-error'."
  (let ((citar-bibliography '("/tmp/citar-test-nonexistent-glob.bib"))
        (citar-major-mode-functions
         '((t . ((local-bib-files . ignore))))))
    (should-error (citar--bibliography-files) :type 'user-error)))

(ert-deftest citar-test--bibliography-files-missing-local-filtered ()
  "Missing local bibliography is silently filtered."
  (let ((tmp (make-temp-file "citar-test-glob" nil ".bib"))
        (missing "/tmp/citar-test-nonexistent-local.bib"))
    (unwind-protect
         (let* ((citar-bibliography (list tmp))
                (citar-major-mode-functions
                 `((t . ((local-bib-files . ,(lambda () (list missing)))))))
                (result (citar--bibliography-files)))
           (should (member (file-truename tmp) result))
           (should-not (member missing result))
           (should-not (member (file-truename missing) result)))
      (delete-file tmp))))

(ert-deftest citar-test--bibliography-files-existing-local-included ()
  "Existing local bibliography is included."
  (let ((tmp-glob (make-temp-file "citar-test-glob" nil ".bib"))
        (tmp-local (make-temp-file "citar-test-local" nil ".bib")))
    (unwind-protect
         (let* ((citar-bibliography (list tmp-glob))
                (citar-major-mode-functions
                 `((t . ((local-bib-files . ,(lambda () (list tmp-local)))))))
                (result (citar--bibliography-files)))
           (should (member (file-truename tmp-glob) result))
           (should (member (file-truename tmp-local) result)))
      (delete-file tmp-glob)
      (delete-file tmp-local))))

(ert-deftest citar-test--local-bibtex-base-name-fallback ()
  "Returns \"references\" when buffer has no local bibliography."
  (let ((citar-major-mode-functions `((t . ((local-bib-files . ignore))))))
    (should (string= "references" (citar-local-bibtex-base-name)))))

(ert-deftest citar-test--local-bibtex-base-name-from-local ()
  "Returns the basename of the first local bibliography file."
  (let ((citar-major-mode-functions
         `((t . ((local-bib-files
                  . ,(lambda (&rest _) '("/tmp/projectA.bib"
                                         "/tmp/projectB.bib"))))))))
    (should (string= "projectA" (citar-local-bibtex-base-name)))))

(ert-deftest citar-test--export-local-bibtex-file-writes-citations ()
  "Writes cited entries to FILENAME."
  (let* ((source (make-temp-file "citar-test-src" nil ".bib"))
         (target (file-name-with-extension
                  (make-temp-name
                   (concat temporary-file-directory "citar-test-tgt"))
                  "bib"))
         (entry-foo "@article{foo2026,\n title = {Foo},\n author = {Alice}\n}\n")
         (entry-bar "@article{bar2026,\n title = {Bar},\n author = {Bob}\n}\n"))
    (unwind-protect
         (progn
           (with-temp-file source
             (insert entry-foo entry-bar))
           (let ((citar-bibliography (list source))
                 (citar-major-mode-functions
                  `((t . ((list-keys . ,(lambda () '("foo2026")))
                          (local-bib-files . ignore))))))
             (citar-export-local-bibtex-file target))
           (should (file-exists-p target))
           (with-temp-buffer
             (insert-file-contents target)
             (should (string-match entry-foo (buffer-string)))))
      (delete-file source)
      (delete-file target))))

(ert-deftest citar-test--export-local-bibtex-base-name-string-used ()
  "When `citar-export-local-bibtex-base-name' is a string, exported file is named after it."
  (let* ((default-directory temporary-file-directory)
         (source (make-temp-file "citar-test-src" nil ".bib"))
         (host (expand-file-name "project.org"))
         (basename "local-bib")
         (expected (expand-file-name (concat basename ".bib")))
         (entry "@article{foo2026,\n title = {Foo}\n}\n"))
    (unwind-protect
         (progn
           (with-temp-file source (insert entry))
           (with-current-buffer (find-file-literally host)
             (let ((current-prefix-arg nil)
                   (citar-export-local-bibtex-base-name basename)
                   (citar-bibliography (list source))
                   (citar-major-mode-functions
                    `((t . ((list-keys . ,(lambda () '("foo2026")))
                            (local-bib-files . ignore)))))
                   (kill-buffer-query-functions nil))
               (call-interactively #'citar-export-local-bibtex-file))
             (kill-buffer))
           (should (file-exists-p expected)))
      (delete-file source)
      (delete-file expected))))

(provide 'citar-test)
;;; citar-test.el ends here
