(*-----
 Name: tactics.mli
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2005
----*)

(** Tactics and Tacticals *)

type tactic = Logic.tactic
(** A tactic is a function of type [Logic.node -> Logic.branch] *)

(** {5 Support functions} *)

(** {7 Error reporting} *)

val error: string -> exn
(** [error s]: Make a Result.Error exception with message [s]. *)

val add_error : string -> exn -> exn
(** [add_error s err]: Add [error s] to exception [err]. *)

(** 
   {7 Accessing elements of a list} 

   Simpler versions of {!Lib.get_one} and {!Lib.get_two}. Both raise
   exception [Failure msg] on failure, with [msg] an optional
   argument.
*)

val get_one: ?msg:string -> 'a list -> 'a
(** Get the first element of a list. *)

val get_two: ?msg:string -> 'a list -> ('a * 'a)
(** Get the first two elements of a list. *)

(** {7 Formulas} *)

val drop_tag : Logic.tagged_form -> Formula.form
(** Get the formula of a tagged formula. *)

val drop_formula: Logic.tagged_form -> Tag.t
(** Get the tag of a tagged formula. *)

(** {7 Formula labels} *)

val fnum: int -> Logic.label
(** Make a label from an integer. *)

val ftag: Tag.t -> Logic.label
(** Make a label from a tag. *)

val fname: string -> Logic.label
(** Make a label from a string. *)

val (!!): int -> Logic.label
(** Formula index to label. [!! x] is [fnum x]. *)

val (!~): int -> Logic.label
(**  Assumption index to label.  [!~ x] is [fnum (-x)]. *)

val (!$): string -> Logic.label
(** Formula name to label. [!$ x] is [fname x]. *)

(** {7 Sequents} *)

val asms_of : Logic.Sequent.t -> Logic.tagged_form list
(** Get the assumptions of a sequent. *)
val concls_of : Logic.Sequent.t -> Logic.tagged_form list
(** Get the conclusions of a sequent. *)
val sqnt_tag : Logic.Sequent.t -> Tag.t
(** Get the tag of a sequent. *)

(** {7 Nodes} *)

val sequent : Logic.node -> Logic.Sequent.t
(** Get sequent of a node. *)
val scope_of : Logic.node -> Scope.t
(** Get the scope of a node. *)
val typenv_of : Logic.node -> Gtypes.substitution
(** Get the type environment of a node. *)
val node_tag: Logic.node -> Tag.t
(** Get the tag of a node. *)

val get_tagged_asm: Logic.label -> Logic.node -> Logic.tagged_form
(** Get an assumption and its tag by label.*)
val get_tagged_concl: Logic.label -> Logic.node -> Logic.tagged_form
(** Get a conclusion and its tag by label.*)

val get_asm: Logic.label -> Logic.node -> Formula.form
(** Get an assumption by label.*)
val get_concl: Logic.label -> Logic.node -> Formula.form
(** Get a conclusion by label.*)
val get_form: Logic.label -> Logic.node -> Formula.form
(** Get a formula by label. First tries [get_concl] then [get_asm]. *)

(** {7 Branches} *)

val branch_tyenv: Logic.branch -> Gtypes.substitution
(** Type environment of a branch. *)

val branch_subgoals: Logic.branch -> Logic.Sequent.t list
(** Subgoals of a branch. *)

val has_subgoals : Logic.branch -> bool
(** Test whether a branch has subgoals. *)

val num_subgoals : Logic.branch -> int
(** Get the number of subgoals in a branch. *)

(** {7 Information records} *)

val mk_info: unit -> Logic.info
(** Make an empty information record. *)

val empty_info: Logic.info -> unit
(** 
   [empty_info info]: Empty the information record [info].
   Equivalent to [info:=mk_info()].
 *)

val subgoals: Logic.info -> Tag.t list
(** 
   [subgoals info]: Get subgoals of [info].
   Equivalent to [(!info).goals]
 *)

val aformulas: Logic.info -> Tag.t list
(** 
   [aformulas info]: Get tags of assumption formulas from [info].
   Equivalent to [(!info).aforms]
*)

val cformulas: Logic.info -> Tag.t list
(** 
   [cformulas info]: Get tags of conclusion formulas from [info].
   Equivalent to [(!info).cforms]
*)

val constants: Logic.info -> Basic.term list
(** 
   [constants info]: Get constants from [info].  Equivalent to
   [(!info).terms]
 *)

val set_info : 
    Logic.info option -> 
      (Tag.t list * Tag.t list * Tag.t list * Basic.term list)
      -> unit
(** 
   A version of {!Logic.add_info}, packaged for use, in tactics, with
   {!Tactics.data_tac}.
*)

(** {7 Utility functions} *)

val extract_consts: 
    Basic.binders list -> Term.substitution -> Basic.term list
(** 
   [extract_consts qs sb]: [extract_consts qs sb] extracts the
   bindings for each of the binders in [qs] from substitution [sb],
   returning the terms in the same order as the binders. [qs] is
   typically obtained by stripping the binders from a formula. [sb] is
   typically constructed by unification.
 *)

val qnt_opt_of: 
    Basic.quant_ty -> (Basic.term -> bool) -> Basic.term -> bool
(**
   [qnt_opt_of k pred t]: Apply predicate [pred] to the body of
   possibly quantified term [t]. The outermost quantifiers of kind [k]
   are stripped off before [pred] is applied.  Returns [pred body]
   where [(_, body)=strip_qnt k t].
*)

val first_asm : 
    (Logic.tagged_form -> bool) -> Logic.Sequent.t
      -> Logic.tagged_form
(** 
   Get the first assumption in a sequent which satisfies a predicate. 
   Raise Not_found if no such assumption.
*)

val first_concl : 
    (Logic.tagged_form -> bool) -> Logic.Sequent.t
      -> Logic.tagged_form
(** 
   Get the first conclusion in a sequent which satisfies a predicate. 
   Raise Not_found if no such assumption.
*)

val first_form : 
    (Logic.tagged_form -> bool) -> Logic.Sequent.t
      -> Logic.tagged_form
(** 
   Get the first formula in a sequent which satisfies a
   predicate. Raise [Not_found] if no such assumption. Searches the
   assumptions then the conclusions of the sequent.
*)

val first_asm_label : 
    Logic.label option -> (Formula.form -> bool) 
      -> Logic.node -> Logic.label
(** 
   [first_asm_label ?c pred sq]: If a is [Some(x)] then return [x].
   Otherwise, get the label of the first assumption whose formula
   satisifies [pred]. Raise Not_found if no such assumption.

   Mostly used to unpack the argument to a tactic, where [a] is the
   optional label identifying a formula and [pred] is used if [a] is
   not given.
*)

val first_concl_label : 
    Logic.label option -> (Formula.form -> bool) 
      -> Logic.node -> Logic.label
(** 
   [first_concl_label ?c pred sq]: If c is [Some(x)] then return [x].
   Otherwise, get the label of the first conclusion whose formula
   satisifies [pred]. Raise Not_found if no such conclusion.

   Mostly used to unpack the argument to a tactic, where [c] is the
   optional label identifying a formula and [pred] is used if [c] is
   not given.
*)

(** 
   {5 Basic tacticals and tactics} 

   Primitive tactics and tacticals needed by the tacticals.
*)

val foreach: tactic -> Logic.branch -> Logic.branch
(** [foreach tac br]: Apply [tac] to each subgoal of branch [br]. *)

val skip : tactic
(** The tactic that does nothing. Alway succeeds. *)

val fail : ?err:exn -> tactic
(** The tactic that always fails. Raises [Failure] or [?err] if given. *)

val data_tac: ('a -> unit) -> 'a -> tactic
(** 
   Evaluate an expression. [data_tac f data g] evaluates [(f data)]
   then behaves like {!Tactics.skip}.
*)

(** {5 Tacticals} *)

val seq : tactic list -> tactic 
(**
   [seq tacl]: Apply each tactic in [tacl] in sequence to the subgoals
   resulting from the previous tactic. Fails if [tacl] is empty.
*)

val (++): tactic -> tactic -> tactic
(**
   [tac1 ++ tac2]: Apply [tac1] then, if there are subgoals, apply [tac2]
   to the subgoals. [tac1 ++ tac2] is [seq [tac1; tac2]].
*)

val alt:  tactic list -> tactic 
(**
   [alt tacl]: Apply each tactic in [tacl], in sequence, until one succeeds.
   Fails if no tactic succeeds. 
*)

val (//) : tactic -> tactic -> tactic
(**
   [tac1 // tac2]: Apply [tac1], if that fails, apply [tac2].
   [tac1 // tac2] is [alt [tac1; tac2]].
*)

val thenl : tactic ->  tactic list -> tactic 
(**
   [thenl tac tacl]: Apply tactic [tac] then pair each of the tactics
   in [tacl] with a resulting subgoal. If [tag n] results in subgoals
   [g1, g2, .. gn], the tactics are matched up to produce [tac1 g1,
   tac2 g2, .. , tacn gn]. Excess tactics in [tacl] are silently
   discarded. Excess subgoals are appended to the result of the tactics.
*)

val (--) : tactic ->  tactic list -> tactic 
(**
   [tac -- tacl]: Synonym for [thenl tac tacl].
*)

val repeat : tactic -> tactic
(**
   [repeat tac]: Apply [tac] at least once then repeat until it fails
   or there are no more subgoals.
*)

val cond : (Logic.node -> bool) -> tactic -> tactic -> tactic
(**
   [cond pred ttac ftac g]:  Conditional application.
   If [pred g] is true then [ttac g] else [ftac g].
*)

val (-->) : (Logic.node -> bool) -> tactic -> tactic 
(** 
   One-armed conditional.  [pred --> tac] is [cond pred tac skip],
   applying [tac] if condition [pred] is met.
*)

val restrict : (Logic.branch -> bool) -> tactic -> tactic
(**
   [restrict pred tac g]:  Restrict the result of applying a tactic.
   Fails if [pred (tac g)] is false otherwise behaves as [(tac g)].
*)

val notify_tac : ('a -> unit) -> 'a -> tactic -> tactic
(**
   [notify_tac f x tac g]: Notify [tac g] succeeded.
   Applies [tac g] then, if the tactic suceeded, apply [f x].
   Fails if [tac g] fails.
*)

val map_every: ('a -> tactic) -> 'a list -> tactic
(**
   [map_every tac xs]: Sequentially apply the tactics formed by [(tac
   x)], for each [x] in [xs].  [map_every tac [y1; y2; .. ; yn]] is
   [(tac y1) ++ (tac y2) ++ .. ++ (tac yn)].

   Fails if function [(tac x)] fails for any [x] in [xs] or if any of
   the tactics [(tac x)] fail. Does nothing if [xs] is initially empty.
*)

val map_first: ('a -> tactic) -> 'a list -> tactic
(**
   [map_first tac xs]: Apply the first tactic formed by [(tac
   x)], for each [x] in [xs].  [map_every tac [y1; y2; .. ; yn]] is
   [(tac y1) ++ (tac y2) ++ .. ++ (tac yn)].

   Fails if function [(tac x)] fails for any [x] in [xs] or if all of the
   resulting tactics fail. Fails if [xs] is initially empty.
*)

val map_some: ('a -> tactic) -> 'a list -> tactic
(**
   [map_some tac xs]: Sequentially apply the tactics formed by [(tac
   x)], for each [x] in [xs], allowing some tactics to fail.

   Fails if function [(tac x)] fails for any [x] in [xs] or if all of
   the tactics [(tac x)] fail. Fails if [xs] is initially empty.
*)

val seq_some: tactic list -> tactic
(**
   [seq_some tacl xs]: Sequentially apply the tactics in [tacl],
   allowing some tactics to fail.

   Fails if every tactic in [tacl] fails or if [tacl] is initially empty.

   [seq_some tacl] is equivalent to [map_some tacl (fun x -> x)]
*)

val foreach_asm: (Logic.label -> tactic) -> tactic
(**
   [foreach_asm tac goal]: Sequentially apply [tac l] to each
   assumption in [goal], beginning with the first assmuption, where [l]
   is the label of each assumption considered.

   Fails if no instance of [tac l] succeeds.
*)

val foreach_concl: (Logic.label -> tactic) -> tactic
(**
   [foreach_concl tac goal]: Sequentially apply [tac l] to each
   conclusion in [goal], beginning with the first assmuption, where [l]
   is the label of each assumption considered.

   Fails if no instance of [tac l] succeeds.
*)

val foreach_form: (Logic.label -> tactic) -> tactic
(**
   Apply {!Tactics.foreach_asm} then {!Tactics.foreach_concl}, failing
   if both fail.
*)

(** 
   {5 Tactics}

   The tactics in this module which abstract from those defined in
   {!Logic.Tactics} should be prefered to those in {!Logic.Tactics}.
   Where tactics take an argument [?info] and the tag details aren't
   given, they can be found in the equivalent tactic in
   {!Logic.Tactics}.
*)

val rotateA : ?info:Logic.info -> tactic
(** Rotate the assumptions. *)

val rotateC : ?info:Logic.info -> tactic
(** Rotate the conclusions. *)

val copyA : ?info:Logic.info -> Logic.label -> tactic
(** Copy an assumption.*)

val copyC : ?info:Logic.info -> Logic.label -> tactic
(** Copy a conclusion. *)

val lift : ?info:Logic.info -> Logic.label -> tactic
(** 
   Move a formula to the top of the list of assumptions/conclusions.
*)

val deleteA: ?info:Logic.info -> Logic.label -> tactic 
(** [deleteA l]: Delete the assumption labelled  [l]. *)

val deleteC: ?info:Logic.info -> Logic.label -> tactic 
(** [deleteC l]: Delete the conclusion labelled  [l]. *)

val delete: ?info:Logic.info -> Logic.label -> tactic 
(** [delete l]: Delete the formula labelled  [l]. *)

val deleten: Logic.label list -> Logic.tactic
(**  [deleten ls]: Delete the formulas identified by a label in [ls]. *)

(** {7 Logic rules}

   Apply the basic rules to the first assumption/conclusion
   which will succeed 

   If assumption [a], conclusion [c] or formula [f] is not
   found, these will search for a suitable assumption/conclusion.
   (Parameter [f] is used for formulas which can be either 
   in the assumptions or the conclusions).

   Tag information provided by the rules is as in {!Logic.Tactics}.
*)

val trueC : ?info:Logic.info -> ?c:Logic.label -> tactic
(** Entry point to {!Logic.Tactics.trueC}. *)
val conjC : ?info:Logic.info -> ?c: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.conjC}. *)
val conjA : ?info:Logic.info -> ?a: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.conjA}. *)
val disjC : ?info:Logic.info -> ?c: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.disjC}. *)
val disjA : ?info:Logic.info -> ?a: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.disjA}. *)
val negC : ?info:Logic.info -> ?c: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.negC}. *)
val negA : ?info:Logic.info -> ?a: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.negA}. *)
val implC : ?info:Logic.info -> ?c: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.implC}. *)
val implA : ?info:Logic.info -> ?a: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.implA}. *)
val existC : ?info:Logic.info -> ?c: Logic.label -> Basic.term -> tactic 
(** Entry point to {!Logic.Tactics.existC}. *)
val existA : ?info:Logic.info -> ?a: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.existA}. *)
val allC : ?info:Logic.info -> ?c: Logic.label -> tactic
(** Entry point to {!Logic.Tactics.allC}. *)
val allA : ?info:Logic.info -> ?a: Logic.label -> Basic.term -> tactic
(** Entry point to {!Logic.Tactics.allA}. *)

val instA: ?info:Logic.info
    -> ?a:Logic.label -> Basic.term list -> tactic
(**
   Instantiate a universally quantified assumption. Generalises
   [allA] to a list of terms. [instA a trms] applies [allA a t] for
   each [t] in [trms]. [?info] is set to the result of the last
   instantiation. Fails if there are more terms then variables.
*)

val instC: ?info:Logic.info
    -> ?c:Logic.label -> Basic.term list -> tactic
(**
   Instantiate an existentially quantified conclusion. Generalises
   [existC] to a list of terms. [instc a trms] applies [existC a t]
   for each [t] in [trms]. [?info] is set to the result of the last
   instantiation. Fails if there are more terms then variables.
*)

val inst_tac: ?info:Logic.info
    -> ?f:Logic.label -> Basic.term list -> tactic
(**
   Instantiate a formula. Tries {!Tactics.instA} then {!Tactics.instC}.
*)

val cut: ?info:Logic.info 
  -> ?inst:Basic.term list -> Logic.thm -> tactic
(** 
   [cut th]: Cut [th] into the sequent. If [~inst:trms] is given then the
   top-most variables of the theorem are instantiated with [trms]. 
   Entry point to {!Logic.Tactics.cut}. 
*)


val betaA: ?info:Logic.info -> Logic.label -> tactic 
(**
   [betaA l sq]: beta conversion of assumption [l]

   {L
   F((%x.P x) c){_ l}, asm |- concl
   ---->
   F(P c){_ l}, asm |- concl
   }

   raise [Not_found] if assumption not found.

   info: [goals = [], aforms=[l], cforms=[], terms = []]
 *)

val betaA_tac: ?info:Logic.info -> ?a:Logic.label -> tactic 
(**
   [betaA_tac ?info ?a]: Front-end to {!Tactics.betaA}. If [?a] is not
   given, apply [betaA] to each assumption.
*)


val betaC: ?info:Logic.info -> Logic.label -> tactic 
(**
   [betaC l sq]: beta conversion of conclusion [l]

   {L
   asms |- F((%x.P x) c){_ l}, concls
   ---->
   asms |- F(P c){_ l}, concls
   }

   raise [Not_found] if conclusion not found.

   info: [goals = [], aforms=[l], cforms=[], terms = []]
 *)


val betaC_tac: ?info:Logic.info -> ?c:Logic.label -> tactic 
(**
   [betaC_tac ?info ?a]: Front-end to {!Tactics.betaC}. If [?c] is not
   given, apply [betaC] to each assumption.
*)

val beta_tac : ?info:Logic.info -> ?f:Logic.label -> tactic
(** 
   [beta_tac]: Apply beta conversion to a formula in the goal.  If
   [?f] is not given, beta convert conclusions and then the
   assumptions. Fails if no change is made.
*)

val name_tac: ?info:Logic.info -> string -> Logic.label -> tactic
(** 
   [name_tac ?info n lbl]: Name formula [lbl] with [n]. 
   Entry point to {!Logic.Tactics.nameA} and {!Logic.Tactics.nameC}. 
*)

val basic : 
    ?info:Logic.info -> ?a:Logic.label -> ?c:Logic.label -> tactic
(** 
   Proves the goal \[A{_ a}, asms |- B{_ c}, concls\] if A is
   alpha-equal to B.  Entry point to {!Logic.Tactics.basic}.
*)

val unify_tac : ?info: Logic.info ->  
  ?a:Logic.label -> ?c:Logic.label -> Logic.tactic
(**
   [unify_tac a c g]: Try to unify assumption [a] with conclusion [c].

   Assumption [a] may be universally quantified.  Conclusion [c] may
   be existentially quantified. Toplevel universal/existential
   quantifiers will be stripped, and the bound variables treated as
   variable for the unification. If unification succeeds, the
   toplevel quantifiers are instantiated with the terms found by
   unification.
   
   Final action is to apply [basic] to solve the goal if the terms
   are alpha-equal.

   Defaults: [a=(fnum -1)], [c=(fnum 1)].
*)

val substA : 
    ?info:Logic.info -> Logic.label list -> Logic.label -> tactic
(** Entry point to {!Logic.Tactics.substA}. *)

val substC : 
    ?info:Logic.info -> Logic.label list -> Logic.label -> tactic
(** Entry point to {!Logic.Tactics.substC}. *)

(** {5 Derived tactics and tacticals} *)

val named_tac : 
    ?info: Logic.info -> (info:Logic.info -> tactic) 
      -> string list -> string list 
	-> tactic
(** 
   [named_tac tac anames cnames]: Apply [tac], renaming the
   assumptions and conclusions produced with the names in [anames] and
   [cnames] respecatively. The number of names does not have to match
   the number of assumptions/conclusions produced.

   Actions: apply [tac ~info:inf goal], rename each of
   [Drule.aformulas inf] with a name from [anames], rename each of
   [Drule.cformulas inf] with a name from [cnames], in order. Set
   [info=inf'] where [inf'] is [inf], with the formula tag produced by
   renaming.
*) 

(** {7 Pattern matching tacticals} *)

(** {8 Support functions} *)

val find_match_formulas: 
    Gtypes.substitution
  -> Scope.t -> (Basic.term -> bool) 
    -> Basic.term -> Logic.tagged_form list -> Logic.label
(**
   [find_match_formulas scp varp t fs]: Find a match for a term in list
   of tagged formulas.  Return the tag of the first formula in [fs]
   to unify with term [t] in scope [scp].  [varp] determines which
   terms can be bound by unification.  raise Not_found if no match.

   Only free variables are bound in the matching process.
   e.g. in [<< !x. y and x >>] only [y] is a bindable variable 
   for the match.
 *)

val find_match_asm : 
    Gtypes.substitution
  -> Basic.term -> Logic.Sequent.t -> Logic.label
(** 
   [find_match_asm tyenv t sq]: Find a match for [t] in the assumptions of
   [sq].  Return the tag of the first formula in the assumptions to
   unify with term [t] in the scope of sequent [sq].
   raise Not_found if no match.
 *)

val find_match_concl :     
    Gtypes.substitution
  -> Basic.term -> Logic.Sequent.t -> Logic.label
(** 
   [match_concl t sq]: Find a match for [t] in the assumptions of
   [sq].  Return the tag of the first formula in the assumptions to
   unify with term [t] in the scope of sequent [sq].  raise Not_found
   if no match.
*)

(** {8 Tacticals} *)

val match_asm: Basic.term -> (Logic.label -> tactic) -> tactic
(** 
   [match_asm trm tac g]: Apply a tactic to the assumption matching 
   term.

   Find the label [l] of the first assumption, in the first subgoal of
   [g], which matches [trm] then apply tactic [tac l] to [g].  Fails
   if [tac l] fails or if there is no matching assumption.

   Free variables in trm may be bound in the matching process.
   e.g. in [<< !x. y and x >>] only [y] is a bindable variable 
   for the match.
*)

val match_concl: Basic.term -> (Logic.label -> tactic) -> tactic
(** 
   [match_concl trm tac g]: Apply a tactic to the conclusion matching
   a term.

   Find the label [l] of the first conclusion, in the first subgoal of
   [g], which matches [trm] then apply tactic [tac l] to [g].  Fails
   if [tac l] fails or if there is no matching conclusion.

   Free variables in trm may be bound in the matching process.
   e.g. in [<< !x. y and x >>] only [y] is a bindable variable 
   for the match.
*)

val match_formula: Basic.term -> (Logic.label -> tactic) -> tactic
(** 
   [match_formula trm tac g]: Apply a tactic the assumption or
   conclusion matching a term.

   Find the label [l] of the first formula, in the first subgoal of
   [g], which matches [trm] then apply tactic [tac l] to [g].  The
   match is carried out first on the assumptions then on the
   conclusions. Fails if [tac l] fails or if there is no matching
   formula in the subgoal.

   Free variables in trm may be bound in the matching process.
   e.g. in [<< !x. y and x >>] only [y] is a bindable variable 
   for the match.
*)

val specA: ?info:Logic.info
    -> ?a:Logic.label -> tactic
(**
   Specialize an existentially quantified assumption. [specA a trms]
   repeatedly applies [existA], failing if [a] is not an
   existentially quantified formula. 

   info: [aforms=[tg], constants = cs] where [tg] is the tag of the
   specialised assumption and [cs] are the constants generated by
   [existA], in the order they were generated.
*)

val specC: ?info:Logic.info
    -> ?c:Logic.label -> tactic
(**
   Specialize a universally quantified assumption. [specC a trms]
   repeatedly applies [allC], failing if [c] is not universally
   quantified.

   info: [cforms=[tg], constants = cs] where [tg] is the tag of the
   specialised conclusion and [cs] are the constants generated by
   [allC], in the order they were generated.
*)

val spec_tac: ?info:Logic.info
    -> ?f:Logic.label -> tactic
(**
   Specialize a formula. Tries {!Tactics.specC} then {!Tactics.specA}.

   info: [cforms=[tg], constants = cs] or [aforms=[tg], constants =
   cs] where [tg] is the tag of the specialised formula and [cs] are
   the new constants in the order they were generated.
*)



(** {7 Rewriting tactics} *)

val leftright : Rewrite.direction
(** Left to right rewriting. *)
val rightleft : Rewrite.direction
(** Right to left rewriting. *)

val rewrite_control: 
    ?max:int -> ?strat:Rewrite.strategy 
      -> Rewrite.direction -> Rewrite.control
(**
   [rewrite_control max strat dir]: Make a rewrite control. Default
   strategy is top-down ([?strat=Rewrite.topdown]).
*)

val is_rewrite_formula: Basic.term -> bool
(** 
   [is_rewrite_formula f]: Test whether [f] is an equality or a
   universally quantified equality (e.g. of the form [l=r] or [! x1
   .. x2 : l = r]).
*)

module Rewriter: 
sig
(** Generalising rewriting. 

   General purpose rewriting functions including rewriting with lists
   of theorems and assumptions (rather than rewrite plans).
 *)

  open Rewrite.Planned

  type ('a)plan = ('a)Rewrite.Planned.plan
  (** Rewrite plans *)

  type rule = Logic.rr_type
  (** Rewrite rules *)

  val pure_rewriteA: 
      ?info:Logic.info -> ?term:Basic.term
      -> (rule)plan -> Logic.label
	-> tactic
    (** [pure_rewriteA info p l]: Rewrite assumption [l] with
       plan [p]. This is a front end to [rewrite_intro]/[substA].  If
       [term] is given, assumption [l] is replaced with the result of
       rewriting [term] otherwise it is the assumption that is
       rewritten.

       {L
       A{_ l}, asms |- concl
       ---->
       B{_ l}, asms|- concl
       }

       info: [goals = [], aforms=[l], cforms=[], terms = []]
     *)

  val pure_rewriteC: 
      ?info:Logic.info -> ?term:Basic.term
      -> (rule)plan -> Logic.label
	-> tactic
    (** [pure_rewriteC info p l]: Rewrite conclusion [l] with
       plan [p]. This is a front end to [rewrite_intro]/[substC].  If
       [term] is given, conclusion [l] is replaced with the result of
       rewriting [term] otherwise it is the conclusion that is
       rewritten.

       {L
       asms |- A{_ l}, concl
       ---->
       asms|- B{_ l}, concl
       }

       info: [goals = [], aforms=[], cforms=[l], terms = []]
     *)

  val pure_rewrite_tac: 
      ?info:Logic.info -> ?term:Basic.term
      -> (rule)plan -> Logic.label
	-> tactic
(** 
   [pure_rewrite info p l]: Combination of [pure_rewriteC] and
   [pure_rewriteA]. First tries [pure_rewriteC] then tries
   [pure_rewriteA].
 *)
  
  val pure_rewrite_conv: (Logic.thm) plan -> Logic.conv
(** 
   [plan_rewrite_conv plan scp trm]: rewrite term [trm] according to
   [plan] in scope [scp]. This is an interface to
   {!Logic.Conv.plan_rewrite_conv}.

   Returns [|- trm = X] where [X] is the result of rewriting [trm]
*)

  val pure_rewrite_rule: 
      (Logic.thm) plan -> Scope.t -> Logic.thm -> Logic.thm
(** 
   [plan_rewrite_rule plan scp thm]: rewrite theorem [thm] according to
   [plan] in scope [scp]. 

   Returns [|- X] where [X] is the result of rewriting [trm]
*)

(** {7 Rewrite planner} *)

  val dest_term : 
      Basic.term -> Rewrite.order option -> Rewrite.rewrite_rules

  val extract_rule:
      Logic.node option -> Logic.rr_type -> Rewrite.rewrite_rules

  module PlannerData :
      (Rewrite.PlannerData 
       with type rule = Logic.rr_type
       and type data = Logic.node option)

  module Planner : 
      (Rewrite.PlannerType with type a_rule = PlannerData.rule 
      and type rule_data = PlannerData.data)


val mk_plan : 
    ?ctrl:Rewrite.control -> Logic.node
      -> rule list -> Basic.term -> rule plan
(** 
   The rewrite planner, for use with tactics.

   [mk_plan scp ?ctrl ?goal rules term]: Make a plan to rewrite [term]
   using theorems and assumptions in [rules]. If [goal] is given, it
   is the source of the assumptions in [rules].

   N.B. The [rr_dir] field of [ctrl] is ignored.
*)

val mk_thm_plan : 
    Scope.t -> ?ctrl:Rewrite.control 
      -> rule list -> Basic.term -> Logic.thm plan
(** 
   The theorem rewrite planner, for use with conversions and rules. 

   [mk_thm_plan scp ?ctrl ?goal rules term]: Make a plan to rewrite [term]
   using theorems in [rules]. 

   N.B. The [rr_dir] field of [ctrl] is ignored.
*)

(** {7 General rewriting} *)


  val falseA : ?info:Logic.info -> ?a:Logic.label -> tactic
  val trivial : ?info:Logic.info -> ?f:Logic.label -> tactic

  val make_eq_refl_thm : unit -> Logic.thm
  val eq_refl_thm_var : Logic.thm Lib.deferred
  val eq_refl_thm : unit -> Logic.thm

  val make_bool_cases_thm : unit -> Logic.thm
  val bool_cases_thm_var : Logic.thm Lib.deferred
  val bool_cases_thm : unit -> Logic.thm

  val make_eq_sym_thm : unit -> Logic.thm
  val eq_sym_thm_var : Logic.thm Lib.deferred
  val eq_sym_thm : unit -> Logic.thm


  val eq_sym_rule : Scope.t -> Logic.thm -> Logic.thm
(** [eq_sym_rule scp thm]: If the body of [thm] is [ |- x = y], return 
   [ |- y=x ].
*)

  val eq_symA: ?info:Logic.info -> Logic.label -> tactic
(** 
   [eq_symA a]: Rewrite assumption [a] with [eq_sym_thm] once.
*)

  val eq_symC: ?info:Logic.info -> Logic.label -> tactic
(**
   [eq_symA a]: Rewrite conclusion [c] with [eq_sym_thm] once.
*)

  val eq_sym_tac: ?info:Logic.info -> Logic.label -> tactic
(** 
   [eq_sym_tac f]: Try to apply [eq_symA f], if that fails, try [eq_symC f].
*)

(** {7 Rewrite functions} *)

      val rewrite_conv: 
	  ?ctrl:Rewrite.control -> Logic.rr_type list -> Logic.conv
(**
   [rewrite_conv scp ctrl rules trm]:
   rewrite term [trm] with rules [rrl] in scope [scp].

   Returns |- trm = X 
   where [X] is the result of rewriting [trm]

   Discards any rule which is not a theorem or an ordered theorem.

   This conversion could be written using the rewriting tactics but
   this would require two sets of rewriting. The first to construct
   the term [X] on the rhs of the equality and the second when the
   rewrite tactic is invoked. By contrast, [rewrite_conv] only does
   one set of rewriting.
 *)


  val map_sym_tac:
      (rule list) ref -> rule list -> tactic
(**
   [map_sym_tac ret rules goal]: Apply [eq_sym] to each rule in
   [rules], returning the resulting list in [ret]. The list in [ret]
   will be in reverse order of [rules]. 
*)


val rewriteA_tac: 
    ?info:Logic.info
  -> ?ctrl:Rewrite.control
    -> rule list -> Logic.label -> tactic
(** 
   [rewriteA ctrl rules l]: Rewrite the assumption at label [l] with
   [rules], passing [ctrl] to the rewriter.

   {L
   A{_ l}, asms |- concls

   ----> (B is the rewritten assumption)

   B{_ l}, asms |- concls
   }

   info: [goals = [], aforms=[l], cforms=[], terms = []]
 *)

      val rewriteC_tac : 
	  ?info:Logic.info
	-> ?ctrl:Rewrite.control
	  -> rule list -> Logic.label -> tactic
(** 
   [rewriteC ctrl rules l]: Rewrite the conclusion at label [l] with
   [rules], passing [ctrl] to the rewriter.

   {L
   asms |- A{_ l}, concls

   ----> (B is the rewritten conclusion)

   asms |- B{_ l}, concls
   }

   info: [goals = [], aforms=[], cforms=[l], terms = []]
 *)

val rewrite_tac: 
	  ?info:Logic.info
	-> ?ctrl:Rewrite.control
	  -> rule list -> Logic.label -> tactic
(**
   rewrite ?info ctrl rules l sq: Rewrite formula [l] with [rules].
   
   If [l] is in the conclusions then call [rewrite_concl]
   otherwise call [rewrite_asm].
 *)

end


val gen_rewrite_tac: 
    ?info: Logic.info 
  -> ?asm:bool
    -> Rewrite.control
      -> ?f:Logic.label 
	-> Logic.rr_type list 
	  -> Logic.tactic
(** 
   [gen_rewrite_tac info ctrl rules f]: General rewriting tactic.

   Rewrite formula [f] with list of theorems and assumptions given in
   [rules]. 

   If [f] is not given, rewrite all assumptions and conclusions in in
   sequent. If [f] is not given and [asm] is given then if [asm] is
   true, rewrite only the assumptions, if [asm] is false then rewrite
   only the conclusions. If neither [f] nor [asm] is given, the
   rewrite both assumptions and conclusions in the sequent.

   This tactic is the entry-point for {!Logic.Tactics.rewrite}.
*)

val rewrite_tac: 
    ?info:Logic.info 
  -> ?dir:Rewrite.direction
    -> ?f:Logic.label
      -> Logic.thm list 
	-> Logic.tactic
(** 
   [rewrite_tac info dir thms f]: Rewrite formula [f] with list of
   theorems [thms]. If [f] is not given, rewrite all formulas in
   sequent.
*)

val once_rewrite_tac: 
    ?info:Logic.info -> ?dir:Rewrite.direction -> 
    ?f:Logic.label -> Logic.thm list -> Logic.tactic
(** 
   [once_rewrite_tac info dir thms f]: Rewrite formula [f] once.
   If [f] is not given, rewrite all formulas in sequent.
*)

val rewriteC_tac: 
    ?info:Logic.info 
  -> ?dir:Rewrite.direction
    -> ?f:Logic.label
      -> Logic.thm list 
	-> Logic.tactic
(** 
   [rewriteC_tac info dir thms f]: Rewrite formula [f] with list of
   theorems [thms]. If [f] is not given, rewrite all conclusions in
   sequent.
*)

val once_rewriteC_tac: 
    ?info:Logic.info -> ?dir:Rewrite.direction -> 
    ?f:Logic.label -> Logic.thm list -> Logic.tactic
(** 
   [once_rewrite_tac info dir thms f]: Rewrite formula [f] once.
   If [f] is not given, rewrite all conclusions in sequent.
*)

val rewriteA_tac: 
    ?info:Logic.info 
  -> ?dir:Rewrite.direction
    -> ?f:Logic.label
      -> Logic.thm list 
	-> Logic.tactic
(** 
   [rewrite_tac info dir thms f]: Rewrite formula [f] with list of
   theorems [thms]. If [f] is not given, rewrite all assumptions in
   sequent.
*)

val once_rewriteA_tac: 
    ?info:Logic.info -> ?dir:Rewrite.direction -> 
    ?f:Logic.label -> Logic.thm list -> Logic.tactic
(** 
   [once_rewrite_tac info dir thms f]: Rewrite formula [f] once.
   If [f] is not given, rewrite all assumptions in sequent.
*)


val gen_replace_tac: 
    ?info:Logic.info -> ?ctrl:Rewrite.control
  -> ?asms:Logic.label list 
    -> ?f:Logic.label -> Logic.tactic
(**
   [gen_replace_tac info ctrl asms f]: Rewrite formula [f] with the
   assumptions in list [asms].  If [f] is not given, rewrite all
   formulas in sequent. If [asms] is not given, use all assumptions of
   the form [l=r] or [!x1 .. xn: l = r]. Doesn't rewrite the
   assumptions used as rewrite rules.
*)

val replace_tac: 
    ?info:Logic.info -> ?dir:Rewrite.direction
  -> ?asms:Logic.label list 
    -> ?f:Logic.label -> Logic.tactic
(** 
   [replace_tac info dir asms f]: Rewrite formula [f] with assumptions
   in list [asms].  If [f] is not given, rewrite all formulas in
   sequent.  If [asms] is not given, use all assumptions of the form
   [l=r] or [!x1 .. xn: l = r].  Doesn't rewrite the used assumptions.
*)

val once_replace_tac: 
    ?info:Logic.info -> ?dir:Rewrite.direction
  -> ?asms:Logic.label list 
    -> ?f:Logic.label -> Logic.tactic
(** 
   [once_replace_tac info dir asms f]: Rewrite formula [f] with
   assumptions in list [asms] once. If [f] is not given, rewrite all
   formulas in sequent.  If [asms] is not given, use all assumptions
   of the form [l=r] or [!x1 .. xn: l = r].  Doesn't rewrite the used
   assumptions.
*)

