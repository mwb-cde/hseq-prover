(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Goals and Proofs

    Support functions for interactive and batch proof.
*)


(**
   Support for interactive proof.

   A proof is a list of goals with the current goal at the head of the
   list.  and earlier goals following in order. Each goal is produced
   from its predecessor by applying a tactic. A tactic is undone by
   popping the top goal off the list.  *)
module Proof:
sig
  type t

  val empty: unit -> t
  val make : Logic.goal -> t
  val push : Logic.goal -> t -> t
  val top : t -> Logic.goal
  val pop : t -> t

  (* Printer *)
  val print: Printers.ppinfo -> t -> unit
end

(**
   Proof stacks for interactive proof. A proof stack is a list of
   proofs. The top proof is the active proof, on which work is done.
*)
module ProofStack :
sig
  type t

  val is_empty: t -> bool
  val empty: unit -> t
  val push : Proof.t -> t -> t
  val top : t -> Proof.t
  val pop : t -> t

  val rotate: t -> t
  val lift: int -> t -> t

  val push_goal : Logic.goal -> t -> t
  val top_goal : t -> Logic.goal
  val pop_goal : t -> t

  val save_hook: t -> (unit -> unit)
  val set_hook: (unit -> unit) -> t -> t
  (** User interface hook called when an application a proof command
      is successful.  *)

  (* Printer *)
  val print: Printers.ppinfo -> t -> unit
end

(** {7 General operations} *)

val has_proofs : ProofStack.t -> bool
(** Test for proof attempts *)

val top : ProofStack.t -> Proof.t
(** The current proof attempt *)

val top_goal : ProofStack.t -> Logic.goal
(** The current goal. *)

val drop : ProofStack.t -> ProofStack.t
(** Drop the current proof.  *)

val goal: ProofStack.t -> Scope.t -> Term.term -> ProofStack.t
(** Start a proof attempt. Creates a goal and pushes it on the top of
    the proof stack.

    Info: [ subgoals=[gl] ] [ cformulas=[trm] ]
    Where [gl] is the tag of the goal and [trm] the conclusion.
*)

val postpone: ProofStack.t -> ProofStack.t
(** Postpone the current proof, pushing it to the bottom of the stack.
*)

val lift: ProofStack.t -> int -> ProofStack.t
(** [lift n]: Focus on the nth proof to the top of the stack, making
    it the current proof attempt. Fails if there is no nth proof.
*)

val undo : ProofStack.t -> ProofStack.t
(** Go back. Pop the top goal off the proof. Fails if there is only
    one goal in the proof.
*)

val result: ProofStack.t -> Logic.thm
(** Claim that proof is completed. Make a theorem from the proof, fail
    if the current goal has subgoals and is therefore not a theorem.
*)

val apply:
  Context.t
  -> Tactics.tactic -> Logic.goal -> Logic.goal
(** [apply ctxt tac goal]: Apply tactic [tac] to [goal] using
    {!Logic.apply_to_goal}.

    Applies [tac] to the first subgoal [n] of [goal]. Returns the goal
    with the subgoals [tac n] appended to the remaining subgoals of goal.
*)

(** {7 Batch proofs} *)

val prove_goal:
  Context.t -> Term.term -> Tactics.tactic
  -> Logic.thm
(** [prove_goal scp trm tac]: Prove the goal formed from [trm]
    using tactic [tac] in scope [scp]. Used for batch proofs.
*)

(** {7 Interactive proofs} *)

val by_com :
  Context.t -> ProofStack.t -> Tactics.tactic -> ProofStack.t
(** Apply a tactic to the current goal. If the tactic succeeds, call
    [!save_hook]. Used for interactive proofs.
*)

val by_list :
  Context.t -> Term.term -> Tactics.tactic list -> Logic.thm
(** [by_list trm tacl]: Apply the list of tactics [tacl] to the
    goal formed from term [trm] in the standard scope.

    [by_list] applies each tactic in the list to the first subgoal of
    the goal, in the same way as an interactive proof is built up by
    applying tactics, one at a time, to a goal. This allows the list of
    tactics used during an interactive proof to be packaged for a batch
    proof. By contrast, {!Goals.prove_goal} requires a structured
    proof, a tactic which completely solves the goal, to be constructed
    from the tactics used in an interactive proof.
*)

(** {7 Support for proof recording} *)

val save_hook: ProofStack.t -> (unit -> unit)
(** User interface hook called when an application a proof command is
    successful.

    The proof commands which invoke [save_hook] are {!Goals.by_com} and
    {!Goals.goal}.
*)

val set_hook : (unit -> unit) -> ProofStack.t -> ProofStack.t
(** Set the user interface hook to a given function. *)

(** {7 Miscellaneous} *)

val curr_sqnt : ProofStack.t -> Logic.Sequent.t
(** The current sequent. *)

val goal_scope: ProofStack.t -> Scope.t
(** The scope of the current subgoal. *)

val get_asm: ProofStack.t -> int -> (Logic.ftag_ty * Term.term)
(** Get an assumption from the current sequent. *)

val get_concl: ProofStack.t -> int -> (Logic.ftag_ty * Term.term)
(** Get a conclusion from the current sequent. *)
