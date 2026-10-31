#!/usr/bin/env bash
# Run local suites for files touched by PR #105 against the merge-commit tree, isolated HOME.
set -uo pipefail
T=/Users/new-jose/repos/aitools/.scratch/session-mg105/tree
export HOME=/Users/new-jose/repos/aitools/.scratch/session-mg105/home
cd "$T"
rc_all=0
echo "== bash -n scripts/aitools-profile.sh"
bash -n scripts/aitools-profile.sh; r=$?; echo "rc=$r"; [ $r -eq 0 ] || rc_all=1
echo "== pwsh parser scripts/aitools-profile.ps1"
pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("scripts/aitools-profile.ps1",[ref]$null,[ref]$e); if ($e) { $e; exit 1 } else { "PARSE OK" }'
r=$?; echo "rc=$r"; [ $r -eq 0 ] || rc_all=1
for t in tests/profile/test-config.sh tests/profile/test-lib.sh tests/profile/test-profile.sh tests/profile/test-user-init.sh tests/logging/test-logging.sh; do
  echo "== $t"
  bash "$t" > "/Users/new-jose/repos/aitools/.scratch/session-mg105/$(basename "$t").log" 2>&1
  r=$?
  tail -n 3 "/Users/new-jose/repos/aitools/.scratch/session-mg105/$(basename "$t").log"
  echo "rc=$r"; [ $r -eq 0 ] || rc_all=1
done
echo "== tests/logging/test-logging.ps1"
pwsh -NoProfile -File tests/logging/test-logging.ps1 > /Users/new-jose/repos/aitools/.scratch/session-mg105/test-logging.ps1.log 2>&1
r=$?
tail -n 3 /Users/new-jose/repos/aitools/.scratch/session-mg105/test-logging.ps1.log
echo "rc=$r"; [ $r -eq 0 ] || rc_all=1
echo "OVERALL rc=$rc_all"
exit $rc_all
