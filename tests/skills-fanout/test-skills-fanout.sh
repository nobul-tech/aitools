#!/usr/bin/env bash
# test-skills-fanout.sh -- tests for the skills fan-out (lib fanout_harness_skills /
# Invoke-HarnessSkillsFanout) as scripts/setup-user-claude.sh and .ps1 run it:
# ~/.aitools/skills -> ~/.claude/skills. Every skill directory is fanned out except
# the ones the skills manifest retires; every file under it (nested too), *.bak.*
# names and hidden entries skipped; the executable bit follows the harness copy; a
# directory or symlink in ~/.claude/skills the fan-out did not deploy (the firecrawl
# symlinks, a third-party skill) is preserved; the copy of a retired skill removed
# only when it holds the harness copy's files, after a backup beside ~/.claude/skills;
# adopt target from the manifest source. One case fills ~/.aitools/skills with the
# real deploy-harness (FO-2 manifest) from this checkout. Cursor cases (FO-5):
# setup-user-cursor step 5 fans out to ~/.cursor/skills with no adopt target
# (retired prune, user skill and symlink kept; the whole script runs, stub
# rg/agent on PATH).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs setup-user-claude.sh, setup-user-cursor.sh and
# deploy-harness.sh on macOS/Linux and refuses Windows; the .ps1 scripts are
# tested on Windows by tests/skills-fanout/test-skills-fanout.ps1. No guard is
# bypassed: the real scripts run.
# Parity between the halves: each parity point writes one record (exit code;
# the skills tree as "path md5 [x]", relative, LC_ALL=C sorted, a backup file
# once as "path.bak.TS (backup)", symlinks left out -- they are checked
# explicitly; the ACTION and skills summary rows, sorted; HOME as "HOME", the
# temp root as <TMP>) that must equal tests/skills-fanout/golden/<case>.txt,
# which the Windows harness checks too (tests/lib/platform-lib.sh
# golden_match). AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux rewrites the files
# from the .sh run. Cases a platform cannot build (chmod 000 reads as root;
# case-only duplicates on a case-insensitive file system) are SKIP there, with
# the reason. The real-harness case has no golden file (its tree is this
# checkout's own skills): its explicit checks run on every platform.
#
# Safe to re-run: every case runs a copy of scripts/ in a temp aitools checkout,
# under its own temp HOME, with a temp git dotprofile (all removed on exit); the
# real HOME, ~/.aitools and dotprofile are never touched.
# Platform: macOS, Linux (perl, git; python3 for the pty cases). Exit 1 if any
# case fails. Spec: plans/skills-and-rules-fanout.md 3.4.
#
# Usage: bash tests/skills-fanout/test-skills-fanout.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility (no-op): the harness always runs only .sh
#   AITOOLS_TEST_BASH=/bin/bash runs the scripts under that bash (CI: macOS 3.2)

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/skills-fanout/test-skills-fanout.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/skills-fanout/test-skills-fanout.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

for arg in "$@"; do
    case "$arg" in
        --help|-h) perl -ne 'last if $. > 1 && !/^#/; print if $. >= 2' "$0"; exit 0 ;;
        --bash-only) ;;
        *) printf 'Unknown option: %s (see --help)\n' "$arg"; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$ROOT/tests/lib/platform-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
GOLDEN_DIR="$ROOT/tests/skills-fanout/golden"
GOLDEN_TMP="$TMP_ROOT"
L=sh                    # tag of the language under test: HOME $C/$L, output $C/$L.out
cleanup() {
    # chmod 000 cases: restore so rm can remove them
    chmod -R u+rwx "$TMP_ROOT" 2>/dev/null || printf 'warn: chmod restore failed under %s\n' "$TMP_ROOT"
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT
TB="${AITOOLS_TEST_BASH:-bash}"   # CI also runs macOS /bin/bash 3.2

PASS=0
FAIL=0
SKIP=0
C=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$C" ] && [ -f "$C/$L.out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/$L.out" | tail -n 25
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }

for t in perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        # In CI a missing tool is a broken runner, not a reason to pass
        if [ -n "${CI:-}" ]; then printf 'FAIL %s not found (CI=%s)\n' "$t" "$CI"; exit 1; fi
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done
die() { printf 'FAIL fixture setup: %s\n' "$1"; exit 1; }
HAVE_PTY=false
NO_PTY_WHY="python3 not found"
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi
CAN_CHMOD_READ=true   # chmod 000 blocks reads (not for root)
if [ "$(id -u)" = 0 ]; then CAN_CHMOD_READ=false; fi
CASE_SENSITIVE_FS=false
: > "$TMP_ROOT/cs-probe"
if [ ! -e "$TMP_ROOT/CS-PROBE" ]; then CASE_SENSITIVE_FS=true; fi

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools checkout: a copy of scripts/ (adopt targets of shared and
# aitools skills land here, never in this repo) ---
A="$TMP_ROOT/aitools"
# A package payload (git archive) has the same files but no .git: adopt into it
# is never offered. The fan-out counts only a git checkout.
PAYLOAD="$TMP_ROOT/payload"
REPO="$A"   # the checkout run_one / run_pty run setup-user-claude from
# --- Fixture dotprofile (a git repo, no remote: an adopt commits, the push fails) ---
DP="$TMP_ROOT/aitools-tess"
# Every fixture step must succeed (a subshell with -e): a broken fixture fails the suite
( set -e
mkdir -p "$A/scripts" "$A/shared/skills/s1" "$A/shared/skills/dup" "$A/.claude/skills/p1" "$A/.claude/skills/dup"
# Plain copies (no script is patched; each runs with its OS guard on)
for f in setup-user-claude.sh setup-user-claude.ps1 aitools-lib.sh aitools-lib.ps1 aitools-profile.sh aitools-profile.ps1 aitools-json.pl aitools-json.ps1; do
    cp "$ROOT/scripts/$f" "$A/scripts/$f"
done
cp "$ROOT/shared/claude-shared.md" "$A/shared/claude-shared.md"
printf '## shared s1\n' > "$A/shared/skills/s1/SKILL.md"
printf '## project p1\n' > "$A/.claude/skills/p1/SKILL.md"
printf '## dup shared\n' > "$A/shared/skills/dup/SKILL.md"
printf '## dup project\n' > "$A/.claude/skills/dup/SKILL.md"
mkdir -p "$PAYLOAD"
cp -R "$A/scripts" "$A/shared" "$A/.claude" "$PAYLOAD/"
git -C "$A" init -q
mkdir -p "$DP/claude/skills/d1"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
printf '## dot d1\n' > "$DP/claude/skills/d1/SKILL.md"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture
) || die "the temp aitools checkout or fixture dotprofile could not be created"

# --- Case helpers ---
# H: the HOME of the run being seeded (set by case_run for each language)
hskill() {  # hskill NAME REL TEXT: ~/.aitools/skills/NAME/REL
    mkdir -p "$(dirname "$H/.aitools/skills/$1/$2")"; printf '%s\n' "$3" > "$H/.aitools/skills/$1/$2"
}
dskill() {  # dskill NAME REL TEXT: ~/.claude/skills/NAME/REL (already deployed)
    mkdir -p "$(dirname "$H/.claude/skills/$1/$2")"; printf '%s\n' "$3" > "$H/.claude/skills/$1/$2"
}
# manifest <line>...: ~/.aitools/skills/.aitools-skills-manifest (v1); "|" stands for the TAB
manifest() {
    mkdir -p "$H/.aitools/skills"
    { printf '# aitools skills manifest v1\n'
      for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done
    } > "$H/.aitools/skills/.aitools-skills-manifest"
}

TMP_FORMS="$TMP_ROOT"   # the temp root as a log prints it (lognorm)

# run_env H SUMMARY [VAR=value...]: sets E, the env command of a run under HOME H
run_env() {
    local h="$1" s="$2"; shift 2
    E=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1
        HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs"
        AITOOLS_SUMMARY_FILE="$s" GIT_CONFIG_GLOBAL="$h/.gitconfig"
        GIT_CONFIG_NOSYSTEM=1 "$@")
}
# script_cmd DIR BASE: sets X, the command running DIR/BASE.sh under $TB
script_cmd() {
    X=("$TB" "$1/$2.sh")
}

# run_one [FLAG]: run setup-user-claude non-interactively under $C/$L
run_one() {
    local flag="${1:-}"
    run_env "$C/$L" "$C/$L.summary"
    script_cmd "$REPO/scripts" setup-user-claude
    : > "$C/$L.summary"
    "${E[@]}" "${X[@]}" ${flag:+"$flag"} < /dev/null > "$C/$L.out" 2>&1
    echo $? > "$C/$L.rc"
}

# run_pty INPUT: the same on a pty (review menu), keystrokes INPUT
run_pty() {
    local input="$1"
    run_env "$C/$L" "$C/$L.summary"
    script_cmd "$REPO/scripts" setup-user-claude
    : > "$C/$L.summary"
    "${E[@]}" python3 "$PTY" --input "$input" --log "$C/$L.out" -- "${X[@]}"
    echo $? > "$C/$L.rc"
}

# seed_home H: config.json -> the fixture dotprofile, a git identity
seed_home() {
    mkdir -p "$1/.aitools"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$1/.aitools/config.json"
    printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$1/.gitconfig"
}
# case_run NAME SEED_FN [FLAG]: a fresh HOME $C/$L seeded by SEED_FN, then one run
case_run() {
    C="$TMP_ROOT/$1"
    local seed="$2"
    mkdir -p "$C"
    H="$C/$L"
    seed_home "$H"
    "$seed"
    run_one "${3:-}"
}
rerun() {  # rerun [FLAG]: run again in the same HOME
    run_one "${1:-}"
}

rc() { cat "$C/${1:-$L}.rc"; }
row() { grep -qxF "$1" "$C/${2:-$L}.summary"; }                  # exact summary row
nondetail() { grep -F '|claude skills|' "$C/${1:-$L}.summary" | grep -v '^DETAIL' | tail -n 1; }
S() { printf '%s' "$C/${1:-$L}/.claude/skills"; }                 # the deployed skills dir
# lognorm [LANG]: the run's log files, CR removed, every backslash a slash, the
# temp root (TMP_FORMS; case-insensitive) as <TMP>, so the expected texts are the
# ones the Windows harness (test-skills-fanout.ps1) matches too
lognorm() {
    local f
    for f in "$C/${1:-$L}/logs/"*.log; do
        [ -f "$f" ] || continue
        TMPF="$TMP_FORMS" perl -pe '
            BEGIN { @t = sort { length($b) <=> length($a) } grep { length } split /\n/, $ENV{TMPF} }
            s/\r//g; tr{\\}{/};
            for my $t (@t) { s/\Q$t\E/<TMP>/gi }
        ' "$f"
    done
}
logged() { lognorm "${2:-$L}" | grep -qF -- "$1"; }      # in the run's log files (none: no match)
logged_re() { lognorm "${2:-$L}" | grep -qE -- "$1"; }   # the same, an extended regex
bakdirs() { ls "$C/${1:-$L}/.claude" | grep -c '^skills\.bak\.'; }  # backup dirs beside ~/.claude/skills
DPN='<TMP>/aitools-tess'   # the fixture dotprofile as lognorm prints it

# tree_sig DIR: "<path> <md5> [x]" per file (x: executable); a backup file is
# "<path>.bak.TS (backup)", listed once however many there are (two runs in
# the same second share one backup name); symlinks are neither listed nor
# followed (checked explicitly)
tree_sig() {
    perl -MDigest::MD5=md5_hex -MFile::Find -e '
        my $root = shift; my %out;
        exit 0 unless -d $root;
        find({ no_chdir => 1, wanted => sub {
            my $rel = substr($_, length($root) + 1);
            return if $rel eq "";
            if (-l $_) { $File::Find::prune = 1; return }
            return unless -f $_;
            if ($rel =~ s/\.bak\.[0-9TZ-]+\z/.bak.TS/) { $out{"$rel (backup)"} = 1; return }
            open my $fh, "<:raw", $_ or die "cannot read $_: $!\n";
            local $/; my $c = <$fh>; close $fh;
            $out{"$rel " . md5_hex(defined $c ? $c : "") . (-x $_ ? " x" : "")} = 1;
        } }, $root);
        print "$_\n" for sort keys %out;
    ' "$1"
}
rows() { grep -E '^(ACTION\||[A-Z]+\|claude skills\|)' "$1" | LC_ALL=C sort; }

# golden_record NAME DIR ROWS_FN [EXTRA_FILE]: the run's exit code, the tree of DIR
# and its summary rows (ROWS_FN), HOME as "HOME", must equal golden/NAME.txt
golden_record() {
    local name="$1" dir="$2" rowsfn="$3" extra="${4:-}" f="$C/golden-$1.txt"
    {
        printf '# exit code\n'; rc
        printf '# skills tree (path md5 [x]; symlinks not listed)\n'; tree_sig "$dir"
        printf '# summary rows (ACTION and skills, sorted)\n'; "$rowsfn" "$C/$L.summary"
        if [ -n "$extra" ]; then printf '# extra\n'; cat "$extra"; fi
    } | HP="$C/$L" perl -pe '
        for my $h (grep { length } ($ENV{HP})) {
            (my $b = $h) =~ s{/}{\\}g;
            s/\Q$h\E/HOME/g; s/\Q$b\E/HOME/g;
        }' > "$f"
    check "golden $L: $name: exit code, tree, summary rows" "golden_match '$name.txt' '$f'"
}
# parity CASE [EXTRA_FILE]: the ~/.claude/skills record of the case (see golden_record)
parity() { golden_record "$1" "$(S)" rows "${2:-}"; }

# ---------------------------------------------------------------------------
# No harness skills: nothing deployed, ~/.claude/skills untouched, exit 0
# ---------------------------------------------------------------------------
seed_missing() { dskill mine SKILL.md 'mine'; }
case_run missing seed_missing
# No row: setup-user-skills (the fallback) owns the claude skills rows then (PR #125 N2)
check "missing: exit 0, no claude skills row, logged" "[ \"\$(rc)\" = 0 ] && ! grep -qF '|claude skills|' '$C/$L.summary' && grep -q 'No harness skills at .*setup-user-skills deploys skills' '$C/$L.out'"
check "missing: ~/.claude/skills untouched, no backup" "grep -qx mine '$(S)/mine/SKILL.md' && [ \"\$(ls '$(S)')\" = mine ] && [ \"\$(bakdirs)\" = 0 ]"
check "missing: the dotprofile's claude/skills is not deployed" "[ ! -e '$(S)/d1' ]"
parity missing

seed_empty() { mkdir -p "$H/.aitools/skills"; }
case_run empty seed_empty
check "empty: row n/a (no harness skills)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|n/a (no harness skills)' ]"
parity empty

# ---------------------------------------------------------------------------
# Fan-out: every source, nested files, filters, executable bit, preserved
# (third-party directory, firecrawl-style symlink), rerun, edit, --force
# ---------------------------------------------------------------------------
seed_fanout() {
    manifest 'd1|dotprofile' 'dup|shared' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'
    hskill s1 tests/expected-behaviors.md 'nested'
    hskill s1 scripts/run.sh '#!/bin/sh'; chmod 755 "$H/.aitools/skills/s1/scripts/run.sh"
    hskill s1 SKILL.md.bak.2026-10-22T010203Z 'old s1'
    hskill s1 tests/X.BAK.1 'upper-case backup'
    hskill p1 SKILL.md '## project p1'
    hskill d1 SKILL.md '## dot d1'
    hskill dup SKILL.md '## dup shared'
    hskill old.bak.2026-10-25T000000Z SKILL.md 'a deploy-harness backup'
    hskill .hidden SKILL.md 'hidden'
    printf 'not a skill\n' > "$H/.aitools/skills/notes.txt"
    dskill mine SKILL.md 'mine'
    mkdir -p "$H/.agents/skills/firecrawl"; printf 'fc\n' > "$H/.agents/skills/firecrawl/SKILL.md"
    ln -s ../../.agents/skills/firecrawl "$H/.claude/skills/firecrawl"
}
case_run fanout seed_fanout
check "fanout: exit 0, row 6 added" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|6 added' ]"
check "fanout: shared, aitools, dotprofile skills deployed" "grep -qx '## shared s1' '$(S)/s1/SKILL.md' && grep -qx '## project p1' '$(S)/p1/SKILL.md' && grep -qx '## dot d1' '$(S)/d1/SKILL.md' && grep -qx '## dup shared' '$(S)/dup/SKILL.md'"
check "fanout: nested files deployed" "grep -qx nested '$(S)/s1/tests/expected-behaviors.md' && [ -f '$(S)/s1/scripts/run.sh' ]"
check "fanout: executable bit copied" "[ -x '$(S)/s1/scripts/run.sh' ] && [ ! -x '$(S)/s1/SKILL.md' ]"
check "fanout: *.bak.* (any case), hidden, backup dirs and top-level files skipped" "[ ! -e '$(S)/s1/SKILL.md.bak.2026-10-22T010203Z' ] && [ ! -e '$(S)/s1/tests/X.BAK.1' ] && [ ! -e '$(S)/old.bak.2026-10-25T000000Z' ] && [ ! -e '$(S)/.hidden' ] && [ ! -e '$(S)/notes.txt' ]"
check "fanout: top-level file logged, manifest silent" "grep -q 'Ignoring non-skill file in harness skills: notes.txt' '$C/$L.out' && ! grep -q 'aitools-skills-manifest' '$C/$L.out'"
check "fanout: third-party skill preserved" "grep -qx mine '$(S)/mine/SKILL.md' && grep -q 'Preserved unmanaged skill: mine' '$C/$L.out'"
check "fanout: firecrawl symlink preserved, never followed" "[ -L '$(S)/firecrawl' ] && [ \"\$(readlink '$(S)/firecrawl')\" = ../../.agents/skills/firecrawl ] && grep -qx fc '$C/$L/.agents/skills/firecrawl/SKILL.md' && [ \"\$(ls '$C/$L/.agents/skills/firecrawl')\" = SKILL.md ] && grep -q 'Preserved unmanaged skill: firecrawl' '$C/$L.out'"
check "fanout: one item per file in DETAIL rows" "row 'DETAIL|claude skills|added: s1/SKILL.md' && row 'DETAIL|claude skills|added: s1/scripts/run.sh' && row 'DETAIL|claude skills|added: s1/tests/expected-behaviors.md'"
for lang in $L; do
    check "adopt map $lang: shared -> aitools shared/skills" "logged 'claude skills: s1/SKILL.md source=shared adopt=' $lang && logged '/shared/skills/s1/SKILL.md' $lang"
    check "adopt map $lang: aitools -> aitools .claude/skills" "logged 'claude skills: p1/SKILL.md source=aitools adopt=' $lang && logged '/.claude/skills/p1/SKILL.md' $lang"
    check "adopt map $lang: dotprofile -> dotprofile claude/skills" "logged 'claude skills: d1/SKILL.md source=dotprofile adopt=$DPN/claude/skills/d1/SKILL.md' $lang"
    check "adopt map $lang: same name in shared and .claude, manifest shared -> shared" "logged_re 'claude skills: dup/SKILL\.md source=shared adopt=.*/aitools/shared/skills/dup/SKILL\.md\$' $lang"
    check "adopt map $lang: no repo file -> none" "logged 'claude skills: s1/tests/expected-behaviors.md source=shared adopt=none' $lang"
done
parity fanout
rerun
check "fanout rerun: row 6 verified, nothing written" "[ \"\$(nondetail)\" = 'OK|claude skills|6 verified' ] && [ -z \"\$(find '$(S)' -name '*.bak.*')\" ] && [ \"\$(bakdirs)\" = 0 ]"
parity fanout-rerun
printf '## shared s1\nlocal edit\n' > "$(S)/s1/SKILL.md"
rerun
check "fanout edited, non-interactive: overwritten, backup kept, WARN row" "[ \"\$(nondetail)\" = 'WARN|claude skills|1 updated, 5 verified' ] && grep -qx '## shared s1' '$(S)/s1/SKILL.md' && ls '$(S)/s1' | grep -q '^SKILL\.md\.bak\.'"
parity fanout-edited
printf '## shared s1\nlocal edit 2\n' > "$(S)/s1/SKILL.md"
rerun --force
check "fanout --force: overwritten" "[ \"\$(rc)\" = 0 ] && grep -qx '## shared s1' '$(S)/s1/SKILL.md' && [ \"\$(nondetail)\" = 'WARN|claude skills|1 updated, 5 verified' ]"
parity fanout-force
chmod 644 "$(S)/s1/scripts/run.sh"
rerun
check "fanout: executable bit restored on a verified file" "[ -x '$(S)/s1/scripts/run.sh' ] && [ \"\$(nondetail)\" = 'OK|claude skills|6 verified' ]"
parity fanout-xbit

case_run fanout-dry seed_fanout --dry-run
check "fanout dry run: nothing written, row dry run" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|dry run (no files written)' ] && [ ! -e '$(S)/s1' ] && grep -q 'DRY RUN\] Would create: s1/SKILL.md' '$C/$L.out'"
parity fanout-dry

# A skill name in DEST that is a symlink or a file: never written, WARN + ACTION
seed_kept() {
    manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
    mkdir -p "$H/.claude/skills" "$H/elsewhere/s1"; printf 'theirs\n' > "$H/elsewhere/s1/SKILL.md"
    ln -s ../../elsewhere/s1 "$H/.claude/skills/s1"
    printf 'a file\n' > "$H/.claude/skills/p1"
}
case_run kept seed_kept
check "kept: exit 0, row 1 added (WARN)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added' ]"
check "kept: symlink and file untouched" "[ -L '$(S)/s1' ] && grep -qx theirs '$C/$L/elsewhere/s1/SKILL.md' && [ \"\$(ls '$C/$L/elsewhere/s1')\" = SKILL.md ] && grep -qx 'a file' '$(S)/p1'"
check "kept: ACTION row names both" "row 'ACTION||Claude Code skills in ~/.claude/skills not updated (a symlink or a file, not a directory the fan-out owns): p1, s1 -- move them aside to get the aitools copy'"
parity kept

# ---------------------------------------------------------------------------
# Retired skills: pruned only when the copy holds the harness copy's files
# ---------------------------------------------------------------------------
seed_retired() {
    manifest '[r]|retired' 'a|shared' 'gone|retired' 'mine2|retired' 'old|retired'
    hskill a SKILL.md 'skill a'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'          # deploy-harness retired it (backup, removed)
    hskill gone.bak.2026-10-25T000000Z tests/x.md 'gx'
    hskill old SKILL.md 'old'                                   # retired, but still in ~/.aitools/skills
    hskill '[r].bak.2026-10-25T000000Z' SKILL.md 'r'
    dskill gone SKILL.md 'gone'; dskill gone tests/x.md 'gx'; dskill gone SKILL.md.bak.2026-01-01T000000Z 'an old backup'
    dskill gone .DS_Store 'finder junk'; dskill gone tests/Thumbs.db 'explorer junk'   # never block the prune
    local i
    for i in 1 2 3 4 5 6; do dskill "../skills.bak.2026-01-0${i}T000000Z/old$i" SKILL.md "old backup $i"; done
    dskill old SKILL.md 'old'
    dskill mine2 SKILL.md 'my own'
    dskill '[r]' SKILL.md 'r'
}
case_run retired seed_retired
check "retired: exit 0, row 1 added, 3 removed (WARN: a kept dir still loads)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added, 3 removed' ]"
check "retired: copies removed from ~/.claude/skills" "[ ! -e '$(S)/gone' ] && [ ! -e '$(S)/old' ] && [ ! -e '$(S)/[r]' ]"
check "retired: OS junk files did not block the prune; the backup keeps them" "b=\$(ls -d '$C/$L/.claude/'skills.bak.* | LC_ALL=C sort | tail -n 1) && [ -f \"\$b/gone/.DS_Store\" ] && [ -f \"\$b/gone/tests/Thumbs.db\" ]"
check "retired: the newest backup dir beside ~/.claude/skills holds them" "b=\$(ls -d '$C/$L/.claude/'skills.bak.* | LC_ALL=C sort | tail -n 1) && grep -qx gone \"\$b/gone/SKILL.md\" && grep -qx gx \"\$b/gone/tests/x.md\" && grep -qx old \"\$b/old/SKILL.md\" && grep -qx r \"\$b/[r]/SKILL.md\""
check "retired: backups beside ~/.claude/skills pruned to the newest 5" "[ \"\$(bakdirs)\" = 5 ] && [ ! -e '$C/$L/.claude/skills.bak.2026-01-01T000000Z' ] && [ ! -e '$C/$L/.claude/skills.bak.2026-01-02T000000Z' ] && [ -d '$C/$L/.claude/skills.bak.2026-01-03T000000Z' ] && grep -q 'Pruned old backup' '$C/$L.out'"
check "retired: removals in DETAIL rows" "row 'DETAIL|claude skills|removed: gone' && row 'DETAIL|claude skills|removed: old' && row 'DETAIL|claude skills|removed: [r]'"
check "retired: a retired skill still in ~/.aitools/skills is not fanned out" "grep -q 'Not fanned out: old (retired in the skills manifest)' '$C/$L.out' && ! row 'DETAIL|claude skills|added: old/SKILL.md'"
check "retired: user dir with a retired name kept, ACTION row" "grep -qx 'my own' '$(S)/mine2/SKILL.md' && row 'ACTION||Claude Code still loads retired skills in ~/.claude/skills: mine2 -- delete them unless you wrote them'"
parity retired
case_run retired-dry seed_retired --dry-run
check "retired dry run: nothing removed, row dry run, removal previewed" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|dry run (no files written)' ] && [ -d '$(S)/gone' ] && [ -d '$(S)/old' ] && [ ! -e '$(S)/a' ] && [ \"\$(bakdirs)\" = 6 ] && grep -q 'DRY RUN\] Would back up and remove gone' '$C/$L.out'"
parity retired-dry

# A retired name whose copy differs only in case (Gone for gone)
seed_retired_case() {
    manifest 'a|shared' 'gone|retired'
    hskill a SKILL.md 'skill a'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
    dskill Gone SKILL.md 'gone'
}
case_run retired-case seed_retired_case
check "retired, case differs: found and removed under its own name" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|1 added, 1 removed' ] && [ ! -e '$(S)/Gone' ] && row 'DETAIL|claude skills|removed: Gone'"
parity retired-case

# A retired copy with one file changed by the user, or with a symlink inside: kept
seed_retired_mod() {
    manifest 'a|shared' 'gone|retired'
    hskill a SKILL.md 'skill a'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
    dskill gone SKILL.md 'gone, edited by me'
}
case_run retired-mod seed_retired_mod
check "retired, user-modified: kept, ACTION row" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added' ] && grep -qx 'gone, edited by me' '$(S)/gone/SKILL.md' && row 'ACTION||Claude Code still loads retired skills in ~/.claude/skills: gone -- delete them unless you wrote them'"
check "retired, user-modified: not counted again as preserved" "! grep -q 'Preserved unmanaged skill: gone' '$C/$L.out' && grep -q 'Skills (claude skills): 1 added, 0 preserved' '$C/$L.out'"
parity retired-mod

# A retired copy that cannot be fully removed (a read-only subdirectory): failed,
# the error names the backup, not counted as preserved; backup modes as in sh
if $CAN_CHMOD_READ; then
    seed_rmfail() {
        manifest 'a|shared' 'gone|retired'
        hskill a SKILL.md 'skill a'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'; hskill gone.bak.2026-10-25T000000Z sub/x.md 'gx'
        dskill gone SKILL.md 'gone'; dskill gone sub/x.md 'gx'
        chmod 555 "$H/.claude/skills/gone/sub"
    }
    case_run rmfail seed_rmfail
    check "retired, cannot remove: exit 1, row 1 failed, the error names the backup" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ] && grep -q 'Cannot remove .*gone (retired skill; it may be partly removed; backup in .*skills\.bak\..*/gone)' '$C/$L.out'"
    check "retired, cannot remove: not counted again as preserved" "! grep -q 'Preserved unmanaged skill: gone' '$C/$L.out'"
    # The backup directory's mode (sh = ps before; now part of the golden record)
    b=$(ls -d "$C/$L/.claude/"skills.bak.* | LC_ALL=C sort | tail -n 1)
    perl -e 'printf "backup gone/sub mode %o\n", (stat shift)[2] & 07777' "$b/gone/sub" > "$C/bakmode"
    check "retired, cannot remove: backup directory mode recorded" "[ -s '$C/bakmode' ]"
    parity rmfail "$C/bakmode"

    # ~/.claude/skills writable but not listable: ACTION row, preserved count unknown
    seed_unlisted() {
        manifest 'a|shared' 'gone|retired'
        hskill a SKILL.md 'skill a'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
        dskill gone SKILL.md 'gone'; dskill mine SKILL.md 'mine'
        chmod 300 "$H/.claude/skills"
    }
    case_run unlisted seed_unlisted
    chmod 755 "$C/$L/.claude/skills"
    check "unlisted DEST: ACTION row, preserved count unknown, retired copy kept" "[ \"\$(rc)\" = 0 ] && row 'ACTION||Claude Code skills in ~/.claude/skills cannot be listed: retired skills not checked and other skills not counted -- check its permissions' && grep -q 'preserved count unknown (cannot list)' '$C/$L.out' && [ -d '$(S)/gone' ]"
    parity unlisted
else
    skip "retired removal failure and unlisted DEST (root)"
fi

# ---------------------------------------------------------------------------
# Manifest absent, bad header, invalid lines, unreadable
# ---------------------------------------------------------------------------
seed_nomanifest() { hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b'; }
case_run nomanifest seed_nomanifest
check "no manifest: everything fanned out, adopt not offered" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|2 added' ] && grep -q 'No skills manifest' '$C/$L.out' && logged 'claude skills: a/SKILL.md source=unknown adopt=none'"
parity nomanifest

seed_badheader() {
    mkdir -p "$H/.aitools/skills"
    printf '# aitools skills manifest v2\nx\tretired\n' > "$H/.aitools/skills/.aitools-skills-manifest"
    hskill a SKILL.md 'skill a'; hskill x.bak.2026-10-25T000000Z SKILL.md 'x'; dskill x SKILL.md 'x'
}
case_run badheader seed_badheader
check "bad header: fanned out, nothing retired, WARN + ACTION" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added' ] && [ -d '$(S)/x' ] && row 'ACTION||Run aitools to rebuild ~/.aitools/skills and its manifest'"
parity badheader

seed_invalid() { manifest '.dot|shared' 'a|unknown' 'b|shared'; hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b'; }
case_run invalid seed_invalid
check "invalid lines: warned, skills still fanned out" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|2 added' ] && grep -q 'line ignored: .dot<TAB>shared' '$C/$L.out' && logged 'claude skills: a/SKILL.md source=unknown adopt=none'"
parity invalid

if $CAN_CHMOD_READ; then
    seed_unreadable() { hskill a SKILL.md 'skill a'; chmod 000 "$H/.aitools/skills"; }
    case_run unreadable seed_unreadable
    check "unreadable harness dir: ERROR row, exit 1" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|cannot read harness skills' ]"
    parity unreadable
    chmod 755 "$C/$L/.aitools/skills"

    seed_manifest_unreadable() { manifest 'a|shared'; hskill a SKILL.md 'skill a'; chmod 000 "$H/.aitools/skills/.aitools-skills-manifest"; }
    case_run manifest-unreadable seed_manifest_unreadable
    check "unreadable manifest: skills fanned out, ERROR rows, final row ERROR, exit 1" "[ \"\$(rc)\" = 1 ] && [ -f '$(S)/a/SKILL.md' ] && row 'ERROR|claude skills|cannot read skills manifest' && row 'DETAIL|claude skills|failed: .aitools-skills-manifest' && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ]"
    parity manifest-unreadable
else
    skip "unreadable harness dir and manifest (root)"
fi

# ---------------------------------------------------------------------------
# Adopt (pty) and abort (pty); package payload (no .git)
# ---------------------------------------------------------------------------
if $HAVE_PTY; then
    C="$TMP_ROOT/fanout"
    for lang in $L; do
        printf '## dot d1\nmy edit %s\n' "$lang" > "$C/$lang/.claude/skills/d1/SKILL.md"
        printf '## project p1\nmy edit %s\n' "$lang" > "$C/$lang/.claude/skills/p1/SKILL.md"
        run_pty 'a\na\n'
        check "adopt $lang: dotprofile skill written to the dotprofile and committed" "grep -qx 'my edit $lang' '$DP/claude/skills/d1/SKILL.md' && git -C '$DP' log -1 --name-only --format= | grep -qx 'claude/skills/d1/SKILL.md' && git -C '$DP' diff --quiet -- claude/skills/d1/SKILL.md"
        check "adopt $lang: aitools skill written to the aitools working tree" "grep -qx 'my edit $lang' '$A/.claude/skills/p1/SKILL.md'"
        check "adopt $lang: DETAIL rows" "row 'DETAIL|claude skills|accept & adopt: d1/SKILL.md' $lang && row 'DETAIL|claude skills|accept & adopt: p1/SKILL.md' $lang"
        # abort: exit 2 from the library, no claude skills row, the local file kept
        printf '## shared s1\nlocal %s\n' "$lang" > "$C/$lang/.claude/skills/s1/SKILL.md"
        run_pty 'x\n'
        check "abort $lang: exit 2, no claude skills row, local file kept" "[ \"\$(rc $lang)\" = 2 ] && [ -z \"\$(nondetail $lang)\" ] && grep -qx 'local $lang' '$C/$lang/.claude/skills/s1/SKILL.md'"
    done
else
    # In CI a missing pty backend is a broken runner, not a reason to pass
    if [ -n "${CI:-}" ]; then
        printf 'FAIL adopt and abort on a pty (%s; required under CI)\n' "$NO_PTY_WHY"; FAIL=$((FAIL + 1))
    else
        skip "adopt and abort on a pty ($NO_PTY_WHY)"
    fi
fi
printf '## project p1\n' > "$A/.claude/skills/p1/SKILL.md"

seed_payload() {
    manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
}
REPO="$PAYLOAD"
case_run payload seed_payload
REPO="$A"
for lang in $L; do
    check "payload $lang: no adopt into a checkout without .git" "logged 'claude skills: s1/SKILL.md source=shared adopt=none' $lang && logged 'claude skills: p1/SKILL.md source=aitools adopt=none' $lang && logged 'claude skills: d1/SKILL.md source=dotprofile adopt=$DPN/claude/skills/d1/SKILL.md' $lang"
done
parity payload

# ---------------------------------------------------------------------------
# Names: [ ] in a name, case-only duplicates, dangling symlink; DEST not creatable
# ---------------------------------------------------------------------------
seed_bracket() { manifest '[x]|shared'; hskill '[x]' SKILL.md 'bracket'; hskill '[x]' 'a*b?.md' 'glob chars'; }
case_run bracket seed_bracket
check "bracket name: deployed" "[ \"\$(nondetail)\" = 'OK|claude skills|2 added' ] && grep -qx bracket '$(S)/[x]/SKILL.md' && grep -qx 'glob chars' '$(S)/[x]/a*b?.md'"
rerun
check "bracket name: rerun verified" "[ \"\$(nondetail)\" = 'OK|claude skills|2 verified' ]"
parity bracket

# Non-text files (a NUL byte; invalid UTF-8): copied byte for byte, never corrupted
seed_binary() {
    manifest 'b|shared'
    hskill b SKILL.md 'skill b'
    printf 'PNG\000\001\002 bytes\n' > "$H/.aitools/skills/b/img.bin"
    printf '\377\376latin1 \351\n' > "$H/.aitools/skills/b/latin.txt"
}
case_run binary seed_binary
check "binary: exit 0, row 3 added, bytes identical" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|3 added' ] && cmp -s '$C/$L/.aitools/skills/b/img.bin' '$(S)/b/img.bin' && cmp -s '$C/$L/.aitools/skills/b/latin.txt' '$(S)/b/latin.txt'"
parity binary
rerun
check "binary rerun: row 3 verified" "[ \"\$(nondetail)\" = 'OK|claude skills|3 verified' ]"
printf 'changed\000\n' > "$(S)/b/img.bin"
rerun
check "binary edited: overwritten byte for byte, backup kept" "[ \"\$(nondetail)\" = 'OK|claude skills|1 updated, 2 verified' ] && cmp -s '$C/$L/.aitools/skills/b/img.bin' '$(S)/b/img.bin' && ls '$(S)/b' | grep -q '^img\.bin\.bak\.' && ! ls '$(S)/b' | grep -q 'aitools-tmp'"
parity binary-edited

# Strict UTF-8 in both languages (review R1): each of these is binary in sh and
# ps; a valid multi-byte file and a noncharacter stay text
seed_utf8edge() {
    manifest 'u|shared'
    hskill u SKILL.md 'skill u'
    printf 'a\355\240\200b\n' > "$H/.aitools/skills/u/surrogate.txt"       # ED A0 80: U+D800
    printf 'a\364\220\200\200b\n' > "$H/.aitools/skills/u/above-max.txt"   # F4 90 80 80: > U+10FFFF
    printf 'a\377b\n' > "$H/.aitools/skills/u/ff.txt"                      # FF
    printf 'a\300\257b\n' > "$H/.aitools/skills/u/overlong.txt"            # C0 AF: overlong "/"
    printf 'a\342\202\n' > "$H/.aitools/skills/u/truncated.txt"            # E2 82 then a newline
    printf 'caf\303\251 \342\202\254\n' > "$H/.aitools/skills/u/valid.txt" # valid: e-acute, euro
    printf 'a\357\277\276b\n' > "$H/.aitools/skills/u/nonchar.txt"         # EF BF BE: U+FFFE (valid UTF-8)
}
case_run utf8edge seed_utf8edge
for lang in $L; do
    for f in surrogate above-max ff overlong truncated; do
        check "utf8 strict $lang: $f.txt copied as binary, bytes identical" "logged 'Created: u/$f.txt (binary)' $lang && cmp -s '$C/$lang/.aitools/skills/u/$f.txt' '$C/$lang/.claude/skills/u/$f.txt'"
    done
    for f in valid nonchar; do
        check "utf8 strict $lang: $f.txt is text (review path)" "logged 'Created: u/$f.txt ->' $lang && ! logged 'Created: u/$f.txt (binary)' $lang"
    done
done
parity utf8edge

# Large valid UTF-8 files stay text in sh as in ps (review NB1: one anchored
# regex with (...)* hit perl's repeat limit and called them binary)
seed_utf8large() {
    manifest 'w|shared'
    hskill w SKILL.md 'skill w'
    perl -e 'print "\303\251" x 100000, "\n"' > "$H/.aitools/skills/w/eacute.txt"   # 200 KB of e-acute
    perl -e 'print "a\303\251" x 40000, "\n"' > "$H/.aitools/skills/w/mixed.txt"    # 120 KB, ASCII between
    perl -e 'print "a\303\251" x 40000, "\377\n"' > "$H/.aitools/skills/w/badtail.txt"  # the same, FF at the end
}
case_run utf8large seed_utf8large
for lang in $L; do
    for f in eacute mixed; do
        check "utf8 large $lang: $f.txt is text (review path), bytes identical" "logged 'Created: w/$f.txt ->' $lang && ! logged 'Created: w/$f.txt (binary)' $lang && cmp -s '$C/$lang/.aitools/skills/w/$f.txt' '$C/$lang/.claude/skills/w/$f.txt'"
    done
    check "utf8 large $lang: badtail.txt (invalid byte after 120 KB) is binary" "logged 'Created: w/badtail.txt (binary)' $lang && cmp -s '$C/$lang/.aitools/skills/w/badtail.txt' '$C/$lang/.claude/skills/w/badtail.txt'"
done
parity utf8large

# Names Claude Code owns (synced, anthropic-skills*): never written, never removed
seed_reserved() {
    manifest 'a|shared' 'anthropic-skills-old|retired'
    hskill a SKILL.md 'skill a'
    hskill synced SKILL.md 'not ours to write'
    hskill Anthropic-Skills-pack SKILL.md 'not ours either'
    hskill anthropic-skills-old.bak.2026-10-25T000000Z SKILL.md 'o'
    dskill synced keep.txt 'theirs'
    dskill anthropic-skills-old SKILL.md 'o'
}
case_run reserved seed_reserved
check "reserved: exit 1, row 2 failed, failed DETAIL rows" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|2 failed' ] && row 'DETAIL|claude skills|failed: synced' && row 'DETAIL|claude skills|failed: Anthropic-Skills-pack'"
check "reserved: nothing written into or removed from them" "[ ! -e '$(S)/synced/SKILL.md' ] && grep -qx theirs '$(S)/synced/keep.txt' && [ ! -e '$(S)/Anthropic-Skills-pack' ] && grep -qx o '$(S)/anthropic-skills-old/SKILL.md' && [ -f '$(S)/a/SKILL.md' ] && ! row 'DETAIL|claude skills|removed: anthropic-skills-old'"
parity reserved

if $CASE_SENSITIVE_FS; then
    seed_dupcase() { hskill a SKILL.md 'lower'; hskill A SKILL.md 'upper'; }
    case_run dupcase seed_dupcase
    check "case-only duplicate: the first wins, the second failed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ]"
    # No golden record: only a case-sensitive file system (Linux) builds this
    # fixture, so the Windows harness never runs it and the macOS run that writes
    # the golden files cannot produce one
else
    skip "case-only duplicate (case-insensitive file system)"
fi

seed_broken() { hskill a SKILL.md 'skill a'; ln -s "$H/nowhere" "$H/.aitools/skills/broken"; }
case_run broken seed_broken
check "dangling symlink: failed, others deployed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ] && [ -f '$(S)/a/SKILL.md' ] && row 'DETAIL|claude skills|failed: broken'"
parity broken

# ~/.claude/skills cannot be created (a file is in the way): ERROR row, exit 1,
# the script still reaches its exit footer
seed_nocreate() { hskill a SKILL.md 'skill a'; mkdir -p "$H/.claude"; printf 'not a dir\n' > "$H/.claude/skills"; }
case_run nocreate seed_nocreate
check "cannot create skills dir: ERROR row, exit 1, file untouched" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|cannot create skills dir' ] && grep -qx 'not a dir' '$C/$L/.claude/skills' && grep -q 'FAILED with' '$C/$L.out'"
parity nocreate
case_run nocreate-dry seed_nocreate --dry-run
check "cannot create skills dir, dry run: the same ERROR row as the real run" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|cannot create skills dir' ] && grep -qx 'not a dir' '$C/$L/.claude/skills'"
parity nocreate-dry

# ---------------------------------------------------------------------------
# The real deploy-harness (FO-2) fills ~/.aitools/skills from this checkout's
# shared/skills only (not .claude/skills, not the fixture dotprofile's
# claude/skills; commander 2026-11-06); the fan-out deploys every non-retired
# skill it lists
# ---------------------------------------------------------------------------
seed_real() {
    # deploy-harness.sh from this checkout, into $H
    run_env "$H" "$C/dh.summary" AITOOLS_LOG_DIR="$H/logs-dh"
    script_cmd "$ROOT/scripts" deploy-harness
    "${E[@]}" "${X[@]}" --skip-config --force < /dev/null > "$C/dh.out" 2>&1
    echo $? > "$C/dh.rc"
}
case_run real seed_real
check "real harness: deploy-harness wrote the skills manifest" "[ \"\$(cat '$C/dh.rc')\" = 0 ] && head -n 1 '$C/$L/.aitools/skills/.aitools-skills-manifest' | grep -qx '# aitools skills manifest v1' || { tail -n 20 '$C/dh.out'; false; }"
perl -ne 'next if $. == 1; s/\r?\n\z//; my ($n, $s) = split /\t/; print "$n\n" if $s ne "retired"' "$C/$L/.aitools/skills/.aitools-skills-manifest" > "$C/names"
check "real harness: every listed skill fanned out with its SKILL.md" "[ -s '$C/names' ] && ! while IFS= read -r n; do [ -f '$(S)/'\"\$n\"/SKILL.md ] || { echo \"missing: \$n\"; exit 0; }; done < '$C/names' | grep -q missing"
check "real harness: manifest lists shared skills only" \
    "perl -ne 'next if \$. == 1; \$bad = 1 unless /\\tshared\\r?\$/; END { exit(\$bad ? 1 : 0) }' '$C/$L/.aitools/skills/.aitools-skills-manifest'"
check "real harness: the dotprofile skill is neither listed nor deployed" "! grep -qx d1 '$C/names' && [ ! -e '$(S)/d1' ] && [ ! -e '$C/$L/.aitools/skills/d1' ]"
check "real harness: exit 0, OK row" "[ \"\$(rc)\" = 0 ] && nondetail | grep -qE '^OK\|claude skills\|[0-9]+ added$'"
# No golden record: the tree is this checkout's own skills (it changes with every
# skill edit); the checks above run on every platform
rerun
check "real harness rerun: verified" "nondetail | grep -qE '^OK\|claude skills\|[0-9]+ verified$'"

# ---------------------------------------------------------------------------
# Cursor (FO-5): setup-user-cursor step 5 runs the same fan-out into
# ~/.cursor/skills with tool "cursor skills" and no adopt target. The whole
# script runs, stub rg/agent on PATH so steps 1-2 find them installed and no
# installer runs.
# ---------------------------------------------------------------------------
cp "$ROOT/scripts/setup-user-cursor.sh" "$A/scripts/setup-user-cursor.sh"
cp "$ROOT/scripts/setup-user-cursor.ps1" "$A/scripts/setup-user-cursor.ps1"
CSTUB="$TMP_ROOT/cursor-stubs"
mkdir -p "$CSTUB"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$CSTUB/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$CSTUB/agent"
chmod +x "$CSTUB/rg" "$CSTUB/agent"

# run_cursor [FLAG]: setup-user-cursor under $C/$L, non-interactive
run_cursor() {
    local flag="${1:-}"
    run_env "$C/$L" "$C/$L.summary" PATH="$CSTUB:$PATH"
    script_cmd "$A/scripts" setup-user-cursor
    : > "$C/$L.summary"
    "${E[@]}" "${X[@]}" ${flag:+"$flag"} < /dev/null > "$C/$L.out" 2>&1
    echo $? > "$C/$L.rc"
}
# cursor_case NAME SEED_FN [FLAG]: as case_run, running setup-user-cursor
cursor_case() {
    C="$TMP_ROOT/$1"
    local seed="$2"
    mkdir -p "$C"
    H="$C/$L"
    seed_home "$H"
    "$seed"
    run_cursor "${3:-}"
}
cnondetail() { grep -F '|cursor skills|' "$C/${1:-$L}.summary" | grep -v '^DETAIL' | tail -n 1; }
CS() { printf '%s' "$C/${1:-$L}/.cursor/skills"; }
crows() { grep -E '^(ACTION\||[A-Z]+\|cursor skills\|)' "$1" | LC_ALL=C sort; }
# cparity CASE: the ~/.cursor/skills record of the case (see golden_record)
cparity() { golden_record "$1" "$(CS)" crows; }
cskill() {  # cskill NAME REL TEXT: ~/.cursor/skills/NAME/REL (already there)
    mkdir -p "$(dirname "$H/.cursor/skills/$1/$2")"; printf '%s\n' "$3" > "$H/.cursor/skills/$1/$2"
}

seed_cursor() {
    manifest 'd1|dotprofile' 'gone|retired' 'mine2|retired' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'
    hskill s1 scripts/run.sh '#!/bin/sh'; chmod 755 "$H/.aitools/skills/s1/scripts/run.sh"
    hskill p1 SKILL.md '## project p1'
    hskill d1 SKILL.md '## dot d1'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
    cskill gone SKILL.md 'gone'                      # the fan-out's copy of a retired skill
    cskill mine2 SKILL.md 'my own'                   # a user's skill at a retired name
    cskill mine SKILL.md 'mine'                      # a user's own skill
    mkdir -p "$H/.agents/skills/firecrawl"; printf 'fc\n' > "$H/.agents/skills/firecrawl/SKILL.md"
    ln -s ../../.agents/skills/firecrawl "$H/.cursor/skills/firecrawl"
}
cursor_case cursor seed_cursor
check "cursor: exit 0, row 4 added, 1 removed (WARN: a kept dir still loads)" "[ \"\$(rc)\" = 0 ] && [ \"\$(cnondetail)\" = 'WARN|cursor skills|4 added, 1 removed' ]"
check "cursor: shared, aitools, dotprofile skills in ~/.cursor/skills, x bit kept" "grep -qx '## shared s1' '$(CS)/s1/SKILL.md' && grep -qx '## project p1' '$(CS)/p1/SKILL.md' && grep -qx '## dot d1' '$(CS)/d1/SKILL.md' && [ -x '$(CS)/s1/scripts/run.sh' ]"
check "cursor: nothing written to ~/.claude/skills" "[ ! -e '$C/$L/.claude/skills' ]"
for lang in $L; do
    check "cursor $lang: adopt=none for every source" "logged 'cursor skills: s1/SKILL.md source=shared adopt=none' $lang && logged 'cursor skills: p1/SKILL.md source=aitools adopt=none' $lang && logged 'cursor skills: d1/SKILL.md source=dotprofile adopt=none' $lang"
done
check "cursor: retired copy removed, backed up beside ~/.cursor/skills" "[ ! -e '$(CS)/gone' ] && b=\$(ls -d '$C/$L/.cursor/'skills.bak.* | head -n 1) && grep -qx gone \"\$b/gone/SKILL.md\" && grep -qxF 'DETAIL|cursor skills|removed: gone' '$C/$L.summary'"
check "cursor: user skill at a retired name kept, ACTION row" "grep -qx 'my own' '$(CS)/mine2/SKILL.md' && grep -qxF 'ACTION||Cursor still loads retired skills in ~/.cursor/skills: mine2 -- delete them unless you wrote them' '$C/$L.summary'"
check "cursor: a user's own skill kept" "grep -qx mine '$(CS)/mine/SKILL.md' && grep -q 'Preserved unmanaged skill: mine' '$C/$L.out'"
check "cursor: firecrawl symlink preserved, never followed" "[ -L '$(CS)/firecrawl' ] && [ \"\$(readlink '$(CS)/firecrawl')\" = ../../.agents/skills/firecrawl ] && [ \"\$(ls '$C/$L/.agents/skills/firecrawl')\" = SKILL.md ]"
check "cursor: step 5 logged after step 4" "grep -q 'Step 5: Cursor user skills' '$C/$L.out'"
cparity cursor
run_cursor
check "cursor rerun: 4 verified (WARN: the kept dir)" "[ \"\$(cnondetail)\" = 'WARN|cursor skills|4 verified' ]"
cparity cursor-rerun

seed_cursor_none() { cskill mine SKILL.md 'mine'; }
cursor_case cursor-none seed_cursor_none
# No ~/.aitools/skills: the fan-out logs only and writes no row (FO-6's
# setup-user-skills owns the row then; contract change in #124 5267e9e)
check "cursor, no harness skills: no cursor skills row, logged, ~/.cursor/skills untouched" "[ \"\$(rc)\" = 0 ] && [ -z \"\$(cnondetail)\" ] && ! grep -qF '|cursor skills|' '$C/$L.summary' && grep -q 'No harness skills at .*setup-user-skills deploys skills' '$C/$L.out' && [ \"\$(ls '$(CS)')\" = mine ]"
cparity cursor-none

# Only retired names in both manifests, nothing in ~/.cursor: steps 4 and 5
# write the same row text (review 1 / audit B6)
seed_cursor_retired_only() {
    manifest 'gone|retired'
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v1\nx.md\tretired\n' > "$H/.aitools/rules/.aitools-rules-manifest"
}
cursor_case cursor-retired-only seed_cursor_retired_only
check "cursor, only retired names: both steps write n/a (nothing to deploy)" "[ \"\$(rc)\" = 0 ] && [ \"\$(cnondetail)\" = 'OK|cursor skills|n/a (nothing to deploy)' ] && [ \"\$(grep -F '|cursor rules|' '$C/$L.summary' | grep -v '^DETAIL' | tail -n 1)\" = 'OK|cursor rules|n/a (nothing to deploy)' ]"
cparity cursor-retired-only

printf '\n%d passed, %d failed, %d skipped (%s: %s scripts)\n' "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" sh
[ "$FAIL" -eq 0 ]
