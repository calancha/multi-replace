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



;;; Tests for `query-replace' undo feature.
(defun mqr-tests-clauses (char-nums def-chr)
  "Build the clauses of the `pcase' in `mqr-tests-with-undo'.
CHAR-NUMS is a list of elements (CHAR . NUMS).
CHAR is one of the chars ?, ?\s ?u ?U ?E ?q.
NUMS is a list of integers; they are the patters to match,
while CHAR is the return value.
DEF-CHAR is the default character to return in the `pcase'
when any of the clauses match."
  (append
   (delq nil
         (mapcar (lambda (chr)
                   (if (cadr (assq chr char-nums))
                       (let ((it (cadr (assq chr char-nums))))
                         (if (cdr it)
                             `(,(cons 'or it) ,chr)
                           `(,(car it) ,chr)))))
                 '(?, ?\s ?u ?U ?E ?q)))
   `((_ ,def-chr))))

(defvar mqr-tests-bind-read-string nil
  "A string to bind `read-string' and avoid the prompt.")

(defmacro mqr-tests-with-undo (input from to char-nums def-chr &rest body)
  "Helper to test `query-replace' undo feature.
INPUT is a string to insert in a temporary buffer.
FROM is the string to match for replace.
TO is the replacement string.
CHAR-NUMS is a list of elements (CHAR . NUMS).
CHAR is one of the chars ?, ?\s ?u ?U ?E ?q.
NUMS is a list of integers.
DEF-CHAR is the char ?\s or ?q.
BODY is a list of forms.
Return the last evaled form in BODY."
  (declare (indent 5) (debug (stringp stringp stringp form characterp body)))
  (let ((text (make-symbol "text"))
        (count (make-symbol "count")))
    `(let* ((,text ,input)
            (,count 0)
            (inhibit-message t))
       (with-temp-buffer
         (insert ,text)
         (goto-char 1)
         ;; Bind `read-event' to simulate user input.
         ;; If `mqr-tests-bind-read-string' is non-nil, then
         ;; bind `read-string' as well.
         (cl-letf (((symbol-function 'read-event)
                    (lambda (&rest args)
                      (cl-incf ,count)
                      (let ((val
                             (pcase ,count
                               ,@(mqr-tests-clauses char-nums def-chr))))
                        val)))
                   ((symbol-function 'read-string)
                    (if mqr-tests-bind-read-string
                        (lambda (&rest args) mqr-tests-bind-read-string)
                      (symbol-function 'read-string))))
           (let ((mqr-alist (list (cons ,from ,to)))
                 (mqr--regexp-replace t))
             (mqr-perform-replace ,from '("") t t nil)))
         ,@body))))

(defun mqr-tests--query-replace-undo (&optional comma)
  (let ((input "111"))
    (if comma
        (should
         (mqr-tests-with-undo
          input "1" "2" ((?, (2)) (?u (3)) (?q (4))) ?\s (buffer-string)))
      (should
       (mqr-tests-with-undo
        input "1" "2" ((?\s (2)) (?u (3)) (?q (4))) ?\s (buffer-string))))))

(ert-deftest mqr--undo ()
  (should (string= "211" (mqr-tests--query-replace-undo)))
  ;; FIXME: The test with 'comma fails
  ;; (when (>= emacs-major-version 25)
  ;;   (should (string= "211" (mqr-tests--query-replace-undo 'comma))))
  )

(ert-deftest mqr-undo-bug31073 ()
  "Test for https://debbugs.gnu.org/31073 ."
  (let ((input "aaa aaa"))
    (should
     (mqr-tests-with-undo
      input "a" "B" ((?\s (1 2 3)) (?U (4))) ?q
      (string= input (buffer-string))))))

(ert-deftest mqr-undo-bug31492 ()
  "Test for https://debbugs.gnu.org/31492 ."
  (let ((input "a\nb\nc\n"))
    (should
     (mqr-tests-with-undo
      input "^\\|\b\\|$" "foo" ((?\s (1 2)) (?U (3))) ?q
      (string= input (buffer-string))))))

(ert-deftest mqr-undo-bug31538 ()
  "Test for https://debbugs.gnu.org/31538 ."
  (let ((input "aaa aaa")
        (mqr-tests-bind-read-string "Bfoo"))
    (should
     (mqr-tests-with-undo
      input "a" "B" ((?\s (1 2 3)) (?E (4)) (?U (5))) ?q
      (string= input (buffer-string))))))

(provide 'mqr-tests)
;;; mqr-tests.el ends here
