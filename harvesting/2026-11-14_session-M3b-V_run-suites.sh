#!/usr/bin/env bash
# run-suites.sh -- M3b-Finish-V driver: run every tracked test suite of the
# worktree the way the Windows CI job runs it, each with its own log, under an
# outer isolated HOME / USERPROFILE / AITOOLS_LOG_DIR (suites also isolate
# themselves). Records exit code, duration and the last lines of each log.
# Usage: bash run-suites.sh [suite-name-filter]
set -uo pipefail

WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/console-input"
S="$WT/.scratch/session-M3b-V"
LOGS="$S/suite-logs"
RES="$S/suite-results.tsv"
mkdir -p "$LOGS" "$S/home" "$S/logs-suites"

# Outer isolation (CI runner HOME is ephemeral; mirror it).
export HOME="$S/home"
export USERPROFILE="$(cygpath -w "$S/home")"
export AITOOLS_LOG_DIR="$S/logs-suites"
# Mirror the Windows CI job: git config --global core.autocrlf false
if [ ! -f "$HOME/.gitconfig" ]; then
    printf '[core]\n\tautocrlf = false\n' > "$HOME/.gitconfig"
fi

cd "$WT" || { echo "cannot cd $WT"; exit 1; }

FILTER="${1:-}"
[ -n "$FILTER" ] || printf 'suite\tcommand\texit\tseconds\n' > "$RES"

# name|runner|path   runner: bash | pwsh | python
SUITES='
os-guards|bash|tests/os-guards/test-os-guards.sh
delegation-score|python|tests/harness-db/test-delegation-score.py
ait-harvest|python|tests/harvest/test-ait-harvest.py
logging-sh|bash|tests/logging/test-logging.sh
logging-ps1|pwsh|tests/logging/test-logging.ps1
console-mode-guard-ps1|pwsh|tests/aitools-entry/test-console-mode-guard.ps1
managed-files-sh|bash|tests/managed-files/test-managed-files.sh
managed-files-ps1|pwsh|tests/managed-files/test-managed-files.ps1
adopt-push-sh|bash|tests/managed-files/test-adopt-push.sh
adopt-push-ps1|pwsh|tests/managed-files/test-adopt-push.ps1
menu-choice-sh|bash|tests/menus/test-menu-choice.sh
menu-choice-ps1|pwsh|tests/menus/test-menu-choice.ps1
setup-user-shell-ps1|pwsh|tests/setup-user-shell/test-setup-user-shell.ps1
b8-consumers|bash|tests/b8-consumers/test-b8-consumers.sh
claude-mdm|bash|tests/claude-mdm/test-claude-mdm.sh
hookin|bash|tests/hookin/test-hookin.sh
build-deploy-backup|bash|tests/build-deploy/test-build-deploy-backup.sh
pre-push-step7|bash|tests/check-pre-push/test-pre-push-step7.sh
profile|bash|tests/profile/test-profile.sh
config|bash|tests/profile/test-config.sh
lib|bash|tests/profile/test-lib.sh
user-init|bash|tests/profile/test-user-init.sh
install|bash|tests/profile/test-install.sh
fanout-lib|bash|tests/fanout-lib/test-fanout-lib.sh
rules-fanout|bash|tests/rules-fanout/test-rules-fanout.sh
rules-fanout-cursor|bash|tests/rules-fanout-cursor/test-rules-fanout-cursor.sh
skills-fanout|bash|tests/skills-fanout/test-skills-fanout.sh
skills-legacy|bash|tests/skills-legacy/test-skills-legacy.sh
deploy-harness|bash|tests/deploy-harness/test-deploy-harness.sh
deploy-harness-mdm|bash|tests/deploy-harness-mdm/test-deploy-harness-mdm.sh
delegation-duty-guard|bash|tests/hooks/test-delegation-duty-guard.sh
workflow-delegation-guard|bash|tests/hooks/test-workflow-delegation-guard.sh
sh-file-fixup|bash|tests/hooks/test-sh-file-fixup.sh
glossary-skill-guard|bash|tests/hooks/test-glossary-skill-guard.sh
sessionstart-harness-db|bash|tests/hooks/test-sessionstart-harness-db.sh
hooks-smoke|bash|tests/hooks/test-hooks-smoke.sh
build-package-cli|bash|tests/build-package/test-cli.sh
setup-user-shell-sh|bash|tests/setup-user-shell/test-setup-user-shell.sh
'

run_one() {
    local name="$1" runner="$2" path="$3" log="$4"
    local cmd
    case "$runner" in
        bash)   cmd="bash $path" ;;
        pwsh)   cmd="pwsh -NoProfile -File $path" ;;
        python) cmd="python $path" ;;
    esac
    local t0 t1 rc
    t0=$(date +%s)
    case "$runner" in
        bash)   bash "$path" > "$log" 2>&1 < /dev/null ;;
        pwsh)   pwsh -NoProfile -File "$path" > "$log" 2>&1 < /dev/null ;;
        python) python "$path" > "$log" 2>&1 < /dev/null ;;
    esac
    rc=$?
    t1=$(date +%s)
    printf '%s\t%s\t%s\t%s\n' "$name" "$cmd" "$rc" "$((t1 - t0))" >> "$RES"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $name exit=$rc ($((t1 - t0))s)"
    return $rc
}

echo "$SUITES" | while IFS='|' read -r name runner path; do
    [ -n "$name" ] || continue
    if [ -n "$FILTER" ] && [ "$FILTER" != "$name" ]; then continue; fi
    log="$LOGS/$name.log"
    run_one "$name" "$runner" "$path" "$log"
    rc=$?
    # Known timing flake: rerun once, keep both logs.
    if [ "$name" = "workflow-delegation-guard" ] && [ "$rc" -ne 0 ]; then
        run_one "${name}-rerun" "$runner" "$path" "$LOGS/${name}-rerun.log"
    fi
done
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] all suites done"
