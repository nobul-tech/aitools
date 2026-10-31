#!/usr/bin/env bash
# a121b-abort.sh WORKTREE RUNS -- [x]abort at a rule review on a pty, both
# languages, isolated HOMEs under RUNS/abort/<lang>. Reuses the runner's temp
# aitools checkout and dotprofile (run a121b-runner.sh first). Prints exit
# code, summary rows and the setup-user-claude log lines of each run.
set -uo pipefail
WT="${1:?usage: a121b-abort.sh WORKTREE RUNS}"; R="${2:?usage: a121b-abort.sh WORKTREE RUNS}"
A="$R/aitools"; DP="$R/aitools-tess"; C="$R/abort"; PTY="$WT/tests/managed-files/pty-run.py"
if [ -d "$C" ]; then rm -rf "$C"; fi
for l in sh ps; do
    H="$C/$l"; mkdir -p "$H/.aitools/rules" "$H/.claude/rules"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
    printf '[user]\n\tname = Test\n\temail = test@example.invalid\n' > "$H/.gitconfig"
    printf '# aitools rules manifest v1\ns.md\tshared\n' > "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## shared s\n' > "$H/.aitools/rules/s.md"
    printf '## shared s\nlocal edit\n' > "$H/.claude/rules/s.md"
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
    printf -- '--- local file\n'; cat "$H/.claude/rules/s.md"
done
