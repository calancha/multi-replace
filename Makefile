emacs ?= emacs

LOAD = -l mqr.el

all: test

test:
	$(emacs) -batch $(LOAD) -l mqr-tests.el -f ert-run-tests-batch-and-exit

compile:
	$(emacs) -batch --eval "(progn (add-to-list 'load-path default-directory) (byte-compile-file \"mqr.el\"))"

clean:
	rm -f *.elc

.PHONY: all compile clean test
