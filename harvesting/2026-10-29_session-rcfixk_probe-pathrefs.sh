#!/usr/bin/env bash
# probe-pathrefs.sh -- probe scripts/check-path-refs.py (a given copy) on a
# fixture repo: bare path in parentheses, backticked missing path, and the
# `scripts/aitools-json.pl/.ps1` pair form. Usage: probe-pathrefs.sh <checker.py>
set -uo pipefail
CHK="$1"
F="$(mktemp -d)"
mkdir -p "$F/.claude/rules" "$F/scripts" "$F/plans"
printf 'x\n' > "$F/scripts/aitools-json.pl"
printf 'x\n' > "$F/scripts/aitools-json.ps1"
printf 'x\n' > "$F/scripts/a.sh"
printf 'x\n' > "$F/scripts/a.ps1"
printf 'x\n' > "$F/plans/real.md"
{
    printf 'L1 bare in parens (see plans/missing-bare.md) here\n'
    printf 'L2 backticked `plans/missing-tick.md`\n'
    printf 'L3 pair pl `scripts/aitools-json.pl/.ps1`\n'
    printf 'L4 pair sh `scripts/a.sh/.ps1`\n'
    printf 'L5 bare existing (plans/real.md)\n'
    printf 'L6 home path ~/.claude/rules/missing-home.md\n'
    printf 'L7 bare missing pair scripts/nope.sh/.ps1 here\n'
    printf 'L8 url https://github.com/x/y/blob/main/reference/missing-url.md\n'
} > "$F/.claude/rules/probe.md"
git -C "$F" init -q
python3 "$CHK" --root "$F"
printf 'rc=%s\n' "$?"
