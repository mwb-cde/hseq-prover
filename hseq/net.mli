(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(**
   Term Nets, structures to store data indexed by a term.

   Look-up is by inexact matching of a term against the keys to get a
   list of possible matches. More exact mactching (such as
   unification) would be applied to this list to select required data.

   A net is a tree having, at each level, a list of labels paired with
   trees. Each label corresponds to a part of a term. An index is
   formed by treating a term as a list of labels, this list describes
   the path through the tree to the data.

   Nets are used to cut the number of elements that need to be
   considered by more expensive matching, particularly
   unification. Net operations assume some terms will be unification
   variables (determined by a given predicate). Look-up operations
   favour more exact matching. When a term matches both a constant and
   a unification variable, the constant will occur first in the list
   of possibilities returned by look-up operations.
*)

(** {5 Labels} *)

(**
    Labels corresponding to the parts of terms considered during
    matching.
*)
type label =
  | Var
  | App
  | Bound of Term.quant
  | Quant of Term.quant
  | Const of Term.Const.t
  | Cname of Ident.t
  | Cmeta of string
  | Cfree of string

(** {7 Label operations} *)

(**
   [term_to_label varp t]: Return the label for term [t] together with
   the remainder of the the term as a list of terms.

   [varp] determines which terms are treated as variables.

   [rst] is the list of terms built up by repeated calls
   to [term_to_label]. Initially, it should be [[]].

   Examples:

   [?y: ! x: (x | z) & y]  (with variable z)
   -->
   [[Qnt(?); Qnt(!); App; App; Bound(!); Var; Bound(?)]]

   [?y: ! x: (x | z) & y]  (with no variables,  z is free)
   -->
   [[Qnt(?); Qnt(!); App; App; Bound(!); Cname(z); Bound(?)]]
*)
val term_to_label:
  (Term.term -> bool) -> Term.term -> Term.term list
  -> (label * Term.term list)

(** {5 Nets} *)

(**
    Nets. Each node holds: data at this level, nets tagged by constant
    labels, nets tagged by [Var].
*)
type 'a net = Node of ('a list
                       * (label * 'a net) list
                       * ('a net) option )

(** {7 Operations on nets} *)

(** Make an empty net *)
val empty: unit -> 'a net

(** Test for an empty net. *)
val is_empty: 'a net -> bool

val lookup: 'a net -> Term.term -> 'a list
(**
    [lookup net t]: Return the list of items indexed by terms matching
    term [t].  Ordered with the best matches first.

    Term [t1] is a better match than term [t2 ]if variables in [t1] occur
    deeper in its term structure than those for [t2]. E.g. with variable
    [x] and [t=(f 1 2)], [t1=(f x y)] is a better match than [t2=(x 1 2)]
    because [x] occurs deeper in [t1] than in [t2]. ([t1] is likely to be
    rejected by exact matching more quickly than [t2] would be.)
*)

val update:
  ('a net -> 'a net) -> (Term.term -> bool)
  -> 'a net -> Term.term -> 'a net
(**
    [update f net trm]: Apply function [f] to the subnet of [net]
    identified by [trm] to update the subnet. Propagate the changes
    through the net. If applying function [f] results in an empty
    subnet, than remove these subnets. This is the basic operation for
    updating a net. Functions [add] and [insert] provide more usable
    interfaces to [update].
*)

val add:
  (Term.term -> bool) -> 'a net
  -> Term.term -> 'a
  -> 'a net
(**
    [add varp net t r]: Add [r], indexed by term [t] with variables
    identified by [varp] to [net].  Replaces but doesn't remove
    previous bindings of [t].
*)

val insert:
  ('a -> 'a -> bool) ->
  (Term.term -> bool) -> 'a net
  -> Term.term -> 'a
  -> 'a net
(**
    [insert order varp net t r]: Add data [r], indexed by term [t] with
    variables identified by [varp] to [net]. Data [r] is stored in the
    order defined by order (smaller terms first).  Replaces but doesn't
    remove previous bindings of [t].
*)

val delete: (Term.term -> bool) -> 'a net
  -> Term.term -> ('a -> bool) -> 'a net
(**
    [delete varp net t test]: Remove data indexed by [t] in net and
    satisfying test.  Fails silently if [t] is not found.  Needs the
    same [varp] as used to add the term to the net.
*)

val iter: ('a -> unit) -> 'a net -> unit
(**
   [iter f net]: Apply [f] to each data item stored in a net.
*)

val print: ('a -> unit) -> 'a net -> unit
(**
   [print p net]: Print the contents of [net] using printer [p].
*)

(** {7 Debugging} *)

val insert_in_list:
  ('a -> 'a -> bool)
  -> 'a -> 'a list -> 'a list
