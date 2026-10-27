#!/usr/bin/env bash
# test-skills-legacy.sh -- tests for setup-user-skills.sh/.ps1 as the fallback
# skills deployer (FD-9, plans/skills-and-rules-fanout.md FO-6), dev path and the
# generated MDM copies that scripts/build-deploy.sh writes into <dotprofile>/deploy/
#
# Cases (each for .sh and .ps1; the summary rows must be the same in both):
#   fallback     no ~/.aitools/skills: shared + dotprofile skills deployed to
#                ~/.claude/skills and ~/.cursor/skills ("claude skills" and
#                "cursor skills" rows), no "skills" row; reverse discovery finds
#                a user-created skill
#   fanned-out   ~/.aitools/skills exists: nothing written, only the row
#                OK "skills" "n/a (fanned out)"; reverse discovery ignores
#                harness names (directory entries, manifest lines of every
#                source, compared case-insensitively) and backup names, and
#                still finds a user-created skill; dry run the same; an empty
#                ~/.aitools/skills is fanned out too
#   header-bad   a manifest with a bad header: directory names still ignored,
#                a manifest-only name is offered again
#   no dotprofile  fanned out, resolver finds none: no adoption offered, exit 0
#   resolver error fanned out: ERROR "skills" "no adopt: dotprofile error", no
#                fan-out rows, exit 1; fallback keeps today's ERROR
#                "claude skills" / "cursor skills" rows
#   unreadable   fanned out, manifest, ~/.aitools/skills or ~/.claude/skills
#                unreadable (chmod 000): ERROR "skills" "no adopt: ..." row,
#                the same log text in .sh and .ps1, exit 1
#   pty adopt    fanned out, [a]dopt on a pty writes the dotprofile; a failed
#                adopt is ERROR "skills" "adopt failed: <name>"
#   one writer   setup-user-claude, setup-user-skills, setup-user-cursor in dev
#                order into one summary: each skills tool row exactly once, in
#                both modes (stub rg / agent on PATH: no installer runs)
#   MDM          the generated setup-user-skills.sh/.ps1 deploy without
#                ~/.aitools/skills and write only the n/a row when it exists
# A missing perl, git, pwsh, node or python3 skips its cases locally; under
# CI=true it is a failure.
#
# Safe to re-run: every case runs under its own temp HOME (never the real HOME
# or a real dotprofile), removed on exit. The scripts run from a fixture copy of
# the repo (scripts/ copied from this checkout, shared/skills a fixture), so the
# skills are known; the .ps1 copy has its OS guard disabled. The build runs
# build-deploy.sh with an isolated HOME whose config.json points at a fixture
# dotprofile (a git repo in the temp dir). The resolver error is a stub
# (AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1, the lib's lookup override).
# Platform: macOS, Linux (needs perl, git; node for the MDM cases, pwsh for the
# .ps1 cases; skipped without them). Exit 1 if any case fails.
#
# Usage: bash tests/skills-legacy/test-skills-legacy.sh [--help]
#   AITOOLS_TEST_BASH=/bin/bash  the bash that runs the scripts under test

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 47' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
# chmod first: undoes a chmod 000 case an interrupted run left behind
trap 'chmod -R u+rwx "$TMP_ROOT"; rm -rf "$TMP_ROOT"' EXIT
W="$TMP_ROOT/work"
mkdir -p "$W"

PASS=0
FAIL=0
SKIP=0
OUT=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$OUT" ] && [ -f "$OUT" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$OUT" | tail -n 25
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }
# need_skip MSG: cases skipped because a tool is missing. Under CI (CI=true) that
# is a failure: a green CI run must not hide the .ps1, parity, pty or MDM cases.
need_skip() {
    if [ "${CI:-}" = "true" ]; then
        printf 'FAIL %s (a required tool is missing under CI=true)\n' "$1"; FAIL=$((FAIL + 1))
    else
        skip "$1"
    fi
}

for t in perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        if [ "${CI:-}" = "true" ]; then
            printf 'FAIL all cases (%s not found; required under CI=true)\n' "$t"
            exit 1
        fi
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done
HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi
HAVE_NODE=false
if command -v node >/dev/null 2>&1; then HAVE_NODE=true; fi
PTY="$ROOT/tests/managed-files/pty-run.py"
HAVE_PTY=false
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi
CAN_CHMOD_READ=true   # chmod 000 blocks reads (not for root, not under Git Bash)
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CAN_CHMOD_READ=false ;; esac
if [ "$(id -u)" = 0 ]; then CAN_CHMOD_READ=false; fi

# The bash that runs the scripts under test (CI also runs macOS /bin/bash 3.2)
TB="${AITOOLS_TEST_BASH:-bash}"

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

skill() {  # skill DIR NAME TEXT -- DIR/NAME/SKILL.md holding TEXT
    mkdir -p "$1/$2"
    printf -- '---\nname: %s\n---\n%s\n' "$2" "$3" > "$1/$2/SKILL.md"
}

# --- Fixture dotprofile (a git repo in the temp dir) ---
DP="$TMP_ROOT/aitools-tess"
mkdir -p "$DP/claude/rules"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf 'rule one\n' > "$DP/claude/rules/r1.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
skill "$DP/claude/skills" dpskill "dotprofile skill"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

# --- Fixture repo: this checkout's scripts/, a known shared/skills ---
FR="$TMP_ROOT/repo"
mkdir -p "$FR/shared/skills"
cp -R "$ROOT/scripts" "$FR/scripts"
skill "$FR/shared/skills" alpha "shared alpha"
skill "$FR/shared/skills" beta "shared beta"
# The .ps1 under test, OS guard disabled (setup-user-skills.ps1 only)
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/setup-user-skills.ps1" > "$FR/scripts/setup-user-skills.ps1"

# Resolver error stubs: resolve_user_repo_path / Resolve-UserRepoPath return 3
printf '#!/usr/bin/env bash\nprintf "via\\tnone\\nerror\\tstub resolver failure\\n"\nexit 2\n' > "$W/fail.sh"
printf '"via`tnone"\n"error`tstub resolver failure"\nexit 2\n' > "$W/fail.ps1"

write_config() {  # write_config HOME_DIR [nodp | DOTPROFILE_DIR]
    mkdir -p "$1/.aitools"
    if [ "${2:-}" = nodp ]; then
        printf '{"machineAlias":"m1"}\n' > "$1/.aitools/config.json"
    else
        printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "${2:-$DP}" > "$1/.aitools/config.json"
    fi
}
# own_dotprofile CASE: a copy of the fixture dotprofile for CASE (adopt writes it)
own_dotprofile() {
    cp -R "$DP" "$TMP_ROOT/dp-$1"
    write_config "$TMP_ROOT/$1" "$TMP_ROOT/dp-$1"
}

# seed_harness HOME_DIR: ~/.aitools/skills as deploy-harness leaves it, plus a
# ~/.claude/skills holding harness skills, a backup, a retired name and one
# user-created skill ("mine")
seed_harness() {
    local h="$1" hs="$1/.aitools/skills" cs="$1/.claude/skills"
    mkdir -p "$hs"
    skill "$hs" alpha "harness alpha"
    skill "$hs" aitskill "aitools project skill"
    skill "$hs" CaseSkill "case"
    skill "$hs" "old.bak.20261001T000000Z" "harness backup"
    printf '# aitools skills manifest v1\naitskill\taitools\nalpha\tshared\nCaseSkill\tshared\ngone\tretired\n' > "$hs/.aitools-skills-manifest"
    skill "$cs" alpha "user alpha"
    skill "$cs" aitskill "fanned out"
    skill "$cs" caseskill "fanned out, other case"
    skill "$cs" gone "retired, kept by the fan-out"
    skill "$cs" "gone.bak.20261020T000000Z" "fan-out backup"
    skill "$cs" mine "user-created"
}

# run_skills LANG CASE [stub] [args...] -- LANG sh|ps; HOME = $TMP_ROOT/CASE;
# stub = live|fail
run_skills() {
    local lang="$1" name="$2" stub="$3" h; shift 3
    h="$TMP_ROOT/$name"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name.out"
    : > "$TMP_ROOT/$name.summary"
    local envs=(HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1)
    if [ "$stub" = fail ]; then envs+=(AITOOLS_PROFILE_SH="$W/fail.sh" AITOOLS_PROFILE_PS1="$W/fail.ps1"); fi
    if [ "$lang" = sh ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
            -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 "${envs[@]}" \
            "$TB" "$FR/scripts/setup-user-skills.sh" "$@" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
            -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 "${envs[@]}" \
            pwsh -NoProfile -File "$FR/scripts/setup-user-skills.ps1" "$@" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name.rc"
}
# run_skills_pty LANG CASE INPUT -- as run_skills (live resolver), on a pty
# (tests/managed-files/pty-run.py) with INPUT typed at the prompts
run_skills_pty() {
    local lang="$1" name="$2" input="$3" h
    h="$TMP_ROOT/$name"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name.out"
    : > "$TMP_ROOT/$name.summary"
    local cmd=("$TB" "$FR/scripts/setup-user-skills.sh")
    if [ "$lang" = ps ]; then cmd=(pwsh -NoProfile -File "$FR/scripts/setup-user-skills.ps1"); fi
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" \
        AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" AITOOLS_PROFILE_TEST_ANY_OS=1 \
        python3 "$PTY" --input "$input" --log "$OUT" -- "${cmd[@]}" > /dev/null 2>&1
    echo $? > "$TMP_ROOT/$name.rc"
}
rc_of() { cat "$TMP_ROOT/$1.rc"; }
row() { grep -qxF "$2" "$TMP_ROOT/$1.summary"; }
no_rows_for() { ! grep -q "^[A-Z]*|$2|" "$TMP_ROOT/$1.summary"; }
# skill rows: every row except the resolver's own (dotprofile, ACTION)
rows_of() { grep -v -e '^ACTION|' -e '|dotprofile|' "$TMP_ROOT/$1.summary" | sort; }
found() { grep -q "Found user-created skill: $2\$" "$TMP_ROOT/$1.out"; }
found_any_of() {  # found_any_of CASE NAME... -- 0 when any NAME was offered
    local c="$1" n; shift
    for n in "$@"; do if found "$c" "$n"; then return 0; fi; done
    return 1
}
same_text() { [ -f "$1" ] && [ "$(cat "$1")" = "$2" ]; }
FANOUT_ROW='OK|skills|n/a (fanned out)'
# found_log CASE TEXT: deploy.log of CASE holds TEXT (a fixed string)
found_log() { grep -qF -- "$2" "$TMP_ROOT/$1/logs/deploy.log"; }

# ---------------------------------------------------------------------------
# Dev path
# ---------------------------------------------------------------------------
for lang in sh ps; do
    if [ "$lang" = ps ] && ! $HAVE_PWSH; then need_skip "ps1 dev cases (pwsh not found)"; continue; fi
    DRY="--dry-run"; if [ "$lang" = ps ]; then DRY="-DryRun"; fi

    # fallback: no ~/.aitools/skills
    c="$lang-fallback"
    skill "$TMP_ROOT/$c/.claude/skills" mine "user-created"
    run_skills "$lang" "$c" live
    check "$lang fallback: exit 0, claude skills and cursor skills rows, no skills row" \
        "[ \"\$(rc_of $c)\" = 0 ] && row $c 'OK|claude skills|3 added' && row $c 'OK|cursor skills|3 added' && no_rows_for $c skills"
    check "$lang fallback: shared and dotprofile skills deployed to both tools" \
        "grep -q 'shared alpha' '$TMP_ROOT/$c/.claude/skills/alpha/SKILL.md' && grep -q 'dotprofile skill' '$TMP_ROOT/$c/.cursor/skills/dpskill/SKILL.md' && [ -f '$TMP_ROOT/$c/.cursor/skills/beta/SKILL.md' ]"
    check "$lang fallback: reverse discovery finds the user-created skill" "found $c mine"
    rows_of "$c" > "$TMP_ROOT/$lang-r1.rows"

    # fanned out: ~/.aitools/skills exists
    c="$lang-fan"
    seed_harness "$TMP_ROOT/$c"
    run_skills "$lang" "$c" live
    check "$lang fanned out: exit 0, only the skills n/a row (no claude skills / cursor skills rows)" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ]"
    check "$lang fanned out: nothing deployed (no ~/.cursor/skills, beta absent, alpha kept)" \
        "[ ! -e '$TMP_ROOT/$c/.cursor/skills' ] && [ ! -e '$TMP_ROOT/$c/.claude/skills/beta' ] && [ ! -e '$TMP_ROOT/$c/.claude/skills/dpskill' ] && grep -q 'user alpha' '$TMP_ROOT/$c/.claude/skills/alpha/SKILL.md'"
    check "$lang fanned out: log names the fan-out owners (same text in .sh and .ps1)" \
        "found_log $c 'Skills are fanned out from ~/.aitools/skills by setup-user-claude (claude skills) and setup-user-cursor (cursor skills): not deploying them here'"
    check "$lang fanned out: harness names (entry, manifest, other case) and backups not offered" \
        "! found_any_of $c alpha aitskill caseskill gone gone.bak.20261020T000000Z"
    check "$lang fanned out: reverse discovery still finds the user-created skill" "found $c mine"
    rows_of "$c" > "$TMP_ROOT/$lang-r2.rows"

    c="$lang-fandry"
    seed_harness "$TMP_ROOT/$c"
    run_skills "$lang" "$c" live "$DRY"
    check "$lang fanned out, dry run: n/a row only, nothing written, adoption only previewed" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ] && [ ! -e '$TMP_ROOT/$c/.cursor/skills' ] && grep -q 'Would offer to adopt mine' '$OUT' && ! grep -q 'Would offer to adopt alpha' '$OUT'"

    # header-bad manifest: directory names still count, manifest-only names do not
    c="$lang-hbad"
    seed_harness "$TMP_ROOT/$c"
    printf '# not a manifest\naitskill\taitools\ngone\tretired\n' > "$TMP_ROOT/$c/.aitools/skills/.aitools-skills-manifest"
    run_skills "$lang" "$c" live
    check "$lang header-bad manifest: exit 0, directory names ignored, manifest-only 'gone' offered" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ] && ! found_any_of $c alpha aitskill && found $c gone && grep -q 'Skills manifest header not recognised' '$OUT'"
    rows_of "$c" > "$TMP_ROOT/$lang-r3.rows"

    # no dotprofile: nothing can be adopted
    c="$lang-nodp"
    write_config "$TMP_ROOT/$c" nodp
    seed_harness "$TMP_ROOT/$c"
    run_skills "$lang" "$c" live
    check "$lang fanned out, no dotprofile: exit 0, n/a row only, no adoption offered" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ] && ! found $c mine"
    rows_of "$c" > "$TMP_ROOT/$lang-r4.rows"

    # resolver error
    c="$lang-rerr"
    seed_harness "$TMP_ROOT/$c"
    run_skills "$lang" "$c" fail
    check "$lang fanned out, resolver error: exit 1, n/a + ERROR skills rows, no fan-out rows, nothing offered" \
        "[ \"\$(rc_of $c)\" = 1 ] && row $c '$FANOUT_ROW' && row $c 'ERROR|skills|no adopt: dotprofile error' && no_rows_for $c 'claude skills' && no_rows_for $c 'cursor skills' && ! found $c mine && found_log $c 'Dotprofile unresolved (resolver error above) -- reverse discovery not run, so no skill can be adopted to the dotprofile'"
    rows_of "$c" > "$TMP_ROOT/$lang-r5.rows"
    c="$lang-rerrfb"
    run_skills "$lang" "$c" fail
    check "$lang fallback, resolver error: today's ERROR claude skills / cursor skills rows, nothing deployed" \
        "[ \"\$(rc_of $c)\" = 1 ] && row $c 'ERROR|claude skills|not deployed: dotprofile error' && row $c 'ERROR|cursor skills|not deployed: dotprofile error' && no_rows_for $c skills && [ ! -e '$TMP_ROOT/$c/.claude/skills' ]"
    rows_of "$c" > "$TMP_ROOT/$lang-r6.rows"

    # unreadable manifest / harness directory
    if $CAN_CHMOD_READ; then
        c="$lang-mfu"
        seed_harness "$TMP_ROOT/$c"
        chmod 000 "$TMP_ROOT/$c/.aitools/skills/.aitools-skills-manifest"
        run_skills "$lang" "$c" live
        chmod 644 "$TMP_ROOT/$c/.aitools/skills/.aitools-skills-manifest"
        check "$lang unreadable manifest: exit 1, ERROR skills row, reverse discovery not run" \
            "[ \"\$(rc_of $c)\" = 1 ] && row $c '$FANOUT_ROW' && row $c 'ERROR|skills|no adopt: manifest unreadable' && ! found $c mine && found_log $c 'Cannot read the skills manifest ~/.aitools/skills/.aitools-skills-manifest -- reverse discovery not run, so no harness skill is offered for adoption: '"
        rows_of "$c" > "$TMP_ROOT/$lang-r7.rows"
        c="$lang-hdu"
        seed_harness "$TMP_ROOT/$c"
        chmod 000 "$TMP_ROOT/$c/.aitools/skills"
        run_skills "$lang" "$c" live
        chmod 755 "$TMP_ROOT/$c/.aitools/skills"
        check "$lang unreadable ~/.aitools/skills: exit 1, ERROR skills row, reverse discovery not run" \
            "[ \"\$(rc_of $c)\" = 1 ] && row $c '$FANOUT_ROW' && row $c 'ERROR|skills|no adopt: harness unreadable' && ! found $c mine && found_log $c 'Cannot read ~/.aitools/skills -- reverse discovery not run, so no harness skill is offered for adoption: '"
        rows_of "$c" > "$TMP_ROOT/$lang-r8.rows"
        # Audit B N1: an unreadable ~/.claude/skills is an error, not an empty scan
        c="$lang-dstu"
        seed_harness "$TMP_ROOT/$c"
        chmod 000 "$TMP_ROOT/$c/.claude/skills"
        run_skills "$lang" "$c" live
        chmod 755 "$TMP_ROOT/$c/.claude/skills"
        check "$lang unreadable ~/.claude/skills: exit 1, ERROR skills 'no adopt: target unreadable', logged" \
            "[ \"\$(rc_of $c)\" = 1 ] && row $c '$FANOUT_ROW' && row $c 'ERROR|skills|no adopt: target unreadable' && no_rows_for $c 'claude skills' && ! found $c mine && found_log $c 'Cannot read ~/.claude/skills -- reverse discovery not run, so no user-created skill is offered for adoption: '"
        rows_of "$c" > "$TMP_ROOT/$lang-r9.rows"
    else
        skip "$lang unreadable cases (chmod does not block reads here)"
        : > "$TMP_ROOT/$lang-r7.rows"; : > "$TMP_ROOT/$lang-r8.rows"; : > "$TMP_ROOT/$lang-r9.rows"
    fi

    # empty harness: still fanned out (the fan-out gates on the directory too)
    c="$lang-empty"
    mkdir -p "$TMP_ROOT/$c/.aitools/skills"
    skill "$TMP_ROOT/$c/.claude/skills" mine "user-created"
    run_skills "$lang" "$c" live
    check "$lang empty ~/.aitools/skills: n/a row only, nothing deployed, user skill still found" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ] && [ ! -e '$TMP_ROOT/$c/.cursor/skills' ] && [ ! -e '$TMP_ROOT/$c/.claude/skills/alpha' ] && found $c mine"
    rows_of "$c" > "$TMP_ROOT/$lang-r10.rows"

    # pty: adopt in fan-out mode writes the dotprofile; a failed adopt is a
    # "skills" row (review N1), never "claude skills"
    if $HAVE_PTY; then
        c="$lang-adopt"
        own_dotprofile "$c"
        seed_harness "$TMP_ROOT/$c"
        run_skills_pty "$lang" "$c" 'a\n'
        check "$lang pty adopt (fanned out): exit 0, mine adopted to the dotprofile, n/a row only" \
            "[ \"\$(rc_of $c)\" = 0 ] && grep -q 'user-created' '$TMP_ROOT/dp-$c/claude/skills/mine/SKILL.md' && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ]"
        rows_of "$c" > "$TMP_ROOT/$lang-r11.rows"
        if $CAN_CHMOD_READ; then
            c="$lang-adoptfail"
            own_dotprofile "$c"
            seed_harness "$TMP_ROOT/$c"
            chmod 555 "$TMP_ROOT/dp-$c/claude/skills"
            run_skills_pty "$lang" "$c" 'a\n'
            chmod 755 "$TMP_ROOT/dp-$c/claude/skills"
            check "$lang pty adopt failure (fanned out): exit 1, ERROR skills 'adopt failed: mine', no claude skills row" \
                "[ \"\$(rc_of $c)\" = 1 ] && row $c 'ERROR|skills|adopt failed: mine' && no_rows_for $c 'claude skills' && [ ! -e '$TMP_ROOT/dp-$c/claude/skills/mine' ]"
            rows_of "$c" > "$TMP_ROOT/$lang-r12.rows"
        else
            skip "$lang pty adopt failure (chmod does not block writes here)"
            : > "$TMP_ROOT/$lang-r12.rows"
        fi
    else
        need_skip "$lang pty adopt cases (python3 pty not available)"
        : > "$TMP_ROOT/$lang-r11.rows"; : > "$TMP_ROOT/$lang-r12.rows"
    fi
done
if $HAVE_PWSH; then
    _parity() {
        local i
        for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
            cmp -s "$TMP_ROOT/sh-r$i.rows" "$TMP_ROOT/ps-r$i.rows" || { printf '      | rows %s differ\n' "$i"; return 1; }
        done
    }
    check "parity: same summary rows in .sh and .ps1 (12 cases)" "_parity"
fi

# ---------------------------------------------------------------------------
# One writer per row (review N2): a dev-order run (setup-user-claude, then
# setup-user-skills, then setup-user-cursor) into one summary file writes each
# skills tool row exactly once -- fallback: "claude skills" and "cursor skills"
# from setup-user-skills; fanned out: both from the fan-out plus "skills" n/a
# ---------------------------------------------------------------------------
for s in setup-user-claude setup-user-cursor; do
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/$s.ps1" > "$FR/scripts/$s.ps1"
done
# Stub rg and agent first on PATH: setup-user-cursor finds them installed, so no
# installer runs (as tests/rules-fanout-cursor does)
SB="$W/stub-bin"
mkdir -p "$SB"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$SB/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$SB/agent"
chmod +x "$SB/rg" "$SB/agent"
# run_dev_order LANG CASE -- the three scripts, one HOME, one summary file
run_dev_order() {
    local lang="$1" name="$2" h s rc=0
    h="$TMP_ROOT/$name"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name.out"
    : > "$TMP_ROOT/$name.summary"; : > "$OUT"
    for s in setup-user-claude setup-user-skills setup-user-cursor; do
        if [ "$lang" = sh ]; then
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
                -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" \
                AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" AITOOLS_PROFILE_TEST_ANY_OS=1 PATH="$SB:$PATH" \
                "$TB" "$FR/scripts/$s.sh" < /dev/null >> "$OUT" 2>&1 || rc=1
        else
            env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
                -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" \
                AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" AITOOLS_PROFILE_TEST_ANY_OS=1 PATH="$SB:$PATH" \
                pwsh -NoProfile -File "$FR/scripts/$s.ps1" < /dev/null >> "$OUT" 2>&1 || rc=1
        fi
    done
    echo "$rc" > "$TMP_ROOT/$name.rc"
    OUT="$TMP_ROOT/$name.summary"   # a failed check shows the rows
}
# count_rows CASE TOOL: the status rows (OK / WARN / ERROR, not DETAIL) for TOOL
count_rows() { grep -cE "^(OK|WARN|ERROR)\|$2\|" "$TMP_ROOT/$1.summary"; }
for lang in sh ps; do
    if [ "$lang" = ps ] && ! $HAVE_PWSH; then need_skip "ps1 one-writer cases (pwsh not found)"; continue; fi
    c="$lang-order-fb"
    run_dev_order "$lang" "$c"
    check "$lang dev order, fallback: claude skills and cursor skills rows once each (from setup-user-skills), no skills row" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(count_rows $c 'claude skills')\" = 1 ] && [ \"\$(count_rows $c 'cursor skills')\" = 1 ] && [ \"\$(count_rows $c skills)\" = 0 ] && row $c 'OK|claude skills|3 added' && row $c 'OK|cursor skills|3 added'"
    c="$lang-order-fan"
    mkdir -p "$TMP_ROOT/$c/.aitools/skills"
    skill "$TMP_ROOT/$c/.aitools/skills" alpha "harness alpha"
    printf '# aitools skills manifest v1\nalpha\tshared\n' > "$TMP_ROOT/$c/.aitools/skills/.aitools-skills-manifest"
    run_dev_order "$lang" "$c"
    check "$lang dev order, fanned out: claude skills, cursor skills and skills rows once each" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(count_rows $c 'claude skills')\" = 1 ] && [ \"\$(count_rows $c 'cursor skills')\" = 1 ] && [ \"\$(count_rows $c skills)\" = 1 ] && row $c '$FANOUT_ROW' && grep -q 'harness alpha' '$TMP_ROOT/$c/.claude/skills/alpha/SKILL.md' && grep -q 'harness alpha' '$TMP_ROOT/$c/.cursor/skills/alpha/SKILL.md'"
done

# ---------------------------------------------------------------------------
# MDM: the generated setup-user-skills.sh/.ps1
# ---------------------------------------------------------------------------
if ! $HAVE_NODE; then
    need_skip "MDM cases (node not found; build-deploy needs it)"
    printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
    [ "$FAIL" -eq 0 ]
    exit
fi

HB="$TMP_ROOT/home-build"
write_config "$HB"
OUT="$TMP_ROOT/build.out"
env -u AITOOLS_USER_REPO_PATH -u AITOOLS_SUMMARY_FILE -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
    HOME="$HB" AITOOLS_LOG_DIR="$HB/logs" "$TB" "$ROOT/scripts/build-deploy.sh" > "$OUT" 2>&1
BUILD_RC=$?
G="$DP/deploy"
check "build: exit 0, setup-user-skills.sh/.ps1 generated, bash -n ($TB)" \
    "[ '$BUILD_RC' = 0 ] && [ -x '$G/setup-user-skills.sh' ] && [ -f '$G/setup-user-skills.ps1' ] && '$TB' -n '$G/setup-user-skills.sh'"
check "build: the generated scripts carry the harness check and gate the embedded deploy" \
    "grep -qF 'SKILLS_HARNESS_DIR=\"\$HOME/.aitools/skills\"' '$G/setup-user-skills.sh' && grep -qF 'if [ \"\$SKILLS_FANNED_OUT\" != \"true\" ]; then' '$G/setup-user-skills.sh' && grep -qF '\$skillsHarnessDir = ' '$G/setup-user-skills.ps1' && grep -qF 'if (-not \$skillsFannedOut) {' '$G/setup-user-skills.ps1'"

# One shared skill the build embedded (the real shared/skills of this checkout)
SHARED_ONE=""
for d in "$ROOT/shared/skills"/*/; do
    if [ -f "$d/SKILL.md" ]; then SHARED_ONE=$(basename "$d"); break; fi
done

run_mdm() {  # run_mdm LANG CASE -- the generated script; HOME = $TMP_ROOT/CASE
    local lang="$1" name="$2" h
    h="$TMP_ROOT/$name"; mkdir -p "$h"
    OUT="$TMP_ROOT/$name.out"; : > "$TMP_ROOT/$name.summary"
    if [ "$lang" = sh ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH HOME="$h" USERPROFILE="$h" \
            AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" \
            "$TB" "$G/setup-user-skills.sh" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH HOME="$h" USERPROFILE="$h" \
            AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" \
            pwsh -NoProfile -File "$TMP_ROOT/ps-deploy/setup-user-skills.ps1" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name.rc"
}

if $HAVE_PWSH; then
    printf '%s\n' '$e = $null' \
        '$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)' \
        'if ($e.Count -gt 0) { $e | ForEach-Object { [Console]::WriteLine($_.Message) }; exit 1 }' > "$W/parse.ps1"
    check "build: pwsh parser accepts the generated setup-user-skills.ps1" \
        "pwsh -NoProfile -File '$W/parse.ps1' '$G/setup-user-skills.ps1' > /dev/null"
    mkdir -p "$TMP_ROOT/ps-deploy"
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$G/setup-user-skills.ps1" > "$TMP_ROOT/ps-deploy/setup-user-skills.ps1"
fi

for lang in sh ps; do
    if [ "$lang" = ps ] && ! $HAVE_PWSH; then need_skip "MDM ps1 cases (pwsh not found)"; continue; fi
    c="mdm-$lang-fb"
    run_mdm "$lang" "$c"
    check "MDM $lang without ~/.aitools/skills: exit 0, embedded skills deployed to both tools ($SHARED_ONE)" \
        "[ \"\$(rc_of $c)\" = 0 ] && grep -q '^OK|claude skills|' '$TMP_ROOT/$c.summary' && grep -q '^OK|cursor skills|' '$TMP_ROOT/$c.summary' && no_rows_for $c skills && [ -f '$TMP_ROOT/$c/.claude/skills/$SHARED_ONE/SKILL.md' ] && [ -f '$TMP_ROOT/$c/.cursor/skills/$SHARED_ONE/SKILL.md' ]"
    c="mdm-$lang-fan"
    mkdir -p "$TMP_ROOT/$c/.aitools/skills"
    run_mdm "$lang" "$c"
    check "MDM $lang with ~/.aitools/skills: exit 0, only the skills n/a row, nothing deployed" \
        "[ \"\$(rc_of $c)\" = 0 ] && [ \"\$(rows_of $c)\" = '$FANOUT_ROW' ] && [ ! -e '$TMP_ROOT/$c/.claude/skills' ] && [ ! -e '$TMP_ROOT/$c/.cursor/skills' ]"
done

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
