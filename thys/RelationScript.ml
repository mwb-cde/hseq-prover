(*-----
 Name: RelationScript.ml
 Author: M Wahab <mwahab@users.sourceforge.net>
 Copyright M Wahab 2006
----*)

(**
   Relations
*)

let _ = begin_theory "Relation" ["Bool"]

(** {5 Definitions} *)

let empty = 
  define <:def< empty x y = false >>;;

let inv_def =
  define <:def< inv R x y = R y x >>;;

let refl_def = 
  define <:def< refl R = ! x: R x x >>;;

let sym_def = 
  define <:def< sym R = ! x y: (R x y) => (R y x) >>;;

let trans_def = 
  define <:def< trans R = ! x y z: ((R x y) & (R y z)) => (R x z) >>;;

let antisym_def =
  define <:def< antisym R = ! x y: ((R x y) & (R y x)) => (x = y) >>;;

let equiv_rel_def =
  define <:def< equiv_rel R = (refl R) & (sym R) & (trans R) >>;;

let partial_order_def = 
  define <:def< partial_order R = (refl R) & (trans R) & (antisym R) >>;;

let total_order_def = 
  define 
    <:def< 
  total_order R = (partial_order R) & (! x y: (R x y) | (R y x)) 
    >>;;

let refl_closure_def =
  define <:def< RC R x y = ((x = y) | (R x y)) >>;;

let refl_trans_closure_def =
  define 
    <:def< 
  RTC R a b = 
  !P: 
    ((! x: (P x x))
       & (! x y z: ((R x y) & (P y z)) => (P x z)))
    => (P a b)
    >>;;

let trans_closure_def =
  define 
    <:def< 
  TC R a b = 
  !P: 
    ((! x y: (R x y) => (P x y))
       & (! x y z: ((R x y) & (P y z)) => (P x z)))
    => (P a b)
    >>;;

let tc_rules=
  theorem "tc_rules"
    << 
    (!R x y: (R x y) => (TC R x y))
    & 
    (!R x y z: ((R x y) & (TC R y z)) => (TC R x z))
    >>
    [
      scatter_tac 
	++ once_rewriteC_tac [defn "TC"]
	++ flatten_tac
	--
	[
	  back_tac ++ simp;
	  (match_asm << TC R X Y >> 
	     (fun l -> 
		once_rewrite_tac [defn "TC"]
		++ instA ~a: l[<< _P >>]))
	  ++ simpA
	  ++ (match_asm << ! x y z: X >> liftA)
	  ++ instA [<< _x >> ; << _y >>; << _z >>]
	  ++ back_tac
	  ++ simp
	]
    ];;

let tc_rule1=
  theorem "tc_rule1"
    << (!R x y: (R x y) => (TC R x y)) >>
    [
      simp_tac [thm "tc_rules"]
    ];;

let tc_rule2=
  theorem "tc_rule2"
    << (!R x y z: ((R x y) & (TC R y z)) => (TC R x z)) >>
    [ cut (thm "tc_rules") ++ conjA ++ basic ];;

let tc_induct =
  theorem "tc_induct"
    << 
    !P R:
    ((! x y: (R x y) => (P x y))
     & 
     (! x y z: ((R x y) & (P y z)) => (P x z)))
  => 
  (! x y: (TC R x y) => (P x y))
    >>
  [ 
    flatten_tac ++ once_rewrite_tac [defn "TC"]
    ++ (match_asm << !P: X => (P _x _y) >> liftA)
    ++ back_tac
    ++ simp_all
  ];;

let tc_cases = 
  theorem "tc_cases"
  << 
    ! R x y: 
    (TC R x y) = ((R x y) | ? z: (R x z) & (TC R z y))
  >>
  [
    flatten_tac ++ equals_tac ++ iffC
    --
      [
	(* 1 *)
	cut ~inst:[<< (% x y: (_R x y) | (?z: (_R x z) & (TC _R z y))) >>]
	  (thm "tc_induct")
	++ instA [<< _R >>]
	++ betaA
	++ scatter_tac
	--
	  [
	    (* 1 *)
	    basic;
	    (* 2 *)
	    (match_concl << ?z: (_R _x1 z) & Y >>
	       (fun l -> instC ~c:l [<< _y1 >>]))
	    ++ (show << TC _R _y1 _z >>
		  (cut (thm "tc_rule1") ++ back_tac ++ basic))
	    ++ simp;
	    (* 3 *)
	    (match_concl << ?z: (_R _x1 z) & Y >> liftC)
	    ++ instC [<<_y1>>]
	    ++ (show << TC _R _y1 _z >>
		 (cut ~inst:[<<_R>>; << _y1 >>; << _z1 >>; << _z >>]
		    (thm "tc_rule2")
		  ++ back_tac ++ simp))
	    ++ simp;
	    (* 4 *)
	    mp_tac ++ blast_tac
	    ++ instC [<< _z >>] ++ simp
	  ];
	(* 2 *)
	scatter_tac
	--
	  [
	    cut_mp_tac (thm "tc_rule1") ++ basic;
	    cut ~inst:[<<_R>>; << _x >>; << _z >>; << _y >>] 
	      (thm "tc_rule2")
	    ++ back_tac
	    ++ simp
	  ]
      ]
  ];;

let rtc_rules=
  theorem "rtc_rules"
    << 
    (!R x: (R x x) => (RTC R x x))
    & 
    (!R x y z: ((R x y) & (RTC R y z)) => (RTC R x z))
    >>
    [
      scatter_tac 
	++ once_rewriteC_tac [defn "RTC"]
	++ flatten_tac
	--
	[
	  simp;
	  (match_asm << RTC R Y Z >> 
	     (fun l -> 
		once_rewrite_tac [defn "RTC"]
		++ instA  ~a:l [<< _P >>]))
	  ++ (implA ++ (simp // skip))
	  ++ (match_asm << ! x y z: P >>
	      (fun l -> instA ~a:l [<< _x >> ; << _y >>; << _z >>]))
	  ++ (back_tac ++ simp)
	]
    ];;


let rtc_rule1=
  theorem "rtc_rule1"
    << (!R x x: (R x x) => (RTC R x x)) >>
    [ simp_tac [thm "rtc_rules"] ];;

let rtc_rule2=
  theorem "rtc_rule2"
    << (!R x y z: ((R x y) & (RTC R y z)) => (RTC R x z)) >>
    [ cut (thm "rtc_rules") ++ conjA ++ basic ];;



let rtc_induct =
  theorem "rtc_induct"
    << 
    !P R:
    ((! x : P x x)
     & 
     (! x y z: ((R x y) & (P y z)) => (P x z)))
  => 
  (! x y: (RTC R x y) => (P x y))
    >>
    [
      flatten_tac ++ once_rewrite_tac [defn "RTC"]
      ++ back_tac ++ simp_all
  ];;


let rtc_cases = 
  theorem "rtc_cases"
    << 
    ! R x y: 
    (RTC R x y) = ((x = y) | ? z: (R x z) & (RTC R z y))
    >>
    [
      flatten_tac ++ equals_tac ++ iffC 
	--
	[
	  cut (thm "rtc_induct")
	  ++ instA [ << % x y: x = y | ?z : (_R x z) & (RTC _R z y) >>;
		     << _R >>]
	  ++ betaA
	  ++ scatter_tac 
	    --
	    [
	      simp;
	      once_rewriteA_tac [defn "RTC"]
	      ++ instA [<< equals >>]
	      ++ simp_all;
	      (show << RTC _R _y1 _z >> 
		 (cut (thm "rtc_rules") ++ conjA
		  ++ (match_asm << !x y z: P >> 
			(fun l -> 
			   instA ~a:l [ << _R >>; << _y1 >> ; 
					<< _z1 >>; << _z>>]
			++ back_tac ~a:l
			++ simp))))
	      ++ (match_concl << ?z: X & (RTC _R z _z) >>
		   (fun l -> instC ~c:l [<< _y1 >>]))
	      ++ simp;
	      mp_tac ++ split_tac ++ simp
	    ];
	  cut (thm "rtc_rules")
	  ++ flatten_tac
	  ++ once_rewriteC_tac [defn "RTC"]
	  ++ flatten_tac
	  ++ (split_tac -- [simp])
	  ++ flatten_tac
	  ++ (match_asm << !x y z: P >> 
		(fun l -> instA ~a:l [<< _x >> ; << _z >> ; << _y >>]))
	  ++ back_tac ++ simp
	  ++ (match_asm << RTC R Z Y >>
		(fun l -> once_rewriteA_tac ~f:l [defn "RTC"]))
	  ++ back_tac ++ simp
	]
    ];;

let _ = end_theory ();;