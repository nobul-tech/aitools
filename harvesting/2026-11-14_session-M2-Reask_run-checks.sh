#!/usr/bin/env bash
# run-checks.sh ROOT OUTDIR -- run check-pre-commit, check-pre-push and
# check-post-push (-Extensive) from ROOT (Windows: the .ps1 twins), each to
# OUTDIR/<name>.log; print rc and the FAIL/WARN lines. Never passes -Fix
# (step 3 -Fix would run build-deploy.sh against the real HOME).
set -uo pipefail
ROOT="$1"; OUT="$2"
mkdir -p "$OUT"
for c in check-pre-commit check-pre-push "check-post-push -Extensive"; do
    name=${c%% *}
    ( cd "$ROOT" && pwsh -NoProfile -File "scripts/$name.ps1" ${c#"$name"} ) > "$OUT/$name.log" 2>&1
    rc=$?
    printf '== %s rc=%s\n' "$c" "$rc"
    perl -pe 's/\e\[[0-9;]*m//g' "$OUT/$name.log" | grep -iE 'FAIL|WARN|passed|summary' | tail -n 25
done
