(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** The simplifier libray. *)

(** {5 Simplification sets} *)

val empty_simp: unit -> Simpset.simpset
(** [empty_simp()]: Clear the standard simpset.
*)

val add_simps:
  Context.t -> Simpset.simpset -> Logic.thm list
  -> Simpset.simpset
(** [add_simps thms]: Add [thms] to the standard simpset. *)

val add_simp:
  Context.t -> Simpset.simpset -> Logic.thm
  -> Simpset.simpset
(** [add_simp thm]: Add [thm] to the standard simpset.
*)

val add_conv:
  Simpset.simpset -> Term.term list
  -> (Context.t -> Logic.conv) -> Simpset.simpset
(** [add_conv trms conv]: Add conversion [conv] to the standard
    simpset, with [trms] as the representative keys.  Example:
    [add_conv [<< !x A: (%y: A) x >>] Logic.Conv.beta_conv] applies
    [beta_conv] on all terms matching [(%y: A) x].
*)

val init_std_ss: unit -> Simpset.simpset
(** The initial standard simpset *)

(** {5 User level simplification tactics} *)

val gen_simpA_tac:
  (Simplifier.control)option
  -> ((Logic.label)list)option
  -> (Logic.label)option
  -> Simpset.simpset
  -> Logic.thm list
  -> Tactics.tactic

val simpA_tac:
  Simpset.simpset -> Logic.thm list -> Tactics.tactic
val simpA_at_tac:
  Simpset.simpset -> Logic.thm list -> Logic.label -> Tactics.tactic

(** [gen_simpA_tac cntrl ignore a set rules goal]

    [simpA_tac set rules goal]: Equiavlent to
        [gen_simpA_tac None None None set rules goal]

    [simpA_at set rules a goal]: Equiavlent to
        [gen_simpA_tac None None (Some(a)) set rules goal]

    Simplify assumptions.

    If [a] is not given then all assumptions are to be simplified.

    {ul
    {- Add all conclusions as simp rules.}
    {- Add all assumptions other than the targets as simp
    rules.}
    {- Simplify the assumption and then add it as a simp rule.
    Repeat for all assumptions to be simplified.}}

    Doesn't use formulas identified by a label in [ignore].

    @param a The assumption to simplify. Default: all assumptions.

    @param cntrl The rewrite control to use (used to select top-down or
    bottom up simplifying). Default: top-down.

    @param ignore List of assumptions/conclusions to ignore. Default: [[]].

    @param set The simpset to use.

    @param rules Additional rewrite rules to use.

    @raise No_change If no change is made.
*)

val simpA:
  Simpset.simpset -> Tactics.tactic
val simpA_at:  Simpset.simpset -> Logic.label -> Tactics.tactic

(** [simpA set]: Shorthand for {!Simplib.simpA_tac std_ss []}
    [simpA_at set a ]: Shorthand for {!Simplib.simpA_at set [] a}

    @raise No_change If no change is made.
*)

val gen_simpC_tac:
  (Simplifier.control)option
  -> ((Logic.label)list)option
  -> (Logic.label)option
  -> Simpset.simpset
  -> Logic.thm list
  -> Tactics.tactic

val simpC_tac: Simpset.simpset -> Logic.thm list -> Tactics.tactic
val simpC_at_tac:
  Simpset.simpset -> Logic.thm list -> Logic.label -> Tactics.tactic
(** [gen_simpC_tac ?cntrl ?ignore ?asms ?c set rules goal]

    [simpC_tac set rules goal] is [gen_simpC_tac set rules goal]

    [simpC_at_tac set rules c goal] is [gen_simp_tac c set rules goal]

    Simplify assumptions.

    If [c] is not given then all conclusions are to be simplified.

    {ul
    {- Add all assumptions as simp rules.}
    {- Add all conclusions other than the target conclusions as simp
    rules.}
    {- Simplify the conclusions and then add it as a simp rule.
    Repeat for all assumptions to be simplified.}}

    Doesn't use formulas identified by a label in [ignore].

    @param c The conclusion to simplify. Default: all conclusions

    @param cntrl The rewrite control to use (used to select top-down or
    bottom up simplifying). Default: top-down.

    @param ignore List of assumptions/conclusions to ignore. Default: [[]].

    @param set The simpset to use. Default: [std_ss].

    @param add Add this simpset to the set specified with [set]. This
    allows extra simpsets to be used with the standard simpset.

    [rules] are the additional rewrite rules to use.

    @raise No_change If no change is made.
*)

val simpC: Simpset.simpset ->  Tactics.tactic
val simpC_at: Simpset.simpset -> Logic.label ->  Tactics.tactic
(** [simp c]: Shorthand for {!Simplib.simpC_tac}
    [simp_at c]: Shorthand for {!Simplib.simpC_at_tac}

    @raise No_change If no change is made.
*)

val gen_simp_all_tac:
  (Simplifier.control)option -> ((Logic.label)list)option
  -> Simpset.simpset -> Logic.thm list -> Tactics.tactic
val simp_all_tac:
  Simpset.simpset -> Logic.thm list -> Tactics.tactic
(**
    [gen_simp_all_tac cntrl ignore asms set rules goal]

    [simp_all_tac set rules goal]

    Simplify each formula in the subgoal.

    {ul
    {- Simplify each assumption, starting with the first (most recent),
    adding it to the simpset}
    {- Simplify each conclusion, starting with the last (least recent),
    adding it to the simpset.}}

    Don't use formulas identified by a label in [ignore].

    @param cntrl The rewrite control to use (used to select top-down or
    bottom up simplifying). Default: top-down.

    @param ignore List of assumptions/conclusions to ignore. Default: [[]].

    @param set The simpset to use. Default: [std_ss].

    @param add Add this simpset to the set specified with [set]. This
    allows extra simpsets to be used with the standard simpset.

    @param rules Additional rewrite rules to use.

    @raise No_change If no change is made.
*)

val simp_all: Simpset.simpset -> Tactics.tactic
(** [simp_all]: Shorthand for {!Simplib.simp_all_tac}.

    @raise No_change If no change is made.
*)


val gen_simp_tac:
  (Simplifier.control)option -> ((Logic.label)list)option
  -> (Logic.label)option -> Simpset.simpset -> Logic.thm list
  -> Tactics.tactic
val simp_tac:
  Simpset.simpset -> Logic.thm list -> Tactics.tactic
val simp_at_tac:
  Simpset.simpset -> Logic.thm list -> Logic.label -> Tactics.tactic
(** [simp_tac ?cntrl ?ignore ?asms ?set ?add ?f rules goal]

    Simplifier tactic.

    If [f] is not given, simplify the the conclusions using
    {!Simplib.simpC_tac}.

    If [f] is given and is a conclusion then simplify using
    {!Simplib.simpC_tac} otherwise simplify using {!Simplib.simpA_tac}.

    Doesn't use formulas identified by a label in [ignore].

    @param f The formula to simplify. Default: all conclusions.

    @param cntrl The rewrite control to use (used to select top-down or
    bottom up simplifying). Default: top-down.

    @param ignore List of assumptions/conclusions to ignore. Default: [[]].

    @param asms Whether to use the assumptions and conclusions as
    rewrite rules. Default: [true].

    @param set The simpset to use. Default: [std_ss].

    @param add Add this simpset to the set specified with [set]. This
    allows extra simpsets to be used with the standard simpset.

    @param rules Additional rewrite rules to use.

    @raise No_change If no change is made.
*)

val simp:
  Simpset.simpset ->  Tactics.tactic
val simp_at:
  Simpset.simpset -> Logic.label ->  Tactics.tactic
(** [simp]: Shorthand for {!Simplib.simp_tac}.
    [simp_at]: Shorthand for {!Simplib.simp_at_tac}.

    @raise No_change If no change is made.
*)

(** {5 Initialising functions} *)

val on_load:
  Context.t -> Simpset.simpset -> Theory.contents -> Simpset.simpset
(** Function to call when a theory is loaded. *)


(** {5 Printer} *)

(** {5 Debugging} *)
val has_property: 'a -> 'a list -> bool
val thm_is_simp:
  Context.t -> Simpset.simpset -> ('a * Theory.thm_record) -> Simpset.simpset
val def_is_simp:
  Context.t -> Simpset.simpset -> ('a * Theory.id_record) -> Simpset.simpset
