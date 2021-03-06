(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Gtype

type binder = {quant: Term.quant; qvar: string; qtyp: Gtype.stype}

let mk_binder q v t = {quant=q; qvar=v; qtyp=t}
let binder_kind q = q.quant
let binder_name q = q.qvar
let binder_type q = q.qtyp

type dbterm =
  | Id of Ident.t * Gtype.stype
  | Free of string * Gtype.stype
  | Qnt of binder * dbterm
  | Bound of int
  | App of dbterm * dbterm
  | Const of Term.Const.t

(*** Conversion functions *)

let of_atom env qnts t =
  match t with
    | Term.Id(n, ty) ->
      let (ty1, env1) = Gtype.to_save_env env ty
      in
      (Id(n, ty1), env1)
    | Term.Free(n, ty) ->
      let (ty1, env1) = Gtype.to_save_env env ty
      in
      (Free(n, ty1), env1)
    | Term.Const(c) -> (Const(c), env)
    | Term.Meta(q) ->
      raise
        (Term.term_error
           "Can't convert meta variables to DB terms"
           [Term.Atom(t)])

let rec of_term_aux env qnts t =
  match t with
  | Term.(Atom(a)) -> of_atom env qnts a
  | Term.Bound(q) ->
     let q_idx = Lib.index (fun x -> (x == q)) qnts
     in
     (Bound(q_idx), env)
  | Term.App(f, a) ->
      let f1, env1 = of_term_aux env qnts f in
      let a1, env2 = of_term_aux env1 qnts a
      in
      (App(f1, a1), env2)
    | Term.Qnt(q, b) ->
      let (tqnt, tqvar, tqtyp) = Term.Binder.dest q
      and (b1, env1) = of_term_aux env (q::qnts) b
      in
      let (ty1, env2) = Gtype.to_save_env env1 tqtyp in
      let q1 = mk_binder tqnt tqvar ty1
      in
      (Qnt(q1, b1), env2)

let of_term t =
  let (t1, _) = of_term_aux [] [] t
  in
  t1

let rec to_term_aux env qnts t =
  match t with
    | Id(n, ty) ->
      let (ty1, env1) = Gtype.from_save_env env ty
      in
      (Term.mk_typed_ident n ty1, env1)
    | Free(n, ty) ->
      let (ty1, env1) = Gtype.from_save_env env ty
      in
      (Term.mk_free n ty1, env1)
    | Const(c) -> (Term.mk_const c, env)
    | Bound(q) ->
      let q_binder = List.nth qnts q
      in
      (Term.mk_bound q_binder, env)
    | App(f, a) ->
      let (f1, env1) = to_term_aux env qnts f in
      let (a1, env2) = to_term_aux env1 qnts a
      in
      (Term.mk_app f1 a1, env2)
    | Qnt(q, b) ->
      let (ty1, env1) = Gtype.from_save_env env q.qtyp in
      let q1 =
        Term.Binder.make (binder_kind q) (binder_name q) ty1
      in
      let (b1, env2) = to_term_aux env1 (q1::qnts) b
      in
      (Term.mk_qnt q1 b1, env2)

let to_term t =
  let (t1, _) = to_term_aux [] [] t
  in
  t1
