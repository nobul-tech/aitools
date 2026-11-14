#!/usr/bin/env bash
# test-menu-parity.sh -- tests for scripts/check-menu-parity.pl, the logic of
# check-post-push step 29 ("Deployment menu parity audit"), and for step 29
# itself in both twins.
#
# Cases:
#   lib        the current scripts/aitools-lib.sh / .ps1 pair matches; every
#              menu-read call is found (4 per file today), the run-time prompt
#              counts as "?"
#   planted    a mismatch inside a read_menu_choice prompt (bash), inside a
#              Read-MenuChoice -Prompt (PowerShell), a letter dropped from a
#              [o/a/m/s/x] list, a printf menu line: each fails and is named;
#              the step 29 extraction before v0.77.2 misses the two prompt
#              mismatches (shown, so the gap stays visible)
#   fixtures   a prompt passed in a variable (bash p="...", PowerShell
#              $p = "...") resolves, a mismatch through it fails; calls in
#              comments and trailing comments do not count; Read-MenuChoice
#              in any letter case counts
#   errors     nothing found, usage, an unreadable file, --help
#   twins      the step 29 section of each twin (.sh in bash; .ps1 in pwsh
#              when installed), run with stub step functions against a copy
#              of the libs: PASS on the current pair, FAIL on a planted one
#
# Safe to re-run: writes only to a temp dir, removed on exit. Needs perl; the
# .ps1 twin case needs pwsh (skipped without it). Exit 1 if any case fails.
# Platform: macOS, Linux, Windows Git Bash (CI: linux and windows jobs).
# Usage: bash tests/check-post-push/test-menu-parity.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 27' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/scripts/check-menu-parity.pl"
SH_LIB="$ROOT/scripts/aitools-lib.sh"
PS1_LIB="$ROOT/scripts/aitools-lib.ps1"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
IS_WINDOWS=false
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;; esac

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$TMP_ROOT/out" ]; then
            perl -pe 's/^/      | /' "$TMP_ROOT/out" | tail -n 15
        fi
    fi
}

# native <path>: the path as native tools want it (C:/... on Windows)
native() { if $IS_WINDOWS; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# run_check <bash lib> <ps1 lib>: exit code in RC, output in $TMP_ROOT/out
run_check() {
    RC=0
    perl "$CHECK" "$1" "$2" > "$TMP_ROOT/out" 2>&1 || RC=$?
}

# plant <src> <dst> <perl substitution>: a copy with one change; fails the
# case (anchor gone) when the copy equals the source
plant() {
    perl -pe "$3" "$1" > "$2"
    if cmp -s "$1" "$2"; then
        printf 'FAIL plant anchor not found in %s (%s)\n' "$1" "$3"; FAIL=$((FAIL + 1))
        return 1
    fi
    return 0
}

# old_step29 <bash lib> <ps1 lib>: "match" or "mismatch" by the step 29
# extraction before v0.77.2 (printf / Console lines only)
old_step29() {
    o_ps1=$(perl -ne 'print "$1\n" if /Console.*Write.*\[(\w)\]/' "$2" | sort -u | paste -s -d , -)
    o_sh=$(perl -ne 'print "$1\n" if /printf.*\[(\w)\]/' "$1" | sort -u | paste -s -d , -)
    if [ "$o_ps1" = "$o_sh" ]; then echo match; else echo mismatch; fi
}

# --- The current libraries ------------------------------------------------------
run_check "$SH_LIB" "$PS1_LIB"
check "lib: the current pair matches (exit 0)" "[ $RC -eq 0 ]"
check "lib: summary names the menus and the prompts" "tail -n 1 '$TMP_ROOT/out' | grep -q '^menus a,m,o,s,x; prompts '"
check "lib: the AI-merge preview prompt [y]es/[r]efine/[n]o is extracted on both sides" \
    "grep -q '^  bash:[0-9]* n,r,y\$' '$TMP_ROOT/out' && grep -q '^  ps1:[0-9]* n,r,y\$' '$TMP_ROOT/out'"
N_SH=$(grep -c '^  bash:' "$TMP_ROOT/out")
N_PS1=$(grep -c '^  ps1:' "$TMP_ROOT/out")
check "lib: every call found, same count each side ($N_SH bash, $N_PS1 PS1; at least 4)" "[ $N_SH -ge 4 ] && [ $N_SH -eq $N_PS1 ]"
check "lib: the run-time prompt (choice [\$(...)]) counts as ?" "grep -q '^  bash:[0-9]* ?\$' '$TMP_ROOT/out' && grep -q '^  ps1:[0-9]* ?\$' '$TMP_ROOT/out'"

# --- Planted mismatches -----------------------------------------------------------
if plant "$SH_LIB" "$TMP_ROOT/planted-prompt.sh" 's/\[n\]o reject: "/[q]uit reject: "/'; then
    run_check "$TMP_ROOT/planted-prompt.sh" "$PS1_LIB"
    check "planted: read_menu_choice prompt [n]o -> [q]uit (bash) fails, named" \
        "[ $RC -eq 1 ] && tail -n 1 '$TMP_ROOT/out' | grep -q 'prompts only in bash: \[q,r,y\]' && tail -n 1 '$TMP_ROOT/out' | grep -q 'prompts only in PS1: \[n,r,y\]'"
    check "planted: the pre-v0.77.2 extraction misses that mismatch (the gap closed)" \
        "[ \"\$(old_step29 '$TMP_ROOT/planted-prompt.sh' '$PS1_LIB')\" = match ]"
fi
if plant "$PS1_LIB" "$TMP_ROOT/planted-prompt.ps1" 's/-Prompt "  \[y\]es accept \/ \[r\]efine/-Prompt "  [y]es accept \/ [e]dit/'; then
    run_check "$SH_LIB" "$TMP_ROOT/planted-prompt.ps1"
    check "planted: Read-MenuChoice -Prompt [r]efine -> [e]dit (PowerShell) fails, named" \
        "[ $RC -eq 1 ] && tail -n 1 '$TMP_ROOT/out' | grep -q 'prompts only in PS1: \[e,n,y\]'"
    check "planted: the pre-v0.77.2 extraction misses that mismatch too" \
        "[ \"\$(old_step29 '$SH_LIB' '$TMP_ROOT/planted-prompt.ps1')\" = match ]"
fi
if plant "$SH_LIB" "$TMP_ROOT/planted-list.sh" 's/"  choice \[o\/a\/m\/s\/x\]: "/"  choice [o\/a\/s\/x]: "/'; then
    run_check "$TMP_ROOT/planted-list.sh" "$PS1_LIB"
    check "planted: [o/a/m/s/x] -> [o/a/s/x] in a bash prompt fails" \
        "[ $RC -eq 1 ] && tail -n 1 '$TMP_ROOT/out' | grep -q 'prompts only in bash: \[a,o,s,x\]'"
fi
if plant "$SH_LIB" "$TMP_ROOT/planted-menu.sh" "s/printf '  \\[s\\]kip            :/printf '  [k]eep            :/"; then
    run_check "$TMP_ROOT/planted-menu.sh" "$PS1_LIB"
    check "planted: a printf menu line [s]kip -> [k]eep fails (menu letters)" \
        "[ $RC -eq 1 ] && tail -n 1 '$TMP_ROOT/out' | grep -q '^menu letters: bash '"
fi

# --- Fixtures ------------------------------------------------------------------------
cat > "$TMP_ROOT/var.sh" <<'EOF'
# read_menu_choice x "y n" n "no" "ctx" "  [z]ap: "   (a comment: not a call)
ask() {
    local prompt="  [y]es / [n]o: " other="x"
    read_menu_choice ans "y n" n "no" "ask $1" "$prompt"
    case "$ans" in
        *) : ;;  # n (read_menu_choice returns only y or n)
    esac
}
EOF
cat > "$TMP_ROOT/var.ps1" <<'EOF'
# $a = Read-MenuChoice -Valid @("z") -Prompt "  [z]ap: "   (a comment: not a call)
function Ask {
    $prompt = '  [y]es / [n]o: '
    $ans = read-menuchoice -Valid @("y", "n") -Default "n" -DefaultDesc "no" `
        -Context "ask $x" -Prompt $prompt   # trailing comment
}
EOF
run_check "$TMP_ROOT/var.sh" "$TMP_ROOT/var.ps1"
check "fixture: prompts in variables resolve and match (exit 0, n,y)" \
    "[ $RC -eq 0 ] && grep -q '^  bash:4 n,y\$' '$TMP_ROOT/out' && grep -q '^  ps1:4 n,y\$' '$TMP_ROOT/out'"
check "fixture: commented-out calls and the trailing comment do not count (one call each)" \
    "[ \"\$(grep -c '^  bash:' '$TMP_ROOT/out')\" = 1 ] && [ \"\$(grep -c '^  ps1:' '$TMP_ROOT/out')\" = 1 ]"
perl -pe 's/\[n\]o: /[c]ancel: /' "$TMP_ROOT/var.ps1" > "$TMP_ROOT/var2.ps1"
run_check "$TMP_ROOT/var.sh" "$TMP_ROOT/var2.ps1"
check "fixture: a mismatch through a variable fails" "[ $RC -eq 1 ] && tail -n 1 '$TMP_ROOT/out' | grep -q 'prompts only in PS1: \[c,y\]'"

# --- Errors ------------------------------------------------------------------------
: > "$TMP_ROOT/empty.sh"
: > "$TMP_ROOT/empty.ps1"
run_check "$TMP_ROOT/empty.sh" "$TMP_ROOT/empty.ps1"
check "nothing found in either file: exit 1" "[ $RC -eq 1 ] && grep -q 'extraction broken' '$TMP_ROOT/out'"
RC=0
perl "$CHECK" "$SH_LIB" > "$TMP_ROOT/out" 2>&1 || RC=$?
check "one argument: exit 2 (usage)" "[ $RC -eq 2 ] && grep -q 'usage' '$TMP_ROOT/out'"
run_check "$TMP_ROOT/does-not-exist.sh" "$PS1_LIB"
check "unreadable file: exit 2" "[ $RC -eq 2 ] && grep -q 'cannot read' '$TMP_ROOT/out'"
RC=0
perl "$CHECK" --help > "$TMP_ROOT/out" 2>&1 || RC=$?
check "--help: exit 0, prints the usage" "[ $RC -eq 0 ] && grep -q 'check-menu-parity.pl BASH_LIB PS1_LIB' '$TMP_ROOT/out'"

# --- The twins' step 29 ------------------------------------------------------------
# section <script> <out>: step 29, from its "# 29." heading to the "# 30." heading
section() {
    perl -ne 's/\r$//; $p = 1 if /^# 29\. /; $p = 0 if /^# 30\. /; print if $p' "$1" > "$2"
}
# A fake repo root with scripts/check-menu-parity.pl and a lib pair
mk_repo() {  # <dir> <bash lib> <ps1 lib>
    mkdir -p "$1/scripts"
    cp "$CHECK" "$1/scripts/check-menu-parity.pl"
    cp "$2" "$1/scripts/aitools-lib.sh"
    cp "$3" "$1/scripts/aitools-lib.ps1"
}
mk_repo "$TMP_ROOT/repo-ok" "$SH_LIB" "$PS1_LIB"
if [ -f "$TMP_ROOT/planted-prompt.sh" ]; then
    mk_repo "$TMP_ROOT/repo-bad" "$TMP_ROOT/planted-prompt.sh" "$PS1_LIB"
fi

section "$ROOT/scripts/check-post-push.sh" "$TMP_ROOT/step29.sh"
check "sh twin: step 29 calls scripts/check-menu-parity.pl" "grep -q 'check-menu-parity.pl' '$TMP_ROOT/step29.sh'"
cat > "$TMP_ROOT/run29.sh" <<'EOF'
set -euo pipefail
step_pass() { printf 'PASS %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
step_fail() { printf 'FAIL %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
step_skip() { printf 'SKIP %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
EXTENSIVE=true
REPO_ROOT="$STEP_REPO"
. "$STEP_SECTION"
EOF
for v in ok bad; do
    [ -d "$TMP_ROOT/repo-$v" ] || continue
    rm -f "$TMP_ROOT/rec-sh-$v"
    RC=0
    STEP_REC="$TMP_ROOT/rec-sh-$v" STEP_REPO="$TMP_ROOT/repo-$v" STEP_SECTION="$TMP_ROOT/step29.sh" \
        bash "$TMP_ROOT/run29.sh" > "$TMP_ROOT/out" 2>&1 || RC=$?
    if [ "$v" = ok ]; then want='^PASS 29 PS1 and bash menus match: menus '; else want='^FAIL 29 .*prompts only in bash'; fi
    check "sh twin: step 29 on the $v pair: exit 0, $want" "[ $RC -eq 0 ] && grep -q '$want' '$TMP_ROOT/rec-sh-$v'"
done

section "$ROOT/scripts/check-post-push.ps1" "$TMP_ROOT/step29.ps1"
check "ps1 twin: step 29 calls scripts/check-menu-parity.pl" "grep -q 'check-menu-parity.pl' '$TMP_ROOT/step29.ps1'"
if ! command -v pwsh >/dev/null 2>&1; then
    printf 'SKIP ps1 twin run: pwsh not installed\n'; SKIP=$((SKIP + 1))
else
    cat > "$TMP_ROOT/run29.ps1" <<'EOF'
$ErrorActionPreference = "Stop"
function StepPass { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "PASS $n $d" }
function StepFail { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "FAIL $n $d" }
function StepSkip { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "SKIP $n $d" }
$Extensive = $true
$script:RepoRoot = $env:STEP_REPO
. $env:STEP_SECTION
EOF
    for v in ok bad; do
        [ -d "$TMP_ROOT/repo-$v" ] || continue
        rm -f "$TMP_ROOT/rec-ps1-$v"
        RC=0
        STEP_REC="$(native "$TMP_ROOT/rec-ps1-$v")" STEP_REPO="$(native "$TMP_ROOT/repo-$v")" \
            STEP_SECTION="$(native "$TMP_ROOT/step29.ps1")" \
            pwsh -NoProfile -NonInteractive -File "$(native "$TMP_ROOT/run29.ps1")" > "$TMP_ROOT/out" 2>&1 || RC=$?
        if [ "$v" = ok ]; then want='^PASS 29 PS1 and bash menus match: menus '; else want='^FAIL 29 .*prompts only in bash'; fi
        check "ps1 twin: step 29 on the $v pair: exit 0, $want" "[ $RC -eq 0 ] && grep -q '$want' '$TMP_ROOT/rec-ps1-$v'"
    done
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
