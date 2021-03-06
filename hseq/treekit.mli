(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Balanced and arbitrary trees

    A tree is built from less-than (<) and equality ( = ) relations. Each
    node of the tree is a list of items whose indices are equal under
    the less-than relation (not (x < y) and not (y < x)). The equality
    gives the exact match for an item in the list.

    The simplest trees, {!Treekit.SimpleTree}, use [Pervasive.compare]
    for both less-than and equality and behave like a standard
    implementation of balanced trees.
*)

(** Comparison relations and index type used to build a tree. *)
module type TreeData =
sig
  type key
  (** Type of keys by which data is indexed. *)

  val compare: key -> key -> Order.t
(** [compare x y]: Compare [x] and [y], returning their order. *)
end

(** {5 Trees} *)

(** The type of trees *)
module type TreeType =
sig

  type key
  (** Type of keys by which data is indexed. *)
  val compare: key -> key -> Order.t

  type ('a)t

  val empty:  'a t
  (** The empty tree. *)

  val add: 'a t -> key -> 'a -> 'a t
  (** [add tr k d]: Add binding of [d] to [k] in tree [tr].  Previous
      bindings to [k] are hidden but not removed.  *)

  val replace: 'a t -> key -> 'a -> 'a t
  (** [replace tr k d]: Replace binding of [k] with [d] in tree [tr].
      Adds the binding even if [k] is not already bound in [tr].  *)

  val find: 'a t -> key -> 'a
  (** [find tree key]: Finds the current binding of [key] in [tree]. *)

  val mem: 'a t -> key -> bool
  (** [mem tree key]: Test whether [key] is bound in [tree].  *)

  val delete: 'a t -> key -> 'a t
  (** [delete tree key]: Remove the data currently bound to [key] in
      [tree].  Does nothing if key is not in tree.  *)
  val remove: 'a t -> key -> 'a t

  val iter: (key -> 'a -> unit) -> 'a t -> unit
  (** [iter tree fn]: Apply [fn] to the data bound to each key.  Only
      the current key bindings are used.  *)

  val fold: (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  (** [fold tree fn]: Apply [fn] to the data bound to each key.  Only
      the current key bindings are used.  *)

  val to_list: 'a t -> (key * 'a) list
(** [to_list tree]: Return a list of the (lists of) elements in the
    tree, in descending order.
*)

end

(** Trees *)
module Tree:
  functor (A: TreeData) -> (TreeType with type key = A.key)

(** {5 Balanced trees} *)

module type BTreeType = TreeType

module BTree:
  functor (A: TreeData) -> (BTreeType with type key = A.key)

(** Standard library maps. *)
module MapTree:
  functor (A: TreeData) -> (TreeType with type key = A.key)

(** {5 Simple Trees}

    Trees ordered by [Stdlib.compare]. Example: a balanced tree
    indexed by strings is constructed by [SimpleTree (struct type key
    = string end)].
*)

(** The type of the index. *)
module type Data =
sig
  type key
end

(** Balanced trees, ordered by [Stdlib.compare] *)
module type SimpleTreeType = TreeType

(** Balanced Trees indexed by type A.key *)
module SimpleTree:
  functor (A:Data) -> (SimpleTreeType with type key = A.key)

(** Balanced Trees indexed by strings *)
module StringTree: SimpleTreeType with type key = string
