(*----
  Copyright (c) 2006-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Support for boolean proofs.

    Many (but not all) of the values here are front-ends to
    values defined elsewhere.
*)


(** {5 Theorems, Rules and Conversions} *)

module Thms:
sig
  (** Theorems used by tactics. A theorem [n] is accessed by
      calling function [n_thm()]. This returns the theorem,
      proving it if necessary. If [n_thm()] has to prove the
      theorem, it stores the result so that subsequent calls to
      [n_thm()] do not have to carry out the proof again. Some
      theorems have a function [make_n_thm()] which actually
      carries out the proof.  *)

  val false_def: Context.t -> Logic.thm
  (** The definition of [false]. *)
  val iff_def: Context.t -> Logic.thm
  (** The definition of [iff]. *)

  (** [iff_equals_thm]: |- !x y: (x iff y) = (x = y) *)
  val make_equals_iff_thm: Context.t -> Logic.thm
  val equals_iff_thm: Context.t -> Logic.thm

  (** [equals_bool_thm]: |- !x y: (x = y) = (x iff y) *)
  val equals_bool_thm: Context.t -> Logic.thm


  (** [bool_eq_thm]: |- !x y: x iff y = ((x => y) and (y=>x)) *)
  val make_bool_eq_thm: Context.t -> Logic.thm
  val bool_eq_thm: Context.t -> Logic.thm

  (** [double_not_thm]: |- ! x: x = (not (not x)) *)
  val make_double_not_thm: Context.t -> Logic.thm
  val double_not_thm: Context.t -> Logic.thm

  (** [rule_true_thm]: |- !x: x = (x=true) *)
  val make_rule_true_thm: Context.t -> Logic.thm
  val rule_true_thm: Context.t -> Logic.thm

  (** rule_false_thm: !x: (not x) = (x=false) *)
  val make_rule_false_thm: Context.t -> Logic.thm
  val rule_false_thm: Context.t -> Logic.thm

  val bool_cases_thm: Context.t -> Logic.thm
  (** [bool_cases_thm]: [! (x:bool): (x=true) | (x=false)] *)

  val cases_thm: Context.t -> Logic.thm
  (** [cases_thm]: |- !P: (~P) | P *)

  val eq_refl_thm: Context.t -> Logic.thm
  (** [eql_refl]: [!x: (x = x)] *)

  val eq_sym_thm: Context.t -> Logic.thm
(** [eql_sym]: [!x y: (x = y) = (y = x)] *)

end

module Rules:
sig
  (** Functions to construct theorems from other theorems.  *)

  val once_rewrite_rule:
    Context.t -> Logic.thm list -> Logic.thm -> Logic.thm
  (** [once_rewrite_rule scp rules thm]: Rewrite [thm] with [rules]
      once.  *)

  val conjunctL: Context.t -> Logic.thm -> Logic.thm
  (** [conjunctL scp thm]: Get the left hand side of conjunct [thm].
      [conjunctL scp << l and r >> = l] *)

  val conjunctR: Context.t -> Logic.thm -> Logic.thm
  (** [conjunctR scp thm]: Get the right hand side of conjunct [thm].
      [conjunctL scp << l and r >> = r] *)

  val conjuncts: Context.t -> Logic.thm -> Logic.thm list
(** [conjuncts scp thm]: Break theorem [thm] into the list of
    conjuncts.  [conjuncts scp << f1 and f2 and .. and fn>> = [f1; f2;
    ..; fn]]
*)

end

module Convs:
sig
  (** Conversions on boolean operators.  *)

  (** [neg_all_conv]: |- (not (!x..y: a)) = ?x..y: not a *)
  val neg_all_conv: Context.t -> Term.term -> Logic.thm

  (** [neg_exists_conv]: |- (not (?x..y: a)) = !x..y: not a *)
  val neg_exists_conv: Context.t -> Term.term -> Logic.thm

end

(** {5 Tactics} *)

val falseA_at: Logic.label -> Tactics.tactic
(** Solve a goal of the form \[ false{_ a}, A |- C \].  [info] is
    unchanged.
*)

val falseA: Tactics.tactic
(** Apply [false_at] to the first instance of [false] in the assumptions *)

val trivial_at: Logic.label -> Tactics.tactic
(** Solve a goal of the form \[ false{_ f}, A |- C \] or \[ A |-
    true{_ f}, C \].  [info] is unchanged.
*)

val trivial: Tactics.tactic
(** Apply [trivial_at] to the first formula that succeeds *)

val cut_thm: Term.term list -> string -> Tactics.tactic
(** Cut a named theorem, with optional instantiation. *)

(** {7 Basic equality reasoning} *)

val eq_sym_rule: Context.t -> Logic.thm -> Logic.thm
(** [eq_sym_rule scp thm]: If the body of [thm] is [ |- x = y], return
    [ |- y=x ].
*)

val eq_symA: Logic.label -> Tactics.tactic
(** [eq_symA a]: Rewrite assumption [a] with [eq_sym_thm] once.
*)

val eq_symC: Logic.label -> Tactics.tactic
(** [eq_symC a]: Rewrite conclusion [c] with [eq_sym_thm] once.
*)

val eq_sym_tac: Logic.label -> Tactics.tactic
(** [eq_sym_tac f]: Try to apply [eq_symA f], if that fails, try
    [eq_symC f].
*)


val eq_tac: Tactics.tactic
(** Prove goals of the form \[A|- x=x{_ c}, C\].  [info] is unchanged.
*)

val eq_at: Logic.label -> Tactics.tactic
(** Apply [eq_tac} at a specific conclusion *)

(** {5 Generalised Rewriting}

    Tactics, conversions and rules for rewriting with a list of
    theorems and assumptions. Combines rewrite planners and rewriting
    and allows the direction of rewriting (left-right/right-left) to
    be specified.
*)

val gen_rewrite_conv:
  Context.t -> Rewrite.control -> Logic.thm list -> Logic.conv
val rewrite_conv:
  Context.t -> Logic.thm list -> Logic.conv
(** [rewrite_conv scp ctrl rules trm]: Rewrite term [trm] with
    theorems [rules] in scope [scp].

    Returns [ |- trm = X ]
    where [X] is the result of rewriting [trm]
*)

val gen_rewrite_rule:
  Context.t -> Rewrite.control -> Logic.thm list
  -> Logic.thm -> Logic.thm
val rewrite_rule:
  Context.t -> Logic.thm list -> Logic.thm -> Logic.thm
(** [rewrite_rule scp ctrl rules thm]: Rewrite theorem [thm] with
    theorems [rules] in scope [scp].

    Returns [ |- X ] where [X] is the result of rewriting [thm]
*)

val gen_rewrite_asm_tac:
  Rewrite.control -> (Logic.label)option -> Logic.rr_type list
  -> Tactics.tactic
(** [gen_rewrite_asm_tac ctrl f rules]: General assumption rewriting tactic.

    Rewrite assumption [f] with list of theorems and assumptions given in
    [rules].

    If [f] is not given, rewrite all assumptions and in the
    sequent.
*)

val gen_rewrite_concl_tac:
  Rewrite.control -> (Logic.label)option -> Logic.rr_type list
  -> Tactics.tactic
(** [gen_rewrite_concl_tac ctrl f rules]: General conclusion rewriting tactic.

    Rewrite conclusion [f] with list of theorems and assumptions given in
   [rules].

    If [f] is not given, rewrite all conclusions in the sequent.  *)

val gen_rewrite_tac:
  Rewrite.control -> (Logic.label)option -> Logic.rr_type list
  -> Tactics.tactic
(** [gen_rewrite_tac ctrl rules f]: General rewriting tactic.

    Rewrite formula [f] with list of theorems and assumptions given in
   [rules].

   If [f] is not given, rewrite all assumptions and conclusions in in
   sequent. If [f] is not given then rewrite both assumptions and conclusions
   in the sequent.  *)

val rewrite_at:
  Logic.thm list -> Logic.label -> Tactics.tactic
val rewrite_tac:
  Logic.thm list -> Tactics.tactic
val once_rewrite_at:
  Logic.thm list -> Logic.label -> Tactics.tactic
val once_rewrite_tac:
  Logic.thm list -> Tactics.tactic
(**
    [rewrite_at thms f]: Rewrite formula [f] with theorems [thms].

    [rewrite_tac thms]:  Rewrite all formulas.

    [once_rewrite_at thms f]: Rewrite formula [f] with theorems [thms] once.

    [once_rewrite_tac thms]:  Rewrite all formulas.
*)

val rewriteC_tac: Logic.thm list -> Tactics.tactic
val rewriteC_at: Logic.thm list -> Logic.label -> Tactics.tactic
val once_rewriteC_tac: Logic.thm list -> Tactics.tactic
val once_rewriteC_at:
  Logic.thm list -> Logic.label -> Tactics.tactic
(**
    [rewriteC_at thms c]: Rewrite conclusion [c] with theorems [thms]

    [rewriteC_tac thms]:  Rewrite all conclusions

    [once_rewriteC_at thms c]: Rewrite conclusion [c] with theorems [thms] once

    [once_rewriteC_tac thms]:  Rewrite all conclusions once
*)

val rewriteA_tac: Logic.thm list -> Tactics.tactic
val rewriteA_at: Logic.thm list -> Logic.label -> Tactics.tactic
val once_rewriteA_tac: Logic.thm list -> Tactics.tactic
val once_rewriteA_at:
  Logic.thm list -> Logic.label -> Tactics.tactic
(**
    [rewriteA_at thms c]: Rewrite assumption [a] with theorems [thms]

    [rewriteA_tac thms]:  Rewrite all assumptions

    [once_rewriteA_at thms c]: Rewrite assumption [a] with theorems [thms] once

    [once_rewriteA_tac thms]:  Rewrite all assumptions once
*)

val gen_replace_tac:
  Rewrite.control -> Logic.label list
  -> (Logic.label)option -> Tactics.tactic
(** [gen_replace_tac ctrl asms f]: Rewrite formula [f] with the
    assumptions in list [asms].  If [f] is not given, rewrite all
    formulas in sequent. If [asms] is not given, use all assumptions
    of the form [l=r] or [!x1 .. xn: l = r]. Doesn't rewrite the
    assumptions used as rewrite rules.
*)

val replace_tac: Logic.label list -> Tactics.tactic
val replace_at: Logic.label list -> Logic.label -> Tactics.tactic
(**
   [replace_at asms f]: Rewrite formula [f] with assumptions in
   list [asms]

   [replace_tac asms f]: Rewrite all formulas with assumptions in
   list [asms]

   If [asms] is empty, use all assumptions of the form [l=r] or [!x1
   .. xn: l = r].  Doesn't rewrite the used assumptions. *)

val replace_rl_tac: Logic.label list -> Tactics.tactic
val replace_rl_at: Logic.label list -> Logic.label -> Tactics.tactic
(** [replace_rl_at asms f]: Rewrite, right to left, formula [f] with
   assumptions in list [asms]

   [replace_rl_tac asms: Rewrite, right to left, all formulas with
   assumptions in list [asms]

   If [asms] is empty, use all assumptions of the form [l=r] or [!x1
   .. xn: l = r].  Doesn't rewrite the used assumptions. *)

val once_replace_tac: Logic.label list -> Tactics.tactic
val once_replace_at: Logic.label list -> Logic.label -> Tactics.tactic
(**
   [once_replace_at asms f]: Rewrite formula [f] with assumptions in
   list [asms] once.

   [once_replace_tac asms f]: Rewrite all formulas with assumptions in
   list [asms] once.

   If [asms] is empty, use all assumptions of the form [l=r] or [!x1
   .. xn: l = r].  Doesn't rewrite the used assumptions. *)

val unfold_at: string -> Logic.label -> Tactics.tactic
(** [unfold f n]: Unfold the definition of [n] at formula [f].

    info: [aforms=[f'], cforms=[]] or [aforms=[], cforms=[f']]
    depending on whether [f] is in the assumptions or conclusions.
    [f'] is the tag of the formula resulting from rewriting.
*)

val unfold: string -> Tactics.tactic
(** [unfold n]: Unfold the definition of [n] *)

(** {7 Boolean equivalence} *)

val iffA_at: Logic.label -> Tactics.tactic
val iffA: Tactics.tactic
(** [iffA l sq]: Elminate the equivalance at assumption [l].

    {L
    g:\[(A iff B){_ l}, asms |- concl\]

    ---->

    g1:\[A{_ l1}, asms |- B{_ l2}, concl\];
    g2:\[B{_ l3}, asms |- A{_ l4}, concl\];
    }

    info: [goals = [g1; g2], aforms=[l1; l3], cforms=[l2; l4], terms = []]
*)

val iffC_at: Logic.label -> Tactics.tactic
val iffC: Tactics.tactic
(** [iffC l sq]: Elminate the equivalence at conclusion [l]

    {L
    g:\[asms |- (A iff B){_ l}, concl\]

    ---->

    g1:\[asms |- (A=>B){_ l}, concl\];
    g2:\[asms |- (B=>A){_ l}, concl\];
    }

    info: [goals = [g1; g2], aforms=[], cforms=[l], terms = []]
*)

val iffE_at: Logic.label -> Tactics.tactic
(** [iffE_at l sq]: Fully elminate the equivalence at conclusion [l]

    {L
    g:\[asms |- (A iff B){_ l}, concl\]

    ---->

    g1:\[A{_ l1}, asms |- B{_ l2}, concl\];
    g2:\[B{_ l3}, asms |- A{_ l4}, concl\];
    }

    info: [goals = [g1; g2], aforms=[l1; l3], cforms=[l2; l4], terms = []]
*)

val iffE: Tactics.tactic
(** Apply [iffE_at] to the first conclusion that matches *)

(**  {5 Eliminating boolean operators}  *)

val direct_alt:
  'a -> ('a -> Tactics.tactic) list
  -> Tactics.tactic
(** [direct_alt tacs info l]: Directed alt. Like {!Tactics.alt} but
    pass [info] and [l] to each tactic in [tacs].  **)

val direct_map_some:
  ('a -> Tactics.tactic) -> 'a list
  ->('a list) Tactics.data_tactic
(** [direct_map_some tac lst l]: Directed map_some. Like
    {!Tactics.map_some} but pass [info] and [l] to [tac]. If [tac]
    fails for [l], then [lst:=l::!lst].  **)

val asm_elim_rules_tac:
  ((Logic.label -> Tactics.tactic) list
   * (Logic.label -> Tactics.tactic) list)
  -> Logic.label
  -> Tactics.tactic
(** [asm_elim_rules (arules, crules) f goal]: Apply elimination
    rules to assumption [f] and to all resulting assumptions and
    conclusions. Assumptions are eliminated with [arules], conclusions
    with [crules]..
*)

val concl_elim_rules_tac:
  ((Logic.label -> Tactics.tactic) list
   * (Logic.label -> Tactics.tactic) list)
  -> Logic.label
  -> Tactics.tactic
(** [concl_elim_rules (arules, crules) f goal]: Apply
    elimination rules to conclusion [f] and to all resulting
    assumptions and conclusions. Assumptions are eliminated with
    [arules], conclusions with [crules].
*)

val elim_rules_tac:
  ((Logic.label -> Tactics.tactic) list
   * (Logic.label -> Tactics.tactic) list)
  -> Logic.label list -> Logic.label list
  -> Tactics.tactic
(** [elim_rules_tac (arules, crules) albls clbls]: Apply
    elimination rules to all assumptions with a label in [albls] and
    all conclusions with a label in [clbls] and with to all resulting
    assumptions and conclusions. The tag of any new formula for which
    the elimination rules fails is stored in arbitrary order and may
    contain duplicates.
*)

val apply_elim_tac:
  (Logic.label list -> Logic.label list
   -> Tactics.tactic)
  -> (Logic.label)option -> Tactics.tactic
(** [apply_elim_tac tac f]: Apply elimination tactic [tac] to formula
    [f]. If [f] is not given, use all formulas in the sequent. The
    tag of any new formula for which the elimination rules fails is
    stored in arbitrary order and may contain duplicates.

    [apply_elim_tac] is intended to be used to wrap
    {!Boollib.elim_rules_tac}.
*)

(** {7 Splitting subgoals}

    A subgoal formula constructed from an operator [op] {e split} is
    split if eliminating the operator results in more than one subgoal
    (or proves the subgoal).
*)

val split_asms_tac:
  Logic.label -> Tactics.tactic
(** Eliminate operators in the assumptions which introduce new
    subgoals. Uses the same rules as {!Boollib.split_tac}.
*)
val split_concls_tac:
  Logic.label -> Tactics.tactic
(** Eliminate operators in the conclusions which introduce new
    subgoals. Uses the same rules as {!Boollib.split_tac}.
*)

val split_at: Logic.label -> Tactics.tactic
(** Eliminate operators in the assumptions and conclusions which
    introduce new subgoals. Resulting tag information may contain
    duplicates.

    In the assumptions, eliminates [false], disjunction ([|]),
    implication ([=>]).

    In the conclusions, eliminates [true], conjunction ([&]).
*)

val split_tac: Tactics.tactic
(** Apply {!split_at} to all formulas in a sequent *)

(** {7 Flattening subgoals}

    A subgoal formula constructed from an operator [op] is {e
    flattened} if eliminating the operator results in at most one
    subgoal (or proves the subgoal).
*)

val flatter_asms_tac:
  Logic.label -> Tactics.tactic
(** Eliminate operators in the assumptions which don't introduce new
    subgoals. Uses the same rules as {!Boollib.flatten_tac}.
*)
val flatter_concls_tac:
  Logic.label -> Tactics.tactic
(** Eliminate operators in the conclusions which don't introduce new
    subgoals. Uses the same rules as {!Boollib.flatten_tac}.
*)

val flatten_tac: Logic.label -> Tactics.tactic
(** Eliminate operators in a formulat which don't
    introduce new subgoals. Resulting tag information may contain
    duplicates.

    In the assumptions, eliminates [false], conjunction ([&]) and
    existential quantification ([?]).

    In the conclusions, eliminates [true], negation ([not]),
    disjunction ([|]), implication ([=>]), universal quantification
    ([!]).

    Doesn't eliminate negation in the assumptions (to avoid
    introducing trivial conclusions).
*)

val flatten_tac: Tactics.tactic
(** Apply {!flatten_at} to all formulas in a sequent *)

(** {7 Scatter subgoals}

    Split and flatten subgoals.
*)

val scatter_at: Logic.label -> Tactics.tactic
(** Eliminate boolean operators in the assumptions and conclusions.

    In the assumptions, eliminates [false], negation ([not]),
    conjunction ([&]) and existential quantification ([?]), disjunction
    ([|]), implication ([=>]).

    In the conclusions, eliminates [true], negation ([not]),
    disjunction ([|]), implication ([=>]), universal quantification
    ([!]), conjunction ([&]) and boolean equivalence ([iff]).

    Resulting tag information may contain duplicates.
*)

val scatter_tac: Tactics.tactic
(** Apply {!scatter_at} to all formulas in a sequent *)

val blast_at: Logic.label -> Tactics.tactic
(** Eliminate boolean operators in a formula
    then try to solve subgoals.

    In the assumptions, eliminates [false], negation ([not]),
    conjunction ([&]) and existential quantification ([?]),
    disjunction ([|]), implication ([=>]) then calls {!Tactics.basic}.

    In the conclusions, eliminates [true], negation ([not]),
    disjunction ([|]), implication ([=>]), universal quantification
    ([!]), conjunction ([&]) and boolean equivalence ([iff]) then
    calls {!Tactics.basic}.

    This is like {!Boollib.scatter_tac}, followed by {!Tactics.basic}.
*)

val blast_tac: Tactics.tactic
(** Apply {!blast_at} to all formulas in a sequent *)


(** {5 Cases} *)

val cases_tac: Term.term -> Tactics.tactic
(** [cases_tac x g]: Cases tactic.

    Add formula [x] to assumptions of [g] and create new subgoal in
    which to prove [x].

    {L
    g:\[asms |- concls\]

    --->

    g1:\[asms |- x{_ t}, concls\]; g2:\[x{_ t}, asms |- concls\]
    }

    info: [goals = [g1; g2], aforms=[t], cforms=[t], terms = []]
*)

val show_tac:
  Term.term -> Tactics.tactic -> Tactics.tactic
(** [show_tac trm tac]: Use [tac] to show that [trm] is true,
    introducing [trm] as a new assumption. If [tac] fails to prove
    [trm], introduces [trm] as the conclusion of a new subgoal.
*)

val show:
  Term.term -> Tactics.tactic -> Tactics.tactic
(** [show trm tac]: Use [tac] to show that [trm] is true, introducing
    [trm] as a new assumption. If [tac] fails to prove [trm],
    introduces [trm] as the conclusion of a new subgoal.

    {!Boollib.show} is a synonym for {!Boollib.show_tac}.
*)

val cases_of: Term.term -> Tactics.tactic
(** [cases_of trm]: Try to introduce a case split based on
    the type of term [trm]. The theorem named ["T_cases"] is
    used, where [T] is the name of the type of [trm].
*)

val cases_with: Logic.thm -> Term.term -> Tactics.tactic
(** Apply {!cases_of} wih the given theorem. *)

(** {5 Modus Ponens} *)

val mp_search: (Logic.label)option -> (Logic.label)option -> Tactics.tactic
val mp_at: Logic.label -> Logic.label -> Tactics.tactic
val mp_tac: Tactics.tactic
(** Modus ponens

    {L g:\[(A=>B){_ a}, A{_ h}, asms |- concls\]

    --->

    g:\[B{_ t}, A{_ h}, asms |- concls\] }

    info: [goals = [], aforms=[t], cforms=[], terms = []]

    [mp_at a h]: If [a] is [! x1 .. xn: A => B] and [h] is [l], try to
   instantiate all of the [x1 .. xn] with values from [h] (found by
   unification).

   [mp_tac] Each (possibly quantified) implication in the assumptions
   is tried, starting with the first and the assumptions are searched
   for a suitable formula.

   [mp_search a h] If either [a] or [h] is None then search for suitable
   assumpitons to use. If either is given, then use it
 *)

val cut_mp_at: Term.term list-> Logic.thm -> Logic.label -> Tactics.tactic
val cut_mp_tac: Term.term list-> Logic.thm -> Tactics.tactic
(** Cut theorem for Modus ponens.

    {L g:\[A{_ a}, asms |- concls\]; thm: |- A => B

    --->

    g:\[B{_ t}, A{_ a}, asms |- concls\] }

    info: [goals = [], aforms=[t], cforms=[], terms = []]

    If [inst] is given, instantiate [thm] with the given terms.

    If [thm] is [! x1 .. xn: A => B] and [a1] is [l], try to instantiate
   all of the [x1 .. xn] with values from [a] (found by unification).

    [cut_mp_at inst a]: Apply modus-ponens to assumption [a].

    [cut_mp_tac inst a]: Apply modus-ponens to the first (possibly
   quantified) suitable assumption.  *)

val back_search: (Logic.label)option -> (Logic.label)option -> Tactics.tactic
val back_at: Logic.label -> Logic.label -> Tactics.tactic
val back_tac: Tactics.tactic
(** Match, backward tactic.

    {L g:\[(A=>B){_ a}, asms |- B{_ c}, concls\]

    --->

    g1:\[asms |- A{_ t}, concls\] }

    info: [goals = [g1], aforms=[], cforms=[t], terms = []]

    [back_at a c] If [a] is [! x1 .. xn: A => B] and [a1] is [l], try to
   instantiate all of the [x1 .. xn] with values from [c] (found by
   unification).

    [back_tac] Each (possibly quantified) implication in the assumptions
   is tried with each of the conclusions

    [back_search a c] If [a] is not given then try each of the
   assumptions, starting with the first. If [c] is not given then try
   the assumption against each of the conclusions, starting with the
   first.
 *)

val cut_back_at: Term.term list -> Logic.thm -> Logic.label -> Tactics.tactic
val cut_back_tac: Term.term list -> Logic.thm -> Tactics.tactic
(** Match, backward tactic.

    {L
    g:\[asms |- B{_ c}, concls\]; thm: |- A => B

    --->

    g1:\[asms |- A{_ t}, concls\]
    }

    info: [goals = [g1], aforms=[], cforms=[t], terms = []]

    If [inst] is given, instantiate [thm] with the given terms.

    If [thm] is [! x1 .. xn: A => B] and [a1] is [l], try to
    instantiate all of the [x1 .. xn] with values from [c] (found by
    unification).

    [cut_back_at inst thm c]: Use assumption [c]

    [cut_back_tac inst thm]: The assumptions are searched for a suitable
    formula.
*)

(** {5 More tactics} *)

val equals_at: Logic.label -> Tactics.tactic
val equals_tac: Tactics.tactic
(** Convert boolean equality to iff *)

(** {7 Induction tactics} *)

val asm_induct_tac:
  Logic.label -> Logic.label -> Tactics.tactic
(** [asm_induct_tac a c]: Apply the induction scheme of
    assumption [a] to conclusion [c].

    See {!Boollib.induct_tac} for details about the form of the
    induction scheme.
*)

val induct_at: Logic.thm -> Logic.label -> Tactics.tactic
(** [induct_at thm c]: Apply induction theorem [thm] to conclusion
    [c].

    Theorem [thm] must be in the form:
    {L ! P a .. b: (thm_asm P a .. b) => (thm_concl P a .. b)}
    where
    {L
    thm_concl P d .. e = (! x .. y: (pred x .. y) => (P d .. e x .. y))
    }
    The order of the outer-most bound variables is not relevant.

    The conclusion must be in the form:
    {L ! a .. b f .. g: (pred a .. b) => (C a .. b f ..g) }
*)

val induct_tac: Logic.thm -> Tactics.tactic
(** [induct_tac thm]: Apply [induct_at] to the each conclusion until it
    succeeds. *)

val induct_on: string -> Tactics.tactic
(** [induct_on n]: Apply induction to the first
    universally quantified variable named [n] in conclusion [c] (or the
    first conclusion to succeed). The induction theorem is [thm], if
    given or the theorem [thm "TY_induct"] where [TY] is the name of
    the type constructor of [n].

    Theorem [thm] must be in the form:
    {L ! P a .. b: (thm_asm P a .. b) => (thm_concl P a .. b)}
    where
    {L
    thm_concl P a .. b= (! x: (P x a .. b))
    }
    The order of the outer-most bound variables is not relevant.

    The conclusion must be in the form:
    {L ! n f .. g: (C n f ..g) }
    [n] does not need to be the outermost quantifier.
*)

val induct_with: Logic.thm -> string -> Tactics.tactic
(** [induct_with thm n]: Apply induction to the first universally quantified
   variable named [n] in the first conclusion to succeed using induction
   theorem [thm].

    Theorem [thm] must be in the form: {L ! P a .. b: (thm_asm P a .. b) =>
   (thm_concl P a .. b)} where {L thm_concl P a .. b= (! x: (P x a .. b)) }
   The order of the outer-most bound variables is not relevant.

    The conclusion must be in the form: {L ! n f .. g: (C n f ..g) } [n] does
   not need to be the outermost quantifier.  *)
