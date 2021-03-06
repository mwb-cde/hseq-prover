(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Lib.Ops
open Logic
open Rewrite

type tactic = Context.t -> Logic.tactic
(** A tactic is a function of type [Logic.node -> Logic.branch] *)
type ('a)data_tactic = Context.t -> Logic.node -> ('a * Logic.branch)
(** A data tactic is a tactic that returns additional data. *)

type conv = Context.t -> Logic.conv
(** A conversion is a function of type [term -> thm] *)

let make_tac f (ctxt: Context.t) (g: Logic.node) =
  ((f ctxt g): Logic.branch)

let set_scope = Context.set_scope
let scope_of = Context.scope_of
let context_tac f tac ctxt g =
  tac (f ctxt) g

(*** Error reporting ***)

let error s = Report.error s
let add_error s err = Report.add_error (error s) err

(*** Accessing elements of a list ***)

let msg_get_one msg l =
  Lib.get_one l (Failure msg)

let msg_get_two msg l =
  Lib.get_two l (Failure msg)

(*** Formulas ***)

let drop_tag = Logic.drop_tag
let drop_formula = Logic.form_tag

(*** Labels ***)

let fnum n = Logic.FNum n
let ftag t = Logic.FTag t
let fname s = Logic.FName s

let (!!) = fnum
let (!~) x = fnum (-x)
let (!$) = fname

(*** Sequents ***)

let asms_of = Logic.Sequent.asms
let concls_of = Logic.Sequent.concls
let sqnt_tag  = Logic.Sequent.sqnt_tag

(*** Nodes ***)

let sequent g = Logic.Subgoals.node_sqnt g
let scope_of_goal g = Logic.Sequent.scope_of (sequent g)
let typenv_of n = Logic.Subgoals.node_tyenv n
let node_tag n = Logic.Sequent.sqnt_tag (sequent n)
let changes n = Logic.Tactics.changes n

let goal_context ctxt g = set_scope ctxt (scope_of_goal g)

let get_tagged_asm i g = Logic.get_label_asm i (sequent g)
let get_tagged_concl i g= Logic.get_label_cncl i (sequent g)

let get_asm i g = Logic.drop_tag (get_tagged_asm i g)
let get_concl i g = Logic.drop_tag (get_tagged_concl i g)
let get_form i g =
  try get_concl i g
  with Not_found -> get_asm i g

(*
let context_of ctxt g = Context.set_scope ctxt (scope_of g)
*)

(*** Branches ***)

let branch_tyenv b = Logic.Subgoals.branch_tyenv b
let branch_subgoals b = Logic.Subgoals.branch_sqnts b
let has_subgoals b =
  match branch_subgoals b with
    | [] -> false
    | _ -> true
let num_subgoals b = List.length (branch_subgoals b)

(*** Information records ***)

module Info =
struct
  type t = Changes.t
  let empty = Changes.empty
  let changes = Logic.Tactics.changes
  let branch_changes = Logic.Tactics.branch_changes
  let set_changes chngs g = Logic.Tactics.set_changes g chngs

  let subgoals = Changes.goals
  let aformulas = Changes.aforms
  let cformulas = Changes.cforms
  let constants = Changes.terms

end

(** skip: Do-nothing tactic. Unlike Logic.Tactics.skip, preserves the
    change record of the node. *)
let skip ctxt g =
  Logic.Tactics.skip g

let record_changes_tac setter (tac: tactic) ctxt g =
  let g1 = tac ctxt g in
  let chngs = setter (Info.branch_changes g1)
  in
  Info.set_changes chngs g1

let set_changes_tac chng (ctxt: Context.t) g =
  let setter _ = chng
  in
  record_changes_tac setter skip ctxt g

let add_changes_tac chng ctxt g =
  let setter new_chng =
    Changes.combine chng new_chng
  in
  record_changes_tac setter skip ctxt g

let append_changes_tac chng ctxt g =
  let setter new_chng =
    Changes.combine new_chng chng
  in
  record_changes_tac setter skip ctxt g

(*** Utility functions ***)

let extract_consts vars env=
  let rec extract_aux qs cnsts =
    match qs with
      | [] -> cnsts
      | x::xs ->
        try
          let nv = Term.Subst.find (Term.mk_bound x) env
          in
          extract_aux xs (nv::cnsts)
        with Not_found -> extract_aux xs cnsts
  in
  List.rev (extract_aux vars [])

let qnt_opt_of kind pred trm =
  let (_, body) = Term.strip_qnt kind trm
  in pred body

let first_asm p sq =
  Lib.first p (asms_of sq)

let first_concl p sq =
  Lib.first p (concls_of sq)

let first_form p sq =
  try first_asm p sq
  with Not_found -> first_concl p sq

let first_asm_label pred sq =
  let asm_pred f = pred (drop_tag f) in
  let tag = drop_formula (first_asm asm_pred (sequent sq))
  in
  ftag tag

let first_concl_label pred sq =
  let concl_pred f = pred (drop_tag f) in
  let tag = drop_formula (first_concl concl_pred (sequent sq))
  in
  ftag tag

let node_changes = Logic.Subgoals.node_changes
let branch_changes = Logic.Subgoals.branch_changes

(*
 * Basic tacticals and tactics
 *)

let foreach tac ctxt br =
  if has_subgoals br
  then Logic.Subgoals.apply_to_each (tac ctxt) br
  else raise (error "No subgoals")

let pass (ctxt: Context.t) g =
  set_changes_tac (Changes.empty()) ctxt g

let fail err (_: Context.t) sq = raise err
(*
let fail (_: Context.t) sq = raise (error "failed")
*)

(*
 * Tacticals
 *)

let seq rls ctxt (sq: Logic.node) =
  let rec seq_aux fs sqs =
    match fs with
      | [] -> sqs
      | r::rs ->
        if has_subgoals sqs
        then seq_aux rs (foreach r ctxt sqs)
        else sqs
  in
  match rls with
  | [] -> raise (error "seq: empty tactic list")
  | tac::xs -> seq_aux xs (tac ctxt sq)

let (++) tac1 tac2 ctxt g = seq [tac1; tac2] ctxt g

let alt tacl ctxt (g: Logic.node) =
  let rec alt_aux ts =
    match ts with
      | [] -> raise (error "alt: No tactic succeeded")
      | x::xs ->
        try x ctxt g
        with _ -> alt_aux xs
  in alt_aux tacl

let (//) tac1 tac2 ctxt g =
  try tac1 ctxt g
  with  _ -> tac2 ctxt g

let thenl tac rls ctxt sq =
  let apply_tac r g = r ctxt g in
  Logic.Subgoals.apply_zip (List.map apply_tac rls) (tac ctxt sq)
let (--) = thenl

let fold_seq data rls (ctxt: Context.t) (sq: Logic.node) =
  let rec fold_aux fs d sqs =
    match fs with
      | [] -> (d, sqs)
      | tac::rest ->
        if has_subgoals sqs
        then
          let (d1, sqs1) =
            Logic.Subgoals.apply_fold (fun x -> tac x ctxt) d sqs
          in
          fold_aux rest d1 sqs1
        else
          (d, sqs)
  in
  fold_aux rls data (Logic.Tactics.skip sq)

let fold_data tac a0 blist ctxt goal =
  let apply_tac a b sqs =
    Logic.Subgoals.apply_fold (fun c -> tac c b ctxt) a sqs
  in
  let rec fold_aux a blist sqs =
    match blist with
      | [] -> (a, sqs)
      | (b::rest) ->
        if has_subgoals sqs
        then
          let (a1, sqs1) = apply_tac a b sqs
          in
          fold_aux a1 rest sqs1
        else (a, sqs)
  in
  fold_aux a0 blist (pass ctxt goal)

let rec alt_data data tacl ctxt g =
  match tacl with
    | [] -> raise (Failure "alt_data: no successful tactic")
    | tac::rest ->
       begin
         try (tac data) ctxt g
         with _ -> alt_data data rest ctxt g
       end

let result_tac tac tv fv ctxt g =
  try (tv, tac ctxt g)
  with _ -> (fv, skip ctxt g)

let rec repeat tac ctxt g =
  (tac ++ ((repeat tac) // skip)) ctxt g

let cond pred ttac ftac ctxt g =
  if pred g
  then ttac ctxt g
  else ftac ctxt g

let (-->) pred tac = cond pred tac skip

let restrict p tac ctxt goal =
  let ng = tac ctxt goal
  in
  if p ng
  then ng
  else raise (Failure "restrict_tac")

let data_tac f tac ctxt g = (f  g, tac ctxt g)
let (>>) f tacl ctxt g = tacl (f g) ctxt g
let query_tac tacl ctxt g = tacl (Info.changes g) ctxt g
let (?>) tacl ctxt g = tacl (Info.changes g) ctxt g

let inject_tac d tac ctxt g = (d, tac ctxt g)
let (>+) = inject_tac
let (+<) tac d = inject_tac d tac

let permute_tac perm tac ctxt g =
  let (d, g1) = tac ctxt g
  in
  (perm d, g1)

let (>/) tac perm ctxt g = permute_tac perm tac ctxt g

let try_tac tac ctxt g =
  try (true, tac ctxt g)
  with _ -> (false, skip ctxt g)

let apply_tac data_tac tac ctxt g =
  let (data, br1) = data_tac ctxt g
  in
  if has_subgoals br1
  then foreach (tac data) ctxt br1
  else br1

let rec map_every tac l ctxt goal =
  let rec every_aux ls ctxt0 g =
    match ls with
      | [] -> skip ctxt0 g
      | x::xs -> (tac x ++ every_aux xs) ctxt0 g
  in
  every_aux l ctxt goal

let map_first tac l ctxt goal =
  let rec every_aux ls ctxt0 g =
    match ls with
      | [] -> fail (error "map_first: no tactic succeeded.") ctxt0 g
      | x::xs ->
        (try tac x ctxt0 g
         with _ -> every_aux xs ctxt0 g)
  in
  every_aux l ctxt goal

let map_some tac lst ctxt goal =
  let nofail_tac l ctxt0 g = (tac l // skip) ctxt0 g
  in
  let rec some_aux tac ls (ctxt0: Context.t) g =
    match ls with
      | [] -> fail (error "map_some: no tactic succeeded.") ctxt0 g
      | x::[] -> tac x ctxt0 g
      | x::xs ->
        (try (tac x ++ some_aux nofail_tac xs) ctxt0 g
         with _ -> some_aux tac xs ctxt0 g)
  in
  some_aux tac lst ctxt goal

let seq_some tacs ctxt goal =
  let nofail_tac tac ctxt g = (tac // skip) ctxt g
  in
  let rec some_aux ls ctxt g =
    match ls with
    | [] ->
       fail (Report.error "seq_some: no tactic succeeded.") ctxt g
      | x::xs ->
        (try (x ++ map_every nofail_tac xs) ctxt g
         with _ -> some_aux xs ctxt g)
  in
  some_aux tacs ctxt goal

let seq_any tacl ctxt goal =
  let try_tac tac (d: bool) = result_tac (tac: tactic) true d
  in
  let (succ, goal1) =
    fold_seq false (List.map try_tac tacl) ctxt goal
  in
  if succ
  then goal1
  else fail (Report.error "seq_any: no tactic succeeded.") ctxt goal

let foreach_asm tac ctxt goal =
  let label_tac tf = tac (ftag (drop_formula tf))
  in
  try map_some label_tac (asms_of (sequent goal)) ctxt goal
  with err -> raise (add_error "foreach_asm: no change." err)

let foreach_concl tac ctxt goal =
  let label_tac tf = tac (ftag (drop_formula tf))
  in
  try map_some label_tac (concls_of (sequent goal)) ctxt goal
  with err -> raise (add_error "foreach_concl: no change." err)

let foreach_form tac ctxt goal =
  let asms_tac ok ctxt g =
    ((try_tac (foreach_asm tac)) >/ (fun x -> ok || x)) ctxt g
  and concls_tac ok ctxt g =
    ((try_tac (foreach_concl tac)) >/ (fun x -> ok || x)) ctxt g
  in
  apply_tac
    (fold_seq false [ asms_tac; concls_tac ])
    (fun ok g ->
      if ok then skip g else fail (Failure "foreach_form") ctxt) ctxt goal

(*
 * Tactics
 *)

(*** Formula manipulation ***)

let rotateA (_: Context.t) = Logic.Tactics.rotate_asms
let rotateC (_: Context.t) = Logic.Tactics.rotate_cncls

let copyA l (_: Context.t) = Logic.Tactics.copy_asm l
let copyC l (_: Context.t)= Logic.Tactics.copy_cncl l

let liftA l (_: Context.t) = Logic.Tactics.lift_asm l
let liftC l (_: Context.t) =  Logic.Tactics.lift_concl l
let lift l (_: Context.t) = Logic.Tactics.lift l

let deleteA l (_: Context.t) = Logic.Tactics.deleteA l
let deleteC l (_: Context.t) = Logic.Tactics.deleteC l

let delete i ctxt g =
  try  deleteA i ctxt g
  with Not_found -> deleteC i ctxt g

let deleten ns ctxt sq =
  let rec del_aux l b =
    match l with
      | [] -> b
      | x::xs -> del_aux xs (foreach (delete x) ctxt b)
  in
  del_aux ns (skip ctxt sq)

(*** Logic Rules **)

let trueC_at c _ sq = Logic.Tactics.trueC c sq
let trueC _ sq =
  let cf = first_concl_label Formula.is_true sq
  in
  Logic.Tactics.trueC cf sq

let conjC_at c _ sq = Logic.Tactics.conjC c sq
let conjC _ sq =
  let cf = first_concl_label Formula.is_conj sq
  in
  Logic.Tactics.conjC cf sq

let conjA_at a _ sq = Logic.Tactics.conjA a sq
let conjA _ sq =
  let af = first_asm_label Formula.is_conj sq
  in
  Logic.Tactics.conjA af sq

let disjC_at c _ sq = Logic.Tactics.disjC c sq
let disjC _ sq =
  let cf = first_concl_label Formula.is_disj sq
  in
  Logic.Tactics.disjC cf sq

let disjA_at a _ sq = Logic.Tactics.disjA a sq
let disjA _ sq =
  let af = first_asm_label Formula.is_disj sq
  in
  Logic.Tactics.disjA af sq

let negC_at c _ sq = Logic.Tactics.negC c sq
let negC _ sq =
  let cf = first_concl_label Formula.is_neg sq
  in
  Logic.Tactics.negC cf sq

let negA_at a _ sq = Logic.Tactics.negA a sq
let negA _ sq =
  let af = first_asm_label Formula.is_neg sq
  in
  Logic.Tactics.negA af sq

let implC_at c _ sq = Logic.Tactics.implC c sq
let implC _ sq =
  let cf = first_concl_label Formula.is_implies sq
  in
  Logic.Tactics.implC cf sq

let implA_at a _ sq = Logic.Tactics.implA a sq
let implA (_: Context.t) sq =
  let af = first_asm_label Formula.is_implies sq
  in
  Logic.Tactics.implA af sq

let existC_at trm c _ sq = Logic.Tactics.existC trm c sq
let existC trm _ sq =
  let cf = first_concl_label Formula.is_exists sq
  in
  Logic.Tactics.existC trm cf sq

let existA_at a _ sq = Logic.Tactics.existA a sq
let existA _ sq =
  let af = first_asm_label Formula.is_exists sq
  in
  Logic.Tactics.existA af sq

let allC_at c _ sq = Logic.Tactics.allC c sq
let allC _ sq =
  let cf = first_concl_label Formula.is_all sq
  in
  Logic.Tactics.allC cf sq

let allA_at trm a _ sq = Logic.Tactics.allA trm a sq
let allA trm _ sq =
  let af = first_asm_label Formula.is_all sq
  in
  Logic.Tactics.allA trm af sq

let nameC s l _ g =
  Logic.Tactics.nameC s l g

let nameA s l _ g =
  Logic.Tactics.nameA s l g

let substA rs l _ g =
  Logic.Tactics.substA rs l g

let substC rs l _ g =
  Logic.Tactics.substC rs l g

let instA0 l trms ctxt goal =
  let instf trm g =
    (?>
        (fun info ->
          let alabel = msg_get_one "instA" (Info.aformulas info)
          in
          allA_at trm (ftag alabel)) g)
  in
  match trms with
    | fst::rest ->
      ((allA_at fst l) ++ map_every instf rest) ctxt goal
    | _ -> raise (error "instA")

let instA_at trms a ctxt goal = instA0 a trms ctxt goal
let instA trms ctxt goal =
  let af = first_asm_label Formula.is_all goal
  in
  instA0 af trms ctxt goal

let instC0 l trms ctxt goal =
  let instf trm ctxt0 g =
    (?>
        (fun info ->
          let clabel = msg_get_one "instC" (Info.cformulas info)
          in
          existC_at trm (ftag clabel))) ctxt0 g
  in
  match trms with
    | [] -> raise (error "instC")
    | fst::rest ->
      (existC_at fst l ++ map_every instf rest ) ctxt goal


let instC_at trms c ctxt goal = instC0 c trms ctxt goal
let instC trms ctxt goal =
  let cf = first_concl_label Formula.is_exists goal
  in
  instC0 cf trms ctxt goal

let insC_at trms f ctxt goal =
  try instC_at trms f ctxt goal
  with _ -> instC_at trms f ctxt goal

let inst_at trms f ctxt goal =
  try instA_at trms f ctxt goal
  with _ -> instC_at trms f ctxt goal

let inst_tac trms ctxt goal =
  try instA trms ctxt goal
  with _ -> instC trms ctxt goal

let cut trms th ctxt goal =
  let cut0 trms ctxt0 g =
    seq [
      (fun _ -> Logic.Tactics.cut th);
      (?>
          (fun info ->
            let atag = msg_get_one "cut" (Info.aformulas info) in
            instA_at trms (ftag atag)))
    ] ctxt0 g
  in
  if trms = []
  then Logic.Tactics.cut th goal
  else
    begin
      try cut0 trms ctxt goal
      with err -> raise (add_error "cut" err)
    end

let betaA_at a ctxt goal =
  let conv_tac (ft, form) ctxt0 g =
    let scp = scope_of_goal g in
    let thm =
      try Logic.Conv.beta_conv scp (Formula.term_of form)
      with err -> raise (add_error "betaA" err)
    in
    let albl = ftag ft
    in
    seq
      [
        cut [] thm;
        (?> (fun info1 g1 ->
          let tlbl =
            ftag (Lib.get_one (Info.aformulas info1) (error "Tactics.betaA"))
          in
          seq
            [
              substA [tlbl] albl;
              (?> (fun info2 g2 ->
                ((fun _ -> Logic.Tactics.deleteA tlbl)
                 ++ set_changes_tac info2) g2))
            ] g1))
      ] ctxt0 g

  in
  conv_tac (get_tagged_asm a goal) ctxt goal

let betaA ctxt goal =
  map_some (fun x -> betaA_at (ftag (Logic.form_tag x)))
    (asms_of (sequent goal)) ctxt goal

let betaC_at c ctxt goal =
  let conv_tac (ft, form) ctxt1 g =
    let scp = scope_of_goal g in
    let thm =
      try Logic.Conv.beta_conv scp (Formula.term_of form)
      with err -> raise (add_error "betaC" err)
    in
    let clbl = ftag ft
    in
    seq
      [
        cut [] thm;
        (?> (fun info1 g1 ->
          let tlbl =
            ftag (Lib.get_one (Info.aformulas info1) (error "Tactics.betaC"))
          in
          seq
            [
              substC [tlbl] clbl;
              (?> (fun info2 g2 ->
                ((fun _ -> Logic.Tactics.deleteA tlbl)
                 ++ set_changes_tac info2) g2))
            ] g1))
      ] ctxt1 g
  in
  conv_tac (get_tagged_concl c goal) ctxt goal

let betaC ctxt goal =
  map_some (fun x -> betaC_at (ftag (Logic.form_tag x)))
    (concls_of (sequent goal)) ctxt goal

let beta_at f ctxt goal =
  try
    seq_some
      [
        betaC_at f;
        betaA_at f
      ] ctxt goal
  with err -> raise (add_error "beta_at" err)

let beta_tac ctxt goal =
  try
    seq_some [ betaC; betaA ] ctxt goal
  with err -> raise (add_error "beta_tac" err)

let name_tac n lbl ctxt goal =
  let sqnt = sequent goal
  in
  match Lib.try_app (Logic.get_label_asm lbl) sqnt with
    | Some _ -> Logic.Tactics.nameA n lbl goal
    | None -> Logic.Tactics.nameC n lbl goal

(*** Unification tactics ***)

let find_basic asm concl node =
  let sqnt = sequent node in
  let scp = scope_of_goal node
  and node_asms =
    match asm with
      | None -> asms_of sqnt
      | Some(x) -> [get_tagged_asm x node]
  and node_concls =
    match concl with
      | None ->  concls_of sqnt
      | Some(x) -> [get_tagged_concl x node]
  in
  let find_match c =
    Lib.try_find
      (Lib.first (fun x -> Formula.alpha_equals scp (drop_tag x) c))
      node_asms
  in
  let rec find_basic_aux xs =
    match xs with
      | [] -> raise Not_found
      | cform::cs ->
        begin
          match find_match (drop_tag cform) with
            | Some aform ->
              (ftag (drop_formula aform), ftag (drop_formula cform))
            | None -> find_basic_aux cs
        end
  in
  find_basic_aux node_concls

let basic_at a c ctxt goal =
  try Logic.Tactics.basic a c goal
  with err -> raise (add_error "basic: failed" err)

let basic ctxt goal =
  begin
    match Lib.try_find (find_basic None None) goal with
    | None -> raise (error "basic: failed")
    | Some(al, cl) -> basic_at al cl ctxt goal
  end

let unify_engine_tac (atg, aform) (ctg, cform) ctxt goal =
  let sqnt = sequent goal in
  let scope = Logic.Sequent.scope_of sqnt in
  let albl = ftag atg
  and clbl = ftag ctg
  in
  let asm = Formula.term_of aform
  and concl = Formula.term_of cform
  in
  let asm_vars, asm_body = Term.strip_qnt Term.All asm
  and concl_vars, concl_body = Term.strip_qnt Term.Ex concl
  in
  let asm_varp x = Rewrite.is_free_binder asm_vars x
  and concl_varp x = Rewrite.is_free_binder concl_vars x
  in
  let varp x = (asm_varp x) || (concl_varp x) in
  let env1 =
    (* unify asm and concl *)
    try Unify.unify scope varp asm concl
    with _ ->
      (* unify asm and concl_body with concl_vars *)
      try Unify.unify scope concl_varp asm concl_body
      with _ ->
        (* unify asm_body and concl with asm_vars *)
        try Unify.unify scope asm_varp asm_body concl
        with _ ->
          (* unify asm_body and concl_body with all vars *)
          try Unify.unify scope asm_varp asm_body concl_body
          with _ -> raise (error "Can't unify formulas")
  in
  let asm_consts = extract_consts asm_vars env1
  and concl_consts = extract_consts concl_vars env1
  in
  let inst_asms g =
    if asm_consts = []
    then skip g
    else instA_at asm_consts albl g
  and inst_concls g =
    if concl_consts = []
    then skip g
    else instC_at concl_consts clbl g
  in
  seq [
    (* Instantiate assumption. *)
    inst_asms;
    (* Instantiate conclusion *)
    (?> (fun inf1 ->
      (inst_concls ++
         (?> (fun inf2 ->
           let albl1 =
             if asm_consts = [] then albl
             else ftag (msg_get_one "unify_engine_tac" (Info.aformulas inf1))
           and clbl1 =
             if concl_consts = [] then clbl
             else ftag (msg_get_one "unify_engine_tac" (Info.cformulas inf2))
           in
           basic_at albl1 clbl1)))))
  ] ctxt goal

let unify_at a c ctxt goal =
  try
    unify_engine_tac
      (get_tagged_asm a goal) (get_tagged_concl c goal) ctxt goal
  with err -> raise (add_error "unify_at" err)

let unify_tac ctxt goal =
  let sqnt = sequent goal
  in
  let asms = asms_of sqnt
  and concls = concls_of sqnt
  in
  let tac c ctxt0 g = map_first (fun x -> unify_engine_tac x c) asms ctxt0 g
  in
  try
    ((map_first tac concls) ++ set_changes_tac (Changes.empty())) ctxt goal
  with err -> raise (add_error "unify_tac" err)

(*
 * Derived tactics and tacticals
 *)

(** [named_tac tac anames cnames]: apply [tac ~info:inf goal], rename
    each of [aformulas inf] with a name from [anames], rename each of
    [Info.cformulas inf] with a name from [cnames], in order. Set
    [info=inf'] where [inf'] is [inf], with the formula tag produced
    by renaming.  *)

let named_tac tac anames cnames ctxt goal =
  let rec name_list_tac ns ls chng br =
    match (ns, ls) with
      | ([], _) -> (chng, br)
      | (_, []) -> (chng, br)
      | (x::xs, y::ys) ->
        let br1 = foreach (name_tac x y) ctxt br in
        let chng1 = Changes.rev_append (Info.branch_changes br1) chng
        in
        name_list_tac xs ys chng1 br1
  in
  let g1 = tac ctxt goal in
  let chng1 = Info.branch_changes g1 in
  let chng1r = Changes.rev chng1 in
  let albls = List.map ftag (Info.aformulas chng1)
  and clbls = List.map ftag (Info.cformulas chng1)
  in
  let (chng2, g2) = name_list_tac anames albls chng1r g1 in
  let (chng3, g3) = name_list_tac cnames clbls chng2 g2
  in
  (Info.set_changes (Changes.rev chng3) g3)

(*** Pattern matching tacticals ***)

(** [find_match_formulas typenv scp varp t fs]

    Match a list of tagged formulas. Return the tag of the first
    formula in [fs] to unify with term [t] in scope [scp].

    [varp] determines which terms can be bound by unification.
    [typenv] is the goals type environment.

    @raise [Not_found] if no match.
*)
let find_match_formulas typenv scp varp t fs=
  let rec match_aux l =
    match l with
      | [] -> raise Not_found
      | tf::tfs ->
        begin
          try
            let tg, f = tf
            in
            ignore(Unify.unify_typed typenv scp varp t (Formula.term_of f));
            tg
          with _ -> match_aux tfs
        end
  in
  Logic.FTag (match_aux fs)

let find_match_asm typenv t sq=
  let scp = Logic.Sequent.scope_of sq
  and asms = Logic.Sequent.asms sq
  in
  let t1 = Lterm.set_names scp t in
  let vars = Term.get_free_vars t1 in
  let varp x =
    try ignore(List.find (Term.equals x) vars); true
    with Not_found -> false
  in
  find_match_formulas typenv scp varp t1 asms

let find_match_concl typenv t sq=
  let scp = Logic.Sequent.scope_of sq
  and concls = Logic.Sequent.concls sq
  in
  let t1= Lterm.set_names scp t in
  let vars = Term.get_free_vars t1 in
  let varp x =
    try ignore(List.find (Term.equals x) vars); true
    with Not_found -> false
  in
  find_match_formulas typenv scp varp t1 concls

let match_asm trm tac ctxt g =
  try tac (find_match_asm (typenv_of g) trm (sequent g)) ctxt g
  with Not_found -> raise (Term.term_error "No matching assumption" [trm])

let match_concl trm tac ctxt g =
  try tac (find_match_concl (typenv_of g) trm (sequent g)) ctxt g
  with Not_found -> raise (Term.term_error "No matching conclusion" [trm])

let match_formula trm tac ctxt g =
  let sqnt =sequent g
  and tyenv = typenv_of g
  in
  try tac (find_match_asm tyenv trm sqnt) ctxt g
  with Not_found ->
    try tac (find_match_concl tyenv trm sqnt) ctxt g
    with Not_found ->
      raise (Term.term_error "No matching formula in sequent" [trm])

let specA_at a ctxt g =
  let existA_rule_at asm =
    (?> (fun info1 ->
      record_changes_tac
        (fun info2 -> Changes.combine info2 info1)
        (existA_at asm)))
  in
  alt
    [
      seq
        [
          repeat (existA_rule_at a);
          (?> (fun info ->
            (set_changes_tac
               (Changes.make
                  []
                  [msg_get_one "specA_at" (Info.aformulas info)]
                  []
                  (List.rev (Info.constants info))))))
        ];
      fail (error "specA_at")
    ] ctxt g

let specA ctxt g =
  let existA_rule =
    (?> (fun info1 ->
      record_changes_tac
        (fun info2 -> Changes.combine info2 info1)
        existA))
  in
  alt
    [
      seq
        [
          repeat existA_rule;
          (?> (fun info ->
            (set_changes_tac
               (Changes.make
                  []
                  [msg_get_one "specA" (Info.aformulas info)]
                  []
                  (List.rev (Info.constants info))))))
        ];
      fail (error "specA")
    ] ctxt g

let specC_at c ctxt g =
  let allC_rule_at conc =
    (?> (fun info1 ->
      record_changes_tac
        (fun info2 -> Changes.combine info2 info1)
        (allC_at conc)))
  in
  alt
    [
      seq
        [
          repeat (allC_rule_at c);
          (?> (fun info ->
            (set_changes_tac
               (Changes.make
                  []
                  []
                  [msg_get_one "specC_at" (Info.cformulas info)]
                  (List.rev (Info.constants info))))))
        ];
      fail (error "specC")
    ] ctxt g

let specC ctxt g =
  let allC_rule =
    (?> (fun info1 ->
      record_changes_tac
        (fun info2 -> Changes.combine info2 info1)
        allC))
  in
  alt
    [
      seq
        [
          repeat allC_rule;
          (?> (fun info ->
            (set_changes_tac
               (Changes.make
                  []
                  []
                  [msg_get_one "specC" (Info.cformulas info)]
                  (List.rev (Info.constants info))))))
        ];
      fail (error "specC")
    ] ctxt g

let spec_at f ctxt g =
  alt
    [
      specC_at f;
      specA_at f;
      fail (error "specA_at")
    ] ctxt g

let spec_tac ctxt g =
  alt [ specC; specA; fail (error "spec_tac") ] ctxt g

(*
 * Rewriting
 *)

type ('a)plan = ('a)Rewrite.plan
(** Rewrite plans *)

type rule = Logic.rr_type
(** Rewrite rules *)

let leftright = Rewrite.leftright
let rightleft = Rewrite.rightleft

let rewrite_control dir =
  { Rewrite.default with rr_dir = dir }

let is_rewrite_formula t =
  let (_, t1) = Term.strip_qnt Term.All t
  in
  Lterm.is_equality t1


(** [conv_rule scp conv thm] apply conversion [conv] to theorem [thm]
*)
let conv_rule (ctxt: Context.t) conv thm =
  let term = Logic.term_of thm in
  let rule = conv ctxt term in
  let (qs, lhs, rhs) =
    let (qs, body) = Term.strip_qnt Term.All (Logic.term_of rule) in
    let (l, r) = Lterm.dest_equality body
    in
    (qs, l, r)
  in
  let goal_term =
    match qs with
      | [] -> rhs
      | _ -> Lterm.close_term rhs
  in
  let goal = mk_goal (scope_of ctxt) (Formula.make (scope_of ctxt) goal_term)
  in
  let tac  =
    (?> (fun info ctxt1 g ->
      let ctag =
        Lib.get_one (Info.cformulas info) (Failure "conv_rule")
      in
      seq
        [
          cut [] thm;
          (?> (fun info ->
            begin
              let atag =
                Lib.get_one (Info.aformulas info) (Failure "conv_rule")
              in
              seq
                [
                  cut [] rule;
                  (?> (fun info ->
                    let rtag =
                      Lib.get_one (Info.aformulas info)
                        (error "conv_rule: cut rule")
                    in
                    seq
                      [
                        substA [ftag rtag] (ftag atag);
                        basic_at (ftag atag) (ftag ctag)
                      ]))
                ]
            end))
        ] ctxt1 g))
  in
  mk_thm (Logic.apply_to_goal None (tac ctxt) goal)

(** [pure_term_rewriteA p trm l]: Rewrite term [trm] with plan [p], replace
    assumption [l] with the resulting equality. *)
let pure_term_rewriteA plan trm lbl ctxt goal =
  let ltag = Logic.label_to_tag lbl (sequent goal) in
  let tac ctxt1 g =
    seq
      [
        (fun _ -> Logic.Tactics.rewrite_intro plan trm);
        (?> (fun inf1 ->
          let rule_tag = msg_get_one "pure_rewriteA" (Info.aformulas inf1) in
          seq
            [
              substA [ftag (rule_tag)] (ftag ltag);
              (?> (fun inf2 ->
                   let asm_tag =
                     msg_get_one "pure_rewrit_A" (Info.aformulas inf2)
                   in
                   (((deleteA (ftag rule_tag)):tactic) ++
                      set_changes_tac (Changes.make [] [asm_tag] [] []))))
            ]))
      ] ctxt1 g
  in
  try tac ctxt goal
  with
    | Not_found -> raise Not_found
    | err -> raise (add_error "Tactics.Rewriter.pure_rewriteA" err)

let pure_rewriteA plan lbl ctxt goal =
  let trm = Formula.term_of (get_asm lbl goal)
  in
  pure_term_rewriteA plan trm lbl ctxt goal

(** [pure_term_rewriteC p trm l]: Rewrite term [trm] with plan [p], replace
    conclution [l] using the resulting equality. *)
let pure_term_rewriteC plan trm lbl ctxt goal =
  let ltag = Logic.label_to_tag lbl (sequent goal) in
  let tac g =
    seq
      [
        (fun _ -> Logic.Tactics.rewrite_intro plan trm);
        ?> (fun inf1 ->
         let rule_tag = msg_get_one "pure_rewriteC" (Info.aformulas inf1) in
         seq
           [
             substC [ftag (rule_tag)] (ftag ltag);
             ?> (fun inf2 ->
               let cncl_tag = msg_get_one "pure_rewriteC" (Info.cformulas inf2)
               in
               (deleteA (ftag rule_tag) ++
                  set_changes_tac (Changes.make [] [] [cncl_tag] [])))
           ])
      ] g
  in
  try tac ctxt goal
  with
      Not_found -> raise Not_found
    | err -> raise (add_error "Tactics.Rewriter.pure_rewriteC" err)

(** [pure_rewriteC info p l]: Rewrite conclusion [l] with plan [p]. *)
let pure_rewriteC plan lbl ctxt goal =
  let trm = Formula.term_of (get_concl lbl goal)
  in
  pure_term_rewriteC plan trm lbl ctxt goal

(** [pure_rewrite info p l]: Combination of [pure_rewriteC] and
    [pure_rewriteA]. First tries [pure_rewriteC] then tries
    [pure_rewriteA].
*)
let pure_term_rewrite_tac plan term lbl goal =
  try
    begin
      try pure_term_rewriteC plan term lbl goal
      with Not_found -> (pure_term_rewriteA plan term lbl goal)
    end
  with
    | Not_found -> raise Not_found
    | err -> raise (add_error "Tactics.pure_rewrite_tac" err)

let pure_rewrite_tac plan lbl goal =
  try
    begin
      try pure_rewriteC plan lbl goal
      with Not_found -> (pure_rewriteA plan lbl goal)
    end
  with
    | Not_found -> raise Not_found
    | err -> raise (add_error "Tactics.pure_rewrite_tac" err)

(** [pure_rewrite_conv plan scp trm]: rewrite term [trm] according to
    [plan] in scope [scp]. This is an interface to
    {!Logic.Conv.rewrite_conv}.

    Returns [|- trm = X] where [X] is the result of rewriting [trm]
*)
let pure_rewrite_conv plan (ctxt: Context.t) trm
    = Logic.Conv.rewrite_conv plan (scope_of ctxt) trm

(** [pure_rewrite_rule plan scp thm]: rewrite theorem [thm] according
    to [plan] in scope [scp].

    Returns [|- X] where [X] is the result of rewriting [trm]
*)
let pure_rewrite_rule plan (ctxt: Context.t) thm =
  conv_rule ctxt (pure_rewrite_conv plan) thm

(*
 * Rewrite planner
 *)

let dest_term x p=
  let qs, b = Term.strip_qnt Term.All x in
  let lhs, rhs= Lterm.dest_equality b
  in
  (qs, lhs, rhs, p)

(** [extract_rules (scp, node) rl]: Extract the rewrite rule [rl],
    getting assumptions from [node].

    Extracts the assumptions to use as a rule from subgoal
    [sg]. Checks that other rules are in the scope of [sg]. Creates
    unordered or ordered rewrite rules as appropriate.

    Fails if any rule in [rls] is the label of an assumption which
    does not exist in [sg].

    Fails if any rule in [rls] is not in scope.
*)
let extract_rule node src=
  let (form, p) =
    match src with
      | Asm(x) ->
          let sq =
            if node = None
            then raise (error "extract_rule")
            else Subgoals.node_sqnt (Lib.from_some node)
          in
          let asm =
            try drop_tag(Sequent.get_tagged_asm (label_to_tag x sq) sq)
            with Not_found ->
              raise (error "extract_rule: can't find tagged assumption")
          in
          (asm, None)
      | OAsm(x, order) ->
        let sq =
          if node = None
          then raise (error "extract_rule")
          else
          Subgoals.node_sqnt (Lib.from_some node)
        in
        let asm=
          try drop_tag (Sequent.get_tagged_asm (label_to_tag x sq) sq)
          with Not_found ->
            raise (error "extract_rule: can't find tagged assumption")
        in
        (asm, Some(order))
      | RRThm(x) -> (formula_of x, None)
      | ORRThm(x, order) -> (formula_of x, Some(order))
  in
  dest_term (Formula.term_of form) p

(** The main rewrite planner *)

module PlannerData =
struct
  type rule = Logic.rr_type
  type data = Logic.node option
  let dest = extract_rule
end

module Planner = Rewrite.Make(PlannerData)

let mk_plan ctrl goal rules term =
  let scp = scope_of_goal goal in
  let (_, plan) = Planner.make (Some(goal)) scp ctrl rules term
  in
  plan

(** The theorem rewrite planner (for conversions) *)
let dest_rr_thm src =
  match src with
    | RRThm(x) -> x
    | ORRThm(x, _) -> x
    | _ -> failwith "Tactics.Rewriter.dest_rr_thm"

let dest_rr_thm src =
  match src with
    | RRThm(x) -> x
    | ORRThm(x, _) -> x
    | _ -> failwith "Tactics.Rewriter.dest_rr_thm"

let to_thm_plan plan =
  mapping dest_rr_thm plan

let mk_thm_plan ctxt ctrl rules term =
  let (_, plan) = Planner.make None (scope_of ctxt) ctrl rules term
  in
  to_thm_plan plan
