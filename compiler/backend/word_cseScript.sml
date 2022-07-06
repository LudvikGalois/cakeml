(*
This file is a Work in Progress.
It gives some functions and verification proofs about a Common Sub-Expression
Elimination occuring right atfer the SSA-like renaming.
*)

(*
Mind map / TODO:
- the register equivalence form
    -> num list list
    -> Grouping equivalent registers together, keeping the first register
         added to a group in the head.
    -> Adding a r2 -> r1 to the existing mapping consits of looking if
         ∃group∈map. r1∈group.
         If so, we look if ∃group'∈map. r2∈group'.
           If so, we merge group and group'.
           Else, we add r2 to group in the second place.
         Else, we look if ∃group'∈map. r2∈group'.
           If so, we add r1 to group' in the second place.
           Else, we create a group=[r1;r2] that we add to map.
    -> !!! Case of function call we context conservation !!!
*)

open preamble wordLangTheory wordsTheory boolTheory mlmapTheory sptreeTheory

val _ = new_theory "word_cse";

Type regsE = ``:num list list``
Type regsM = ``:num num_map``
Type instrsM = ``:(num list,num)map``

val _ = Datatype `knowledge = <| eq:regsE;
                                 map:regsM;
                                 instrs:instrsM;
                                 all_names:num_set |>`;

(* add a (all_names:num_set) ⇒ when seeing a new register, add it in all_names
if a register is affected and is in all_names, throw everything

!!! even registers !!!
*)

(* LIST COMPARISON *)

Definition listCmp_def:
  (listCmp ((hd1:num) :: tl1) ((hd2:num) :: tl2) =
   if hd1=hd2
     then listCmp tl1 tl2
     else if hd1>hd2 then Greater else Less) ∧
  (listCmp [] [] = Equal) ∧
  (listCmp (hd1::tl1) [] = Greater) ∧
  (listCmp [] (hd2::tl2) = Less)
End

Definition empty_data_def:
  empty_data = <| eq:=[];
                  map:=LN;
                  instrs:=empty listCmp;
                  all_names:=LN |>
End

Definition is_seen_def:
  is_seen r data = case sptree$lookup r data.all_names of SOME _ => T | NONE => F
End


(* REGISTERS EQUIVALENCE MEMORY *)

Definition listLookup_def:
  listLookup x [] = F ∧
  listLookup x (y::tl) = if x=y then T else listLookup x tl
End

Definition regsLookup_def:
  regsLookup r [] = F ∧
  regsLookup r (hd::tl) = if listLookup r hd then T else regsLookup r tl
End

Definition regsUpdate1Aux_def:
  regsUpdate1Aux r l (hd::tl) =
    if listLookup r hd
      then (l ++ hd)::tl
      else hd::(regsUpdate1Aux r l tl)
End

Definition regsUpdate1_def:
  regsUpdate1 r1 r2 (hd::tl) =
    if listLookup r1 hd
      then if listLookup r2 hd
        then (hd::tl)
        else regsUpdate1Aux r2 hd tl
      else if listLookup r2 hd
        then regsUpdate1Aux r1 hd tl
        else hd::(regsUpdate1 r1 r2 tl)
End

Definition regsUpdate2_def:
  regsUpdate2 r1 r2 ((hd::tl)::tl') =
    if listLookup r1 (hd::tl)
      then (hd::r2::tl)::tl'
      else (hd::tl)::(regsUpdate2 r1 r2 tl')
End

Definition regsUpdate_def:
  regsUpdate r1 r2 [] = [[r1;r2]] ∧
  regsUpdate r1 r2 (hd::tl) =
    if regsLookup r1 (hd::tl)
      then if regsLookup r2 (hd::tl)
        then regsUpdate1 r1 r2 (hd::tl)
        else regsUpdate2 r1 r2 (hd::tl)
      else if regsLookup r2 (hd::tl)
        then regsUpdate2 r2 r1 (hd::tl)
        else [r1;r2]::hd::tl
End

(* REGISTER TRANSFORMATIONS *)

Definition canonicalRegs_def:
  canonicalRegs (data:knowledge) (r:num) =
  lookup_any r data.map r
End

Definition canonicalImmReg_def:
  canonicalImmReg data (Reg r) = Reg (canonicalRegs data r) ∧
  canonicalImmReg data (Imm w) = Imm w
End

Definition canonicalMultRegs_def:
  canonicalMultRegs (data:knowledge) (regs:num list) = MAP (canonicalRegs data) regs
End
(*
Definition canonicalMoveRegs_def:
  canonicalMoveRegs data [] = (data, []) ∧
  canonicalMoveRegs data ((r1,r2)::tl) =
  if is_seen r1 data then empty_data, ((r1,r2)::tl) else
        case sptree$lookup r2 data.och_map of
        | SOME r2' => let och_map' = sptree$insert r1 r2' data.och_map in
                      let (data', tl') = canonicalMoveRegs (data with och_map:=och_map') tl in
                        (data', (r1,r2')::tl')
        | NONE     => let r2' = (case sptree$lookup r2 data.inst_map of SOME r => r | NONE => r2) in
                      let inst_eq' = regsUpdate r2' r1 data.inst_eq in
                      let inst_map' = sptree$insert r1 r2' data.inst_map in
                      let (data', tl') = canonicalMoveRegs (data with <| inst_eq:=inst_eq'; inst_map:=inst_map' |>) tl in
                        (data', (r1,r2')::tl')
End

(* make a lookup_data to wrap case matching
lookup_any x sp d = lookup x sp otherwise return d
To discuss*)

Definition canonicalMoveRegs2_def:
  canonicalMoveRegs2 data [] = (data, []) ∧
  canonicalMoveRegs2 data ((r1,r2)::tl) =
    if is_seen r1 data then empty_data, ((r1,r2)::tl) else
    if (EVEN r1 ∨ EVEN r2)
      then let (data', tl') = canonicalMoveRegs2 data tl in
               (data', (r1, canonicalRegs data r2)::tl')
      else
        case sptree$lookup r2 data.och_map of
        | SOME r2' => let och_map' = sptree$insert r1 r2' data.och_map in
                      let (data', tl') = canonicalMoveRegs2 (data with och_map:=och_map') tl in
                        (data', (r1,r2')::tl')
        | NONE     => let r2' = (case sptree$lookup r2 data.inst_map of SOME r => r | NONE => r2) in
                      let inst_eq' = regsUpdate r2' r1 data.inst_eq in
                      let inst_map' = sptree$insert r1 r2' data.inst_map in
                      let (data', tl') = canonicalMoveRegs2 (data with <| inst_eq:=inst_eq'; inst_map:=inst_map' |>) tl in
                        (data', (r1,r2')::tl')
End
*)
(*
Move [(1,2);(2,3);(3,1)]
Move [(1,can 2);(2,can 3);(3,can 1)]
Knowledge : 1 ⇔ can 2 / 2 ⇔ can 3 / 3 ⇔ can 1
*)

Definition map_insert_def:
  map_insert [] m = m ∧
  map_insert ((x,y)::xs) m =
    insert x y (map_insert xs m)
End

Definition canonicalMoveRegs3_def:
  canonicalMoveRegs3 data moves =
  let moves' = MAP (λ(a,b). (a, canonicalRegs data b)) moves in
    if EXISTS (λ(a,b). is_seen a data) moves then (empty_data, moves')
    else
      let xs = FILTER (λ(a,b).  ¬EVEN a ∧ ¬EVEN b) moves' in
      let a_n = list_insert (MAP FST xs) data.all_names in
      let m = map_insert xs data.map in
        (data with <| all_names := a_n; map := m |>, moves')
End

Definition canonicalExp_def:
  canonicalExp data (Var r) = Var (canonicalRegs data r) ∧
  canonicalExp data exp = exp
End

Definition canonicalArith_def:
  canonicalArith data (Binop op r1 r2 r3) =
    Binop op r1 (canonicalRegs data r2) (canonicalImmReg data r3) ∧
  canonicalArith data (Shift s r1 r2 n) =
    Shift s r1 (canonicalRegs data r2) n ∧
  canonicalArith data (Div r1 r2 r3) =
    Div r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalArith data (LongMul r1 r2 r3 r4) =
    LongMul r1 r2 (canonicalRegs data r3) (canonicalRegs data r4) ∧
  canonicalArith data (LongDiv r1 r2 r3 r4 r5) =
    LongDiv r1 r2 (canonicalRegs data r3) (canonicalRegs data r4) (canonicalRegs data r5) ∧
  canonicalArith data (AddCarry r1 r2 r3 r4) =
    AddCarry r1 (canonicalRegs data r2) (canonicalRegs data r3) r4 ∧
  canonicalArith data (AddOverflow r1 r2 r3 r4) =
    AddOverflow r1 (canonicalRegs data r2) (canonicalRegs data r3) r4 ∧
  canonicalArith data (SubOverflow r1 r2 r3 r4) =
    SubOverflow r1 (canonicalRegs data r2) (canonicalRegs data r3) r4
End

Definition canonicalFp_def:
  canonicalFp data (FPLess r1 r2 r3) =
    FPLess r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPLessEqual r1 r2 r3) =
    FPLessEqual r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPEqual r1 r2 r3) =
    FPEqual r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPAbs r1 r2) =
    FPAbs r1 (canonicalRegs data r2) ∧
  canonicalFp data (FPNeg r1 r2) =
    FPNeg r1 (canonicalRegs data r2) ∧
  canonicalFp data (FPSqrt r1 r2) =
    FPSqrt r1 (canonicalRegs data r2) ∧
  canonicalFp data (FPAdd r1 r2 r3) =
    FPAdd r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPSub r1 r2 r3) =
    FPSub r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPMul r1 r2 r3) =
    FPMul r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPDiv r1 r2 r3) =
    FPDiv r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPFma r1 r2 r3) =
    FPFma r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPMov r1 r2) =
    FPMov r1 (canonicalRegs data r2) ∧
  canonicalFp data (FPMovToReg r1 r2 r3) =
    FPMovToReg r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPMovFromReg r1 r2 r3) =
    FPMovFromReg r1 (canonicalRegs data r2) (canonicalRegs data r3) ∧
  canonicalFp data (FPToInt r1 r2) =
    FPToInt r1 (canonicalRegs data r2) ∧
  canonicalFp data (FPFromInt r1 r2) =
    FPFromInt r1 (canonicalRegs data r2)
End

(* SEEN INSTRUCTIONS MEMORY *)

Definition wordToNum_def:
  wordToNum w = w2n w
End

Definition shiftToNum_def:
  shiftToNum Lsl = (38:num) ∧
  shiftToNum Lsr = 39 ∧
  shiftToNum Asr = 40 ∧
  shiftToNum Ror = 41
End

Definition arithOpToNum_def:
  arithOpToNum Add = (33:num) ∧
  arithOpToNum Sub = 34 ∧
  arithOpToNum And = 35 ∧
  arithOpToNum Or = 36 ∧
  arithOpToNum Xor = 37
End

Definition regImmToNumList_def:
  regImmToNumList (Reg r) = [31; r+100] ∧
  regImmToNumList (Imm w) = [32; wordToNum w]
End


Definition arithToNumList_def:
  arithToNumList (Binop op r1 r2 ri) = [23; arithOpToNum op; r2+100] ++ regImmToNumList ri ∧
  arithToNumList (LongMul r1 r2 r3 r4) = [24; r3+100; r4+100] ∧
  arithToNumList (LongDiv r1 r2 r3 r4 r5) = [25; r3+100; r4+100; r5+100] ∧
  arithToNumList (Shift s r1 r2 n) = [26; shiftToNum s; r2+100; n] ∧
  arithToNumList (Div r1 r2 r3) = [27; r2+100; r3+100] ∧
  arithToNumList (AddCarry r1 r2 r3 r4) = [28; r2+100; r3+100] ∧
  arithToNumList (AddOverflow r1 r2 r3 r4) = [29; r2+100; r3+100] ∧
  arithToNumList (SubOverflow r1 r2 r3 r4) = [30; r2+100; r3+100]
End

Definition memOpToNum_def:
  memOpToNum Load = (19:num) ∧
  memOpToNum Load8 = 20 ∧
  memOpToNum Store = 21 ∧
  memOpToNum Store8 = 22
End

Definition fpToNumList_def:
  fpToNumList (FPLess r1 r2 r3) = [3; r2+100; r3+100] ∧
  fpToNumList (FPLessEqual r1 r2 r3) = [4; r2+100; r3+100] ∧
  fpToNumList (FPEqual r1 r2 r3) = [5; r2+100; r3+100] ∧
  fpToNumList (FPAbs r1 r2) = [6; r2+100] ∧
  fpToNumList (FPNeg r1 r2) = [7; r2+100] ∧
  fpToNumList (FPSqrt r1 r2) = [8; r2+100] ∧
  fpToNumList (FPAdd r1 r2 r3) = [9; r2+100; r3+100] ∧
  fpToNumList (FPSub r1 r2 r3) = [10; r2+100; r3+100] ∧
  fpToNumList (FPMul r1 r2 r3) = [11; r2+100; r3+100] ∧
  fpToNumList (FPDiv r1 r2 r3) = [12; r2+100; r3+100] ∧
  fpToNumList (FPFma r1 r2 r3) = [13; r1+100; r2+100; r3+100] ∧ (* List never matched again *)
  fpToNumList (FPMov r1 r2) = [14; r2+100] ∧
  fpToNumList (FPMovToReg r1 r2 r3) = [15; r2+100; r3+100] ∧
  fpToNumList (FPMovFromReg r1 r2 r3) = [16; r2+100; r3+100] ∧
  fpToNumList (FPToInt r1 r2) = [17; r2+100] ∧
  fpToNumList (FPFromInt r1 r2) = [18; r2+100]
End

Definition instToNumList_def:
  instToNumList (Skip) = [1] ∧
  instToNumList (Const r w) = [2;wordToNum w] ∧
  instToNumList (Arith a) = 3::(arithToNumList a) ∧
  instToNumList (FP fp) = 4::(fpToNumList fp)
End

(*
Principle:
Each unique instruction is converted to a unique num list.
Numbers between 0 and 99 corresponds to a unique identifier of an instruction.
Numbers above 99 corresponds to a register or a word value.
*)
(* TODO : redo the rename of instruction numbers such that each is unique *)
Definition OpCurrHeapToNumList_def:
  OpCurrHeapToNumList op r2 = [1; arithOpToNum op; r2+100]
End

Definition firstRegOfArith_def:
  firstRegOfArith (Binop _ r _ _) = r ∧
  firstRegOfArith (Shift _ r _ _) = r ∧
  firstRegOfArith (Div r _ _) = r ∧
  firstRegOfArith (LongMul r _ _ _) = r ∧
  firstRegOfArith (LongDiv r _ _ _ _) = r ∧
  firstRegOfArith (AddCarry r _ _ _) = r ∧
  firstRegOfArith (AddOverflow r _ _ _) = r ∧
  firstRegOfArith (SubOverflow r _ _ _) = r
End

Definition firstRegOfFp_def:
  firstRegOfFp (FPLess r _ _) = r ∧
  firstRegOfFp (FPLessEqual r _ _) = r ∧
  firstRegOfFp (FPEqual r _ _) = r ∧
  firstRegOfFp (FPAbs r _) = r ∧
  firstRegOfFp (FPNeg r _) = r ∧
  firstRegOfFp (FPSqrt r _) = r ∧
  firstRegOfFp (FPAdd r _ _) = r ∧
  firstRegOfFp (FPSub r _ _) = r ∧
  firstRegOfFp (FPMul r _ _) = r ∧
  firstRegOfFp (FPDiv r _ _) = r ∧
  firstRegOfFp (FPFma r _ _) = r ∧
  firstRegOfFp (FPMov r _) = r ∧
  firstRegOfFp (FPMovToReg r _ _) = r ∧
  firstRegOfFp (FPMovFromReg r _ _) = r ∧
  firstRegOfFp (FPToInt r _) = r ∧
  firstRegOfFp (FPFromInt r _) = r
End

Definition are_reads_seen_def:
  are_reads_seen (Binop _ _ r1 (Reg r2)) data = (is_seen r1 data ∧ is_seen r2 data) ∧
  are_reads_seen (Binop _ _ r1 (Imm _)) data = (is_seen r1 data) ∧
  are_reads_seen (Div _ r1 r2) data = (is_seen r1 data ∧ is_seen r2 data) ∧
  are_reads_seen (Shift _ _ r _) data = is_seen r data ∧
  are_reads_seen _ data = T
End

Definition add_to_data_aux_def:
  add_to_data_aux data r i x =
    case mlmap$lookup data.instrs i of
    | SOME r' => (data with <| eq:=regsUpdate r' r data.eq; map:=insert r r' data.map; all_names:=insert r () data.all_names |>, Move 0 [(r,r')])
    | NONE    => (data with <| instrs:=insert data.instrs i r; all_names:=insert r () data.all_names |>, x)
End

Definition add_to_data_def:
  add_to_data data r x =
  let i = instToNumList x in
    add_to_data_aux data r i (Inst x)
End

Definition is_store_def:
  is_store Load = F ∧
  is_store Load8 = F ∧
  is_store Store = T ∧
  is_store Store8 = T
End

Definition is_complex_def:
  is_complex (Binop _ _ _ _) = F ∧
  is_complex (Div _ _ _) = F ∧
  is_complex (Shift _ _ _ _) = F ∧
  is_complex _ = T
End

Definition word_cseInst_def:
  (word_cseInst (data:knowledge) Skip = (data, Inst Skip)) ∧
  (word_cseInst data (Const r w) =
   if is_seen r data then (empty_data with all_names:=data.all_names, Inst (Const r w)) else
     add_to_data data r (Const r w)) ∧
  (word_cseInst data (Arith a) =
   let r = firstRegOfArith a in
     let a' = canonicalArith data a in
       if is_seen r data ∨ is_complex a' ∨ ¬are_reads_seen a' data then
         (empty_data with all_names:=data.all_names, Inst (Arith a'))
       else
         add_to_data data r (Arith a')) ∧
  (word_cseInst data (Mem op r (Addr r' w)) =
   if is_store op then
     (data, Inst (Mem op (canonicalRegs data r) (Addr (canonicalRegs data r') w)))
   else
     if is_seen r data then
       (empty_data with all_names:=data.all_names, Inst (Mem op r (Addr (canonicalRegs data r') w)))
     else
       (data, Inst (Mem op r (Addr (canonicalRegs data r') w))) ) ∧
  (word_cseInst data ((FP f):'a inst) =
            (empty_data with all_names:=data.all_names, Inst (FP f)))
  (* Not relevant: issue with fp regs having same id as regs, possible confusion
            let f' = canonicalFp inst_map och_map f in
            let r = firstRegOfFp f' in
            let i = instToNumList ((FP f'):'a inst) in
            case mlmap$lookup inst_instrs i of
            | SOME r' => (n+1, regsUpdate r' r inst_eq, insert r r' inst_map, inst_instrs, Move 0 [(r,r')])
            | NONE    => (n, inst_eq, inst_map, insert inst_instrs i r, Inst (FP f')))
   *)
End

(*
Principle:
  We keep track of a map containing all instructions already dealt with,
    and we explore the program to find instuctions matching one in the map.
  If we find one, we change the instruction by a simple move and we keep track
    of the registers equivalence.
  If we don't find any, depending on the instruction, we store it into the map
    under the shape of an num list.
Signification of the terms:
    r -> registers or imm_registers
    rs-> multiple registers associations ((num # num) list) (For the Move)
    i -> instructions
    e -> expressions
    x -> "store_name"
    p -> programs
    c -> comparisons
    m -> num_set
    b -> binop
    s -> string
*)
Definition word_cse_def:
  (word_cse (data:knowledge) (Skip) =
                (data, Skip)) ∧
  (word_cse data (Move r rs) =
            let (data', rs') = canonicalMoveRegs3 data rs in
                (data', Move r rs')) ∧
  (word_cse data (Inst i) =
            let (data', p) = word_cseInst data i in
                (data', p)) ∧
  (word_cse data (Assign r e) =
                (data, Assign r e)) ∧
  (word_cse data (Get r x) =
            if is_seen r data then (empty_data with all_names:=data.all_names, Get r x) else (data, Get r x)) ∧
  (word_cse data (Set x e) =
            let e' = canonicalExp data e in
            if x = CurrHeap then
                (empty_data with all_names:=data.all_names, Set x e')
            else
                (data, Set x e'))∧
  (word_cse data (Store e r) =
                (data, Store e r)) ∧
  (word_cse data (MustTerminate p) =
            let (data', p') = word_cse data p in
                (data', MustTerminate p')) ∧
  (word_cse data (Call ret dest args handler) =
                (empty_data, Call ret dest args handler)) ∧
  (word_cse data (Seq p1 p2) =
            let (data1, p1') = word_cse data p1 in
            let (data2, p2') = word_cse data1 p2 in
                (data2, Seq p1' p2')) ∧
  (word_cse data (If c r1 r2 p1 p2) =
            let r1' = canonicalRegs data r1 in
            let r2' = canonicalImmReg data r2 in
            let (data1, p1') = word_cse data p1 in
            let (data2, p2') = word_cse data p2 in
                (empty_data with all_names:=data.all_names, If c r1' r2' p1' p2')) ∧
                (* We don't know what happen in the IF. Intersection would be the best. *)
  (word_cse data (Alloc r m) =
                (empty_data with all_names:=data.all_names, Alloc r m)) ∧
  (word_cse data (Raise r) =
                (data, Raise r)) ∧
  (word_cse data (Return r1 r2) =
                (data, Return r1 r2)) ∧
  (word_cse data (Tick) =
                (data, Tick)) ∧
  (word_cse data ((OpCurrHeap b r1 r2):'a prog) =
    if is_seen r1 data ∨ ¬is_seen r2 data then (empty_data, OpCurrHeap b r1 r2) else
      let r2' = canonicalRegs data r2 in
        let pL = OpCurrHeapToNumList b r2' in
          add_to_data_aux data r1 pL (OpCurrHeap b r1 r2')) ∧
  (word_cse data (LocValue r l) =
                if is_seen r data then (empty_data with all_names:=data.all_names, LocValue r l) else (data, LocValue r l)) ∧
  (word_cse data (Install p l dp dl m) =
                (empty_data with all_names:=data.all_names, Install p l dp dl m)) ∧
  (word_cse data (CodeBufferWrite r1 r2) =
                (empty_data with all_names:=data.all_names, CodeBufferWrite r1 r2)) ∧
  (word_cse data (DataBufferWrite r1 r2) =
                (empty_data with all_names:=data.all_names, DataBufferWrite r1 r2)) ∧
  (word_cse data (FFI s p1 l1 p2 l2 m) =
                (empty_data with all_names:=data.all_names, FFI s p1 l1 p2 l2 m))
End


(*
EVAL “word_cse empty_data (Seq (Inst (Arith (Binop Add 3 1 (Reg 2)))) (Inst (Arith (Binop Add 4 1 (Reg 2)))))”

EVAL “word_cse empty_data
    (Seq
      (Inst (Arith (Binop Add 3 1 (Reg 2))))
    (Seq
      (Inst (Arith (Binop Add 4 1 (Reg 2))))
    (Seq
      (Inst (Arith (Binop Sub 5 1 (Reg 3))))
      (Inst (Arith (Binop Sub 6 1 (Reg 4))))
    )))
”
*)

val _ = export_theory ();
