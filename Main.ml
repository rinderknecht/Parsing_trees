(* See reader.mll for the documentation. *)

let usage () =
  prerr_endline ("Usage: " ^ Sys.argv.(0) ^ " <Clang ast>");
  Pervasives.exit 1

let missing file =
  prerr_endline ("File " ^ file ^ " does not exist.");
  usage ()

let args = Array.length Sys.argv;;

if args = 2
then let source = Sys.argv.(1)
     in if Sys.file_exists source
        then let _tree = Reader.make_tree source in ()
        else missing source
else usage ()
