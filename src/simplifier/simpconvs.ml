(*----
  Name: simpconvs.ml
  Copyright M Wahab 2005-2010
  Author: M Wahab  <mwb.cde@googlemail.com>

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

let log_message = ref None
let log x = log_message:=Some x
let log_tac x g = log x; Tactics.skip g

(** Functions to prepare theorems and assumptions being added to a
    simpset.
*)

open Simputils
open Boollib
open Boollib.Thms
open Boollib.Convs
open Boollib.Rules
open Tactics

(*** Theorems and conversions used by the simplifier. ***)

(*** Theorems ***)

(** [cond_rule_true_thm]: |- !x y: (x=>y) = (x => (y=true))
*)
let cond_rule_true_id = Ident.mk_long "_simplifier" "cond_rule_true"
let make_cond_rule_true_thm ctxt =
  Commands.prove ctxt << !x y: (x => y) = (x => (y = true)) >>
  (allC ++ allC ++
     (?> fun info1 g1 ->
       let y_term =
	 Lib.get_one (Info.constants info1) 
	   (Failure "make_cond_rule_true_thm: y-term")
       in 
       seq 
         [
           cut (rule_true_thm ctxt);
           inst_tac [y_term];
	   once_replace_tac ctxt;
	   eq_tac ctxt
         ] g1))

(*
let cond_rule_true_var = Lib.freeze (make_cond_rule_true_thm)
let cond_rule_true_thm () = Lib.thaw ~fresh:fresh_thm cond_rule_true_var
*)
let cond_rule_true_thm ctxt = 
  Context.find_thm ctxt cond_rule_true_id make_cond_rule_true_thm

(** [cond_rule_false_thm]: |- !x y: (x=>~y) = (x => (y=false))
*)
let cond_rule_false_id = Ident.mk_long "_simplifier" "cond_rule_false"
let make_cond_rule_false_thm ctxt =
  Commands.prove ctxt << !x y: (x=>(not y)) = (x => (y=false)) >>
  (allC ++ allC ++
     (?> fun info g -> 
       let y_term = 
	 Lib.get_one (Info.constants info) 
	   (Failure "make_cond_rule_false_thm: y-term")
       in 
       (cut (rule_false_thm ctxt) ++ inst_tac [y_term]
	++ once_replace_tac ctxt
	++ eq_tac ctxt) g))
  
(*
let cond_rule_false_var = Lib.freeze make_cond_rule_false_thm
let cond_rule_false_thm () =
  Lib.thaw ~fresh:fresh_thm cond_rule_false_var
*)
let cond_rule_false_thm ctxt =
  Context.find_thm ctxt cond_rule_false_id make_cond_rule_false_thm

(** [cond_rule_imp_false_thm]: |- !x y: (x=>false) = (not x)
*)
let cond_rule_imp_false_id = 
  Ident.mk_long "_simplifier" "cond_rule_imp_false"
let make_cond_rule_imp_false_thm ctxt =
  Commands.prove ctxt << !x: (x => false) = (not x) >>
  (allC ++ equals_tac ctxt ++ blast_tac ctxt)

(*
let cond_rule_imp_false_var = Lib.freeze (make_cond_rule_imp_false_thm)
let cond_rule_imp_false_thm () =
  Lib.thaw ~fresh:fresh_thm cond_rule_imp_false_var
*)
let cond_rule_imp_false_thm ctxt =
  Context.find_thm ctxt cond_rule_false_id make_cond_rule_imp_false_thm

(** [cond_rule_imp_not_true]: |- !x y: (x=> not true) => (not x)
*)
let cond_rule_imp_not_true_id = 
  Ident.mk_long "_simplifier" "cond_rule_imp_not_true"

let make_cond_rule_imp_not_true_thm ctxt =
  Commands.prove ctxt << !x: (x => (not true)) = (not x) >>
  (allC  ++ equals_tac ctxt ++ blast_tac ctxt)

(*
let cond_rule_imp_not_true_var = Lib.freeze (make_cond_rule_imp_not_true_thm)
let cond_rule_imp_not_true_thm () =
  Lib.thaw ~fresh:fresh_thm cond_rule_imp_not_true_var
*)
let cond_rule_imp_not_true_thm ctxt =
  Context.find_thm ctxt 
    cond_rule_imp_not_true_id 
    make_cond_rule_imp_not_true_thm

(** [neg_disj]: |- not (a | b) = ((not a) & (not b))
*)
let neg_disj_id = 
  Ident.mk_long "_simplifier" "neg_disj"

let make_neg_disj_thm ctxt =
  Commands.prove ctxt << !x y: (not (x or y)) = ((not x) and (not y)) >>
  (allC ++ allC ++ equals_tac ctxt ++ blast_tac ctxt)

(*
let neg_disj_var = Lib.freeze (make_neg_disj_thm)
let neg_disj_thm () = Lib.thaw ~fresh:fresh_thm neg_disj_var
*)
let neg_disj_thm ctxt = 
  Context.find_thm ctxt neg_disj_id make_neg_disj_thm

(** [neg_eq_sym]: |- not (a = b) = not (b = a) *)
let neg_eq_sym_id = 
  Ident.mk_long "_simplifier" "neg_eq_sym"
let make_neg_eq_sym_thm ctxt=
  let thm = Boollib.Thms.eq_sym_thm ctxt
  in 
  Commands.prove ctxt 
  << !x y: (not (x = y)) = (not (y = x)) >>
    (seq
       [ 
	 allC; allC; equals_tac ctxt;
         iffE ctxt
         --
	   [
	     (?> fun info g -> 
	       let (atg, _) = 
                 Lib.get_two (Info.aformulas info)
                   (error "simpconvs.make_neg_eq_sym_thm:1")
	       in 
	       (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
	        ++ basic) g);
	     (?> fun info g -> 
	       let (_, atg) = 
                 Lib.get_two (Info.aformulas info)
                   (error "simpconvs.make_neg_eq_sym_thm:1")
	       in 
	       (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
	        ++ basic) g)
	   ]
       ])
      
(*
let neg_eq_sym_var = Lib.freeze (make_neg_eq_sym_thm)
let neg_eq_sym_thm () = Lib.thaw ~fresh:fresh_thm neg_eq_sym_var
*)
let neg_eq_sym_thm ctxt = 
  Context.find_thm ctxt neg_eq_sym_id make_neg_eq_sym_thm

(** [cond_neg_eq_sym]: |- (c=> not (a = b)) = (c => not (b = a))
*)
let cond_neg_eq_sym_id = Ident.mk_long "_simplifier" "cond_neg_eq_sym"
let make_cond_neg_eq_sym_thm ctxt=
  let thm = Boollib.Thms.eq_sym_thm ctxt
  in 
  Commands.prove ctxt
  << !c x y: (c => (not (x = y))) = (c => (not (y = x))) >>
      (seq
         [ 
	   allC; allC; allC; equals_tac ctxt; 
	   (iffE ctxt ++ (?> fun info -> implC ++ set_changes_tac info))
	   --
	     [
               (?> fun info ->
	       implA --
	         [
                   basic;
	           (fun g -> 
		     let (atg, _) = 
                       Lib.get_two (Info.aformulas info)
                         (error "simpconvs.make_cond_neg_eq_sym_thm:1")
		     in 
		     (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
		      ++ basic) g)]);
               (?> fun info ->
	         implA --
	           [basic;
	            (fun g -> 
		      let (_, atg) = 
                        Lib.get_two (Info.aformulas info)
                          (error "simpconvs.make_cond_neg_eq_sym_thm:2")
		      in 
		      (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
		       ++ basic) g)])
	     ]
         ])

(*
let cond_neg_eq_sym_var = Lib.freeze (make_cond_neg_eq_sym_thm)
let cond_neg_eq_sym_thm () =
  Lib.thaw ~fresh:fresh_thm cond_neg_eq_sym_var
*)
let cond_neg_eq_sym_thm ctxt =
  Context.find_thm ctxt cond_neg_eq_sym_id make_cond_neg_eq_sym_thm

(** [cond_eq_sym]: |- (c=> not (a = b)) = (c => not (b = a))
*)
let cond_eq_sym_id = Ident.mk_long "_simplifier" "cond_eq_sym"
let make_cond_eq_sym_thm ctxt=
  let thm = Boollib.Thms.eq_sym_thm ctxt
  in 
  Commands.prove ctxt
  << !c x y: (c => (x = y)) = (c => (y = x)) >>
      (seq
         [ 
	   allC; allC; allC; equals_tac ctxt; 
           (iffE ctxt ++ (?> fun info -> implC ++ set_changes_tac info))
	   --
	     [
               (?> fun info ->
	       implA
	       --
	         [basic;
	          (fun g -> 
		    let (atg, _) =
                        Lib.get_two (Info.aformulas info)
                          (error "simpconvs.make_cond_eq_sym_thm:1")
		    in 
		    (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
		     ++ basic) g)]);
               (?> fun info ->
	       implA
	       --
	         [basic;
	          (fun g -> 
		    let (_, atg) = 
                        Lib.get_two (Info.aformulas info)
                          (error "simpconvs.make_cond_eq_sym_thm:2")
		    in 
		    (once_rewrite_tac ctxt ~f:(ftag atg) [thm]
		     ++ basic) g)])
	     ]
         ])

(*
let cond_eq_sym_var = Lib.freeze (make_cond_eq_sym_thm)
let cond_eq_sym_thm () =
  Lib.thaw ~fresh:fresh_thm cond_eq_sym_var
*)
let cond_eq_sym_thm ctxt =
  Context.find_thm ctxt cond_eq_sym_id make_cond_eq_sym_thm


(*** Rewriting conversions and tactics ***)

(** Rewriting applied inside topmost universal quantifiers *)

(** [simple_rewrite_conv scp rule trm]

    Form an equality from term [trm = !x .. y: body] and [rule = (l = r)] by
    descending through topmost universal quantifiers of [trm] and
    applying rewrite once only to the body of [trm]. Return the theorem
    stating the equality [(!x..y: body) = (!x.. y: (body = r))].

    e.g 
    [simple_rewrite_conv |- ! a: a = true,  |- !x y z: (f x y z) ]
    ->
    [ |- (!x y z: f x y z) = (! x y z: (f x y z = true))  ]
*)
let simple_rewrite_conv scp rule trm =
  let key = Rewrite.neg_key Rewrite.allq_key in 
  let plan =  Rewrite.mk_keyed key [Rewrite.mk_rules [rule]] in 
  let conv = Logic.Conv.rewrite_conv
  in 
  conv plan scp trm

(** [simple_rewrite_rule scp rule thm]

    Apply [simple_rewrite_conv] to theorem [thm].
*)
let simple_rewrite_rule scp rule thm =
  conv_rule scp (fun s -> simple_rewrite_conv s rule) thm

(** [simple_asm_rewrite_tac rule asm]

    Rewrite assumption [asm] with [rule] by descending through topmost
    universal quantifiers and applying rewrite once only to the body of
    [asm].  i.e.
    
    rule=|- lhs = rhs
    asm:lhs, A |- C 
    -->
    asm:rhs, A |- C
*)
let simple_asm_rewrite_tac ctxt rule asm node =
  let sqnt = sequent node in 
  let (_, f) = Logic.get_label_asm asm sqnt
  and scp = scope_of node in 
  let trm = Formula.term_of f in 
  let thm = 
    if Lterm.is_all trm
    then simple_rewrite_conv scp rule trm
    else rule
  in 
  once_rewrite_tac ctxt [thm] ~f:asm node

(*** 
     Functions manipulating theorems, needed to
     convert theorems to rewriting rules.
***)

(** [negate_concl_tac info t g]: Negate conclusion [t], making it
    assumption tagged [t'].
*)
let negate_concl_tac ctxt clbl goal =
  let make_neg_concl c g =
    let cform = get_concl c g in
    if (Formula.is_neg cform)
    then skip g
    else once_rewrite_tac ctxt [double_not_thm ctxt] ~f:c g
  in
  seq 
    [ 
      make_neg_concl clbl;
      Tactics.negC ~c:clbl;
      (?> fun inf -> 
        set_changes_tac (Changes.make [] (Info.aformulas inf) [] []))
    ] goal

(*** Preparing simplifier rules. ***)

(** Tests on theorems *)

(** [is_many_conj thm]: test [thm] is of the form |- a and b and
    ... and z
*)
let is_many_conj thm = Lterm.is_conj (Logic.term_of thm)

(** [is_neg_disj thm]: test [thm] is of the form |- not (a or b)
*)
let is_neg_disj thm =
  let trm = Logic.term_of thm
  in 
  ((Lterm.is_neg trm)
   && (Lterm.is_disj (Term.rand trm)))

(** [is_iffterm (vars, cnd, main)]: true if [main] is of the for [a
    iff b]
*)
let is_iffterm (vars, cnd, main) =
  try fst(Term.dest_fun main) = Lterm.iffid
  with _ -> false

(** [is_negation (var, cnd, main): true if [main] is of the form [not
    a]
*)
let is_negation (vars, cnd, main) = Lterm.is_neg main

(** [is_equality (var, cnd, main): true if [main] is of the form a=b
*)
let is_equality (vars, cnd, main) = Lterm.is_equality main

let is_constant clst (qs, c, t) = List.exists (Term.equals t) clst
let is_constant_true (qs, c, t) = Lterm.is_true t
let is_constant_false (qs, c, t) = Lterm.is_false t
let is_constant_bool (qs, c, t) =
  Pervasives.(||)
    (is_constant_true (qs, c, t))
    (is_constant_true (qs, c, t))

let is_neg_all (qs, c, t) = 
  if Lterm.is_neg t
  then 
    let (_, not_body) = Term.dest_unop t in
    Lterm.is_all not_body
  else false

let is_neg_exists (qs, c, t) = 
  if Lterm.is_neg t
  then 
    let (_, not_body)=Term.dest_unop t in
    Lterm.is_exists not_body
  else false

(** [is_rr_rule qs c l r]: Check that [c => (l = r)] is a rewrite rule.

    All variables (in [qs]) occuring in [c] or [r] must also occur in [l]

    Returns [(cnd, rhs)]
    where 
    [cnd = Some(true)] iff all variables in [c] occur in [l].
    [cnd = None] if no condition.
    [rhs = Some(true)] iff all variables in [r] occur in [l].
    [rhs = None] if no [rhs].
*)
let is_rr_rule (qs, c, l, r) =
  let is_var q = List.exists (Basic.binder_equality q) qs in 
  let vars = Simputils.find_variables is_var (Term.empty_subst()) l in 
  let rret =
    match r with 
      | None -> None 
      | Some(rhs) -> 
	try check_variables is_var vars rhs; Some(true)
	with Not_found -> Some(false)
  in 
  let cret =
    match c with 
      | None -> None 
      | Some(cnd) -> 
	try check_variables is_var vars cnd; Some(true)
	with Not_found -> Some(false)
  in 
  (cret, rret)

let is_rr_equality (qs, c, a) =
  if Lterm.is_equality a
  then 
    let (_, lhs, rhs) = Term.dest_binop a
    in 
    match is_rr_rule (qs, c, lhs, (Some rhs)) with
      | (Some(true), Some(true)) -> true
      | (None, Some(true)) -> true
      | _ -> false
  else false

(** Two types of rule: theorems and assumptions for both: a formula f
    is transformed to T(f) as follows:

    T(x and y) = T(x), T(y)
    T(x iff y) = T(x=y), if this results in a rewrite rule (not implemented)
    T(not x) = x=false
    T(x) = x=true
    T(not (?x. y)) = T(!x. not y)

    Conditional formulas: 
    T(c=>false) = T(not c)
    T(c=>not true) = T(not c)
    T(c=>(x and y)) = c=>(x and y)
    T(c=>x) = (c => T(x))

    Rewrite rules:
    T(x=y) = x=y, if all variables in y also occur in x 
    = (x=y)=true and (y=x)=true, otherwise

    T(c=>x=y) 
    = c=>(x=y), if all variables in y and c occur in x
    = c=>((x=y)=true) and c=>((y=x)=true), if variables in y don't
    occur in x and all variables in c occur in x
    = (c=>x=y)=true, otherwise
*)


(*** Functions to make simp rules from theorems **)

(** [thm_to_rule scp thm]: convert theorem [thm] to a list of theorems
    suitable for rewriting.

    Conversion:
    |- l=r   ->  no change, if all variables in [r] also occur in [l])
    -> |- (l=r)=true; |- (r=l)=true , otherwise

    |- c => l = r -> no change, if all variables in [r] and [c] 
    also occur in [l]
    |- c=> (l=r)=true ; |- c=> (r=l)=true, if all variables in [c]
    occur in [l=r]
    -> |- (c=> l = r)=true, otherwise

    |- a -> |- a=true
    |- c=> a -> |- c => a=true
    |- not (a = b) -> |- (a = b) = false ; |- (b = a) = false
    |- not a ->  |- a=false
    |- c=> not a -> |- c => a = false
    |- a and b -> |- a; |- b
    |- false -> not true
*)

module Thms =
struct
  (* The conversion functions *)

  let rec accept_all_thms ret (ctxt, scp, thm, (qs, c, a)) = 
    if is_constant_true (qs, c, a)
    then ret
    else (once_rewrite_rule ctxt [rule_true_thm ctxt] thm)::ret

  and do_rr_equality ret (_, _, thm, (qs, c, a)) =
    if is_rr_equality (qs, c, a)
    then (thm::ret)
    else failwith "is_rr_equality: not a rewrite rule"

  and do_eq_rule ret (ctxt, scp, thm, (qs, c, a)) =
    if Lterm.is_equality a
    then 
      match is_rr_rule (qs, c, a, None) with
	| (None, _) -> 
	    let thm1 = simple_rewrite_rule scp (eq_sym_thm ctxt) thm
	    in 
	    (simple_rewrite_rule scp (rule_true_thm ctxt) thm)
	    ::(simple_rewrite_rule scp (rule_true_thm ctxt) thm1)
	    ::ret
        | (Some(true), _) -> 
	  let thm1 = simple_rewrite_rule scp (cond_eq_sym_thm ctxt) thm
	  in 
	  (simple_rewrite_rule scp (cond_rule_true_thm ctxt) thm)
	  ::(simple_rewrite_rule scp (cond_rule_true_thm ctxt) thm1)
	  ::ret
        | _ -> 
	  failwith "do_eq_rule"
    else
      failwith "do_eq_rule"    
        
  and do_fact_rule ret (ctxt, scp, thm, (qs, c, a)) = 
    if not (Lterm.is_equality a)
    then 
      match is_rr_rule (qs, c, a, None) with
        | (None, _) -> 
 	    if is_constant_true (qs, c, a)
 	    then ret
 	    else (simple_rewrite_rule scp (rule_true_thm ctxt) thm)::ret
        | (Some(true), _) -> 
 	  if is_constant_true (qs, c, a)
 	  then ret
 	  else 
 	    (** |- c => false -> |- not c*)
 	    if is_constant_false (qs, c, a)
 	    then 
 	      let thm1 = 
                simple_rewrite_rule scp (cond_rule_imp_false_thm ctxt) thm
 	      in
 	      single_thm_to_rules ctxt ret scp thm1
 	    else 
	      let thm1 =
 	        simple_rewrite_rule scp (cond_rule_true_thm ctxt) thm
	      and thm2 =
	        simple_rewrite_rule scp (rule_true_thm ctxt) thm
	      in 
	      thm1::thm2::ret
        | _ -> failwith "do_fact_rule"
    else 
      do_eq_rule ret (ctxt, scp, thm, (qs, c, a))
        
  and do_neg_eq_rule ret (ctxt, scp, thm, (qs, c, a)) =
    if (Lterm.is_neg a) && (Lterm.is_equality (Term.rand a))
    then 
      match c with 
	| None -> 
	    let thm1 = simple_rewrite_rule scp (neg_eq_sym_thm ctxt) thm
	    in 
	    (simple_rewrite_rule scp (rule_false_thm ctxt) thm)
	    ::(simple_rewrite_rule scp (rule_false_thm ctxt) thm1)
	    ::ret
        | _ -> 
	  let thm1 = simple_rewrite_rule scp (cond_neg_eq_sym_thm ctxt) thm
	  in 
	  (simple_rewrite_rule scp (cond_rule_false_thm ctxt) thm)
	  ::(simple_rewrite_rule scp (cond_rule_false_thm ctxt) thm1)
	  ::ret
    else
      failwith "do_neg_eq_rule"    

  and do_neg_rule ret (ctxt, scp, thm, (qs, c, a)) = 
    if Lterm.is_neg a
    then 
      match is_rr_rule (qs, c, a, None) with
	| (None, _) -> 
	    if Lterm.is_equality (Term.rand a)
	    then (* Convert |- not (a = b) and |- c=> not (a = b) *)
	      do_neg_eq_rule ret (ctxt, scp, thm, (qs, c, a))
	    else 
	      (simple_rewrite_rule scp (rule_false_thm ctxt) thm)::ret
        | (Some(true), _) -> 
	  (** |- c => not true -> |- not c *)
	  if is_constant_true (qs, c, Term.rand a)
	  then 
	    let thm1 = 
	      simple_rewrite_rule scp (cond_rule_imp_not_true_thm ctxt) thm
	    in
	    single_thm_to_rules ctxt ret scp thm1
	  else 
	    if Lterm.is_equality (Term.rand a)
	    then 
	      (* Convert |- not (a = b) and |- c=> not (a = b) *)
	      do_neg_eq_rule ret (ctxt, scp, thm, (qs, c, a))
	    else 
	      let thm1 = 
                simple_rewrite_rule scp (cond_rule_false_thm ctxt) thm
	      and thm2 = 
                simple_rewrite_rule scp (rule_true_thm ctxt) thm
	      in 
              thm1::thm2::ret
        | _ -> failwith "do_neg_rule"
    else failwith "do_neg_rule"

  and do_neg_all_rule ret (ctxt, scp, thm, (qs, c, a)) = 
    match c with 
      | None -> 
          if is_neg_all (qs, c, a)
          then 
	    let thm1= once_rewrite_rule ctxt [neg_all_conv ctxt a] thm
	    in 
	    single_thm_to_rules ctxt ret scp thm1
          else failwith "do_neg_all_rule: Not a negated universal quantifier"
      | Some _ ->  
        failwith 
	  "do_neg_all_rule: Not an unconditional negated universal quantifier"

  and do_neg_exists_rule ret (ctxt, scp, thm, (qs, c, a)) = 
    match c with 
        None -> 
          if is_neg_exists (qs, c, a)
          then 
	    let thm1 = once_rewrite_rule ctxt [neg_exists_conv ctxt a] thm
	    in 
	    single_thm_to_rules ctxt ret scp thm1
          else 
            failwith "do_neg_exists_rule: Not a negated existential quantifier"
      | Some _ ->  failwith 
	("do_neg_exists_rule: "
         ^"Not an unconditional negated existential quantifier")

  and do_conj_rule ret (ctxt, scp, thm, (qs, c, a)) =
    if is_many_conj thm
    then 
      let lst = Boollib.Rules.conjuncts ctxt thm
      in 
      List.fold_left (fun r t -> single_thm_to_rules ctxt r scp t) ret lst
    else failwith "do_conj_rule: not a conjunction"

  and do_neg_disj_rule ret (ctxt, scp, thm, (qs, c ,a)) =
    if is_neg_disj thm
    then 
      let thm1 = once_rewrite_rule ctxt [neg_disj_thm ctxt] thm
      in 
      single_thm_to_rules ctxt ret scp thm1
    else
      failwith "do_neg_disj_rule: Not a negated disjunction."

  and single_thm_to_rules ctxt ret scp thm = 
    let (qs, c, a) = strip_qnt_cond (Logic.term_of thm)
    in 
    let make x = 
      Lib.apply_first 
        [
          do_neg_disj_rule ret;
          do_conj_rule ret;
          do_neg_exists_rule ret;
          do_rr_equality ret;
          do_neg_rule ret;
          do_fact_rule ret;
          accept_all_thms ret
        ] x
    in 
    try make (ctxt, scp, thm, (qs, c, a))
    with err -> raise (add_error "Simpconvs.single_thm_to_rules" err)

end

let thm_to_rules ctxt scp thm = 
  let ret = Thms.single_thm_to_rules ctxt [] scp thm
  in 
  List.rev ret

(*** Converting assumptions to rewrite rules **)

(** [asm_rewrite_tac thm tg g]:

    Rewrite assumption [tg] with rule [thm] = |- a=b

    tg:a, asms |- concl
    -->
    tg:b, asms |- concl
*)
let asm_rewrite_tac ctxt thm tg g =
  once_rewriteA_tac ctxt [thm] ~a:(ftag tg) g
    
(** [qnt_asm_rewrite_tac thm tg g]:

    Descend through topmost quantifiers and rewrite assumption [tg]
    with rule [thm]
    
    tg:a, asms |- concl
    -->
    tg:b, asms |- concl
*)
let qnt_asm_rewrite_tac ctxt thm tg g =
  simple_asm_rewrite_tac ctxt thm (ftag tg) g

(** [add_asm_tac ret tg g]: Add the assumption labelled [tg] to [ret].
    
    If g = [ a{_ tg}, asms |- concl ]
    then return [ret = [a]::!(reg)]
*)
(**
let add_asm_tac ret tg g = 
  let aform = get_tagged_asm (ftag tg) g
  in 
  update_tac (fun _ -> ret := aform::(!ret)) () g
**)

let new_add_asm ret tg g = 
  let aform = get_tagged_asm (ftag tg) g in 
  aform::ret


(** [solve_not_true_tac]: Solve goals of the form [not true |- C].
*)
let solve_not_true_tac tg goal = 
  seq
    [
      negA ~a:(ftag tg);
      (?> fun info g ->
	let ctg = get_one ~msg:"solve_not_true_tac" (Info.cformulas info)
	in 
	trueC ~c:(ftag ctg) g)
    ] goal

(** Functions to convert an assumption

    [accept_asm]: convert |- a to |- a=true and delete |- true

    [rr_equality_asm]: accept |- l=r or |= c=> l=r 

    [eq_asm]:
    Convert [a=b] to [(a=b) = true] and [(b=a)=true]
    and [c=> (a=b)] to [c=>((a=b) = true)] and [c=>((b=a)=true)]
    This is only called if [rr_equality_asm] failed.

    [fact_rule_asm]: 
    convert |- a to |- a=true 
    and |- c=> false to |- (not c)
    and |- c=> a to |- c => a=true; |- (c=>a) = true 
    pass [(a=b)] and [c=>(a=b)] to [eq_asm]
    and solve [false |- C]

    [neg_eq_asm]:
    Convert [not (a=b)] to [(a=b) = false] and [(b=a)=false]
    and [c=>not (a=b)] to [c=>((a=b) = false)] and [c=>((b=a)=false)]

    [neg_rule_asm]: 
    convert 
    and |- c=> not true to |- (not c)
    and |- not a to |- a=false 
    and |- c=> not a to |- c=> a=false
    pass [not (a=b)] and [c=>not(a=b)] to [neg_eq_asm]
    and solve  [not true |- C]

    [conj_rule_asm]: convert |- (a & b)  to |- a and |- b

    [neg_all_rule_asm]: convert |- not (!a: b) to |- ?a: not b
    then convert the new theorem. (Not used)

    [neg_exists_rule_asm]: convert |- not (?a: b) to |- !a: not b
    then convert the new theorem.

    [conj_rule_asm]: convert  |- a and b to |- a and |- b.

    [single_asm_to_rules l g]:
    convert an assumption stating a single fact to a rewrite-rule.

    [asm_to_rules tg ret g]: Toplevel conversion function.  Convert
    assumption [tg] of goal [g] to one or more rules.  The tag of each
    rule (including [tg]) generated from [tg] is stored in [ret].
*)
module Asms =
struct
  (** [asm_rewrite_add_tac ret thm tg g]:

      Rewrite assumption [tg] with [thm] after descending through the
      topmost quantifiers.

      (!x:a){_ tg}, asms |- concl
      -->
      (!x:(a=T)){_ tg}, asms |- concl

      Return [ret = [b]::!(reg)]
  *)
  let asm_rewrite_add_tac ctxt ret thm tg goal =
    let gctxt = context_of ctxt goal in 
    fold_seq ret
      [
        (fun lst -> (lst >+ qnt_asm_rewrite_tac gctxt thm tg));
        (fun lst g ->
          let info = Info.changes g in
          let tg1 = get_one ~msg:"Simpconvs.Asms.asm_rewrite_add_tac"
            (Info.aformulas info)
          in
          ((new_add_asm lst tg1 g) >+ skip) g)
      ] goal

  let rec accept_asm ret (ctxt, tg, (qs, c, a)) goal =
    let gctxt = context_of ctxt goal in 
    if is_constant_true (qs, c, a)
    then 
      (** Delete assumption true *)
      (ret, deleteA (ftag tg) goal)
    else 
      if is_constant_false (qs, c, a)
      then (** Solve assumption false *)
        (ret, falseA gctxt ~a:(ftag tg) goal)
      else 
        asm_rewrite_add_tac gctxt ret (rule_true_thm gctxt) tg goal

  and rr_equality_asm ret (ctxt, tg, (qs, c, a)) g =
    if is_rr_equality (qs, c, a)
    then (new_add_asm ret tg g, skip g)
    else failwith "rr_equality_asm: not a rewrite rule"

  and eq_asm (ret: 'a list) (ctxt, tg, (qs, c, a)) g =
    let gctxt = context_of ctxt g in 
    if Lterm.is_equality a
    then 
      let asm_info = is_rr_rule (qs, c, a, None) in 
      let rr_thm =
        match asm_info with
 	  | (None, _ ) -> eq_sym_thm gctxt
 	  | (Some(true), _) -> cond_eq_sym_thm gctxt
 	  | _ -> failwith "eq_asm"
      in 
      let rr_truth_thm =
        match asm_info with
 	  | (Some(true), _) -> cond_rule_true_thm gctxt
 	  | (_, _) -> rule_true_thm gctxt
      in 
      fold_seq []
        [
          (fun ret -> (ret >+ copyA (ftag tg)));
          (fun ret g1 ->
            let info = Info.changes g1 in
 	    let atg = get_one ~msg:"eq_asm" (Info.aformulas info)
 	    in 
 	    fold_seq ret
 	      [
                (fun l -> 
 		  (l >+ qnt_asm_rewrite_tac gctxt rr_thm atg));
                (fun l ->
 		  (l >+ qnt_asm_rewrite_tac gctxt rr_truth_thm atg));
 		(fun ret g3 -> 
                  (new_add_asm ret atg g3, skip g3));
		(fun ret g3 ->
                  (new_add_asm ret tg g3, 
                   qnt_asm_rewrite_tac gctxt rr_truth_thm tg g3))
 	      ] g1)
        ] g
    else 
      failwith "eq_asm"

  and fact_rule_asm ret (ctxt, tg, (qs, c, a)) g = 
    let gctxt = context_of ctxt g in 
    if not (Lterm.is_equality a)
    then 
      begin
        match is_rr_rule (qs, c, a, None) with
          | (None, _) -> 
	    if is_constant_true (qs, c, a)
	    then 
	      (** Delete assumption true *)
	      (ret, deleteA (ftag tg) g)
	    else 
	      if is_constant_false (qs, c, a)
	      then (** Solve assumption false *)
	        (ret, falseA gctxt ~a:(ftag tg) g)
	      else 
 	        asm_rewrite_add_tac gctxt ret (rule_true_thm gctxt) tg g
          | (Some(true), _) -> 
	    if is_constant_true (qs, c, a)
	    then 
	    (** Delete assumption true *)
	      (ret, deleteA (ftag tg) g)
	    else 
	    (** |- c => false -> |- not c*)
	      if is_constant_false (qs, c, a)
	      then 
	        fold_seq ret
                  [
                    (fun lst1 ->
                      (lst1 >+ 
                         (qnt_asm_rewrite_tac gctxt
                            (cond_rule_imp_false_thm gctxt) tg)));

                    (fun lst1 -> single_asm_to_rule gctxt lst1 tg)
	        ] g
	      else 
	        fold_seq ret
	          [
		    (fun lst -> (lst >+ copyA (ftag tg)));
		    (fun lst g1 -> 
                      let info = Info.changes g1 in
		      let atg = get_one ~msg:"neg_eq_asm" (Info.aformulas info)
		      in 
                      fold_seq lst
		        [
                          (fun lst1 ->
			    asm_rewrite_add_tac gctxt lst1
                              (cond_rule_true_thm gctxt) tg);
                          (fun lst1 ->
			    asm_rewrite_add_tac gctxt lst1 
                              (rule_true_thm gctxt) atg);
		        ] g1)
	          ] g
          | _ -> failwith "do_fact_asm"
      end
    else eq_asm ret (gctxt, tg, (qs, c, a)) g

  and neg_eq_asm ret (ctxt, tg, (qs, c, a)) g =
    let gctxt = context_of ctxt g in 
    if (Lterm.is_neg a) && (Lterm.is_equality (Term.rand a))
    then 
      let rr_thm =
        match c with
	  | None -> neg_eq_sym_thm gctxt
	  | _ -> cond_neg_eq_sym_thm gctxt
      in 
      fold_seq ret
	[
	  (fun lst g2 -> lst, copyA (ftag tg) g2);
	  (fun ret1 g1 ->
            let info = Info.changes g1 in
	    let atg = get_one ~msg:"neg_eq_asm" (Info.aformulas info)
	    in 
            let local_false_thm = rule_false_thm gctxt in
	    fold_seq ret1
	      [
		(fun lst g2 ->
                  (lst, qnt_asm_rewrite_tac gctxt rr_thm atg g2));
                (fun lst g2 -> 
                  (lst,
		   qnt_asm_rewrite_tac gctxt local_false_thm atg g2));
                (fun lst g2 ->
		  (new_add_asm lst atg g2,
		   qnt_asm_rewrite_tac gctxt local_false_thm tg g2));
                (fun lst g2 ->
		  new_add_asm lst tg g2, skip g2)
	      ] g1)
	] g
    else
      failwith "neg_eq_asm"

  and neg_disj_asm (ret: 'a list) (ctxt, tg, (qs, c, a)) g=
    let gctxt = context_of ctxt g in 
    if (Lterm.is_neg a) && (Lterm.is_disj (Term.rand a))
    then 
      match c with
	| None -> 
          begin
            try
	      fold_seq ret
		[
                  (fun lst -> 
                    (lst >+ asm_rewrite_tac gctxt (neg_disj_thm gctxt) tg));
                  (fun lst -> single_asm_to_rule gctxt lst tg)
		] g
            with _ -> asm_rewrite_add_tac gctxt ret (rule_false_thm gctxt) tg g
          end
        | Some _ ->  
	  failwith "neg_disj_asm: Not an unconditional negated disjunction"
    else failwith "neg_disj_asm"

  and neg_rule_asm (ret: 'a list) (ctxt, tg, (qs, c, a)) g = 
    let gctxt = context_of ctxt g in 
    if Lterm.is_neg a
    then 
      let b = Term.rand a in 
      begin
        match is_rr_rule (qs, c, a, None) with
	  | (None, _) -> 
	    if is_constant_false (qs, c, b)
	    then 
	      (** Delete assumption (not false) *)
	      (ret, deleteA (ftag tg) g)
	    else
	      if is_constant_true (qs, c, b)
	      then
                (** Solve assumption (not true) *)
		(ret, solve_not_true_tac tg g)
	      else 
		if Lterm.is_equality b 
		then neg_eq_asm ret (gctxt, tg, (qs, c, a)) g
		else 
		  if Lterm.is_disj b
		  then 
                    neg_disj_asm ret (gctxt, tg, (qs, c, a)) g
		  else 
                    asm_rewrite_add_tac gctxt ret (rule_false_thm gctxt) tg g
	  | (Some(true), _) -> 
	    if is_constant_false (qs, c, b)
	    then (ret, deleteA (ftag tg) g)
	    else
	      (** |- c => not true -> |- not c*)
	      if is_constant_true (qs, c, b)
	      then 
	        fold_seq ret 
                  [
                    (fun lst -> 
                      (lst >+
                         qnt_asm_rewrite_tac gctxt
                         (cond_rule_imp_not_true_thm gctxt) tg));
		    (fun lst -> single_asm_to_rule gctxt lst tg)
	          ] g
	      else 
	        if Lterm.is_equality b 
	        then neg_eq_asm ret (gctxt, tg, (qs, c, a)) g
	        else 
		  fold_seq ret
		    [
		      (fun lst -> (lst >+ copyA (ftag tg)));
                      (fun lst g1 ->
                        let info = Info.changes g1 in
		        let atg = 
			  get_one ~msg:"neg_rule_asm" (Info.aformulas info)
		        in 
		        fold_seq lst
			  [
                            (fun lst1 ->
			      asm_rewrite_add_tac gctxt lst1
			        (cond_rule_false_thm gctxt) tg);
                            (fun lst1 -> 
			      asm_rewrite_add_tac gctxt lst1
			        (rule_true_thm gctxt) atg)
			  ] g1)
		    ] g
	  | _ -> failwith "neg_rule_asm"
      end
    else failwith "neg_rule_asm"

  and conj_rule_asm ret (ctxt, tg, (qs, c, a)) g = 
    let gctxt = context_of ctxt g in 
    if Lterm.is_conj a
    then 
      fold_seq ret
	[
	  (fun lst -> (lst >+ conjA ~a:(ftag tg)));
          (fun lst g1 ->
            let inf = Info.changes g1 in
	    let ltg, rtg = 
	      get_two ~msg:"Simpconvs.conj_rule_asm" (Info.aformulas inf)
	    in 
	    fold_seq lst
	      [
		(fun lst1 -> single_asm_to_rule gctxt lst1 ltg);
		(fun lst1 -> single_asm_to_rule gctxt lst1 rtg)
	      ] g1)
	] g
    else failwith "conj_rule_asm"

  and neg_all_rule_asm ret (ctxt, tg, (qs, c, a)) g = 
    let gctxt = context_of ctxt g in 
    match c with 
      | None -> 
          if is_neg_all (qs, c, a)
          then 
            fold_seq ret
              [
	        (fun lst g1 -> 
                  (lst, asm_rewrite_tac gctxt (neg_all_conv gctxt a) tg g1));
                (fun lst -> single_asm_to_rule gctxt lst tg)
              ] g
          else failwith "neg_all_rule_asm: Not a negated universal quantifier"
      | Some _ ->  
        failwith 
	  "neg_all_rule_asm: Not an unconditional negated universal quantifier"

  and neg_exists_rule_asm (ret: 'a list) (ctxt, tg, (qs, c, a)) g = 
    let gctxt = context_of ctxt g in 
    match c with 
      | None -> 
          if is_neg_exists (qs, c, a)
          then 
            fold_seq ret
	      [ 
                (fun lst g1 -> 
                  (lst, 
                   asm_rewrite_tac gctxt (neg_exists_conv gctxt a) tg g1));
                (fun lst -> single_asm_to_rule gctxt lst tg)
              ] g
          else 
	    failwith "neg_exists_rule_asm: Not a negated existential quantifier"
      | Some _ ->  
        failwith 
	  ("neg_exists_rule_asm: "
           ^"Not an unconditional negated existential quantifier")

  and single_asm_to_rule ctxt ret tg goal = 
    let tform =  Logic.Sequent.get_tagged_asm tg (sequent goal) in 
    let trm = Formula.term_of (drop_tag tform) in 
    let (qs, c, a) = strip_qnt_cond trm in 
    let goal_ctxt = context_of ctxt goal in
    let make g = 
      Lib.apply_first 
        [
          (*     neg_all_rule_asm ret (tg, (qs, c, a)); *)
          neg_disj_asm ret (goal_ctxt, tg, (qs, c, a));
          neg_exists_rule_asm ret (goal_ctxt, tg, (qs, c, a));
          rr_equality_asm ret (goal_ctxt, tg, (qs, c, a));
          neg_rule_asm ret (goal_ctxt, tg, (qs, c, a));
          conj_rule_asm ret (goal_ctxt, tg, (qs, c, a));
          fact_rule_asm ret (goal_ctxt, tg, (qs, c, a));
          accept_asm ret (goal_ctxt, tg, (qs, c, a))
        ] g
    in 
    try make goal
    with err ->  raise (add_error "single_asm_to_rule" err)
end

(*
let asm_to_rules ret tg goal = 
  let ret1, goal1 = Asms.single_asm_to_rule (!ret) tg goal
  in
  ret := ret1;
  goal1
*)
let asm_to_rules ret tg goal = Asms.single_asm_to_rule ret tg goal

(*** Rules from assumptions and conclusions. ***)


(** Information about rules created from sequent formulas. **)
type rule_data = 
    { 
      src: Logic.tagged_form; (** The source of the rules. **)
      new_asm: Formula.t;
      (** The new assumption (e.g. when a conclusion is lifted into
	  the assumptions) to add to the simp set.  **)
      new_rules: (Logic.tagged_form) list 
    (** The rules formed fro the source. *)
    }

let mk_rule_data s a rs = 
  { src = s; new_asm = a; new_rules = rs }

(** [unpack_rule_data rd]: Unpack a list of rule data in a list of
    sources, a list of new assumptions and a list of new rules.
*)
let unpack_rule_data rds = 
  let srcs, asms = 
    Lib.apply_split (fun rd -> (rd.src, rd.new_asm)) rds
  in 
  let rules = Lib.apply_flatten (fun rd -> rd.new_rules) rds
  in 
  (srcs, asms, rules)

(** [prepare_asm data a goal]: Prepare assumption labelled [a] for use
    as a simp rule.

    Solves the goal if [a] is [false]. Otherwise, returns the list of
    new assumptions formed from [a] which are to be used as simp
    rules.

    {ul
    {- Copy the assumption to get new assumption [a1].}
    {- Call [asm_to_rules] on [a1] to get [rules].}
    {- For each new assumption [r], store the result as the pair
    [{ src = a; new_asm = a1; new_rules = rules }].
    {- Return the result in [data]. }
    }
*)

let prepare_asm ctxt data atg goal =
  let gctxt = context_of ctxt goal in 
  let asm_form = get_tagged_asm (ftag atg) goal in 
  let false_test g = 
    let (_, asm) = Logic.Sequent.get_tagged_asm atg (sequent g) in 
    Lterm.is_false (Formula.term_of asm)
  in 
  fold_seq []
    [
      (fun l -> seq 
        [
          (false_test --> Boollib.falseA gctxt ~a:(ftag atg));
          copyA (ftag atg)
        ] +< l);
      (fun _ g ->
        let info = Info.changes g in
        let a1 = get_one ~msg:"Simplib.prepare_asm" (Info.aformulas info) in 
        let a1form = drop_tag (get_tagged_asm (ftag a1) g) in
        let mk_data rules = 
          (mk_rule_data asm_form a1form rules)::data
        in 
        permute_tac mk_data (asm_to_rules gctxt [] a1) g)
    ] goal

(** [prepare_asms data asm g]: Apply [prepare_asm] to each assumption
    in the list [asms]. Return the cumulative results.
*)
let prepare_asms ctxt data ams goal =
  fold_data (prepare_asm ctxt) data ams goal

(** [prepare_concl data c goal]: Prepare conclusion labelled [a] for
    use as a simp rule.

    Solves the goal if [c] is [true]. Otherwise, returns the list of
    new assumptions formed from [c] which are to be used as simp
    rules.

    {ul 

    {- Copy the conclusion and lift it into the assumptions (by
    negation) to get new assumption [a].}

    {- Call [asm_to_rules] on [a] to get [rules].}

    {- For each new assumption [r], store the result as the pair
    [{ src = c; new_asm = a; new_rules = rules }].
    {- Return the result in [data]. }
    }
*)
let prepare_concl ctxt data c goal =
  let gctxt = context_of ctxt goal in 
  let concl_form = get_tagged_concl (ftag c) goal in 
  let true_test g = 
    let (_, concl) = Logic.Sequent.get_tagged_cncl c (sequent g)
    in 
    Lterm.is_true (Formula.term_of concl)
  in 
  fold_seq []
    [
      (fun l ->
        seq [
          (true_test --> Logic.Tactics.trueC (ftag c));
          copyC (ftag c);
          (?> fun info g -> 
            let c1 = get_one ~msg:"Simplib.prepare_concl" 
              (Info.cformulas info) 
            in 
            negate_concl_tac gctxt (ftag c1) g)
        ] +< l);
      (fun _ g ->
        let info = Info.changes g in 
        let a = get_one ~msg:"Simplib.prepare_concl" (Info.aformulas info) 
        in 
        let aform = drop_tag (get_tagged_asm (ftag a) g) in 
        let mk_data rules = 
          (mk_rule_data concl_form aform rules)::data 
        in 
        permute_tac mk_data (asm_to_rules gctxt [] a) g)
    ] goal

(** [prepare_concls data concls g]: Apply [prepare_concl] to each
    assumption in the list [concls]. Return the cumulative results.
*)
let prepare_concls ctxt data cs goal =
  fold_data (prepare_concl ctxt) data cs goal
