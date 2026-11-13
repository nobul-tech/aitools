#!/usr/bin/env bash
# test-deploy-harness.sh -- tests for scripts/deploy-harness.sh/.ps1 (populate ~/.aitools)
#
# Each case builds fixture repos (a git aitools repo holding a copy of
# deploy-harness + aitools-lib, and a git dotprofile) and runs the script
# under an isolated HOME in a temp directory, removed on exit. The real HOME,
# the real repos and the real dotprofile are never touched.
# Cases: first run, rerun, edit then rerun (non-interactive -> overwrite),
# accept & adopt into the aitools repo (pty), skip (pty), abort (pty, exit 2),
# --force on a terminal, conflicts (first source wins, ERROR rows, exit 1),
# dry run (no writes), config writer failure (stub and real writer),
# rules and skills from aitools shared/ only (aitools .claude/rules,
# .claude/skills and the dotprofile claude/rules, claude/skills are fixtures
# that must never be deployed, commander 2026-11-06), preserved files, bad
# arguments, --help, the rules manifest and retired rules (withdrawn sources
# "aitools" and "dotprofile" retired), the skills manifest and retired skills
# (withdrawn sources retired, the .claude -> shared move, retire with a
# verified backup_dir backup, dry run, failed backup, invalid lines, bad
# header), and rule names with an upper- or mixed-case .md extension
# (deployed, listed, no warning, retired; .bak. rejected; the lib's manifest
# reader).
#
# Platform targeting (plans/ci-platform-targeting.md): each script runs only
# where its OS guard allows. macOS/Linux run deploy-harness.sh; Windows (Git
# Bash) runs deploy-harness.ps1 with native pwsh (HOME and USERPROFILE set,
# native paths). Every case runs in that one language. Parity between the two:
# the skills sequence's trace (exit codes, summary rows, manifest, tree) must
# equal the committed golden files in tests/deploy-harness/golden/
# (tests/lib/platform-lib.sh golden_match); AITOOLS_TEST_UPDATE_GOLDEN=1 on
# macOS/Linux rewrites them. The other cases check exact rows and files,
# the same expectations for both languages.
# Not on Windows: the read-only and unreadable-file cases (chmod does not
# block writes or reads under Git Bash), the executable-bit checks (only the
# .sh sets the bit). Interactive cases use tests/managed-files/pty-run.py
# (python3; pywinpty on Windows); skipped without it. The config writer is a
# stub except in the "real writer" case. AITOOLS_TEST_BASH picks the bash
# that runs the .sh scripts (default: bash). Exit 1 if any case fails.
#
# Usage: bash tests/deploy-harness/test-deploy-harness.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: macOS/Linux always run only .sh

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 40' "$0"
    exit 0
fi
if [ "${1:-}" = "--bash-only" ]; then shift; fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$ROOT/tests/lib/platform-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
GOLDEN_DIR="$ROOT/tests/deploy-harness/golden"
GOLDEN_TMP="$TMP_ROOT"
LANG_RUN="$TEST_LANG"   # sh on macOS/Linux, ps1 on Windows

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false
[ -f "$PTY" ] || HAVE_PTY=false
# Windows pty = pywinpty (ConPTY); python3 -c's failure means "not installed".
if [ "$TEST_PLATFORM" = windows ] && $HAVE_PTY && ! python3 -c 'import winpty' >/dev/null 2>&1; then
    HAVE_PTY=false
fi
# chmod 555/000 blocks writes and reads only on POSIX, and not for root.
HAVE_READONLY=true
if [ "$TEST_PLATFORM" = windows ] || [ "$(id -u)" = 0 ]; then HAVE_READONLY=false; fi

if [ "$LANG_RUN" = ps1 ] && ! command -v pwsh >/dev/null 2>&1; then
    printf 'FAIL pwsh is not on PATH: deploy-harness.ps1 cannot be tested on Windows\n'
    exit 1
fi

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g; s/\r//g; s/^/      | /' "$C/out" | tail -n 30
        fi
    fi
}

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# lang_scripts: the deploy-harness of the language under test, its library and
# a stub config writer in $R/scripts. The stub records its arguments in
# $HOME/writer-calls ("called " or "called --dry-run", LF, both languages) and
# exits with STUB_WRITER_RC.
lang_scripts() {
    if [ "$LANG_RUN" = sh ]; then
        cp "$ROOT/scripts/deploy-harness.sh" "$ROOT/scripts/aitools-lib.sh" "$R/scripts/"
        printf '#!/usr/bin/env bash\nprintf "%%s\\n" "called $*" >> "$HOME/writer-calls"\nexit "${STUB_WRITER_RC:-0}"\n' \
            > "$R/scripts/setup-user-config.sh"
    else
        cp "$ROOT/scripts/deploy-harness.ps1" "$ROOT/scripts/aitools-lib.ps1" "$R/scripts/"
        printf '%s\n' 'param([switch]$DryRun, [switch]$Force)' \
            '$a = if ($DryRun) { "--dry-run" } else { "" }' \
            '[IO.File]::AppendAllText((Join-Path $env:USERPROFILE "writer-calls"), "called $a`n")' \
            '$rc = 0; if ($env:STUB_WRITER_RC) { $rc = [int]$env:STUB_WRITER_RC }' \
            'exit $rc' > "$R/scripts/setup-user-config.ps1"
    fi
}

# setup_case NAME: fixture aitools repo ($R), dotprofile ($D), HOME ($H) with config.json.
# Deployed: reference 3, registries 1, hooks 2, skills 3 (s1: 2 files, s2), rules 2
# (scratch, hook-lifecycle), bin 3 = 14 files. Never deployed (not harness
# sources): .claude/skills/s3, .claude/rules/{p1,p2}.md,
# the dotprofile claude/rules/user1.md.
setup_case() {
    C="$TMP_ROOT/$1"; R="$C/repo"; D="$C/dot"; H="$C/home"
    mkdir -p "$R/scripts" "$R/reference/evaluations" "$R/registries" "$R/shared/hooks" \
        "$R/shared/skills/s1/tests" "$R/shared/skills/s2" "$R/.claude/skills/s3" \
        "$R/shared/rules" "$R/.claude/rules" "$D/claude/rules" "$H/.aitools" "$C/logs"
    lang_scripts
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
    printf 'project rule two\n' > "$R/.claude/rules/p2.md"
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

write_config() {  # write_config USER_REPO_PATH (native paths: pwsh reads them on Windows)
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
        "$(native_path "$C")" "$(native_path "$R")" "$(native_path "$1")" > "$H/.aitools/config.json"
}

# ps_args ARGS...: the .sh flags as the .ps1 spells them, one per line
ps_args() {
    local a
    for a in "$@"; do
        case "$a" in
            --dry-run) printf '%s\n' -DryRun ;;
            --force)   printf '%s\n' -Force ;;
            --help)    printf '%s\n' -Help ;;
            *)         printf '%s\n' "$a" ;;
        esac
    done
}

# post_run: CRs removed from the summary and the console output; $LOG is the
# deploy log with CRs removed and, on Windows, \ turned into / (log lines name
# native paths), so one pattern serves both languages.
post_run() {
    if [ -f "$C/summary" ]; then perl -pi -e 's/\r//g' "$C/summary"; fi
    if [ -f "$C/out" ]; then perl -pi -e 's/\r//g' "$C/out"; fi
    LOG="$C/deploy.log.txt"
    if [ -f "$C/logs/deploy.log" ]; then
        if [ "$TEST_PLATFORM" = windows ]; then
            perl -pe 's/\r//g; s{\\}{/}g' "$C/logs/deploy.log" > "$LOG"
        else
            perl -pe 's/\r//g' "$C/logs/deploy.log" > "$LOG"
        fi
    else
        : > "$LOG"
    fi
}

# run_dh [input] -- ARGS...: run deploy-harness (.sh on macOS/Linux, .ps1 on
# Windows) under the case HOME. ARGS are the .sh flags (mapped for the .ps1).
# No input: stdin is /dev/null (non-interactive). Input: on a pty with keystrokes.
run_dh() {
    local input="$1"; shift
    [ "${1:-}" = "--" ] && shift
    local a=()
    if [ "$LANG_RUN" = ps1 ] && [ $# -gt 0 ]; then
        local line
        while IFS= read -r line; do a+=("$line"); done <<EOF
$(ps_args "$@")
EOF
    elif [ $# -gt 0 ]; then
        a=("$@")
    fi
    : > "$C/summary"
    if [ "$LANG_RUN" = sh ]; then
        if [ -z "$input" ]; then
            # shellcheck disable=SC2086  # EXTRA_ENV is a list of VAR=value words
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" AITOOLS_LOG_DIR="$C/logs" \
                AITOOLS_SUMMARY_FILE="$C/summary" ${EXTRA_ENV:-} \
                "$TB" "$R/scripts/deploy-harness.sh" ${a[@]+"${a[@]}"} < /dev/null > "$C/out" 2>&1
            echo $? > "$C/rc"
        else
            # shellcheck disable=SC2086
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" AITOOLS_LOG_DIR="$C/logs" \
                AITOOLS_SUMMARY_FILE="$C/summary" ${EXTRA_ENV:-} \
                python3 "$PTY" --input "$input" --log "$C/out" -- "$TB" "$R/scripts/deploy-harness.sh" ${a[@]+"${a[@]}"}
            echo $? > "$C/rc"
        fi
    else
        local nh nscript
        nh="$(native_path "$H")"; nscript="$(native_path "$R/scripts/deploy-harness.ps1")"
        if [ -z "$input" ]; then
            # shellcheck disable=SC2086
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$nh" USERPROFILE="$nh" \
                AITOOLS_LOG_DIR="$(native_path "$C/logs")" AITOOLS_SUMMARY_FILE="$(native_path "$C/summary")" ${EXTRA_ENV:-} \
                pwsh -NoProfile -NonInteractive -File "$nscript" ${a[@]+"${a[@]}"} < /dev/null > "$C/out" 2>&1
            echo $? > "$C/rc"
        else
            # shellcheck disable=SC2086
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$nh" USERPROFILE="$nh" \
                AITOOLS_LOG_DIR="$(native_path "$C/logs")" AITOOLS_SUMMARY_FILE="$(native_path "$C/summary")" ${EXTRA_ENV:-} \
                python3 "$(native_path "$PTY")" --input "$input" --log "$(native_path "$C/out")" -- \
                pwsh -NoProfile -File "$nscript" ${a[@]+"${a[@]}"}
            echo $? > "$C/rc"
        fi
    fi
    post_run
}

rc() { cat "$C/rc"; }
row() { grep -qxF "$1" "$C/summary"; }          # exact summary row
has_row() { grep -qF "$1" "$C/summary"; }       # summary substring
A() { printf '%s' "$H/.aitools"; }
is_sh() { [ "$LANG_RUN" = sh ]; }
lang="$LANG_RUN"

# ---------------------------------------------------------------------------
# First run, rerun, edit then rerun
# ---------------------------------------------------------------------------
setup_case first
run_dh "" --
check "first run: exit 0" "[ \"\$(rc)\" = 0 ]"
check "first run: six directories exist" \
    "[ -d '$(A)/reference' ] && [ -d '$(A)/registries' ] && [ -d '$(A)/hooks' ] && [ -d '$(A)/rules' ] && [ -d '$(A)/skills' ] && [ -d '$(A)/bin' ]"
check "first run: one OK row, 14 added" "row 'OK|harness files|14 added'"
check "first run: no ERROR row" "! grep -q '^ERROR|' '$C/summary'"
check "first run: config writer called without flags" "perl -pe 's/\r//' '$H/writer-calls' | grep -qx 'called '"
check "first run: reference tree kept (nested path)" "cmp -s '$R/reference/evaluations/e.md' '$(A)/reference/evaluations/e.md'"
check "first run: registries deployed (JSON)" "cmp -s '$R/registries/r.json' '$(A)/registries/r.json'"
check "first run: untracked file not deployed" "[ ! -e '$(A)/reference/untracked.md' ]"
check "first run: tracked *.bak.* not deployed" "[ ! -e '$(A)/hooks/h1.sh.bak.2026-01-01T000000Z' ]"
check "first run: hooks flat" "[ -f '$(A)/hooks/h1.sh' ] && [ -f '$(A)/hooks/hooks-manifest.json' ]"
check "first run: skills are directories (all files)" \
    "[ -f '$(A)/skills/s1/SKILL.md' ] && [ -f '$(A)/skills/s1/tests/t.md' ] && [ -f '$(A)/skills/s2/SKILL.md' ]"
check "first run: rules flat from shared/rules" \
    "[ -f '$(A)/rules/scratch.md' ] && [ -f '$(A)/rules/hook-lifecycle.md' ]"
check "first run: .claude/skills, .claude/rules and dotprofile rules not deployed" \
    "[ ! -e '$(A)/skills/s3' ] && [ ! -e '$(A)/rules/p1.md' ] && [ ! -e '$(A)/rules/p2.md' ] && [ ! -e '$(A)/rules/user1.md' ]"
check "first run: no .claude/rules, .claude/skills or dotprofile source looked at" \
    "! grep -qE 'Source (\\.claude/(rules|skills)|dotprofile)' '$LOG' && ! grep -qi 'dotprofile' '$LOG'"
check "first run: bin CLIs deployed" "[ -f '$(A)/bin/harness-db.py' ] && [ -f '$(A)/bin/read-session-full.py' ]"
if is_sh; then
    # Only the .sh sets the executable bit (deploy-harness.ps1 header).
    check "first run sh: hooks and bin CLIs executable" "[ -x '$(A)/hooks/h1.sh' ] && [ -x '$(A)/bin/harness-db.py' ] && [ -x '$(A)/bin/read-session-full.py' ]"
fi
check "first run: missing .claude/hooks is info, not error" "grep -q '\[info\] Source .claude/hooks not found' '$LOG'"

run_dh "" --
check "rerun: exit 0, everything verified" "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|14 verified'"
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
# no_menu: the console output shows no review menu (ANSI sequences removed)
no_menu() { ! perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g' "$C/out" | grep -q 'choice \['; }
if $HAVE_PTY; then
    setup_case adopt
    run_dh "" --
    printf '# Harness\n\nlocal edit\n' > "$(A)/reference/harness.md"
    run_dh 'a\n' --
    check "adopt: exit 0" "[ \"\$(rc)\" = 0 ]"
    check "adopt: LOCAL kept and copied to the repo source" \
        "grep -qx 'local edit' '$(A)/reference/harness.md' && grep -qx 'local edit' '$R/reference/harness.md'"
    check "adopt: aitools repo target left uncommitted and logged, no protected-file WARN" \
        "grep -q 'Uncommitted change in .*: harness.md' '$LOG' && ! grep -q 'Adopted into protected file' '$LOG'"
    check "adopt: DETAIL row" "grep -q '^DETAIL|harness files|accept & adopt: ' '$C/summary'"
    run_dh "" --
    check "adopt: next run verifies; repo backup not deployed" \
        "row 'OK|harness files|14 verified' && [ -z \"\$(find '$(A)/reference' -name '*.bak.*' -print)\" ]"

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
    printf 'local edit\n' > "$(A)/rules/hook-lifecycle.md"
    run_dh 'a\n' -- --force
    check "--force on a terminal: overwrite, no menu" \
        "[ \"\$(rc)\" = 0 ] && cmp -s '$R/shared/rules/hook-lifecycle.md' '$(A)/rules/hook-lifecycle.md' && no_menu"
    printf 'local edit\n' > "$(A)/rules/hook-lifecycle.md"
    EXTRA_ENV="AITOOLS_FORCE=1" run_dh 'a\n' --
    check "AITOOLS_FORCE=1 on a terminal: overwrite, no menu" \
        "[ \"\$(rc)\" = 0 ] && cmp -s '$R/shared/rules/hook-lifecycle.md' '$(A)/rules/hook-lifecycle.md' && no_menu"
else
    printf 'SKIP interactive cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Conflicts: first source wins, one ERROR row per skipped duplicate, exit 1
# ---------------------------------------------------------------------------
# Hooks still have two sources (shared/hooks, then .claude/hooks). Rules and
# skills of the same name in .claude/ or the dotprofile are not sources: no
# duplicate, nothing deployed from them.
setup_case conflict
mkdir -p "$R/.claude/hooks" "$R/.claude/skills/s1"
printf '#!/usr/bin/env bash\necho project hook\n' > "$R/.claude/hooks/h1.sh"
printf '{"Hooks": []}\n' > "$R/.claude/hooks/Hooks-Manifest.json"
printf 'project skill one\n' > "$R/.claude/skills/s1/SKILL.md"
printf 'project scratch rule\n' > "$R/.claude/rules/scratch.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m dups
printf 'dotprofile scratch rule\n' > "$D/claude/rules/scratch.md"
printf 'dotprofile lifecycle\n' > "$D/claude/rules/Hook-Lifecycle.md"
gitc -C "$D" add -A; gitc -C "$D" commit -q -m dups
run_dh "" --
check "conflict: exit 1" "[ \"\$(rc)\" = 1 ]"
check "conflict: ERROR row per duplicate (hooks), none for .claude/ or dotprofile rules and skills" \
    "row 'ERROR|harness files|h1.sh: dup in .claude/hooks' && row 'ERROR|harness files|Hooks-Manifest.json: dup in...' && [ \"\$(grep -c '^ERROR|' '$C/summary')\" = 2 ]"
check "conflict: log_error names both sources" "grep -q '\[error\] Duplicate hooks name: h1.sh in .claude/hooks .* kept h1.sh from shared/hooks' '$LOG'"
check "conflict: first source wins (hooks); shared rules and skills deployed" \
    "cmp -s '$R/shared/hooks/h1.sh' '$(A)/hooks/h1.sh' && cmp -s '$R/shared/rules/scratch.md' '$(A)/rules/scratch.md' && cmp -s '$R/shared/rules/hook-lifecycle.md' '$(A)/rules/hook-lifecycle.md' && cmp -s '$R/shared/skills/s1/SKILL.md' '$(A)/skills/s1/SKILL.md'"
check "conflict: case-insensitive duplicate not deployed" "grep -q '\"hooks\"' '$(A)/hooks/hooks-manifest.json' && ! ls '$(A)/hooks' | grep -qx 'Hooks-Manifest.json' && ! ls '$(A)/rules' | grep -qx 'Hook-Lifecycle.md'"
check "conflict: other files still deployed" "[ -f '$(A)/skills/s2/SKILL.md' ] && [ -f '$(A)/skills/s1/tests/t.md' ]"

# ---------------------------------------------------------------------------
# Dry run: report, write nothing
# ---------------------------------------------------------------------------
setup_case dryrun
run_dh "" -- --dry-run
check "dry run: exit 0, counts" "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|dry-run: 14 create, 0 update'"
check "dry run: no harness directory created" \
    "[ ! -e '$(A)/reference' ] && [ ! -e '$(A)/rules' ] && [ ! -e '$(A)/bin' ]"
check "dry run: config writer called with --dry-run" "perl -pe 's/\r//' '$H/writer-calls' | grep -qx 'called --dry-run'"
run_dh "" --
printf 'local edit\n' > "$(A)/rules/hook-lifecycle.md"
EXTRA_ENV="AITOOLS_DRY_RUN=1" run_dh "" --
check "AITOOLS_DRY_RUN=1: would update 1, file untouched" \
    "row 'OK|harness files|dry-run: 0 create, 1 update' && grep -qx 'local edit' '$(A)/rules/hook-lifecycle.md'"

# ---------------------------------------------------------------------------
# config.json writer failures
# ---------------------------------------------------------------------------
setup_case writerfail
EXTRA_ENV="STUB_WRITER_RC=1" run_dh "" --
check "writer failure: exit 1, ERROR row, files still deployed" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|config.json not generated' && [ -f '$(A)/rules/scratch.md' ]"

setup_case realwriter
if is_sh; then
    cp "$ROOT/scripts/setup-user-config.sh" "$ROOT/scripts/aitools-profile.sh" "$ROOT/scripts/aitools-json.pl" "$R/scripts/"
else
    cp "$ROOT/scripts/setup-user-config.ps1" "$ROOT/scripts/aitools-profile.ps1" "$ROOT/scripts/aitools-json.ps1" "$R/scripts/"
fi
rm -f "$H/.aitools/config.json"
run_dh "" --
check "real writer, no bootstrap config: exit 1, ERROR row propagated" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|config.json not generated' && grep -q '\[setup-user-config\] \[error\]' '$LOG'"

# ---------------------------------------------------------------------------
# The dotprofile is not a harness source: missing or not a git checkout changes nothing
# ---------------------------------------------------------------------------
setup_case nodot
write_config "$C/no-such-dotprofile"
run_dh "" --
check "missing dotprofile: exit 0, 14 added, not mentioned" \
    "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|14 added' && ! grep -qi 'dotprofile' '$LOG'"

setup_case nogitdot
rm -rf "$D/.git"
run_dh "" --
check "dotprofile not in git: exit 0, no ERROR row, its rules not deployed" \
    "[ \"\$(rc)\" = 0 ] && ! grep -q '^ERROR|' '$C/summary' && row 'OK|harness files|14 added' && [ ! -e '$(A)/rules/user1.md' ]"

# ---------------------------------------------------------------------------
# Rules manifest (~/.aitools/rules/.aitools-rules-manifest) and retired rules
# ---------------------------------------------------------------------------
M() { printf '%s' "$H/.aitools/rules/.aitools-rules-manifest"; }
# mf_is LINE... -- the manifest is exactly the header + these lines (LF, in order)
mf_is() {
    { printf '# aitools rules manifest v1\n'; printf '%s\n' "$@"; } > "$C/mf.expected"
    cmp -s "$C/mf.expected" "$(M)"
}
T="$(printf '\t')"
fresh_log() { mkdir -p "$C/logs"; : > "$C/logs/deploy.log"; }   # the log accumulates across the runs of a case
FIRST_MF=("hook-lifecycle.md${T}shared" "scratch.md${T}shared")

setup_case manifest
mkdir -p "$(A)/rules"
printf 'left over\n' > "$(A)/rules/old.md"
printf 'backup copy\n' > "$R/shared/rules/x.bak.1.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m bak
run_dh "" --
check "manifest: first run writes it (header, sorted, winning sources)" "[ \"\$(rc)\" = 0 ] && mf_is \"\${FIRST_MF[@]}\""
check "manifest: LF, no BOM" "! grep -q \$'\\r' '$(M)' && head -c 3 '$(M)' | grep -q '^# a'"
check "manifest: first run (no previous manifest) retires nothing" \
    "[ -f '$(A)/rules/old.md' ] && grep -q 'Preserved: .*rules/old.md' '$LOG' && ! grep -q 'Retired rule' '$LOG'"
check "manifest: *.bak.* never listed, manifest itself not preserved" \
    "! grep -q 'bak' '$(M)' && ! grep -q 'Preserved: .*aitools-rules-manifest' '$LOG' && [ ! -e '$(M).tmp' ]"
check "manifest: no .md extension (consumers copying *.md skip it)" "[ -f '$(M)' ] && ! ls '$(A)/rules' | grep -q 'manifest.*\\.md'"

gitc -C "$R" rm -q shared/rules/scratch.md; gitc -C "$R" commit -q -m retire
fresh_log
run_dh "" --
check "retire: exit 0, line becomes retired" \
    "[ \"\$(rc)\" = 0 ] && mf_is 'hook-lifecycle.md${T}shared' 'scratch.md${T}retired'"
check "retire: file backed up and removed, logged, DETAIL row" \
    "[ ! -e '$(A)/rules/scratch.md' ] && ls '$(A)/rules/'scratch.md.bak.* >/dev/null 2>&1 && grep -q 'Retired rule: scratch.md (was shared' '$LOG' && row 'DETAIL|harness files|retired: rules/scratch.md'"
check "retire: a file never in a manifest is still preserved" "[ -f '$(A)/rules/old.md' ]"
fresh_log
run_dh "" --
check "retired line persists; no new backup, no row" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'scratch.md${T}retired' '$(M)' && [ \"\$(ls '$(A)/rules/' | grep -c '^scratch.md.bak')\" = 1 ] && ! has_row 'retired:'"
printf 'scratch again\n' > "$(A)/rules/scratch.md"
run_dh "" --
check "retired name's file found again: backed up and removed" \
    "[ ! -e '$(A)/rules/scratch.md' ] && grep -lq 'scratch again' '$(A)/rules/'scratch.md.bak.* && grep -qx 'scratch.md${T}retired' '$(M)'"
printf 'shared scratch again\n' > "$R/shared/rules/scratch.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m back
run_dh "" --
check "reappearing name returns to its source and is deployed" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'scratch.md${T}shared' '$(M)' && grep -qx 'shared scratch again' '$(A)/rules/scratch.md'"

# Migration from the three-source harness: a previous manifest (and
# ~/.aitools/rules) still holds rules deployed from aitools .claude/rules
# ("aitools") and the dotprofile ("dotprofile"). Both sources are withdrawn:
# their names are retired on the next run, although neither is listed, and
# whether or not the dotprofile exists. The .claude/rules and dotprofile files
# that still exist in the repos change nothing.
seed_withdrawn_rules() {
    printf '# aitools rules manifest v1\nhook-lifecycle.md\tshared\np1.md\taitools\np2.md\taitools\nscratch.md\tshared\nuser1.md\tdotprofile\n' > "$(M)"
    printf 'project rule\n' > "$(A)/rules/p1.md"
    printf 'project rule two\n' > "$(A)/rules/p2.md"
    printf 'user rule\n' > "$(A)/rules/user1.md"
}
seed_withdrawn_rules
fresh_log
run_dh "" -- --dry-run
check "withdrawn sources, dry run: retirement reported, nothing removed or written" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/rules/p1.md' ] && [ -f '$(A)/rules/user1.md' ] && grep -qx 'p1.md${T}aitools' '$(M)' && grep -qx 'user1.md${T}dotprofile' '$(M)' && grep -q 'DRY RUN\] Would back up and remove .*rules/user1.md' '$LOG' && grep -q 'DRY RUN\] Would back up and remove .*rules/p1.md' '$LOG'"
fresh_log
run_dh "" --
check "withdrawn sources: aitools and dotprofile names retired (backed up, removed), DETAIL rows" \
    "[ \"\$(rc)\" = 0 ] && mf_is 'hook-lifecycle.md${T}shared' 'p1.md${T}retired' 'p2.md${T}retired' 'scratch.md${T}shared' 'user1.md${T}retired' && [ ! -e '$(A)/rules/p1.md' ] && [ ! -e '$(A)/rules/p2.md' ] && [ ! -e '$(A)/rules/user1.md' ] && ls '$(A)/rules/'user1.md.bak.* >/dev/null 2>&1 && ls '$(A)/rules/'p1.md.bak.* >/dev/null 2>&1 && row 'DETAIL|harness files|retired: rules/p1.md' && row 'DETAIL|harness files|retired: rules/user1.md' && grep -q 'Retired rule: user1.md (was dotprofile' '$LOG' && grep -q 'Retired rule: p1.md (was aitools' '$LOG'"
check "withdrawn sources: shared rules untouched" \
    "[ -f '$(A)/rules/scratch.md' ] && [ -f '$(A)/rules/hook-lifecycle.md' ] && ! ls '$(A)/rules/' | grep -q '^hook-lifecycle.md.bak'"
seed_withdrawn_rules
write_config "$C/no-such-dotprofile"
fresh_log
run_dh "" --
check "withdrawn sources, no dotprofile configured: retired all the same" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'user1.md${T}retired' '$(M)' && grep -qx 'p1.md${T}retired' '$(M)' && [ ! -e '$(A)/rules/user1.md' ] && ! grep -q 'kept as' '$LOG'"
write_config "$D"

# A source that is not listed this run keeps its names (shared/rules missing)
gitc -C "$R" rm -q -r shared/rules; gitc -C "$R" commit -q -m no-shared-rules
fresh_log
run_dh "" --
check "source not listed (shared/rules missing): its names keep their lines, files kept" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'scratch.md${T}shared' '$(M)' && [ -f '$(A)/rules/scratch.md' ] && grep -q 'scratch.md kept as shared' '$LOG' && grep -q 'Source shared/rules not found' '$LOG'"
gitc -C "$R" checkout -q HEAD~1 -- shared/rules; gitc -C "$R" commit -q -m shared-rules-back

printf '# aitools rules manifest v1\nScratch.md\tshared\nHOOK-LIFECYCLE.md\taitools\n' > "$(M)"
fresh_log
run_dh "" --
check "names compared case-insensitively: a case variant is not retired (withdrawn source too)" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/rules/scratch.md' ] && [ -f '$(A)/rules/hook-lifecycle.md' ] && ! grep -q 'Retired rule' '$LOG' && ! grep -q 'Scratch.md' '$(M)' && ! grep -q 'HOOK-LIFECYCLE' '$(M)'"
printf 'not a manifest\nold.md\tshared\n' > "$(M)"
fresh_log
run_dh "" --
check "unknown header: warning, nothing retired, rewritten" \
    "[ -f '$(A)/rules/old.md' ] && grep -q '\[warn\] Rules manifest .*the first line is not' '$LOG' && head -n 1 '$(M)' | grep -qx '# aitools rules manifest v1' && ! grep -q '^old.md' '$(M)'"
printf '# aitools rules manifest v1\n../evil.md\tshared\nnotes.txt\tshared\nz.md\tbogus\n' > "$(M)"
printf 'keep me\n' > "$(A)/evil.md"    # where rules/../evil.md resolves
fresh_log
run_dh "" --
check "invalid lines ignored with a warning (no path outside rules/)" \
    "[ -f '$(A)/evil.md' ] && [ \"\$(grep -c 'line ignored' '$LOG')\" = 3 ] && ! grep -q 'evil' '$(M)'"
mkdir -p "$(A)/rules/d.md"
printf 'inside\n' > "$(A)/rules/d.md/f"
printf '# aitools rules manifest v1\nd.md\tretired\n' > "$(M)"
fresh_log
run_dh "" --
check "a directory named like a retired rule is left alone" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/rules/d.md/f' ] && grep -qx 'd.md${T}retired' '$(M)'"

# Retirement edge cases on a fresh case: a name with [ ], then (POSIX only) a
# failed backup and the retry
run_dh_plain() { run_dh "" --; }
setup_case retire
printf 'bracket\n' > "$R/shared/rules/a[1].md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m bracket
run_dh_plain
gitc -C "$R" rm -q 'shared/rules/a[1].md'; gitc -C "$R" commit -q -m bracket-gone
fresh_log; run_dh_plain
check "$lang: retired name with [ ] is backed up before removal" \
    "[ ! -e '$(A)/rules/a[1].md' ] && ls '$(A)/rules' | grep -qF 'a[1].md.bak.' && grep -qxF 'a[1].md${T}retired' '$(M)'"
if $HAVE_READONLY; then
    gitc -C "$R" rm -q shared/rules/hook-lifecycle.md; gitc -C "$R" commit -q -m hl-gone
    chmod 555 "$(A)/rules"
    fresh_log; run_dh_plain
    chmod 755 "$(A)/rules"
    check "$lang: failed backup keeps the file (ERROR row, exit 1)" \
        "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/rules/hook-lifecycle.md' ] && row 'ERROR|harness files|retire failed: hook-lifecyc...' && grep -q 'backup failed' '$LOG'"
    fresh_log; run_dh_plain
    check "$lang: next run retries and removes it" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/rules/hook-lifecycle.md' ] && grep -qx 'hook-lifecycle.md${T}retired' '$(M)'"
    chmod 555 "$(A)/rules"
    run_dh "" --
    chmod 755 "$(A)/rules"
    check "manifest write failure: ERROR row, exit 1, run completes" \
        "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|rules manifest not written' && grep -q 'harness files: .* retired' '$LOG'"
else
    printf 'SKIP failed rule backup and manifest write failure (chmod does not block writes here)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Skills manifest (~/.aitools/skills/.aitools-skills-manifest) and retired skills
# (plan skills-and-rules-fanout.md section 3.2, FO-2). One case sequence; each
# step's exit code, summary rows, manifest and skills tree go to a trace that
# must equal the golden file (the .sh on macOS/Linux and the .ps1 on Windows
# share it). The read-only steps (POSIX only) come last, with their own trace.
# ---------------------------------------------------------------------------
SM() { printf '%s' "$H/.aitools/skills/.aitools-skills-manifest"; }
# smf_is LINE... -- the skills manifest is exactly the header + these lines (LF, in order)
smf_is() {
    { printf '# aitools skills manifest v1\n'; printf '%s\n' "$@"; } > "$C/smf.expected"
    cmp -s "$C/smf.expected" "$(SM)"
}
# n_bak NAME -- number of NAME.bak.* directories in ~/.aitools/skills (literal name)
n_bak() {
    perl -e 'opendir my $d, $ARGV[0] or die "cannot list $ARGV[0]: $!\n"; my $p = "$ARGV[1].bak.";
        print scalar(grep { substr($_, 0, length $p) eq $p && -d "$ARGV[0]/$_" } readdir $d), "\n"' "$(A)/skills" "$1"
}
# The skill named with glob characters: '*' and '?' cannot be in a Windows file
# name, so Windows uses the brackets only. The trace writes the name as <BN>.
if [ "$TEST_PLATFORM" = windows ]; then BN='b[1]'; else BN='b[1] *?'; fi
# trace STEP -- append the observable state (timestamps and the glob skill name
# normalized) to $TRACE
TRACE=""
trace() {
    {
        printf '== %s rc=%s\n' "$1" "$(rc)"
        cat "$C/summary"
        printf -- '-- manifest\n'
        if [ -f "$(SM)" ]; then cat "$(SM)"; fi
        printf -- '-- tree\n'
        (cd "$(A)/skills" && find . | LC_ALL=C sort)
    } | BN="$BN" perl -pe 's/\r//g; s/\.bak\.\d{4}-\d\d-\d\dT\d{6}Z/.bak.TS/g; s/\Q$ENV{BN}\E/<BN>/g' >> "$TRACE"
}
run_sk() { fresh_log; run_dh "" -- "$@"; }

setup_case skills
TRACE="$C/trace"
mkdir -p "$D/claude/skills/d1/ref" "$R/shared/skills/.hidden" "$R/shared/skills/old.bak.1"
printf 'dotprofile skill\n' > "$D/claude/skills/d1/SKILL.md"
printf 'dotprofile ref\n' > "$D/claude/skills/d1/ref/x.md"
gitc -C "$D" add -A; gitc -C "$D" commit -q -m skills
printf 'hidden\n' > "$R/shared/skills/.hidden/SKILL.md"
printf 'backup\n' > "$R/shared/skills/old.bak.1/SKILL.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m hidden

run_sk; trace first
check "$lang skills: first run writes the manifest (sorted, shared only)" \
    "[ \"\$(rc)\" = 0 ] && smf_is 's1${T}shared' 's2${T}shared'"
check "$lang skills: .claude/skills and dotprofile skills not deployed" \
    "[ ! -e '$(A)/skills/s3' ] && [ ! -e '$(A)/skills/d1' ]"
check "$lang skills: hidden and *.bak.* skill directories neither deployed nor listed" \
    "[ ! -e '$(A)/skills/.hidden' ] && [ ! -e '$(A)/skills/old.bak.1' ] && ! grep -q 'hidden\|old' '$(SM)'"
check "$lang skills: manifest not reported as preserved, no .tmp left" \
    "! grep -q 'Preserved: .*aitools-skills-manifest' '$LOG' && [ ! -e '$(SM).tmp' ]"

# Migration from the three-source harness: the previous manifest and
# ~/.aitools/skills still hold s3 (from .claude/skills, "aitools") and d1 (from
# the dotprofile). Both sources are withdrawn: both skills are retired.
printf '# aitools skills manifest v1\nd1\tdotprofile\ns1\tshared\ns2\tshared\ns3\taitools\n' > "$(SM)"
mkdir -p "$(A)/skills/d1/ref" "$(A)/skills/s3"
printf 'dotprofile skill\n' > "$(A)/skills/d1/SKILL.md"
printf 'dotprofile ref\n' > "$(A)/skills/d1/ref/x.md"
printf 'skill three\n' > "$(A)/skills/s3/SKILL.md"
run_sk --dry-run; trace dryrun
check "$lang skills: withdrawn sources, dry run -- retirement reported, nothing removed or written" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/skills/d1/SKILL.md' ] && [ -f '$(A)/skills/s3/SKILL.md' ] && grep -qx 'd1${T}dotprofile' '$(SM)' && grep -q '\[DRY RUN\] Retired skill: d1 (was dotprofile' '$LOG' && grep -q '\[DRY RUN\] Retired skill: s3 (was aitools' '$LOG' && [ \"\$(n_bak d1)\" = 0 ]"
run_sk; trace withdrawn
check "$lang skills: withdrawn sources -- d1 and s3 retired (verified backups), DETAIL rows" \
    "[ \"\$(rc)\" = 0 ] && smf_is 'd1${T}retired' 's1${T}shared' 's2${T}shared' 's3${T}retired' && [ ! -e '$(A)/skills/d1' ] && [ ! -e '$(A)/skills/s3' ] && [ \"\$(n_bak d1)\" = 1 ] && [ \"\$(n_bak s3)\" = 1 ] && grep -rqx 'dotprofile ref' '$(A)/skills/'d1.bak.*/ref/x.md && row 'DETAIL|harness files|retired: skills/d1' && row 'DETAIL|harness files|retired: skills/s3'"

# The #74/#75 layout move: a skill moves from .claude/skills to shared/skills
# and is deployed again, from shared
gitc -C "$R" mv .claude/skills/s3 shared/skills/s3; gitc -C "$R" commit -q -m move
run_sk; trace move
check "$lang skills: moved .claude -> shared: deployed again, source shared, nothing retired" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 's3${T}shared' '$(SM)' && [ -f '$(A)/skills/s3/SKILL.md' ] && ! grep -q 'Retired skill' '$LOG' && [ \"\$(n_bak s3)\" = 1 ]"

gitc -C "$R" rm -q -r shared/skills/s2; gitc -C "$R" commit -q -m retire
run_sk; trace retire
check "$lang skills: removed from its source -- retired line, DETAIL row" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 's2${T}retired' '$(SM)' && row 'DETAIL|harness files|retired: skills/s2' && grep -q 'Retired skill: s2 (was shared' '$LOG'"
check "$lang skills: harness directory backed up (backup_dir) and removed" \
    "[ ! -e '$(A)/skills/s2' ] && [ \"\$(n_bak s2)\" = 1 ] && grep -rqx 'skill two' '$(A)/skills/'s2.bak.*/SKILL.md"
check "$lang skills: backup directory not reported as preserved" "! grep -q 'Preserved: .*s2.bak' '$LOG'"

run_sk; trace rerun
check "$lang skills: retired line persists; no new backup, no row" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 's2${T}retired' '$(SM)' && [ \"\$(n_bak s2)\" = 1 ] && ! has_row 'retired:'"

# A skill with no top-level *.md, one named with glob characters ($BN; old
# backups pruned to 5 by literal name; a decoy that the glob would match is
# kept), and an upper-case .BAK. directory (not a skill name, never deployed)
mkdir -p "$R/shared/skills/nomd/a" "$R/shared/skills/$BN" "$R/shared/skills/x.BAK.y"
printf 'nested only\n' > "$R/shared/skills/nomd/a/x.md"
printf 'bracket skill\n' > "$R/shared/skills/$BN/SKILL.md"
printf 'upper bak\n' > "$R/shared/skills/x.BAK.y/SKILL.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m copy-cases
run_sk; trace copydeploy
check "$lang skills: nested-only and glob-named skills deployed; .BAK. directory not (case-insensitive)" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/skills/nomd/a/x.md' ] && [ -f \"$(A)/skills/\$BN/SKILL.md\" ] && [ ! -e '$(A)/skills/x.BAK.y' ] && ! grep -qi 'x.bak.y' '$(SM)'"
for i in 1 2 3 4 5 6; do
    mkdir -p "$(A)/skills/$BN.bak.2026-01-0${i}T000000Z"
    printf 'old %s\n' "$i" > "$(A)/skills/$BN.bak.2026-01-0${i}T000000Z/SKILL.md"
done
mkdir -p "$(A)/skills/b1.bak.2026-01-01T000000Z"
printf 'decoy\n' > "$(A)/skills/b1.bak.2026-01-01T000000Z/SKILL.md"
gitc -C "$R" rm -q -r shared/skills/nomd "shared/skills/$BN"; gitc -C "$R" commit -q -m copy-retire
run_sk; trace copyretire
check "$lang skills: retired skill with no top-level *.md -- copied, verified, removed" \
    "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/nomd' ] && [ \"\$(n_bak nomd)\" = 1 ] && grep -rqx 'nested only' '$(A)/skills/'nomd.bak.*/a/x.md && row 'DETAIL|harness files|retired: skills/nomd'"
check "$lang skills: glob-named skill retired; its backups pruned to 5 (oldest two); decoy kept" \
    "[ ! -e \"$(A)/skills/\$BN\" ] && [ \"\$(n_bak \"\$BN\")\" = 5 ] && [ ! -e \"$(A)/skills/\$BN.bak.2026-01-01T000000Z\" ] && [ ! -e \"$(A)/skills/\$BN.bak.2026-01-02T000000Z\" ] && [ -d \"$(A)/skills/\$BN.bak.2026-01-03T000000Z\" ] && [ -f '$(A)/skills/b1.bak.2026-01-01T000000Z/SKILL.md' ]"

printf 'a file\n' > "$(A)/skills/zz"
printf '# aitools skills manifest v1\nzz\tretired\n../evil\tshared\n.hidden\tshared\nx.bak.1\tshared\na/b\tshared\nok\tbogus\n' > "$(SM)"
run_sk; trace invalid
check "$lang skills: invalid lines ignored (5 warnings); a file named like a retired skill left alone" \
    "[ \"\$(rc)\" = 0 ] && [ \"\$(grep -c 'line ignored' '$LOG')\" = 5 ] && [ -f '$(A)/skills/zz' ] && grep -q 'Retired skill zz: .* is not a directory' '$LOG' && row 'WARN|harness files|not a dir: zz' && grep -qx 'zz${T}retired' '$(SM)' && ! grep -q 'evil\|hidden\|bogus' '$(SM)'"
printf 'not a manifest\nd2\tdotprofile\n' > "$(SM)"
run_sk; trace header
check "$lang skills: unknown header -- warning, nothing retired, rewritten" \
    "[ \"\$(rc)\" = 0 ] && grep -q '\[warn\] Skills manifest .*the first line is not' '$LOG' && head -n 1 '$(SM)' | grep -qx '# aitools skills manifest v1' && ! grep -q 'retired' '$(SM)'"

# A directory at the manifest paths (skills and rules): ERROR, exit 1, nothing moved into it
rm -f "$(SM)" "$(M)"
mkdir -p "$(SM)" "$(M)"
printf 'inside\n' > "$(SM)/inside"
run_sk; trace mfdir
check "$lang skills: manifest path is a directory -- ERROR rows (skills, rules), exit 1, nothing written into it, contents not reported preserved" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|skills manifest not written' && row 'ERROR|harness files|rules manifest not written' && [ \"\$(ls -A '$(SM)')\" = inside ] && [ -z \"\$(ls -A '$(M)')\" ] && grep -q 'Skills manifest: .* is a directory' '$LOG' && ! grep -q 'Preserved: .*aitools-skills-manifest' '$LOG'"
rm -rf "$(SM)" "$(M)"
run_sk; trace mfdirgone
check "$lang skills: directory removed -- both manifests written again" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(SM)' ] && [ -f '$(M)' ]"
check "skills parity: trace equals the golden file (sh and ps1 share it)" \
    "[ \"\$(grep -c '^== ' '$TRACE')\" -ge 12 ] && golden_match skills.trace '$TRACE'"

if $HAVE_READONLY; then
    TRACE="$C/trace-ro"
    # Partial backup: an unreadable file in the retired skill's directory
    mkdir -p "$R/shared/skills/pb"
    printf 'partial\n' > "$R/shared/skills/pb/SKILL.md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m pb
    run_sk; trace pbdeploy
    printf 'secret\n' > "$(A)/skills/pb/secret.md"
    chmod 000 "$(A)/skills/pb/secret.md"
    gitc -C "$R" rm -q -r shared/skills/pb; gitc -C "$R" commit -q -m pb-gone
    run_sk; trace pbfail
    chmod 644 "$(A)/skills/pb/secret.md"
    check "$lang skills: partial backup removed again; directory kept (ERROR row, exit 1)" \
        "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/pb/SKILL.md' ] && [ \"\$(n_bak pb)\" = 0 ] && row 'ERROR|harness files|retire failed: pb' && grep -q 'Retired skill pb: backup failed (' '$LOG' && grep -q 'Retired skill pb: removed the incomplete backup' '$LOG'"
    run_sk; trace pbretry
    check "$lang skills: readable again -- backed up and removed" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/pb' ] && [ \"\$(n_bak pb)\" = 1 ] && grep -rqx 'secret' '$(A)/skills/'pb.bak.*/secret.md"

    # Partial backup holding a read-only (555) subdirectory: cleanup must still work
    mkdir -p "$R/shared/skills/rs/ro"
    printf 'ro skill\n' > "$R/shared/skills/rs/SKILL.md"
    printf 'ro file\n' > "$R/shared/skills/rs/ro/a.md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m rs
    run_sk; trace rsdeploy
    printf 'secret\n' > "$(A)/skills/rs/ro/secret.md"
    chmod 000 "$(A)/skills/rs/ro/secret.md"
    chmod 555 "$(A)/skills/rs/ro"
    gitc -C "$R" rm -q -r shared/skills/rs; gitc -C "$R" commit -q -m rs-gone
    run_sk; trace rsfail
    chmod 755 "$(A)/skills/rs/ro"
    chmod 644 "$(A)/skills/rs/ro/secret.md"
    check "$lang skills: partial backup with a read-only subdirectory removed (no leftover, nothing renamed)" \
        "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/rs/ro/a.md' ] && [ \"\$(n_bak rs)\" = 0 ] && row 'ERROR|harness files|retire failed: rs' && ! has_row 'bak cleanup failed' && grep -q 'Retired skill rs: removed the incomplete backup' '$LOG'"
    run_sk; trace rsretry
    check "$lang skills: read-only case retried -- backed up and removed" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/rs' ] && [ \"\$(n_bak rs)\" = 1 ]"

    gitc -C "$R" rm -q -r shared/skills/s1; gitc -C "$R" commit -q -m s1-gone
    chmod 555 "$(A)/skills"
    run_sk; trace bakfail
    chmod 755 "$(A)/skills"
    check "$lang skills: failed backup keeps the directory (ERROR row, exit 1)" \
        "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/s1/SKILL.md' ] && row 'ERROR|harness files|retire failed: s1' && grep -q 'Retired skill s1: backup failed' '$LOG' && [ \"\$(n_bak s1)\" = 0 ]"
    run_sk; trace bakretry
    check "$lang skills: next run retries -- backed up and removed" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/s1' ] && [ \"\$(n_bak s1)\" = 1 ] && grep -qx 's1${T}retired' '$(SM)'"
    check "skills read-only parity: trace equals the golden file" "golden_match skills-readonly.trace '$TRACE'"
else
    printf 'SKIP skills partial and failed backups (chmod does not block reads or writes here)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Rule names with an upper- or mixed-case .md extension (plan rules-fanout-claude.md
# F2/R9; D1 "case-insensitive, *.md only, skipping *.bak.*"): deployed as named,
# listed in the manifest, no warning on the next run, retired when the source
# goes; a case variant in the dotprofile is not a source (no duplicate, not
# deployed); .bak. names are still rejected.
# ---------------------------------------------------------------------------
# lsx NAME -- NAME is in ~/.aitools/rules with exactly this case (macOS and
# Windows file systems are case-insensitive, so [ -f ] alone cannot tell X.MD from x.md)
lsx() { ls "$(A)/rules" | grep -qxF "$1"; }
no_warn_rows() { ! grep -qE '^(WARN|ACTION)\|' "$C/summary"; }
setup_case upper
printf 'upper rule\n' > "$R/shared/rules/X.MD"
printf 'upper backup\n' > "$R/shared/rules/Old.BAK.1.MD"
printf 'mixed rule\n' > "$R/shared/rules/Mixed.Md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m upper
fresh_log; run_dh_plain
check "$lang upper: X.MD and Mixed.Md deployed as named, exit 0, no WARN/ACTION row" \
    "[ \"\$(rc)\" = 0 ] && lsx X.MD && lsx Mixed.Md && grep -qx 'upper rule' '$(A)/rules/X.MD' && no_warn_rows"
check "$lang upper: listed in the manifest with their source" \
    "grep -qxF 'X.MD${T}shared' '$(M)' && grep -qxF 'Mixed.Md${T}shared' '$(M)'"
check "$lang upper: .BAK. name (any case) neither deployed nor listed" \
    "! ls '$(A)/rules' | grep -qi '^old\\.bak' && ! grep -qi '^old\\.bak' '$(M)'"

fresh_log; run_dh_plain
check "$lang upper: rerun -- manifest lines accepted (no 'line ignored', no WARN/ACTION), verified" \
    "[ \"\$(rc)\" = 0 ] && ! grep -q 'line ignored' '$LOG' && no_warn_rows && grep -qE '^OK\\|harness files\\|[0-9]+ verified\$' '$C/summary'"

printf 'shared dup\n' > "$R/shared/rules/dup.md"
printf 'dotprofile dup\n' > "$D/claude/rules/DUP.MD"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m dup
gitc -C "$D" add -A; gitc -C "$D" commit -q -m dup
fresh_log; run_dh_plain
check "$lang upper: case variant in the dotprofile (DUP.MD) -- not a source: no ERROR row, not deployed" \
    "[ \"\$(rc)\" = 0 ] && ! grep -q '^ERROR|' '$C/summary' && lsx dup.md && ! lsx DUP.MD && grep -qx 'shared dup' '$(A)/rules/dup.md' && grep -qxF 'dup.md${T}shared' '$(M)' && ! grep -q '^DUP' '$(M)'"
gitc -C "$D" rm -q claude/rules/DUP.MD; gitc -C "$D" commit -q -m undup

printf 'Q.MD.BAK.1\tshared\nq.MD.bak.2\tshared\n' >> "$(M)"
fresh_log; run_dh_plain
check "$lang upper: manifest names with .bak. (any case) still ignored" \
    "[ \"\$(rc)\" = 0 ] && [ \"\$(grep -c 'line ignored' '$LOG')\" = 2 ] && grep -q 'line ignored: Q.MD.BAK.1<TAB>shared' '$LOG' && ! grep -qi '^q\\.md\\.bak' '$(M)'"

gitc -C "$R" rm -q shared/rules/X.MD; gitc -C "$R" commit -q -m retire-upper
gitc -C "$R" rm -q shared/rules/Mixed.Md; gitc -C "$R" commit -q -m retire-mixed
fresh_log; run_dh_plain
check "$lang upper: source removed -- retired (backup kept, file removed), DETAIL rows, no WARN" \
    "[ \"\$(rc)\" = 0 ] && grep -qxF 'X.MD${T}retired' '$(M)' && grep -qxF 'Mixed.Md${T}retired' '$(M)' && ! ls '$(A)/rules' | grep -qix 'x.md' && ! ls '$(A)/rules' | grep -qix 'mixed.md' && ls '$(A)/rules' | grep -q '^X\\.MD\\.bak\\.' && ls '$(A)/rules' | grep -q '^Mixed\\.Md\\.bak\\.' && row 'DETAIL|harness files|retired: rules/X.MD' && row 'DETAIL|harness files|retired: rules/Mixed.Md' && ! grep -q 'line ignored' '$LOG' && no_warn_rows"

# The lib's manifest reader (read_harness_manifest / Read-HarnessManifest), as
# setup-user-cursor and setup-user-claude call it: upper- and mixed-case
# extensions are valid; a case-only duplicate and a .bak. name are invalid.
setup_case reader
printf '# aitools rules manifest v1\nX.MD\tdotprofile\nMixed.Md\tshared\nx.md\tshared\nY.MD.bak.1\tshared\n' > "$C/mf"
printf 'rule\tX.MD\tdotprofile\nrule\tMixed.Md\tshared\ninvalid\tx.md<TAB>shared\ninvalid\tY.MD.bak.1<TAB>shared\n' > "$C/reader.expected"
if is_sh; then
    printf 'source "$1/scripts/aitools-lib.sh"\nlogging_init "test-deploy-harness-reader"\nread_harness_manifest "$2" rules\n' > "$C/reader.sh"
    env HOME="$H" AITOOLS_LOG_DIR="$C/logs" "$TB" "$C/reader.sh" "$ROOT" "$C/mf" > "$C/reader.out" 2> "$C/reader.err"
else
    printf '%s\n' 'param([string]$Repo, [string]$Mf)' \
        '$ErrorActionPreference = "Stop"' \
        '. (Join-Path $Repo "scripts/aitools-lib.ps1")' \
        'Initialize-Logging "test-deploy-harness-reader"' \
        '$r = Read-HarnessManifest -Path $Mf -Kind "rules"' \
        '$out = [System.Text.StringBuilder]::new()' \
        'foreach ($x in $r.Rules) { [void]$out.Append("rule`t$($x.Name)`t$($x.Source)`n") }' \
        'foreach ($x in $r.Invalid) { [void]$out.Append("invalid`t$x`n") }' \
        '[Console]::Out.Write($out.ToString())' > "$C/reader.ps1"
    env HOME="$(native_path "$H")" USERPROFILE="$(native_path "$H")" AITOOLS_LOG_DIR="$(native_path "$C/logs")" \
        pwsh -NoProfile -NonInteractive -File "$(native_path "$C/reader.ps1")" -Repo "$(native_path "$ROOT")" -Mf "$(native_path "$C/mf")" \
        > "$C/reader.out" 2> "$C/reader.err"
fi
echo $? > "$C/rc"
perl -pi -e 's/\r//g' "$C/reader.out"
check "reader $lang: X.MD and Mixed.Md valid; case-only duplicate and .bak. invalid" \
    "[ \"\$(rc)\" = 0 ] && cmp -s '$C/reader.expected' '$C/reader.out'"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
setup_case args
run_dh "" -- --bogus
check "bad argument: exit 1, ERROR row" "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|bad arguments'"
run_dh "" -- --help
check "--help: exit 0, usage shown, nothing deployed" \
    "[ \"\$(rc)\" = 0 ] && grep -q 'Usage: deploy-harness.$lang' '$C/out' && [ ! -e '$(A)/rules' ]"

printf '\n%d passed, %d failed, %d skipped (%s: %s scripts)\n' "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" "$lang"
[ "$FAIL" -eq 0 ]
