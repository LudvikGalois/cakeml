open preamble bviTheory
open backend_commonTheory;

val _ = new_theory "bvi_tailrec";

val _ = Define `dummy = bvi$Var 1234567890`;

val MEM_exp_size_imp = Q.store_thm ("MEM_exp_size_imp",
  `∀xs a. MEM a xs ⇒ bvi$exp_size a < exp2_size xs`,
  Induct \\ rw [bviTheory.exp_size_def] \\ res_tac \\ fs []);

(* TODO defined in bviSemTheory, should be moved to bviTheory?
   On the other hand: its use here is temporary.
*)
val small_int_def = Define `
  small_int i <=> -268435457 <= i /\ i <= 268435457`;

val is_arith_op_def = Define `
  is_arith_op Add       = T ∧
  is_arith_op Mult      = T ∧
  is_arith_op Sub       = T ∧
  is_arith_op Div       = T ∧
  is_arith_op Mod       = T ∧
  is_arith_op (Const _) = T ∧
  is_arith_op _         = F
  `;

val is_num_rel_def = Define `
  (is_num_rel LessEq       ⇔ T) ∧
  (is_num_rel Less         ⇔ T) ∧
  (is_num_rel Greater      ⇔ T) ∧
  (is_num_rel GreaterEq    ⇔ T) ∧
  (is_num_rel (EqualInt _) ⇔ T) ∧
  (is_num_rel _            ⇔ F)
  `;

val is_rec_def = Define `
  (is_rec name (bvi$Call _ d _ NONE) ⇔ d = SOME name) ∧
  (is_rec _    _                     ⇔ F)
  `;

val _ = Datatype `
  assoc_op = Plus
           | Times
           | Noop`;

val _ = Datatype `v_ty = Int | Any`;

val to_op_def = Define `
  (to_op Plus  = Add) ∧
  (to_op Times = Mult) ∧
  (to_op Noop  = Const 0)
  `;

val from_op_def = Define `
  from_op op =
    if op = Add then Plus else
      if op = Mult then Times else Noop
  `;

val op_eq_def = Define `
  (op_eq Plus  (Op op xs) ⇔ op = Add) ∧
  (op_eq Times (Op op xs) ⇔ op = Mult) ∧
  (op_eq _     _          ⇔ F)`;

val apply_op_def = Define `
  apply_op op e1 e2 = Op (to_op op) [e1; e2]
  `;

val id_from_op_def = Define `
  (id_from_op Plus  = bvi$Op (Const 0) []) ∧
  (id_from_op Times = bvi$Op (Const 1) []) ∧
  (id_from_op Noop  = dummy)
  `;

val index_of_def = Define `
  (index_of (bvi$Var i) = SOME i) ∧
  (index_of _           = NONE)
  `;

val args_from_def = Define `
  (args_from (bvi$Call t (SOME d) as hdl) = SOME (t, d, as, hdl)) ∧
  (args_from _                            = NONE)
  `;

val get_bin_args_def = Define `
  get_bin_args (bvi$Op _ [e1; e2]) = SOME (e1, e2) ∧
  get_bin_args _                   = NONE
  `;

val exp_size_get_bin_args = Q.store_thm ("exp_size_get_bin_args",
  `∀x x1 x2.
     get_bin_args x = SOME (x1, x2) ⇒
       exp_size x1 < exp_size x ∧
       exp_size x2 < exp_size x`,
  Induct \\ fs [get_bin_args_def]
  \\ ntac 3 strip_tac
  \\ Cases_on `l` \\ simp [get_bin_args_def]
  \\ Cases_on `t` \\ simp [get_bin_args_def]
  \\ Cases_on `t'` \\ simp [get_bin_args_def]
  \\ fs [bviTheory.exp_size_def]);

val try_update_def = Define `
  (try_update vty NONE           ts      = ts) ∧
  (try_update vty (SOME (SUC n)) (t::ts) = t::try_update vty (SOME n) ts) ∧
  (try_update vty (SOME 0)       (t::ts) = vty::ts) ∧
  (try_update vty (SOME n)       []      = [])
  `;

(* Allowed expressions `y` in the tail position `f x + y`. *)
val no_err_def = tDefine "no_err" `
  (no_err ts (Op op xs) ⇔
    case op of
      Const i => small_int i ∧ xs = []
    | Add     => LENGTH xs = 2 ∧ EVERY (no_err ts) xs
    | Mult    => LENGTH xs = 2 ∧ EVERY (no_err ts) xs
    | _       => F) ∧
  (no_err ts (Var i) ⇔ i < LENGTH ts ∧ EL i ts = Int) ∧
  (no_err ts _       ⇔ F)`
  (WF_REL_TAC `measure (exp_size o SND)`
  \\ Induct
  \\ rw [bviTheory.exp_size_def]
  \\ res_tac \\ fs []);

val is_rec_or_rec_binop_def = Define `
  is_rec_or_rec_binop ts name op exp ⇔
    is_rec name exp ∨
    op_eq op exp ∧
      (case get_bin_args exp of
        NONE        => F
      | SOME (x, y) => is_rec name x ∧ no_err ts y)
  `;

val assoc_swap_def = Define `
  assoc_swap op from into =
    if ¬op_eq op into then
      apply_op op into from
    else
      case get_bin_args into of
        NONE        => apply_op op into from
      | SOME (x, y) => apply_op op x (apply_op op from y)
  `;

val rewrite_op_def = tDefine "rewrite_op" `
  rewrite_op ts op loc exp =
    if ¬op_eq op exp then
      (F, exp)
    else
      case get_bin_args exp of
        NONE => (F, exp)
      | SOME (x1, x2) =>
        let (r1, y1) = rewrite_op ts op loc x1 in
        let (r2, y2) = rewrite_op ts op loc x2 in
          case (is_rec_or_rec_binop ts loc op y1,
                is_rec_or_rec_binop ts loc op y2) of
            (T, F) => if no_err ts y2 then (T, assoc_swap op y2 y1) else (F, exp)
          | (F, T) => if no_err ts y1 then (T, assoc_swap op y1 y2) else (F, exp)
          | _      => (F, exp)
  `
  (WF_REL_TAC `measure (exp_size o SND o SND o SND)`
  \\ rw [exp_size_get_bin_args]);

val decide_ty_def = Define `
  (decide_ty Int Int = Int) ∧
  (decide_ty _   _   = Any)`;

(* Gather information about expressions:

     - Build context by following order of evaluation during recursion
       and set variable to Int only if interpretation of the expression would
       result in Rerr (Rabort Rtype_error) otherwise.
     - Check if tail positions are arithmetic or variables typed as Int in
       context.
     - Check if tail positions carry suitable operation (Add/Mult) and track
       branch of origin for the operation in conditionals.
*)
val scan_expr_def = tDefine "scan_expr" `
  (scan_expr ts loc (Var n) =
    let ty = if n < LENGTH ts then EL n ts else Any in
      (ts, ty, F, n < LENGTH ts ∧ EL n ts = Int, NONE)) ∧
  (scan_expr ts loc (If xi xt xe) =
    let (ti, tyi, _, pi, oi) = scan_expr ts loc xi in
    let (tt, ty1, _, pt, ot) = scan_expr ti loc xt in
    let (te, ty2, _, pe, oe) = scan_expr ti loc xe in
      (MAP2 decide_ty tt te, decide_ty ty1 ty2, IS_SOME oe, pt ∧ pe,
        case ot of
          NONE => oe
        | _    => ot)) ∧
  (scan_expr ts loc (Let xs x) =
    let tt =
      FOLDL (λt e. let (ts,ty,_,_,_) = scan_expr t loc e in ty::ts) ts xs in
    let (t, ty, _, p, oo) = scan_expr tt loc x in
      (DROP (LENGTH xs) t, ty, F, p, oo)) ∧
  (scan_expr ts loc (Raise x) = (ts, Any, F, F, NONE)) ∧
  (scan_expr ts loc (Tick x) = scan_expr ts loc x) ∧
  (scan_expr ts loc (Call t d xs h) = (ts, Any, F, F, NONE)) ∧
  (scan_expr ts loc (Op op xs) =
    let ok_type = is_arith_op op in
    let iop =
      if op = Add ∨ op = Mult then
        let iop = from_op op in
          if (FST (rewrite_op ts iop loc (Op op xs)))
          then SOME iop
          else NONE
      else
        NONE
      in
    let tt =
      if ¬(is_arith_op op ∨ is_num_rel op) then ts
      else
        case get_bin_args (Op op xs) of
          NONE        => ts
        | SOME (x, y) =>
            MAP2 (λa b. if a = Int ∨ b = Int then Int else Any)
              (try_update Int (index_of x) ts)
              (try_update Int (index_of y) ts)
    in (tt, if ok_type then Int else Any, F, ok_type, iop))`
    (WF_REL_TAC `measure (exp_size o SND o SND)`
     \\ rw [bviTheory.exp_size_def]
     \\ pop_assum mp_tac
     \\ qspec_tac (`e`,`e`)
     \\ qspec_tac (`xs`,`xs`)
     \\ Induct \\ rw []
     \\ res_tac
     \\ fs [bviTheory.exp_size_def]);

val push_call_def = Define `
  (push_call n op acc exp (SOME (ticks, dest, args, handler)) =
    Call ticks (SOME n) (args ++ [apply_op op exp (Var acc)]) handler) ∧
  (push_call _ _ _ _ _ = dummy)
  `;

val mk_tailcall_def = Define `
  mk_tailcall ts n op name acc exp =
    case rewrite_op ts op name exp of
      (F, exp2) => apply_op op exp2 (Var acc)
    | (T, exp2) =>
        (case get_bin_args exp2 of
          NONE => dummy
        | SOME (call, exp3) =>
          push_call n op acc exp3 (args_from call))
  `;

(* Unfortunately rewrite_op now requires a context implying some code
   duplication between rewrite and scan_expr.
*)
val rewrite_def = Define `
  (rewrite (loc, next, op, acc, ts) (Var n) =
    let ty = if n < LENGTH ts then EL n ts else Any in
      (ts, ty, F, Var n)) ∧
  (rewrite (loc, next, op, acc, ts) (If xi xt xe) =
    let (ti, tyi, ri, ok, iop) = scan_expr ts loc xi in
    let (tt, ty1, rt, yt) = rewrite (loc, next, op, acc, ti) xt in
    let (te, ty2, re, ye) = rewrite (loc, next, op, acc, ti) xe in
    let zt = if rt then yt else apply_op op xt (Var acc) in
    let ze = if re then ye else apply_op op xe (Var acc) in
      (MAP2 decide_ty tt te, decide_ty ty1 ty2, rt ∨ re, If xi zt ze)) ∧
  (rewrite (loc, next, op, acc, ts) (Let xs x) =
    let tt =
      FOLDL (λt e. let (ts,ty,_,_,_) = scan_expr t loc e in ty::ts) ts xs in
    let (t, ty, r, y) = rewrite (loc, next, op, acc + LENGTH xs, tt) x in
      (DROP (LENGTH xs) t, ty, r, Let xs y)) ∧
  (rewrite (loc, next, op, acc, ts) (Tick x) =
    let (tt, ty, r, y) = rewrite (loc, next, op, acc, ts) x in
      (tt, ty, r, Tick y)) ∧
  (rewrite (loc, next, op, acc, ts) (Raise x) = (ts, Any, F, Raise x)) ∧
  (rewrite (loc, next, op, acc, ts) exp =
    case rewrite_op ts op loc exp of
      (F, _)    => (ts, Int, F, apply_op op exp (Var acc))
    | (T, exp1) =>
      case get_bin_args exp1 of
        NONE              => (ts, Int, F, apply_op op exp (Var acc))
      | SOME (call, exp2) =>
          (ts, Int, T, push_call next op acc exp2 (args_from call)))`;

val check_exp_def = Define `
  check_exp loc arity exp =
    let (ts, ty, r, ok, op) = scan_expr (REPLICATE arity Any) loc exp in
      if ¬ok then NONE else op`;

val let_wrap_def = Define `
  let_wrap arity id exp =
    Let ((GENLIST (λi. Var i) arity) ++ [id]) exp`;

val mk_aux_call_def = Define `
  mk_aux_call loc arity id =
    Call 0 (SOME loc) (id :: GENLIST (λi. Var i) arity) NONE`;

val compile_exp_def = Define `
  compile_exp loc next arity exp =
    case check_exp loc arity exp of
      NONE    => NONE
    | SOME op =>
      let ts               = REPLICATE arity Any in
      let (tu, ty, r, opt) = rewrite (loc, next, op, arity, ts) exp in
      let aux             = let_wrap arity (id_from_op op) opt in
        SOME (aux, opt)`;

val compile_prog_def = Define `
  (compile_prog next [] = (next, [])) ∧
  (compile_prog next ((loc, arity, exp)::xs) =
    case compile_exp loc next arity exp of
    | NONE =>
        let (n, ys) = compile_prog next xs in
          (n, (loc, arity, exp)::ys)
    | SOME (exp_aux, exp_opt) =>
        let (n, ys) = compile_prog (next + 2) xs in
        (n, (loc, arity, exp_aux)::(next, arity + 1, exp_opt)::ys))
  `;

val _ = export_theory();

