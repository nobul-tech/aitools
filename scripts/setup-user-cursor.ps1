# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Safe to re-run — checks each step and skips what's already done.
#
# Does four things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Writes ~/.cursor/cli-config.json (skips if already up to date)
#   4. Copies User Rules to clipboard for pasting into Cursor Settings > Rules

param(
    [string]$UserRulesPath = (Join-Path $PSScriptRoot "..\shared\cursor-rules\user-rules.md")
)

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-cursor"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg" }
function LogWarn($msg)  { Log "WARN: $msg" }

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$cursorDir = Join-Path $env:USERPROFILE ".cursor"
$cliConfig = Join-Path $cursorDir "cli-config.json"

# Track status for summary
$status = @{
    ripgrep   = ""
    cursorCli = ""
    cliConfig = ""
    userRules = ""
}

# Helper: refresh PATH from registry (picks up winget installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- 1. ripgrep (rg) ---

Log "Step 1: ripgrep (rg)"

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

# --- 2. Cursor CLI (agent) ---

Log "Step 2: Cursor CLI (agent)"

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

# --- 3. cli-config.json ---

Log "Step 3: cli-config.json"

$expectedConfig = @'
{
  "version": 1,
  "editor": {
    "vimMode": false
  },
  "permissions": {
    "allow": [],
    "deny": []
  }
}
'@

# Ensure ~/.cursor/ exists
if (-not (Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    Log "Created $cursorDir"
}

if (Test-Path $cliConfig) {
    $existingConfig = (Get-Content -Path $cliConfig -Raw).TrimEnd()
    if ($existingConfig -eq $expectedConfig) {
        LogOk "Already up to date: $cliConfig"
        $status.cliConfig = "already up to date"
    } else {
        Set-Content -Path $cliConfig -Value $expectedConfig -Encoding UTF8 -NoNewline
        LogOk "Updated: $cliConfig"
        $status.cliConfig = "updated"
    }
} else {
    Set-Content -Path $cliConfig -Value $expectedConfig -Encoding UTF8 -NoNewline
    LogOk "Created: $cliConfig"
    $status.cliConfig = "created"
}

# --- 4. Copy User Rules to clipboard ---

Log "Step 4: User Rules"

if (Test-Path $UserRulesPath) {
    $rulesContent = Get-Content -Path $UserRulesPath -Raw
    Set-Clipboard -Value $rulesContent
    LogOk "Copied to clipboard from: $UserRulesPath"
    Log "Paste into: Cursor Settings > Rules"
    $status.userRules = "copied to clipboard -- paste into Cursor Settings > Rules"
} else {
    LogWarn "User Rules file not found at $UserRulesPath. Skipping clipboard copy."
    $status.userRules = "SKIPPED (file not found)"
}

# --- Summary ---

Log "=============================="
Log "Summary:"
Log "  ripgrep:       $($status.ripgrep)"
Log "  Cursor CLI:    $($status.cursorCli)"
Log "  cli-config:    $($status.cliConfig)"
Log "  User Rules:    $($status.userRules)"
Log "=============================="

# Open User Rules file so user can see what to paste
if (Test-Path $UserRulesPath) {
    Start-Process $UserRulesPath
}
