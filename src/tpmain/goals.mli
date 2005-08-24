(*-----
   Name: goals.mli
   Author: M Wahab <mwahab@users.sourceforge.net>
   Copyright M Wahab 2005
   ----*)

(** Goals and Proofs

   Support functions for interactive and batch proof.
 *)


(**
   Support for an interactive proof.

   A proof is a list of goals. The first is the current current,
   earlier goals occur later in the list. Each goal is produced from
   its predecessor by applying a tactic. A tactic is undone by popping
   the top goal off the list.
 *) 
module Proof: 
    sig
      type t = Logic.goal list

      val push : Logic.goal -> t -> t
      val top : t -> Logic.goal
      val pop : t -> t

    end

(**
   Proof stacks for interactive proof. A proof stack is a list of
   proofs. The top proof is the active proof, on which work is done.
*)
module ProofStack :
    sig
      type t = Proof.t list

      val push : Proof.t -> t -> t
      val top : t -> Proof.t
      val pop : t -> t

      val rotate: t -> t
      val lift: int -> t -> t

      val push_goal : Logic.goal -> t -> t
      val top_goal : t -> Logic.goal
      val pop_goal : t -> t

    end 

(** {7 General operations} *)

val proofs : unit -> ProofStack.t
(** Get the stack of proofs. *)

val top : unit -> Logic.goal
(** The current proof attempt *)

val drop : unit -> unit
(** Drop the current proof.  *)

val goal : Basic.term -> Logic.goal
(** 
   Start a proof attempt. Creates a goal and pushes it on the top of
   the proof list.
*)

val postpone: unit -> Logic.goal
(**
   Postpone the current proof, pushing it to the bottom of the list of
   attempts.
*)

val lift: int -> Logic.goal
(**
   [lift n]: Focus on the nth proof, making it the current proof
   attempt. Fails if there is no nth proof.
*)

val undo : unit -> Logic.goal
(** 
   Go back. Pop the top goal off the proof. Fails if there is only one
   goal in the proof.
*)

val result: unit-> Logic.thm
(** 
   Claim that proof is completed. Make a theorem from the proof, fail
   if the current goal has subgoals.
*)

val apply: 
    ?report:(Logic.node -> Logic.branch -> unit) 
  -> Tactics.tactic -> Logic.goal -> Logic.goal
(** 
   [apply ?report tac goal]: Apply tactic [tac] to [goal] using
   {!Logic.Subgoals.apply_to_goal}.

   Applies [tac] to the first subgoal [n] of [goal]. Returns the goal 
   with the subgoals [tac n] appended to the remaining subgoals of goal.
*)

(** {7 Batch proofs} *)

val prove_goal: Scope.t -> Basic.term -> Tactics.tactic -> Logic.thm 
(**
   [prove_goal scp trm tac]: Prove the goal formed from [trm] using
   tactic [tac] in scope [scp]. Used for batch proofs.
*)

(*
val prove: Basic.term -> Tactics.tactic -> Logic.thm
(**
   [prove trm tac]: Prove the goal formed from [trm] using tactic
   [tac] in the standard scope. Equivalent to [prove_goal
   (Global.scope()) trm tac]. Used for batch proofs.
*)
*)

(** {7 Interactive proofs} *)

val by_com : Tactics.tactic -> Logic.goal
(** 
   Apply a tactic to the current goal. If the tactic succeeds, call
   [!save_hook]. Used for interactive proofs.
*)

val by_list : Basic.term -> Tactics.tactic list -> Logic.thm
(**
   [by_list trm tacl]: Apply the list of tactics [tacl] to the goal formed 
   from term [trm] in the standard scope.

   [by_list] applies each tactic in the list to the first subgoal of
   the goal, in the same way as an interactive proof is built up by
   applying tactics, one at a time, to a goal. This allows the list of
   tactics used during an interactive proof to be packaged for a batch
   proof. By contrast, {!Goals.prove_goal} requires a structured
   proof, a tactic which completely solves the goal, to be constructed
   from the tactics used in an interactive proof.
*)

(** {7 Support for proof recording} *)

val save_hook: (unit -> unit) ref 
(**
   User interface hook called when an application a proof command is
   successful.

   The proof commands which invoke [save_hook] are {!Goals.by_com} and
   {!Goals.goal}.
*)

val set_hook : (unit -> unit) -> unit
(** Set the user interface hook to a given function. *)

(** {7 Miscellaneous} *)

val curr_goal : unit -> Logic.goal
(** Get the current goal in a proof. *)

val curr_sqnt : unit -> Logic.Sequent.t
(** The current sequent *)

val get_asm: int -> (Tag.t * Basic.term)
(** Get an assumption from the current sequent. *)

val get_concl: int -> (Tag.t * Basic.term)
(** Get a conclusion from the current sequent. *)


(** {7 Debugging} *)
