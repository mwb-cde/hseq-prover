(* 
   Term Nets

   Store data indexed by a term.  

   Lookup is by inexact matching of a given term against those
   indexing the data. Resulting list of terms-data pair would then be
   subject to more exact mactching (such as unification) to select
   required data.

   Used to cut the number of terms that need to be
   considered by (more expensive) exact matching.
 *) 

type label = 
    Var 
  | App
  | Bound of Basic.quant_ty
  | Quant of Basic.quant_ty
  | Const of Basic.const_ty 
  | Cname of Basic.fnident

(* 'a net : Node data, rest of net, Var tagged net (if any) *)

type 'a net =  
    Node of ('a list                  (* data held at this node *)
	       * (label * 'a net) list  (* nets tagged by labels *)
	       * ('a net) option )           (* net tagged by Var *)


(* Empty nets *)
val empty: unit -> 'a net
val is_empty: 'a net -> bool


(* 
   label varp t:
   Return the label for term t. Not used, term_to_label is better.
 *)

val label: (Term.term -> bool) -> Term.term -> label

(*
   term_to_label varp t:

   Return the label for term t together with the remainder
   of the the term as a list of terms.

   varp determines which terms are treated as variables.

   rst is the list of terms built up by repeated calls
   to term_to_label. Initially, it should be [].

   examples:
   
   ?y: ! x: (x or z) and y  (with variable z)
   -->
   [Qnt(?); Qnt(!); App; App; Bound(!); Var; Bound(?)]

   ?y: ! x: (x or z) and y  (with no variables,  z is free)
   -->
   [Qnt(?); Qnt(!); App; App; Bound(!); Cname(z); Bound(?)]
 *)

val term_to_label : 
    (Term.term -> bool) -> Term.term -> Term.term list 
      -> (label * Term.term list)


(* update f net trm:

   Apply function f to the subnet of net identified by trm to update
   the subnet. Propagate the changes through the net. 
   If applying function f results in an empty subnet, than remove
   these subnets.
 *)
val update: 
    ('a net -> 'a net) -> (Term.term -> bool) 
      -> 'a net -> Term.term -> 'a net


(* Functions to use Nets *)

(* lookup net t:

   Return the list of items indexed by terms matching term t.
   Orderd with the best matches first. 

   Term t1 is a better match than term t2 if
   variables in t1 occur deeper in its term structure than
   those for t2.

   e.g. with variable x and t=(f 1 2), t1=(f x y) is a better match
   than t2=(x 1 2) because x occurs deeper in t1 than in t2. (t1 is
   likely to be rejected by exact matching more quickly than t2 would
   be.)

 *)
	  
val lookup: 'a net -> Term.term -> 'a list

(* add varp net t r:

   Add term r, indexed by term t with variables identified by varp
   to net.

   Replaces but doesn't remove previous bindings of t
 *)
val add: 
    (Term.term -> bool) -> (Term.term * 'a) net 
      -> Term.term -> 'a
	-> (Term.term * 'a) net

(* delete varp net t:

   Remove term bound to t in net. Fails silently if t is not found.

   Needs the same varp as used to add the term to the net.
 *)

val delete: 
    (Term.term -> bool) -> (Term.term * 'a) net -> Term.term 
      -> (Term.term * 'a) net
