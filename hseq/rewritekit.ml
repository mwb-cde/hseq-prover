(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(** Planned Rewriting  *)

exception Stop of exn
exception Quit of exn

(***
* Rewriting plans
***)

(** The specification of a rewriting plan *)
type ('k, 'a)plan =
    Node of (('k, 'a) plan) list
      (** The rewriting plan for a node *)
  | Keyed of 'k * ((('k, 'a) plan) list)
      (** The rewriting plan for a specified kind of node *)
  | Rules of 'a list
      (** The rules to use to rewrite the current node *)
  | Subnode of (int * ('k, 'a)plan)
      (** The rewriting plan for a branch of the node *)
  | Branches of (('k, 'a) plan) list
      (** The rewriting plans for all branches of the node *)
  | Skip  (** The null rewriting plan *)

(**
    A rewrite plan specificies how a node [n] is to be rewritten in
    terms of the rules to be applied to each sub-node [n].

    Plans are keyed to particular kinds of node. If a plan [p] is
    applied to node [n] which does not have the right key, the
    sub-nodes of [n] are searched for a node with the right key. The
    search is top-down and left-right and the test on keys uses
    predicate [A.is_key]. It is therefore possible to direct the
    search using plans and an appropriate value for [A.is_key].

    Rules for rewriting node [n] by plan [p], starting with the
    initial data [d]:

    {b [p=Node(ps)]}: Rewrite node [n] with plans [ps] and data
    [d]. The plans [ps] are used in order: if [ps = [x1; x2;
    .. ]], node [n] is rewritten with plan [x1] and data [d] to
    get node [n'] and data [d']. Plan [x2] is then used to
    rewrite node [n'], with data [d'], to get node [n''] and data
    [d''], and so on until all plans in [ps] have been used.

    {b [p=Keyed(k, ps)]}: If [is_key k n]: for each [x] in [ps],
    rewrite [n] with [x] and [d] to get new node [n'] and data [d'].

    If [not(is_key k n)]: Let [ns] be the subnodes of [n].  Try
    rewriting each [x] in [ns], starting with the left-most, and
    return the result of the first which does not raise
    [Not_found]. If all subnodes in [ns] fail with [Not_found] then
    raise [Not_found].

    {b [p=Rules rs]}: Rewrite node [n] with each rule in [rs] in
    order. If either [matches] or [subst] raise [Stop] then stop
    rewriting and return the result so far. If either [matches] or
    [subst] raise [Quit e] then abandon the attempt and fail, raising
    [e].

    {b [p=Subnode(i, p)]}: Rewrite the [i]'th subnode of [n] (starting
    with the left-most being [0]) using plan [p].

    {b [p=Branches(ps)]}: Rewrite each subnode of [n] with the
    matching plan in [ps]. If there are more plans then subnodes,
    ingore the extra plans. If there are more subnodes, use the extra
    sub-nodes unchanged.

    {b [p=Skip]}: Do nothing, succeeding quietly.}
*)

(*** Functions on plans ***)

let rec mapping (f:('a -> 'b)) pl =
  match pl with
      Node ps ->
        Node (List.map (mapping f) ps)
    | Keyed (k, ps) ->
        Keyed (k, List.map (mapping f) ps)
    | Subnode(i, p) ->
        Subnode (i, mapping f p)
    | Branches(ps) ->
        Branches(List.map (mapping f) ps)
    | Rules rs -> Rules (List.map f rs)
    | Skip -> Skip

let iter f plan =
  let rec iter_aux pl =
    match pl with
        Node ps -> ((List.iter iter_aux ps); f pl)
      | Keyed (k, ps) -> (List.iter iter_aux ps; f pl)
      | Subnode(i, p) -> iter_aux p; f (Subnode(i, p))
      | Branches(ps) -> List.iter iter_aux ps; f (Branches ps)
      | _ -> f pl
  in
    iter_aux plan

(***
    * Rewriter data
***)

module type Data =
sig
  type node  (** Nodes to be rewritten *)
  type key   (** Node identifiers, for use in a plan *)
  type data  (** Data used in matching/substitution *)
  type substn (** The substition generated by a match *)
  type rule  (** Rewrite rules *)

  val key_of : node -> key
    (** [key_of n]: Get an identifier for [n] *)

  val is_key : key -> node -> bool
    (** [is_key k n]: Test whether node [n] matches key [k] *)

  val num_subnodes : node -> int
    (** [num_subnodes n]: The number of subnodes of [n]. *)

  val subnodes_of : node -> node list
    (** [subnodes_of n]: Get the list of subnodes of [n] *)

  val set_subnodes : node -> node list -> node
    (**
        [set_subnodes n xs]: Set subnodes of [n] to [xs], replacing the
        [i]'th subnode of [n] with the [i]'th element of [xs]. Fails with
        [Quit] if the number of new nodes in [xs] is not the same as the
        number of subnodes.
    *)

  val get_subnode : node -> int -> node
    (**
        [get_subnode n i]: Get subnode [i] of node [n]. Subnodes are
        counted from the left and starting from [0]
    *)

  val set_subnode : node -> int -> node -> node
    (**
        [set_subnode n i x]: set subnode [i] of [n] to [x]. Subnodes are
        counted from the left and starting from [0]
    *)

  val matches :
    data -> rule -> node -> (data * substn)
    (** [matches data r n]: Try to match node [n] with rule [r].

        [data] is extra data to pass to [matches]. [r] is the rewrite rule
        being tried.  Returns [(new_data, env)] where [new_data] is to be
        passed on to the next application of [matches] or [subst] and [env]
        is the substitution to be passed to [subst].
    *)

  val subst :
    data -> rule -> substn -> (data * node)
    (** [subst data env rhs]: Apply the substitutions in [env] to rule [r]
        to get a new node.

        [data] is extra data to pass to [subst], usually generated from the
        last invocation of [matches]. [env] is the substitution generated
        from an invocation of [matches] and [r] is the matched rewrite
        rule.  Returns [(new_data, n)] where [new_data] is to be passed on
        to the next application of [matches] or [subst] and [n] is the
        result of the substititution
    *)

  val add_data : data -> node -> data
    (** [add_data data n]: Add to data from node [n]. *)


  val drop_data : (data * node) -> (data * node) -> data
    (**
        [drop_data (d1, n1) (d2, n2)]: Drop data generated from a
        node. Called for each node before all rewriting of the node has
        completed. Node [n1] is the original node and [d1] is the data
        generated by calling [add_data n1]. Node [n2] and data [d2] are the
        result of rewriting [n1] using data [d1].
    *)
end


(***
    * The generic rewriter
***)

module type T =
sig
  (***
       The type of a specific rewriter module.
  ***)

  (*** Term data ***)

  type data
  type rule
  type node
  type substn
  type key

  val is_key : key -> node -> bool
  val matches :
    data -> rule -> node -> (data * substn)
  val subst :
    data -> rule -> substn -> (data * node)
  val subnodes_of : node -> node list
  val set_subnodes : node -> node list -> node
  val get_subnode : node -> int -> node
  val set_subnode : node -> int -> node -> node
  val add_data : data -> node -> data
  val drop_data : (data * node) -> (data * node) -> data

  (*** Rewriting functions ***)

  val rewrite_first :
    data -> (key, rule)plan -> node list
    -> (data * (node list))
  val rewrite_branches :
    data -> node list -> (key, rule)plan list
    -> (data * (node list))
  val rewrite_rules :
    (data * node) -> rule list -> (data * node)
  val rewrite_aux :
    (data * node) -> (key, rule)plan
    -> (data * node)

  (*** Toplevel rewrite function ***)

  val rewrite :
    data -> (key, rule)plan -> node -> (data * node)
end

(** Instantiate the generic rewriter with data **)
module Make =
  functor (A : Data) ->
struct

  type rule = A.rule
  type node = A.node
  type data = A.data
  type substn = A.substn
  type key = A.key

  let is_key = A.is_key
  let matches = A.matches
  let subst = A.subst
  let subnodes_of = A.subnodes_of
  let set_subnodes = A.set_subnodes
  let get_subnode = A.get_subnode
  let set_subnode = A.set_subnode
  let add_data = A.add_data
  let drop_data = A.drop_data

  let rec rewrite_first data p lst =
    let rec repl_aux ls rslt =
      match ls with
          [] -> raise Not_found
        | (x::xs) ->
            (try
               let (data1, x1) = rewrite_aux (data, x) p
               in
                 (data1, List.rev_append xs (x1::rslt))
             with
                 Quit err -> raise (Quit err)
               | Not_found -> repl_aux xs (x::rslt)
               | _ -> (data, List.rev_append  xs (x::rslt)))
    in
    let (data1, ts) = repl_aux lst []
    in
      (data1, List.rev ts)
  and
      rewrite_rules (data, node) rules =
    match rules with
        [] -> (data, node)
      | (r::rls) ->
          (try
             (let (data1, sb) = matches data r node
              in
              let (data2, nt) = subst data1 r sb
              in
                rewrite_rules (data2, nt) rls)
           with
               Quit err -> raise (Quit err)
             | Stop err -> (data, node)
             | _ -> (data, node))
  and
      rewrite_branches data nodes plans =
    let rec repl_aux d (nds, pls) rslt =
      match (nds, pls) with
          ([], _) -> (d, List.rev rslt)
        | (ns, []) -> (d, List.rev (List.rev_append ns rslt))
        | ((n::ns), (p::ps)) ->
            (try
               let (d1, x1) = rewrite_aux (d, n) p
               in
                 repl_aux d1 (ns, ps) (x1::rslt)
             with
                 Quit err -> raise (Quit err)
               | Stop _ -> (d, List.rev (List.rev_append ns (n::rslt)))
               | _ -> (d, List.rev (List.rev_append ns (n::rslt))))
    in
      repl_aux data (nodes, plans) []
  and
      rewrite_aux (data, node) plan =
    let data1 = add_data data node
    in
    let (data2, node2) =
      match plan with
          Node(ps) ->
            List.fold_left rewrite_aux (data1, node) ps
        | Keyed(k, ps) ->
            if (is_key k node)
            then
              List.fold_left rewrite_aux (data1, node) ps
            else
              let (data3, subnodes1) =
                rewrite_first data1 plan
                  (subnodes_of node)
              in
                (data3, set_subnodes node subnodes1)
        | Subnode(i, p) ->
            let (data3, b) =
              rewrite_aux (data1, get_subnode node i) p
            in
              (data3, set_subnode node i b)
        | Branches(ps) ->
            let (data3, subnodes1) =
              rewrite_branches data1 (subnodes_of node) ps
            in
              (data3, set_subnodes node subnodes1)
        | Rules rls ->
            rewrite_rules (data1, node) rls
        | Skip -> (data1, node)
    in
    let data3 = drop_data (data, node) (data2, node2)
    in
      (data3, node2)

  let rewrite data plan node =
    rewrite_aux (data, node) plan

end
