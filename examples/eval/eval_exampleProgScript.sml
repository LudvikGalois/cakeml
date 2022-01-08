(*
  Defines abstract syntax for a simple program that calls eval.
  The call is made to machine code read from a file.
*)

open preamble ml_translatorLib ml_progLib
     basisProgTheory basisFunctionsLib

val _ = new_theory "eval_exampleProg";

val _ = translation_extends "basisProg";

(* We assume the machine code is in two files:
   - eval_words.txt
     - exactly one integer (decimal numeral) per line
     - in the range [0, 2**64)
     - each line represents one compiler-generated
       bitmap (64-bit word)
   - eval_bytes.txt
     - exactly one integer (decimal numeral) per line
     - in the range [0, 2**8)
     - each line represents one compiler-generated byte
       of machine code *)

Definition trimr_def:
  trimr s = substring s 0 (strlen s - 1)
End

val res = translate trimr_def;

val fname_to_words = process_topdecs`
  fun fname_to_words from_int fname =
    List.map
      (from_int o
       Option.valOf o Int.fromNatString o
       trimr)
      (Option.valOf (TextIO.b_inputLinesFrom fname))
    handle _ => (print "Error reading data to eval.\n";
                 Runtime.exit 1; [])`;

val res = append_prog fname_to_words;

val ml_prog_state = get_ml_prog_state()
val s2 = get_state ml_prog_state
val locn_thm = EVAL``LENGTH ^s2.refs``

Theorem ref_eval_thm:
  !l. eval_rel
    ^s2
    ^(get_env ml_prog_state)
    (App Opref [Lit l])
    (^s2 with refs := ^s2.refs ++ [Refv (Litv l)])
    (Loc ^(rconc locn_thm))
Proof
  rw[ml_progTheory.eval_rel_alt]
  \\ rw[evaluateTheory.evaluate_def]
  \\ rw[semanticPrimitivesTheory.do_app_def]
  \\ rw[semanticPrimitivesTheory.store_alloc_def]
  \\ rw[semanticPrimitivesTheory.state_component_equality]
  \\ rw[locn_thm]
QED

val () = ml_prog_update (
  ml_progLib.add_Dlet
    (Q.SPEC `StrLit "initial string\n"` ref_eval_thm)
    "the_string_ref")

(* These decs cannot go through ml_progLib
   because it only supports declaring functions *)

val read_code_decs = process_topdecs`
  val the_bytes =
    fname_to_words Word8.fromInt "eval_bytes.txt"
  val the_words =
    fname_to_words Word64.fromInt "eval_words.txt"`;

(* These decs cannot go through ml_progLib
   because it does not support eval.

   To make the effect of the eval'd code visible, we
   put a string ref in its scope and print the
   string after eval'ing. *)

val call_eval_decs = ``
  [Denv "env1";
   Dlet unknown_loc Pany
     (App Opapp [Var (Short "print");
                 App Opderef [Var (Short "the_string_ref")]]);
   Dlet unknown_loc (Pvar "env2")
     (App Eval [Var (Short "env1");
                Lit (StrLit "dummy_input_state");
                Lit (StrLit "dummy_decs");
                Lit (StrLit "dummy_output_state");
                Var (Short "the_bytes");
                Var (Short "the_words")]);
   Dlet unknown_loc Pany
     (App Opapp [Var (Short "print");
                 App Opderef [Var (Short "the_string_ref")]]) ]``;

val decls_thm = get_Decls_thm (get_ml_prog_state())
val init_decls =
  decls_thm |> concl |> strip_comb |> #2 |> el 3
val all_decls =
  listSyntax.mk_append(init_decls,
    listSyntax.mk_append(read_code_decs, call_eval_decs))
  |> PURE_REWRITE_CONV [listTheory.APPEND]
  |> rconc

Definition eval_example_prog_def:
  eval_example_prog = ^all_decls
End

val _ = export_theory();
