import Erdos486
import Lean

/-!
# Millennium Research full-environment axiom sweep (single-pass)

Enumerates every theorem in the `Erdos486` namespace and collects axiom
dependencies with ONE memoized `CollectAxioms` state threaded through all
of them (a single closure walk). Passes iff the union of axioms is a
subset of {propext, Classical.choice, Quot.sound}.
-/

open Lean Elab Command

def allowedAxioms : List Name :=
  [`propext, `Classical.choice, `Quot.sound]

run_cmd do
  let env ← getEnv
  let mut st : CollectAxioms.State := {}
  let mut count := 0
  for (n, ci) in env.constants.toList do
    unless (`Erdos486).isPrefixOf n do continue
    unless ci matches .thmInfo _ do continue
    count := count + 1
    let (_, st') := ((CollectAxioms.collect n).run env).run st
    st := st'
  let dirty := st.axioms.toList.filter (fun a => ¬ allowedAxioms.contains a)
  logInfo m!"theorems swept: {count}"
  logInfo m!"axiom union: {st.axioms.toList}"
  if dirty.isEmpty then
    logInfo m!"AXIOM SWEEP PASS: union ⊆ {allowedAxioms}"
  else
    logError m!"AXIOM SWEEP FAIL: disallowed axioms {dirty}"
