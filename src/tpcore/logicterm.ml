open Basic
open Gtypes
open Term

let base_thy = "base"

let notid = Basic.mk_long base_thy "not"
let andid = Basic.mk_long base_thy "and"
let orid = Basic.mk_long base_thy "or"
let impliesid = Basic.mk_long base_thy "implies"
let iffid = Basic.mk_long base_thy "iff"
let equalsid = Basic.mk_long base_thy "equals"
let equalssym = "="

let someid = Basic.mk_long base_thy "some"

let mk_not t = mk_fun notid [t]
let mk_and l r = mk_fun andid [l; r]
let mk_or l r = mk_fun orid [l; r]
let mk_implies l r = mk_fun impliesid [l; r]
let mk_iff l r = mk_fun iffid [l; r]
let mk_equality l r = mk_fun equalsid [l; r]

let is_neg t = try(fst(dest_fun t) = notid) with _ -> false
let is_conj t = try(fst(dest_fun t) = andid) with _ -> false
let is_disj t = try( fst(dest_fun t) = orid) with _ -> false
let is_implies t = try (fst(dest_fun t) = impliesid) with _ -> false
let is_equality t = try (fst(dest_fun t) = equalsid) with _ -> false

let dest_equality t = 
  if is_equality t 
  then 
    (match snd(dest_fun t) with
      [l; r] -> (l, r)
    |	_ -> raise (termError "Badly formed equality" [t]))
  else raise (Result.error "Not an equality")

let mk_all tyenv n b= mk_qnt tyenv Basic.All n b
let mk_ex tyenv n b= mk_qnt tyenv Basic.Ex n b
let mk_lam tyenv n b= mk_qnt tyenv Basic.Lambda n b

let mk_all_ty tyenv n ty b= mk_typed_qnt tyenv Basic.All ty n b
let mk_ex_ty tyenv n ty b= mk_typed_qnt tyenv Basic.Ex ty n b
let mk_lam_ty tyenv n ty b= mk_typed_qnt tyenv Basic.Lambda ty n b

let mk_some=Term.mk_var someid

let is_all t = 
  ((is_qnt t) &
   (match (dest_qnt t) with (_, Basic.All, _, _, _) -> true | _ -> false))

let is_exists t = 
  (is_qnt t) &
  (match (dest_qnt t) with (_, Basic.Ex, _, _, _) -> true | _ -> false)

let is_lambda t = 
  ((is_qnt t) &
   (match (dest_qnt t) with (_, Basic.Lambda, _, _, _) -> true | _ -> false))


let alpha_convp_aux scp trmenv s t =
  let rec alpha_aux t1 t2 env =
    match (t1, t2) with
      (Id(n1, ty1), Id(n2, ty2)) -> 
	if (n1=n2) & (Gtypes.matches scp ty1 ty2)
	then env
	else raise (termError "alpha_convp_aux" [t1;t2])
    | (Bound(q1), Bound(q2)) ->
	if equals (chase (fun x->true) t1 env) 
	    (chase (fun x->true) t2 env) 
	then env
	else raise (termError "alpha_convp_aux" [t1;t2])
    | (App(f1, a1), App(f2, a2)) ->
	let env1=alpha_aux f1 f2  env
	in alpha_aux a1 a2 env1
    | (Qnt(qn1, q1, b1), Qnt(qn2, q2, b2)) ->
	(let qty1=Basic.binder_type q1
	and qty2=Basic.binder_type q2
	in 
	if (qn1=qn2) & (Gtypes.matches scp qty1 qty2)
	then 
	  alpha_aux b1 b2 (bind (Bound(q1)) (Bound(q2)) env)
	else raise (termError "alpha_convp_aux" [t1;t2]))
    | (Typed(trm, _), _) -> alpha_aux trm t2 env
    | (_, Typed(trm, _)) -> alpha_aux t1 trm env
    | _ -> 
	(if equals t1 t2 then env
	else raise (termError "alpha_convp_aux" [t1;t2]))
  in alpha_aux s t trmenv
    
let alpha_convp scp t1 t2 =
  let env=empty_subst()
  in 
  try ignore(alpha_convp_aux scp env t1 t2); true
  with _ -> false

let alpha_equals tyenv t1 t2 =
  let env=empty_subst()
  in 
  try ignore(alpha_convp_aux tyenv env t1 t2); true
  with _ -> false

(* beta reduction *)

let beta_convp  =
  function
      App(f, a) -> is_lambda f
    | _ -> false

(* beta reduction: assuming well-typed expression *)
let beta_conv t =
  match t with
    App(f, a) -> 
      if is_lambda f
      then 
	(let (q, _, _, _, b)=dest_qnt f
	in 
	subst_quick (Bound(q)) a  b)
      else raise (termError "Can't apply beta-reduction" [t])
  | _ -> raise (termError "Can't apply beta-reduction" [t])

let beta_reduce t = 
  let rec beta_reduce_aux chng t =
    match t with
      App(f, a) -> 
	(let nf= beta_reduce_aux chng f
	and na = beta_reduce_aux chng a
	in 
	(try (let nt=beta_conv (App(nf, na)) in chng:=true; nt)
	with _ -> (App(nf, na))))
    |	Qnt(k, q, b) -> Qnt(k, q, beta_reduce_aux chng b)
    |	Typed(tr, ty) -> Typed(beta_reduce_aux chng tr, ty)
    |	x -> x
  in let flag = ref false
  in let nt = beta_reduce_aux flag t
  in if !flag then nt else raise (Result.error "No change")

(* eta-abstraction *)
(* abstract x, of type ty, from term t *)
let eta_conv x ty t=
  let name="a" 
  in let q= mk_binding Basic.Lambda name ty 
  in App((Qnt(Basic.Lambda, q, subst_quick x (Bound(q)) t)), x)
    


(* closed terms *)

exception TermCheck of term

let rec is_closed_aux env t =
  match t with
    App(l, r) -> 
      is_closed_aux env l;
      is_closed_aux env r
  | Typed(a, _) -> 
      is_closed_aux env a
  | Qnt(_, q, b) -> 
      let nenv=bind (Bound(q)) (mk_bool true) env
      in 
      is_closed_aux nenv b
  | Bound(q) -> 
    (try ignore(find t env)
    with Not_found -> raise (TermCheck t))
  | _ -> ()

let is_closed_scope env t =
  try is_closed_aux env t; true
  with TermCheck _ -> false

let is_closed t = 
  try is_closed_aux (empty_subst()) t; true
  with TermCheck _ -> false

      
(*
   let close_term t = 
   let qnts = Term.get_free_binders t
   in 
 *)

let close_term t = 
  let memo = empty_table()
  and qnts = ref []
  and mk_univ q = 
    let (_, n, ty) = Basic.dest_binding q
    in Basic.mk_binding Basic.All n ty
  in 
  let rec close_aux x =
    match x with
      Qnt(_, q, b) ->
	ignore(table_add (Bound q) (Bound q) memo);
	close_aux b
    | Bound(q) ->
	(try ignore(table_find x memo)
	with Not_found ->
	  let nq = mk_univ q
	  in 
	  ignore(table_add x (Bound nq) memo);
	  qnts:=nq::!qnts)
    | Typed(tr, _) -> close_aux tr
    | App(f, a) -> close_aux f; close_aux a
    | _ -> ()
  in 
  close_aux t; 
  List.fold_left 
    (fun b q-> Qnt(binder_kind q, q, b)) t !qnts

