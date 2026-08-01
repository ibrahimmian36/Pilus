/-
Millennium Research — machine-checked defect certificate for the
formal-conjectures rendering of Erdős Problem 486.

Audited file : FormalConjectures/ErdosProblems/486.lean
fc commit    : 735aee074327b8e78b0d92bb1ee8ea00937c3f51 (2026-08-01)

The right-hand side of `Erdos486.erdos_486` is transcribed VERBATIM below
(only the `answer(sorry) ↔` wrapper is dropped, since `answer` is the
benchmark's own metadata attribute and `sorry` would contaminate the
axiom set). `Set.HasLogDensity` is fc's own definition, imported, not
restated.

What is certified here: fc's rendering places NO constraint on the
modulus `n`, so `n = 0` is admitted, and in Mathlib `ZMod 0 = ℤ`. The
single row `X 0 ⊆ ℤ` can therefore delete an arbitrary set of naturals
outright. Consequently fc's statement is equivalent to the assertion
that EVERY subset of ℕ has a logarithmic density — a statement with no
arithmetic content, false by classical oscillating examples.

This defect is independent of, and additional to, the omission of the
`m > n` activation threshold.
-/

import FormalConjecturesForMathlib.Data.Set.Density

namespace MR486Defect

open Set

/-- fc's `erdos_486` right-hand side, transcribed verbatim. -/
def FCAssertion : Prop :=
  ∀ X : (n : ℕ) → Set (ZMod n), ∃ d,
    {m : ℕ | ∀ n, (m : ZMod n) ∉ X n}.HasLogDensity d

/-- The witness. `ZMod 0` is `ℤ`, so row `0` may name an arbitrary set of
integers; every other row is left empty. -/
def badX (S : Set ℕ) : (n : ℕ) → Set (ZMod n)
  | 0 => {z : ℤ | ∃ m : ℕ, m ∉ S ∧ (m : ℤ) = z}
  | (_ + 1) => ∅

/-- Row `0` alone carves out an arbitrary set: fc's `B` ranges over ALL
subsets of ℕ. -/
theorem fc_B_arbitrary (S : Set ℕ) :
    {m : ℕ | ∀ n, (m : ZMod n) ∉ badX S n} = S := by
  ext m
  simp only [Set.mem_setOf_eq]
  constructor
  · intro h
    by_contra hm
    exact h 0 ⟨m, hm, rfl⟩
  · rintro hm (_ | k)
    · rintro ⟨m', hm', he⟩
      have hmm : m' = m := by exact_mod_cast he
      subst hmm
      exact hm' hm
    · exact Set.notMem_empty _

/-- fc's statement of Erdős 486 carries no arithmetic content: it is
equivalent to "every set of naturals has a logarithmic density". -/
theorem fc_assertion_iff_all_sets :
    FCAssertion ↔ ∀ S : Set ℕ, ∃ d, S.HasLogDensity d := by
  constructor
  · intro h S
    have hS := h (badX S)
    rwa [fc_B_arbitrary S] at hS
  · intro h X
    exact h _

/-! ### The obvious fix does not close the hole

Adding the missing `m > n` activation threshold — the fix suggested by the
site's 2026-01-11 correction — does NOT repair the statement, because for
`0 < m` the modulus `n = 0` satisfies `n < m` and so is always active. A
positivity constraint on the modulus is needed as well. (Wang's
`Statement.lean` gets this right by quantifying over `A ⊆ ℕ` with `0 ∉ A`;
fc's own `erdos_25`, the singleton special case, gets it right via
`∀ i, 0 < seq_n i`.) -/

/-- fc's statement with the activation threshold restored but still no
positivity constraint on the modulus. -/
def FCAssertionThresholded : Prop :=
  ∀ X : (n : ℕ) → Set (ZMod n), ∃ d,
    {m : ℕ | 0 < m ∧ ∀ n, n < m → (m : ZMod n) ∉ X n}.HasLogDensity d

/-- Even with the threshold, row `0` still carves out an arbitrary set of
positive naturals. -/
theorem fc_thresholded_B_arbitrary (S : Set ℕ) (hS : 0 ∉ S) :
    {m : ℕ | 0 < m ∧ ∀ n, n < m → (m : ZMod n) ∉ badX S n} = S := by
  ext m
  simp only [Set.mem_setOf_eq]
  constructor
  · rintro ⟨hpos, h⟩
    by_contra hm
    exact h 0 hpos ⟨m, hm, rfl⟩
  · intro hm
    refine ⟨Nat.pos_of_ne_zero (fun h => hS (h ▸ hm)), ?_⟩
    rintro (_ | k) _
    · rintro ⟨m', hm', he⟩
      have hmm : m' = m := by exact_mod_cast he
      subst hmm
      exact hm' hm
    · exact Set.notMem_empty _

/-- So the thresholded statement is still contentless: it asserts that every
set of positive naturals has a logarithmic density. -/
theorem fc_thresholded_iff_all_sets :
    FCAssertionThresholded ↔ ∀ S : Set ℕ, 0 ∉ S → ∃ d, S.HasLogDensity d := by
  constructor
  · intro h S hS
    have hSd := h (badX S)
    rwa [fc_thresholded_B_arbitrary S hS] at hSd
  · intro h X
    exact h _ (fun hc => absurd hc.1 (lt_irrefl 0))

end MR486Defect

-- Axiom manifest for this certificate.
#print axioms MR486Defect.fc_B_arbitrary
#print axioms MR486Defect.fc_assertion_iff_all_sets
#print axioms MR486Defect.fc_thresholded_B_arbitrary
#print axioms MR486Defect.fc_thresholded_iff_all_sets
