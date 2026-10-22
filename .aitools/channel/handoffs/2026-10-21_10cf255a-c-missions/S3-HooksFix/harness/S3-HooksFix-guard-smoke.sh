#!/usr/bin/env bash
# S3-HooksFix-guard-smoke.sh -- smoke-test shared/hooks/standing-order-guard.sh
# with the sed check at enforce (hook-rollout.md "Pre-deploy verification").
# Runs every case under an isolated HOME. Test file: exempt from OS guard and
# lib sourcing (cross-platform.md "OS guard exemptions", scratch/test files).
#
# Usage: S3-HooksFix-guard-smoke.sh [worktree-root]
#   BASH_BIN=/bin/bash S3-HooksFix-guard-smoke.sh   # run the hook under bash 3.2
set -euo pipefail

WT="${1:-/Users/new-jose/repos/aitools/.claude/worktrees/sed-guard-enforce}"
HOOK="$WT/shared/hooks/standing-order-guard.sh"
FAKE_HOME="$WT/.scratch/session-S3-HooksFix/home-guard"
rm -rf "$FAKE_HOME"
mkdir -p "$FAKE_HOME"
LOGF="$FAKE_HOME/.aitools/logs/standing-order-guard.log"

pass=0
fail=0

# run_case <label> <expected-exit> <command as a JSON string body>
# Also asserts that no observe-log line is written (every check enforces).
run_case() {
    local label="$1" want="$2" cmd="$3"
    local before=0 after=0 rc=0
    if [ -f "$LOGF" ]; then before=$(wc -l < "$LOGF"); fi
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
        | HOME="$FAKE_HOME" "${BASH_BIN:-bash}" "$HOOK" 2>"$FAKE_HOME/stderr.txt" || rc=$?
    if [ -f "$LOGF" ]; then after=$(wc -l < "$LOGF"); fi
    local verdict=PASS
    if [ "$rc" != "$want" ] || [ "$after" -ne "$before" ]; then verdict=FAIL; fi
    if [ "$verdict" = PASS ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
    printf '%s | %-40s | exit=%s (want %s) | observe-log-lines=+%s | cmd: %s\n' \
        "$verdict" "$label" "$rc" "$want" "$((after - before))" "$cmd"
}

echo "hook: $HOOK"
echo "hook interpreter: ${BASH_BIN:-bash} ($("${BASH_BIN:-bash}" -c 'echo $BASH_VERSION'))"
echo "MODE_SED line: $(grep -n '^MODE_SED=' "$HOOK")"

echo "--- clean / read-only (exit 0) ---"
run_case "clean: git status"                0 "git status"
run_case "clean: ls -la"                    0 "ls -la"
run_case "sed -n '60,75p' file"             0 "sed -n '60,75p' file.txt"
run_case "sed -n 60,75p file (unquoted)"    0 "sed -n 60,75p file.txt"
run_case "sed -n 12p file"                  0 "sed -n 12p file.txt"
run_case "sed -n '\$p' file"                0 "sed -n '\$p' file.txt"
run_case "sed -n '100,\$p' file (to end)"   0 "sed -n '100,\$p' a.txt"
run_case "sed -n 1,5p two files"            0 "sed -n 1,5p a.txt b.txt"
run_case "#82 cmd: sed -n '60,75p' setup"   0 "sed -n '60,75p' scripts/setup-user-hooks.sh"
run_case "pipeline: git log | sed -n 1p"    0 "git log | sed -n 1p"
run_case "pipeline: git log | sed -n 1,3p"  0 "git log | sed -n 1,3p"
run_case "pipeline: ls | sed s/a/b/"        0 "ls | sed s/a/b/"

echo "--- sed write/edit forms outside a pipeline (exit 2) ---"
run_case "sed -i s/a/b/ file"               2 "sed -i s/a/b/ file.txt"
run_case "sed -i '' 's/a/b/' file (BSD)"    2 "sed -i '' 's/a/b/' file.txt"
run_case "sed 's/a/b/w out' f"              2 "sed 's/a/b/w out' f"
run_case "sed s/a/b/ f > g"                 2 "sed s/a/b/ f > g"
run_case "sed s/a/b/ f (plain)"             2 "sed s/a/b/ f"
run_case "sed -n 1p -i file"                2 "sed -n 1p -i file.txt"
run_case "sed -n 1p --in-place file"        2 "sed -n 1p --in-place file.txt"
run_case "sed -n '1,5w out' file"           2 "sed -n '1,5w out.txt' file.txt"
run_case "sed -n 's/a/b/w out' file"        2 "sed -n 's/a/b/w out.txt' file.txt"
run_case "sed -n 1,5p file > out"           2 "sed -n 1,5p file.txt > out.txt"
run_case "sed -n '/foo/p' file (regex)"     2 "sed -n '/foo/p' file.txt"
run_case "sed -n 1p (stdin, no file)"       2 "sed -n 1p"

echo "--- other checks unchanged (exit 2) ---"
run_case "&& chain"                         2 "git status && git log"
run_case "|| chain"                         2 "git status || true"
run_case "; chain"                          2 "ls ; ls"
run_case "\$() substitution"                2 "echo \$(date)"
run_case "backtick substitution"            2 "echo \`date\`"
run_case "cat outside pipeline"             2 "cat file.txt"
run_case "head outside pipeline"            2 "head -5 file.txt"
run_case "tail outside pipeline"            2 "tail -5 file.txt"
run_case "awk outside pipeline"             2 "awk '{print}' file.txt"
run_case "rm glob"                          2 "rm -f *.tmp"
run_case "echo redirect"                    2 "echo hi > f.txt"
run_case "sed -n 1p a && ls (and-check)"    2 "sed -n 1p a.txt && ls"

echo "--- recorded limitation (first-token scope; see report) ---"
# Two-line command: line 1 matches the exemption, line 2 is a write-form sed.
# Exit 0 is the CURRENT behavior, asserted so a future change is noticed.
run_case "2-line: sed -n 1p f / sed s/a/b/wout f" 0 'sed -n 1p f\nsed s/a/b/wout f'

echo ""
echo "RESULT: $pass passed, $fail failed"
if [ -f "$LOGF" ]; then
    echo "--- observe log (expected absent) ---"
    cat "$LOGF"
fi
[ "$fail" -eq 0 ]
