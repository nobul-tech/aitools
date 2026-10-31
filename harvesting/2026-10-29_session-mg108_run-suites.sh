#!/usr/bin/env bash
# run-suites.sh TREE LABEL -- run the suites PR #108 touches (and its consumers)
# under an isolated HOME. Scratch, not reusable.
set -uo pipefail
TREE="$1"
LABEL="$2"
S=/Users/new-jose/repos/aitools/.scratch/session-mg108
OUT="$S/logs/$LABEL"
mkdir -p "$OUT" "$S/home-$LABEL" "$S/aitlogs-$LABEL" "$S/cwd"
export HOME="$S/home-$LABEL"
export AITOOLS_LOG_DIR="$S/aitlogs-$LABEL"
cd "$S/cwd" || exit 9
rc_all=0
for t in test-profile test-config test-lib test-user-init; do
  bash "$TREE/tests/profile/$t.sh" > "$OUT/$t-bash5.log" 2>&1
  rc=$?
  AITOOLS_TEST_BASH=/bin/bash /bin/bash "$TREE/tests/profile/$t.sh" --bash-only > "$OUT/$t-bash32.log" 2>&1
  rc32=$?
  printf '%s bash5 rc=%s | %s\n' "$t" "$rc" "$(grep -Ei 'passed|failed' "$OUT/$t-bash5.log" | tail -n 1)"
  printf '%s bash32 rc=%s | %s\n' "$t" "$rc32" "$(grep -Ei 'passed|failed' "$OUT/$t-bash32.log" | tail -n 1)"
  if [ "$rc" -ne 0 ] || [ "$rc32" -ne 0 ]; then rc_all=1; fi
done
for f in scripts/aitools-profile.sh tests/profile/test-profile.sh; do
  bash -n "$TREE/$f" ; printf 'bash -n %s rc=%s\n' "$f" "$?"
  /bin/bash -n "$TREE/$f" ; printf '/bin/bash -n %s rc=%s\n' "$f" "$?"
done
perl -c "$TREE/scripts/aitools-json.pl" 2>&1
for f in scripts/aitools-profile.ps1 scripts/aitools-json.ps1; do
  pwsh -NoProfile -Command "\$e=\$null; \$null=[System.Management.Automation.Language.Parser]::ParseFile('$TREE/$f',[ref]\$null,[ref]\$e); if (\$e) { \$e; exit 1 } else { 'parse ok $f' }"
done
exit $rc_all
