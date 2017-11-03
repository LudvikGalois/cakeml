open preamble bviSemTheory bviPropsTheory bvi_tailrecTheory

(* TODO

   - It should be possible to prove that we can replace the simplified
     compile_exp by the old compile_exp without touching the evaluate-
     theorem. Benefits:
       * Less code duplication
       * Can inline auxiliary calls more easily
*)

val _ = new_theory "bvi_tailrecProof";

val find_code_def = bvlSemTheory.find_code_def;

val get_bin_args_SOME = Q.store_thm ("get_bin_args_SOME[simp]",
  `∀exp q. get_bin_args exp = SOME q
    ⇔
    ∃e1 e2 op. q = (e1, e2) ∧ exp = Op op [e1; e2]`,
  Cases \\ rw [get_bin_args_def]
  \\ rw[bvlPropsTheory.case_eq_thms]
  \\ rw[EQ_IMP_THM]);

val opbinargs_SOME = Q.store_thm ("opbinargs_SOME[simp]",
  `!exp opr. opbinargs opr exp = SOME q
   <=>
   opr <> Noop /\ ?x y. q = (x, y) /\ exp = Op (to_op opr) [x;y]`,
   Cases \\ Cases \\ fs [opbinargs_def, to_op_def, op_eq_def]
   \\ rw [EQ_IMP_THM]);

val decide_ty_simp = Q.store_thm ("decide_ty_simp[simp]",
  `(decide_ty ty1 ty2 = Int  <=> ty1 = Int  /\ ty2 = Int) /\
   (decide_ty ty1 ty2 = List <=> ty1 = List /\ ty2 = List)`,
  Cases_on `ty1` \\ Cases_on `ty2` \\ fs [decide_ty_def]);

val ty_rel_def = Define `
  ty_rel = LIST_REL
    (\v t. (t = Int  ==> ?k. v = Number k) /\
           (t = List ==> ?ys. v_to_list v = SOME ys))`;

val try_update_LENGTH = Q.store_thm ("try_update_LENGTH",
  `LENGTH (try_update ty idx ts) = LENGTH ts`,
  Cases_on `idx` \\ rw [try_update_def]);

val v_ty_thms = { nchotomy = v_ty_nchotomy, case_def = v_ty_case_def };
val v_ty_cases = CONJ (prove_case_elim_thm v_ty_thms) (prove_case_eq_thm v_ty_thms)

val term_ok_IMP = Q.store_thm("term_ok_IMP",
  `!ts ty x.
     term_ok ts ty x ==> term_ok ts Any x`,
  recInduct term_ok_ind \\ rw []
  \\ pop_assum mp_tac
  \\ once_rewrite_tac [term_ok_def]
  \\ TRY (Cases_on `ty` \\ fs []) \\ rw []
  \\ fs [EVERY_MEM] \\ rw []);

val list_to_v_simp = Q.store_thm("list_to_v_simp[simp]",
  `!xs. v_to_list (list_to_v xs) = SOME xs`,
  Induct \\ fs [bvlSemTheory.v_to_list_def, bvlSemTheory.list_to_v_def]);

val list_to_v_imp = Q.store_thm ("list_to_v_imp",
  `!x xs. v_to_list x = SOME xs ==> list_to_v xs = x`,
  recInduct bvlSemTheory.v_to_list_ind
  \\ rw [bvlSemTheory.v_to_list_def]
  \\ fs [case_eq_thms] \\ rw []
  \\ fs [bvlSemTheory.list_to_v_def]);

(* Very slow, because of how term_ok is defined *)
val term_ok_SING = Q.store_thm("term_ok_SING",
  `!ts ty exp env (s: 'ffi bviSem$state) r t.
     term_ok ts ty exp /\
     ty_rel env ts /\
     evaluate ([exp], env, s) = (r, t) ==>
       s = t /\
       ?v. r = Rval [v] /\
       (!(s: 'ffi bviSem$state). evaluate ([exp], env, s) = (r, s)) /\
       case ty of
         Int => ?k. v = Number k
       | List => ?ys. v_to_list v = SOME ys
       | _ => T`,
  recInduct term_ok_ind
  \\ rpt strip_tac
  \\ pop_assum mp_tac
  \\ simp [evaluate_def]
  \\ TRY
   (rename1 `if _ < LENGTH _ then _ else _`
    \\ fs [term_ok_def, ty_rel_def, LIST_REL_EL_EQN] \\ rw []
    \\ every_case_tac \\ fs [])
  \\ qpat_x_assum `term_ok _ _ _` mp_tac
  \\ simp [term_ok_def]
  \\ fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS]
  \\ rw [term_ok_def]
  \\ imp_res_tac evaluate_IMP_LENGTH \\ fs [] \\ rveq
  \\ fs [LENGTH_EQ_NUM_compute] \\ rveq
  \\ fs [LENGTH_EQ_NUM_compute] \\ rveq
  \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def]
  \\ fs [case_eq_thms, pair_case_eq, bool_case_eq]
  \\ rw [bvlSemTheory.v_to_list_def]
  \\ fs [bvl_to_bvi_id, PULL_EXISTS]
  \\ fsrw_tac [DNF_ss] [evaluate_def]
  \\ fs [pair_case_eq, case_eq_thms, case_elim_thms] \\ rw []
  \\ imp_res_tac evaluate_IMP_LENGTH \\ fs []
  \\ fs [LENGTH_EQ_NUM_compute] \\ rveq
  \\ fs [PULL_EXISTS]
  \\ TRY (ntac 2 (first_x_assum drule \\ rpt (disch_then drule) \\ rw []) \\ NO_TAC)
  \\ fs [small_int_def, small_enough_int_def]);

val op_id_val_def = Define `
  op_id_val Plus   = Number 0 /\
  op_id_val Times  = Number 1 /\
  op_id_val Append = Block nil_tag [] /\
  op_id_val Noop   = Number 6333
  `;

val scan_expr_not_Noop = Q.store_thm ("scan_expr_not_Noop",
  `∀exp ts loc tt ty r ok op.
     scan_expr ts loc [exp] = [(tt, ty, r, SOME op)] ⇒
       op ≠ Noop`,
  Induct
  \\ rw [scan_expr_def]
  \\ rpt (pairarg_tac \\ fs []) \\ rw []
  \\ fs[bvlPropsTheory.case_eq_thms]
  \\ fs [from_op_def] \\ rveq
  \\ TRY (metis_tac [])
  \\ fs [check_op_def, opbinargs_def, get_bin_args_def]
  \\ fs [case_eq_thms, case_elim_thms, bool_case_eq]);

val check_exp_not_Noop = Q.store_thm ("check_exp_not_Noop",
  `∀loc arity exp op.
     check_exp loc arity exp = SOME op ⇒ op ≠ Noop`,
  rw [check_exp_def] \\ imp_res_tac scan_expr_not_Noop);

val to_op_eq_simp = Q.store_thm("to_op_eq_simp[simp]",
  `(to_op x = Add        <=> (x = Plus))   /\
   (to_op x = Mult       <=> (x = Times))  /\
   (to_op x = Mod        <=> (x = Noop))   /\
   (to_op x = ListAppend <=> (x = Append)) /\
   (Add        = to_op x <=> (x = Plus))   /\
   (Mult       = to_op x <=> (x = Times))  /\
   (ListAppend = to_op x <=> (x = Append)) /\
   (Mod        = to_op x <=> (x = Noop))`,
   Cases_on`x` \\ rw[to_op_def]);

val op_eq_simp = Q.store_thm("op_eq_simp[simp]",
  `(op_eq Plus x   <=> (?xs. x = Op Add xs))  /\
   (op_eq Times x  <=> (?xs. x = Op Mult xs)) /\
   (op_eq Append x <=> (?xs. x = Op ListAppend xs))`,
  Cases_on`x` \\ rw[op_eq_def]);

val rotate_correct = Q.store_thm("rotate_correct",
  `!opr exp env s r t.
     evaluate ([exp], env, s) = (r, t) /\
     r <> Rerr (Rabort Rtype_error) ==>
       evaluate ([rotate opr exp], env, s) = (r, t)`,
  recInduct rotate_ind \\ rw []
  \\ once_rewrite_tac [rotate_def]
  \\ rw [opbinargs_def, get_bin_args_def]
  \\ rpt (PURE_CASE_TAC \\ fs []) \\ rw []
  \\ fs [apply_op_def]
  \\ first_x_assum (qspecl_then [`env`,`s`,`r`,`t`] mp_tac)
  \\ impl_tac \\ fs []
  \\ fs [evaluate_def, pair_case_eq, case_eq_thms, case_elim_thms]
  \\ rw [PULL_EXISTS]
  \\ imp_res_tac evaluate_SING_IMP \\ fs [] \\ rveq
  \\ Cases_on `opr` \\ fs [to_op_def]
  \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def]
  \\ fs [pair_case_eq, case_eq_thms, case_elim_thms, PULL_EXISTS] \\ rw []
  \\ fs [bvl_to_bvi_id]
  \\ TRY intLib.COOPER_TAC \\ rw []);

val do_assocr_lemma = Q.store_thm("do_assocr_lemma",
  `!opr exp env s r t.
     evaluate ([exp], env, s) = (r, t) /\
     r <> Rerr (Rabort Rtype_error) ==>
       evaluate ([do_assocr opr exp], env, s) = (r, t)`,
  recInduct do_assocr_ind \\ rw []
  \\ once_rewrite_tac [do_assocr_def]
  \\ rw [opbinargs_def, get_bin_args_def]
  \\ rpt (PURE_CASE_TAC \\ fs []) \\ rw []
  \\ imp_res_tac rotate_correct
  \\ fs [apply_op_def]
  \\ qpat_x_assum `!x. evaluate _ = (r, t)` (qspec_then `opr` mp_tac)
  \\ pop_assum (fn th => fs [th])
  \\ fs [evaluate_def, pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
  \\ rw [PULL_EXISTS] \\ fs []
  \\ imp_res_tac evaluate_SING_IMP \\ fs [] \\ rveq
  \\ rename1 `evaluate ([do_assocr opr expr], env, st)`
  \\ Cases_on `evaluate ([expr], env, st)`
  \\ first_x_assum drule \\ fs []);

val assocr_correct = Q.store_thm("assocr_correct",
  `!exp env s r t.
     evaluate ([exp], env, s) = (r, t) /\
     r <> Rerr (Rabort Rtype_error) ==>
       evaluate ([assocr exp], env, s) = (r, t)`,
  Induct \\ rw [assocr_def]
  \\ qpat_x_assum `evaluate _ = _` mp_tac
  \\ simp [evaluate_def, pair_case_eq, case_eq_thms, case_elim_thms, PULL_EXISTS]
  \\ rw []
  \\ fs [bool_case_eq] \\ rw []
  \\ qmatch_goalsub_abbrev_tac `do_assocr _ expr`
  \\ Cases_on `evaluate ([expr], env, s)`
  \\ imp_res_tac do_assocr_lemma
  \\ qpat_x_assum `evaluate ([expr],_,_) = _` mp_tac
  \\ simp [Once evaluate_def, Abbr`expr`] \\ rw []
  \\ metis_tac []);

val comml_correct = Q.store_thm("comml_correct",
  `!exp env s r t loc.
     evaluate ([exp], env, s) = (r, t) /\
     r <> Rerr (Rabort Rtype_error) ==>
       evaluate ([comml loc exp], env, s) = (r, t)`,
  cheat (* TODO *)
  );

val env_rel_def = Define `
  env_rel ty opt acc env1 env2 <=>
    isPREFIX env1 env2 /\
    (opt ⇒
      LENGTH env1 = acc /\
      LENGTH env2 > acc /\
      case ty of
        Int => ?k. EL acc env2 = Number k
      | List => ?ys. v_to_list (EL acc env2) = SOME ys
      | Any => F)`;

val code_rel_def = Define `
  code_rel c1 c2 ⇔
    ∀loc arity exp op.
      lookup loc c1 = SOME (arity, exp) ⇒
      (check_exp loc arity exp = NONE ⇒
        lookup loc c2 = SOME (arity, exp)) ∧
      (check_exp loc arity exp = SOME op ⇒
        ∃n. ∀exp_aux exp_opt.
        compile_exp loc n arity exp = SOME (exp_aux, exp_opt) ⇒
          lookup loc c2 = SOME (arity, exp_aux) ∧
          lookup n c2 = SOME (arity + 1, exp_opt))`;

val code_rel_find_code_SOME = Q.prove (
  `∀c1 c2 (args: v list) a exp.
     code_rel c1 c2 ∧
     find_code (SOME n) args c1 = SOME (a, exp) ⇒
       find_code (SOME n) args c2 ≠ NONE`,
  rw [find_code_def, code_rel_def]
  \\ pop_assum mp_tac
  \\ rpt (PURE_TOP_CASE_TAC \\ fs [])
  \\ first_x_assum drule
  \\ fs [compile_exp_def]
  \\ CASE_TAC \\ fs [] \\ rw []
  \\ pairarg_tac \\ fs []);

val code_rel_find_code_NONE = Q.prove (
  `∀c1 c2 (args: v list) a exp.
     code_rel c1 c2 ∧
     find_code NONE args c1 = SOME (a, exp) ⇒
       find_code NONE args c2 ≠ NONE`,
  rw [find_code_def, code_rel_def]
  \\ pop_assum mp_tac
  \\ rpt (PURE_TOP_CASE_TAC \\ fs []) \\ rw []
  >-
   (first_x_assum drule
    \\ fs [compile_exp_def]
    \\ CASE_TAC \\ fs [] \\ rw []
    \\ pairarg_tac \\ fs [])
  \\ first_x_assum drule
  \\ fs [compile_exp_def]
  \\ CASE_TAC \\ fs [] \\ rw []
  \\ pairarg_tac \\ fs []);

val state_rel_def = Define `
  state_rel s t ⇔
    s.ffi = t.ffi ∧
    s.clock = t.clock ∧
    code_rel s.code t.code
  `;

val code_rel_domain = Q.store_thm ("code_rel_domain",
  `∀c1 c2.
     code_rel c1 c2 ⇒ domain c1 ⊆ domain c2`,
  simp [code_rel_def, SUBSET_DEF]
  \\ CCONTR_TAC \\ fs []
  \\ Cases_on `lookup x c1`
  >- fs [lookup_NONE_domain]
  \\ fs [GSYM lookup_NONE_domain]
  \\ rename1 `SOME z`
  \\ PairCases_on `z`
  \\ first_x_assum drule
  \\ fs [compile_exp_def]
  \\ CASE_TAC \\ fs [] \\ rw []
  \\ pairarg_tac \\ fs []);

val evaluate_let_wrap = Q.store_thm ("evaluate_let_wrap",
  `∀x op vs (s:'ffi bviSem$state) r t.
     op ≠ Noop ⇒
     evaluate ([let_wrap (LENGTH vs) (id_from_op op) x], vs, s) =
     evaluate ([x], vs ++ [op_id_val op] ++ vs, s)`,
  rw []
  \\ `LENGTH vs + 0 ≤ LENGTH vs` by fs []
  \\ drule evaluate_genlist_vars
  \\ disch_then (qspec_then `s` mp_tac)
  \\ simp [let_wrap_def, evaluate_def]
  \\ once_rewrite_tac [evaluate_APPEND]
  \\ simp [pair_case_eq, case_eq_thms, case_elim_thms, PULL_EXISTS, bool_case_eq]
  \\ Cases_on `op` \\ EVAL_TAC \\ rw []
  \\ AP_TERM_TAC
  \\ fs [state_component_equality]);

val evaluate_complete_ind = Q.store_thm ("evaluate_complete_ind",
  `∀P.
    (∀xs s.
      (∀ys t.
        exp2_size ys < exp2_size xs ∧ t.clock ≤ s.clock ∨ t.clock < s.clock ⇒
        P ys t) ⇒
      P xs s) ⇒
    ∀(xs: bvi$exp list) (s: 'ffi bviSem$state). P xs s`,
  rpt strip_tac
  \\ `∃sz. exp2_size xs = sz` by fs []
  \\ `∃ck0. s.clock = ck0` by fs []
  \\ ntac 2 (pop_assum mp_tac)
  \\ qspec_tac (`xs`,`xs`)
  \\ qspec_tac (`s`,`s`)
  \\ qspec_tac (`sz`,`sz`)
  \\ completeInduct_on `ck0`
  \\ strip_tac
  \\ completeInduct_on `sz`
  \\ fs [PULL_FORALL, AND_IMP_INTRO, GSYM CONJ_ASSOC]
  \\ rpt strip_tac \\ rveq
  \\ last_x_assum match_mp_tac
  \\ rpt strip_tac
  \\ simp []
  \\ fs [LESS_OR_EQ]);

val scan_expr_EVERY_SING = Q.store_thm ("scan_expr_EVERY_SING[simp]",
  `EVERY P (scan_expr ts loc [x]) ⇔ P (HD (scan_expr ts loc [x]))`,
  `LENGTH (scan_expr ts loc [x]) = 1` by fs []
  \\ Cases_on `scan_expr ts loc [x]` \\ fs []);

val EVERY_LAST1 = Q.store_thm("EVERY_LAST1",
  `!xs y. EVERY P xs /\ LAST1 xs = SOME y ==> P y`,
  ho_match_mp_tac LAST1_ind \\ rw [LAST1_def] \\ fs []);

val scan_expr_LENGTH = Q.store_thm ("scan_expr_LENGTH",
  `∀ts loc xs ys.
     scan_expr ts loc xs = ys ⇒
       EVERY (λy. LENGTH (FST y) = LENGTH ts) ys`,
  ho_match_mp_tac scan_expr_ind
  \\ rw [scan_expr_def] \\ fs []
  \\ rpt (pairarg_tac \\ fs [])
  \\ TRY (PURE_CASE_TAC \\ fs [case_eq_thms, case_elim_thms, pair_case_eq])
  \\ rw [LENGTH_MAP2_MIN, try_update_LENGTH]
  \\ fs [LAST1_def, case_eq_thms] \\ rw [] \\ fs []
  \\ imp_res_tac EVERY_LAST1 \\ fs []
  \\ Cases_on `op` \\ fs [arg_ty_def, update_context_def, check_op_def]
  \\ fs [opbinargs_def, get_bin_args_def, op_type_def]
  \\ fs [LENGTH_MAP2_MIN, try_update_LENGTH]);

val ty_rel_decide_ty = Q.store_thm ("ty_rel_decide_ty",
  `∀ts tt env.
     (ty_rel env ts ∨ ty_rel env tt) ∧ LENGTH ts = LENGTH tt ⇒
       ty_rel env (MAP2 decide_ty ts tt)`,
  Induct \\ rw [] \\ fs []
  \\ Cases_on `tt` \\ rfs [ty_rel_def]
  \\ EVAL_TAC \\ fs [] \\ rveq
  \\ Cases_on `h`  \\ fs [] \\ Cases_on `h'` \\ simp [decide_ty_def]);

val ty_rel_APPEND = Q.prove (
  `∀env ts ws vs.
     ty_rel env ts ∧ ty_rel vs ws ⇒ ty_rel (vs ++ env) (ws ++ ts)`,
  rw []
  \\ sg `LENGTH ws = LENGTH vs`
  >- (fs [ty_rel_def, LIST_REL_EL_EQN])
  \\ fs [ty_rel_def, LIST_REL_APPEND_EQ]);

val LAST1_thm = Q.store_thm("LAST1_thm",
  `!xs. LAST1 xs = NONE <=> xs = []`,
  Induct \\ rw [LAST1_def]
  \\ Cases_on `xs` \\ fs [LAST1_def]);

val scan_expr_ty_rel = Q.store_thm ("scan_expr_ty_rel",
  `∀ts loc xs env ys (s: 'ffi bviSem$state) vs (t: 'ffi bviSem$state).
     ty_rel env ts ∧
     scan_expr ts loc xs = ys ∧
     evaluate (xs, env, s) = (Rval vs, t) ⇒
       EVERY (ty_rel env o FST) ys ∧
       ty_rel vs (MAP (FST o SND) ys)`,
  ho_match_mp_tac scan_expr_ind
  \\ fs [scan_expr_def]
  \\ rpt conj_tac
  \\ rpt gen_tac
  \\ simp [evaluate_def]
  \\ TRY (fs [ty_rel_def] \\ NO_TAC)
  >- (* Cons *)
   (fs [case_eq_thms, pair_case_eq, case_elim_thms, PULL_EXISTS] \\ rw []
    \\ rpt (pairarg_tac \\ fs [])
    \\ fs [ty_rel_def]
    \\ res_tac \\ fs [] \\ rw [])
  >- (* Var *)
   (rw []
    \\ fs [ty_rel_def, LIST_REL_EL_EQN]
    \\ rw []
    \\ metis_tac [])
  \\ strip_tac
  \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs [])
  \\ TRY (* All but Let, Op *)
   (fs [case_eq_thms, pair_case_eq, case_elim_thms, bool_case_eq, PULL_EXISTS]
    \\ rw []
    \\ res_tac \\ fs [] \\ rw []
    \\ TRY (metis_tac [])
    \\ imp_res_tac evaluate_SING_IMP \\ fs []
    \\ imp_res_tac scan_expr_LENGTH \\ fs []
    \\ TRY (fs [ty_rel_def] \\ NO_TAC)
    \\ Cases_on `ty1` \\ fs []
    \\ TRY (metis_tac [ty_rel_decide_ty])
    \\ fs [decide_ty_def, ty_rel_def]
    \\ metis_tac [])
  >- (* Let *)
   (fs [case_eq_thms, pair_case_eq, case_elim_thms, bool_case_eq]
    \\ fs [PULL_EXISTS]
    \\ rpt (gen_tac ORELSE DISCH_TAC) \\ fs []
    \\ reverse conj_tac
    \\ qpat_x_assum `scan_expr _ _ [x] = _` mp_tac
    \\ CASE_TAC \\ fs [LAST1_thm]
    \\ strip_tac
    \\ res_tac \\ rfs []
    \\ TRY (fs [ty_rel_def, LIST_REL_LENGTH] \\ NO_TAC)
    \\ TRY
     (pop_assum mp_tac
      \\ rw [ty_rel_def] \\ fs [] \\ rfs []
      \\ pop_assum mp_tac
      \\ rw [ty_rel_def]
      \\ res_tac
      \\ fs [LIST_REL_EL_EQN]
      \\ imp_res_tac scan_expr_LENGTH \\ fs []
      \\ imp_res_tac evaluate_IMP_LENGTH \\ fs [] \\ rveq
      \\ fs [ty_rel_def, LIST_REL_EL_EQN]
      \\ NO_TAC)
    \\ rw []
    \\ imp_res_tac evaluate_IMP_LENGTH \\ fs [] \\ rveq
    \\ fs [LENGTH_EQ_NUM_compute] \\ rveq
    \\ imp_res_tac EVERY_LAST1 \\ fs []
    \\ fs [ty_rel_APPEND]
    \\ rpt (qpat_x_assum `ty_rel _ _` mp_tac)
    \\ rw [ty_rel_def, LIST_REL_EL_EQN]
    \\ rfs [EL_DROP]
    \\ `n + LENGTH vs' < LENGTH tu` by fs []
    \\ rpt (first_x_assum drule) \\ rw []
    \\ rfs [EL_APPEND1, EL_APPEND2, EL_LENGTH_APPEND])
  \\ CASE_TAC \\ fs []
  >-
   (Cases_on `op` \\ fs [arg_ty_def, op_ty_def]
    \\ fs [ty_rel_def, case_eq_thms, case_elim_thms, pair_case_eq, bool_case_eq] \\ rw []
    \\ fs [term_ok_def, evaluate_def, get_bin_args_def] \\ rw []
    \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def] \\ rw []
    \\ fs [case_eq_thms, case_elim_thms, pair_case_eq, bool_case_eq] \\ rw []
    \\ fs [evaluate_def] \\ rw []
    \\ fs [bvlSemTheory.v_to_list_def, small_enough_int_def, small_int_def])
  \\ rveq
  \\ fs [evaluate_def]
  \\ fs [pair_case_eq, case_eq_thms] \\ rw []
  \\ imp_res_tac evaluate_IMP_LENGTH \\ fs []
  \\ fs [LENGTH_EQ_NUM_compute] \\ rveq
  \\ fs [LENGTH_EQ_NUM_compute] \\ rveq \\ fs []
  \\ TRY
   (Cases_on `op` \\ fs [term_ok_def, op_ty_def]
    \\ simp [ty_rel_def]
    \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def] \\ rw []
    \\ fs [bvlSemTheory.v_to_list_def]
    \\ imp_res_tac term_ok_SING \\ fs [] \\ rw []
    \\ fs [case_eq_thms, case_elim_thms, pair_case_eq] \\ rw []
    \\ every_case_tac \\ fs [] \\ rw []
    \\ NO_TAC)
  \\ CASE_TAC \\ fs []
  \\ cheat (* TODO *)
  );

val rewrite_scan_expr = Q.store_thm ("rewrite_scan_expr",
  `!loc next op acc ts exp tt ty p exp2 r opr.
   rewrite loc next op acc ts exp = (p,exp2) /\
   op <> Noop /\
   scan_expr ts loc [exp] = [(tt, ty, r, opr)] ==>
     case opr of
       SOME op1 => op = op1 ==> p
     | NONE     => ~p`,
  recInduct rewrite_ind
  \\ rw [rewrite_def, scan_expr_def] \\ fs []
  \\ rpt (pairarg_tac \\ fs []) \\ rveq
  \\ fs [check_op_def, case_eq_thms, case_elim_thms, bool_case_eq, pair_case_eq]
  \\ fs [] \\ rveq
  \\ Cases_on `opr` \\ fs [from_op_def]
  \\ fs [case_eq_thms, case_elim_thms, bool_case_eq, pair_case_eq]
  \\ fs [opbinargs_def, to_op_def, get_bin_args_def]
  \\ Cases_on `v23` \\ fs [from_op_def, op_type_def, term_ok_def]);

val optimized_code_def = Define `
  optimized_code loc arity exp n c op =
    ∃exp_aux exp_opt.
        compile_exp loc n arity exp = SOME (exp_aux, exp_opt) ∧
        check_exp loc arity exp     = SOME op ∧
        lookup loc c                = SOME (arity, exp_aux) ∧
        lookup n c                  = SOME (arity + 1, exp_opt)`;

val op_rel_def = Define `
  (op_rel Append x <=> x = Append) /\
  (op_rel x Append <=> x = Append) /\
  (op_rel Plus x <=> x = Plus \/ x = Times) /\
  (op_rel x Plus <=> x = Plus \/ x = Times) /\
  (op_rel Times x <=> x = Plus \/ x = Times) /\
  (op_rel x Times <=> x = Plus \/ x = Times) /\
  (op_rel Noop x <=> x = Noop) /\
  (op_rel x Noop <=> x = Noop)` |> SIMP_RULE (srw_ss()) []

val decide_ty_lem = Q.store_thm("decide_ty_lem",
  `decide_ty ty1 ty2 = ty3 /\
   ty3 <> Any ==>
     ty1 = ty3 /\ ty2 = ty3`,
  Cases_on `ty3` \\ fs []);

val op_type_lem = Q.store_thm("op_type_lem[simp]",
  `op <> Noop <=> op_type op <> Any`,
  Cases_on `op` \\ fs [op_type_def]);

val op_type_lem1 = Q.store_thm("op_type_lem1[simp]",
  `op_rel op1 op2 <=> op_type op1 = op_type op2`,
  Cases_on `op1` \\ Cases_on `op2` \\ fs [op_type_def, op_rel_def]);

val scan_expr_check_op = Q.store_thm("scan_expr_check_op",
  `scan_expr ts loc [Op op xs] = [(tt, ty, r, SOME opr)] ==>
     check_op ts opr loc (Op op xs)`,
  once_rewrite_tac [scan_expr_def] \\ rw [] \\ fs []);

val scan_expr_op_same = Q.store_thm("scan_expr_op_same",
  `scan_expr ts loc [Op op xs] = [(tt, ty, r, SOME opr)] ==>
     op = to_op opr`,
  once_rewrite_tac [scan_expr_def]
  \\ rw [check_op_def, opbinargs_def, get_bin_args_def]
  \\ fs [case_eq_thms, case_elim_thms, pair_case_eq, bool_case_eq]);

val do_assocr_op = Q.store_thm("do_assocr_op",
  `?ys. do_assocr (from_op op) (Op op xs) = Op op ys`,
  once_rewrite_tac [do_assocr_def]
  \\ rw [opbinargs_def, get_bin_args_def]
  \\ every_case_tac \\ fs []
  \\ fs [apply_op_def]);

val comml_op = Q.store_thm("comml_op",
  `?ys. comml loc (Op op xs) = Op op ys`,
  rw [comml_def]
  \\ once_rewrite_tac [do_comml_def]
  \\ fs [opbinargs_def, get_bin_args_def]
  \\ every_case_tac \\ fs []
  \\ fs [apply_op_def]);

val from_op_to_op = Q.store_thm("from_op_to_op[simp]",
  `from_op (to_op opr) = opr`,
  Cases_on `opr` \\ fs [from_op_def, to_op_def]);

val term_ok_extend = Q.store_thm("term_ok_extend",
  `!ts ty exp extra.
     term_ok ts ty exp ==> term_ok (ts ++ extra) ty exp`,
  recInduct term_ok_ind \\ rw []
  \\ pop_assum mp_tac
  \\ Cases_on `ty = Any` \\ fs []
  \\ simp [term_ok_def]
  \\ rw [] \\ rfs []
  \\ fs [EL_APPEND1, EVERY_MEM]);

val evaluate_rewrite_tail = Q.store_thm ("evaluate_rewrite_tail",
  `∀xs (s:'ffi bviSem$state) env1 r t opt c acc env2 loc ts ty.
     evaluate (xs, env1, s) = (r, t) ∧
     env_rel ty opt acc env1 env2 ∧
     code_rel s.code c ∧
     ty_rel env1 ts ∧
     (opt ⇒ LENGTH xs = 1) ∧
     r ≠ Rerr (Rabort Rtype_error) ⇒
       evaluate (xs, env2, s with code := c) = (r, t with code := c) ∧
       (opt ⇒
         ∀op n exp arity.
           op_type op = ty /\
           lookup loc s.code = SOME (arity, exp) ∧
           optimized_code loc arity exp n c op ∧
           (∃tt ty r.
             scan_expr ts loc [HD xs] = [(tt, ty, r, SOME op)] ∧
             op ≠ Noop ∧ ty = op_type op) ⇒
               let (lr, x) = rewrite loc n op acc ts (HD xs) in
                 evaluate ([x], env2, s with code := c) =
                 evaluate ([apply_op op (HD xs) (Var acc)],
                   env2, s with code := c))`,
  ho_match_mp_tac evaluate_complete_ind
  \\ ntac 2 (rpt gen_tac \\ strip_tac)
  \\ Cases_on `xs` \\ fs []
  >- fs [evaluate_def]
  \\ qpat_x_assum `evaluate _ = _` mp_tac
  \\ reverse (Cases_on `t'`) \\ fs []
  >-
   (simp [evaluate_def]
    \\ PURE_TOP_CASE_TAC \\ fs []
    \\ reverse PURE_TOP_CASE_TAC \\ fs []
    >-
     (rw []
      \\ first_assum (qspecl_then [`[h]`,`s`] mp_tac)
      \\ simp [bviTheory.exp_size_def]
      \\ rpt (disch_then drule) \\ fs [])
    \\ qmatch_goalsub_rename_tac `evaluate (y::ys, env1, s2)`
    \\ first_assum (qspecl_then [`[h]`,`s`] mp_tac)
    \\ simp [bviTheory.exp_size_def]
    \\ rpt (disch_then drule) \\ fs []
    \\ strip_tac
    \\ ntac 2 PURE_TOP_CASE_TAC \\ fs [] \\ rveq
    \\ PURE_TOP_CASE_TAC \\ fs [] \\ rw []
    \\ first_assum (qspecl_then [`y::ys`,`s2`] mp_tac)
    \\ imp_res_tac evaluate_clock
    \\ imp_res_tac evaluate_code_const
    \\ simp [bviTheory.exp_size_def]
    \\ rpt (disch_then drule) \\ fs [])
  \\ fs [bviTheory.exp_size_def]
  \\ Cases_on `∃v. h = Var v` \\ fs [] \\ rveq
  >-
   (simp [evaluate_def]
    \\ `LENGTH env1 ≤ LENGTH env2` by metis_tac [env_rel_def, IS_PREFIX_LENGTH]
    \\ fs [env_rel_def, scan_expr_def] \\ rw []
    \\ fs [is_prefix_el])
  \\ Cases_on `∃x1. h = Tick x1` \\ fs [] \\ rveq
  >-
   (rw [evaluate_def, scan_expr_def, rewrite_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rw []
    \\ fs [evaluate_def, apply_op_def, rewrite_def]
    \\ first_x_assum (qspecl_then [`[x1]`,`dec_clock 1 s`] mp_tac)
    \\ fs [bviTheory.exp_size_def, evaluate_clock, dec_clock_def]
    \\ `env_rel ty F acc env1 env2` by fs [env_rel_def]
    \\ imp_res_tac evaluate_code_const \\ fs []
    >- (rpt (disch_then drule) \\ fs [] \\ rw [])
    \\ qpat_x_assum `env_rel _ F _ _ _` kall_tac
    \\ rpt (disch_then drule)
    \\ disch_then (qspec_then `loc` mp_tac)
    \\ fs [scan_expr_def, rewrite_def]
    \\ rw []
    \\ first_x_assum drule
    \\ pairarg_tac \\ fs [])
  \\ Cases_on `∃x1. h = Raise x1` \\ fs [] \\ rveq
  >-
   (simp [scan_expr_def, evaluate_def, rewrite_def]
    \\ `env_rel ty F acc env1 env2` by fs [env_rel_def]
    \\ CASE_TAC \\ fs []
    \\ fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS]
    \\ first_x_assum (qspecl_then [`[x1]`,`s`] mp_tac)
    \\ simp [bviTheory.exp_size_def]
    \\ rpt (disch_then drule) \\ rw [])
  \\ Cases_on `∃xs x1. h = Let xs x1` \\ fs [] \\ rveq
  >-
   (simp [evaluate_def]
    \\ `env_rel ty F acc env1 env2` by fs [env_rel_def]
    \\ CASE_TAC \\ fs []
    \\ strip_tac
    \\ first_assum (qspecl_then [`xs`,`s`] mp_tac)
    \\ impl_tac
    >- simp [bviTheory.exp_size_def]
    \\ rpt (disch_then drule) \\ fs []
    \\ impl_tac
    >- fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
    \\ strip_tac
    \\ fs []
    \\ reverse CASE_TAC \\ fs []
    >-
     (rw [rewrite_def, scan_expr_def]
      \\ rpt (pairarg_tac \\ fs []) \\ rw []
      \\ fs [evaluate_def, apply_op_def])
    \\ rename1 `evaluate (xs,env1,s) = (Rval zz, s2)`
    \\ sg `env_rel ty opt (LENGTH zz + acc) (zz ++ env1) (zz ++ env2)`
    >-
     (fs [env_rel_def]
      \\ strip_tac
      \\ fs [IS_PREFIX_LENGTH, IS_PREFIX_APPEND, EL_LENGTH_APPEND, EL_APPEND1]
      \\ simp_tac std_ss [ADD_ASSOC] \\ fs []
      \\ rfs [case_eq_thms, case_elim_thms, bool_case_eq, v_ty_cases, EL_LENGTH_APPEND, EL_APPEND1, EL_APPEND2])
    \\ qabbrev_tac `ttt = scan_expr ts loc xs`
    \\ sg `ty_rel (zz ++ env1) (MAP (FST o SND) ttt ++ (case LAST1 ttt of SOME z => FST z | NONE => ts))`
    >-
     (match_mp_tac ty_rel_APPEND
      \\ drule scan_expr_ty_rel
      \\ disch_then (qspecl_then [`loc`,`xs`,`ttt`,`s`] mp_tac)
      \\ qunabbrev_tac `ttt`
      \\ simp []
      \\ strip_tac
      \\ CASE_TAC \\ fs []
      \\ imp_res_tac EVERY_LAST1 \\ fs [])
    \\ qunabbrev_tac `ttt`
    \\ first_assum (qspecl_then [`[x1]`,`s2`] mp_tac)
    \\ impl_tac
    >-
     (imp_res_tac evaluate_clock
      \\ simp [bviTheory.exp_size_def])
    \\ imp_res_tac evaluate_code_const \\ fs []
    \\ rpt (disch_then drule)
    \\ disch_then (qspec_then `loc` mp_tac)
    \\ rw []
    \\ pairarg_tac \\ fs []
    \\ first_x_assum (qspec_then `op` mp_tac) \\ fs []
    \\ disch_then drule
    \\ fs [scan_expr_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ qpat_x_assum `rewrite _ _ _ _ _ (Let _ _) = _` mp_tac
    \\ simp [rewrite_def]
    \\ pairarg_tac \\ fs [] \\ rw []
    \\ `acc < LENGTH env2` by fs [env_rel_def]
    \\ `LENGTH xs = LENGTH zz` by metis_tac [evaluate_IMP_LENGTH]
    \\ pop_assum (fn th => fs [th]) \\ rw []
    \\ simp [apply_op_def, evaluate_def, EL_LENGTH_APPEND, EL_APPEND2])
  \\ Cases_on `∃x1 x2 x3. h = If x1 x2 x3` \\ fs [] \\ rveq
  >-
   (
    simp [evaluate_def]
    \\ `env_rel ty F acc env1 env2` by fs [env_rel_def]
    \\ PURE_TOP_CASE_TAC \\ fs []
    \\ reverse PURE_TOP_CASE_TAC \\ fs []
    >-
     (strip_tac \\ rveq \\ fs []
      \\ first_assum (qspecl_then [`[x1]`,`s`] mp_tac)
      \\ simp [bviTheory.exp_size_def]
      \\ rpt (disch_then drule) \\ fs [] \\ rw []
      \\ pairarg_tac \\ fs []
      \\ fs [rewrite_def, comml_def, assocr_def]
      \\ rpt (pairarg_tac \\ fs [])
      \\ rw [evaluate_def, apply_op_def])
    \\ first_assum (qspecl_then [`[x1]`,`s`] mp_tac)
    \\ simp [bviTheory.exp_size_def]
    \\ rpt (disch_then drule) \\ fs []
    \\ strip_tac
    \\ reverse (Cases_on `opt`) \\ fs []
    \\ rename1 `evaluate ([x1],_,s) = (_,s2)`
    >-
     (IF_CASES_TAC \\ fs []
      >-
       (strip_tac
        \\ first_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
        \\ imp_res_tac evaluate_clock
        \\ imp_res_tac evaluate_code_const
        \\ simp [bviTheory.exp_size_def]
        \\ rpt (disch_then drule) \\ fs [])
      \\ IF_CASES_TAC \\ fs []
      \\ strip_tac
      \\ first_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
      \\ imp_res_tac evaluate_clock
      \\ imp_res_tac evaluate_code_const
      \\ simp [bviTheory.exp_size_def]
      \\ rpt (disch_then drule) \\ fs [])
    \\ strip_tac
    \\ conj_tac
    >-
     (IF_CASES_TAC \\ fs []
      >-
       (first_x_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
        \\ imp_res_tac evaluate_clock \\ fs []
        \\ imp_res_tac evaluate_code_const \\ fs []
        \\ simp [bviTheory.exp_size_def]
        \\ rpt (disch_then drule) \\ fs [])
      \\ IF_CASES_TAC \\ fs []
      \\ first_x_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
      \\ imp_res_tac evaluate_clock \\ fs []
      \\ imp_res_tac evaluate_code_const \\ fs []
      \\ simp [bviTheory.exp_size_def]
      \\ rpt (disch_then drule) \\ fs [])
    \\ rw []
    \\ fs [rewrite_def, evaluate_def, scan_expr_def]
    \\ rpt (pairarg_tac \\ fs [])
    \\ sg `ty_rel env1 ti`
    >-
     (drule scan_expr_ty_rel
      \\ rpt (disch_then drule)
      \\ rw [])
    \\ rw []
    \\ cheat (* TODO *)
    (*
    >- (* xt ∧ xe optimized *)
     (qpat_x_assum `_ = (r, t)` mp_tac
      \\ IF_CASES_TAC \\ fs []
      >-
       (strip_tac
        \\ first_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
        \\ impl_tac
        >-
         (imp_res_tac evaluate_clock
          \\ simp [bviTheory.exp_size_def])
        \\ imp_res_tac evaluate_code_const \\ fs []
        \\ disch_then drule
        \\ disch_then (qspec_then `T` drule)
        \\ rpt (disch_then drule)
        \\ disch_then (qspec_then `loc` mp_tac) \\ rw []
        \\ first_x_assum (qspec_then `op` mp_tac) \\ fs []
        \\ disch_then drule
        \\ impl_tac
        >-
         (fs [optimized_code_def]
          \\ drule rewrite_scan_expr
          \\ rpt (disch_then drule)
          \\ qpat_x_assum `rewrite _ _ _ _ _ (_ (_ x3)) = _` kall_tac
          \\ drule rewrite_scan_expr
          \\ rpt (disch_then drule)
          \\ fs [case_elim_thms, case_eq_thms] \\ rw []
          \\ metis_tac [op_type_lem, decide_ty_lem])
        \\ pairarg_tac \\ fs []
        \\ rw [evaluate_def, apply_op_def])
      \\ IF_CASES_TAC \\ fs [] \\ rw []
      \\ first_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
      \\ impl_tac
      >-
       (imp_res_tac evaluate_clock
        \\ simp [bviTheory.exp_size_def])
      \\ imp_res_tac evaluate_code_const \\ fs []
      \\ disch_then drule
      \\ disch_then (qspec_then `T` drule)
      \\ rpt (disch_then drule)
      \\ disch_then (qspec_then `loc` mp_tac) \\ rw []
      \\ first_x_assum (qspec_then `op` mp_tac) \\ fs []
      \\ disch_then drule
      \\ impl_tac
      >-
       (
        fs [optimized_code_def]
        \\ imp_res_tac scan_expr_not_Noop
        \\ drule rewrite_scan_expr
        \\ rpt (disch_then drule)
        \\ cheat (* TODO *)
        )
      \\ pairarg_tac \\ fs []
      \\ rw [evaluate_def, apply_op_def])
    >- (* xt optimized, xe untouched *)
     (qpat_x_assum `_ = (r, t)` mp_tac
      \\ IF_CASES_TAC \\ fs []
      >-
       (strip_tac
        \\ first_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
        \\ impl_tac
        >-
         (imp_res_tac evaluate_clock
          \\ simp [bviTheory.exp_size_def])
        \\ imp_res_tac evaluate_code_const \\ fs []
        \\ disch_then drule
        \\ disch_then (qspec_then `T` drule)
        \\ rpt (disch_then drule)
        \\ disch_then (qspec_then `loc` mp_tac) \\ rw []
        \\ first_x_assum drule
        \\ impl_tac
        >-
         (fs [optimized_code_def]
          \\ imp_res_tac scan_expr_not_Noop
          \\ qpat_x_assum `rewrite _ x3 = _` kall_tac
          \\ drule rewrite_scan_expr
          \\ rpt (disch_then drule)
          \\ PURE_CASE_TAC \\ fs [])
        \\ pairarg_tac \\ fs []
        \\ rw [evaluate_def, apply_op_def])
      \\ IF_CASES_TAC \\ fs [] \\ rw []
      \\ first_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
      \\ impl_tac
      >-
       (imp_res_tac evaluate_clock
        \\ simp [bviTheory.exp_size_def])
      \\ imp_res_tac evaluate_code_const \\ fs []
      \\ rpt (disch_then drule)
      \\ rw [evaluate_def, apply_op_def])
    >- (* xe optimized, xt untouched *)
     (qpat_x_assum `_ = (r, t)` mp_tac
      \\ IF_CASES_TAC \\ fs []
      >-
       (strip_tac
        \\ first_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
        \\ impl_tac
        >-
         (imp_res_tac evaluate_clock
          \\ simp [bviTheory.exp_size_def])
        \\ imp_res_tac evaluate_code_const \\ fs []
        \\ rpt (disch_then drule)
        \\ rw [evaluate_def, apply_op_def])
      \\ IF_CASES_TAC \\ fs [] \\ rw []
      \\ first_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
      \\ impl_tac
      >-
       (imp_res_tac evaluate_clock
        \\ simp [bviTheory.exp_size_def])
      \\ imp_res_tac evaluate_code_const \\ fs []
      \\ disch_then drule
      \\ disch_then (qspec_then `T` drule)
      \\ rpt (disch_then drule)
      \\ disch_then (qspec_then `loc` mp_tac) \\ rw []
      \\ first_x_assum drule
      \\ impl_tac
      >-
       (fs [optimized_code_def]
        \\ imp_res_tac scan_expr_not_Noop
        \\ drule rewrite_scan_expr
        \\ rpt (disch_then drule)
        \\ PURE_CASE_TAC \\ fs []
        \\ imp_res_tac scan_expr_not_Noop)
      \\ pairarg_tac \\ fs []
      \\ rw [evaluate_def, apply_op_def])
    \\ qpat_x_assum `_ = (r, t)` mp_tac
    \\ IF_CASES_TAC \\ fs []
    >-
     (strip_tac
      \\ first_assum (qspecl_then [`[x2]`,`s2`] mp_tac)
      \\ impl_tac
      >-
       (imp_res_tac evaluate_clock
        \\ simp [bviTheory.exp_size_def])
      \\ imp_res_tac evaluate_code_const \\ fs []
      \\ rpt (disch_then drule)
      \\ rw [evaluate_def, apply_op_def])
    \\ IF_CASES_TAC \\ fs [] \\ rw []
    \\ first_assum (qspecl_then [`[x3]`,`s2`] mp_tac)
    \\ impl_tac
    >-
     (imp_res_tac evaluate_clock
      \\ simp [bviTheory.exp_size_def])
    \\ imp_res_tac evaluate_code_const \\ fs []
    \\ rpt (disch_then drule)
    \\ rw [evaluate_def, apply_op_def])
  *)
  )
  \\ Cases_on `∃xs op. h = Op op xs` \\ fs [] \\ rveq
  >-
   (
    simp [evaluate_def]
    \\ PURE_TOP_CASE_TAC \\ fs []
    \\ strip_tac
    \\ conj_tac
    >-
     (first_x_assum (qspecl_then [`xs`, `s`] mp_tac)
      \\ simp [bviTheory.exp_size_def]
      \\ `env_rel ty F acc env1 env2` by fs [env_rel_def]
      \\ rpt (disch_then drule)
      \\ disch_then (qspec_then `loc` mp_tac) \\ fs [] \\ rw []
      \\ fs [case_eq_thms, case_elim_thms, pair_case_eq, bool_case_eq]
      \\ metis_tac [code_rel_domain, evaluate_code_const, do_app_with_code,
                    do_app_with_code_err, do_app_err])
    \\ rw []
    \\ pairarg_tac \\ fs []
    \\ pop_assum mp_tac
    \\ qpat_x_assum `scan_expr _ _ _ = _` mp_tac
    \\ fs [rewrite_def, scan_expr_def, opbinargs_def]
    \\ strip_tac \\ rveq
    \\ IF_CASES_TAC \\ fs []
    \\ IF_CASES_TAC \\ fs []
    >- (Cases_on `op` \\ fs [to_op_def, from_op_def, op_type_def, check_op_def])
    \\ PURE_CASE_TAC \\ fs []
    >-
     (rw []
      \\ fs [check_op_def, opbinargs_def, bool_case_eq, pair_case_eq, case_eq_thms, case_elim_thms]
      \\ rw [] \\ fs [get_bin_args_def])
    \\ rw []
    \\ qpat_x_assum `check_op _ _ _ _` mp_tac
    \\ simp [check_op_def, opbinargs_def, get_bin_args_def]
    \\ rw []
    \\ sg `∃ticks args. e1 = Call ticks (SOME loc) args NONE`
    >-
     (Cases_on `e1` \\ fs [is_rec_def]
      \\ rename1 `_ /\ z = NONE`
      \\ Cases_on `z` \\ fs [is_rec_def])
    \\ rw []
    \\ simp [args_from_def, push_call_def, apply_op_def]
    \\ Cases_on `evaluate (args, env1, s)`
    \\ first_assum (qspecl_then [`args`,`s`] mp_tac)
    \\ impl_tac
    >- simp [bviTheory.exp_size_def]
    \\ sg `env_rel ty F acc env1 env2`
    >- fs [env_rel_def]
    \\ rpt (disch_then drule) \\ fs []
    \\ impl_tac
    >- (fs [evaluate_def,pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq] \\ rw [])
    \\ strip_tac
    \\ rename1 `_ = (res_args, st_args with code := c)`
    \\ Cases_on `evaluate ([e2], env1, st_args)`
    \\ drule term_ok_SING
    \\ rpt (disch_then drule) \\ rw []
    \\ rename1 `_ = (Rval [v], st_args)`
    \\ reverse (Cases_on `res_args`)
    >-
     (fs [evaluate_def, case_eq_thms, pair_case_eq, case_elim_thms, bool_case_eq]
      \\ fs [PULL_EXISTS] \\ rw []
      \\ once_rewrite_tac [evaluate_APPEND] \\ fs [])
    \\ sg `ty_rel env2 (ts ++ (REPLICATE (LENGTH env2 - LENGTH env1) Any))`
    >-
     (fs [ty_rel_def, LIST_REL_EL_EQN]
      \\ `LENGTH ts < LENGTH env2` by fs [env_rel_def, IS_PREFIX_LENGTH]
      \\ rw []
      \\ Cases_on `n' < LENGTH ts`
      \\ TRY
       (imp_res_tac is_prefix_el \\ rfs [env_rel_def]
        \\ fs [EL_REPLICATE, EL_LENGTH_APPEND, EL_APPEND1, EL_APPEND2]
        \\ `n' < LENGTH ts` by fs []
        \\ first_x_assum drule
        \\ rw []
        \\ drule is_prefix_el
        \\ fs [IS_PREFIX_LENGTH]
        \\ disch_then drule
        \\ rw [] \\ metis_tac [])
      \\ fs [EL_APPEND2]
      \\ `n' - LENGTH ts < LENGTH env2 - LENGTH ts` by fs []
      \\ fs [EL_REPLICATE])
    \\ drule term_ok_extend
    \\ disch_then (qspec_then `REPLICATE (LENGTH env2 - LENGTH env1) Any` assume_tac)
    \\ Cases_on `evaluate ([e2], env2, s)`
    \\ drule term_ok_SING
    \\ disch_then drule
    \\ disch_then drule \\ rw [] \\ fs []
    \\ qpat_x_assum `term_ok _ _ e2` kall_tac
    \\ qpat_x_assum `ty_rel env2 _` kall_tac
    \\ rename1 `evaluate (args,env2,s with code := c)`
    \\ sg `v = v'`
    >-
     (first_x_assum (qspecl_then [`[e2]`, `s`] mp_tac)
      \\ simp [bviTheory.exp_size_def]
      \\ imp_res_tac evaluate_clock \\ fs []
      \\ Cases_on `evaluate ([e2],env1,s)`
      \\ rpt (disch_then drule) \\ fs [] \\ rw []
      \\ first_x_assum (qspec_then `s` assume_tac)
      \\ first_x_assum (qspec_then `s` assume_tac)
      \\ rfs [] \\ rw [])
    \\ rveq \\ fs []
    \\ simp [evaluate_def]
    \\ once_rewrite_tac [evaluate_APPEND]
    \\ simp [evaluate_def]
    \\ `acc < LENGTH env2` by fs [env_rel_def]
    \\ pop_assum (fn th => fs [th])
    \\ sg `?val.
           do_app (to_op (from_op op)) [EL acc env2; v] (st_args with code := c) =
             Rval (val, st_args with code := c) /\
           case op_type (from_op op) of
             Int => ?k. val = Number k
           | List => ?ys. v_to_list val = SOME ys
           | Any => T`
    >-
     (Cases_on `op` \\ fs [to_op_def, from_op_def, op_type_def]
      \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def]
      \\ fs [env_rel_def]
      \\ fs [bvl_to_bvi_id])
    \\ fs []
    \\ imp_res_tac evaluate_code_const
    \\ fs [optimized_code_def, find_code_def]
    \\ IF_CASES_TAC \\ fs []
    \\ IF_CASES_TAC \\ fs []
    \\ qpat_x_assum `compile_exp _ _ _ _ = _` mp_tac
    \\ simp [compile_exp_def]
    \\ PURE_TOP_CASE_TAC \\ fs []
    \\ pairarg_tac \\ fs [] \\ rw []
    \\ imp_res_tac scan_expr_not_Noop \\ fs []
    \\ simp [evaluate_let_wrap]
    \\ qpat_x_assum `evaluate ([_;e2],_,_) = _` mp_tac
    \\ simp [evaluate_def, find_code_def]
    \\ PURE_CASE_TAC \\ fs []
    \\ rename1 `_ = (res_exp, st_exp)`
    \\ Cases_on `res_exp = Rerr (Rabort Rtype_error)` \\ fs []
    >- (rw [] \\ fs [case_eq_thms, case_elim_thms, bool_case_eq, pair_case_eq])
    \\ strip_tac
    \\ sg `env_rel (op_type (from_op op)) T (LENGTH a) a (a ++ [val])`
    >-
     (fs [env_rel_def]
      \\ Cases_on `op` \\ fs [op_type_def, from_op_def, EL_APPEND1, EL_LENGTH_APPEND])
    \\ sg `ty_rel a (REPLICATE (LENGTH a) Any)`
    >- fs [ty_rel_def, LIST_REL_EL_EQN, EL_REPLICATE]
    \\ drule assocr_correct \\ rw []
    \\ drule comml_correct
    \\ disch_then (qspec_then `loc` mp_tac) \\ rw []
    \\ first_assum (qspecl_then [`[comml loc (assocr exp)]`, `dec_clock (ticks+1) st_args`] mp_tac)
    \\ impl_tac
    >-
     (imp_res_tac evaluate_clock
      \\ fs [dec_clock_def])
    \\ rpt (disch_then drule)
    \\ imp_res_tac evaluate_code_const \\ fs []
    \\ disch_then (qspecl_then [`c`,`loc`,`REPLICATE (LENGTH a) Any`] mp_tac)
    \\ rw []
    \\ first_x_assum (qspec_then `n` mp_tac)
    \\ simp [compile_exp_def, check_exp_def]
    \\ rw []
    \\ pop_assum kall_tac
    \\ sg `env_rel (op_type (from_op op)) T (LENGTH a) a (a ++ [op_id_val (from_op op)] ++ a)`
    >-
     (fs [env_rel_def]
      \\ Cases_on `op` \\ fs [op_id_val_def, op_type_def, from_op_def, EL_APPEND1, EL_LENGTH_APPEND, IS_PREFIX_APPEND, bvlSemTheory.v_to_list_def])
    \\ first_x_assum (qspecl_then [`[comml loc (assocr exp)]`, `dec_clock (ticks+1) st_args`] mp_tac)
    \\ impl_tac
    >-
     (imp_res_tac evaluate_clock
      \\ fs [dec_clock_def])
    \\ rpt (disch_then drule)
    \\ imp_res_tac evaluate_code_const \\ fs []
    \\ disch_then (qspecl_then [`c`,`loc`,`REPLICATE (LENGTH a) Any`] mp_tac)
    \\ rw []
    \\ first_x_assum (qspec_then `n` mp_tac)
    \\ simp [compile_exp_def, check_exp_def]
    \\ rw []
    \\ pop_assum kall_tac
    \\ fs [apply_op_def, evaluate_def]
    \\ reverse (Cases_on `res_exp`) \\ fs []
    >-
     (fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS]
      \\ rw [])
    \\ fs [env_rel_def, EL_LENGTH_APPEND, EL_APPEND1]
    \\ rw [] \\ fs []
    \\ drule scan_expr_ty_rel
    \\ rpt (disch_then drule) \\ fs [] \\ rw []
    \\ pop_assum mp_tac
    \\ simp [ty_rel_def] \\ rw []
    \\ Cases_on `op` \\ fs [to_op_def, from_op_def, op_type_def, op_id_val_def]
    \\ rw []
    \\ fs [do_app_def, do_app_aux_def, bvlSemTheory.do_app_def, bvlSemTheory.v_to_list_def]
    \\ fs [bvl_to_bvi_id] \\ rveq \\ fs []
    \\ fs [bvl_to_bvi_id]
    \\ rfs [] \\ rveq
    \\ TRY intLib.COOPER_TAC
    \\ fs [bvl_to_bvi_id])
  \\ Cases_on `∃ticks dest xs hdl. h = Call ticks dest xs hdl` \\ fs [] \\ rveq
  >-
   (
   simp [scan_expr_def, evaluate_def]
   \\ IF_CASES_TAC
   >- fs []
   \\ `dest = NONE ⇒ ¬IS_SOME hdl` by fs []
   \\ qpat_x_assum `¬(_)` kall_tac
   \\ TOP_CASE_TAC
   \\ first_assum (qspecl_then [`xs`, `s`] mp_tac)
   \\ simp [bviTheory.exp_size_def]
   \\ sg `env_rel ty F acc env1 env2`
   >- fs [env_rel_def]
   \\ rpt (disch_then drule) \\ fs []
   \\ strip_tac
   \\ reverse PURE_TOP_CASE_TAC \\ fs []
   >- (rw [] \\ fs [])
   \\ PURE_TOP_CASE_TAC \\ fs []
   \\ PURE_TOP_CASE_TAC \\ fs []
   \\ IF_CASES_TAC \\ fs []
   >-
    (rw [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS]
     \\ imp_res_tac evaluate_code_const \\ fs []
     \\ simp [scan_expr_def, comml_def, assocr_def]
     \\ rename1 `_ = (Rval _, st with code := c)`
     \\ `code_rel st.code c` by fs []
     \\ Cases_on `find_code dest a c` \\ fs []
     >-
      (Cases_on `dest` \\ fs []
       \\ metis_tac [code_rel_find_code_NONE, code_rel_find_code_SOME])
     \\ PairCases_on `x` \\ fs [])
   \\ rename1 `([exp],args, _ _ s1)`
   \\ Cases_on `dest` \\ fs []
   >-
    (strip_tac
     \\ PURE_TOP_CASE_TAC \\ fs []
     >- metis_tac [evaluate_code_const, code_rel_find_code_NONE]
     \\ PURE_TOP_CASE_TAC \\ fs []
     \\ qpat_x_assum `_ = (r, t)` mp_tac
     \\ PURE_TOP_CASE_TAC \\ fs []
     \\ rpt (qpat_x_assum `find_code _ _ _ = _` mp_tac)
     \\ simp [find_code_def]
     \\ CASE_TAC \\ fs []
     \\ CASE_TAC \\ fs []
     \\ CASE_TAC \\ fs []
     \\ strip_tac \\ rveq
     \\ CASE_TAC \\ fs []
     \\ CASE_TAC \\ fs []
     \\ strip_tac \\ rveq
     \\ sg `code_rel s1.code c`
     >- (imp_res_tac evaluate_code_const \\ fs [])
     \\ qpat_assum `code_rel _ _` mp_tac
     \\ simp_tac std_ss [code_rel_def]
     \\ disch_then drule
     \\ simp [compile_exp_def]
     \\ CASE_TAC \\ fs []
     >-
      (rw []
       \\ sg `env_rel ty F (LENGTH (FRONT a)) (FRONT a) (FRONT a)`
       >- fs [env_rel_def]
       \\ sg `ty_rel (FRONT a) (REPLICATE (LENGTH (FRONT a)) Any)`
       >- fs [ty_rel_def, LIST_REL_EL_EQN, EL_REPLICATE]
       \\ first_assum (qspecl_then [`[exp]`,`dec_clock (ticks+1) s1`] mp_tac)
       \\ impl_tac
       >-
        (imp_res_tac evaluate_clock
         \\ simp [dec_clock_def])
       \\ simp []
       \\ rpt (disch_then drule) \\ fs []
       \\ fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS]
       \\ rw [])
     \\ rw []
     \\ pairarg_tac \\ fs [] \\ rw []
     \\ rename1 `let_wrap qs _ _`
     \\ `qs = LENGTH (FRONT a)` by fs [LENGTH_FRONT]
     \\ pop_assum (fn th => fs [th])
     \\ imp_res_tac scan_expr_not_Noop
     \\ fs [evaluate_let_wrap]
     \\ rename1 `evaluate _ = (res_exp, st_exp)`
     \\ sg `env_rel (op_type x) T (LENGTH (FRONT a)) (FRONT a)
                                  (FRONT a ++ [op_id_val x] ++ FRONT a)`
     >-
       (fs [env_rel_def, EL_LENGTH_APPEND, EL_APPEND1, IS_PREFIX_APPEND]
        \\ Cases_on `x` \\ fs [op_id_val_def, op_type_def, v_ty_cases, bvlSemTheory.v_to_list_def])
     \\ sg `ty_rel (FRONT a) (REPLICATE (LENGTH (FRONT a)) Any)`
     >- fs [ty_rel_def, LIST_REL_EL_EQN, EL_REPLICATE]
     \\ Cases_on `res_exp = Rerr (Rabort Rtype_error)`
     >- fs [pair_case_eq, bool_case_eq, case_eq_thms, case_elim_thms]
     \\ drule assocr_correct \\ rw []
     \\ drule comml_correct
     \\ disch_then (qspec_then `n` mp_tac) \\ rw []
     \\ first_x_assum (qspecl_then [`[comml n (assocr exp)]`,`dec_clock (ticks+1) s1`] mp_tac)
     \\ impl_tac
     >-
      (imp_res_tac evaluate_clock
       \\ simp [dec_clock_def])
     \\ simp []
     \\ rpt (disch_then drule)
     \\ disch_then (qspec_then `n` mp_tac) \\ fs []
     \\ simp [optimized_code_def, compile_exp_def, check_exp_def, scan_expr_def]
     \\ rw []
     \\ first_x_assum (qspec_then `n'` mp_tac) \\ rw []
     \\ fs [evaluate_def, apply_op_def, EL_LENGTH_APPEND, EL_APPEND1]
     \\ fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
     \\ fs [PULL_EXISTS] \\ rw []
     \\ drule scan_expr_ty_rel
     \\ rpt (disch_then drule) \\ rw []
     \\ pop_assum mp_tac \\ rw [ty_rel_def]
     \\ Cases_on `x`
     \\ fs [to_op_def, op_id_val_def, do_app_def, do_app_aux_def,
            bvlSemTheory.do_app_def, bvl_to_bvi_id, op_type_def]
     \\ fs [bvlSemTheory.v_to_list_def]
     \\ fs [case_eq_thms, case_elim_thms, pair_case_eq, bool_case_eq]
     \\ rw []
     \\ fs [bvl_to_bvi_id, list_to_v_imp])
   \\ PURE_TOP_CASE_TAC \\ fs [] \\ rw []
   \\ PURE_TOP_CASE_TAC \\ fs []
   >- metis_tac [code_rel_find_code_SOME, evaluate_code_const]
   \\ PURE_TOP_CASE_TAC \\ fs []
   \\ first_assum (qspecl_then [`[exp]`, `dec_clock (ticks+1) s1`] mp_tac)
   \\ impl_tac
   >-
    (imp_res_tac evaluate_clock
     \\ simp [dec_clock_def])
   \\ `env_rel ty F acc args args` by fs [env_rel_def]
   \\ sg `ty_rel args (REPLICATE (LENGTH args) Any)`
   >- fs [ty_rel_def, LIST_REL_EL_EQN, EL_REPLICATE]
   \\ imp_res_tac evaluate_code_const \\ fs []
   \\ rpt (disch_then drule) \\ fs []
   \\ impl_tac
   >- fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
   \\ rpt (qpat_x_assum `find_code _ _ _ = _` mp_tac)
   \\ simp [find_code_def]
   \\ ntac 4 (PURE_TOP_CASE_TAC \\ fs []) \\ rw []
   \\ qpat_assum `code_rel _ _` mp_tac
   \\ simp_tac std_ss [code_rel_def]
   \\ disch_then drule \\ fs []
   \\ simp [compile_exp_def]
   \\ CASE_TAC \\ fs []
   >-
    (fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS] \\ rw []
     \\ rename1 `([z], aa::env1, s2)`
     \\ first_x_assum (qspecl_then [`[z]`,`s2`] mp_tac)
     \\ impl_tac
     >-
      (imp_res_tac evaluate_clock
       \\ fs [dec_clock_def])
     \\ `env_rel ty F (LENGTH env1 + 1) (aa::env1) (aa::env2)` by fs [env_rel_def]
     \\ sg `ty_rel (aa::env1) (Any::ts)`
     >- fs [ty_rel_def, LIST_REL_EL_EQN]
     \\ imp_res_tac evaluate_code_const \\ fs []
     \\ rpt (disch_then drule) \\ rw [])
   \\ rw []
   \\ pairarg_tac \\ fs [] \\ rw []
   \\ imp_res_tac scan_expr_not_Noop
   \\ fs [evaluate_let_wrap]
   \\ qpat_x_assum `evaluate ([exp], _,_) = _` mp_tac
   \\ drule assocr_correct
   \\ impl_tac
   >- fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
   \\ strip_tac
   \\ drule comml_correct
   \\ disch_then (qspec_then `x` mp_tac)
   \\ impl_tac
   >- fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
   \\ strip_tac
   \\ strip_tac
   \\ first_assum (qspecl_then [`[comml x (assocr exp)]`,`dec_clock (ticks+1) s1`] mp_tac)
   \\ impl_tac
   >-
    (imp_res_tac evaluate_clock
     \\ fs [dec_clock_def])
   \\ sg `env_rel (op_type x') T (LENGTH a) a (a ++ [op_id_val x'] ++ a)`
   >-
    (Cases_on `x'`
     \\ fs [op_id_val_def, op_type_def, env_rel_def, EL_LENGTH_APPEND, EL_APPEND1, IS_PREFIX_APPEND, bvlSemTheory.v_to_list_def])
   \\ sg `ty_rel a (REPLICATE (LENGTH a) Any)`
   >- fs [ty_rel_def, LIST_REL_EL_EQN, EL_REPLICATE]
   \\ imp_res_tac evaluate_code_const \\ fs []
   (*\\ strip_tac*)
   \\ rpt (disch_then drule) \\ fs []
   \\ disch_then (qspec_then `x` mp_tac)
   \\ impl_tac
   >- fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq]
   \\ rw []
   \\ first_x_assum (qspecl_then [`n`] mp_tac)
   \\ rw [optimized_code_def, compile_exp_def, check_exp_def]
   \\ pop_assum kall_tac
   \\ fs [evaluate_def, apply_op_def]
   \\ reverse (PURE_CASE_TAC \\ fs [])
   >-
    (fs [pair_case_eq, case_eq_thms, case_elim_thms, bool_case_eq, PULL_EXISTS] \\ rw []
     \\ rename1 `([z], aa::env1, s2)`
     \\ first_x_assum (qspecl_then [`[z]`,`s2`] mp_tac)
     \\ impl_tac
     >-
      (imp_res_tac evaluate_clock
       \\ fs [dec_clock_def])
     \\ `env_rel (op_type x') F (LENGTH env1 + 1) (aa::env1) (aa::env2)` by fs [env_rel_def]
     \\ `ty_rel (aa::env1) (Any::ts)` by fs [ty_rel_def]
     \\ imp_res_tac evaluate_code_const \\ fs []
     \\ rpt (disch_then drule) \\ rw [])
   \\ simp [EL_LENGTH_APPEND, EL_APPEND1]
   \\ drule scan_expr_ty_rel
   \\ rpt (disch_then drule) \\ rw []
   \\ pop_assum mp_tac
   \\ rw [ty_rel_def]
   \\ Cases_on `x'`
   \\ fs [to_op_def, op_type_def, do_app_def, do_app_aux_def, op_id_val_def,
          bvlSemTheory.do_app_def, bvl_to_bvi_id, bvlSemTheory.v_to_list_def]
   \\ fs [list_to_v_imp])
  \\ Cases_on `h` \\ fs []);

val compile_prog_LENGTH = Q.store_thm ("compile_prog_LENGTH",
  `∀n prog. LENGTH (SND (bvi_tailrec$compile_prog n prog)) ≥ LENGTH prog`,
  recInduct compile_prog_ind
  \\ conj_tac
  >- fs [compile_prog_def]
  \\ rw []
  \\ Cases_on `compile_exp loc next arity exp` \\ fs []
  >-
   (fs [compile_prog_def]
    \\ pairarg_tac \\ fs [])
  \\ PairCases_on `x`
  \\ fs [compile_prog_def]
  \\ pairarg_tac \\ fs []);

val free_names_def = Define `
  free_names n (name: num) ⇔ ∀k. n + bvl_to_bvi_namespaces*k ≠ name
  `;

val more_free_names = Q.prove (
  `free_names n name ⇒ free_names (n + bvl_to_bvi_namespaces) name`,
  fs [free_names_def] \\ rpt strip_tac
  \\ first_x_assum (qspec_then `k + 1` mp_tac) \\ strip_tac
  \\ rw []);

val is_free_name = Q.prove (
  `free_names n name ⇒ n ≠ name`,
  fs [free_names_def] \\ strip_tac
  \\ first_x_assum (qspec_then `0` mp_tac) \\ strip_tac \\ rw []);

val compile_exp_next_addr = Q.prove (
  `compile_exp loc next args exp = NONE ⇒
     compile_exp loc (next + bvl_to_bvi_namespaces) args exp = NONE`,
  fs [compile_exp_def]
  \\ every_case_tac
  \\ pairarg_tac \\ fs []);

val compile_prog_untouched = Q.store_thm ("compile_prog_untouched",
  `∀next prog prog2 loc exp arity.
     free_names next loc ∧
     lookup loc (fromAList prog) = SOME (arity, exp) ∧
     check_exp loc arity exp = NONE ∧
     compile_exp loc next arity exp = NONE ∧
     compile_prog next prog = (next1, prog2) ⇒
       lookup loc (fromAList prog2) = SOME (arity, exp)`,
  ho_match_mp_tac compile_prog_ind \\ rw []
  \\ fs [fromAList_def, lookup_def]
  \\ Cases_on `loc' = loc` \\ rw []
  >-
   (Cases_on `lookup loc (fromAList xs)`
    \\ fs [compile_prog_def]
    \\ rpt (pairarg_tac \\ fs [])
    \\ rfs [] \\ rw []
    \\ simp [fromAList_def])
  \\ fs [lookup_insert]
  \\ Cases_on `compile_exp loc next arity exp` \\ fs []
  >-
   (fs [compile_prog_def]
    \\ pairarg_tac \\ fs [] \\ rw []
    \\ fs [fromAList_def, lookup_insert])
  \\ PairCases_on `x`
  \\ imp_res_tac more_free_names
  \\ imp_res_tac compile_exp_next_addr
  \\ fs [compile_prog_def]
  \\ pairarg_tac \\ fs [] \\ rw []
  \\ fs [fromAList_def, lookup_insert]
  \\ first_x_assum drule
  \\ disch_then drule
  \\ rw [fromAList_def, lookup_insert, is_free_name]);

val EVERY_free_names_SUCSUC = Q.prove (
  `∀xs.
     EVERY (free_names n o FST) xs ⇒
       EVERY (free_names (n + bvl_to_bvi_namespaces) o FST) xs`,
  Induct
  \\ strip_tac \\ fs []
  \\ strip_tac
  \\ imp_res_tac more_free_names);

val compile_prog_touched = Q.store_thm ("compile_prog_touched",
  `∀next prog prog2 loc exp arity.
     ALL_DISTINCT (MAP FST prog) ∧
     EVERY (free_names next o FST) prog ∧
     free_names next loc ∧
     lookup loc (fromAList prog) = SOME (arity, exp) ∧
     check_exp loc arity exp = SOME op ∧
     compile_prog next prog = (next1, prog2) ⇒
       ∃k. ∀exp_aux exp_opt.
         compile_exp loc (next + bvl_to_bvi_namespaces * k) arity exp = SOME (exp_aux, exp_opt) ⇒
           lookup loc (fromAList prog2) = SOME (arity, exp_aux) ∧
           lookup (next + bvl_to_bvi_namespaces * k) (fromAList prog2) = SOME (arity + 1, exp_opt)`,
  ho_match_mp_tac compile_prog_ind \\ rw []
  \\ fs [fromAList_def, lookup_def]
  \\ pop_assum mp_tac
  \\ simp [compile_prog_def]
  \\ rpt (pairarg_tac \\ fs [])
  \\ PURE_TOP_CASE_TAC \\ fs []
  >-
   (rw []
    \\ qpat_x_assum `compile_exp _ _ _ _ = _` mp_tac
    \\ simp [Once compile_exp_def, check_exp_def]
    \\ `LENGTH (scan_expr (REPLICATE arity Any) loc [exp]) = LENGTH [exp]` by fs []
    \\ CASE_TAC \\ fs []
    \\ PairCases_on `h` \\ fs [] \\ rveq
    \\ qpat_x_assum `_ = SOME (_, _)` mp_tac
    \\ simp [lookup_insert, fromAList_def]
    \\ IF_CASES_TAC \\ strip_tac
    \\ rw [] \\ rfs []
    \\ rveq \\ fs []
    \\ TRY (pairarg_tac \\ fs [])
    \\ first_x_assum drule
    \\ disch_then drule \\ rw []
    \\ fs [lookup_insert, fromAList_def]
    \\ qexists_tac `k` \\ rw []
    \\ fs [free_names_def,backend_commonTheory.bvl_to_bvi_namespaces_def])
  \\ PURE_CASE_TAC \\ rw []
  \\ qpat_x_assum `lookup _ _ = SOME (_,_)` mp_tac
  \\ fs [lookup_insert, fromAList_def]
  \\ IF_CASES_TAC \\ fs [] \\ rw []
  \\ imp_res_tac more_free_names
  \\ rfs [EVERY_free_names_SUCSUC]
  \\ fs [lookup_insert, fromAList_def, free_names_def]
  \\ TRY (qexists_tac `0` \\ fs [backend_commonTheory.bvl_to_bvi_namespaces_def] \\ NO_TAC)
  \\ first_x_assum (qspec_then `loc'` assume_tac)
  \\ first_x_assum drule
  \\ disch_then drule \\ rw []
  \\ qexists_tac `k + 1` \\ fs []
  \\ simp [LEFT_ADD_DISTRIB]
  \\ fs[backend_commonTheory.bvl_to_bvi_namespaces_def]);

val check_exp_NONE_compile_exp = Q.prove (
  `check_exp loc arity exp = NONE ⇒ compile_exp loc next arity exp = NONE`,
  fs [compile_exp_def]);

val check_exp_SOME_compile_exp = Q.prove (
  `check_exp loc arity exp = SOME p ⇒
     ∃q. compile_exp loc next arity exp = SOME q`,
  fs [compile_exp_def, check_exp_def]
  \\ rw [] \\ rw []
  \\ pairarg_tac \\ fs []);

val EVERY_free_names_thm = Q.prove (
  `EVERY (free_names next o FST) prog ∧
   lookup loc (fromAList prog) = SOME x ⇒
     free_names next loc`,
  rw [lookup_fromAList, EVERY_MEM]
  \\ imp_res_tac ALOOKUP_MEM
  \\ first_x_assum (qspec_then `(loc, x)` mp_tac) \\ rw []);

val compile_prog_code_rel = Q.store_thm ("compile_prog_code_rel",
  `ALL_DISTINCT (MAP FST prog) ∧
   EVERY (free_names next o FST) prog ∧
   compile_prog next prog = (next1, prog2) ⇒
     code_rel (fromAList prog) (fromAList prog2)`,
  rw [code_rel_def]
  \\ imp_res_tac EVERY_free_names_thm
  >- metis_tac [check_exp_NONE_compile_exp, compile_prog_untouched]
  \\ drule compile_prog_touched
  \\ rpt (disch_then drule) \\ rw []
  \\ qexists_tac `bvl_to_bvi_namespaces * k + next` \\ fs []);

val evaluate_compile_prog = Q.store_thm ("evaluate_compile_prog",
  `EVERY (free_names next o FST) prog ∧
   ALL_DISTINCT (MAP FST prog) ∧
   evaluate ([Call 0 (SOME start) [] NONE], [],
             initial_state ffi0 (fromAList prog) k) = (r, s) ∧
   0 < k ∧
   r ≠ Rerr (Rabort Rtype_error) ⇒
   ∃ck s2.
     evaluate
      ([Call 0 (SOME start) [] NONE], [],
        initial_state ffi0 (fromAList (SND (compile_prog next prog))) (k + ck))
      = (r, s2) ∧
     state_rel s s2`,
  rw []
  \\ qmatch_asmsub_abbrev_tac `(es,env,st1)`
  \\ `env_rel F 0 env env` by fs [env_rel_def]
  \\ qabbrev_tac `ts: v_ty list = []`
  \\ `ty_rel env ts` by fs [ty_rel_def, Abbr`ts`]
  \\ drule (GEN_ALL compile_prog_code_rel)
  \\ disch_then drule
  \\ Cases_on `compile_prog next prog` \\ fs []
  \\ strip_tac
  \\ qmatch_assum_abbrev_tac `code_rel _ c`
  \\ `fromAList prog = st1.code` by fs [Abbr`st1`]
  \\ pop_assum (fn th => fs [th])
  \\ drule evaluate_rewrite_tail
  \\ disch_then (qspec_then `F` drule)
  \\ rpt (disch_then drule) \\ fs []
  \\ strip_tac
  \\ qexists_tac `0` \\ fs [inc_clock_ZERO]
  \\ qunabbrev_tac `st1`
  \\ imp_res_tac evaluate_code_const
  \\ fs [state_rel_def, initial_state_def]);

val compile_prog_semantics = Q.store_thm ("compile_prog_semantics",
  `EVERY (free_names n o FST) prog ∧
   ALL_DISTINCT (MAP FST prog) ∧
   SND (compile_prog n prog) = prog2 ∧
   semantics ffi (fromAList prog) start ≠ Fail ⇒
   semantics ffi (fromAList prog) start =
   semantics ffi (fromAList prog2) start`,
   simp [GSYM AND_IMP_INTRO]
   \\ ntac 3 strip_tac
   \\ simp [Ntimes semantics_def 2]
   \\ IF_CASES_TAC \\ fs []
   \\ DEEP_INTRO_TAC some_intro \\ simp []
   \\ conj_tac
   >-
     (gen_tac \\ strip_tac \\ rveq \\ simp []
     \\ simp [semantics_def]
     \\ IF_CASES_TAC \\ fs []
     >-
       (first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
       \\ drule evaluate_add_clock
       \\ impl_tac >- fs []
       \\ strip_tac
       \\ qpat_x_assum `evaluate (_,_,_ _ (_ prog) _) = _` kall_tac
       \\ last_assum (qspec_then `SUC k'` mp_tac)
       \\ (fn g => subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) (#2 g) g )
       \\ drule (GEN_ALL evaluate_compile_prog) \\ simp []
       \\ disch_then drule
       \\ impl_tac
       >-
         (fs [] \\ last_x_assum (qspec_then `SUC k'` strip_assume_tac)
         \\ rfs [] \\ spose_not_then strip_assume_tac \\ fs [])
       \\ strip_tac
       \\ first_x_assum (qspec_then `SUC ck` mp_tac)
       \\ simp [inc_clock_def]
       \\ fs [ADD1])
     \\ DEEP_INTRO_TAC some_intro \\ simp []
     \\ conj_tac
     >-
       (gen_tac \\ strip_tac \\ rveq \\ fs []
       \\ qmatch_assum_abbrev_tac `evaluate (opts,[],sopt) = _`
       \\ qmatch_assum_abbrev_tac `evaluate (exps,[],st) = (r,s)`
       \\ qspecl_then [`opts`,`[]`,`sopt`] mp_tac evaluate_add_to_clock_io_events_mono
       \\ qspecl_then [`exps`,`[]`,`st`] mp_tac evaluate_add_to_clock_io_events_mono
       \\ simp [inc_clock_def, Abbr`sopt`, Abbr`st`]
       \\ ntac 2 strip_tac
       \\ Cases_on `s.ffi.final_event` \\ fs []
       >-
         (Cases_on `s'.ffi.final_event` \\ fs []
         >-
           (unabbrev_all_tac
           \\ drule (GEN_ALL evaluate_compile_prog) \\ simp []
           \\ disch_then drule
           \\ impl_tac
           >- (spose_not_then strip_assume_tac \\ fs []
               \\ fs [evaluate_def]
               \\ every_case_tac \\ fs [] \\ rveq \\ fs [])
           \\ strip_tac
           \\ drule evaluate_add_clock
           \\ impl_tac
           >- (every_case_tac \\ fs [])
           \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
           \\ qpat_x_assum `evaluate (_,_,_ _ (_ prog2) _) = _` mp_tac
           \\ drule evaluate_add_clock
           \\ impl_tac
           >- (spose_not_then strip_assume_tac \\ fs [evaluate_def])
           \\ disch_then (qspec_then `ck+k` mp_tac) \\ simp [inc_clock_def]
           \\ ntac 2 strip_tac \\ rveq \\ fs []
           \\ fs [state_component_equality, state_rel_def]
           \\ every_case_tac \\ fs [])
         \\ qpat_x_assum `∀extra._` mp_tac
         \\ first_x_assum (qspec_then `k'` assume_tac)
         \\ first_assum (subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl)
         \\ strip_tac \\ fs []
         \\ unabbrev_all_tac
         \\ drule (GEN_ALL evaluate_compile_prog)
         \\ ntac 2 (disch_then drule)
         \\ impl_tac
         >-
          (last_x_assum (qspec_then `k + k'` mp_tac)
          \\ fs [] \\ strip_tac
          \\ spose_not_then assume_tac \\ fs [] \\ rveq
          \\ qpat_x_assum `_ = (q,_)` mp_tac
          \\ qpat_x_assum `_ = (r,_)` mp_tac
          \\ simp [evaluate_def]
          \\ every_case_tac \\ fs [] \\ rveq \\ fs [])
         \\ strip_tac
         \\ qhdtm_x_assum `evaluate` mp_tac
         \\ imp_res_tac evaluate_add_clock
         \\ pop_assum mp_tac
         \\ ntac 2 (pop_assum kall_tac)
         \\ impl_tac
         >- (strip_tac \\ fs [])
         \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
         \\ first_x_assum (qspec_then `ck + k` mp_tac) \\ fs []
         \\ ntac 3 strip_tac
         \\ fs [state_rel_def] \\ rveq)
       \\ qpat_x_assum `∀extra._` mp_tac
       \\ first_x_assum (qspec_then `SUC k'` assume_tac)
       \\ first_assum (subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl)
       \\ fs []
       \\ unabbrev_all_tac
       \\ strip_tac
       \\ drule (GEN_ALL evaluate_compile_prog)
       \\ ntac 2 (disch_then drule)
       \\ impl_tac
       >-
         (last_x_assum (qspec_then `k + SUC k'` mp_tac)
         \\ fs [] \\ strip_tac
         \\ spose_not_then assume_tac \\ rveq \\ fs [])
       \\ strip_tac \\ rveq \\ fs []
       \\ reverse (Cases_on `s'.ffi.final_event`) \\ fs [] \\ rfs []
       >-
         (first_x_assum (qspec_then `ck + SUC k` mp_tac)
         \\ fs [ADD1]
         \\ strip_tac \\ fs [state_rel_def] \\ rfs [])
       \\ qhdtm_x_assum `evaluate` mp_tac
       \\ imp_res_tac evaluate_add_clock
       \\ pop_assum kall_tac
       \\ pop_assum mp_tac
       \\ impl_tac
       >- (strip_tac \\ fs [])
       \\ disch_then (qspec_then `ck + SUC k` mp_tac)
       \\ simp [inc_clock_def]
       \\ fs [ADD1]
       \\ ntac 2 strip_tac \\ rveq
       \\ fs [state_rel_def] \\ rfs [])
     \\ qmatch_assum_abbrev_tac `evaluate (exps,[],st) = _`
     \\ qspecl_then [`exps`,`[]`,`st`] mp_tac evaluate_add_to_clock_io_events_mono
     \\ simp [inc_clock_def, Abbr`st`]
     \\ disch_then (qspec_then `1` strip_assume_tac)
     \\ first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
     \\ unabbrev_all_tac
     \\ drule (GEN_ALL evaluate_compile_prog)
     \\ ntac 2 (disch_then drule) \\ simp []
     \\ impl_tac
     >-
       (spose_not_then assume_tac
       \\ last_x_assum (qspec_then `k + 1` mp_tac)
       \\ fs [])
     \\ strip_tac
     \\ asm_exists_tac
     \\ every_case_tac \\ fs [] \\ rveq \\ fs []
     >-
       (qpat_x_assum `evaluate _ = (Rerr e,_)` mp_tac
       \\ imp_res_tac evaluate_add_clock
       \\ pop_assum kall_tac
       \\ pop_assum mp_tac
       \\ impl_tac >- fs []
       \\ disch_then (qspec_then `1` mp_tac)
       \\ simp [inc_clock_def])
     \\ rfs [state_rel_def] \\ fs [])
   \\ strip_tac
   \\ simp [semantics_def]
   \\ IF_CASES_TAC \\ fs []
   >-
     (last_x_assum (qspec_then `k` assume_tac) \\ rfs []
     \\ first_assum (qspec_then `e` assume_tac)
     \\ fs [] \\ rfs []
     \\ qmatch_assum_abbrev_tac `FST q ≠ _`
     \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
     \\ pop_assum (assume_tac o SYM)
     \\ drule (GEN_ALL evaluate_compile_prog)
     \\ ntac 2 (disch_then drule)
     \\ impl_tac
     >-
       (reverse conj_tac
       \\ CCONTR_TAC \\ fs []
       \\ fs [] \\ rveq
       \\ qhdtm_x_assum `evaluate` mp_tac
       \\ simp [evaluate_def]
       \\ every_case_tac \\ fs []
       \\ CCONTR_TAC \\ fs []
       \\ rveq \\ fs []
       \\ qpat_x_assum `FST _ = _` mp_tac
       \\ simp [evaluate_def]
       \\ drule (GEN_ALL compile_prog_code_rel) \\ fs []
       \\ disch_then drule
       \\ Cases_on `compile_prog n prog` \\ fs []
       \\ strip_tac
       \\ Cases_on `find_code (SOME start) ([]: v list) (fromAList prog)`
       \\ fs [] \\ rveq
       \\ rename1 `_ = SOME (q1, q2)`
       \\ imp_res_tac code_rel_find_code_SOME
       \\ PURE_TOP_CASE_TAC \\ fs []
       \\ PURE_TOP_CASE_TAC \\ fs [])
     \\ simp []
     \\ spose_not_then strip_assume_tac
     \\ qmatch_assum_abbrev_tac `FST q = _`
     \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
     \\ pop_assum (assume_tac o SYM)
     \\ imp_res_tac evaluate_add_clock \\ rfs []
     \\ first_x_assum (qspec_then `ck` mp_tac)
     \\ simp [inc_clock_def])
   \\ DEEP_INTRO_TAC some_intro \\ simp []
   \\ conj_tac
   >-
    (spose_not_then assume_tac \\ rw []
    \\ fsrw_tac [QUANT_INST_ss[pair_default_qp]] []
    \\ last_assum (qspec_then `SUC k` mp_tac)
    \\ (fn g => subterm (fn tm => Cases_on`^(assert (can dest_prod o type_of) tm)` g) (#2 g))
    \\ strip_tac
    \\ drule (GEN_ALL evaluate_compile_prog)
    \\ ntac 2 (disch_then drule)
    \\ impl_tac
    >- (spose_not_then assume_tac \\ fs [])
    \\ strip_tac
    \\ qmatch_assum_rename_tac `evaluate (_,[],_ (SUC k)) = (_,rr)`
    \\ reverse (Cases_on `rr.ffi.final_event`)
    >-
      (first_x_assum
        (qspecl_then
          [`SUC k`, `FFI_outcome(THE rr.ffi.final_event)`] mp_tac)
      \\ simp [])
    \\ qpat_x_assum `∀x y. ¬z` mp_tac \\ simp []
    \\ qexists_tac `SUC k` \\ simp []
    \\ reverse (Cases_on `s.ffi.final_event`) \\ fs []
    >-
      (qhdtm_x_assum `evaluate` mp_tac
      \\ qmatch_assum_abbrev_tac `evaluate (opts,[],os) = (r,_)`
      \\ qspecl_then [`opts`,`[]`,`os`] mp_tac evaluate_add_to_clock_io_events_mono
      \\ disch_then (qspec_then `SUC ck` mp_tac)
      \\ fs [ADD1, inc_clock_def, Abbr`os`]
      \\ rpt strip_tac \\ fs []
      \\ fs [state_rel_def] \\ rfs [])
    \\ qhdtm_x_assum `evaluate` mp_tac
    \\ imp_res_tac evaluate_add_clock
    \\ pop_assum mp_tac
    \\ impl_tac
    >- (strip_tac \\ fs [])
    \\ disch_then (qspec_then `SUC ck` mp_tac)
    \\ simp [inc_clock_def]
    \\ fs [ADD1]
    \\ rpt strip_tac \\ rveq
    \\ qexists_tac `outcome` \\ rw [])
  \\ strip_tac
  \\ qmatch_abbrev_tac `build_lprefix_lub l1 = build_lprefix_lub l2`
  \\ `(lprefix_chain l1 ∧ lprefix_chain l2) ∧ equiv_lprefix_chain l1 l2`
     suffices_by metis_tac [build_lprefix_lub_thm,
                            lprefix_lub_new_chain,
                            unique_lprefix_lub]
  \\ conj_asm1_tac
  >-
    (unabbrev_all_tac
    \\ conj_tac
    \\ Ho_Rewrite.ONCE_REWRITE_TAC [GSYM o_DEF]
    \\ REWRITE_TAC [IMAGE_COMPOSE]
    \\ match_mp_tac prefix_chain_lprefix_chain
    \\ simp [prefix_chain_def, PULL_EXISTS]
    \\ qx_genl_tac [`k1`,`k2`]
    \\ qspecl_then [`k1`,`k2`] mp_tac LESS_EQ_CASES
    \\ metis_tac [
         LESS_EQ_EXISTS,
         bviPropsTheory.initial_state_with_simp,
         bvlPropsTheory.initial_state_with_simp,
         bviPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bviPropsTheory.inc_clock_def],
         bvlPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bvlPropsTheory.inc_clock_def]])
  \\ simp [equiv_lprefix_chain_thm]
  \\ unabbrev_all_tac \\ simp [PULL_EXISTS]
  \\ ntac 2 (pop_assum kall_tac)
  \\ simp [LNTH_fromList, PULL_EXISTS, GSYM FORALL_AND_THM]
  \\ rpt gen_tac
  \\ drule (GEN_ALL evaluate_compile_prog)
  \\ fsrw_tac [QUANT_INST_ss [pair_default_qp]] []
  \\ disch_then (qspecl_then [`start`,`k`,`ffi`] mp_tac) \\ simp []
  \\ Cases_on `k = 0` \\ simp []
  >-
    (fs [evaluate_def]
    \\ every_case_tac \\ fs []
    \\ simp [GSYM IMP_CONJ_THM]
    \\ rpt strip_tac
    \\ qexists_tac `0` \\ simp [])
  \\ impl_tac
  >-
    (spose_not_then assume_tac
    \\ last_x_assum (qspec_then `k` mp_tac)
    \\ fs [])
  \\ strip_tac
  \\ qmatch_asmsub_abbrev_tac `state_rel (SND p1) (SND p2)`
  \\ Cases_on `p1` \\ Cases_on `p2` \\ fs [markerTheory.Abbrev_def]
  \\ ntac 2 (pop_assum (mp_tac o SYM)) \\ fs []
  \\ ntac 2 strip_tac
  \\ qmatch_assum_rename_tac `state_rel p1 p2`
  \\ `p1.ffi = p2.ffi` by fs [state_rel_def]
  \\ rveq
  \\ conj_tac \\ rw []
  >- (qexists_tac `ck + k`
     \\ fs [])
  \\ qexists_tac `k` \\ fs []
  \\ qmatch_assum_abbrev_tac `_ < (LENGTH (_ ffi1))`
  \\ `ffi1.io_events ≼ p2.ffi.io_events` by
    (qunabbrev_tac `ffi1`
    \\ metis_tac [
       initial_state_with_simp, evaluate_add_to_clock_io_events_mono
         |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
         |> Q.SPEC`s with clock := k`
         |> SIMP_RULE(srw_ss())[inc_clock_def],
       SND,ADD_SYM])
  \\ fs [IS_PREFIX_APPEND]
  \\ simp [EL_APPEND1]);

val compile_prog_MEM = Q.store_thm("compile_prog_MEM",
  `compile_prog n xs = (n1,ys) /\ MEM e (MAP FST ys) ==>
   MEM e (MAP FST xs) \/ n <= e`,
  qspec_tac (`e`,`e`)
  \\ qspec_tac (`n1`,`n1`)
  \\ qspec_tac (`ys`,`ys`)
  \\ qspec_tac (`n`,`n`)
  \\ qspec_tac (`xs`,`xs`)
  \\ Induct
  >- fs [compile_prog_def]
  \\ gen_tac
  \\ PairCases_on `h`
  \\ rename1 `(name, arity, exp)`
  \\ simp [compile_prog_def]
  \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs [])
  \\ PURE_CASE_TAC \\ fs []
  \\ TRY (PURE_CASE_TAC \\ fs [])
  \\ fs [MEM_MAP, PULL_EXISTS, FORALL_PROD]
  \\ rpt strip_tac \\ rveq \\ fs []
  \\ TRY (metis_tac [])
  \\ first_x_assum drule
  \\ disch_then drule
  \\ strip_tac
  >- metis_tac []
  \\ fs []);

val compile_prog_intro = Q.prove (
  `∀xs n ys n1 name.
    ¬MEM name (MAP FST xs) ∧
    free_names n name ∧
    compile_prog n xs = (n1, ys) ⇒
      ¬MEM name (MAP FST ys)`,
  Induct
  >- fs [compile_prog_def]
  \\ gen_tac
  \\ PairCases_on `h`
  \\ rpt gen_tac
  \\ simp [compile_prog_def]
  \\ rpt (pairarg_tac \\ fs [])
  \\ PURE_TOP_CASE_TAC \\ fs []
  >-
    (rpt strip_tac \\ rveq \\ fs []
    \\ metis_tac [])
  \\ PURE_CASE_TAC \\ fs []
  \\ rpt strip_tac \\ rveq \\ fs []
  \\ TRY (metis_tac [is_free_name])
  \\ metis_tac [more_free_names]);

val compile_prog_ALL_DISTINCT = Q.store_thm("compile_prog_ALL_DISTINCT",
  `compile_prog n xs = (n1,ys) /\ ALL_DISTINCT (MAP FST xs) /\
   EVERY (free_names n o FST) xs ==>
   ALL_DISTINCT (MAP FST ys)`,
  qspec_tac (`n1`,`n1`)
  \\ qspec_tac (`ys`,`ys`)
  \\ qspec_tac (`n`,`n`)
  \\ qspec_tac (`xs`,`xs`)
  \\ Induct
  >- fs [compile_prog_def]
  \\ gen_tac
  \\ PairCases_on `h`
  \\ rename1 `(name, arity, exp)`
  \\ simp [compile_prog_def]
  \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs [])
  \\ PURE_CASE_TAC \\ fs []
  >-
    (rpt strip_tac \\ fs [] \\ rveq
    \\ qpat_x_assum `_ = (_, ys'')` kall_tac
    \\ res_tac
    \\ simp [MAP]
    \\ metis_tac [more_free_names, compile_prog_intro])
  \\ PURE_CASE_TAC \\ fs []
  \\ rpt strip_tac
  \\ rveq
  \\ fs [is_free_name]
  \\ imp_res_tac EVERY_free_names_SUCSUC
  \\ res_tac
  \\ simp []
  \\ reverse conj_tac
  >-
    (CCONTR_TAC \\ fs []
    \\ drule (GEN_ALL compile_prog_MEM)
    \\ disch_then drule
    \\ simp [MEM_MAP]
    \\ fs [EVERY_MEM,backend_commonTheory.bvl_to_bvi_namespaces_def]
    \\ gen_tac
    \\ Cases_on `MEM y xs` \\ fs []
    \\ res_tac
    \\ fs [is_free_name])
  \\ CCONTR_TAC \\ fs []
  \\ drule (GEN_ALL compile_prog_MEM)
  \\ disch_then drule
  \\ simp [MEM_MAP]
  \\ metis_tac [compile_prog_intro, more_free_names]);

val _ = export_theory();
