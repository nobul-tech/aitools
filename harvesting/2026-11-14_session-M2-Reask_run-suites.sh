#!/usr/bin/env bash
# run-suites.sh ROOT OUTDIR [suite...] -- run test suites from ROOT, each to
# OUTDIR/<name>.log; print one summary line per suite (rc + last count line).
# A suite is tests/<dir>/<file>; .sh runs in bash, .ps1 in pwsh.
set -uo pipefail
ROOT="$1"; OUT="$2"; shift 2
mkdir -p "$OUT"
for t in "$@"; do
    name=$(printf '%s' "$t" | tr '/' '_')
    case "$t" in
        *.sh)  ( cd "$ROOT" && bash "$t" ) > "$OUT/$name.log" 2>&1; rc=$? ;;
        *.ps1) ( cd "$ROOT" && pwsh -NoProfile -File "$t" ) > "$OUT/$name.log" 2>&1; rc=$? ;;
    esac
    last=$(grep -E '[0-9]+ passed|passed:|PASS(ED)?[: ]+[0-9]+|failed' "$OUT/$name.log" | tail -n 1)
    printf 'rc=%s  %-55s %s\n' "$rc" "$t" "$last"
done
