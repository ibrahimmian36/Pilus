#!/usr/bin/env bash
# Erdős 486 maximal-verification BUILD pod.
# Usage: COMPILER=gcc ./pod_build.sh   (or COMPILER=clang)
#
# Self-contained Layer 7 bootstrap: pins every commit, builds the Lean
# toolchain FROM SOURCE, rebuilds mathlib with NO cache, re-runs our three
# checks, and replays the compiled environment through lean4checker.
#
# PROVENANCE FIX (this is the defect recorded in the Erdős 1002 run, see
# audit1002/pod_results/SCRIPT_PROVENANCE.txt): the executed script copies
# ITSELF into the results directory as its very first action, and every
# lean4checker pattern is logged with its own exit code so the archived log
# evidences exactly the coverage the report claims. Do not claim a pattern
# was checked unless its PASS line appears in lean4checker_full.log.
#
# Hard cap: WALL_CAP seconds, then results tarball + idle.
set -u
export DEBIAN_FRONTEND=noninteractive

COMPILER="${COMPILER:-gcc}"                 # gcc | clang
WALL_CAP="${WALL_CAP:-43200}"               # 12h hard cap (486 is small)
SMOKE="${SMOKE:-0}"                          # SMOKE=1: cheap preflight only
L4C_PAT_CAP="${L4C_PAT_CAP:-5400}"           # per-pattern lean4checker cap, 90 min
WANG_COMMIT=61325b10bbdc29f4fb5e0618b414b9f2189333ad
MATHLIB_REV=a3a10db0e9d66acbebf76c5e6a135066525ac900
LEAN_TAG=v4.27.0
L4C_TAG=v4.27.0
WORK=/workspace/audit486
OUT=$WORK/results
mkdir -p "$WORK" "$OUT"

# ---- PROVENANCE: archive the executed script BEFORE doing anything else ----
cp -- "$0" "$OUT/pod_build.EXECUTED.sh" 2>/dev/null || true
sha256sum -- "$0" > "$OUT/pod_build.EXECUTED.sha256" 2>/dev/null || true

MANIFEST=$OUT/MANIFEST.txt
: > "$MANIFEST"
note() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$MANIFEST"; }
note "pod_build.sh compiler=$COMPILER cap=${WALL_CAP}s host=$(uname -mrs)"
note "executed script archived to results/pod_build.EXECUTED.sh"

finish() {
  if [ "$SMOKE" = "1" ]; then return 0; fi
  note "packaging results"
  ( cd "$WORK" && tar czf /workspace/results_build486_${COMPILER}.tar.gz results ) || true
  note "tarball: /workspace/results_build486_${COMPILER}.tar.gz"
  while true; do
    echo "*** RESULTS READY: download /workspace/results_build486_${COMPILER}.tar.gz then TERMINATE ***"
    sleep 300
  done
}
trap finish EXIT

main() {
set -x
# ---------- stage 0: deps ----------
apt-get update -qq
apt-get install -y -qq git curl cmake make g++ clang libgmp-dev libuv1-dev \
  pkg-config ccache python3 || { note "STAGE0 FAIL apt"; exit 1; }
curl -sSf https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain none
export PATH="$HOME/.elan/bin:$PATH"
note "STAGE0 PASS deps"

CORES=$(nproc)
# RAM detection must be CONTAINER-aware. /proc/meminfo reports the HOST's
# memory inside a container, so on a cloud pod it wildly overstates what we
# may actually use: the Erdos 486 run on a 128 GB RunPod pod read 755 GB and
# the RAM-based clamp silently did nothing. Prefer the cgroup limit.
RAM_BYTES=""
if [ -r /sys/fs/cgroup/memory.max ]; then                      # cgroup v2
  v=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)
  [ "$v" != "max" ] && [ -n "$v" ] && RAM_BYTES=$v
elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then  # cgroup v1
  v=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)
  # v1 reports a sentinel near 2^63 when unlimited
  [ -n "$v" ] && [ "$v" -lt 9223372036854000000 ] 2>/dev/null && RAM_BYTES=$v
fi
if [ -n "$RAM_BYTES" ]; then
  RAM_GB=$(( RAM_BYTES / 1073741824 )); RAM_SRC=cgroup
else
  RAM_GB=$(awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo); RAM_SRC=meminfo-HOST
fi
JOBS=$(( RAM_GB / 3 < CORES ? RAM_GB / 3 : CORES )); [ "$JOBS" -lt 4 ] && JOBS=4
JOBS="${JOBS_OVERRIDE:-$JOBS}"
note "cores=$CORES ram=${RAM_GB}GB (source=$RAM_SRC) jobs=$JOBS"
[ "$RAM_SRC" = meminfo-HOST ] && note "WARN ram read from host meminfo; the RAM clamp may be ineffective in a container. Set JOBS_OVERRIDE to force."
# NOTE: lean4checker over the whole Erdos486 namespace needs the full mathlib
# environment resident. It was killed at 16 GB on the audit laptop. Size this
# pod at >= 32 GB or the STAGE4 umbrella pattern will die with exit 137.

if [ "$SMOKE" = "1" ]; then
  cd "$WORK"
  git clone --depth 1 --branch $LEAN_TAG https://github.com/leanprover/lean4 lean4-src \
    && note "SMOKE ok: lean4 $LEAN_TAG clone" || { note "SMOKE FAIL lean4 clone"; exit 1; }
  ( cd lean4-src && cmake --preset release > "$OUT/smoke_cmake.log" 2>&1 ) \
    && note "SMOKE ok: cmake configure" || { note "SMOKE FAIL cmake"; exit 1; }
  git clone --filter=blob:none https://github.com/ShouqiaoW/erdos wang_repo \
    && ( cd wang_repo && git checkout $WANG_COMMIT ) \
    && note "SMOKE ok: wang repo @ pinned commit" || { note "SMOKE FAIL wang clone"; exit 1; }
  grep -q "$MATHLIB_REV" wang_repo/486/lean/lake-manifest.json \
    && note "SMOKE ok: mathlib pin" || { note "SMOKE FAIL mathlib pin"; exit 1; }
  git ls-remote --exit-code https://github.com/leanprover/lean4checker "refs/tags/$L4C_TAG" >/dev/null \
    && note "SMOKE ok: lean4checker tag" || note "SMOKE WARN lean4checker tag missing"
  note "SMOKE PASS — rerun without SMOKE=1"
  exit 0
fi

# ---------- stage 1: Lean toolchain from source ----------
cd "$WORK"
[ -d lean4-src ] || git clone --depth 1 --branch $LEAN_TAG https://github.com/leanprover/lean4 lean4-src \
  || { note "STAGE1 FAIL clone"; exit 1; }
cd lean4-src
if [ "$COMPILER" = clang ]; then CC=clang; CXX=clang++; else CC=gcc; CXX=g++; fi
cmake --preset release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX \
  > "$OUT/toolchain_cmake.log" 2>&1 \
  && make -C build/release -j"$JOBS" > "$OUT/toolchain_make.log" 2>&1 \
  || { note "STAGE1 FAIL toolchain build"; tail -50 "$OUT/toolchain_make.log" >> "$MANIFEST"; exit 1; }
elan toolchain link lean-src "$WORK/lean4-src/build/release/stage1" 2>/dev/null || true
note "STAGE1 PASS toolchain from source ($COMPILER)"

# ---------- stage 2: Wang repo, pinned; NO cache; full source build ----------
cd "$WORK"
[ -d wang_repo ] || git clone https://github.com/ShouqiaoW/erdos wang_repo || { note "STAGE2 FAIL clone"; exit 1; }
cd wang_repo && git checkout $WANG_COMMIT || { note "STAGE2 FAIL checkout"; exit 1; }
git rev-parse HEAD > "$OUT/wang_head.txt"
cd 486/lean
elan override set lean-src
grep -q "$MATHLIB_REV" lake-manifest.json || { note "STAGE2 FAIL mathlib pin mismatch"; exit 1; }
# NO cache: purge any prefetched build artifacts. ProofWidgets' fetched release
# is retained (UI/JS bundle); its oleans are re-kernel-checked in stage 4.
for d in .lake/packages/*/; do
  case "$(basename "$d")" in
    proofwidgets|ProofWidgets) ;;
    *) rm -rf "${d}.lake/build" ;;
  esac
done
rm -rf .lake/build
# NOTE: Lake 5.0.0 (Lean 4.27.0) exposes NO job-count option: neither -j nor
# --jobs is accepted, and `lake build -j` is a hard error. Parallelism is
# therefore left to Lake, and the RAM clamp above governs only the toolchain
# build. Size the pod correctly; do not assume the clamp protects this stage.
LAKE_NUM_JOBS="$JOBS" lake build > "$OUT/lake_build.log" 2>&1 \
  || { note "STAGE2 FAIL lake build"; tail -80 "$OUT/lake_build.log" >> "$MANIFEST"; exit 1; }
note "STAGE2 PASS full from-source build (mathlib + Erdos486, no cache)"

# ---------- stage 3: our two checks ----------
cat > MRAxioms.lean <<'LEAN_EOF'
import Erdos486
#print axioms Erdos486.erdos486_negative
#print axioms Erdos486.erdos486_quantitativeCounterexample
LEAN_EOF
cat > AxiomSweep.lean <<'LEAN_EOF'
import Erdos486
import Lean
open Lean Elab Command
def allowedAxioms : List Name := [`propext, `Classical.choice, `Quot.sound]
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
LEAN_EOF
for f in MRAxioms AxiomSweep; do
  if lake env lean $f.lean > "$OUT/check_$f.log" 2>&1; then
    note "STAGE3 PASS $f"
  else
    note "STAGE3 FAIL $f"; tail -30 "$OUT/check_$f.log" >> "$MANIFEST"
  fi
done

# ---------- stage 4: lean4checker, per pattern, per exit code ----------
cd "$WORK"
git clone --depth 1 --branch $L4C_TAG https://github.com/leanprover/lean4checker \
  && cd lean4checker && elan override set lean-src \
  && lake build > "$OUT/l4c_build.log" 2>&1 \
  || { note "STAGE4 FAIL lean4checker build"; tail -30 "$OUT/l4c_build.log" >> "$MANIFEST"; }
git -C "$WORK/lean4checker" rev-parse HEAD > "$OUT/l4c_head.txt"
cd "$WORK/wang_repo/486/lean"
L4C=$WORK/lean4checker/.lake/build/bin/lean4checker
: > "$OUT/lean4checker_full.log"
L4C_FAIL=0
# ORDERING: the per-module Erdos486 replay is the output this audit actually
# needs, so it runs FIRST. The umbrella patterns below can each take hours
# (Mathlib especially) and a wall-cap hit during them must not cost us the
# result we came for. Each pattern also gets its own timeout so one cannot
# eat the whole cap.
echo "=== per-module Erdos486 (primary) ===" >> "$OUT/lean4checker_full.log"
L4C_MODFAIL=0
for f in Erdos486.lean Erdos486/*.lean; do
  M=$(echo "$f" | sed 's|/|.|g; s|\.lean$||')
  if timeout "$L4C_PAT_CAP" lake env "$L4C" "$M" >> "$OUT/lean4checker_full.log" 2>&1; then
    echo "L4C PASS module $M" | tee -a "$OUT/lean4checker_full.log" >> "$MANIFEST"
  else
    RC=$?
    echo "L4C FAIL module $M rc=$RC" | tee -a "$OUT/lean4checker_full.log" >> "$MANIFEST"
    L4C_MODFAIL=1
  fi
done
[ "$L4C_MODFAIL" = 0 ] && note "STAGE4a PASS lean4checker all Erdos486 modules" \
                       || note "STAGE4a PARTIAL lean4checker modules (see per-module lines)"

# Umbrella patterns, best effort, after the primary result is banked.
# Every pattern gets its own line WITH its exit code. The report may claim
# coverage only for patterns that show "L4C PASS" here. rc=124 means the
# pattern hit its timeout and was NOT checked — do not report it as passing.
for PAT in Erdos486 Batteries Aesop Qq ProofWidgets Plausible ImportGraph Cli LeanSearchClient Mathlib; do
  echo "=== pattern: $PAT ===" >> "$OUT/lean4checker_full.log"
  if timeout "$L4C_PAT_CAP" lake env "$L4C" "$PAT" >> "$OUT/lean4checker_full.log" 2>&1; then
    echo "L4C PASS $PAT" | tee -a "$OUT/lean4checker_full.log" >> "$MANIFEST"
  else
    RC=$?
    if [ "$RC" = 124 ]; then
      echo "L4C TIMEOUT $PAT (cap ${L4C_PAT_CAP}s) — NOT CHECKED" | tee -a "$OUT/lean4checker_full.log" >> "$MANIFEST"
    else
      echo "L4C FAIL rc=$RC $PAT" | tee -a "$OUT/lean4checker_full.log" >> "$MANIFEST"
    fi
    L4C_FAIL=1
  fi
done
[ "$L4C_FAIL" = 0 ] && note "STAGE4b PASS lean4checker all umbrella patterns" \
                    || note "STAGE4b PARTIAL lean4checker umbrella (see per-pattern lines)"

# ---------- stage 5: digests ----------
cd "$WORK/wang_repo/486/lean"
find .lake/build/lib/lean -name '*.olean' -exec sha256sum {} + | sort -k2 \
  > "$OUT/oleans_erdos486.sha256"
find .lake/packages/mathlib/.lake/build/lib/lean -name '*.olean' -exec sha256sum {} + 2>/dev/null \
  | sort -k2 > "$OUT/oleans_mathlib.sha256"
git -C .lake/packages/mathlib rev-parse HEAD > "$OUT/mathlib_head.txt" 2>/dev/null
note "STAGE5 PASS digests recorded"
note "ALL STAGES COMPLETE compiler=$COMPILER"
}

main &
MAIN_PID=$!
( sleep "$WALL_CAP" && note "WALL CAP HIT — killing main" && kill -TERM "$MAIN_PID" ) &
WD_PID=$!
wait "$MAIN_PID"; RC=$?
kill "$WD_PID" 2>/dev/null
trap - EXIT
finish
exit $RC
