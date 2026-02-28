# setup-user-hooks.ps1 -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.PreToolUse, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)
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
# Recursively converts PSCustomObject (from ConvertFrom-Json) to Hashtable.
# Also recurses into arrays so nested objects in JSON arrays become hashtables.
function ConvertPSObjectToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    if ($obj -is [array]) {
        # Leading comma prevents PowerShell from unwrapping single-element arrays
        return ,@($obj | ForEach-Object { ConvertPSObjectToHashtable $_ })
    }
    if ($obj -isnot [System.Management.Automation.PSCustomObject]) { return $obj }
    $ht = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        $ht[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
    }
    return $ht
}

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

$hookScript = Join-Path $repoDir "shared\hooks\session-archive.sh"
$guardScript = Join-Path $repoDir "shared\hooks\standing-order-guard.sh"
foreach ($src in @($hookScript, $guardScript)) {
    if (-not (Test-Path $src)) {
        LogError "Hook script not found: $src"
        exit 1
    }
}

# --- Deploy hook script to ~/.claude/hooks/ ---
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"

$hookDest = Join-Path $hooksDir "session-archive.sh"
$guardDest = Join-Path $hooksDir "standing-order-guard.sh"

if ($DryRun) {
    Log "[DRY RUN] Would deploy hook: $hookScript -> $hookDest"
    Log "[DRY RUN] Would deploy hook: $guardScript -> $guardDest"
} else {
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

    Copy-Item -Path $hookScript -Destination $hookDest -Force
    LogOk "Deployed hook: $hookDest"
    Copy-Item -Path $guardScript -Destination $guardDest -Force
    LogOk "Deployed hook: $guardDest"
}
# --- END hook deployment (replaced by build-deploy) ---

# --- BEGIN claude preferences (replaced by build-deploy) ---
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
function MergeHookEntry($eventName, $hookIdentifier, $matcherValue, $cmd) {
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
            hooks   = @(@{ type = "command"; command = $cmd })
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

# SessionEnd: session archive
MergeHookEntry "SessionEnd" "session-archive.sh" "" $hookCmd

# PreToolUse: standing order guard
$guardDestUnix = $guardDest -replace '\\', '/'
$guardCmd = "bash `"$guardDestUnix`""
MergeHookEntry "PreToolUse" "standing-order-guard.sh" "Bash" $guardCmd

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
    Log "[DRY RUN] SessionEnd hook: $hookCmd"
    Log "[DRY RUN] PreToolUse hook: $guardCmd"
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

        # Validate hook deduplication
        $seCount = @($vParsed.hooks.SessionEnd | Where-Object { $_.hooks.command -match 'session-archive\.sh' }).Count
        $ptCount = @($vParsed.hooks.PreToolUse | Where-Object { $_.hooks.command -match 'standing-order-guard\.sh' }).Count
        if ($seCount -ne 1) { LogError "Validation failed: expected 1 SessionEnd hook, got $seCount" }
        if ($ptCount -ne 1) { LogError "Validation failed: expected 1 PreToolUse hook, got $ptCount" }

        LogOk "Settings deployed to $settingsFile"
        Log "  SessionEnd hook: $hookCmd"
        Log "  PreToolUse hook: $guardCmd"
        Log "  autoMemoryEnabled: $autoMemory"
        Log "  alwaysThinkingEnabled: $alwaysThinking"
    }
}
# --- END hooks body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
