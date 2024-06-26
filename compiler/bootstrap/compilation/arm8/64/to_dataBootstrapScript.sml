(*
  Evaluate the 32-bit version of the compiler down to a DataLang
  program.
*)
open preamble compiler64ProgTheory

val _ = new_theory"to_dataBootstrap";

(*
  Eventually, this file will prove
   |- to_data c prog_t1 = ...
   |- to_data c prog_t2 = ...
   |- ...
   where
     c =
       a default initial config (shared by all targets)
     prog_tn =
       a prog declaring the entire compiler for target n

  With incremental compilation, we might get away with only one prog, which is
  the prog for all the non-target-specific parts of the compiler, but Magnus
  suggests incremental compilation like that might be impossible, since some
  phases need to know they have the whole program.

  Alternatively, the different to_data theorems for different targets could go
  into different theories. The only thing they share is init_conf_def and the
  strategy for evaluation.
*)

val _ = Globals.max_print_depth := 20;

val cs = compilationLib.compilation_compset();

val init_conf_def = zDefine`
  init_conf = <|
    source_conf := prim_src_config;
    clos_conf   := clos_to_bvl$default_config
                   with known_conf := SOME
                     <| inline_max_body_size := 8; inline_factor := 0;
                        initial_inline_factor := 0; val_approx_spt := LN |>;
    bvl_conf    := bvl_to_bvi$default_config with
                     <| inline_size_limit := 3; exp_cut := 200 |>
  |>`;

(*
val (ls,ty) = compiler_prog_def |> rconc |> listSyntax.dest_list
val new_prog = listSyntax.mk_list(List.take(ls,80),ty)
val compiler_prog_thm = mk_thm([],mk_eq(lhs(concl(compiler_prog_def)),new_prog));
*)
val compiler64_prog_thm = compiler64_prog_def;

(* uncomment the line below for debugging purposes *)
(* val compiler64_prog_thm = prove(“compiler64_prog = []”,cheat); *)

val to_data_arm8_thm = save_thm("to_data_arm8_thm",
  compilationLib.compile_to_data
    cs init_conf_def compiler64_prog_thm "data_prog_arm8");

val _ = export_theory();
