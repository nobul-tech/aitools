#!/usr/bin/env bash
# Run every tracked test suite (tests/**/test-*.{sh,py,ps1}) and record the
# result of each. Logs: <scratch>/suites/<name>.log; summary: suites-summary.txt.
set -euo pipefail
ROOT=/Users/new-jose/repos/aitools
OUT="$(cd "$(dirname "$0")" && pwd)/suites"
SUMMARY="$OUT/../suites-summary.txt"
mkdir -p "$OUT"
: > "$SUMMARY"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cd "$ROOT"
git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.py' 'tests/*/test-*.ps1' | while IFS= read -r t; do
    name=$(printf '%s' "$t" | tr '/' '_')
    log="$OUT/$name.log"
    case "$t" in
        *.sh)  cmd=(bash "$t") ;;
        *.py)  cmd=(python3 "$t") ;;
        *.ps1) cmd=(pwsh -NoProfile -File "$t") ;;
    esac
    start=$(date +%s)
    if "${cmd[@]}" > "$log" 2>&1 < /dev/null; then rc=0; else rc=$?; fi
    dur=$(( $(date +%s) - start ))
    if [ "$rc" -eq 0 ]; then st=PASS; else st=FAIL; fi
    printf '[%s] [run-all-suites] [%s] %s rc=%s %ss\n' "$(ts)" "$st" "$t" "$rc" "$dur" | tee -a "$SUMMARY"
done
printf '[%s] [run-all-suites] [info] done\n' "$(ts)" | tee -a "$SUMMARY"
