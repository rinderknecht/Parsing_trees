(* Once a node name is recognised, everything afterwards until the end
   of the line is lumped together) and the markup ("|", "|-" and "`-")
   is simply ignored: only the columns where the node names occur are
   relevant to infer the tree structure.

   The key observations are that the nodes are listed in preorder
   ('document order' in XML parlance), one per line, and, the name of
   the nodes being tabulated, the columns where they appear in the
   source can be easily translated into the depths (or levels) of the
   corresponding nodes in the AST. A preorder traversal of a _Catalan
   tree_ (that is, a tree whose nodes do not have necessarily the same
   arity, sometimes called `unranked tree'), with the depth of the
   nodes, is enough to reconstruct the corresponding tree.

   The design of the algorithm is twofold.

   First, a _monotonic lattice path_ is built from the source
   file. Such a path is a series made from two basic elements, called
   _steps_: _rises_, written `/', and _falls_, noted `\'. For
   instance:

         /\
        /  \/\
   /\/\/      \

   (This representation can be conceived as a mountain range, with
   heights associated to points, featuring peaks and valleys.)

   This construction is possible because of the standard bijection
   between _Dyck paths_, which are monotonic lattice paths which never
   cross the horizontal baseline and end at the same level as they
   start (as the previous example), and Catalan trees. To build a Dyck
   path, let us start at the root, and undertake, for example, a
   preorder traversal. Each time an edge is traversed downwardly, a
   rise is created; each time an edge is traversed upwardly (including
   those which have already been visited on the way down), a fall is
   issued. For instance, the previous Dyck path can be obtained from
   the following Catalan tree:

          /|\
            /\
            |

   Note that if a tree contains _n_ nodes, the equivalent Dyck path
   contains _2n_ steps.

   The second phase of the algorithm is the converse mapping. To build
   a tree from a Dyck path, we start reading a rise, which will be the
   root, then a _forest_ (that is, a series of trees) is read from the
   remainder of the path, which will be the immediate subtrees of the
   root, then the fall corresponding to the initial rise is read and
   discarded. This process is recursive, as reading a forest requires
   reading a tree, and it is applied recursively itself until the path
   is empty.

   As far as efficiency is concerned, we want to perform only one pass
   over the input source file, and exactly one pass over the Dyck path
   generated by the first phase.
*)

{
(* HEADER *)

(* STRING PROCESSING *)

(* The call [mk_rev_str p] is the string corresponding to the list of
   characters [p], in reverse order. For instance [mk_rev_str
   ['a';'b'] = "ba"]. *)

let mk_rev_str (p: char list) : string =
  let len = List.length p in
  let s = Bytes.make len ' ' in
  let rec fill i =
    function [] -> s | c::l -> Bytes.set s i c; fill (i-1) l
in Bytes.to_string (fill (len-1) p)

(* CATALAN TREES *)

(* The type ['a tree] defines inductively the set of Catalan
   trees. The empty tree is modelled by its value [Nil]. The value
   [Node(r,f)] models a non-empty tree whose root carries the value
   [r] of type ['a], and the immediate subtrees (children) make up the
   forest [f] (a list of trees).

   For example, the value

   [Node("a",[Node("b",[]);
              Node("c",[]);
              Node("d",[Node("e",[Node("f",[])]);
                        Node("g",[])])])]

   (make sure to remove the outermost square brackets when quoting
   this excerpt to an OCaml top-level) represents the tree

                      a
                    / | \
                   b  c  d
                        / \
                       e   g
                       |
                       f
*)

type 'a tree =
  Node of 'a * 'a tree list
| Nil

(* MONOTONIC LATTICE PATHS *)

(* The type ['a path] defines inductively the set of monotonic lattice
   paths. The empty path is denoted by the value [Empty]. The value
   [Rise(r,p)] represents a rise annotated with the contents [r], of
   type ['a], and the rest of the path is [p]. The value [Fall p]
   models a fall followed by the path [p].

   For instance, the value

   [Rise("a",
      Rise("b",
      Fall(
      Rise("c",
      Fall(
      Rise("d",
        Rise("e",
          Rise("f",
          Fall(
        Fall(
        Rise("g",
        Fall(
      Fall(
    Fall Empty)))))))))))))]

   (make sure to remove the outermost square brackets when quoting
   this excerpt to an OCaml toplevel) corresponds to the path

            f/\
           e/  \g/\
    b/\c/\d/       \
   a/               \

   where the contents ("a", "b", etc.) are linked to the next rise, so
   we should read "a/", "d/" etc. as atoms.

   Note the difference with the tree without annotations given above:

         /\
        /  \/\
   /\/\/      \

  Here, beyond the annotations themselves, we added an initial rise
  "a/" and a final fall. The rationale is that we need to store the
  contents of the root ("a"), but information is only stored in rises,
  hence this additional, first rise with "a", and the corresponding
  fall at the end (right).
 *)

type 'a path =
  Rise  of 'a * 'a path
| Fall  of 'a path
| Empty

(* Conversion from a reverse-preorder Dyck path to a Catalan tree

   In the description of the algorithm in the header above, we did not
   consider technical details. In particular, Dyck paths have a
   structure which is isomorphic to lists (that is, stacks), which
   have to be built bottom-up. The source file lists the nodes in
   preorder. Therefore, when a node is read and pushed on the path
   under construction, the order is reversed, and we end up with a
   path which is a reverse-preorder (for instance, the root, which is
   the first line of the file, finds its way to the end of the path).

   For instance, resuming the same example, instead of the Dyck path

            f/\
           e/  \g/\
    b/\c/\d/       \
   a/               \

   we actually build the reversed path

   \               a/
    \       d/\c/\b/
     \g/\  e/
         \f/

   Keep in mind that the leftmost step corresponds to the head of the
   list modelling the path, and the rightmost to the bottom. This
   leftward convention follows the same convention when representing
   lists in OCaml, for example, in [[1;2;3]], the head [1] is is the
   leftmost element.

   Consequently, what we need is not a function to build a Catalan
   tree from a preorder Dyck path, but from a reverse-preorder Dyck
   path: that is the aim of [rpre_to_tree], with the help of functions
   [rpre_to_tree'] and [rpre_to_forest']. The call [rpre_to_tree' p]
   evaluates into a pair [(t,p')], where [t] is the tree made from the
   shortest possible prefix of the path [p], and [p'] is [p] without
   that prefix. The call [rpre_to_forest' f p] evaluates into a pair
   [(f',p')], where [f'] is the forest obtained by pushing on top of
   the forest [f] the trees made from the longest prefix of the path
   [p], and [p'] is [p] without that prefix. The function
   [rpre_to_tree] is simply a front-end to [rpre_to_tree'], which
   discards the remaining suffix of the path, which should be [Empty]
   because that enforces that it is indeed a Dyck path.

   For instance, the value of [rpre_to_tree t], where [t] is the path

   \               a/
    \       d/\c/\b/
     \g/\  e/
         \f/

   yields the call of [rpre_to_forest [] path], where [path] is the
   previous path without the leading fall. That call evaluates into
   the children of the node "a" in the tree to-be, and the rise "a"
   itself, as we can see in the first case of the [match] below. Note
   the clause [assert false] if the rise corresponding to "a" is not
   found, which enforces that each fall is paired with a rise,
   therefore the path is a Dyck path, and the remaining path at the
   end is [Empty] (as claimed above). In general, we recursively apply
   the following pattern to the path:

   \                 x/''''''''''''''''
    ''''''''''''''''''
      children of x

   (This is called the _quadratic decomposition_ in the literature,
   except that we work with a reversed path here (upside-down).)
*)

let rec rpre_to_forest' forest path =
  match rpre_to_tree' path with
     Nil, path' -> forest, path'
  | tree, path' -> rpre_to_forest' (tree::forest) path'

and rpre_to_tree' = function
  Fall path ->
    (match rpre_to_forest' [] path with
       forest, Rise(root,path') -> Node(root,forest), path'
     |                        _ -> assert false)
| path -> Nil, path

let rpre_to_tree path = fst (rpre_to_tree' path)

(* The values of the call [push_falls p n] is a path
   [Fall(Fall(...Fall(Fall p)...))], where there are [n] applications
   of the constructor [Fall] to the path [p]. This function is useful
   to close Dyck paths, in other words, to have a path become a Dyck
   path by completing it so it returns to its baseline (that is, the
   horizontal starting line). Note that it is not checked that the new
   path is actually a Dyck path: the proper value of [n] is entrusted
   to the caller. The function [push_falls] is also used to pad falls in
   front of a rise (keep in mind that we work on a reversed path),
   modelling the fact that, once a new node is read in the input, we
   must walk up in the output tree and down to put it at the right
   place. See below the parser [scan]. *)

let rec push_falls path = function
  0 -> path
| n -> push_falls (Fall path) (n-1)

(* COLUMNS *)

(* Where a node name has been found in the input file, let [c] be the
   column of the current node and [t] the stack of columns of the
   nodes from the root to the previous node, _as found in the input
   tree_. For example, let us consider again the input tree

   a
   |- b
   |- c
   `- d
      |- e
      |  `- f
      `- g

   where "a" has column [0]. At the node "b", the column is [3] and
   the stack is [[0]] (corresponding to the thread "a" in the tree);
   at the node "c", the column is [3] and the stack is [[3;0]] (for
   the thread "a->b"); at the node "d", the column is [3] and the
   stack is [[3;0]] (for the thread "a->c"); at the node "e", the
   column is [6] and the stack is [[3;0]] (for "a->d"); at the node
   "f", the column is [9] and the stack is [[6;3;0]] (for "a->d->e");
   at the node "g", the column is [6] and the stack is [[9;6;3;0]]
   (for "a->d->e->f").

   The value of the call [diff c t] is the number of columns on top of
   the thread (stack) [t] that can be popped until finding the same
   column. For instance, [diff 6 [9;6;3;0]] has value [1], because all
   we need is to pop [9] to find [6]. This particular value, for
   instance, is interpreted in our continued example as the signed
   difference of levels (depth) between the node "f" and "g": this
   difference is positive, so when encountering "g", we find out that
   "f" is deeper than "g" (of one level). Similarly, the value of
   [diff 3 [3;0]] is [0], meaning, for instance, that the node "c" has
   the same level in the tree as the node "b". We can have negative
   values, as [diff 9 [6;3;0]] yielding [-1], which means that, when
   encountering "f", we find out that "f" is deeper than "e" (of one
   level).
*)

let rec diff col' = function
                [] -> -1, [col']
| col::thread as l -> if col = col'
                      then 0, l
                      else if col < col'
                           then -1, col'::l
                           else let delta, thread' = diff col' thread
                                in 1+delta, thread'

(* END OF HEADER *)
}

(* REGULAR EXPRESSIONS *)

(* White space *)

let nl = ['\n' '\r'] (* | "\r\n" *)
let blank = [' ' '\t']

(* Integers *)

let digit = ['0'-'9']
let dec = digit+

(* Identifiers *)

let letter = ['a'-'z' 'A'-'Z']
let start = '_' | letter
let alphanum = letter | digit | '_'
let ident = start alphanum*


(* RULES *)

(* The lexer [scan] is the entry point. A call takes four arguments:
   [scan col thread path lexbuf]. The first, [col], is the current
   column in the input file being scanned; the argument [thread] is
   the stack of columns as explained in the comment about the function
   [diff] above (it is isomorphic to the path from the root to the
   previously parsed node); the argument [path] is the
   reversed-preorder Dyck path under construction; and the last
   argument, [lexbuf], is the implicit lexing buffer. (See the
   documentation of the module [Lexing] in the OCaml standard
   library.)

   The construction assumes that any Dyck path can be decomposed into
   a series of patterns like so:

   / or \/ or \   or \    etc.
               \/     \
                       \/

  All these patterns can actually be reduced to a single one: a
  series, possibly empty, of falls, followed by one rise. Consider
  again our continued example:

   \            /  is made of \     \    / / \/ \/ /
    \      /\/\/               \     \/
     \/\  /                     \/
        \/

  Remember to read from right to left, so "/" is pushed first onto an
  empty path, then "\/", "\/" again, then "/" etc.

  The rationale for decomposing Dyck paths in this manner is as
  follows. Reading line by line the input file will provide nodes one
  by one, in preorder. We can determine the level of each new node in
  the AST by means of the tabulations (columns of the node names) of
  the preceding nodes and its own. Therefore, since a node corresponds
  to a rise when we reach it, we need to produce one '/', but, we may
  need to climb up in the tree _before_ reaching it (we perform a
  preorder traversal), and that situation corresponds to a series of
  falls '\' in the path. (See function [push_falls].)

  The first case of [scan] handles newline characters by updating the
  state of the lexing engine (calling [Lexing.new_line]) and resetting
  the column to [0] in a recursive call.

  The second case of [scan] deals with white space by simply
  incrementing the column in a recursive call.

  The third and fourth cases of [scan] parse the markup, which we
  ignore, but the current column is updated accordingly, as always.

  The fifth case is matched when the end of the file is found. As
  indicated above, we may have to close the Dyck path because there is
  no next node, which is the purpose of the call to [push_falls]: the
  number of down steps to pad is simply the length of the thread,
  which is isomorphic to the path from the root of the tree to the
  current node (so the padding takes us back up to the root). The last
  action to perform is, of course, to build the abstract syntax tree
  from the (reverse-preorder) Dyck path we have just constructed,
  which is why [rpre_to_tree] is called.

  The sixth case is used when encountering a node name, including the
  special node "<<<NULL>>>". First, the rest of the line in the input
  file is read by the parser [copy_to_eol] and lumped into a string
  assigned to the variable [attr] (short for "attribute"). Second, the
  difference in depth between the node just read and the previous is
  computed by the function [diff], which also provides a new thread
  [thread'], that is, a new path from the root to the new node. Third,
  the lattice path [path] is extended with a new chunk made of a
  series of falls (provided by the call to [push_falls]) followed by a
  rise containing the node we just parsed -- This extension
  corresponds to a possible climb in the corresponding tree, followed
  by a descent of one level to reach the new node. Finally, a
  recursive call to [scan], carrying all these updates, resets the
  column to [0], as [copy_to_eol] ended by reading an end-of-line
  character.

  The last case is a catch-all clause for invalid characters. The
  error message provides the location in the input source, which
  justifies updating the state of the lexing engine with
  calling [Lexing.new_line] in the first case of [scan].
*)

rule scan col thread path = parse
  nl          { Lexing.new_line lexbuf;
                scan       0 thread path lexbuf }
| blank       { scan (col+1) thread path lexbuf }
| '|'         { scan (col+1) thread path lexbuf }
| "|-" | "`-" { scan (col+2) thread path lexbuf }
| eof         { rpre_to_tree (push_falls path (List.length thread)) }
| (ident | "<<<NULL>>>") as root {
    let attr = copy_to_eol [] lexbuf in
    let delta, thread' = diff col thread in
    let path' = Rise ((root,attr), push_falls path (delta+1))
    in scan 0 thread' path' lexbuf
  }
| _ as c { let line = Lexing.(lexbuf.lex_curr_p.pos_lnum)
           in prerr_endline ("Invalid character '" ^ String.make 1 c
                             ^ "' at line " ^ string_of_int line
                             ^ " and column " ^ string_of_int col ^ ".");
           exit 1 }

and copy_to_eol acc = parse
  nl     { Lexing.new_line lexbuf; mk_rev_str acc }
| eof    { mk_rev_str acc }
| _ as c { copy_to_eol (c::acc) lexbuf }


{
(* POSTLUDE *)

(* The function [make_tree] is the entry point of the module
   [Reader]. Its sole parameter is the name of the input source file,
   [source]. This function is a front-end for the parser [scan], which
   is initialised with column [0], an empty thread, an empty lattice
   path, and the initial lexing buffer to parse. *)

let make_tree source =
  match open_in source with
    cin -> scan 0 [] Empty (Lexing.from_channel cin)
  | exception Sys_error msg -> prerr_endline msg; exit 1
}