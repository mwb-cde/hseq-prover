(* representation and manipulation of well formed formulas *)
(* a term is a formula in a given scope scp if it is correctly typed
   in scp and it is closed (all bound variables occur only in their binding
   terms *)

    type form 
    type saved_form 

    type substitution = Term.substitution

(* conversion between terms and formulas *)
    val is_closed: Term.term -> bool
    val term_of_form : form -> Term.term

(* form_of_term: make a formula from a closed term
   with all types and identifers correct *)
    val form_of_term: Gtypes.scope -> Term.term -> form

(* mk_form: make a formula from an arbitrary.
   resets all types in the term *)

    val mk_form: Gtypes.scope -> Term.term -> form

    val string_form : form -> string

(* check that a given formula is in the scope of an identified theory *)
val in_thy_scope_memo: (string, bool) Lib.substype ->
  Gtypes.scope -> Basic.thy_id -> form -> bool

val in_thy_scope:  Gtypes.scope -> Basic.thy_id -> form -> bool

(* formula destructor *)
val dest_form: form -> Term.term

(* apply a predicate to a term *)
(*
    exception TermCheck of Term.term
*)
    val check_term: (Term.term -> bool) -> Term.term -> unit

(* instantiate a quantified formula with a given term *)
(* succeeds only if the result is a formula *)
    val inst : Gtypes.scope -> form -> Term.term -> form

(* Unification *)
    val unify: Gtypes.scope 
      -> form        (* assumption *)
      -> form       (* conclusion *)
	-> Term.substitution

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
    val get_var_id : form-> Basic.fnident
    val get_var_type : form-> Gtypes.gtype

    val is_app : form -> bool
    val is_const : form -> bool

(*    val dest_num : form -> int *)
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

    val is_equals : form -> bool
    val dest_equals: form -> (form * form)

    val get_binder_name : form -> string
    val get_binder_type: form -> Gtypes.gtype

val dest_qnt : form -> Term.binders * Term.term

    val is_all: form -> bool
    val mk_all: Gtypes.scope -> string->form -> form
    val mk_typed_all: Gtypes.scope -> string -> Gtypes.gtype -> form -> form

    val is_exists: form -> bool
    val is_lambda:  form -> bool

(* typechecking *)

   val typecheck: Gtypes.scope -> form  -> Gtypes.gtype ->form
   val typecheck_env : Gtypes.scope -> Gtypes.substitution 
   -> form -> Gtypes.gtype -> Gtypes.substitution

    val retype: Gtypes.substitution
	-> form -> form


(* equality with pointers *)
    val equality : form -> form -> bool

(* equality under alpha conversion *)
    val alpha_convp : Gtypes.scope -> form -> form -> bool 
(* beta reduction *)
    val beta_convp:  form -> bool
    val beta_conv: Gtypes.scope -> form -> form
    val beta_reduce : Gtypes.scope -> form -> form
(* eta abstraction *)
    val eta_conv: Gtypes.scope -> form -> Gtypes.gtype -> form -> form

(* rewriting *)
    val rewrite : Gtypes.scope -> ?dir:bool -> form list-> form -> form
    val rewrite_simple : Gtypes.scope -> ?dir:bool -> form list-> form -> form

(*
type rulesDB 

val empty_db: Basic.thy_id -> rulesDB
val thy_of_db : rulesDB -> Basic.thy_id
val rescope_db: Gtypes.scope -> Basic.thy_id -> rulesDB -> rulesDB
val add: Gtypes.scope -> bool -> form list -> rulesDB -> rulesDB
*)

val rewrite_net : Gtypes.scope -> Rewrite.rewrite_rules Net.net 
  -> form -> form

(* print a formula in a given PP state *)
val print : Corepp.pp_state -> form -> unit
