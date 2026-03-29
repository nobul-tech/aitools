# setup-user-hooks.ps1 -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop, autoMemoryEnabled, alwaysThinkingEnabled, effortLevel
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionStart: scratch-init.sh (creates session scratch directory)
#   SessionStart: dashboard-serve.sh (launches live dashboard server)
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   SessionEnd: harvest-session.sh (harvests session artifacts)
#   SessionEnd: tool-ops-session-audit.sh (runs tool-ops contract tests and drift detection)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)
#   PreToolUse[Read|Grep]: glossary-skill-guard.sh (reminds agent to use /glossary skill)
#   PreToolUse[Agent]: block-claude-code-guide.sh (blocks buggy built-in subagent)
#   PostToolUse[Write|Edit]: sh-file-fixup.sh (fixes CRLF and chmod on .sh files)
#   PreToolUse[Agent]: delegation-duty-guard.sh (checks delegation prompts for duty elements)
#   SessionStart: harness-db-sessionstart.sh (initializes harness SQLite DBs)
#   SessionEnd: harness-db-sessionend.sh (marks session complete, exports JSON)
#   Stop: command-channel-stop.sh (polls session DB for commander directives)
#   Stop: failure-mode-identity-stop.sh (reinforces agent identity and process)
#   Stop: failure-mode-verify-stop.sh (lightweight failure mode self-check)
#
# Reads claude preferences from profile.json (via config.json -> userRepoPath).
# See reference/user-repo.md and shared/hooks/ for details.
#
# Note: Hook scripts are bash-only (Claude Code hooks always run in bash on
# both platforms). This PS1 script only deploys the hook configuration.

# --- BEGIN hooks body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-hooks"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- BEGIN hook deployment (replaced by build-deploy) ---
# --- Resolve repo path ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

# User repo for dotprofile overrides and adopt target
$userRepoPath = ReadConfigKey -File (Join-Path $env:USERPROFILE ".aitools\config.json") -Key "userRepoPath"
$dotprofileHooks = $null
if ($userRepoPath) {
    $dpHooksPath = Join-Path $userRepoPath "claude\hooks"
    if (Test-Path $dpHooksPath) {
        $dotprofileHooks = $dpHooksPath
    }
}

# Resolve hook source: dotprofile wins over shared
function Resolve-HookSource {
    param([string]$HookName)
    if ($dotprofileHooks -and (Test-Path (Join-Path $dotprofileHooks $HookName))) {
        return (Join-Path $dotprofileHooks $HookName)
    }
    return (Join-Path $repoDir "shared\hooks\$HookName")
}

$hookScript = Resolve-HookSource "session-archive.sh"
$guardScript = Resolve-HookSource "standing-order-guard.sh"
$glossaryScript = Resolve-HookSource "glossary-skill-guard.sh"
$scratchScript = Resolve-HookSource "scratch-init.sh"
$harvestScript = Resolve-HookSource "harvest-session.sh"
$shfixupScript = Resolve-HookSource "sh-file-fixup.sh"
$blockGuideScript = Resolve-HookSource "block-claude-code-guide.sh"
$toolOpsAuditScript = Resolve-HookSource "tool-ops-session-audit.sh"
$dashboardScript = Resolve-HookSource "dashboard-serve.sh"
$delegGuardScript = Resolve-HookSource "delegation-duty-guard.sh"
$harnessDbStartScript = Resolve-HookSource "harness-db-sessionstart.sh"
$harnessDbEndScript = Resolve-HookSource "harness-db-sessionend.sh"
$cmdChannelStopScript = Resolve-HookSource "command-channel-stop.sh"
$fmIdentityStopScript = Resolve-HookSource "failure-mode-identity-stop.sh"
$fmVerifyStopScript = Resolve-HookSource "failure-mode-verify-stop.sh"
foreach ($src in @($hookScript, $guardScript, $glossaryScript, $scratchScript, $harvestScript, $shfixupScript, $blockGuideScript, $toolOpsAuditScript, $dashboardScript, $delegGuardScript, $harnessDbStartScript, $harnessDbEndScript, $cmdChannelStopScript, $fmIdentityStopScript, $fmVerifyStopScript)) {
    if (-not (Test-Path $src)) {
        LogError "Hook script not found: $src"
        exit 1
    }
}

# --- Deploy hook scripts to ~/.claude/hooks/ ---
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"

$hookDest = Join-Path $hooksDir "session-archive.sh"
$guardDest = Join-Path $hooksDir "standing-order-guard.sh"
$glossaryDest = Join-Path $hooksDir "glossary-skill-guard.sh"
$scratchDest = Join-Path $hooksDir "scratch-init.sh"
$harvestDest = Join-Path $hooksDir "harvest-session.sh"
$shfixupDest = Join-Path $hooksDir "sh-file-fixup.sh"
$blockGuideDest = Join-Path $hooksDir "block-claude-code-guide.sh"
$toolOpsAuditDest = Join-Path $hooksDir "tool-ops-session-audit.sh"
$dashboardDest = Join-Path $hooksDir "dashboard-serve.sh"
$delegGuardDest = Join-Path $hooksDir "delegation-duty-guard.sh"
$harnessDbStartDest = Join-Path $hooksDir "harness-db-sessionstart.sh"
$harnessDbEndDest = Join-Path $hooksDir "harness-db-sessionend.sh"
$cmdChannelStopDest = Join-Path $hooksDir "command-channel-stop.sh"
$fmIdentityStopDest = Join-Path $hooksDir "failure-mode-identity-stop.sh"
$fmVerifyStopDest = Join-Path $hooksDir "failure-mode-verify-stop.sh"

$hooksChanged = $false

$hookAdoptLabel = ""
if ($userRepoPath) { $hookAdoptLabel = "dotprofile" }

if ($DryRun) {
    Log "[DRY RUN] Would deploy hook: $hookScript -> $hookDest"
    Log "[DRY RUN] Would deploy hook: $guardScript -> $guardDest"
    Log "[DRY RUN] Would deploy hook: $glossaryScript -> $glossaryDest"
    Log "[DRY RUN] Would deploy hook: $scratchScript -> $scratchDest"
    Log "[DRY RUN] Would deploy hook: $harvestScript -> $harvestDest"
    Log "[DRY RUN] Would deploy hook: $shfixupScript -> $shfixupDest"
    Log "[DRY RUN] Would deploy hook: $blockGuideScript -> $blockGuideDest"
    Log "[DRY RUN] Would deploy hook: $toolOpsAuditScript -> $toolOpsAuditDest"
    Log "[DRY RUN] Would deploy hook: $dashboardScript -> $dashboardDest"
    Log "[DRY RUN] Would deploy hook: $delegGuardScript -> $delegGuardDest"
    Log "[DRY RUN] Would deploy hook: $harnessDbStartScript -> $harnessDbStartDest"
    Log "[DRY RUN] Would deploy hook: $harnessDbEndScript -> $harnessDbEndDest"
    Log "[DRY RUN] Would deploy hook: $cmdChannelStopScript -> $cmdChannelStopDest"
    Log "[DRY RUN] Would deploy hook: $fmIdentityStopScript -> $fmIdentityStopDest"
    Log "[DRY RUN] Would deploy hook: $fmVerifyStopScript -> $fmVerifyStopDest"
    # Stale hook cleanup preview
    foreach ($staleHook in @("surfacing-duty-stop.sh", "estimate-refresh-stop.sh", "intent-sentinel-stop.sh")) {
        if (Test-Path (Join-Path $hooksDir $staleHook)) {
            Log "[DRY RUN] Would remove stale hook: $staleHook"
        }
    }
} else {
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

    Initialize-DeployTracker

    foreach ($pair in @(@($hookScript, $hookDest), @($guardScript, $guardDest), @($glossaryScript, $glossaryDest), @($scratchScript, $scratchDest), @($harvestScript, $harvestDest), @($shfixupScript, $shfixupDest), @($blockGuideScript, $blockGuideDest), @($toolOpsAuditScript, $toolOpsAuditDest), @($dashboardScript, $dashboardDest), @($delegGuardScript, $delegGuardDest), @($harnessDbStartScript, $harnessDbStartDest), @($harnessDbEndScript, $harnessDbEndDest), @($cmdChannelStopScript, $cmdChannelStopDest), @($fmIdentityStopScript, $fmIdentityStopDest), @($fmVerifyStopScript, $fmVerifyStopDest))) {
        $src = $pair[0]; $dst = $pair[1]
        $hookName = Split-Path $dst -Leaf
        $srcContent = Get-Content $src -Raw -ErrorAction Stop

        $hookResult = Deploy-ManagedFile -Content $srcContent -DestPath $dst -ToolName "claude hooks" -ItemName $hookName -AdoptLabel $hookAdoptLabel

        switch ($hookResult) {
            "accept & adopt" {
                if ($userRepoPath) {
                    $adoptDir = Join-Path $userRepoPath "claude\hooks"
                    if (-not (Test-Path $adoptDir)) {
                        New-Item -ItemType Directory -Path $adoptDir -Force | Out-Null
                    }
                    Copy-Item -Path $dst -Destination (Join-Path $adoptDir $hookName) -Force -ErrorAction Stop
                    LogOk "Adopted hook to dotprofile: $hookName"
                } else {
                    LogWarn "Cannot adopt: no user repo configured (run 'aitools user init')"
                }
            }
            { $_ -in @("created", "updated") } {
                $hooksChanged = $true
            }
            { $_ -in @("skipped", "verified") } {
                # No action needed
            }
        }
        Record-DeployOutcome -Outcome $hookResult -ToolName "claude hooks" -ItemName $hookName
    }

    Write-DeployTrackerSummary -ToolName "claude hooks"

    # --- Stale hook cleanup ---
    # Remove hook files that were previously deployed but are no longer managed.
    # These were removed from shared/hooks/ in commit e070043 but remain on disk.
    $staleHooks = @("surfacing-duty-stop.sh", "estimate-refresh-stop.sh", "intent-sentinel-stop.sh")
    foreach ($staleHook in $staleHooks) {
        $stalePath = Join-Path $hooksDir $staleHook
        if (Test-Path $stalePath) {
            Remove-Item $stalePath -Force
            LogOk "Removed stale hook: $staleHook"
            $hooksChanged = $true
        }
        # Also remove any backups of stale hooks
        $bakPattern = Join-Path $hooksDir "$staleHook.bak.*"
        foreach ($bak in Get-ChildItem -Path $bakPattern -File -ErrorAction SilentlyContinue) {
            Remove-Item $bak.FullName -Force
            Log "Removed stale backup: $($bak.Name)"
        }
    }

    # --- Reverse discovery ---
    # Scan deployed hooks for user-created hooks not in shared or dotprofile
    if (Test-Path $hooksDir) {
        foreach ($hookFile in Get-ChildItem -Path $hooksDir -Filter "*.sh" -File) {
            $hookName = $hookFile.Name

            # Skip if in shared
            if (Test-Path (Join-Path $repoDir "shared\hooks\$hookName")) { continue }
            # Skip if in dotprofile
            if ($dotprofileHooks -and (Test-Path (Join-Path $dotprofileHooks $hookName))) { continue }

            # Found a user-created hook
            if ($userRepoPath) {
                Log "Found user-created hook: $hookName"
                try {
                    [Console]::WriteLine("")
                    [Console]::WriteLine("  User-created hook detected: $hookName")
                    [Console]::WriteLine("  [a]dopt to dotprofile  [s]kip")
                    [Console]::Write("  > ")
                    $choice = [Console]::ReadLine()
                } catch {
                    $choice = "s"
                }
                switch ($choice) {
                    { $_ -in @("a", "adopt") } {
                        $adoptDir = Join-Path $userRepoPath "claude\hooks"
                        if (-not (Test-Path $adoptDir)) {
                            New-Item -ItemType Directory -Path $adoptDir -Force | Out-Null
                        }
                        Copy-Item -Path $hookFile.FullName -Destination (Join-Path $adoptDir $hookName) -Force
                        LogOk "Adopted user hook to dotprofile: $hookName"
                    }
                    default {
                        Log "Skipped adoption of $hookName"
                    }
                }
            }
        }
    }
}
# --- END hook deployment (replaced by build-deploy) ---

# --- BEGIN claude preferences (replaced by build-deploy) ---
$autoMemory = $true
$alwaysThinking = $true
$effortLevel = $null
$validEffortLevels = @("low", "medium", "high")

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $profilePath = Join-Path $cfg["userRepoPath"] "profile.json"
            if (Test-Path $profilePath) {
                $pf = ConvertPSObjectToHashtable (Get-Content $profilePath -Raw | ConvertFrom-Json)
                if ($pf.ContainsKey("claude")) {
                    $claudePrefs = $pf["claude"]
                    if ($claudePrefs.ContainsKey("autoMemory")) { $autoMemory = [bool]$claudePrefs["autoMemory"] }
                    if ($claudePrefs.ContainsKey("alwaysThinking")) { $alwaysThinking = [bool]$claudePrefs["alwaysThinking"] }
                    if ($claudePrefs.ContainsKey("effortLevel")) {
                        $val = $claudePrefs["effortLevel"]
                        if ($val -is [string] -and $val -in $validEffortLevels) {
                            $effortLevel = $val
                        } else {
                            LogWarn "Invalid effortLevel '$val' in profile (valid: $($validEffortLevels -join ', '))"
                        }
                    }
                }
            }
        }
    } catch {
        LogWarn "Could not read profile preferences: $_"
    }
}
# --- END claude preferences (replaced by build-deploy) ---

# --- Merge hook + preferences into ~/.claude/settings.json ---
$settingsFile = Join-Path $claudeDir "settings.json"
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
}

# Hook command uses Unix-style path (hooks run in bash even on Windows)
$hookDestPath = Join-Path $hooksDir "session-archive.sh"
$hookDestUnix = $hookDestPath -replace '\\', '/'
$hookCmd = "bash `"$hookDestUnix`""

$shfixupDestUnix = $shfixupDest -replace '\\', '/'
$shfixupCmd = "bash `"$shfixupDestUnix`""

# Read existing settings
$settings = @{}
$corrupt = $false
if (Test-Path $settingsFile) {
    try {
        $raw = Get-Content $settingsFile -Raw
        $settings = ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)
    } catch {
        $corrupt = $true
        LogWarn "$settingsFile could not be parsed ($_)"
    }
}
$beforeKeys = @($settings.Keys)

# --- Merge hooks ---
if (-not $settings.ContainsKey("hooks")) { $settings["hooks"] = @{} }

# Helper: ensure exactly one entry for a hookId in an event array.
# Updates the command if found, adds if not, deduplicates extras.
function MergeHookEntry($eventName, $hookIdentifier, $matcherValue, $cmd, $hookType) {
    if (-not $hookType) { $hookType = "command" }
    if (-not $settings["hooks"].ContainsKey($eventName)) {
        $settings["hooks"][$eventName] = @()
    }
    $arr = @($settings["hooks"][$eventName])

    # Find first matching entry and update it
    $found = $false
    foreach ($rule in $arr) {
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    if (-not $found) {
                        $h["command"] = $cmd
                        $h["type"] = $hookType
                        $rule["matcher"] = $matcherValue
                        $found = $true
                    }
                }
            }
        }
    }
    if (-not $found) {
        $arr += @{
            matcher = $matcherValue
            hooks   = @(@{ type = $hookType; command = $cmd })
        }
    }

    # Normalize: ensure hooks field in each rule is always an array
    # (fixes corruption from prior buggy writes where ConvertTo-Json unwrapped single-element arrays)
    foreach ($rule in $arr) {
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks") -and $rule["hooks"] -isnot [array]) {
            $rule["hooks"] = @($rule["hooks"])
        }
    }

    # Deduplicate: keep only the first entry matching hookIdentifier
    $seen = $false
    $deduped = @()
    foreach ($rule in $arr) {
        $isMatch = $false
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    $isMatch = $true
                    break
                }
            }
        }
        if ($isMatch -and $seen) { continue }
        if ($isMatch) { $seen = $true }
        $deduped += $rule
    }
    $settings["hooks"][$eventName] = $deduped
}

# Helper: remove all entries for a hookId from an event array.
# Used to clean up stale hook registrations after hooks are deleted.
function RemoveHookEntry($eventName, $hookIdentifier) {
    if (-not $settings["hooks"].ContainsKey($eventName)) { return }
    $arr = @($settings["hooks"][$eventName])
    $filtered = @()
    foreach ($rule in $arr) {
        $isMatch = $false
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    $isMatch = $true
                    break
                }
            }
        }
        if (-not $isMatch) { $filtered += $rule }
    }
    if ($filtered.Count -eq 0) {
        $settings["hooks"].Remove($eventName)
    } else {
        $settings["hooks"][$eventName] = $filtered
    }
}

# Remove stale Stop hooks (deleted from shared/hooks/ in commit e070043)
RemoveHookEntry "Stop" "surfacing-duty-stop.sh"
RemoveHookEntry "Stop" "estimate-refresh-stop.sh"
RemoveHookEntry "Stop" "intent-sentinel-stop.sh"

# SessionEnd: session archive
MergeHookEntry "SessionEnd" "session-archive.sh" "" $hookCmd

# PreToolUse: standing order guard
$guardDestUnix = $guardDest -replace '\\', '/'
$guardCmd = "bash `"$guardDestUnix`""
MergeHookEntry "PreToolUse" "standing-order-guard.sh" "Bash" $guardCmd

# PreToolUse: glossary skill guard
$glossaryDestUnix = (Join-Path $hooksDir "glossary-skill-guard.sh") -replace '\\', '/'
$glossaryCmd = "bash `"$glossaryDestUnix`""
MergeHookEntry "PreToolUse" "glossary-skill-guard.sh" "Read|Grep" $glossaryCmd
MergeHookEntry "PostToolUse" "sh-file-fixup.sh" "Write|Edit" $shfixupCmd

# PreToolUse: block claude-code-guide subagent
$blockGuideDestUnix = $blockGuideDest -replace '\\', '/'
$blockGuideCmd = "bash `"$blockGuideDestUnix`""
MergeHookEntry "PreToolUse" "block-claude-code-guide.sh" "Agent" $blockGuideCmd

# SessionEnd: tool-ops session audit
$toolOpsAuditDestUnix = $toolOpsAuditDest -replace '\\', '/'
$toolOpsAuditCmd = "bash `"$toolOpsAuditDestUnix`""
MergeHookEntry "SessionEnd" "tool-ops-session-audit.sh" "" $toolOpsAuditCmd

# SessionStart: dashboard server
$dashboardDestUnix = $dashboardDest -replace '\\', '/'
$dashboardCmd = "bash `"$dashboardDestUnix`""
MergeHookEntry "SessionStart" "dashboard-serve.sh" "" $dashboardCmd

# PreToolUse: delegation duty guard
$delegGuardDestUnix = $delegGuardDest -replace '\\', '/'
$delegGuardCmd = "bash `"$delegGuardDestUnix`""
MergeHookEntry "PreToolUse" "delegation-duty-guard.sh" "Agent" $delegGuardCmd

# SessionStart: harness DB initialization
$harnessDbStartDestUnix = $harnessDbStartDest -replace '\\', '/'
$harnessDbStartCmd = "bash `"$harnessDbStartDestUnix`""
MergeHookEntry "SessionStart" "harness-db-sessionstart.sh" "" $harnessDbStartCmd

# SessionEnd: harness DB session end + export
$harnessDbEndDestUnix = $harnessDbEndDest -replace '\\', '/'
$harnessDbEndCmd = "bash `"$harnessDbEndDestUnix`""
MergeHookEntry "SessionEnd" "harness-db-sessionend.sh" "" $harnessDbEndCmd

# Stop: command channel
$cmdChannelStopDestUnix = $cmdChannelStopDest -replace '\\', '/'
$cmdChannelStopCmd = "bash `"$cmdChannelStopDestUnix`""
MergeHookEntry "Stop" "command-channel-stop.sh" "" $cmdChannelStopCmd

# Stop: failure mode identity
$fmIdentityStopDestUnix = $fmIdentityStopDest -replace '\\', '/'
$fmIdentityStopCmd = "bash `"$fmIdentityStopDestUnix`""
MergeHookEntry "Stop" "failure-mode-identity-stop.sh" "" $fmIdentityStopCmd

# Stop: failure mode verify
$fmVerifyStopDestUnix = $fmVerifyStopDest -replace '\\', '/'
$fmVerifyStopCmd = "bash `"$fmVerifyStopDestUnix`""
MergeHookEntry "Stop" "failure-mode-verify-stop.sh" "" $fmVerifyStopCmd

# --- Track old values for change reporting ---
$oldAutoMemory = $settings["autoMemoryEnabled"]
$oldAlwaysThinking = $settings["alwaysThinkingEnabled"]
$oldEffortLevel = $settings["effortLevel"]

# --- Merge claude preferences ---
$settings["autoMemoryEnabled"] = $autoMemory
$settings["alwaysThinkingEnabled"] = $alwaysThinking
if ($effortLevel) { $settings["effortLevel"] = $effortLevel }

# --- Detect preference changes ---
$prefChanges = @()
if ($oldAutoMemory -ne $settings["autoMemoryEnabled"]) {
    $oldVal = if ($null -ne $oldAutoMemory) { $oldAutoMemory } else { "(not set)" }
    $prefChanges += "autoMemoryEnabled: $oldVal -> $($settings['autoMemoryEnabled'])"
}
if ($oldAlwaysThinking -ne $settings["alwaysThinkingEnabled"]) {
    $oldVal = if ($null -ne $oldAlwaysThinking) { $oldAlwaysThinking } else { "(not set)" }
    $prefChanges += "alwaysThinkingEnabled: $oldVal -> $($settings['alwaysThinkingEnabled'])"
}
if ($effortLevel -and $oldEffortLevel -ne $settings["effortLevel"]) {
    $oldEL = if ($oldEffortLevel) { $oldEffortLevel } else { "(not set)" }
    $prefChanges += "effortLevel: $oldEL -> $($settings['effortLevel'])"
}

# --- Clobber detection ---
$managedKeys = @("hooks", "autoMemoryEnabled", "alwaysThinkingEnabled", "effortLevel")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $settings.Keys })

if ($DryRun) {
    Log "[DRY RUN] $settingsFile`: merge"
    Log "  Managed fields: $($managedKeys -join ', ')"
    if ($lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
    Log "[DRY RUN] SessionEnd hook: $hookCmd"
    Log "[DRY RUN] PreToolUse hook: $guardCmd"
    Log "[DRY RUN] autoMemoryEnabled: $autoMemory"
    Log "[DRY RUN] alwaysThinkingEnabled: $alwaysThinking"
    if ($effortLevel) { Log "[DRY RUN] effortLevel: $effortLevel" }
} else {
    if ($corrupt -and -not $Force) {
        LogError "$settingsFile is corrupt. Use -Force to overwrite, or fix manually."
        Write-Summary "ERROR" "claude hooks" "settings corrupt"
    } elseif ($lostKeys.Count -gt 0 -and -not $Force) {
        LogError "$settingsFile merge would lose fields: $($lostKeys -join ', '). Use -Force to proceed."
        Write-Summary "ERROR" "claude hooks" "merge would lose fields"
    } else {
        if ($corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
        if ($lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: $($lostKeys -join ', ')" }

        $mergedJson = $settings | ConvertTo-Json -Depth 10
        $mergedNorm = Normalize-JsonForComparison $settings -Depth 10
        $existingNorm = if (Test-Path $settingsFile) {
            try { Normalize-JsonForComparison (ConvertPSObjectToHashtable (Get-Content $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json)) -Depth 10 }
            catch { $null }
        } else { $null }
        if ($mergedNorm -eq $existingNorm) {
            LogOk "Settings unchanged: $settingsFile"
        } else {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($settingsFile)
            [System.IO.File]::WriteAllText($resolvedPath, $mergedJson, [System.Text.UTF8Encoding]::new($false))
            $hooksChanged = $true

            # Post-write validation
            try {
                $vContent = [System.IO.File]::ReadAllText($resolvedPath)
                $vParsed = $vContent | ConvertFrom-Json
                $requiredKeys = @("hooks", "autoMemoryEnabled", "alwaysThinkingEnabled")
                if ($effortLevel) { $requiredKeys += "effortLevel" }
                foreach ($rk in $requiredKeys) {
                    if (-not ($vParsed.PSObject.Properties.Name -contains $rk)) {
                        LogError "Validation failed: $settingsFile missing required field '$rk'"
                    }
                }
            } catch {
                LogError "Validation failed: $settingsFile is not valid JSON -- $_"
            }

            # Validate hook deduplication
            $seCount = @($vParsed.hooks.SessionEnd | Where-Object { $_.hooks.command -match 'session-archive\.sh' }).Count
            $ptCount = @($vParsed.hooks.PreToolUse | Where-Object { $_.hooks.command -match 'standing-order-guard\.sh' }).Count
            $glCount = @($vParsed.hooks.PreToolUse | Where-Object { $_.hooks.command -match 'glossary-skill-guard\.sh' }).Count
            if ($seCount -ne 1) { LogError "Validation failed: expected 1 SessionEnd hook, got $seCount" }
            if ($ptCount -ne 1) { LogError "Validation failed: expected 1 PreToolUse standing-order-guard hook, got $ptCount" }
            if ($glCount -ne 1) { LogError "Validation failed: expected 1 PreToolUse glossary-skill-guard hook, got $glCount" }
            $bgCount = @($vParsed.hooks.PreToolUse | Where-Object { $_.hooks.command -match 'block-claude-code-guide\.sh' }).Count
            if ($bgCount -ne 1) { LogError "Validation failed: expected 1 PreToolUse block-claude-code-guide hook, got $bgCount" }
            $toaCount = @($vParsed.hooks.SessionEnd | Where-Object { $_.hooks.command -match 'tool-ops-session-audit\.sh' }).Count
            if ($toaCount -ne 1) { LogError "Validation failed: expected 1 SessionEnd tool-ops-session-audit hook, got $toaCount" }
            $dashCount = @($vParsed.hooks.SessionStart | Where-Object { $_.hooks.command -match 'dashboard-serve\.sh' }).Count
            if ($dashCount -ne 1) { LogError "Validation failed: expected 1 SessionStart dashboard-serve hook, got $dashCount" }
            $dgCount = @($vParsed.hooks.PreToolUse | Where-Object { $_.hooks.command -match 'delegation-duty-guard\.sh' }).Count
            if ($dgCount -ne 1) { LogError "Validation failed: expected 1 PreToolUse delegation-duty-guard hook, got $dgCount" }
            $hdbStartCount = @($vParsed.hooks.SessionStart | Where-Object { $_.hooks.command -match 'harness-db-sessionstart\.sh' }).Count
            if ($hdbStartCount -ne 1) { LogError "Validation failed: expected 1 SessionStart harness-db-sessionstart hook, got $hdbStartCount" }
            $hdbEndCount = @($vParsed.hooks.SessionEnd | Where-Object { $_.hooks.command -match 'harness-db-sessionend\.sh' }).Count
            if ($hdbEndCount -ne 1) { LogError "Validation failed: expected 1 SessionEnd harness-db-sessionend hook, got $hdbEndCount" }
            $ccStopCount = @($vParsed.hooks.Stop | Where-Object { $_.hooks.command -match 'command-channel-stop\.sh' }).Count
            if ($ccStopCount -ne 1) { LogError "Validation failed: expected 1 Stop command-channel-stop hook, got $ccStopCount" }
            $fmiStopCount = @($vParsed.hooks.Stop | Where-Object { $_.hooks.command -match 'failure-mode-identity-stop\.sh' }).Count
            if ($fmiStopCount -ne 1) { LogError "Validation failed: expected 1 Stop failure-mode-identity-stop hook, got $fmiStopCount" }
            $fmvStopCount = @($vParsed.hooks.Stop | Where-Object { $_.hooks.command -match 'failure-mode-verify-stop\.sh' }).Count
            if ($fmvStopCount -ne 1) { LogError "Validation failed: expected 1 Stop failure-mode-verify-stop hook, got $fmvStopCount" }

            # Validate hook schema: command-type must have command,
            # prompt-type must have prompt (not command).
            foreach ($eventName in $vParsed.hooks.PSObject.Properties.Name) {
                foreach ($rule in @($vParsed.hooks.$eventName)) {
                    foreach ($h in @($rule.hooks)) {
                        if ($h.type -eq "command" -and -not $h.command) {
                            LogError "Validation failed: $eventName hook has type 'command' but no command field"
                        }
                        if ($h.type -eq "prompt") {
                            if (-not $h.prompt) {
                                LogError "Validation failed: $eventName hook has type 'prompt' but no prompt field. Prompt-type hooks require a static string."
                            }
                            if ($h.command) {
                                LogError "Validation failed: $eventName hook has type 'prompt' with command field. Use type 'command' for scripts."
                            }
                        }
                    }
                }
            }

            LogOk "Settings deployed to $settingsFile"
            Log "  SessionEnd hook: $hookCmd"
            Log "  PreToolUse hook: $guardCmd"
            Log "  autoMemoryEnabled: $autoMemory"
            Log "  alwaysThinkingEnabled: $alwaysThinking"
            $effortDisplay = if ($effortLevel) { $effortLevel } else { "(not set)" }
            Log "  effortLevel: $effortDisplay"
            if ($prefChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $prefChanges -ToolName "claude hooks"
            }
        }
    }
}
# --- END hooks body (extracted by build-deploy) ---

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
