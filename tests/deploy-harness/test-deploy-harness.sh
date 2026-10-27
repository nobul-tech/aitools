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
# missing / non-git dotprofile, preserved files, bad arguments, --help, the
# rules manifest and retired rules (.sh, and the .ps1 on pwsh when available),
# the skills manifest and retired skills (dotprofile skills source, shared vs
# .claude duplicate, the .claude -> shared move, retire with a verified
# backup_dir backup, unlisted source, per-kind listing, dry run, failed backup,
# invalid lines, bad header), run by the .sh and the .ps1 with identical traces.
# Interactive cases use tests/managed-files/pty-run.py (python3); skipped
# without it. The config writer is a stub except in the "real writer" case.
# Platform: macOS, Linux. Exit 1 if any case fails.
#
# Usage: bash tests/deploy-harness/test-deploy-harness.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 22' "$0"
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
    "[ \"\$(rc)\" = 0 ] && grep -q '\[info\] Dotprofile .* not found -- dotprofile rules and skills skipped' '$LOG' && row 'OK|harness files|17 added'"

setup_case nogitdot
rm -rf "$D/.git"
run_dh "" --
check "dotprofile not in git: ERROR row, exit 1" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|dotprofile: not a git checkout' && [ ! -e '$(A)/rules/user1.md' ]"

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
fresh_log() { : > "$C/logs/deploy.log"; }   # the log accumulates across the runs of a case
FIRST_MF=("hook-lifecycle.md${T}shared" "p1.md${T}aitools" "scratch.md${T}shared" "sources-of-truth.md${T}aitools" "user1.md${T}dotprofile")

setup_case manifest
mkdir -p "$(A)/rules"
printf 'left over\n' > "$(A)/rules/old.md"
printf 'backup copy\n' > "$R/shared/rules/x.bak.1.md"
gitc -C "$R" add -A; gitc -C "$R" commit -q -m bak
run_dh "" --
check "manifest: first run writes it (header, sorted, winning sources)" "[ \"\$(rc)\" = 0 ] && mf_is \"\${FIRST_MF[@]}\""
check "manifest: first run (no previous manifest) retires nothing" \
    "[ -f '$(A)/rules/old.md' ] && grep -q 'Preserved: .*rules/old.md' '$LOG' && ! grep -q 'Retired rule' '$LOG'"
check "manifest: *.bak.* never listed, manifest itself not preserved" \
    "! grep -q 'bak' '$(M)' && ! grep -q 'Preserved: .*aitools-rules-manifest' '$LOG' && [ ! -e '$(M).tmp' ]"
check "manifest: no .md extension (consumers copying *.md skip it)" "[ -f '$(M)' ] && ! ls '$(A)/rules' | grep -q 'manifest.*\\.md'"

gitc -C "$R" rm -q shared/rules/scratch.md; gitc -C "$R" commit -q -m retire
fresh_log
run_dh "" --
check "retire: exit 0, line becomes retired" \
    "[ \"\$(rc)\" = 0 ] && mf_is 'hook-lifecycle.md${T}shared' 'p1.md${T}aitools' 'scratch.md${T}retired' 'sources-of-truth.md${T}aitools' 'user1.md${T}dotprofile'"
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
printf 'dotprofile scratch\n' > "$D/claude/rules/scratch.md"
gitc -C "$D" add -A; gitc -C "$D" commit -q -m back
run_dh "" --
check "reappearing name returns to its (new) source and is deployed" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'scratch.md${T}dotprofile' '$(M)' && grep -qx 'dotprofile scratch' '$(A)/rules/scratch.md'"

write_config "$C/no-such-dotprofile"
fresh_log
run_dh "" --
check "source not listed (no dotprofile): its names keep their lines, files kept" \
    "[ \"\$(rc)\" = 0 ] && grep -qx 'user1.md${T}dotprofile' '$(M)' && grep -qx 'scratch.md${T}dotprofile' '$(M)' && [ -f '$(A)/rules/user1.md' ] && grep -q 'user1.md kept as dotprofile' '$LOG'"
write_config "$D"
gitc -C "$D" rm -q claude/rules/user1.md; gitc -C "$D" commit -q -m retire-user
fresh_log
run_dh "" -- --dry-run
check "dry run: retirement reported, nothing removed or written" \
    "[ -f '$(A)/rules/user1.md' ] && grep -qx 'user1.md${T}dotprofile' '$(M)' && grep -q 'DRY RUN\] Would back up and remove .*user1.md' '$LOG'"
run_dh "" --
check "dotprofile listed again: its removed rule is retired" \
    "[ ! -e '$(A)/rules/user1.md' ] && grep -qx 'user1.md${T}retired' '$(M)'"

printf '# aitools rules manifest v1\nScratch.md\tdotprofile\nP1.MD\taitools\n' > "$(M)"
fresh_log
run_dh "" --
check "names compared case-insensitively: a case variant is not retired" \
    "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/rules/scratch.md' ] && [ -f '$(A)/rules/p1.md' ] && ! grep -q 'Retired rule' '$LOG' && ! grep -q 'Scratch.md' '$(M)'"
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

# rule_retire_cases RUNNER -- bracket name, failed backup (shared by .sh and .ps1)
rule_retire_cases() {
    local runner="$1" side="$2"
    printf 'bracket\n' > "$R/shared/rules/a[1].md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m bracket
    : > "$C/summary"; "$runner"
    gitc -C "$R" rm -q 'shared/rules/a[1].md'; gitc -C "$R" commit -q -m bracket-gone
    fresh_log; : > "$C/summary"; "$runner"
    check "$side: retired name with [ ] is backed up before removal" \
        "[ ! -e '$(A)/rules/a[1].md' ] && ls '$(A)/rules' | grep -qF 'a[1].md.bak.' && grep -qxF 'a[1].md${T}retired' '$(M)'"
    gitc -C "$R" rm -q .claude/rules/p1.md; gitc -C "$R" commit -q -m p1-gone
    chmod 555 "$(A)/rules"
    fresh_log; : > "$C/summary"; "$runner"
    chmod 755 "$(A)/rules"
    check "$side: failed backup keeps the file (ERROR row, exit 1)" \
        "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/rules/p1.md' ] && row 'ERROR|harness files|retire failed: p1.md' && grep -q 'backup failed' '$LOG'"
    fresh_log; : > "$C/summary"; "$runner"
    check "$side: next run retries and removes it" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/rules/p1.md' ] && grep -qx 'p1.md${T}retired' '$(M)'"
}
run_dh_plain() { run_dh "" --; }
if [ "$(id -u)" != 0 ]; then
    setup_case retiresh
    rule_retire_cases run_dh_plain sh
fi
if [ "$(id -u)" != 0 ]; then
    chmod 555 "$(A)/rules"
    run_dh "" --
    chmod 755 "$(A)/rules"
    check "manifest write failure: ERROR row, exit 1, run completes" \
        "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|rules manifest not written' && grep -q 'harness files: .* retired' '$LOG'"
else
    printf 'SKIP manifest write failure (root ignores permissions)\n'; SKIP=$((SKIP + 1))
fi

# The .ps1 twin on pwsh (OS guard disabled in a temp copy): same manifest, same retirement
if command -v pwsh >/dev/null 2>&1; then
    setup_case psmanifest
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/deploy-harness.ps1" > "$R/scripts/deploy-harness.ps1"
    cp "$ROOT/scripts/aitools-lib.ps1" "$R/scripts/"
    printf 'param([switch]$DryRun, [switch]$Force)\nexit 0\n' > "$R/scripts/setup-user-config.ps1"
    run_ps() {
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" USERPROFILE="$H" AITOOLS_LOG_DIR="$C/logs" \
            AITOOLS_SUMMARY_FILE="$C/summary" pwsh -NoProfile -File "$R/scripts/deploy-harness.ps1" "$@" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
        LOG="$C/logs/deploy.log"
    }
    : > "$C/summary"
    run_ps
    check "ps1 manifest: first run, same content as the .sh" "[ \"\$(rc)\" = 0 ] && mf_is \"\${FIRST_MF[@]}\""
    gitc -C "$R" rm -q shared/rules/scratch.md; gitc -C "$R" commit -q -m retire
    : > "$C/summary"
    run_ps
    check "ps1 retire: retired line, file backed up and removed, DETAIL row" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 'scratch.md${T}retired' '$(M)' && [ ! -e '$(A)/rules/scratch.md' ] && ls '$(A)/rules/'scratch.md.bak.* >/dev/null 2>&1 && row 'DETAIL|harness files|retired: rules/scratch.md'"
    write_config "$C/no-such-dotprofile"
    gitc -C "$R" rm -q .claude/rules/p1.md; gitc -C "$R" commit -q -m retire2
    : > "$C/summary"
    run_ps
    check "ps1: unlisted source keeps its lines; listed source retires" \
        "grep -qx 'user1.md${T}dotprofile' '$(M)' && [ -f '$(A)/rules/user1.md' ] && grep -qx 'p1.md${T}retired' '$(M)' && [ ! -e '$(A)/rules/p1.md' ]"
    check "ps1: manifest is LF, no BOM" "! grep -q \$'\\r' '$(M)' && head -c 3 '$(M)' | grep -q '^# a'"
    write_config "$D"
    # Another dotprofile rule keeps claude/rules in the checkout (git removes empty directories)
    printf 'user rule two\n' > "$D/claude/rules/user2.md"
    gitc -C "$D" add -A; gitc -C "$D" commit -q -m user2
    gitc -C "$D" rm -q claude/rules/user1.md; gitc -C "$D" commit -q -m retire-user
    fresh_log; : > "$C/summary"
    run_ps -DryRun
    check "ps1 dry run: retirement reported, nothing removed or written" \
        "[ -f '$(A)/rules/user1.md' ] && grep -qx 'user1.md${T}dotprofile' '$(M)' && grep -q 'DRY RUN\] Would back up and remove .*user1.md' '$LOG'"
    printf '# aitools rules manifest v1\n../evil.md\tshared\nnotes.txt\tshared\nz.md\tbogus\nHook-Lifecycle.md\tshared\n' > "$(M)"
    printf 'keep me\n' > "$(A)/evil.md"
    fresh_log; : > "$C/summary"
    run_ps
    check "ps1: invalid lines ignored (3 warnings), case variant not retired" \
        "[ -f '$(A)/evil.md' ] && [ \"\$(grep -c 'line ignored' '$LOG')\" = 3 ] && ! grep -q 'evil' '$(M)' && ! grep -q 'Retired rule' '$LOG' && [ -f '$(A)/rules/hook-lifecycle.md' ]"
    mkdir -p "$(A)/rules/d.md"; printf 'inside\n' > "$(A)/rules/d.md/f"
    printf '# aitools rules manifest v1\nd.md\tretired\n' > "$(M)"
    fresh_log; : > "$C/summary"
    run_ps
    check "ps1: a directory named like a retired rule is left alone" \
        "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/rules/d.md/f' ]"
    if [ "$(id -u)" != 0 ]; then
        setup_case retireps
        perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/deploy-harness.ps1" > "$R/scripts/deploy-harness.ps1"
        cp "$ROOT/scripts/aitools-lib.ps1" "$R/scripts/"
        printf 'param([switch]$DryRun, [switch]$Force)\nexit 0\n' > "$R/scripts/setup-user-config.ps1"
        rule_retire_cases run_ps ps1
    fi
else
    printf 'SKIP ps1 manifest cases (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Skills manifest (~/.aitools/skills/.aitools-skills-manifest) and retired skills
# (plan skills-and-rules-fanout.md section 3.2, FO-2). One case sequence, run by
# the .sh and by the .ps1 (pwsh); each step's exit code, summary rows, manifest
# and skills tree go to a trace, and the two traces must be identical.
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
# trace STEP -- append the observable state (timestamps normalized) to $C/trace
trace() {
    {
        printf '== %s rc=%s\n' "$1" "$(rc)"
        cat "$C/summary"
        printf -- '-- manifest\n'
        if [ -f "$(SM)" ]; then cat "$(SM)"; fi
        printf -- '-- tree\n'
        (cd "$(A)/skills" && find . | LC_ALL=C sort)
    } | perl -pe 's/\.bak\.\d{4}-\d\d-\d\dT\d{6}Z/.bak.TS/g' >> "$C/trace"
}
run_sk_sh() { mkdir -p "$C/logs"; fresh_log; run_dh "" -- "$@"; }
run_sk_ps() {
    mkdir -p "$C/logs"; fresh_log; : > "$C/summary"
    local a=()
    if [ "${1:-}" = "--dry-run" ]; then a=(-DryRun); fi
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" USERPROFILE="$H" AITOOLS_LOG_DIR="$C/logs" \
        AITOOLS_SUMMARY_FILE="$C/summary" pwsh -NoProfile -File "$R/scripts/deploy-harness.ps1" ${a[@]+"${a[@]}"} < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}
ps_fixture() {  # the .ps1 twin in the case repo, OS guard disabled, stub config writer
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/deploy-harness.ps1" > "$R/scripts/deploy-harness.ps1"
    cp "$ROOT/scripts/aitools-lib.ps1" "$R/scripts/"
    printf 'param([switch]$DryRun, [switch]$Force)\nexit 0\n' > "$R/scripts/setup-user-config.ps1"
}

# skill_cases RUNNER SIDE -- the FO-2 skills sequence on the current case
skill_cases() {
    local run="$1" side="$2"
    mkdir -p "$D/claude/skills/d1/ref" "$R/shared/skills/.hidden" "$R/shared/skills/old.bak.1"
    printf 'dotprofile skill\n' > "$D/claude/skills/d1/SKILL.md"
    printf 'dotprofile ref\n' > "$D/claude/skills/d1/ref/x.md"
    gitc -C "$D" add -A; gitc -C "$D" commit -q -m skills
    printf 'hidden\n' > "$R/shared/skills/.hidden/SKILL.md"
    printf 'backup\n' > "$R/shared/skills/old.bak.1/SKILL.md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m hidden

    "$run"; trace first
    check "$side skills: first run writes the manifest (sorted, winning sources, dotprofile)" \
        "[ \"\$(rc)\" = 0 ] && smf_is 'd1${T}dotprofile' 's1${T}shared' 's2${T}shared' 's3${T}aitools'"
    check "$side skills: dotprofile skill deployed as a directory (nested file)" \
        "grep -qx 'dotprofile ref' '$(A)/skills/d1/ref/x.md'"
    check "$side skills: hidden and *.bak.* skill directories neither deployed nor listed" \
        "[ ! -e '$(A)/skills/.hidden' ] && [ ! -e '$(A)/skills/old.bak.1' ] && ! grep -q 'hidden\|old' '$(SM)'"
    check "$side skills: manifest not reported as preserved, no .tmp left" \
        "! grep -q 'Preserved: .*aitools-skills-manifest' '$LOG' && [ ! -e '$(SM).tmp' ]"

    mkdir -p "$R/.claude/skills/S2"
    printf 'project S2\n' > "$R/.claude/skills/S2/SKILL.md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m dup
    "$run"; trace dup
    check "$side skills: same name in shared/ and .claude/ -- shared wins, ERROR row, manifest shared" \
        "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|S2: dup in .claude/skills' && grep -qx 's2${T}shared' '$(SM)' && ! grep -q '^S2' '$(SM)' && grep -qx 'skill two' '$(A)/skills/s2/SKILL.md'"
    gitc -C "$R" rm -q -r .claude/skills/S2; gitc -C "$R" commit -q -m undup

    # The #74/#75 layout move: a skill moves from .claude/skills to shared/skills
    gitc -C "$R" mv .claude/skills/s3 shared/skills/s3; gitc -C "$R" commit -q -m move
    "$run"; trace move
    check "$side skills: moved .claude -> shared: source flips, nothing retired" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 's3${T}shared' '$(SM)' && [ -f '$(A)/skills/s3/SKILL.md' ] && ! grep -q 'Retired skill' '$LOG' && [ \"\$(n_bak s3)\" = 0 ]"

    gitc -C "$R" rm -q -r shared/skills/s2; gitc -C "$R" commit -q -m retire
    "$run"; trace retire
    check "$side skills: removed from its source -- retired line, DETAIL row" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 's2${T}retired' '$(SM)' && row 'DETAIL|harness files|retired: skills/s2' && grep -q 'Retired skill: s2 (was shared' '$LOG'"
    check "$side skills: harness directory backed up (backup_dir) and removed" \
        "[ ! -e '$(A)/skills/s2' ] && [ \"\$(n_bak s2)\" = 1 ] && grep -rqx 'skill two' '$(A)/skills/'s2.bak.*/SKILL.md"
    check "$side skills: backup directory not reported as preserved" "! grep -q 'Preserved: .*s2.bak' '$LOG'"

    "$run"; trace rerun
    check "$side skills: retired line persists; no new backup, no row" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 's2${T}retired' '$(SM)' && [ \"\$(n_bak s2)\" = 1 ] && ! has_row 'retired:'"

    write_config "$C/no-such-dotprofile"
    "$run"; trace unlisted
    check "$side skills: source not listed (no dotprofile) -- kept, line kept" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 'd1${T}dotprofile' '$(SM)' && [ -f '$(A)/skills/d1/SKILL.md' ] && grep -q 'Skills manifest: d1 kept as dotprofile' '$LOG'"
    write_config "$D"
    gitc -C "$D" rm -q -r claude/skills; gitc -C "$D" commit -q -m no-skills
    "$run"; trace perkind
    check "$side skills: dotprofile rules listed, dotprofile skills not -- skill kept (per kind)" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 'd1${T}dotprofile' '$(SM)' && [ -f '$(A)/skills/d1/SKILL.md' ] && grep -qx 'user1.md${T}dotprofile' '$(M)' && grep -q 'Source dotprofile/skills not found' '$LOG'"

    mkdir -p "$D/claude/skills/d2"
    printf 'second dotprofile skill\n' > "$D/claude/skills/d2/SKILL.md"
    gitc -C "$D" add -A; gitc -C "$D" commit -q -m d2
    "$run" --dry-run; trace dryrun
    check "$side skills: dry run -- retirement reported, nothing removed or written" \
        "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/skills/d1/SKILL.md' ] && grep -qx 'd1${T}dotprofile' '$(SM)' && [ ! -e '$(A)/skills/d2' ] && grep -q 'DRY RUN\] Would back up and remove .*skills/d1' '$LOG' && grep -q '\[DRY RUN\] Retired skill: d1 (was dotprofile' '$LOG' && [ \"\$(n_bak d1)\" = 0 ]"
    "$run"; trace d1gone
    check "$side skills: dotprofile skills listed again -- d1 retired, d2 deployed" \
        "[ \"\$(rc)\" = 0 ] && grep -qx 'd1${T}retired' '$(SM)' && grep -qx 'd2${T}dotprofile' '$(SM)' && [ ! -e '$(A)/skills/d1' ] && [ \"\$(n_bak d1)\" = 1 ]"

    # A skill with no top-level *.md, one named with [ ] * ? (old backups pruned to
    # 5 by literal name; a decoy that the glob would match is kept), and an
    # upper-case .BAK. directory (not a skill name, never deployed)
    local bn='b[1] *?'
    mkdir -p "$R/shared/skills/nomd/a" "$R/shared/skills/$bn" "$R/shared/skills/x.BAK.y"
    printf 'nested only\n' > "$R/shared/skills/nomd/a/x.md"
    printf 'bracket skill\n' > "$R/shared/skills/$bn/SKILL.md"
    printf 'upper bak\n' > "$R/shared/skills/x.BAK.y/SKILL.md"
    gitc -C "$R" add -A; gitc -C "$R" commit -q -m copy-cases
    "$run"; trace copydeploy
    check "$side skills: nested-only and [ ] * ? skills deployed; .BAK. directory not (case-insensitive)" \
        "[ \"\$(rc)\" = 0 ] && [ -f '$(A)/skills/nomd/a/x.md' ] && [ -f \"$(A)/skills/\$bn/SKILL.md\" ] && [ ! -e '$(A)/skills/x.BAK.y' ] && ! grep -qi 'x.bak.y' '$(SM)'"
    local i
    for i in 1 2 3 4 5 6; do
        mkdir -p "$(A)/skills/$bn.bak.2026-01-0${i}T000000Z"
        printf 'old %s\n' "$i" > "$(A)/skills/$bn.bak.2026-01-0${i}T000000Z/SKILL.md"
    done
    mkdir -p "$(A)/skills/b1.bak.2026-01-01T000000Z"
    printf 'decoy\n' > "$(A)/skills/b1.bak.2026-01-01T000000Z/SKILL.md"
    gitc -C "$R" rm -q -r shared/skills/nomd "shared/skills/$bn"; gitc -C "$R" commit -q -m copy-retire
    "$run"; trace copyretire
    check "$side skills: retired skill with no top-level *.md -- copied, verified, removed" \
        "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/nomd' ] && [ \"\$(n_bak nomd)\" = 1 ] && grep -rqx 'nested only' '$(A)/skills/'nomd.bak.*/a/x.md && row 'DETAIL|harness files|retired: skills/nomd'"
    check "$side skills: [ ] * ? name retired; its backups pruned to 5 (oldest two); decoy kept" \
        "[ ! -e \"$(A)/skills/\$bn\" ] && [ \"\$(n_bak \"\$bn\")\" = 5 ] && [ ! -e \"$(A)/skills/\$bn.bak.2026-01-01T000000Z\" ] && [ ! -e \"$(A)/skills/\$bn.bak.2026-01-02T000000Z\" ] && [ -d \"$(A)/skills/\$bn.bak.2026-01-03T000000Z\" ] && [ -f '$(A)/skills/b1.bak.2026-01-01T000000Z/SKILL.md' ]"

    if [ "$(id -u)" != 0 ]; then
        # Partial backup: an unreadable file in the retired skill's directory
        mkdir -p "$R/shared/skills/pb"
        printf 'partial\n' > "$R/shared/skills/pb/SKILL.md"
        gitc -C "$R" add -A; gitc -C "$R" commit -q -m pb
        "$run"; trace pbdeploy
        printf 'secret\n' > "$(A)/skills/pb/secret.md"
        chmod 000 "$(A)/skills/pb/secret.md"
        gitc -C "$R" rm -q -r shared/skills/pb; gitc -C "$R" commit -q -m pb-gone
        "$run"; trace pbfail
        chmod 644 "$(A)/skills/pb/secret.md"
        check "$side skills: partial backup removed again; directory kept (ERROR row, exit 1)" \
            "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/pb/SKILL.md' ] && [ \"\$(n_bak pb)\" = 0 ] && row 'ERROR|harness files|retire failed: pb' && grep -q 'Retired skill pb: backup failed (' '$LOG' && grep -q 'Retired skill pb: removed the incomplete backup' '$LOG'"
        "$run"; trace pbretry
        check "$side skills: readable again -- backed up and removed" \
            "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/pb' ] && [ \"\$(n_bak pb)\" = 1 ] && grep -rqx 'secret' '$(A)/skills/'pb.bak.*/secret.md"

        # Partial backup holding a read-only (555) subdirectory: cleanup must still work
        mkdir -p "$R/shared/skills/rs/ro"
        printf 'ro skill\n' > "$R/shared/skills/rs/SKILL.md"
        printf 'ro file\n' > "$R/shared/skills/rs/ro/a.md"
        gitc -C "$R" add -A; gitc -C "$R" commit -q -m rs
        "$run"; trace rsdeploy
        printf 'secret\n' > "$(A)/skills/rs/ro/secret.md"
        chmod 000 "$(A)/skills/rs/ro/secret.md"
        chmod 555 "$(A)/skills/rs/ro"
        gitc -C "$R" rm -q -r shared/skills/rs; gitc -C "$R" commit -q -m rs-gone
        "$run"; trace rsfail
        chmod 755 "$(A)/skills/rs/ro"
        chmod 644 "$(A)/skills/rs/ro/secret.md"
        check "$side skills: partial backup with a read-only subdirectory removed (no leftover, nothing renamed)" \
            "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/rs/ro/a.md' ] && [ \"\$(n_bak rs)\" = 0 ] && row 'ERROR|harness files|retire failed: rs' && ! has_row 'bak cleanup failed' && grep -q 'Retired skill rs: removed the incomplete backup' '$LOG'"
        "$run"; trace rsretry
        check "$side skills: read-only case retried -- backed up and removed" \
            "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/rs' ] && [ \"\$(n_bak rs)\" = 1 ]"

        gitc -C "$R" rm -q -r shared/skills/s1; gitc -C "$R" commit -q -m s1-gone
        chmod 555 "$(A)/skills"
        "$run"; trace bakfail
        chmod 755 "$(A)/skills"
        check "$side skills: failed backup keeps the directory (ERROR row, exit 1)" \
            "[ \"\$(rc)\" = 1 ] && [ -f '$(A)/skills/s1/SKILL.md' ] && row 'ERROR|harness files|retire failed: s1' && grep -q 'Retired skill s1: backup failed' '$LOG' && [ \"\$(n_bak s1)\" = 0 ]"
        "$run"; trace bakretry
        check "$side skills: next run retries -- backed up and removed" \
            "[ \"\$(rc)\" = 0 ] && [ ! -e '$(A)/skills/s1' ] && [ \"\$(n_bak s1)\" = 1 ] && grep -qx 's1${T}retired' '$(SM)'"
    fi

    printf 'a file\n' > "$(A)/skills/zz"
    printf '# aitools skills manifest v1\nzz\tretired\n../evil\tshared\n.hidden\tshared\nx.bak.1\tshared\na/b\tshared\nok\tbogus\n' > "$(SM)"
    "$run"; trace invalid
    check "$side skills: invalid lines ignored (5 warnings); a file named like a retired skill left alone" \
        "[ \"\$(rc)\" = 0 ] && [ \"\$(grep -c 'line ignored' '$LOG')\" = 5 ] && [ -f '$(A)/skills/zz' ] && grep -q 'Retired skill zz: .* is not a directory' '$LOG' && row 'WARN|harness files|not a dir: zz' && grep -qx 'zz${T}retired' '$(SM)' && ! grep -q 'evil\|hidden\|bogus' '$(SM)'"
    printf 'not a manifest\nd2\tdotprofile\n' > "$(SM)"
    "$run"; trace header
    check "$side skills: unknown header -- warning, nothing retired, rewritten" \
        "[ \"\$(rc)\" = 0 ] && grep -q '\[warn\] Skills manifest .*the first line is not' '$LOG' && head -n 1 '$(SM)' | grep -qx '# aitools skills manifest v1' && ! grep -q 'retired' '$(SM)'"

    # A directory at the manifest paths (skills and rules): ERROR, exit 1, nothing moved into it
    rm -f "$(SM)" "$(M)"
    mkdir -p "$(SM)" "$(M)"
    printf 'inside\n' > "$(SM)/inside"
    "$run"; trace mfdir
    check "$side skills: manifest path is a directory -- ERROR rows (skills, rules), exit 1, nothing written into it, contents not reported preserved" \
        "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|skills manifest not written' && row 'ERROR|harness files|rules manifest not written' && [ \"\$(ls -A '$(SM)')\" = inside ] && [ -z \"\$(ls -A '$(M)')\" ] && grep -q 'Skills manifest: .* is a directory' '$LOG' && ! grep -q 'Preserved: .*aitools-skills-manifest' '$LOG'"
    rm -rf "$(SM)" "$(M)"
    "$run"; trace mfdirgone
    check "$side skills: directory removed -- both manifests written again" \
        "[ \"\$(rc)\" = 0 ] && [ -f '$(SM)' ] && [ -f '$(M)' ]"
}

setup_case skillssh
skill_cases run_sk_sh sh
if command -v pwsh >/dev/null 2>&1; then
    SH_TRACE="$C/trace"
    setup_case skillsps
    ps_fixture
    skill_cases run_sk_ps ps1
    check "skills parity: .sh and .ps1 traces identical (exit codes, rows, manifest, tree)" \
        "[ \"\$(grep -c '^== ' '$SH_TRACE')\" -ge 12 ] && grep -q '^-- manifest' '$SH_TRACE' && diff '$SH_TRACE' '$C/trace' > '$C/trace.diff'"
    if [ -s "$C/trace.diff" ]; then perl -pe 's/^/      | /' "$C/trace.diff" | head -n 40; fi
else
    printf 'SKIP ps1 skills cases (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi

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
