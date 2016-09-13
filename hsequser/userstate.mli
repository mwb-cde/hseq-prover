(**----
   Name: userlib.mli
   Copyright Matthew Wahab 2013-2016
   Author: Matthew Wahab  <mwb.cde@gmail.com>

   This file is part of HSeq

   HSeq is free software; you can redistribute it and/or modify it under
   the terms of the Lesser GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   HSeq is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the Lesser GNU General Public
   License for more details.

   You should have received a copy of the Lesser GNU General Public
   License along with HSeq.  If not see <http://www.gnu.org/licenses/>.
   ----*)

open HSeq

(** {5 Default values} *)
module Default :
sig
  val context: unit -> Context.t
  val scope: unit -> Scope.t
  val printers: unit -> Printer.ppinfo
  val parsers: unit -> Parser.Table.t
  val simpset: unit -> Simpset.simpset
  val proofstack: unit -> Goals.ProofStack.t
  val base_thy_builder: unit -> unit -> unit
  val thyset: unit -> Lib.StringSet.t
end

(** {5 Global state} *)

module State:
sig
  type t =
    {
      context_f : Context.t;
      simpset_f : Simpset.simpset;
      proofstack_f: Goals.ProofStack.t;
      base_thy_builder_f: t -> t;
      thyset_f: Lib.StringSet.t;
    }

  val empty: unit -> t

  val context: t -> Context.t
  val set_context: t -> Context.t -> t

  val scope: t -> Scope.t
  val set_scope: t -> Scope.t -> t

  val ppinfo: t -> Printer.ppinfo
  val set_ppinfo: t -> Printer.ppinfo -> t

  val parsers: t -> Parser.Table.t
  val set_parsers: t -> Parser.Table.t -> t

  val simpset: t -> Simpset.simpset
  val set_simpset: t -> Simpset.simpset -> t

  val proofstack: t -> Goals.ProofStack.t
  val set_proofstack: t -> Goals.ProofStack.t -> t

  val base_thy_builder: t -> (t -> t)
  val set_base_thy_builder: t -> (t -> t) -> t

  val thyset: t -> Lib.StringSet.t
  val set_thyset: t -> Lib.StringSet.t -> t
end

(***
val state: unit -> State.t
(** The global state *)
val set_state: State.t -> unit
(** Set the global state *)
***)

val context: State.t -> Context.t
(** The global context *)
val set_context: State.t -> Context.t -> State.t
(** Set the global context *)

val scope: State.t -> Scope.t
(** The global Scope *)
val set_scope: State.t -> Scope.t -> State.t
(** Set the global scope *)

val ppinfo: State.t -> Printer.ppinfo
(** The global pretty printers *)
val set_ppinfo: State.t -> Printer.ppinfo -> State.t
(** Set the global pretty printers *)

val parsers: State.t -> Parser.Table.t
(** The global parser tables *)
val set_parsers: State.t -> Parser.Table.t -> State.t
(** Set the global parser tables *)

val simpset: State.t -> Simpset.simpset
(** The standard simplifier set *)
val set_simpset: State.t -> Simpset.simpset -> State.t
(** Set the global simplifier set *)

val proofstack: State.t -> Goals.ProofStack.t
(** The standard simplifier set *)
val set_proofstack: State.t -> Goals.ProofStack.t -> State.t
(** Set the global simplifier set *)

val base_thy_builder: State.t -> (State.t -> State.t)
(** The base theory builder *)
val set_base_thy_builder: State.t -> (State.t -> State.t) -> State.t
(** Set the base theory builder *)

val thyset: State.t -> Lib.StringSet.t
val set_thyset: State.t -> Lib.StringSet.t -> State.t
val thyset_add: State.t -> string -> State.t
val thyset_mem: State.t -> string -> bool

val init_context: State.t -> State.t
(** Initialize the global context *)
val init_scope: State.t -> State.t
(** Initialize the global scope *)
val init_ppinfo: State.t -> State.t
(** Initialize the global pretty printers *)
val init_parsers: State.t -> State.t
(** Initialize the global parser tables *)
val init_simpset: State.t -> State.t
(** Initialize the global simpset *)
val init_proofstack: State.t -> State.t
(** Initialize the global proofstack *)
val init_base_thy_builder: State.t -> State.t
(** Initialize the base theory builder *)

module Init :
sig
  (** {5 State initialising functions} *)

  (** Initialise the global state *)
  val init: State.t -> State.t
  (** Reset the global state *)
  val reset: State.t -> State.t
end

(** Initialise the global state *)
val init: State.t -> State.t
(** Reset the global state *)
val reset: State.t -> State.t
