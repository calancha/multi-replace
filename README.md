# Multi-dimensional query and replace

[![Build Status](https://api.travis-ci.org/calancha/multi-replace.svg?branch=master)](https://travis-ci.org/calancha/multi-replace)

This lib defines the commands **mqr-replace**,
**mqr-replace-regexp**, **mqr-query-replace** and
**mqr-query-replace-regexp** to match and replace several regexps
in the region.

Interactively, prompt the user for the regexps and their replacements.
If the region is active, then the commands act on the active region.
Otherwise, they act on the entire buffer.

To use this library, save this file in a directory included in
your *load-path*.  Then, add the following line into your .emacs:

```
(require 'mqr)
```

You might want to bind **mqr-query-replace**, **mqr-query-replace-regexp**
to some easy to remember keys.  If you have the Hyper key, then the
following combos are analogs to those for the Vanila Emacs commands:

```
(define-key global-map (kbd "H-%") 'mqr-query-replace)
(define-key global-map (kbd "C-H-%") 'mqr-query-replace-regexp)
```

# Video example

Use case example for this library:

https://www.dropbox.com/s/wzm1ju59f18604q/mqr_example_music.mkv?dl=0