#!/usr/bin/env bash
# test-menu-choice.sh -- tests for the choice-menu read read_menu_choice in
# scripts/aitools-lib.sh: an offered answer is returned (case and surrounding
# whitespace ignored); an empty line, a word or a letter not offered prints
# "  please type one of a/b/c" and asks again; EOF returns the default with the
# EOF warning; every answer is logged at detail (deploy.log only); 50
# unrecognised answers in a row end with the default and a warning; the prompt
# is printed as data; READ_TTY_EOF=1 from read_tty_choice is honoured as EOF.
# The real menus end to end: deploy_managed_file's text review (with and
# without an adopt target), its JSON field review (a differing field and a
# field only in LOCAL) and the AI merge preview (a stub `claude` on PATH)
# re-ask on an empty line, a word or a letter not offered, then apply the
# offered answer; EOF at the review menu still overwrites; --force on a
# terminal and a non-interactive run show no menu and log no answer.
#
# Safe to re-run: every case runs in its own temp HOME and log dir, removed on
# exit. The real read_menu_choice and read_tty_choice run on a pseudo-terminal
# (tests/managed-files/pty-run.py, python3); the guard, flag and CR cases
# replace read_tty_choice with a stub inside the same pty run (the wrapper
# still writes to /dev/tty). Without a pty (python3 missing, or pywinpty not
# installed on Windows) the pty cases SKIP with the reason. The JSON cases
# need node (SKIP without it).
# Platform: macOS, Linux, Windows Git Bash (aitools-lib.sh also runs there).
# AITOOLS_TEST_BASH=/bin/bash runs the lib under another bash (macOS 3.2).
# Spec: .claude/rules/interactive-menus.md; reference/managed-file-deployment.md
# "Menus"; commander 2026-11-13: "no default or other characters should re-ask".
# Exit 1 if any case fails.
#
# Usage: bash tests/menus/test-menu-choice.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 29' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/aitools-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
IS_WINDOWS=false
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        IS_WINDOWS=true
        # Windows pty = pywinpty (ConPTY); python3 -c's failure means "not installed".
        if $HAVE_PTY && ! python3 -c 'import winpty' >/dev/null 2>&1; then HAVE_PTY=false; fi ;;
esac

# check <name> <command...>: PASS when the command succeeds
check() {
    local name="$1"; shift
    if "$@"; then
        printf 'PASS %s\n' "$name"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$name"; FAIL=$((FAIL + 1))
        # The terminal output may end without a newline (a prompt): add one
        if [ -f "$C/plain" ]; then perl -pe 's/^/      | /; $_ .= "\n" unless /\n\z/' "$C/plain" | tail -n 15; fi
        if [ -f "$C/logs/deploy.log" ]; then
            grep -E 'menu answer|\[warn\]' "$C/logs/deploy.log" | perl -pe 's/^/      log| /' | tail -n 10
        fi
    fi
}
not() { ! "$@"; }
# res_is <answer>: the snippet exited 0 and read_menu_choice set this answer
res_is() { [ "$(cat "$C/rc")" = 0 ] && [ "$(cat "$C/result" 2>/dev/null)" = "$1" ]; }
# occ_is <n> <fixed string> <file>: the string occurs exactly n times in the file
occ_is() {
    [ "$(perl -0777 -ne 'BEGIN { $s = shift @ARGV } $n++ while /\Q$s\E/g; END { print $n + 0 }' "$2" "$3")" = "$1" ]
}
# tty_occ <n> <fixed string>: occ_is on the terminal output ($C/plain). On
# Windows ConPTY re-renders the screen and may repeat a line it already sent, so
# there the count is a minimum (0 stays exact; the deploy.log counts are exact
# everywhere, and test-menu-choice.ps1 counts the hints exactly on Windows).
tty_occ() {
    if $IS_WINDOWS && [ "$1" -gt 0 ]; then
        [ "$(perl -0777 -ne 'BEGIN { $s = shift @ARGV } $n++ while /\Q$s\E/g; END { print $n + 0 }' "$2" "$C/plain")" -ge "$1" ]
    else
        occ_is "$1" "$2" "$C/plain"
    fi
}
has() { grep -qF -- "$1" "$2"; }

setup_case() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home" "$C/logs"
    : > "$C/summary"
    LOG="$C/logs/deploy.log"
}

# run_menu <input> [stub]: a fresh bash on a pty sources the lib, defines the
# stub (a read_tty_choice replacement) if given, calls read_menu_choice with
# MC_VALID / MC_DEFAULT / MC_DESC / MC_CTX / MC_PROMPT and writes the answer to
# $C/result and WARNINGS to $C/warnings. Terminal output -> $C/out, $C/plain.
run_menu() {
    local input="$1" stub="${2:-}"
    printf '%s\n' "set -euo pipefail" "source '$LIB'" "logging_init t" "$stub" \
        'ans=""' \
        'read_menu_choice ans "$MC_VALID" "$MC_DEFAULT" "$MC_DESC" "$MC_CTX" "$MC_PROMPT"' \
        "printf '%s' \"\$ans\" > '$C/result'" \
        "printf '%s' \"\$WARNINGS\" > '$C/warnings'" > "$C/snippet.sh"
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" TERM=xterm \
        MC_VALID="$MC_VALID" MC_DEFAULT="$MC_DEFAULT" MC_DESC="$MC_DESC" MC_CTX="$MC_CTX" MC_PROMPT="$MC_PROMPT" \
        python3 "$PTY" --input "$input" --log "$C/out" --timeout "${RUN_TIMEOUT:-30}" -- "$BASH_BIN" "$C/snippet.sh"
    echo $? > "$C/rc"
    # $C/plain: terminal output without OSC/CSI codes and carriage returns
    perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g; s/\e\[[0-9;?]*[A-Za-z]//g; s/\e[=>]//g; s/\r//g' "$C/out" > "$C/plain"
    [ -f "$LOG" ] || : > "$LOG"
}

# menu <valid> <default> <ctx> [prompt]: set the read_menu_choice arguments
menu() {
    MC_VALID="$1"; MC_DEFAULT="$2"; MC_DESC="overwrite"; MC_CTX="$3"; MC_PROMPT="${4:-  choice: }"
}

# ---------------------------------------------------------------------------
# Without a terminal: the lib defines the wrapper and the EOF flag
# ---------------------------------------------------------------------------
setup_case defined
printf '%s\n' "set -euo pipefail" "source '$LIB'" \
    "declare -F read_menu_choice > '$C/result'" "printf '%s' \"\$READ_TTY_EOF\" > '$C/flag'" > "$C/snippet.sh"
env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" "$BASH_BIN" "$C/snippet.sh" < /dev/null > "$C/out" 2>&1
echo $? > "$C/rc"
check "lib: read_menu_choice defined, READ_TTY_EOF starts at 0" \
    eval '[ "$(cat "$C/rc")" = 0 ] && has read_menu_choice "$C/result" && [ "$(cat "$C/flag")" = 0 ]'

if $HAVE_PTY; then
    # -----------------------------------------------------------------------
    # Real read_tty_choice on a pseudo-terminal
    # -----------------------------------------------------------------------
    # Default s (not o): an empty line taken as the default would end with s
    setup_case reask; menu "o a m s x" s reask
    run_menu '\n\nskip\nq\no\n'
    check "re-ask: empty, empty, word, letter not offered, then o -> o (default s not taken)" res_is o
    check "re-ask: 4 hints '  please type one of o/a/m/s/x'" tty_occ 4 "  please type one of o/a/m/s/x"
    check "re-ask: prompt printed before every read (5)" tty_occ 5 "  choice: "
    check "re-ask: 5 answers logged at detail" occ_is 5 "[detail] menu answer (reask): " "$LOG"
    check "re-ask: empty line logged as not offered" has '[detail] menu answer (reask): "" -> not one of o/a/m/s/x, asked again' "$LOG"
    check "re-ask: word logged as not offered" has '[detail] menu answer (reask): "skip" -> not one of o/a/m/s/x, asked again' "$LOG"
    check "re-ask: accepted answer logged" has '[detail] menu answer (reask): "o" -> o' "$LOG"
    check "re-ask: answers not on the console" not has "menu answer" "$C/plain"
    check "re-ask: no warning" not has "[warn]" "$LOG"
    if ! $IS_WINDOWS; then
        # ConPTY re-renders lines with cursor moves; the own-line check is POSIX only
        check "re-ask: hint on its own line" grep -qx -- "  please type one of o/a/m/s/x" "$C/plain"
    fi

    setup_case case-space; menu "o a m s x" o case-space
    run_menu '  S \n'
    check "case and whitespace: '  S ' -> s" res_is s
    check "case and whitespace: raw answer logged" has '[detail] menu answer (case-space): "  S " -> s' "$LOG"
    check "case and whitespace: no hint" tty_occ 0 "please type one of"

    setup_case word; menu "y yes n no" n word "  [y/n]: "
    run_menu 'Yes\n'
    check "word answer: 'Yes' with y/yes/n/no -> yes" res_is yes

    setup_case numbers; menu "1 2 n s" s numbers
    run_menu '3\n0\n2\n'
    check "numbers: 3 and 0 not offered, then 2 -> 2" res_is 2
    check "numbers: 2 hints '  please type one of 1/2/n/s'" tty_occ 2 "  please type one of 1/2/n/s"

    setup_case eof; menu "o a m s x" o eof
    run_menu '\x04'
    check "EOF: default returned" res_is o
    check "EOF: read_tty_choice warning logged" has "[warn] No input at prompt (EOF) -- defaulting to overwrite" "$LOG"
    check "EOF: logged at detail" has "[detail] menu answer (eof): EOF -> o" "$LOG"
    check "EOF: no hint" tty_occ 0 "please type one of"

    setup_case reask-eof; menu "o s x" o reask-eof
    run_menu '\n\x04'
    check "re-ask then EOF: default returned" res_is o
    check "re-ask then EOF: one hint, then EOF logged" \
        eval 'tty_occ 1 "  please type one of o/s/x" && has "[detail] menu answer (reask-eof): \"\" -> not one of o/s/x, asked again" "$LOG" && has "[detail] menu answer (reask-eof): EOF -> o" "$LOG"'

    setup_case prompt-data; menu "o s x" o prompt-data '  pick %s 100%: {0} '
    run_menu 'o\n'
    check "prompt printed as data: '%s 100%: {0}' literal" eval 'res_is o && has "  pick %s 100%: {0} " "$C/plain"'

    # -----------------------------------------------------------------------
    # Stubbed read_tty_choice (pty only for the wrapper's /dev/tty writes)
    # -----------------------------------------------------------------------
    # Closed input that read_tty_choice does not report: "" with no warning and
    # no flag, forever. The 50-try guard must end the loop.
    setup_case guard; menu "o s x" o guard
    RUN_TIMEOUT=90 run_menu "" 'read_tty_choice() { printf -v "$1" "%s" ""; }'
    check "50-try guard: default returned" res_is o
    check "50-try guard: warning logged" has "[warn] No valid answer after 50 tries at guard -- treating input as ended, defaulting to overwrite" "$LOG"
    check "50-try guard: 50 answers logged, 49 hints" \
        eval 'occ_is 50 "[detail] menu answer (guard): \"\" -> not one of o/s/x, asked again" "$LOG" && tty_occ 49 "  please type one of o/s/x"'

    # Contract flag: READ_TTY_EOF=1 with no warning is EOF
    setup_case flag; menu "o s x" o flag
    run_menu "" 'read_tty_choice() { READ_TTY_EOF=1; printf -v "$1" "%s" ""; }'
    check "READ_TTY_EOF=1: default returned, EOF logged" eval 'res_is o && has "[detail] menu answer (flag): EOF -> o" "$LOG"'
    check "READ_TTY_EOF=1: no warning, no hint" eval '[ "$(cat "$C/warnings")" = 0 ] && tty_occ 0 "please type one of"'

    # A trailing CR (Windows line ending) is trimmed
    setup_case cr; menu "o a s x" o cr
    run_menu "" 'read_tty_choice() { printf -v "$1" "a\r"; }'
    check "trailing CR trimmed: 'a<CR>' -> a" res_is a
else
    printf 'SKIP pty cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)\n'; SKIP=$((SKIP + 1))
fi

# ===========================================================================
# The real menus: deploy_managed_file (text review, JSON field review) and the
# AI merge preview
# ===========================================================================
# setup_dmf <name>: setup_case plus dest/, repo/ (a git repo: the adopt target)
# and bin/ (first on PATH: the stub claude)
setup_dmf() {
    setup_case "$1"
    mkdir -p "$C/dest" "$C/repo" "$C/bin"
    git -C "$C/repo" init -q
}
# stub_claude: a fake AI CLI that prints a fixed valid merge
stub_claude() {
    printf '#!/usr/bin/env bash\ncat > /dev/null\nprintf "# Title\\nmerged line\\n"\n' > "$C/bin/claude"
    chmod +x "$C/bin/claude"
}
# run_snip <snippet> [input]: a fresh bash sources the lib and runs the snippet.
# With input: on a pty, the keystrokes fed one line per prompt. Without: stdin
# is /dev/null (non-interactive). Terminal output -> $C/out, $C/plain.
run_snip() {
    local snippet="$1" input="${2:-}"
    printf '%s\n' "set -euo pipefail" "source '$LIB'" "logging_init t" "$snippet" > "$C/snippet.sh"
    local envs=(HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary"
        PATH="$C/bin:$PATH" TERM=xterm)
    if [ -n "$input" ]; then
        env -u AITOOLS_FORCE "${envs[@]}" python3 "$PTY" --input "$input" --log "$C/out" --timeout "${RUN_TIMEOUT:-60}" -- "$BASH_BIN" "$C/snippet.sh"
    else
        env -u AITOOLS_FORCE "${envs[@]}" "$BASH_BIN" "$C/snippet.sh" < /dev/null > "$C/out" 2>&1
    fi
    echo $? > "$C/rc"
    perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g; s/\e\[[0-9;?]*[A-Za-z]//g; s/\e[=>]//g; s/\r//g' "$C/out" > "$C/plain"
    [ -f "$LOG" ] || : > "$LOG"
}
# DMF: deploy_managed_file SOURCE=$SRCF to LOCAL=$DEST, adopt target $ADOPT
# ("" = none); the result goes to $C/result (res_is reads it)
DMF='deploy_managed_file "$(cat "$SRCF")" "$DEST" tool item "$ADOPT"; printf "%s" "$MANAGED_FILE_RESULT" > "$C/result"'
# json_is <file> <compact json>: the file's JSON without whitespace (the values
# used here have none)
json_is() { [ "$(perl -0777 -pe 's/\s+//g' "$1")" = "$2" ]; }
HAVE_NODE=true
command -v node >/dev/null 2>&1 || HAVE_NODE=false

# --- Without a terminal: no menu, no answer logged (unchanged behaviour) ---
setup_dmf dmf-noninteractive
printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
run_snip "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
check "non-interactive text review: overwrite, no menu" \
    eval 'res_is updated && grep -qx new "$C/dest/a.md" && ! has "choice [" "$C/plain" && [ ! -e "$C/repo/a.md" ]'
check "non-interactive text review: no answer logged" not has "menu answer" "$LOG"

if $HAVE_NODE; then
    setup_dmf dmf-json-noninteractive
    printf '{"a":1,"b":2}\n' > "$C/repo/c.json"; printf '{"a":9,"b":2,"z":0}\n' > "$C/dest/c.json"
    run_snip "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF"
    check "non-interactive JSON review: field overwritten, LOCAL-only kept, no menu" \
        eval 'res_is updated && json_is "$C/dest/c.json" "{\"a\":1,\"b\":2,\"z\":0}" && ! has "choice [" "$C/plain"'
    check "non-interactive JSON review: no answer logged" not has "menu answer" "$LOG"
fi

if $HAVE_PTY; then
    # --- Text review with an adopt target: empty, word, letter not offered, then s ---
    setup_dmf dmf-reask-adopt
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_snip "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" '\nskip\nq\ns\n'
    check "text review (adopt): empty, 'skip', 'q' re-ask, then s -> skipped" res_is skipped
    check "text review (adopt): LOCAL unchanged, nothing adopted" \
        eval 'grep -qx old "$C/dest/a.md" && [ ! -e "$C/repo/a.md" ]'
    check "text review (adopt): 3 hints '  please type one of o/a/m/s/x'" tty_occ 3 "  please type one of o/a/m/s/x"
    check "text review (adopt): prompt asked 4 times" tty_occ 4 "  choice [o/a/m/s/x]: "
    check "text review (adopt): 4 answers logged at detail" occ_is 4 "[detail] menu answer (review a.md): " "$LOG"
    check "text review (adopt): empty, word and letter logged as not offered" \
        eval 'has "[detail] menu answer (review a.md): \"\" -> not one of o/a/m/s/x, asked again" "$LOG" && has "[detail] menu answer (review a.md): \"skip\" -> not one of o/a/m/s/x, asked again" "$LOG" && has "[detail] menu answer (review a.md): \"q\" -> not one of o/a/m/s/x, asked again" "$LOG"'
    check "text review (adopt): s logged" has '[detail] menu answer (review a.md): "s" -> s' "$LOG"
    check "text review (adopt): skipped logged" has "Skipped: item (local differs from source" "$LOG"
    if ! $IS_WINDOWS; then
        # ConPTY may repeat lines it already sent; the exact menu count is POSIX only
        check "text review (adopt): re-ask prints the hint and the prompt, not the menu again" \
            occ_is 1 "  [s]kip            : nothing written; asked again next run" "$C/plain"
    fi

    # --- Text review without an adopt target: a and m are not offered ---
    setup_dmf dmf-reask-noadopt
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_snip "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" 'a\nm\no\n'
    check "text review (no adopt): a and m re-ask, then o -> updated" \
        eval 'res_is updated && grep -qx new "$C/dest/a.md"'
    check "text review (no adopt): 2 hints '  please type one of o/s/x'" tty_occ 2 "  please type one of o/s/x"
    check "text review (no adopt): a and m logged as not offered, o accepted" \
        eval 'has "[detail] menu answer (review a.md): \"a\" -> not one of o/s/x, asked again" "$LOG" && has "[detail] menu answer (review a.md): \"m\" -> not one of o/s/x, asked again" "$LOG" && has "[detail] menu answer (review a.md): \"o\" -> o" "$LOG"'
    check "text review (no adopt): no AI merge started, nothing adopted" \
        eval '! has "AI merge" "$C/plain" && [ ! -e "$C/repo/a.md" ]'

    # --- Text review: case and surrounding spaces ignored ---
    setup_dmf dmf-case-space
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_snip "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" ' O \n'
    check "text review: ' O ' -> o, updated, no hint" \
        eval 'res_is updated && grep -qx new "$C/dest/a.md" && tty_occ 0 "please type one of"'
    check "text review: raw answer logged" has '[detail] menu answer (review a.md): " O " -> o' "$LOG"

    # --- EOF at the review menu: overwrite (unchanged) ---
    setup_dmf dmf-eof
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_snip "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" '\x04'
    check "EOF at the review menu: overwrite" eval 'res_is updated && grep -qx new "$C/dest/a.md"'
    check "EOF at the review menu: warning and 'EOF -> o' logged, no hint" \
        eval 'has "[warn] No input at prompt (EOF) -- defaulting to overwrite" "$LOG" && has "[detail] menu answer (review a.md): EOF -> o" "$LOG" && tty_occ 0 "please type one of"'

    # --- --force on a terminal: no menu, no answer read or logged ---
    setup_dmf dmf-force
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_snip "export AITOOLS_FORCE=1; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" 'a\n'
    check "--force on a terminal: overwrite, no menu" \
        eval 'res_is updated && grep -qx new "$C/dest/a.md" && ! has "choice [" "$C/plain" && [ ! -e "$C/repo/a.md" ]'
    check "--force on a terminal: no answer logged" not has "menu answer" "$LOG"

    # --- AI merge preview: empty and a word re-ask, then y ---
    setup_dmf dmf-merge-reask
    stub_claude
    printf '# Title\nsource line\n' > "$C/repo/a.md"; printf '# Title\nlocal line\n' > "$C/dest/a.md"
    run_snip "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" 'm\n\nmaybe\ny\n'
    check "merge preview: empty and 'maybe' re-ask, then y -> accept & adopt" res_is "accept & adopt"
    check "merge preview: the merge in LOCAL and the repo" \
        eval 'grep -qx "merged line" "$C/dest/a.md" && cmp -s "$C/dest/a.md" "$C/repo/a.md"'
    check "merge preview: 2 hints '  please type one of y/r/n'" tty_occ 2 "  please type one of y/r/n"
    check "merge preview: m, the two re-asks and y logged" \
        eval 'has "[detail] menu answer (review a.md): \"m\" -> m" "$LOG" && has "[detail] menu answer (merge preview a.md): \"\" -> not one of y/r/n, asked again" "$LOG" && has "[detail] menu answer (merge preview a.md): \"maybe\" -> not one of y/r/n, asked again" "$LOG" && has "[detail] menu answer (merge preview a.md): \"y\" -> y" "$LOG"'

    # --- JSON field review: a differing field, then a field only in LOCAL ---
    if $HAVE_NODE; then
        setup_dmf dmf-json-reask
        printf '{"a":1,"b":2}\n' > "$C/repo/c.json"; printf '{"a":9,"b":2,"z":0}\n' > "$C/dest/c.json"
        run_snip "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" '\no\no\ns\n'
        check "json review: a: empty re-asks, then o; z (only in LOCAL): o re-asks, then s -> skipped" res_is skipped
        check "json review: a overwritten, z kept in LOCAL, the repo unchanged" \
            eval 'json_is "$C/dest/c.json" "{\"a\":1,\"b\":2,\"z\":0}" && json_is "$C/repo/c.json" "{\"a\":1,\"b\":2}"'
        check "json review: one hint '  please type one of o/a/s/x' (field a)" tty_occ 1 "  please type one of o/a/s/x"
        check "json review: one hint '  please type one of a/s/x' (field z: no overwrite)" tty_occ 1 "  please type one of a/s/x"
        check "json review: field a answers logged" \
            eval 'has "[detail] menu answer (json item: a): \"\" -> not one of o/a/s/x, asked again" "$LOG" && has "[detail] menu answer (json item: a): \"o\" -> o" "$LOG"'
        check "json review: field z answers logged" \
            eval 'has "[detail] menu answer (json item: z): \"o\" -> not one of a/s/x, asked again" "$LOG" && has "[detail] menu answer (json item: z): \"s\" -> s" "$LOG"'
    fi
else
    printf 'SKIP real-menu pty cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)\n'; SKIP=$((SKIP + 1))
fi
if ! $HAVE_NODE; then
    printf 'SKIP JSON review cases (node not on PATH)\n'; SKIP=$((SKIP + 1))
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
