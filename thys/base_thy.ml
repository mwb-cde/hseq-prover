new_theory "base";;

new_full_decln "=" "'a -> 'a -> bool" true 6 "=";;
new_full_decln "not" "bool -> bool" false (-1) "not";;
new_full_decln "and" "bool->bool->bool" true 4 "and";; 

new_full_defn "or x y = (not ((not x) and (not y)))" true 3 "or";;
new_full_defn "=> x y = (not x) or y" true 2 "=>";;
new_full_defn "iff  x y = (x => y) and (y => x)" true 1 "iff";;
new_axiom "false_def" "false = (not true)";;

new_axiom "eq_sym" "!x: x=x";;
new_axiom "bool_cases" "!x: (x=true) or (x=false)";;

declare "epsilon: ('a -> bool) -> 'a";;
new_axiom "epsilon_ax" "!P: (?x: P x) => (P(epsilon P))";;

define "if b t f = (epsilon (%z: (b => (z=t)) and ((not b) => (z=f))))";;

prove_theorem "eq_trans" "!x y z: (x=y) and (y=z) => (x=z)"
  [(repeat allI); implI; conjE; (replace (-1) 1); basic];;

(* following taken from hol98: bool/boolScript.sml *)
define 
  "one_one f = !x1 x2: ((f x1) = (f x2)) => (x1=x2)";;

define "onto f = !y: ?x: y=(f x)";;

define 
"Type_Def P rep =
  !x1 x2: (((rep x1) = (rep x2)) => (x1 = x2))
     and (!x: (P x) = (?x1: x=(rep x1)))";;

new_type "ind";;
new_axiom "infinity_ax" "?(f: ind -> ind): (one_one f) and (onto f)";;

new_axiom "extensionality"  "!f g: (!x: (f x) = (g x)) => (f = g)";;

end_theory();;


