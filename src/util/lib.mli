(*----
 Name: lib.mli
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2005
----*)

(**
   General purpose functions.
*)

(* Simple utility functions *)

val iteri : (int -> 'a array -> 'b) -> 'a array -> unit 
val list_string : ('a -> string) -> string -> 'a list -> string 

val take : int * 'a list -> 'a list 
val drop : int * 'a list -> 'a list 
val delete_nth : int -> 'a list -> 'a list
val replace_nth : int -> 'a list -> 'a -> 'a list
val insert : 'a -> 'b -> ('a * 'b) list -> ('a * 'b) list
val replace : 'a -> 'b -> ('a*'b) list -> ('a*'b) list
val wrap_around: 'a list -> int -> int
val get_nth: 'a list -> int -> 'a
val splice_nth : int -> 'a list -> 'a list -> 'a list
val move_right : 'a list * 'a list -> 'a list * 'a list 
val move_left : 'a list * 'a list -> 'a list * 'a list 
val index: ('a -> bool) -> 'a list -> int
val filter: ('a -> bool) -> 'a list -> 'a list
val assocp: ('a -> bool) -> ('a* 'b) list -> 'b

type ('a, 'b) substype = ('a, 'b)Hashtbl.t
val empty_env : unit -> ('a, 'b) Hashtbl.t 
val env_size : int -> ('a, 'b) Hashtbl.t 
val find : 'a -> ('a, 'b) Hashtbl.t -> 'b 
val bind_env : 'a -> 'b -> ('a, 'b) Hashtbl.t -> unit 
val bind : 'a -> 'b -> ('a, 'b) Hashtbl.t -> ('a, 'b) Hashtbl.t 
val add : 'a -> 'b -> ('a, 'b) Hashtbl.t -> 'b 
val chase : ('a -> bool) -> 'a -> ('a, 'a) Hashtbl.t -> 'a
val fullchase : ('a -> bool) -> 'a -> ('a, 'a) Hashtbl.t -> 'a 
val member : 'a -> ('a, 'b)Hashtbl.t -> bool
val remove: 'a -> ('a, 'b)Hashtbl.t -> unit
val remove_dups: 'a list -> 'a list

val table_to_list : ('a, 'b) Hashtbl.t -> ('a * 'b) list
(** Convert from a table to a list. *)
val table_from_list : ('a * 'b) list -> ('a, 'b) Hashtbl.t
(** Convert from a list to a table. *)

val find_char : char -> int -> string -> int 

(* chop_at c str:
   cut str into pair of strings (x, y)
   with x the substring before char c, y the substring after c
   if no char c in str, then x is the empty string
*)

val chop_at : char -> string -> string * string

(* [int_to_name i]: convert i to a string
   0 -> a
   25-> z
   26 -> a1
*)
val int_to_name: int -> string

(* [num_to_name i]: convert [i] to string
   0 -> a
   25-> z
   26 -> a1
*)
val num_to_name: Num.num -> string

(**
   Named Lists 

   Lists in which elements are named and data can be
   added by relative position

   Use association list functions for operations other than add.
*)
type ('a, 'b)named_list = ('a * 'b) list

type ('a)position = 
    First | Last | Before of 'a | After of 'a | Level of 'a


(** [named_add l p n x]: 
   add (n, x) to named list l at position p 
*)
val named_add: 
    ('a, 'b)named_list->('a)position 
      -> 'a -> 'b -> ('a, 'b) named_list

(* 
   [get_option x default]:
   If [x] is [Some(y)] then return [y], otherwise return [default].

   [set_option x d]:
   If [x] is [Some(y)] then [y:=d].

   [dest_option ?err x]
   If [x] is [Some(y)] then [y], otherwise raise [err] or [Failure]
*)
val get_option : 'a option -> 'a -> 'a
val set_option:  'a option ref -> 'a -> unit
val dest_option: ?err:exn -> 'a option -> 'a


val set_int_option : int -> int option
val get_int_option : int option -> int
val compare_int_option: int option -> int -> bool

(** [apply_option f a d]
   
   Apply to [f] to option [a].
   if [a] is [Some i] then return [f i] else return [d].
*)
val apply_option: ('a -> 'b) -> 'a option -> 'b -> 'b

(** [date]: used to ensure dependencies among theory files *)
val date: unit -> float

(* 
   [nice_date f]
   return date [f] in form [(year, month, day, hour, min)]
*)
val nice_date: float -> (int * int * int * int * int)

(**
   [get_one l e]: Get first element of list [l].
   raise exception [e] if [l] is empty.

   [get_two l e]: Get first two elements of list [l].
   raise exception [e] if length of [l] < 2.
*)
val get_one : 'a list -> exn -> 'a
val get_two : 'a list -> exn -> ('a * 'a)


val split_at_index : int -> 'a list -> ('a list * 'a list)
(**
   [split_at_index i x]: Split [x] into [(l, r)] so that
   [x=List.append l r] and [List.hd r] is the [i]th element of [x]
   (counting from [0]).

   @raise Not_found if [i] >= [length x].
*)

val full_split_at: ('a -> bool) -> 'a list -> ('a list * 'a * 'a list)
(**
   [split_at p x]: Split [x] into [(l, c, r)] so that
   [x=List.rev_append l (c::r)] and [c] is element satisfying [p].

   @raise Not_found if no element of [x] satisifies the condition.
*)

val full_split_at_index: int -> 'a list -> ('a list * 'a * 'a list)
(**
   [split_at_index i x]: Split [x] into [(l, c, r)] so that
   [x=List.rev_append l (c::r)] and [c] is the [i]th element of [x]
   (counting from [0]).

   @raise Not_found if [i] >= [length x].
 *)

(*
val full_split_at_tag: 
    Tag.t -> (Tag.t * 'a) list 
      -> ((Tag.t * 'a) list * (Tag.t * 'a) * (Tag.t * 'a) list)
*)

(**
   [rotate_left n l]: Rotate list [l] [n] places left 

   [rotate_right n l]: Rotate list [l] [n] places right 
*)
val rotate_left : int -> 'a list -> 'a list
val rotate_right : int -> 'a list -> 'a list

val apply_nth : int -> ('a -> 'b) -> 'a list -> 'b -> 'b
(** 
   [apply_nth n f l d]: Apply [f] to [n]th element of list.
   If list [l] is empty, return [d].
*)

(**
   [fold_map f a l]: 
   [fold_map f a [b1; ... ; bn]] is
   [ (fst(f (std f a bn-1) bn),
   [snd(f a b1); snd(f (fst f a b1) b2) ; ... ; snd(f (fstf a bn-1) bn)])]
*)
val fold_map : 
    ('a -> 'b -> ('a * 'c )) -> 'a -> 'b list -> ('a * 'c list)

(** [swap p]: [swap (a, b)] is [b, a] *)
val swap: ('a * 'b) -> ('b * 'a)

val map_find: ('a -> 'b) -> 'a list -> 'b list
(**
   [map_find f l]: map function [f] to list [l]. Silently discard
   elements for which [f] raises [Not_found].
*)

(**
   [extract p ls]: Extract the first element [x] of [ls] satisfying [p].
   return [(x, ls')], where [ls'] is [ls] with [x] removed.
   Raise [Not_found] if no element of [ls] satisfies [p].
*)
val extract : ('a -> bool) -> 'a list -> ('a * 'a list)

(**
   [least ord ls]: return least [x] in [ls]. Raise [Invalid_argument]
   if [ls] is empty
*)
val least: ('a -> 'a -> bool) -> 'a list -> 'a


val try_find: ('a -> 'b) -> 'a -> 'b option
(**
   [try_find f p]: Return [Some (f p)]. If [(f p)] raises [Not_found],
   return [None].
*)

val try_app: ('a -> 'b) -> 'a -> 'b option
(**
   [try_app f p]: Return [Some (f p)]. If [(f p)] raises an exception,
   return [None]. This is a generalisation of [try_find].
*)

val test_app: ('a -> 'b) -> 'a -> bool
(**
   [test_app f p]: Apply (f p), returning [true] if it succeeds and
   [false] if it raises an exception.
*)

val find_first: ('a -> 'b) -> 'a list -> 'b
(**
   [find_first f lst]: Apply f to each element in the list, returning
   the result of the first application to succeed. An application (f
   x) fails if it raises an exception.
*)

val first: ('a -> bool) -> 'a list -> 'a
(**
   [first p lst]: Return the first element of [lst] for which [p] is true.
   Raise [Not_found] if no such element.
*)

(** {5 Sets of strings} *)

module StringSet : Set.S with type elt=string

(** {5 Lazy Evaluation} *)

type ('a)deferred
(** 
   The type of lazy evaluation. A deferred function is evaluated once
   and the result stored and used for subsequent evaluation.
*)

val freeze: (unit -> 'a) -> ('a)deferred
(** [freeze fn]: Defer the evaluation of [fn]. *)

val thaw: ('a) deferred -> 'a
(** 
   Get the value of the deferred function, evaluating the function if
   necessary.
*)
