(*----
 Name: buildall.ml
 Copyright M Wahab 2005-2013
 Author: M Wahab  <mwb.cde@gmail.com>

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
   Build all theories.

   Run from a shell with 
   `hseq -I INCLUDEDIR buildall.ml`
   where INCLUDEDIR is the path to the hseq include directory.
   e.g. hseq -I ../include buildall
   or hseq -I HSEQ/include buildall
   where HSEQ is the hseq install directory.
*)

(** Open the theorem prover *)

open HSeq
open HSeq.Userlib

(** Add the source include directories *)
let _ = 
 Settings.include_dirs :=
    "../obj/lib":: (!Settings.include_dirs);;
    

(** Initialise hseq *)
#use "hseqstart.ml";;

(**
   This is part of the standard library so clear the theory base name.
*)
let buildall_base_name = 
  let str = 
    try Context.Thys.get_base_name(Global.context()) 
    with _ -> "Main"
  in 
  Global.set_context(Context.Thys.clear_base_name (Global.context())); 
  str;;

let _ = BaseTheory.builder (Context.empty())
(**
#use "0MainScript.ml";;
**)

(***

(* Reset the base theory name *)
let _ = Global.Thys.set_base_name buildall_base_name;;


***)
