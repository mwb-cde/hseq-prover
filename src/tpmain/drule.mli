(* Useful functions for writing tactics *)

(* Utility functions *)

val ftag : Tag.t -> Logic.label
val fnum : int -> Logic.label

(* formulas of a sequent *)
val asm_forms : Logic.sqnt -> Formula.form list
val concl_forms : Logic.sqnt -> Formula.form list

(** [sequent g]
   get first subgoal of of goal [g].
*)
val sequent : Logic.goal -> Logic.sqnt

(** [scope_of g]
   get scope of first subgoal of of goal [g].
*)
val scope_of : Logic.goal -> Gtypes.scope

(** [get_asm i g]
   get assumption [i] of first sequent of goal [g]
*)
val get_asm: Logic.label -> Logic.goal -> Formula.form

(** [get_cncl i g]
   get conclusion [i] of first sequent of goal [g]
*)
val get_cncl: Logic.label -> Logic.goal -> Formula.form


(** [mk_info()]
   make an empty information record.
*)
val mk_info: unit -> Logic.info

(** [empty_info inf]
   empty information record [inf]
*)
val empty_info: Logic.info -> Logic.info

(** [subgoals info]
   get subgoals of [info].
   equivalent to [(!info).goals]
*)
val subgoals: Logic.info -> Tag.t list

(** [formulas info]
   get formulas of [info].
   equivalent to [(!info).forms]
*)
val formulas: Logic.info -> Tag.t list

(** [constants info]
   get constants of [info].
   equivalent to [(!info).terms]
*)
val constants: Logic.info -> Basic.term list


(** [make_consts l sb]
   make a list of terms suitable for instantiating a quantifier.
   [l] is the list of binders to be instantiated.
   [sb] stores the terms to be used (typically found by substitution)
*)
val make_consts: 
    Basic.binders list -> Term.substitution -> Basic.term list

(**
   [inst_list rule cs id goal]: 
   instantiate formula [id] in [goal] with constants [cs]
   using tactic [rule].
*)
val inst_list : 
    (Basic.term -> Logic.label -> Logic.rule)
    -> Basic.term list -> Logic.label -> Logic.rule

(* Search functions *)

(** [first p l]
   first formula in assumption or conclusion list [l]
   satisfying predicate [p] 

   Search starts at (-1)/1 
*)
val first : ('a -> bool) -> (Tag.t * 'a) list -> Logic.label
val first_asm : (Formula.form -> bool) -> Logic.sqnt -> Logic.label
val first_concl : (Formula.form -> bool) -> Logic.sqnt -> Logic.label

(* first rule which can be applied to an assumption/conclusion *)

val find_rule : 'a -> (('a -> bool) * 'b) list -> 'b

(* Apply functions *)
(* apply test and rules to each/all assumption/conclusion *)
val foreach_asm :
    ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
      Logic.rule

val foreach_asm_except : Tag.t list->
  ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
    Logic.rule

val foreach_conc :
    ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
      Logic.rule

val foreach_formula :
    ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
      Logic.rule

val foreach_conc_except : Tag.t list -> 
  ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
    Logic.rule

val foreach_except:
    Tag.t list -> 
      ((Formula.form -> bool) * (Logic.label -> Logic.rule)) list ->
	Logic.rule

(*
val foreach_in_sq :
    ((Formula.form -> bool) * (int -> Logic.rule)) list ->
      ((Formula.form -> bool) * (int -> Logic.rule)) list ->
	Logic.rule
*)

(* apply rules once *)
val foreach_conc_once :
    (Logic.label -> Logic.rule) -> Logic.rule
val foreach_asm_once :
    (Logic.label -> Logic.rule) -> Logic.rule
val foreach_once :
    (Logic.label -> Logic.rule) -> Logic.rule

(** [foreach_subgoal l r g]
   Apply rule [r] to each subgoal of goal [g] with a label in list [l].
   The rule is applied to the subgoal in the order they appear in [l].
*)
val foreach_subgoal: 
    Tag.t list -> Logic.rule -> Logic.rule

