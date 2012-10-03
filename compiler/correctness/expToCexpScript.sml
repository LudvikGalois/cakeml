open HolKernel bossLib boolLib boolSimps intLib sumTheory listTheory pred_setTheory finite_mapTheory alistTheory lcsymtacs
open MiniMLTheory MiniMLTerminationTheory miniMLExtraTheory evaluateEquationsTheory miscTheory intLangTheory compileTerminationTheory pmatchTheory
val _ = new_theory "expToCexp"
val fsd = full_simp_tac std_ss

(* Characterise MAP-like constants *)

val exps_to_Cexps_MAP = store_thm(
"exps_to_Cexps_MAP",
``exps_to_Cexps = mapM exp_to_Cexp``,
fs[Once FUN_EQ_THM] >>
Induct >> rw[exp_to_Cexp_def,FUN_EQ_THM,mapM_cons])

val pes_to_Cpes_MAP = store_thm(
"pes_to_Cpes_MAP",
``pes_to_Cpes = mapM (λ(p,e). BIND (λs. UNIT s.e2c_cmap s) (λcmap. let (pvs,Cp) = pat_to_Cpat cmap [] p in (Cp, exp_to_Cexp s e))``,
gen_tac >> Induct >- rw[exp_to_Cexp_def] >>
Cases >> rw[exp_to_Cexp_def])

val defs_to_Cdefs_MAP = store_thm(
"defs_to_Cdefs_MAP",
``∀s defs. defs_to_Cdefs s defs = (MAP FST defs, MAP (λ(d,vn,e). ([vn],INL (exp_to_Cexp s e))) defs)``,
gen_tac >> Induct >- rw[exp_to_Cexp_def] >>
qx_gen_tac `d` >> PairCases_on `d` >> rw[exp_to_Cexp_def])

(* Nicer induction *)

val exp_to_Cexp_nice_ind = save_thm(
"exp_to_Cexp_nice_ind",
exp_to_Cexp_ind
|> Q.SPECL [`P`
   ,`λs defs. EVERY (λ(d,vn,e). P s e) defs`
   ,`λs pes. EVERY (λ(p,e). P s e) pes`
   ,`λs. EVERY (P s)`]
|> SIMP_RULE (srw_ss()) []
|> UNDISCH_ALL
|> CONJUNCTS
|> el 1
|> DISCH_ALL
|> Q.GEN `P`
|> SIMP_RULE (srw_ss()) [optionTheory.option_case_compute,cond_sum_expand])

(* Misc. lemmas *)

val do_Opapp_SOME_CRecClos = store_thm(
"do_Opapp_SOME_CRecClos",
``(do_app env Opapp v1 v2 = SOME (env',exp'')) ∧
  syneq c (v_to_Cv m v1) w1 ⇒
  ∃env'' ns' defs n.
    (w1 = CRecClos env'' ns' defs n)``,
Cases_on `v1` >> rw[do_app_def,v_to_Cv_def,LET_THM] >>
fs[defs_to_Cdefs_MAP, syneq_cases])

val env_to_Cenv_APPEND = store_thm("env_to_Cenv_APPEND",
  ``env_to_Cenv m (l1 ++ l2) = env_to_Cenv m l1 ++ env_to_Cenv m l2``,
  rw[env_to_Cenv_MAP])
val _ = export_rewrites["env_to_Cenv_APPEND"]

(* free vars lemmas *)

val Cpat_vars_pat_to_Cpat = store_thm(
"Cpat_vars_pat_to_Cpat",
``(∀p s pvs pvs' Cp. (pat_to_Cpat s pvs p = (pvs',Cp))
  ⇒ (Cpat_vars Cp = pat_vars p)) ∧
  (∀ps s pvs pvs' Cps. (pats_to_Cpats s pvs ps = (pvs',Cps))
  ⇒ (MAP Cpat_vars Cps = MAP pat_vars ps))``,
ho_match_mp_tac (TypeBase.induction_of ``:pat``) >>
rw[pat_to_Cpat_def,LET_THM,pairTheory.UNCURRY] >>
rw[FOLDL_UNION_BIGUNION,IMAGE_BIGUNION] >- (
  qabbrev_tac `q = pats_to_Cpats s' pvs ps` >>
  PairCases_on `q` >>
  fsrw_tac[ETA_ss][MAP_EQ_EVERY2,EVERY2_EVERY,EVERY_MEM,pairTheory.FORALL_PROD] >>
  AP_TERM_TAC >>
  first_x_assum (qspecl_then [`s'`,`pvs`] mp_tac) >>
  rw[] >>
  pop_assum mp_tac >>
  rw[MEM_ZIP] >>
  rw[Once EXTENSION,MEM_EL] >>
  PROVE_TAC[] )
>- (
  qabbrev_tac `q = pats_to_Cpats s pvs ps` >>
  PairCases_on `q` >>
  qabbrev_tac `r = pat_to_Cpat s q0 p` >>
  PairCases_on `r` >>
  fs[] >>
  PROVE_TAC[] )
>- (
  fs[Once pat_to_Cpat_empty_pvs] ))

val Cpes_vars_thm = store_thm(
"Cpes_vars_thm",
``Cpes_vars Cpes = BIGUNION (IMAGE Cpat_vars (set (MAP FST Cpes))) ∪ BIGUNION (IMAGE (free_vars FEMPTY) (set (MAP SND Cpes)))``,
rw[Cpes_vars_def] >>
rw[Once (GSYM UNION_ASSOC)] >>
rw[FOLDL_UNION_BIGUNION_paired] >>
srw_tac[DNF_ss][Once EXTENSION,MEM_MAP,pairTheory.EXISTS_PROD] >>
PROVE_TAC[])

val Cpat_vars_SND_pat_to_Cpat = store_thm("Cpat_vars_SND_pat_to_Cpat",
  ``Cpat_vars (SND (pat_to_Cpat s [] z)) = pat_vars z``,
  Cases_on `pat_to_Cpat s [] z` >>
  imp_res_tac Cpat_vars_pat_to_Cpat >>
  rw[])
val _ = export_rewrites["Cpat_vars_SND_pat_to_Cpat"]

val free_vars_exp_to_Cexp = store_thm(
"free_vars_exp_to_Cexp",
``∀s e. free_vars FEMPTY (exp_to_Cexp s e) = FV e``,
ho_match_mp_tac exp_to_Cexp_nice_ind >>
srw_tac[ETA_ss,DNF_ss][exp_to_Cexp_def,exps_to_Cexps_MAP,pes_to_Cpes_MAP,defs_to_Cdefs_MAP,
FOLDL_UNION_BIGUNION,IMAGE_BIGUNION,BIGUNION_SUBSET,LET_THM,EVERY_MEM] >>
rw[] >- (
  AP_TERM_TAC >>
  rw[Once EXTENSION] >>
  fsrw_tac[DNF_ss][MEM_MAP,EVERY_MEM] >>
  PROVE_TAC[] )
>- (
  fs[] >>
  BasicProvers.EVERY_CASE_TAC >> rw[] >>
  srw_tac[DNF_ss][Once EXTENSION] >>
  PROVE_TAC[] )
>- (
  BasicProvers.EVERY_CASE_TAC >> rw[] )
>- (
  qmatch_abbrev_tac `free_vars FEMPTY (remove_mat_var v pe) DIFF x ∪ y = z` >>
  qspecl_then [`v`,`pe`] mp_tac free_vars_remove_mat_var >>
  asm_simp_tac std_ss [EXTENSION,IN_DIFF,IN_SING,IN_UNION] >>
  strip_tac >>
  qx_gen_tac `u` >>
  Cases_on `u ∈ y` >> fsd[] >>
  qunabbrev_tac `y` >>
  fsd[pairTheory.FORALL_PROD] >>
  Cases_on `u=v` >> fsd[] >- (
    qunabbrev_tac`v` >>
    match_mp_tac fresh_var_not_in_any >>
    qunabbrev_tac`x` >>
    qunabbrev_tac`z` >>
    pop_assum kall_tac >>
    ntac 2 (pop_assum kall_tac) >>
    fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,
                     Abbr`pe`,Cpes_vars_thm] >>
    fsrw_tac[DNF_ss][MAP_MAP_o,combinTheory.o_DEF,
                     pairTheory.LAMBDA_PROD] >>
    fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
    fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
    map_every qx_gen_tac [`x`,`y`,`z`] >>
    strip_tac >>
    disj2_tac >>
    map_every qexists_tac [`y`,`z`] >>
    rw[] >> PROVE_TAC[] ) >>
  fsrw_tac[DNF_ss][pairTheory.EXISTS_PROD] >>
  fsrw_tac[DNF_ss][Abbr`pe`,MEM_MAP,pairTheory.EXISTS_PROD] >>
  qunabbrev_tac`x` >>
  qunabbrev_tac`z` >>
  fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
  rw[Once CONJ_ASSOC] >>
  qho_match_abbrev_tac `
    (∃p1 p2. A p1 p2 ∧ MEM (p1,p2) pes) =
    (∃p1 p2. B p1 p2 ∧ MEM (p1,p2) pes)` >>
  (qsuff_tac `∀p1 p2. MEM (p1,p2) pes ⇒ (A p1 p2 = B p1 p2)` >- PROVE_TAC[]) >>
  srw_tac[DNF_ss][Abbr`A`,Abbr`B`] >>
  first_x_assum (qspecl_then [`p1`,`p2`] mp_tac) >>
  rw[] >>
  qabbrev_tac `q = pat_to_Cpat s [] p1` >>
  PairCases_on `q` >> fs[] >>
  PROVE_TAC[Cpat_vars_pat_to_Cpat])
>- (
  rw[EXTENSION] >> PROVE_TAC[] )
>- (
  fs[FOLDL_UNION_BIGUNION_paired] >>
  qmatch_abbrev_tac `X ∪ Y = Z ∪ A` >>
  `X = A` by (
    fs[markerTheory.Abbrev_def] >>
    rw[LIST_TO_SET_MAP] ) >>
  rw[UNION_COMM] >>
  unabbrev_all_tac >>
  ntac 2 AP_TERM_TAC >>
  rw[Once EXTENSION,pairTheory.EXISTS_PROD,LIST_TO_SET_MAP,DIFF_UNION,DIFF_COMM] >>
  srw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD,pairTheory.UNCURRY] >>
  fs[pairTheory.FORALL_PROD] >>
  PROVE_TAC[] )
>- (
  qabbrev_tac `q = pat_to_Cpat s [] p` >>
  PairCases_on`q`>>fs[] )
>- (
  qmatch_assum_rename_tac `MEM d defs`[] >>
  PairCases_on `d` >> fs[] >>
  qabbrev_tac `q = pat_to_Cpat s [] p` >>
  PairCases_on `q` >> fs[pairTheory.FORALL_PROD] >>
  PROVE_TAC[]))
val _ = export_rewrites["free_vars_exp_to_Cexp"];

(* closed lemmas *)

val v_to_Cv_closed = store_thm(
"v_to_Cv_closed",
``(∀m v. closed v ⇒ Cclosed FEMPTY (v_to_Cv m v)) ∧
  (∀m vs. EVERY closed vs ⇒ EVERY (Cclosed FEMPTY) (vs_to_Cvs m vs)) ∧
  (∀m env. EVERY closed (MAP SND env) ⇒ FEVERY ((Cclosed FEMPTY) o SND) (alist_to_fmap (env_to_Cenv m env)))``,
ho_match_mp_tac v_to_Cv_ind >>
rw[v_to_Cv_def] >> rw[Cclosed_rules]
>- (
  fs[Once closed_cases] >>
  rw[Once Cclosed_cases,Abbr`Ce`,Abbr`Cenv`,env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
  fs[SUBSET_DEF] >> PROVE_TAC[])
>- (
  fs[Once closed_cases] >>
  fs[defs_to_Cdefs_MAP] >> rw[] >>
  rw[Once Cclosed_cases,Abbr`Cenv`,env_to_Cenv_MAP] >>
  pop_assum mp_tac >> rw[EL_MAP] >>
  qabbrev_tac `p = EL i defs` >>
  PairCases_on `p` >> fs[] >> rw[] >>
  rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
  fs[SUBSET_DEF] >> PROVE_TAC[] ) >>
first_x_assum (match_mp_tac o MP_CANON) >>
pop_assum mp_tac >>
rw[FRANGE_DEF,DOMSUB_FAPPLY_THM] >>
rw[] >> PROVE_TAC[])

(* correctness *)

(*
val v_to_Cv_inj_rwt = store_thm(
"v_to_Cv_inj_rwt",
``∀s v1 v2. (v_to_Cv s v1 = v_to_Cv s v2) = (v1 = v2)``,
probably not true until equality is corrected in the source language *)

val exp_to_Cexp_thm1 = store_thm("exp_to_Cexp_thm1",
  ``∀cenv env exp res. evaluate cenv env exp res ⇒
    (EVERY closed (MAP SND env)) ∧ (FV exp ⊆ set (MAP FST env)) ∧
    good_cenv cenv ∧ (res ≠ Rerr Rtype_error) ⇒
    ∀m. good_cmap cenv m ⇒
      ∃Cres. Cevaluate FEMPTY (alist_to_fmap (env_to_Cenv m env)) (exp_to_Cexp m exp) Cres ∧
             result_rel (syneq FEMPTY) (map_result (v_to_Cv m) res) Cres``,
  ho_match_mp_tac evaluate_nice_strongind >>
  strip_tac >- rw[exp_to_Cexp_def,v_to_Cv_def] >>
  strip_tac >- rw[exp_to_Cexp_def] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,vs_to_Cvs_MAP,
       evaluate_list_with_value,Cevaluate_con,
       Cevaluate_list_with_Cevaluate,Cevaluate_list_with_EVERY] >>
    rw[syneq_cases] >>
    fsrw_tac[DNF_ss][EVERY2_EVERY,EVERY_MEM,pairTheory.FORALL_PROD] >>
    first_x_assum (qspec_then `m` strip_assume_tac o CONV_RULE SWAP_FORALL_CONV) >>
    `∀n. n < LENGTH es ⇒ FV (EL n es) ⊆ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,MEM_EL] >>
      PROVE_TAC[] ) >>
    qpat_assum `good_cmap cenv m` assume_tac >>
    fs[] >>
    fs[Once (GSYM RIGHT_EXISTS_IMP_THM),SKOLEM_THM] >>
    qexists_tac `GENLIST f (LENGTH vs)` >>
    fsrw_tac[DNF_ss][MEM_ZIP,EL_MAP,EL_GENLIST,MAP_GENLIST,EL_MAP]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,
       evaluate_list_with_error,Cevaluate_con,
       Cevaluate_list_with_Cevaluate,Cevaluate_list_with_error] >>
    fs[] >>
    `∀n. n < LENGTH es ⇒ FV (EL n es) ⊆ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,MEM_EL] >>
      PROVE_TAC[] ) >>
    rpt (qpat_assum `X < LENGTH es` mp_tac) >> rw[] >>
    fsrw_tac[ARITH_ss][] >>
    first_x_assum (qspec_then `m` strip_assume_tac) >>
    qpat_assum `good_cmap cenv m` assume_tac >> fs[] >>
    qmatch_assum_rename_tac `Cevaluate FEMPTY Cenv (exp_to_Cexp m (EL k es)) (Rerr err)`["Cenv"] >>
    qexists_tac `k` >> fs[EL_MAP] >>
    qx_gen_tac `z` >> strip_tac >>
    qpat_assum `∀m. m < k ⇒ P` (qspec_then `z` mp_tac) >> rw[] >>
    first_x_assum (qspec_then `m` strip_assume_tac) >>
    fsrw_tac[ARITH_ss][EL_MAP] >>
    PROVE_TAC[] ) >>
  strip_tac >- (
    fs[exp_to_Cexp_def,MEM_MAP,pairTheory.EXISTS_PROD,env_to_Cenv_MAP] >>
    rpt gen_tac >> rpt (disch_then strip_assume_tac) >> qx_gen_tac `m` >>
    rw[alist_to_fmap_MAP_values] >>
    `n ∈ FDOM (alist_to_fmap env)` by (
      rw[MEM_MAP,pairTheory.EXISTS_PROD] >> PROVE_TAC[] ) >>
    rw[o_f_FAPPLY] >>
    PROVE_TAC[ALOOKUP_SOME_FAPPLY_alist_to_fmap,syneq_refl] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,env_to_Cenv_MAP,LET_THM] >>
    srw_tac[DNF_ss][Once syneq_cases] >>
    rw[FINITE_has_fresh_string,fresh_var_not_in]) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      qexists_tac `w1` >>
      qexists_tac `w2` >>
      fs[] >>
      qmatch_assum_rename_tac `do_app env (Opn opn) v1 v2 = SOME (env',exp'')` [] >>
      Cases_on `opn` >>
      Cases_on `v1` >> Cases_on `l` >> fs[MiniMLTheory.do_app_def] >>
      Cases_on `v2` >> Cases_on `l` >> fs[] >> rw[] >>
      fs[CevalPrim2_def,doPrim2_def,exp_to_Cexp_def,MiniMLTheory.opn_lookup_def,i0_def,v_to_Cv_def] >>
      rw[] >> fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv (IntLit x)`]syneq_cases,i0_def] >>
      rw[] >> fs[] >> rw[] >> fs[] >> rw[v_to_Cv_def])
    >- (
      qmatch_assum_rename_tac `do_app env (Opb opb) v1 v2 = SOME (env',exp'')` [] >>
      fs[] >>
      `every_result closed (Rval v1) ∧
       every_result closed (Rval v2)` by metis_tac[evaluate_closed] >>
      fs[] >>
      `EVERY closed (MAP SND env') ∧
       FV exp'' ⊆ set (MAP FST env')` by PROVE_TAC[do_app_closed] >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      Cases_on `opb` >> fsrw_tac[DNF_ss][]
      >- (
        rw[Once Cevaluate_cases] >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        qexists_tac `w1` >>
        qexists_tac `w2` >>
        rw[] >>
        Cases_on `v1` >> Cases_on `l` >> fs[MiniMLTheory.do_app_def] >>
        Cases_on `v2` >> Cases_on `l` >> fs[] >> rw[] >>
        fs[CevalPrim2_def,doPrim2_def,exp_to_Cexp_def,MiniMLTheory.opb_lookup_def] >>
        rw[] >> fs[v_to_Cv_def] >> fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases])
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w1` >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        qmatch_assum_abbrev_tac `Cevaluate FEMPTY env0 exp0 (Rval w2)` >>
        `∀v. v ∈ FRANGE env0 ⇒ Cclosed FEMPTY v` by (
          imp_res_tac v_to_Cv_closed >>
          fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
        `free_vars FEMPTY exp0 ⊆ FDOM env0` by (
          fs[Abbr`exp0`,Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
             pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
        `every_result (Cclosed FEMPTY) (Rval w1)` by (
          match_mp_tac (MP_CANON Cevaluate_closed) >>
          map_every qexists_tac [`env0`,`exp_to_Cexp m e1`] >>
          fs[Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
             pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
        `∃res. Cevaluate FEMPTY (env0 |+ (fresh_var (FV e2),w1)) exp0 res ∧
               result_rel (syneq FEMPTY) (Rval w2) res` by (
          match_mp_tac Cevaluate_FUPDATE >>
          fs[Abbr`exp0`] >>
          rw[fresh_var_not_in,FINITE_has_fresh_string] ) >>
        fs[] >> rw[] >>
        qmatch_assum_rename_tac `syneq FEMPTY w2 y2`[] >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `y2` >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        Cases_on `v1` >> Cases_on `l` >> fs[MiniMLTheory.do_app_def] >>
        Cases_on `v2` >> Cases_on `l` >> fs[] >> rw[] >>
        fs[doPrim2_def,exp_to_Cexp_def,MiniMLTheory.opb_lookup_def] >>
        fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[integerTheory.int_gt,integerTheory.int_ge])
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w1` >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w2` >>
        rw[] >>
        Cases_on `v1` >> Cases_on `l` >> fs[MiniMLTheory.do_app_def] >>
        Cases_on `v2` >> Cases_on `l` >> fs[] >> rw[] >>
        fs[CevalPrim2_def,doPrim2_def,exp_to_Cexp_def,MiniMLTheory.opb_lookup_def] >>
        rw[] >> fs[v_to_Cv_def] >> fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >>
        rw[CompileTheory.i1_def] >> ARITH_TAC)
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w1` >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        qmatch_assum_abbrev_tac `Cevaluate FEMPTY env0 exp0 (Rval w2)` >>
        `∀v. v ∈ FRANGE env0 ⇒ Cclosed FEMPTY v` by (
          imp_res_tac v_to_Cv_closed >>
          fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
        `free_vars FEMPTY exp0 ⊆ FDOM env0` by (
          fs[Abbr`exp0`,Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
             pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
        `every_result (Cclosed FEMPTY) (Rval w1)` by (
          match_mp_tac (MP_CANON Cevaluate_closed) >>
          map_every qexists_tac [`env0`,`exp_to_Cexp m e1`] >>
          fs[Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
             pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
        `∃res. Cevaluate FEMPTY (env0 |+ (fresh_var (FV e2),w1)) exp0 res ∧
               result_rel (syneq FEMPTY) (Rval w2) res` by (
          match_mp_tac Cevaluate_FUPDATE >>
          fs[Abbr`exp0`] >>
          rw[fresh_var_not_in,FINITE_has_fresh_string] ) >>
        fs[] >> rw[] >>
        qmatch_assum_rename_tac `syneq FEMPTY w2 y2`[] >>
        CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `y2` >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj1_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        Cases_on `v1` >> Cases_on `l` >> fs[MiniMLTheory.do_app_def] >>
        Cases_on `v2` >> Cases_on `l` >> fs[] >> rw[] >>
        fs[doPrim2_def,exp_to_Cexp_def,MiniMLTheory.opb_lookup_def] >>
        fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[Once Cevaluate_cases] >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        rw[CompileTheory.i1_def] >>
        ARITH_TAC))
    >- (
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      qexists_tac `w1` >>
      qexists_tac `w2` >>
      fs[] >>
      fs[MiniMLTheory.do_app_def] >>
      qmatch_abbrev_tac `P` >> rw[] >>
      fs[exp_to_Cexp_def] >> rw[] >>
      fs[v_to_Cv_def] >>
      rw[Abbr`P`,Q.SPECL[`c`,`CLitv l`]syneq_cases] >>
      cheat )
    >- (
      `every_result closed (Rval v1) ∧
       every_result closed (Rval v2)` by (
        conj_tac >>
        match_mp_tac (MP_CANON evaluate_closed) >>
        PROVE_TAC[]) >>
      fs[] >>
      `EVERY closed (MAP SND env') ∧
       FV exp'' ⊆ set (MAP FST env')` by
        metis_tac[do_app_closed] >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      srw_tac[DNF_ss][] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY env0 ee1 (Rval w1)` >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY env0 ee2 (Rval w2)` >>
      `∀v. v ∈ FRANGE env0 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,
           pairTheory.LAMBDA_PROD] >>
        fs[MEM_MAP,pairTheory.EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,MEM_MAP,pairTheory.EXISTS_PROD] >>
        PROVE_TAC[]) >>
      `every_result (Cclosed FEMPTY) (Rval w1) ∧
       every_result (Cclosed FEMPTY) (Rval w2)` by(
         conj_tac >>
         match_mp_tac (MP_CANON Cevaluate_closed) >>
         qexists_tac `alist_to_fmap (env_to_Cenv m env)` >|[
           qexists_tac `exp_to_Cexp m e1`,
           qexists_tac `exp_to_Cexp m e2`] >>
         fs[] >>
         fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,
            pairTheory.LAMBDA_PROD,FST_pair] ) >>
      `∃env1 ns' defs n. w1 = CRecClos env1 ns' defs n` by (
        imp_res_tac do_Opapp_SOME_CRecClos >> rw[] ) >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `env1` >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `ns'` >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `defs` >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `n` >>
      rw[] >>
      fs[Q.SPECL[`FEMPTY`,`CRecClos env1 ns' defs n`]Cclosed_cases] >>
      fs[MEM_EL] >> rw[] >>
      qabbrev_tac `p = EL n' defs` >>
      PairCases_on `p` >>
      pop_assum (mp_tac o SYM o SIMP_RULE std_ss [markerTheory.Abbrev_def]) >>
      rw[] >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w2` >>
      rw[] >>
      fs[MiniMLTheory.do_app_def] >>
      Cases_on `v1` >> fs[] >- (
        fs[v_to_Cv_def,LET_THM] >>
        fs[Q.SPECL[`c`,`CRecClos env1 ns' defs zz`]syneq_cases] >>
        rw[] >> fs[] >> rw[] >> fs[] >> rw[] >>
        Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
        qmatch_assum_rename_tac `Cevaluate FEMPTY X (exp_to_Cexp m e) r`["X"] >>
        qmatch_assum_abbrev_tac`Cevaluate FEMPTY env3 ee r` >>
        qspecl_then [`FEMPTY`,`env3`,`ee`,`r`] mp_tac Cevaluate_free_vars_env >>
        `free_vars FEMPTY ee ⊆ FDOM env3` by(
          unabbrev_all_tac >> fs[] >>
          rw[env_to_Cenv_MAP,MAP_MAP_o] >>
          rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] ) >>
        `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by(
          unabbrev_all_tac >>
          fs[env_to_Cenv_MAP] >>
          match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
          fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
          rw[bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
          fs[EVERY_MEM,bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          PROVE_TAC[]) >>
        fs[] >> rw[] >>
        qmatch_assum_rename_tac `result_rel (syneq FEMPTY) r rr`[] >>
        `free_vars FEMPTY ee ⊆ FDOM env2` by (
          unabbrev_all_tac >> fs[] ) >>
        `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >> fs[] >>
          fs[extend_rec_env_def] >>
          qx_gen_tac `v` >>
          Cases_on `v=w2` >> fs[] >>
          match_mp_tac IN_FRANGE_DOMSUB_suff >>
          match_mp_tac IN_FRANGE_FUPDATE_suff >>
          fs[] >>
          rw[Once Cclosed_cases] ) >>
        qsuff_tac `∃x. Cevaluate FEMPTY (DRESTRICT env2 (free_vars FEMPTY ee)) ee x ∧ result_rel (syneq FEMPTY) rr x` >- (
          rw[] >>
          imp_res_tac Cevaluate_any_super_env >>
          metis_tac[result_rel_syneq_trans,result_rel_syneq_sym] ) >>
        qsuff_tac `fmap_rel (syneq FEMPTY)
                   (DRESTRICT env3 (free_vars FEMPTY ee))
                   (DRESTRICT env2 (free_vars FEMPTY ee))` >- (
          strip_tac >>
          qspecl_then [`FEMPTY`,
                       `DRESTRICT env2 (free_vars FEMPTY ee)`,
                       `DRESTRICT env3 (free_vars FEMPTY ee)`,
                       `ee`,`rr`] mp_tac Cevaluate_syneq_env >>
          fs[] >>
          fs[FDOM_DRESTRICT] >>
          PROVE_TAC[IN_FRANGE_DRESTRICT_suff] ) >>
        rw[fmap_rel_def,FDOM_DRESTRICT] >-
          fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
        `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
        rw[DRESTRICT_DEF] >>
        qunabbrev_tac `env3` >>
        qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
        `∃v. ALOOKUP al x = SOME v` by (
          Cases_on `ALOOKUP al x` >> fs[] >>
          imp_res_tac ALOOKUP_FAILS >>
          unabbrev_all_tac >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
        imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
        pop_assum(SUBST1_TAC) >>
        fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >>
        fs[bind_def] >- (
          rw[Abbr`env2`] >>
          rw[extend_rec_env_def] ) >>
        rw[Abbr`env2`,extend_rec_env_def] >>
        Cases_on`s=x`>>fs[FAPPLY_FUPDATE_THM] >- (
          fs[Abbr`ee`,NOT_fresh_var] >>
          fs[FLOOKUP_DEF,optionTheory.OPTREL_def] >>
          fsrw_tac[DNF_ss][] >>
          metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11]) >>
        fs[Abbr`ee`] >>
        PROVE_TAC[NOT_fresh_var,FINITE_FV]) >>
      fs[v_to_Cv_def,LET_THM,defs_to_Cdefs_MAP] >>
      fs[Q.SPECL[`c`,`CRecClos env1 ns' defs X`]syneq_cases] >>
      rw[] >> fs[] >> rw[] >>
      qpat_assum `X < LENGTH Y` assume_tac >>
      fs[EL_MAP] >>
      qmatch_assum_rename_tac `ALL_DISTINCT (MAP FST ns)`[] >>
      qabbrev_tac`q = EL n' ns` >>
      PairCases_on `q` >>
      pop_assum (mp_tac o SYM o SIMP_RULE std_ss [markerTheory.Abbrev_def]) >> rw[] >>
      fs[] >> rw[] >>
      Cases_on `ALOOKUP ns q0` >> fs[] >>
      qmatch_assum_rename_tac `ALOOKUP ns q0 = SOME p`[] >>
      PairCases_on `p` >> fs[] >> rw[] >>
      `ALOOKUP ns q0 = SOME (q1,q2)` by (
        match_mp_tac ALOOKUP_ALL_DISTINCT_MEM >>
        rw[MEM_EL] >> PROVE_TAC[] ) >>
      fs[] >> rw[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY env3 ee r` >>
      Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
      qmatch_assum_abbrev_tac `result_rel (syneq FEMPTY) rr r` >>
      fs[Q.SPEC`Recclosure l ns q0`closed_cases] >>
      `free_vars FEMPTY ee ⊆ FDOM env2` by (
        first_x_assum (qspecl_then [`n'`,`[p0]`,`INL ee`] mp_tac) >>
        unabbrev_all_tac >> fs[] >>
        rw[EL_MAP] ) >>
      `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >> fs[] >>
        fs[extend_rec_env_def] >>
        qx_gen_tac `v` >>
        Cases_on `v=w2` >> fs[] >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        fs[FOLDL_FUPDATE_LIST] >>
        match_mp_tac IN_FRANGE_FUPDATE_LIST_suff >> fs[] >>
        fs[MAP_MAP_o,MEM_MAP,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        rw[Once Cclosed_cases,MEM_MAP,pairTheory.EXISTS_PROD]
          >- PROVE_TAC[]
          >- ( first_x_assum match_mp_tac >>
               PROVE_TAC[] ) >>
        Cases_on `cb` >> fs[] >>
        pop_assum mp_tac >>
        fs[EL_MAP,pairTheory.UNCURRY]) >>
      qsuff_tac `∃x. Cevaluate FEMPTY (DRESTRICT env2 (free_vars FEMPTY ee)) ee x ∧ result_rel (syneq FEMPTY) rr x` >- (
        rw[] >>
        imp_res_tac Cevaluate_any_super_env >>
        metis_tac[result_rel_syneq_trans,result_rel_syneq_sym] ) >>
      `free_vars FEMPTY ee ⊆ FDOM env3` by(
        unabbrev_all_tac >> fs[] >>
        rw[env_to_Cenv_MAP,MAP_MAP_o] >>
        rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] ) >>
      `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by(
        unabbrev_all_tac >>
        fs[env_to_Cenv_MAP] >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
        rw[bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
        PROVE_TAC[]) >>
      qspecl_then [`FEMPTY`,`env3`,`ee`,`r`] mp_tac Cevaluate_free_vars_env >>
      fs[] >> rw[] >>
      qunabbrev_tac`rr` >>
      qmatch_assum_rename_tac `result_rel (syneq FEMPTY) r rr`[] >>
      qsuff_tac `fmap_rel (syneq FEMPTY)
                 (DRESTRICT env3 (free_vars FEMPTY ee))
                 (DRESTRICT env2 (free_vars FEMPTY ee))` >- (
        strip_tac >>
        qspecl_then [`FEMPTY`,
                     `DRESTRICT env2 (free_vars FEMPTY ee)`,
                     `DRESTRICT env3 (free_vars FEMPTY ee)`,
                     `ee`,`rr`] mp_tac Cevaluate_syneq_env >>
        fs[] >>
        fs[FDOM_DRESTRICT] >>
        PROVE_TAC[IN_FRANGE_DRESTRICT_suff,
                  result_rel_syneq_trans] ) >>
      rw[fmap_rel_def,FDOM_DRESTRICT] >-
        fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
      `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
      rw[DRESTRICT_DEF] >>
      qunabbrev_tac `env3` >>
      qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
      `∃v. ALOOKUP al x = SOME v` by (
        Cases_on `ALOOKUP al x` >> fs[] >>
        imp_res_tac ALOOKUP_FAILS >>
        unabbrev_all_tac >>
        fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
      imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
      qpat_assum `alist_to_fmap al ' x = X`(SUBST1_TAC) >>
      qpat_assum `Cevaluate c X ee rr` kall_tac >>
      fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >> rw[] >>
      fs[bind_def] >- (
        rw[Abbr`env2`] >>
        rw[extend_rec_env_def] ) >>
      Cases_on `p0=x`>>fs[] >- (
        rw[] >>
        rw[Abbr`env2`,extend_rec_env_def] ) >>
      qpat_assum `ALOOKUP X Y = SOME Z` mp_tac >>
      asm_simp_tac(srw_ss())[build_rec_env_def,bind_def,FOLDR_CONS_triple] >>
      rw[ALOOKUP_APPEND] >>
      Cases_on `MEM x (MAP FST ns)` >>
      fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >- (
        qpat_assum `X = SOME v'` mp_tac >>
        qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
          NONE => ALOOKUP l x | SOME v => SOME v) = SOME v') ⇒ P` >>
        `MAP FST (MAP ff ns) = MAP FST ns` by (
          asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
          qx_gen_tac `y` >> strip_tac >>
          fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
          qabbrev_tac `yy = EL y ns` >>
          PairCases_on `yy` >> fs[] ) >>
        `ALL_DISTINCT (MAP FST (MAP ff ns))` by PROVE_TAC[] >>
        `MEM (x,Recclosure l ns x) (MAP ff ns)` by (
          rw[Abbr`ff`,MEM_MAP,pairTheory.EXISTS_PROD] >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] >>
          PROVE_TAC[] ) >>
        imp_res_tac ALOOKUP_ALL_DISTINCT_MEM >>
        fs[] >> rw[Abbr`P`] >>
        rw[v_to_Cv_def] >>
        rw[Abbr`env2`,extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
        rw[FAPPLY_FUPDATE_THM] >>
        ho_match_mp_tac FUPDATE_LIST_ALL_DISTINCT_APPLY_MEM >>
        fs[MAP_MAP_o,combinTheory.o_DEF] >>
        fsrw_tac[ETA_ss][] >>
        fs[pairTheory.LAMBDA_PROD] >>
        fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
        rw[Once syneq_cases] >>
        fs[defs_to_Cdefs_MAP] >>
        qmatch_assum_rename_tac `MEM (x,z0,z1) ns`[] >>
        map_every qexists_tac [`z0`,`z1`] >> fs[] >>
        rw[] >>
        fs[EVERY_MEM,pairTheory.FORALL_PROD] >>
        fs[MEM_MAP,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        fs[Abbr`Cenv`] >>
        fs[env_to_Cenv_MAP,ALOOKUP_MAP] >>
        fsrw_tac[ETA_ss][] >>
        rw[] >>
        first_x_assum (match_mp_tac o MP_CANON) >>
        PROVE_TAC[]) >>
      qpat_assum `X = SOME v'` mp_tac >>
      qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
        NONE => ALOOKUP l x | SOME v => SOME v) = SOME v') ⇒ P` >>
      `MAP FST (MAP ff ns) = MAP FST ns` by (
        asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
        qx_gen_tac `y` >> strip_tac >>
        fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
        qabbrev_tac `yy = EL y ns` >>
        PairCases_on `yy` >> fs[] ) >>
      `ALOOKUP (MAP ff ns) x= NONE` by (
        rw[ALOOKUP_NONE]) >>
      rw[Abbr`P`] >>
      rw[Abbr`env2`] >>
      rw[extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
      rw[FAPPLY_FUPDATE_THM] >>
      ho_match_mp_tac FUPDATE_LIST_APPLY_HO_THM >>
      disj2_tac >>
      fs[MAP_MAP_o,combinTheory.o_DEF] >>
      fsrw_tac[ETA_ss][] >>
      fsrw_tac[DNF_ss][EVERY_MEM,pairTheory.FORALL_PROD] >>
      fsrw_tac[DNF_ss][optionTheory.OPTREL_def,FLOOKUP_DEF] >>
      fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
      fs[Abbr`ee`] >>
      imp_res_tac ALOOKUP_MEM >>
      metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11])) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      disj1_tac >>
      qexists_tac `w1` >> fs[] )
    >- (
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY env0 exp0 (Rval w1)` >>
      `∀v. v ∈ FRANGE env0 ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY exp0 ⊆ FDOM env0` by (
        fs[Abbr`exp0`,Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
      `every_result (Cclosed FEMPTY) (Rval w1)` by (
        match_mp_tac (MP_CANON Cevaluate_closed) >>
        map_every qexists_tac [`env0`,`exp_to_Cexp m e1`] >>
        fs[Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ) >>
      fs[] >>
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases]
      >- (
        disj2_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        disj1_tac >>
        qexists_tac `w1` >> fs[] )
      >- (
        disj1_tac >>
        qexists_tac `w1` >> fs[] >>
        rw[Once Cevaluate_cases] >>
        disj2_tac >>
        match_mp_tac Cevaluate_FUPDATE_Rerr >>
        fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,
           pairTheory.LAMBDA_PROD,FST_pair,
           fresh_var_not_in,FINITE_has_fresh_string] >>
        fs[Abbr`exp0`] >>
        fs[Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] )
      >- (
        disj2_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        rw[Once Cevaluate_cases] >>
        disj2_tac >>
        rw[Cevaluate_list_with_Cevaluate] >>
        rw[Cevaluate_list_with_cons] >>
        disj1_tac >>
        PROVE_TAC[] )
      >- (
        disj1_tac >>
        qexists_tac `w1` >>
        fs[] >>
        rw[Once Cevaluate_cases] >>
        disj2_tac >>
        match_mp_tac Cevaluate_FUPDATE_Rerr >>
        fs[fresh_var_not_in,FINITE_has_fresh_string] >>
        fs[Abbr`env0`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] ))
    >- (
      rw[Once Cevaluate_cases] >>
      disj2_tac >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      disj1_tac >>
      fsrw_tac[DNF_ss][] >>
      PROVE_TAC[] )
    >- (
      rw[Once Cevaluate_cases] >>
      disj2_tac >> disj1_tac >>
      fsrw_tac[DNF_ss][] >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      PROVE_TAC[])) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] )
    >- (
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases] >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] >>
      disj2_tac >>
      rw[Once Cevaluate_cases] >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons])
    >- (
      rw[Once Cevaluate_cases] >>
      rw[Cevaluate_list_with_Cevaluate] >>
      rw[Cevaluate_list_with_cons] )
    >- (
      rw[Once Cevaluate_cases] )) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][] >>
    imp_res_tac do_log_FV >>
    `FV exp' ⊆ set (MAP FST env)` by PROVE_TAC[SUBSET_TRANS] >>
    fsrw_tac[DNF_ss][] >>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >>
    rw[] >>
    Cases_on `op` >> Cases_on `v` >> fs[do_log_def] >>
    Cases_on `l` >> fs[v_to_Cv_def] >>
    fs[Q.SPECL[`c`,`CLitv l`]syneq_cases] >> rw[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >> disj1_tac >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `b` >> fs[] >>
    rw[] >> fs[] >> rw[] >>
    fs[evaluate_lit] >> rw[v_to_Cv_def] >>
    PROVE_TAC[result_rel_refl,syneq_refl] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    Cases_on `op` >> fsrw_tac[DNF_ss][] >>
    rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][] >>
    imp_res_tac do_if_FV >>
    `FV exp' ⊆ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      PROVE_TAC[]) >> fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    qpat_assum `do_if v e2 e3 = X` mp_tac >>
    fs[do_if_def] >> rw[] >|[
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`T`,
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`F`] >>
    fsrw_tac[DNF_ss][v_to_Cv_def,Q.SPECL[`c`,`CLitv l`]syneq_cases] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rpt strip_tac >> fs[] >>
    first_x_assum (qspec_then `m` mp_tac) >> rw[] >>
    qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v) w`[] >>
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    srw_tac[DNF_ss][] >>
    disj1_tac >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w` >> fs[] >>
    qmatch_assum_abbrev_tac `evaluate_match_with P cenv env v pes res` >>
    Q.ISPECL_THEN [`pes`,`res`] mp_tac evaluate_match_with_matchres >> fs[] >>
    strip_tac >>
    qmatch_assum_abbrev_tac `evaluate_match_with (matchres env) cenv env v pes r` >>
    Q.ISPECL_THEN [`pes`,`r`] mp_tac evaluate_match_with_Cevaluate_match >>
    fs[Abbr`r`] >>
    disch_then (qspec_then `m` mp_tac) >>
    rw[] >- (
      qmatch_assum_abbrev_tac `Cevaluate_match vv ppes FEMPTY NONE` >>
      `Cevaluate_match vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) FEMPTY NONE` by (
        metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
      qmatch_assum_abbrev_tac `Cevaluate_match vv (MAP ff ppes) FEMPTY NONE` >>
      `MAP ff ppes = pes_to_Cpes m pes` by (
        unabbrev_all_tac >>
        rw[pes_to_Cpes_MAP,LET_THM] >>
        rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
        rw[pairTheory.UNCURRY] ) >>
      fs[] >>
      unabbrev_all_tac >>
      pop_assum kall_tac >>
      pop_assum mp_tac >>
      pop_assum kall_tac >>
      strip_tac >>
      Q.SPECL_THEN [`v_to_Cv m v`,`pes_to_Cpes m pes`,`FEMPTY`,`NONE`]
        mp_tac (INST_TYPE[alpha|->``:Cexp``](Q.GEN`v` Cevaluate_match_syneq)) >>
      fs[] >>
      disch_then (qspecl_then [`FEMPTY`,`w`] mp_tac) >> fs[] >>
      rw[fmap_rel_def,FDOM_EQ_EMPTY] >>
      qspecl_then [`w`,`pes_to_Cpes m pes`,`FEMPTY`,`NONE`]
        mp_tac (Q.GEN`v` Cevaluate_match_remove_mat_var) >>
      fs[] >>
      disch_then match_mp_tac >>
      fs[FLOOKUP_DEF] >>
      fsrw_tac[DNF_ss][pairTheory.FORALL_PROD] >>
      conj_tac >- (
        qx_gen_tac `s` >>
        Q.PAT_ABBREV_TAC`f = fresh_var X` >>
        Cases_on `f ∈ s` >> fs[] >>
        qx_gen_tac `p` >>
        qx_gen_tac `e` >>
        Cases_on `s = Cpat_vars p` >> fs[] >>
        spose_not_then strip_assume_tac >>
        `f ∉ Cpat_vars p` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[Cpes_vars_thm] >> rw[] >>
          srw_tac[DNF_ss][SUBSET_DEF,pairTheory.EXISTS_PROD,MEM_MAP] >>
          metis_tac[] ) ) >>
      conj_tac >- (
        fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
        fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,pes_to_Cpes_MAP,MEM_MAP,LET_THM,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][pairTheory.UNCURRY,Cpes_vars_thm] >>
        metis_tac[Cpat_vars_pat_to_Cpat,pairTheory.pair_CASES,pairTheory.SND] ) >>
      `every_result (Cclosed FEMPTY) (Rval w)` by (
        match_mp_tac (MP_CANON Cevaluate_closed) >>
        qmatch_assum_abbrev_tac `Cevaluate FEMPTY ee xx (Rval w)` >>
        map_every qexists_tac [`ee`,`xx`] >>
        unabbrev_all_tac >> fs[] >>
        fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        fsrw_tac[DNF_ss][MEM_MAP,pairTheory.FORALL_PROD] >>
        rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fsrw_tac[DNF_ss][EVERY_MEM,MEM_MAP,pairTheory.FORALL_PROD] >>
        metis_tac[] ) >>
      fs[] >>
      match_mp_tac IN_FRANGE_DOMSUB_suff >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
      fsrw_tac[DNF_ss][MEM_MAP,pairTheory.FORALL_PROD] >>
      rw[] >>
      match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      fsrw_tac[DNF_ss][EVERY_MEM,MEM_MAP,pairTheory.FORALL_PROD] >>
      metis_tac[] ) >>
    qmatch_assum_abbrev_tac `Cevaluate_match vv ppes eenv (SOME mr)` >>
    `Cevaluate_match vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) eenv (SOME (exp_to_Cexp m mr))` by (
      metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
    pop_assum mp_tac >>
    unabbrev_all_tac >>
    pop_assum kall_tac >>
    strip_tac >>
    qmatch_assum_abbrev_tac `Cevaluate_match vv (MAP ff ppes) eenv mmr` >>
    `MAP ff ppes = pes_to_Cpes m pes` by (
      unabbrev_all_tac >>
      rw[pes_to_Cpes_MAP,LET_THM] >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
      rw[pairTheory.UNCURRY] ) >>
    fs[] >>
    unabbrev_all_tac >>
    pop_assum kall_tac >>
    pop_assum mp_tac >>
    pop_assum mp_tac >>
    fs[] >>
    `every_result closed (Rval v)` by (
      match_mp_tac (MP_CANON evaluate_closed) >>
      PROVE_TAC[] ) >>
    Q.ISPECL_THEN [`pes`,`Rval (menv,mr)`] mp_tac evaluate_match_with_matchres_closed >>
    fs[] >> strip_tac >>
    `FV mr ⊆ set (MAP FST menv) ∪ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      fsrw_tac[DNF_ss][pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD] >>
      fsrw_tac[DNF_ss][EXTENSION,MEM_MAP,pairTheory.EXISTS_PROD] >>
      PROVE_TAC[] ) >>
    fs[] >>
    disch_then (qspec_then `m` mp_tac) >>
    rw[] >>
    qmatch_assum_abbrev_tac `Cevaluate_match vv pp ee rr` >>
    qspecl_then [`vv`,`pp`,`ee`,`rr`]
      mp_tac (INST_TYPE[alpha|->``:Cexp``](Q.GEN`v` Cevaluate_match_syneq)) >>
    fs[] >>
    disch_then (qspecl_then [`FEMPTY`,`w`] mp_tac) >> fs[] >>
    disch_then (Q.X_CHOOSE_THEN`ef` strip_assume_tac) >>
    qspecl_then [`w`,`pp`,`ef`,`rr`] mp_tac
      (Q.GEN`v`Cevaluate_match_remove_mat_var) >>
    fs[Abbr`rr`] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY eg rr Cres` >>
    qabbrev_tac `eh = alist_to_fmap (env_to_Cenv m env)` >>
    qspecl_then [`FEMPTY`,`ef ⊌ eh`,`eg`,`rr`,`Cres`]
      mp_tac (Q.GEN`c`Cevaluate_any_syneq_env) >>
    fs[] >>
    `fmap_rel (syneq FEMPTY) eg (ef ⊌ eh)` by (
      unabbrev_all_tac >>
      rw[env_to_Cenv_MAP] >>
      match_mp_tac fmap_rel_FUNION_rels >>
      fs[env_to_Cenv_MAP] ) >>
    `∀v. v ∈ FRANGE eh ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,pairTheory.FORALL_PROD] >>
      rw[] >>
      match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      fsrw_tac[DNF_ss][EVERY_MEM,pairTheory.FORALL_PROD,MEM_MAP] >>
      METIS_TAC[] ) >>
    `FV exp ⊆ FDOM eh` by (
      unabbrev_all_tac >>
      fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] ) >>
    `every_result (Cclosed FEMPTY) (Rval w)` by (
      match_mp_tac (MP_CANON Cevaluate_closed) >>
      map_every qexists_tac [`eh`,`exp_to_Cexp m exp`] >>
      fs[] >> fs[Abbr`eh`] ) >> fs[] >>
    `∀v. v ∈ FRANGE ef ⇒ Cclosed FEMPTY v` by imp_res_tac Cevaluate_match_closed >>
    `∀v. v ∈ FRANGE (ef ⊌ eh) ⇒ Cclosed FEMPTY v` by imp_res_tac IN_FRANGE_FUNION_suff >>
    Q.PAT_ABBREV_TAC`s= FDOM ef ∪ X` >>
    `s = FDOM eg` by (
      unabbrev_all_tac >>
      fs[fmap_rel_def,env_to_Cenv_MAP] ) >>
    qunabbrev_tac`s` >> fs[] >>
    `free_vars FEMPTY rr ⊆ FDOM eg` by (
      unabbrev_all_tac >> fs[] >>
      fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,pairTheory.LAMBDA_PROD] >>
      METIS_TAC[] ) >>
    `∀v. v ∈ FRANGE eg ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >> fs[] >>
      match_mp_tac IN_FRANGE_FUNION_suff >>
      conj_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,pairTheory.EXISTS_PROD] >>
      fsrw_tac[DNF_ss][EVERY_MEM,MEM_MAP,pairTheory.FORALL_PROD] >>
      METIS_TAC[v_to_Cv_closed] ) >>
    fs[] >>
    disch_then (Q.X_CHOOSE_THEN`r1` strip_assume_tac) >>
    Q.PAT_ABBREV_TAC`x = fresh_var s` >>
    disch_then (qspecl_then [`eh|+(x,w)`,`x`] mp_tac) >>
    fs[FLOOKUP_DEF] >>
    qmatch_abbrev_tac `(P ⇒ Q) ⇒ R` >>
    `P` by (
      unabbrev_all_tac >>
      conj_tac >- (
        qx_gen_tac `s` >>
        qmatch_abbrev_tac `A ∨ B` >>
        Cases_on `B` >> fs[markerTheory.Abbrev_def] >>
        match_mp_tac fresh_var_not_in_any >>
        fsrw_tac[DNF_ss][Cpes_vars_thm,pes_to_Cpes_MAP,LET_THM,MEM_MAP,SUBSET_DEF,pairTheory.UNCURRY] >>
        METIS_TAC[] ) >>
      conj_tac >- (
        fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,pes_to_Cpes_MAP,env_to_Cenv_MAP,LET_THM,MEM_MAP,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
        METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
      rw[] >> rw[] >>
      pop_assum mp_tac >> match_mp_tac IN_FRANGE_DOMSUB_suff >>
      rw[] ) >>
    pop_assum mp_tac >> simp_tac std_ss [] >>
    strip_tac >> qunabbrev_tac`P` >>
    qunabbrev_tac`Q` >> qunabbrev_tac`R` >>
    `x ∉ FDOM ef` by (
      unabbrev_all_tac >>
      match_mp_tac fresh_var_not_in_any >>
      fs[fmap_rel_def] >>
      fsrw_tac[DNF_ss][Cpes_vars_thm] >>
      `set (MAP FST (env_to_Cenv m menv)) = Cpat_vars (SND (pat_to_Cpat m [] p))` by (
        fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair] >>
        METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
      fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,pes_to_Cpes_MAP,MEM_MAP,LET_THM] >>
      qpat_assum `MEM (p,x) pes` mp_tac >>
      rpt (pop_assum kall_tac) >>
      fsrw_tac[DNF_ss][pairTheory.EXISTS_PROD,pairTheory.UNCURRY] >>
      METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
    fs[FUNION_FUPDATE_2] >>
    qspecl_then [`FEMPTY`,`ef ⊌ eh`,`rr`,`r1`,`x`,`w`] mp_tac Cevaluate_FUPDATE >>
    fs[] >>
    `x ∉ free_vars FEMPTY rr` by (
      unabbrev_all_tac >>
      match_mp_tac fresh_var_not_in_any >>
      fsrw_tac[DNF_ss][Cpes_vars_thm] >>
      fsrw_tac[DNF_ss][pes_to_Cpes_MAP,LET_THM,SUBSET_DEF,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,pairTheory.EXISTS_PROD] >>
      fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
      metis_tac[Cpat_vars_pat_to_Cpat,pairTheory.pair_CASES,pairTheory.SND] ) >>
    fs[] >>
    metis_tac[result_rel_syneq_trans,result_rel_syneq_sym]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fs[] >> rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][bind_def] >>
    `every_result closed (Rval v)` by (
      match_mp_tac (MP_CANON evaluate_closed) >>
      METIS_TAC[] ) >>
    fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    rpt (first_x_assum (qspec_then `m` mp_tac)) >>
    rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac `w` >> fs[] >>
    pop_assum mp_tac >>
    Q.PAT_ABBREV_TAC`P = X ⊆ Y` >>
    `P` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      METIS_TAC[] ) >>
    rw[] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY ee xx Cres` >>
    Q.PAT_ABBREV_TAC`ef = X |+ (n,w)` >>
    qspecl_then [`FEMPTY`,`ef`,`ee`,`xx`,`Cres`] mp_tac (Q.GEN`c`Cevaluate_any_syneq_env) >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      unabbrev_all_tac >>
      fs[] >>
      conj_tac >- (
        rw[fmap_rel_def,env_to_Cenv_MAP,FAPPLY_FUPDATE_THM] >>
        rw[] ) >>
      qabbrev_tac `ev = alist_to_fmap (env_to_Cenv m env)` >>
      `∀v. v ∈ FRANGE ev ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        rw[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
        fsrw_tac[DNF_ss][MEM_MAP,EVERY_MEM,pairTheory.UNCURRY] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        METIS_TAC[] ) >>
      `every_result (Cclosed FEMPTY) (Rval w)` by (
        match_mp_tac (MP_CANON Cevaluate_closed) >>
        qmatch_assum_abbrev_tac `Cevaluate FEMPTY e1 x1 (Rval w)` >>
        map_every qexists_tac [`e1`,`x1`] >>
        unabbrev_all_tac >> fs[] >>
        rw[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] ) >>
      fs[] >>
      conj_tac >- (
        rw[] >> rw[] >>
        pop_assum mp_tac >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        rw[] ) >>
      fs[env_to_Cenv_MAP] >>
      fsrw_tac[DNF_ss][MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair] >>
      fsrw_tac[][SUBSET_DEF] >>
      METIS_TAC[v_to_Cv_closed,IN_FRANGE_DOMSUB_suff] ) >>
    metis_tac[result_rel_syneq_trans] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM,FST_triple] >>
    fs[] >>
    rw[defs_to_Cdefs_MAP] >>
    rw[Once Cevaluate_cases,FOLDL_FUPDATE_LIST] >>
    `FV exp ⊆ set (MAP FST funs) ∪ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD] >>
      METIS_TAC[] ) >>
    fs[] >>
    `EVERY closed (MAP SND (build_rec_env funs env))` by (
      match_mp_tac build_rec_env_closed >>
      fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD,MEM_EL] >>
      METIS_TAC[] ) >>
    fs[] >>
    first_x_assum (qspec_then `m` mp_tac) >>
    fs[] >>
    simp_tac std_ss [build_rec_env_def,bind_def,FOLDR_CONS_triple] >>
    simp_tac (srw_ss())[] >>
    simp_tac std_ss [FUNION_alist_to_fmap] >>
    Q.PAT_ABBREV_TAC`ee = alist_to_fmap (env_to_Cenv X Y)` >>
    simp_tac (srw_ss()) [env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
    simp_tac (srw_ss()) [v_to_Cv_def,LET_THM,pairTheory.UNCURRY,defs_to_Cdefs_MAP] >>
    Q.PAT_ABBREV_TAC`ls:(string#Cv) list = MAP f funs` >>
    `ALL_DISTINCT (MAP FST ls)` by (
      unabbrev_all_tac >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_triple] ) >>
    rw[FUPDATE_LIST_ALL_DISTINCT_REVERSE] >>
    rw[MEM_MAP,pairTheory.FORALL_PROD] >>
    METIS_TAC[] ) >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- rw[evaluate_list_with_cons] >>
  strip_tac >- rw[evaluate_list_with_cons] >>
  strip_tac >- (
    rw[evaluate_list_with_cons] >>
    fsrw_tac[DNF_ss][] >>
    METIS_TAC[] ) >>
  strip_tac >- rw[Once evaluate_match_with_cases] >>
  strip_tac >- rw[Once evaluate_match_with_cases] >>
  strip_tac >- (
    rw[] >>
    simp_tac std_ss [Once evaluate_match_with_cases] >>
    fsrw_tac[][] ) >>
  strip_tac >- (
    rw[] >>
    simp_tac std_ss [Once evaluate_match_with_cases] >>
    fsrw_tac[][] ) >>
  rw[] >>
  simp_tac std_ss [Once evaluate_match_with_cases] >>
  fsrw_tac[][])

val _ = export_theory()
