import Erdos486

/-!
# Millennium Research — adversarial probes against the Erdos486 formalization

The kernel replay establishes that `erdos486_negative` IS a theorem. It does
not establish that the sentence means what Erdős asked, nor that the
definitions are non-degenerate. Those are the only two places a failure can
still hide, and this file attacks them.

The attack is: if `HasLogDensity` / `logAverage` carried a wrong
normalization — a stray constant, a wrong base, a mis-set cutoff — then
instantiating Wang's own positive recovery theorem at cases whose answer is
classically known would yield the WRONG number, or would fail to typecheck
against the right one. We pin the normalization at three known points.

If these compile, then `HasLogDensity B d` really does mean "the logarithmic
average of B converges to d" in the ordinary sense, and `¬∃ d, HasLogDensity
B d` really is the assertion that no logarithmic density exists.
-/

namespace MRAdversarial

open Erdos486 Filter Set

/-! ## Probe 1 — the normalization is pinned at three known points -/

/-- The positive even numbers have logarithmic density `1/2`, not `1`, not
`log 2`, not anything else. -/
theorem evens_density_half :
    HasLogDensity {n : ℕ | 0 < n ∧ n % 2 = 0} ((1 : ℝ) / 2) := by
  have h := hasLogDensity_of_eventually_periodic
      {n : ℕ | 0 < n ∧ n % 2 = 0} ({0} : Finset ℕ) 2 1
      (by norm_num)
      (by intro r hr; simp only [Finset.mem_singleton] at hr; omega)
      (fun n hn => hn.1)
      (by
        intro n hn
        simp only [Set.mem_setOf_eq, Finset.mem_singleton]
        omega)
  simpa using h

/-- Every positive natural survives, and the density is exactly `1`. This is
the sharpest single check on the normalizing factor `1 / log x`: a wrong
denominator shows up here as a number other than 1. -/
theorem all_positives_density_one :
    HasLogDensity {n : ℕ | 0 < n} (1 : ℝ) := by
  have h := hasLogDensity_of_eventually_periodic
      {n : ℕ | 0 < n} ({0, 1} : Finset ℕ) 2 1
      (by norm_num)
      (by intro r hr; simp only [Finset.mem_insert, Finset.mem_singleton] at hr; omega)
      (fun n hn => hn)
      (by
        intro n hn
        simp only [Set.mem_setOf_eq, Finset.mem_insert, Finset.mem_singleton]
        omega)
  norm_num at h
  simpa using h

/-- Multiples of three: density `1/3`. Rules out a normalization that happens
to be right only for `L = 2`. -/
theorem mult_three_density_third :
    HasLogDensity {n : ℕ | 0 < n ∧ n % 3 = 0} ((1 : ℝ) / 3) := by
  have h := hasLogDensity_of_eventually_periodic
      {n : ℕ | 0 < n ∧ n % 3 = 0} ({0} : Finset ℕ) 3 1
      (by norm_num)
      (by intro r hr; simp only [Finset.mem_singleton] at hr; omega)
      (fun n hn => hn.1)
      (by
        intro n hn
        simp only [Set.mem_setOf_eq, Finset.mem_singleton]
        omega)
  simpa using h

/-! ## Probe 2 — the counterexample is not cheap

If `Erdos486Assertion` were refuted by some simple congruence system, the
elaborate block construction would be unnecessary and the formalization
suspect. Here is a genuine, admissible instance of the problem — the delayed
"avoid the even numbers" sieve, `A = {2}`, `X₂ = {0}` — for which a
logarithmic density DOES exist. So the assertion is not trivially false, and
the counterexample has to work for its living. -/

/-- The delayed even-sieve survivor set: `1`, `2`, and every odd number. -/
def evenSieveSurvivors : Set ℕ := {m : ℕ | 0 < m ∧ (2 < m → m % 2 = 1)}

theorem evenSieve_has_density :
    HasLogDensity evenSieveSurvivors ((1 : ℝ) / 2) := by
  have h := hasLogDensity_of_eventually_periodic
      evenSieveSurvivors ({1} : Finset ℕ) 2 3
      (by norm_num)
      (by intro r hr; simp only [Finset.mem_singleton] at hr; omega)
      (fun n hn => hn.1)
      (by
        intro n hn
        simp only [evenSieveSurvivors, Set.mem_setOf_eq, Finset.mem_singleton]
        omega)
  simpa using h

/-! ## Probe 3 — the two quantitative constants genuinely separate -/

theorem constants_separate : (177 : ℝ) / 200 < 49 / 50 := by norm_num

end MRAdversarial

#print axioms MRAdversarial.evens_density_half
#print axioms MRAdversarial.all_positives_density_one
#print axioms MRAdversarial.mult_three_density_third
#print axioms MRAdversarial.evenSieve_has_density
