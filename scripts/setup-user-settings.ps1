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
# Source of truth: profile.json (dotprofile repo, found by Resolve-UserRepoPath).

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
# Get-Command exempt: command-existence check; the branch is the fallback
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-AitError "claude settings" "settings not synced" "node not found (run aitools install)"
    exit 1
}

$settingsFile = Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json"
$deprecatedRules = "MCP(vercel),MCP(webflow),Agent(claude-code-guide)"

# --- Resolve profile.json (source of truth): the one dotprofile resolver ---
# (reference/user-repo.md "Resolution"; SD-7). Return: 0 found, 1 no dotprofile
# (shared-only mode, expected), 3 resolver error (the lib already logged,
# counted and recorded it once: Write-AitError "dotprofile").
$urpRc = Resolve-UserRepoPath
$userRepoPath = $script:AitLibUserRepoPath
$profileFile = if ($userRepoPath) { Join-Path $userRepoPath "profile.json" } else { "" }

if ($urpRc -ne 0 -and $urpRc -ne 1) {
    # A consequence of the resolver's error, which the lib already counted and
    # recorded: logged at info, so one cause is one red line (reference/logging.md
    # 8.3; supersedes the earlier S3-M3Lead choice to count it again). The exit
    # status stays 1 through the resolver's counted error.
    Log "Dotprofile unresolved (resolver error above) -- settings not synced"
} elseif (-not $userRepoPath -or -not (Test-Path -LiteralPath $userRepoPath -PathType Container)) {
    Write-AitWarn "claude settings" "not synced: no dotprofile (shared-only mode) -- run: aitools user init"
} elseif (-not (Test-Path $profileFile)) {
    Write-AitWarn "claude settings" "not synced: profile.json not found at $profileFile"
} else {
    # A missing settings.json is not skipped: Sync-ManagedJson creates it from the
    # profile without prompting (#31, C-F5).

    # --- Legacy migration: claude.{autoMemory,alwaysThinking,effortLevel} ---
    #     -> claude.settings.{autoMemoryEnabled,alwaysThinkingEnabled,effortLevel}
    if (-not $DryRun) {
      # Only back up + migrate when legacy flat keys are actually present.
      # Probe exit codes: 0 = legacy keys present, 1 = none, 2 = profile.json
      # unreadable (the sync below then reports the parse error).
      $legacyOut = & node -e 'try { const c=(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).claude)||{}; process.exit(["autoMemory","alwaysThinking","effortLevel"].some(k=>Object.prototype.hasOwnProperty.call(c,k))?0:1) } catch (e) { console.log(e.message); process.exit(2) }' $profileFile 2>&1 | Out-String
      $legacyRc = $LASTEXITCODE
      if ($legacyRc -ge 2) {
        # Logged at info, not a warning: the sync below reads the same file and
        # records the same failure as its error, and one cause is recorded once
        # (reference/logging.md 8.3). Get-AitErrorReason logs the output as detail.
        Log "Legacy preference check skipped: $profileFile unreadable: $(Get-AitErrorReason -Output $legacyOut -ExitCode $legacyRc) (the settings sync reports it)"
      }
      if ($legacyRc -eq 0) {
        Backup-File -FilePath $profileFile
        $migrateJs = @'
const fs = require("fs");
const p = process.argv[2];  // run as `node <script-file> <profile>`: argv[1] is the script
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
        $migrated = & node $migrateFile $profileFile 2>&1 | Out-String
        $migrateRc = $LASTEXITCODE
        # ErrorAction exempt: temp file cleanup; the file may already be gone
        Remove-Item $migrateFile -ErrorAction SilentlyContinue
        if ($migrateRc -ne 0) {
            # Get-AitErrorReason logs the migration's output as detail lines
            Write-AitWarn "claude settings" "legacy preference migration failed (non-fatal): $(Get-AitErrorReason -Output $migrated -ExitCode $migrateRc)"
        } elseif ($migrated.Trim()) {
            LogOk "Migrated legacy prefs into claude.settings: $($migrated.Trim())"
        }
      }
    }

    # --- Sync settings.json <-> profile.json (granular per-leaf review) ---
    # Sync-ManagedJson records a failure once, under -Tool (Write-AitError;
    # reference/logging.md 8.3): compare the error count so a failed sync writes
    # no OK record (#26b) and no second ERROR record.
    $errorsBeforeSync = $errors
    Sync-ManagedJson -LiveFile $settingsFile -ProfileFile $profileFile -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules $deprecatedRules -Tool "claude settings"
    if ($errors -gt $errorsBeforeSync) {
        Log "Settings sync failed (recorded above) -- no status record"
    } elseif ($DryRun) {
        Write-Summary "OK" "claude settings" "dry-run"
    } else {
        switch ($script:SyncManagedJsonResult) {
            "created" { Write-Summary "OK" "claude settings" "created" }
            "updated" { Write-Summary "OK" "claude settings" "synced" }
            default   { Write-Summary "OK" "claude settings" "verified" }
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
