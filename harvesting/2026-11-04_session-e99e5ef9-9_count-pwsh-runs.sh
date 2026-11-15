#!/usr/bin/env bash
# Run one test suite with a PATH shim that counts pwsh and git executions
# and the wall time spent inside pwsh. Usage: count-pwsh-runs.sh <suite.sh>
set -euo pipefail
SUITE="$1"
SHIM=$(mktemp -d)
LOG="$SHIM/calls.log"
: > "$LOG"
REAL_PWSH=$(command -v pwsh)
REAL_GIT=$(command -v git)
cat > "$SHIM/pwsh" <<EOF
#!/bin/bash
s=\$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
"$REAL_PWSH" "\$@"; rc=\$?
e=\$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
printf 'pwsh %s\n' "\$(perl -e "printf '%.3f', \$e - \$s")" >> "$LOG"
exit \$rc
EOF
cat > "$SHIM/git" <<EOF
#!/bin/bash
printf 'git 0\n' >> "$LOG"
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$SHIM/pwsh" "$SHIM/git"
s=$(date +%s)
PATH="$SHIM:$PATH" bash "$SUITE" > "$SHIM/suite.out" 2>&1 || echo "suite exit $?"
e=$(date +%s)
tail -n 1 "$SHIM/suite.out"
perl -ane '$n{$F[0]}++; $t{$F[0]} += $F[1]; END { printf "%s: %d runs, %.1fs inside\n", $_, $n{$_}, $t{$_} for sort keys %n }' "$LOG"
printf 'suite wall time: %ss\n' "$((e - s))"
