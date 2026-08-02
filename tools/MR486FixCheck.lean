/-
Millennium Research — verification that the proposed fix to
FormalConjectures/ErdosProblems/486.lean actually closes the hole.

Proposing a fix is cheap. This file checks it. Against the CURRENT fc
statement we certified (see MR486Defect.lean) that row `X 0` can carve out
an arbitrary set of naturals, because `ZMod 0 = ℤ` and nothing requires
`0 < n`. Here we certify the converse for the PROPOSED statement: with the
`0 < n` guard in place, row `X 0` is never consulted at all, so the attack
is not merely inconvenienced, it is unavailable.
-/

import FormalConjecturesForMathlib.Data.Set.Density

namespace MR486FixCheck

open Set

/-- The proposed survivor set, transcribed from the fix. -/
def survivors (X : (n : ℕ) → Set (ZMod n)) : Set ℕ :=
  {m : ℕ | 0 < m ∧ ∀ n, 0 < n → n < m → (m : ZMod n) ∉ X n}

/-- **Row zero is inert.** Two congruence systems agreeing on every positive
modulus define the same survivor set, whatever they do at `n = 0`. So the
`ZMod 0 = ℤ` attack that refutes the current statement cannot be mounted
against the proposed one. -/
theorem row_zero_irrelevant (X Y : (n : ℕ) → Set (ZMod n))
    (h : ∀ n, 0 < n → X n = Y n) :
    survivors X = survivors Y := by
  ext m
  simp only [survivors, Set.mem_setOf_eq]
  constructor
  · rintro ⟨hm, hX⟩
    refine ⟨hm, fun n hn hnm hmem => hX n hn hnm ?_⟩
    rwa [h n hn]
  · rintro ⟨hm, hY⟩
    refine ⟨hm, fun n hn hnm hmem => hY n hn hnm ?_⟩
    rwa [← h n hn]

/-- In particular, an adversary may set row `0` to absolutely anything —
including all of `ℤ` — without changing the survivor set by a single
element. -/
theorem row_zero_unusable (X : (n : ℕ) → Set (ZMod n)) (S : Set ℤ) :
    survivors (fun n => match n with | 0 => S | (k + 1) => X (k + 1))
      = survivors X := by
  apply row_zero_irrelevant
  rintro (_ | k) hn
  · exact absurd hn (lt_irrefl 0)
  · rfl

/-- And the activation threshold is genuinely present: a modulus `n` with
`m ≤ n` imposes no constraint on `m`. -/
theorem threshold_active (X : (n : ℕ) → Set (ZMod n)) (m : ℕ) (hm : 0 < m)
    (h : ∀ n, 0 < n → n < m → (m : ZMod n) ∉ X n) :
    m ∈ survivors X :=
  ⟨hm, h⟩

end MR486FixCheck

#print axioms MR486FixCheck.row_zero_irrelevant
#print axioms MR486FixCheck.row_zero_unusable
#print axioms MR486FixCheck.threshold_active
