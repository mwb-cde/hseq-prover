(*----
  Copyright (c) 2012-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

open Parser
open Lib.Ops

(** Default values. *)
module Default =
struct

  (** {6 File handling} *)

  let load f = Report.warning ("Context.load: Failed to load file "^f)
  let use silent f = Report.warning ("Context.use: Failed to use file "^f)

  (** {6 Theories} *)

  let empty_thy_name = Ident.null_thy
  let base_thy_name = "Main"
end

(** Global context *)

(** File handling functions *)
type file_t =
  {
    (** [load_file f]: Load a byte-code file [f] into memory. *)
    load_f: string -> unit;

    (** [use_file ?silent f]: Read file [f] as a script.  If
        [silent=true], do not report any information. *)
    use_f: bool -> string -> unit;

    (** [path]: List of directories to search for theories,
        libraries and scripts.*)
    path_f: string list;

    (** obj_suffix: List of possible suffixes for an object file. *)
    obj_suffix_f: string list;

    (** thy_suffix: Suffix for a theory file. *)
    thy_suffix_f: string;

    (** script_suffix: Suffix for a script file. *)
    script_suffix_f: string;
  }

let empty_file_t ()=
  {
    load_f = Default.load;
    use_f = Default.use;
    path_f = [];
    obj_suffix_f = [];
    thy_suffix_f = "";
    script_suffix_f = "";
  }

(** Theory data *)
type thy_t =
  {
    (** Name of the theory on which all user theories are based *)
    base_name_f: string option;

    (** The theory data base. *)
    thydb_f: Thydb.thydb;
  }

let empty_thy_t () =
  {
    base_name_f = None;
    thydb_f = Thydb.empty();
  }

(** Printer info *)
type pp_t =
  {
    pp_info_f: Printers.ppinfo;
  }

let empty_pp_t () =
  {
    pp_info_f = Printers.empty_ppinfo()
  }

(** Parser info *)
type parser_t =
  {
    parser_info_f: Parser.Table.t
  }

let empty_parser_t () =
  {
    parser_info_f = Parser.Table.empty Parser.Table.default_size
  }

(** Top-level context *)
type t =
  {
    (** File handling functions *)
    file_f: file_t;

    (** Theory data *)
    thys_f: thy_t;

    (** Pretty Printer *)
    pp_f: pp_t;

    (** Parsers *)
    parser_f: parser_t;

    (** A list of functions to invoke on a theory when it is added
        to the data-base. *)
    load_functions_f: (t -> Theory.contents -> t) list;

    (** Information needed for the theory database loader. *)
    loader_data_f: (t -> Thydb.Loader.data);

    (** Theorems caches *)
    thm_cache_f: (Ident.t, Logic.thm) Hashtbl.t;

    (** Scope attached to this context. *)
    scope_f: Scope.t;
  }

let empty() =
  {
    file_f = empty_file_t();
    thys_f = empty_thy_t();
    pp_f = empty_pp_t();
    parser_f = empty_parser_t();
    load_functions_f = [];
    loader_data_f = (fun _ -> Thydb.Loader.mk_empty());
    thm_cache_f = Hashtbl.create(13);
    scope_f = Scope.empty_scope();
  }

(** {6 Scoped contexts} *)

let scope_of sctxt = sctxt.scope_f
let context_of sctxt = sctxt
let set_scope sctxt scp =
  { sctxt with scope_f = scp }
let set_context sctxt ctxt = set_scope ctxt (scope_of sctxt)

(** {5 Accessor Functions} *)

(** {6 File handling} *)

let set_loader t f =
  let file1 = {t.file_f with load_f = f} in
  { t with file_f = file1 }

let loader t = t.file_f.load_f

let set_scripter t f =
  let file1 = {t.file_f with use_f = f} in
  { t with file_f = file1 }

let scripter t = t.file_f.use_f

let set_path t p =
  let file1 = {t.file_f with path_f = p} in
  { t with file_f = file1 }

let path t = t.file_f.path_f

let set_obj_suffix t sl =
  let file1 = {t.file_f with obj_suffix_f = sl} in
  { t with file_f = file1 }

let obj_suffix t = t.file_f.obj_suffix_f

let set_thy_suffix t sl =
  let file1 = {t.file_f with thy_suffix_f = sl} in
  { t with file_f = file1 }

let thy_suffix t = t.file_f.thy_suffix_f

let set_script_suffix t sl =
  let file1 = {t.file_f with script_suffix_f = sl} in
  { t with file_f = file1 }

let script_suffix t = t.file_f.script_suffix_f

(** {6 Theory handling} *)

let set_base_name t n =
  let thys1 = {t.thys_f with base_name_f = Some(n)}
  in
  { t with thys_f = thys1 }

let base_name t =
  match t.thys_f.base_name_f with
  | Some(x) -> x
  | _ -> raise Not_found

let has_base_name t =
  not ((t.thys_f.base_name_f) = None)

let clear_base_name t =
  let thys1 = {t.thys_f with base_name_f = None}
  in
  { t with thys_f = thys1 }

let thydb t = t.thys_f.thydb_f
let set_thydb t db =
  let thys1 = { t.thys_f with thydb_f = db } in
  let scp1 = Thydb.mk_scope db in
  let t1 = { t with thys_f = thys1 } in
  set_scope t1 scp1
let init_thydb ctxt = set_thydb ctxt (Thydb.empty())

  (** The current theory *)
let current ctxt = Thydb.current (thydb ctxt)
let current_name ctxt = Theory.get_name (current ctxt)
let set_current ctxt thy =
  let thydb = Thydb.set_current (thydb ctxt) thy in
  set_thydb ctxt thydb

let set_loader_data t lf =
  { t with loader_data_f = lf }

let loader_data t = t.loader_data_f t

let set_load_functions t fl =
  { t with load_functions_f = fl }

let load_functions t = t.load_functions_f

let add_load_functions t fl =
  let nl = List.rev_append (load_functions t) (List.rev fl) in
  set_load_functions t nl

(** Pretty printer information *)
let ppinfo t = t.pp_f.pp_info_f
let set_ppinfo t inf =
  let pinf = { pp_info_f = inf } in
  { t with pp_f = pinf }

(** Parser information *)
let parsers t = t.parser_f.parser_info_f
let set_parsers t inf =
  let ptable = { parser_info_f = inf } in
  { t with parser_f = ptable }

(** Theorem cache *)
let cache_thm t id thm =
  if not (Hashtbl.mem t.thm_cache_f id)
  then (Hashtbl.add t.thm_cache_f id thm; t)
  else t

let remove_cached_thm t id =
  if Hashtbl.mem t.thm_cache_f id
  then
    (Hashtbl.remove t.thm_cache_f id; t)
  else t

let lookup_thm sctxt id =
  let ctxt = context_of sctxt
  and scp = scope_of sctxt in
  let thm = Hashtbl.find ctxt.thm_cache_f id
  in
  if Logic.is_fresh scp thm
  then thm
  else
    begin
      ignore(remove_cached_thm ctxt id);
      raise Not_found
    end

let find_thm sctxt id fn =
  try lookup_thm sctxt id
  with Not_found ->
    begin
      let thm = fn sctxt in
      let _ = cache_thm (context_of sctxt) id thm
      in
      thm
    end

let empty_thy_name = Ident.null_thy
let anon_thy() = Theory.mk_thy empty_thy_name []

(*** Printer/parser support ***)
module PP =
struct

  (*** Terms ***)
  let add_term_parser ctxt pos id ph =
    set_parsers ctxt
      (Parser.add_term_parser (parsers ctxt) pos id ph)

  let remove_term_parser ctxt id =
    set_parsers ctxt
      (Parser.remove_term_parser (parsers ctxt) id)

  let get_term_pp ctxt id =
    Printers.get_term_info (ppinfo ctxt) id

  let add_term_pp ctxt id prec fixity repr =
    let ctxt0 =
      set_ppinfo ctxt
        (Printers.add_term_info (ppinfo ctxt) id prec fixity repr)
    in
    set_parsers ctxt0
      (Parser.add_token (parsers ctxt0) id
         (Lib.from_option repr (Ident.name_of id)) fixity prec)

  let add_term_pp_record ctxt id rcrd =
    let ctxt0 =
      set_ppinfo ctxt (Printers.add_term_record (ppinfo ctxt) id rcrd)
    in
    set_parsers ctxt0
      (Parser.add_token (parsers ctxt0) id
         (Lib.from_option rcrd.Printkit.repr (Ident.name_of id))
         (rcrd.Printkit.fixity)
         (rcrd.Printkit.prec))

  let remove_term_pp ctxt id =
    let (_, _, sym) = get_term_pp ctxt id in
    let ctxt0 =
      set_ppinfo ctxt (Printers.remove_term_info (ppinfo ctxt) id)
    in
    set_parsers ctxt0
      (Parser.remove_token (parsers ctxt0)
         (Lib.from_option sym (Ident.name_of id)))

  (*** Types ***)

  let add_type_parser ctxt pos id ph =
    set_parsers ctxt
      (Parser.add_type_parser (parsers ctxt) pos id ph)

  let remove_type_parser ctxt id =
    set_parsers ctxt
      (Parser.remove_type_parser (parsers ctxt) id)

  let get_type_pp ctxt id =
    Printers.get_type_info (ppinfo ctxt) id

  let add_type_pp ctxt id prec fixity repr =
    let ctxt0 =
      set_ppinfo ctxt
        (Printers.add_type_info (ppinfo ctxt) id prec fixity repr)
    in
    set_parsers ctxt0
      (Parser.add_type_token (parsers ctxt0)
         id (Lib.from_option repr (Ident.name_of id)) fixity prec)

  let add_type_pp_record ctxt id rcrd =
    let ctxt0 =
      set_ppinfo ctxt (Printers.add_type_record (ppinfo ctxt) id rcrd)
    in
    set_parsers ctxt0
      (Parser.add_type_token (parsers ctxt0) id
         (Lib.from_option rcrd.Printkit.repr (Ident.name_of id))
         (rcrd.Printkit.fixity)
         (rcrd.Printkit.prec))

  let remove_type_pp ctxt id =
    let (_, _, sym) = get_type_pp ctxt id in
    let ctxt0 =
      set_ppinfo ctxt (Printers.remove_type_info (ppinfo ctxt) id)
    in
    set_parsers ctxt0
      (Parser.remove_type_token (parsers ctxt0)
         (Lib.from_option sym (Ident.name_of id)))

  (*** User-defined printers ***)

  let get_term_printer ctxt id =
    Printers.get_term_printer (ppinfo ctxt) id

  let add_term_printer ctxt id printer =
    set_ppinfo ctxt (Printers.add_term_printer (ppinfo ctxt) id printer)

  let remove_term_printer ctxt id =
    set_ppinfo ctxt (Printers.remove_term_printer (ppinfo ctxt) id)

  let get_type_printer ctxt id =
    Printers.get_type_printer (ppinfo ctxt) id

  let add_type_printer ctxt id printer =
    set_ppinfo ctxt
      (Printers.add_type_printer (ppinfo ctxt) id printer)

  let remove_type_printer ctxt id =
    set_ppinfo ctxt
      (Printers.remove_type_printer (ppinfo ctxt) id)

  (** {7 Overloading} *)

  let overload_lookup ctxt sym =
    Parser.get_overload_list (parsers ctxt) sym

  let add_overload ctxt sym pos (id, ty) =
    let ppinf = Parser.add_overload (parsers ctxt) sym pos (id, ty)
    in
    set_parsers ctxt ppinf

  let remove_overload ctxt sym id =
    set_parsers ctxt
      (Parser.remove_overload (parsers ctxt) sym id)

  (** Lexer symbols *)
  let add_pp_symbol ctxt str sym =
    let tok = Lexer.Sym (Lexer.OTHER sym) in
    set_parsers ctxt
      (Parser.add_symbol (parsers ctxt) str tok)

  (** Functions to add PP information when a theory is loaded *)

  let add_id_record ctxt id rcrd =
    let pr, fx, repr =
      (rcrd.Printkit.prec, rcrd.Printkit.fixity, rcrd.Printkit.repr)
    in
    add_term_pp ctxt id pr fx repr

  let add_type_record ctxt id rcrd =
    let pr, fx, repr =
      (rcrd.Printkit.prec, rcrd.Printkit.fixity, rcrd.Printkit.repr)
    in
    add_type_pp ctxt id pr fx repr

  let add_theory_term_pp ctxt th =
    let thy_name = th.Theory.cname
    and pp_list = List.rev th.Theory.cid_pps
    in
    let add_pp ctxt0 (id, (rcrd, pos)) =
      let ctxt1 = add_id_record ctxt0 (Ident.mk_long thy_name id) rcrd in
      let repr = rcrd.Printkit.repr
      in
      match repr with
      | None -> ctxt1
      | Some(sym) ->
        try
          let id_record = List.assoc id th.Theory.cdefns in
          let id_type = id_record.Theory.typ in
          add_overload ctxt1 sym pos
            (Ident.mk_long thy_name id, id_type)
        with _ -> ctxt1
    in
    List.fold_left add_pp ctxt pp_list

  let add_theory_type_pp ctxt th =
    let thy_name = th.Theory.cname
    and pp_list = List.rev th.Theory.ctype_pps
    in
    let add_pp ctxt0 (id, rcrd) =
      add_type_record ctxt0 (Ident.mk_long thy_name id) rcrd
    in
    List.fold_left add_pp ctxt pp_list


  (*** Parsing ***)

  let catch_parse_error e a =
    try (e a)
    with
    | Parser.ParsingError x -> raise (Report.error x)
    | Lexer.Lexing _ -> raise (Report.error ("Lexing error: "^a))

  let overload_lookup ctxt s =
    let thydb s = Thydb.get_id_options s (thydb ctxt)
    and parserdb s = Parser.get_overload_list (parsers ctxt) s
    in
    try parserdb s
    with Not_found -> thydb s

  let expand_term scpd t =
    let scp, ctxt = (scope_of scpd, context_of scpd) in
    let lookup = Pterm.Resolver.make_lookup scp (overload_lookup ctxt)
    in
    let (new_term, env) = Pterm.Resolver.resolve_term scp lookup t
    in
    new_term

  let expand_type_names scpd t =
    Ltype.set_name (Scope.relaxed (scope_of scpd)) t

  let expand_typedef_names scpd t=
    match t with
    | Grammars.NewType (n, args) ->
      Defn.Parser.NewType (n, args)
    | Grammars.TypeAlias (n, args, def) ->
      Defn.Parser.TypeAlias(n, args, expand_type_names scpd def)
    | Grammars.Subtype (n, args, def, set) ->
      Defn.Parser.Subtype(n, args,
                          expand_type_names scpd def,
                          expand_term scpd set)

  let expand_defn scpd (plhs, prhs) =
    let rhs = expand_term scpd prhs
    and ((name, ty), pargs) = plhs
    in
    let args = List.map Pterm.to_term pargs
    in
    (((name, ty), args), rhs)

  let mk_term scp pt = expand_term scp pt

  let read scpd str =
    let ptable = parsers (context_of scpd) in
    mk_term scpd
      (catch_parse_error (Parser.read_term ptable) str)

  let read_unchecked ctxt x =
    let ptable = parsers ctxt in
    catch_parse_error
      (Pterm.to_term <+ (Parser.read_term ptable)) x

  let read_defn scpd x =
    let ptable = parsers (context_of scpd) in
    let (lhs, rhs) =
      catch_parse_error (Parser.read ptable defn_parser) x
    in
    expand_defn scpd (lhs, rhs)

  let read_type_defn scpd x =
    let ptable = parsers (context_of scpd) in
    let pdefn =
      catch_parse_error
        (Parser.read ptable Parser.typedef_parser) x
    in
    expand_typedef_names scpd pdefn

  let read_type scpd x =
    let ptable = parsers (context_of scpd) in
    expand_type_names scpd
      (catch_parse_error (Parser.read_type ptable) x)

  let read_identifier ctxt x =
    let ptable = parsers ctxt in
    catch_parse_error
      (Parser.read ptable Parser.identifier_parser) x
end

(** {5 File-Handling} *)

module Files =
struct
  let get_cdir () = Sys.getcwd ()

  let load_use_file ctxt f =
    try
      if List.exists (Filename.check_suffix f) (obj_suffix ctxt)
      then loader ctxt f
      else scripter ctxt false f
    with
    | Not_found -> Report.warning ("Can't find file "^f)
    | _ -> Report.warning ("Failed to load file "^f)

  (** {7 Paths} ***)

  let set_path = set_path
  let get_path = path
  let add_path ctxt x = set_path ctxt (x::(get_path ctxt))
  let remove_path ctxt x =
    let pth = get_path ctxt in
    set_path ctxt (List.filter (fun y -> x = y) pth)

  let init_thy_path ctxt =
    set_path ctxt ["."]

  let get_thy_path ctxt = path ctxt
  let add_thy_path ctxt x = add_path ctxt x
  let set_thy_path ctxt x = set_path ctxt x
  let remove_from_path ctxt x = remove_path ctxt x

  let init_paths ctxt = init_thy_path ctxt

  (*** Theory files ***)

  let file_of_thy ctxt th = th^(thy_suffix ctxt)
  let script_of_thy ctxt th = th^(script_suffix ctxt)

  let find_file f path =
    let rec find_aux ths =
      match ths with
      | (t::ts) ->
        let nf = Filename.concat t f in
        if Sys.file_exists nf
        then Some(nf)
        else find_aux ts
      | _ -> None
    in
    if Sys.file_exists f
    then f
    else
      let nf_opt = find_aux path in
      if nf_opt = None
      then raise Not_found
      else Lib.from_some nf_opt

  let find_thy_file ctxt f =
    try find_file (file_of_thy ctxt f) (get_thy_path ctxt)
    with Not_found -> raise (Report.error ("Can't find theory "^f))

  (** [load_thy_file info]: Load the file storing the theory named
      [info.name] with protection [info.prot] and date no later than
      [info.date]. Finds the file from the path [get_thy_path()].  *)
  let load_thy_file ctxt info =
    let test_protection prot b =
      match prot with
      | None -> true
      | (Some p) -> p && b
    in
    let test_date tym d =
      match tym with
      | None -> true
      | (Some tim) -> d <= tim
    in
    let name = info.Thydb.Loader.name
    and date = info.Thydb.Loader.date
    and prot = info.Thydb.Loader.prot
    in
    let thyfile = file_of_thy ctxt name in
    let thyload filename =
        if Sys.file_exists filename
        then
          let sthy = Theory.load_theory filename in
          if (test_protection prot (Theory.saved_prot sthy))
            && (test_date date (Theory.saved_date sthy))
          then sthy
          else raise Not_found
        else raise Not_found
    in
    let rec load_aux ths =
      match ths with
      | [] -> raise Not_found
      | (t::ts) ->
        let filename = Filename.concat t thyfile
        in
        try thyload filename
        with Not_found -> load_aux ts
    in
    try thyload thyfile
    with Not_found -> load_aux (get_thy_path ctxt)

  (** [load_use_theory thy]: Load or use each of the files named in
      theory [thy].  *)
  let load_use_theory_files ctxt thy =
    let files = thy.Theory.cfiles in
    let path = get_thy_path ctxt in
    let find_load f = load_use_file ctxt (find_file f path)
    in
    List.iter find_load files

  (*** Theory inspection functions ***)

  (** [default_load_function]: The default list of functions to call
      on a newly-loaded theory.  *)
  let default_load_functions =
    [
      load_use_theory_files;    (* load files *)
    ]

  let apply_thy_fns ctxt thylist =
    let thyfns = load_functions ctxt in
    let (uthylist, _) =
      List.fold_left
        (fun (lst, thyset) th ->
          if Lib.StringSet.mem (th.Theory.cname) thyset
          then (lst, thyset)
          else ((th::lst), Lib.StringSet.add (th.Theory.cname) thyset))
        ([], Lib.StringSet.empty)
        thylist
    in
    let rthylist = List.rev uthylist in
    let apply_thy_fn fnlist (ct0: t) (thy: Theory.contents) =
      List.fold_left (fun (ct: t) f -> f ct thy) ct0 fnlist
    in
    List.fold_left (apply_thy_fn thyfns) ctxt rthylist

  let load_theory_as_cur ctxt n =
    let (db, thylist) =
      Thydb.Loader.load (thydb ctxt)
        (loader_data ctxt)
        (Thydb.Loader.mk_info n None None)
    in
    let ctxt1 = set_thydb ctxt db in
    apply_thy_fns ctxt1 thylist

  let make_current ctxt thy =
    let db = thydb ctxt in
    let (db1, thylist) = Thydb.Loader.make_current db (loader_data ctxt) thy
    in
    let ctxt1 = set_thydb ctxt db1 in
    apply_thy_fns ctxt1 thylist

end
