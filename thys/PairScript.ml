(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(**
   Product of types.
 *)

let _ = begin_theory "Pair" ["Fun"];;

(* Compile the library and its signature: pairLib.ml *)

let _ = compile [] "pairLib.mli";;
let _ = compile [] "pairLib.ml";;
let _ = add_file true "pairLib.cmo";;

(** [pair_prec] and [pair_fixity] must agree with the values in pairLib.ml. *)
let pair_prec = 10
let pair_fixity = Printkit.infixr

(** {5 Definition and basic properties of pairs} *)

let mk_pair_def =
  define [] (?<% " mk_pair x y = (%a b: (a=x) and (b=y)) ");;

let is_pair_def =
  define [] (?<% " is_pair p = (?x y: p = (mk_pair x y)) ");;

let pair_exists =
  theorem
    "pair_exists" (!% " ? p: is_pair p ")
    [
      unfold "is_pair";
      inst_tac  [ (!% " mk_pair true true"); (!% "true"); (!% "true") ];
      eq_tac
    ];;

let mk_pair_is_pair =
  theorem
    "mk_pair_is_pair" (!% " !x y : is_pair (mk_pair x y) ")
    [
      flatten_tac; unfold "is_pair" ;
      inst_tac [ (!% " _x "); (!% " _y ") ];
      eq_tac
    ];;

let pair_tydef =
  typedef [opt_symbol (pair_prec, infixr, Some("*"));
           opt_thm pair_exists;
           opt_repr "dest_PAIR";
           opt_abs "make_PAIR"]
          (?<: "('a, 'b)PAIR = ('a -> 'b -> bool): is_pair ");;

let pair_def =
  define [opt_symbol(pair_prec, pair_fixity, Some(","))]
    (?<% " pair x y = make_PAIR (mk_pair x y) ") ;;

let fst_def =
  define []
    (?<% " fst p = (epsilon(% x: ?y: p = (pair x y))) ");;

let snd_def =
  define []
    (?<% " snd p = epsilon(% y: ?x: p = (pair x y)) ");;

let mk_pair_eq =
  theorem
    "mk_pair_eq"
    (!% "! a b x y:
         ((mk_pair a b) = (mk_pair x y))
         =
         ((a = x) and (b = y))")
    [flatten_tac ++ equals_tac ++ iffE
     --
       [ (match_asm (!% " X = Y ")
            (once_rewrite_at [thm "function_eq"]))
         ++ inst_tac [ (!% " _a ") ]
         ++ (match_asm (!% " L = R ")
               (once_rewrite_at [thm "function_eq"]))
         ++ inst_tac [ (!% " _b ") ]
         ++ (match_asm (!% " A = B ")
               (once_rewrite_at [thm "eq_sym"]))
         ++ unfold "mk_pair" ++ beta_tac
         ++ replace_tac []
         ++ split_tac ++ eq_tac;
         (* 2 *)
         flatten_tac ++ replace_tac [] ++ eq_tac]
    ];;

let rep_abs_pair=
  theorem
    "rep_abs_pair"
    (!% " !x y: (dest_PAIR(make_PAIR (mk_pair x y))) = (mk_pair x y) ")
    [
      flatten_tac
      ++ cut_thm [] "mk_pair_is_pair"
      ++ inst_tac [ (!% " _x ") ; (!% " _y ") ]
      ++ cut_mp_tac [] (thm "make_PAIR_inverse")
      ++ basic
    ];;

let pair_thm =
  theorem
    "pair_thm"
    (!% " ! x y: (dest_PAIR (pair x y)) = (mk_pair x y) ")
    [
      flatten_tac ++ unfold "pair"
      ++ cut_thm [] "epsilon_ax"
      ++ rewrite_tac [thm "rep_abs_pair"]
      ++ eq_tac
    ];;


let inj_on_make_PAIR =
  theorem
    "inj_on_make_PAIR"
    (!% " inj_on make_PAIR is_pair ")
    [
      cut_thm [] "inj_on_inverse_intro"
      ++ inst_tac [ (!% "make_PAIR"); (!% "is_pair"); (!% "dest_PAIR") ]
      ++ cut_thm [] "make_PAIR_inverse"
      ++ split_tac
      -- [ basic; basic ]
    ];;


(** {5 Properties} *)

let basic_pair_eq =
  theorem
    "basic_pair_eq"
    (!% "! a b x y: ((pair a b) = (pair x y)) = ((a = x) and (b = y))")
    [
      flatten_tac
      ++ equals_tac
      ++ iffE
      --
        [
          (* 1 *)
          unfold "pair"
          ++ cut_thm [] "inj_on_make_PAIR"
          ++ unfold "inj_on"
          ++ inst_tac [ (!% " mk_pair _a _b "); (!% " mk_pair _x _y ") ]
          ++ cut_thm [] "mk_pair_is_pair"
          ++ inst_tac [ (!% " _a ") ; (!% " _b ") ]
          ++ cut_thm [] "mk_pair_is_pair"
          ++ inst_tac [ (!% " _x ") ; (!% " _y ") ]
          ++ (implA -- [conjC ++ basic] )
          ++ (implA -- [basic])
          ++ rewrite_tac [thm "mk_pair_eq"]
          ++ basic;
          (* 2 *)
          flatten_tac ++ replace_tac [] ++ eq_tac
        ]
    ];;


let fst_thm =
  rule
    "fst_thm"
    (!% " ! x y: (fst (pair x y)) = x ")
    [
      flatten_tac ++ unfold "fst"
      ++ cut_thm [] "epsilon_ax"
      ++ inst_tac [ (!% " %a: ?b: (pair _x _y) = (pair a b) ") ]
      ++ beta_tac
      ++ split_tac
      --
        [
          inst_tac [ (!% " _x ") ; (!% " _y ") ] ++ eq_tac;
          flatten_tac
          ++ rewrite_tac [basic_pair_eq]
          ++ flatten_tac
          ++ (replace_rl_tac [])
          ++ eq_tac
        ]
    ];;

let snd_thm =
  rule
    "snd_thm"
    (!% " ! x y: (snd (pair x y)) = y ")
    [
      flatten_tac ++ unfold "snd"
      ++ cut_thm [] "epsilon_ax"
      ++ inst_tac [ (!% " %b: ?a: (pair _x _y) = (pair a b) ") ]
      ++ beta_tac
      ++ split_tac
      --
        [
          inst_tac [ (!% " _y "); (!% " _x ") ] ++ eq_tac;
          flatten_tac
          ++ rewrite_tac [basic_pair_eq]
          ++ flatten_tac
          ++ replace_rl_tac []
          ++ eq_tac
        ]
    ];;

let pair_inj =
  theorem
    "pair_inj"
    (!% " ! p: ?x y: p = (pair x y) ")
    [
      flatten_tac ++ unfold "pair"
      ++ cut [ (!% " _p ") ] (thm "dest_PAIR_mem")
      ++ cut [ (!% " _p ") ] (thm "dest_PAIR_inverse")
      ++ unfold "is_pair"
      ++ flatten_tac
      ++ inst_tac [ (!% " _x ") ; (!% " _y ") ]
      ++ (match_asm (!% " (dest_PAIR x) = Y ")
            (fun l -> replace_rl_tac [l]))
      ++ (match_asm (!% " (make_PAIR (dest_PAIR x)) = Y ")
            (fun l -> replace_tac [l]))
      ++ eq_tac
    ];;

let pair_cases =
  save_thm false "PAIR_cases" pair_inj

let pair_induct =
  theorem "PAIR_induct"
    (!% " !P: (! x y: (P (x, y))) => (!x: P x) ")
    [
      flatten_tac
      ++ cut [] pair_cases
      ++ instA [ (!% " _x ") ]
      ++ specA
      ++ replace_tac [] ++ unify_tac
    ]

let surjective_pairing =
  rule
    "surjective_pairing"
    (!% " !p: (pair (fst p) (snd p)) = p ")
    [
      flatten_tac
      ++ cut [ (!% " _p ") ] pair_inj
      ++ flatten_tac
      ++ replace_tac []
      ++ rewrite_tac [basic_pair_eq; fst_thm; snd_thm]
      ++ (split_tac ++ eq_tac)
    ];;

let pair_eq =
  theorem
    "pair_eq"
    (!% "! p q : (p = q) = (((fst p) = (fst q)) and ((snd p) = (snd q)))")
    [
      flatten_tac
      ++ cut [ (!% " fst _p "); (!% " snd _p ") ;
                     (!% " fst _q "); (!% "snd _q ") ] basic_pair_eq
      ++ rewrite_tac [surjective_pairing]
      ++ basic
    ];;

let _ = end_theory();;

let _ = Display.print_theory (theory "");;
