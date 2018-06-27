(*----
  Name: term.mli
  Copyright Matthew Wahab 2005-2019
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

(** Term representation and basic functions. *)

open Basic
open Gtype

(** {5 Very basic operations} *)

val equals : term -> term -> bool
(** [equals s t]: Syntactic equality of terms [s] and [t]. This is
    essentially the same as [Pervasives.=] over terms except that
    references (type [binders]) are compared as first class objects
    (using [Pervasives.==]).
*)

val compare: term -> term -> Order.t
(** [compare s t]: Ordering of [s] and [t]. It is always true that [compare s t
    = 0] iff [equals s t ].

    Defines the order Const < Id < Bound < App < Qnt and includes types in the
    comparison.
 *)

(** {5 Data structures indexed by terms.} *)

(** {7 Balanced Trees.} *)

module TermTreeData: Treekit.TreeData
module TermTree: (Treekit.BTreeType with type key = term)

type ('a)tree = ('a)TermTree.t
(** Trees indexed by terms *)

val empty_tree: unit -> ('a)tree
val basic_find: term -> ('a)tree -> 'a
val basic_bind: term -> 'a -> ('a)tree -> ('a)tree
val basic_remove: term -> ('a)tree -> ('a)tree
val basic_member: term -> ('a)tree -> bool

(** {7 Hashtables} *)

type ('a)table
(** Tables with a term as the key. *)

val empty_table: unit -> ('a) table
val table_find: term -> 'a table -> 'a
val table_member: term -> 'a table -> bool
val table_remove: term -> 'a table -> unit
val table_add : term -> 'a -> 'a table -> unit
val table_rebind : term -> 'a -> 'a table -> unit

(** {5 Operations on terms} *)

(** {7 Recognisers} *)

val is_atom: term -> bool
val is_qnt: term -> bool
val is_app: term -> bool
val is_bound: term -> bool
val is_free: term -> bool
val is_ident: term -> bool
val is_const: term -> bool

(** {7 Constructors} *)

val mk_atom: Basic.baseterm -> term
val mk_qnt: binders -> term -> term
val mk_bound: binders -> term
val mk_free: string -> Gtype.t -> term
val mk_app: term -> term -> term
val mk_const: Basic.const_ty -> term
val mk_typed_ident: Ident.t -> Gtype.t -> term

val mk_ident: Ident.t -> term
val mk_short_ident: string -> term

(** {7 Destructors} *)
val dest_atom: term -> Basic.baseterm
val dest_qnt: term -> (binders * term)
val dest_bound: term -> binders
val dest_free: term -> (string * Gtype.t)
val dest_app: term -> (term * term)
val dest_const: term -> Basic.const_ty
val dest_ident: term -> (Ident.t * Gtype.t)

(** {6 Specialised Manipulators} *)

(** {7 Meta variables}

    qA meta variable is a Meta with quant [Basic.Meta]. A meta
    variable is treated like a term identifier, not a bound variable.
*)

val mk_meta: string -> Gtype.t -> term
val is_meta: term -> bool
val dest_meta: term -> binders

(** {7 Constants} *)

val destbool: term -> bool

(** {7 Function application} *)

val is_fun: term-> bool
(** Test for application of a function. *)

val mk_comb: term -> term list -> term
(** [mk_comb x y]: Make a function application from [x] and [y].
    [mk_comb f [a1;a2;...;an]] is [((((f a1) a2) ...) an).]
*)
val mk_fun: Ident.t -> term list -> term
(** [mk_fun f args]: make function application [f args]. *)

val flatten_app: term -> term list
(** [flatten_app trm]: flatten an application in [trm] to a list of
    terms.  [flatten_app (((f a1) a2) a3)] is [[f; a1; a2; a3]] and
    [flatten_app (((f a1) (g a2)) a3)] is [[f; a1; (g a2); a3]].
*)

val get_fun_args: term -> (term * term list)
(** Get the function and arguments of a function application. *)

val get_args: term -> term list
(** Get the arguments of a function application. *)
val get_fun: term -> term
(** Get the function of a function application .*)
val dest_fun: term-> Ident.t * term list
(** Get the function identifier and arguments of a function application. *)

val rator: term -> term
(** Get the operator of a function application.  [rator << f a >>] is
    [<< f >>].
*)
val rand: term -> term
(** Get the operand of a function application.  [rator << f a >>] is
    [<< a >>].
*)

val dest_unop: Basic.term -> (Ident.t * Basic.term)
(** [dest_unop t]: Destruct unary operator [t], return the identifier
    and argument.

    @raise [Failure] if not enough arguments.
*)

val dest_binop: Basic.term -> (Ident.t * Basic.term * Basic.term)
(** [dest_binop t]: Destruct binary operator [t], return the
    identifier and two arguments.

    @raise [Failure] if not enough arguments.
*)

val strip_fun_qnt:
  Ident.t -> Basic.term -> Basic.binders list
  -> (Basic.binders list * Basic.term)
(** [strip_fun_qnt f term qs]: Strip applications of the form [f (% x:
    P)] returning the bound variables and P. ([qs] should be [[]]
    initially).
*)

(** {7 Identifier (Id) terms} *)

val get_ident_id: term-> Ident.t
val get_ident_type: term-> Gtype.t

(** {7 Free variables} *)

val get_free_name: term-> string
val get_free_vars: term -> term list
(** Get the free variables in a term. *)

(** {7 Quantified and bound terms} *)

(** [get_binder t]: If [t] is [Qnt(q,_)] or [Bound(q)], return
    [q]. Otherwise raise [Failure].
*)
val get_binder: term -> binders

val get_binder_name: term -> string
(** [get_binder_name t]: The name of the variable bound in [t]. *)
val get_binder_type: term -> Gtype.t
(** [get_binder_type t]: The type of the variable bound in [t]. *)
val get_binder_kind: term -> quant
(** [get_binder_kind t]: The kind of binder in [t]. *)
val get_qnt_body: term -> term
(** [get_qnt_body t]: Get the body quantified by term [t]. *)

val get_free_binders: term -> binders list
(** [get_free_binders t]: Get the list of bound variables loose in [t]
    (those which occur outside their binding term).
*)

val strip_qnt: Basic.quant -> term -> binders list * term
(** [strip_qnt q t]: remove outermost quantifiers of kind [k] from
    term [t].
*)
val rebuild_qnt: binders list -> term -> term
(** [rebuild_qnt qs t]: rebuild quantified term from quantifiers [qs]
    and body [b].
*)

(**  {5 Error handling}  *)

type error = { msg: string; terms: (term)list; next: (exn)option }
exception Error of error

val term_error: string -> term list -> exn
val add_term_error: string -> term list -> exn -> exn

(** {5 Substitution in terms} *)

val rename: term -> term
(** [rename t]: Rename bound variables in term [t] (alpha-conversion). *)


(** {5 Retyping} *)

val retype: Gtype.substitution -> term -> term
(** [retype tyenv t]: Reset the types in term [t] using type
    substitution [tyenv].  Substitutes variables with their concrete
    type in [tyenv].
*)

(*
val retype_with_check: Scope.t -> Gtype.substitution -> term -> term
(** [retype_with_check scp tyenv t]: Reset the types in term [t] using
    type substitution [tyenv].  Substitutes variables with their
    concrete type in [tyenv]. Check that the new types are in scope
    [scp].
*)
*)

val retype_pretty_env:
  Gtype.substitution -> term -> (term * Gtype.substitution)
(** [retype_pretty]: Like [retype], make substitution for type
    variables but also replace other type variables with new, prettier
    names
*)
val retype_pretty: Gtype.substitution -> term -> term
(** [retype_pretty_env]: Like [retype_pretty] but also return the
    substitution storing from the bindings/replacements generated
    during retyping.
*)

(** {5 Combined type/binder renaming} *)

val full_rename: Gtype.substitution -> term -> (term * Gtype.substitution)
(** [full_rename env t]: Rename all type variables and bound variables
    in term [t]. *)

val retype_index:
  int -> term -> (term * int * Gtype.substitution)
(** [retype idx t]: Rename all type variables in term [t]. *)

type substitution
(** The type of term substitutions. *)

(** {7 Operations on a substitution} *)

val empty_subst: unit -> substitution
(** Make an empty substitution. *)
val find: term -> substitution -> term
(** [find t env]: Find term [t] in substitution [env]. *)
val bind: term -> term -> substitution -> substitution
(** [bind t r env]: Bind term [r] to term [t] in [env]. *)
val member: term -> substitution -> bool
(** [member t env]: True if term [t] has a binding in [env]. *)
val remove: term -> substitution -> substitution
(** [remove t env]: Remove the binding for term [t] in [env].  *)
val replace: substitution -> term -> term
(** [replace env t]: Replace term [t] with its binding in [env],
    renaming as necessary to ensure that binders are unique.
*)

(** {7 Substitution functions} *)

val subst: substitution -> term -> term
(** [subst env t]: Substitute the bindings in [env] in term [t].
*)

val qsubst: (term * term) list -> term -> term
(** [qsubst_quick [(v1, r1); ..; (vn, rn)] t]: Substitute term [ri]
    for term [vi] in term [t].
*)

(** {7 Chase functions, needed for unification (some redundancy).} *)

val chase: (term -> bool) -> term -> substitution -> term
(** [chase varp t env]: Follow the chain of bindings in [env]
    beginning with term [t] and ending with the first term for which
    [varp] is false or which has no binding in [env]. ([varp] is true
    for terms which can be given a binding in [env] e.g. for
    unification.)
*)

val fullchase: (term -> bool) -> term -> substitution -> term
(** [fullchase varp t env]: chase term [t] in [env]. If [varp] is true
    for the result, return [t] otherwise return the result. This is
    like [chase], but only returns terms which aren't variable.
*)

val chase_var: (term -> bool) -> term -> substitution -> term
(** [chase_var varp t env]: Follow the chain of bindings in [env]
    beginning with term [t] and ending with the first term for which
    [varp] is false or which has no binding in [env]. ([varp] is true
    for terms which can be given a binding in [env] e.g. for
    unification.)
*)

val subst_mgu: (term -> bool) -> substitution -> term -> term
(** [subst_mgu varp env t]: Construct the most general unifier from
    subsitution [env] and term [t]. Predicate [varp] determines which
    terms are considered variable by the unifier. This is only needed
    if variables in the unification of [x] and [y] can occur in both
    [x] and [y]. If the variables only occur in [x], then [subst env
    x] is enough.
*)

(** {6 Operations using substitution} *)

val inst: term -> term -> term
(** [inst t r]: Instantiate a quantified term [t] with term [r] *)

val mk_qnt_name: Scope.t -> Basic.quant -> string -> term -> term
(** [mk_qnt_name scp qnt n t]: Make a quantified term, with quantifier
    [qnt], from term [t], binding free variables named [n].
*)
val mk_typed_qnt_name:
  Scope.t -> Basic.quant -> Gtype.t -> string -> term -> term
(** [mk_typed_qnt_name scp qnt ty n t]: Make a quantified term, of
    kind [qnt], from term [t], binding all free variables named
    [n]. Set the type of the quantifier to [ty].
*)

(**  {5 Conversion of a term to a string} *)

val string_typed_name: string -> Gtype.t -> string
val string_term: term -> string
val string_inf_term:
  ((Ident.t -> int) * (Ident.t -> bool)) -> term -> string
val string_term_basic: term -> string


(** {5 Comparisons} *)

val least: term list -> term
(** [least ts]: The least term in [ts], using [term_lt].
*)

val term_lt: term -> term -> bool
(** [term_lt]: Less-Than-or-Equal. Defines the same order as [compare], but
    ignores types. *)

val term_leq: term -> term -> bool
(** [term_leq]: Less-Than-or-Equal, ignores types. *)

val term_gt: term -> term -> bool
(** [term_gt]: Greater-Than, defined in terms of [term_leq].
*)

val is_subterm: term -> term -> bool
(** [is_subterm x y]: Test whether [x] is a subterm of [y].
*)
