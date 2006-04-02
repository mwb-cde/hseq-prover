(*-----
 Name: baseScript.ml
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2005
----*)

begin_theory "base" [];;

(** Types *)

(** 
   Grammar:
   type ::=  
           bool           
         | ind            
         | ('a ->'b)      (100, infixr, "FUN")

   Default precedence=10, assoc = non_assoc, fixity=non_fix
*)

let _ = typedef <:def<: ('a, 'b)FUN >> ~pp:(100, infixr, Some("->"));;
let _ = typedef <:def<: bool >> ;;
let _ = typedef <:def<: ind >>;;

(** Terms *)

(** 
   Grammar:
   term ::=  
    ~x                 (205, prefix, Logicterm.negid) {Boollib.PP}
   | not x             (205, prefix, Logicterm.negid) {Boollib.PP}
   | x = y             (200, infixl, Logicterm.equalsid)
   | x => y            (195, infixr, Logicterm.impliesid)
   | x | y             (190, infixr, Logicterm.impliesid)
   | x or y            (190, infixr, Logicterm.impliesid)
   | x & y             (185, infixr, Logicterm.impliesid)
   | x and y           (185, infixr, Logicterm.impliesid)
   | x iff y           (180, infixr, Logicterm.impliesid)

   | f x               (90, nonfix) {Printer}  (Function application)
   | % x: P            (60, nonfix) {Printer, Parser} (Lambda abstraction)
   | ! x: P            (55, nonfix) {Printer, Parser} (Universal quantifier)
   | ? x: P            (55, nonfix) {Printer, Parser} (Existential quantifier)

   | x, y              (10, infixr) {pariLib}  (Pair constructor)
   | ?! x: P           (10, nonfix) {Boollib.PP} (Unique existance)
   | @ x: P            (10, nonfix) {Boollib.PP}  (Choice quantifier)

   Default precedence=10, assoc = non_assoc, fixity=non_fix
*)

(**
   Negation:
   Negation has its own printer [BoolLib.PP.negation_printer] 
*)
let _ = 
  let prec = Boollib.PP.negation_pprec.Printer.prec
  and fixity = Boollib.PP.negation_pprec.Printer.fixity
  in 
  declare
    (Commands.read_unchecked 
       ((Ident.name_of Logicterm.notid)^": bool -> bool"))
    ~pp:(prec, fixity, Some "~");;

let _ = 
  let prec = Boollib.PP.negation_pprec.Printer.prec
  and fixity = Boollib.PP.negation_pprec.Printer.fixity
  in 
  add_term_pp "not" prec fixity (Some "not");;

(** Equality *)
let _ =
declare
(Commands.read_unchecked 
   ((Ident.name_of Logicterm.equalsid)^": 'a -> 'a -> bool"))
  ~pp:(200, infixl, (Some "="));;

(** Conjunction *)
let _ =
declare
(Commands.read_unchecked ((Ident.name_of Logicterm.andid)^":bool->bool->bool"))
  ~pp:(185, infixr, Some "and");; 

let _ = add_term_pp "and" 185 infixr (Some "&");;

(** Disjunction *)
let or_def =
define
(Commands.read_defn ((Ident.name_of Logicterm.orid)
	    ^" x y = (not ((not x) and (not y)))"))
  ~pp:(190, infixr, Some "or");;

let _ = add_term_pp "or" 190 infixr (Some "|");;

(** Implication *)
let implies_def = 
define
(Commands.read_defn ((Ident.name_of Logicterm.impliesid)
	    ^" x y = (not x) or y"))
  ~pp:(195, infixr, Some "=>");;

(** Equivalance *)

let iff_def = 
define
(Commands.read_defn ((Ident.name_of Logicterm.iffid)
	    ^" x y = (x => y) and (y => x)"))
  ~pp:(180, infixn, Some "iff");;


(** Axioms *)

(** False definition *)
let false_def = axiom "false_def" << false = (not true)>>;;

(** Boolean cases *)
let bool_cases_ax = 
  axiom "bool_cases" <<!x: (x=true) or (x=false)>>;;

(** Equality *)

let eq_refl_ax = 
  axiom "eq_refl" <<!x: x=x>>;;

let one_one_def =
  define 
    <:def< one_one f = !x1 x2: ((f x1) = (f x2)) => (x1=x2)>>;;

let onto_def = 
  define <:def< onto f = !y: ?x: y=(f x)>>;;

let infinity_ax = 
  axiom "infinity_ax" <<?(f: ind -> ind): (one_one f) and (onto f)>>;;

let extensionality = 
  axiom "extensionality"  <<!f g: (!x: (f x) = (g x)) => (f = g)>>;;

(** Specification operator (epsilon) *)
let _ = declare <<epsilon: ('a -> bool) -> 'a>>;;

let epsilon_ax = 
  axiom "epsilon_ax" <<!P: (?x: P x) => (P(epsilon P))>>;;

(** Conditional *)
let cond_def = 
  define
    <:def< IF b t f = (epsilon (%z: (b => (z=t)) and ((not b) => (z=f))))>>;;

(** Any value *)
let any_def = define <:def< any = epsilon (%a: true)>>;;

(** Unique existence *)
let exists_unique_def =
  define 
    <:def<
  EXISTS_UNIQUE p = 
  (? x: (p x)) and (! x y : ((p x) and (p y)) => (x = y))
    >>;;

end_theory();;
