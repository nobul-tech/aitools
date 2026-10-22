#!/usr/bin/env bash
# test-rules-fanout-cursor.sh -- tests for step 4 of scripts/setup-user-cursor.sh:
# the harness rules fan-out ~/.aitools/rules -> ~/.cursor/rules/*.mdc (convert
# .md to .mdc, copy everything else, preserve unmanaged files, review on diff).
#
# Safe to re-run: every case runs the real script in its own temp HOME (removed
# on exit) with stub rg/agent on PATH, so no installer runs and the real
# ~/.cursor is never touched. With pwsh on PATH, ConvertTo-CursorRule in
# setup-user-cursor.ps1 is checked against the bash converter (parity).
# Platform: macOS, Linux, Git Bash. Exit 1 if any case fails.
# Spec: .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-Cursor/
# S3-H-Cursor-research.md; .claude/rules/managed-file-deployment.md.
#
# Usage: bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 14' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/setup-user-cursor.sh"
SCRIPT_PS1="$ROOT/scripts/setup-user-cursor.ps1"
HELPER_PS1="$ROOT/tests/rules-fanout-cursor/convert-rule.ps1"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 25
        fi
    fi
}

# setup_case <name>: fresh HOME and stub bin (rg, agent: version only)
setup_case() {
    C="$TMP_ROOT/$1"
    H="$C/home"
    mkdir -p "$H" "$C/bin"
    printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$C/bin/rg"
    printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$C/bin/agent"
    chmod +x "$C/bin/rg" "$C/bin/agent"
    : > "$C/summary"
}

# seed_rules: a harness rules directory covering every source shape
seed_rules() {
    mkdir -p "$H/.aitools/rules/subdir"
    printf '## Plain rule\n\nAlways loaded.\n' > "$H/.aitools/rules/plain.md"
    printf -- '---\npaths:\n  - scripts/**\n  - "shared/**"\n---\n\n## Scoped rule\n\nBody with a table:\n\n| a | b |\n|---|---|\n' > "$H/.aitools/rules/scoped.md"
    printf -- '---\ndescription: native cursor rule\nalwaysApply: false\n---\nNative body.\n' > "$H/.aitools/rules/native.mdc"
    printf 'not a rule\n' > "$H/.aitools/rules/notes.txt"
    printf 'hidden\n' > "$H/.aitools/rules/.hidden.md"
    printf 'nested\n' > "$H/.aitools/rules/subdir/nested.md"
}

# run_script [args...]: run setup-user-cursor.sh non-interactively under the case HOME
run_script() {
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
        PATH="$C/bin:$PATH" bash "$SCRIPT" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

rc() { cat "$C/rc"; }
row() { grep -F "|cursor rules|" "$C/summary" | grep -v '^DETAIL' | tail -n 1; }
R="$TMP_ROOT/r"  # shorthand for the deployed rules dir, set per case

# --- converter golden cases (via the script's own function) ------------------
# Extract cursor_rule_from_md from the script and run it on sample inputs.
CONV="$TMP_ROOT/conv.sh"
perl -ne 'print if /^cursor_rule_from_md\(\) \{/ .. /^\}/' "$SCRIPT" > "$CONV"
GOLD="$TMP_ROOT/gold"
mkdir -p "$GOLD"
conv() { bash -c "source '$CONV'; cursor_rule_from_md '$1'"; }

printf 'Body line\n' > "$GOLD/nofm.md"
printf -- '---\nalwaysApply: true\n---\nBody line\n' > "$GOLD/nofm.want"
printf -- '---\npaths:\n  - a/**\n  - b/**\n---\nBody\n' > "$GOLD/paths.md"
printf -- '---\nglobs:\n  - a/**\n  - b/**\nalwaysApply: false\n---\nBody\n' > "$GOLD/paths.want"
printf -- '---\npaths: src/**/*.ts\ndescription: x\n---\nB\n' > "$GOLD/inline.md"
printf -- '---\nglobs: src/**/*.ts\ndescription: x\nalwaysApply: false\n---\nB\n' > "$GOLD/inline.want"
printf -- '---\ndescription: keep\nalwaysApply: true\n---\nB\n' > "$GOLD/native.md"
printf -- '---\ndescription: keep\nalwaysApply: true\n---\nB\n' > "$GOLD/native.want"
printf -- '---\n---\nB\n' > "$GOLD/emptyfm.md"
printf -- '---\nalwaysApply: true\n---\nB\n' > "$GOLD/emptyfm.want"
printf '\xEF\xBB\xBF---\r\npaths:\r\n  - x/**\r\n---\r\nB\r\n' > "$GOLD/crlf.md"
printf -- '---\nglobs:\n  - x/**\nalwaysApply: false\n---\nB\n' > "$GOLD/crlf.want"

for g in nofm paths inline native emptyfm crlf; do
    conv "$GOLD/$g.md" > "$GOLD/$g.got"
    check "convert: $g" "cmp -s '$GOLD/$g.got' '$GOLD/$g.want'"
done

# --- PS1 parity: ConvertTo-CursorRule gives the same bytes --------------------
if command -v pwsh >/dev/null 2>&1; then
    for g in nofm paths inline native emptyfm crlf; do
        pwsh -NoProfile -File "$HELPER_PS1" "$SCRIPT_PS1" "$GOLD/$g.md" "$GOLD/$g.ps1.got" > "$GOLD/$g.ps1.log" 2>&1
        check "parity ps1: $g" "cmp -s '$GOLD/$g.ps1.got' '$GOLD/$g.got'"
    done
else
    printf 'SKIP parity ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1))
fi

# --- case: missing ~/.aitools/rules -> info + OK n/a, nothing created ----------
setup_case missing
run_script
check "missing: exit 0" "[ \"\$(rc)\" = 0 ]"
check "missing: OK n/a row" "grep -qxF 'OK|cursor rules|n/a (no harness rules)' '$C/summary'"
check "missing: no ~/.cursor/rules" "[ ! -e '$H/.cursor/rules' ]"
check "missing: info log" "grep -q 'No harness rules at' '$C/out'"

# --- case: empty ~/.aitools/rules -> same n/a ---------------------------------
setup_case empty
mkdir -p "$H/.aitools/rules"
run_script
check "empty: exit 0" "[ \"\$(rc)\" = 0 ]"
check "empty: OK n/a row" "grep -qxF 'OK|cursor rules|n/a (no harness rules)' '$C/summary'"

# --- case: first run, rerun, edited target, --force ----------------------------
setup_case fanout
seed_rules
mkdir -p "$H/.cursor/rules"
printf -- '---\nalwaysApply: true\n---\nmine\n' > "$H/.cursor/rules/mine.mdc"
R="$H/.cursor/rules"
run_script
check "first: exit 0" "[ \"\$(rc)\" = 0 ]"
check "first: plain.md -> plain.mdc (alwaysApply true)" "[ \"\$(head -n 3 '$R/plain.mdc')\" = \"\$(printf -- '---\nalwaysApply: true\n---')\" ]"
check "first: scoped.md -> globs list, alwaysApply false" "grep -qx 'globs:' '$R/scoped.mdc' && grep -qx '  - scripts/\*\*' '$R/scoped.mdc' && grep -qx 'alwaysApply: false' '$R/scoped.mdc' && ! grep -q '^paths:' '$R/scoped.mdc'"
check "first: scoped body kept (table ---)" "grep -qxF '|---|---|' '$R/scoped.mdc'"
check "first: native.mdc copied unchanged" "cmp -s '$R/native.mdc' '$H/.aitools/rules/native.mdc'"
check "first: notes.txt copied as is" "cmp -s '$R/notes.txt' '$H/.aitools/rules/notes.txt'"
check "first: no .md left in target" "[ ! -e '$R/plain.md' ] && [ ! -e '$R/scoped.md' ]"
check "first: hidden file not deployed" "[ ! -e '$R/.hidden.mdc' ] && [ ! -e '$R/.hidden.md' ]"
check "first: subdirectory not deployed" "[ ! -e '$R/subdir' ] && grep -q 'Ignoring non-file in harness rules: subdir' '$C/out'"
check "first: user rule preserved" "[ \"\$(cat '$R/mine.mdc')\" = \"\$(printf -- '---\nalwaysApply: true\n---\nmine')\" ] && grep -q 'Preserved unmanaged rule: mine.mdc' '$C/out'"
check "first: OK row 4 added" "grep -qxF 'OK|cursor rules|4 added' '$C/summary'"

run_script
check "rerun: exit 0" "[ \"\$(rc)\" = 0 ]"
check "rerun: OK row 4 verified" "grep -qxF 'OK|cursor rules|4 verified' '$C/summary'"
check "rerun: no backups (nothing written)" "! ls '$R' | grep -q '\.bak\.'"

printf 'local edit\n' >> "$R/plain.mdc"
run_script
check "edited: exit 0" "[ \"\$(rc)\" = 0 ]"
check "edited: non-interactive overwrite" "grep -q 'plain.mdc -- overwriting (non-interactive)' '$C/out'"
check "edited: source content restored" "! grep -q 'local edit' '$R/plain.mdc'"
check "edited: backup kept, not loadable by Cursor" "ls '$R' | grep -q '^plain\.mdc\.bak\.' && ! ls '$R' | grep '\.bak\.' | grep -q '\.mdc$'"
check "edited: row reports 1 updated" "row | grep -q '|cursor rules|1 updated, 3 verified'"
check "edited: backup not reported as preserved" "! grep -q 'Preserved unmanaged rule: plain.mdc.bak' '$C/out'"

printf 'local edit 2\n' >> "$R/scoped.mdc"
run_script --force
check "force: exit 0" "[ \"\$(rc)\" = 0 ]"
check "force: overwrite (--force)" "grep -q 'scoped.mdc -- overwriting (--force)' '$C/out'"
check "force: source content restored" "! grep -q 'local edit 2' '$R/scoped.mdc'"

# --- case: duplicate target (x.md and x.mdc) -> first wins, ERROR, exit 1 -----
setup_case dup
mkdir -p "$H/.aitools/rules"
printf 'from md\n' > "$H/.aitools/rules/dup.md"
printf -- '---\nalwaysApply: true\n---\nfrom mdc\n' > "$H/.aitools/rules/dup.mdc"
run_script
check "dup: exit 1" "[ \"\$(rc)\" = 1 ]"
check "dup: first source (dup.md) wins" "grep -q 'from md' '$H/.cursor/rules/dup.mdc'"
check "dup: error names the duplicate" "grep -q 'Skipped duplicate: dup.mdc -> dup.mdc' '$C/out'"
check "dup: ERROR row" "grep -qxF 'ERROR|cursor rules|1 failed' '$C/summary'"

# --- case: dry run -> nothing written ------------------------------------------
setup_case dry
seed_rules
run_script --dry-run
check "dry: exit 0" "[ \"\$(rc)\" = 0 ]"
check "dry: no ~/.cursor/rules files" "[ ! -e '$H/.cursor/rules/plain.mdc' ]"
check "dry: would-create logged" "grep -q 'Would create: plain.mdc' '$C/out'"
check "dry: dry-run row" "grep -q '|cursor rules|dry run (no files written)' '$C/summary'"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
