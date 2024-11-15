(*----
  Copyright (c) 2005-2021 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(*
module Input =
struct

  exception Empty

  (** ['a seq]: Sequences of 'a, built up as function tail is called. *)
  type 'a seq =
      Nil | Cons of 'a * ('a seq ref)| Fun of (unit -> 'a)

  let make_seq fn =
    try Cons(fn(), ref(Fun fn))
    with Empty -> Nil

  let hd l =
    match l with
      | Nil -> raise Empty
      | Cons(d, _) -> d
      | Fun f -> failwith "Seq.hd"

  let tail l =
    match l with
      |	Nil -> raise Empty
      | Cons(_, t) ->
        (match !t with
          | Fun f -> let nt = make_seq f
                     in
                     t:=nt; nt
          | _ -> !t)
      | Fun f -> failwith "Seq.hd"

  let seq_is_empty l =
    match l with
      |	Nil -> true
      | _ -> false

  (*
   * Input Stream operations
   *)
  type 'a t = 'a seq
  let make fn=make_seq fn
  let is_empty inp=seq_is_empty inp

  (** [look inp]: Get first token from stream keep token in stream. *)
  let look inp = hd inp

  (** [accept inp]: Create a new stream which is exactly like [inp]
      except that first token is dropped. *)
  let accept inp = tail inp
end
*)

module Input =
struct
  type ('a)t = ('a)ListSeq.t

  let is_empty inp = ListSeq.is_empty inp

  let look n inp = ListSeq.look n inp
  let first n inp = ListSeq.first n inp
  let drop n inp = ListSeq.drop n inp
  let accept inp = ListSeq.accept inp

  let make = ListSeq.of_fun
end


(*
 * Symbol parsing and pretty printing attributes.
 *)
module Info =
struct
  type associativity = Nonassoc | Leftassoc | Rightassoc

  let non_assoc = Nonassoc
  let left_assoc = Leftassoc
  let right_assoc = Rightassoc

  type fixity = Nonfix | Prefix | Suffix | Infix of associativity
  let nonfix = Nonfix
  let infix a = Infix a
  let prefix = Prefix
  let suffix = Suffix

  let is_nonfix f = match f with Nonfix -> true | _ -> false
  let is_prefix f = match f with Prefix -> true | _ -> false
  let is_suffix f = match f with Suffix -> true | _ -> false
  let is_infix f = match f with Infix _ -> true | _ -> false

  let is_left_assoc a =
    match a with
      | Infix Leftassoc -> true
      | _ -> false

  let is_right_assoc a =
    match a with
      |	Infix Rightassoc -> true
      | _ -> false

  let is_non_assoc a =
    match a with
      | Infix Leftassoc -> false
      | Infix Rightassoc -> false
      | _ -> true

  let assoc_of a =
    match a with
      |	Infix x -> x
      | _ -> Nonassoc
end

(*
 * Parser tokens
 *)
module type TOKENS =
sig
  type tokens
  val matches: tokens -> tokens -> bool

  (** [string_of_token]: Used for error reporting only.  If necessary
      use [(fun x _ -> "")].  *)
  val string_of_token: tokens -> string
end

(*
 * Parser constructors
 *)
module type T =
sig

  exception ParsingError of string
  exception No_match

  type token
  type input = (token)Input.t
  type ('a)phrase = input -> ('a * input)

  val empty: ('a list)phrase
  val next_token: token phrase
  val error: string -> (token -> string) -> 'a phrase

  val get: (token -> bool) -> (token -> 'a) -> ('a)phrase
  val (!$): token -> token phrase
  val (!!): 'a phrase -> 'a phrase
  val (--): ('a)phrase -> ('b)phrase -> ('a*'b)phrase
  val (--%): ('a)phrase -> ('c)phrase -> ('c)phrase
  val (>>): ('a)phrase -> ('a -> 'b) -> ('b)phrase

  val optional: ('a)phrase -> ('a option)phrase
  val repeat: ('b)phrase -> ('b list)phrase
  val multiple: ('b)phrase -> ('b list)phrase
  val list0: ('a)phrase -> 'b phrase -> ('a list)phrase
  val list1: ('a)phrase -> 'b phrase -> ('a list)phrase

  val (//): 'a phrase -> 'a phrase -> 'a phrase
  val alt: ('b)phrase list -> ('b)phrase
  val named_alt: ('x, ('a -> ('b)phrase))Lib.assoc_list
    -> ('a -> ('b)phrase)
  val seq: ('b phrase) list -> ('b list)phrase
  val named_seq: ('x, ('a -> ('b)phrase))Lib.assoc_list
    -> ('a -> ('b list)phrase)

  val unop_prefix:
    ('a -> 'b) -> ('c)phrase -> ('a)phrase
    -> ('b)phrase
  val unop_suffix:
    ('a -> 'b) -> ('c)phrase -> ('a)phrase
    -> ('b)phrase
  val binop_left:
    ('a -> 'a -> 'a)
    -> ('b)phrase -> ('a)phrase
    -> ('a)phrase
  val binop_right:
    ('a -> 'a -> 'a)
    -> ('b)phrase -> ('a)phrase
    -> ('a)phrase

  type token_info =
      {
        fixity: Info.fixity;
        prec: int
      }

  val operators:
    (('a)phrase
     * (token -> token_info)
     * (token -> 'a -> 'a -> 'a)
     * (token -> 'a -> 'a))
    -> ('a) phrase

  val parse: ('a)phrase -> token -> input -> 'a
end

(*
 * Parser module contructor
 *)
module Make =
  functor (A: TOKENS) -> struct

    exception ParsingError of string
    exception No_match

    type token = A.tokens
    type input = (token)Input.t
    type ('a)phrase = input -> ('a * input)

    type token_info =
        {
          fixity: Info.fixity;
          prec: int
        }

    let matches = A.matches
    let empty inp = ([], inp)

    let get test fn inp =
      let (ts, inp1) = Input.look 1 inp in
      match ts with
      | [t] ->
         if test t
         then (fn t, Input.accept inp)
         else raise
                (ParsingError
                   ("Unexpected symbol: \""^(A.string_of_token t)^"\""))
      | _ -> raise
               (ParsingError "Unexpected input")

    let (!$) tok inp =
      get (fun t -> matches tok t) (fun t -> t) inp

    let next_token inp  =
      get (fun t -> true) (fun t -> t) inp

    let error msg tok_to_str inp =
      let str = (": "^msg) in
      try
        let (tok, _) = next_token inp
        in
        raise (ParsingError ("Error at "^(tok_to_str tok)^str))
      with _ -> raise (ParsingError str)

    let (//) ph1 ph2 =
      (fun toks ->
        try (ph1 toks)
        with ParsingError _ -> (ph2 toks))

    let (!!) ph toks =
      try (ph toks)
      with ParsingError m -> failwith m

    let (--) ph1 ph2 toks =
      let (x, toks2) = ph1 toks in
      let (y, toks3) = ph2 toks2
      in ((x, y), toks3)

    let (>>) ph f =
      (fun toks ->
        let (x, toks2) = ph toks
        in (f x, toks2))

    let rec alt phl toks =
      match phl with
        | [] -> raise (ParsingError "No alternative parsers")
        | (ph::phs) ->
          try ph toks
          with ParsingError _ -> (alt phs toks)

    let (--%) a ph toks =
      ((a -- (!!ph)) >> fun (_, x) -> x) toks

    let rec repeat ph toks =
      (((ph -- (repeat ph)) >> (fun (x, y) -> x::y))
       // empty) toks

    let rec multiple ph toks =
      ((ph -- (repeat ph)) >> (fun (x, y) -> x::y)) toks

    let list0 ph sep toks =
      (((ph -- (repeat (sep --% ph))) >> (fun (x, y) -> x::y))
       // empty) toks

    let list1 ph sep toks =
      ((ph -- (repeat (sep --% ph))) >> (fun (x, y) -> x::y)) toks

    let optional ph toks =
      try (ph >> (fun x->(Some x))) toks
      with ParsingError _ -> (None, toks)

    let rec named_alt phl inf toks =
      match phl with
        | [] -> raise (ParsingError "No alternative parsers")
        | (_, ph)::phs ->
          (try (ph inf) toks
           with ParsingError _ -> (named_alt phs inf toks))

    let seq phl inp =
      let rec seq_aux l r toks =
        match l with
          | [] -> (List.rev r, toks)
          | (ph::phs) ->
            let (x, toks1) = ph toks
            in
            seq_aux phs (x::r) toks1
      in
      match phl with
        | [] -> raise (ParsingError "No parsers in sequence")
        | _ -> seq_aux phl [] inp

    let named_seq phl info inp =
      let rec seq_aux l r toks =
        match l with
          | [] -> (List.rev r, toks)
          | (_, ph)::phs ->
            let (x, toks1) = ph info toks
            in
            seq_aux phs (x::r) toks1
      in
      match phl with
        | [] -> raise (ParsingError "No parsers in sequence")
        | _ -> seq_aux phl [] inp

  (*
   * Operators
   *)

    (** [unop_prefix f op ph]: Prefix unary operator.

        [op]: The parser for the operator.

        [ph]: The parser for the argument.

        [f]: The constructor for the resulting term.
    *)
    let unop_prefix f op ph toks =
      ((op -- ph) >> (fun (_, a) -> f a)) toks

    (** [unop_suffix f op ph]: Suffix unary operator.

        [op]: The parser for the operator.

        [ph]: The parser for the argument.

        [f]: The constructor for the resulting term.
    *)
    let unop_suffix f op ph toks =
      ((ph -- op) >> (fun (a, _) -> f a)) toks

    (** [binop_left f op ph]: Left associative binary operator

        [op]: The parser for the operator.

        [ph]: The parser for the arguments.

        [f]: The constructor for the resulting term.
    *)
    let binop_left f op ph toks =
      let pa ts =
        ((ph -- repeat (op --% ph))
         >> (fun (x, rest) -> x::rest)) ts
      in
      (pa >>
         (fun args ->
           match args with
             | (x::y::xs) -> List.fold_left f x (y::xs)
             | _ -> raise (ParsingError "binop_left"))) toks

    (** [binop_right]: right associative binary operator

        [op]: The parser for the operator.

        [ph]: The parser for the arguments.

        [f]: The constructor for the resulting term.
    *)
    let binop_right f op ph toks =
      let pa ts =
        ((ph -- repeat (op --% ph))
         >> (fun (x, rest) -> x::rest)) ts
      in
      (pa >>
         (fun args ->
           match (List.rev args) with
               (x::y::xs) ->
                 let cf y x = f x y
                 in
                 List.fold_left cf x (y::xs)
             | _ -> raise (ParsingError "binop_right"))) toks


    (* [operators (ph, info, binop, unaryop) inp]: Precedence parsing of
       binary and unary operators.

       [ph]: Parser for arguments to operators.

       [info]: Parsing attributes of tokens.

       [binop]: Constructors for tokens representing binary operands.

       [unop]: Constructors for tokens representing unary operands.
    *)
    let operators (ph, info, binop, unaryop) inp =
      (* [token_look inp]: Look at the token at the front of input
         [inp]. *)
      let token_look inp =
        let (toks, inp1) = Input.look 1 inp in
        match toks with
        | [tok] ->
           let inf = info tok
           in
           ((tok, inf), inp1)
        | [] -> raise (ParsingError "Unexpected end of input.")
        | (_::_) -> raise (ParsingError "Unexpected number of tokens")
      in
      (* [chunk prec inp]: Parser the argument to a binary operator. *)
      let rec chunk inp =
        let ((tok, inf), inp1) = token_look inp
        in
        if Info.is_prefix inf.fixity
        then list_prefix inf.prec tok (Input.accept inp1)
        else ph inp1
      and list_binary prec (x, inp) =
        if Input.is_empty inp
        then (x, inp)
        else
          let ((tok, inf), inp1) = token_look inp in
          if inf.prec < prec
          then (x, inp1)
          else
            if Info.is_suffix inf.fixity
            then
              list_binary prec
                (list_suffix inf.prec tok (x, Input.accept inp1))
            else
              if Info.is_right_assoc inf.fixity
              then
                list_binary prec
                  (list_right inf.prec tok (x, Input.accept inp1))
              else
                if Info.is_infix inf.fixity
                then
                  list_binary prec
                    (list_left inf.prec tok (x, Input.accept inp1))
                else (x, inp1)
      and list_left prec tok (x, inp) =
        let (nx, ninp) = list_binary prec ((chunk >>binop tok x) inp)
        in
        (nx, ninp)
      and list_right prec tok (x, inp) =
        let (nx, ninp) = list_binary prec (chunk inp)
        in
        (binop tok x nx, ninp)
      and list_prefix prec tok inp =
        let (nx, ninp) = list_binary prec (chunk inp)
        in
        unaryop tok nx, ninp
      and list_suffix prec tok (x, inp) =
        unaryop tok x, inp
      in
      list_binary 0 (chunk inp)

    let parse ph eof inp =
      let (x, toks) = ((ph -- (!$eof))>> fun (x, _) -> x) inp
      in
      x

  end
