(* Global environment and utility functions *)

(* destruct a long identifier *)
(*
val dest_name : string -> string * string
*)

(* default theory and theoryDB*)

(** [empty_thy_name] the name of the anonymous theory *)
val empty_thy_name : string
val base_name : ref (string option)

(** [get_base_name ()]
   get the name of the base theory.
   raise Not Found if no base theory loaded or set.

   [set_base_name s]
   set the name of the base theory to [s]

   [clear_base_name()]
   clear the base name.
*)
val get_base_name: unit -> string
val set_base_name: string -> unit
val clear_base_name: unit -> unit


(* anon_thy: the anonymous theory *)
val anon_thy : unit -> Theory.thy
val thdb : unit -> Thydb.thydb

(* current theoryDB *)
val theories : Thydb.thydb ref

(* get/set theoryDB and current theory *)
val get_theories : unit -> Thydb.thydb
val set_theories : Thydb.thydb -> unit

val get_cur_thy : unit -> Theory.thy
val get_cur_name : unit -> string
val set_cur_thy : Theory.thy -> unit

(* filenames and paths for theory files *)

val thy_suffix: string

val get_thy_path : unit -> string list
val add_thy_path : string -> unit
val set_thy_path: string list -> unit
val remove_from_path: string -> unit

(** [find_file x]: Find file [x] in the theory path. 
   
   raise [Not_found] if not found
*)

val build_thy_file: string -> unit
val find_thy_file: string -> string

val get_cdir : unit -> string

(* current scope  *)
val scope : unit -> Gtypes.scope


(*
   [load_base_thy()]
   try to load the base theory 
   if successful:
   make it the current theory.
   set the base theory name ([set_base_name(...)])

   if unsuccessful:
   use an empty theory as the current theory.
   if [!base_thy_builder=Some(f)] 
   then call [f]
   otherwise clear the base theory name ([clear_base_name()])

   [get_base_thy_builder()]
   [set_base_thy_builder f]

   Set/get value of base_thy_builder.
*)

val set_base_thy_builder : (unit -> unit) -> unit
val get_base_thy_builder : unit -> (unit -> unit) option

val load_base_thy: unit -> unit


(* build PP record *)

(* function to invoke when loading theories from disk *)

val on_load_thy: Theory.thy -> unit

(* parsing functions *)
(* does error handling (from exception to Result.Error)
   so all calls to the parser should go through here *)

(* 
   [mk_term scp trm]
   typecheck term [trm] in scope [scp]
*)
val mk_term : Gtypes.scope -> Basic.term -> Basic.term
val mk_term_raw : Gtypes.scope -> Basic.term -> Basic.term
val mk_term_unchecked : Gtypes.scope -> Basic.term -> Basic.term
val read : string -> Basic.term
val read_unchecked : string -> Basic.term
val read_defn :
    string -> (string * (string * Basic.gtype) list) * Basic.term
val read_type_defn : string -> string * string list * Basic.gtype option
val read_type : string -> Basic.gtype
val read_fulltype : string -> Basic.gtype
val read_identifier: string -> Basic.ident

(* PP information *)

(* 
   [tp_pp_info]
   The system PP information store (of size Printer.default_info_size).
 *)
val tp_pp_info: Printer.ppinfo ref

(**
   [pp_info()]
   Get the system PP information store
 *)
val pp_info : unit -> Printer.ppinfo

(**
   [pp_reset()]
   Reset the system PP information store
 *)
val pp_reset: unit -> unit

(** 
   [pp_set info]
   Set the system PP information store to [info]
 *)
val pp_set : Printer.ppinfo -> unit

(** get/set/remove PP information for identifiers*)

(** PP information for terms *)

(*
   [get_term_pp id]
   get parsing and pretty printing information for identifer occuring 
   in a term.
   @param id identifier to look up.

   @return [(prec, fixity, repr)]
   where 
   [prec] is precedence
   [fixity] is fixity
   [repr] is representation to use (if any)

   @return [(default_term_prec, default_term_fixity, None)] if id is not found.
 *)
val get_term_pp : Basic.ident -> (int * Printer.fixity * string option)   

(**
   [add_term_pp id prec fixity repr]
   add parsing and pretty printing information for identifer 
   occuring in a term.
   @param id identifier to add.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
 *)
val add_term_pp : 
    Basic.ident -> int -> Printer.fixity 
      -> string option -> unit

(**
   [add_term_pp_record id rcrd]
   add parsing and pretty printing record for identifer occuring in a term.
   @param id identifier to add.
   @param rcrd PP record
 *)
val add_term_pp_record : 
    Basic.ident -> Printer.record -> unit

(**
   [remove_term_pp id]
   remove parsing and pretty printing information for identifer 
   occuring in a term.
   @param id identifier to remove.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
*)
val remove_term_pp : Basic.ident -> unit

(**
   [get_type_pp id]
   get parsing and pretty printing information for identifer occuring 
   in a type.
   @param id identifier to look up.

   @return [(prec, fixity, repr)]
   where 
   [prec] is precedence
   [fixity] is fixity
   [repr] is representation to use (if any)
 *)
val get_type_pp : Basic.ident -> (int * Printer.fixity * string option)

(**
   [add_type_pp id prec fixity repr]
   add parsing and pretty printing information for identifer 
   occuring in a type.
   @param id identifier to add.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
 *)

val add_type_pp : 
    Basic.ident -> int -> Printer.fixity -> string option -> unit

(**
   [add_type_pp_record id rcrd]
   add parsing and pretty printing record for identifer occuring in a type.
   @param id identifier to add.
   @param rcrd PP record
 *)
val add_type_pp_record : 
    Basic.ident -> Printer.record -> unit

(**
   [remove_type_pp id]
   remove parsing and pretty printing information for identifer 
   occuring in a type.
   @param id identifier to remove.
   @param prec precedence.
   @param fixity fixity.
   @param repr representation (if any).
 *)
val remove_type_pp : Basic.ident -> unit

(**
   [get/add/remove_term_printer]

   get/add/remove a term printer
*)
val get_term_printer:
    Basic.ident -> 
      (int -> (Basic.ident * (Basic.term list)) Printer.printer)
val add_term_printer : 
    Basic.ident -> 
      (Printer.ppinfo -> 
	int -> (Basic.ident * (Basic.term list)) Printer.printer) -> unit
val remove_term_printer : Basic.ident -> unit

(**
   [get/add/remove_type_printer]

   get/add/remove a type printer
*)
val get_type_printer:
    Basic.ident -> 
      (int -> (Basic.ident * (Basic.gtype list)) Printer.printer)
val add_type_printer : 
    Basic.ident -> 
      (Printer.ppinfo -> 
	int -> (Basic.ident * (Basic.gtype list)) Printer.printer) -> unit
val remove_type_printer : Basic.ident -> unit

(* initialising functions *)

val init_theoryDB : unit -> unit

(* list of initialising functions *)
val init_list: (unit -> unit) list ref
val add_init: (unit-> unit) -> unit

(* function to call to initialise system *)
val init : unit -> unit

(* list of reset functions *)

val reset_list: (unit -> unit) list ref
val add_reset: (unit-> unit) -> unit

(* reset(): function to call to reset system 

   calls al functions in reset_list then
   call init()
*)
val reset : unit -> unit

