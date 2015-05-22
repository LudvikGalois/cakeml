open HolKernel boolLib bossLib
open ml_translatorLib ml_monadTheory ml_hol_kernelTheory astPP

val _ = new_theory"ppKernel"

val _ = translation_extends"ml_hol_kernel";

val decls = get_decls()

fun equalityprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([l,r],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [App Opapp [Var(Short"=");^l];^r]``
  end
val _ = add_astPP("equalityprinter",``App Equality [x;y]``,equalityprinter)

fun refprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([a],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [Var(Short"ref");^a]``
  end
val _ = add_astPP("refprinter",``App Opref [x]``,refprinter)

fun assignprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([l,r],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [App Opapp [Var(Short":=");^l];^r]``
  end
val _ = add_astPP("assignprinter",``App Opassign [x;y]``,assignprinter)

fun derefprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([a],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [Var(Short"!");^a]``
  end
val _ = add_astPP("derefprinter",``App Opderef [x]``,derefprinter)

fun plusprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([l,r],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [App Opapp [Var(Short"+");^l];^r]``
  end
val _ = add_astPP("plusprinter",``App (Opn Plus) [x;y]``,plusprinter)

fun implodeprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([a],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [Var(Long"String""implode");^a]``
  end
val _ = add_astPP("implodeprinter",``App Implode [x]``,implodeprinter)

fun explodeprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([a],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [Var(Long"String""explode");^a]``
  end
val _ = add_astPP("explodeprinter",``App Explode [x]``,explodeprinter)

fun chltprinter _ _ sys _ gs d t =
  let
    val (_,ls) = dest_comb t
    val ([l,r],_) = listSyntax.dest_list ls
  in
    sys gs d ``App Opapp [App Opapp [Var(Short"<");^l];^r]``
  end
val _ = add_astPP("chltprinter",``App (Chopb Lt) [x;y]``,chltprinter)

val _ = enable_astPP()

val _ = set_trace "pp_avoids_symbol_merges" 0

val f = TextIO.openOut("kernel.ml.txt")

fun appthis tm = let
  val () = TextIO.output(f,term_to_string tm)
  val () = TextIO.output(f,"\n")
in () end

val _ = app appthis (fst(listSyntax.dest_list decls))

val _ = TextIO.closeOut f

val _ = export_theory()