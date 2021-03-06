(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Term rewriting

    Rewriting uses the rewriter from {!Rewritekit}, instantiated for
    {!Term.term} together with an implementation of a generic term
    rewrite planner {!Rewrite.Planner}.

    Terms are rewritten with rules of the form [x=y], which may be
    ordered by a predicate. The rewrite planner can be controled to limit
    the number of rewrite rules applied and to determine whether
    rewriting is top-down or bottom-up.

    A term is rewritten by first calling a planner to construct a
    plan which can then be passed to the rewriter.

    For testing only, an instance of the planner is provided as module
    {!Rewrite.TermPlanner}.
*)

(** {5 Rewrite Rules} *)

(** Rewrite rules are terms of the form [x = y]. Rules can be ordered
    by a predicate [order]. Ordered rewrite rules are only applied to
    a term [t] if [order x t] is true, where [order x t] is
    interpreted as [x] is less-than [t].
*)

type order = (Term.term -> Term.term -> bool)
(** Ordering predicates for rewrite rules. [order x y] is interpreted
    as true if [x] is less-than [y].
*)

type rule = (Term.Binder.t list * Term.term * Term.term)
(** The representation used by the rewriting engine. An rule of the
    form [! v1 .. vn. lhs = rhs] for left-right rewriting is broken to
    [([v1; .. ; vn], lhs, rhs)].
*)

type orule = (Term.Binder.t list * Term.term * Term.term * order option)
(** The representation used by the rewriting engine. An rule of the
    form [! v1 .. vn. lhs = rhs] for left-right rewriting is broken to
    [([v1; .. ; vn], lhs, rhs, opt_order)]. If the rule is unordered,
    then [opt_order] is [None], if the rule is ordered by [p] then
    [opt_order] is [Some p]. For right-left rewriting, the rule is
    broken to [([v1; ..; vn], rhs, lhs, opt_order)].
*)

(** {5 Controlling rewriting} *)

(** The direction of rewriting (left to right or right to left) and
    whether rewriting is top-down or bottom-up are both controlled by
    options to the rewriter.

    It is also possible to limit the number of times the rewriter makes
    changes. This is mainly used to ensure that the rewriter always
    terminates. It is also used to apply the rewriter once, usually to
    ensure that only one occurence of term is rewritten.

    The options apply to the rewriter and therefore affect all rewrite
    rules.
*)

type direction
(** The direction of rewriting. This is ignored by the rewriter and
    planner, but is included here for use elsewhere.
*)

val leftright: direction
(** Rewrite from left to right (this is the usual direction) *)

val rightleft: direction
(** Rewrite from right to left (this reverses rewrite rules) *)

type strategy = TopDown | BottomUp
(** The rewriting strategy *)

val topdown: strategy
(** Rewrite from the top-most term down (the default). This is fast
    but less thorough than bottom-up.
*)

val bottomup: strategy
(** Rewrite from lowest-terms up. This is thorough but can be
    inefficient since the result of rewriting at one level can be
    discarded by rewriting at a higher level.
*)

(** How the options are passed to the planner. *)
type control =
    {
      depth: int option;
      rr_dir: direction;
      rr_strat: strategy
    }

val control:
  direction -> strategy -> (int)option -> control
(** Make a rewrite control.

    [strat] is the strategy to use.

    [dir] is the direction of rewriting.

    [max] is the maximum number of times to rewrite in the term.
*)

val default: control
(** The default rewrite control.

    [default_control = control TopDown leftright None]
*)

(** {5 The Rewriter} *)

exception Quit of exn
exception Stop of exn

(**
   Planned Rewriting

   Rewriting based on a pre-determined plan.

   Rewrites a node [n] by following the direction in a plan [p]. Plan
   [p] specifies the rules to be applied to each node and the order in
   which a node is to be rewritten.

   (For hseq, a node is a term).
*)

(**
    [term_key]: Keys identifying terms.
*)
type term_key =
  | Ident  (** Term [Id] *)
  | BVar   (** Term [Bound] *)
  | MVar   (** Term [Meta] *)
  | FVar   (** Term [Free] *)
  | Appln  (** Term [App] *)
  | Quant  (** Term [Qnt] *)
  | AllQ   (** Term [Qnt] ([All]) *)
  | ExQ   (** Term [Qnt] ([Ex]) *)
  | LamQ   (** Term [Qnt] ([Lambda]) *)
  | Constn (** Term [Const] *)
  | AnyTerm    (** Any term *)
  | NoTerm   (** No term *)
  | Neg of term_key (** Negate a key *)
  | Alt of term_key * term_key  (** Alternative keys *)


val is_free_binder: Term.Binder.t list -> Term.term -> bool
(** Utility function to construct a predicate which tests for
    variables in unification. [is_free_binder qs t] is true if [t] is
    a bound variable [Bound b] and [b] occurs in [qs].
*)

val limit_reached: (int)option -> bool
(** [limit_reached d] is [true] iff [d = Some 0] *)

(**
   [TermData]: The data used to instantiate the generic rewriter.
*)
module TermData:
  (Rewritekit.Data
   with type data = (Scope.t                (** Scope *)
                     * Term.Subst.t    (** Quantifier environment *)
                     * Gtype.Subst.t) (** Type environment *)
   and type rule = rule
   and type node = Term.term
   and type substn = Term.Subst.t
   and type key = term_key)

type data = TermData.data
type key = term_key


(** The Rewriter *)
module TermRewriter:
  (Rewritekit.T
   with type data =
    (Scope.t (** Scope *)
     * Term.Subst.t    (** Quantifier environment *)
     * Gtype.Subst.t)  (** Type environment *)
   and type node = TermData.node
   and type substn = Term.Subst.t
   and type rule = TermData.rule
   and type key = TermData.key)

(** {5 Toplevel rewrite functions} *)

type ('a)plan = (key, 'a)Rewritekit.plan
(** [('a)plan]: Plans for rewriting terms, using rules of type ['a]. *)

val rewrite:
  data -> (rule)plan -> Term.term -> (data * Term.term)
(**
    [rewrite data p t]: Rewrite term [t] with plan [t].
    This is the basic function provide by {!Rewritekit.Make}.
*)

(** {5 Generic Rewrite Planner} *)

module Planner:
sig

  module type Data =
  sig
    type rule (** The type of rewrite rules. *)
    type data (** Additional data to pass to the planning functions. *)

    (** [dest]: How to destruct rewrite rules. *)
    val dest: data -> rule
        -> (Term.Binder.t list * Term.term * Term.term * order option)
  end
    (** Data passed to a rewriter planner. *)

  module type T =
  sig
    (** Rewrite plan constructors.

        Two planning functions are provided. The first,
        {!Rewrite.Planner.T.make}, is for general rewriting. The
        second, {!Rewrite.Planner.T.make_env}, for rewriting w.r.t a
        type context.

        Both take rewrite rules as universally quantified equalities
        of the for [!v1 .. vn. lhs = rhs]. The variables [v1 .. vn]
        are taken as variables which can be instantiated by the
        rewriter. If the rule is not an equality then rewriting will
        fail.

        Rewriting breaks a rule [lhs = rhs] to an equality. If
        rewriting is left-right, the equality is [lhs = rhs]; if
        rewriting is right-left then the equality is [rhs = lhs].

        For left-right rewriting, every variable (from [v1 .. vn])
        appearing in [rhs] must also appear in [lhs] otherwise the
        rule cannot be used. Similarly for right-left rewriting.  *)

    exception No_change

    type a_rule
    type rule_data

    val make:
      rule_data ->
      Scope.t -> control -> a_rule list
      -> Term.term
      -> (Term.term * (a_rule)plan)
    (** Make a rewrite plan using a list of universally quantified
        rewrite rules.  *)

    val make_env:
      rule_data
      -> Scope.t
      -> control
      -> Gtype.Subst.t
      -> a_rule list -> Term.term
      -> (Term.term * Gtype.Subst.t * (a_rule)plan)
    (** [make_env tyenv rules trm]: Make a rewrite plan for [trm]
        w.r.t type environment [tyenv] using [rules]. Return the new
        term and the type environment contructed during rewriting.  *)

    (** {7 Exposed for debugging} *)

    type data = (Scope.t               (** Scope *)
                 * Term.Subst.t   (** Quantifier environment *)
                 * Gtype.Subst.t) (** Type environment *)

    type internal_rule = (Term.Binder.t list
                          * Term.term
                          * Term.term
                          * order option
                          * a_rule)

    type rewrite_net = internal_rule Net.net

    val src_of: internal_rule -> a_rule

    val match_rewrite:
      control -> data -> internal_rule -> Term.term
      -> (a_rule * Term.term * Gtype.Subst.t)

    val match_rr_list:
      control -> data -> internal_rule list
      -> Term.term -> a_rule list
      -> (Term.term * Gtype.Subst.t
          * control * (a_rule)list)

    val match_rewrite_list:
      control -> data -> rewrite_net -> Term.term -> a_rule list
      -> (Term.term * Gtype.Subst.t
          * control * (a_rule)list)

    val check_change: ('a)plan -> unit
    val check_change2: ('a)plan -> ('a)plan -> unit

    val make_list_topdown:
      control -> rewrite_net -> data -> Term.term
      -> (Term.term * Gtype.Subst.t
          * control * (a_rule)plan)

    val make_list_bottomup:
      control -> rewrite_net-> data -> Term.term
      -> (Term.term * Gtype.Subst.t
          * control * (a_rule)plan)

    val make_rewrites: rule_data -> a_rule list -> rewrite_net

    val make_list:
      rule_data -> control -> Scope.t -> Gtype.Subst.t
      -> a_rule list -> Term.term
      -> (Term.term * Gtype.Subst.t * (a_rule)plan)

  end
  (** Rewriter Planner *)

end
(** The generic rewrite planner. *)

module Make:
  functor (A: Planner.Data) ->
    (Planner.T with type a_rule = A.rule
               and type rule_data = A.data)
(** Make a rewrite planner. *)


(** {5 Utility functions} *)

(** {7 Plans} *)

val mk_node: ('a)plan list -> ('a)plan
(** [mk_node ps]: Apply rewrite a node with plans [ps]. *)

val mk_keyed: key -> ('a)plan list -> ('a)plan
(** [mk_keyed k ps]: Apply plans [ps] to a node with key [k]. *)

val mk_rules: 'a list -> ('a)plan
(** [mk_rules rs]: Rewrite the node with rules [rs]. *)

val mk_subnode: int -> ('a)plan -> ('a)plan
(** [mk_subnode i p]: Rewrite subnode [i] with plan [p]. *)

val mk_branches: ('a)plan list -> ('a)plan
(** [mk_branches ps]: Rewrite the subnodes of the node with plans
    [ps], applying the i'th plan to the i'th subnode.
*)

val mk_skip: ('a)plan
(** Do nothing. *)

val mapping: ('a -> 'b) -> ('a)plan -> ('b)plan
(** [mapping f p]: Map function [f] to each rule in [p]. *)

val pack: ('a)plan -> ('a)plan
(** [pack p]: Pack plan [p], removing redundant directions. *)

val pack_rules: ('a)list -> ('a)plan
val pack_node: ('a)plan list -> ('a)plan
val pack_keyed: key -> ('a)plan list -> ('a)plan
val pack_branches: ('a)plan list -> ('a)plan
val pack_subnode: int -> 'a plan -> 'a plan

(** {7 Keys} *)

val key_of: Term.term -> key
(** [key_of t]: Get the key of term [t]. *)
val anyterm: key
(** Key matching any term *)
val noterm: key
(** Key matching no term *)
val alt_key: key -> key -> key
(** [alt_key k1 k2]: Key matching [k1] or [k2] *)
val neg_key: key -> key
(** [neg_key k]: Key not matching [k] *)
val ident_key: key
(** Key of [Term.Id] *)
val fvar_key: key
(** Key of [Term.Free] *)
val bvar_key: key
(** Key of [Term.Bound] *)
val appln_key: key
(** Key of [Term.App] *)
val quant_key: key
(** Key of [Term.Qnt] *)
val allq_key: key
(** Key of [Term.Qnt], with [Term.All] *)
val exq_key: key
(** Key of [Term.Qnt], with [Term.Ex] *)
val lamq_key: key
(** Key of [Term.Qnt], with [Term.Lam] *)
val constn_key: key
(** Key of [Term.Constn] *)


(** {7 Term Rewrite Planner}

    An instantiation of the generic rewrite planner, for testing and
    experiments.
*)

module TermPlannerData:
  (Planner.Data
   with type rule = Term.term
   and type data = unit)
(** Data used to instantiate the generic planner. *)

module TermPlanner:
  (Planner.T
   with type a_rule = TermPlannerData.rule
   and type rule_data = unit)
(** The rewriter planner instantiated for terms. *)

val make_plan_full:
  Scope.t -> control -> Gtype.Subst.t
  -> Term.term list -> Term.term
  -> (Term.term * Gtype.Subst.t * (Term.term) plan)
(** [make_plan_full scp ctrl tyenv rules trm]: Make a rewrite plan for
    [trm] w.r.t type environment [tyenv] using rewrite rules
    [rules]. Return the new term, the type environment contructed
    during rewriting and the rewrite plan. Control [ctrl] can specify
    the maximum number of rewrites to carry out and whether rewriting
    is top-down or bottom-up.
*)

val make_plan:
  Scope.t -> control -> Term.term list -> Term.term
  -> (Term.term * (Term.term)plan)
(** [make_plan_full scp ctrl tyenv rules trm]: Make a rewrite plan for
    [trm] using rewrite rules [rules]. Return the new term and the
    rewrite plan. Control [ctrl] can specify the maximum number of
    rewrites to carry out and whether rewriting is top-down or
    bottom-up.
*)
