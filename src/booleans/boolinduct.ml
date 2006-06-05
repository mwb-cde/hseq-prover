(*-----
 Name: boolinduct.ml
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2006
----*)

(*** Induction tactics ***)

open Lib.Ops
open Tactics

open Boolutil
open Boolbase
open Rewritelib


      
(*** Tactics ***)

(**
   [mini_scatter_tac ?info c goal]: Mini scatter tactic for induction.

   Scatter conclusion [c], using [falseA], [conjA], [existA],
   [trueC], [implC] and [allC]

*)
let mini_scatter_tac ?info c goal =
  let asm_rules =
    [ (fun inf l -> falseA ~info:inf ~a:l) ]
  in 
  let concl_rules =
    [
      (fun inf -> Logic.Tactics.trueC ~info:inf);
      (fun inf -> Logic.Tactics.conjC ~info:inf)
    ]
  in 
  let main_tac ?info =
    elim_rules_tac ?info (asm_rules, concl_rules)
  in 
    apply_elim_tac main_tac ?info ~f:c goal

(** 
    [mini_mp_tac ?info asm1 asm2 goal]: Apply modus ponens to 
    [asm1 = A => C] and [asm2 = A] to get [asm3 = C].
    info: aformulas=[asm3]; subgoals = [goal1]
    Fails if [asm2] doesn't match the assumption of [asm1].
*)
let mini_mp_tac ?info asm1 asm2 goal =
  let tinfo = mk_info()
  in
  let tac g =
    seq
      [
	implA ~info:tinfo ~a:asm1
	--
	  [
	    (fun g1 -> 
	       let a1_tag = get_one (aformulas tinfo)
	       in 
	       let c_tag = get_one (cformulas tinfo)
	       in 
	       let (_, g_tag) = get_two (subgoals tinfo)
	       in 
		 seq
		   [
		     data_tac (set_info info)
		       ([g_tag], [a1_tag], [], []);
		     basic ~a:asm2 ~c:(ftag c_tag);
		     (fun g2 -> fail ~err:(error "mini_mp_tac") g2)
		   ] g1);
	    skip
	  ]
      ] g
  in 
    tac goal 


(*** 
     * The induction tactic [induct_tac]
***)

(**
   [induct_tac_bindings tyenv scp aterm cterm]: Extract bindings for
   the induction theorem in [aterm] from conclusion term [cterm] in
   type environment [tyenv] and scope [scp].

   [aterm] is in the form [(vars, asm, concl)], obtained by 
   splitting a theorem of the form [! vars : asm => concl]. 

   Returns an updated type environment and a substitution containing
   bindings for the variables in [vars], with which to instantiate the
   induction theorem.

   This function is specialized for use by [induct_tac].
*)
let induct_tac_bindings typenv scp aterm cterm =
  (** Split the induction theorem *)
  let (thm_vars, thm_asm, thm_concl) = aterm
  in
  let is_thm_var = Rewrite.is_free_binder thm_vars
  in 
    (** Split the theorem conclusion (the hypothesis) *)
  let (hyp_vars, hyp_asm, hyp_concl) = dest_qnt_implies thm_concl
  in 
    (** Split the property application *)
  let prop_fun, prop_args = Term.get_fun_args hyp_concl
  in 
    (** Split the target conclusion *)
  let (concl_vars, concl_asm, concl_concl) = dest_qnt_implies cterm
  in 
    (**
       Unify [hyp_asm] (= [pred x .. y]) and [concl_asm] (= [pred a
       .. b]) to get the bindings for the [hyp_vars]
    *)
  let is_hyp_var x = 
    (Rewrite.is_free_binder hyp_vars x)
    || (is_thm_var x)
  in 
  let (typenv1, hyp_var_bindings) = 
    try 
      Unify.unify_fullenv scp typenv (Term.empty_subst())
    	is_hyp_var hyp_asm concl_asm
    with err -> 
      raise 
	(add_error "Can't unify induction theorem with formula" err)
  in 
    (** Eta abstract [concl_concl] w.r.t the constants for [hyp_vars] *)
  let hyp_var_constants = 
    Tactics.extract_consts hyp_vars hyp_var_bindings
  in 
  let thm_var_constants = 
    Tactics.extract_consts thm_vars hyp_var_bindings
  in 
    (**
       [concl_concl_eta = (% a1 .. an: (! v1 .. vn: C))] 
       and [concl_concl_args = [a; .. ; b]]
       where
       [v1 .. vn] are the variables ([f .. g]) that don't appear in
       [pred a .. b]
    *)
  let (concl_concl_eta, concl_conl_args) = 
    (** Get the variables which don't appear in [concl_asm] *)
    let cvar_set = 
      let null_term = Term.mk_free "null" (Gtypes.mk_null())
      in 
      let env1 = 
	List.fold_left
	  (fun e x -> 
	     if (Term.is_bound x)
	     then Term.bind x null_term e
	     else e)
	  (Term.empty_subst()) hyp_var_constants
      in 
	List.fold_left
	  (fun e x -> 
	     if (Term.is_bound x)
	     then Term.bind x null_term e
	     else e)
	  env1 thm_var_constants
    in 
    let cvars = 
      List.filter 
	(fun x -> 
	   Term.member (Term.mk_bound x) cvar_set)
	concl_vars
    in 
    let concl_concl_trm = 
      Lterm.eta_conv hyp_var_constants concl_concl
    in 
      close_lambda_app cvars concl_concl_trm
  in 
  let (ret_typenv, ret_subst) = 
    Unify.unify_fullenv scp typenv1 hyp_var_bindings 
      is_hyp_var prop_fun concl_concl_eta
  in 
    (ret_typenv, ret_subst)


(**
   [induct_tac_solve_rh_tac ?info a c goal]: solve the right sub-goal of an
   induction tactic([t2]).
   
   Formula [a] is of the form [ ! a .. b: A => C ]
   Formula [c] is of the form [ ! a .. b x .. y: A => C]
   or of the form [ ! a .. b: A => (! x .. y : C)] 

   Specialize [c], instantiate [a], 
   implC [c] to get [a1] and [c1]
   mini_mp_tac [a] and [a2] to replace [a] with [a3]
   specialize [c1] again, intantiate [a3]
   basic [c1] and [a3].
   
   Completely solves the goal or fails.
*)
let induct_tac_solve_rh_tac ?info a_lbl c_lbl g =
  let minfo = mk_info()
  in 
  let (c_tag, c_trm) = 
    let (tg, cf) = get_tagged_concl c_lbl g
    in 
      (tg, Formula.term_of cf)
  in 
  let (c_vars, c_lhs, c_rhs) = dest_qnt_implies c_trm
  in 
  let a_trm = Formula.term_of (get_asm a_lbl g)
  in 
  let (a_vars, a_lhs, a_rhs) = dest_qnt_implies a_trm
  in 
  let a_varp = Rewrite.is_free_binder a_vars
  in 
    seq
      [
	(specC ~c:c_lbl
	 // data_tac (set_info (Some minfo)) ([], [], [c_tag], []));
	(fun g1 -> 
	   let env =
	     unify_in_goal a_varp a_lhs c_lhs g1
	   in 
	   let const_list = extract_consts a_vars env
	   in 
	     seq
	       [
		 instA ~info:minfo ~a:a_lbl const_list;
		 implC ~info:minfo ~c:c_lbl
	       ] g1);
	(fun g1 ->
	   let c_tag = get_one (cformulas minfo)
	   in 
	   let a1_tag, a_tag = get_two (aformulas minfo)
	   in 
	     empty_info minfo;
	     set_info (Some minfo) ([], [], [c_tag], []);
	     mini_mp_tac ~info:minfo (ftag a_tag) (ftag a1_tag) g1);
	(fun g1 -> 
	   let c1_tag = get_one (cformulas minfo)
	   in 
	     (specC ~info:minfo ~c:(ftag c1_tag)
	      // data_tac (set_info (Some minfo)) ([], [], [c1_tag], []))
	       g1);
	(fun g1 -> 
	   let c1_tag = get_one (cformulas minfo)
	   in 
	   let c1_lbl = ftag c1_tag
	   in 
	   let c1_trm = Formula.term_of (get_concl c1_lbl g1)
	   in 
	   let a3_tag = get_one (aformulas minfo)
	   in 
	   let a3_lbl = ftag a3_tag
	   in 
	   let a3_trm = Formula.term_of (get_asm a3_lbl g1)
	   in 
	   let (a3_vars, a3_body) = Term.strip_qnt Basic.All a3_trm
	   in 
	   let a3_varp = Rewrite.is_free_binder a3_vars
	   in 
	   let env = unify_in_goal a3_varp a3_body c1_trm g1
	   in 
	   let const_list = extract_consts a3_vars env
	   in 
	     seq
	       [
		 (instA ~a:a3_lbl const_list // skip);
		 basic ~a:a3_lbl ~c:c1_lbl;
		 (fun g2 -> 
		    fail ~err:(error "induct_tac_solve_rh_goal") g2)
	       ] g1)
      ] g
      

let asm_induct_tac ?info alabel clabel goal = 
  let typenv = typenv_of goal
  and scp = scope_of goal
  in 
    (** Get the theorem and conclusion *)
  let (atag, aform) = get_tagged_asm alabel goal
  and (ctag, cform) = get_tagged_concl clabel goal
  in 
    (** Get theorem and conclusion as terms *)
  let aterm = Formula.term_of aform
  and cterm = Formula.term_of cform
  in 
    (** Split the induction theorem *)
  let (thm_vars, thm_asm, thm_concl) = dest_qnt_implies aterm
  in
    (** Get the bindings for the outer-most theorem variables *)
  let (consts_typenv, consts_subst) = 
    induct_tac_bindings typenv scp 
      (thm_vars, thm_asm, thm_concl) cterm
  in 
  let consts_list = Tactics.extract_consts thm_vars consts_subst
  in 
    (** tinfo: information built up by the tactics. *)
  let tinfo = mk_info()
  in 
    (**
       [inst_split_asm_tac]: Instantiate and split the assumption.
       tinfo: aformulas=[a1]; cformulas=[c1]; subgoals = [t1; t2]

       Goals:
       {L 
       [a, asms |- c, concls]  (a = ! .. : a1 => c)
       ----> 
       t1: [asms |- c1, c, concls]; t2: [a1, asms |- c, concls]
       }
    *)
  let inst_split_asm_tac g =
    let minfo = mk_info ()
    in 
      seq
	[
	  (fun g1 -> 
	     let albl = ftag atag
	     in 
	       (instA ~info:minfo ~a:albl consts_list 
		++ (betaA ~info:minfo ~a:albl // skip))
		 g1);
	  (fun g1 ->
	     let atag = get_one (aformulas minfo)
	     in 
	       implA ~info:tinfo ~a:(ftag atag) g1);
	] g
  in
    (** 
	[split_lh_tac c]: Split conclusion [c] of the left-hand
	subgoal. 
    *)
  let split_lh_tac c g = 
    (mini_scatter_tac ?info c // skip) g
  in 
    (** the Main tactic *)
  let main_tac g = 
    seq 
      [
	inst_split_asm_tac 
	--
	  [
	    (** Left-hand sub-goal *)
	    seq 
	      [
		deleteC (ftag ctag);
		(fun g1 -> 
		   let c1_tag = get_one (cformulas tinfo)
		   in 
		     split_lh_tac (ftag c1_tag) g1)
	      ];
	    (** Right-hand sub-goal *)
	    seq
	      [
		(specC ~info:tinfo 
		 // data_tac (set_info (Some tinfo)) ([], [], [ctag], []));
		(fun g1 -> 
		   let a1_tag = get_one (aformulas tinfo)
		   in 
		   let c1_tag = get_one (cformulas tinfo)
		   in 
		     induct_tac_solve_rh_tac 
		       (ftag a1_tag) (ftag c1_tag) g1)
	      ]
	  ]
      ] g
  in 
    main_tac goal
      

(**
   [basic_induct_tac c thm]: Apply induction theorem [thm] to
   conclusion [c].

   See {!Induct.induct_tac}.
*)
let basic_induct_tac ?info c thm goal =
  let tinfo = mk_info()
  in 
  let main_tac c_lbl g =
    seq 
      [
	cut ~info:tinfo thm;
	(fun g1 ->
	   let a_tag = get_one (aformulas tinfo)
	   in 
	     asm_induct_tac ?info (ftag a_tag) c_lbl g1)
      ] g
  in 
    main_tac c goal

(**
   [induct_tac ?c thm]: Apply induction theorem [thm] to conclusion
   [c] (or the first
   conclusion to succeed).

   Theorem [thm] must be in the form:
   {L ! P a .. b : (thm_asm P a .. b) => (thm_concl P a .. b)}
   where
   {L 
   thm_concl P d .. e = (! x .. y : (pred x .. y) => (P d .. e x .. y))
   }   
   The order of the outer-most bound variables is not relevant. 
   
   The conclusion must be in the form:
   {L ! a .. b f .. g: (pred a .. b) => (C a .. b f ..g) }

   info: 
   cformulas=the new conclusions (in arbitray order)
   subgoals=the new sub-goals (in arbitray order)
*)
let induct_tac ?info ?c thm goal =
  let one_tac x g = 
    try basic_induct_tac ?info x thm g
    with err -> raise (add_error "induct_tac: Failed" err)
  in 
  let all_tac targets g = 
    try
      map_first (fun x -> basic_induct_tac ?info x thm) targets goal
    with err -> raise (error "induct_tac: Failed")
  in 
    match c with
	Some(x) -> one_tac x goal
      | _ -> 
	  let targets = 
	    List.map (ftag <+ drop_formula) 
	      (concls_of (sequent goal))
	  in 
	    all_tac targets goal



(*** 
     * The induct-on tactic [induct_on]
***)

(**
   [get_binder qnt n trm]: Get the top-most [qnt] binder with name [n]
   in term [trm]. Raises [Not_found] if the no top-most [qnt] binder
   named [n] can be found.
*)
let get_binder qnt n trm =  
  let qnt= Basic.All in
  let rec get_aux t = 
    match t with
	Basic.Qnt(b, body) -> 
	  if (Basic.binder_kind b = qnt)
	  then 
	    if(Basic.binder_name b = n)
	    then b
	    else get_aux body
	  else raise Not_found
      | Basic.Typed(b, _) -> get_aux b
      | _ -> raise Not_found
  in 
    get_aux trm

(**
   [induct_thm ?thm scp tyenv trm]: Get the induction theorem for
   [trm].  If [?thm] is given, return [thm].  Othewise, get the
   theorem named "TY_induct" where [TY] is the type of [trm].

   e.g. if [trm] has type [bool], the induction theorem is
   [bool_induct] and if [trm] has type [('a, 'b)PAIR], the induction
   theorem is [PAIR_induct].
*)
let induct_thm ?thm scp tyenv trm = 
  match thm with
      (Some x) -> x
    | None ->
	let ty = 
	  let sb = Typing.settype scp ~env:tyenv trm
	  in Gtypes.mgu (Typing.typeof scp ~env:tyenv trm) sb
	in
	let (th, id) = Ident.dest (get_type_name ty)
	in 
	let thm_name = id^"_induct"
	in 
	  try 
	    Commands.thm (Ident.string_of (Ident.mk_long th thm_name))
	  with 
	      _ ->
		try Commands.thm thm_name
		with _ -> 
		  failwith ("Can't find cases theorem "^thm_name)

(**
   [induct_on_bindings tyenv scp nbind aterm cterm]: Extract bindings
   for the induction theorem in [aterm] from conclusion term [cterm]
   in type environment [tyenv] and scope [scp], to induct on term
   [Bound nbind].

   [aterm] is in the form [(vars, asm, concl)], obtained by 
   splitting a theorem of the form [! vars : asm => concl]. 

   [cterm] is in the form [! xs : body]. 

   [nbind] must be a universally quantified binder.

   Tries to unify [body] and [concl], returns an updated type
   environment and a substitution containing bindings for the
   variables in [vars], with which to instantiate the induction
   theorem.

   This function is specialized for use by [induct_on].
*)
let induct_on_bindings typenv scp nbind aterm cterm =
  let nterm = Term.mk_bound nbind
  in 
    (** Split the induction theorem *)
  let (thm_vars, thm_asm, thm_concl) = aterm
  in
  let is_thm_var = Rewrite.is_free_binder thm_vars
  in 
    (** Split the theorem conclusion (the hypothesis) *)
  let (hyp_vars, hyp_body) = Term.strip_qnt Basic.All thm_concl
  in 
    (** Split the property application *)
  let prop_fun, prop_args = Term.get_fun_args hyp_body
  in 
    (** Split the target conclusion *)
  let (concl_vars, concl_body) = Term.strip_qnt Basic.All cterm
  in 
    (** 
	eta abstract the conclusion body, wrt [nbind],
	close the resulting term.
    *)
  let (concl_body_eta, concl_concl_args) = 
    let concl_concl_trm = Lterm.eta_conv [nterm] concl_body
    in 
    let cvars = [ nbind ]
    in
      close_lambda_app cvars concl_concl_trm
  in 
  let (ret_typenv, ret_subst) =
    try 
      Unify.unify_fullenv scp typenv (Term.empty_subst())
	is_thm_var prop_fun concl_body_eta
    with err -> 
      raise (add_error "Can't unify induction theorem with formula" err)
  in 
    (ret_typenv, ret_subst)

(**
   [induct_on_solve_rh_tac ?info a c goal]: solve the right sub-goal of an
   induction tactic([t2]).
   
   Formula [a] is of the form [ ! a .. b: C ]
   Formula [c] is of the form [ ! a .. b x .. y: C]

   Specialize [c], instantiate [a], 
   basic [a] and [c]

   Completely solves the goal or fails.
*)
let induct_on_solve_rh_tac ?info a_lbl c_lbl goal =
  let minfo = mk_info()
  in 
  let (c_tag, c_trm) = 
    let (tg, cf) = get_tagged_concl c_lbl goal
    in 
      (tg, Formula.term_of cf)
  in 
  let (c_vars, c_body) = Term.strip_qnt Basic.All c_trm
  in 
  let a_trm = Formula.term_of (get_asm a_lbl goal)
  in 
  let (a_vars, a_body) = Term.strip_qnt Basic.All a_trm
  in 
  let a_varp = Rewrite.is_free_binder a_vars
  in 
    seq
      [
	(specC ~c:c_lbl
	 // data_tac (set_info (Some minfo)) ([], [], [c_tag], []));
	(fun g1 -> 
	   let env =
	     unify_in_goal a_varp a_body c_body g1
	   in 
	   let const_list = extract_consts a_vars env
	   in 
	     instA ~info:minfo ~a:a_lbl const_list g1);
	(fun g1 ->
	   let c_tag = get_one (cformulas minfo)
	   in 
	   let a_tag = get_one (aformulas minfo)
	   in 
	     empty_info minfo;
	     basic ~a:(ftag a_tag) ~c:(ftag c_tag) g1)
      ] goal

(**
   [induct_on ?thm ?c n]: Apply induction to the first universally
   quantified variable named [n] in conclusion [c] (or the first
   conclusion to succeed). The induction theorem is [thm], if given or
   the theorem [thm "TY_induct"] where [TY] is the name of the type
   constructor of [n].

   Theorem [thm] must be in the form:
   {L ! P a .. b : (thm_asm P a .. b) => (thm_concl P a .. b)}
   where
   {L 
   thm_concl P a .. b= (! x : (P x a .. b))
   }   
   The order of the outer-most bound variables is not relevant. 
   
   The conclusion must be in the form:
   {L ! n f .. g: (C n f ..g) }
   [n] does not need to be the outermost quantifier.
*)

let basic_induct_on ?info ?thm name clabel goal = 
  let typenv = typenv_of goal
  and scp = scope_of goal
  in 
    (** Get the conclusion *)
  let (ctag, cform) = get_tagged_concl clabel goal
  in 
    (** Get conclusion as a term *)
  let cterm = Formula.term_of cform
  in 
    (** 
	Get the top-most binder named [name] in [cterm] 
	Fail if not found.
    *)
  let nbinder = 
    try get_binder Basic.All name cterm
    with _ -> 
      raise (Term.term_error 
	       ("No quantified variable named "^name^" in term")
	       [cterm])
  in 
  let nterm = Term.mk_bound nbinder
  in
    (** Get the theorem *)
  let thm = induct_thm ?thm scp typenv nterm
  in 
  let thm_term = Logic.term_of thm
  in 
    (** Split the induction theorem *)
  let (thm_vars, thm_asm, thm_concl) = dest_qnt_implies thm_term
  in
    (** Get the bindings for the outer-most theorem variables *)
  let (consts_typenv, consts_subst) = 
    induct_on_bindings typenv scp 
      nbinder (thm_vars, thm_asm, thm_concl) cterm
  in 
  let consts_list = Tactics.extract_consts thm_vars consts_subst
  in 
    (** tinfo: information built up by the tactics. *)
  let tinfo = mk_info()
  in 
    (**
       [inst_split_asm_tac]: Instantiate and split the assumption.
       tinfo: aformulas=[a1]; cformulas=[c1]; subgoals = [t1; t2]
       
       Goals:
       {L 
       [a, asms |- c, concls]  (a = ! .. : a1 => c)
       ----> 
       t1: [asms |- c1, c, concls]; t2: [a1, asms |- c, concls]
       }
    *)
  let inst_split_asm_tac atag g =
    let minfo = mk_info ()
    in 
      seq
	[
	  (fun g1 -> 
	     let albl = ftag atag
	     in 
	       (instA ~info:minfo ~a:albl consts_list 
		++ (betaA ~info:minfo ~a:albl // skip))
		 g1);
	  (fun g1 ->
	     let atag = get_one (aformulas minfo)
	     in 
	       implA ~info:tinfo ~a:(ftag atag) g1);
	] g
  in
    (** 
	[split_lh_tac c]: Split conclusion [c] of the left-hand
	subgoal. 
    *)
  let split_lh_tac c g = 
    (mini_scatter_tac ?info c // skip) g
  in 
    (** the Main tactic *)
  let main_tac g = 
    let minfo = mk_info ()
    in 
      seq 
	[
	  cut ~info:minfo thm;
	  (fun g1 -> 
	     let atag = get_one (aformulas minfo)
	     in 
	       ((inst_split_asm_tac atag)
		--
		[
		  (** Left-hand sub-goal *)
		  seq 
		    [
		      deleteC (ftag ctag);
		      (fun g1 -> 
			 let c1_tag = get_one (cformulas tinfo)
			 in 
			   split_lh_tac (ftag c1_tag) g1)
		    ];
		  (** Right-hand sub-goal *)
		  seq
		    [
		      (specC ~info:tinfo 
		       // 
		       data_tac 
		       (set_info (Some tinfo)) 
		       ([], [], [ctag], []));
		      (fun g1 -> 
			 let a1_tag = get_one (aformulas tinfo)
			 in 
			 let c1_tag = get_one (cformulas tinfo)
			 in 
			   induct_on_solve_rh_tac 
			     (ftag a1_tag) (ftag c1_tag) g1)
		    ]
		]) g1)
	] g
  in 
    main_tac goal
      

let induct_on ?info ?thm ?c n goal =
  match c with
      Some(x) -> basic_induct_on ?info ?thm n x goal
    | _ -> 
	let targets =
	  List.map (ftag <+ drop_formula) (concls_of (sequent goal))
	in 
	let main_tac g = 
	  map_first (fun x -> basic_induct_on ?info ?thm n x) targets g
	in 
	  try main_tac goal
	  with _ -> raise (error "induct_on: Failed")

