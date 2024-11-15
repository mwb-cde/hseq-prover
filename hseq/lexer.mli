(*----
  Copyright (c) 2005-2024 Matthew Wahab <mwb.cde@gmail.com>

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
----*)

(**
   Lexer

   Match strings in a stream of characters, constructing a stream of
   tokens.

   Tokens are found by longest-sequence matching: if [c] is the first
   character in the input stream and [n] is the length of the longest
   known string begining with [c], matching begins with the first [n]
   characters from the stream and continues by trying with fewer
   ([n-1], [n-2], etc) characters until a match is found for the first
   [m<=n] characters. The [m] characters are removed from the input
   stream and a token is formed from the string.
 *)

exception Lexing of (int * int)
(**
   Exception [Lexing(f, l)] marks a lexing error between characters
   [f] and [l] in an input string.
 *)

(** {7 Tokens} *)

(** Symbols. *)
type symbols =
    DOT      (** String "." *)
  | ORB        (** String "(" *)
  | CRB      (** String ")" *)
  | PRIME      (** String "'" *)
  | COLON      (** String ":" *)
  | OTHER of string      (** An arbitrary (user-defined) symbol *)
  | NULL_SYMBOL      (** The null symbol *)

val comma_sym: symbols
(** The comma symbol (","). *)

(** Keywords *)
type keys =
    ALL  (** Universal quantifier *)
  | EX   (** Existential quantifier *)
  | LAM  (** Lambda quantifier *)

type token_info =
  (Ident.t * Parserkit.Info.fixity  * int)
(** Identifier fixity and precdence information. *)

(** Tokens. These are the tokens passed to the parser. *)
type tok =
    Key of keys  (** Keywords *)
  | Sym of symbols  (** Symbols *)
  | ID of Ident.t  (** Long identifiers *)
  | PrimedID of string  (** Primed identifiers (for types) *)
  | NUM of string    (** Numbers *)
  | BOOL of bool     (** Booleans *)
  | EOF    (** End of file *)
  | NULL   (** Null token *)

val eof_tok : tok
(** The end of file token. *)

val null_tok : tok
(** The null token. *)

val mk_ident : Ident.t -> tok
(** Make an identifier token. *)
val mk_symbol : string -> tok
(** Make a symbol token. *)

val string_of_token : tok -> string
(**
   [string_of_token tok]: Make a string representation of token [tok].
 *)

val message_of_token : tok -> string
(**
   [message_of_token tok]: Make a string description of token
   [tok] suitable for use in an error message.
 *)

val match_tokens : tok -> tok -> bool
(**
   [match_tokens x y]: Compare tokens [x] and [y], return [true] iff
   they are the same.
 *)

(** {7 Symbol Tables}

   A symbol table {!Lexer.symtable} stores strings and the tokens they
   map to. To assist in matching, the number of strings of each size
   [n] is also stored.
 *)

module SymbolTree: Treekit.SimpleTreeType with type key = string
type symbol_table= (tok) SymbolTree.t
type symtable = (char * int Counter.t) list * symbol_table

val mk_symtable : int -> symtable
val clear_symtable : symtable -> symtable
val add_sym :
    symtable -> string -> tok -> symtable
(**
   [add_sym tbl s t]: Add [s] to symtable [tbl] as the representation
   of token [t]. Fails if [s] is already in the table.
 *)

val remove_sym : symtable -> string -> symtable
(** [remove_sym tbl s]: Remove [s] from symtable [tbl].
 *)

val find_sym : symtable -> string -> tok
(**
   [find_sym tbl s]: Find string [s] in symtable [tbl],
   returning associated token.
   Raise [Not_found] if [s] is not in [tbl].
 *)

val find_sym_opt : symtable -> string -> (tok)option
(**
   [find_sym tbl s]: Find string [s] in symtable [tbl],
   returning associated token.
   Return [None] if [s] is not in [tbl].
 *)

val lookup_sym :  symtable -> string -> (int * tok)option
(**
   [lookup_sym tbl str]:
   Try to match a symbol at the beginning of string [str],
   returning token and size of matched string.
   Raise [Not_found] if no matching symbol.

   Uses longest substring matching: looks at first character of
   string; finds length of longest symbol beginning with that
   character; beginning with this length, trys initial sub-strings of
   decreasing size until a match is found.
 *)

(** {5 Utility functions} *)

module Stream:
sig
  type ('a) t

  val is_empty: ('a)t -> bool
  val uncons: ('a)t -> ('a * ('a)t)option
  val cons: 'a -> ('a)t -> ('a)t

  val push_front: ('a)list -> ('a)t -> ('a)t
  val first: int -> ('a)t -> (('a)list * ('a)t)
  val look: int -> ('a)t -> (('a)list * ('a)t)

  val apply: ('a -> 'b) -> ('a)t -> ('b * ('a)t)option
  val test: ('a -> bool) -> ('a)t -> (bool * ('a)t)
  val drop: int -> ('a)t -> ('a)t

  val of_string: string -> (char)t
end

val string_implode : char list -> string
(** Make a string from a list of characters. *)

(** {5 Matching functions} *)

val white_space : char list
(** The white space characters: [[' '; '\n'; '\t'; '\r']] *)

val special : char list
(** Special characters: [['_'; '''; '.']] *)

val special_alpha : char list
(** Special characters, treated as alpha-numeric:  [['_'; '?'; ''']] *)

val is_negate_char : char -> bool
(** [is_negate_char c]: [c] is the negation character ("-"). *)
val is_space : char -> bool
(** [is_space c]: [c] is white space. *)
val is_special : char -> bool
(** [is_special c]: [c] is a special character. *)
val is_special_alpha : char -> bool
(** [is_special_alpha c]: [c] is a special alpha-numeric character. *)
val is_dot : char  -> bool
(** [is_dot c]: character [c] is a dot. *)
val is_prime : char -> bool
(** [is_prime c]: character [c] is a prime ("'") *)

val is_digit : char -> bool
(** [is_digit c]: [c] is a digit. *)
val is_alpha : char -> bool
(** [is_alpha c]: [c] is an alphabetic character. *)

val is_identifier_char : char  -> bool
(** [is_identifier_char c]: character [c] can appear in an identifier. *)
val is_identifier_start : char  -> bool
(** [is_identifier_start c]: character [c] can start an identifier. *)

val get_while: ('a -> bool) -> ('a)Stream.t -> (('a)list * ('a)Stream.t)
(**
   [get_while test stm]: Read the initial elements satisfying [test].  *)

val get_sep_list:
    (char->bool) -> (char->bool) -> (char->bool)
      ->  (char)Stream.t -> ((string)list * (char)Stream.t)
(**
   [get_sep_list init body sep stm]: Read a list of strings from [stm].
   Each string must begin with character satisfying [init]
   and contain characters satisfying [body].
   The list must be seperated by a single character satisfying [sep].

   The list is returned with the strings in the order that they appear
   in the stream (e.g. "abcd.efgh" -> ["abcd"; "efgh"] )
 *)

val get_alpha : (char)Stream.t -> ((char)list * (char)Stream.t)
(**  Get the alpha-numeric string at the front of the stream. *)

val is_num : (char)Stream.t -> (bool * (char)Stream.t)
(** [is_num stm]: There is a number at the start of stream [stm]. *)

val get_num : (char)Stream.t -> ((string)option * (char)Stream.t)
(** [get_num stm]: Get the string representation of the number at the start
    of stream [stm]. *)

val skip_space : (char)Stream.t -> (char)Stream.t
(** [skip_space stm]: Drop the leading white space from stream [stm]. *)

(**
   {5 Lexer functions}

   Each lexer function tries to match the characters at the front
   of the input stream. If the match succeeds, the function removes
   the string from the stream and returns [(true, tok)] where [tok]
   is the token for the string. If the match fails, the function
   returns [(false, tok)] where [tok] is an arbitrary token.
 *)

type ('a) matcher = symtable -> ('a)Stream.t -> ((tok)option * ('a)Stream.t)
    (** Functions which match from a stream. *)

val first_match:
    ('a) matcher list -> symtable -> ('a)Stream.t -> ((tok)option * ('a)Stream.t)
        (**
           Apply each of the lexers in a list, in order, returning the result
           of the first to suceed. Returns [(false, null_tok)] on failure.
         *)

val match_number : (char)matcher
(**
   [match_number stm]: Match a number.
 *)

val match_other : (char)matcher
(**
   [match_other stm]: General matching function, tries standard
   lexers. Currently, only tries {!Lexer.match_number}.
 *)

val match_primed_identifier : (char)matcher
(**
   Match a primed identifier. An identifier begins with a prime ("'")
   and is made up of alpha-numeric characters.
 *)

val match_identifier : (char)matcher
    (**
       Match identifiers. An identifier begins with a alphabetic
       character or underscore ("_") and is made up of alpha-numeric
       characters possibly seperated by a single dot (".").
     *)

val match_keywords : char matcher
(** [match_keywords tbl stm]: Match keywords in [stm]. *)

val match_empty : 'a matcher
    (** Match the empty stream. *)

(* ANTIQUOTATION NOT SUPPORTED
   val match_antiquote : symtable -> char Stream.t -> bool * tok
 *)

(** {5 Toplevel functions} *)

val lex : symtable -> (char)Stream.t -> (tok * (char)Stream.t)option
(**
   [lex symtab strm]: The main lexing function. Reads a token from stream
   [stm], with symbol table [symtab].
 *)

val scan : symtable -> (char)Stream.t -> (tok)Parserkit.Input.t
(**
   [scan symtab stm]: make token input stream from a char stream with
   symbol table symtab.
 *)

val reader :
  ((char)Stream.t -> 'a) -> ('a -> 'b) -> string -> 'b
(**
   [reader lex ph str]:
   Parse string [str] using lexer [lex] and parser [ph].
 *)


(** {7 Debugging information} *)

val add_sym_size : 'a -> ('a * int) list -> ('a * int) list
val add_char_info :
    'a -> 'b -> ('a * ('b * int) list) list -> ('a * ('b * int) list) list

val remove_sym_size : 'a -> ('a * int) list -> ('a * int) list
val remove_char_info :
    'a -> 'b -> ('a * ('b * int) list) list -> ('a * ('b * int) list) list
val largest_sym : 'a -> ('a * (int)Counter.t) list * 'd -> (int)option

val find_char_info : 'a -> ('a * (int)Counter.t) list -> (int)Counter.t
