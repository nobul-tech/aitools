#!/usr/bin/env bash
set -uo pipefail
W=C:/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
cd "$W"
for f in scripts/setup-user-hooks.sh scripts/setup-user-skills.sh; do
    if bash -n "$f"; then echo "bash -n OK: $f"; else echo "bash -n FAIL: $f"; fi
done
pwsh -NoProfile -File "$W/.scratch/session-M2-B2/parse.ps1" "$W/scripts/setup-user-hooks.ps1" "$W/scripts/setup-user-skills.ps1"
echo "--- git diff --summary"
git diff --summary -- scripts/setup-user-hooks.sh scripts/setup-user-hooks.ps1 scripts/setup-user-skills.sh scripts/setup-user-skills.ps1
echo "--- ls-files -s"
git ls-files -s scripts/setup-user-hooks.sh scripts/setup-user-skills.sh
echo "--- mode vs origin/main"
git ls-tree origin/main scripts/setup-user-hooks.sh scripts/setup-user-skills.sh scripts/setup-user-hooks.ps1 scripts/setup-user-skills.ps1
echo "--- diff --stat"
git diff --stat -- scripts/setup-user-hooks.sh scripts/setup-user-hooks.ps1 scripts/setup-user-skills.sh scripts/setup-user-skills.ps1
echo "--- prompt text lines"
grep -n -E "User-created (hook|skill) detected|\[a\]dopt to dotprofile|read_menu_choice|Read-MenuChoice|read_tty_choice|Read-ConsoleChoice" scripts/setup-user-hooks.sh scripts/setup-user-hooks.ps1 scripts/setup-user-skills.sh scripts/setup-user-skills.ps1
echo "--- build-deploy prompt code"
grep -n -E "read_tty_choice|Read-ConsoleChoice|read_menu_choice|Read-MenuChoice|/dev/tty|ReadLine|Read-Host|\[a\]dopt|Reverse discovery|reverse_discover" scripts/build-deploy.sh
echo "build-deploy grep exit: $?"
echo "--- CRLF check ps1"
file scripts/setup-user-hooks.ps1 scripts/setup-user-skills.ps1
git diff -- scripts/setup-user-hooks.ps1 scripts/setup-user-skills.ps1 | perl -ne 'print "CRLF-mismatch line: $_" if /^\+/ && !/^\+\+\+/ && !/\r$/'
echo "done"
