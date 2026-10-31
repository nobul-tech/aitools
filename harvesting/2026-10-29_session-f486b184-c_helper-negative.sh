#!/usr/bin/env bash
# helper-negative.sh -- unit-check only_review_diff_git against sample call logs
set -uo pipefail
TMP_ROOT=$(mktemp -d)
only_review_diff_git() {
    [ ! -s "$TMP_ROOT/fakegit.calls" ] || ! grep -qv -e ' diff --no-index ' "$TMP_ROOT/fakegit.calls"
}
t() {  # t NAME EXPECT(pass|fail) CONTENT
    printf '%s' "$3" > "$TMP_ROOT/fakegit.calls"
    if only_review_diff_git; then got=pass; else got=fail; fi
    if [ "$got" = "$2" ]; then echo "ok   $1 -> $got"; else echo "BAD  $1 -> $got (want $2)"; fi
}
t "empty log"             pass ""
t "one review diff call"  pass $'-c core.quotePath=false -c diff.suppressBlankEmpty=false diff --no-index --no-color -- /t/local /t/source\n'
t "two review diff calls" pass $'-c x=1 diff --no-index -- a b\n-c x=1 diff --no-index -- c d\n'
t "ls-files call"         fail $'-C /stage/aitools ls-files -z\n'
t "review + other call"   fail $'-c x=1 diff --no-index -- a b\nstatus --porcelain\n'
t "plain diff (not -no-index)" fail $'diff HEAD -- file\n'
rm -rf "$TMP_ROOT"
