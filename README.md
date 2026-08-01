# Erdős #486: independent kernel-level verification of a negative answer

Third-party verification of a claimed resolution of
[Erdős #486](https://www.erdosproblems.com/486): *let A ⊆ ℕ and choose
X_n ⊆ ℤ/nℤ for each n ∈ A; let*

$$B=\{m\in\mathbb{N}: m \bmod n\notin X_n \text{ for every } n\in A \text{ with } n<m\}.$$

*Must B have a logarithmic density?* Erdős recorded the question as
Problem I.26 in 1961. Davenport–Erdős proved **yes** for the
sets-of-multiples case X_n = {0}; the general question stayed open. In
July 2026 Shouqiao Wang claimed **no**, with a Lean 4 formalization.

This repository holds the artifacts of our independent replay. The
statement verified is:

```lean
/-- Erdős Problem 486 has a negative answer. -/
theorem erdos486_negative : ¬Erdos486Assertion
```

together with `erdos486_quantitativeCounterexample`, which strengthens it
to liminf L_B ≤ 177/200 and 49/50 ≤ limsup L_B. Both depend on axioms
exactly `propext`, `Classical.choice`, `Quot.sound` — as do all 492
theorems in the compiled namespace. There is no `sorry`, no
`native_decide`, no bespoke axiom: **the disproof is unconditional**,
which a good fraction of Lean-closed Erdős problems are not.

Full report: **[reports/erdos-486.md](reports/erdos-486.md)**.

## What is new here, and what is not

The mathematics is **not ours**. It is Shouqiao Wang's, produced with
GPT-5.6 Sol under iterative human prompting as he discloses. We claim no
part of it, and this repository contains none of his code. The problem
and its lineage belong to Erdős, and to Davenport–Erdős, Besicovitch and
Behrend in the surrounding results.

The contribution here is **epistemic**. On the claim thread the site
owner said he was inclined to wait for a formalized version rather than
check a delicate ad hoc construction line by line. Wang posted one the
next day, and until this audit nobody had checked it. What we add is an
independent replay from a cleared build tree; a mechanically enforced
axiom gate over every theorem in the development rather than the
headline two; an external kernel re-check of the compiled environment;
an exact-arithmetic re-derivation of the construction's constants,
independent of the Lean development; and a report that states its own
limits as plainly as its results.

## The formal-conjectures statement of this problem is degenerate

Independently of Wang's work, and this would stand if his claim were
withdrawn tomorrow. The `m > n` activation delay is not a technicality —
it is what lets an infinite congruence system stay silent long enough
for the logarithmic average to recover, which is what makes the
oscillation possible. Terence Tao restored that condition to the problem
statement in January 2026, after Liam Price asked whether it belonged.

[`FormalConjectures/ErdosProblems/486.lean`](https://github.com/google-deepmind/formal-conjectures/blob/main/FormalConjectures/ErdosProblems/486.lean)
still omits it, six months and three edits later. It also places no
positivity constraint on the modulus, so `n = 0` is admitted — and in
Mathlib `ZMod 0 = ℤ`, so the single row `X 0 ⊆ ℤ` deletes an arbitrary
set of naturals. We certify in Lean, against formal-conjectures' own
`Set.HasLogDensity`, that its `erdos_486` therefore asserts only that
*every* subset of ℕ has a logarithmic density, and that **adding the
missing threshold alone does not repair it** — for `0 < m` the modulus
`n = 0` is still active. Both guards are needed. See
[`tools/MR486Defect.lean`](tools/MR486Defect.lean) and §5 of the report.

That repository's own `erdos_25` — the singleton special case of exactly
this problem — has both guards right. The general case and its own
special case currently disagree.

**Wang's theorem resolves the problem as the site states it. It does not
resolve formal-conjectures' version, which is a different and degenerate
statement, and it should not be recorded as doing so.**

## Contents

| Path | What it is |
|---|---|
| `reports/erdos-486.md` | The verification report: seven layers (six executed), the counterexample mechanism, the trust base, and what we did *not* verify |
| `tools/MRAxioms.lean` | The axiom manifest: `#print axioms` on both public theorems |
| `tools/AxiomSweep.lean` | Our mechanical sweep: every theorem in the compiled namespace via `CollectAxioms`, one memoized closure walk, so nothing hides behind a hand-kept manifest (492 theorems) |
| `tools/MR486Defect.lean` | Four theorems certified against formal-conjectures' own `Set.HasLogDensity`, showing its `erdos_486` is contentless and that the obvious fix still leaks |
| `probes/probe486.py` | Exact-rational corroboration of the block lemma's constants and the global assembly arithmetic, independent of the Lean development |
| `pods/pod_build.sh` | The from-source bootstrap: Lean toolchain compiled from source, mathlib rebuilt with no cache, checks re-run, `lean4checker` replay. **Staged, not executed** — see below |
| `logs/` | The replay, escape scan, per-module `lean4checker` run, probe output, and the defect certificate's axioms |

## Check it yourself

The audited code is **not** vendored here — clone it at the pinned commit:

```
git clone https://github.com/ShouqiaoW/erdos && cd erdos
git checkout 61325b10bbdc29f4fb5e0618b414b9f2189333ad
cd 486/lean
lake exe cache get && lake build        # 7,912 jobs, ~9 min on a laptop
```

Then drop in our two files and run both checks:

```
cp .../Pilus/tools/MRAxioms.lean .
cp .../Pilus/tools/AxiomSweep.lean .
lake env lean MRAxioms.lean     # the two public theorems
lake env lean AxiomSweep.lean   # our sweep: 492 theorems
```

Each prints `depends on axioms: [propext, Classical.choice, Quot.sound]`,
and the sweep prints `AXIOM SWEEP PASS`. Expected output is quoted
verbatim in the report.

The external `lean4checker` replay must be run **one module per
process**. The umbrella pattern is a prefix match: it pulls in all 27
modules plus the full mathlib environment and was killed at 16 GB
(exit 137). The per-module loop is in the report.

The from-source bootstrap is `pods/pod_build.sh`. **We have not run it**
— it needs ≥ 32 GB, which the audit machine does not have — and the
report claims only Layers 0–6 accordingly. The script fixes the
provenance defect our Erdős 1002 run exposed: it archives itself into
the results directory as its first action, and every `lean4checker`
pattern logs its own exit code, so the logs evidence exactly the
coverage a report may claim.

## Attribution

The audited formalization is © its author and is **not** redistributed
here; at the audited commit `ShouqiaoW/erdos` carried no license file.
The formal-conjectures statements transcribed in `tools/MR486Defect.lean`
are from
[formal-conjectures](https://github.com/google-deepmind/formal-conjectures)
(Apache-2.0, The Formal Conjectures Authors) at `735aee074327`.
[`lean4checker`](https://github.com/leanprover/lean4checker) is by the
Lean FRO. The activation-threshold correction is due to Liam Price, who
raised the question, and Terence Tao, who checked Erdős's 1961 statement
and answered it the same day. The problem, its history, and the comment
threads that map the terrain are hosted at
[erdosproblems.com](https://www.erdosproblems.com) (Thomas Bloom).

## Citing

```bibtex
@misc{mian2026erdos486verification,
  title  = {Independent Kernel-Level Verification of a Claimed Negative
            Resolution of Erd\H{o}s Problem 486},
  author = {Ibrahim Mian and Shayaan Siddique},
  year   = {2026},
  note   = {Millennium Research},
  url    = {https://github.com/ibrahimmian36/Pilus}
}
```

Our related work on Erdős problems:
[centurion](https://github.com/ibrahimmian36/centurion) (#7,
[arXiv:2607.25628](https://arxiv.org/abs/2607.25628)),
[Optio](https://github.com/ibrahimmian36/Optio) (#364), and
[Tesserarius](https://github.com/ibrahimmian36/Tesserarius) (#1002). The
name continues that line: the *primus pilus* was the senior centurion of
a Roman legion, who held the first century of the first cohort — the
rank you reached by having been right often enough to be trusted with
the front.

## License

[Apache 2.0](LICENSE). Copyright 2026 Millennium Research
(Ibby Mian, Shayaan Siddique); developed with Claude. Covers **our**
files only.

Contact: ibrahimnmian@gmail.com
