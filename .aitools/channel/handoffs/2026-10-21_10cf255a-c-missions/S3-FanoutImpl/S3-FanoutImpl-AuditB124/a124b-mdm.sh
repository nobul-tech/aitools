#!/usr/bin/env bash
# a124b-mdm.sh WORKTREE OUT -- MDM path check for PR #124: build-deploy.sh under
# an isolated HOME into a CLONE of the dotprofile inside OUT (remote removed, so
# nothing can be pushed), then the generated deploy/setup-user-claude.sh and a
# guard-patched copy of deploy/setup-user-claude.ps1 run against seeded isolated
# HOMEs (clean, then a verified rerun, then a retired case). Captures rc, rows,
# deploy.log per run under OUT/mdm-<case>/<lang>.
set -uo pipefail
WT="${1:?usage: a124b-mdm.sh WORKTREE OUT}"; OUT="${2:?usage: a124b-mdm.sh WORKTREE OUT}"
SRC_DP=/Users/new-jose/repos/aitools-nobul-jose
case "$OUT" in /Users/new-jose/.claude*|/Users/new-jose/.aitools*|"$SRC_DP"*) echo "refusing OUT"; exit 1 ;; esac
mkdir -p "$OUT"
DP="$OUT/dp-copy"
if [ -d "$DP" ]; then rm -rf "$DP"; fi
git clone -q --no-hardlinks "$SRC_DP" "$DP" || { echo "clone failed"; exit 1; }
git -C "$DP" remote remove origin
if git -C "$DP" remote | grep -q .; then echo "remote still present"; exit 1; fi

HB="$OUT/home-build"
if [ -d "$HB" ]; then rm -rf "$HB"; fi
mkdir -p "$HB/.aitools"
printf '{"userRepoPath":"%s","reposPath":"%s","repoPath":"%s"}\n' "$DP" "$OUT" "$WT" > "$HB/.aitools/config.json"
env -u AITOOLS_SUMMARY_FILE -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
    HOME="$HB" USERPROFILE="$HB" AITOOLS_USER_REPO_PATH="$DP" AITOOLS_LOG_DIR="$HB/logs" \
    bash "$WT/scripts/build-deploy.sh" > "$OUT/build.out" 2>&1
echo "build rc=$?"
G="$DP/deploy"
for f in setup-user-claude.sh setup-user-claude.ps1; do [ -f "$G/$f" ] || { echo "missing $G/$f"; exit 1; }; done
printf 'skills span in generated sh: %s, ps1: %s\n' \
    "$(grep -c 'fanout_harness_skills "claude skills"' "$G/setup-user-claude.sh")" \
    "$(grep -c 'Invoke-HarnessSkillsFanout -ToolName "claude skills"' "$G/setup-user-claude.ps1")"
printf 'lib function defined in generated sh: %s, ps1: %s\n' \
    "$(grep -c '^fanout_harness_skills()' "$G/setup-user-claude.sh")" \
    "$(grep -c '^function Invoke-HarnessSkillsFanout' "$G/setup-user-claude.ps1")"
bash -n "$G/setup-user-claude.sh"; echo "bash -n rc=$?"
GP="$OUT/gen-ps"; mkdir -p "$GP"
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$G/setup-user-claude.ps1" > "$GP/setup-user-claude.ps1"
if cmp -s "$G/setup-user-claude.ps1" "$GP/setup-user-claude.ps1"; then echo "generated ps1 guard patch did not apply"; exit 1; fi

seed() {  # seed H CASE
    local H="$1"
    mkdir -p "$H/.aitools/skills/s1/scripts" "$H/.aitools/skills/d1" "$H/.claude/skills/mine"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
    printf '[user]\n\tname = Test\n\temail = test@example.invalid\n' > "$H/.gitconfig"
    printf '# aitools skills manifest v1\nd1\tdotprofile\ngone\tretired\ns1\tshared\n' > "$H/.aitools/skills/.aitools-skills-manifest"
    printf '## s1\n' > "$H/.aitools/skills/s1/SKILL.md"
    printf '#!/bin/sh\n' > "$H/.aitools/skills/s1/scripts/run.sh"; chmod 755 "$H/.aitools/skills/s1/scripts/run.sh"
    printf '## d1\n' > "$H/.aitools/skills/d1/SKILL.md"
    printf 'mine\n' > "$H/.claude/skills/mine/SKILL.md"
    if [ "$2" = retired ]; then
        mkdir -p "$H/.aitools/skills/gone.bak.2026-10-25T000000Z" "$H/.claude/skills/gone"
        printf 'gone\n' > "$H/.aitools/skills/gone.bak.2026-10-25T000000Z/SKILL.md"
        printf 'gone\n' > "$H/.claude/skills/gone/SKILL.md"
    fi
}
runit() {  # runit CASE LANG
    local C="$OUT/mdm-$1" l="$2" H="$OUT/mdm-$1/$2"
    : > "$C/$l.summary"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 -u AITOOLS_LOG_DIR
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$C/$l.summary" AITOOLS_PROFILE_TEST_ANY_OS=1
        GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1)
    if [ "$l" = sh ]; then
        "${e[@]}" bash "$G/setup-user-claude.sh" < /dev/null > "$C/$l.out" 2> "$C/$l.err"
    else
        "${e[@]}" pwsh -NoProfile -File "$GP/setup-user-claude.ps1" < /dev/null > "$C/$l.out" 2> "$C/$l.err"
    fi
    echo $? > "$C/$l.rc"
    cp "$H/.aitools/logs/deploy.log" "$C/$l.deploy.log"
    printf '%s %s rc=%s\n' "$1" "$l" "$(cat "$C/$l.rc")"
    grep -E '^(ACTION\||[A-Z]+\|claude skills\|)' "$C/$l.summary"
}
for cs in clean retired; do
    C="$OUT/mdm-$cs"
    if [ -d "$C" ]; then chmod -R u+rwx "$C"; rm -rf "$C"; fi
    for l in sh ps; do mkdir -p "$C/$l"; seed "$C/$l" "$cs"; runit "$cs" "$l"; done
done
# verified rerun of clean
for l in sh ps; do runit clean "$l"; done
for l in sh ps; do
    printf 'clean %s: x bit on s1/scripts/run.sh: %s\n' "$l" "$([ -x "$OUT/mdm-clean/$l/.claude/skills/s1/scripts/run.sh" ] && echo yes || echo no)"
    printf 'retired %s: gone removed: %s, backup dirs: %s\n' "$l" "$([ -e "$OUT/mdm-retired/$l/.claude/skills/gone" ] && echo no || echo yes)" "$(ls "$OUT/mdm-retired/$l/.claude" | grep -c '^skills\.bak\.')"
done
