(* 
   Settings:
   Put installation dependent settings in here 
*)


(* File and directory settings *)
(* 
   base_dir:
   base directory of installation.
   all other directories are set relative to this
*)

val base_dir: string

(* 
   make_filename f: make file name f relative to the base directory
*)
val make_filename: string -> string

(* 
   init_file: name of file to execute to initialise the system
   the file name used will be contructed as base_dir^init_file
*)
   
val init_file: string

(* 
   File suffixes:
   suffixes to add to a name to form a file name
*)

(* thy_suffix: suffix of stored theories *)
val thy_suffix: string
