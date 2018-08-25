# A parser for trees

This program reads an unranked tree from a text file, where it is
specified as in a textual menu.

An example of simplified input file is:

      a
      |- b
      |- c
      `- d
         |- e
         |  `- f
         `- g

The present program reads that text file and produces an OCaml value
 (not text) corresponding to

                      a
                    / | \
                   b  c  d
                        / \
                       e   g
                       |
                       f

which is discarded. As such, it should be considered a library to
parse such trees, for example, the abstract syntax trees (AST) output
by the C/C++ compiler Clang, using the undocumented command
[clang-check -ast-dump <foo.cc>].

It has been designed to be resilient to differences in format between
several versions of Clang, and has been tested against versions 3.4,
3.5 and 3.6.1. These differences are of several kinds: markup errors,
different (internal) trees, source locations added or removed, node
attributes added or removed. (By attribute, mean whatever information
is associated to the node after its name.) For example, we may have to
process, in place of the above input, the erroneous file

   a
   |- b
   |- c
   |- d
   |  |- e
   |  |  |- f
   |  `- g

We rely on [ocamllex] and a bijection between Catalan trees (that is,
unranked trees) and Dyck paths to very efficiently build an OCaml
value representing the input.
