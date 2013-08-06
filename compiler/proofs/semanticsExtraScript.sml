open HolKernel bossLib boolLib boolSimps pairTheory alistTheory listTheory rich_listTheory pred_setTheory finite_mapTheory lcsymtacs SatisfySimps quantHeuristicsLib miscLib
open LibTheory SemanticPrimitivesTheory AstTheory BigStepTheory TypeSystemTheory terminationTheory bigClockTheory bigBigEquivTheory replTheory miscTheory
val _ = new_theory "semanticsExtra"

(* ALOOKUPs *)

val lookup_ALOOKUP = store_thm(
"lookup_ALOOKUP",
``lookup = combin$C ALOOKUP``,
fs[FUN_EQ_THM] >> gen_tac >> Induct >- rw[] >> Cases >> rw[])
val _ = export_rewrites["lookup_ALOOKUP"];

val find_recfun_ALOOKUP = store_thm(
"find_recfun_ALOOKUP",
``∀funs n. find_recfun n funs = ALOOKUP funs n``,
Induct >- rw[find_recfun_def] >>
qx_gen_tac `d` >>
PairCases_on `d` >>
rw[find_recfun_def])
val _ = export_rewrites["find_recfun_ALOOKUP"]

(* pat_bindings *)

val pat_bindings_acc = store_thm("pat_bindings_acc",
  ``(∀p l. pat_bindings p l = pat_bindings p [] ++ l) ∧
    (∀ps l. pats_bindings ps l = pats_bindings ps [] ++ l)``,
  ho_match_mp_tac (TypeBase.induction_of``:pat``) >> rw[] >>
  simp_tac std_ss [pat_bindings_def] >>
  metis_tac[APPEND,APPEND_ASSOC])

val pats_bindings_MAP = store_thm("pats_bindings_MAP",
  ``∀ps ls. pats_bindings ps ls = FLAT (MAP (combin$C pat_bindings []) (REVERSE ps)) ++ ls``,
  Induct >>
  rw[pat_bindings_def] >>
  rw[Once pat_bindings_acc])

val _ = Parse.overload_on("pat_vars",``λp. set (pat_bindings p [])``)

(* misc *)

val evaluate_list_MAP_Var = store_thm("evaluate_list_MAP_Var",
  ``∀vs ck menv cenv s env. set vs ⊆ set (MAP FST env) ⇒ evaluate_list ck menv cenv s env (MAP (Var o Short) vs) (s,Rval (MAP (THE o ALOOKUP env) vs))``,
  Induct >> simp[Once evaluate_cases] >>
  rw[] >> rw[Once evaluate_cases,SemanticPrimitivesTheory.lookup_var_id_def] >>
  Cases_on`ALOOKUP env h`>>simp[] >>
  imp_res_tac ALOOKUP_FAILS >>
  fsrw_tac[DNF_ss][MEM_MAP,EXISTS_PROD])

val store_to_fmap_def = Define`
  store_to_fmap s = FUN_FMAP (combin$C EL s) (count (LENGTH s))`

val is_Short_def = Define
  `is_Short (Short _) = T ∧
   is_Short _ = F`
val dest_Short_def = Define`
  dest_Short (Short x) = x`
val _ = export_rewrites["is_Short_def","dest_Short_def"]

val _ = Parse.overload_on("menv_dom",``λmenv:envM.  set (FLAT (MAP (λx. MAP (Long (FST x) o FST) (SND x)) menv))``)
val _ = Parse.overload_on("menv_range",``λmenv:envM.  set (FLAT (MAP (MAP SND o SND) menv))``)
val _ = Parse.overload_on("env_range",``λenv:envE. set (MAP SND env)``)

val mk_id_inj = store_thm("mk_id_inj",
  ``mk_id mn n1 = mk_id mn n2 ⇒ n1 = n2``,
  rw[AstTheory.mk_id_def] >>
  BasicProvers.EVERY_CASE_TAC >> fs[])

val map_result_def = Define`
  (map_result f (Rval v) = Rval (f v)) ∧
  (map_result _ (Rerr e) = Rerr e)`
val _ = export_rewrites["map_result_def"]

val every_result_def = Define`
  (every_result _ P2 (Rerr (Rraise v)) = P2 v) ∧
  (every_result _ _ (Rerr _) = T) ∧
  (every_result P1 _ (Rval v) = P1 v)`
val _ = export_rewrites["every_result_def"]

val every_result_rwt = store_thm("every_result_rwt",
  ``every_result P1 P2 res = ((∀v. (res = Rval v) ⇒ P1 v) ∧ (∀v. (res = Rerr (Rraise v)) ⇒ P2 v))``,
  Cases_on`res`>>rw[]>>Cases_on`e`>>rw[])

val evaluate_dec_decs = store_thm("evaluate_dec_decs",
  ``evaluate_dec mn menv cenv s env dec (s',res) =
    evaluate_decs mn menv cenv s env [dec] (s',(case res of Rval (cenv',_) => cenv' | _ => []),map_result SND res)``,
  simp[Once evaluate_decs_cases] >>
  Cases_on`res`>>simp[] >>
  simp[Once evaluate_decs_cases,SemanticPrimitivesTheory.combine_dec_result_def] >>
  simp[LibTheory.emp_def,LibTheory.merge_def] >>
  Cases_on`a`>>simp[])

val evaluate_decs_divergence_take = store_thm("evaluate_decs_divergence_take",
  ``∀ds mn menv cenv s env.
    (∀res. ¬ evaluate_decs mn menv cenv s env ds res)
    ⇒
    ∃n s' cenv' env'.
    n < LENGTH ds ∧
    evaluate_decs mn menv cenv s env (TAKE n ds) (s',cenv',Rval env') ∧
    (∀res. ¬ evaluate_dec mn menv (cenv'++cenv) s' (env'++env) (EL n ds) res)``,
  Induct >>
  simp[Once evaluate_decs_cases] >>
  qx_gen_tac`d` >> rpt strip_tac >>
  Cases_on`∃res. evaluate_dec mn menv cenv s env d res` >- (
    fs[] >>
    PairCases_on`res`>>fs[] >>
    Cases_on`res1`>>fs[]>-(
      PairCases_on`a`>>fs[]>>
      fsrw_tac[DNF_ss][] >>
      first_x_assum(qspecl_then[`mn`,`menv`,`merge a0 cenv`,`res0`,`merge a1 env`]mp_tac) >>
      simp[FORALL_PROD] >>
      discharge_hyps >- metis_tac[] >>
      strip_tac >>
      qexists_tac`SUC n` >>
      simp[] >>
      simp[Once evaluate_decs_cases] >>
      fsrw_tac[DNF_ss][] >>
      qexists_tac`s'` >>
      simp[SemanticPrimitivesTheory.combine_dec_result_def] >>
      qexists_tac`merge env' a1` >>
      qexists_tac`res0` >>
      qexists_tac`cenv'` >>
      qexists_tac`a0` >>
      qexists_tac`a1` >>
      qexists_tac`Rval env'` >>
      simp[] >>
      fs[LibTheory.merge_def] ) >>
    fsrw_tac[DNF_ss][] >>
    metis_tac[] ) >>
  qexists_tac`0` >>
  simp[] >>
  simp[Once evaluate_decs_cases,LibTheory.emp_def,LibTheory.merge_def] >>
  metis_tac[] )

val evaluate_decs_divergence = store_thm("evaluate_decs_divergence",
  ``∀ds mn menv cenv s env.
    (∀res. ¬ evaluate_decs mn menv cenv s env ds res)
    ⇒
    ∃d ds'.
    d ::ds' = ds ∧
    ∀res. evaluate_dec mn menv cenv s env d res ⇒
    ∃s' cenv' env'. res = (s',Rval (cenv',env')) ∧
    ∀res. ¬ evaluate_decs mn menv (cenv'++cenv) s' (env'++env) ds' res``,
  Induct >> simp[Once evaluate_decs_cases] >>
  qx_gen_tac`d` >> rpt strip_tac >>
  PairCases_on`res`>>fs[] >>
  Cases_on`res1`>>fs[]>-(
    PairCases_on`a`>>fs[]>>
    fsrw_tac[DNF_ss][] >>
    fs[LibTheory.merge_def,FORALL_PROD] >>
    metis_tac[] ) >>
  metis_tac[])

val pmatch_tac =
  ho_match_mp_tac pmatch_ind >>
  strip_tac >- (
    rw[pmatch_def,bind_def,pat_bindings_def] >>
    rw[] >> rw[EXTENSION] ) >>
  strip_tac >- (
    rw[pmatch_def,pat_bindings_def] >> rw[] ) >>
  strip_tac >- (
    rpt gen_tac >> fs[] >>
    Cases_on `ALOOKUP cenv n` >> fs[] >- (
      rw[pmatch_def] ) >>
    qmatch_assum_rename_tac `ALOOKUP cenv n = SOME p`[] >>
    PairCases_on `p` >> fs[] >>
    Cases_on `ALOOKUP cenv n'` >> fs[] >- (
      rw[pmatch_def] ) >>
    qmatch_assum_rename_tac `ALOOKUP cenv n' = SOME p`[] >>
    PairCases_on `p` >> fs[] >>
    rw[pmatch_def,pat_bindings_def] >>
    srw_tac[ETA_ss][] >> fsrw_tac[SATISFY_ss][] ) >>
  strip_tac >- (
    rw[pmatch_def,pat_bindings_def] >>
    Cases_on `store_lookup lnum s`>>
    fsrw_tac[DNF_ss][store_lookup_def,EVERY_MEM,MEM_EL] >>
    metis_tac[]) >>
  strip_tac >- (
    rw[pmatch_def,pat_bindings_def] >>
    Cases_on `store_lookup lnum s`>>
    fsrw_tac[DNF_ss][store_lookup_def,EVERY_MEM,MEM_EL] >>
    metis_tac[]) >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- ( rw[pmatch_def] >> rw[] ) >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- (rw[pmatch_def,pat_bindings_def] >> rw[]) >>
  strip_tac >- (rw[pmatch_def,pat_bindings_def] >> rw[]) >>
  strip_tac >- (rw[pmatch_def,pat_bindings_def] >> rw[]) >>
  strip_tac >- (
    rpt gen_tac >>
    strip_tac >>
    simp_tac(srw_ss())[pmatch_def,pat_bindings_def] >>
    Cases_on `pmatch cenv s p v env` >> fs[] >>
    qmatch_assum_rename_tac `pmatch cenv s p v env = Match env0`[] >>
    Cases_on `pmatch_list cenv s ps vs env0` >> fs[] >>
    simp[Once pat_bindings_acc,SimpRHS] >>
    metis_tac[APPEND_ASSOC]) >>
  rw[pmatch_def]

val cenv = rand ``pmatch cenv``

val pmatch_dom = store_thm("pmatch_dom",
  ``(∀^cenv s p v env env' (menv:envM).
      (pmatch cenv s p v env = Match env') ⇒
      (MAP FST env' = pat_bindings p [] ++ (MAP FST env))) ∧
    (∀^cenv s ps vs env env' (menv:envM).
      (pmatch_list cenv s ps vs env = Match env') ⇒
      (MAP FST env' = pats_bindings ps [] ++ MAP FST env))``,
    pmatch_tac)

val build_rec_env_dom = store_thm(
"build_rec_env_dom",
``MAP FST (build_rec_env defs cenv env) = MAP FST defs ++ MAP FST env``,
rw[build_rec_env_def,bind_def,FOLDR_CONS_triple] >>
rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
rw[FST_triple])
val _ = export_rewrites["build_rec_env_dom"]

val build_rec_env_MAP = store_thm("build_rec_env_MAP",
  ``build_rec_env funs cle env = MAP (λ(f,cdr). (f, (Recclosure cle funs f))) funs ++ env``,
  rw[build_rec_env_def] >>
  qho_match_abbrev_tac `FOLDR (f funs) env funs = MAP (g funs) funs ++ env` >>
  qsuff_tac `∀funs env funs0. FOLDR (f funs0) env funs = MAP (g funs0) funs ++ env` >- rw[]  >>
  unabbrev_all_tac >> simp[] >>
  Induct >> rw[bind_def] >>
  PairCases_on`h` >> rw[])

val evaluate_dec_err_cenv_emp = store_thm("evaluate_dec_err_cenv_emp",
  ``∀mn menv cenv s env d res. evaluate_dec mn menv cenv s env d res ⇒
    ∀err. SND res = Rerr err ∧ err ≠ Rtype_error ⇒ dec_to_cenv mn d = []``,
  ho_match_mp_tac evaluate_dec_ind >> simp[dec_to_cenv_def])

val new_dec_cns_def = Define`
  (new_dec_cns (Dtype ts) = (MAP FST (FLAT (MAP (SND o SND) ts)))) ∧
  (new_dec_cns (Dexn c _) = [c]) ∧
  (new_dec_cns _ = [])`
val _ = export_rewrites["new_dec_cns_def"]

val _ = Parse.overload_on("new_decs_cns",``λds. BIGUNION (IMAGE (set o new_dec_cns) (set ds))``)

val new_top_cns_def = Define`
  (new_top_cns (Tdec d) = set (new_dec_cns d)) ∧
  (new_top_cns (Tmod _ _ ds) = new_decs_cns ds)`
val _ = export_rewrites["new_top_cns_def"]

(* FV *)

val FV_def = tDefine "FV"`
  (FV (Raise e) = FV e) ∧
  (FV (Handle e pes) = FV e ∪ FV_pes pes) ∧
  (FV (Lit _) = {}) ∧
  (FV (Con _ ls) = FV_list ls) ∧
  (FV (Var id) = {id}) ∧
  (FV (Fun x e) = FV e DIFF {Short x}) ∧
  (FV (Uapp _ e) = FV e) ∧
  (FV (App _ e1 e2) = FV e1 ∪ FV e2) ∧
  (FV (Log _ e1 e2) = FV e1 ∪ FV e2) ∧
  (FV (If e1 e2 e3) = FV e1 ∪ FV e2 ∪ FV e3) ∧
  (FV (Mat e pes) = FV e ∪ FV_pes pes) ∧
  (FV (Let x e b) = FV e ∪ (FV b DIFF {Short x})) ∧
  (FV (Letrec defs b) =
     let ds = set (MAP (Short o FST) defs) in
     FV_defs ds defs ∪ (FV b DIFF ds)) ∧
  (FV_list [] = {}) ∧
  (FV_list (e::es) = FV e ∪ FV_list es) ∧
  (FV_pes [] = {}) ∧
  (FV_pes ((p,e)::pes) =
     (FV e DIFF (IMAGE Short (pat_vars p))) ∪ FV_pes pes) ∧
  (FV_defs _ [] = {}) ∧
  (FV_defs ds ((_,x,e)::defs) =
     (FV e DIFF ({Short x} ∪ ds)) ∪ FV_defs ds defs)`
(WF_REL_TAC `inv_image $< (λx. case x of
   | INL e => exp_size e
   | INR (INL es) => exp6_size es
   | INR (INR (INL pes)) => exp3_size pes
   | INR (INR (INR (_,defs))) => exp1_size defs)`)
val _ = export_rewrites["FV_def"]

val FV_ind = theorem"FV_ind"

val _ = Parse.overload_on("SFV",``λe. {x | Short x ∈ FV e}``)

val FV_dec_def = Define`
  (FV_dec (Dlet p e) = FV (Mat e [(p,Lit ARB)])) ∧
  (FV_dec (Dletrec defs) = FV (Letrec defs (Lit ARB))) ∧
  (FV_dec (Dtype _) = {}) ∧
  (FV_dec (Dexn _ _) = {})`
val _ = export_rewrites["FV_dec_def"]

val new_dec_vs_def = Define`
  (new_dec_vs (Dtype _) = []) ∧
  (new_dec_vs (Dexn _ _) = []) ∧
  (new_dec_vs (Dlet p e) = pat_bindings p []) ∧
  (new_dec_vs (Dletrec funs) = MAP FST funs)`
val _ = export_rewrites["new_dec_vs_def"]

val _ = Parse.overload_on("new_decs_vs",``λdecs. FLAT (REVERSE (MAP new_dec_vs decs))``)

val FV_decs_def = Define`
  (FV_decs [] = {}) ∧
  (FV_decs (d::ds) = FV_dec d ∪ ((FV_decs ds) DIFF (set (MAP Short (new_dec_vs d)))))`

val FV_top_def = Define`
  (FV_top (Tdec d) = FV_dec d) ∧
  (FV_top (Tmod mn _ ds) = FV_decs ds)`
val _ = export_rewrites["FV_top_def"]

val FINITE_FV = store_thm(
"FINITE_FV",
``(∀exp. FINITE (FV exp)) ∧
  (∀es. FINITE (FV_list es)) ∧
  (∀pes. FINITE (FV_pes pes)) ∧
  (∀ds defs. FINITE (FV_defs ds defs))``,
ho_match_mp_tac FV_ind >>
rw[pairTheory.EXISTS_PROD] >>
fsrw_tac[SATISFY_ss][])
val _ = export_rewrites["FINITE_FV"]

val FV_defs_MAP = store_thm("FV_defs_MAP",
  ``FV_defs ds defs = BIGUNION (IMAGE (λ(d,x,e). FV e DIFF ({Short x} ∪ ds)) (set defs))``,
  Induct_on`defs`>>simp[]>>
  qx_gen_tac`p`>>PairCases_on`p`>>rw[])

val FV_pes_MAP = store_thm("FV_pes_MAP",
  ``FV_pes pes = BIGUNION (IMAGE (λ(p,e). FV e DIFF (IMAGE Short (pat_vars p))) (set pes))``,
  Induct_on`pes`>>simp[]>>
  qx_gen_tac`p`>>PairCases_on`p`>>rw[])

val FV_list_MAP = store_thm("FV_list_MAP",
  ``FV_list es = BIGUNION (IMAGE FV (set es))``,
  Induct_on`es`>>simp[])

val do_prim_app_FV = store_thm(
"do_prim_app_FV",
``∀s env op v1 v2 s' env' exp.
  (op ≠ Opapp) ∧
  (do_app s env op v1 v2 = SOME (s',env',exp)) ⇒
  (FV exp = {})``,
rw[bigClockTheory.do_app_cases] >> rw[])

val do_log_FV = store_thm(
"do_log_FV",
``(do_log op v e2 = SOME exp) ⇒
  (FV exp ⊆ FV e2)``,
fs[do_log_def] >>
BasicProvers.EVERY_CASE_TAC >>
rw[] >>rw[])

val do_if_FV = store_thm(
"do_if_FV",
``(do_if v e2 e3 = SOME e) ⇒
  (FV e ⊆ FV e2 ∪ FV e3)``,
fs[do_if_def] >>
BasicProvers.EVERY_CASE_TAC >>
rw[] >>rw[])

val evaluate_dec_new_dec_vs = store_thm("evaluate_dec_new_dec_vs",
  ``∀mn menv cenv s env dec res.
    evaluate_dec mn menv cenv s env dec res ⇒
    ∀tds vs. (SND res = Rval (tds,vs)) ⇒ MAP FST vs = new_dec_vs dec``,
  ho_match_mp_tac evaluate_dec_ind >>
  simp[LibTheory.emp_def] >> rw[] >>
  imp_res_tac pmatch_dom >> fs[])

val evaluate_decs_new_decs_vs = store_thm("evaluate_decs_new_decs_vs",
  ``∀mn menv cenv s env decs res.
    evaluate_decs mn menv cenv s env decs res ⇒
    ∀env'. SND (SND res) = Rval env' ⇒ MAP FST env' = new_decs_vs decs``,
  ho_match_mp_tac evaluate_decs_ind >>
  simp[LibTheory.emp_def,SemanticPrimitivesTheory.combine_dec_result_def] >>
  rpt gen_tac >>
  BasicProvers.CASE_TAC >>
  simp[LibTheory.merge_def] >>
  metis_tac[evaluate_dec_new_dec_vs,SND])

(* evaluate_match_with *)

val (evaluate_match_with_rules,evaluate_match_with_ind,evaluate_match_with_cases) = Hol_reln
  (* evaluate_rules |> SIMP_RULE (srw_ss()) [] |> concl |> strip_conj |>
     Lib.filter (fn tm => tm |> strip_forall |> snd |> strip_imp |> snd |>
     strip_comb |> fst |> same_const ``evaluate_match``) *)
   `(evaluate_match_with P (cenv) (cs:count_store) env v [] err_v (cs,Rerr (Rraise err_v))) ∧
    (ALL_DISTINCT (pat_bindings p []) ∧
     (pmatch cenv (SND cs) p v env = Match env') ∧ P cenv cs env' (p,e) bv ⇒
     evaluate_match_with P cenv cs env v ((p,e)::pes) err_v bv) ∧
    (ALL_DISTINCT (pat_bindings p []) ∧
     (pmatch cenv (SND cs) p v env = No_match) ∧
     evaluate_match_with P cenv cs env v pes err_v bv ⇒
     evaluate_match_with P cenv cs env v ((p,e)::pes) err_v bv) ∧
    ((pmatch cenv (SND cs) p v env = Match_type_error) ⇒
     evaluate_match_with P cenv cs env v ((p,e)::pes) err_v (cs,Rerr Rtype_error)) ∧
    (¬ALL_DISTINCT (pat_bindings p []) ⇒
     evaluate_match_with P cenv cs env v ((p,e)::pes) err_v (cs,Rerr Rtype_error))`

val evaluate_match_with_evaluate = store_thm(
"evaluate_match_with_evaluate",
``evaluate_match ck menv = evaluate_match_with (λcenv cs env pe bv. evaluate ck menv cenv cs env (SND pe) bv)``,
simp_tac std_ss [FUN_EQ_THM,FORALL_PROD] >>
ntac 5 gen_tac >>
Induct >-
  rw[Once evaluate_cases,Once evaluate_match_with_cases] >>
Cases >>
rw[Once evaluate_cases] >>
rw[Once evaluate_match_with_cases,SimpRHS] >>
fs[])

val evaluate_nicematch_strongind = save_thm(
"evaluate_nicematch_strongind",
evaluate_strongind
|> INST_TYPE[alpha|->``:tid_or_exn``]
|> Q.SPECL [`P0`,`P1`,`λck menv. evaluate_match_with (λcenv cs env pe bv. P0 ck menv cenv cs env (SND pe) bv)`] |> SIMP_RULE (srw_ss()) []
|> UNDISCH_ALL
|> CONJUNCTS
|> C (curry List.take) 2
|> LIST_CONJ
|> DISCH_ALL
|> Q.GENL [`P1`,`P0`]
|> SIMP_RULE (srw_ss()) [evaluate_match_with_rules])

(* pmatch *)

val map_match_def = Define`
  (map_match f (Match env) = Match (f env)) ∧
  (map_match f x = x)`
val _ = export_rewrites["map_match_def"]

val pmatch_APPEND = store_thm(
"pmatch_APPEND",
``(∀^cenv s p v env n.
    (pmatch cenv s p v env =
     map_match (combin$C APPEND (DROP n env)) (pmatch cenv s p v (TAKE n env)))) ∧
  (∀^cenv s ps vs env n.
    (pmatch_list cenv s ps vs env =
     map_match (combin$C APPEND (DROP n env)) (pmatch_list cenv s ps vs (TAKE n env))))``,
ho_match_mp_tac pmatch_ind >>
strip_tac >- rw[pmatch_def,bind_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- (
  rw[pmatch_def] >>
  Cases_on `ALOOKUP cenv n` >> fs[] >>
  PairCases_on `x` >> fs[] >>
  rw[] >> fs[] >>
  Cases_on `ALOOKUP cenv n'` >> fs[] >>
  PairCases_on `x` >> fs[] >>
  rw[] >> fs[] ) >>
strip_tac >- (
  rw[pmatch_def] >>
  BasicProvers.CASE_TAC >>
  fs[] ) >>
strip_tac >- (
  rw[pmatch_def] >>
  BasicProvers.CASE_TAC >>
  fs[] ) >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- (
  rw[pmatch_def] >>
  Cases_on `pmatch cenv p v (TAKE n env)` >> fs[] >>
  Cases_on `pmatch cenv p v env` >> fs[] >>
  TRY (first_x_assum (qspec_then `n` mp_tac) >> rw[] >> NO_TAC) >>
  first_x_assum (qspec_then `n` mp_tac) >> rw[] >>
  first_x_assum (qspec_then `LENGTH l` mp_tac) >> rw[] >>
  rw[TAKE_APPEND1,DROP_APPEND1,DROP_LENGTH_NIL] ) >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- rw[pmatch_def] >>
strip_tac >- (
  rw[pmatch_def] >>
  pop_assum (qspec_then`n`mp_tac) >>
  Cases_on `pmatch cenv s p v (TAKE n env)`>>fs[] >>
  strip_tac >> res_tac >>
  pop_assum(qspec_then`LENGTH l`mp_tac) >>
  simp_tac(srw_ss())[TAKE_LENGTH_APPEND,DROP_LENGTH_APPEND] ) >>
strip_tac >- rw[pmatch_def] >>
NTAC 2 (strip_tac >- (
  rw[pmatch_def] >>
  pop_assum (qspec_then`n`mp_tac) >>
  Cases_on `pmatch cenv s p v (TAKE n env)`>>fs[] >>
  strip_tac >> res_tac >>
  pop_assum(qspec_then`LENGTH l`mp_tac) >>
  simp_tac(srw_ss())[TAKE_LENGTH_APPEND,DROP_LENGTH_APPEND] )) >>
strip_tac >- rw[pmatch_def])

val pmatch_plit = store_thm(
"pmatch_plit",
``(pmatch cenv s (Plit l) v env = r) =
  (((v = Litv l) ∧ (r = Match env)) ∨
   ((∃l'. (v = Litv l') ∧ lit_same_type l l' ∧ l ≠ l') ∧
    (r = No_match)) ∨
   ((∀l'. (v = Litv l') ⇒ ¬lit_same_type l l') ∧ (r = Match_type_error)))``,
Cases_on `v` >> rw[pmatch_def,EQ_IMP_THM] >>
Cases_on `l` >> fs[lit_same_type_def])

val pmatch_nil = save_thm("pmatch_nil",
  LIST_CONJ [
    pmatch_APPEND
    |> CONJUNCT1
    |> Q.SPECL[`cenv`,`s`,`p`,`v`,`env`,`0`]
    |> SIMP_RULE(srw_ss())[]
  ,
    pmatch_APPEND
    |> CONJUNCT2
    |> Q.SPECL[`cenv`,`s`,`ps`,`vs`,`env`,`0`]
    |> SIMP_RULE(srw_ss())[]
  ])

val pmatch_extend_cenv = store_thm("pmatch_extend_cenv",
  ``(∀^cenv s p v env id x. id ∉ set (MAP FST cenv) ∧ pmatch cenv s p v env ≠ Match_type_error
    ⇒ pmatch ((id,x)::cenv) s p v env = pmatch cenv s p v env) ∧
    (∀^cenv s ps vs env id x. id ∉ set (MAP FST cenv) ∧ pmatch_list cenv s ps vs env ≠ Match_type_error
    ⇒ pmatch_list ((id,x)::cenv) s ps vs env = pmatch_list cenv s ps vs env)``,
  ho_match_mp_tac pmatch_ind >>
  rw[pmatch_def] >> rw[] >>
  BasicProvers.CASE_TAC >> rw[] >> rpt (pop_assum mp_tac) >>
  TRY (BasicProvers.CASE_TAC >> rw[] >> rpt (pop_assum mp_tac)) >>
  TRY (BasicProvers.CASE_TAC >> rw[] >> rpt (pop_assum mp_tac)) >>
  TRY (BasicProvers.CASE_TAC) >> rw[] >>
  TRY (
    TRY (BasicProvers.CASE_TAC) >> rw[] >>
    imp_res_tac ALOOKUP_MEM >>
    fsrw_tac[DNF_ss][MEM_MAP,FORALL_PROD] >>
    metis_tac[]))

(* all_cns *)

val all_cns_pat_def = Define`
  (all_cns_pat (Pvar _) = {}) ∧
  (all_cns_pat (Plit _) = {}) ∧
  (all_cns_pat (Pcon cn ps) = cn INSERT all_cns_pats ps) ∧
  (all_cns_pat (Pref p) = all_cns_pat p) ∧
  (all_cns_pats [] = {}) ∧
  (all_cns_pats (p::ps) = all_cns_pat p ∪ all_cns_pats ps)`
val _ = export_rewrites["all_cns_pat_def"]

val all_cns_exp_def = tDefine "all_cns_exp"`
  (all_cns_exp (Raise e) = all_cns_exp e) ∧
  (all_cns_exp (Handle e pes) = all_cns_exp e ∪ all_cns_pes pes) ∧
  (all_cns_exp (Lit _) = {}) ∧
  (all_cns_exp (Con cn es) = cn INSERT all_cns_list es) ∧
  (all_cns_exp (Var _) = {}) ∧
  (all_cns_exp (Fun _ e) = all_cns_exp e) ∧
  (all_cns_exp (Uapp _ e) = all_cns_exp e) ∧
  (all_cns_exp (App _ e1 e2) = all_cns_exp e1 ∪ all_cns_exp e2) ∧
  (all_cns_exp (Log _ e1 e2) = all_cns_exp e1 ∪ all_cns_exp e2) ∧
  (all_cns_exp (If e1 e2 e3) = all_cns_exp e1 ∪ all_cns_exp e2 ∪ all_cns_exp e3) ∧
  (all_cns_exp (Mat e pes) = all_cns_exp e ∪ all_cns_pes pes) ∧
  (all_cns_exp (Let _ e1 e2) =  all_cns_exp e1 ∪ all_cns_exp e2) ∧
  (all_cns_exp (Letrec defs e) =  all_cns_defs defs ∪ all_cns_exp e) ∧
  (all_cns_list [] = {}) ∧
  (all_cns_list (e::es) = all_cns_exp e ∪ all_cns_list es) ∧
  (all_cns_defs [] = {}) ∧
  (all_cns_defs ((_,_,e)::defs) = all_cns_exp e ∪ all_cns_defs defs) ∧
  (all_cns_pes [] = {}) ∧
  (all_cns_pes ((p,e)::pes) = all_cns_pat p ∪ all_cns_exp e ∪ all_cns_pes pes)`
(WF_REL_TAC`inv_image $<
  (λx. case x of INL e => exp_size e
               | INR (INL es) => exp6_size es
               | INR (INR (INL defs)) => exp1_size defs
               | INR (INR (INR pes)) => exp3_size pes)`)
val _ = export_rewrites["all_cns_exp_def"]

val all_cns_def = tDefine "all_cns"`
  (all_cns (Litv _) = {}) ∧
  (all_cns (Conv cn vs) = cn INSERT BIGUNION (IMAGE all_cns (set vs))) ∧
  (all_cns (Closure env _ exp) = BIGUNION (IMAGE all_cns (env_range env)) ∪ all_cns_exp exp) ∧
  (all_cns (Recclosure env defs _) = BIGUNION (IMAGE all_cns (env_range env)) ∪ all_cns_defs defs) ∧
  (all_cns (Loc _) = {})`
  (WF_REL_TAC `measure v_size` >>
   srw_tac[ARITH_ss][v1_size_thm,v3_size_thm,SUM_MAP_v2_size_thm] >>
   Q.ISPEC_THEN`v_size`imp_res_tac SUM_MAP_MEM_bound >>
   fsrw_tac[ARITH_ss][])
val all_cns_def = save_thm("all_cns_def",SIMP_RULE(srw_ss()++ETA_ss)[]all_cns_def)
val _ = export_rewrites["all_cns_def"]

val all_cns_list_MAP = store_thm("all_cns_list_MAP",
  ``∀es. all_cns_list es = BIGUNION (IMAGE all_cns_exp (set es))``,
  Induct >> simp[])

val all_cns_defs_MAP = store_thm("all_cns_defs_MAP",
  ``∀ds. all_cns_defs ds = BIGUNION (IMAGE all_cns_exp (set (MAP (SND o SND) ds)))``,
  Induct >>simp[]>>qx_gen_tac`x`>>PairCases_on`x`>>simp[])

val all_cns_pes_MAP = store_thm("all_cns_pes_MAP",
  ``∀ps. all_cns_pes ps = BIGUNION (IMAGE all_cns_pat (set (MAP FST ps))) ∪ BIGUNION (IMAGE all_cns_exp (set (MAP SND ps)))``,
  Induct >>simp[]>>qx_gen_tac`x`>>PairCases_on`x`>>simp[] >> metis_tac[UNION_COMM,UNION_ASSOC]);

val do_app_all_cns = store_thm("do_app_all_cns",
  ``∀cns s env op v1 v2 s' env' exp.
      all_cns v1 ⊆ cns ∧ all_cns v2 ⊆ cns ∧
      BIGUNION (IMAGE all_cns (env_range env)) ⊆ cns ∧
      BIGUNION (IMAGE all_cns (set s)) ⊆ cns ∧
      (do_app s env op v1 v2 = SOME (s',env',exp))
      ⇒
      BIGUNION (IMAGE all_cns (set s')) ⊆ cns ∧
      BIGUNION (IMAGE all_cns (env_range env')) ⊆ cns ∧
      all_cns_exp exp ⊆ cns ∪ {SOME(Short"Div");SOME(Short"Eq")}``,
 rw [bigClockTheory.do_app_cases] >>
 fs [all_cns_def, bind_def]
 >- fs[SUBSET_DEF]
 >- (
    rw[build_rec_env_MAP,LIST_TO_SET_MAP,GSYM IMAGE_COMPOSE,combinTheory.o_DEF,LAMBDA_PROD] >>
    fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,MEM_MAP] >>
    metis_tac[])
 >- (
     imp_res_tac ALOOKUP_MEM >>
     fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,all_cns_defs_MAP,MEM_MAP] >>
     metis_tac[])
 >- (
     rw[] >> fs[store_assign_def] >> rw[] >>
     fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD] >> rw[] >>
     imp_res_tac MEM_LUPDATE >> fs[] >> rw[] >>
     TRY (qmatch_assum_rename_tac`MEM z t`[]>>PairCases_on`z`>>fs[]) >>
     metis_tac[]));

val pmatch_all_cns = store_thm("pmatch_all_cns",
  ``(∀^cenv s p v env env'. (pmatch cenv s p v env = Match env') ⇒
    BIGUNION (IMAGE all_cns (env_range env')) ⊆
    all_cns v ∪
    BIGUNION (IMAGE all_cns (env_range env)) ∪
    BIGUNION (IMAGE all_cns (set s))) ∧
    (∀^cenv s ps vs env env'. (pmatch_list cenv s ps vs env = Match env') ⇒
    BIGUNION (IMAGE all_cns (env_range env')) ⊆
    BIGUNION (IMAGE all_cns (set vs)) ∪
    BIGUNION (IMAGE all_cns (env_range env)) ∪
    BIGUNION (IMAGE all_cns (set s)))``,
  ho_match_mp_tac pmatch_ind >>
  rw[pmatch_def,bind_def] >>
  TRY(pop_assum mp_tac >> BasicProvers.CASE_TAC >> rw[]) >>
  TRY(pop_assum mp_tac >> BasicProvers.CASE_TAC >> rw[]) >>
  TRY(rpt (pop_assum mp_tac) >> BasicProvers.CASE_TAC >> rw[]) >>
  TRY(pop_assum mp_tac >> BasicProvers.CASE_TAC >> rw[]) >>
  rfs[] >>
  fsrw_tac[DNF_ss][SUBSET_DEF,store_lookup_def,FORALL_PROD,EXISTS_PROD] >>
  rw[] >> metis_tac[MEM_EL]);

val do_uapp_all_cns = store_thm("do_uapp_all_cns",
  ``∀cns s uop v s' v'.
      all_cns v ⊆ cns ∧
      BIGUNION (IMAGE all_cns (set s)) ⊆ cns ∧
      (do_uapp s uop v = SOME (s',v')) ⇒
      all_cns v' ⊆ cns ∧ BIGUNION (IMAGE all_cns (set s')) ⊆ cns``,
  ntac 2 gen_tac >> Cases >>
  Cases >> TRY (Cases_on`l`) >>
  rw[do_uapp_def,LET_THM,store_alloc_def] >>
  fsrw_tac[DNF_ss][SUBSET_DEF,store_lookup_def] >>
  TRY (pop_assum mp_tac >> rw[]) >>
  metis_tac[MEM_EL])

val do_log_all_cns = store_thm("do_log_all_cns",
  ``∀cns op v e e2. all_cns v ⊆ cns ∧ all_cns_exp e ⊆ cns ∧ (do_log op v e = SOME e2) ⇒ all_cns_exp e2 ⊆ cns``,
  gen_tac >> Cases >> Cases >> TRY (Cases_on`l`) >> rw[do_log_def] >> fs[])

val do_if_all_cns = store_thm("do_if_all_cns",
  ``∀cns v e1 e2 e3. all_cns v ⊆ cns ∧ all_cns_exp e1 ⊆ cns ∧ all_cns_exp e2 ⊆ cns ∧ (do_if v e1 e2 = SOME e3) ⇒ all_cns_exp e3 ⊆ cns``,
  gen_tac >> Cases >> rw[do_if_def] >> fs[])

val cenv_dom_def = Define `
cenv_dom cenv = NONE INSERT set (MAP (SOME o FST) cenv)`;

val cenv_bind_div_eq_cenv_dom = store_thm("cenv_bind_div_eq_cenv_dom",
  ``cenv_bind_div_eq cenv ⇒
    SOME(Short "Bind") ∈ cenv_dom cenv ∧
    SOME(Short "Div") ∈ cenv_dom cenv ∧
    SOME(Short "Eq") ∈ cenv_dom cenv``,
  rw[cenv_bind_div_eq_def,cenv_dom_def,MEM_MAP,EXISTS_PROD] >>
  imp_res_tac ALOOKUP_MEM >> metis_tac[])

val cenv_bind_div_eq_append = store_thm("cenv_bind_div_eq_append",
  ``∀cenv cenv'. cenv_bind_div_eq cenv ∧ DISJOINT (set(MAP FST cenv')) (set(MAP FST cenv)) ⇒ cenv_bind_div_eq (cenv' ++ cenv)``,
  rw[cenv_bind_div_eq_def,ALOOKUP_APPEND,IN_DISJOINT] >>
  BasicProvers.CASE_TAC >> imp_res_tac ALOOKUP_MEM >>
  fs[MEM_MAP,FORALL_PROD] >> Cases_on`x` >> metis_tac[])

val evaluate_all_cns = store_thm("evaluate_all_cns",
  ``(∀ck menv cenv s env exp res. evaluate ck menv cenv s env exp res ⇒
       cenv_bind_div_eq cenv ∧
       all_cns_exp exp ⊆ cenv_dom cenv ∧
       (∀v. v ∈ menv_range menv ∨ v ∈ env_range env ∨ MEM v (SND s) ⇒ all_cns v ⊆ cenv_dom cenv) ⇒
       every_result (λv. all_cns v ⊆ cenv_dom cenv) (λv. all_cns v ⊆ cenv_dom cenv) (SND res) ∧
       (∀v. MEM v (SND (FST res)) ⇒ all_cns v ⊆ cenv_dom cenv)) ∧
    (∀ck menv cenv s env exps ress. evaluate_list ck menv cenv s env exps ress ⇒
       cenv_bind_div_eq cenv ∧
       all_cns_list exps ⊆ cenv_dom cenv ∧
       (∀v. v ∈ menv_range menv ∨ v ∈ env_range env ∨ MEM v (SND s) ⇒ all_cns v ⊆ cenv_dom cenv) ⇒
       every_result (EVERY (λv. all_cns v ⊆ cenv_dom cenv)) (λv. all_cns v ⊆ cenv_dom cenv) (SND ress) ∧
       (∀v. MEM v (SND (FST ress)) ⇒ all_cns v ⊆ cenv_dom cenv)) ∧
    (∀ck menv cenv s env v pes errv res. evaluate_match ck menv cenv s env v pes errv res ⇒
      cenv_bind_div_eq cenv ∧
      all_cns_pes pes ⊆ cenv_dom cenv ∧
      (∀v. v ∈ menv_range menv ∨ v ∈ env_range env ∨ MEM v (SND s) ⇒ all_cns v ⊆ cenv_dom cenv)
      ∧ all_cns v ⊆ cenv_dom cenv ∧ all_cns errv ⊆ cenv_dom cenv ⇒
      every_result (λw. all_cns w ⊆ cenv_dom cenv) (λw. all_cns w ⊆ cenv_dom cenv) (SND res) ∧
      (∀v. MEM v (SND (FST res)) ⇒ all_cns v ⊆ cenv_dom cenv))``,
  ho_match_mp_tac evaluate_ind >>
  strip_tac (* Lit *) >- rw[] >>
  strip_tac (* Raise *) >- (rw[] >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rw[] >> fs[] >> metis_tac[] ) >>
  strip_tac (* Handle *) >- (
    rpt gen_tac >> ntac 2 strip_tac >>
    first_x_assum match_mp_tac >>
    fsrw_tac[DNF_ss][bind_def] >>
    ho_match_mp_tac IN_FRANGE_DOMSUB_suff >> rw[]) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    first_x_assum match_mp_tac >>
    fsrw_tac[DNF_ss][] ) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    metis_tac[] ) >>
  strip_tac (* Con *) >- (
    srw_tac[DNF_ss][MEM_MAP,FORALL_PROD,EXISTS_PROD] >>
    fs[do_con_check_def] >- (
      fsrw_tac[DNF_ss][SUBSET_DEF,EVERY_MEM] >>
      metis_tac[] ) >>
    metis_tac[]) >>
  strip_tac >- rw[] >>
  strip_tac >- ( rw[] >> fs[] >> Cases_on`err`>>fs[] >> metis_tac[] ) >>
  strip_tac >- (
    rw[lookup_var_id_def] >>
    BasicProvers.EVERY_CASE_TAC >> fs[] >>
    fsrw_tac[DNF_ss][MEM_FLAT,MEM_MAP,FORALL_PROD] >>
    imp_res_tac ALOOKUP_MEM >>
    metis_tac[]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[] >>
    fsrw_tac[DNF_ss][SUBSET_DEF,MEM_MAP,EXISTS_PROD,FORALL_PROD] >>
    metis_tac[] ) >>
  strip_tac (* Uapp *) >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    qmatch_assum_rename_tac`do_uapp s0 uop v = SOME (s',v')`[] >>
    Q.ISPECL_THEN[`cenv_dom cenv`,`s0`,`uop`,`v`,`s'`,`v'`]mp_tac(do_uapp_all_cns) >>
    simp[BIGUNION_IMAGE_set_SUBSET] >> metis_tac[]) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> PROVE_TAC[] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >>
    first_x_assum match_mp_tac >> fs[] >>
    fsrw_tac[DNF_ss][] >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    imp_res_tac cenv_bind_div_eq_cenv_dom >>
    Q.ISPECL_THEN[`cenv_dom cenv`,`s3`,`env`,`op`,`v1`,`v2`,`s4`,`env'`,`exp''`]
      (mp_tac o SIMP_RULE(srw_ss()++DNF_ss)[SUBSET_DEF]) do_app_all_cns >>
    metis_tac[]) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >>
    rpt BasicProvers.VAR_EQ_TAC >> fs[] >>
    Q.ISPECL_THEN[`cenv_dom cenv`,`s3`,`env`,`Opapp`,`v1`,`v2`,`s4`,`env'`,`e3`] mp_tac do_app_all_cns >>
    discharge_hyps >- (
      conj_tac >- metis_tac[] >>
      conj_tac >- metis_tac[] >>
      conj_tac >- (
        simp_tac(srw_ss()++DNF_ss)[SUBSET_DEF] >>
        metis_tac[SUBSET_DEF] ) >>
      conj_tac >- (
        simp_tac(srw_ss()++DNF_ss)[SUBSET_DEF] >>
        metis_tac[SUBSET_DEF] ) >>
      simp[] ) >>
    simp_tac(srw_ss()++DNF_ss)[SUBSET_DEF] >>
    metis_tac[]) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac (* Log *) >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    first_x_assum match_mp_tac >>
    reverse conj_tac >- metis_tac[] >>
    match_mp_tac do_log_all_cns >>
    metis_tac[] ) >>
  strip_tac >- ( rw[] >> metis_tac[] ) >>
  strip_tac >- ( rw[] >> metis_tac[] ) >>
  strip_tac (* If *) >- (
    rpt gen_tac >> strip_tac >> simp[] >> strip_tac >>
    first_x_assum match_mp_tac >> fs[] >>
    reverse conj_tac >- metis_tac[] >>
    match_mp_tac do_if_all_cns >>
    metis_tac[] ) >>
  strip_tac >- ( rw[] >> metis_tac[] ) >>
  strip_tac >- ( rw[] >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> imp_res_tac cenv_bind_div_eq_cenv_dom >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    first_x_assum match_mp_tac >>
    fsrw_tac[DNF_ss][bind_def] >>
    ho_match_mp_tac IN_FRANGE_DOMSUB_suff >>
    PROVE_TAC[]) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    first_x_assum match_mp_tac >>
    fsrw_tac[DNF_ss][] >>
    simp[build_rec_env_MAP,MEM_MAP,EXISTS_PROD] >>
    rw[] >> rw[] >>
    fsrw_tac[DNF_ss][MEM_MAP,FORALL_PROD,SUBSET_DEF,EXISTS_PROD] >>
    metis_tac[]) >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> Cases_on`err`>>fs[] >> metis_tac[] ) >>
  strip_tac >- ( rpt gen_tac >> ntac 2 strip_tac >> fs[] >> metis_tac[] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    first_x_assum match_mp_tac >>
    imp_res_tac pmatch_all_cns >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[]) >>
  strip_tac >- ( rw[] >> fs[] >> metis_tac[] ) >>
  strip_tac >- rw[] >>
  strip_tac >- rw[])

val dec_cns_def = Define`
  (dec_cns (Dlet p e) = all_cns_pat p ∪ all_cns_exp e) ∧
  (dec_cns (Dletrec defs) = all_cns_defs defs) ∧
  (dec_cns (Dtype _) = {}) ∧
  (dec_cns (Dexn _ _) = {})`
val _ = export_rewrites["dec_cns_def"]

val decs_cns_def = Define`
  (decs_cns _ [] = {}) ∧
  (decs_cns mn (d::ds) = dec_cns d ∪ (decs_cns mn ds DIFF (IMAGE (SOME o mk_id mn) (set (new_dec_cns d)))))`

val top_cns_def = Define`
  (top_cns (Tdec d) = dec_cns d) ∧
  (top_cns (Tmod mn _ ds) = decs_cns (SOME mn) ds)`
val _ = export_rewrites["top_cns_def"]

val evaluate_dec_new_dec_cns = store_thm("evaluate_dec_new_dec_cns",
  ``∀mn menv cenv s env d res. evaluate_dec mn menv cenv s env d res ⇒
    ∀tds env. SND res = Rval (tds,env) ⇒
    MAP (mk_id mn) (new_dec_cns d) = (MAP FST tds)``,
  ho_match_mp_tac evaluate_dec_ind >>
  simp[LibTheory.emp_def,SemanticPrimitivesTheory.build_tdefs_def] >>
  rw[bind_def] >>
  simp[MAP_MAP_o,MAP_FLAT] >> AP_TERM_TAC >>
  simp[MAP_EQ_f,FORALL_PROD,MAP_MAP_o])

val evaluate_dec_all_cns = store_thm("evaluate_dec_all_cns",
  ``∀mn menv cenv s env dec res.
    evaluate_dec mn menv cenv s env dec res ⇒
    (∀v. MEM v (FLAT (MAP (MAP SND o SND) menv)) ∨ MEM v (MAP SND env) ∨ MEM v s ⇒ all_cns v ⊆ cenv_dom cenv)
    ∧ dec_cns dec ⊆ cenv_dom cenv
    ∧ cenv_bind_div_eq cenv
    ⇒
    ∀v. MEM v (FST res) ∨ SND res = Rerr(Rraise v) ⇒ all_cns v ⊆ cenv_dom cenv``,
  ho_match_mp_tac evaluate_dec_ind >> simp[] >>
  rpt conj_tac >>
  rpt strip_tac >>
  imp_res_tac (CONJUNCT1 evaluate_all_cns) >>
  rev_full_simp_tac pure_ss [] >>
  rfs[] >> rpt BasicProvers.VAR_EQ_TAC >> rfs[] >> metis_tac[cenv_bind_div_eq_cenv_dom] )

(* all_locs *)

val all_locs_def = tDefine "all_locs"`
  (all_locs (Litv _) = {}) ∧
  (all_locs (Conv _ vs) = BIGUNION (IMAGE all_locs (set vs))) ∧
  (all_locs (Closure env _ _) = BIGUNION (IMAGE all_locs (env_range env))) ∧
  (all_locs (Recclosure env _ _) = BIGUNION (IMAGE all_locs (env_range env))) ∧
  (all_locs (Loc n) = {n})`
(WF_REL_TAC `measure v_size` >>
 srw_tac[ARITH_ss][v1_size_thm,v3_size_thm,SUM_MAP_v2_size_thm] >>
 Q.ISPEC_THEN`v_size`imp_res_tac SUM_MAP_MEM_bound >>
 fsrw_tac[ARITH_ss][] )
val _ = export_rewrites["all_locs_def"]

val do_uapp_locs = store_thm("do_uapp_locs",
  ``∀s uop v s' v'.
    (∀v. MEM v s ⇒ all_locs v ⊆ count (LENGTH s)) ∧
    all_locs v ⊆ count (LENGTH s) ∧ do_uapp s uop v = SOME (s',v') ⇒
    LENGTH s ≤ LENGTH s' ∧
    (∀v. MEM v s' ⇒ all_locs v ⊆ count (LENGTH s')) ∧
    all_locs v' ⊆ count (LENGTH s')``,
  rpt gen_tac >> simp[do_uapp_def] >>
  BasicProvers.CASE_TAC >> simp[] >>
  BasicProvers.CASE_TAC >> simp[store_alloc_def] >> strip_tac >>
  rpt BasicProvers.VAR_EQ_TAC >> simp[] >>
  TRY (
    pop_assum mp_tac >> BasicProvers.CASE_TAC >>
    fs[store_lookup_def] >> strip_tac >>
    rpt BasicProvers.VAR_EQ_TAC >> simp[]) >>
  rw[] >> fsrw_tac[DNF_ss][SUBSET_DEF] >>
  TRY (rw[] >> res_tac >> simp[] >> NO_TAC) >>
  fs[MEM_EL] >> metis_tac[])

val do_app_locs = store_thm("do_app_locs",
  ``∀s env op v1 v2 s' env' e.
    (∀v. MEM v (MAP SND env) ∨ v = v1 ∨ v = v2 ∨ MEM v s ⇒ all_locs v ⊆ count (LENGTH s)) ∧
    do_app s env op v1 v2 = SOME (s',env',e)
    ⇒
    LENGTH s ≤ LENGTH s' ∧
    (∀v. MEM v (MAP SND env') ∨ MEM v s' ⇒ all_locs v ⊆ count (LENGTH s'))``,
  rw [bigClockTheory.do_app_cases, SUBSET_DEF] >>
  simp[contains_closure_def,LibTheory.bind_def]>>
  rw[AstTheory.opn_lookup_def,AstTheory.opb_lookup_def] >> simp[] >> fs[] >>
  fsrw_tac[DNF_ss][SUBSET_DEF] >>
  TRY(metis_tac[]) >>
  TRY(qpat_assum`X = SOME Y` mp_tac >> BasicProvers.CASE_TAC >> simp[] >> BasicProvers.CASE_TAC >>rw[]) >>
  fs[build_rec_env_MAP]>> rpt BasicProvers.VAR_EQ_TAC >> fs[] >>
  rfs[store_assign_def] >> rpt BasicProvers.VAR_EQ_TAC >> fs[] >>
  imp_res_tac miscTheory.MEM_LUPDATE >> fs[bind_def] >>
  TRY(metis_tac[]) >>
  fs[MEM_MAP,UNCURRY] >> rpt BasicProvers.VAR_EQ_TAC >> fs[] >> fs[MEM_MAP] >> metis_tac[])

val pmatch_locs = store_thm("pmatch_locs",
  ``(∀^cenv s p w env env'.
        pmatch cenv s p w env = Match env' ∧
        (∀v. MEM v (MAP SND env) ∨ v = w ∨ MEM v s ⇒ all_locs v ⊆ count (LENGTH s))
        ⇒
        (∀v. MEM v (MAP SND env') ⇒ all_locs v ⊆ count (LENGTH s))) ∧
    (∀^cenv s ps ws env env'.
        pmatch_list cenv s ps ws env = Match env' ∧
        (∀v. MEM v (MAP SND env) ∨ MEM v ws ∨ MEM v s ⇒ all_locs v ⊆ count (LENGTH s))
        ⇒
        (∀v. MEM v (MAP SND env') ⇒ all_locs v ⊆ count (LENGTH s)))``,
    ho_match_mp_tac pmatch_ind >>
    strip_tac >- (rw[pmatch_def,LibTheory.bind_def] >> fs[]) >>
    strip_tac >- (rw[pmatch_def]) >>
    strip_tac >- (
      simp[pmatch_def] >>
      rpt gen_tac >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      BasicProvers.CASE_TAC >> fs[] >>
      TRY(BasicProvers.CASE_TAC >> fs[]) >>
      TRY(BasicProvers.CASE_TAC >> fs[]) >>
      TRY(BasicProvers.CASE_TAC >> fs[]) >>
      TRY(BasicProvers.CASE_TAC >> fs[]) >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[] ) >>
    strip_tac >- (
      simp[pmatch_def,store_lookup_def] >>
      rpt gen_tac >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[MEM_EL] ) >>
    strip_tac >- (
      simp[pmatch_def,store_lookup_def] >>
      rpt gen_tac >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[MEM_EL] ) >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- (
      simp[pmatch_def] >>
      rpt gen_tac >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      metis_tac[] ) >>
    strip_tac >- rw[pmatch_def] >>
    strip_tac >- (
      simp[pmatch_def] >>
      rpt gen_tac >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      metis_tac[] ) >>
    strip_tac >- rw[pmatch_def] >-
    rw [pmatch_def])

val tac1 =
    rw[] >> rw[all_locs_def] >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS]

val tac0 =
  qpat_assum`P ⇒ Q`mp_tac >>
  discharge_hyps >- tac1 >>
  strip_tac

val tac =
  rpt gen_tac >> ntac 2 strip_tac >> fs[LibTheory.bind_def] >>
  tac0 >>
  fsrw_tac[DNF_ss][SUBSET_DEF] >>
  metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS]

val evaluate_locs = store_thm("evaluate_locs",
  ``(∀ck menv ^cenv cs env e res. evaluate ck menv cenv cs env e res ⇒
       (∀v. v ∈ menv_range menv ∨ MEM v (SND cs) ∨ v ∈ env_range env ⇒ all_locs v ⊆ count (LENGTH (SND cs)))
       ⇒
       LENGTH (SND cs) ≤ LENGTH (SND (FST res)) ∧
       every_result (λv. all_locs v ⊆ count (LENGTH (SND (FST res)))) (λv. all_locs v ⊆ count (LENGTH (SND (FST res)))) (SND res) ∧
       (∀v. MEM v (SND (FST res)) ⇒ all_locs v ⊆ count (LENGTH (SND (FST res))))) ∧
    (∀ck menv ^cenv cs env e res. evaluate_list ck menv cenv cs env e res ⇒
       (∀v. v ∈ menv_range menv ∨ MEM v (SND cs) ∨ v ∈ env_range env ⇒ all_locs v ⊆ count (LENGTH (SND cs)))
       ⇒
       LENGTH (SND cs) ≤ LENGTH (SND (FST res)) ∧
       every_result (EVERY (λv. all_locs v ⊆ count (LENGTH (SND (FST res))))) (λv. all_locs v ⊆ count (LENGTH (SND (FST res)))) (SND res) ∧
       (∀v. MEM v (SND (FST res)) ⇒ all_locs v ⊆ count (LENGTH (SND (FST res))))) ∧
    (∀ck menv ^cenv cs env w pes errv res. evaluate_match ck menv cenv cs env w pes errv res ⇒
       (∀v. v = w ∨ v = errv ∨ v ∈ menv_range menv ∨ MEM v (SND cs) ∨ v ∈ env_range env ⇒ all_locs v ⊆ count (LENGTH (SND cs)))
       ⇒
       LENGTH (SND cs) ≤ LENGTH (SND (FST res)) ∧
       every_result (λv. all_locs v ⊆ count (LENGTH (SND (FST res)))) (λv. all_locs v ⊆ count (LENGTH (SND (FST res)))) (SND res) ∧
       (∀v. MEM v (SND (FST res)) ⇒ all_locs v ⊆ count (LENGTH (SND (FST res)))))``,
  ho_match_mp_tac evaluate_ind >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> strip_tac >>
    fs[LibTheory.bind_def] >>
    strip_tac >>
    last_x_assum mp_tac >>
    discharge_hyps >- metis_tac[] >> strip_tac >>
    qpat_assum`P ⇒ Q`mp_tac >>
    discharge_hyps >- (
      rw[] >> rw[all_locs_def] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
    strip_tac >>
    fsrw_tac[DNF_ss,ARITH_ss][SUBSET_DEF] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> strip_tac >>
    fsrw_tac[ETA_ss,DNF_ss][SUBSET_DEF,EVERY_MEM] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
  strip_tac >- rw[] >>
  strip_tac >- ( rw[] >> fs[] >> Cases_on`err`>>fs[]>> metis_tac[]) >>
  strip_tac >- (
    rw[lookup_var_id_def] >>
    BasicProvers.EVERY_CASE_TAC >> fs[] >>
    imp_res_tac alistTheory.ALOOKUP_MEM >>
    fsrw_tac[DNF_ss][MEM_MAP,EXISTS_PROD,MEM_FLAT] >>
    metis_tac[]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[] >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[] ) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    tac0 >>
    qspecl_then[`s2`,`uop`,`v`,`s3`,`v'`]mp_tac do_uapp_locs >>
    simp[]) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    tac0 >> simp[]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    last_x_assum mp_tac >> discharge_hyps >- tac1 >> strip_tac >>
    last_x_assum mp_tac >> discharge_hyps >- tac1 >> strip_tac >>
    qspecl_then[`s3`,`env`,`op`,`v1`,`v2`,`s4`,`env'`,`e''`]mp_tac do_app_locs >>
    discharge_hyps >- tac1 >> strip_tac >>
    tac0 >> simp[]) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    last_x_assum mp_tac >> discharge_hyps >- tac1 >> strip_tac >>
    last_x_assum mp_tac >> discharge_hyps >- tac1 >> strip_tac >>
    qspecl_then[`s3`,`env`,`op`,`v1`,`v2`,`s4`,`env'`,`e3`]mp_tac do_app_locs >>
    discharge_hyps >- tac1 >> strip_tac >>
    simp[]) >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[] >>
    tac0 >> tac0 >> simp[]) >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- tac >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- tac >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >>
    fs[LibTheory.bind_def,build_rec_env_MAP,MAP_FST_funs] >>
    qpat_assum`P ⇒ Q`mp_tac >>
    discharge_hyps >- (
      rw[] >> rw[all_locs_def] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,MEM_MAP,UNCURRY] >>
      metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
    strip_tac >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- tac >>
  strip_tac >- ( rw[] >> Cases_on`err`>>fs[]>> metis_tac[]) >>
  strip_tac >- tac >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rpt gen_tac >> ntac 2 strip_tac >> fs[LibTheory.bind_def] >>
    qpat_assum`P ⇒ Q`mp_tac >>
    discharge_hyps >- (
      rw[] >> rw[all_locs_def] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      qspecl_then[`cenv`,`s`,`p`,`w`,`env`,`env'`]mp_tac(CONJUNCT1 pmatch_locs)>>
      discharge_hyps >- (
        fsrw_tac[DNF_ss][SUBSET_DEF] >>
        metis_tac[] ) >>
      simp[SUBSET_DEF] >>
      metis_tac[]) >>
    strip_tac >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS,arithmeticTheory.LESS_EQ_TRANS] ) >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- rw[])

(* check_dup_ctors *)

val check_dup_ctors_ALL_DISTINCT = store_thm("check_dup_ctors_ALL_DISTINCT",
  ``check_dup_ctors menv cenv tds ⇒ ALL_DISTINCT (MAP FST (FLAT (MAP (SND o SND) tds)))``,
  simp[SemanticPrimitivesTheory.check_dup_ctors_def] >>
  rw[] >>
  qmatch_assum_abbrev_tac`ALL_DISTINCT l1` >>
  qmatch_abbrev_tac`ALL_DISTINCT l2` >>
  qsuff_tac`l1 = l2`>- PROVE_TAC[] >>
  unabbrev_all_tac >>
  rpt (pop_assum kall_tac) >>
  Induct_on`tds` >> simp[FORALL_PROD] >>
  Induct >> simp[FORALL_PROD])

val check_dup_ctors_NOT_MEM = store_thm("check_dup_ctors_NOT_MEM",
  ``check_dup_ctors mn cenv tds ∧ MEM e (MAP FST (FLAT (MAP (SND o SND) tds))) ⇒ ¬MEM (mk_id mn e) (MAP FST cenv)``,
  simp[SemanticPrimitivesTheory.check_dup_ctors_def] >>
  strip_tac >>
  qpat_assum`ALL_DISTINCT X`kall_tac >>
  Induct_on`tds` >> simp[] >>
  fs[FORALL_PROD,res_quanTheory.RES_FORALL] >>
  rw[] >- (
    fsrw_tac[DNF_ss][MEM_MAP] >>
    qmatch_assum_rename_tac`MEM a b`[] >>
    PairCases_on`a`>>fs[] >>
    res_tac >>
    imp_res_tac ALOOKUP_FAILS >>
    simp[FORALL_PROD] >>
    metis_tac[] ) >>
  first_x_assum (match_mp_tac o MP_CANON) >>
  simp[] >> metis_tac[])

(* closed *)

val (closed_rules,closed_ind,closed_cases) = Hol_reln`
(closed (menv:envM) (Litv l)) ∧
(EVERY (closed menv) vs ⇒ closed menv (Conv cn vs)) ∧
(EVERY (closed menv) (MAP SND env) ∧
 FV b ⊆ set (MAP (Short o FST) env) ∪ {Short x} ∪ menv_dom menv
⇒ closed menv (Closure env x b)) ∧
(EVERY (closed menv) (MAP SND env) ∧
 ALL_DISTINCT (MAP FST defs) ∧
 MEM d (MAP FST defs) ∧
 (∀d x b. MEM (d,x,b) defs ⇒
          FV b ⊆ set (MAP (Short o FST) env) ∪ set (MAP (Short o FST) defs) ∪ {Short x} ∪ menv_dom menv)
⇒ closed menv (Recclosure env defs d)) ∧
(closed menv (Loc n))`;

val closed_lit = save_thm(
"closed_lit",
SIMP_RULE(srw_ss())[]
(Q.SPECL[`menv`,`Litv l`]closed_cases))
val _ = export_rewrites["closed_lit"]

val closed_conv = save_thm(
"closed_conv",
SIMP_RULE(srw_ss())[]
(Q.SPECL[`menv`,`Conv cn vs`]closed_cases))
val _ = export_rewrites["closed_conv"]

val closed_loc = save_thm("closed_loc",
SIMP_RULE(srw_ss())[]
(Q.SPECL[`menv`,`Loc n`]closed_cases))
val _ = export_rewrites["closed_loc"]

val closed_strongind=theorem"closed_strongind"

val build_rec_env_closed = store_thm(
"build_rec_env_closed",
``∀menv defs env l.
  EVERY (closed menv) (MAP SND l) ∧
  EVERY (closed menv) (MAP SND env) ∧
  ALL_DISTINCT (MAP FST defs) ∧
  (∀d x b. MEM (d,x,b) defs ⇒
   FV b ⊆ set (MAP (Short o FST) env) ∪ set (MAP (Short o FST) defs) ∪ {Short x} ∪ menv_dom menv)
  ⇒ EVERY (closed menv) (MAP SND (build_rec_env defs env l))``,
rw[build_rec_env_def,bind_def,FOLDR_CONS_triple] >>
rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
asm_simp_tac(srw_ss())[EVERY_MEM,MEM_MAP,pairTheory.EXISTS_PROD] >>
rw[Once closed_cases] >- (
  rw[MEM_MAP,pairTheory.EXISTS_PROD] >>
  PROVE_TAC[]) >>
first_x_assum match_mp_tac >>
PROVE_TAC[])

val do_app_closed = store_thm(
"do_app_closed",
``∀menv s s' env op v1 v2 env' exp.
  EVERY (closed menv) (MAP SND env) ∧
  closed menv v1 ∧ closed menv v2 ∧
  EVERY (closed menv) s ∧
  (do_app s env op v1 v2 = SOME (s',env',exp))
  ⇒ EVERY (closed menv) (MAP SND env') ∧
    FV exp ⊆ set (MAP (Short o FST) env') ∪ menv_dom menv ∧
    EVERY (closed menv) s'``,
ntac 4 gen_tac >> Cases
>- (
  Cases >> TRY (Cases_on `l`) >>
  Cases >> TRY (Cases_on `l`) >>
  rw[do_app_def] >>
  fs[closed_cases])
>- (
  Cases >> TRY (Cases_on `l`) >>
  Cases >> TRY (Cases_on `l`) >>
  rw[do_app_def] >>
  fs[closed_cases])
>- (
  fs [bigClockTheory.do_app_cases] >>
  rw [] >>
  fs [])
>- (
  Cases >> Cases >> rw[do_app_def,bind_def] >> fs[closed_cases] >>
  fs[] >> rw[] >>
  TRY (rw[Once INSERT_SING_UNION] >> PROVE_TAC[UNION_COMM,UNION_ASSOC]) >>
  pop_assum mp_tac >>
  BasicProvers.CASE_TAC >>
  strip_tac >> fs[] >>
  qmatch_assum_rename_tac `ALOOKUP defs dd = SOME pp`[] >>
  PairCases_on `pp` >> fs[] >> rw[] >> rw[Once closed_cases] >>
  fs[] >> rw[] >> rw[Once closed_cases] >>
  TRY (qmatch_abbrev_tac `EVERY (closed menv) X` >>
       metis_tac[build_rec_env_closed]) >>
  imp_res_tac ALOOKUP_MEM >>
  fsrw_tac[DNF_ss][SUBSET_DEF,GSYM MAP_MAP_o] >>
  PROVE_TAC[])
>- (
  Cases >> Cases >> rw[do_app_def] >>
  pop_assum mp_tac >> BasicProvers.CASE_TAC >>
  rw[] >> fs[] >>
  fsrw_tac[DNF_ss][EVERY_MEM,MEM_MAP,FORALL_PROD] >>
  rw[] >>
  fs[store_assign_def] >> rw[] >>
  PROVE_TAC[MEM_LUPDATE,closed_lit,closed_conv,EVERY_MEM,closed_loc]));

val pmatch_closed = store_thm("pmatch_closed",
  ``(∀^cenv s p v env env' (menv:envM).
      EVERY (closed menv) (MAP SND env) ∧ closed menv v ∧
      EVERY (closed menv) s ∧
      (pmatch cenv s p v env = Match env') ⇒
      EVERY (closed menv) (MAP SND env') ∧
      (MAP FST env' = pat_bindings p [] ++ (MAP FST env))) ∧
    (∀^cenv s ps vs env env' (menv:envM).
      EVERY (closed menv) (MAP SND env) ∧ EVERY (closed menv) vs ∧
      EVERY (closed menv) s ∧
      (pmatch_list cenv s ps vs env = Match env') ⇒
      EVERY (closed menv) (MAP SND env') ∧
      (MAP FST env' = pats_bindings ps [] ++ MAP FST env))``,
    pmatch_tac)

val do_uapp_closed = store_thm("do_uapp_closed",
  ``∀s uop v s' v' menv.
    EVERY (closed menv) s ∧ (closed menv) v ∧
    (do_uapp s uop v = SOME (s',v')) ⇒
    EVERY (closed menv) s' ∧ closed menv v'``,
  gen_tac >> Cases >>
  rw[do_uapp_def,LET_THM,store_alloc_def] >>
  rw[EVERY_APPEND] >>
  Cases_on`v`>>fs[store_lookup_def]>>
  pop_assum mp_tac >> rw[] >> rw[]>>
  fsrw_tac[DNF_ss][EVERY_MEM,MEM_EL])

val evaluate_closed = store_thm(
"evaluate_closed",
``(∀ck menv ^cenv s env exp res.
   evaluate ck menv cenv s env exp res ⇒
   FV exp ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
   EVERY (EVERY (closed menv) o MAP SND) (MAP SND menv) ∧
   EVERY (closed menv) (MAP SND env) ∧
   EVERY (closed menv) (SND s)
   ⇒
   EVERY (closed menv) (SND (FST res)) ∧
   every_result (closed menv) (closed menv) (SND res)) ∧
  (∀ck menv ^cenv s env exps ress.
   evaluate_list ck menv cenv s env exps ress ⇒
   FV_list exps ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
   EVERY (EVERY (closed menv) o MAP SND) (MAP SND menv) ∧
   EVERY (closed menv) (MAP SND env) ∧
   EVERY (closed menv) (SND s)
   ⇒
   EVERY (closed menv) (SND (FST ress)) ∧
   every_result (EVERY (closed menv)) (closed menv) (SND ress)) ∧
  (∀ck menv ^cenv s env v pes errv res.
   evaluate_match ck menv cenv s env v pes errv res ⇒
   FV_pes pes ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
   EVERY (EVERY (closed menv) o MAP SND) (MAP SND menv) ∧
   EVERY (closed menv) (MAP SND env) ∧
   EVERY (closed menv) (SND s) ∧ closed menv v ∧ closed menv errv
   ⇒
   EVERY (closed menv) (SND (FST res)) ∧
   every_result (closed menv) (closed menv) (SND res))``,
ho_match_mp_tac evaluate_ind >>
strip_tac (* Lit *) >- rw[] >>
strip_tac (* Raise *) >- rw[] >>
strip_tac (* Handle *) >- (rw[] >> fsrw_tac[DNF_ss][SUBSET_DEF]) >>
strip_tac (* Handle *) >- (
  rw[] >> fs[] >> rfs[] >>
  fsrw_tac[DNF_ss][SUBSET_DEF,bind_def,MEM_MAP,EXISTS_PROD] >>
  PROVE_TAC[] ) >>
strip_tac (* Handle *) >- (rw[] >> fsrw_tac[DNF_ss][SUBSET_DEF]) >>
strip_tac (* Handle *) >- (rw[] >> fsrw_tac[DNF_ss][SUBSET_DEF]) >>
strip_tac (* Con *) >- ( rw[] >> fsrw_tac[ETA_ss,DNF_ss][SUBSET_DEF] ) >>
strip_tac (* Con *) >- rw[] >>
strip_tac (* Con *) >- ( rw[] >> Cases_on`err` >> fsrw_tac[ETA_ss,DNF_ss][SUBSET_DEF] ) >>
strip_tac (* Var *) >- (
  ntac 4 gen_tac >>
  Cases >> rw[lookup_var_id_def,MEM_FLAT,MEM_MAP] >>
  TRY (fsrw_tac[DNF_ss][MEM_MAP]>>NO_TAC) >>
  TRY (
    imp_res_tac ALOOKUP_MEM >>
    fs[EVERY_MEM,MEM_MAP,EXISTS_PROD] >>
    PROVE_TAC[]) >>
  BasicProvers.EVERY_CASE_TAC >>
  fsrw_tac[DNF_ss][MEM_MAP] >>
  imp_res_tac ALOOKUP_MEM >>
  fs[EVERY_MEM,MEM_MAP,EXISTS_PROD] >>
  PROVE_TAC[]) >>
strip_tac (* Var *) >- rw[] >>
strip_tac (* Fun *) >- (
  rw[] >>
  rw[Once closed_cases] >>
  fsrw_tac[DNF_ss][SUBSET_DEF] >>
  PROVE_TAC[]) >>
strip_tac (* Uapp *) >- (
  rpt gen_tac >> strip_tac >> strip_tac >> fs[] >>
  PROVE_TAC[do_uapp_closed] ) >>
strip_tac (* Uapp *) >- rw[] >>
strip_tac (* Uapp *) >- rw[] >>
strip_tac (* App *) >- (
  rpt gen_tac >> ntac 2 strip_tac >> fs[] >> rfs[] >>
  PROVE_TAC[do_app_closed]) >>
strip_tac (* App *) >- (
  rw[] >> fs[] >> rfs[] >>
  PROVE_TAC[do_app_closed] ) >>
strip_tac (* App *) >- rw[] >>
strip_tac (* App *) >- rw[] >>
strip_tac (* Log *) >- (
  rw[] >> fs[] >>
  PROVE_TAC[do_log_FV,SUBSET_TRANS]) >>
strip_tac (* Log *) >- (
  rw[] >> fs[] >> rfs[] >>
  PROVE_TAC[do_log_FV,SUBSET_TRANS] ) >>
strip_tac (* Log *) >- rw[] >>
strip_tac (* If *) >- (
  rw[] >> fs[] >>
  PROVE_TAC[do_if_FV,SUBSET_DEF,IN_UNION]) >>
strip_tac (* If *) >- (
  rw[] >> fs[] >> rfs[] >>
  PROVE_TAC[do_if_FV,UNION_SUBSET,SUBSET_TRANS] ) >>
strip_tac (* If *) >- rw[] >>
strip_tac (* Mat *) >- rw[] >>
strip_tac (* Mat *) >- rw[] >>
strip_tac (* Let *) >- (
  rpt gen_tac >> ntac 2 strip_tac >>
  fs[] >> rfs[bind_def] >>
  fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD] >>
  PROVE_TAC[] ) >>
strip_tac (* Let *) >- (
  rpt gen_tac >> strip_tac >>
  simp[] >> strip_tac >> fs[] >>
  first_x_assum match_mp_tac >>
  fsrw_tac[DNF_ss][SUBSET_DEF,bind_def] >>
  metis_tac[] ) >>
strip_tac (* Let *) >- rw[] >>
strip_tac (* Letrec *) >- (
  rpt gen_tac >> ntac 2 strip_tac >>
  first_x_assum match_mp_tac >>
  fs[FST_triple] >> rfs[] >>
  conj_tac >- (
    fs[GSYM MAP_MAP_o,LET_THM,FV_defs_MAP] >>
    fsrw_tac[DNF_ss][SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD,MEM_FLAT] >>
    gen_tac >> strip_tac >> res_tac >>
    Cases_on`x`>>fs[] >>
    PROVE_TAC[] ) >>
  match_mp_tac build_rec_env_closed >> fs[] >>
  fsrw_tac[DNF_ss][SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD,MEM_FLAT,LET_THM,FV_defs_MAP] >>
  metis_tac[]) >>
strip_tac (* Letrec *) >- rw[] >>
strip_tac (* [] *) >- rw[] >>
strip_tac (* :: *) >- rw[] >>
strip_tac (* :: *) >- (rw[] >> Cases_on`err`>>fs[]) >>
strip_tac (* :: *) >- rw[] >>
strip_tac (* [] *) >- rw[] >>
strip_tac (* Match *) >- (
  rpt gen_tac >> ntac 2 strip_tac >>
  fs[] >> rfs[] >>
  first_x_assum match_mp_tac >>
  qspecl_then[`cenv`,`s`,`p`,`v`,`env`,`env'`,`menv`]mp_tac(CONJUNCT1 pmatch_closed) >>
  simp[] >>
  fs[GSYM MAP_MAP_o] >> strip_tac >>
  fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,MEM_MAP,FV_pes_MAP,MEM_FLAT] >>
  metis_tac[]) >>
strip_tac (* Match *) >- rw[] >>
strip_tac (* Match *) >- rw[] >>
rw[])

val closed_under_cenv_def = Define`
  closed_under_cenv cenv (menv:envM) env s =
  (∀v. v ∈ menv_range menv ∨ v ∈ env_range env ∨ MEM v s ⇒ all_cns v ⊆ cenv_dom cenv)`

val closed_under_menv_def = Define`
  closed_under_menv menv env s ⇔
    EVERY (closed menv) s ∧
    EVERY (closed menv) (MAP SND env) ∧
    EVERY (EVERY (closed menv) o MAP SND) (MAP SND menv)`

val closed_context_def = Define`
  closed_context menv cenv s env ⇔
    ALL_DISTINCT (MAP FST menv) ∧
    EVERY (closed menv) s ∧
    EVERY (closed menv) (MAP SND env) ∧
    EVERY (EVERY (closed menv) o MAP SND) (MAP SND menv) ∧
    closed_under_cenv cenv menv env s ∧
    closed_under_menv menv env s ∧
    (∀v. v ∈ menv_range menv ∨ v ∈ env_range env ∨ MEM v s ⇒ all_locs v ⊆ count (LENGTH s))`

val closed_context_append = store_thm("closed_context_append",
  ``∀menv cenv s env cenv' env'.
    closed_context menv cenv s env  ∧
    EVERY (closed menv) (MAP SND env') ∧
    (∀v. MEM v (MAP SND env') ⇒ all_cns v ⊆ cenv_dom (cenv' ++ cenv)) ∧
    (∀v. MEM v (MAP SND env') ⇒ all_locs v ⊆ count (LENGTH s))
    ⇒
    closed_context menv (cenv' ++ cenv) s (env' ++ env)``,
  rpt gen_tac >>
  simp[closed_context_def] >> strip_tac >>
  fs[closed_under_cenv_def,closed_under_menv_def] >>
  conj_tac >- (
    `cenv_dom cenv ⊆ cenv_dom (cenv' ++ cenv)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF, cenv_dom_def] ) >>
    metis_tac[SUBSET_TRANS] ) >>
  metis_tac[])

val evaluate_closed_under_cenv = store_thm("evaluate_closed_under_cenv",
  ``∀ck menv cenv s env exp res.
    closed_under_cenv cenv menv env (SND s) ∧
    evaluate ck menv cenv s env exp res ∧
    all_cns_exp exp ⊆ cenv_dom cenv ∧
    cenv_bind_div_eq cenv
    ⇒
    closed_under_cenv cenv menv env (SND (FST res)) ∧
    every_result (λv. all_cns v ⊆ cenv_dom cenv) (λv. all_cns v ⊆ cenv_dom cenv) (SND res)``,
  rw[] >>
  qspecl_then[`ck`,`menv`,`cenv`,`s`,`env`,`exp`,`res`]mp_tac (CONJUNCT1 evaluate_all_cns) >>
  fsrw_tac[DNF_ss][closed_under_cenv_def])

val closed_context_extend_cenv = store_thm("closed_context_extend_cenv",
  ``∀menv cenv s env cenv'.
      closed_context menv cenv s env ⇒
      closed_context menv (cenv'++cenv) s env``,
  rw[closed_context_def] >> fs[] >>
  fs[closed_under_cenv_def] >>
  fsrw_tac[DNF_ss][cenv_dom_def, SUBSET_DEF] >>
  metis_tac[]);

val closed_top_def = Define`
  closed_top menv cenv s env top ⇔
    closed_context menv cenv s env ∧
    FV_top top ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
    top_cns top ⊆ cenv_dom cenv`

val evaluate_dec_closed_context = store_thm("evaluate_dec_closed_context",
  ``∀mn menv cenv s env d s' res. evaluate_dec mn menv cenv s env d (s',res) ∧
    closed_context menv cenv s env ∧
    FV_dec d ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
    dec_cns d ⊆ cenv_dom cenv ∧
    cenv_bind_div_eq cenv
    ⇒
    let (cenv',env',ls) = case res of Rval(c,e)=>(c++cenv,e++env,[]) | Rerr(Rraise v) => (cenv,env,[v]) | _ => (cenv,env,[]) in
    closed_context menv cenv' s' env' ∧
    EVERY (closed menv) ls``,
  rpt gen_tac >>
  Cases_on`d`>>simp[Once evaluate_dec_cases]>>
  Cases_on`res`>>simp[]>>strip_tac>>rpt BasicProvers.VAR_EQ_TAC>>simp[LibTheory.emp_def]>>TRY(strip_tac)>>
  TRY (
    TRY(BasicProvers.CASE_TAC >> fs[])>>(
    fs[closed_context_def] >>
    qmatch_assum_abbrev_tac`evaluate ck menv cenv s0 env e res` >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac(CONJUNCT1 evaluate_closed) >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac evaluate_closed_under_cenv >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac (CONJUNCT1 evaluate_locs) >>
    UNABBREV_ALL_TAC >> simp[] >> ntac 3 strip_tac >>
    qpat_assum`P ⇒ Q`mp_tac >>
    discharge_hyps >- metis_tac[] >> strip_tac >>
    conj_tac >- fs[closed_under_menv_def] >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS]))
  >- (
    fs[closed_context_def] >>
    qmatch_assum_abbrev_tac`evaluate ck menv cenv s0 env e res` >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac(CONJUNCT1 evaluate_closed) >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac evaluate_closed_under_cenv >>
    Q.ISPECL_THEN[`ck`,`menv`,`cenv`,`s0`,`env`,`e`,`res`]mp_tac (CONJUNCT1 evaluate_locs) >>
    UNABBREV_ALL_TAC >> simp[] >> ntac 3 strip_tac >>
    qpat_assum`P ⇒ Q`mp_tac >>
    discharge_hyps >- metis_tac[] >> strip_tac >>
    qspecl_then[`cenv`,`s'`,`p`,`v`,`emp`]mp_tac(INST_TYPE[alpha|->``:tid_or_exn``](CONJUNCT1 pmatch_closed)) >>
    simp[] >> disch_then(qspec_then`menv`mp_tac) >>
    simp[LibTheory.emp_def] >> strip_tac >>
    conj_tac >- (
      fs[closed_under_cenv_def] >>
      qx_gen_tac`z` >> strip_tac >> TRY(metis_tac[]) >>
      imp_res_tac (CONJUNCT1 pmatch_all_cns) >>
      fsrw_tac[DNF_ss][SUBSET_DEF,LibTheory.emp_def] >>
      metis_tac[] ) >>
    conj_tac >- fs[closed_under_menv_def] >>
    fsrw_tac[DNF_ss][SUBSET_DEF] >>
    conj_tac >- metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS] >>
    conj_tac >- (
      qspecl_then[`cenv`,`s'`,`p`,`v`,`emp`,`env'`]mp_tac(INST_TYPE[alpha|->``:tid_or_exn``](CONJUNCT1 pmatch_locs)) >>
      discharge_hyps >- (
        simp[] >>
        fsrw_tac[DNF_ss][LibTheory.emp_def,SUBSET_DEF] >>
        metis_tac[] ) >>
      simp[SUBSET_DEF] >>
      metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS]) >>
    metis_tac[arithmeticTheory.LESS_LESS_EQ_TRANS])
  >- (
    simp[build_rec_env_MAP] >>
    fs[closed_context_def,miscTheory.MAP_FST_funs] >>
    simp[EVERY_MAP,UNCURRY] >>
    conj_tac >- (
      simp[Once closed_cases] >>
      simp[EVERY_MEM,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
      fs[] >> rpt gen_tac >> strip_tac >> conj_tac >- metis_tac[] >>
      fs[FV_defs_MAP] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD] >>
      metis_tac[] ) >>
    conj_tac >- (
      fs[closed_under_cenv_def] >>
      qx_gen_tac`z` >> strip_tac >> TRY(metis_tac[]) >>
      pop_assum mp_tac >>
      simp[MEM_MAP,EXISTS_PROD] >> strip_tac >>
      simp[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[] ) >>
    conj_tac >- (
      fs[closed_under_menv_def,EVERY_MAP,UNCURRY] >>
      simp[Once closed_cases] >>
      fs[EVERY_MEM] >>
      fs[FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
      rpt gen_tac >> strip_tac >> conj_tac >- metis_tac[] >>
      fs[FV_defs_MAP] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD] >>
      metis_tac[] ) >>
    gen_tac >> strip_tac >> TRY(metis_tac[]) >>
    fs[MEM_MAP,UNCURRY] >>
    fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,MEM_MAP] >>
    metis_tac[] )
  >> (
    simp[SemanticPrimitivesTheory.build_tdefs_def] >>
    Cases_on`mn`>>fs[AstTheory.mk_id_def] >- (
      fs[closed_context_def] >>
      fs[closed_under_cenv_def] >>
      reverse conj_tac >- metis_tac[] >>
      fs[MAP_FLAT,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      fs [cenv_dom_def] >>
      metis_tac[] ) >>
    fs[closed_context_def] >>
    conj_tac >- (
      fs[closed_under_cenv_def] >>
      simp[MAP_FLAT,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
      fsrw_tac[DNF_ss][MEM_MAP,SUBSET_DEF] >>
      fs [cenv_dom_def] >>
      metis_tac[] ) >>
    metis_tac[] ))

val evaluate_decs_closed_context = store_thm("evaluate_decs_closed_context",
  ``∀mn menv cenv s env ds res. evaluate_decs mn menv cenv s env ds res ⇒
      closed_context menv cenv s env ∧
      FV_decs ds ⊆ set (MAP (Short o FST) env) ∪ menv_dom menv ∧
      decs_cns mn ds ⊆ cenv_dom cenv ∧
      cenv_bind_div_eq cenv
    ⇒
      let (env',ls) = case SND(SND res) of Rval(e)=>(e++env,[]) | Rerr(Rraise v) => (env,[v]) | _ => (env,[]) in
      closed_context menv ((FST(SND res))++cenv) (FST res) env' ∧ EVERY (closed menv) ls``,
  ho_match_mp_tac evaluate_decs_ind >>
  simp[LibTheory.emp_def] >>
  conj_tac >- (
    rpt gen_tac >> rpt strip_tac >>
    BasicProvers.CASE_TAC >>
    fs[FV_decs_def,decs_cns_def] >>
    imp_res_tac evaluate_dec_closed_context >>
    fs[] >> fs[LET_THM] ) >>
  simp[SemanticPrimitivesTheory.combine_dec_result_def,LibTheory.merge_def] >>
  rpt gen_tac >> rpt strip_tac >>
  qspecl_then[`mn`,`menv`,`cenv`,`s`,`env`,`d`,`s'`,`Rval (new_tds,new_env)`]mp_tac evaluate_dec_closed_context >>
  simp[] >> strip_tac >>
  Cases_on`r`>>fs[]>- (
    first_x_assum match_mp_tac >>
    simp[CONJ_ASSOC] >>
    reverse conj_tac >- (
      match_mp_tac cenv_bind_div_eq_append >>
      Cases_on`d`>>fs[evaluate_dec_cases,LibTheory.emp_def,LibTheory.bind_def] >>
      imp_res_tac check_dup_ctors_NOT_MEM >>
      imp_res_tac ALOOKUP_NONE >>
      simp[IN_DISJOINT,build_tdefs_def] >>
      fsrw_tac[DNF_ss][MEM_MAP,MEM_FLAT,FORALL_PROD] >>
      spose_not_then strip_assume_tac >> rw[] >>
      metis_tac[] ) >>
    fsrw_tac[DNF_ss][SUBSET_DEF,FV_decs_def,decs_cns_def] >>
    imp_res_tac evaluate_dec_new_dec_cns >> fs[] >>
    pop_assum(assume_tac o AP_TERM``LIST_TO_SET:string id list -> string id set``) >>
    imp_res_tac evaluate_dec_new_dec_vs >> fs[] >>
    pop_assum(assume_tac o AP_TERM``LIST_TO_SET:string list -> string set``) >>
    fsrw_tac[DNF_ss][MEM_MAP,EXTENSION, cenv_dom_def] >>
    metis_tac[]) >>
  qpat_assum`P ⇒ Q`mp_tac>>
  discharge_hyps>-(
    fsrw_tac[DNF_ss][SUBSET_DEF,FV_decs_def,decs_cns_def] >>
    metis_tac[]) >>
  strip_tac >>
  qho_match_abbrev_tac`P env` >>
  qsuff_tac`P (new_env ++ env)` >- (
    simp[Abbr`P`] >>
    rw[closed_context_def] >> fs[] >>
    fs[closed_under_cenv_def,closed_under_menv_def] >>
    BasicProvers.CASE_TAC >> fs[] >>
    metis_tac[] ) >>
  simp[Abbr`P`] >>
  first_x_assum match_mp_tac >>
  fs[] >>
  simp[CONJ_ASSOC] >>
  reverse conj_tac >- (
    match_mp_tac cenv_bind_div_eq_append >>
    Cases_on`d`>>fs[evaluate_dec_cases,LibTheory.emp_def,LibTheory.bind_def] >>
    imp_res_tac check_dup_ctors_NOT_MEM >>
    imp_res_tac ALOOKUP_NONE >>
    simp[IN_DISJOINT,build_tdefs_def] >>
    fsrw_tac[DNF_ss][MEM_MAP,MEM_FLAT,FORALL_PROD] >>
    spose_not_then strip_assume_tac >> rw[] >>
    metis_tac[] ) >>
  fsrw_tac[DNF_ss][SUBSET_DEF,FV_decs_def,decs_cns_def] >>
  imp_res_tac evaluate_dec_new_dec_cns >> fs[] >>
  pop_assum(assume_tac o AP_TERM``LIST_TO_SET:string id list -> string id set``) >>
  imp_res_tac evaluate_dec_new_dec_vs >> fs[] >>
  pop_assum(assume_tac o AP_TERM``LIST_TO_SET:string list -> string set``) >>
  fsrw_tac[DNF_ss][cenv_dom_def,MEM_MAP,EXTENSION] >>
  metis_tac[]);

(* result_rel *)

val exc_rel_def = Define`
  (exc_rel R (Rraise v1) (Rraise v2) = R v1 v2) ∧
  (exc_rel _ Rtype_error Rtype_error = T) ∧
  (exc_rel _ Rtimeout_error Rtimeout_error = T) ∧
  (exc_rel _ _ _ = F)`
val _ = export_rewrites["exc_rel_def"]

val exc_rel_raise1 = store_thm("exc_rel_raise1",
  ``exc_rel R (Rraise v) e = ∃v'. (e = Rraise v') ∧ R v v'``,
  Cases_on`e`>>rw[])
val exc_rel_raise2 = store_thm("exc_rel_raise2",
  ``exc_rel R e (Rraise v) = ∃v'. (e = Rraise v') ∧ R v' v``,
  Cases_on`e`>>rw[])
val exc_rel_type_error = store_thm("exc_rel_type_error",
  ``(exc_rel R Rtype_error e = (e = Rtype_error)) ∧
    (exc_rel R e Rtype_error = (e = Rtype_error))``,
  Cases_on`e`>>rw[])
val exc_rel_timeout_error = store_thm("exc_rel_timeout_error",
  ``(exc_rel R Rtimeout_error e = (e = Rtimeout_error)) ∧
    (exc_rel R e Rtimeout_error = (e = Rtimeout_error))``,
  Cases_on`e`>>rw[])
val _ = export_rewrites["exc_rel_raise1","exc_rel_raise2","exc_rel_type_error","exc_rel_timeout_error"]

val result_rel_def = Define`
(result_rel R1 _ (Rval v1) (Rval v2) = R1 v1 v2) ∧
(result_rel _ R2 (Rerr e1) (Rerr e2) = exc_rel R2 e1 e2) ∧
(result_rel _ _ _ _ = F)`
val _ = export_rewrites["result_rel_def"]

val result_rel_Rval = store_thm(
"result_rel_Rval",
``result_rel R1 R2 (Rval v) r = ∃v'. (r = Rval v') ∧ R1 v v'``,
Cases_on `r` >> rw[])
val result_rel_Rerr1 = store_thm(
"result_rel_Rerr1",
``result_rel R1 R2 (Rerr e) r = ∃e'. (r = Rerr e') ∧ exc_rel R2 e e'``,
Cases_on `r` >> rw[EQ_IMP_THM])
val result_rel_Rerr2 = store_thm(
"result_rel_Rerr2",
``result_rel R1 R2 r (Rerr e) = ∃e'. (r = Rerr e') ∧ exc_rel R2 e' e``,
Cases_on `r` >> rw[EQ_IMP_THM])
val _ = export_rewrites["result_rel_Rval","result_rel_Rerr1","result_rel_Rerr2"]

val exc_rel_refl = store_thm(
"exc_rel_refl",
  ``(∀x. R x x) ⇒ ∀x. exc_rel R x x``,
strip_tac >> Cases >> rw[])
val _ = export_rewrites["exc_rel_refl"];

val result_rel_refl = store_thm(
"result_rel_refl",
``(∀x. R1 x x) ∧ (∀x. R2 x x) ⇒ ∀x. result_rel R1 R2 x x``,
strip_tac >> Cases >> rw[])
val _ = export_rewrites["result_rel_refl"]

val exc_rel_trans = store_thm(
"exc_rel_trans",
``(∀x y z. R x y ∧ R y z ⇒ R x z) ⇒ (∀x y z. exc_rel R x y ∧ exc_rel R y z ⇒ exc_rel R x z)``,
rw[] >>
Cases_on `x` >> fs[] >> rw[] >> fs[] >> PROVE_TAC[])

val result_rel_trans = store_thm(
"result_rel_trans",
``(∀x y z. R1 x y ∧ R1 y z ⇒ R1 x z) ∧ (∀x y z. R2 x y ∧ R2 y z ⇒ R2 x z) ⇒ (∀x y z. result_rel R1 R2 x y ∧ result_rel R1 R2 y z ⇒ result_rel R1 R2 x z)``,
rw[] >>
Cases_on `x` >> fs[] >> rw[] >> fs[] >> PROVE_TAC[exc_rel_trans])

val exc_rel_sym = store_thm(
"exc_rel_sym",
``(∀x y. R x y ⇒ R y x) ⇒ (∀x y. exc_rel R x y ⇒ exc_rel R y x)``,
rw[] >> Cases_on `x` >> fs[])

val result_rel_sym = store_thm(
"result_rel_sym",
``(∀x y. R1 x y ⇒ R1 y x) ∧ (∀x y. R2 x y ⇒ R2 y x) ⇒ (∀x y. result_rel R1 R2 x y ⇒ result_rel R1 R2 y x)``,
rw[] >> Cases_on `x` >> fs[exc_rel_sym])

(* determinism *)

val evaluate_dec_determ = store_thm("evaluate_dec_determ",
  ``∀mn menv (cenv:envC) s env d r1.
    evaluate_dec mn menv cenv s env d r1 ⇒
    ∀r2. evaluate_dec mn menv cenv s env d r2 ⇒ r2 = r1``,
  ho_match_mp_tac evaluate_dec_ind >>
  rpt conj_tac >>
  rw[Once evaluate_dec_cases] >>
  imp_res_tac big_exp_determ >> fs[] )

val evaluate_decs_determ = store_thm("evaluate_decs_determ",
  ``∀mn menv cenv s env ds res.
    evaluate_decs mn menv cenv s env ds res ⇒
    ∀r2. evaluate_decs mn menv cenv s env ds r2 ⇒ r2 = res``,
  ho_match_mp_tac evaluate_decs_ind >>
  rpt conj_tac >>
  rpt gen_tac >> strip_tac >>
  rw[Once evaluate_decs_cases] >>
  imp_res_tac evaluate_dec_determ >> fs[] >>
  fs[LibTheory.merge_def,SemanticPrimitivesTheory.combine_dec_result_def] >>
  res_tac >> fs[])

(* evaluate functional equations *)

val evaluate_lit = Q.store_thm(
"evaluate_lit",
`!ck menv cenv s env l r.
  (evaluate ck menv cenv s env (Lit l) r = (r = (s,Rval (Litv l))))`,
rw [Once evaluate_cases]);

val evaluate_var = store_thm(
"evaluate_var",
``∀ck menv cenv s env n r. evaluate ck menv cenv s env (Var n) r =
  (∃v topt. (lookup_var_id n menv env = SOME v) ∧ (r = (s, Rval v))) ∨
  ((lookup_var_id n menv env = NONE) ∧ (r = (s, Rerr Rtype_error)))``,
rw [Once evaluate_cases] >>
metis_tac [])

val evaluate_fun = store_thm(
"evaluate_fun",
``∀ck menv cenv s env n e r.
  evaluate ck menv cenv s env (Fun n e) r = (r = (s, Rval (Closure env n e)))``,
rw [Once evaluate_cases])

val _ = export_rewrites["evaluate_lit","evaluate_fun"];

(*
val ALIST_REL_def = Define`
  ALIST_REL R a1 a2 = ∀x. OPTION_REL R (ALOOKUP a1 x) (ALOOKUP a2 x)`

val ALIST_REL_fmap_rel = store_thm("ALIST_REL_fmap_rel",
  ``ALIST_REL R a1 a2 = fmap_rel R (alist_to_fmap a1) (alist_to_fmap a2)``,
  rw[ALIST_REL_def,fmap_rel_def,EQ_IMP_THM] >- (
    fs[EXTENSION] >>
    rw[EQ_IMP_THM] >>
    first_x_assum(qspec_then`x`mp_tac) >>
    Cases_on`ALOOKUP a1 x`>>rw[optionTheory.OPTREL_def] >>
    imp_res_tac ALOOKUP_NONE >> fs[] >>
    imp_res_tac ALOOKUP_MEM >> rw[MEM_MAP,EXISTS_PROD] >>
    PROVE_TAC[])
  >- (
    first_x_assum(qspec_then`x`mp_tac) >>
    rw[optionTheory.OPTREL_def] >>
    imp_res_tac ALOOKUP_NONE >>
    imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
    rw[] )
  >- (
    rw[optionTheory.OPTREL_def] >>
    fs[EXTENSION] >>
    ntac 2 (pop_assum(qspec_then`x`mp_tac)) >>
    rw[] >>
    Cases_on`ALOOKUP a1 x`>>
    imp_res_tac ALOOKUP_NONE >> fs[]
      >- metis_tac[ALOOKUP_NONE] >>
    imp_res_tac ALOOKUP_MEM >>
    `MEM x (MAP FST a1)` by srw_tac[SATISFY_ss][MEM_MAP,EXISTS_PROD] >>
    Cases_on`ALOOKUP a2 x`>>
    imp_res_tac ALOOKUP_NONE >> fs[] >>
    imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
    rw[]))

val ALIST_REL_mono = store_thm("ALIST_REL_mono",
  ``(∀x y. R1 x y ⇒ R2 x y) ⇒ ALIST_REL R1 a1 a2 ⇒ ALIST_REL R2 a1 a2``,
  metis_tac[ALIST_REL_fmap_rel,fmap_rel_mono])
val _ = IndDefLib.export_mono"ALIST_REL_mono"

val ALIST_REL_CONS_SAME = store_thm("ALIST_REL_CONS_SAME",
  ``ALIST_REL R env1 env2 ∧ R v1 v2 ⇒ ALIST_REL R ((x,v1)::env1) ((x,v2)::env2)``,
  rw[ALIST_REL_def] >> rw[] >> rw[optionTheory.OPTREL_def])

val ALIST_REL_refl = store_thm("ALIST_REL_refl",
  ``(∀x. R x x) ⇒ ∀x. ALIST_REL R x x``,
  metis_tac[ALIST_REL_fmap_rel,fmap_rel_refl])

val ALIST_REL_trans = store_thm("ALIST_REL_trans",
  ``(∀x y z. R x y ∧ R y z ⇒ R x z) ⇒ ∀x y z. ALIST_REL R x y ∧ ALIST_REL R y z ⇒ ALIST_REL R x z``,
  PROVE_TAC[ALIST_REL_fmap_rel,fmap_rel_trans])

val ALIST_REL_APPEND = store_thm("ALIST_REL_APPEND",
  ``ALIST_REL R l1 l2 ∧ ALIST_REL R l3 l4 ⇒ ALIST_REL R (l1 ++ l3) (l2 ++ l4)``,
  rw[ALIST_REL_def,ALOOKUP_APPEND] >>
  fs[optionTheory.OPTREL_def] >>
  BasicProvers.CASE_TAC >> fs[] >>
  BasicProvers.CASE_TAC >> fs[] >>
  metis_tac[optionTheory.NOT_SOME_NONE,optionTheory.SOME_11])

val (enveq_rules,enveq_ind,enveq_cases) = Hol_reln`
  (enveq (Litv l) (Litv l)) ∧
  (EVERY2 enveq vs1 vs2 ⇒ enveq (Conv cn vs1) (Conv cn vs2)) ∧
  (ALIST_REL enveq env1 env2 ⇒ enveq (Closure env1 vn e) (Closure env2 vn e)) ∧
  (ALIST_REL enveq env1 env2 ⇒ enveq (Recclosure env1 defs vn) (Recclosure env2 defs vn)) ∧
  (enveq (Loc n) (Loc n))`

val enveq_refl = store_thm("enveq_refl",
  ``(∀v. enveq v v) ∧
    (∀(env:envE). ALIST_REL enveq env env) ∧
    (∀(p:string#v). enveq (SND p) (SND p)) ∧
    (∀vs. EVERY2 enveq vs vs)``,
  ho_match_mp_tac(TypeBase.induction_of``:v``)>>
  rw[enveq_cases] >- rw[ALIST_REL_fmap_rel] >>
  PairCases_on`p`>> fs[] >>
  match_mp_tac ALIST_REL_CONS_SAME >>
  rw[Once enveq_cases])
val _ = export_rewrites["enveq_refl"]

val enveq_trans = store_thm("enveq_trans",
  ``∀e1 e2. enveq e1 e2 ⇒ ∀e3. enveq e2 e3 ⇒ enveq e1 e3``,
  ho_match_mp_tac enveq_ind >> rw[] >- (
    rw[Once enveq_cases] >>
    pop_assum mp_tac >>
    rw[Once enveq_cases] >>
    fs[EVERY2_EVERY,EVERY_MEM,FORALL_PROD] >> rw[] >>
    rpt (qpat_assum`LENGTH X = Y`mp_tac) >>
    rpt strip_tac >> fs[MEM_ZIP] >>
    metis_tac[] )
  >- (
    pop_assum mp_tac >>
    rw[Once enveq_cases] >>
    rw[Once enveq_cases] >>
    fs[ALIST_REL_def,optionTheory.OPTREL_def] >>
    rpt strip_tac >>
    metis_tac[optionTheory.option_CASES,optionTheory.NOT_SOME_NONE,optionTheory.SOME_11] ) >>
  pop_assum mp_tac >>
  rw[Once enveq_cases] >>
  rw[Once enveq_cases] >>
  fs[ALIST_REL_def,optionTheory.OPTREL_def] >>
  rpt strip_tac >>
  metis_tac[optionTheory.option_CASES,optionTheory.NOT_SOME_NONE,optionTheory.SOME_11] )

val EVERY2_enveq_trans = save_thm("EVERY2_enveq_trans",
 EVERY2_trans |> Q.GEN`R` |> Q.ISPEC`enveq` |> UNDISCH
 |> prove_hyps_by(metis_tac[enveq_trans]))

val ALIST_REL_enveq_trans = save_thm("ALIST_REL_enveq_trans",
  ALIST_REL_trans |> Q.GEN`R` |> Q.ISPEC`enveq` |> UNDISCH
 |> prove_hyps_by(metis_tac[enveq_trans]))

val ALOOKUP_CONS_SAME = store_thm("ALOOKUP_CONS_SAME",
  ``(ALOOKUP env1 = ALOOKUP env2) ⇒ (ALOOKUP (x::env1) = ALOOKUP (x::env2))``,
  Cases_on`x`>>rw[FUN_EQ_THM])

val do_uapp_enveq = store_thm("do_uapp_enveq",
  ``∀s uop v s' v' v1 s1.
    do_uapp s uop v = SOME (s',v') ∧
    enveq v v1 ∧
    LIST_REL enveq s s1 ⇒
    ∃s1' v1'.
    do_uapp s1 uop v1 = SOME (s1',v1') ∧
    LIST_REL enveq s' s1' ∧
    enveq v' v1'``,
  gen_tac >> Cases >> Cases >> TRY (Cases_on`l`) >> simp[do_uapp_def,store_alloc_def,store_lookup_def] >>
  TRY (
    rw[Once enveq_cases] >> TRY (fs[EVERY2_EVERY] >> NO_TAC) >>
    match_mp_tac EVERY2_APPEND_suff >> simp[] >> NO_TAC) >>
  TRY (
    rw[Once enveq_cases] >>
    TRY(rw[Once enveq_cases] >> fs[EVERY2_EVERY] >> NO_TAC) >>
    match_mp_tac EVERY2_APPEND_suff >> fs[] >>
    rw[Once enveq_cases] ) >>
  ntac 2 gen_tac >> Cases >>
  rw[Once enveq_cases] >> rw[] >> fs[EVERY2_EVERY] >> rfs[EVERY_MEM,MEM_ZIP,FORALL_PROD,GSYM LEFT_FORALL_IMP_THM] >>
  spose_not_then strip_assume_tac >> fs[])

val enveq_contains_closure = store_thm("enveq_contains_closure",
  ``∀v1 v2. enveq v1 v2 ⇒ (contains_closure v1 ⇔ contains_closure v2)``,
  ho_match_mp_tac enveq_ind >>
  simp[contains_closure_def] >>
  simp[EVERY2_EVERY,EXISTS_MEM,EVERY_MEM,FORALL_PROD] >>
  rw[] >> rfs[MEM_ZIP] >> simp[MEM_EL] >> metis_tac[])

val LIST_REL_enveq_contains_closure = store_thm("LIST_REL_enveq_contains_closure",
  ``LIST_REL enveq v1 v2 ⇒ LIST_REL (λv1 v2. contains_closure v1 ⇔ contains_closure v2) v1 v2``,
  match_mp_tac EVERY2_mono >> simp[enveq_contains_closure])

val enveq_lit_loc = store_thm("enveq_lit_loc",
  ``(enveq (Litv l) v ⇔ (v = Litv l)) ∧
    (enveq v (Litv l) ⇔ (v = Litv l)) ∧
    (enveq v (Loc n) ⇔ (v = Loc n)) ∧
    (enveq (Loc n) v ⇔ (v = Loc n))``,
  simp[enveq_cases])
val _ = export_rewrites["enveq_lit_loc"]

val enveq_conv = store_thm("enveq_conv",
  ``(enveq (Conv n ls) v = (∃ls'. v = Conv n ls' ∧ EVERY2 enveq ls ls')) ∧
    (enveq v (Conv n ls) = (∃ls'. v = Conv n ls' ∧ EVERY2 enveq ls' ls))``,
  simp[Once enveq_cases] >> rw[] >>
  simp[Once enveq_cases] >> rw[])

val enveq_no_closures_equal = store_thm("enveq_no_closures_equal",
  ``∀v1 v2. enveq v1 v2 ⇒ ¬contains_closure v1 ⇒ (v2 = v1)``,
  ho_match_mp_tac enveq_ind >>
  simp[contains_closure_def] >>
  rw[LIST_EQ_REWRITE,EVERY2_EVERY,EVERY_MEM,FORALL_PROD] >>
  rfs[MEM_ZIP,GSYM LEFT_FORALL_IMP_THM] >>
  metis_tac[MEM_EL])

val ALIST_REL_EVERY2 = store_thm("ALIST_REL_EVERY2",
  ``∀R l1 l2. (MAP FST l1 = MAP FST l2) ∧ EVERY2 R (MAP SND l1) (MAP SND l2) ⇒ ALIST_REL R l1 l2``,
  gen_tac >> Induct >> simp[] >- simp[ALIST_REL_def,optionTheory.OPTREL_def] >>
  Cases >> Cases >> simp[] >> rw[] >>
  Cases_on`h` >> fs[] >>
  match_mp_tac ALIST_REL_CONS_SAME >> simp[] )

val do_app_SOME_enveq = store_thm("do_app_SOME_enveq",
  ``∀s env op v1 v2 s' env' exp' sq sq' envq envq' v1q v2q.
      do_app s env op v1 v2 = SOME (s',env',exp') ∧
      enveq v1 v1q ∧ enveq v2 v2q ∧
      LIST_REL enveq s sq ∧
      ALIST_REL enveq env envq
      ⇒
      ∃sq' envq'.
        do_app sq envq op v1q v2q = SOME (sq',envq',exp') ∧
        LIST_REL enveq s' sq' ∧
        ALIST_REL enveq env' envq'``,
  ntac 2 gen_tac >> Cases >>
  Cases >> TRY(Cases_on`l:lit`) >>
  Cases >> TRY(Cases_on`l:lit`) >>
  simp[do_app_def] >>
  rw[] >> fs[enveq_conv] >> rw[] >>
  fs[contains_closure_def,store_assign_def] >>
  TRY (
    imp_res_tac enveq_contains_closure >>
    imp_res_tac LIST_REL_enveq_contains_closure >>
    fs[EVERY2_EVERY] >> rfs[EVERY_MEM,MEM_ZIP,FORALL_PROD] >>
    fs[GSYM LEFT_FORALL_IMP_THM,MEM_EL] >>
    NO_TAC)  >>
  TRY (
    qmatch_abbrev_tac`a ∧ b ⇔ a ∧ c` >>
    Cases_on`a`>>simp[]>>
    unabbrev_all_tac >>
    qmatch_rename_tac`l1 = l2 ⇔ l3 = l4`[] >>
    fs[LIST_EQ_REWRITE,EVERY2_EVERY] >>
    rfs[EVERY_MEM,MEM_ZIP,FORALL_PROD,GSYM LEFT_FORALL_IMP_THM] >>
    Cases_on`LENGTH l1 = LENGTH l2`>>simp[]>>
    metis_tac[enveq_no_closures_equal,MEM_EL] ) >>
  TRY (
    fs[Once enveq_cases,bind_def] >>
    match_mp_tac ALIST_REL_CONS_SAME >>
    simp[] >> simp[enveq_conv] >>
    simp[Once enveq_cases] >> NO_TAC) >>
  TRY (
    fs[Once enveq_cases] >>
    BasicProvers.CASE_TAC >> fs[] >>
    BasicProvers.CASE_TAC >> fs[bind_def] >> rw[] >>
    match_mp_tac ALIST_REL_CONS_SAME >>
    simp[Once enveq_cases,build_rec_env_MAP] >>
    match_mp_tac ALIST_REL_APPEND >> simp[] >>
    match_mp_tac ALIST_REL_EVERY2 >>
    simp[MAP_MAP_o,combinTheory.o_DEF,UNCURRY,EVERY2_EVERY,EVERY_MEM,FORALL_PROD,MEM_ZIP,GSYM LEFT_FORALL_IMP_THM,EL_MAP] >>
    simp[Once enveq_cases] >> NO_TAC) >>
  TRY (
    rw[] >> fs[] >>
    fs[EVERY2_EVERY] >>
    rw[] >> rfs[EVERY_MEM,MEM_ZIP,GSYM LEFT_FORALL_IMP_THM] >>
    rw[EL_LUPDATE] >>
    rw[enveq_conv,EVERY2_EVERY,EVERY_MEM,MEM_ZIP,UNCURRY] >> rw[] >>
    NO_TAC))

val do_app_NONE_enveq = store_thm("do_app_NONE_enveq",
  ``∀s env op v1 v2 sq sq' envq envq' v1q v2q.
      do_app s env op v1 v2 = NONE ∧
      enveq v1 v1q ∧ enveq v2 v2q ∧
      LIST_REL enveq s sq ∧
      ALIST_REL enveq env envq
      ⇒
      do_app sq envq op v1q v2q = NONE``,
  ntac 2 gen_tac >> Cases >>
  Cases >> TRY(Cases_on`l:lit`) >>
  Cases >> TRY(Cases_on`l:lit`) >>
  simp[do_app_def] >>
  rw[] >> fs[enveq_conv] >> rw[] >>
  fs[contains_closure_def,store_assign_def] >>
  fs[Once enveq_cases,contains_closure_def] >>
  TRY (
    imp_res_tac LIST_REL_enveq_contains_closure >>
    fs[EVERY2_EVERY,EVERY_MEM,EXISTS_MEM,FORALL_PROD] >>
    rfs[MEM_ZIP,GSYM LEFT_FORALL_IMP_THM] >>
    fs[MEM_ZIP,GSYM LEFT_FORALL_IMP_THM] >>
    fsrw_tac[DNF_ss][MEM_EL] >>
    metis_tac[] ) >>
  TRY (
    BasicProvers.CASE_TAC >> fs[] >>
    BasicProvers.CASE_TAC >> fs[] >>
    NO_TAC ) >>
  BasicProvers.CASE_TAC >> fs[EVERY2_EVERY] )

val do_log_enveq = store_thm("do_log_enveq",
  ``∀op v1 e v2. enveq v1 v2 ⇒ do_log op v2 e = do_log op v1 e``,
  Cases >> Cases >> rw[do_log_def,enveq_conv] >> rw[] >> fs[Once enveq_cases])

val do_if_enveq = store_thm("do_if_enveq",
  ``∀v1 e1 e2 v2. enveq v1 v2 ⇒ do_if v2 e1 e2 = do_if v1 e1 e2``,
  Cases >> rw[do_if_def,enveq_conv] >> rw[] >> fs[Once enveq_cases])

val pmatch_enveq = store_thm("pmatch_enveq",
  ``(∀cenv:envC s p v env sq vq envq.
       LIST_REL enveq s sq ∧
       enveq v vq ∧
       ALIST_REL enveq env envq ⇒
       (∀env'. pmatch cenv s p v env = Match env' ⇒
         ∃env'q. pmatch cenv sq p vq envq = Match env'q ∧
                 ALIST_REL enveq env' env'q) ∧
       (∀env'. pmatch cenv s p v env = No_match ⇒
         pmatch cenv sq p vq envq = No_match) ∧
       (∀env'. pmatch cenv s p v env = Match_type_error ⇒
         pmatch cenv sq p vq envq = Match_type_error)) ∧
    (∀cenv:envC s p v env sq vq envq.
       LIST_REL enveq s sq ∧
       LIST_REL enveq v vq ∧
       ALIST_REL enveq env envq ⇒
       (∀env'. pmatch_list cenv s p v env = Match env' ⇒
         ∃env'q. pmatch_list cenv sq p vq envq = Match env'q ∧
                 ALIST_REL enveq env' env'q) ∧
       (∀env'. pmatch_list cenv s p v env = No_match ⇒
         pmatch_list cenv sq p vq envq = No_match) ∧
       (∀env'. pmatch_list cenv s p v env = Match_type_error ⇒
         pmatch_list cenv sq p vq envq = Match_type_error))``,
  ho_match_mp_tac pmatch_ind >>
  strip_tac >- (
    rw[pmatch_def,bind_def] >>
    match_mp_tac ALIST_REL_CONS_SAME >> rw[] ) >>
  strip_tac >- rw[pmatch_def] >>
  strip_tac >- (
    simp[] >>
    rpt gen_tac >> strip_tac >>
    simp[pmatch_def,enveq_conv] >>
    rpt gen_tac >> strip_tac >>
    Cases_on`ALOOKUP cenv n`>>fs[] >- (
      rw[] >> rw[pmatch_def] ) >>
    Cases_on`ALOOKUP cenv n'`>>fs[] >- (
      rw[] >> rw[pmatch_def] ) >>
    Cases_on`x`>>fs[]>>
    Cases_on`x'`>>fs[]>>
    conj_tac >- (
      rw[pmatch_def] >>
      fs[EVERY2_EVERY] ) >>
    conj_tac >- (
      rw[pmatch_def] >>
      fs[EVERY2_EVERY] ) >>
    rw[pmatch_def] >>
    fs[EVERY2_EVERY] ) >>
  strip_tac >- (
    simp[] >>
    rpt gen_tac >> strip_tac >>
    simp[pmatch_def] >>
    Cases_on`store_lookup lnum s`>>fs[] >- (
      fs[store_lookup_def,EVERY2_EVERY] >> rw[] >> fs[] ) >>
    fs[store_lookup_def] >>
    fs[EVERY2_EVERY] >>
    rpt gen_tac >> strip_tac >> fs[] >>
    fsrw_tac[DNF_ss][] >>
    rw[] >> first_x_assum (match_mp_tac o MP_CANON) >> fs[] >>
    rfs[EVERY_MEM,MEM_ZIP,FORALL_PROD,GSYM LEFT_FORALL_IMP_THM] ) >>
  strip_tac >- (
    rw[pmatch_def,enveq_conv] >>
    rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- ( rw[pmatch_def] >> fs[Once enveq_cases] >> rw[pmatch_def] ) >>
  strip_tac >- (
    simp[] >>
    rpt gen_tac >> strip_tac >>
    rpt gen_tac >> strip_tac >>
    BasicProvers.VAR_EQ_TAC >>
    conj_tac >- (
      rw[pmatch_def] >>
      pop_assum mp_tac >>
      BasicProvers.CASE_TAC >> fs[] >> strip_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      TRY (res_tac >> fs[] >> NO_TAC) >>
      last_x_assum(qspecl_then[`sq`,`y`,`envq`]mp_tac) >>
      simp[]) >>
    rw[pmatch_def] >>
    pop_assum mp_tac >>
    BasicProvers.CASE_TAC >> fs[] >> strip_tac >>
    BasicProvers.CASE_TAC >> fs[] >>
    TRY (res_tac >> fs[] >> NO_TAC) >>
    last_x_assum(qspecl_then[`sq`,`y`,`envq`]mp_tac) >>
    simp[]) >>
  strip_tac >- (
    rw[] >>
    rw[pmatch_def] >>
    fs[pmatch_def] ) >>
  simp[pmatch_def] >>
  rw[] >> rw[pmatch_def])

val evaluate_enveq = store_thm("evaluate_enveq",
  ``(∀menv (cenv:envC) s env exp res. evaluate menv cenv s env exp res ⇒
      ∀s' env'. (ALIST_REL enveq env env') ∧ (LIST_REL enveq s s') ⇒
        ∃res'. evaluate menv cenv s' env' exp res' ∧
               EVERY2 enveq (FST res) (FST res') ∧
               result_rel enveq (SND res) (SND res')) ∧
    (∀menv (cenv:envC) s env es res. evaluate_list menv cenv s env es res ⇒
      ∀s' env'. (ALIST_REL enveq env env') ∧ (LIST_REL enveq s s') ⇒
        ∃res'. evaluate_list menv cenv s' env' es res' ∧
               EVERY2 enveq (FST res) (FST res') ∧
               result_rel (EVERY2 enveq) (SND res) (SND res')) ∧
    (∀menv (cenv:envC) s env v pes res. evaluate_match menv cenv s env v pes res ⇒
      ∀s' env' v'. (ALIST_REL enveq env env') ∧ (LIST_REL enveq s s') ∧ enveq v v' ⇒
        ∃res'. evaluate_match menv cenv s' env' v' pes res' ∧
               EVERY2 enveq (FST res) (FST res') ∧
               result_rel enveq (SND res) (SND res'))``,
  ho_match_mp_tac evaluate_ind >>
  strip_tac >- rw[] >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][bind_def] >>
    disj2_tac >> disj1_tac >>
    last_x_assum(qspecl_then[`s''`,`env'`]mp_tac) >> rw[] >>
    qmatch_assum_rename_tac`LIST_REL enveq s' s'''`[] >>
    last_x_assum(qspecl_then[`s'''`,`((var,Litv (IntLit n))::env')`]mp_tac) >>
    discharge_hyps >- ( simp[] >> metis_tac[ALIST_REL_CONS_SAME,enveq_refl] ) >>
    rw[] >> PROVE_TAC[]) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][bind_def] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    simp[Once enveq_cases]) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][lookup_var_id_def] >>
    BasicProvers.CASE_TAC >> fs[] >>
    fs[ALIST_REL_def,optionTheory.OPTREL_def] >>
    metis_tac[optionTheory.NOT_SOME_NONE,optionTheory.SOME_11] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][lookup_var_id_def] >>
    BasicProvers.CASE_TAC >> fs[] >>
    fs[ALIST_REL_def,optionTheory.OPTREL_def] >>
    metis_tac[optionTheory.NOT_SOME_NONE,optionTheory.SOME_11] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    rw[Once enveq_cases] ) >>
  strip_tac >- (
    rw[] >>
    qspecl_then[`s2`,`uop`,`v`,`s3`,`v'`]mp_tac do_uapp_enveq >>
    simp[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    first_x_assum(qspecl_then[`s'`,`env'`]mp_tac) >>
    rw[] >> metis_tac[] ) >>
  strip_tac >- (
    rw[] >> rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    Cases_on`uop`>>Cases_on`v`>>fs[do_uapp_def,store_alloc_def,store_assign_def,store_lookup_def,LET_THM] >>
    fs[Once enveq_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    first_x_assum(qspecl_then[`s'`,`env'`]mp_tac) >>
    simp[] >> disch_then(Q.X_CHOOSE_THEN`s1`strip_assume_tac) >>
    qexists_tac`s1` >> HINT_EXISTS_TAC >>
    simp[] >>
    rw[]>>fs[EVERY2_EVERY] ) >>
  strip_tac >- (
    rw[] >> rw[Once evaluate_cases] >>
    fsrw_tac[DNF_ss][FORALL_PROD,EXISTS_PROD] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    srw_tac[DNF_ss][Once evaluate_cases] >>
    disj1_tac >>
    fsrw_tac[DNF_ss][] >>
    qspecl_then[`s3`,`env`,`op`,`v1`,`v2`]mp_tac do_app_SOME_enveq >>
    simp[] >> strip_tac >>
    last_x_assum(qspecl_then[`s'''`,`env''`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sa`,`va`]strip_assume_tac) >>
    last_x_assum(qspecl_then[`sa`,`env''`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sb`,`vb`]strip_assume_tac) >>
    first_x_assum(qspecl_then[`sb`,`env''`,`va`,`vb`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sc`,`envc`]strip_assume_tac) >>
    first_x_assum(qspecl_then[`sc`,`envc`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sd`,`envd`]strip_assume_tac) >>
    map_every qexists_tac [`sd`,`envd`,`va`,`vb`,`envc`,`exp''`,`sa`,`sb`,`sc`] >>
    simp[] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    srw_tac[DNF_ss][Once evaluate_cases] >>
    disj2_tac >> disj1_tac >>
    fsrw_tac[DNF_ss][] >>
    last_x_assum(qspecl_then[`s''`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sa`,`va`]strip_assume_tac) >>
    last_x_assum(qspecl_then[`sa`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sb`,`vb`]strip_assume_tac) >>
    map_every qexists_tac [`sb`,`va`,`vb`,`sa`] >> simp[] >>
    imp_res_tac do_app_NONE_enveq ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    srw_tac[DNF_ss][Once evaluate_cases] >>
    disj2_tac >> disj2_tac >> disj1_tac >>
    fsrw_tac[DNF_ss][] >>
    last_x_assum(qspecl_then[`s''`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sa`,`va`]strip_assume_tac) >>
    last_x_assum(qspecl_then[`sa`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sb`]strip_assume_tac) >>
    metis_tac[] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >> rw[] >>
    srw_tac[DNF_ss][Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    disj1_tac >>
    metis_tac[do_log_enveq,EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[do_log_enveq,EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[do_if_enveq,EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[do_if_enveq,EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[do_if_enveq,EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD,bind_def] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases,bind_def] >>
    disj1_tac >>
    last_x_assum(qspecl_then[`s''`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sa`,`va`]strip_assume_tac) >>
    last_x_assum(qspecl_then[`sa`,`(n,v')::env'`]mp_tac) >> simp[] >>
    discharge_hyps >- (
      match_mp_tac ALIST_REL_CONS_SAME >>
      simp[] ) >>
    disch_then(qx_choosel_then[`sb`,`vb`]strip_assume_tac) >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD,bind_def] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases,bind_def] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD,build_rec_env_MAP] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases,build_rec_env_MAP] >>
    Q.PAT_ABBREV_TAC`env'' = MAP X Y ++ env'` >>
    last_x_assum(qspecl_then[`s'`,`env''`]mp_tac) >> simp[] >>
    discharge_hyps >- (
      simp[Abbr`env''`] >>
      match_mp_tac ALIST_REL_APPEND >> simp[] >>
      match_mp_tac ALIST_REL_EVERY2 >>
      simp[MAP_MAP_o,combinTheory.o_DEF,UNCURRY,EVERY2_EVERY,EVERY_MEM,FORALL_PROD,MEM_ZIP,GSYM LEFT_FORALL_IMP_THM,EL_MAP] >>
      simp[Once enveq_cases]) >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD,build_rec_env_MAP] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases,build_rec_env_MAP] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    last_x_assum(qspecl_then[`s''`,`env'`]mp_tac) >> simp[] >>
    disch_then(qx_choosel_then[`sa`,`va`]strip_assume_tac) >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    metis_tac[EVERY2_enveq_trans,ALIST_REL_enveq_trans] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    qspecl_then[`cenv`,`s`,`p`,`v`,`env`]mp_tac(CONJUNCT1 pmatch_enveq) >> simp[] >>
    disch_then(qspecl_then[`s'`,`v'`,`env''`]mp_tac) >> simp[] >>
    metis_tac[] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    qspecl_then[`cenv`,`s`,`p`,`v`,`env`]mp_tac(CONJUNCT1 pmatch_enveq) >> simp[] ) >>
  strip_tac >- (
    simp[FORALL_PROD,EXISTS_PROD] >>
    rw[] >> srw_tac[DNF_ss][Once evaluate_cases] >>
    qspecl_then[`cenv`,`s`,`p`,`v`,`env`]mp_tac(CONJUNCT1 pmatch_enveq) >> simp[] ) >>
  simp[FORALL_PROD,EXISTS_PROD] >>
  rw[] >> srw_tac[DNF_ss][Once evaluate_cases])
*)

val _ = export_theory()
