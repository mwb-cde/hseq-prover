(*----
  Copyright (c) 2024 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
  ----*)

(** ListSeq: Sequences that can be used lists.

    A ListSeq is able to be queried repeatedly, a new element is only
    generated once and remembered for subsequent queries.
*)

(** The type of list sequences *)
type ('a)t

val is_empty: ('a)t -> bool
val uncons: ('a)t -> ('a * ('a)t)option

(** [push_front l s] Push the list of element [l] to the front of the sequence *)
val push_front: ('a)list -> ('a)t -> ('a)t

(** [first n s] Get and remove the first [n] elements. Returns as many
    elements as are available up to [n].  *)
val first: int -> ('a)t -> (('a)list * ('a)t)

(** [look n s] Get the first [n] elements but don't remove them. Returns as many
    elements as are available up to [n].  *)
val look: int -> ('a)t -> (('a)list * ('a)t)

(** [drop n s] Drop the first [n] elements from [s] *)
val drop: int -> ('a)t -> ('a)t

(** [accept s] Drop the first element from [s] *)
val accept: ('a)t -> ('a)t

(** [of_fun fn first] Make a sequence from fun [fn], using [first] as the first
    argument. [fn] should return a pair [(r, next)] where r is [None] for the
    end of input or [Some(x)] to return value [x]. [next] is the argument to be
    passed to [fn] to generate the next value. The first element in the sequence
    is generated by [fn first].  *)
val of_fun: ('b -> ('a * 'b)option) -> 'b -> ('a)t

(** [of_list lst] Make a sequence from list [lst] *)
val of_list: ('a)list -> ('a)t

(** [of_string str] Make a sequence from string [str] *)
val of_string: string -> (char)t
