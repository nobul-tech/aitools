#!/usr/bin/env bash
# test-deploy-harness.sh -- tests for scripts/deploy-harness.sh (populate ~/.aitools)
#
# Each case builds fixture repos (a git aitools repo holding a copy of
# deploy-harness.sh + aitools-lib.sh, and a git dotprofile) and runs the script
# under an isolated HOME in a temp directory, removed on exit. The real HOME,
# the real repos and the real dotprofile are never touched.
# Cases: first run, rerun, edit then rerun (non-interactive -> overwrite),
# accept & adopt into a protected file (pty), skip (pty), abort (pty, exit 2),
# --force on a terminal, conflicts (first source wins, ERROR rows, exit 1),
# dry run (no writes), config writer failure (stub and real writer),
# missing / non-git dotprofile, preserved files, bad arguments, --help.
# Interactive cases use tests/managed-files/pty-run.py (python3); skipped
# without it. The config writer is a stub except in the "real writer" case.
# Platform: macOS, Linux. Exit 1 if any case fails.
#
# Usage: bash tests/deploy-harness/test-deploy-harness.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 17' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false
[ -f "$PTY" ] || HAVE_PTY=false

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 30
        fi
    fi
}

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# setup_case NAME: fixture aitools repo ($R), dotprofile ($D), HOME ($H) with config.json
setup_case() {
    C="$TMP_ROOT/$1"; R="$C/repo"; D="$C/dot"; H="$C/home"
    mkdir -p "$R/scripts" "$R/reference/evaluations" "$R/registries" "$R/shared/hooks" \
        "$R/shared/skills/s1/tests" "$R/shared/skills/s2" "$R/.claude/skills/s3" \
        "$R/shared/rules" "$R/.claude/rules" "$D/claude/rules" "$H/.aitools"
    cp "$ROOT/scripts/deploy-harness.sh" "$ROOT/scripts/aitools-lib.sh" "$R/scripts/"
    # Stub config writer: records its arguments; exit code from STUB_WRITER_RC.
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "called $*" >> "$HOME/writer-calls"\nexit "${STUB_WRITER_RC:-0}"\n' \
        > "$R/scripts/setup-user-config.sh"
    for f in harness-db.py read-session.py read-session-full.py; do
        printf '#!/usr/bin/env python3\nprint("%s")\n' "$f" > "$R/scripts/$f"
        chmod +x "$R/scripts/$f"
    done
    printf '# Harness\n\nsource text\n' > "$R/reference/harness.md"
    printf 'notes\n' > "$R/reference/notes.md"
    printf 'eval\n' > "$R/reference/evaluations/e.md"
    printf '{\n  "a": 1,\n  "b": [1, 2]\n}\n' > "$R/registries/r.json"
    printf '#!/usr/bin/env bash\necho hook\n' > "$R/shared/hooks/h1.sh"; chmod +x "$R/shared/hooks/h1.sh"
    printf 'old copy\n' > "$R/shared/hooks/h1.sh.bak.2026-01-01T000000Z"
    printf '{"hooks": []}\n' > "$R/shared/hooks/hooks-manifest.json"
    printf 'skill one\n' > "$R/shared/skills/s1/SKILL.md"
    printf 'skill one test\n' > "$R/shared/skills/s1/tests/t.md"
    printf 'skill two\n' > "$R/shared/skills/s2/SKILL.md"
    printf 'skill three\n' > "$R/.claude/skills/s3/SKILL.md"
    printf 'shared scratch rule\n' > "$R/shared/rules/scratch.md"
    printf 'shared hook lifecycle\n' > "$R/shared/rules/hook-lifecycle.md"
    printf 'project rule\n' > "$R/.claude/rules/p1.md"
    # The protected-files table makes reference/harness.md a protected adopt target.
    cp "$ROOT/.claude/rules/sources-of-truth.md" "$R/.claude/rules/sources-of-truth.md"
    git -C "$R" init -q
    gitc -C "$R" add -A
    gitc -C "$R" commit -q -m fixture
    printf 'untracked\n' > "$R/reference/untracked.md"
    printf 'user rule\n' > "$D/claude/rules/user1.md"
    git -C "$D" init -q
    gitc -C "$D" add -A
    gitc -C "$D" commit -q -m fixture
    write_config "$D"
}

write_config() {  # write_config USER_REPO_PATH
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
        "$C" "$R" "$1" > "$H/.aitools/config.json"
}

# run_dh [input] -- ARGS...: run deploy-harness.sh under the case HOME.
# No input: stdin is /dev/null (non-interactive). Input: on a pty with keystrokes.
run_dh() {
    local input="$1"; shift
    [ "${1:-}" = "--" ] && shift
    : > "$C/summary"
    if [ -z "$input" ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" AITOOLS_LOG_DIR="$C/logs" \
            AITOOLS_SUMMARY_FILE="$C/summary" ${EXTRA_ENV:-} \
            bash "$R/scripts/deploy-harness.sh" "$@" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" AITOOLS_LOG_DIR="$C/logs" \
            AITOOLS_SUMMARY_FILE="$C/summary" ${EXTRA_ENV:-} \
            python3 "$PTY" --input "$input" --log "$C/out" -- bash "$R/scripts/deploy-harness.sh" "$@"
        echo $? > "$C/rc"
    fi
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

rc() { cat "$C/rc"; }
row() { grep -qxF "$1" "$C/summary"; }          # exact summary row
has_row() { grep -qF "$1" "$C/summary"; }       # summary substring
A() { printf '%s' "$H/.aitools"; }

# ---------------------------------------------------------------------------
# First run, rerun, edit then rerun
# ---------------------------------------------------------------------------
setup_case first
run_dh "" --
check "first run: exit 0" "[ \"\$(rc)\" = 0 ]"
check "first run: six directories exist" \
    "[ -d '$(A)/reference' ] && [ -d '$(A)/registries' ] && [ -d '$(A)/hooks' ] && [ -d '$(A)/rules' ] && [ -d '$(A)/skills' ] && [ -d '$(A)/bin' ]"
check "first run: one OK row, 18 added" "row 'OK|harness files|18 added'"
check "first run: no ERROR row" "! grep -q '^ERROR|' '$C/summary'"
check "first run: config writer called without flags" "grep -qx 'called ' '$H/writer-calls'"
check "first run: reference tree kept (nested path)" "cmp -s '$R/reference/evaluations/e.md' '$(A)/reference/evaluations/e.md'"
check "first run: registries deployed (JSON)" "cmp -s '$R/registries/r.json' '$(A)/registries/r.json'"
check "first run: untracked file not deployed" "[ ! -e '$(A)/reference/untracked.md' ]"
check "first run: tracked *.bak.* not deployed" "[ ! -e '$(A)/hooks/h1.sh.bak.2026-01-01T000000Z' ]"
check "first run: hooks flat, executable" "[ -x '$(A)/hooks/h1.sh' ] && [ -f '$(A)/hooks/hooks-manifest.json' ]"
check "first run: skills are directories (all files)" \
    "[ -f '$(A)/skills/s1/SKILL.md' ] && [ -f '$(A)/skills/s1/tests/t.md' ] && [ -f '$(A)/skills/s3/SKILL.md' ]"
check "first run: rules flat from three sources" \
    "[ -f '$(A)/rules/scratch.md' ] && [ -f '$(A)/rules/p1.md' ] && [ -f '$(A)/rules/sources-of-truth.md' ] && [ -f '$(A)/rules/user1.md' ]"
check "first run: bin CLIs deployed, executable" "[ -x '$(A)/bin/harness-db.py' ] && [ -x '$(A)/bin/read-session-full.py' ]"
check "first run: missing .claude/hooks is info, not error" "grep -q '\[info\] Source .claude/hooks not found' '$LOG'"

run_dh "" --
check "rerun: exit 0, everything verified" "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|18 verified'"
check "rerun: no backups made" "[ -z \"\$(find '$(A)' -name '*.bak.*' -print)\" ]"

printf 'local edit\n' > "$(A)/rules/scratch.md"
run_dh "" --
check "edit then rerun (non-interactive): source overwrites, backup kept" \
    "[ \"\$(rc)\" = 0 ] && cmp -s '$R/shared/rules/scratch.md' '$(A)/rules/scratch.md' && ls '$(A)/rules/'scratch.md.bak.* >/dev/null 2>&1"
check "edit then rerun: counted as updated" "has_row 'harness files|1 updated'"
check "edit then rerun: backup is not reported as preserved" "! grep -q 'Preserved: .*scratch.md.bak' '$LOG'"

printf 'mine\n' > "$(A)/rules/mine.md"
run_dh "" --
check "preserved: file with no source kept and logged" "[ -f '$(A)/rules/mine.md' ] && grep -q 'Preserved: .*rules/mine.md' '$LOG'"

# ---------------------------------------------------------------------------
# Interactive (pty): adopt, skip, abort, --force
# ---------------------------------------------------------------------------
if $HAVE_PTY; then
    setup_case adopt
    run_dh "" --
    printf '# Harness\n\nlocal edit\n' > "$(A)/reference/harness.md"
    run_dh 'a\n' --
    check "adopt: exit 0" "[ \"\$(rc)\" = 0 ]"
    check "adopt: LOCAL kept and copied to the repo source" \
        "grep -qx 'local edit' '$(A)/reference/harness.md' && grep -qx 'local edit' '$R/reference/harness.md'"
    check "adopt: WARN names the protected file" "grep -q '\[warn\] Adopted into protected file .*reference/harness.md' '$LOG'"
    check "adopt: DETAIL row" "grep -q '^DETAIL|harness files|accept & adopt: ' '$C/summary'"
    run_dh "" --
    check "adopt: next run verifies; repo backup not deployed" \
        "row 'OK|harness files|18 verified' && [ -z \"\$(find '$(A)/reference' -name '*.bak.*' -print)\" ]"

    setup_case skip
    run_dh "" --
    printf 'local edit\n' > "$(A)/skills/s2/SKILL.md"
    run_dh 's\n' --
    check "skip: nothing written, WARN row" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 'local edit' '$(A)/skills/s2/SKILL.md' && row 'WARN|harness files|1 skipped (user review)'"

    setup_case abort
    run_dh "" --
    printf 'local edit\n' > "$(A)/hooks/h1.sh"
    run_dh 'x\n' --
    check "abort: exit 2, file unchanged" "[ \"\$(rc)\" = 2 ] && grep -qx 'local edit' '$(A)/hooks/h1.sh'"

    setup_case force
    run_dh "" --
    printf 'local edit\n' > "$(A)/rules/p1.md"
    run_dh 'a\n' -- --force
    check "--force on a terminal: overwrite, no menu" \
        "[ \"\$(rc)\" = 0 ] && cmp -s '$R/.claude/rules/p1.md' '$(A)/rules/p1.md' && ! grep -q 'choice \[' '$C/out'"
    printf 'local edit\n' > "$(A)/rules/p1.md"
    EXTRA_ENV="AITOOLS_FORCE=1" run_dh 'a\n' --
    check "AITOOLS_FORCE=1 on a terminal: overwrite, no menu" \
        "[ \"\$(rc)\" = 0 ] && cmp -s '$R/.claude/rules/p1.md' '$(A)/rules/p1.md' && ! grep -q 'choice \[' '$C/out'"
else
    printf 'SKIP interactive cases (python3 pty not available)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Conflicts: first source wins, one ERROR row per skipped duplicate, exit 1
# ---------------------------------------------------------------------------
setup_case conflict
printf 'dotprofile scratch rule\n' > "$D/claude/rules/scratch.md"
printf 'dotprofile lifecycle\n' > "$D/claude/rules/Hook-Lifecycle.md"
gitc -C "$D" add -A; gitc -C "$D" commit -q -m dups
mkdir -p "$R/.claude/skills/s1"
printf 'project skill one\n' > "$R/.claude/skills/s1/SKILL.md"
gitc -C "$R" add .claude/skills/s1/SKILL.md; gitc -C "$R" commit -q -m dups
run_dh "" --
check "conflict: exit 1" "[ \"\$(rc)\" = 1 ]"
check "conflict: ERROR row per duplicate" \
    "row 'ERROR|harness files|scratch.md: dup in dotprofile' && row 'ERROR|harness files|s1: dup in .claude/skills' && row 'ERROR|harness files|Hook-Lifecycle.md: dup in d...'"
check "conflict: log_error names both sources" "grep -q '\[error\] Duplicate rules name: scratch.md in dotprofile .* kept scratch.md from shared/rules' '$LOG'"
check "conflict: first source wins (rules, skills)" \
    "cmp -s '$R/shared/rules/scratch.md' '$(A)/rules/scratch.md' && cmp -s '$R/shared/rules/hook-lifecycle.md' '$(A)/rules/hook-lifecycle.md' && cmp -s '$R/shared/skills/s1/SKILL.md' '$(A)/skills/s1/SKILL.md'"
check "conflict: case-insensitive duplicate not deployed" "grep -qx 'shared hook lifecycle' '$(A)/rules/hook-lifecycle.md' && ! ls '$(A)/rules' | grep -qx 'Hook-Lifecycle.md'"
check "conflict: other files still deployed" "[ -f '$(A)/rules/user1.md' ] && [ -f '$(A)/skills/s1/tests/t.md' ]"

# ---------------------------------------------------------------------------
# Dry run: report, write nothing
# ---------------------------------------------------------------------------
setup_case dryrun
run_dh "" -- --dry-run
check "dry run: exit 0, counts" "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|dry-run: 18 create, 0 update'"
check "dry run: no harness directory created" \
    "[ ! -e '$(A)/reference' ] && [ ! -e '$(A)/rules' ] && [ ! -e '$(A)/bin' ]"
check "dry run: config writer called with --dry-run" "grep -qx 'called --dry-run' '$H/writer-calls'"
run_dh "" --
printf 'local edit\n' > "$(A)/rules/user1.md"
EXTRA_ENV="AITOOLS_DRY_RUN=1" run_dh "" --
check "AITOOLS_DRY_RUN=1: would update 1, file untouched" \
    "row 'OK|harness files|dry-run: 0 create, 1 update' && grep -qx 'local edit' '$(A)/rules/user1.md'"

# ---------------------------------------------------------------------------
# config.json writer failures
# ---------------------------------------------------------------------------
setup_case writerfail
EXTRA_ENV="STUB_WRITER_RC=1" run_dh "" --
check "writer failure: exit 1, ERROR row, files still deployed" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|config.json not generated' && [ -f '$(A)/rules/scratch.md' ]"

setup_case realwriter
cp "$ROOT/scripts/setup-user-config.sh" "$ROOT/scripts/aitools-profile.sh" "$ROOT/scripts/aitools-json.pl" "$R/scripts/"
rm -f "$H/.aitools/config.json"
run_dh "" --
check "real writer, no bootstrap config: exit 1, ERROR row propagated" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|config.json not generated' && grep -q '\[setup-user-config\] \[error\]' '$LOG'"

# ---------------------------------------------------------------------------
# Dotprofile missing / not a git checkout
# ---------------------------------------------------------------------------
setup_case nodot
write_config "$C/no-such-dotprofile"
run_dh "" --
check "missing dotprofile: info, exit 0, 17 added" \
    "[ \"\$(rc)\" = 0 ] && grep -q '\[info\] Dotprofile .* not found -- dotprofile rules skipped' '$LOG' && row 'OK|harness files|17 added'"

setup_case nogitdot
rm -rf "$D/.git"
run_dh "" --
check "dotprofile not in git: ERROR row, exit 1" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|dotprofile: not a git checkout' && [ ! -e '$(A)/rules/user1.md' ]"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
setup_case args
run_dh "" -- --bogus
check "bad argument: exit 1, ERROR row" "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|bad arguments'"
run_dh "" -- --help
check "--help: exit 0, usage shown, nothing deployed" \
    "[ \"\$(rc)\" = 0 ] && grep -q 'Usage: deploy-harness.sh' '$C/out' && [ ! -e '$(A)/rules' ]"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
