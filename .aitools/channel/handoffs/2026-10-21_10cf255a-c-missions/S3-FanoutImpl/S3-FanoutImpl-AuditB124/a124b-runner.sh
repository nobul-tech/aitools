#!/usr/bin/env bash
# a124b-runner.sh -- runtime logging audit of the skills fan-out in
# setup-user-claude.sh/.ps1 (PR #124, FO-4). For each case: a fresh isolated
# HOME per language under $OUT/<case>/<lang>, seeded by seed_<case>; optional
# prerun_<case>=1 (one uncaptured run first) and mid_<case> (a function run
# between the prerun and the captured run); then one captured run of the .sh
# and of the .ps1 (a scratch copy with its Windows OS guard patched off), from
# a temp git-init'ed aitools checkout, non-interactive (stdin /dev/null).
# Captured per run: <lang>.rc, <lang>.out (console), <lang>.summary (rows),
# <lang>.deploy.log (HOME/.aitools/logs/deploy.log; AITOOLS_LOG_DIR unset).
# Never touches the real HOME: HOME and USERPROFILE point into $OUT, git global
# config is a file in the case HOME, AITOOLS_* overrides are unset.
# Adapted from S3-FanoutImpl-AuditB121/a121b-runner.sh.
# Usage: bash a124b-runner.sh WORKTREE OUTDIR [case...]
set -uo pipefail

WT="${1:?usage: a124b-runner.sh WORKTREE OUTDIR [case...]}"
OUT="${2:?usage: a124b-runner.sh WORKTREE OUTDIR [case...]}"
shift 2
REAL_HOME=/Users/new-jose
case "$OUT" in "$REAL_HOME/.claude"*|"$REAL_HOME/.aitools"*) echo "refusing OUT under the real HOME config dirs"; exit 1 ;; esac
case "$OUT" in /*) ;; *) echo "OUT must be absolute"; exit 1 ;; esac
mkdir -p "$OUT"

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools checkout (adopt targets never land in the worktree) ---
A="$OUT/aitools"
if [ -d "$A" ]; then rm -rf "$A"; fi
mkdir -p "$A/scripts" "$A/shared/skills/s1" "$A/.claude/skills/p1"
for f in setup-user-claude.sh aitools-lib.sh aitools-lib.ps1 aitools-profile.sh aitools-profile.ps1 aitools-json.pl aitools-json.ps1; do
    cp "$WT/scripts/$f" "$A/scripts/$f"
done
# OS guard patched in the scratch copy only (never in the worktree file)
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$WT/scripts/setup-user-claude.ps1" > "$A/scripts/setup-user-claude.ps1"
if cmp -s "$WT/scripts/setup-user-claude.ps1" "$A/scripts/setup-user-claude.ps1"; then echo "guard patch did not apply"; exit 1; fi
cp "$WT/shared/claude-shared.md" "$A/shared/claude-shared.md"
printf '## shared s1\n' > "$A/shared/skills/s1/SKILL.md"
printf '## project p1\n' > "$A/.claude/skills/p1/SKILL.md"
git -C "$A" init -q

# --- Fixture dotprofile ---
DP="$OUT/aitools-tess"
if [ -d "$DP" ]; then rm -rf "$DP"; fi
mkdir -p "$DP/claude/skills/d1"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
printf '## dot d1\n' > "$DP/claude/skills/d1/SKILL.md"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

# --- Seed helpers ($H = HOME being seeded) ---
hskill() { mkdir -p "$(dirname "$H/.aitools/skills/$1/$2")"; printf '%s\n' "$3" > "$H/.aitools/skills/$1/$2"; }
dskill() { mkdir -p "$(dirname "$H/.claude/skills/$1/$2")"; printf '%s\n' "$3" > "$H/.claude/skills/$1/$2"; }
manifest() {
    mkdir -p "$H/.aitools/skills"
    { printf '# aitools skills manifest v1\n'; for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done; } > "$H/.aitools/skills/.aitools-skills-manifest"
}
std_skills() {
    manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
    hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
}

# --- Cases ---
seed_clean() {
    std_skills
    hskill s1 tests/expected.md 'nested'
    hskill s1 scripts/run.sh '#!/bin/sh'; chmod 755 "$H/.aitools/skills/s1/scripts/run.sh"
    hskill s1 SKILL.md.bak.2026-10-22T010203Z 'old s1'
    hskill old.bak.2026-10-25T000000Z SKILL.md 'a deploy-harness backup'
    hskill .hidden SKILL.md 'hidden'
    printf 'not a skill\n' > "$H/.aitools/skills/notes.txt"
    dskill mine SKILL.md 'mine'
    mkdir -p "$H/.agents/skills/firecrawl"; printf 'fc\n' > "$H/.agents/skills/firecrawl/SKILL.md"
    ln -s ../../.agents/skills/firecrawl "$H/.claude/skills/firecrawl"
}
seed_verified()   { seed_clean; }
prerun_verified=1
seed_missing()    { dskill mine SKILL.md 'mine'; }
seed_empty()      { mkdir -p "$H/.aitools/skills"; }
seed_unreaddir()  { std_skills; chmod 000 "$H/.aitools/skills"; }
seed_unreadx()    { std_skills; chmod 444 "$H/.aitools/skills"; }      # readable, not searchable
seed_mfunread()   { std_skills; chmod 000 "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_mfunreadonly() { manifest 'a|shared'; chmod 000 "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_mfdangling() { hskill a SKILL.md 'skill a'; ln -s "$H/nowhere-manifest" "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_mfdir()      { hskill a SKILL.md 'skill a'; mkdir -p "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_mfempty()    { hskill a SKILL.md 'skill a'; : > "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_badheader()  {
    mkdir -p "$H/.aitools/skills"
    printf '# aitools skills manifest v2\nx\tretired\n' > "$H/.aitools/skills/.aitools-skills-manifest"
    hskill a SKILL.md 'skill a'; hskill x.bak.2026-10-25T000000Z SKILL.md 'x'; dskill x SKILL.md 'x'
}
seed_invalid()    { manifest '.dot|shared' 'a|unknown' 'b|shared' 'B|aitools'; hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b'; }
seed_srclink()    { std_skills; ln -s "$H/nowhere" "$H/.aitools/skills/broken"; }
seed_srcinner()   { std_skills; ln -s "$H/nowhere.md" "$H/.aitools/skills/s1/dangling.md"; }   # dangling file link inside a skill
seed_destlink()   {
    std_skills; mkdir -p "$H/.claude/skills"
    ln -s "$H/nowhere1" "$H/.claude/skills/s1"          # dangling, at a skill name
    ln -s "$H/nowhere2" "$H/.claude/skills/stale"       # dangling, unmanaged name
}
seed_destkept()   {
    std_skills; mkdir -p "$H/.claude/skills" "$H/elsewhere/s1"; printf 'theirs\n' > "$H/elsewhere/s1/SKILL.md"
    ln -s ../../elsewhere/s1 "$H/.claude/skills/s1"     # symlink to a dir, at a skill name
    printf 'a file\n' > "$H/.claude/skills/p1"          # plain file, at a skill name
}
seed_nocreate()   { std_skills; mkdir -p "$H/.claude"; printf 'not a dir\n' > "$H/.claude/skills"; }
seed_nocreatedry() { seed_nocreate; }
flags_nocreatedry="--dry-run -DryRun"
seed_noclaude()   { std_skills; }                       # no ~/.claude at all
seed_retired()    {
    manifest 'a|shared' 'gone|retired' 'mine2|retired' 'old|retired'
    hskill a SKILL.md 'skill a'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
    hskill old SKILL.md 'old'
    dskill gone SKILL.md 'gone'; dskill old SKILL.md 'old'; dskill mine2 SKILL.md 'my own'
}
seed_retireddry() { seed_retired; }
flags_retireddry="--dry-run -DryRun"
seed_retonly()    { manifest 'gone|retired'; hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'; dskill gone SKILL.md 'user edit'; }
seed_retonlyrm()  { manifest 'gone|retired'; hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'; dskill gone SKILL.md 'gone'; }
# backup failure: prerun deploys everything, then the retired copy is added and
# ~/.claude made read-only, so DEST.bak.<UTC> cannot be created beside DEST
seed_bakfail()    { manifest 'a|shared'; hskill a SKILL.md 'skill a'; }
prerun_bakfail=1
mid_bakfail()     {
    manifest 'a|shared' 'gone|retired'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
    dskill gone SKILL.md 'gone'
    chmod 555 "$H/.claude"
}
# remove failure: the retired copy holds a read-only subdirectory
seed_rmfail()     { manifest 'a|shared'; hskill a SKILL.md 'skill a'; }
prerun_rmfail=1
mid_rmfail()      {
    manifest 'a|shared' 'gone|retired'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'; hskill gone.bak.2026-10-25T000000Z sub/x.md 'x'
    dskill gone SKILL.md 'gone'; dskill gone sub/x.md 'x'
    chmod 555 "$H/.claude/skills/gone/sub"
}
seed_srcunread()  { std_skills; chmod 000 "$H/.aitools/skills/p1/SKILL.md"; }
seed_subunread()  { std_skills; hskill p1 sub/x.md 'x'; chmod 000 "$H/.aitools/skills/p1/sub"; }
seed_destro()     { std_skills; dskill p1 SKILL.md 'local edit'; chmod 555 "$H/.claude/skills/p1"; }
seed_dry()        { seed_clean; }
flags_dry="--dry-run -DryRun"
seed_envdry()     { seed_clean; }
env_envdry="AITOOLS_DRY_RUN=1"
seed_edited()     { std_skills; dskill s1 SKILL.md '## shared s1'; dskill p1 SKILL.md 'local edit'; dskill d1 SKILL.md '## dot d1'; }
seed_force()      { seed_edited; }
flags_force="--force -Force"
seed_xbit()       { std_skills; dskill s1 SKILL.md '## shared s1'; chmod 755 "$H/.claude/skills/s1/SKILL.md"; }
# DEST writable and searchable but not listable: the retired and preserved scans fail
seed_destunlist() {
    manifest 'a|shared' 'gone|retired'; hskill a SKILL.md 'skill a'
    hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'; dskill gone SKILL.md 'gone'; dskill mine SKILL.md 'mine'
    chmod 300 "$H/.claude/skills"
}
# case-only duplicates: only meaningful on a case-sensitive volume (OUT there)
seed_dupcase()    { manifest 'a|shared'; hskill a SKILL.md 'lower'; hskill A SKILL.md 'upper'; }
seed_bracket()    { manifest '[x]|shared'; hskill '[x]' SKILL.md 'bracket'; hskill '[x]' 'a*b?.md' 'glob chars'; }

ALL_CASES="clean verified missing empty unreaddir unreadx mfunread mfunreadonly mfdangling mfdir mfempty badheader invalid srclink srcinner destlink destkept nocreate nocreatedry noclaude retired retireddry retonly retonlyrm bakfail rmfail srcunread subunread destro dry envdry edited force xbit bracket"
CASES="${*:-$ALL_CASES}"

run_lang() {  # case lang flag extra_env capture(1|0)
    local cs="$1" lang="$2" flag="$3" extra="$4" cap="$5" h="$OUT/$1/$2" C="$OUT/$1"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 -u AITOOLS_LOG_DIR -u AITOOLS_ENVIRONMENT
        HOME="$h" USERPROFILE="$h" AITOOLS_SUMMARY_FILE="$C/$lang.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1)
    if [ -n "$extra" ] && [ "$cap" = 1 ]; then e+=("$extra"); fi
    : > "$C/$lang.summary"
    local fl=""; if [ "$cap" = 1 ]; then fl="$flag"; fi
    if [ "$lang" = sh ]; then
        "${e[@]}" "${RUN_BASH:-bash}" "$A/scripts/setup-user-claude.sh" ${fl:+"$fl"} < /dev/null > "$C/sh.out" 2> "$C/sh.err"
    else
        "${e[@]}" pwsh -NoProfile -File "$A/scripts/setup-user-claude.ps1" ${fl:+"$fl"} < /dev/null > "$C/ps.out" 2> "$C/ps.err"
    fi
    echo $? > "$C/$lang.rc"
    # only the captured run's log lines: truncate the log after a prerun
    if [ "$cap" = 0 ]; then
        if [ -f "$h/.aitools/logs/deploy.log" ]; then : > "$h/.aitools/logs/deploy.log"; fi
        return
    fi
    if [ -f "$h/.aitools/logs/deploy.log" ]; then cp "$h/.aitools/logs/deploy.log" "$C/$lang.deploy.log"; else : > "$C/$lang.deploy.log"; fi
    # tree of ~/.claude/skills* with modes, before the runner restores permissions
    perl -e 'use File::Find; my $r = shift; my @o;
        find({ no_chdir => 1, wanted => sub { my @s = lstat $_; return unless @s;
            (my $rel = substr($_, length($r))) =~ s/\.bak\.[0-9TZ-]+/.bak.TS/g;
            push @o, sprintf("%04o %s%s", $s[2] & 07777, $rel, -l $_ ? " -> " . readlink($_) : "") } }, grep { -e $_ || -l $_ } glob("$r/.claude/skills*"));
        print "$_\n" for sort @o;' "$h" > "$C/$lang.tree"
}

for cs in $CASES; do
    C="$OUT/$cs"
    if [ -d "$C" ]; then chmod -R u+rwx "$C"; rm -rf "$C"; fi
    mkdir -p "$C"
    fl_var="flags_$cs"; fl="${!fl_var:-}"
    env_var="env_$cs"; ex="${!env_var:-}"
    pre_var="prerun_$cs"; pre="${!pre_var:-0}"
    shf="${fl%% *}"; psf="${fl##* }"
    for lang in sh ps; do
        H="$C/$lang"
        mkdir -p "$H/.aitools"
        printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
        printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$H/.gitconfig"
        "seed_$cs"
        if [ "$pre" = 1 ]; then
            run_lang "$cs" "$lang" "" "" 0
            if declare -F "mid_$cs" > /dev/null; then "mid_$cs"; fi
        fi
        if [ "$lang" = sh ]; then run_lang "$cs" sh "$shf" "$ex" 1; else run_lang "$cs" ps "$psf" "$ex" 1; fi
    done
    # restore permissions so the outputs can be read and removed
    chmod -R u+rwx "$C"
    printf '%-14s sh=%s ps=%s\n' "$cs" "$(cat "$C/sh.rc")" "$(cat "$C/ps.rc")"
done
