#!/usr/bin/env bash
# Sweeps the GroupV3 scenarios with one runner and writes the sweeps under OUT, one directory per
# scenario, as `sim matrix` reads them. Run it once per revision (base and head).
#
#   bash tools/sim/delivery-fix.sh RUNNER OUT [GROW_RUNS=10] [EPOCH_RUNS=2]
set -euo pipefail

RUNNER=${1:?usage: delivery-fix.sh RUNNER OUT [GROW_RUNS] [EPOCH_RUNS]}
OUT=${2:?usage: delivery-fix.sh RUNNER OUT [GROW_RUNS] [EPOCH_RUNS]}
GROW_RUNS=${3:-10}
EPOCH_RUNS=${4:-2}
SIM=$(cd "$(dirname "$0")" && pwd)

sweep() { # scenario runs
  [ -f "$OUT/$1/sweep.json" ] && { echo "skip $1 (already swept)"; return; }
  # A sweep exits 1 when a run went otherwise than its scenario expects; keep going.
  python3 "$SIM" sweep "$SIM/scenarios/$1.json" --runs "$2" --one-process "$RUNNER" --out "$OUT/$1" \
    | tail -1 | sed "s/^/$1: /" || true
}

mkdir -p "$OUT"
for loss in 0 0.1 0.5 1 5; do sweep "grow-waku-loss-$loss-groupv3" "$GROW_RUNS"; done
for loss in 0 0.1 1 5; do sweep "50-epochs-by-saro-waku-loss-$loss-groupv3" "$EPOCH_RUNS"; done
