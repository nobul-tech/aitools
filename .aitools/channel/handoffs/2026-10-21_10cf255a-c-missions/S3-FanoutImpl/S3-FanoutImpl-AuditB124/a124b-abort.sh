#!/usr/bin/env bash
# a124b-abort.sh WORKTREE RUNS -- [x]abort at a skill file review on a pty, both
# languages, isolated HOMEs under RUNS/abort/<lang>. Two skills: a1 (verified,
# before) and s1 (edited locally: the review). Reuses the runner's temp aitools
# checkout and dotprofile (run a124b-runner.sh first). Prints the exit code,
# summary rows, the setup-user-claude log lines (no detail) and the local file.
# Adapted from S3-FanoutImpl-AuditB121/a121b-abort.sh.
set -uo pipefail
WT="${1:?usage: a124b-abort.sh WORKTREE RUNS}"; R="${2:?usage: a124b-abort.sh WORKTREE RUNS}"
A="$R/aitools"; DP="$R/aitools-tess"; C="$R/abort"; PTY="$WT/tests/managed-files/pty-run.py"
if [ -d "$C" ]; then rm -rf "$C"; fi
for l in sh ps; do
    H="$C/$l"; mkdir -p "$H/.aitools/skills/a1" "$H/.aitools/skills/s1" "$H/.claude/skills/a1" "$H/.claude/skills/s1"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
    printf '[user]\n\tname = Test\n\temail = test@example.invalid\n' > "$H/.gitconfig"
    printf '# aitools skills manifest v1\na1\tshared\ns1\tshared\n' > "$H/.aitools/skills/.aitools-skills-manifest"
    printf '## a1\n' > "$H/.aitools/skills/a1/SKILL.md"; printf '## a1\n' > "$H/.claude/skills/a1/SKILL.md"
    printf '## shared s1\n' > "$H/.aitools/skills/s1/SKILL.md"
    printf '## shared s1\nlocal edit\n' > "$H/.claude/skills/s1/SKILL.md"
    if [ "$l" = sh ]; then cmd=(bash "$A/scripts/setup-user-claude.sh"); else cmd=(pwsh -NoProfile -File "$A/scripts/setup-user-claude.ps1"); fi
    : > "$C/$l.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_LOG_DIR \
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$C/$l.summary" AITOOLS_PROFILE_TEST_ANY_OS=1 \
        GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1 \
        python3 "$PTY" --input 'x\n' --log "$C/$l.out" -- "${cmd[@]}"
    rc=$?
    printf '=== %s rc=%s\n' "$l" "$rc"
    printf -- '--- rows\n'; cat "$C/$l.summary"
    printf -- '--- log (setup-user-claude, no detail)\n'
    grep -F '[setup-user-claude]' "$H/.aitools/logs/deploy.log" | grep -v '\[detail\]' | perl -pe 's/^\[[^]]+\] //'
    printf -- '--- local file\n'; cat "$H/.claude/skills/s1/SKILL.md"
done
