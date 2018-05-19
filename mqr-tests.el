;;; mqr-tests.el --- Test suite for multi-replace.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Tino Calancha

;; Author: Tino Calancha <tino.calancha@gmail.com>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:


(require 'ert)
(require 'mqr)
(eval-when-compile (require 'cl-lib))

(ert-deftest mqr-tests ()
  (with-temp-buffer
    (insert "foo bar baz")
    (mqr-replace '(("foo" . "aaa") ("bar" . "bbb") ("baz" . "ccc")))
    (should (equal (buffer-string) "aaa bbb ccc")))
  ;; Must work when special regxp symbols are present, e.g. '[', ']'.
  (with-temp-buffer
    (insert "[foo")
    (mqr-replace '(("foo" . "bar") ("[" . "the-")))
    (should (equal (buffer-string) "the-bar"))))

(ert-deftest mqr-tests-regexp ()
  (with-temp-buffer
    (insert "foo-123 bar-32 baz-10z99")
    (mqr-replace-regexp '(("foo-\\([0-9]+\\)" . "aaa-\\1")
                                    ("bar-\\([0-9]+\\)" . "bbb-\\1")
                                    ("baz-\\([0-9]+\\)\\([a-z]\\)\\([0-9]+\\)" . "ccc-\\1\\2\\3")))
    (should (equal (buffer-string) "aaa-123 bbb-32 ccc-10z99"))))


(ert-deftest mqr-query-replace-undo-bug31492 ()
  "Test for https://debbugs.gnu.org/31492 ."
  (let ((text "a\nb\nc\n")
        (count 0)
        (inhibit-message t))
    (with-temp-buffer
      (insert text)
      (goto-char 1)
      (cl-letf (((symbol-function 'read-event)
                 (lambda (&rest args)
                   (cl-incf count)
                   (let ((val (pcase count
                                ((or 1 2) ?\s) ; replace current and go next
                                (3 ?U) ; undo-all
                                (_ ?q)))) ; exit
                     val))))
        (let ((mqr-alist (list (cons "^\\|\b\\|$" "foo")))
              (mqr--regexp-replace t))
          (mqr-perform-replace "^\\|\b\\|$" '("") t t nil)))
      ;; After undo text must be the same.
      (should (string= text (buffer-string))))))

(provide 'mqr-tests)
;;; mqr-tests.el ends here
