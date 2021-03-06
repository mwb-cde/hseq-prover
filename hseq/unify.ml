(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Term
open Report

(** Unification of terms. *)

exception Occurs
exception Unify of string

(** Occurs check *)
let rec occurs s t =
  if Term.equals s t
  then true
  else
    match t with
      | App(f, a) -> (occurs s f) || (occurs s a)
      | Qnt(_, b) -> occurs s b
      | _ -> false

let bind_occs s t env =
  if not (occurs t s)
  then Term.Subst.bind s t env
  else raise (term_error "occurs:" [t; s])

(*
 * General Unification
 *)

(** Unify terms w.r.t given type and term contexts *)

let unify_fullenv scp typenv trmenv varp trm1 trm2 =
  let lookup q sbs =
    let r = (Bound q)
    in
    try Term.Subst.find r sbs
    with Not_found -> r
  in
  let eq_binder tyenv b1 b2 =
    let qnt1, _, qty1 = Binder.dest b1
    and qnt2, _, qty2 = Binder.dest b2
    in
    if qnt1 = qnt2
    then
      try (true, Ltype.unify_env scp qty1 qty2 tyenv)
      with _ -> (false, tyenv)
    else (false, tyenv)
  in
  let unify_atom tyenv env qntenv atm1 atm2 =
    let trm1 = Atom(atm1)
    and trm2 = Atom(atm2)
    in
    match (atm1, atm2) with
    | (Id(n1, ty1), Id(n2, ty2)) ->
       if n1 = n2
       then (Ltype.unify_env scp ty1 ty2 tyenv, env)
       else raise (term_error "unify_aux: var" [trm1; trm2])
    | (Free(n1, ty1), Free(n2, ty2)) ->
       if n1 = n2
       then (Ltype.unify_env scp ty1 ty2 tyenv, env)
       else raise (term_error "unify_aux: var" [trm1; trm2])
    | (Meta(q1), Meta(q2)) ->
       (if Binder.equality q1 q2
        then (tyenv, env)
        else raise (term_error"unify_aux: meta" [trm1; trm2]))
    | (Const(c1), Const(c2)) ->
       if c1 = c2
       then (tyenv, env)
       else raise (term_error "unify_aux: const" [trm1; trm2])
    | (_, _) ->
       if Term.equals trm1 trm2
       then (tyenv, env)
       else raise (term_error "unify_aux: default" [trm1; trm2])
  in
  let rec unify_aux tyenv env qntenv t1 t2 =
    let s = Term.Subst.chase_var varp t1 env
    and t = Term.Subst.chase_var varp t2 env
    in
    if varp s
    then
      if equals s t
      then (tyenv, env)
      else (tyenv, bind_occs s t env)
    else
      if varp t
      then (tyenv, bind_occs t s env)
      else
        begin
          match (s, t) with
          | Atom(a1), Atom(a2) -> unify_atom tyenv env qntenv a1 a2
          | (App(f1, a1), App(f2, a2)) ->
             let tyenv1, env1 = unify_aux tyenv env qntenv f1 f2 in
             let tyenv2, env2 = unify_aux tyenv1 env1 qntenv a1 a2
             in
             (tyenv2, env2)
          | (Bound(q1), Bound(q2)) ->
             let nq1 = dest_bound (lookup q1 qntenv)
             in
             if Binder.equality nq1 q2
             then (tyenv, env)
             else raise (term_error "unify_aux: bound" [trm1; trm2])
          | (Qnt(q1, b1), Qnt(q2, b2)) ->
             let qtst, qtyenv = eq_binder tyenv q1 q2
             in
             if qtst
             then
               let nqntenv =
                 Term.Subst.bind (Bound q1) (Bound q2) qntenv
               in
               unify_aux qtyenv env nqntenv b1 b2
             else raise (term_error "unify_aux: qnt" [t1; t2])
          | (_, _) ->
             if Term.equals s t
             then (tyenv, env)
             else raise (term_error "unify_aux: default" [t1; t2])
        end
  in
  unify_aux typenv trmenv (Term.Subst.empty()) trm1 trm2

(**  Unify terms in a given term context. *)
let unify_env typenv scp env varp trm1 trm2 =
  let tye =
    match typenv with
      | Some x -> x
      | _ -> Gtype.Subst.empty()
  in
  let (_, retenv) = unify_fullenv scp tye env varp trm1 trm2
  in
  retenv

(** Unify terms and in scope. *)

(* let unify typenv ?initial scp varp trm1 trm2 = *)
let unify scp varp trm1 trm2 =
(*
  let tye =
    match typenv with
      | Some x -> x
      | _ -> Gtype.Subst.empty()
  and subst =
    match initial with
      | None -> Term.Subst.empty()
      | Some x -> x
  in
 *)
  let tye = Gtype.Subst.empty()
  and subst = Term.Subst.empty()
  in
  let (_, retenv) =
    unify_fullenv scp tye subst varp trm1 trm2
  in
  retenv

let unify_typed tyenv scp varp trm1 trm2 =
  let subst = Term.Subst.empty()
  in
  let (_, retenv) =
    unify_fullenv scp tyenv subst varp trm1 trm2
  in
  retenv

(*** Matching ***)

(** Match terms w.r.t given type and term contexts *)
let matches_full scp typenv trmenv varp trm1 trm2 =
  let lookup q sbs =
    let r = (Bound q)
    in
    try Term.Subst.find r sbs
    with Not_found -> r
  in
  let eq_binder tyenv b1 b2 =
    let (qnt1, _, qty1) = Binder.dest b1
    and (qnt2, _, qty2) = Binder.dest b2
    in
    if qnt1 = qnt2
    then
      try (true, Gtype.matching_env (Scope.types_scope scp) tyenv qty1 qty2)
      with _ -> (false, tyenv)
    else (false, tyenv)
  in
  let match_atom tyenv env qntenv atm1 atm2 =
    let trm1 = Atom(atm1)
    and trm2 = Atom(atm2)
    in
    match (atm1, atm2) with
    | (Id(n1, ty1), Id(n2, ty2)) ->
       if n1 = n2
       then (Gtype.matching_env (Scope.types_scope scp) tyenv ty1 ty2, env)
       else raise (term_error "matches_aux: var" [trm1; trm2])
    | (Free(n1, ty1), Free(n2, ty2)) ->
       if n1 = n2
       then (Gtype.matching_env (Scope.types_scope scp) tyenv ty1 ty2, env)
       else raise (term_error "matches_aux: var" [trm1; trm2])
    | (Meta(q1), Meta(q2)) ->
       if Binder.equality q1 q2
       then (tyenv, env)
       else raise (term_error "matches_aux: meta" [trm1; trm2])
    | (Const(c1), Const(c2)) ->
       if c1 = c2
       then (tyenv, env)
       else raise (term_error "matches_aux: const" [trm1; trm2])
    | (_, _) ->
       if Term.equals trm1 trm2
       then (tyenv, env)
       else raise (term_error "matches_aux: default" [trm1; trm2])
  in
  let rec matches_aux tyenv env qntenv t1 t2 =
    let s = Term.Subst.chase_var varp t1 env
    in
    if varp s
    then
      if equals s t2
      then (tyenv, env)
      else (tyenv, bind_occs s t2 env)
    else
      begin
        match (s, t2) with
        | (Atom(a1), Atom(a2)) -> match_atom tyenv env qntenv a1 a2
        | (Bound(q1), Bound(q2)) ->
           let nq1 = dest_bound (lookup q1 qntenv)
           in
           if Binder.equality nq1 q2
           then (tyenv, env)
           else raise (term_error "matches_aux: bound" [trm1; trm2])
        | (App(f1, a1), App(f2, a2)) ->
           let (tyenv1, env1) = matches_aux tyenv env qntenv f1 f2 in
           let (tyenv2, env2) = matches_aux tyenv1 env1 qntenv a1 a2
           in
           (tyenv2, env2)
        | (Qnt(q1, b1), Qnt(q2, b2)) ->
           let (qtst, qtyenv) = eq_binder tyenv q1 q2
           in
           if qtst
           then
             let nqntenv =
               Term.Subst.bind (Term.mk_bound q1) (Term.mk_bound q2) qntenv
             in
             matches_aux qtyenv env nqntenv b1 b2
           else
             raise (term_error "matches_aux: qnt" [t1; t2])
        | (_, _) ->
           if Term.equals s t2
           then (tyenv, env)
           else raise (term_error "matches_aux: default" [t1; t2])
      end
  in
  matches_aux typenv trmenv (Term.Subst.empty()) trm1 trm2

let matches_rewrite scp typenv env varp trm1 trm2 =
  let (trm1, typenv1) = full_rename typenv trm1
  in
  matches_full scp typenv1 env varp trm1 trm2
