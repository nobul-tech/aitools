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
# real deploy-harness.sh (FO-2 manifest) from this checkout.
#
# Safe to re-run: every case runs a copy of scripts/ in a temp aitools checkout,
# under its own temp HOME, with a temp git dotprofile (all removed on exit); the
# real HOME, ~/.aitools and dotprofile are never touched. With pwsh on PATH every
# case also runs setup-user-claude.ps1 (a copy with its Windows OS guard off) and
# compares its ~/.claude/skills tree and summary rows with the .sh run (parity).
# Platform: macOS, Linux (perl, git; pwsh and python3 optional: their cases are
# skipped). Exit 1 if any case fails. Spec: plans/skills-and-rules-fanout.md 3.4.
#
# Usage: bash tests/skills-fanout/test-skills-fanout.sh [--bash-only] [--help]
#   --bash-only  skip the PowerShell runs (parity cases are reported SKIP)
#   AITOOLS_TEST_BASH=/bin/bash runs the scripts under that bash (CI: macOS 3.2)

set -uo pipefail

BASH_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --help|-h) perl -ne 'print if $. >= 2 && $. <= 23' "$0"; exit 0 ;;
        --bash-only) BASH_ONLY=true ;;
        *) printf 'Unknown option: %s (see --help)\n' "$arg"; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
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
        if [ -n "$C" ] && [ -f "$C/sh.out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/sh.out" | tail -n 25
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }

for t in perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done
HAVE_PWSH=false
if ! $BASH_ONLY && command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi
HAVE_PTY=false
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi
CAN_CHMOD_READ=true   # chmod 000 blocks reads (not for root, not under Git Bash)
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CAN_CHMOD_READ=false ;; esac
if [ "$(id -u)" = 0 ]; then CAN_CHMOD_READ=false; fi
CAN_SYMLINK=true
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CAN_SYMLINK=false ;; esac
CASE_SENSITIVE_FS=false
: > "$TMP_ROOT/cs-probe"
if [ ! -e "$TMP_ROOT/CS-PROBE" ]; then CASE_SENSITIVE_FS=true; fi

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools checkout: a copy of scripts/ (adopt targets of shared and
# aitools skills land here, never in this repo) ---
A="$TMP_ROOT/aitools"
mkdir -p "$A/scripts" "$A/shared/skills/s1" "$A/shared/skills/dup" "$A/.claude/skills/p1" "$A/.claude/skills/dup"
for f in setup-user-claude.sh aitools-lib.sh aitools-lib.ps1 aitools-profile.sh aitools-profile.ps1 aitools-json.pl aitools-json.ps1; do
    cp "$ROOT/scripts/$f" "$A/scripts/$f"
done
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/setup-user-claude.ps1" > "$A/scripts/setup-user-claude.ps1"
cp "$ROOT/shared/claude-shared.md" "$A/shared/claude-shared.md"
printf '## shared s1\n' > "$A/shared/skills/s1/SKILL.md"
printf '## project p1\n' > "$A/.claude/skills/p1/SKILL.md"
printf '## dup shared\n' > "$A/shared/skills/dup/SKILL.md"
printf '## dup project\n' > "$A/.claude/skills/dup/SKILL.md"
# A package payload (git archive) has the same files but no .git: adopt into it
# is never offered. The fan-out counts only a git checkout.
PAYLOAD="$TMP_ROOT/payload"
mkdir -p "$PAYLOAD"
cp -R "$A/scripts" "$A/shared" "$A/.claude" "$PAYLOAD/"
git -C "$A" init -q
REPO="$A"   # the checkout run_one / run_pty run setup-user-claude from

# --- Fixture dotprofile (a git repo, no remote: an adopt commits, the push fails) ---
DP="$TMP_ROOT/aitools-tess"
mkdir -p "$DP/claude/skills/d1"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
printf '## dot d1\n' > "$DP/claude/skills/d1/SKILL.md"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

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

# run_one LANG [FLAG]: run setup-user-claude.<LANG> non-interactively under $C/<LANG>
run_one() {
    local lang="$1" flag="${2:-}" h="$C/$1"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1
        HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$C/$lang.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1)
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then
        "${e[@]}" "$TB" "$REPO/scripts/setup-user-claude.sh" ${flag:+"$flag"} < /dev/null > "$C/sh.out" 2>&1
    else
        "${e[@]}" pwsh -NoProfile -File "$REPO/scripts/setup-user-claude.ps1" ${flag:+"$flag"} < /dev/null > "$C/ps.out" 2>&1
    fi
    echo $? > "$C/$lang.rc"
}

# run_pty LANG INPUT: the same on a pty (review menu), keystrokes INPUT
run_pty() {
    local lang="$1" input="$2" h="$C/$1" cmd
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then cmd=("$TB" "$REPO/scripts/setup-user-claude.sh"); else cmd=(pwsh -NoProfile -File "$REPO/scripts/setup-user-claude.ps1"); fi
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
        HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$C/$lang.summary" \
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
        python3 "$PTY" --input "$input" --log "$C/$lang.out" -- "${cmd[@]}"
    echo $? > "$C/$lang.rc"
}

# case_run NAME SEED_FN [SH_FLAG PS_FLAG]: fresh HOMEs $C/sh and $C/ps (the
# latter only with pwsh), each with config.json -> the fixture dotprofile,
# seeded by SEED_FN, then one run per language
case_run() {
    C="$TMP_ROOT/$1"
    local seed="$2" shf="${3:-}" psf="${4:-}" lang
    mkdir -p "$C"
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        H="$C/$lang"
        mkdir -p "$H/.aitools"
        printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
        printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$H/.gitconfig"
        "$seed"
        if [ "$lang" = sh ]; then run_one sh "$shf"; else run_one ps "$psf"; fi
    done
}
rerun() {  # rerun [SH_FLAG PS_FLAG]: run again in the same HOMEs
    run_one sh "${1:-}"
    if [ "$HAVE_PWSH" = "true" ]; then run_one ps "${2:-}"; fi
}
both() {  # both CMD...: run CMD with H set to each language's HOME
    local lang
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        H="$C/$lang"; "$@"
    done
}

rc() { cat "$C/${1:-sh}.rc"; }
row() { grep -qxF "$1" "$C/${2:-sh}.summary"; }                  # exact summary row
nondetail() { grep -F '|claude skills|' "$C/${1:-sh}.summary" | grep -v '^DETAIL' | tail -n 1; }
S() { printf '%s' "$C/${1:-sh}/.claude/skills"; }                 # the deployed skills dir
logged() { cat "$C/${2:-sh}/logs/"*.log 2>/dev/null | grep -qF "$1"; }  # in the run's log files (none: no match)
logged_re() { cat "$C/${2:-sh}/logs/"*.log 2>/dev/null | grep -qE "$1"; }  # the same, an extended regex
bakdirs() { ls "$C/${1:-sh}/.claude" | grep -c '^skills\.bak\.'; }  # backup dirs beside ~/.claude/skills

# tree_sig DIR: "<path> <md5> [x]" per file (x: executable), "<path> -> <target>"
# per symlink (not followed), backup time stamps normalized
tree_sig() {
    perl -MDigest::MD5=md5_hex -MFile::Find -e '
        my $root = shift; my @out;
        exit 0 unless -d $root;
        find({ no_chdir => 1, wanted => sub {
            (my $rel = substr($_, length($root) + 1)) =~ s/\.bak\.[0-9TZ-]+\z/.bak.TS/;
            return if $rel eq "";
            if (-l $_) { push @out, "$rel -> " . readlink($_); $File::Find::prune = 1; return }
            return unless -f $_;
            open my $fh, "<:raw", $_ or die "cannot read $_: $!\n";
            local $/; my $c = <$fh>; close $fh;
            push @out, "$rel " . md5_hex(defined $c ? $c : "") . (-x $_ ? " x" : "");
        } }, $root);
        print "$_\n" for sort @out;
    ' "$1"
}
rows() { grep -E '^(ACTION\||[A-Z]+\|claude skills\|)' "$1" | LC_ALL=C sort; }

# parity CASE: the .ps1 run of the case gave the .sh run's exit code, tree and rows
parity() {
    if [ "$HAVE_PWSH" != "true" ]; then skip "parity ps1: $1 (pwsh not on PATH or --bash-only)"; return; fi
    tree_sig "$(S sh)" | perl -pe "s{\Q$C/sh\E}{HOME}g" > "$C/tree-sh"
    tree_sig "$(S ps)" | perl -pe "s{\Q$C/ps\E}{HOME}g" > "$C/tree-ps"
    rows "$C/sh.summary" > "$C/rows-sh"; rows "$C/ps.summary" > "$C/rows-ps"
    check "parity ps1: $1: exit code" "[ \"\$(rc ps)\" = \"\$(rc sh)\" ] || { tail -n 20 '$C/ps.out'; false; }"
    check "parity ps1: $1: ~/.claude/skills" "cmp -s '$C/tree-sh' '$C/tree-ps' || { diff '$C/tree-sh' '$C/tree-ps'; false; }"
    check "parity ps1: $1: summary rows" "cmp -s '$C/rows-sh' '$C/rows-ps' || { diff '$C/rows-sh' '$C/rows-ps'; false; }"
}

# ---------------------------------------------------------------------------
# No harness skills: nothing deployed, ~/.claude/skills untouched, exit 0
# ---------------------------------------------------------------------------
seed_missing() { dskill mine SKILL.md 'mine'; }
case_run missing seed_missing
check "missing: exit 0, row n/a (no harness skills)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|n/a (no harness skills)' ]"
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
    if $CAN_SYMLINK; then
        mkdir -p "$H/.agents/skills/firecrawl"; printf 'fc\n' > "$H/.agents/skills/firecrawl/SKILL.md"
        ln -s ../../.agents/skills/firecrawl "$H/.claude/skills/firecrawl"
    fi
}
case_run fanout seed_fanout
check "fanout: exit 0, row 6 added" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|6 added' ]"
check "fanout: shared, aitools, dotprofile skills deployed" "grep -qx '## shared s1' '$(S)/s1/SKILL.md' && grep -qx '## project p1' '$(S)/p1/SKILL.md' && grep -qx '## dot d1' '$(S)/d1/SKILL.md' && grep -qx '## dup shared' '$(S)/dup/SKILL.md'"
check "fanout: nested files deployed" "grep -qx nested '$(S)/s1/tests/expected-behaviors.md' && [ -f '$(S)/s1/scripts/run.sh' ]"
check "fanout: executable bit copied" "[ -x '$(S)/s1/scripts/run.sh' ] && [ ! -x '$(S)/s1/SKILL.md' ]"
check "fanout: *.bak.* (any case), hidden, backup dirs and top-level files skipped" "[ ! -e '$(S)/s1/SKILL.md.bak.2026-10-22T010203Z' ] && [ ! -e '$(S)/s1/tests/X.BAK.1' ] && [ ! -e '$(S)/old.bak.2026-10-25T000000Z' ] && [ ! -e '$(S)/.hidden' ] && [ ! -e '$(S)/notes.txt' ]"
check "fanout: top-level file logged, manifest silent" "grep -q 'Ignoring non-skill file in harness skills: notes.txt' '$C/sh.out' && ! grep -q 'aitools-skills-manifest' '$C/sh.out'"
check "fanout: third-party skill preserved" "grep -qx mine '$(S)/mine/SKILL.md' && grep -q 'Preserved unmanaged skill: mine' '$C/sh.out'"
if $CAN_SYMLINK; then
    check "fanout: firecrawl symlink preserved, never followed" "[ -L '$(S)/firecrawl' ] && [ \"\$(readlink '$(S)/firecrawl')\" = ../../.agents/skills/firecrawl ] && grep -qx fc '$C/sh/.agents/skills/firecrawl/SKILL.md' && [ \"\$(ls '$C/sh/.agents/skills/firecrawl')\" = SKILL.md ] && grep -q 'Preserved unmanaged skill: firecrawl' '$C/sh.out'"
fi
check "fanout: one item per file in DETAIL rows" "row 'DETAIL|claude skills|added: s1/SKILL.md' && row 'DETAIL|claude skills|added: s1/scripts/run.sh' && row 'DETAIL|claude skills|added: s1/tests/expected-behaviors.md'"
for lang in sh ps; do
    if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
    check "adopt map $lang: shared -> aitools shared/skills" "logged 'claude skills: s1/SKILL.md source=shared adopt=' $lang && logged '/shared/skills/s1/SKILL.md' $lang"
    check "adopt map $lang: aitools -> aitools .claude/skills" "logged 'claude skills: p1/SKILL.md source=aitools adopt=' $lang && logged '/.claude/skills/p1/SKILL.md' $lang"
    check "adopt map $lang: dotprofile -> dotprofile claude/skills" "logged 'claude skills: d1/SKILL.md source=dotprofile adopt=$DP/claude/skills/d1/SKILL.md' $lang"
    check "adopt map $lang: same name in shared and .claude, manifest shared -> shared" "logged_re 'claude skills: dup/SKILL\.md source=shared adopt=.*/aitools/shared/skills/dup/SKILL\.md\$' $lang"
    check "adopt map $lang: no repo file -> none" "logged 'claude skills: s1/tests/expected-behaviors.md source=shared adopt=none' $lang"
done
parity fanout
rerun
check "fanout rerun: row 6 verified, nothing written" "[ \"\$(nondetail)\" = 'OK|claude skills|6 verified' ] && [ -z \"\$(find '$(S)' -name '*.bak.*')\" ] && [ \"\$(bakdirs)\" = 0 ]"
parity fanout-rerun
printf '## shared s1\nlocal edit\n' > "$(S sh)/s1/SKILL.md"
if [ "$HAVE_PWSH" = "true" ]; then printf '## shared s1\nlocal edit\n' > "$(S ps)/s1/SKILL.md"; fi
rerun
check "fanout edited, non-interactive: overwritten, backup kept, WARN row" "[ \"\$(nondetail)\" = 'WARN|claude skills|1 updated, 5 verified' ] && grep -qx '## shared s1' '$(S)/s1/SKILL.md' && ls '$(S)/s1' | grep -q '^SKILL\.md\.bak\.'"
parity fanout-edited
printf '## shared s1\nlocal edit 2\n' > "$(S sh)/s1/SKILL.md"
if [ "$HAVE_PWSH" = "true" ]; then printf '## shared s1\nlocal edit 2\n' > "$(S ps)/s1/SKILL.md"; fi
rerun --force -Force
check "fanout --force: overwritten" "[ \"\$(rc)\" = 0 ] && grep -qx '## shared s1' '$(S)/s1/SKILL.md' && [ \"\$(nondetail)\" = 'WARN|claude skills|1 updated, 5 verified' ]"
parity fanout-force
chmod 644 "$(S sh)/s1/scripts/run.sh"
if [ "$HAVE_PWSH" = "true" ]; then chmod 644 "$(S ps)/s1/scripts/run.sh"; fi
rerun
check "fanout: executable bit restored on a verified file" "[ -x '$(S)/s1/scripts/run.sh' ] && [ \"\$(nondetail)\" = 'OK|claude skills|6 verified' ]"
parity fanout-xbit

case_run fanout-dry seed_fanout --dry-run -DryRun
check "fanout dry run: nothing written, row dry run" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|dry run (no files written)' ] && [ ! -e '$(S)/s1' ] && grep -q 'DRY RUN\] Would create: s1/SKILL.md' '$C/sh.out'"
parity fanout-dry

# A skill name in DEST that is a symlink or a file: never written, WARN + ACTION
seed_kept() {
    manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
    mkdir -p "$H/.claude/skills" "$H/elsewhere/s1"; printf 'theirs\n' > "$H/elsewhere/s1/SKILL.md"
    ln -s ../../elsewhere/s1 "$H/.claude/skills/s1"
    printf 'a file\n' > "$H/.claude/skills/p1"
}
if $CAN_SYMLINK; then
    case_run kept seed_kept
    check "kept: exit 0, row 1 added (WARN)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added' ]"
    check "kept: symlink and file untouched" "[ -L '$(S)/s1' ] && grep -qx theirs '$C/sh/elsewhere/s1/SKILL.md' && [ \"\$(ls '$C/sh/elsewhere/s1')\" = SKILL.md ] && grep -qx 'a file' '$(S)/p1'"
    check "kept: ACTION row names both" "row 'ACTION||Claude Code skills in ~/.claude/skills not updated (a symlink or a file, not a directory the fan-out owns): p1, s1 -- move them aside to get the aitools copy'"
    parity kept
else
    skip "kept symlink (no symlinks)"
fi

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
    dskill old SKILL.md 'old'
    dskill mine2 SKILL.md 'my own'
    dskill '[r]' SKILL.md 'r'
}
case_run retired seed_retired
check "retired: exit 0, row 1 added, 3 removed (WARN: a kept dir still loads)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|1 added, 3 removed' ]"
check "retired: copies removed from ~/.claude/skills" "[ ! -e '$(S)/gone' ] && [ ! -e '$(S)/old' ] && [ ! -e '$(S)/[r]' ]"
check "retired: one backup dir beside ~/.claude/skills holds them" "[ \"\$(bakdirs)\" = 1 ] && b=\$(ls -d '$C/sh/.claude/'skills.bak.*) && grep -qx gone \"\$b/gone/SKILL.md\" && grep -qx gx \"\$b/gone/tests/x.md\" && grep -qx old \"\$b/old/SKILL.md\" && grep -qx r \"\$b/[r]/SKILL.md\""
check "retired: removals in DETAIL rows" "row 'DETAIL|claude skills|removed: gone' && row 'DETAIL|claude skills|removed: old' && row 'DETAIL|claude skills|removed: [r]'"
check "retired: a retired skill still in ~/.aitools/skills is not fanned out" "grep -q 'Not fanned out: old (retired in the skills manifest)' '$C/sh.out' && ! row 'DETAIL|claude skills|added: old/SKILL.md'"
check "retired: user dir with a retired name kept, ACTION row" "grep -qx 'my own' '$(S)/mine2/SKILL.md' && row 'ACTION||Claude Code still loads retired skills in ~/.claude/skills: mine2 -- delete them unless you wrote them'"
parity retired
case_run retired-dry seed_retired --dry-run -DryRun
check "retired dry run: nothing removed, row dry run, removal previewed" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|dry run (no files written)' ] && [ -d '$(S)/gone' ] && [ -d '$(S)/old' ] && [ ! -e '$(S)/a' ] && [ \"\$(bakdirs)\" = 0 ] && grep -q 'DRY RUN\] Would back up and remove gone' '$C/sh.out'"
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
parity retired-mod

# ---------------------------------------------------------------------------
# Manifest absent, bad header, invalid lines, unreadable
# ---------------------------------------------------------------------------
seed_nomanifest() { hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b'; }
case_run nomanifest seed_nomanifest
check "no manifest: everything fanned out, adopt not offered" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude skills|2 added' ] && grep -q 'No skills manifest' '$C/sh.out' && logged 'claude skills: a/SKILL.md source=unknown adopt=none'"
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
check "invalid lines: warned, skills still fanned out" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude skills|2 added' ] && grep -q 'line ignored: .dot<TAB>shared' '$C/sh.out' && logged 'claude skills: a/SKILL.md source=unknown adopt=none'"
parity invalid

if $CAN_CHMOD_READ; then
    seed_unreadable() { hskill a SKILL.md 'skill a'; chmod 000 "$H/.aitools/skills"; }
    case_run unreadable seed_unreadable
    check "unreadable harness dir: ERROR row, exit 1" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|cannot read harness skills' ]"
    parity unreadable
    chmod 755 "$C/sh/.aitools/skills"
    if [ -d "$C/ps/.aitools/skills" ]; then chmod 755 "$C/ps/.aitools/skills"; fi

    seed_manifest_unreadable() { manifest 'a|shared'; hskill a SKILL.md 'skill a'; chmod 000 "$H/.aitools/skills/.aitools-skills-manifest"; }
    case_run manifest-unreadable seed_manifest_unreadable
    check "unreadable manifest: skills fanned out, ERROR rows, final row ERROR, exit 1" "[ \"\$(rc)\" = 1 ] && [ -f '$(S)/a/SKILL.md' ] && row 'ERROR|claude skills|cannot read skills manifest' && row 'DETAIL|claude skills|failed: .aitools-skills-manifest' && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ]"
    parity manifest-unreadable
else
    skip "unreadable harness dir and manifest (root or Git Bash)"
fi

# ---------------------------------------------------------------------------
# Adopt (pty) and abort (pty); package payload (no .git)
# ---------------------------------------------------------------------------
if $HAVE_PTY; then
    C="$TMP_ROOT/fanout"
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        printf '## dot d1\nmy edit %s\n' "$lang" > "$C/$lang/.claude/skills/d1/SKILL.md"
        printf '## project p1\nmy edit %s\n' "$lang" > "$C/$lang/.claude/skills/p1/SKILL.md"
        run_pty "$lang" 'a\na\n'
        check "adopt $lang: dotprofile skill written to the dotprofile and committed" "grep -qx 'my edit $lang' '$DP/claude/skills/d1/SKILL.md' && git -C '$DP' log -1 --name-only --format= | grep -qx 'claude/skills/d1/SKILL.md' && git -C '$DP' diff --quiet -- claude/skills/d1/SKILL.md"
        check "adopt $lang: aitools skill written to the aitools working tree" "grep -qx 'my edit $lang' '$A/.claude/skills/p1/SKILL.md'"
        check "adopt $lang: DETAIL rows" "row 'DETAIL|claude skills|accept & adopt: d1/SKILL.md' $lang && row 'DETAIL|claude skills|accept & adopt: p1/SKILL.md' $lang"
        # abort: exit 2 from the library, no claude skills row, the local file kept
        printf '## shared s1\nlocal %s\n' "$lang" > "$C/$lang/.claude/skills/s1/SKILL.md"
        run_pty "$lang" 'x\n'
        check "abort $lang: exit 2, no claude skills row, local file kept" "[ \"\$(rc $lang)\" = 2 ] && [ -z \"\$(nondetail $lang)\" ] && grep -qx 'local $lang' '$C/$lang/.claude/skills/s1/SKILL.md'"
    done
else
    skip "adopt and abort on a pty (python3 not found)"
fi
printf '## project p1\n' > "$A/.claude/skills/p1/SKILL.md"

seed_payload() {
    manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
}
REPO="$PAYLOAD"
case_run payload seed_payload
REPO="$A"
for lang in sh ps; do
    if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
    check "payload $lang: no adopt into a checkout without .git" "logged 'claude skills: s1/SKILL.md source=shared adopt=none' $lang && logged 'claude skills: p1/SKILL.md source=aitools adopt=none' $lang && logged 'claude skills: d1/SKILL.md source=dotprofile adopt=$DP/claude/skills/d1/SKILL.md' $lang"
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

if $CASE_SENSITIVE_FS; then
    seed_dupcase() { hskill a SKILL.md 'lower'; hskill A SKILL.md 'upper'; }
    case_run dupcase seed_dupcase
    check "case-only duplicate: the first wins, the second failed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ]"
    parity dupcase
else
    skip "case-only duplicate (case-insensitive file system)"
fi

if $CAN_SYMLINK; then
    seed_broken() { hskill a SKILL.md 'skill a'; ln -s "$H/nowhere" "$H/.aitools/skills/broken"; }
    case_run broken seed_broken
    check "dangling symlink: failed, others deployed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|1 failed' ] && [ -f '$(S)/a/SKILL.md' ] && row 'DETAIL|claude skills|failed: broken'"
    parity broken
else
    skip "dangling symlink (no symlinks)"
fi

# ~/.claude/skills cannot be created (a file is in the way): ERROR row, exit 1,
# the script still reaches its exit footer
seed_nocreate() { hskill a SKILL.md 'skill a'; mkdir -p "$H/.claude"; printf 'not a dir\n' > "$H/.claude/skills"; }
case_run nocreate seed_nocreate
check "cannot create skills dir: ERROR row, exit 1, file untouched" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude skills|cannot create skills dir' ] && grep -qx 'not a dir' '$C/sh/.claude/skills' && grep -q 'FAILED with' '$C/sh.out'"
parity nocreate

# ---------------------------------------------------------------------------
# The real deploy-harness (FO-2) fills ~/.aitools/skills from this checkout and
# the fixture dotprofile; the fan-out deploys every non-retired skill it lists
# ---------------------------------------------------------------------------
seed_real() {
    if [ "$H" = "$C/sh" ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$H" USERPROFILE="$H" AITOOLS_LOG_DIR="$H/logs-dh" \
            AITOOLS_SUMMARY_FILE="$C/dh.summary" GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
            "$TB" "$ROOT/scripts/deploy-harness.sh" --skip-config --force < /dev/null > "$C/dh.out" 2>&1
        echo $? > "$C/dh.rc"
    else
        cp -R "$C/sh/.aitools/skills" "$H/.aitools/skills"
    fi
}
case_run real seed_real
check "real harness: deploy-harness wrote the skills manifest" "[ \"\$(cat '$C/dh.rc')\" = 0 ] && head -n 1 '$C/sh/.aitools/skills/.aitools-skills-manifest' | grep -qx '# aitools skills manifest v1' || { tail -n 20 '$C/dh.out'; false; }"
perl -ne 'next if $. == 1; chomp; my ($n, $s) = split /\t/; print "$n\n" if $s ne "retired"' "$C/sh/.aitools/skills/.aitools-skills-manifest" > "$C/names"
check "real harness: every listed skill fanned out with its SKILL.md" "[ -s '$C/names' ] && grep -qx d1 '$C/names' && ! while IFS= read -r n; do [ -f '$(S)/'\"\$n\"/SKILL.md ] || { echo \"missing: \$n\"; exit 0; }; done < '$C/names' | grep -q missing"
check "real harness: exit 0, OK row" "[ \"\$(rc)\" = 0 ] && nondetail | grep -qE '^OK\|claude skills\|[0-9]+ added$'"
for lang in sh ps; do
    if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
    check "real harness $lang: dotprofile skill adopt target is the dotprofile" "logged 'claude skills: d1/SKILL.md source=dotprofile adopt=$DP/claude/skills/d1/SKILL.md' $lang"
done
parity real
rerun
check "real harness rerun: verified" "nondetail | grep -qE '^OK\|claude skills\|[0-9]+ verified$'"
parity real-rerun

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
