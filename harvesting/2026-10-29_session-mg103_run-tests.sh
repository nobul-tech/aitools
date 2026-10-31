#!/usr/bin/env bash
# Post-merge local verification for PR #103 under an isolated HOME.
set -uo pipefail
R=/Users/new-jose/repos/aitools
S=$R/.scratch/session-mg103
IH=$S/home
mkdir -p "$IH"
export HOME="$IH"
cd "$R" || exit 1
rc=0
n=0
for f in scripts/aitools-lib.sh scripts/setup-user-claude.sh tests/managed-files/test-adopt-push.sh; do
    if bash -n "$f"; then echo "SYNTAX OK $f"; else echo "SYNTAX FAIL $f"; rc=1; fi
done
for f in scripts/aitools-lib.ps1 scripts/setup-user-claude.ps1 tests/managed-files/test-adopt-push.ps1; do
    pwsh -NoProfile -File "$S/parse.ps1" "$R/$f"
    if [ $? -eq 0 ]; then echo "PARSE OK $f"; else echo "PARSE FAIL $f"; rc=1; fi
done
run() {
    n=$((n + 1))
    echo "=== $* ==="
    "$@" > "$S/out-$n.log" 2>&1
    local e=$?
    tail -n 3 "$S/out-$n.log"
    echo "exit=$e"
    [ $e -eq 0 ] || rc=1
}
run bash tests/managed-files/test-adopt-push.sh
run pwsh -NoProfile -File tests/managed-files/test-adopt-push.ps1
run bash tests/managed-files/test-managed-files.sh
run pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1
echo "OVERALL rc=$rc"
exit $rc
