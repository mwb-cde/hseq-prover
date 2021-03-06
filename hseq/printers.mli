(*----
  Copyright (c) 2018-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Printkit

(**
   Term and type printers

   Support for pretty printing terms and types including printer
   information records to store symbolic representations and user
   defined printers.
*)

(** {5 Combined printer information tables} *)

type ppinfo =
    {
      terms: (ppinfo, (Term.term * (Term.term)list))info;
      types: (ppinfo, (Ident.t * (Gtype.t)list))info
    }

(**
   The combined printer information for terms and types.

   [terms]: The printer information for term identifiers.  User
   defined printers are applied to function identifier [f] and the list of
   terms [args] forming the application [f args].

   [types]: The printer information for term identifiers. User defined
   printers are applied to type identifier [f] and the list of
   types [args] forming the constructor [(args)f].
*)

val mk_ppinfo: int-> ppinfo
(**
   [mk_ppinfo sz]: Make an PP info store of size [sz].
*)

val empty_ppinfo: unit-> ppinfo
(**
   Create a PP information store using the default size given
   by [default_info_size].
*)

(** {7 Term printer information} *)

type term_printer =
  ppinfo -> (fixity * int) -> (Term.term * (Term.term)list) printer

val get_term_info: ppinfo -> Ident.t -> (int * fixity * string option)
(**
   [get_term_info ppinfo id]: Get pretty printing information for term
   identifer [id].  Returns [(default_term_prec, default_term_fixity,
   None)] if id is not found.
*)

val add_term_info:
  ppinfo -> Ident.t -> int -> fixity
  -> string option -> ppinfo
(**
   [add_term_info ppinfo id prec fixity repr]
   Add pretty printing information for term identifer [id].
   @param info PP information.
   @param id identifier to add.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
*)

val add_term_record:
  ppinfo -> Ident.t -> record -> ppinfo
(**
   [add_term_record info id record]
   Add pretty printing record for a term identifer.
   @param info PP information.
   @param id identifier to add.
   @param record PP record
*)

val remove_term_info: ppinfo ->  Ident.t -> ppinfo
(** [remove_term_info info id] Remove pretty printing information for
    a term identifer.
*)

val get_term_printer:
  ppinfo -> Ident.t -> term_printer
(** Get the user defined printer for a term identifier. *)

val add_term_printer:
  ppinfo -> Ident.t
  -> term_printer
  -> ppinfo
(** Add a user defined printer for a term identifier. *)

val remove_term_printer: ppinfo -> Ident.t -> ppinfo
(** Remove user defined printer for a term identifier. *)

(** {7 Gype printer information} *)

type gtype_printer =
  ppinfo -> (fixity * int) -> (Ident.t * (Gtype.t list)) printer

val get_type_info:
  ppinfo -> Ident.t -> (int * fixity * string option)
(**
   Get pretty printing information for a type identifer.
*)

val add_type_info:
  ppinfo -> Ident.t -> int -> fixity -> string option -> ppinfo
(**
   [add_type_info info id prec fixity repr]
   Add pretty printing information for type identifer [id].
   @param info PP information.
   @param id identifier to add.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
*)

val add_type_record: ppinfo -> Ident.t -> record -> ppinfo
(**
   [add_type_record info id record]
   Add a pretty printing record for a type identifer.
   @param info PP information.
   @param id identifier to add.
   @param record PP record
*)

val remove_type_info: ppinfo -> Ident.t -> ppinfo
(**
   [remove_type_info info id]
   Remove pretty printing information for a type identifer.
*)

val get_type_printer:
  ppinfo -> Ident.t -> gtype_printer
(** Get the user defined printer for a type identifier *)

val add_type_printer:
  ppinfo -> Ident.t -> gtype_printer -> ppinfo
(** Add a user defined printer for a type identifier *)

val remove_type_printer: ppinfo -> Ident.t -> ppinfo
(** Remove a user defined printer for a type identifier *)

(** {5 Pretty-printing utility functions} *)

val fun_app_prec: int
(** Precedence of function application *)
val prec_qnt: Term.quant -> int
(** Precedence of Quantifiers *)
val assoc_qnt: Term.quant -> assoc
(** Associativity of Quantifiers *)
val fixity_qnt: Term.quant -> fixity
(** Fixity of Quantifiers *)

(** {5 Type printers} *)

module Types:
sig
  (** Implementation of type printers *)

  (** Main type printer *)
  val print_type:
    ppinfo -> (fixity * int) -> (Gtype.t)Printkit.printer
end

(** Printer for types. This is an alias for [Types.print] *)
val print_type: ppinfo -> (Gtype.t)Printkit.printer

(** Printer for type error *)
val print_type_error:
  Format.formatter -> ppinfo -> Gtype.error -> unit

(** {5 Term printers} *)

module Terms:
sig
  (** {7 Helper functions for user defined printers} *)

  val pplookup: ppinfo -> Ident.t -> Printkit.record
  (** Get the printer record for a term identifier.
   *)

  val print_qnts:
    ppinfo -> (Printkit.fixity * int)
    -> (string * (Term.Binder.t list)) Printkit.printer
  (** [print_qnts ppstate prec (str, qnts)]: Print binders [qnts] using
    symbol [str].
   *)

  val print_typed_obj:
    int
    -> (ppinfo -> (Printkit.fixity * int) -> ('a) Printkit.printer)
    -> ppinfo
    -> (Printkit.fixity * int)
    -> ('a * Gtype.t) Printkit.printer
  (** [print_typed_obj level printer ppstate prec (obj, ty)]: If
    [Setting.print_type_level > level] print [obj] with [ty] as its
    type in the form [(obj: ty)] otherwise print [obj] only. Uses
    [printer] to print [obj].
   *)

  val print_bracket:
    (Printkit.fixity * int) -> (Printkit.fixity * int)
    -> string Printkit.printer
  (** [print_bracket ppstate prec str]: Print bracket [str].
   *)

  val print_ident_as_identifier:
    ppinfo ->  (Printkit.fixity * int)
    -> (Term.term)Printkit.printer
  (** [print_ident_as_identifier ppstate]: Print a [Id(id, _)] term as
    an identifier using [Printkit.print_identifier ppstate].
   *)

  val print_infix:
    (((Printkit.fixity * int) -> Ident.t Printkit.printer)
     * ((Printkit.fixity * int) -> Term.term Printkit.printer))
    -> (Printkit.fixity * int)
    -> (Ident.t * (Term.term)list) Printkit.printer
  (** [print_infix]: print [(f, args)] as an infix operator. *)

  val print_prefix:
    (((Printkit.fixity * int) -> Ident.t Printkit.printer)
     * ((Printkit.fixity * int) -> Term.term Printkit.printer))
    -> (Printkit.fixity * int)
    -> (Ident.t * (Term.term)list) Printkit.printer
  (**
   [print_suffix]: Print [(f, args)] as a suffix operator.
   *)
  val print_suffix:
    (((Printkit.fixity * int) -> Ident.t Printkit.printer)
     * ((Printkit.fixity * int) -> Term.term Printkit.printer))
    -> (Printkit.fixity * int)
    -> (Ident.t * (Term.term)list) Printkit.printer
  (** [print_prefix]: Print [(f, args)] as a prefix operator.  *)

  val print_fn_app:
    ppinfo
    -> (((Printkit.fixity * int) -> Term.term Printkit.printer)
        * ((Printkit.fixity * int) -> Term.term Printkit.printer))
    -> (Printkit.fixity * int)
    -> (Term.term * (Term.term)list) Printkit.printer
  (** [print_fn_app ppstate id_printer term_printer (f, args)]: Print
    [(f, args)] as a function application.

    If there is a printer in [ppstate] for [f] then that is used
    otherwise [f] as an identifier and [term_printer] to print each of
    the [args].
   *)

  val simple_print_fn_app:
    ppinfo -> (Printkit.fixity * int)
    -> (Term.term * Term.term list) Printkit.printer
  (** [simple_print_fn_app]: Print an application as [f a1 a2 .. an].

    Utility function for user defined pretty-printers. Unlike
    [print_fn_app], doesn't try to find a printer for [f] so this
    should be used as a default if a user defined printer can't be
    used.
   *)

  val print_as_binder:
    (Printkit.fixity * int) -> Ident.t -> string
    -> ppinfo -> (Printkit.fixity * int)
    -> (Term.term * (Term.term)list) Printkit.printer
  (** [print_as_binder (sym_assoc, sym_prec) f sym]: Construct a printer
    to print function applications of the form [f (%x: P)] as [sym x:
    P].
   *)

  val print_qnt_body:
    ppinfo -> (Printkit.fixity * int)
    -> ((Term.Binder.t)list * Term.term) Printkit.printer
(** [print_qnt_body (assoc, prec) qs body]: Print term [body]
    quantified by variables [qs=[x1; x2; ...; xn]] as [x1 x2 ... xn:
    body].
 *)

  val print_term:
    ppinfo -> (Printkit.fixity * int) -> (Term.term)Printkit.printer
end

(** Term printer *)
val print_term: ppinfo -> (Term.term)Printkit.printer

(** Print a term error *)
val print_term_error:
  Format.formatter -> ppinfo -> Term.error -> unit
