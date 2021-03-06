(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

let log str x = ()

(** Tactical interface to the simplifier engine. *)

open Tactics
open Simplifier
open Lib.Ops

(***
    Simplification data
***)

(** [default_data]: The default data set. *)
let default_data =
  let d1 = Simplifier.Data.default
  in
  Data.set_tactic d1 Simplifier.cond_prover_tac

(** [add_rule_data data rules]: Update [data] with assumption
    [rules]. [rules] should be as provided by
    {!Simpconvs.prepare_asm}.
*)
let add_rule_data data rules =
  (*** Put rules into a useful form ***)
  let asm_srcs, asm_new_asms, asm_new_rules =
    Simpconvs.unpack_rule_data rules
  in
  (** Add the simp rules to the simpset *)
  let data1 =
    let simp_rules = Simpset.make_asm_rules (fun _ -> false) asm_new_rules
    in
    (** Add new simp rules to the simpset *)
    let set1 =
      Simpset.simpset_add_rules (Data.get_simpset data) simp_rules
    in
    (** Add the new context *)
    let set2 =
      List.fold_left Simpset.add_context set1
        (List.map Formula.term_of asm_new_asms)
    in
    Data.set_simpset data set2
  in
  (** Record the new assumptions *)
  let data2 =
    let asm_entry_tags = List.map drop_formula asm_new_rules
    in
    Data.set_asms data1
      (List.rev_append asm_entry_tags (Data.get_asms data1))
  in
  data2

(*** Adding assumptions and conclusions ***)

let add_asms_tac data atags ctxt goal =
  let tac data1 tg ctxt0 g =
    ((Simpconvs.prepare_asm [] tg)
        >/ (add_rule_data data1 )) ctxt0 g
  in
  fold_data tac data atags ctxt goal

let add_concls_tac data ctags ctxt goal =
  let tac data1 tg ctxt0 g =
    ((Simpconvs.prepare_concl [] tg)
        >/ (add_rule_data data1)) ctxt0 g
  in
  fold_data tac data ctags ctxt goal

(***
    Simplification engines
***)

(** [initial_prep_tac ctrl ret lbl goal]: Prepare formula [lbl] for
    simplification.  This just tries to apply [allC] or [existA].
*)
let initial_prep_tac ctrl lbl ctxt goal =
  let is_asm =
    try ignore(get_tagged_asm lbl goal); true
    with _ -> false
  in
  if is_asm
  then specA_at lbl ctxt goal
  else specC_at lbl ctxt goal

(** [simp_engine_tac cntrl ret l goal]: The engine for [simp_tac].

    - eliminate toplevel universal quantifiers of [l]
    - simplify [l]
    - solve trivial goals
    - repeat until nothing works
*)
let simp_engine_tac data tag ctxt goal =
  let sum_flag fl1 fl2 = fl1 || fl2 in
  let sum_fn fl1 (fl2, r2) = (sum_flag fl1 fl2, r2) in
  let try_rule dt null ctxt1 g1 =
    try (dt >/ (fun x -> (true, x))) ctxt1 g1
    with _ -> ((false, null) >+ skip) ctxt1 g1
  in
  (** main_tac: Repeatedly simplify **)
  let rec main_tac (chng, ncntrl) ctxt1 g1 =
    fold_seq (false, ncntrl)
      [
        (** Prepare the goal for simplification *)
        (fun (chng2, ncntrl2) ->
          try_tac (initial_prep_tac ncntrl2 (ftag tag))
          >/ (fun c -> ((sum_flag chng2 c), ncntrl2)));

        (** Try simplification. **)
        (fun (chng2, ncntrl2) ->
          try_rule (basic_simp_tac ncntrl2 tag) ncntrl2
          >/ (sum_fn chng2));

        (** Go round again if something changed on this iteration.
            Fail if nothing changed on any iteration.
        *)
        (fun (chng2, ncntrl2) ctxt2 g2 ->
          if chng2
          then main_tac (chng2, ncntrl2) ctxt2 g2
          else
            if chng
            then ((chng, ncntrl2) >+ skip) ctxt2 g2
            else raise No_change)
      ] ctxt1 g1
  in
  (** trivia_tac: Clean up trivial goals. **)
  let apply_trivial_tac arg ctxt1 g1 =
    (arg >+ alt [Boollib.trivial_at (ftag tag); skip]) ctxt1 g1
  in
  (fold_seq (false, data)
    [
      main_tac; apply_trivial_tac
    ]
   >/ (fun (_, cntrl1) -> cntrl1)) ctxt goal


(** [simpA_engine_tac cntrl ret chng l goal]: Simplify assumption [l],
    returning the updated data in [ret]. Set [chng] to true on success.

    Doesn't clean-up.
*)
let simpA_engine_tac cntrl l ctxt goal =
  let (atag, _) =
    try get_tagged_asm l goal
    with Not_found -> raise No_change
  in
  let loopdb = Data.get_loopdb cntrl in
  (simp_engine_tac cntrl atag
     >/ (fun cntrl1 -> Data.set_loopdb cntrl1 loopdb)) ctxt goal

(** [simpC_engine_tac cntrl ret chng l goal]: Simplify conclusion [l],
    returning the updated data in [ret]. Set [chng] to true on success.

    Doesn't clean-up.
*)
let simpC_engine_tac cntrl l ctxt goal =
  let (ctag, _) =
    try get_tagged_concl l goal
    with Not_found -> raise No_change
  in
  let loopdb = Data.get_loopdb cntrl in
  (simp_engine_tac cntrl ctag
     >/ (fun cntrl1 -> Data.set_loopdb cntrl1 loopdb)) ctxt goal

(***
    Simplifying assumptions
***)

(** [simpA0_tac ret cntrl goal]: Simplify assumptions

    Simplify each assumptions, starting with the first, adding it to
    the simpset rules after it is simplified.

    Doesn't clean-up.
*)
let simpA0_tac data a ctxt goal =
  let sqnt = sequent goal in
  let excluded_tags = Data.get_exclude data in
  let except_tag x = List.exists (Unique.equal x) excluded_tags in
  let concls =
    List.filter (not <+ except_tag) (List.map drop_formula (concls_of sqnt))
  in
  let (targets, asms) =
    let except_or y x = ((Unique.equal y x) || except_tag x) in
    let asm_tags = List.map drop_formula (asms_of sqnt)
    in
    match a with
      | None -> (List.filter (not <+ except_tag) asm_tags, [])
      | Some(x) ->
        let atag = Logic.label_to_tag x sqnt
        in
        ([atag], List.filter (not <+ (except_or atag)) asm_tags)
  in
  let sum_flag fl1 fl2 = fl1 || fl2 in
  let sum_fn fl1 (fl2, r2) = (sum_flag fl1 fl2, r2) in
  let try_rule dt null ctxt0 g1 =
    try (dt >/ (fun x -> (true, x))) ctxt0 g1
    with _ -> ((false, null) >+ skip) ctxt0 g1
  in
  let target_tac (ctrl: Data.t) tg ctxt1 g1 =
    fold_seq (false, ctrl)
      [
        (** Simplify the target **)
        (fun (fl1, ctrl1) ->
          try_rule (simpA_engine_tac ctrl (ftag tg)) ctrl1
            >/ (sum_fn fl1));
        (** Add the assumption to the simpset *)
        (fun (fl1, ctrl1) ->
          try_rule (add_asms_tac ctrl1 [tg]) ctrl1
          >/ (fun (_, ret2) -> (fl1, ret2)));
      ] ctxt1 g1
  in
  let main_tac ctrl ctxt1 g1 =
    fold_seq (false, ctrl)
      [
        (** Add non-target assumptions to the simpset *)
        (fun (fl1, ctrl1) ->
          try_rule (add_asms_tac ctrl1 asms) ctrl1
         >/ (fun (_, ret2) -> (fl1, ret2)));
        (** Add conclusions to the simpset *)
        (fun (fl1, ctrl1) ->
          try_rule (add_concls_tac ctrl1 concls) ctrl1
         >/ (fun (_, ret2) -> (fl1, ret2)));
        (** Simplify the targets *)
        (fun (fl1, ctrl1) ->
          fold_data
            (fun (fl2, ctrl2) l -> target_tac ctrl2 l
              >/ (sum_fn fl2))
            (fl1, ctrl1) targets)
      ] ctxt1 g1
  in
  try
    let ((ok, ret1), ngoal) = main_tac data ctxt goal in
    if ok
    then (ret1, ngoal)
    else raise No_change
  with _ -> raise No_change

(** [simpA_tac ret cntrl a goal]: Simplify conclusion.

    If [l] is given, just simplify conclusion [l]. Otherwise, simplify
    each conclusion, starting with the last, adding it to the
    assumptions after it is simplified.

    Doesn't clean-up.
*)
let simpA_tac cntrl a ctxt goal =
  try apply_tac (simpA0_tac cntrl a) clean_up_tac ctxt goal
  with _ -> raise No_change

(***
    Simplifying conclusions
***)

(** [simpC0_tac ret cntrl goal]: Simplify conclusions.

    Simplify each conclusion, starting with the last, adding it to the
    assumptions after it is simplified.

    Doesn't clean-up.
*)
let simpC0_tac data c ctxt goal =
  let sqnt = sequent goal in
  let excluded_tags = Data.get_exclude data in
  let except_tag x = List.exists (Unique.equal x) excluded_tags in
  let asms =
    List.filter (not <+ except_tag) (List.map drop_formula (asms_of sqnt))
  in
  let (targets, concls) =
    let except_or y x = ((Unique.equal y x) || except_tag x) in
    let concl_tags = List.map drop_formula (concls_of sqnt)
    in
    match c with
      | None -> (List.filter (not <+ except_tag) concl_tags, [])
      | Some(x) ->
        let ctag = Logic.label_to_tag x sqnt
        in
        ([ctag], List.filter (not <+ (except_or ctag)) concl_tags)
  in
  let sum_flag fl1 fl2 = fl1 || fl2 in
  let sum_fn fl1 (fl2, r2) = (sum_flag fl1 fl2, r2) in
  let try_rule dt null ctxt0 g1 =
    try (dt >/ (fun x -> (true, x))) ctxt0 g1
    with _ -> ((false, null) >+ skip) ctxt0 g1
  in
  let target_tac ret ct ctxt0 g =
    fold_seq (false, ret)
      [
        (** Simplify the target *)
        (fun (fl1, ret1) ->
          try_rule (simpC_engine_tac ret1 (ftag ct)) ret1
          >/ (sum_fn fl1));
        (** Add it to the assumptions *)
        (fun (fl1, ret1) ->
          try_rule (add_concls_tac ret1 [ct]) ret1
            >/ (fun (_, ret2) -> (fl1, ret2)))
      ] ctxt0 g
  in
  let main_tac ret ctxt0 g =
    fold_seq (false, ret)
      [
        (** Add assumptions to the simpset *)
        (fun (fl1, ret1) ->
          try_rule (add_asms_tac ret1 asms) ret1
         >/ (fun (_, ret2) -> (fl1, ret2)));

        (** Add non-target conclusions to the simpset *)
        (fun (fl1, ret1) ->
          try_rule (add_concls_tac ret1 concls) ret1
         >/ (fun (_, ret2) -> (fl1, ret2)));

        (** Simplify the targets (in reverse order) *)
        (fun (fl1, ret1) ->
          fold_data
            (fun (fl2, ret2) l ->
              (target_tac ret2 l) >/ (sum_fn fl2))
            (fl1, ret1) targets)
      ] ctxt0 g
  in
  try
    let ((ok, data1), ngoal) = main_tac data ctxt goal in
    if ok
    then (data1, ngoal)
    else raise No_change
  with _ -> raise No_change

(** [simpC_tac ret cntrl l goal]: Simplify conclusion.

    If [l] is given, just simplify conclusion [l]. Otherwise, simplify
    each conclusion, starting with the last, adding it to the
    assumptions after it is simplified.
*)
let simpC_tac cntrl c ctxt goal =
  try apply_tac (simpC0_tac cntrl c) clean_up_tac ctxt goal
  with _ -> raise No_change

(***
    Simplifying subgoals
***)

(** [full_simp0_tac ret cntrl goal]: Simplify subgoal

    {ul
    {- Simplify each assumption, starting with the last, adding it to the
    simpset rules after it is simplified.}
    {- Simplify each conclusion, starting with the last, adding it to the
    simpset rules after it is simplified.}}

    Doesn't clean-up.
*)
let full_simp0_tac data ctxt goal =
  let excluded = Data.get_exclude data in
  let except x = List.exists (Unique.equal x) excluded
  and sqnt = sequent goal
  in
  let asms =
    List.filter (not <+ except) (List.map drop_formula (asms_of sqnt))
  and concls =
    List.filter (not <+ except) (List.map drop_formula (concls_of sqnt))
  in
  let try_rule dt null ctxt1 g1 =
    try (dt >/ (fun x -> (true, x))) ctxt1 g1
    with _ -> ((false, null) >+ skip) ctxt1 g1
  in
  let sum_fn fl1 (fl2, r2) = (fl1 || fl2, r2)
  in
  let asm_tac ret tg ctxt0 g =
    fold_seq (false, ret)
      [
        (** Simplify the assumption **)
        (fun (fl1, ret1) ->
          try_rule (simpA_engine_tac ret1 (ftag tg)) ret1
          >/ (sum_fn fl1));
        (** Add the assumption to the simpset *)
        (fun (fl1, ret1) ->
          try_rule (add_asms_tac ret1 [tg]) ret1
         >/ (fun (_, ret2) -> (fl1, ret2)));
      ] ctxt0 g
  in
  let concl_tac ret tg ctxt0 g =
    fold_seq (false, ret)
      [
        (** Simplify the conclusion **)
        (fun (fl1, ret1) ->
          try_rule (simpC_engine_tac ret1 (ftag tg)) ret1
          >/ (sum_fn fl1));
        (** Add the conclusion to the simpset *)
        (fun (fl1, ret1) ->
          try_rule (add_concls_tac ret1 [tg]) ret1
          >/ (fun (_, ret2) -> (fl1, ret2)));
      ] ctxt0 g
  in
  let main_tac ret ctxt0 g =
    fold_seq (false, ret)
      [
        (** Simplify the assumptions *)
        (fun (fl1, ret1) ->
          fold_data
            (fun (fl2, ret2) tg ->
              ((asm_tac ret2 tg) >/ (sum_fn fl2)))
            (fl1, ret1)
            asms);
        (** Simplify the conclusions (in reverse order) *)
        (fun (fl1, ret1) ->
          fold_data
            (fun (fl2, ret2) tg ->
              ((concl_tac ret2 tg) >/ (sum_fn fl2)))
            (fl1, ret1)
            (List.rev concls) )
      ] ctxt0 g
  in
  let ((ok, ret1), ngoal) = main_tac data ctxt goal
  in
  if ok then (ret1, ngoal)
  else raise No_change

(** [full_simp_tac ret cntrl goal]: Simplify subgoal

    {ul
    {- Simplify each assumption, starting with the first, adding it to the
    simpset rules after it is simplified.}
    {- Simplify each conclusion, starting with the last, adding it to the
    simpset rules after it is simplified.}}
*)
let full_simp_tac cntrl ctxt goal =
  let clean_tac cntrl1 ctxt0 g =
    let ncntrl =
      if cntrl1 = None
      then raise (Failure "full_simp_tac")
      else Lib.from_some cntrl1
    in
    clean_up_tac ncntrl ctxt0 g
  in
  try
    apply_tac
      (full_simp0_tac cntrl)
      (fun cntrl1 -> clean_tac (Some cntrl1)) ctxt goal
  with _ -> raise No_change
