#!/usr/bin/env bash
# Fetch PR diffs and file lists for remediation cross-checks (scratch, read-only).
set -euo pipefail
out="/Users/new-jose/repos/aitools/.scratch/session-remedwr/prs"
mkdir -p "$out"
for n in 98 99 100 101 102 103 104 105 106 108 109 110 111 112 113 114 115 116; do
    if gh pr diff "$n" -R nobul-tech/aitools > "$out/pr$n.diff"; then
        printf '%s ok %s lines\n' "$n" "$(wc -l < "$out/pr$n.diff")"
    else
        printf '%s FAILED\n' "$n"
    fi
done
