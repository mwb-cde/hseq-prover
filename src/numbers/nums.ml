(* tests *)

(* 
   conversion of a term involving boolean and number expressions only
   to a boolexpr
*)

let raiseError s l = raise (Term.termError s l)

let num_type = Gtypes.mk_num

type varenvs = (int * (int ref *  Term.term)list)

let new_env () = (0, [])
let var_ctr (n, _) = n
let var_env (_, e) = e
let get_var (n, e) t =
  fst(List.find (fun (_, x) -> Term.equality t x) e)
let get_index (n, e) i =
    try snd(List.nth e (i-1))
    with _ -> raise Not_found
let add_var (n, e) t = 
  try (get_var (n,e) t, (n, e))
  with Not_found -> (n+1, (n+1, (n+1, t)::e))

let mk_plus x = Supinf.Plus x
let mk_max x = Supinf.Max x
let mk_min x = Supinf.Min x

let mk_mult x = 
  match x with
    [a] -> Supinf.Mult (Num.num_of_int 1, a)
  | [Supinf.Val(a); b] -> Supinf.Mult(a, b)
  | [a; Supinf.Val(b)] -> Supinf.Mult(b, a)
  | _ -> raiseError "mult: Badly formed integer expression" []

let mk_minus x = 
  match x with 
    [a] -> Supinf.Mult(Num.minus_num Supinf.one_num, a)
  | [a; b] -> mk_plus [a; Supinf.Mult(Num.minus_num Supinf.one_num, b)]
  | _ -> raiseError "minus: Badly formed integer expression" []

let mk_negate x = 
  match x with
    [a] -> Supinf.Mult (Num.num_of_int (-1), a)
  | _ -> raiseError "negate: Badly formed integer expression" []
let num_thy = "nums"
let plusid = Basic.mklong num_thy "plus"
let minusid = Basic.mklong num_thy "minus"
let multid = Basic.mklong num_thy "mult"
let negid = Basic.mklong num_thy "negate"
let maxid = Basic.mklong num_thy "max"
let minid = Basic.mklong num_thy "min"


let num_fns =
  [ plusid, mk_plus;  
    minusid, mk_minus; 
    multid, mk_mult; 
    negid, mk_negate; 
    maxid, mk_max; 
    minid, mk_min]
    
let is_num_fn x = List.mem_assoc x num_fns
let get_num_fn x = List.assoc x num_fns  

let numterm_to_expr var_env scp t =
  let env = ref var_env
  in 
  let rec conv_aux x =
    match x with
      Term.Var(f, ty) -> 
	if (Gtypes.varp ty)
	then raiseError "Variable type in term" [x]
	else 
	  (Typing.typecheck scp x (num_type);
	   let c, e=add_var (!env) x
	   in env:=e;
	   Supinf.Var(c))
    | Term.Typed(y, ty) -> conv_aux y
    | Term.Qnt(_) -> raiseError "Badly formed integer expression" [x]
    | Term.Const(Basic.Cnum(i)) -> Supinf.Val(i)
    | Term.Const(_) -> raiseError "Badly formed integer expression" [x]
    | Term.App(_, _) ->
	let f, args = Term.dest_fun x
	in 
	let cnstr = 
	  try get_num_fn f
	  with Not_found -> 
	    (raiseError "Badly formed integer expression" [x])
	in 
	cnstr (List.map conv_aux args)
    | Term.Bound(_) ->
	try Supinf.Var(get_var !env x)
	with Not_found -> raiseError "Badly formed integer expression" [x]
  in 
  let nume = conv_aux t
  in 
  (nume, !env)

let mk_num_equals a b = Prop.mk_bexpr(Supinf.Equals, a, b)
let mk_gt a b = Prop.mk_bexpr(Supinf.Gt, a, b)
let mk_geq a b = Prop.mk_bexpr(Supinf.Geq, a, b)
let mk_lt a b = Prop.mk_bexpr(Supinf.Lt, a, b)
let mk_leq a b = Prop.mk_bexpr(Supinf.Leq, a, b)

let gtid = Basic.mklong num_thy "greater"
let geqid = Basic.mklong num_thy "geq"
let ltid = Basic.mklong num_thy "less"
let leqid = Basic.mklong num_thy "leq"

let comp_fns =
  [ gtid, mk_gt; 
    geqid, mk_geq;
    ltid, mk_lt;
    leqid, mk_leq]
    
(*Basic.mklong num_thy "equals", mk_equals;  *)

let is_equals scp ty f a b = 
  if f=Logicterm.equalsid
  then 
    try 
      (Typing.typecheck scp a ty;
       Typing.typecheck scp b ty; 
       true)
    with _ -> false
  else false

let is_comp_fn x = List.mem_assoc x comp_fns
let get_comp_fn scp f a b = 
  try 
    List.assoc f comp_fns  
  with Not_found ->
    (if is_equals scp num_type f a b
    then mk_num_equals
    else raise Not_found)


let compterm_to_compexpr env scp fnid args=
  match args with
    [a; b] -> 
      (try 
	(let cnstr = get_comp_fn scp fnid a b
	in 
      	let (na, env1) = numterm_to_expr env scp a
	in let (nb, nenv) = numterm_to_expr env scp b
	in (cnstr na nb, nenv))
      with Not_found -> 
	raiseError "Unknown comparison function" [Term.mkfun fnid args])
  | _ -> 
      raiseError "Badly formed expression" [Term.mkfun fnid args]


let bool_type = Gtypes.mk_bool

let strip_univs scp bvar_env var_env t =
  let (rqnts, b) = Term.strip_qnt Basic.All t
  in 
  let nenv=ref var_env
  and benv = ref bvar_env
  in 
  let add_qntvar x =
    let nx=Term.Bound(x)
    in 
    (if (Gtypes.varp (Term.get_binder_type nx))
    then ()
    else 
      (try 
	(Typing.typecheck scp nx (num_type);
	 nenv:=snd(add_var !nenv nx))
      with _ ->
	(try
	  (Typing.typecheck scp nx (bool_type);
	   benv:=snd(add_var !benv nx))
	with _ -> raiseError "Badly formed expression" [t])))
  in
  List.iter add_qntvar rqnts;
  (rqnts, b, !benv, !nenv)


let mk_not x =
  match x with
    [a] -> Prop.mk_not a
  | _ -> raiseError "Badly formed expression" []

let mk_and x =
  match x with
    [a; b] -> Prop.mk_and a b
  | _ -> raiseError "Badly formed expression" []

let mk_or x =
  match x with
    [a; b] -> Prop.mk_or a b
  | _ -> raiseError "Badly formed expression" []

let mk_implies x =
  match x with
    [a; b] -> Prop.mk_implies a b
  | _ -> raiseError "Badly formed expression" []

let mk_iff x =
  match x with
    [a; b] -> Prop.mk_iff a b
  | _ -> raiseError "Badly formed expression" []

let mk_bool_equals x =
  match x with
    [a; b] -> Prop.mk_equals a b
  | _ -> raiseError "Badly formed expression" []


let bool_fns =
  [ Logicterm.notid, mk_not;
    Logicterm.andid, mk_and;
    Logicterm.orid, mk_or;
    Logicterm.iffid, mk_iff;
    Logicterm.impliesid, mk_implies]
    
let is_bool_fn x = List.mem_assoc x bool_fns

let get_bool_fn scp f args = 
  try 
    List.assoc f bool_fns  
  with Not_found ->
    (match args with
      [a;b] ->
    	if is_equals scp bool_type f a b
    	then mk_bool_equals
    	else raise Not_found
    | _ -> raise Not_found)


(* bterm_to_boolexpr bvar_env nvar_env scp t
   bvar_env : boolean variables
   nvar_env: integer variables
   scp : scope
   t: term 
*)

let bterm_to_boolexpr bvar_env nvar_env scp t =
  let benv = ref bvar_env
  and nenv =ref nvar_env
  in 
  let rec conv_aux x =
    match x with
      Term.Var(f, ty) -> 
	if (Gtypes.varp ty)
	then raiseError "Variable type in term" [x]
	else 
	  (Typing.typecheck scp x (bool_type);
	   let c, e=add_var (!benv) x
	   in benv:=e;
	   Prop.Var(c))
    | Term.Typed(y, ty) -> conv_aux y
    | Term.Qnt(_) -> raiseError "Badly formed expression" [x]
    | Term.Const(Basic.Cbool(b)) -> 
	if b then Prop.mk_true() else Prop.mk_false()
    | Term.Const(_) -> 
	raiseError "Badly formed expression (Const)" [x]
    | Term.App(_, args) ->
	let f, args = Term.dest_fun x
	in 
	(try 
	  let mker= (get_bool_fn scp f args)
	  in mker (List.map conv_aux args)
	with 
	  Not_found -> 
	    try 
	      (let ne, tnenv = (compterm_to_compexpr !nenv scp f args)
	      in 
	      nenv:=tnenv; ne)
	    with _ -> 
	      (raiseError "Badly formed expression (App)" [x]))
    | Term.Bound(b) ->
	let (q, _, qty) = Term.dest_binding b
	in 
	if (Gtypes.varp qty)
	then raiseError "Variable type in bound term" [x]
	else 
	  match q with
	    Basic.All -> 
		(Typing.typecheck scp x (bool_type);
		 let c, e=add_var (!benv) x
		 in benv:=e;
		 Prop.Var(c))
	  | _ -> raiseError "Badly formed expression (Bound)" [x]
  in (conv_aux t, !benv, !nenv)

(* term_to_boolexpr scp t *)

let term_to_boolexpr scp t =
  let (rqnts, nb, benv, nenv) =
    strip_univs scp (new_env()) (new_env()) t
  in 
  let (e, nbenv, nnenv) = bterm_to_boolexpr benv nenv scp nb
  in (e, nbenv, nnenv, rqnts)

(* expr_to_numterm : conversion from expressions to number terms *)

let expr_to_numterm env t =
  let rec conv_aux e =
    match e with
      Supinf.Val(v) -> Term.mknum(Num.integer_num v)
    | Supinf.Var(i) -> get_index env i
    | Supinf.Plus(args) ->
	Term.mkfun plusid (List.map conv_aux args)
    | Supinf.Mult(v, arg) ->
	Term.mkfun multid 
	  [(Term.mknum(Num.integer_num v)); conv_aux arg]
    | Supinf.Max(args) ->
	Term.mkfun maxid (List.map conv_aux args)
    | Supinf.Min(args) ->
	Term.mkfun minid (List.map conv_aux args)
    | _ -> raiseError "Invalid expression" []
  in conv_aux t

(* compexpr_to_term: conversion expression to comparison *)

let compexpr_to_term env cfn a b =
  match cfn with
    Supinf.Equals -> 
      Term.mkfun 
	Logicterm.equalsid 
	[(expr_to_numterm env a); (expr_to_numterm env b)]
  | Supinf.Leq -> 
      Term.mkfun leqid 
	[(expr_to_numterm env a); (expr_to_numterm env b)]
  | Supinf.Lt -> 
      Term.mkfun ltid
	[(expr_to_numterm env a); (expr_to_numterm env b)]
  | Supinf.Gt -> 
      Term.mkfun gtid
	[(expr_to_numterm env a); (expr_to_numterm env b)]
  | Supinf.Geq -> 
      Term.mkfun geqid
	[(expr_to_numterm env a); (expr_to_numterm env b)]

(* boolexpr_to_bterm *)

let boolexpr_to_bterm benv nenv e =
  let rec conv_aux t =
    match t with
      Prop.Bool(b) -> Term.mkbool b
    | Prop.Not(a) -> Logicterm.mknot (conv_aux a)
    | Prop.And(a, b) -> 
	Logicterm.mkand (conv_aux a) (conv_aux b)
    | Prop.Or(a, b) -> 
	Logicterm.mkor (conv_aux a) (conv_aux b)
    | Prop.Implies(a, b) -> 
	Logicterm.mkimplies (conv_aux a) (conv_aux b)
    | Prop.Iff(a, b) -> 
	Logicterm.mkiff (conv_aux a) (conv_aux b)
    | Prop.Equals(a, b) -> 
	Logicterm.mkequal (conv_aux a) (conv_aux b)
    | Prop.Bexpr(c, a, b) -> 
	compexpr_to_term nenv c a b
    | Prop.Var(i) -> get_index benv i
  in conv_aux e

(* boolexpr_to_term*)

let boolexpr_to_term scp e benv nenv rqnts =
  let rec rebuild x ls=
    match ls with
      [] -> x
    | q::qs -> rebuild (Term.Qnt(q, x)) qs
  in 
  rebuild (boolexpr_to_bterm benv nenv e) rqnts
  

(* simp_term_basic: simplify a term involving only integer functions *)

let simp_term_basic scp t=
  let (e, env) = numterm_to_expr (new_env()) scp t
  in 
  let ne=Supinf.simp e
  in expr_to_numterm env ne

(* simp_term_rewrite: 
   build a rewrite rule for simplifying the given term 
*)

let simp_term_rewrite scp t =
  let nt = simp_term_basic scp t
  in 
  Logicterm.mkequal t nt

(* simp_rewrite: 
   build a rewrite rule for simplifying the given formula
   return the rule as an axiom
*)

let simp_rewrite scp f =
  let t =(Formula.term_of_form f)
  in 
  let nt = simp_term_basic scp t
  in 
  Logic.mk_axiom 
    (Formula.mk_form scp (Logicterm.close_term (Logicterm.mkequal t nt)))
      

(* decide_term_basic: 
   decide whether a term is true, false or undecidable 
*)


let decide_term_basic scp t =
  let (e, _, _, _) = term_to_boolexpr scp t
  in 
  try
    Supinf.decide e
  with Supinf.Possible_solution _ -> 
    raiseError "Numbers: Undecidable term" [t]


(* decide_term scp t: 
   decide whether term [t] is true, false or undecidable 
   return [t=true], [t=false] or raise an exception
*)

let decide_term scp t =
  Logicterm.close_term 
    (Logicterm.mkequal t (Term.mkbool (decide_term_basic scp t)))


(* decide_rewrite scp f: 
   decide whether formula [f] is true, false or undecidable 
   return the rule as an axiom
   or raise an exception
*)

let decide_rewrite scp f =
  let nt = Formula.term_of_form f
  in 
  Logic.mk_axiom (Formula.mk_form scp (decide_term scp nt))

