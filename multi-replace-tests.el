;;; multi-replace-tests.el --- Test suite for multi-replace.el  -*- lexical-binding: t; -*-

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
(require 'multi-replace)

(ert-deftest multi-replace-tests ()
  (with-temp-buffer
    (insert "foo bar baz")
    (mrep-replace-regexp '(("foo" . "aaa") ("bar" . "bbb") ("baz" . "ccc")))
    (should (equal (buffer-string) "aaa bbb ccc"))))



(provide 'multi-replace-tests)
;;; multi-replace-tests.el ends here
