#!/bin/sh
set -x
ocamllex.opt Reader.mll
ocamlfind ocamlopt -c Reader.ml
ocamlfind ocamlopt -c Reader.ml
ocamlfind ocamlopt -c Main.ml
ocamlfind ocamlopt -c Main.ml
ocamlfind ocamlopt -o Main.opt Reader.cmx Main.cmx
