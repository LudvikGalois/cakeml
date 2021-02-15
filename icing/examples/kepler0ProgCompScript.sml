(*
  Auto-generated by Daisy (https://gitlab.mpi-sws.org/AVA/daisy
  *)
(* INCLUDES, do not change those *)
open exampleLib preamble;

val _ = new_theory "kepler0ProgComp";

val _ = translation_extends "cfSupport";

Definition theAST_pre_def:
  theAST_pre = \ (x:(string, string) id).
  if x = Short "x1" then (((4)/(1), (159)/(25)):real#real)
  else if x = Short "x2" then (((4)/(1), (159)/(25)):real#real)
  else if x = Short "x3" then (((4)/(1), (159)/(25)):real#real)
  else if x = Short "x4" then (((4)/(1), (159)/(25)):real#real)
  else if x = Short "x5" then (((4)/(1), (159)/(25)):real#real)
  else if x = Short "x6" then (((4)/(1), (159)/(25)):real#real)
  else (0,0)
End

Definition theAST_def:
  theAST =
  [ Dlet unknown_loc (Pvar "kepler0")
    (Fun "x1"(Fun "x2"(Fun "x3"(Fun "x4"(Fun "x5"(Fun "x6"
      (FpOptimise Opt
(App (FP_bop FP_Add)
        [
          (App (FP_bop FP_Sub)
          [
            (App (FP_bop FP_Sub)
            [
              (App (FP_bop FP_Add)
              [
                (App (FP_bop FP_Mul)
                [
                  Var (Short  "x2");
                  Var (Short  "x5")
                ]);
                (App (FP_bop FP_Mul)
                [
                  Var (Short  "x3");
                  Var (Short  "x6")
                ])
              ]);
              (App (FP_bop FP_Mul)
              [
                Var (Short  "x2");
                Var (Short  "x3")
              ])
            ]);
            (App (FP_bop FP_Mul)
            [
              Var (Short  "x5");
              Var (Short  "x6")
            ])
          ]);
          (App (FP_bop FP_Mul)
          [
            Var (Short  "x1");
            (App (FP_bop FP_Add)
            [
              (App (FP_bop FP_Add)
              [
                (App (FP_bop FP_Sub)
                [
                  (App (FP_bop FP_Add)
                  [
                    (App (FP_bop FP_Add)
                    [
                      (App (FP_uop FP_Neg)
                      [
                        Var (Short  "x1")
                      ]);
                      Var (Short  "x2")
                    ]);
                    Var (Short  "x3")
                  ]);
                  Var (Short  "x4")
                ]);
                Var (Short  "x5")
              ]);
              Var (Short  "x6")
            ])
          ])
        ]))))))))]
End
Definition theErrBound_def:
  theErrBound = inv (2 pow (10))
End

val x = define_benchmark theAST_def theAST_pre_def false;

val _ = export_theory()