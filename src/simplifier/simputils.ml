module Simputils=
  struct

    (** Utility functions for simplifier *)

    open Term
    open Logicterm

    let dest_rrthm t = 
      match t with 
	Logic.RRThm (x) -> x
      | _ -> failwith("dest_rrth: failure")

    let dest_option x=
      match x with
	None -> failwith "dest_option"
      | Some c -> c

    let has_cond c =
      match c with
	None -> false
      | Some(_) -> true


(** [dest_implies trm]
   Destruct implication.
   fails if trm is not an implication.
*)
    let dest_implies trm =
      let (f, args)=Term.dest_fun trm
      in
      if(f=Logicterm.impliesid)
      then 
	Lib.get_two args (Failure "dest_implies: too many arguments")
      else raise (Failure "dest_implies: not an implication")

(** [sqnt_solved st g]: 
   true if sqnt st is no longer in goal g 
 *)
    let sqnt_solved st g =
      try
	ignore(List.find 
		 (fun x->Tag.equal st x) 
		 (Logic.get_subgoal_tags g));
	false
      with Not_found ->true

(** [apply_on_cond c t f x]
   if c is None then return [(t x)] else return [(f x)]
 *)
    let apply_on_cond c uncondf condf x =
      match c with
	None -> uncondf x
      | Some(_) -> condf x

(** [apply_tag tac g]
   apply tactic [tac] to goal [g]
   return new goal and tag record of tactic
 *)
    let apply_tag tac g =
      let inf=Drule.mk_info()
      in 
      let ng = tac inf g
      in 
      (!inf, ng)


(** [apply_get_formula_tag n tac g]
   apply tactic [tac] to goal [g]
   return tags of formulas
   fail if more than [n] new formulas (tags) are generated
*)
    let apply_get_formula_tag n tac g =
      let inf= Drule.mk_info()
      in 
      let ng = tac inf g
      in 
      let ntg = (!inf).Logic.forms
      in 
      if(List.length ntg)>n 
      then
	raise (Failure "too many tags")
      else (ntg, ng)

(** [apply_get_single_formula_tag tac g]
   apply tactic [tac] to goal [g]
   return tag of single formula.
   fail if more than 1 new formula is reported by [tac]
 *)
    let apply_get_single_formula_tag tac g =
      let ts, ng=apply_get_formula_tag 1 tac g
      in 
      (Lib.get_one ts (Failure "too many tags"), ng)

(** [rebuild_qnt k qs b]
   rebuild quantified term of kind k from quantifiers [qs] and body [b]

   e.g. [rebuild_qnt All ["x", "y", "z"] << b >>]
   ->
   [ << !x y z : b >> ]
 *)
    let rec rebuild_qnt k qs b=
      match qs with
	[] -> b
      | (x::xs) -> Basic.Qnt(k, x, rebuild_qnt k xs b)


(** [allA_list i vs g]
   apply [allA] to formula [i] using terms [vs]
 *)
    let allA_list i vs g =
      let rec inst_aux xs sq=
	match xs with 
	  [] -> sq
	| (c::cs) -> 
	    let nsq=Logic.Rules.allA None c i sq
	    in 
	    inst_aux cs nsq
      in 
      inst_aux vs g

(* [make_consts qs env]: 
   Get values for each binder in [qs] from [env].
   Use [base.some] if no value is found.
   [base.some] constant is defined in theory [base].
 *)
(* moved to drule.ml
    let make_consts qs env = 
      let make_aux q=
	try Term.find (Basic.Bound q) env
	with 
	  Not_found -> Logicterm.mk_some
      in 
      List.map make_aux qs
*)

  end

