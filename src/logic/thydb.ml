(*----
  Name: thydb.ml
  Copyright M Wahab 2005-2010
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

open Report

exception Importing

(*
 * Error handling 
*)

class dbError s ns =
object (self)
  inherit Report.error s
  val names = (ns: string list)
  method get() = names
  method print st = 
    Format.printf "@[%s@ @[" (self#msg()); 
    Printer.print_sep_list (Format.print_string , ",") (self#get());
    Format.printf "@]@]"
end

let error s t = mk_error ((new dbError s t):>Report.error)
let add_error s t es = raise (Report.add_error (error s t) es)

(*
 * Databases
 *)

(** NameSet: A data structure for storing the names of theories in the
    order they are added.

    This behaves like a list of strings but also supports fast lookup.
*)
module NameSet = 
struct
  type t = { list : string list ; set : Lib.StringSet.t }

  let empty = { list = []; set = Lib.StringSet.empty }
  let mem s x = Lib.StringSet.mem x s.set

  (** [add s x]: Add [x] to [s]. Fail if [x] is already present in [s]. *)
  let add s x = 
    if mem s x
    then raise (error "Name exists in scope:" [x])
    else 
      { 
        list = x::s.list;
        set = Lib.StringSet.add x s.set 
      }

  (** [insert s x]: Add [x] to [s], if not already present.  Do
      nothing if [x] is already present in [s].  *)
  let insert s x = 
    if mem s x
    then s
    else 
      { 
        list = x::s.list;
        set = Lib.StringSet.add x s.set
      }

  let rev s  = { s with list = List.rev s.list }

  let filter p s  = 
    {
      list = List.filter p s.list;
      set = Lib.StringSet.filter p s.set 
    }

  let to_list s = s.list
  let to_set s = s.set
  let from_list ls = List.fold_left add empty ls

  let print s = 
    Format.printf "@[<2>";
    Printer.print_sep_list (Format.print_string, ",") (to_list s);
    Format.printf "@]";
end

module Tree = Treekit.StringTree

type table_t = (Theory.thy)Tree.t

type thydb = 
    {
      db: table_t;
      curr: Theory.thy option;
      importing : NameSet.t
    }

let empty () = 
  {
    db= Tree.nil; 
    curr=None;
    importing = NameSet.empty
  }

let table thdb = thdb.db
let current thdb = 
  Lib.dest_option ~err:(Failure "No current theory") thdb.curr
let imported thdb = NameSet.to_list thdb.importing
let thys thdb = NameSet.to_set thdb.importing

let expunge db = 
  let used_list = db.importing
  and tbl = table db
  in 
  let not_used = 
    let rec flatten_list ls rs =
      match ls with 
        | [] -> rs
        | ((n, _)::_)::xs -> 
	  if not (NameSet.mem used_list n)
	  then flatten_list xs (n::rs)
	  else flatten_list xs rs
        | [] :: xs -> flatten_list xs rs
    in 
    flatten_list (Treekit.StringTree.to_list tbl) []
  in 
  let tbl1 = List.fold_left Treekit.StringTree.delete tbl not_used
  in 
  { db with db=tbl1 }

(*
 * Operations on Theories
 *)

let current_name db = 
  let thy = current db
  in 
  Theory.get_name thy

let is_imported th thdb = NameSet.mem thdb.importing th
let is_loaded name thdb = Tree.mem thdb.db name

let add_thy thdb thy = 
  let name = Theory.get_name thy
  in 
  if is_loaded name thdb
  then raise (error ("Theory "^name^" already present in database.") [])
  else { thdb with db =Tree.add thdb.db name thy }

let remove_thy thdb n= 
  if (n=current_name thdb) || (is_imported n thdb)
  then raise (error ("Theory "^n^" is being used in the database.") [])
  else { thdb with db = Tree.delete thdb.db n }

let get_thy thdb name = Tree.find thdb.db name

let get_parents thdb s = Theory.get_parents (get_thy thdb s)


(*
 * Printer 
 *)

let print db = 
  let table_as_list db0 = Treekit.StringTree.to_list (table db0)
  and print_tbl ths = 
    Printer.print_sep_list 
      ((fun (n, _) -> Format.print_string n), ",") ths
  and name = try current_name db with _ -> "(none)"
  in 
  Format.printf "@[{@,Current theory: %s;@ " name;
  Format.printf "Importing: @[<2>";
  Printer.print_sep_list (Format.print_string, ",") (imported db);
  Format.printf ";@]@ ";
  Format.printf "Table: @[<2>";
  Printer.print_sep_list (print_tbl, ",") (table_as_list db);
  Format.printf ";@]@,}@]"

let message s db = 
  Format.printf "@[<v>%s" s;
  print db;
  Format.printf "@,@]"

(*
 * Operations on the current theory 
 *)

(*** House keeping functions ***)

(*** Constructing an importing list from the current theory. ***)

(** [not_loaded db ns]: Get the list of names in [ns] which are not
    loaded in the database of [db].
*)
let not_loaded db ns = 
  List.filter (fun x -> not (is_loaded x db)) ns

(** [all_loaded db ns]: Test that each theory named in [ns] is loaded
    in [db]. Raise error if any is not loaded.
*)
let all_loaded db ns = 
  match not_loaded db ns with
    | [] -> true
    | (x::_) -> raise (error "Theory not in database" [x])

(** [add_importing db ns]: Add names [ns] to the importing list.
*)
let add_importing thdb ls = 
  let ls1 = Lib.remove_dups ((imported thdb) @ ls)
  in 
  if all_loaded thdb ls1
  then 
    let thys1 = List.fold_left NameSet.add thdb.importing ls1
    in 
    { thdb with importing = thys1 }
  else thdb

(** [mk_importing db]: Build the importing list of the current theory
    Fail if any theory in not loaded.
*)
let mk_importing thdb =
  let rec mk_aux name rs = 
    if NameSet.mem rs name
    then rs
    else 
      let thy_list = 
	try get_parents thdb name
	with err -> raise (add_error "mk_importing, theory" [name] err)
      in 
      let rs1 = List.fold_left (fun r n -> mk_aux n r) rs thy_list 
      in 
      List.fold_left NameSet.insert rs1 (List.rev thy_list)
  in 
  let name = current_name thdb
  in 
  NameSet.insert (mk_aux name NameSet.empty) name

(** Set the current theory to the given theory. The theory is added to
    the table of theories if not already present. The importing list
    is rebuilt from the theory parents. Fails if any of the theorys'
    parents are not loaded.
*)
let set_current thdb thy = 
  let check_first n l =
    match Lib.try_app List.hd l with
      | None -> true
      | (Some x) -> ((x == n) || (x = n))
  in 
  let name = Theory.get_name thy 
  in
  let test_loaded () = 
    try ignore(all_loaded thdb (imported thdb))
    with e -> 
      raise (add_error ("Parents of theory "^name^" not in database.") [] e)
  in 
  let set_aux () = 
    test_loaded();
    let db1 = try add_thy thdb thy with _ -> thdb in 
    let db2 = { db1 with curr = Some(thy) } in 
    let db3 = { db2 with importing = mk_importing db2 }
    in 
    if check_first name (imported db3)
    then db3
    else raise (error "Circular importing, theory" [name])
  in 
  try set_aux()
  with e -> 
    raise (add_error 
	     ("Can't set theory "^name^" as the current theory.") [] e)

(*** Find functions ***)

(** [find f tdb]: Apply [f] to each theory in the importing list,
    returning the first that succeeds. Raise [Not_found] if none
    succeed.
*)
let find f tdb =
  let rec find_aux ls =
    match ls with 
      | [] -> raise Not_found
      | x::xs ->
	try f (get_thy tdb x)
	with Not_found -> find_aux xs
  in find_aux (imported tdb)

(** [quick_find f th tdb]: apply [f] to theory [th] if it is in the
    importing list. Raise [Not_found] if not found.
*)
let quick_find f th tdb =
  if is_imported th tdb
  then f (get_thy tdb th)
  else raise Not_found

(*** Types ***)

let add_type_rec tr thdb = 
  Theory.add_type_rec tr (current thdb); thdb

let get_type_rec th n tdb=
  let get_aux cur= 
    try Theory.get_type_rec n cur
    with _ -> raise Not_found 
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let thy_of_type th name thdb =
  let is_thy_of thy =
    if Theory.type_exists name thy 
    then Theory.get_name thy
    else raise Not_found
  in 
  find is_thy_of thdb 

(*** Definitions and Declarations ***)

let add_decln_rec dcl ps thdb =
  let s, ty = Logic.Defns.dest_termdecln dcl
  in 
  Theory.add_decln_rec (Ident.name_of s) ty ps (current thdb);
  thdb

let add_decln dcl ps thdb =
  let s, ty = Logic.Defns.dest_termdecln dcl
  in 
  Theory.add_decln_rec (Ident.name_of s) ty ps (current thdb);
  thdb

let add_defn_rec s ty def ps thdb =
  Theory.add_defn_rec s ty def ps (current thdb);
  thdb

let add_defn s ty def ps thdb =
  Theory.add_defn_rec s ty (Some def) ps (current thdb);
  thdb

let get_defn_rec th n tdb =
  let get_aux cur = 
    try Theory.get_defn_rec n cur
    with _ -> raise Not_found 
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let get_defn th n tdb = 
  let r = get_defn_rec th n tdb
  in 
  match r.Theory.def with
    | None -> raise (Report.error ("No definition for "^n))
    | Some(d) -> d

let get_id_type th n tdb = 
  let r = get_defn_rec th n tdb
  in
  r.Theory.typ

let get_id_options n db = 
  let get_id x =
    try Some(get_defn_rec x n db) 
    with Not_found -> None
  in 
  let rec get_aux ls r= 
    match ls with
      | [] -> List.rev r
      | x::xs -> 
        begin
	  match get_id x with
	    | None -> get_aux xs r
	    | Some(defn) ->
              let new_id = Ident.mk_long x n
              and new_ty = defn.Theory.typ
              in 
	      get_aux xs ((new_id, new_ty)::r)
        end
  in 
  get_aux (imported db) []

let id_exists th n tdb = 
  try ignore(get_defn_rec th n tdb); true
  with Not_found -> false

let thy_of th name thdb =
  let is_thy_of thy =
    if Theory.id_exists name thy
    then Theory.get_name thy
    else raise Not_found
  in 
  find is_thy_of thdb 

(*** Theorems ***)

let add_axiom s th ps thdb =
  Theory.add_axiom s th ps (current thdb); thdb

let add_thm s th ps thdb =
  Theory.add_thm s th ps (current thdb); thdb

let get_axiom th n tdb =
  let get_aux cur = 
    try Theory.get_axiom n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let get_theorem th n tdb =
  let get_aux cur =
    try Theory.get_theorem n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let get_lemma th n tdb =
  let get_aux cur =
    try Theory.get_theorem n cur
    with _ -> 
      try Theory.get_axiom n cur
      with _ ->
	try Theory.get_defn n cur
	with _ -> raise Not_found
  in
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

(*** Type Printer-Parser records ***)

let add_type_pp_rec n ppr thdb = 
  Theory.add_type_pp_rec n ppr (current thdb); thdb

let get_type_pp_rec th n tdb =
  let get_aux cur = 
    try Theory.get_type_pp_rec n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb
    
let remove_type_pp_rec th n tdb = 
  let get_aux cur = 
    try Theory.remove_type_pp_rec n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let get_type_pplist th tdb =
  let get_aux cur = Theory.get_type_pplist cur
  in 
  quick_find get_aux th tdb

(*** Term Printer-Parser records ***)

let add_term_pp_rec n ppr thdb = 
  Theory.add_term_pp_rec n ppr (current thdb); thdb

let get_term_pp_rec th n tdb =
  let get_aux cur = 
    try Theory.get_term_pp_rec n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb
    
let remove_term_pp_rec th n tdb = 
  let get_aux cur = 
    try Theory.remove_term_pp_rec n cur
    with _ -> raise Not_found
  in 
  if th = "" 
  then find get_aux tdb
  else quick_find get_aux th tdb

let get_term_pplist th tdb =
  let get_aux cur = Theory.get_term_pplist cur
  in
  quick_find get_aux th tdb

(*
 * Scopes from database 
 *)

let marker_in_scope m db =
  let get_mark n tbl = Theory.get_marker (get_thy tbl n) in 
  let name = Scope.marker_name m
  in 
  if is_imported name db
  then 
    try 
      let thy_mark = get_mark name db
      in
      Tag.equal thy_mark m
    with Not_found -> false
  else false
    
let scope_term_type db f =
  let thstr, idstr = Ident.dest f
  in 
  get_id_type thstr idstr db

let scope_term_thy thy_name db x = thy_of thy_name x db

let scope_type_defn db f = 
  let thstr, idstr = Ident.dest f
  in 
  get_type_rec thstr idstr db

let scope_type_thy thy_name db x = 
  thy_of_type thy_name x db

let scope_thy_in_scope db th1 = 
  if th1=Ident.null_thy  (* ignore the empty scope *)
  then true
  else is_imported th1 db

let scope_marker_in_scope db m = marker_in_scope m db

let mk_scope db =
  let thy_marker = 
    try 
      let thy = get_thy db (current_name db)
      in 
      Theory.get_marker thy
    with _ -> Scope.mk_marker Ident.null_thy
  in 
  let thy_name = Scope.marker_name thy_marker 
  and empty_scp = Scope.empty_scope()
  in 
  {
    empty_scp
   with 
     Scope.curr_thy = thy_marker;
     Scope.term_type = scope_term_type db; 
     Scope.term_thy = scope_term_thy thy_name db;
     Scope.type_defn = scope_type_defn db;
     Scope.type_thy = scope_type_thy thy_name db;
     Scope.thy_in_scope  = scope_thy_in_scope db;
     Scope.marker_in_scope = scope_marker_in_scope db
  } 
    
(*
 * Theory loader 
 *)

module Loader = 
struct

  (** Information about a theory passed to file-handling functions. *)
  type info =
      { 
	name: string;
	date : float option;
	prot : bool option;
	childn : Lib.StringSet.t 
      }

  let mk_info n d p = 
    { 
      name = n;
      date = d;
      prot = p; 
      childn = Lib.StringSet.empty
    }

  let mk_full_info n d p c = 
    { 
      name = n;
      date = d;
      prot = p ; 
      childn=c
    }

  let info_add inf n = 
    { inf with childn = Lib.StringSet.add n (inf.childn) }

    (*** Data needed for loading a theory. ***)
  type data = 
      {
	thy_fn: (thydb -> Theory.contents -> unit);
	(** Function to apply to a successfully loaded theory.  *)
	load_fn: info -> Theory.saved_thy;
	(** Function to find and load a theory file. *)
	build_fn: thydb -> string -> thydb
       (** Function to build the theory if it can't be loaded. *)
      }

  let mk_data tfn lfn bfn = 
    { thy_fn = tfn; load_fn = lfn; build_fn = bfn }

  (*** Support functions for loading a theory ***)

  (** A version of [set_current] for internal use. Sets the current
      theory and adds the name to the importing list, if the theory
      isn't already in the importing list otherwise it does nothing.

      Doesn't re-calculate the importing list. 
      Doesn't test whether any of the theories are loaded.
  *)
  let set_curr db thy = 
    let name = Theory.get_name thy
    and imps = db.importing
    in 
    if NameSet.mem imps name 
    then db
    else
      { db with
        curr = Some(thy);
        importing = NameSet.add imps name
      }

  (** [test_data tim thy]: Ensure that the date of theory [thy] is
      not greater then [tim].  *)
  let test_date name tym thy_date = 
    match tym with
      | None -> ()
      | Some(tim) ->
	if thy_date <= tim
	then () 
	else 
	  (warning ("Imported theory "^name
		    ^" is more recent than"
		    ^" its importing theory");
	   raise (Report.error 
      		    ("Imported theory "^name
		     ^" is more recent than"
		     ^" its importing theory")))

  (** [test_protection prot thy]: Ensure that the protection of theory
      [thy] is [prot].  *)
  let test_protection name prot thy_prot =
    match prot with 
      | None -> ()
      | (Some pval) ->
	if pval
	then 
          if thy_prot
	  then ()
	  else 
	    (warning 
	       ("Imported theory "^name
		^" is not complete");
	     raise 
	       (Report.error 
		  ("Imported theory "^name
		   ^" is not complete")))
	else ()

  (** [load_thy info ]: Load theory specified by [info], using
      [data.load_fn]. The protection and date of the theory must be as
      specified by [prot] and [tim]. Returns the loaded theory as the
      saved representation of a theory.  *)
  let load_thy info data thdb=
    let load_aux () = 
      let saved_thy = data.load_fn info
      in 
      test_protection info.name info.prot (Theory.saved_prot saved_thy);
      test_date info.name info.date (Theory.saved_date saved_thy);
      if !Settings.load_thy_level > 0
      then Format.printf "@[Loading theory %s@]@." info.name
      else ();
      saved_thy
    in 
    try load_aux()
    with err -> add_error "Failed to load theory" [info.name] err

  (*** Building theories ***)

  (** [check_importing info n]: Test for a circular importing. Fails
      iff [n] is in [info.childn].  *)
  let check_importing info n =
    let childn = info.childn
    in 
    if Lib.StringSet.mem n childn
    then raise (error "Circular importing, theory" [n])
    else ()

  (** [check_build db0 db thy]: Check the result of a theory
      build. Verify that [thy] is in database [db], that the parents
      of [thy] are in the importing list of [db], that [thy] is the
      first in the importing list and that every theory in the
      importing list of [db0] is in the table of [db].

      raise Failure if checks fail.
  *)
  let check_build db0 db thy =
    let check_first n l = 
      match Lib.try_app List.hd l with
	| None -> ()
	| Some(x) -> 
	  if ((x == n) || (x = n))
          then ()
	  else 
	    raise 
	      (error "Built theory not first in importing list." [n; x])
    in 
    let thy_list = imported db 
    and name = Theory.get_name thy
    in 
    let check_aux () = 
      check_first name thy_list;
      ignore(all_loaded db thy_list);
      ignore(all_loaded db (imported db0));
      try ignore (get_thy db name)
      with _ -> raise (error "Built theory not in database." [name])
    in
    try check_aux()
    with err -> raise (add_error "Failed to build theory" [name] err)

  (** [build_thy info buildfn thdb]: Build theory named [info.name]
      using function [buildfn]. Function [buildfn] is assumed to add
      the theory to [thdb].

      Fails if the newly built theory does not have the attributes
      specified in [info].

      Returns the database with the newly built theory as the current
      theory.  *)
  let build_thy info data thdb= 
    let db = 
      try data.build_fn thdb info.name
      with err -> add_error "Failed to rebuild theory" [info.name] err
    in 
    let thy = 
      try get_thy db info.name 
      with err -> 
	add_error "Failed to rebuild theory. Theory not in database." 
	  [info.name] err
    in 
    let build_aux() = 
      test_protection (Theory.get_name thy) 
	info.prot (Theory.get_protection thy);
      check_build thdb db thy;
      set_curr db thy
    in
    try build_aux()
    with err -> 
      add_error "Failed to rebuild theory. Can't make theory current." 
	 [info.name] err

  (** [apply_fn db thy_fn thy]: Apply [thy_fn] to the contents of
      theory [thy] in scope [mk_scope db]. Ignores all errors.  *)
  let apply_fn db thy_fn thy =
    try thy_fn db (Theory.contents thy) 
    with _ -> ()

  (** [check_theory info thy]: Run tests on theory.  For each theory
      [thy] named in [parents]: - Ensure that the date of [thy] is no
      more than [info.date] - Ensure that the protection of [thy] is
      set to [info.prot].  *)
  let check_theory info thy=
    let name = info.name 
    and tyme = info.date
    in 
    test_date name tyme (Theory.get_date thy);
    test_protection name info.prot (Theory.get_protection thy)

  (** [check_parents db info parents]: Check parents loaded by a
      theory.  For each theory [thy] named in [parents]: - Ensure that
      the date of [thy] is no more than [info.date] - Ensure that the
      protection of [thy] is set to [info.prot].  *)
  let check_parents db info parents =
    let rec check_aux ps =
      match ps with
	| [] -> ()
	| x::xs -> 
	  let thy = get_thy db x
	  in 
	  check_theory info thy;
	  check_aux xs
    in 
    check_aux parents

  (** [load_theory thdb name data]: Load the theory named [name] into
      database [thdb]. Also load the parents of the theory and applies
      the functions [data.thy_fn] to each loaded theory.

      Makes the newly loaded theory the current theory.
  *)
  let rec load_theory thdb data info =
    let name = info.name
    and childn = info.childn
    in 
    let _ =
      try check_importing info name
      with err -> add_error "Failed to load theory" [name] err
    in 
    if is_loaded name thdb
    then 
      let thy=get_thy thdb name in 
      let new_info = 
        mk_full_info name (Some (Theory.get_date thy)) (Some true) childn
      in 
      let db1 =
	load_parents thdb data (info_add new_info name)
	  (Theory.get_parents thy)
      in 
      set_curr db1 thy
    else 
      let load_attempt = Lib.try_app (load_thy info data) thdb
      in 
      match load_attempt with 
	| None -> (** Loading from file failed, try to rebuild. *)
	  build_thy info data thdb
	| Some(saved_thy) -> 
	  let sparents = Theory.saved_parents saved_thy
	  and sdate = Theory.saved_date saved_thy
	  in 
	  let sinfo = mk_full_info name (Some sdate) (Some true) childn in 
	  let db1 = load_parents thdb data (info_add sinfo name) sparents in 
	  let parents_ok = Lib.try_app (check_parents db1 sinfo) sparents
	  in
	  match parents_ok with
	    | None -> (** Parents failed to load, try to rebuild **)
	      build_thy info data thdb
	    | Some _ ->  (** Parents loaded succesfully **)
	      let thy = Theory.from_saved (mk_scope db1) saved_thy in 
	      let db2 = add_thy db1 thy in 
	      let db3 = set_curr db2 thy
	      in 
	      apply_fn db3 data.thy_fn thy;
	      db3
  (** [load_parents db data name tyme ps imports]: Load the theories
      with names in [ps] as parents of theory named [name] into
      database [db]. Each parent must be no younger then the date
      given by [tyme].  *)
  and 
      load_parents db bundle info ps =
    let tyme = info.date
    and prot = info.prot
    and childn = info.childn
    in 
    match ps with 
      | [] -> db
      | x::xs ->
	let db1 = 
	  load_theory db bundle 
	    (mk_full_info x tyme prot childn)
	in 
	load_parents db1 bundle info xs

  (*
   * Toplevel functions 
   *)

  let make_current db data thy = 
    let ps = Theory.get_parents thy
    and name = Theory.get_name thy
    and tyme = Theory.get_date thy
    and prot = true
    in 
    let info = info_add (mk_info name (Some tyme) (Some prot)) name in 
    let db1 = load_parents db data info ps
    in 
    set_current db1 thy  

  let load db data info =
    let name = info.name in 
    let db1 = load_theory db data info in 
    let thy = get_thy db1 name
    in 
    set_current db1 thy

end      

