# Erdős 486 from-source bootstrap — pod launch guide

One pod, CPU-only. You launch it; it archives its own results and then idles
loudly until you download them and terminate it.

## What this buys, and what it does not

**It does not make the theorem more likely to be true.** The kernel replay
and the axiom gate already establish that `erdos486_negative` is a theorem,
and the adversarial probes establish that the statement is not hollow. This
pod changes none of that.

What it buys is the **trust base**. Our laptop run used the distributed Lean
v4.27.0 binary and the community mathlib cache. This pod compiles the Lean
toolchain from source, rebuilds mathlib with the cache purged, re-runs the
checks, and replays the compiled environment through `lean4checker`. That
removes two pieces of infrastructure we currently take on faith, and adds an
x86 + gcc/clang leg to complement the laptop's ARM + Apple-clang leg.

So: run it for completeness and for the credibility of the practice, not
because the mathematics is in doubt. The report currently claims six of
seven layers and says so plainly; this closes the seventh.

## Why it cannot run on the laptop

Needs roughly 32 GB RAM and 50 GB disk. The audit machine has 16 GB RAM and
had ~23 GiB free. The 16 GB ceiling is also what killed the whole-namespace
`lean4checker` run (exit 137), forcing the per-module loop.

## Launch (RunPod)

1. Deploy → **CPU pod**. 64 vCPU / ≥192 GB RAM, container disk ≥80 GB.
   (RAM matters: mathlib elaboration peaks ~2.5 GB per job; the script
   self-limits jobs to RAM/3.)
2. Upload `pod_build.sh`, or `curl` it from the Pilus repo.
3. Preflight first — it is cheap and catches every fetch problem before you
   pay for six hours:

   ```
   SMOKE=1 bash pod_build.sh
   ```

   Expect `SMOKE PASS`. It verifies the lean4 tag clones, cmake configures,
   Wang's repo checks out at the pinned commit, the mathlib pin matches, and
   the lean4checker tag exists.

4. Then the real run:

   ```
   COMPILER=gcc bash pod_build.sh
   ```

   6–9 hours expected, 12-hour hard cap. Optionally repeat with
   `COMPILER=clang` on a second pod for a second compiler leg.

5. When it prints `RESULTS READY`, download
   `/workspace/results_build486_gcc.tar.gz` and **terminate the pod**. It
   does not self-terminate, deliberately: this template has no persistent
   volume, so stopping would erase the results.

## What to check in the results before claiming anything

The 1002 run taught us to distrust our own summaries here, so check the logs
rather than the narrative:

- `MANIFEST.txt` — every stage prints PASS/FAIL with a UTC timestamp.
- `pod_build.EXECUTED.sh` + `.sha256` — the script copies itself in as its
  first action, so this is provably the bytes that ran. The 1002 run did not
  do this and we had to publish a provenance caveat instead.
- `lean4checker_full.log` — every pattern logs its own exit code as
  `L4C PASS <pattern>` or `L4C FAIL rc=<n> <pattern>`. **Claim coverage only
  for patterns with a PASS line.** On the 1002 run the script looped ten
  patterns but the log evidenced one, and the report had to be walked back.
- `check_MRAxioms.log` and `check_AxiomSweep.log` — expect the same output
  as the laptop: the two theorems axiom-clean, and `theorems swept: 492` with
  `AXIOM SWEEP PASS`. **A different theorem count is a red flag**, not a
  rounding difference.
- `oleans_erdos486.sha256` — digests of the from-source build.

## Then

Update `reports/erdos-486.md`: Layer 7's verdict, the header line that
currently reads "Layers 0-6 pass; Layer 7 staged, not executed", the README's
"We have not run it", and the Contents table entry. Copy the logs into
`logs/pod-gcc/`. If any stage failed, say so in the report rather than
quietly dropping the layer.
