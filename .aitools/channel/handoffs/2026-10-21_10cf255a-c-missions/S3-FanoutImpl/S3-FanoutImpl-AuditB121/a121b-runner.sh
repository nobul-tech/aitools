#!/usr/bin/env bash
# a121b-runner.sh -- runtime logging audit of setup-user-claude.sh/.ps1 (PR #121,
# rules fan-out). For each case: a fresh isolated HOME per language under
# $OUT/<case>/<lang>, seeded by a seed_<case> function, then one run of the .sh
# and one of the .ps1 (a scratch copy with its Windows OS guard patched off),
# both from a temp aitools checkout (git init'ed copy of scripts/ + shared/),
# non-interactive (stdin /dev/null). Captured per run: exit code (<lang>.rc),
# console (<lang>.out), summary rows (<lang>.summary), the run's deploy.log
# (HOME/.aitools/logs/deploy.log, default location: AITOOLS_LOG_DIR unset).
# Never touches the real HOME: HOME and USERPROFILE point into $OUT, git global
# config is a file inside the case HOME, AITOOLS_* overrides are unset.
# Usage: bash a121b-runner.sh WORKTREE OUTDIR [case...]
set -uo pipefail

WT="${1:?usage: a121b-runner.sh WORKTREE OUTDIR [case...]}"
OUT="${2:?usage: a121b-runner.sh WORKTREE OUTDIR [case...]}"
shift 2
REAL_HOME=/Users/new-jose
case "$OUT" in "$REAL_HOME/.claude"*|"$REAL_HOME/.aitools"*) echo "refusing OUT under the real HOME config dirs"; exit 1 ;; esac
mkdir -p "$OUT"

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools checkout (adopt targets never land in the worktree) ---
A="$OUT/aitools"
rm -rf "$A"
mkdir -p "$A/scripts" "$A/shared/rules" "$A/.claude/rules"
for f in setup-user-claude.sh aitools-lib.sh aitools-lib.ps1 aitools-profile.sh aitools-profile.ps1 aitools-json.pl aitools-json.ps1; do
    cp "$WT/scripts/$f" "$A/scripts/$f"
done
# OS guard patched in the scratch copy only (never in the worktree file)
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$WT/scripts/setup-user-claude.ps1" > "$A/scripts/setup-user-claude.ps1"
if cmp -s "$WT/scripts/setup-user-claude.ps1" "$A/scripts/setup-user-claude.ps1"; then echo "guard patch did not apply"; exit 1; fi
cp "$WT/shared/claude-shared.md" "$A/shared/claude-shared.md"
printf '## shared s\n' > "$A/shared/rules/s.md"
printf '## project p\n' > "$A/.claude/rules/p.md"
git -C "$A" init -q

# --- Fixture dotprofile ---
DP="$OUT/aitools-tess"
rm -rf "$DP"
mkdir -p "$DP/claude/rules"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
printf '## dot d\n' > "$DP/claude/rules/d.md"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

# --- Seed helpers ($H = HOME being seeded) ---
harness()  { mkdir -p "$H/.aitools/rules"; printf '%s\n' "$2" > "$H/.aitools/rules/$1"; }
deployed() { mkdir -p "$H/.claude/rules"; printf '%s\n' "$2" > "$H/.claude/rules/$1"; }
manifest() {
    mkdir -p "$H/.aitools/rules"
    { printf '# aitools rules manifest v1\n'; for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done; } > "$H/.aitools/rules/.aitools-rules-manifest"
}
std_rules() {
    manifest 'd.md|dotprofile' 'p.md|aitools' 's.md|shared'
    harness s.md '## shared s'; harness p.md '## project p'; harness d.md '## dot d'
}

# --- Cases: seed_<name> [and optional flags_<name> "SHFLAG PSFLAG", env_<name>] ---
seed_clean()      { std_rules; harness notes.txt 'x'; harness s.md.bak.2026-10-22T010203Z 'old'; deployed mine.md 'mine'; }
seed_missing()    { deployed mine.md 'mine'; }
seed_empty()      { mkdir -p "$H/.aitools/rules"; }
seed_unreaddir()  { std_rules; chmod 000 "$H/.aitools/rules"; }
seed_mfunread()   { std_rules; chmod 000 "$H/.aitools/rules/.aitools-rules-manifest"; }
seed_mfunreadonly() { mkdir -p "$H/.aitools/rules"; manifest 'a.md|shared'; chmod 000 "$H/.aitools/rules/.aitools-rules-manifest"; }
seed_badheader()  { harness a.md 'rule a'; printf '# aitools rules manifest v9\nx.md\tretired\n' > "$H/.aitools/rules/.aitools-rules-manifest"; }
seed_mfempty()    { harness a.md 'rule a'; : > "$H/.aitools/rules/.aitools-rules-manifest"; }
seed_mfdir()      { harness a.md 'rule a'; mkdir -p "$H/.aitools/rules/.aitools-rules-manifest"; }
seed_invalid()    { manifest 'bad.txt|shared' 'a.md|unknown' 'b.md|shared' 'b.md|aitools'; harness a.md 'rule a'; harness b.md 'rule b'; }
seed_srclink()    { std_rules; ln -s "$H/nowhere.md" "$H/.aitools/rules/broken.md"; }
seed_destlink()   { std_rules; mkdir -p "$H/.claude/rules"; ln -s "$H/nowhere1.md" "$H/.claude/rules/s.md"; ln -s "$H/nowhere2.md" "$H/.claude/rules/stale.md"; deployed mine.md 'mine'; }
seed_nocreate()   { std_rules; mkdir -p "$H/.claude"; printf 'not a dir\n' > "$H/.claude/rules"; }
seed_nocreatedry() { seed_nocreate; }
flags_nocreatedry="--dry-run -DryRun"
seed_retired()    {
    manifest 'a.md|shared' 'gone.md|retired' 'mine2.md|retired' 'old.md|retired'
    harness a.md 'rule a'
    harness gone.md.bak.2026-10-25T000000Z 'gone rule'
    harness old.md 'old rule'
    deployed gone.md 'gone rule'; deployed old.md 'old rule'; deployed mine2.md 'my own edited copy'
}
seed_retireddry() { seed_retired; }
flags_retireddry="--dry-run -DryRun"
seed_retonly()    { manifest 'gone.md|retired'; harness gone.md.bak.2026-10-25T000000Z 'gone rule'; deployed gone.md 'user edit'; }
seed_srcunread()  { std_rules; chmod 000 "$H/.aitools/rules/p.md"; }
seed_destro()     { std_rules; deployed s.md '## shared s'; deployed p.md 'local edit'; chmod 555 "$H/.claude/rules"; }
seed_retunread()  { manifest 'a.md|shared' 'gone.md|retired'; harness a.md 'rule a'; harness gone.md.bak.2026-10-25T000000Z 'gone rule'; deployed gone.md 'gone rule'; chmod 000 "$H/.claude/rules/gone.md"; }
seed_dryclean()   { seed_clean; }
flags_dryclean="--dry-run -DryRun"
seed_envdry()     { seed_clean; }
env_envdry="AITOOLS_DRY_RUN=1"
seed_edited()     { std_rules; deployed s.md '## shared s'; deployed p.md 'local edit'; deployed d.md '## dot d'; }
seed_force()      { seed_edited; }
flags_force="--force -Force"
seed_many()       {
    manifest 'a.md|shared' 'b.md|shared' 'c.md|shared' 'd.md|shared' 'gone.md|retired' 'gone2.md|retired'
    harness a.md 'a'; harness b.md 'b'; harness c.md 'c'; harness d.md 'd'
    harness gone.md.bak.2026-10-25T000000Z 'gone'; harness gone2.md.bak.2026-10-25T000000Z 'gone2'
    deployed b.md 'b edited'; deployed c.md 'c'; deployed d.md 'd'; deployed gone.md 'gone'; deployed gone2.md 'gone2'
}

ALL_CASES="clean missing empty unreaddir mfunread mfunreadonly badheader mfempty mfdir invalid srclink destlink nocreate nocreatedry retired retireddry retonly srcunread destro retunread dryclean envdry edited force many"
CASES="${*:-$ALL_CASES}"

run_lang() {  # case lang flag extra_env
    local cs="$1" lang="$2" flag="$3" extra="$4" h="$OUT/$1/$2" C="$OUT/$1"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 -u AITOOLS_LOG_DIR -u AITOOLS_ENVIRONMENT
        HOME="$h" USERPROFILE="$h" AITOOLS_SUMMARY_FILE="$C/$lang.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1)
    if [ -n "$extra" ]; then e+=("$extra"); fi
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then
        "${e[@]}" bash "$A/scripts/setup-user-claude.sh" ${flag:+"$flag"} < /dev/null > "$C/sh.out" 2>&1
    else
        "${e[@]}" pwsh -NoProfile -File "$A/scripts/setup-user-claude.ps1" ${flag:+"$flag"} < /dev/null > "$C/ps.out" 2>&1
    fi
    echo $? > "$C/$lang.rc"
    if [ -f "$h/.aitools/logs/deploy.log" ]; then cp "$h/.aitools/logs/deploy.log" "$C/$lang.deploy.log"; else : > "$C/$lang.deploy.log"; fi
}

for cs in $CASES; do
    C="$OUT/$cs"
    if [ -d "$C" ]; then chmod -R u+rwx "$C"; rm -rf "$C"; fi
    mkdir -p "$C"
    fl_var="flags_$cs"; fl="${!fl_var:-}"
    env_var="env_$cs"; ex="${!env_var:-}"
    shf="${fl%% *}"; psf="${fl##* }"
    for lang in sh ps; do
        H="$C/$lang"
        mkdir -p "$H/.aitools"
        printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
        printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$H/.gitconfig"
        "seed_$cs"
        if [ "$lang" = sh ]; then run_lang "$cs" sh "$shf" "$ex"; else run_lang "$cs" ps "$psf" "$ex"; fi
    done
    # restore permissions so the outputs can be read
    chmod -R u+rwx "$C"
    printf '%-14s sh=%s ps=%s\n' "$cs" "$(cat "$C/sh.rc")" "$(cat "$C/ps.rc")"
done
