#!/usr/bin/env bash
# test-managed-files.sh -- tests for the managed-file model in scripts/aitools-lib.sh:
# deploy_managed_file, prompt_diff_review, review_json_fields, the tracker,
# [x]abort (exit 2), and setup-user-claude.sh's CLAUDE.md adopt filter.
#
# Safe to re-run: every case runs in its own temp HOME, removed on exit.
# Interactive cases run on a pseudo-terminal (tests/managed-files/pty-run.py,
# python3). The AI merge uses a stub `claude` on PATH; no real AI is called.
# Platform: macOS, Linux (OS guard below; commander, 2026-11-14: "sh scripts
# and tests should only run on linux/mac and ps1 on windows"). On Windows,
# tests/managed-files/test-managed-files.ps1 tests the PowerShell side
# (aitools-lib.ps1). Exit 1 if any case fails.
# Spec: .claude/rules/agentic-standards.md "Managed-file review choices and
# merge"; reference/managed-file-deployment.md; .claude/rules/interactive-menus.md.
#
# Usage: bash tests/managed-files/test-managed-files.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/managed-files/test-managed-files.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/managed-files/test-managed-files.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 14' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/aitools-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
# Cleanup: make read-only test dirs writable, then remove. chmod's errors are
# irrelevant here (rm -rf reports anything it cannot remove).
trap 'chmod -R u+w "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false

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

# setup_case <name>: fresh HOME, log dir, a git repo for adopt targets, stub bin
setup_case() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home" "$C/dest" "$C/repo" "$C/bin"
    git -C "$C/repo" init -q
    : > "$C/summary"
}

# stub_claude <good|bad>: a fake AI CLI. good prints a fixed valid merge.
stub_claude() {
    if [ "$1" = "good" ]; then
        printf '#!/usr/bin/env bash\ncat > /dev/null\nprintf "# Title\\nmerged line\\n"\n' > "$C/bin/claude"
    else
        printf '#!/usr/bin/env bash\ncat > /dev/null\nprintf "Sure, here is the merge\\n"\n' > "$C/bin/claude"
    fi
    chmod +x "$C/bin/claude"
}

# run_lib <snippet> [input]: source the lib in a fresh bash under the case HOME.
# No input -> stdin is /dev/null (non-interactive). Input -> pty with keystrokes.
# The snippet writes what the test needs into $C. rc -> $C/rc.
run_lib() {
    local snippet="$1" input="${2:-}"
    printf '%s\n' "set -euo pipefail" "source '$LIB'" "logging_init t" "$snippet" > "$C/snippet.sh"
    # Terminal for the review-diff colour: TERM=$RUN_TERM (default xterm);
    # NO_COLOR is unset unless RUN_NO_COLOR is given.
    local envs=(HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary"
        PATH="$C/bin:$PATH" TERM="${RUN_TERM:-xterm}")
    if [ -n "${RUN_NO_COLOR:-}" ]; then envs+=(NO_COLOR="$RUN_NO_COLOR"); fi
    if [ -z "$input" ]; then
        env -u NO_COLOR "${envs[@]}" bash "$C/snippet.sh" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
    else
        env -u NO_COLOR "${envs[@]}" python3 "$PTY" --input "$input" --log "$C/out" -- bash "$C/snippet.sh"
        echo $? > "$C/rc"
    fi
    # $C/plain: the terminal output without colour codes and carriage returns
    perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g; s/\e[=>]//g; s/\r//g' "$C/out" > "$C/plain"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

result() { cat "$C/result" 2>/dev/null; }
ESC=$(printf '\033')
# has_line <file> <exact line>: the file has this line (fixed string, whole line)
has_line() { grep -qxF -- "$2" "$1"; }
DMF='deploy_managed_file "$(cat "$SRCF")" "$DEST" tool item "$ADOPT"; printf "%s" "$MANAGED_FILE_RESULT" > "$C/result"'

# ---------------------------------------------------------------------------
# Text files, non-interactive
# ---------------------------------------------------------------------------
setup_case created
printf 'hello\n' > "$C/src.md"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF"
check "created: missing LOCAL is written" "[ \"\$(result)\" = created ] && cmp -s '$C/src.md' '$C/dest/a.md'"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF"
check "verified: LOCAL == SOURCE writes nothing" "[ \"\$(result)\" = verified ]"
check "verified: no backup made" "! ls '$C/dest/'a.md.bak.* >/dev/null 2>&1"

setup_case overwrite
printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
check "non-interactive: SOURCE overwrites LOCAL" "[ \"\$(result)\" = updated ] && cmp -s '$C/src.md' '$C/dest/a.md'"
check "non-interactive: LOCAL backed up" "ls '$C/dest/'a.md.bak.* >/dev/null 2>&1"
check "non-interactive: adopt target untouched" "[ ! -e '$C/repo/a.md' ]"
check "non-interactive: no review diff, no colour" "! grep -q 'this machine' '$C/out' && ! grep -qF \"\${ESC}[31m\" '$C/out' && ! grep -qF \"\${ESC}[32m\" '$C/out'"

setup_case nostate
mkdir -p "$C/home/.aitools/deploy-state"; printf '{}' > "$C/home/.aitools/deploy-state/manifest.json"
printf 'x\n' > "$C/src.md"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF"
check "deploy state: old files left on disk, noted once (detail)" \
    "[ -f '$C/home/.aitools/deploy-state/manifest.json' ] && [ \"\$(grep -c 'deploy state is no longer used' '$LOG')\" = 1 ]"

setup_case readonly-dir
printf 'x\n' > "$C/src.md"; mkdir -p "$C/dest/ro"; chmod 555 "$C/dest/ro"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/ro/new.md' ADOPT=''; $DMF; deploy_managed_file 'y' '$C/dest/b.md' tool b ''; printf '%s' \"\$MANAGED_FILE_RESULT\" > '$C/result2'"
check "write failure: result failed, nothing left" "[ \"\$(result)\" = failed ] && [ ! -e '$C/dest/ro/new.md' ]"
check "write failure: log_error with the reason" "grep -q '\[error\] Failed: item: write failed' '$LOG'"
check "write failure: the run continues" "[ \"\$(cat '$C/result2')\" = created ] && [ \"\$(cat '$C/rc')\" = 0 ]"
chmod 755 "$C/dest/ro"

setup_case backup-fail
printf 'new\n' > "$C/src.md"; mkdir -p "$C/dest/ro"; printf 'old\n' > "$C/dest/ro/a.md"; chmod 555 "$C/dest/ro"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/ro/a.md' ADOPT=''; $DMF"
check "failed backup: step failed, LOCAL unchanged" "[ \"\$(result)\" = failed ] && grep -qx old '$C/dest/ro/a.md'"
chmod 755 "$C/dest/ro"

setup_case tracker
run_lib "deploy_tracker_init; deploy_tracker_record failed tool x.md; deploy_tracker_record updated tool y.md; deploy_tracker_summary tool"
check "tracker: failed -> DETAIL + ERROR row" "grep -qx 'DETAIL|tool|failed: x.md' '$C/summary' && grep -qx 'ERROR|tool|1 failed' '$C/summary'"

# ---------------------------------------------------------------------------
# Text files, interactive (pty)
# ---------------------------------------------------------------------------
if $HAVE_PTY; then
    setup_case force
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "export AITOOLS_FORCE=1; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "a\n"
    check "--force on a terminal: overwrite, no menu" "[ \"\$(result)\" = updated ] && cmp -s '$C/src.md' '$C/dest/a.md' && ! grep -q 'choice \[' '$C/out'"

    setup_case eof
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" '\x04'
    check "EOF at the menu: overwrite, warning logged" "[ \"\$(result)\" = updated ] && grep -q 'No input at prompt (EOF)' '$LOG'"

    setup_case menu-no-adopt
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    check "no adopt target: menu is [o/s/x], no adopt or merge" "grep -q 'choice \[o/s/x\]' '$C/out' && ! grep -q 'accept & adopt :' '$C/out'"

    setup_case skip
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "s\n"
    check "skip: nothing written" "[ \"\$(result)\" = skipped ] && grep -qx old '$C/dest/a.md' && [ ! -e '$C/repo/a.md' ]"

    setup_case adopt
    printf 'source\n' > "$C/repo/a.md"; printf 'local edit\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "a\n"
    check "adopt: LOCAL kept, copied to the repo" "[ \"\$(result)\" = 'accept & adopt' ] && grep -qx 'local edit' '$C/dest/a.md' && grep -qx 'local edit' '$C/repo/a.md'"
    check "adopt: repo backed up, uncommitted change logged" "ls '$C/repo/'a.md.bak.* >/dev/null 2>&1 && grep -q 'Uncommitted change in' '$LOG'"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
    check "adopt: next run verifies" "[ \"\$(result)\" = verified ]"

    setup_case filter
    printf 'TEMPLATE\n' > "$C/repo/a.md"; printf 'body\nFOOTER\n' > "$C/dest/a.md"
    run_lib "strip_footer() { perl -ne 'print unless /^FOOTER/'; }; C='$C'; deploy_managed_file \"\$(cat '$C/repo/a.md')\" '$C/dest/a.md' tool item '$C/repo/a.md' strip_footer; printf '%s' \"\$MANAGED_FILE_RESULT\" > '$C/result'" "a\n"
    check "adopt filter: the repo gets the filtered LOCAL" "[ \"\$(result)\" = 'accept & adopt' ] && grep -qx body '$C/repo/a.md' && ! grep -q FOOTER '$C/repo/a.md'"

    setup_case merge
    stub_claude good
    printf '# Title\nsource line\n' > "$C/repo/a.md"; printf '# Title\nlocal line\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "m\ny\n"
    check "merge & adopt: merge written to LOCAL and the repo" "[ \"\$(result)\" = 'accept & adopt' ] && grep -qx 'merged line' '$C/dest/a.md' && cmp -s '$C/dest/a.md' '$C/repo/a.md'"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
    check "merge & adopt: next run verifies (incident #129 fixed)" "[ \"\$(result)\" = verified ]"

    setup_case merge-reject
    stub_claude good
    printf '# Title\nsource line\n' > "$C/repo/a.md"; printf '# Title\nlocal line\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "m\nn\ns\n"
    check "merge [n]o: back to the menu (then skip)" "[ \"\$(result)\" = skipped ] && [ \"\$(grep -c 'choice \[o/a/m/s/x\]' '$C/out')\" -ge 2 ] && grep -qx 'local line' '$C/dest/a.md'"

    setup_case merge-fail
    stub_claude bad
    printf '# Title\nsource line\n' > "$C/repo/a.md"; printf '# Title\nlocal line\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "m\n"
    check "failed AI merge: failed, nothing written" "[ \"\$(result)\" = failed ] && grep -qx 'local line' '$C/dest/a.md' && grep -qx 'source line' '$C/repo/a.md'"
    check "failed AI merge: reason logged" "grep -q 'Failed: item: AI merge failed' '$LOG'"

    setup_case merge-restore
    stub_claude good
    printf '# Title\nsource line\n' > "$C/repo/a.md"; printf '# Title\nlocal line\n' > "$C/dest/a.md"
    chmod 444 "$C/repo/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "m\ny\n"
    check "adopt-target write failure: LOCAL restored, failed" "[ \"\$(result)\" = failed ] && grep -qx 'local line' '$C/dest/a.md' && grep -q 'Restored' '$LOG'"
    chmod 644 "$C/repo/a.md"

    setup_case abort
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "x\n"
    check "abort: exit 2, error logged" "[ \"\$(cat '$C/rc')\" = 2 ] && grep -q 'Aborted by user' '$LOG'"
    check "abort: LOCAL unchanged" "grep -qx old '$C/dest/a.md'"

    # --- Review display: LOCAL -> SOURCE, labelled, coloured (mission DIFF-UX) ---
    setup_case display
    printf '# Title\nline one\nrepo line\nend\n' > "$C/repo/a.md"; printf '# Title\nline one\nmy local line\nend\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/repo/a.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "s\n"
    P="$C/plain"
    SD="$C/dest/a.md"; SR="$C/repo/a.md"
    check "display: diff is LOCAL -> SOURCE (- this machine, + repo)" "has_line '$P' '-my local line' && has_line '$P' '+repo line' && ! has_line '$P' '+my local line'"
    check "display: headers name both paths, padded" "has_line '$P' '--- this machine  $SD' && has_line '$P' '+++ repo          $SR'"
    check "display: legend above the diff" "has_line '$P' '  red - = only on this machine   green + = only in the repo' && [ \"\$(grep -n 'red - = only' '$P' | cut -d: -f1)\" -lt \"\$(grep -n '^--- this machine' '$P' | cut -d: -f1)\" ]"
    check "display: menu says what each choice does to the lines" \
        "has_line '$P' '  [o]verwrite       : this machine gets the green + lines (backup kept)' && has_line '$P' '  [a]ccept & adopt  : the repo gets the red - lines (your version) -> $SR' && has_line '$P' '  [m]erge & adopt   : AI combines both; written to this machine and $SR' && has_line '$P' '  [s]kip            : nothing written; asked again next run' && has_line '$P' '  [x]abort          : stop this script (exit 2)'"
    check "display: red - lines and header, green + lines and header" \
        "grep -qF \"\${ESC}[31m-my local line\${ESC}[0m\" '$C/out' && grep -qF \"\${ESC}[32m+repo line\${ESC}[0m\" '$C/out' && grep -qF \"\${ESC}[31m--- this machine\" '$C/out' && grep -qF \"\${ESC}[32m+++ repo\" '$C/out'"
    check "display: full diff in the log, plain text" \
        "grep -qF 'diff a.md: --- this machine  $SD' '$LOG' && grep -qF 'diff a.md: -my local line' '$LOG' && grep -qF 'diff a.md: +repo line' '$LOG' && ! grep -qF \"\$ESC\" '$LOG'"
    check "display: [REVIEW] line, no source/local/repo context lines" \
        "has_line '$P' '[REVIEW] $SD differs from source.' && ! grep -qE '^  (source|local |repo  ) = ' '$P'"
    check "display: choice unchanged (skip)" "[ \"\$(result)\" = skipped ] && grep -qx 'my local line' '$C/dest/a.md'"

    setup_case display-nocolor
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    RUN_NO_COLOR=1 run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    check "display NO_COLOR: no colour, same lines" "! grep -qF \"\${ESC}[31m\" '$C/out' && ! grep -qF \"\${ESC}[32m\" '$C/out' && has_line '$C/plain' '-old' && has_line '$C/plain' '+new'"
    check "display, no adopt target: SOURCE header is embedded, menu [o/s/x]" \
        "has_line '$C/plain' '+++ repo          source (embedded)' && has_line '$C/plain' '  [o]verwrite       : this machine gets the green + lines (backup kept)' && ! grep -q 'accept & adopt' '$C/plain'"

    setup_case display-dumb
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    RUN_TERM=dumb run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    check "display TERM=dumb: no colour" "! grep -qF \"\${ESC}[31m\" '$C/out' && ! grep -qF \"\${ESC}[32m\" '$C/out' && has_line '$C/plain' '-old'"

    setup_case display-long
    perl -e 'print "local $_\n" for 1..50' > "$C/dest/a.md"; perl -e 'print "repo $_\n" for 1..50' > "$C/src.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    # 103 diff lines: 2 headers + 1 hunk header + 50 - + 50 +
    check "display >40 lines: first 30 shown, rest in the log" \
        "has_line '$C/plain' '  ... (73 more lines -- full diff in deploy log)' && has_line '$C/plain' '-local 27' && ! has_line '$C/plain' '-local 28' && [ \"\$(grep -c 'diff a.md: ' '$LOG')\" = 103 ] && grep -qF 'diff a.md: +repo 50' '$LOG'"

    setup_case display-huge
    perl -e 'print "local line $_ " . ("x" x 40) . "\n" for 1..3000' > "$C/dest/a.md"; perl -e 'print "repo line $_ " . ("y" x 40) . "\n" for 1..3000' > "$C/src.md"
    GIT_DIFF_OPTS=--unified=0 run_lib "export GIT_DIFF_OPTS; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    # ~330 KB diff, larger than a pipe buffer (head-based truncation died of SIGPIPE here)
    check "display, diff over 64 KB: menu shown, run continues, full diff logged" \
        "[ \"\$(cat '$C/rc')\" = 0 ] && [ \"\$(result)\" = skipped ] && has_line '$C/plain' '  ... (5973 more lines -- full diff in deploy log)' && [ \"\$(grep -c 'diff a.md: ' '$LOG')\" = 6003 ]"

    setup_case display-nogit
    printf '#!/usr/bin/env bash\nexit 128\n' > "$C/bin/git"; chmod +x "$C/bin/git"
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF" "s\n"
    check "display, git diff fails: warning logged, menu still works" \
        "grep -q '\[warn\] Review diff unavailable' '$LOG' && has_line '$C/plain' '  (diff unavailable -- see deploy log)' && [ \"\$(result)\" = skipped ]"
else
    printf 'SKIP interactive cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# JSON files
# ---------------------------------------------------------------------------
setup_case json-created
printf '{"a":1,"b":2}\n' > "$C/src.json"
run_lib "C='$C' SRCF='$C/src.json' DEST='$C/dest/c.json' ADOPT=''; $DMF"
check "json: created" "[ \"\$(result)\" = created ] && node -e 'JSON.parse(require(\"fs\").readFileSync(process.argv[1]))' '$C/dest/c.json'"

setup_case json-noninteractive
printf '{"a":1,"b":2}\n' > "$C/repo/c.json"; printf '{"z":0,"b":3,"a":1}\n' > "$C/dest/c.json"
run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF"
check "json non-interactive: SOURCE field written, LOCAL-only kept, key order kept" \
    "[ \"\$(result)\" = updated ] && [ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/dest/c.json')\" = '{\"z\":0,\"b\":2,\"a\":1}' ]"
check "json non-interactive: repo untouched" "grep -qx '{\"a\":1,\"b\":2}' '$C/repo/c.json'"
run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF"
check "json: LOCAL-only field alone -> verified (kept, no prompt)" "[ \"\$(result)\" = verified ]"

setup_case json-invalid
printf '{"a":1}\n' > "$C/src.json"; printf 'not json\n' > "$C/dest/c.json"
run_lib "C='$C' SRCF='$C/src.json' DEST='$C/dest/c.json' ADOPT=''; $DMF"
check "json: invalid LOCAL -> failed, untouched" "[ \"\$(result)\" = failed ] && grep -qx 'not json' '$C/dest/c.json'"

# The JSON review names the file by the caller's item name (deploy-harness: registries/x.json)
DMF_LABEL='deploy_managed_file "$(cat "$SRCF")" "$DEST" tool registries/c.json "$ADOPT"; printf "%s" "$MANAGED_FILE_RESULT" > "$C/result"'
setup_case json-label
printf '{"a":1,"b":[1]}\n' > "$C/repo/c.json"
run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF_LABEL"
check "json label: Created names the item" "[ \"\$(result)\" = created ] && grep -qF 'Created: registries/c.json -> ' '$LOG'"
printf '{"a":2,"b":[2]}\n' > "$C/dest/c.json"
run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF_LABEL"
check "json label: Divergence and Updated name the item" \
    "[ \"\$(result)\" = updated ] && grep -qF 'Divergence in registries/c.json: a -- overwriting from source (non-interactive)' '$LOG' && grep -qF 'Updated: registries/c.json -> ' '$LOG'"

# ---------------------------------------------------------------------------
# The JSON review's node script (plan mode): the twins embed the same text, and
# the detail column (arrayDetail) for array fields. No pseudo-terminal needed.
# ---------------------------------------------------------------------------
NODE_SH="$TMP_ROOT/review-sh.js"; NODE_PS1="$TMP_ROOT/review-ps1.js"
perl -0777 -ne 's/\r//g; print $1 if /<<\x27REVIEW_JSON_NODE_EOF\x27\n(.*?\n)REVIEW_JSON_NODE_EOF\n/s' "$LIB" > "$NODE_SH"
perl -0777 -ne 's/\r//g; print $1 if /\$script:ReviewJsonNode = \@\x27\n(.*?\n)\x27\@\n/s' "$ROOT/scripts/aitools-lib.ps1" > "$NODE_PS1"
check "json review node script: found in both libs, identical" "[ -s '$NODE_SH' ] && [ -s '$NODE_PS1' ] && cmp -s '$NODE_SH' '$NODE_PS1'"

# plan_detail <source json> <local json>: run plan mode; $C/detail gets the first
# field's detail column, one element line per line (empty file: no detail);
# $C/plan.tsv keeps the raw plan.
plan_detail() {
    printf '%s\n' "$1" > "$C/s.json"; printf '%s\n' "$2" > "$C/l.json"
    : > "$C/plan.tsv"
    node "$NODE_SH" plan "$C/s.json" "$C/l.json" "$C/plan.tsv" 2> "$C/err" || printf 'node failed: %s\n' "$(cat "$C/err")"
    perl -ne 'chomp; my @f = split /\t/, $_, -1; if ($. == 1 && length($f[5] // "")) { print map { "$_\n" } split /\x1f/, $f[5] }' "$C/plan.tsv" > "$C/detail"
}
# detail_is <line>...: $C/detail is exactly these lines
detail_is() { [ "$(cat "$C/detail")" = "$(printf '%s\n' "$@")" ]; }

if command -v node >/dev/null 2>&1; then
    setup_case array-detail
    plan_detail '{"t":[1,3,4]}' '{"t":[1,2,3]}'
    check "array detail: scalars, removed and added by index" "detail_is '3 local, 3 source element(s)' '- [1] 2' '+ [2] 4'"
    plan_detail '{"t":[1,1]}' '{"t":[1]}'
    check "array detail: a duplicate element counts" "detail_is '1 local, 2 source element(s)' '+ [1] 1'"
    plan_detail '{"t":["1",1,{"a":2}]}' '{"t":[1,"1",null,{"a":1}]}'
    check "array detail: mixed types (1 and \"1\" differ), objects without identity" \
        "detail_is '4 local, 3 source element(s)' '+ [2] {\"a\":2}' '- [2] null' '- [3] {\"a\":1}'"
    plan_detail '{"t":[]}' '{"t":[1]}'
    check "array detail: empty SOURCE array" "detail_is '1 local, 0 source element(s)' '- [0] 1'"
    plan_detail '{"t":[1]}' '{"t":[]}'
    check "array detail: empty LOCAL array" "detail_is '0 local, 1 source element(s)' '+ [0] 1'"
    plan_detail '{"t":[[1,2],[3,4]]}' '{"t":[[1,2],[3]]}'
    check "array detail: nested arrays compared whole" "detail_is '2 local, 2 source element(s)' '+ [1] [3,4]' '- [1] [3]'"
    plan_detail '{"t":[{"id":5,"v":"b"}]}' '{"t":[{"id":5,"v":"a","x":1}]}'
    check "array detail: same identity, one line per changed key, absent key" \
        "detail_is '1 local, 1 source element(s)' '~ [0] id=5: v: \"a\" -> \"b\"' '~ [0] id=5: x: 1 -> (absent)'"
    plan_detail '{"t":[{"name":"n","k":{"b":1,"a":2}}]}' '{"t":[{"k":{"a":2,"b":1},"name":"n"}]}'
    check "array detail: key order inside an element is no difference" "[ ! -s '$C/plan.tsv' ]"
    plan_detail '{"t":["x","y"]}' '{"t":["y","x"]}'
    check "array detail: a reorder alone is one line" "detail_is '2 local, 2 source element(s)' '~ order differs (same elements)'"
    # 0,1,...,24 (perl, not seq: BSD seq -s leaves a trailing separator on macOS)
    plan_detail "{\"t\":[$(perl -e 'print join(",", 0 .. 24)')]}" '{"t":[]}'
    check "array detail: at most 20 element lines, then a count of the rest" \
        "[ \"\$(wc -l < '$C/detail')\" -eq 22 ] && [ \"\$(sed -n 2p '$C/detail')\" = '+ [0] 0' ] && [ \"\$(sed -n 21p '$C/detail')\" = '+ [19] 19' ] && [ \"\$(tail -n 1 '$C/detail')\" = '... 5 more line(s)' ]"
    plan_detail '{"t":["a\tb\u001fc"]}' '{"t":[]}'
    check "array detail: tab and unit separator inside a value stay escaped" \
        "detail_is '0 local, 1 source element(s)' '+ [0] \"a\\tb\\u001fc\"' && [ \"\$(perl -ne 'chomp; @f = split /\\t/, \$_, -1; print scalar @f' '$C/plan.tsv')\" = 6 ]"
    plan_detail '{"a":1}' '{"a":2}'
    check "array detail: a scalar field has an empty detail column (6 columns)" \
        "[ ! -s '$C/detail' ] && [ \"\$(perl -ne 'chomp; @f = split /\\t/, \$_, -1; print scalar @f' '$C/plan.tsv')\" = 6 ]"
    plan_detail '{"t":[1]}' '{"t":"x"}'
    check "array detail: array against a non-array, no detail" "[ ! -s '$C/detail' ] && [ -s '$C/plan.tsv' ]"
    plan_detail '{"t":[1]}' '{}'
    check "array detail: a field only in SOURCE, no detail" "[ ! -s '$C/detail' ] && grep -q 'source-only' '$C/plan.tsv'"
else
    printf 'SKIP json review node script cases: node not installed\n'; SKIP=$((SKIP + 1))
fi

# Read-only copies: a new file is created; a dry run writes nothing
setup_case readonly-copy-json-new
printf '{"a":1}\n' > "$C/repo/c.json"
run_lib "export MANAGED_NO_REVIEW=true; C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF"
check "read-only copy (JSON), LOCAL missing: created from SOURCE" "[ \"\$(result)\" = created ] && cmp -s '$C/repo/c.json' '$C/dest/c.json'"
setup_case readonly-copy-dryrun
printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
run_lib "export MANAGED_NO_REVIEW=true DRY_RUN=true; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
check "read-only copy in a dry run: reported, nothing written" \
    "[ \"\$(result)\" = verified ] && grep -qx old '$C/dest/a.md' && grep -qF '[DRY RUN] Would update: item' '$LOG' && ! ls '$C/dest/'a.md.bak.* >/dev/null 2>&1"

# Read-only copies (MANAGED_NO_REVIEW=true): SOURCE wins, backup kept, no warning
setup_case readonly-copy-text
printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
run_lib "export MANAGED_NO_REVIEW=true; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF"
check "read-only copy (text): SOURCE written, backup kept, adopt target untouched" \
    "[ \"\$(result)\" = updated ] && grep -qx new '$C/dest/a.md' && ls '$C/dest/'a.md.bak.* >/dev/null 2>&1 && [ ! -e '$C/repo/a.md' ]"
check "read-only copy (text): logged as such, no warning" \
    "grep -q 'read-only copy: source wins, backup kept' '$LOG' && ! grep -q '\[warn\]' '$LOG'"

setup_case readonly-copy-json
printf '{"a":1,"b":[1,2]}\n' > "$C/repo/c.json"; printf '{"z":0,"b":[2]}\n' > "$C/dest/c.json"
run_lib "export MANAGED_NO_REVIEW=true; C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF"
check "read-only copy (JSON): written whole (LOCAL-only field gone), backup kept" \
    "[ \"\$(result)\" = updated ] && cmp -s '$C/repo/c.json' '$C/dest/c.json' && ls '$C/dest/'c.json.bak.* >/dev/null 2>&1"

if $HAVE_PTY; then
    setup_case readonly-copy-pty
    printf 'new\n' > "$C/src.md"; printf 'old\n' > "$C/dest/a.md"
    run_lib "export MANAGED_NO_REVIEW=true; C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT='$C/repo/a.md'; $DMF" "a\n"
    check "read-only copy on a terminal: no menu, SOURCE written, nothing adopted" \
        "[ \"\$(result)\" = updated ] && grep -qx new '$C/dest/a.md' && ! grep -q 'choice \[' '$C/out' && [ ! -e '$C/repo/a.md' ]"

    setup_case json-array-display
    printf '{"list":[{"id":1,"v":"a"},{"id":2,"v":"b"}],"tags":["x","y"]}\n' > "$C/repo/c.json"
    printf '{"list":[{"id":1,"v":"a"},{"id":2,"v":"OLD"},{"id":3,"v":"c"}],"tags":["y","x"]}\n' > "$C/dest/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" "o\no\n"
    perl -pe 's/\e\[[0-9;]*m//g; s/\r//g' "$C/out" > "$C/out.plain"
    check "json array: the header names the file" "has_line '$C/out.plain' '[REVIEW] item: list differs from source.'"
    check "json array: counts, the changed and the removed element shown" \
        "has_line '$C/out.plain' '  3 local, 2 source element(s)' && has_line '$C/out.plain' '  ~ [1] id=2: v: \"OLD\" -> \"b\"' && has_line '$C/out.plain' '  - [2] {\"id\":3,\"v\":\"c\"}'"
    check "json array: a reorder alone is one line" "has_line '$C/out.plain' '  ~ order differs (same elements)'"
    check "json array: legend, colour-coded lines" \
        "has_line '$C/out.plain' '  red - = only in local   green + = only in source   yellow ~ = changed' && grep -qF \"\${ESC}[33m~ [1] id=2\" '$C/out' && grep -qF \"\${ESC}[31m- [2]\" '$C/out'"
    check "json array: element lines in the log" "grep -qF 'review item: list: ~ [1] id=2: v: \"OLD\" -> \"b\"' '$LOG'"
    check "json array: overwrite applied" \
        "[ \"\$(result)\" = updated ] && [ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/dest/c.json')\" = '{\"list\":[{\"id\":1,\"v\":\"a\"},{\"id\":2,\"v\":\"b\"}],\"tags\":[\"x\",\"y\"]}' ]"
fi

if $HAVE_PTY; then
    setup_case json-fields
    printf '{"a":1,"b":2,"c":3}\n' > "$C/repo/c.json"; printf '{"a":9,"b":8,"c":7,"z":0}\n' > "$C/dest/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" "o\na\ns\na\n"
    check "json per-field: overwrite a, adopt b, skip c, adopt LOCAL-only z" \
        "[ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/dest/c.json')\" = '{\"a\":1,\"b\":8,\"c\":7,\"z\":0}' ] && [ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/repo/c.json')\" = '{\"a\":1,\"b\":8,\"c\":3,\"z\":0}' ]"
    check "json per-field: precedence -> accept & adopt" "[ \"\$(result)\" = 'accept & adopt' ]"
    check "json LOCAL-only: no [o]verwrite offered" "grep -q 'choice \[a/s/x\]' '$C/out'"

    setup_case json-label-pty
    printf '{"a":1,"b":2}\n' > "$C/repo/c.json"; printf '{"a":9,"b":8,"z":0}\n' > "$C/dest/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF_LABEL" "a\ns\ns\n"
    check "json label: every review header names the file, the LOCAL-only field too" \
        "has_line '$C/plain' '[REVIEW] registries/c.json: a differs from source.' && has_line '$C/plain' '[REVIEW] registries/c.json: z differs from source.'"
    check "json label: Accept & adopt and Skipped name the item" \
        "[ \"\$(result)\" = 'accept & adopt' ] && grep -qF 'Accept & adopt: registries/c.json -> ' '$LOG' && grep -qF 'Skipped: registries/c.json (' '$LOG'"

    setup_case json-skip
    printf '{"a":1}\n' > "$C/repo/c.json"; printf '{"a":2}\n' > "$C/dest/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" "s\n"
    check "json skip: skipped, both unchanged" "[ \"\$(result)\" = skipped ] && grep -qx '{\"a\":2}' '$C/dest/c.json' && grep -qx '{\"a\":1}' '$C/repo/c.json'"

    setup_case json-restore
    printf '{"a":1,"b":2}\n' > "$C/repo/c.json"; printf '{"a":9,"b":8}\n' > "$C/dest/c.json"; chmod 444 "$C/repo/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" "o\na\n"
    check "json write failure: LOCAL restored, failed" "[ \"\$(result)\" = failed ] && grep -qx '{\"a\":9,\"b\":8}' '$C/dest/c.json'"
    chmod 644 "$C/repo/c.json"
fi

# ---------------------------------------------------------------------------
# setup-user-claude.sh: CLAUDE.md adopt filter round trip (isolated HOME)
# ---------------------------------------------------------------------------
if $HAVE_PTY && command -v node >/dev/null 2>&1; then
    setup_case claude-md
    DP="$C/dotprofile"; mkdir -p "$DP/claude" "$C/home/.aitools"
    git -C "$C" init -q dotprofile
    printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
    printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$C/home/.aitools/config.json"
    run_claude() {
        local input="${1:-}"
        if [ -z "$input" ]; then
            env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
                bash "$ROOT/scripts/setup-user-claude.sh" < /dev/null > "$C/out" 2>&1
        else
            env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
                python3 "$PTY" --input "$input" --log "$C/out" -- bash "$ROOT/scripts/setup-user-claude.sh"
        fi
        echo $? > "$C/rc"
    }
    run_claude
    check "claude.md: created with interpolation" "grep -qx '# Prefs for Tess' '$C/home/.claude/CLAUDE.md' && grep -q '## Machine-Specific' '$C/home/.claude/CLAUDE.md'"
    perl -0pi -e 's/- keep it simple/- keep it simple\n- my local rule/' "$C/home/.claude/CLAUDE.md"
    run_claude "a\n"
    check "claude.md adopt: template gets the edit, token restored, no footer" \
        "grep -qx -- '- my local rule' '$DP/claude/CLAUDE.md' && grep -qx '# Prefs for {{PROFILE_NAME}}' '$DP/claude/CLAUDE.md' && ! grep -q 'Machine-Specific' '$DP/claude/CLAUDE.md'"
    check "claude.md adopt: empty company not substituted" "! grep -q '{{PROFILE_COMPANY}}' '$DP/claude/CLAUDE.md'"
    : > "$C/summary"
    run_claude
    check "claude.md adopt: next run verifies" "grep -qx 'OK|claude.md|verified' '$C/summary'"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
