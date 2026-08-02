/-
Copyright 2025 The Formal Conjectures Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-/

import FormalConjecturesUtil

/-!
# Erdős Problem 486: Logarithmic density for sets avoiding modular subsets

*Reference:* [erdosproblems.com/486](https://www.erdosproblems.com/486)
-/

namespace Erdos486

/--
For each $n \geq 1$ choose some $X_n \subseteq \mathbb{Z}/n\mathbb{Z}$.
Let $B$ be the set of $m \geq 1$ such that $m \not\equiv x \pmod n$ for every
$x \in X_n$ and every $n$ with $n < m$.
Must $B$ have a logarithmic density?

Two side conditions are essential to the statement.

The activation condition $n < m$: a modulus constrains $m$ only once $m$
exceeds it. It appears in Erdős's own formulation as $b \geq a_i$ in condition
(I.26.1) of [Er61, pp. 235-236], and on the problem page. Without it the
question is degenerate.

The positivity condition $0 < n$: in Mathlib `ZMod 0 = ℤ`, so admitting
$n = 0$ would let the single set $X_0 \subseteq \mathbb{Z}$ delete an
arbitrary set of naturals, and the statement would assert only that every
subset of $\mathbb{N}$ has a logarithmic density.

This generalises `Erdos25.erdos_25`, the case where each $X_n$ is a singleton;
that statement carries both conditions already.
-/
@[category research open, AMS 11]
theorem erdos_486 : answer(sorry) ↔
    ∀ X : (n : ℕ) → Set (ZMod n), ∃ d,
      {m : ℕ | 0 < m ∧ ∀ n, 0 < n → n < m →
        (m : ZMod n) ∉ X n}.HasLogDensity d := by
  sorry

end Erdos486
