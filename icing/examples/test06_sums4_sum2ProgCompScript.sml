(*
  Auto-generated by Daisy (https://gitlab.mpi-sws.org/AVA/daisy
  *)
(* INCLUDES, do not change those *)
open exampleLib preamble;

val _ = new_theory "test06_sums4_sum2ProgComp";

val _ = translation_extends "cfSupport";

Definition theAST_pre_def:
  theAST_pre = \ (x:(string, string) id).
  if x = Short "x0" then (((-1)/(100000), (100001)/(100000)):real#real)
  else if x = Short "x1" then (((0)/(1), (1)/(1)):real#real)
  else if x = Short "x2" then (((0)/(1), (1)/(1)):real#real)
  else if x = Short "x3" then (((0)/(1), (1)/(1)):real#real)
  else (0,0)
End

Definition theAST_def:
  theAST =
  [ Dlet unknown_loc (Pvar "test06_sums4_sum2")
    (Fun "x0"(Fun "x1"(Fun "x2"(Fun "x3"
      (FpOptimise Opt
(App (FP_bop FP_Add)
        [
          (App (FP_bop FP_Add)
          [
            Var (Short  "x0");
            Var (Short  "x1")
          ]);
          (App (FP_bop FP_Add)
          [
            Var (Short  "x2");
            Var (Short  "x3")
          ])
        ]))))))]
End
Definition theErrBound_def:
  theErrBound = inv (2 pow (10))
End

val x = define_benchmark theAST_def theAST_pre_def false;

val _ = export_theory()