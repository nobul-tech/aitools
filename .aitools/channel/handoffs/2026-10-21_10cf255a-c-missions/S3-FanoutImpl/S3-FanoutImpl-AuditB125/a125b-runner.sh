#!/usr/bin/env bash
# a125b-runner.sh -- runtime logging audit of setup-user-skills.sh/.ps1 (PR #125,
# FO-6 fallback skills deployer). For each case: a fresh isolated HOME per
# language under $OUT/<case>/<lang>, seeded by seed_<case>, then one run of the
# .sh and one of the .ps1 (a scratch copy with its Windows OS guard patched off),
# both from a temp aitools fixture checkout (scripts/ copied from the worktree,
# shared/skills a fixture), non-interactive (stdin /dev/null).
# Captured per run: exit code (<lang>.rc), console (<lang>.out), summary rows
# (<lang>.summary), the run's deploy.log (HOME/.aitools/logs/deploy.log, default
# location: AITOOLS_LOG_DIR unset).
# Never touches the real HOME: HOME and USERPROFILE point into $OUT, git global
# config is a file inside the case HOME, AITOOLS_* overrides are unset.
# Usage: bash a125b-runner.sh WORKTREE OUTDIR [case...]
set -uo pipefail

WT="${1:?usage: a125b-runner.sh WORKTREE OUTDIR [case...]}"
OUT="${2:?usage: a125b-runner.sh WORKTREE OUTDIR [case...]}"
shift 2
REAL_HOME=/Users/new-jose
case "$OUT" in "$REAL_HOME/.claude"*|"$REAL_HOME/.aitools"*|"$REAL_HOME/.cursor"*) echo "refusing OUT under the real HOME config dirs"; exit 1 ;; esac
mkdir -p "$OUT"

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }
skill() { mkdir -p "$1/$2"; printf -- '---\nname: %s\n---\n%s\n' "$2" "$3" > "$1/$2/SKILL.md"; }

# --- Fixture aitools checkout (adopt targets never land in the worktree) ---
A="$OUT/aitools"
if [ -d "$A" ]; then chmod -R u+rwx "$A"; rm -rf "$A"; fi
mkdir -p "$A/shared/skills"
cp -R "$WT/scripts" "$A/scripts"
skill "$A/shared/skills" alpha "shared alpha"
skill "$A/shared/skills" beta "shared beta"
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$WT/scripts/setup-user-skills.ps1" > "$A/scripts/setup-user-skills.ps1"
if cmp -s "$WT/scripts/setup-user-skills.ps1" "$A/scripts/setup-user-skills.ps1"; then echo "guard patch did not apply"; exit 1; fi
git -C "$A" init -q

# --- Fixture dotprofile ---
DP="$OUT/aitools-tess"
if [ -d "$DP" ]; then rm -rf "$DP"; fi
mkdir -p "$DP/claude/rules"
printf '# Prefs for {{PROFILE_NAME}}\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
skill "$DP/claude/skills" dpskill "dotprofile skill"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

# --- Resolver error stubs (the lib's lookup override) ---
W="$OUT/stubs"; mkdir -p "$W"
printf '#!/usr/bin/env bash\nprintf "via\\tnone\\nerror\\tstub resolver failure\\n"\nexit 2\n' > "$W/fail.sh"
printf '"via`tnone"\n"error`tstub resolver failure"\nexit 2\n' > "$W/fail.ps1"

# --- Seed helpers ($H = HOME being seeded) ---
harness() {
    local hs="$H/.aitools/skills" cs="$H/.claude/skills"
    mkdir -p "$hs"
    skill "$hs" alpha "harness alpha"
    skill "$hs" aitskill "aitools project skill"
    skill "$hs" CaseSkill "case"
    skill "$hs" "old.bak.20261001T000000Z" "harness backup"
    printf '# aitools skills manifest v1\naitskill\taitools\nalpha\tshared\nCaseSkill\tshared\ngone\tretired\nbad/name\tshared\n' > "$hs/.aitools-skills-manifest"
    skill "$cs" alpha "user alpha"
    skill "$cs" aitskill "fanned out"
    skill "$cs" caseskill "fanned out, other case"
    skill "$cs" gone "retired"
    skill "$cs" "gone.bak.20261020T000000Z" "fan-out backup"
    skill "$cs" mine "user-created"
}
user_only() { skill "$H/.claude/skills" mine "user-created"; }

# --- Cases: seed_<name>; optional flags_<name>="SHFLAG PSFLAG", env_<name>, stub_<name>=fail, cfg_<name>=nodp ---
seed_a_fan()        { harness; }
seed_b_fallback()   { user_only; }
seed_c_mfunread()   { harness; chmod 000 "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_c2_dirunread() { harness; chmod 000 "$H/.aitools/skills"; }
seed_c3_dirnox()    { harness; chmod 444 "$H/.aitools/skills"; }
seed_c4_mfdir()     { harness; rm -f "$H/.aitools/skills/.aitools-skills-manifest"; mkdir "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_c5_mflink()    { harness; rm -f "$H/.aitools/skills/.aitools-skills-manifest"; ln -s "$H/nowhere" "$H/.aitools/skills/.aitools-skills-manifest"; }
seed_d_rerrfan()    { harness; }
stub_d_rerrfan=fail
seed_d2_rerrfb()    { user_only; }
stub_d2_rerrfb=fail
seed_e_dryfan()     { harness; }
flags_e_dryfan="--dry-run -DryRun"
seed_e2_dryfb()     { user_only; }
flags_e2_dryfb="--dry-run -DryRun"
seed_e3_envdry()    { harness; }
env_e3_envdry="AITOOLS_DRY_RUN=1"
seed_f_nodp()       { harness; }
cfg_f_nodp=nodp
seed_g_envwarn()    { harness; }
env_g_envwarn="AITOOLS_ENVIRONMENT=bogus"
seed_h_destunread() { harness; chmod 000 "$H/.claude/skills"; }
seed_i_harnessfile(){ mkdir -p "$H/.aitools"; printf 'not a dir\n' > "$H/.aitools/skills"; user_only; }
seed_j_emptyharness(){ mkdir -p "$H/.aitools/skills"; user_only; }

ALL_CASES="a_fan b_fallback c_mfunread c2_dirunread c3_dirnox c4_mfdir c5_mflink d_rerrfan d2_rerrfb e_dryfan e2_dryfb e3_envdry f_nodp g_envwarn h_destunread i_harnessfile j_emptyharness"
CASES="${*:-$ALL_CASES}"

run_lang() {  # case lang flag extra_env stub
    local cs="$1" lang="$2" flag="$3" extra="$4" stub="$5" h="$OUT/$1/$2" C="$OUT/$1"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 -u AITOOLS_LOG_DIR -u AITOOLS_ENVIRONMENT -u CLAUDE_CODE_REMOTE
        HOME="$h" USERPROFILE="$h" AITOOLS_SUMMARY_FILE="$C/$lang.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1)
    if [ -n "$extra" ]; then e+=("$extra"); fi
    if [ "$stub" = fail ]; then e+=(AITOOLS_PROFILE_SH="$W/fail.sh" AITOOLS_PROFILE_PS1="$W/fail.ps1"); fi
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then
        "${e[@]}" bash "$A/scripts/setup-user-skills.sh" ${flag:+"$flag"} < /dev/null > "$C/sh.out" 2>&1
    else
        "${e[@]}" pwsh -NoProfile -File "$A/scripts/setup-user-skills.ps1" ${flag:+"$flag"} < /dev/null > "$C/ps.out" 2>&1
    fi
    echo $? > "$C/$lang.rc"
    if [ -f "$h/.aitools/logs/deploy.log" ]; then cp "$h/.aitools/logs/deploy.log" "$C/$lang.deploy.log"; else : > "$C/$lang.deploy.log"; fi
    # what the run left on disk (after permissions are restored by the caller)
}

for cs in $CASES; do
    C="$OUT/$cs"
    if [ -d "$C" ]; then chmod -R u+rwx "$C"; rm -rf "$C"; fi
    mkdir -p "$C"
    fl_var="flags_$cs"; fl="${!fl_var:-}"
    env_var="env_$cs"; ex="${!env_var:-}"
    st_var="stub_$cs"; st="${!st_var:-live}"
    cf_var="cfg_$cs"; cf="${!cf_var:-}"
    shf="${fl%% *}"; psf="${fl##* }"
    for lang in sh ps; do
        H="$C/$lang"
        mkdir -p "$H/.aitools"
        if [ "$cf" = nodp ]; then
            printf '{"machineAlias":"m1"}\n' > "$H/.aitools/config.json"
        else
            printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
        fi
        printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$H/.gitconfig"
        "seed_$cs"
        if [ "$lang" = sh ]; then run_lang "$cs" sh "$shf" "$ex" "$st"; else run_lang "$cs" ps "$psf" "$ex" "$st"; fi
    done
    chmod -R u+rwx "$C"
    for lang in sh ps; do
        ( cd "$C/$lang" && find .claude .cursor -name SKILL.md 2>/dev/null | sort ) > "$C/$lang.files"
    done
    printf '%-16s sh=%s ps=%s\n' "$cs" "$(cat "$C/sh.rc")" "$(cat "$C/ps.rc")"
done
