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
  When stdin is a terminal, prompts for gh login, repos path, and file reviews.
  When piped or run non-interactively, uses defaults and flags.
  AITOOLS_FORCE=1 (aitools install --force): no prompts even in a terminal;
  managed files take the source version (backups kept).
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

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }
if ($DryRun) { $env:AITOOLS_DRY_RUN = "1" }

# --- BEGIN install log helpers (tests/profile/test-config.sh extracts this block) ---
# deploy.jsonl records (Write-JsonlRecord) and the child relay (Invoke-ChildRelayed)
# come from aitools-lib: one copy for the installers, user init and deploy-harness
# (audit A-1). A record that cannot be written is one warning and the run goes on
# (A-16). This block keeps only the installer's own Step 3 / Step 5 helpers.

# Invoke-ConfigWriter WRITER ARGS -- Step 5: run setup-user-config.ps1 in-process
# through the lib relay. The writer logs and writes its own summary rows; the relay
# shows and mirrors its lines to deploy.jsonl, counts its warnings, logs one error
# for a failed writer (exit code or throw) and writes "ERROR|aitools config|..."
# when the writer died before a row of its own (A-1, A-18). Returns nothing.
function Invoke-ConfigWriter([string]$Writer, [hashtable]$WriterArgs) {
    $writerRc = Invoke-ChildRelayed "Step 5: setup-user-config.ps1" $Writer $WriterArgs "aitools config"
    if ($writerRc -ne 0) {
        LogDetail "Step 5: config writer step failed (exit $($script:AitLibChildRc); logged and counted by the relay)"
    }
}

# Get-AbsoluteReposPath PATH -- PATH as an absolute path. A relative answer is taken
# relative to the current location, where Step 3 creates it (the pre-#79 installer
# kept it relative; the config writer accepts absolute paths only). "" when it
# cannot be resolved (the reason is a detail line).
function Get-AbsoluteReposPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    try {
        return [IO.Path]::GetFullPath($Path, (Get-Location).Path)
    } catch {
        LogDetail "Repos path '$Path': $($_.Exception.Message)"
        return ""
    }
}

# Resolve-ReposDir PATH -- Step 3: make PATH absolute (relative to the current
# location) and create it. Returns the absolute path, or "" after LogError and one
# ERROR row "aitools config" when it cannot be resolved or created; the caller then
# skips Step 5, whose writer accepts absolute paths only (audit A-17).
function Resolve-ReposDir([string]$Path) {
    $abs = $Path
    if (-not [IO.Path]::IsPathRooted($Path)) {
        $abs = Get-AbsoluteReposPath $Path
        if (-not $abs) {
            LogError "Repos path '$Path' is relative and could not be resolved -- config.json will not be written"
            Write-Summary "ERROR" "aitools config" "repos path not absolute"
            return ""
        }
        Log "Repos path '$Path' is relative -- using $abs (relative to the current directory)"
    }
    if (-not (Test-Path -LiteralPath $abs)) {
        try {
            $null = New-Item -ItemType Directory -Path $abs -Force -ErrorAction Stop
        } catch {
            LogDetail "Repos directory '$abs': $($_.Exception.Message)"
            LogError "Repos directory '$abs' could not be created -- config.json will not be written"
            Write-Summary "ERROR" "aitools config" "repos dir not created"
            return ""
        }
    }
    return $abs
}
# --- END install log helpers ---

# --- BEGIN install log override (tests/profile/test-install.sh extracts this block) ---
# Override: JSONL dual-format (human-readable + structured JSON). The record goes
# through the lib's Write-JsonlRecord: escaped, one run_id for the installer's own
# lines and its relayed children's, and an unwritable deploy.jsonl is one warning (A-16).
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
    Write-JsonlRecord $ts $scriptName $level $msg
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }
# --- END install log override ---

# --- Summary file init (if not already set by parent aitools invocation) ---
if (-not $env:AITOOLS_SUMMARY_FILE) {
    $env:AITOOLS_SUMMARY_FILE = Join-Path $env:USERPROFILE ".aitools\run-summary.txt"
    # Remove stale summary file before creating fresh one; may not exist (expected)
    if (Test-Path $env:AITOOLS_SUMMARY_FILE) {
        Remove-Item $env:AITOOLS_SUMMARY_FILE -Force
    }
    New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
}

# Interactive mode (same rule as the lib's review prompts): a console on stdin and
# no -Force / AITOOLS_FORCE. Otherwise every prompt takes its default.
$installInteractive = ($env:AITOOLS_FORCE -ne "1") -and (Test-InteractiveConsole)

# --- Script validation helper ---
# Validates PS1 syntax with ParseFile before executing. A parse error or a failed
# script logs an error and writes an ERROR summary row; the install continues.
function Invoke-ValidatedScript {
    param([string]$ScriptPath)
    $name = Split-Path $ScriptPath -Leaf
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        foreach ($err in $parseErrors) {
            LogDetail "$name parse: line $($err.Extent.StartLineNumber): $($err.Message)"
        }
        LogError "$name has parse errors on this PowerShell version -- skipped"
        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "parse errors -- skipped"
        return
    }
    $global:LASTEXITCODE = 0
    try {
        & $ScriptPath
    } catch {
        LogError "$name failed: $_"
        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "script failed (exception)"
        return
    }
    $scriptRc = $LASTEXITCODE
    if ($scriptRc -and $scriptRc -ne 0) {
        LogError "$name failed (exit $scriptRc)"
        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "script failed (exit $scriptRc)"
    }
}

# --- Post-write JSON validation ---
# Validates a JSON config file after writing: checks non-empty, valid JSON,
# required keys present, and no double-slash paths (excluding protocol prefixes).
# No caller here since config.json moved to setup-user-config.ps1 (M3 B3b). It stays
# in this installer (M3 B2 kept it out of aitools-lib) because config-file-safety.md
# cites it as the reference example for ValidateJsonConfig.
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
    $longPathsOut = git config --global core.longpaths true 2>&1 | Out-String
    $longPathsRc = $LASTEXITCODE
    foreach ($lpLine in $longPathsOut.Split("`n")) {
        if ($lpLine.Trim()) { LogDetail "git-longpaths: $($lpLine.TrimEnd())" }
    }
    if ($longPathsRc -eq 0) {
        LogOk "git core.longpaths enabled"
    } else {
        LogWarn "git config --global core.longpaths true failed (exit $longPathsRc) -- deep paths may fail"
    }
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
    } elseif ($installInteractive) {
        Log "Not authenticated. Starting gh auth login..."
        # Interactive: gh talks to the console directly, so only the exit code is captured.
        gh auth login
        $ghAuthRc = $LASTEXITCODE
        if ($ghAuthRc -ne 0) {
            LogError "gh auth login failed (exit $ghAuthRc)"
            Write-Summary "ERROR" "gh auth" "login failed (exit $ghAuthRc)"
            Write-Summary "ACTION" "" "Run: gh auth login"
        }
    } else {
        LogWarn "Not authenticated and not interactive -- skipping gh auth (use -SkipGhAuth to suppress)"
        Write-Summary "WARN" "gh auth" "not authenticated"
        Write-Summary "ACTION" "" "Run: gh auth login"
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
    if ($installInteractive) {
        $defaultPath = Join-Path $env:USERPROFILE "repos"
        [Console]::Write("Where should new repos live? [$defaultPath]: ")
        $userInput = Read-ConsoleChoice $defaultPath
        if ($userInput) {
            $resolvedReposPath = $userInput -replace '^~', $env:USERPROFILE
        } else {
            $resolvedReposPath = $defaultPath
        }
    } else {
        $resolvedReposPath = Join-Path $env:USERPROFILE "repos"
    }
}

$reposOk = $true
$reposAbs = Resolve-ReposDir $resolvedReposPath
if ($reposAbs) {
    $resolvedReposPath = $reposAbs
    LogOk "Repos directory: $resolvedReposPath"
} else {
    $reposOk = $false   # logged with its ERROR row; Step 5 is skipped
}

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

# config.json has one writer: setup-user-config.ps1 (bootstrap keys from this
# installer + values derived from profile.json; no node needed, P-Q3).
$configWriter = Join-Path $PSScriptRoot "setup-user-config.ps1"
if (-not $reposOk) {
    Log "Step 5: skipped -- the repos path is unusable (see the error above); config.json not written"
} elseif (-not (Test-Path $configWriter)) {
    LogError "Failed: setup-user-config.ps1 not found next to the installer -- config.json not written"
    Write-Summary "ERROR" "aitools config" "writer missing"
} else {
    $drivesJson = ConvertTo-Json -InputObject @($drives | ForEach-Object { [ordered]@{ path = $_.path; account = $_.account; label = $_.label } }) -Depth 5 -Compress
    if (-not $drivesJson) { $drivesJson = "[]" }
    $writerArgs = @{ ReposPath = $resolvedReposPath; RepoPath = $aitoolsRepo; DrivesJson = $drivesJson }
    if ($DryRun) { $writerArgs["DryRun"] = $true }
    # In-process like Invoke-ValidatedScript: reset the exit code, catch a throw
    Invoke-ConfigWriter $configWriter $writerArgs
}

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

$hhPs1Src = Join-Path $PSScriptRoot "hh.ps1"
$hhPs1Dst = Join-Path $localBin "hh.ps1"
if (Test-Path $hhPs1Src) {
    Copy-Item $hhPs1Src $hhPs1Dst -Force
    LogOk "Installed hh.ps1 to $hhPs1Dst"
} else {
    LogWarn "hh.ps1 not found -- skipping"
}

# Harness Python CLIs -> ~/.aitools/bin (deployed copy, called by hooks via
# absolute path so every project's hooks resolve them -- not run from the repo).
# These are sole-owned generated artifacts (the user never edits the deployed
# copy), so per config-file-safety.md we back up + overwrite, with NO
# interactive review. Deploy-ManagedFile's prompt is for user-customizable
# files only.
$aitoolsBin = Join-Path $env:USERPROFILE ".aitools\bin"
if (-not (Test-Path $aitoolsBin)) { New-Item -ItemType Directory -Path $aitoolsBin -Force | Out-Null }
$hbinDeployed = 0
foreach ($hcli in @("harness-db.py", "read-session.py", "read-session-full.py")) {
    $hsrc = Join-Path $PSScriptRoot $hcli
    $hdst = Join-Path $aitoolsBin $hcli
    if (-not (Test-Path $hsrc)) {
        LogWarn "$hcli not found (MDM deploy -- skipping)"
        continue
    }
    if ((Test-Path $hdst) -and -not (Compare-Object (Get-Content $hsrc) (Get-Content $hdst))) {
        continue  # identical -- nothing to deploy
    }
    if (Test-Path $hdst) { Backup-File $hdst }
    Copy-Item $hsrc $hdst -Force
    LogOk "Deployed $hcli -> $hdst"
    $hbinDeployed++
}
Write-Summary "OK" "harness bin" "$hbinDeployed deployed to ~/.aitools/bin"

# ============================================================
# 7. Shell integration
# ============================================================
Log "Step 7: Shell integration"

# Login-profile PATH ownership (managed marked block)
$shellScript = Join-Path $PSScriptRoot "setup-user-shell.ps1"
if (Test-Path $shellScript) {
    Invoke-ValidatedScript $shellScript
} else {
    LogWarn "setup-user-shell.ps1 not found -- skipping login-profile PATH block (MDM deploy)"
}

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
function hh { & "`$HOME\.local\bin\hh.ps1" @args }
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
    $updateRc = $LASTEXITCODE
    foreach ($updateLine in $claudeOutput.Split("`n")) {
        if ($updateLine.Trim()) { Log $updateLine.TrimEnd() }
    }
    if ($updateRc -ne 0) {
        LogWarn "claude update failed (exit $updateRc) -- see $logFile"
    } elseif ($claudeOutput -match '(?i)already.*up.to.date|no update') {
        LogOk "Already up to date"
    } else {
        LogOk "claude update finished"
    }
} else {
    Log "Installing Claude Code CLI..."
    try {
        # Capture every stream of the official installer so its output reaches the log.
        $installOut = Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1') *>&1 | Out-String
        foreach ($installLine in $installOut.Split("`n")) {
            if ($installLine.Trim()) { Log $installLine.TrimEnd() }
        }
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
# 14. uv  (MUST precede Python -- uv is the Python manager)
# ============================================================
Log "Step 14: uv"

$uvScript = Join-Path $PSScriptRoot "setup-uv.ps1"
if (Test-Path $uvScript) {
    Invoke-ValidatedScript $uvScript
} else {
    LogWarn "setup-uv.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 15. Python  (via uv -- requires Step 14)
# ============================================================
Log "Step 15: Python"

$pythonScript = Join-Path $PSScriptRoot "setup-python.ps1"
if (Test-Path $pythonScript) {
    Invoke-ValidatedScript $pythonScript
} else {
    LogWarn "setup-python.ps1 not found -- skipping (MDM deploy)"
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
# 20. Bash
# ============================================================
Log "Step 20: Bash"

$bashScript = Join-Path $PSScriptRoot "setup-bash.ps1"
if (Test-Path $bashScript) {
    Invoke-ValidatedScript $bashScript
} else {
    LogWarn "setup-bash.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 20b. Google Chrome (managed in the Claude Code web environment only, D-CHR1)
# ============================================================
# Parity with aitools-install.sh (D-ENV8): on Windows the script reports "n/a (local)".
Log "Step 20b: Google Chrome"

$chromeScript = Join-Path $PSScriptRoot "setup-google-chrome.ps1"
if (Test-Path $chromeScript) {
    Invoke-ValidatedScript $chromeScript
} else {
    LogWarn "setup-google-chrome.ps1 not found -- skipping (MDM deploy)"
}

# ============================================================
# 21. Deploy configurations
# ============================================================
Log "Step 21: Deploy configurations"

$deployScripts = @(
    "setup-user-claude.ps1",
    "setup-user-cursor.ps1",
    "setup-user-mcp.ps1",
    "setup-user-skills.ps1",
    "setup-cursor-ide-mcp.ps1",
    "setup-user-settings.ps1",
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

# ============================================================
# 22. Relay → Cursor AGENTS.md (mirror; same as aitools deploy)
# ============================================================
Log "Step 22: Relay → Cursor AGENTS.md mirror"

$syncPy = Join-Path $PSScriptRoot "sync-relay-to-cursor-agents.py"
if (Test-Path $syncPy) {
    if (-not $DryRun) { $env:AITOOLS_SYNC_DEPLOY_LOG = "1" }
    $target = Join-Path $env:USERPROFILE ".cursor\AGENTS.md"
    $syncArgs = @($syncPy, "--target", $target)
    if ($DryRun) { $syncArgs += "--dry-run" }
    $exitCode = -1
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $out = & python3 @syncArgs 2>&1
        $exitCode = $LASTEXITCODE
        $out | Add-Content -Path $logFile
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $pyArgs = @("-3") + $syncArgs
        $out = & py @pyArgs 2>&1
        $exitCode = $LASTEXITCODE
        $out | Add-Content -Path $logFile
    } else {
        LogWarn "Python not found -- skipping relay→AGENTS sync"
        $exitCode = -2
    }
    if ($exitCode -ge 0) {
        if ($exitCode -eq 0) {
            if ($DryRun) { LogOk "relay→AGENTS sync (dry-run)" }
        } else {
            LogWarn "sync-relay-to-cursor-agents.py failed (non-fatal)"
        }
    }
    if (Test-Path Env:\AITOOLS_SYNC_DEPLOY_LOG) { Remove-Item Env:\AITOOLS_SYNC_DEPLOY_LOG }
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
