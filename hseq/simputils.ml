(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Utility functions for the simplifier *)

open Term
open Lterm

(** [is_variable qnts x]: Test for variables (universal quantifiers)
    in an entry
*)
let is_variable qnts x= Rewrite.is_free_binder qnts x

(** [equal_upto_vars varp x y]: Terms [x] and [y] are equal upto the
    position of the terms for which [varp] is true (which are
    considered to be variables.)

    This is used to determine whether a rewrite- or simp-rule could
    lead to an infinite loop (e.g. |- (x and y) = (y and x) ).
*)
let rec equal_upto_vars varp x y =
  if (varp x) && (varp y)
  then true
  else
    begin
      match (x, y) with
      | (Term.App(f1, arg1), Term.App(f2, arg2))->
         (equal_upto_vars varp f1 f2) && (equal_upto_vars varp arg1 arg2)
      | (Term.Qnt(qn1, b1), Term.Qnt(qn2, b2)) ->
         (qn1 == qn2) && (equal_upto_vars varp b1 b2)
      | _ -> Term.equals x y
    end

(** [find_variables is_var vars trm]: find all subterms [t] of [trm]
    s.t. [(is_var t)] is true, add [t] to [vars] then return [vars]
*)
let find_variables is_var vars trm =
  let rec find_aux env t =
    match t with
      | Term.Bound(q) ->
        if is_var q
        then
          if Term.Subst.member t env
          then env
          else Term.Subst.bind t t env
        else env
      | Term.Qnt(_, b) -> find_aux env b
      | Term.App(f, a) ->
        let nv = find_aux env f
        in
        find_aux nv a
      | _ -> env
  in find_aux vars trm

(** [check_variables is_var vars trm]: Check that all subterms [t] of
    [trm] s.t. [is_var t] are in [vars].  *)
let check_variables is_var vars trm =
  let rec check_aux t =
    match t with
      | Term.Bound(q) ->
        if is_var q
        then Term.Subst.member t vars
        else true
      | Term.Qnt(_, b) -> check_aux b
      | Term.App(f, a) -> check_aux f && check_aux a
      | _ -> true
  in check_aux trm

(** [strip_qnt_cond trm]: split rule [trm] into variable binders,
    condition, equality rules are of the form: a=>c c
*)
let strip_qnt_cond t =
  (* get leading quantifiers *)
  let (qs, t1) = Term.strip_qnt Term.All t in
  if Lterm.is_implies t1  (* deal with conditional equalities *)
  then
    let (_, a, c) = Term.dest_binop t1
    in
    (qs, Some a, c)
  else (qs, None, t1)

(** [apply_merge_list f lst]: Apply [f] to each element [x] in [lst]
    and repeat for the resulting list. Concatenate the list of lists
    that result. If [f x] fails, keep [x] as the result.
*)
let apply_merge_list f ls =
  let rec app_aux ys result =
    match ys with
      | [] -> result
      | x::xs ->
        begin
          try
            let nlst = f x in
            let nresult = app_aux nlst result
            in
            app_aux xs nresult
          with _ -> app_aux xs (x::result)
        end
  in
  app_aux ls []

(** [fresh_thm th]: Test whether theorem [th] is fresh in the global
    scope.
*)
let fresh_thm scp th = Logic.is_fresh scp th

(** [simp_beta_conv scp t]: Apply {!Logic.Conv.beta_conv} to [t] if
    [t] is of the form << (% x: F) a >>.  Raise [Failure] if [t] is not
    an application.
*)
let simp_beta_conv scp t =
  match t with
    | Term.App(Term.Qnt(q, _), a) ->
      if Term.Binder.kind_of q = Term.Lambda
      then Logic.Conv.beta_conv scp t
      else failwith "simp_beta_conv"
    | _ -> failwith "simp_beta_conv"
