# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: reference/tool-registry.md
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#
# Managed fields: version, editor, permissions, model, hasChangedDefaultModel
# Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields

# --- BEGIN cursor body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-cursor"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

$cursorDir = Join-Path $env:USERPROFILE ".cursor"
$cliConfig = Join-Path $cursorDir "cli-config.json"

# Track status for summary
$status = @{
    ripgrep   = ""
    cursorCli = ""
    cliConfig = ""
}

# --- 1. ripgrep (rg) ---

Log "Step 1: ripgrep (rg)"

if ($DryRun) {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        Log "[DRY RUN] ripgrep already installed: $rgVersion"
        $status.ripgrep = "already installed ($rgVersion)"
    } else {
        Log "[DRY RUN] Would install ripgrep via winget"
        $status.ripgrep = "would install"
    }
} else {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        LogOk "Already installed: $rgVersion"
        $status.ripgrep = "already installed ($rgVersion)"
    } else {
        Log "Installing ripgrep via winget..."
        winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements
        Refresh-Path

        $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
        if ($rgCmd) {
            $rgVersion = (rg --version | Select-Object -First 1)
            LogOk "Installed: $rgVersion"
            $status.ripgrep = "installed ($rgVersion)"
        } else {
            LogWarn "winget install completed but 'rg' not found in PATH. Restart terminal to verify."
            $status.ripgrep = "installed (restart terminal to verify)"
        }
    }
}

# --- 2. Cursor CLI (agent) ---

Log "Step 2: Cursor CLI (agent)"

if ($DryRun) {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        Log "[DRY RUN] Cursor CLI already installed: $agentVersion"
        $status.cursorCli = "already installed ($agentVersion)"
    } else {
        Log "[DRY RUN] Would install Cursor CLI"
        $status.cursorCli = "would install"
    }
} else {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        LogOk "Already installed: $agentVersion"
        $status.cursorCli = "already installed ($agentVersion)"
    } else {
        Log "Installing Cursor CLI..."
        Invoke-Expression (Invoke-RestMethod 'https://cursor.com/install?win32=true')

        $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
        if ($agentCmd) {
            $agentVersion = agent --version
            LogOk "Installed: $agentVersion"
            $status.cursorCli = "installed ($agentVersion)"
        } else {
            LogWarn "Cursor CLI install completed but 'agent' not found in PATH. Restart terminal to verify."
            $status.cursorCli = "installed (restart terminal to verify)"
        }
    }
}

# --- 3. cli-config.json (merge, not overwrite) ---

Log "Step 3: cli-config.json"

# --- BEGIN profile preferences (replaced by build-deploy) ---
# config.json -> userRepoPath -> profile.json -> cursor.cli prefs
$vimMode = $false
$modelId = "auto"

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $profilePath = Join-Path $cfg["userRepoPath"] "profile.json"
            if (Test-Path $profilePath) {
                $pf = ConvertPSObjectToHashtable (Get-Content $profilePath -Raw | ConvertFrom-Json)
                if ($pf.ContainsKey("cursor") -and $pf["cursor"].ContainsKey("cli")) {
                    $cli = $pf["cursor"]["cli"]
                    if ($cli.ContainsKey("vimMode")) { $vimMode = [bool]$cli["vimMode"] }
                    if ($cli.ContainsKey("model")) { $modelId = [string]$cli["model"] }
                }
            }
        }
    } catch {
        LogWarn "Could not read profile preferences: $_"
    }
}
# --- END profile preferences (replaced by build-deploy) ---

# Back up before merge
if (-not $DryRun) {
    Backup-File -FilePath $cliConfig
}

# Ensure ~/.cursor/ exists
if (-not (Test-Path $cursorDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
        Log "Created $cursorDir"
    }
}

# --- Read existing cli-config.json ---
$config = @{}
$corrupt = $false
if (Test-Path $cliConfig) {
    try {
        $config = ConvertPSObjectToHashtable (Get-Content $cliConfig -Raw | ConvertFrom-Json)
    } catch {
        $corrupt = $true
        LogWarn "$cliConfig could not be parsed ($_)"
    }
}
$beforeKeys = @($config.Keys)
$beforeJson = Normalize-JsonForComparison $config -Depth 10

# Snapshot managed keys before merge for change tracking
$managedKeysList = @("version", "editor", "permissions", "model", "hasChangedDefaultModel")
$beforeManaged = @{}
foreach ($k in $managedKeysList) {
    if ($config.ContainsKey($k)) {
        $beforeManaged[$k] = Normalize-JsonForComparison $config[$k] -Depth 5 -Compress
    } else {
        $beforeManaged[$k] = $null
    }
}

# --- Merge managed fields ---
$config["version"] = 1
if (-not $config.ContainsKey("editor")) { $config["editor"] = @{} }
$config["editor"]["vimMode"] = $vimMode
if (-not $config.ContainsKey("permissions")) { $config["permissions"] = @{} }
if (-not $config["permissions"].ContainsKey("allow")) { $config["permissions"]["allow"] = @() }
if (-not $config["permissions"].ContainsKey("deny")) { $config["permissions"]["deny"] = @() }

# Model: only set if profile specifies 'auto' (the only supported value for now)
if ($modelId -eq "auto") {
    $config["model"] = @{
        modelId          = "default"
        displayModelId   = "auto"
        displayName      = "Auto"
        displayNameShort = "Auto"
        aliases          = @("auto")
        maxMode          = $false
    }
    $config["hasChangedDefaultModel"] = $true
}

# --- Clobber detection ---
$managedKeys = @("version", "editor", "permissions", "model", "hasChangedDefaultModel")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $config.Keys })

$afterJson = Normalize-JsonForComparison $config -Depth 10

if ($DryRun) {
    # --- Dry-run output ---
    Log "[DRY RUN] $cliConfig`: merge"
    Log "  Managed fields: $($managedKeys -join ', ')"
    if ($lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
    if ($beforeJson -eq $afterJson -and -not $corrupt) {
        Log "[DRY RUN] No changes needed (already up to date)"
        $status.cliConfig = "already up to date (dry-run)"
    } else {
        Log "[DRY RUN] Would write merged config"
        $status.cliConfig = "would merge (dry-run)"
    }
} else {
    # --- Normal mode ---
    if ($corrupt -and -not $Force) {
        LogError "$cliConfig is corrupt. Use -Force to overwrite, or fix manually."
        $status.cliConfig = "ERROR (corrupt, needs -Force)"
        Write-Summary "ERROR" "cursor cli" "config corrupt"
    } elseif ($lostKeys.Count -gt 0 -and -not $Force) {
        LogError "$cliConfig merge would lose fields: $($lostKeys -join ', '). Use -Force to proceed."
        $status.cliConfig = "ERROR (clobber, needs -Force)"
        Write-Summary "ERROR" "cursor cli" "merge would lose fields"
    } elseif ($beforeJson -eq $afterJson -and -not $corrupt) {
        LogOk "Already up to date: $cliConfig"
        $status.cliConfig = "already up to date"
        Write-Summary "OK" "cursor cli" "verified"
    } else {
        if ($corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
        if ($lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: $($lostKeys -join ', ')" }

        $json = $config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText(
            $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($cliConfig),
            $json,
            [System.Text.UTF8Encoding]::new($false)
        )

        # Post-write validation
        try {
            $vContent = [System.IO.File]::ReadAllText(
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($cliConfig)
            )
            $vParsed = $vContent | ConvertFrom-Json
            if (-not ($vParsed.PSObject.Properties.Name -contains "version")) {
                LogError "Validation failed: $cliConfig missing required field 'version'"
            }
        } catch {
            LogError "Validation failed: $cliConfig is not valid JSON -- $_"
        }

        # Detect per-key changes and emit DETAIL lines
        $keyChanges = @()
        foreach ($k in $managedKeysList) {
            $newVal = if ($config.ContainsKey($k)) { Normalize-JsonForComparison $config[$k] -Depth 5 -Compress } else { $null }
            if ($beforeManaged[$k] -ne $newVal) {
                $oldDisplay = if ($beforeManaged[$k]) { $beforeManaged[$k] } else { "(unset)" }
                $newDisplay = if ($newVal) { $newVal } else { "(removed)" }
                $keyChanges += "${k}: $oldDisplay -> $newDisplay"
            }
        }

        if ($beforeKeys.Count -eq 0) {
            LogOk "Created: $cliConfig"
            $status.cliConfig = "created"
            if ($keyChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $keyChanges -ToolName "cursor cli"
            }
            Write-Summary "OK" "cursor cli" "created"
        } else {
            LogOk "Merged preferences into: $cliConfig"
            $status.cliConfig = "merged"
            if ($keyChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $keyChanges -ToolName "cursor cli"
            }
            Write-Summary "OK" "cursor cli" "updated"
        }
    }
}

# --- END cursor body (extracted by build-deploy) ---

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
