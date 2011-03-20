(*----
 Name: setLib.mli
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

(*
   setLib.mli:

   Support code for setScript.ml.

   Adds a parser and printer for set terms.

   Parse and print [SET (%x: P)] as [{x: P}].

   Parse [{} ] as [empty].  The standard printer handles the empty set
   correctly.

   compile with [compile [] "setLib.mli"; compile [] "setLib.ml"]
*)

open HSeq

val set_thy: string
(**
   [set_thy]: The name of the theory of sets.
*)

val set_id : Hident.t
(**
   [set_id] The identifier of the set constructor
*)

val set_data:(Printer.fixity* int)
(**
   [set_data] The precedence and fixity of the set identifier 
*)

(** 
   [empty_id] The identifier of the set constructor

   [empty_data] PP data for the empty set.
*)
val empty_id : Hident.t
val empty_data:(Printer.fixity* int)


module SetPP:
    sig
      val ocb_sym: string
      val ccb_sym: string

      val set_parser: 
	  unit 
	-> (Grammars.parser_info -> Pterm.t Parser.phrase)
      val set_printer : 
	  unit 
	-> Printer.ppinfo -> (Printer.fixity * int)
	  -> (Basic.term * Basic.term list) Printer.printer

end
