(*----
  Name: basic.mli
  Copyright Matthew Wahab 2005-2018
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

(** Basic constants and data structures. *)

(** {5 Base representation of logic types} *)

(*
type typ_const = Ident.t
(** Representation of user-defined type constructors (could merged
    into [pre_typ]).
*)
*)

(** The base representation of types. *)
type ('idtyp) pre_typ =
  | Var of 'idtyp
  (** Type variables. *)
  | Constr of Ident.t * ('idtyp) pre_typ list
  (** User defined type constructors. *)
  | WeakVar of 'idtyp
(**
   Weak type variables. These bind to anything except a
   variable and aren't (normally) renamed. They are used in a sequent
   calculus when a variable type 'x can occur in more than one
   sequent. If 'x is bound in one sequent, then it must have that
   binding in every sequent in which it occurs. (Like weak types in
   ML).
*)

type gtype_id
(** Type identifers. *)

val mk_gtype_id: string -> gtype_id
(** Make a type identifier. *)
val gtype_id_string: gtype_id -> string
(** Get a string representation of a type identifier. *)
val gtype_id_copy: gtype_id -> gtype_id
(** Make a new, unique with the same string representation as another. *)
val gtype_id_equal: gtype_id -> gtype_id -> bool
(** Equality of gtype_id. *)
val gtype_id_greaterthan: gtype_id -> gtype_id -> bool
val gtype_id_lessthan: gtype_id -> gtype_id -> bool
val gtype_id_compare: gtype_id -> gtype_id -> Order.t
(** Orderings on gtype_id.

    Maintains the invariant:
    - [gtype_id_equal x y]
      =>
      [not (gtype_id_lessthan x y)] and [not (gtype_id_greaterthan x y)].
    - [gtype_id_lessthan x y = not(gtype_id_greaterthan x y)]
*)

type gtype = (gtype_id)pre_typ
(** The actual representation of types. *)

(** String representation of types. *)
val string_tconst: Ident.t -> string list -> string

(** {5 Base Representation of logic terms} *)

(** Built-in constants that can appear in terms  *)
type const_ty =
  | Cnum of Num.num    (* big numbers *)
  | Cbool of bool

val const_compare: const_ty -> const_ty -> Order.t
(** Total ordering on constants. *)
val const_lt: const_ty -> const_ty -> bool
(** Less-than ordering on constants. *)
val const_leq: const_ty -> const_ty -> bool
(** Less-than-equal ordering on constants. *)
val string_const: const_ty -> string
(** String representation of a constant. *)

(** {7 Basis of quantified terms} *)

(** Quantifiers for terms. *)
type quant =
  | All | Ex | Lambda
  | Gamma (** Meta-constants *)

val quant_string: quant -> string
(** The string representation of quantifiers. *)

(** {7 Binders} *)

type binders
(** Associating bound variables with their binding term. *)
val mk_binding: quant -> string -> gtype -> binders
(**
    [mk_binding k n ty] makes a binder of kind [k], with name [n] and
    type [ty]. This binder will be distinct from any other under
    [binder_equality].
*)
val dest_binding: binders -> (quant * string * gtype)
(** Destructor for binders. *)

val binder_kind: binders -> quant
(** [binder_kind b]: The kind of binder binding variable [b]. *)

val binder_name: binders -> string
(** [binder_name b]: The name of bound variable [b]. *)

val binder_type: binders -> gtype
(** [binder_type b]: The type of bound variable [b]. *)

val binder_equality: binders -> binders -> bool
(** Equality of binders. *)

val binder_greaterthan: binders -> binders -> bool
val binder_lessthan: binders -> binders -> bool
val binder_compare: binders -> binders -> Order.t
(** Orderings on binders.

    Maintains the invariant:
    - [binder_equality x y]
      =>
      [not (binder_lessthan x y)] and [not (binder_greaterthan x y)].
    - [binder_lessthan x y = not(binder_greaterthan x y)]
*)

(** {7 Terms} *)

(** The representation of a term *)
type term =
  | Id of Ident.t * gtype   (** Identifiers *)
  | Bound of binders     (** Bound variables *)
  | Free of string * gtype  (** Free variables *)
  | Meta of binders       (** Meta variables (use for skolem constants) *)
  | App of term * term    (** Function application *)
  | Qnt of binders * term (** Binding terms *)
  | Const of const_ty     (** Constants *)
