(*----
  Name: hseqc.ml
  Copyright Matthew Wahab 2005-2016
  Author: Matthew Wahab <mwb.cde@gmail.com>

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

(**
   hseqc: Support for compiling against the HSeq library.

   usage: hseqc {hseqc options} -- {ocamlc options}

   Example:

   Compile test.ml using the native-code compiler
     hseqc -o test test.ml

   Compile test.ml using the native-code compiler
     hseqc --native -- -o test test.ml
*)

(** [bindir]: The hseq binary directory *)
let bindir = Hseqc_config.value_BinDir

(** [includedir]: location of the hseq libraries *)
let includedir = Hseqc_config.value_LibDir

(** Start of script *)

(** Default values *)

(** [hseq_include]: The location of the hseq libs *)
let hseq_include = [includedir]

(** [hsq_libs]: The hseq libraries *)
let hseq_libs = ["hseq"]

(** [hseq_quoter]: The hseq quotation expander *)
let hseq_quoter = "tpquote.cma"

(** [pp_include]: Includes for the preprocessor *)
let pp_include =
  String.concat " " (List.map (fun x -> "-I "^x) hseq_include)

(** [hseq_pp]: The hseq preprocessor *)
let hseq_pp =
  String.concat " "
  ["camlp4o"; pp_include; "q_MLast.cmo"; hseq_quoter; "pa_extend.cmo"]

(** [ocamlc_include]: include directories for the ocamlc compiler (in order)*)
let ocamlc_include = ["+camlp4"]

(** [ocamlc_libs]: standard librariess for the ocamlc compiler (in order)*)
let ocamlc_libs = ["nums"; "unix"]

(** Functions *)

(** [error s]: exit print error message [s] *)
let error s =
  Format.printf "@[hseqc: %s@]@." s;
  exit (-1)

(**
  [program n]: Make the program name [n].
  On Win32, this adds .exe to [n].
  On other systems this is just [n].
*)
let program name =
  let suffix =
    if (Sys.os_type = "Win32")
    then ".exe"
    else ""
  in
    name^suffix

(** [bytelib n]: Make the name of byte-code library [n] *)
let bytelib n =
  n^".cma"

(** [natlib n]: Make the name of native-code library [n] *)
let natlib n =
  n^".cmxa"

(** [has_program name]: Test whether program [name] is available *)
let has_program s =
  Sys.command s = 0

let ocamlc = "ocamlc"
let ocamlcopt = "ocamlc.opt"
let ocamlopt = "ocamlopt"
let ocamloptopt = "ocamlopt.opt"

(** [has_ocamlc]: Test for [ocamlc]*)
let has_ocamlc = has_program ocamlc

(** [has_ocamlcopt]: Test for [ocamlc.opt]*)
let has_ocamlcopt = has_program ocamlcopt

(** [has_ocamlopt]: Test for [ocamlopt]*)
let has_ocamlopt = has_program ocamlopt

(** [has_ocamloptopt]: Test for [ocamlopt.opt]*)
let has_ocamloptopt = has_program ocamloptopt

(** [byte_compiler]: The byte-code compiler *)
let byte_compiler =
  if has_ocamlcopt
  then program ocamlcopt
  else program ocamlc

(** [nat_compiler]: The native-code compiler *)
let nat_compiler =
  if has_ocamloptopt
  then program ocamloptopt
  else program ocamlopt


(** Argument processing *)

type options =
    {
      mutable info: bool;
      mutable native: bool;
      mutable verbose: bool;
      mutable lib: bool;
      mutable header: bool;
      mutable pp: bool;
    }

(** Initial option values *)
let options =
  {
    info = false;
    native = false;
    verbose = false;
    lib = false;
    header = false;
    pp = false;
  }

let set_info option v () =
   option.info <- v

let set_native option v () =
   option.native <- v

let set_verbose option v () =
   option.verbose <- v

let set_lib option v () =
   option.lib <- v

let set_header option v () =
   option.header <- v

let set_pp option v () =
   option.pp <- v

(** The command arguments *)

let other_args = ref []
let add_other arg =
  other_args := arg::(!other_args)

let add_trapped opt arg =
  let str = String.concat " " [opt; arg]
  in
    add_other str

let cli_args =
  Arg.align
  [
    ("--native", Arg.Unit (set_native options true),
     " native-code compilation");
    ("--verbose", Arg.Unit (set_verbose options true),
     " print the executed command");
    ("--pp", Arg.Unit (set_pp options true),
     " print preprocessor information");
    ("--lib", Arg.Unit (set_lib options true),
     " print library information");
    ("--header", Arg.Unit (set_header options true),
     " print headers directory information");
    ("--info", Arg.Unit (set_info options true),
     " print all information");
    ("-o", Arg.String (add_trapped "-o"),
     "<file> pass option \"-o <file>\" to the compiler");
    ("-c", Arg.String (add_trapped "-c"),
     "<file> pass option \"-c <file>\" to the compiler");
    ("--", Arg.Rest (add_other),
     "<rest> pass remaining options directly to the compiler");
  ]

let usage_msg =
  String.concat ""
  [
    "hseqc: Support for compiling with HSeq\n";
    "  usage: hseqc {hseqc options} -- {compiler options} {source files}\n";
    "hseqc options:"
  ]

let anon_fun = add_other
(*
let anon_fun _= raise (Arg.Bad "unknown option")
*)

let parse_args () = Arg.parse cli_args anon_fun usage_msg

(** Main *)

let add x y = x^y

let make_pp() = hseq_pp

let make_header () =
  let headers =
    String.concat " "
      (List.map (add "-I ") ocamlc_include)
  in
  let hseq_headers =
    String.concat " "
      (List.map (add "-I ") hseq_include)
  in
    String.concat " " [headers; hseq_headers]

let make_byte_libs() =
  let libs =
    String.concat " "
      (List.map bytelib ocamlc_libs)
  in
  let hseqlib =
    String.concat " "
      (List.map bytelib hseq_libs)
  in
    String.concat " " [libs; hseqlib]

let make_nat_libs() =
  let libs =
    String.concat " "
      (List.map natlib ocamlc_libs)
  in
  let hseqlib =
    String.concat " "
      (List.map natlib hseq_libs)
  in
    String.concat " " [libs; hseqlib]

let make_libs() =
  if options.native
  then make_nat_libs()
  else make_byte_libs()

let make_byte_info () =
  let pp =
    "-pp \""^(make_pp())^"\""
  in
    String.concat " "
      [pp; make_header(); make_byte_libs()]

let make_nat_info () =
  let pp =
    "-pp \""^(make_pp())^"\""
  in
    String.concat " "
      [pp; make_header(); make_nat_libs()]

let make_info () =
  if (options.native)
  then make_nat_info()
  else make_byte_info()

let print_info info args =
  let args_str =
    String.concat " " args
  in
  let info_str =
    String.concat " " [info; args_str]
  in
  (Format.printf "@[%s@]@." info_str); 0

let compile info args =
  let _ =
    if args = []
    then
      (Arg.usage cli_args usage_msg;
       error "Nothing to do")
    else 0
  in
  let compiler =
    if (options.native)
    then nat_compiler
    else byte_compiler
  in
  let arg_string = String.concat " " args
  in
  let command =
    String.concat " "
      [compiler; info; arg_string]
  in
    (if options.verbose
    then Format.printf "@[%s@]@." command
    else ());
    Sys.command command

let main() =
  let args = List.rev (!other_args)
  in
  if (options.info)
  then print_info (make_info()) args
  else
    if options.pp
    then print_info (make_pp()) []
    else
      if options.lib
      then print_info (make_libs()) []
      else
        if options.header
        then print_info (make_header()) []
        else
          compile (make_info()) args

let _ =
  parse_args();
  let ret = main()
  in
  exit ret