# setup-user-settings.ps1 — Syncs ~/.claude/settings.json with profile.json (source of truth)
# Safe to re-run. Platform: Windows (macOS/Linux: setup-user-settings.sh).
# UNTESTED on Windows: authored on macOS (no pwsh). Mirrors setup-user-settings.sh.
# Reference: reference/user-repo.md, .claude/rules/managed-file-deployment.md.
#
# profile.json `claude.settings` is the source of truth for ~/.claude/settings.json,
# EXCEPT `hooks` (manifest-owned, deployed by setup-user-hooks). For each managed leaf
# (arbitrary keys; permissions per-rule across allow/ask/deny): live-only -> auto-adopt;
# equal -> no-op; differ/live-missing -> granular per-leaf prompt. Obsolete deny rules
# are purged before the scan.
#
# Managed: all of ~/.claude/settings.json except `hooks`.
# Source of truth: profile.json (dotprofile repo, via config.json userRepoPath).

# --- BEGIN settings body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-settings"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- Require node ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    LogError "node required for settings sync"
    exit 1
}

$settingsFile = Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json"
$deprecatedRules = "MCP(vercel),MCP(webflow),Agent(claude-code-guide)"

# --- Resolve profile.json (source of truth) via config.json userRepoPath ---
$userRepoPath = ReadConfigKey -File (Join-Path $env:USERPROFILE ".aitools\config.json") -Key "userRepoPath"
$profileFile = if ($userRepoPath) { Join-Path $userRepoPath "profile.json" } else { "" }

if (-not $userRepoPath -or -not (Test-Path $userRepoPath)) {
    LogWarn "No user repo configured (run 'aitools user init') -- skipping settings sync"
    Write-Summary "WARN" "claude settings" "no profile (run aitools user init)"
} elseif (-not (Test-Path $profileFile)) {
    LogWarn "profile.json not found at $profileFile -- skipping settings sync"
    Write-Summary "WARN" "claude settings" "profile.json missing"
} elseif (-not (Test-Path $settingsFile)) {
    Log "No settings.json yet at $settingsFile -- nothing to sync"
    Write-Summary "OK" "claude settings" "no settings.json"
} else {
    # --- Legacy migration: claude.{autoMemory,alwaysThinking,effortLevel} ---
    #     -> claude.settings.{autoMemoryEnabled,alwaysThinkingEnabled,effortLevel}
    if (-not $DryRun) {
      # Only back up + migrate when legacy flat keys are actually present.
      & node -e 'const c=(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).claude)||{}; process.exit(["autoMemory","alwaysThinking","effortLevel"].some(k=>Object.prototype.hasOwnProperty.call(c,k))?0:1)' $profileFile 2>$null
      if ($LASTEXITCODE -eq 0) {
        Backup-File -FilePath $profileFile
        $migrateJs = @'
const fs = require("fs");
const p = process.argv[1];
const o = JSON.parse(fs.readFileSync(p, "utf8"));
const c = o.claude = o.claude || {};
const s = c.settings = (c.settings && typeof c.settings === "object") ? c.settings : {};
const map = { autoMemory: "autoMemoryEnabled", alwaysThinking: "alwaysThinkingEnabled", effortLevel: "effortLevel" };
const migrated = [];
for (const [legacy, target] of Object.entries(map)) {
    if (Object.prototype.hasOwnProperty.call(c, legacy)) {
        if (!Object.prototype.hasOwnProperty.call(s, target)) { s[target] = c[legacy]; migrated.push(legacy + "->" + target); }
        delete c[legacy];
    }
}
if (migrated.length) fs.writeFileSync(p, JSON.stringify(o, null, 2) + "\n");
process.stdout.write(migrated.join(", "));
'@
        $migrateFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($migrateFile, $migrateJs, [System.Text.UTF8Encoding]::new($false))
        $migrated = & node $migrateFile $profileFile
        Remove-Item $migrateFile -ErrorAction SilentlyContinue
        if ($migrated) { LogOk "Migrated legacy prefs into claude.settings: $migrated" }
      }
    }

    # --- Sync settings.json <-> profile.json (granular per-leaf review) ---
    if ($DryRun) {
        Sync-ManagedJson -LiveFile $settingsFile -ProfileFile $profileFile -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules $deprecatedRules
        Write-Summary "OK" "claude settings" "dry-run"
    } else {
        Sync-ManagedJson -LiveFile $settingsFile -ProfileFile $profileFile -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules $deprecatedRules
        switch ($script:SyncManagedJsonResult) {
            { $_ -in @("updated", "created") } { Write-Summary "OK" "claude settings" "synced" }
            default { Write-Summary "OK" "claude settings" "verified" }
        }
    }
}
# --- END settings body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
