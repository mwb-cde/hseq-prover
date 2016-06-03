(*----
  Name: typing.ml
  Copyright M Wahab 2005-2014
  Author: M Wahab  <mwb.cde@gmail.com>

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

open Basic
open Term

(*** Type Errors ***)

class typingError s t ty expty =
object (self)
  inherit Report.error s
  val trm = (t: term)
  val typs = ((expty, ty): (Basic.gtype * Basic.gtype))
  method get_term() = trm
  method get_types() = typs
  method print st = 
    Format.printf "@[";
    Format.printf "%s@ " (self#msg());
    Format.printf "expected type@ ";
    Gtypes.print st (fst typs);
    Format.printf "@ got type@ ";
    Gtypes.print st (snd typs);
    Format.printf "@ in term@ ";
    Term.print st trm;
    Format.printf "@]"
end

let typing_error s tr expty ty = 
  Report.mk_error((new typingError s tr expty ty):> Report.error)
let add_typing_error s tr expty ty es =
  Report.add_error (typing_error s tr expty ty) es

(*
 * Typing a term
 *)

let typeof_env scp (inf, typenv) trm =
  let rec typeof_aux t tyenv =
    let (ctr, env) = tyenv 
    in
    match t with
      | Id(n, ty) -> (Gtypes.mgu ty env, tyenv)
      | Free(n, ty) -> (Gtypes.mgu ty env, tyenv)
      | Meta(q) -> (Gtypes.mgu (get_binder_type t) env, tyenv)
      | Bound(q) -> (Gtypes.mgu (get_binder_type t) env, tyenv)
      | Const(c) -> (Lterm.typeof_cnst c, tyenv)
      | Qnt(q, b) -> 
        begin
	  match Basic.binder_kind q with
	    | Basic.Lambda -> 
	      let (btyp, (ctr1, benv)) = typeof_aux b (ctr, env)
	      in 
	      (Lterm.mk_fun_ty (Term.get_binder_type t) btyp, (ctr1, benv))
	    | _ -> (Lterm.mk_bool_ty(), (ctr, env))
        end
      | App(f, a) -> 
	let fty, (ctr1, fenv) = typeof_aux f (ctr, env) in
        let aty, (ctr2, aenv) = typeof_aux a (ctr1, fenv)
        in
        let (ctr3, retty) = Gtypes.mk_typevar ctr2 in
	let nty = Lterm.mk_fun_ty aty retty in 
	let renv = Gtypes.unify_env scp fty nty aenv
	in 
	(Gtypes.mgu retty renv, (ctr3, renv))
  in 
  typeof_aux trm (inf, typenv)

let typeof scp ?env t = 
  let tenv = 
    match env with
      | None -> Gtypes.empty_subst()
      | Some x -> x
  in 
  let (ty, _) = typeof_env scp (0, tenv) t
  in ty
  
(*
 * Type-checking 
 *)
  
(** Two flavours: 

    [settype] looks up the type of each identifier in the scope before
    type checking.

    [typecheck] assumes that identifiers have already been assigned
    their correct types.
*)

(*** typecheck based type checking ****)

let typecheck_aux scp (inf, cache) typenv exty et =
  let test_type scope cache env trm ty expty =
    (* check given type *) 
    Gtypes.quick_well_defined scope cache ty;
    (* unify with expected type *)
    try Gtypes.unify_env scope ty expty env 
    with err -> 
      raise (add_typing_error "Typechecking: " trm
	       (Gtypes.mgu expty env) (Gtypes.mgu ty env) err)
  in 
  let rec type_aux expty trm tyenv =
    let (ctr, env) = tyenv
    in
    match trm with
      | Id(n, ty) -> (ctr, test_type scp cache env trm ty expty)
      | Free(n, ty) -> (ctr, test_type scp cache env trm ty expty)
      | Meta(q) -> 
	let ty = get_binder_type trm
	in
        (ctr, test_type scp cache env trm ty expty)
      | Bound(q) -> 
	let ty = get_binder_type trm
	in
        (ctr, test_type scp cache env trm ty expty)
      | Const(c) -> 
        let ty = Lterm.typeof_cnst c
	in
        (ctr, test_type scp cache env trm ty expty)
      | App(f, a) -> 
        (* Make an argument type *)
	let (ctr1, aty) = Gtypes.mk_plain_typevar ctr in 
        (* Check argument type *)
        let (ctr2, aenv) =
	  try type_aux aty a (ctr1, env)
	  with err -> Term.add_term_error "Typechecking: " [trm] err
        in
        (* Expect a function type *)
	let fty = Lterm.mk_fun_ty aty expty in 
        (* Check function type *)
	let (ctr3, fenv) =
	  try type_aux fty f (ctr2, aenv) 
	  with err -> Term.add_term_error "Typechecking:" [trm] err
	in 
        (ctr3, fenv)
      | Qnt(q, b) ->
        begin
	  match Basic.binder_kind q with
	    | Basic.Lambda -> 
	      let (ctr1, rty) = Gtypes.mk_plain_typevar ctr     (* range *)
	      and fty = Term.get_binder_type trm  (* domain *)
	      in
	      let bty = Lterm.mk_fun_ty fty rty   (* type of term *)
	      in 
              (* check domain *)
	      Gtypes.quick_well_defined scp cache fty; 
	      let env1= 
	        try Gtypes.unify_env scp bty expty env
	        with err -> 
		  raise (add_typing_error "Typechecking: " trm 
		           (Gtypes.mgu expty env) (Gtypes.mgu bty env) err)
	      in 
              begin
	        try type_aux rty b (ctr1, env1)
	        with err -> Term.add_term_error "Typecheck: " [trm] err
              end
	    | _ -> 
	      let (ctr1, env1) = type_aux (Lterm.mk_bool_ty()) b tyenv in 
              let env2 = 
	        try Gtypes.unify_env scp (Lterm.mk_bool_ty()) expty env1
	        with err -> 
	          raise (add_typing_error "Typechecking: " trm 
		           (Gtypes.mgu expty env) 
		           (Gtypes.mgu (Lterm.mk_bool_ty()) env) err)
              in
              (ctr1, env2)
        end
  in 
  try type_aux exty et (inf, typenv)
  with err -> 
    raise (Term.add_term_error "Typecheck: badly typed" [et] err)

let typecheck_top scp env t expty = 
  let inf = (0, Lib.empty_env()) in 
  let (_, env1) = typecheck_aux scp inf env expty t
  in 
  env1

let typecheck scp t expty =
  ignore(typecheck_top scp (Gtypes.empty_subst()) t expty)

(*** Settype based type checking ****)

type debugType = TermType of (string * Basic.term * (Basic.gtype list))
let debug_flag = ref false
let debug_list = ref []

let init_list list = list := []
let add_to_list t list = 
  if (!debug_flag)
  then list := (t:: (!list))
  else ()

let rec test_type scp cache env trm ty expty = 
  Gtypes.quick_well_defined scp cache ty;
  try Gtypes.unify_env scp ty expty env
  with err -> 
    raise (add_typing_error "Typechecking: " trm 
	     (Gtypes.mgu expty env) (Gtypes.mgu ty env) err)
and settype_aux scp (inf, cache, appfn) expty t tyenv =
  let (ctr, env) = tyenv in
  match t with
    | Id(n, ty) -> 
      Gtypes.quick_well_defined scp cache ty; 
      let env1 =
        begin
          match Lib.try_app (Scope.type_of scp) n with
            | None -> appfn env expty t
            | Some(nt) ->
              begin
 	        try Gtypes.unify_env scp nt ty env
	        with err -> 
	          raise (add_typing_error "Typechecking: " t 
		           (Gtypes.mgu expty env) 
                           (Gtypes.mgu ty env) err)
              end
        end
      in
      let env2 = Gtypes.unify_env scp ty expty env1 in
      add_to_list (TermType("Id", t, [Gtypes.mgu expty env2])) debug_list;
      (ctr, env2)
    | Free(n, ty) ->
      let env1 = 
	Gtypes.quick_well_defined scp cache ty;
	try Gtypes.unify_env scp ty expty env
	with err -> 
	  raise (add_typing_error "Typechecking: " t 
		   (Gtypes.mgu expty env) (Gtypes.mgu ty env) err)
      in
      add_to_list (TermType("Free", t, [Gtypes.mgu expty env1])) debug_list;
      (ctr, env1)
    | Meta(q) -> 
      let ty = get_binder_type t in
      let env1 = test_type scp cache env t ty expty
      in
      add_to_list (TermType("Meta", t, [Gtypes.mgu expty env1])) debug_list;
      (ctr, env1)
    | Bound(q) -> 
      let ty = get_binder_type t in
      let env1 = test_type scp cache env t ty expty
      in
      add_to_list (TermType("Bound", t, [Gtypes.mgu expty env1])) debug_list;
      (ctr, env1)
    | Const(c) -> 
      let ty = Lterm.typeof_cnst c in
      let env1 = test_type scp cache env t ty expty
      in
      add_to_list (TermType("Const", t, [Gtypes.mgu expty env1])) debug_list;
      (ctr, env1)
    | App(f, arg) -> 
      (* Make an argument type. *)
      let (ctr1, arg_ty) = Gtypes.mk_plain_typevar ctr in
      (* Check argument type *)
      let (ctr2, env2) = 
	try settype_aux scp (inf, cache, appfn) arg_ty arg (ctr1, env)
	with err -> 
	  raise (Term.add_term_error "Typechecking: " [t] err)
      in
      (* Check function type *)
      let fty = Lterm.mk_fun_ty arg_ty expty in 
      let (ctr3, env3) =
	try settype_aux scp (inf, cache, appfn) fty f (ctr2, env2)
	with err -> 
	  raise (Term.add_term_error "Typechecking failure " [t] err)
      in 
      add_to_list (TermType("App", t, [Gtypes.mgu expty env3])) debug_list;
      (ctr3, env3)
    | Qnt(q, b) ->
      begin
	match Basic.binder_kind q with
          | Basic.Lambda -> 
	    let (ctr1, rty) = Gtypes.mk_plain_typevar ctr
	    and fty = Term.get_binder_type t in
	    let bty = Lterm.mk_fun_ty fty rty 
	    in 
            Gtypes.quick_well_defined scp cache fty;
	    let env1= 
	      try Gtypes.unify_env scp bty expty env
	      with err -> 
		raise (add_typing_error "Typechecking: " t
			 (Gtypes.mgu expty env) (Gtypes.mgu bty env) err)
	    in 
            let (ctr2, env2) = 
	      try settype_aux scp (inf, cache, appfn) rty b (ctr1, env1)
	      with err -> 
	        raise (Term.add_term_error "Typechecking: " [t] err)
            in
            add_to_list 
              (TermType("Lambda", t, [Gtypes.mgu expty env2])) debug_list;
            (ctr2, env2)
	  | _ -> 
	    let (ctr1, env1) =
	      try settype_aux scp (inf, cache, appfn)
                    (Lterm.mk_bool_ty()) b (ctr, env)
	      with err -> 
		raise (Term.add_term_error "Typechecking: " [t] err)
	    in 
            let env2 = 
	      try Gtypes.unify_env scp (Lterm.mk_bool_ty()) expty env1
	      with err -> 
	        raise (add_typing_error "Typechecking: " t
		         (Gtypes.mgu expty env) 
		         (Lterm.mk_bool_ty()) err)
            in
            add_to_list 
              (TermType("Qnt", t, [Gtypes.mgu expty env2])) debug_list;
            (ctr1, env2)
      end
and settype_top scp (inf, cache) errfn typenv exty et =
  init_list debug_list;
  settype_aux scp (inf, cache, errfn) exty et (inf, typenv)

let settype scp ?env t =
  let inf = 0
  and cache = Lib.empty_env()
  and f env expty trm = 
    match trm with
      | Id(n, ty) -> Gtypes.unify_env scp ty expty env
      | _ -> env
  in 
  let tyenv =
    match env with 
      | None -> Gtypes.empty_subst()
      | Some(x) -> x
  in 
  let (inf1, tyvar) = Gtypes.mk_plain_typevar inf in
  let (_, env1) = settype_top scp (inf1, cache) f tyenv tyvar t
  in 
  env1

(** 
    [typecheck_env tyenv scp t ty]: Check, w.r.t type context [tyenv],
    that term [t] has type [ty] in scope [scp]. Type variables in [t]
    take their assigned value from [tyenv], if they have one.

    The type of an identifier [Id(n, ty)] is looked for in scope [scp].
    The given type [ty] is discarded.
*) 
let typecheck_env scp env t expty =
  let inf = (0, Lib.empty_env())
  and f = (fun _ _ t -> 
    match t with 
      | Basic.Id(n, ty) ->
	raise (Term.term_error ("Typecheck: unknown identifier ") [t])
      | _ -> 
	raise (Term.term_error "Typecheck: unknown error" [t] ))
  in 
  let (_, env1) = settype_top scp inf f env expty t
  in
  env1

(*
 * Well-definedness of types.
 *)

let rec check_types scp t =
  match t with
    | Id(_, ty) -> Gtypes.well_defined scp [] ty
    | App(f, a) -> check_types scp f; check_types scp a
    | Qnt(q, b) ->
      Gtypes.well_defined scp [] (Term.get_binder_type t);
      check_types scp b
    | _ -> ()
