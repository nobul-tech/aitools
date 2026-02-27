# setup-user-hooks.ps1 -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Adds a SessionEnd hook that archives session transcripts to the user repo.
# Reads claude preferences from profile.json (via config.json -> userRepoPath).
# See reference/user-repo.md and shared/hooks/session-archive.sh for details.
#
# Note: The hook script itself is bash-only (Claude Code hooks always run in
# bash on both platforms). This PS1 script only deploys the hook configuration.

param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-hooks"
$errors = 0
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }

# --- PS 5.1 compatibility helper ---
function ConvertPSObjectToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    $ht = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            $ht[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- Resolve repo path ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

$hookScript = Join-Path $repoDir "shared\hooks\session-archive.sh"
if (-not (Test-Path $hookScript)) {
    LogError "Hook script not found: $hookScript"
    exit 1
}

# --- Deploy hook script to ~/.claude/hooks/ ---
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"

if ($DryRun) {
    Log "[DRY RUN] Would deploy hook: $hookScript -> $(Join-Path $hooksDir 'session-archive.sh')"
} else {
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

    $hookDest = Join-Path $hooksDir "session-archive.sh"
    Copy-Item -Path $hookScript -Destination $hookDest -Force
    LogOk "Deployed hook: $hookDest"
}

# --- Read claude preferences from profile.json ---
$autoMemory = $true
$alwaysThinking = $true

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
                }
            }
        }
    } catch {
        LogWarn "Could not read profile preferences: $_"
    }
}

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

# --- Merge hook ---
if (-not $settings.ContainsKey("hooks")) { $settings["hooks"] = @{} }
if (-not $settings["hooks"].ContainsKey("SessionEnd")) { $settings["hooks"]["SessionEnd"] = @() }

$hookId = "session-archive.sh"
$existingIdx = -1
$sessionEndArr = @($settings["hooks"]["SessionEnd"])
for ($i = 0; $i -lt $sessionEndArr.Count; $i++) {
    $rule = $sessionEndArr[$i]
    if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
        $hooksArr = @($rule["hooks"])
        foreach ($h in $hooksArr) {
            if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match $hookId) {
                $existingIdx = $i
                break
            }
        }
    }
    if ($existingIdx -ge 0) { break }
}

if ($existingIdx -ge 0) {
    # Update existing hook command
    $rule = $sessionEndArr[$existingIdx]
    $hooksArr = @($rule["hooks"])
    for ($i = 0; $i -lt $hooksArr.Count; $i++) {
        $h = $hooksArr[$i]
        if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match $hookId) {
            $h["command"] = $hookCmd
        }
    }
} else {
    # Add new hook entry
    $newEntry = @{
        matcher = ""
        hooks   = @(
            @{
                type    = "command"
                command = $hookCmd
            }
        )
    }
    $sessionEndArr += $newEntry
    $settings["hooks"]["SessionEnd"] = $sessionEndArr
}

# --- Merge claude preferences ---
$settings["autoMemoryEnabled"] = $autoMemory
$settings["alwaysThinkingEnabled"] = $alwaysThinking

# --- Clobber detection ---
$managedKeys = @("hooks", "autoMemoryEnabled", "alwaysThinkingEnabled")
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
    Log "[DRY RUN] Hook: $hookCmd"
    Log "[DRY RUN] autoMemoryEnabled: $autoMemory"
    Log "[DRY RUN] alwaysThinkingEnabled: $alwaysThinking"
} else {
    if ($corrupt -and -not $Force) {
        LogError "$settingsFile is corrupt. Use -Force to overwrite, or fix manually."
    } elseif ($lostKeys.Count -gt 0 -and -not $Force) {
        LogError "$settingsFile merge would lose fields: $($lostKeys -join ', '). Use -Force to proceed."
    } else {
        if ($corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
        if ($lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: $($lostKeys -join ', ')" }

        $json = $settings | ConvertTo-Json -Depth 10
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($settingsFile)
        [System.IO.File]::WriteAllText($resolvedPath, $json, [System.Text.UTF8Encoding]::new($false))

        # Post-write validation
        try {
            $vContent = [System.IO.File]::ReadAllText($resolvedPath)
            $vParsed = $vContent | ConvertFrom-Json
            $requiredKeys = @("hooks", "autoMemoryEnabled", "alwaysThinkingEnabled")
            foreach ($rk in $requiredKeys) {
                if (-not ($vParsed.PSObject.Properties.Name -contains $rk)) {
                    LogError "Validation failed: $settingsFile missing required field '$rk'"
                }
            }
        } catch {
            LogError "Validation failed: $settingsFile is not valid JSON -- $_"
        }

        LogOk "Settings deployed to $settingsFile"
        Log "  Hook: $hookCmd"
        Log "  autoMemoryEnabled: $autoMemory"
        Log "  alwaysThinkingEnabled: $alwaysThinking"
    }
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
