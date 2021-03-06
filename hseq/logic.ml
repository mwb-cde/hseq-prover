(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Lib.Ops
open Formula

(******************************************************************************)
(** {5 Theorems} *)
(******************************************************************************)

type thm =
  | Axiom of Formula.t
  | Theorem of Formula.t

(** Recogniseres *)
let is_axiom t = match t with Axiom( _ ) -> true | _ -> false
let is_thm t = match t with Theorem( _ ) -> true | _ -> false

(** Constructors *)
let mk_axiom t = Axiom t
let mk_theorem t = Theorem t

(** Destructors *)
let formula_of x =
  match x with
  | Axiom f -> f
  | Theorem f -> f

let term_of x = Formula.term_of (formula_of x)

(** Tests *)
let is_fresh scp x = Formula.is_fresh scp (formula_of x)

(*
 * Representation for storage
 *)

type saved_thm =
  | Saxiom of saved_form
  | Stheorem of saved_form

let to_save t =
  match t with
  | Axiom f -> Saxiom (Formula.to_save f)
  | Theorem f -> Stheorem (Formula.to_save f)

let from_save scp t =
  match t with
  | Saxiom f -> Axiom (Formula.from_save scp f)
  | Stheorem f -> Theorem (Formula.from_save scp f)

(******************************************************************************)
(** {5 Pretty printing} *)
(******************************************************************************)

let print_thm pp t =
  Format.printf "@[<3>|- ";
  Printers.print_term pp (term_of t);
  Format.printf "@]"

let string_thm x = string_form (formula_of x)

(******************************************************************************)
(** {5 Error handling} *)
(******************************************************************************)
let logic_error s t = Term.term_error s (List.map Formula.term_of t)
let add_logic_error s t es =
  raise (Report.add_error (logic_error s t) es)

let sqntError s = Report.error s

let addsqntError s es =
  raise (Report.add_error (sqntError s) es)

(******************************************************************************)
(** {5 Subgoals} *)
(******************************************************************************)

(*
 * Types used in subgoals
 *)

type ftag_ty = (string)Unique.t

type label =
  | FNum of int
  | FTag of ftag_ty
  | FName of string

type tagged_form = (ftag_ty * Formula.t)

let form_tag (t, _) = t
let drop_tag (_, f) = f

(******************************************************************************)
(** {5 Sequents} *)
(******************************************************************************)

(*
 * Utility funcitons
 *)

let join_up l r = List.rev_append l r

let split_at_tag t x =
  let test (l, _) = Unique.equal t l
  in
  Lib.full_split_at test x
(** [split_at_tag t x]: Split [x] into [(l, c, r)] so that
    [x=List.rev_append x (c::r)] and [c] is the formula in [x]
    identified by tag [t].
*)

let split_at_name n x =
  let test (l, _) = (String.compare n (Unique.name l)) = 0
  in
  Lib.full_split_at test x
(** [split_at_name n x]: Split [x] into [(l, c, r)] so that
    [x=List.rev_append x (c::r)] and [c] is the formula in [x]
    identified by a tag with name [n].
*)

(** [split_at_label lbl x]: Split [x] into [(l, c, r)] so that
    [x=List.rev_append x (c::r)] and [c] is the formula in [x]
    identified by label [lbl].

    If [lbl=FNum i], then split at index [(abs i)-1].
    (to deal with assumptions and the index offset).
*)
let split_at_label lbl x =
  match lbl with
  | FNum i -> Lib.full_split_at_index ((abs i)-1) x
  | FTag tg -> split_at_tag tg x
  | FName n -> split_at_name n x

(** [split_at_asm lbl x]: Split [x] into [(l, c, r)] so that
    [x=List.rev_append x (c::r)] and [c] is the formula in [x]
    identified by label [lbl].

    @raise Not_found if [lbl=FNum i] and i>=0
*)
let split_at_asm l fs =
  match l with
  | FNum i ->
     if i >= 0
     then raise Not_found
     else split_at_label l fs
  | _ -> split_at_label l fs

(** [split_at_concl lbl x]: Split [x] into [(l, c, r)] so that
    [x=List.rev_append x (c::r)] and [c] is the formula in [x]
    identified by label [lbl].

    @raise Not_found if [lbl=FNum i] and i<0
*)
let split_at_concl l fs =
  match l with
  | FNum i ->
     if i < 0
     then raise Not_found
     else split_at_label l fs
  | _ -> split_at_label l fs

let get_pair x =
  match x with
  | [t1; t2] -> (t1, t2)
  | _ -> raise (logic_error "get_pair" x)

let get_one x =
  match x with
  | [t1] -> t1
  | _ -> raise (logic_error "get_one" x)

(** Sequents and their components *)
module Sequent=
struct
  (**
     Sequents

     A sequent is made up of a unique tag, a scope, information
     about skolem constants (the sqnt_env), a list of tagged
     formulas: the assumptions, a list of tagged formulas: the
     conclusions.
  *)

  (** [mk_sqnt_form x]: make the subgoal |- x  (with x to be proved) *)
  let mk_sqnt_form f = (Unique.create(), f)

  (** A sqnt_env is made up of the shared type variables
      (Gtype.WeakVar) that may be used in the sequent information
      for constructing names of weak types the skolem constants that
      may be used in the sequent the scope of the sequent. *)
  type sqnt_env =
    {
      sklms: (Skolem.skolem_cnst)list;
      sqscp : Scope.t;
      tyvars: Gtype.t list;
      tynames: (string * int) list;
    }

  (** The type of sequents *)
  type t = (ftag_ty * sqnt_env * tagged_form list * tagged_form list)

  let make tg env ps cs = (tg, env, ps, cs)
  let dest (tg, env, ps, cs) = (tg, env, ps, cs)

  (** Components of a sequent *)

  let asms (_, _, asml, _ ) = asml
  let concls (_, _, _, cnl) = cnl
  let sqnt_env (_, e, _, _) = e

  let sqnt_tag (t, _, _, _) = t
  let sqnt_retag _ = Unique.create()

  let sklm_cnsts (_, e, _, _) = e.sklms
  let scope_of (_, e, _, _) = e.sqscp
  let sqnt_tyvars (_, e, _, _) = e.tyvars
  let sqnt_tynames (_, e, _, _) = e.tynames

  let thy_of_sqnt sq = Scope.thy_of (scope_of sq)

  let mk_sqnt_env sks scp tyvs names=
    { sklms=sks; sqscp=scp; tyvars=tyvs; tynames=names }

  let new_sqnt scp x =
    let env = mk_sqnt_env [] scp [] []
    and gtag = Unique.create()
    and cform = mk_sqnt_form x
    in
    (make gtag env [] [cform], cform)

  (* Accessing and manipulating formulas in a sequent *)

  let get_asm i sq =
    let (t, f) =
      try List.nth (asms sq) ((-i) - 1)
      with _ -> raise Not_found
    in (t, rename f)

  let get_cncl i sq =
    let (t, f) =
      try List.nth (concls sq) (i - 1)
      with _ -> raise Not_found
    in (t, rename f)

  let get_tagged_asm t sq =
    let rec get_aux ams =
      match ams with
      | [] -> raise Not_found
      | (xt, xf)::xs ->
         if Unique.equal xt t
         then (xt, rename xf)
         else get_aux xs
    in
    get_aux (asms sq)

  let get_tagged_cncl t sq =
    let rec get_aux ccs =
      match ccs with
      | [] -> raise Not_found
      | (xt, xf)::xs ->
         if Unique.equal xt t
         then (xt, rename xf)
         else get_aux xs
    in
    get_aux (concls sq)

  let get_tagged_form t sq =
    try get_tagged_asm t sq
    with Not_found -> get_tagged_cncl t sq

  let get_named_asm t sq =
    let rec get_aux ams =
      match ams with
      | [] -> raise Not_found
      | (xt, xf)::xs ->
         if (Unique.name xt) = t
         then (xt, rename xf)
         else get_aux xs
    in
    if t = ""
    then raise Not_found
    else get_aux (asms sq)

  let get_named_cncl t sq =
    let rec get_aux ccs =
      match ccs with
      | [] -> raise Not_found
      | (xt, xf)::xs ->
         if (Unique.name xt) = t
         then (xt, rename xf)
         else get_aux xs
    in
    if t = ""
    then raise Not_found
    else get_aux (concls sq)

  let get_named_form t sq =
    if t = ""
    then raise Not_found
    else
      try get_named_asm t sq
      with Not_found -> get_named_cncl t sq

  (** Delete an assumption by label*)
  let delete_asm l sq =
    let tg, env, ams, cls = dest sq in
    let nsqnt_tag = sqnt_retag sq in
    let (lasms, _, rasms) = split_at_asm l ams
    in
    make nsqnt_tag env (List.rev_append lasms rasms) cls

  (** Delete a conclusion by label*)
  let delete_cncl l sq =
    let tg, env, ams, cls = dest sq in
    let nsqnt_tag = sqnt_retag sq in
    let (lcncls, _, rcncls) = split_at_concl l cls
    in
    make nsqnt_tag env ams  (List.rev_append lcncls rcncls)

  let tag_to_index t sq =
    let rec index_aux fs i =
      match fs with
      | [] -> raise Not_found
      | x::xs ->
         if Unique.equal (form_tag x) t
         then i
         else index_aux xs (i + 1)
    in
    try -(index_aux (asms sq) 1)
    with
      Not_found -> index_aux (concls sq) 1

  let index_to_tag i sq =
    let rec index_aux fs i =
      match fs with
      | [] -> raise Not_found
      | x::xs ->
         if i = 1
         then (form_tag x)
         else index_aux xs (i - 1)
    in
    if (i < 0)
    then index_aux (asms sq)  (-i)
    else index_aux (concls sq) i

  let name_to_tag n sq =
    let test x = (String.compare n (Unique.name (fst x)) = 0) in
    let first ls =
      let (_, f, _) = Lib.full_split_at test ls
      in
      (fst f)
    in
    if n = ""
    then raise Not_found
    else
      try first (asms sq)
      with Not_found -> first (concls sq)
end

(*
 * Operations on sequent formulas
 *)

let label_to_tag f sq =
  match f with
  | FNum(x) -> Sequent.index_to_tag x sq
  | FTag(x) -> x
  | FName(x) -> Sequent.name_to_tag x sq

let label_to_index f sq =
  match f with
  | FNum(x) -> x
  | FTag(x) -> Sequent.tag_to_index x sq
  | FName(x) -> Sequent.tag_to_index (Sequent.name_to_tag x sq) sq

let get_label_asm t sq =
  match t with
  | FTag x -> Sequent.get_tagged_asm x sq
  | FNum x -> Sequent.get_asm x sq
  | FName x -> Sequent.get_named_asm x sq

let get_label_cncl t sq =
  match t with
  | FTag x -> Sequent.get_tagged_cncl x sq
  | FNum x -> Sequent.get_cncl x sq
  | FName x -> Sequent.get_named_cncl x sq

let get_label_form t sq=
  try get_label_asm t sq
  with Not_found -> get_label_cncl t sq


(******************************************************************************)
(** {5 Goals and subgoals} *)
(******************************************************************************)

(*
 * Goals
 *)

(**
   A goal is made up of:
   {ul
   {- The sub-goals still to be proved.}
   {- A type environment: the bindings of the shared type
   variables which occur in the goals sequents (all of these are weak
   type variables).}
   {- A formula: the theorem which is to be proved.}}
*)
type goal =
    Goal of (Sequent.t list * Gtype.Subst.t * Formula.t * Changes.t)

let get_goal (Goal(_, _, f, _)) = f
let get_subgoals (Goal(sq, _, _, _)) = sq
let goal_tyenv (Goal(_, e, _, _)) = e
let goal_changes (Goal(_, _, _, c)) = c

let has_subgoals g =
  match (get_subgoals g) with
  | [] -> false
  | _ -> true

let num_of_subgoals g =
  List.length (get_subgoals g)

let mk_goal scp f =
  let goal_frm = Formula.typecheck scp f (Lterm.mk_bool_ty()) in
  let (sqnt, sqnt_frm) = Sequent.new_sqnt scp goal_frm in
  let sqnt_tag = form_tag sqnt_frm in
  let chngs = Changes.make [] [] [sqnt_tag] []
  in
  Goal([sqnt], Gtype.Subst.empty(), goal_frm, chngs)

let mk_thm g =
  match g with
  | Goal([], _, f, _) -> Theorem f
  | _ -> raise (logic_error "Not a theorem" [])

(*** Manipulating goals ****)

let goal_focus t (Goal(sqnts, tyenv, f, chngs)) =
  let rec focus sqs rslt =
    match sqs with
    | [] -> raise Not_found
    | (x::xs) ->
       if Unique.equal t (Sequent.sqnt_tag x)
       then x::((List.rev rslt) @ xs)
       else focus xs (x::rslt)
  in
  Goal(focus sqnts [], tyenv, f, chngs)

let rotate_subgoals_left n goal =
  if has_subgoals goal
  then
    let (Goal(sqnts, tyenv, f, chngs)) = goal
    in
    Goal(Lib.rotate_left n sqnts, tyenv, f, chngs)
  else raise (Failure "rotate_subgoals_left")

let rotate_subgoals_right n goal =
  if has_subgoals goal
  then
    let (Goal(sqnts, tyenv, f, chngs)) = goal
    in
    Goal(Lib.rotate_right n sqnts, tyenv, f, chngs)
  else raise (Failure "rotate_subgoals_right")

let postpone g =
  match g with
  | Goal (sq::[], _, _, _) -> raise (sqntError "postpone: No other subgoals")
  | Goal (sg::sgs, tyenv, f, chngs) ->
     Goal (List.concat [sgs;[sg]], tyenv, f, chngs)
  | _ -> raise (sqntError "postpone: No subgoals")

(** {7 Applying Rules to Subgoals} *)

exception No_subgoals
(** No subgoals. Either a tactic solved all subgoals or a function
    expected subgoals.
*)

exception Solved_subgoal of Gtype.Subst.t
(** [Solved_subgoal tyenv]: solved a subgoal, creating new goal type
    environment tyenv
*)

module Sqnts =
struct
  (** Type of unique identifiers. *)
  type tag_ty = ftag_ty
  (** Make a unique tag. *)
  let tag_create = Unique.create
  (** Compare tags for equality. *)
  let tag_equals = Unique.equal

  (** Type of sequents. *)
  type sqnt_ty = Sequent.t
  (** Tag of sequent. *)
  let sqnt_tag = Sequent.sqnt_tag
  (** Exceptions. *)
  exception No_subgoals = No_subgoals
end

module Subgoals = Subgoalkit.Make(Sqnts)

type node = Subgoals.node
type branch = Subgoals.branch

(** [rule_apply f g]: Apply function [f] to sequent [sg] and type
    environment of node [g] to get [(ng, tyenv)]. [ng] is the list
    of sequents produced by [f] from [sg].  [tyenv] is the new type
    environment for the goal.

    [f] must have type
    [Gtype.substitution -> Sequent.t
    -> (Gtype.substitution * Sequent.t list)]

    Resulting branch has the same tag as [sg].

    THIS FUNCTION MUST REMAIN PRIVATE TO MODULE LOGIC
*)
let rule_apply r nd =
  let ntag = Subgoals.node_tag nd
  and tyenv = Subgoals.node_tyenv nd
  and sqnt = Subgoals.node_sqnt nd
  in
  try
    let (rg, rtyenv, rchngs) = r tyenv sqnt in
    Subgoals.mk_branch ntag (Subgoals.mk_env rtyenv rchngs) rg
  with
  | No_subgoals ->
     Subgoals.mk_branch ntag (Subgoals.mk_env tyenv (Changes.empty())) []
  | Solved_subgoal ntyenv ->
     Subgoals.mk_branch ntag (Subgoals.mk_env ntyenv (Changes.empty())) []

(******************************************************************************)
(** {5 Rule construction} *)
(******************************************************************************)

(** [rule_apply f g]: Apply function [f] to sequent [sg] and type
    environment of node [g] to get [(ng, tyenv)]. [ng] is the list
    of sequents produced by [f] from [sg].  [tyenv] is the new type
    environment for the goal.

    [f] must have type
    [Gtype.substitution -> Sequent.t
    -> (Gtype.substitution * Sequent.t list)]

    Resulting branch has the same tag as [sg].

    THIS FUNCTION MUST REMAIN PRIVATE TO MODULE LOGIC
*)
let rule_apply r nd =
  let ntag = Subgoals.node_tag nd
  and tyenv = Subgoals.node_tyenv nd
  and sqnt = Subgoals.node_sqnt nd
  in
  try
    let (rg, rtyenv, rchngs) = r tyenv sqnt in
    Subgoals.mk_branch ntag (Subgoals.mk_env rtyenv rchngs) rg
  with
  | No_subgoals ->
     Subgoals.mk_branch ntag (Subgoals.mk_env tyenv (Changes.empty())) []
  | Solved_subgoal ntyenv ->
     Subgoals.mk_branch ntag (Subgoals.mk_env ntyenv (Changes.empty())) []

(** [simple_rule_apply f g]: Apply function [f: sqnt -> sqnt list]
    to the first subgoal of g Like sqnt_apply but does not change
    [tyenv] of [g].  Used for rules which do not alter the type
    environment.  *)
let simple_rule_apply r node =
  let wrapper tyenv sq =
    let (sbgl, chngs) = r sq
    in
    (sbgl, tyenv, chngs)
  in
  rule_apply wrapper node

(** [apply_to_goal tac goal]: Apply tactic [tac] to firat subgoal
    of [goal] using [apply_to_first].  Replace original list of
    subgoals with resulting subgoals.

    raise [logic_error "Invalid Tactic"]
    if tag of result doesn't match tag originaly assigned to it.

    raises [No_subgoals] if goal is solved.
*)
let apply_to_goal report tac (Goal(sqnts, tyenv, f, chngs)) =
  let g_tag = Unique.create() in
  let branch = Subgoals.mk_branch g_tag (Subgoals.mk_env tyenv chngs) sqnts
  in
  let new_branch = Subgoals.apply_to_first report tac branch
  in
  if Unique.equal g_tag (Subgoals.branch_tag new_branch)
  then
    let new_tyenv = Subgoals.branch_tyenv new_branch
    and new_sqnts = Subgoals.branch_sqnts new_branch
    and new_chngs = Subgoals.branch_changes new_branch
    in
    Goal(new_sqnts, new_tyenv, f, new_chngs)
  else raise
    (logic_error "Subgoal.apply_to_goal: Invalid tactic" [])

(******************************************************************************)
(** {5 Tactics} *)
(******************************************************************************)

type tactic = node -> branch

let foreach rule branch =
  Subgoals.apply_to_each rule branch

let first_only rule branch =
  Subgoals.apply_to_first None rule branch

(** {7 Support for rewriting} *)

(** Rules for rewrite tactics.

    rr_type: where to get rewrite rule from
    Asm : labelled assumption
    RRThm: given theorem
    OAsm : labelled assumption, with ordering
    ORRThm: given theorem, with ordering
*)

type rr_type =
  | RRThm of thm   (** A theorem *)
  | ORRThm of thm * Rewrite.order (** An ordered theorem *)
  | Asm of label  (** The label of an assumption *)
  | OAsm of label * Rewrite.order (** The label of an ordered assumption *)

(** The type of rewrite plans *)
type plan = rr_type Rewrite.plan

(**
   [check_term_memo memo scp], [check_term scp trm]: Check that term
   [trm] is in the scope [scp].
*)
let check_term_memo memo scp frm =
  Formula.in_scope_memo memo scp frm

let check_term scp frm =
  let (ret, _) = check_term_memo (Lib.StringSet.empty) scp frm in
  ret

(** [extract_rules scp rls l sg]: Filter the rewrite rules [rls].

    Extracts the assumptions to use as a rule from subgoal [sg]. Checks
    that other rules are in the scope of [sg]. Creates unordered or
    ordered rewrite rules as appropriate.

    Fails if any rule in [rls] is the label of an assumption
    which does not exist in [sg].

    Fails if any rule in [rls] is not in scope.
*)
let extract_rules scp plan node=
  let sq = Subgoals.node_sqnt node in
  let extract src =
    match src with
    | Asm(x) ->
       let asm =
         try drop_tag (Sequent.get_tagged_asm (label_to_tag x sq) sq)
         with Not_found ->
           raise (logic_error "Rewrite: can't find tagged assumption" [])
       in
       asm
    | OAsm(x, order) ->
       let asm=
         try drop_tag (Sequent.get_tagged_asm (label_to_tag x sq) sq)
         with Not_found ->
           raise (logic_error "Rewrite: can't find tagged assumption" [])
       in
       asm
    | RRThm(x) ->
       if check_term scp (formula_of x)
       then formula_of x
       else raise (logic_error "Rewrite: Invalid theorem" [])
    | ORRThm(x, order) ->
       if check_term scp (formula_of x)
       then formula_of x
       else raise (logic_error "Rewrite: Invalid theorem" [])
  in
  Rewrite.mapping extract plan

module Tactics =
struct

  (** Rules: The implementation of the rules of the sequent calculus

      Information: Each tactic implementing a basic rule produces
      information about the tags of the formulas affected by applying
      the rule.  e.g. applying conjunction introduction to [a and b],
      produces the tags for the two new formulas [a] and [b] *)

  (*** Utility functions ***)

  let get_sqnt = Subgoals.node_sqnt
  let changes = Subgoals.node_changes
  let branch_changes = Subgoals.branch_changes
  let set_changes = Subgoals.branch_set_changes

  (** [sqnt_apply f g]: apply function f to the first subgoal of
      [g] *)
  let sqnt_apply r g = rule_apply r g

  (** [simple_sqnt_apply f g]: apply function [(f: sqnt -> sqnt list)]
      to the first subgoal of g Like sqnt_apply but does not change
      [tyenv] of [g].  Used for rules which do not alter the type
      environment.  *)
  let simple_sqnt_apply r g =
    let wrapper tyenv sq =
      let (sbgl, chngs) = r sq in
      (sbgl, tyenv, chngs)
    in
    sqnt_apply wrapper g

  let mk_subgoal sq = [sq]
  (** A simple wrapper to make a list of sequents *)

  (*** instantiation terms ***)
  let inst_term scp tyenv t trm =
    let (fm1, tyenv1) = Formula.make_full true scp tyenv trm
    in
    Formula.inst_env scp tyenv1 t fm1

  (*
   * Manipulating Assumptions and Conclusions
   *)

  (***  Lifting assumptions/conclusions ***)

  let split_at_label l fs = split_at_label l fs
  let split_at_asm l fs = split_at_asm l fs
  let split_at_concl l fs = split_at_concl l fs

  let lift_tagged id fs =
    let (lhs, c, rhs) = split_at_label id fs in
    let (t, f) = c
    in
    (t, c::join_up lhs rhs)

  let lift_asm_sq l sq =
    let (t, nasms) = lift_tagged l (Sequent.asms sq) in
    let new_sqnt =
      Sequent.make (Sequent.sqnt_retag sq) (Sequent.sqnt_env sq)
        nasms (Sequent.concls sq)
    in
    let chngs = Changes.make [] [t] [] []
    in
    ([new_sqnt], chngs)

  let lift_asm f g =
    simple_sqnt_apply (lift_asm_sq f) g

  let lift_concl_sq f sq =
    let (t, nconcls) = lift_tagged f (Sequent.concls sq) in
    let new_sqnt =
      Sequent.make (Sequent.sqnt_retag sq)
        (Sequent.sqnt_env sq) (Sequent.asms sq)
        nconcls
    in
    let chngs = Changes.make [] [] [t] []
    in
    ([new_sqnt], chngs)

  let lift_concl f g =
    simple_sqnt_apply (lift_concl_sq f) g

  let lift f g =
    try lift_asm f g
    with Not_found -> lift_concl f g

  (*** Copying assumptions and conclusions ***)

  (** copy_asm i:

      .., t:Ai, ..|- C
      ->
      g:\[ .., t':Ai, t:Ai, .. |- C \]
      info: [g] [t'] [] []
  *)
  let copy_asm0 l sq =
    let (lasms, na, rasms) = split_at_asm l (Sequent.asms sq)
    and nt = Unique.create()
    in
    let nb = (nt, drop_tag na)
    in
    let chngs = Changes.make [] [nt] [] [] in
    let sbgl =  mk_subgoal (Sequent.sqnt_retag sq, Sequent.sqnt_env sq,
                            join_up lasms (nb::na::rasms),
                            Sequent.concls sq)
    in
    (sbgl, chngs)

  let copy_asm i g =
    simple_sqnt_apply (copy_asm0 i) g

  (** copy_cncl i:

      A|- .., t:Ci, ..
      ->
      A|- .., t':Ci, t:Ci, ..
      info: [] [] [] [t']
  *)
  let copy_cncl0 l sq =
    let (lcncls, nc, rcncls) = split_at_concl l (Sequent.concls sq)
    and nt = Unique.create()
    in
    let nb = (nt, drop_tag nc)
    in
    let chngs = Changes.make [] [] [nt] [] in
    let sbgl = mk_subgoal(Sequent.sqnt_retag sq, Sequent.sqnt_env sq,
                          Sequent.asms sq,
                          join_up lcncls (nb::nc::rcncls))
    in
    (sbgl, chngs)

  let copy_cncl i g =
    simple_sqnt_apply (copy_cncl0 i) g

  (*** Rotating assumptions and conclusions ***)

  let rotate_asms0 sq =
    let hs = Sequent.asms sq
    in
    let chngs = Changes.make [] [] [] [] in
    let sbgl =
      match hs with
      |	[] -> mk_subgoal(Sequent.sqnt_retag sq, Sequent.sqnt_env sq,
                         hs, Sequent.concls sq)
      | h::hys -> mk_subgoal(Sequent.sqnt_retag sq,
                             Sequent.sqnt_env sq, hys@[h],
                             Sequent.concls sq)
    in
    (sbgl, chngs)

  let rotate_asms sqnt =
    simple_sqnt_apply rotate_asms0 sqnt

  let rotate_cncls0 sq =
    let cs = Sequent.concls sq
    in
    let chngs = Changes.make [] [] [] [] in
    let sbgl =
      match cs with
      | [] -> mk_subgoal(Sequent.sqnt_retag sq,
                         Sequent.sqnt_env sq, Sequent.asms sq, cs)
      | c::cns -> mk_subgoal(Sequent.sqnt_retag sq,
                             Sequent.sqnt_env sq, Sequent.asms sq, cns@[c])
    in
    (sbgl, chngs)

  let rotate_cncls sqnt =
    simple_sqnt_apply rotate_cncls0 sqnt

  (** [deleteA l sq]: delete assumption [l].  *)
  let deleteA0 x sq =
    let ng = [Sequent.delete_asm x sq] in
    let chngs = Changes.make [] [] [] [] in
    (ng, chngs)

  let deleteA x g =
    simple_sqnt_apply (deleteA0 x) g

  (** [deleteC l sq]: delete conclusion [l].  *)
  let deleteC0 x sq =
    let ng = [Sequent.delete_cncl x sq]  in
    let chngs = Changes.make [] [] [] [] in
    (ng, chngs)

  let deleteC x g =
    simple_sqnt_apply (deleteC0 x) g

  (** [delete l sq]: delete assumption [l] or conclusion [l].  *)
  let delete info x g =
    try deleteA x g
    with Not_found -> deleteC x g

  (*
   * Logic Rules
   *)

  (** [skip]: The do nothing tactic.

      Useful for turning a node into a branch (e.g. for recursive
      functions).
  *)
  let skip node = Subgoals.branch_node node

  (** cut x sq: adds theorem [x] to assumptions of [sq].

      asm |- cncl      --> t:x, asm |- cncl
      ?info: [] [t] [] []
  *)
  let cut0 x sq=
    let scp = Sequent.scope_of sq
    and ftag = Unique.create()
    in
    let nf = formula_of x in
    let nt = Formula.term_of nf in
    let nasm = (ftag, Formula.make_strict scp nt)
    in
    try
      let ng = mk_subgoal(Sequent.sqnt_retag sq,
                          Sequent.sqnt_env sq,
                          nasm::(Sequent.asms sq),
                          Sequent.concls sq)
      in
      let chngs = Changes.make [] [ftag] [] []
      in
      (ng, chngs)
    with x -> add_logic_error "Not in scope of sequent" [nf] x

  let cut x sqnt = simple_sqnt_apply (cut0 x) sqnt

  (** basic i j sq: asm i is alpha-equal to cncl j of sq.

      asm, a_{i}, asm' |- concl, c_{j}, concl'
      -->
      true if a_{i}=c_{j}

      info: [] [] []
  *)
  let basic0 i j tyenv sq =
    let scp = Sequent.scope_of sq
    and (lasms, asm, rasms) = split_at_asm i (Sequent.asms sq)
    and (lconcls, concl, rconcls) = split_at_concl j (Sequent.concls sq)
    in
    let tyenv1 =
      try Formula.alpha_equals_match scp tyenv
            (drop_tag asm) (drop_tag concl)
      with _ ->
        raise (logic_error "Assumption not equal to conclusion"
                 [drop_tag asm; drop_tag concl])
    in
    let tyenv2 =
      try Gtype.extract_bindings (Sequent.sqnt_tyvars sq) tyenv1 tyenv
      with _ ->
        raise (logic_error "basic: Inconsistent types"
                 [drop_tag asm; drop_tag concl])
    in
    raise (Solved_subgoal tyenv2)

  let basic i j g =
    sqnt_apply (basic0 i j) g

  (** conjA i sq:

      t:a/\ b, asm |- concl
      -->
      t:a, t':b, asm |- concl
      info: [] [t; t'] [] []
  *)
  let conjA0 i sq =
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq) in
    let (ft1, t) = asm
    in
    if Formula.is_conj t
    then
      let (t1, t2) = Formula.dest_conj t
      and ft2 = Unique.create()
      in
      let asm1 = (ft1, t1)
      and asm2 = (ft2, t2)
      in
      let chngs = Changes.make [] [ft1; ft2] [] [] in
      let sbgl =
        mk_subgoal (Sequent.sqnt_retag sq, Sequent.sqnt_env sq,
                    asm1::asm2::(join_up lasms rasms),
                    Sequent.concls sq)
      in
      (sbgl, chngs)
    else raise (logic_error "Not a conjunction" [t])

  let conjA i g =
    simple_sqnt_apply (conjA0 i) g

  (** conjC i sq:

      g| asm |- t:(a /\ b), concl
      -->
      g1| asm |- t:a  and g2| asm |- t:b

      where t:a means formula has tag t.
      info: [g1;g2] [t] []
  *)
  let conjC0 i sq=
    let (lcncls, cncl, rcncls) = split_at_concl i (Sequent.concls sq) in
    let (ft1, t) = cncl
    in
    if Formula.is_conj t
    then
      let (t1, t2) = Formula.dest_conj t
      in
      let concll = join_up lcncls ((ft1, t1)::rcncls)
      and conclr = join_up lcncls ((ft1, t2)::rcncls)
      and tagl = Unique.create()
      and tagr = Unique.create()
      and asms = Sequent.asms sq
      in
      let chngs = Changes.make [tagl; tagr] [] [ft1] [] in
      let sbgl =
        [
          Sequent.make tagl (Sequent.sqnt_env sq) asms concll;
          Sequent.make tagr (Sequent.sqnt_env sq) asms conclr
        ]
      in
      (sbgl, chngs)
    else raise (logic_error "Not a conjunct" [t])

  let conjC i g =
    simple_sqnt_apply (conjC0 i) g

  (**
     disjA i sq:
     g| t:a\/b, asm |-  concl
     -->
     g1| t:a, asm |- concl  and g2| t:b, asm |- concl
     info: [g1; g2] [t] []
  *)
  let disjA0 i sq=
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq)
    in
    let (ft, t) = asm
    in
    if (Formula.is_disj t)
    then
      let (t1, t2) = (Formula.dest_disj t)
      in
      let asmsl= join_up lasms ((ft, t1)::rasms)
      and asmsr = join_up lasms ((ft, t2)::rasms)
      and tagl = Unique.create()
      and tagr = Unique.create()
      in
      let chngs = Changes.make [tagl; tagr] [ft] [] [] in
      let sbgl =
        [
          Sequent.make tagl (Sequent.sqnt_env sq) asmsl (Sequent.concls sq);
          Sequent.make tagr (Sequent.sqnt_env sq) asmsr (Sequent.concls sq)
        ]
      in
      (sbgl, chngs)
    else raise (logic_error "Not a disjunction" [t])

  let disjA i g =
    simple_sqnt_apply (disjA0 i) g

  (**
     disjC i sq:
     asm |- t:a\/b, concl
     -->
     asm |- t:a, t':b, concl
     info: [] [] [t;t'] []
  *)
  let disjC0 i sq =
    let (lconcls, concl, rconcls) = split_at_concl i (Sequent.concls sq)
    in
    let (ft1, t) = concl
    in
    if Formula.is_disj t
    then
      let (t1, t2) = (Formula.dest_disj t)
      and ft2 = Unique.create()
      in
      let cncl1 = (ft1, t1)
      and cncl2 = (ft2, t2)
      in
      let chngs = Changes.make [] [] [ft1; ft2] [] in
      let sbgl =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.sqnt_env sq,
           Sequent.asms sq,
           cncl1::cncl2::(join_up lconcls rconcls))
      in
      (sbgl, chngs)
    else raise (logic_error "Not a disjunction" [t])

  let disjC i g =
    simple_sqnt_apply (disjC0 i) g

  (** negA i sq:

      t:~a, asms |- concl
      -->
      asms |- t:a, concl
      info: [] [] [t] []
  *)
  let negA0 i sq =
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq) in
    let (ft, t) = asm
    in
    if Formula.is_neg t
    then
      let t1 = (Formula.dest_neg t)
      in
      let cncl1 = (ft, t1)
      in
      let chngs = Changes.make [] [] [ft] [] in
      let sbgl =
        mk_subgoal (Sequent.sqnt_retag sq,
                    Sequent.sqnt_env sq,
                    join_up lasms rasms,
                    cncl1::(Sequent.concls sq))
      in
      (sbgl, chngs)
    else raise (logic_error "Not a negation"[t])

  let negA i g =
    simple_sqnt_apply (negA0 i) g

  (** negC i sq:

      asms |- t:~c, concl
      -->
      t:c, asms |- concl
      info: [] [t] [] []
  *)
  let negC0 i sq =
    let lconcls, concl, rconcls = split_at_concl i (Sequent.concls sq)
    in
    let (ft, t) = concl
    in
    if Formula.is_neg t
    then
      let t1 = (Formula.dest_neg t) in
      let asm1 = (ft, t1)
      in
      let chngs = Changes.make [] [ft] [] [] in
      let sbgl =  mk_subgoal (Sequent.sqnt_retag sq,
                              Sequent.sqnt_env sq,
                              asm1::(Sequent.asms sq),
                              join_up lconcls rconcls)
      in
      (sbgl, chngs)
    else raise (logic_error "Not a negation"[t])

  let negC i g =
    simple_sqnt_apply (negC0 i) g

  (** implA i sq

      g| t:a => b,asms |-cncl
      -->
      g1| asms |- t:a, cncl
      and
      g2| t:b, asms |- cncl

      info: [g1; g2]  [t] [t] []

      where g| asms |- concl
      means g is the tag for the sequent
  *)
  let implA0 i sq =
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq) in
    let (ft, t) = asm
    in
    if Formula.is_implies t
    then
      let (t1, t2) = (Formula.dest_implies t)
      in
      let asm2 = join_up lasms ((ft, t2)::rasms)
      and asm1 = join_up lasms rasms
      and cncl1 = (ft, t1)::(Sequent.concls sq)
      and tagl = Unique.create()
      and tagr = Unique.create()
      in
      let chngs = Changes.make [tagl; tagr] [ft] [ft] [] in
      let sbgl =
        [
          Sequent.make tagl (Sequent.sqnt_env sq) asm1 cncl1;
          Sequent.make tagr (Sequent.sqnt_env sq) asm2 (Sequent.concls sq)
        ]
      in
      (sbgl, chngs)
    else raise (logic_error "Not an implication" [t])

  let implA i g =
    simple_sqnt_apply (implA0 i) g

  (** implC i sq

      asms |- t:a-> b, cncl
      -->
      t':a, asms |- t:b, cncl
      info: [] [t'] [t] []
  *)
  let implC0 i sq =
    let lconcls, concl, rconcls = split_at_concl i (Sequent.concls sq) in
    let (ft1, t) = concl
    in
    if Formula.is_implies t
    then
      let  (t1, t2) = (Formula.dest_implies t)
      and ft2 = Unique.create()
      in
      let asm =(ft2, t1)
      and cncl = (ft1, t2)
      in
      let chngs = Changes.make [] [ft2] [ft1] [] in
      let sbgl =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.sqnt_env sq,
           asm::(Sequent.asms sq),
           join_up lconcls (cncl::rconcls))
      in
      (sbgl, chngs)
    else raise (logic_error "Not an implication" [t])

  let implC i g =
    simple_sqnt_apply (implC0 i) g

  (** allA i sq

      t:!x. P(c), asm |-  concl
      -->
      t:P(c'), asm |- concl   where c' is a given term

      info: [] [t] [] []
  *)
  let allA0 trm i tyenv sq =
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq) in
    let (ft, t) = asm
    in
    if Formula.is_all t
    then
      try
        let ntrm, tyenv2 = inst_term (Sequent.scope_of sq) tyenv t trm in
        let gtyenv =
          Gtype.extract_bindings (Sequent.sqnt_tyvars sq) tyenv2 tyenv
        in
        let new_subgoal =
          mk_subgoal
            (Sequent.sqnt_retag sq,
             Sequent.sqnt_env sq,
             join_up lasms ((ft, ntrm)::rasms),
             Sequent.concls sq)
        in
        let chngs = Changes.make [] [ft] [] []
        in
        (new_subgoal, gtyenv, chngs)
      with x ->
        raise (Report.add_error
                 (logic_error "allA: " [t]) x)
    else raise (logic_error "Not a universal quantifier" [t])

  let allA trm i g =
    sqnt_apply (allA0 trm i) g

  (** allC i sq

      asm |- t:!x. P(x), concl
      -->
      asm |- t:P(c), concl   where c is a new identifier

      info: [] [] [t] [c]
  *)
  let allC0 i tyenv sq =
    let lconcls, concl, rconcls = split_at_concl i (Sequent.concls sq) in
    let (ft, t) = concl
    in
    if Formula.is_all t
    then
      let (nv, nty) = (Formula.get_binder_name t, Formula.get_binder_type t)
      in
      let localscope = Scope.new_local_scope (Sequent.scope_of sq) in
      let sv, sty, nsklms, styenv, ntynms =
        Skolem.mk_new_skolem
          {
            Skolem.name = Ident.mk_long (Sequent.thy_of_sqnt sq) nv;
            Skolem.ty = nty;
            Skolem.tyenv = tyenv;
            Skolem.scope = localscope;
            Skolem.skolems = Sequent.sklm_cnsts sq;
            Skolem.tylist = Sequent.sqnt_tynames sq
          }
      in
      let nscp = Scope.add_meta localscope (Term.dest_meta sv) in
      let nsqtys=
        if Gtype.is_weak sty
        then sty::(Sequent.sqnt_tyvars sq)
        else Sequent.sqnt_tyvars sq
      in
      let ncncl, ntyenv = inst_term nscp tyenv t sv in
      let gtyenv = Gtype.extract_bindings nsqtys ntyenv tyenv in
      let new_subgoal =
        mk_subgoal (Sequent.sqnt_retag sq,
                    Sequent.mk_sqnt_env nsklms nscp nsqtys ntynms,
                    Sequent.asms sq,
                    join_up lconcls ((ft, ncncl)::rconcls))
      in
      let chngs = Changes.make [] [] [ft] [sv]
      in
      (new_subgoal, gtyenv, chngs)
    else raise (logic_error "Not a universal quantifier" [t])

  let allC i g =
    sqnt_apply (allC0 i) g

  (** existA i sq

      t:?x. P(x), asm |- concl
      -->
      t:P(c), asm |- concl   where c is a new identifier

      info: [] [t] [] [c]
  *)
  let existA0 i tyenv sq =
    let lasms, asm, rasms = split_at_asm i (Sequent.asms sq) in
    let (ft, t) = asm
    in
    if Formula.is_exists t
    then
      let (nv, nty) = (Formula.get_binder_name t, Formula.get_binder_type t)
      in
      let localscope = Scope.new_local_scope (Sequent.scope_of sq) in
      let sv, sty, nsklms, styenv, ntynms =
        Skolem.mk_new_skolem
          {
            Skolem.name = Ident.mk_long (Sequent.thy_of_sqnt sq) nv;
            Skolem.ty = nty;
            Skolem.tyenv = tyenv;
            Skolem.scope = localscope;
            Skolem.skolems = Sequent.sklm_cnsts sq;
            Skolem.tylist = Sequent.sqnt_tynames sq
          }
      in
      let nscp = Scope.add_meta localscope (Term.dest_meta sv) in
      let nsqtys=
        if Gtype.is_weak sty
        then sty::(Sequent.sqnt_tyvars sq)
        else Sequent.sqnt_tyvars sq
      in
      let nasm, ntyenv = inst_term nscp styenv t sv in
      let gtyenv = Gtype.extract_bindings nsqtys ntyenv tyenv in
      let new_subgoal =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.mk_sqnt_env nsklms nscp nsqtys ntynms,
           join_up lasms ((ft, nasm)::rasms),
           Sequent.concls sq)
      in
      let chngs = Changes.make [] [ft] [] [sv]
      in
      (new_subgoal, gtyenv, chngs)
    else raise (logic_error "Not an existential quantifier" [t])

  let existA i g =
    sqnt_apply (existA0 i) g

  (** existC i sq

      asm |- t:?x. P(c), concl
      -->
      asm |- t:P(c), concl where c is a given term

      info: [] [] [t] []
  *)
  let existC0 trm i tyenv sq =
    let lconcls, concl, rconcls = split_at_concl i (Sequent.concls sq)
    in
    let (ft, t) = concl
    in
    if Formula.is_exists t
    then
      try
        let trm2, tyenv2 = inst_term (Sequent.scope_of sq) tyenv t trm in
        let gtyenv=
          Gtype.extract_bindings (Sequent.sqnt_tyvars sq) tyenv2 tyenv
        in
        let new_subgoal =
          mk_subgoal
            (Sequent.sqnt_retag sq,
             Sequent.sqnt_env sq,
             Sequent.asms sq,
             join_up lconcls ((ft, trm2)::rconcls))
        in
        let chngs = Changes.make [] [] [ft] []
        in
        (new_subgoal, gtyenv, chngs)
      with x -> raise (Report.add_error
                         (logic_error "existC:" [t]) x)
    else raise (logic_error "Not an existential quantifier" [t])

  let existC trm i g =
    sqnt_apply (existC0 trm i) g

  (** trueC i sq

      t:asm |- true, concl
      --> true
      info : [] []
  *)
  let trueC0 i tyenv sq =
    let lconcls, concl, rconcls = split_at_concl i (Sequent.concls sq)
    in
    let (_, t) = concl
    in
    if Formula.is_true t
    then raise (Solved_subgoal tyenv)
    else raise (logic_error "Not trivial" [t])

  let trueC i g =
    sqnt_apply (trueC0 i) g

  (** [extract_rules scp rls l sg]: Filter the rewrite rules [rls].

      Extracts the assumptions to use as a rule from subgoal [sg]. Checks
      that other rules are in the scope of [sg]. Creates unordered or
      ordered rewrite rules as appropriate.

      Fails if any rule in [rls] is the label of an assumption
      which does not exist in [sg].

      Fails if any rule in [rls] is not in scope.
  *)
  let extract_rules scp plan sq =
    let get_asm lbl =
      try drop_tag (Sequent.get_tagged_asm (label_to_tag lbl sq) sq)
      with Not_found ->
        raise (logic_error "Rewrite: can't find tagged assumption" [])
    in
    let extract src =
      match src with
      | Asm(x) -> get_asm x
      | OAsm(x, order) -> get_asm x
      | RRThm(x) ->
         if check_term scp (formula_of x)
         then formula_of x
         else
           raise (logic_error "Rewrite: Invalid theorem" [])
      | ORRThm(x, order) ->
         if check_term scp (formula_of x)
         then formula_of x
         else
           raise (logic_error "Rewrite: Invalid theorem" [])
    in
    Rewrite.mapping extract plan

  (** [rewrite_intro plan trm sq]: Introduce an equality
      established by rewriting term [trm] with [plan].

      {L
      asms |- concl
      ---->>
      (trm = T){_ l}, asms|- concl
      }

      info: [] [l] [] []

      Fails if [trm] cannot be made into a formula.
  *)
  let rewrite_intro0 plan trm tyenv sq =
    let scp = Sequent.scope_of sq
    in
    let do_rewrite () =
      let fplan = extract_rules scp plan sq in
      let nasm, ntyenv =
        Formula.mk_rewrite_eq scp tyenv fplan trm
      in
      let asm_tag= Unique.create() in
      let gtyenv =
        Gtype.extract_bindings (Sequent.sqnt_tyvars sq) ntyenv tyenv
      in
      let new_subgoal =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.sqnt_env sq,
           ((asm_tag, nasm)::(Sequent.asms sq)),
           Sequent.concls sq)
      in
      let chngs = Changes.make [] [asm_tag] [] []
      in
      (new_subgoal, gtyenv, chngs)
    in
    try do_rewrite()
    with x -> raise (Report.add_error (logic_error "rewrite_intro" []) x)

  let rewrite_intro plan trm g=
    sqnt_apply (rewrite_intro0 plan trm) g

  (**** Subsitution tactics ****)

  (** [get_eqs_list lbls sq]: Get the equalities in [lbls], break
      them into lhs and rhs.  *)
  let get_eq_list lbls sq =
    let get_eq_list =
      Lib.map_find (fun t -> drop_tag(get_label_asm t sq)) lbls
    in
    let ret_list =
      Lib.map_find
        (fun f -> try Formula.dest_equality f with _ -> raise Not_found)
        get_eq_list
    in
    ret_list

  (** [substA eqs l sq]: Substitute, using the assumptions in
      [eq], into the assumption [l].  The assumptions in [eq] must all
      be equalities of the form [L=R]. The substitution is A{_ l}\[R1,
      R2, ..., Rn/L1, L2, ..., Rn\].

      {L
      A{_ l}, asms |- concl

      ---->

      (A\[R1, R2, ..., Rn/L1, L2, ..., Rn\]){_ l}, asms|- concl
      }

      info: [] [l] [] []
  *)
  let substA0 eqs l tyenv sq =
    let scp = Sequent.scope_of sq
    and (lasms, asm, rasms) = split_at_asm l (Sequent.asms sq)
    in
    let (form_tag, form) = asm
    and eqs_list = get_eq_list eqs sq
    in
    let do_subst() =
      let form1= Formula.subst_equiv scp form eqs_list in
      let (form2, tyenv2) =
        Formula.typecheck_retype scp tyenv form1 (Gtype.mk_null())
      in
      let gtyenv=
        Gtype.extract_bindings (Sequent.sqnt_tyvars sq) tyenv2 tyenv
      in
      let new_asms = join_up lasms ((form_tag, form2)::rasms) in
      let new_subgoal =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.sqnt_env sq,
           new_asms,
           Sequent.concls sq)
      in
      let chngs = Changes.make [] [form_tag] [] []
      in
      (new_subgoal, gtyenv, chngs)
    in
    try do_subst()
    with x -> raise
      (Report.add_error (logic_error "substA" [form]) x)

  let substA eqs l g=
    sqnt_apply (substA0 eqs l) g

  (** [substC eqs l sq]: Substitute, using the assumptions in
      [eq], into the conclusion [l].  The assumptions in [eq] must
      all be equalities of the form [L=R]. The substitution is C{_
      l}\[R1, R2, ..., Rn/L1, L2, ..., Rn\].

      {L
      asms |- C{_ l}, concl

      ---->

      asms|- (C\[R1, R2, ..., Rn/L1, L2, ..., Rn\]){_ l}, concl
      }

      info: [] [] [l] []
  *)
  let substC0 eqs l tyenv sq =
    let scp = Sequent.scope_of sq
    and (lconcls, concl, rconcls) = split_at_concl l (Sequent.concls sq)
    in
    let (form_tag, form) = concl
    and eqs_list = get_eq_list eqs sq
    in
    let do_subst() =
      let form1 = Formula.subst_equiv scp form eqs_list
      in
      let (form2, tyenv2) =
        Formula.typecheck_retype scp tyenv form1 (Gtype.mk_null())
      in
      let gtyenv =
        Gtype.extract_bindings (Sequent.sqnt_tyvars sq) tyenv2 tyenv
      in
      let new_concls = join_up lconcls ((form_tag, form2)::rconcls) in
      let new_subgoal =
        mk_subgoal
          (Sequent.sqnt_retag sq,
           Sequent.sqnt_env sq,
           Sequent.asms sq,
           new_concls)
      in
      let chngs = Changes.make [] [] [form_tag] []
      in
      (new_subgoal, gtyenv, chngs)
    in
    try do_subst()
    with x -> raise (Report.add_error (logic_error "substC" [form]) x)

  let substC eqs l g =
    sqnt_apply (substC0 eqs l) g

  (** [nameA name l sq]: Rename the assumption labelled [l] as
      [name].  The previous name and tag of [l] are both discarded.

      {L
      A{_ l1}, asms |- concl

      ----> l2 a tag created from name

      A{_ l2}, asms|- concl
      }

      info: [goals = [], aforms=[l2], cforms = [], terms = []]
  *)

  (** [check_name n sq]: test whether [n] is the name of a formula
      in [sq]. *)
  let check_name n sq =
    if n = ""
    then raise (Report.error "Invalid formula name.")
    else
      match Lib.try_app (Sequent.get_named_form n) sq with
      | None -> ()
      | _ -> raise (Report.error ("Name "^n^" is used in sequent"))

  let nameA0 name lbl sqnt =
    let name_aux () =
      check_name name sqnt;
      let (lasms, asm, rasms) = split_at_asm lbl (Sequent.asms sqnt) in
      let form_tag, form = asm in
      let new_tag = Unique.named name in
      let new_asms = join_up lasms ((new_tag, form)::rasms) in
      let chngs = Changes.make [] [new_tag] [] [] in
      let new_sbgl =
        mk_subgoal
          (Sequent.sqnt_retag sqnt, Sequent.sqnt_env sqnt,
           new_asms, Sequent.concls sqnt)
      in
      (new_sbgl, chngs)
    in
    try name_aux()
    with err -> raise (add_logic_error "nameA: failed." [] err)

  let nameA name l g=
    simple_sqnt_apply (nameA0 name l) g

  (** [nameC name l sq]: Rename the conclusion labelled [l] as
      [name].  The previous name and tag of [l] are both discarded.

      {L
      asms |- C{_ l1}, concl

      ----> l2 a tag created from name

      asms|- C{_ l2}, concl
      }

      info: [goals = [], aforms=[], cforms = [l2], terms = []]
  *)
  let nameC0 name lbl sqnt =
    let name_aux () =
      check_name name sqnt;
      let (lconcls, concl, rconcls) =
        split_at_concl lbl (Sequent.concls sqnt)
      in
      let form_tag, form = concl in
      let new_tag = Unique.named name in
      let new_concls = join_up lconcls ((new_tag, form)::rconcls)
      in
      let chngs = Changes.make [] [] [new_tag] [] in
      let sbgl =
        mk_subgoal
          (Sequent.sqnt_retag sqnt, Sequent.sqnt_env sqnt,
           Sequent.asms sqnt, new_concls)
      in
      (sbgl, chngs)
    in
    try name_aux()
    with err -> raise (add_logic_error "nameC: failed." [] err)

  let nameC name l g =
    simple_sqnt_apply (nameC0 name l) g
end

type conv = Term.term -> thm

module Conv =
struct

  (** [beta_conv scp term]: Apply a single beta conversion to
      [term].

      Returns |- ((%x: F) y) = F'
      where F' = F\[y/x\]

      Fails if [term] is not of the form [(%x: F)y]
      or the resulting formula is not in scope.
  *)
  let beta_conv scp term =
    let eq_term t =
      fst(Formula.mk_beta_reduce_eq scp (Gtype.Subst.empty()) t)
    in
    try mk_theorem (eq_term term)
    with err ->
      raise (Report.add_error
               (logic_error "beta_conv" [])
               (Report.add_error
                  (Term.term_error "beta_conv term: " [term]) err))

  (** [rewrite_conv scp pl trm]: rewrite term [trm] with plan [pl]
      in scope [scp].

      Returns |- trm = X
      where [X] is the result of rewriting [trm]
  *)
  let rewrite_conv plan scp trm =
    let plan1 = Rewrite.mapping formula_of plan in
    let conv_aux t =
      let (tform, _) =
        Formula.mk_rewrite_eq scp (Gtype.Subst.empty()) plan1 t
      in
      mk_theorem tform
    in
    try conv_aux trm
    with x -> raise
      (Report.add_error (Term.term_error "rewrite_conv" [trm]) x)

end

(******************************************************************************)
(** {5 Definitions and declarations} *)
(******************************************************************************)

(** Defns: Support for defining terms and subtypes. *)
module Defns =
struct

  (*** Error reporting ***)

  let defn_error s t = Term.term_error s (List.map Formula.term_of t)
  let add_defn_error s t es =
    raise (Report.add_error (defn_error s t) es)

  (*** Data Representation ***)

  (** Checked and subtype definitions. Elements of [cdefn] and
      [ctypedef] have been correctly defined.  *)
  type cdefn =
    | TypeAlias of Ident.t * string list * Gtype.t option
    | TypeDef of ctypedef
    | TermDecln of Ident.t * Gtype.t
    | TermDef of Ident.t * Gtype.t	* thm
  and ctypedef =
    {
      type_name: Ident.t;       (* name of new type *)
      type_args: string list;   (* arguments of new type *)
      type_base: Gtype.t;      (* the base type *)
      type_rep: cdefn;          (* representation function *)
      type_abs: cdefn;          (* abstraction function *)
      type_set: Formula.t;      (* defining set *)
      rep_type: thm;
      rep_type_inverse: thm;
      abs_type_inverse: thm
    }

  (*** Representations for permanent storage ***)

  type saved_cdefn =
    | STypeAlias of Ident.t * string list * Gtype.stype option
    | STypeDef of saved_ctypedef
    | STermDecln of Ident.t * Gtype.stype
    | STermDef of Ident.t * Gtype.stype * saved_thm
  and saved_ctypedef =
    {
      stype_name: Ident.t;             (* name of new type *)
      stype_args: string list;         (* arguments of new type *)
      stype_base: Gtype.stype;
      stype_rep: saved_cdefn;          (* representation function *)
      stype_abs: saved_cdefn;          (* abstraction function *)
      stype_set: Formula.saved_form;   (* defining set *)
      srep_type: saved_thm;
      srep_type_inverse: saved_thm;
      sabs_type_inverse: saved_thm
    }

  (*** Conversions to and from the permanent storage representation
  ***)

  let rec to_saved_cdefn td =
    match td with
    | TypeAlias (id, sl, ty) ->
       (match ty with
       | None -> STypeAlias (id, sl, None)
       | Some t -> STypeAlias (id, sl, Some(Gtype.to_save t)))
    | TermDecln (id, ty) ->
       STermDecln (id, Gtype.to_save ty)
    | TermDef (id, ty, thm) ->
       STermDef (id, Gtype.to_save ty, to_save thm)
    | TypeDef ctdef ->
       STypeDef (to_saved_ctypedef ctdef)
  and
      to_saved_ctypedef x =
    {
      stype_name = x.type_name;
      stype_args = x.type_args;
      stype_base = Gtype.to_save x.type_base;
      stype_rep = to_saved_cdefn x.type_rep;
      stype_abs = to_saved_cdefn x.type_abs;
      stype_set = Formula.to_save x.type_set;
      srep_type = to_save x.rep_type;
      srep_type_inverse = to_save x.rep_type_inverse;
      sabs_type_inverse = to_save x.abs_type_inverse
    }

  let rec from_saved_cdefn scp td =
    match td with
    | STypeAlias (id, sl, ty) ->
       (match ty with
       | None -> TypeAlias (id, sl, None)
       | Some t -> TypeAlias (id, sl, Some(Gtype.from_save t)))
    | STermDecln (id, ty) ->
       TermDecln (id, Gtype.from_save ty)
    | STermDef (id, ty, thm) ->
       TermDef (id, Gtype.from_save ty, from_save scp thm)
    | STypeDef ctdef ->
       TypeDef (from_saved_ctypedef scp ctdef)
  and
      from_saved_ctypedef scp x =
    {
      type_name = x.stype_name;
      type_args = x.stype_args;
      type_base = Gtype.from_save x.stype_base;
      type_rep = from_saved_cdefn scp x.stype_rep;
      type_abs = from_saved_cdefn scp x.stype_abs;
      type_set = Formula.from_save scp x.stype_set;
      rep_type = from_save scp x.srep_type;
      rep_type_inverse = from_save scp x.srep_type_inverse;
      abs_type_inverse = from_save scp x.sabs_type_inverse
    }

  (** {5 Term definition and declaration} *)

  (**** Term definition ****)

  let is_termdef x =
    match x with
    | TermDef _ -> true
    | _ -> false

  let dest_termdef x =
    match x with
    | TermDef (id, ty, thm) -> (id, ty, thm)
    | _ -> raise (defn_error "Not a term definition" [])

  (** [mk_termdef scp n ty args d]:

      - check n doesn't exist already
      - check all arguments in args are unique
  *)
  let mk_termdef scp n args d =
    let (id, ty, frm) = Defn.mk_defn scp n args d in
    let thm = mk_axiom frm
    in
    TermDef(id, ty, thm)

  (**** Term declarations ****)

  let is_termdecln x =
    match x with
    | TermDecln _ -> true
    | _ -> false

  let dest_termdecln x =
    match x with
    | TermDecln (id, ty) -> (id, ty)
    | _ -> raise (defn_error "Not a term declaration" [])

  (** [mk_termdecln scp name ty]: Declare identifier [name] of type
      [ty] in scope [scp].  Fails if identifier [name] is already
      defined in [scp] or if [ty] is not well defined.  *)
  let mk_termdecln scp n ty =
    let name = Ident.mk_long (Scope.thy_of scp) n in
    let (id, typ) = Defn.mk_decln scp name ty
    in
    TermDecln(id, typ)

  (** {7 Type definitions} *)

  (**** Type declaration and aliasing ***)

  let is_typealias x =
    match x with
    | TypeAlias _ -> true
    | _ -> false

  let dest_typealias x =
    match x with
    | TypeAlias (id, args, def) -> (id, args, def)
    | _ -> raise (defn_error "Not a term definition" [])

  (** [mk_typealias scp n args d]:

      - check n doesn't exist already
      - check all arguments in args are unique
      if defining n as d
      - check d is well defined
      (all constructors exist and variables are in the list of arguments)
  *)
  let mk_typealias scp n ags d =
    let th = Scope.thy_of scp in
    let _ = Defn.check_args_unique ags in
    let dfn =
      match d with
      | None -> None
      | Some(a) ->
         try Ltype.well_defined scp ags a; Some(a)
         with err ->
           raise (Gtype.add_type_error "Badly formed definition" [a] err)
    in
    TypeAlias((Ident.mk_long th n), ags, dfn)

  (**** Type definition: Subtypes ****)

  let is_subtype x =
    match x with
    |	TypeDef _ -> true
    | _ -> false

  let dest_subtype x =
    match x with
    |	TypeDef ctd -> ctd
    | _ -> raise (defn_error "Not a term definition" [])

  let mk_subtype_thm scp prop =
    mk_axiom (Formula.make scp prop)

  (** [prove_subtype_exists scp setp thm] Use [thm] to prove the
      goal << ?x. setp x >> (built by mk_subtype_exists).

      [thm] should be of the form << ?x. setp x >> otherwise
      the proof will fail.
  *)
  let prove_subtype_exists scp setp thm =
    let goal_form = Formula.make scp (Defn.mk_subtype_exists setp) in
    let gl = mk_goal scp goal_form in
    let chngs = goal_changes gl in
    let concl = FTag(List.hd (Changes.cforms chngs))
    in
    let tac1 g = Tactics.cut thm g in
    let tac2 g =
      let chngs1 = Tactics.changes g in
      let a = FTag (List.hd (Changes.aforms chngs1))
      in
      Tactics.basic a concl g
    in
    let gl1 = apply_to_goal None tac1 gl in
    let gl2 = apply_to_goal None tac2 gl1
    in
    mk_thm gl2

  (** [mk_subtype scp name args d setP rep]:

      - check name doesn't exist already
      - check all arguments in args are unique
      - check def is well defined
      (all constructors exist and variables are in the list of arguments)
      - ensure setP has type (d -> bool)
      - declare rep as a function of type (d -> n)
      - make subtype property from setp and rep.
  *)
  let mk_subtype scp name args dtype setp rep_name abs_name exist_thm =
    let dtype1 = Ltype.set_name scp dtype
    and setp1 = Lterm.set_names scp setp
    in
    let subtype_def =
      Defn.mk_subtype scp name args dtype1 setp1 rep_name abs_name
    in
    let new_setp = subtype_def.Defn.set
    and type_id = subtype_def.Defn.id
    and (rep_id, rep_ty) = subtype_def.Defn.rep
    and (abs_id, abs_ty) = subtype_def.Defn.abs
    in
    (* try to prove the subtype exists *)
    let _ = prove_subtype_exists scp new_setp exist_thm
    in
    (* temporarily extend the scope with the new type and rep identifier *)
    (* nscp0: scope with new type *)
    let nscp0 = Scope.extend_with_typedeclns scp [(type_id, args)]
    in
    (* declare the the rep function *)
    let rep_decln = mk_termdecln nscp0 rep_name rep_ty
    and abs_decln = mk_termdecln nscp0 abs_name abs_ty
    in
    (* nscp1: scope with new type and rep identifier *)
    let nscp1 =
      let (rid, rty) = dest_termdecln rep_decln
      and (aid, aty) = dest_termdecln abs_decln
      in
      Scope.extend_with_terms nscp0 [(rid, rty); (aid, aty)]
    in
    TypeDef
      {
        type_name = subtype_def.Defn.id;
        type_args = subtype_def.Defn.args;
        type_base = dtype1;
        type_rep = rep_decln;
        type_abs = abs_decln;
        type_set = Formula.make scp new_setp;
        rep_type = mk_subtype_thm nscp1 subtype_def.Defn.rep_T;
        rep_type_inverse =
          mk_subtype_thm nscp1 subtype_def.Defn.rep_T_inverse;
        abs_type_inverse =
          mk_subtype_thm nscp1 subtype_def.Defn.abs_T_inverse;
      }

  (** {5 Pretty printing} *)

  let print_termdefn ppinfo (n, ty, th) =
    Format.printf "@[";
    Format.printf "@[";
    Printkit.print_ident (Ident.mk_long Ident.null_thy (Ident.name_of n));
    Format.printf ":@ ";
    Printers.print_type ppinfo ty;
    Format.printf "@],@ ";
    print_thm ppinfo th;
    Format.printf "@]"

  let print_termdecln ppinfo (n, ty) =
    Format.printf "@[";
    Printkit.print_ident (Ident.mk_long Ident.null_thy (Ident.name_of n));
    Format.printf ":@ ";
    Printers.print_type ppinfo ty;
    Format.printf "@]"

  let print_typealias ppinfo (n, args, ty) =
    let named_ty =
      Gtype.mk_constr n
        (List.map (fun x -> Gtype.mk_var x) args)
    in
    Format.printf "@[";
    Printers.print_type ppinfo named_ty;
    begin
      match ty with
      | None -> ()
      | (Some t) ->
         Format.printf "=@,";
        Printers.print_type ppinfo t
    end;
    Format.printf "@]"

  let rec print_subtype ppinfo x =
    let named_ty =
      Gtype.mk_constr x.type_name
        (List.map (fun x -> Gtype.mk_var x) x.type_args)
    in
    Format.printf "@[<v>";
    Format.printf "@[";
    Printers.print_type ppinfo named_ty;
    Format.printf "@ =@ ";
    Printers.print_type ppinfo x.type_base;
    Format.printf "@,:@ ";
    Formula.print ppinfo x.type_set;
    Format.printf "@]@,";
    print_cdefn ppinfo x.type_rep;
    Format.printf "@,";
    print_cdefn ppinfo x.type_abs;
    Format.printf "@,";
    print_thm ppinfo x.rep_type;
    Format.printf "@,";
    print_thm ppinfo x.rep_type_inverse;
    Format.printf "@,";
    print_thm ppinfo x.abs_type_inverse;
    Format.printf "@]"
  and
      print_cdefn ppinfo x =
    Format.printf "@[";
    begin
      match x with
      | TypeAlias (n, args, ty) ->
         print_typealias ppinfo (n, args, ty)
      | TypeDef y -> print_subtype ppinfo y
      | TermDecln (n, ty) -> print_termdecln ppinfo (n, ty)
      | TermDef (n, ty, th) -> print_termdefn ppinfo (n, ty, th)
    end;
    Format.printf "@]"
end

let print_sqnt ppinfo sq =
  let nice = !Settings.nice_sequent in
  let nice_prefix =
    if nice
    then (!Settings.nice_sequent_prefix)
    else "-"
  in
  let name_of_asm i tg =
    if (Unique.name tg) = ""
    then (nice_prefix^(string_of_int (-i)))
    else Unique.name tg
  and name_of_concl i tg =
    if (Unique.name tg) = ""
    then string_of_int i
    else Unique.name tg
  in
  let rec print_asm i afl =
    Format.printf "@[<v>";
    begin
      match afl with
      | [] -> ()
      | (s::als) ->
         Format.printf "@[[%s] " (name_of_asm i (form_tag s));
         Printers.print_term ppinfo (Formula.term_of (drop_tag s));
         Format.printf "@]@,";
         print_asm (i-1) als
    end;
    Format.printf "@]"
  and print_cncl i cfl =
    Format.printf "@[<v>";
    begin
      match cfl with
      | [] -> ()
      | (s::cls) ->
         Format.printf "@[[%s] " (name_of_concl i (form_tag s));
         Printers.print_term ppinfo (Formula.term_of (drop_tag s));
         Format.printf "@]@,";
         print_cncl (i+1) cls
    end ;
    Format.printf "@]"
  in
  let sq_asms = (Sequent.asms sq)
  and sq_concls = (Sequent.concls sq)
  in
  Format.printf "@[<v>";
  begin
    match sq_asms with
    | [] -> ()
    | _ -> print_asm (-1) sq_asms
  end;
  Format.printf ("@[----------------------@]@,");
  print_cncl 1 sq_concls;
  Format.printf "@]"

let print_node ppstate n = print_sqnt ppstate (Subgoals.node_sqnt n)

let print_branch ppstate branch=
  let rec print_subgoals i gs =
    match gs with
    | [] -> ()
    | (y::ys) ->
       Format.printf "@[<v>";
      Format.printf "@[(Subgoal %i)@]@," i;
      print_sqnt ppstate y;
      Format.printf "@]@,";
      print_subgoals (i + 1) ys
  in
  let sqnts = Subgoals.branch_sqnts branch
  in
  Format.printf "@[<v>";
  begin
    match sqnts with
    | [] -> Format.printf "@[No subgoals@]@,"
    | _ ->
       let len=(List.length sqnts)
       in
       Format.printf "@[%i %s@]@,"
         len
         (if len > 1 then "subgoal" else "subgoals");
       print_subgoals 1 sqnts
  end;
  Format.printf "@]"
