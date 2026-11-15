#!/usr/bin/env bash
# Time the per-case costs the parity suites pay: a bare pwsh start, a pwsh
# start that dot-sources aitools-lib.ps1, and bash sourcing aitools-lib.sh.
set -euo pipefail
ROOT=/Users/new-jose/repos/aitools
t() { local s e; s=$(perl -MTime::HiRes=time -e 'printf "%.3f", time'); "$@" > /dev/null 2>&1; e=$(perl -MTime::HiRes=time -e 'printf "%.3f", time'); perl -e "printf '%.2f', $e - $s"; }
printf 'aitools-lib.ps1 size: %s bytes\n' "$(wc -c < "$ROOT/scripts/aitools-lib.ps1" | tr -d ' ')"
printf 'aitools-lib.sh  size: %s bytes\n' "$(wc -c < "$ROOT/scripts/aitools-lib.sh" | tr -d ' ')"
for i in 1 2 3; do
    a=$(t pwsh -NoProfile -Command 'exit 0')
    b=$(t pwsh -NoProfile -Command ". '$ROOT/scripts/aitools-lib.ps1'; exit 0")
    c=$(t bash -c ". '$ROOT/scripts/aitools-lib.sh'; exit 0")
    printf 'run %s: pwsh bare %ss  pwsh+lib %ss  bash+lib %ss\n' "$i" "$a" "$b" "$c"
done
