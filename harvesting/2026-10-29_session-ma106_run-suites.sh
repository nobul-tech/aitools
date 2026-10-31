#!/usr/bin/env bash
# run-suites.sh ROOT OUTDIR SUITE... : run each test suite under ROOT with an isolated HOME,
# log output per suite to OUTDIR, print a result line per suite. Scratch, not reusable.
set -euo pipefail
root="$1"; out="$2"; shift 2
mkdir -p "$out"
for s in "$@"; do
    name="$(basename "$s" .sh)"
    h="$out/home-$name"
    mkdir -p "$h"
    set +e
    ( cd "$root" ; HOME="$h" bash "$root/$s" ) > "$out/$name.log" 2>&1
    rc=$?
    set -e
    tailline="$(grep -E 'passed|PASS|FAIL|failed' "$out/$name.log" | tail -n 1)"
    printf '%s rc=%s %s\n' "$s" "$rc" "$tailline"
done
