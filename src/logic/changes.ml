  (*----
    Name: changes.mli
    Copyright M Wahab 2010
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


  (** {7 Changes to a goal} 

      The changes made to a goal by a tactic are recorded as data
      embedded in the goal. A tactic can access the data by reading the
      [changes] field of the goal.
  *)

  (** The record holding information generated by tactics. *)
type t = 
    { 
      goal_tags: Tag.t list; 
        (** new sub-goals produced by the tactic. *) 
      asm_tags: Tag.t list;
        (** new assumption produced by the tactic. *)
      cncl_tags: Tag.t list;
        (** new conclusions produced by the tactic. *)
      term_tags: Basic.term list
      (** new constants produced by the tactic. *)
    }

let empty () = 
  { goal_tags = []; asm_tags = []; cncl_tags = []; term_tags = [] }

let make gs hs cs ts = 
  { goal_tags = gs; asm_tags = hs; cncl_tags = cs; term_tags = ts }

let goals l = l.goal_tags
let aforms l = l.asm_tags
let cforms l = l.cncl_tags
let terms l = l.term_tags
let dest l = (goals l, aforms l, cforms l, terms l)

let add r gs hs cs ts =
  make (gs@r.goal_tags) (hs@r.asm_tags) (cs@r.cncl_tags) (ts@r.term_tags)

let rev_append l r =
  make 
    (List.rev_append l.goal_tags r.goal_tags) 
    (List.rev_append l.asm_tags r.asm_tags)
    (List.rev_append l.cncl_tags r.cncl_tags)
    (List.rev_append l.term_tags r.term_tags)

let rev r =
  make 
    (List.rev r.goal_tags) 
    (List.rev r.asm_tags)
    (List.rev r.cncl_tags)
    (List.rev r.term_tags)

let combine l r =
  rev_append (rev l) r

let flatten l = 
  let rec flatten_aux lst sum =
    match lst with
      | [] -> rev sum
      | (chng::rest) -> flatten_aux rest (rev_append chng sum)
  in
  flatten_aux l (empty())
