(*-----
 Name: formula.mli
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2005
----*)

(* representation and manipulation of well formed formulas *)
(* a term is a formula in a given scope scp if it is correctly typed
   in scp and it is closed (all bound variables occur only in their binding
   terms *)

type form 
type saved_form 

type substitution = Term.substitution

(* conversion between terms and formulas *)
(*
   is_closed ts f:
   true iff all bound variables in [f] are in the body 
   of a quantifier or occur in ts
 *)
val is_closed: Basic.term list -> Basic.term -> bool
val term_of_form : form -> Basic.term

(*
   form_of_term: make a formula from a closed term
   with all types and identifers correct 
*)
(*
val form_of_term: Gtypes.scope -> Basic.term -> form
*)

(*
 mk_form: make a formula from an arbitrary term.
   resets all types in the term 
*)
(*
val mk_form: Gtypes.scope -> Basic.term -> form
*)

(*
   [close_term scp trm]: close term [trm] in scope [scp].
   
   1. Replace each free variable [Var(x, _)] in [trm] with the term
   associated with [x] in scope [scp]. Fail if [x] is not in scope [scp].

   2. Fail if any bound variable in [trm] occurs outside its binding term.
*)
val close_term: Gtypes.scope -> Basic.term -> Basic.term

(*
   [make ?env scp trm]: make a formula from term [trm] in scope [scp].
   
   1. Replace each free variable [Var(x, _)] in [trm] with the term
   associated with [x] in scope [scp]. Fail if [x] is not in scope [scp].
   2. Fail if any bound variable in [trm] occurs outside its binding term.
   4. Fail if any identifier is not in scope.
   4. Typecheck resulting term, to set correct types. If [?env] is
      given, pass it to the typechecker.
   5. return resulting formula built from resulting term.  If [?env]
      is given, set it to the type substitution obtained from typechecking.

   [dest frm]: Formula destructor.
*)
val make: ?env:Gtypes.substitution ref -> Gtypes.scope -> Basic.term -> form
val dest: form -> Basic.term

val string_form : form -> string

(* check that a given formula is in the scope of an identified theory *)
val in_thy_scope_memo: 
    (string, bool) Lib.substype ->
      Gtypes.scope -> Basic.thy_id -> form -> bool
val in_thy_scope:  Gtypes.scope -> Basic.thy_id -> form -> bool

(* formula destructor *)
(*
val dest_form: form -> Basic.term
*)

(* apply a predicate to a term *)
(*
   exception TermCheck of Basic.term
*)
val check_term: (Basic.term -> bool) -> Basic.term -> unit

(* instantiate a quantified formula with a given term *)
(* succeeds only if the result is a formula *)
val inst : Gtypes.scope -> Basic.term list -> form -> Basic.term -> form
val inst_env : Gtypes.scope -> Basic.term list -> Gtypes.substitution
  -> form -> Basic.term -> (form* Gtypes.substitution)

(* Unification *)
val unify: Gtypes.scope 
  -> form        (* assumption *)
    -> form       (* conclusion *)
      -> Term.substitution

val unify_env: Gtypes.scope 
  -> Gtypes.substitution (* type environment *)
    -> form        (* assumption *)
      -> form       (* conclusion *)
	-> (Gtypes.substitution * Term.substitution)

(* (basiclly term) substitution *)
val empty_subst: unit -> substitution
val subst : Gtypes.scope -> substitution -> form -> form

(* rename bound variables *)
val rename: form -> form

(* conversions for disk storage *)
val to_save: form -> saved_form
val from_save : saved_form -> form

(* recognisers/destructors and some constructors *)

val is_fun: form -> bool
val is_var : form-> bool
val get_var_id : form-> Basic.ident
val get_var_type : form-> Basic.gtype

val is_app : form -> bool
val is_const : form -> bool

val dest_num : form -> Num.num
val dest_bool : form -> bool

val is_true :form -> bool
val is_false :form -> bool
val is_neg : form -> bool
val dest_neg: form -> form list

val is_conj : form -> bool

val dest_conj: form -> form list


val is_disj : form -> bool
val dest_disj: form -> form list

val is_implies : form -> bool
val dest_implies: form -> form list

val is_equality : form -> bool
val dest_equality: form -> (form * form)

val get_binder_name : form -> string
val get_binder_type: form -> Basic.gtype

val dest_qnt : form -> Basic.binders * Basic.term

val is_all: form -> bool
val mk_all: Gtypes.scope -> string->form -> form
val mk_typed_all: Gtypes.scope -> string -> Basic.gtype -> form -> form

val is_exists: form -> bool
val is_lambda:  form -> bool

(* typechecking *)

val typecheck: Gtypes.scope -> form  -> Basic.gtype ->form
val typecheck_env : Gtypes.scope -> Gtypes.substitution 
  -> form -> Basic.gtype -> Gtypes.substitution

val retype: Gtypes.substitution
  -> form -> form


(* equality with pointers *)
val equals : form -> form -> bool

(* equality under alpha conversion *)

(* alpha_equals: equality under alpha conversion
   (renaming of alpha_convp)
 *)
val alpha_equals_match : 
    Gtypes.scope -> Gtypes.substitution 
      -> form -> form -> Gtypes.substitution
val alpha_equals : Gtypes.scope -> form -> form -> bool 

(* beta reduction *)
val beta_convp:  form -> bool
val beta_conv: Gtypes.scope -> form -> form
val beta_reduce : Gtypes.scope -> form -> form
(* eta abstraction *)
val eta_conv: Gtypes.scope -> form -> Basic.gtype -> form -> form

(* rewriting *)
val default_rr_control : Rewrite.control

val rewrite : 
Gtypes.scope -> ?ctrl:Rewrite.control
  -> Rewrite.rule list-> form -> form

(* rewriting with a given type environment *)
val rewrite_env : 
    Gtypes.scope -> ?ctrl:Rewrite.control
      -> Gtypes.substitution 
	-> Rewrite.rule list-> form -> (form * Gtypes.substitution)
(*
   type rulesDB 

   val empty_db: Basic.thy_id -> rulesDB
   val thy_of_db : rulesDB -> Basic.thy_id
   val rescope_db: Gtypes.scope -> Basic.thy_id -> rulesDB -> rulesDB
   val add: Gtypes.scope -> bool -> form list -> rulesDB -> rulesDB
 *)

(*
val rewrite_net : Gtypes.scope -> Rewrite.rewrite_rules Net.net 
  -> form -> form

val rewrite_net_env : 
    Gtypes.scope -> Gtypes.substitution 
      -> Rewrite.rewrite_rules Net.net 
	-> form -> (form * Gtypes.substitution)
*)

(* print a formula in a given PP state *)
val print : Printer.ppinfo -> form -> unit 
