#!/usr/bin/env bash
# test-managed-files.sh -- tests for the managed-file model in scripts/aitools-lib.sh:
# deploy_managed_file, prompt_diff_review, review_json_fields, the tracker,
# [x]abort (exit 2), and setup-user-claude.sh's CLAUDE.md adopt filter.
#
# Safe to re-run: every case runs in its own temp HOME, removed on exit.
# Interactive cases run on a pseudo-terminal (tests/managed-files/pty-run.py,
# python3). The AI merge uses a stub `claude` on PATH; no real AI is called.
# Platform: macOS, Linux (Git Bash: pty cases need python3 pty, unavailable on
# Windows -- they are skipped there). Exit 1 if any case fails.
# Spec: .claude/rules/agentic-standards.md "Managed-file review choices and
# merge"; reference/managed-file-deployment.md; .claude/rules/interactive-menus.md.
#
# Usage: bash tests/managed-files/test-managed-files.sh [--help]

set -uo pipefail

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
HAVE_READONLY=true   # chmod 555/444 does not block writes under Git Bash
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) HAVE_PTY=false; HAVE_READONLY=false ;; esac
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
    if [ -z "$input" ]; then
        env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
            PATH="$C/bin:$PATH" bash "$C/snippet.sh" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
    else
        env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
            PATH="$C/bin:$PATH" python3 "$PTY" --input "$input" --log "$C/out" -- bash "$C/snippet.sh"
        echo $? > "$C/rc"
    fi
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

result() { cat "$C/result" 2>/dev/null; }
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

setup_case nostate
mkdir -p "$C/home/.aitools/deploy-state"; printf '{}' > "$C/home/.aitools/deploy-state/manifest.json"
printf 'x\n' > "$C/src.md"
run_lib "C='$C' SRCF='$C/src.md' DEST='$C/dest/a.md' ADOPT=''; $DMF"
check "deploy state: old files left on disk, noted once (detail)" \
    "[ -f '$C/home/.aitools/deploy-state/manifest.json' ] && [ \"\$(grep -c 'deploy state is no longer used' '$LOG')\" = 1 ]"

if $HAVE_READONLY; then
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
else
    printf 'SKIP read-only cases (chmod does not block writes on this platform)\n'; SKIP=$((SKIP + 1))
fi

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
else
    printf 'SKIP interactive cases (no python3 pty on this platform)\n'; SKIP=$((SKIP + 1))
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

if $HAVE_PTY; then
    setup_case json-fields
    printf '{"a":1,"b":2,"c":3}\n' > "$C/repo/c.json"; printf '{"a":9,"b":8,"c":7,"z":0}\n' > "$C/dest/c.json"
    run_lib "C='$C' SRCF='$C/repo/c.json' DEST='$C/dest/c.json' ADOPT='$C/repo/c.json'; $DMF" "o\na\ns\na\n"
    check "json per-field: overwrite a, adopt b, skip c, adopt LOCAL-only z" \
        "[ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/dest/c.json')\" = '{\"a\":1,\"b\":8,\"c\":7,\"z\":0}' ] && [ \"\$(node -e 'console.log(JSON.stringify(JSON.parse(require(\"fs\").readFileSync(process.argv[1]))))' '$C/repo/c.json')\" = '{\"a\":1,\"b\":8,\"c\":3,\"z\":0}' ]"
    check "json per-field: precedence -> accept & adopt" "[ \"\$(result)\" = 'accept & adopt' ]"
    check "json LOCAL-only: no [o]verwrite offered" "grep -q 'choice \[a/s/x\]' '$C/out'"

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
