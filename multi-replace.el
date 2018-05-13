;;; multi-replace.el --- Multi-dimensional query and replace  -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Tino Calancha

;; Filename: multi-replace.el
;; Description: Multi-dimensional query and replace

;; Author: Tino Calancha <tino.calancha@gmail.com>
;; Maintainer: Tino Calancha <tino.calancha@gmail.com>
;; Keywords: convenience, extensions, lisp
;; Created: Sat May 12 22:09:30 JST 2018
;; Version: 0.1.1
;; Package-Requires: ((emacs "26.1") (cl-lib "0.5"))
;;

;;; Commentary:
;; This lib defines the commands `mrep-multi-replace',
;; `mrep-multi-replace-regexp', `mrep-query-replace' and
;; `mrep-query-replace-regexp' to match and replace several regexps
;; in the region.
;;
;; Interactively, prompt the user for the regexps and their replacements.
;; If the region is active, then the commands act on the active region.
;; Otherwise, they act on the entire buffer.
;;
;; To use this library, save this file in a directory included in
;; your `load-path'.  Then, add the following line into your .emacs:
;;
;; (require 'multi-replace)
;;
;; You might want to bind `mrep-query-replace', `mrep-query-replace-regexp'
;; to some easy to remember keys.  If you have the Hyper key, then the
;; following combos are analogs to those for the Vanila Emacs commands:
;;
;; (define-key global-map (kbd "H-%") 'mrep-query-replace)
;; (define-key global-map (kbd "C-H-%") 'mrep-query-replace-regexp)
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This file is NOT part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)

(defvar mrep-query-replace-alist nil
  "List of conses (REGEXP . REPLACEMENT).")

(defun mrep-query-replace-alist (regexp-list replacements)
  "Make an alist with the elements of REGEXP-LIST and REPLACEMENETS.
Each element is a cons (REGEXP . REPLACEMENT)."
  (let (res)
    (dotimes (i (length regexp-list))
      (push (cons (nth i regexp-list) (nth i replacements)) res))
    (nreverse res)))

(defun mrep--replacement (regexp)
  "Return the replacement for REGEXP."
  (save-match-data
    (cdr
     (cl-assoc-if-not (lambda (s) (null (string-match s regexp)))
                      mrep-query-replace-alist))))

(defun mrep--replace-interactive-spec (prompt)
  (let ((alist '())
        (start (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max)))
        (regexp)
        (replace))
    (while (not (equal regexp ""))
      (let (query-replace-defaults)
        (setq regexp (query-replace-read-from prompt nil))
	    (setq query-replace-defaults nil)
        (unless (equal regexp "")
          (setq replace (query-replace-read-to
                         regexp (format "%s %s with" prompt regexp) nil))
          (setq query-replace-defaults nil)
          (push (cons regexp replace) alist))))
    (list (nreverse alist) start end)))

(defun mrep--multi-replace (alist &optional start end regexp-flag)
  (unless start (setq start (point-min)))
  (unless end (setq end (point-max)))
  (let ((regexp
         (if regexp-flag (mapconcat #'identity (mapcar #'car alist) "\\|")
           (regexp-opt (mapcar #'car alist))))
        (mrep-query-replace-alist alist))
    (save-excursion
      (goto-char start)
      (while (re-search-forward regexp nil end)
        (let ((replacement (mrep--replacement (match-string 0))))
          (replace-match replacement))))))

(defun mrep-multi-replace (alist &optional start end)
  "Match and replace several strings.
ALIST is a list of conses (STRING . TO).
START and END define the region where look for matches.  If the
region is active, then they default to `region-beginning'
and `region-end'.  Otherwise, apply the command in the entire buffer.

Interactively, prompt user for the conses (STRING . TO) until
the user inputs '' for STRING."
  (interactive (mrep--replace-interactive-spec "Multi replace"))
  (mrep--multi-replace alist start end))

(defun mrep-multi-replace-regexp (alist &optional start end)
  "Match and replace several regexps.
ALIST is a list of conses (REGEXP . TO).
START and END define the region where look for matches.  If the
region is active, then they default to `region-beginning'
and `region-end'.  Otherwise, apply the command in the entire buffer.

Interactively, prompt user for the conses (REGEXP . TO) until
the user inputs '' for REGEXP."
  (interactive (mrep--replace-interactive-spec "Multi replace regexp"))
  (mrep--multi-replace alist start end 'regexp-flag))

(defalias 'mrep-replace 'mrep-multi-replace)
(defalias 'mrep-replace-regexp 'mrep-multi-replace-regexp)


;;; Multi query replace

(defun mrep--query-replace-interactive-spec (prompt)
  (let* ((common (mrep--replace-interactive-spec prompt))
         (regexp-list (mapcar #'car (car common)))
         (replacements (mapcar #'cdr (car common))))
    (setq mrep-query-replace-alist
          (mrep-query-replace-alist regexp-list replacements))
    (list (car common)
          nil
          (cadr common)
          (caddr common)
          (and current-prefix-arg (eq current-prefix-arg '-))
          (and (use-region-p) (region-noncontiguous-p)))))

;;; Modify `perform-replace' to handle multiple regexp input.
(defun mrep-perform-replace (from-string replacements
		                                 query-flag regexp-flag delimited-flag
			                             &optional _repeat-count map start end backward region-noncontiguous-p)
  (or map (setq map query-replace-map))
  (and query-flag minibuffer-auto-raise
       (raise-frame (window-frame (minibuffer-window))))
  (let* ((case-fold-search
	      (if (and case-fold-search search-upper-case)
	          (if (consp from-string)
                  (cl-every
                   (lambda (str) (isearch-no-upper-case-p str regexp-flag))
                   from-string)
                (isearch-no-upper-case-p from-string regexp-flag))
	        case-fold-search))
         (nocasify (not (and case-replace case-fold-search)))
         (literal (or (not regexp-flag) (eq regexp-flag 'literal)))
         (search-string from-string)
         (real-match-data nil)       ; The match data for the current match.
         (next-replacement nil)
         ;; This is non-nil if we know there is nothing for the user
         ;; to edit in the replacement.
         (noedit nil)
         (keep-going t)
         (stack nil)
         (search-string-replaced nil)    ; last string matching `from-string'
         (next-replacement-replaced nil) ; replacement string
                                        ; (substituted regexp)
         (last-was-undo)
         (last-was-act-and-show)
         (update-stack t)
         (replace-count 0)
         (skip-read-only-count 0)
         (skip-filtered-count 0)
         (skip-invisible-count 0)
         (nonempty-match nil)
	     (multi-buffer nil)
	     (recenter-last-op nil)	; Start cycling order with initial position.

         ;; If non-nil, it is marker saying where in the buffer to stop.
         (limit nil)
         ;; Use local binding in add-function below.
         (isearch-filter-predicate isearch-filter-predicate)
         (region-bounds nil)

         ;; Data for the next match.  If a cons, it has the same format as
         ;; (match-data); otherwise it is t if a match is possible at point.
         (match-again t)

         (message
          (if query-flag
              (apply 'propertize
                     (concat "Query replacing "
                             (if backward "backward " "")
                             (if delimited-flag
                                 (or (and (symbolp delimited-flag)
                                          (get delimited-flag
                                               'isearch-message-prefix))
                                     "word ") "")
                             (if regexp-flag "regexp " "")
                             "%s with %s: "
                             (substitute-command-keys
                              "(\\<query-replace-map>\\[help] for help) "))
                     minibuffer-prompt-properties))))

    ;; Unless a single contiguous chunk is selected, operate on multiple chunks.
    (when region-noncontiguous-p
      (setq region-bounds
            (mapcar (lambda (position)
                      (cons (copy-marker (car position))
                            (copy-marker (cdr position))))
                    (funcall region-extract-function 'bounds)))
      (add-function :after-while isearch-filter-predicate
                    (lambda (start end)
                      (delq nil (mapcar
                                 (lambda (bounds)
                                   (and
                                    (>= start (car bounds))
                                    (<= start (cdr bounds))
                                    (>= end   (car bounds))
                                    (<= end   (cdr bounds))))
                                 region-bounds)))))

    ;; If region is active, in Transient Mark mode, operate on region.
    (if backward
	    (when end
	      (setq limit (copy-marker (min start end)))
	      (goto-char (max start end))
	      (deactivate-mark))
      (when start
	    (setq limit (copy-marker (max start end)))
	    (goto-char (min start end))
	    (deactivate-mark)))

    ;; If last typed key in previous call of multi-buffer perform-replace
    ;; was `automatic-all', don't ask more questions in next files
    (when (eq (lookup-key map (vector last-input-event)) 'automatic-all)
      (setq query-flag nil multi-buffer t))

    (when real-match-data
      (setq next-replacement
            (mrep--replacement
             (buffer-substring-no-properties (match-beginning 0) (match-end 0)))))
    (when query-replace-lazy-highlight
      (setq isearch-lazy-highlight-last-string nil))

    (push-mark)
    (undo-boundary)
    (unwind-protect
	    ;; Loop finding occurrences that perhaps should be replaced.
	    (while (and keep-going
		            (if backward
			            (not (or (bobp) (and limit (<= (point) limit))))
		              (not (or (eobp) (and limit (>= (point) limit)))))
		            ;; Use the next match if it is already known;
		            ;; otherwise, search for a match after moving forward
		            ;; one char if progress is required.
		            (setq real-match-data
			              (cond ((consp match-again)
				                 (goto-char (if backward
						                        (nth 0 match-again)
					                          (nth 1 match-again)))
				                 (replace-match-data
				                  t real-match-data match-again))
				                ;; MATCH-AGAIN non-nil means accept an
				                ;; adjacent match.
				                (match-again
				                 (and
				                  (replace-search search-string limit
						                          regexp-flag delimited-flag
						                          case-fold-search backward)
				                  ;; For speed, use only integers and
				                  ;; reuse the list used last time.
				                  (replace-match-data t real-match-data)))
				                ((and (if backward
					                      (> (1- (point)) (point-min))
					                    (< (1+ (point)) (point-max)))
				                      (or (null limit)
					                      (if backward
					                          (> (1- (point)) limit)
					                        (< (1+ (point)) limit))))
				                 ;; If not accepting adjacent matches,
				                 ;; move one char to the right before
				                 ;; searching again.  Undo the motion
				                 ;; if the search fails.
				                 (let ((opoint (point)))
				                   (forward-char (if backward -1 1))
				                   (if (replace-search search-string limit
						                               regexp-flag delimited-flag
						                               case-fold-search backward)
				                       (replace-match-data
					                    t real-match-data)
				                     (goto-char opoint)
				                     nil))))))

	      ;; Record whether the match is nonempty, to avoid an infinite loop
	      ;; repeatedly matching the same empty string.
	      (setq nonempty-match
		        (/= (nth 0 real-match-data) (nth 1 real-match-data)))

	      ;; If the match is empty, record that the next one can't be
	      ;; adjacent.

	      ;; Otherwise, if matching a regular expression, do the next
	      ;; match now, since the replacement for this match may
	      ;; affect whether the next match is adjacent to this one.
	      ;; If that match is empty, don't use it.
	      (setq match-again
		        (and nonempty-match
		             (or (not regexp-flag)
			             (and (if backward
				                  (looking-back search-string nil)
				                (looking-at search-string))
			                  (let ((match (match-data)))
				                (and (/= (nth 0 match) (nth 1 match))
				                     match))))))

	      (cond
	       ;; Optionally ignore matches that have a read-only property.
	       ((not (or (not query-replace-skip-read-only)
		             (not (text-property-not-all
			               (nth 0 real-match-data) (nth 1 real-match-data)
			               'read-only nil))))
	        (setq skip-read-only-count (1+ skip-read-only-count)))
	       ;; Optionally filter out matches.
	       ((not (funcall isearch-filter-predicate
                          (nth 0 real-match-data) (nth 1 real-match-data)))
	        (setq skip-filtered-count (1+ skip-filtered-count)))
	       ;; Optionally ignore invisible matches.
	       ((not (or (eq search-invisible t)
		             ;; Don't open overlays for automatic replacements.
		             (and (not query-flag) search-invisible)
		             ;; Open hidden overlays for interactive replacements.
		             (not (isearch-range-invisible
			               (nth 0 real-match-data) (nth 1 real-match-data)))))
	        (setq skip-invisible-count (1+ skip-invisible-count)))
	       (t
	        ;; Calculate the replacement string, if necessary.
	        (when replacements
	          (set-match-data real-match-data)
              (setq next-replacement
                    (mrep--replacement
                     (buffer-substring-no-properties (match-beginning 0) (match-end 0)))))
	        (if (not query-flag)
		        (progn
		          (unless (or literal noedit)
		            (replace-highlight
		             (nth 0 real-match-data) (nth 1 real-match-data)
		             start end search-string
		             regexp-flag delimited-flag case-fold-search backward))
		          (setq noedit
			            (replace-match-maybe-edit
			             next-replacement nocasify literal
			             noedit real-match-data backward)
			            replace-count (1+ replace-count)))
	          (undo-boundary)
	          (let (done replaced key def)
		        ;; Loop reading commands until one of them sets done,
		        ;; which means it has finished handling this
		        ;; occurrence.  Any command that sets `done' should
		        ;; leave behind proper match data for the stack.
		        ;; Commands not setting `done' need to adjust
		        ;; `real-match-data'.
		        (while (not done)
		          (set-match-data real-match-data)
                  (run-hooks 'replace-update-post-hook) ; Before `replace-highlight'.
                  (replace-highlight
		           (match-beginning 0) (match-end 0)
		           start end search-string
		           regexp-flag delimited-flag case-fold-search backward)
                  (setq next-replacement
                        (mrep--replacement
                         (buffer-substring-no-properties (match-beginning 0) (match-end 0))))
                  ;; Obtain the matched groups: needed only when
                  ;; regexp-flag non nil.
                  (when (and last-was-undo regexp-flag)
                    (setq last-was-undo nil
                          real-match-data
                          (save-excursion
                            (goto-char (match-beginning 0))
                            (looking-at search-string)
                            (match-data t real-match-data))))
                  ;; Matched string and next-replacement-replaced
                  ;; stored in stack.
                  (setq search-string-replaced (buffer-substring-no-properties
                                                (match-beginning 0)
                                                (match-end 0))
                        next-replacement-replaced
                        (query-replace-descr
                         (save-match-data
                           (set-match-data real-match-data)
                           (match-substitute-replacement
                            next-replacement nocasify literal))))
		          ;; Bind message-log-max so we don't fill up the
		          ;; message log with a bunch of identical messages.
		          (let ((message-log-max nil)
			            (replacement-presentation
			             (if query-replace-show-replacement
			                 (save-match-data
			                   (set-match-data real-match-data)
			                   (match-substitute-replacement next-replacement
							                                 nocasify literal))
			               next-replacement)))
		            (let ((target (buffer-substring-no-properties (match-beginning 0) (match-end 0))))
                      (message message
                               (query-replace-descr target)
                               (query-replace-descr replacement-presentation))))
		          (setq key (read-event))
		          ;; Necessary in case something happens during
		          ;; read-event that clobbers the match data.
		          (set-match-data real-match-data)
		          (setq key (vector key))
		          (setq def (lookup-key map key))
		          ;; Restore the match data while we process the command.
		          (cond ((eq def 'help)
			             (with-output-to-temp-buffer "*Help*"
			               (princ
			                (concat "Query replacing "
				                    (if backward "backward " "")
				                    (if delimited-flag
					                    (or (and (symbolp delimited-flag)
						                         (get delimited-flag
                                                      'isearch-message-prefix))
					                        "word ") "")
				                    (if regexp-flag "regexp " "")
				                    from-string " with "
				                    next-replacement ".\n\n"
				                    (substitute-command-keys
				                     query-replace-help)))
			               (with-current-buffer standard-output
			                 (help-mode))))
			            ((eq def 'exit)
			             (setq keep-going nil)
			             (setq done t))
			            ((eq def 'exit-current)
			             (setq multi-buffer t keep-going nil done t))
			            ((eq def 'backup)
			             (if stack
			                 (let ((elt (pop stack)))
			                   (goto-char (nth 0 elt))
			                   (setq replaced (nth 1 elt)
				                     real-match-data
				                     (replace-match-data
				                      t real-match-data
				                      (nth 2 elt))))
			               (message "No previous match")
			               (ding 'no-terminate)
			               (sit-for 1)))
			            ((or (eq def 'undo) (eq def 'undo-all))
			             (if (null stack)
                             (progn
                               (message "Nothing to undo")
                               (ding 'no-terminate)
                               (sit-for 1))
			               (let ((stack-idx         0)
                                 (stack-len         (length stack))
                                 (num-replacements  0)
                                 (nocasify t) ; Undo must preserve case (Bug#31073).
                                 search-string
                                 next-replacement)
                             (while (and (< stack-idx stack-len)
                                         stack
                                         (or (null replaced) last-was-act-and-show))
                               (let* ((elt (nth stack-idx stack)))
                                 (setq
                                  stack-idx (1+ stack-idx)
                                  replaced (nth 1 elt)
                                  ;; Bind swapped values
                                  ;; (search-string <--> replacement)
                                  search-string (nth (if replaced 4 3) elt)
                                  next-replacement (nth (if replaced 3 4) elt)
                                  search-string-replaced search-string
                                  next-replacement-replaced next-replacement
                                  last-was-act-and-show nil)

                                 (when (and (= stack-idx stack-len)
                                            (and (null replaced) (not last-was-act-and-show))
                                            (zerop num-replacements))
                                   (message "Nothing to undo")
                                   (ding 'no-terminate)
                                   (sit-for 1))

                                 (when replaced
                                   (setq stack (nthcdr stack-idx stack))
                                   (goto-char (nth 0 elt))
                                   (set-match-data (nth 2 elt))
                                   (setq real-match-data
                                         (save-excursion
                                           (goto-char (match-beginning 0))
                                           (looking-at search-string)
                                           (match-data t (nth 2 elt)))
                                         noedit
                                         (replace-match-maybe-edit
                                          next-replacement nocasify literal
                                          noedit real-match-data backward)
                                         replace-count (1- replace-count)
                                         real-match-data
                                         (save-excursion
                                           (goto-char (match-beginning 0))
                                           (looking-at next-replacement)
                                           (match-data t (nth 2 elt))))
                                   ;; Set replaced nil to keep in loop
                                   (when (eq def 'undo-all)
                                     (setq replaced nil
                                           stack-len (- stack-len stack-idx)
                                           stack-idx 0
                                           num-replacements
                                           (1+ num-replacements))))))
                             (when (and (eq def 'undo-all)
                                        (null (zerop num-replacements)))
                               (message "Undid %d %s" num-replacements
                                        (if (= num-replacements 1)
                                            "replacement"
                                          "replacements"))
                               (ding 'no-terminate)
                               (sit-for 1)))
			               (setq replaced nil last-was-undo t last-was-act-and-show nil)))
			            ((eq def 'act)
			             (or replaced
			                 (setq noedit
				                   (replace-match-maybe-edit
				                    next-replacement nocasify literal
				                    noedit real-match-data backward)
				                   replace-count (1+ replace-count)))
			             (setq done t replaced t update-stack (not last-was-act-and-show)))
			            ((eq def 'act-and-exit)
			             (or replaced
			                 (setq noedit
				                   (replace-match-maybe-edit
				                    next-replacement nocasify literal
				                    noedit real-match-data backward)
				                   replace-count (1+ replace-count)))
			             (setq keep-going nil)
			             (setq done t replaced t))
			            ((eq def 'act-and-show)
			             (unless replaced
			               (setq noedit
				                 (replace-match-maybe-edit
				                  next-replacement nocasify literal
				                  noedit real-match-data backward)
				                 replace-count (1+ replace-count)
				                 real-match-data (replace-match-data
						                          t real-match-data)
				                 replaced t last-was-act-and-show t)
                           (replace--push-stack
                             replaced
                             search-string-replaced
                             next-replacement-replaced stack)))
			            ((or (eq def 'automatic) (eq def 'automatic-all))
			             (or replaced
			                 (setq noedit
				                   (replace-match-maybe-edit
				                    next-replacement nocasify literal
				                    noedit real-match-data backward)
				                   replace-count (1+ replace-count)))
			             (setq done t query-flag nil replaced t)
			             (if (eq def 'automatic-all) (setq multi-buffer t)))
			            ((eq def 'skip)
			             (setq done t update-stack (not last-was-act-and-show)))
			            ((eq def 'recenter)
			             ;; `this-command' has the value `query-replace',
			             ;; so we need to bind it to `recenter-top-bottom'
			             ;; to allow it to detect a sequence of `C-l'.
			             (let ((this-command 'recenter-top-bottom)
			                   (last-command 'recenter-top-bottom))
			               (recenter-top-bottom)))
			            ((eq def 'edit)
			             (let ((opos (point-marker)))
			               (setq real-match-data (replace-match-data
						                          nil real-match-data
						                          real-match-data))
			               (goto-char (match-beginning 0))
			               (save-excursion
			                 (save-window-excursion
			                   (recursive-edit)))
			               (goto-char opos)
			               (set-marker opos nil))
			             ;; Before we make the replacement,
			             ;; decide whether the search string
			             ;; can match again just after this match.
			             (if (and regexp-flag nonempty-match)
			                 (setq match-again (and (looking-at search-string)
						                            (match-data)))))
			            ;; Edit replacement.
			            ((eq def 'edit-replacement)
			             (setq real-match-data (replace-match-data
						                        nil real-match-data
						                        real-match-data)
			                   next-replacement
			                   (read-string "Edit replacement string: "
                                            next-replacement)
			                   noedit nil)
			             (if replaced
			                 (set-match-data real-match-data)
			               (setq noedit
				                 (replace-match-maybe-edit
				                  next-replacement nocasify literal noedit
				                  real-match-data backward)
				                 replaced t))
			             (setq done t))

			            ((eq def 'delete-and-edit)
			             (replace-match "" t t)
			             (setq real-match-data (replace-match-data
						                        nil real-match-data))
			             (replace-dehighlight)
			             (save-excursion (recursive-edit))
			             (setq replaced t))
			            ;; Note: we do not need to treat `exit-prefix'
			            ;; specially here, since we reread
			            ;; any unrecognized character.
			            (t
			             (setq this-command 'mode-exited)
			             (setq keep-going nil)
			             (setq unread-command-events
			                   (append (listify-key-sequence key)
				                       unread-command-events))
			             (setq done t)))
		          (when query-replace-lazy-highlight
		            ;; Force lazy rehighlighting only after replacements.
		            (if (not (memq def '(skip backup)))
			            (setq isearch-lazy-highlight-last-string nil)))
		          (unless (eq def 'recenter)
		            ;; Reset recenter cycling order to initial position.
		            (setq recenter-last-op nil)))
		        ;; Record previous position for ^ when we move on.
		        ;; Change markers to numbers in the match data
		        ;; since lots of markers slow down editing.
                (when update-stack
                  (replace--push-stack
                    replaced
                    search-string-replaced
                    next-replacement-replaced stack))
                (setq next-replacement-replaced nil
                      search-string-replaced    nil
                      last-was-act-and-show     nil))))))
      (replace-dehighlight))
    (or unread-command-events
	    (message "Replaced %d occurrence%s%s"
		         replace-count
		         (if (= replace-count 1) "" "s")
		         (if (> (+ skip-read-only-count
			               skip-filtered-count
			               skip-invisible-count) 0)
		             (format " (skipped %s)"
			                 (mapconcat
			                  'identity
			                  (delq nil (list
					                     (if (> skip-read-only-count 0)
					                         (format "%s read-only"
						                             skip-read-only-count))
					                     (if (> skip-invisible-count 0)
					                         (format "%s invisible"
						                             skip-invisible-count))
					                     (if (> skip-filtered-count 0)
					                         (format "%s filtered out"
						                             skip-filtered-count))))
			                  ", "))
		           "")))
    (or (and keep-going stack) multi-buffer)))

(defun mrep-query-replace (from-string-alist &optional delimited start end backward region-noncontiguous-p)
  "Multi-dimensional version of `query-replace'.
FROM-STRING-ALIST is a list of conses (STRING . REPLACEMENT).

Interactively, prompt user for the conses (STRING . REPLACEMENT) until
the user inputs '' for STRING."
  (interactive (mrep--query-replace-interactive-spec "Multi query replace"))
  (let ((from-string (regexp-opt (mapcar #'car from-string-alist))))
    (mrep-perform-replace from-string '("") t t delimited nil nil start end backward region-noncontiguous-p)))

(defun mrep-query-replace-regexp (regexp-replacement-alist &optional delimited start end backward region-noncontiguous-p)
  "Multi-dimensional version of `replace-regexp'.
REGEXP-REPLACEMENT-ALIST is a list of conses (REGEXP . REPLACEMENT).

Interactively, prompt user for the conses (REGEXP . REPLACEMENT) until
the user inputs '' for REGEXP."
  (interactive (mrep--query-replace-interactive-spec "Multi query replace regexp"))
  (let ((from-string (mapconcat #'identity (mapcar #'car regexp-replacement-alist) "\\|")))
    (mrep-perform-replace from-string '("") t t delimited nil nil start end backward region-noncontiguous-p)))


(provide 'multi-replace)
;;; multi-replace.el ends here
