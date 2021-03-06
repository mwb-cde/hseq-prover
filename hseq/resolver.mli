(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** {7 Overloading}

    Operator overloading works by maintaining a list of identifiers
    which have the same symbol together with their types. When the
    symbol occurs in a term, as a short name, a type is inferred for
    the name and the list of identifiers is searched for a matching
    type. The first matching identifier is used. If there is no match,
    the first identifier in the list is chosen.

    The standard table for operator overloading is
    {!Parser.overload_table}, which maintains a list of identifiers and
    types for each overloaded symbols. Identifiers are normally added
    to the front of the list but a position can be passed, to prefer
    one identifier over others. (The search begins from the front of
    the list.)

    The toplevel for operator overloading is
    {!Resolver.resolve_term} which takes a function which
    carries out the search for an identifier with a matching
    type. Function {!Resolver.make_lookup} constructs a suitable
    search function, from a symbol look-up table.
*)

val resolve_term:
  Scope.t
  -> (string -> Basic.gtype -> (Ident.t * Basic.gtype))
  -> Term.term
  -> (Term.term * Gtype.substitution)
(** [resolve_term scp env t]: Resolve the symbols in term [t].

    For each free variable [Free(s, ty)] in [t], lookup [s] in [env]
    to get long identifier [id].  If not found, use [Free(s, ty)].  If
    found, replace [Free(s, ty)] with the identifier [Id(id, ty)].

    [env] should return an identifier-type pair where type matches (in
    some sense) [ty].

    [env] must raise Not_found if [s] is not found.
*)

val make_lookup:
  Scope.t
  -> (string -> (Ident.t * Basic.gtype) list)
  -> (string -> Basic.gtype -> (Ident.t * Basic.gtype))
(** [make_lookup scp db]: Make an environment suitable for
    {!Resolver.resolve_term} from table [db].

    [db] must raise [Not_found] when items are not found.

    [make_lookup db s ty]: returns the identifier-type pair associated
    by [db] with [s] for which [ty] is unifies with type in scope
    [scp].

    [make_lookup db s ty] raise Not_found if [s] is not found in [db].
*)


(** {7 Debugging} *)

val default:
  string -> Basic.gtype -> (Ident.t * Basic.gtype) list
  -> (Ident.t * Basic.gtype) option

type resolve_memo =
    {
      types: (Ident.t, Basic.gtype)Hashtbl.t;
      idents: (string, Ident.t)Hashtbl.t;
      symbols: (string, Ident.t)Hashtbl.t;
      type_names: (string, Ident.thy_id)Hashtbl.t
    }

type resolve_arg =
    {
      scp: Scope.t;
      inf: int ref;
      memo: resolve_memo;
      qnts: Term.substitution;
      lookup: (string -> Basic.gtype -> (Ident.t * Basic.gtype))
    }

val resolve_aux:
  resolve_arg
  -> Gtype.substitution
  -> Basic.gtype
  -> Term.term
  -> (Term.term * Basic.gtype * Gtype.substitution)

val memo_find:
  ('a, 'b)Hashtbl.t
  -> ('a -> 'c -> 'b)
  -> 'c
  -> 'a -> 'b

val find_type :
  Scope.t
  -> string
  -> Basic.gtype -> (Ident.t * Basic.gtype) list
  -> (Ident.t * Basic.gtype)
