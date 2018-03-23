(*----
  Name: ltype.mli
  Copyright Matthew Wahab 2018
  Author: Matthew Wahab <mwb.cde@gmail.com>

  This file is part of HSeq

  HSeq is free software; you can redistribute it and/or modify it under
  the terms of the Lesser GNU General Public License as published by
  the Free Software Foundation; either version 3, or (at your option)
  any later version.

  HSeq is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the Lesser GNU General Public
  License for more details.

  You should have received a copy of the Lesser GNU General Public
  License along with HSeq.  If not see <http://www.gnu.org/licenses/>.
  ----*)

(** Manipulating types of the logic. *)

val set_name:
  ?memo:(string, Ident.thy_id)Hashtbl.t
  -> Scope.t -> Basic.gtype -> Basic.gtype
(** [set_name ?strict ?memo scp ty]: set names in type [ty] to their
    long form.

    [memo] is an optional memoisation table.
*)

val unfold: Scope.t -> Basic.gtype -> Basic.gtype
(**
   [unfold scp ty]: Unfold the definition of type [ty] from the scope
   [scp].

   @raise [Not_found] if no definition.
*)

val well_formed_full:
  (Basic.gtype -> (string * Basic.gtype)option)
  -> Scope.t -> Basic.gtype -> bool
(** [well_formed_full pred scp t]: ensure that [t] is well-formed

   See [Gtypes.well_formed_full] for a description
*)

val well_formed: Scope.t -> Basic.gtype -> bool
(** [well_formed scp t]: ensure that [t] is well-formed in scope [scp] *)

val well_defined: Scope.t -> (string)list -> Basic.gtype -> unit
(** [well_defined scp args ty]: Test [ty] for well-definedness. every
    constructor occuring in [ty] must be defined. Variables in [ty]
    must have a name in [args] and weak variables are not permitted in
    [ty].
*)

val check_decl_type: Scope.t -> Basic.gtype -> unit
(** [check_decl_type scp ty]: Ensure type [ty] is suitable for the
    declaration of a term. Fails if [ty] contains a weak variable.
*)

val unify_env:
  Scope.t -> Basic.gtype -> Basic.gtype
  -> Gtypes.substitution -> Gtypes.substitution
(** [unify_env scp ty1 ty2 env]: Unify two types in context [env],
    return a new subsitution.
*)

val unify: Scope.t -> Basic.gtype -> Basic.gtype -> Gtypes.substitution
(** [unify]: unify two types, returning the substitution.
*)

val matching_env:
  Scope.t -> Gtypes.substitution
  -> Basic.gtype -> Basic.gtype -> Gtypes.substitution
(**
   [matching_env scp env t1 t2]: Match type [t1] with type [t2] w.r.t
   context [env]. This unifies [t1] and [t2], but only variables in
   type [t1] can be bound.

   Raises an exception if matching fails.
*)

val matches_env:
  Scope.t -> Gtypes.substitution
  -> Basic.gtype -> Basic.gtype -> Gtypes.substitution
(** [matches_env scp env t1 t2]: Match type [t1] with type [t2] w.r.t
    context [env]. This unifies [t1] and [t2], but only variables in
    type [t1] can be bound.

    Silently returns unchanged substitution on failure.
*)

val matches: Scope.t -> Basic.gtype -> Basic.gtype -> bool
(** Toplevel for [matches_env]. *)