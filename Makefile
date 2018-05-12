emacs ?= emacs

LOAD = -l multi-replace.el

all: test

test:
	$(emacs) -batch $(LOAD) -l multi-replace-tests.el -f ert-run-tests-batch-and-exit

compile:
	$(emacs) -batch --eval "(progn (add-to-list 'load-path default-directory) (byte-compile-file \"multi-replace.el\"))"

clean:
	rm -f *.elc

.PHONY: all compile clean test
