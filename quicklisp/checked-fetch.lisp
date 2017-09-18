;;;; checked-fetch.lisp

(in-package #:ql-http)

(define-condition verification-error (error) ())
(define-condition unexpected-sha256-error (verification-error) ())
(define-condition signature-verification-error (verification-error) ())

(defun openpgp-signature-url (url)
  (etypecase url
    (string
     (format nil "~A.asc" url))
    (url
     (format nil "~A.asc" (urlstring url)))))

(defun fetch-digest-checked (url output expected-digest &key quietly)
  "Fetch the data at URL and save to the file OUTPUT. The
  EXPECTED-DIGEST value of OBJECT is checked against the actual SHA256
  digest of the retrieved file, and if they match, the output file is
  returned, otherwise an UNEXPECTED-SHA256-ERROR is signaled."
  (with-temp-output-file (file "digest-checked.dat")
    (fetch url file :quietly quietly)
    (let ((actual-digest (file-sha-string 'sha256 file)))
      (unless (equalp actual-digest expected-digest)
        (error 'unexpected-sha256-error)))
    (rename-mundanely file output)
    (probe-file output)))

(defun fetch-openpgp-checked (url output &key quietly)
  (with-temp-output-files ((file "openpgp-checked.dat")
                           (sig "openpgp-signature.asc"))
    (let ((sig-url (openpgp-signature-url url)))
      (fetch sig-url sig :quietly quietly)
      (fetch url file :quietly quietly)
      (let* ((signature (ql-openpgp:load-signature sig))
             (id (ql-openpgp:key-id-string signature))
             (key (ql-openpgp:find-key id)))
        (unless key
          (error "No key available for id ~S" id))
        (let ((result (ql-openpgp:verify-signature file signature key)))
          (unless result
            (error "Signature failed for file ~A"
                   output))
          (unless quietly
            (format t "~&; Signature check result: ~A~%" result)))
        (rename-mundanely file output)))))