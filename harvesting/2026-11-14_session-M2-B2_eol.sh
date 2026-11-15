#!/usr/bin/env bash
set -uo pipefail
W=C:/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
for f in scripts/setup-user-hooks.ps1 scripts/setup-user-skills.ps1 scripts/setup-user-hooks.sh scripts/setup-user-skills.sh; do
    perl -ne '$c++ if /\r\n$/; $l++ if /[^\r]\n$/; END { printf "%s: CRLF=%d LF-only=%d\n", $ARGV, $c//0, $l//0 }' "$W/$f"
done
git -C "$W" config --get core.autocrlf
git -C "$W" ls-files --eol scripts/setup-user-hooks.ps1 scripts/setup-user-skills.ps1 scripts/setup-user-hooks.sh scripts/setup-user-skills.sh
