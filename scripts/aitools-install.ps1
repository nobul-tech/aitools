# aitools-install.ps1 -- Install aitools command + configure environment
# Run once for first-time setup, or re-run via `aitools` to stay current.
#
# Installs/updates gh CLI, configures repos directory, auto-detects Google
# Drive mounts, writes ~/.aitools/config.json, installs the
# aitools command to ~/.local/bin/, adds shell integration, and deploys
# all configuration scripts.

param(
    [string]$ReposPath = "",
    [switch]$SkipDriveDetection,
    [switch]$SkipGhAuth,
    [switch]$DryRun,
    [switch]$Help
)

if ($Help) {
    @"
aitools-install.ps1 -- Install aitools command + configure environment

Usage: .\scripts\aitools-install.ps1 [OPTIONS]

Options:
  -ReposPath <string>       Set repos directory without prompting (default: ~/repos)
  -SkipDriveDetection       Skip Google Drive auto-detection
  -SkipGhAuth               Skip gh auth login
  -DryRun                   Preview mode -- show what would change without writing
  -Help                     Show this help

Interactive behavior:
  When stdin is a terminal, prompts for repos path and drive confirmation.
  When piped or run non-interactively, uses defaults and flags.
  When config.json already exists, uses saved values without prompting.
"@
    exit 0
}

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "aitools-install"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# JSONL logging (extends standard pattern with structured JSON)
$logJsonl = Join-Path $logDir "deploy.jsonl"
$runId = if ($env:AITOOLS_RUN_ID) { $env:AITOOLS_RUN_ID } else { -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) }) }
$hostName = $env:COMPUTERNAME
$osName = "Windows"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }
if ($DryRun) { $env:AITOOLS_DRY_RUN = "1" }

# Override: JSONL dual-format (human-readable + structured JSON)
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
    $json = @{ ts=$ts; host=$hostName; os=$osName; script=$scriptName; run_id=$runId; level=$level; msg=$msg } | ConvertTo-Json -Compress
    Add-Content -Path $logJsonl -Value $json
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }

# --- Summary file init (if not already set by parent aitools invocation) ---
if (-not $env:AITOOLS_SUMMARY_FILE) {
    $env:AITOOLS_SUMMARY_FILE = Join-Path $env:USERPROFILE ".aitools\run-summary.txt"
    # Remove stale summary file before creating fresh one; may not exist (expected)
    if (Test-Path $env:AITOOLS_SUMMARY_FILE) {
        Remove-Item $env:AITOOLS_SUMMARY_FILE -Force
    }
    New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
}

# --- Script validation helper ---
# Validates PS1 syntax with ParseFile before executing. Skips with warning on parse errors.
function Invoke-ValidatedScript {
    param([string]$ScriptPath)
    $name = Split-Path $ScriptPath -Leaf
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        LogWarn "$name has parse errors on this PowerShell version -- skipping"
        foreach ($err in $parseErrors) {
            Log "  line $($err.Extent.StartLineNumber): $($err.Message)" "warn"
        }
        return
    }
    try { & $ScriptPath } catch { LogError "$name failed: $_" }
}

# --- Post-write JSON validation ---
# Validates a JSON config file after writing: checks non-empty, valid JSON,
# required keys present, and no double-slash paths (excluding protocol prefixes).
function ValidateJsonConfig {
    param([string]$File, [string[]]$RequiredKeys)
    if (-not (Test-Path $File) -or (Get-Item $File).Length -eq 0) {
        LogError "Validation failed: $File is empty or missing"
        return
    }
    try {
        $content = [System.IO.File]::ReadAllText($File)
        $parsed = $content | ConvertFrom-Json
    } catch {
        LogError "Validation failed: $File is not valid JSON -- $_"
        return
    }
    foreach ($key in $RequiredKeys) {
        if (-not ($parsed.PSObject.Properties.Name -contains $key)) {
            LogError "Validation failed: $File missing required field '$key'"
        }
    }
    # Double-slash path check (skip protocol prefixes)
    if ($content -match '"[^"]*(?<!https?:)//[^"]*"') {
        LogError "Validation failed: $File contains double-slash in path value"
    }
}

# --- Config file setup ---
$configDir = Join-Path $env:USERPROFILE ".aitools"
$configFile = Join-Path $configDir "config.json"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

# Auto-detect aitools repo path from this script's location
$aitoolsRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# ============================================================
# 0. System prerequisites (Windows long paths)
# ============================================================
# Windows has a 260-char path limit by default. Many tools (git, cargo, node)
# need longer paths. Enable both the OS-level setting and git's own flag.
$longPathsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
$longPathsEnabled = $false
try {
    $val = Get-ItemProperty $longPathsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue
    if ($val -and $val.LongPathsEnabled -eq 1) { $longPathsEnabled = $true }
} catch {
    # Registry read failed -- treat as disabled
}

if ($longPathsEnabled) {
    LogOk "Windows long paths enabled"
} else {
    LogWarn "Windows long paths disabled (LongPathsEnabled=0) -- cargo/git may fail on deep paths"
    LogWarn "Fix (run as admin): Set-ItemProperty '$longPathsKey' -Name LongPathsEnabled -Value 1"
    Write-Summary "ACTION" "" "Enable long paths (admin): Set-ItemProperty '$longPathsKey' -Name LongPathsEnabled -Value 1"
}

# git core.longpaths -- can set without elevation
$gitLongPaths = git config --global core.longpaths 2>$null
if ($gitLongPaths -ne "true") {
    Log "Setting git config --global core.longpaths true..."
    git config --global core.longpaths true
    LogOk "git core.longpaths enabled"
} else {
    LogOk "git core.longpaths already enabled"
}

# ============================================================
# 1. Install/update gh CLI
# ============================================================
Log "Step 1: gh CLI"

$ghScript = Join-Path $PSScriptRoot "setup-gh-cli.ps1"
if (Test-Path $ghScript) {
    Invoke-ValidatedScript $ghScript
} else {
    LogWarn "setup-gh-cli.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 2. Authenticate gh
# ============================================================
Log "Step 2: gh authentication"

if ($SkipGhAuth) {
    Log "Skipping gh auth (-SkipGhAuth)"
} elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    LogWarn "gh not installed, skipping auth"
} else {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        LogOk "gh already authenticated"
    } elseif ([Environment]::UserInteractive) {
        Log "Not authenticated. Starting gh auth login..."
        gh auth login
        if ($LASTEXITCODE -ne 0) {
            LogError "gh auth login failed"
        }
    } else {
        LogWarn "Not authenticated and not interactive -- skipping gh auth"
    }
}

# ============================================================
# 3. Configure repos directory
# ============================================================
Log "Step 3: repos directory"

$resolvedReposPath = ""
if ($ReposPath) {
    $resolvedReposPath = $ReposPath -replace '^~', $env:USERPROFILE
    Log "Using repos path from flag: $resolvedReposPath"
} elseif (Test-Path $configFile) {
    # Config exists -- reuse saved value
    try {
        $existingConfig = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($existingConfig.reposPath) {
            $resolvedReposPath = $existingConfig.reposPath
            Log "Using repos path from config: $resolvedReposPath"
        }
    } catch {
        LogWarn "Could not read repos path from config"
    }
}
if (-not $resolvedReposPath) {
    if ([Environment]::UserInteractive) {
        $defaultPath = Join-Path $env:USERPROFILE "repos"
        $userInput = Read-Host "Where should new repos live? [$defaultPath]"
        if ($userInput) {
            $resolvedReposPath = $userInput -replace '^~', $env:USERPROFILE
        } else {
            $resolvedReposPath = $defaultPath
        }
    } else {
        $resolvedReposPath = Join-Path $env:USERPROFILE "repos"
    }
}

if (-not (Test-Path $resolvedReposPath)) {
    New-Item -ItemType Directory -Path $resolvedReposPath -Force | Out-Null
}
LogOk "Repos directory: $resolvedReposPath"

# ============================================================
# 4. Detect Google Drive mounts
# ============================================================
Log "Step 4: Google Drive detection"

$drives = @()

if ($SkipDriveDetection) {
    Log "Skipping drive detection (-SkipDriveDetection)"
} else {
    # Google Drive for Desktop uses a virtual filesystem driver that Get-Volume
    # cannot see. Get-PSDrive finds them via Description: "<email> - Google Drive"
    # (or "<email> - Google ..." when truncated for longer emails).
    $gdDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Description -like "* - Google*" }
    foreach ($gd in $gdDrives) {
        $email = ($gd.Description -replace ' - Google.*$', '')
        $myDrive = Join-Path $gd.Root "My Drive"
        if (Test-Path $myDrive) {
            $drives += @{
                path    = $myDrive
                account = $email
                label   = ""
            }
            LogOk "Detected Google Drive: $email -> $myDrive"
        }
    }

    if ($drives.Count -eq 0) {
        LogWarn "No Google Drive mounts detected"
    }
}

# ============================================================
# 5. Write config file
# ============================================================
Log "Step 5: Writing config"

# If config already exists, preserve fields we don't manage
$existingUserRepoPath = $null
$existingMachineAlias = $null
if (Test-Path $configFile) {
    try {
        $existingConfig = Get-Content $configFile -Raw | ConvertFrom-Json
        # Preserve googleDrives if we didn't detect any
        if (($drives.Count -eq 0) -and $existingConfig.googleDrives -and $existingConfig.googleDrives.Count -gt 0) {
            $drives = @($existingConfig.googleDrives | ForEach-Object {
                @{ path = $_.path; account = $_.account; label = $_.label }
            })
            Log "Preserved existing Google Drive entries from config"
        }
        # Preserve userRepoPath (set by 'aitools user init')
        if ($existingConfig.userRepoPath) {
            $existingUserRepoPath = $existingConfig.userRepoPath
        }
        # Preserve machineAlias (set by 'aitools user init')
        if ($existingConfig.machineAlias) {
            $existingMachineAlias = $existingConfig.machineAlias
        }
    } catch {
        LogWarn "Failed to read existing config, writing fresh"
    }
}

$config = [ordered]@{
    version          = 2
    reposPath        = $resolvedReposPath
    repoPath          = $aitoolsRepo
    googleDrives     = @($drives | ForEach-Object {
        [ordered]@{ path = $_.path; account = $_.account; label = $_.label }
    })
}
if ($existingUserRepoPath) { $config["userRepoPath"] = $existingUserRepoPath }
if ($existingMachineAlias) { $config["machineAlias"] = $existingMachineAlias }

$jsonContent = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($configFile, $jsonContent, [System.Text.UTF8Encoding]::new($false))
LogOk "Config written to $configFile"
ValidateJsonConfig -File $configFile -RequiredKeys @("version", "reposPath", "repoPath")

# ============================================================
# 6. Install aitools command
# ============================================================
Log "Step 6: Install aitools command"

$localBin = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBin)) { New-Item -ItemType Directory -Path $localBin -Force | Out-Null }

# Install bash aitools (for Git Bash compatibility)
$aitoolsSrc = Join-Path $PSScriptRoot "aitools"
$aitoolsDst = Join-Path $localBin "aitools"
if (Test-Path $aitoolsSrc) {
    Copy-Item $aitoolsSrc $aitoolsDst -Force
    LogOk "Installed aitools (bash) to $aitoolsDst"
} else {
    LogWarn "aitools bash source not found (MDM deploy -- skipping)"
}

# Install PowerShell aitools.ps1 (native Windows CLI)
$aitoolsPs1Src = Join-Path $PSScriptRoot "aitools.ps1"
$aitoolsPs1Dst = Join-Path $localBin "aitools.ps1"
if (Test-Path $aitoolsPs1Src) {
    Copy-Item $aitoolsPs1Src $aitoolsPs1Dst -Force
    LogOk "Installed aitools.ps1 to $aitoolsPs1Dst"
} else {
    LogWarn "aitools.ps1 source not found (MDM deploy -- skipping)"
}

# ============================================================
# 7. Shell integration
# ============================================================
Log "Step 7: Shell integration"

$aliasesPath = Join-Path $PSScriptRoot "..\shared\shell\aliases.ps1"
if (Test-Path $aliasesPath) {
    $aliasesAbs = (Resolve-Path $aliasesPath).Path
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    $oldMarker = "# ai-tooling shell integration"
    $marker = "# aitools shell integration"

    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
    } else {
        $content = ""
    }

    # Remove old marker block if present
    if ($content -match [regex]::Escape($oldMarker)) {
        $lines = @(Get-Content $PROFILE)
        $result = @()
        $i = 0
        while ($i -lt $lines.Count) {
            if ($lines[$i] -match [regex]::Escape($oldMarker)) {
                $i++  # skip marker
                while ($i -lt $lines.Count -and $lines[$i].Trim() -ne '') { $i++ }
            } else {
                $result += $lines[$i]
                $i++
            }
        }
        Set-Content $PROFILE -Value ($result -join "`n")
        $content = Get-Content $PROFILE -Raw
        Log "Removed old shell integration marker from $PROFILE"
    }

    $desiredBlock = @"
$marker
. "$aliasesAbs"
function aitools { & "`$HOME\.local\bin\aitools.ps1" @args }
"@

    if ($content -notmatch [regex]::Escape($marker)) {
        Add-Content -Path $PROFILE -Value "`n$desiredBlock"
        LogOk "Added shell integration to $PROFILE"
    } else {
        # Upgrade: remove old block (marker + following non-empty lines), re-add current
        $lines = @(Get-Content $PROFILE)
        $result = @()
        $i = 0
        while ($i -lt $lines.Count) {
            if ($lines[$i] -match [regex]::Escape($marker)) {
                $i++  # skip marker
                while ($i -lt $lines.Count -and $lines[$i].Trim() -ne '') { $i++ }
            } else {
                $result += $lines[$i]
                $i++
            }
        }
        Set-Content $PROFILE -Value (($result -join "`n") + "`n`n$desiredBlock`n")
        LogOk "Updated shell integration in $PROFILE"
    }
} else {
    LogWarn "aliases.ps1 not found -- skipping shell integration (MDM deploy)"
}

# ============================================================
# 8. Node.js
# ============================================================
# Source: https://nodejs.org
Log "Step 8: Node.js"

# Helper: refresh PATH from registry (picks up winget/npm installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

if (Get-Command node -ErrorAction SilentlyContinue) {
    LogOk "Node.js already installed ($(node --version))"
    Write-Summary "OK" "node.js" "$(node --version)"
} else {
    Log "Installing Node.js via winget..."
    $wingetOutput = winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install node failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "node.js" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path
    if (Get-Command node -ErrorAction SilentlyContinue) {
        LogOk "Node.js installed ($(node --version))"
        Write-Summary "OK" "node.js" "$(node --version)"
    } else {
        LogError "Node.js install failed (restart terminal and re-run)"
        Write-Summary "ERROR" "node.js" "install failed (restart terminal)"
    }
}

# ============================================================
# 9. Claude Code CLI
# ============================================================
# Source: https://code.claude.com/docs/en/setup
Log "Step 9: Claude Code CLI"

if (Get-Command claude -ErrorAction SilentlyContinue) {
    LogOk "Claude Code already installed ($(claude --version 2>$null | Select-Object -First 1))"
    Write-Summary "OK" "claude code" "$(claude --version 2>$null | Select-Object -First 1)"
    Log "Running claude update..."
    $claudeOutput = claude update 2>&1 | Out-String
    $claudeOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
    if ($LASTEXITCODE -ne 0) {
        LogWarn "claude update returned non-zero (exit $LASTEXITCODE)"
    }
} else {
    Log "Installing Claude Code CLI..."
    try {
        Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1')
        Refresh-Path
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            LogOk "Claude Code installed ($(claude --version 2>$null | Select-Object -First 1))"
            Write-Summary "OK" "claude code" "$(claude --version 2>$null | Select-Object -First 1)"
        } else {
            LogWarn "Claude Code installed -- restart terminal to use"
            Write-Summary "WARN" "claude code" "installed -- restart terminal to use"
        }
    } catch {
        LogError "Claude Code install failed: $_"
        Write-Summary "ERROR" "claude code" "install failed"
    }
}

# ============================================================
# 10. Vercel CLI
# ============================================================
Log "Step 10: Vercel CLI"

$vercelScript = Join-Path $PSScriptRoot "setup-vercelcli.ps1"
if (Test-Path $vercelScript) {
    Invoke-ValidatedScript $vercelScript
} else {
    LogWarn "setup-vercelcli.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 11. Pandoc
# ============================================================
Log "Step 11: Pandoc"

$pandocScript = Join-Path $PSScriptRoot "setup-pandoc.ps1"
if (Test-Path $pandocScript) {
    Invoke-ValidatedScript $pandocScript
} else {
    LogWarn "setup-pandoc.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 12. Rust (cargo)
# ============================================================
Log "Step 12: Rust (cargo)"

$rustScript = Join-Path $PSScriptRoot "setup-rust.ps1"
if (Test-Path $rustScript) {
    Invoke-ValidatedScript $rustScript
} else {
    LogWarn "setup-rust.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 13. Typst
# ============================================================
Log "Step 13: Typst"

$typstScript = Join-Path $PSScriptRoot "setup-typst.ps1"
if (Test-Path $typstScript) {
    Invoke-ValidatedScript $typstScript
} else {
    LogWarn "setup-typst.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 14. Python
# ============================================================
Log "Step 14: Python"

$pythonScript = Join-Path $PSScriptRoot "setup-python.ps1"
if (Test-Path $pythonScript) {
    Invoke-ValidatedScript $pythonScript
} else {
    LogWarn "setup-python.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 15. uv
# ============================================================
Log "Step 15: uv"

$uvScript = Join-Path $PSScriptRoot "setup-uv.ps1"
if (Test-Path $uvScript) {
    Invoke-ValidatedScript $uvScript
} else {
    LogWarn "setup-uv.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 16. Modal CLI
# ============================================================
Log "Step 16: Modal CLI"

$modalScript = Join-Path $PSScriptRoot "setup-modal.ps1"
if (Test-Path $modalScript) {
    Invoke-ValidatedScript $modalScript
} else {
    LogWarn "setup-modal.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 17. Go
# ============================================================
Log "Step 17: Go"

$goScript = Join-Path $PSScriptRoot "setup-go.ps1"
if (Test-Path $goScript) {
    Invoke-ValidatedScript $goScript
} else {
    LogWarn "setup-go.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 18. Datadog CLI
# ============================================================
Log "Step 18: Datadog CLI"

$datadogScript = Join-Path $PSScriptRoot "setup-datadog.ps1"
if (Test-Path $datadogScript) {
    Invoke-ValidatedScript $datadogScript
} else {
    LogWarn "setup-datadog.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 19. Perl
# ============================================================
Log "Step 19: Perl"

$perlScript = Join-Path $PSScriptRoot "setup-perl.ps1"
if (Test-Path $perlScript) {
    Invoke-ValidatedScript $perlScript
} else {
    LogWarn "setup-perl.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 20. Deploy configurations
# ============================================================
Log "Step 20: Deploy configurations"

$deployScripts = @(
    "setup-user-claude.ps1",
    "setup-user-cursor.ps1",
    "setup-user-mcp.ps1",
    "setup-user-skills.ps1",
    "setup-cursor-ide-mcp.ps1",
    "setup-user-hooks.ps1"
)

foreach ($script in $deployScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (Test-Path $scriptPath) {
        Invoke-ValidatedScript $scriptPath
    } else {
        LogWarn "$script not found -- skipping"
    }
}

# --- Cleanup ---
if ($DryRun) { Remove-Item Env:\AITOOLS_DRY_RUN -ErrorAction SilentlyContinue }

if (-not $env:AITOOLS_SUPPRESS_SUMMARY_DISPLAY) { Show-Summary }

# --- Exit ---
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
