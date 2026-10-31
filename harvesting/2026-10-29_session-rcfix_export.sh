#!/usr/bin/env bash
# export.sh REF OUTDIR PATH... -- export the given paths at REF into OUTDIR (git archive).
set -euo pipefail
ref="$1"; out="$2"; shift 2
mkdir -p "$out"
git -C /Users/new-jose/repos/aitools archive "$ref" -- "$@" | tar -xf - -C "$out"
echo "exported $ref -> $out"
