#!/usr/bin/env bash
# Scan PR diffs (added lines) for patterns that would fix remediation items (scratch, read-only).
set -uo pipefail
D=/Users/new-jose/repos/aitools/.scratch/session-remedwr/prs
R=/Users/new-jose/repos/aitools
scan() {
    local label="$1" pat="$2"
    printf '\n=== %s  [%s]\n' "$label" "$pat"
    for f in "$D"/pr*.diff; do
        local n; n=$(basename "$f" .diff)
        local c; c=$(grep -E '^\+' "$f" | grep -c -E -- "$pat")
        if [ "$c" -gt 0 ]; then printf '%s:%s ' "$n" "$c"; fi
    done
    printf '\n'
}
scan "trap fix" "MDM_TMP=\"\\\$BUILD_TMP/mdm\""
scan "skip-config" "skip-config|SkipConfig"
scan "size gate" "200000|200,000|1000000"
scan "no bootstrap n/a" "no bootstrap"
scan "deploy-harness in installer/sync" "run_harness_step|Invoke-HarnessStep"
scan "unknown option exit" "Unknown option"
scan "node@22" "node@22|brew install node"
scan "hooks settings backup" "backup_file \"\\\$SETTINGS|Backup-File .*[Ss]ettings"
scan "ait-harvest cwd" "PROJECT_ROOT/scripts/ait-harvest"
scan "bash_profile" "bash_profile|\\.zprofile"
scan "winget scope" "winget.*--scope"
scan "LASTEXITCODE git" "LASTEXITCODE = 1|Get-Command git"
scan "stamp (?m)" "\\(\\?m\\)"
scan "create dotprofile default" "ans=\"y\"|ans=\"n\""
scan "GIT_TERMINAL_PROMPT" "GIT_TERMINAL_PROMPT"
scan "log fail-safe" "mkdir -p \"\\\$LOG_DIR\"|AppendAllText"
scan "jsonl rotate" "_rotate_log .*jsonl|deploy.jsonl"
scan "first profile" "first profile"
scan "os-release" "os-release"
scan "cursor-cloud" "cursor-cloud"
scan "console user" "SUDO_USER|/dev/console|ConsoleUser"
scan "Test-IsAdmin" "Test-IsAdmin"
scan "SHELL unbound" "SHELL:-|basename \"\\\$SHELL"
scan "cursor node no row" "node not found"
scan "cursor fanout restrict" "rules-manifest|aitools-rules-manifest"
scan "non-main branch push" "non-main|symbolic-ref|rev-parse --abbrev-ref"
scan "dotprofile_commit_push" "dotprofile_commit_push"
scan "mcp ps1 summary" "Write-Summary \"ERROR\" \"claude mcp\""
scan "cursor-ide-mcp disable" "agent mcp (disable|remove)"
scan "skipping MDM deploy" "MDM deploy"
scan "AITOOLS_DEPLOY" "AITOOLS_DEPLOY"
scan "Git Bash path" "Git\\\\bin\\\\bash.exe"
scan "sync_managed_json" "autoAdopt|sync_managed_json"
scan "backup_dir md" "backup_dir"
scan "PS7 guard" "PSVersion.Major"
scan "HOME guard" "HOME:\\?|HOME is not set|HOME not set"
scan "lib source check" "aitools-lib.sh not found|aitools-lib.ps1 not found"
scan "version stamp/BUILD-INFO" "BUILD-INFO|--stamp"
scan "deploy-paths mdc steps" "Four script pairs|steps 3\\+10"
scan "Step21 order" "DEPLOY_SCRIPTS="
scan "npx -y" "npx -y chrome-devtools|\"-y\""
printf '\n=== installer MDM deploy counts\n'
grep -c 'MDM deploy' "$R/scripts/aitools-install.sh" "$R/scripts/aitools-install.ps1"
printf '\n=== bd 2286-2290\n'
grep -n 'chmod +x "\$DEPLOY_DIR"/\*\|2>/dev/null || true' "$R/scripts/build-deploy.sh" | head -n 5
printf '\n=== installer mkdir HOME/.aitools\n'
grep -n 'mkdir -p' "$R/scripts/aitools-install.sh" | head -n 10
printf '\n=== incidents.json related titles\n'
grep -n -i -E '"title".*(console user|run context|trap|LASTEXITCODE|keg|node@22|SHELL|bash_profile|ait-harvest|version stamp|unknown option|first profile|jsonl|winget|scope|cursor cloud|cursor-cloud|bak|backup)' "$R/registries/incidents.json" | head -n 40
printf '\n=== pr102 incident titles\n'
grep -E '^\+.*"title"' "$D/pr102.diff" | head -n 30
