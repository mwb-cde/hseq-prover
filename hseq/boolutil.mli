(*----
  Copyright (c) 2006-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Utility functions for boolean reasoning *)

val find_unifier:
  Scope.t ->  Gtype.Subst.t
  -> (Term.term -> bool)
  -> Term.term -> (Logic.tagged_form -> bool)
  -> Logic.tagged_form list
  -> (Logic.ftag_ty * Term.Subst.t)
(** [find_unifier scp typenv varp trm exclude forms]: Find the first
    formula in [forms] which unifies with [trm]. Return the tag of the
    formula and the substitution cosntructed by unification. Ignore
    those formulas for which [exclude] is true.

    [varp] determines what is a bindable variable for unification.
    [typenv] is the type environment, to pass to the unifier.  [scp]
    is the scope, to pass to the unifier.  Raise [Not_found] if no
    unifiable formula is found.
*)

val is_iff: Formula.t -> bool
(** [is_iff f]: Test whether [f] is a boolean equivalence.
*)

val is_qnt_opt:
  Term.quant -> (Term.term -> bool)
  -> Logic.tagged_form -> bool
(** [is_qnt_opt kind pred form]: Test whether [form] satifies [pred].
    The formula may by quantified by binders of kind [kind].
*)

val dest_qnt_opt:
  Term.quant->
  Logic.tagged_form -> (Logic.ftag_ty * Term.Binder.t list * Term.term)
(** [dest_qnt_opt forms]: Destruct a possibly quantified tagged
    formula.  Returns the binders, the tag and the formula.
*)

(** [find_qnt_opt kind f pred forms]

    Find the first formula in [forms] to satisfy [pred].  The formula
    may by quantified by binders of kind [kind].  Returns the binders,
    the tag and the formula.

    Raises [Not_found] if no formula can be found which satisfies all
    the conditions.
*)
val find_qnt_opt:
  Term.quant
  -> (Term.term -> bool)
  -> Logic.tagged_form list
  -> (Logic.ftag_ty * Term.Binder.t list * Term.term)

val fresh_thm: Scope.t -> Logic.thm -> bool
(** [fresh_thm th]: Test whether theorem [th] is fresh (a formula of
    the current global scope).
*)

val dest_qnt_implies:
  Term.term
  -> (Term.Binder.t list * Term.term * Term.term)
(** [dest_qnt_implies term]: Split a term of the form [! a .. b: asm
    => concl] into [( a .. b, asm, concl)].
*)

val unify_in_goal:
  (Term.term -> bool)
  -> Term.term -> Term.term -> Logic.node
  -> Term.Subst.t
(** [unify_in_goal varp atrm ctrm goal]: Unify [atrm] with [ctrm] in
    the scope and type environment of [goal].  [varp] identifies the
    variables.
*)

val close_lambda_app:
  Term.Binder.t list
  -> Term.term
  -> (Term.term * Term.term list)
(** [close_lambda_app term]: From term [((% a1 .. an: B) v1 .. vn)],
    return [(% a1 .. an: (!x1 .. xn: B)), [v1; .. ; vn]] where the [x1
    .. xn] close unbound variables in [B].
*)
