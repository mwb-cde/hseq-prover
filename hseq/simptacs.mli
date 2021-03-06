(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Tactical interface to the simplifier engine. *)

open Simplifier

(** {5 Simplification Data} *)

val default_data: Data.t
(** The default data set. *)

val add_rule_data:
  Data.t -> Simpconvs.rule_data list -> Data.t
(** [add_rule_data data rules]: Update [data] with assumption
    [rules]. [rules] should be as provided by
    {!Simpconvs.prepare_asm}.
*)

(** {7 Adding assumptions and conclusions} *)

val add_asms_tac:
  Data.t -> Logic.ftag_ty list
  -> (Data.t) Tactics.data_tactic
(** [add_asms_tac data tags g]: Prepare the assumptions in [tags] for
    use as simp-rules. Add them to [data].
*)

val add_concls_tac:
  Data.t -> Logic.ftag_ty list
  -> (Data.t) Tactics.data_tactic
(** [add_concls_tac data tags g]: Prepare the conclusions in [tags]
    for use as simp-rules. Add them to [data].
*)

(** {5 Simplification engines} *)

val simp_engine_tac:
  Data.t -> Logic.ftag_ty
  -> (Data.t) Tactics.data_tactic
(** The engine for [simp_tac].

    [simp_engine_tac ret cntrl l goal]:

    {ul
    {- Eliminate toplevel universal quantifiers of [l].}
    {- Simplify [l], using {!Simplifier.basic_simp_tac}}
    {- Solve trivial goals}
    {- Repeat until nothing works}}

    Returns the updated simp data in [ret].
*)

val simpA_engine_tac:
  Data.t -> Logic.label
  -> (Data.t) Tactics.data_tactic
(** [simpA_engine_tac cntrl ret chng l goal]: Simplify assumption [l],
    returning the updated data in [ret]. Sets [chng] to true on
    success. Doesn't clean-up.  *)

val simpC_engine_tac:
  Data.t -> Logic.label
  -> (Data.t) Tactics.data_tactic
(** [simpC_engine_tac cntrl ret chng l goal]: Simplify conclusion [l],
    returning the updated data in [ret]. Sets [chng] to true on
    success. Doesn't clean-up.  *)


(** {5 Simplifying assumptions} *)

val simpA0_tac:
  Data.t -> (Logic.label)option -> (Data.t)Tactics.data_tactic
(** [simpA1_tac cntrl ret a goal]: Simplify assumptions

    If [a] is given, add other assumptions to the simpset and then
    simplify [a]. If [a] is not given, simplify each assumption,
    starting with the last, adding it to the simpset rules it is
    simplified. The conclusions are always added to the simpset.

    Doesn't clean-up.
*)

val simpA_tac:
  Data.t -> (Logic.label)option -> Tactics.tactic
(** [simpA_tac cntrl a goal]: Simplify assumptions

    If [a] is given, add other assumptions to the simpset and then
    simplify [a]. If [a] is not given, simplify each assumption,
    starting with the last, adding it to the simpset rules it is
    simplified. The conclusions are always added to the simpset.

    This is the top-level tactic (for this module) for simplifying
    assumptions.
*)

(** {5 Simplifying conclusions} *)

val simpC0_tac:
  Data.t -> (Logic.label)option -> (Data.t) Tactics.data_tactic
(** [simpC1_tac cntrl ret c goal]: Simplify conclusions.

    If [c] is given, add other conclusions to the simpset and simplify
    [c]. Otherwise, simplify each conclusion, starting with the last,
    adding it to the assumptions after it is simplified. The
    assumptions are always added to the simpset.

    Doesn't clean-up.
*)

val simpC_tac:
  Data.t -> (Logic.label)option -> Tactics.tactic
(** [simpC_tac cntrl c goal]: Simplify conclusions.

    If [c] is given, add other conclusions to the simpset and simplify
    [c]. Otherwise, simplify each conclusion, starting with the last,
    adding it to the assumptions after it is simplified. The
    assumptions are always added to the simpset.

    This is the top-level tactic (for this module) for simplifying
    conclusions.
*)

(** {5 Simplifying subgoals} *)

val full_simp0_tac:
  Data.t -> (Data.t)Tactics.data_tactic
(** [full_simp0_tac cntrl ret goal]: Simplify subgoal

    {ul
    {- Simplify each assumption, starting with the last, adding it to the
    simpset rules after it is simplified.}
    {- Simplify each conclusion, starting with the last, adding it to the
    simpset rules after it is simplified.}}

    Doesn't clean-up.
*)

val full_simp_tac:
  Data.t -> Tactics.tactic
(** [full_simp_tac cntrl ret goal]: Simplify subgoal

    {ul
    {- Simplify each assumption, starting with the last, adding it to the
    simpset rules after it is simplified.}
    {- Simplify each conclusion, starting with the last, adding it to the
    simpset rules after it is simplified.}}

    This is the top-level tactic (for this module) for simplifying
    subgoals.
*)

(** Debugging information **)

val log: string -> Data.t -> unit
