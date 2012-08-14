(*----
  Name: userlib.ml
  Copyright M Wahab 2005-2010, 2012
  Author: M Wahab  <mwb.cde@googlemail.com>

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

(** {5 Global state} *)

module Global =
struct

  (** The default context. *)
  let default_context() = 
    let ctxt = Context.empty() in
    let ctxt1 = Context.set_obj_suffix [".cmo"; "cmi"] ctxt in
    let ctxt2 = Context.set_script_suffix (Settings.script_suffix) ctxt1 in
    let ctxt3 = Context.set_thy_suffix (Settings.thy_suffix) ctxt2 in  
    ctxt3

  (** Variables *)
  let state_var = ref (default_context())

  let state () = !state_var
  let set_state ctxt = state_var := ctxt

  (** Short cut to {!Thys.theories.} *)
  let theories() = Context.Thys.get_theories (state())

  (** Short cut to {!Thys.current.} *)
  let current() = Context.Thys.current (state())

  (** Short cut to {!Thys.current_name.} *)
  let current_name () = Context.Thys.current_name (state())

  (** The global scope. Constructed from the theory database. *)
  let scope () = Thydb.mk_scope(theories())

  (** Printer-Parser *)
  module PP =
  struct
    (*** Printer tables ***)
    let tp_pp_info = ref (Printer.empty_ppinfo())
    let info() = !tp_pp_info 
    let set info = tp_pp_info := info
    let pp_reset() = set (Printer.empty_ppinfo())

    (*** Parser tables ***)
    let sym_init() = Parser.init()
    let sym_info() = Parser.symtable()
    let sym_reset () = Parser.init()

    (** Initialiser *)
    let init() = pp_reset(); sym_init()
  end

  (** Initialise the global state. *)
  let init () =
    begin
      set_state(default_context());
      PP.init()
    end

end

(***
    Utility functions
***)

(** String utilities **)

let compile dirs name = 
  let compile_aux () =
    let inc_dirs = 
      Lib.list_string (fun x -> ("-I \""^x^"\"")) " " dirs
    in 
    let inc_std_dirs =
      Lib.list_string 
	(fun x -> ("-I \""^x^"\"")) " " (!Settings.include_dirs)
    in 
    let inc_string = inc_std_dirs^" "^inc_dirs in 
    let com_string = "ocamlc -c"
    in 
    Sys.command (com_string ^" "^ inc_string ^" "^name)
  in 
  if !Sys.interactive
  then compile_aux()
  else (-1)
    
let catch_errors = Commands.catch_errors

(***
    Printing and parsing 
***)

type fixity = Commands.fixity
let nonfix = Commands.nonfix
let prefix = Commands.prefix
let suffix = Commands.suffix
let infixl = Commands.infixl
let infixr = Commands.infixr
let infixn = Commands.infixn

let first_pos = Lib.First
let last_pos = Lib.Last
let before_pos s = Lib.Before (Global.read_identifier s)
let after_pos s = Lib.After (Global.read_identifier s)
let at_pos s = Lib.Level (Global.read_identifier s)

let add_term_pp s ?(pos=Lib.First) i f sym = 
  Commands.add_term_pp 
    (Ident.mk_long (Global.current_name()) s) ~pos:pos i f sym
let get_term_pp s = 
  Commands.get_term_pp (Ident.mk_long (Global.current_name()) s)
let remove_term_pp s = 
  Commands.remove_term_pp (Ident.mk_long (Global.current_name()) s)

let add_type_pp s = 
  Commands.add_type_pp (Ident.mk_long (Global.current_name()) s)
let get_type_pp s = 
  Commands.get_type_pp (Ident.mk_long (Global.current_name()) s)
let remove_type_pp s =
  Commands.remove_type_pp (Ident.mk_long (Global.current_name()) s)

(***
    Theories 
***)

let begin_theory = Commands.begin_theory
let end_theory = Commands.end_theory
let open_theory = Commands.open_theory
let close_theory = Commands.close_theory

(*** Theory properties ***)

let parents = Commands.parents
let add_file = Commands.add_file
let remove_file = Commands.remove_file

(*** Type declaration and definition ***)

let typedef ?pp ?(simp=true) ?thm ?rep ?abs tydef = 
  let defn = 
    Commands.typedef ?pp:pp ~simp:simp ?thm:thm ?rep:rep ?abs:abs tydef
  in 
  begin
    if simp && (Logic.Defns.is_subtype defn)
    then 
      let tyrec = Logic.Defns.dest_subtype defn in 
      let rt_thm = tyrec.Logic.Defns.rep_type
      and rti_thm = tyrec.Logic.Defns.rep_type_inverse
      and ati_thm = tyrec.Logic.Defns.abs_type_inverse
      in 
      List.iter Simplib.add_simp [rt_thm; rti_thm; ati_thm]
    else ()
  end;
  defn

(*** Term declaration and definition ***)

let define ?pp ?(simp=false) df =
  let ret = Commands.define ?pp ~simp:simp df
  in 
  if simp
  then 
    let (_, _, thm) = Logic.Defns.dest_termdef ret
    in 
    Simplib.add_simp thm; ret
  else ret

let declare = Commands.declare

(*** Axioms and theorems ***)

let axiom ?(simp=false) n t =
  let thm = Commands.axiom ~simp:simp n t
  in 
  if simp
  then (Simplib.add_simp thm; thm)
  else thm


let save_thm ?(simp=false) n thm =
  let ret = Commands.save_thm ~simp:simp n thm
  in 
  if simp 
  then (Simplib.add_simp ret; ret)
  else ret

let prove_thm ?(simp=false) n t tac =
  let thm = Commands.prove_thm ~simp:simp n t tac
  in 
  if simp 
  then (Simplib.add_simp thm; thm)
  else thm

let theorem = prove_thm
let lemma = theorem

(***
    Information access
***)

let theory = Commands.theory
let theories = Commands.theories

let defn = Commands.defn
let thm = Commands.thm

let scope = Commands.scope
let goal_scope = Goals.goal_scope

(***
    Proof commands
***)

let prove = Commands.prove
let by x = (catch_errors Goals.by_com) x
let qed = Commands.qed

(*** 
     Initialising functions
***)

let init = Global.init
let reset = Global.reset 
