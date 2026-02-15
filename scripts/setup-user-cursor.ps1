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

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Error "This script is for Windows. On macOS/Linux, use the .sh version."
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

Write-Host ""
Write-Host "--- Step 1: ripgrep (rg) ---"

$rgCmd = Get-Command rg -ErrorAction SilentlyContinue
if ($rgCmd) {
    $rgVersion = (rg --version | Select-Object -First 1)
    Write-Host "Already installed: $rgVersion"
    $status.ripgrep = "already installed ($rgVersion)"
} else {
    Write-Host "Installing ripgrep via winget..."
    winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements
    Refresh-Path

    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        Write-Host "Installed: $rgVersion"
        $status.ripgrep = "installed ($rgVersion)"
    } else {
        Write-Host "WARNING: winget install completed but 'rg' not found in PATH."
        Write-Host "You may need to restart your terminal."
        $status.ripgrep = "installed (restart terminal to verify)"
    }
}

# --- 2. Cursor CLI (agent) ---

Write-Host ""
Write-Host "--- Step 2: Cursor CLI (agent) ---"

$agentCmd = Get-Command agent -ErrorAction SilentlyContinue
if ($agentCmd) {
    $agentVersion = agent --version
    Write-Host "Already installed: $agentVersion"
    $status.cursorCli = "already installed ($agentVersion)"
} else {
    Write-Host "Installing Cursor CLI..."
    Invoke-Expression (Invoke-RestMethod 'https://cursor.com/install?win32=true')

    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        Write-Host "Installed: $agentVersion"
        $status.cursorCli = "installed ($agentVersion)"
    } else {
        Write-Host "WARNING: Cursor CLI install completed but 'agent' not found in PATH."
        Write-Host "You may need to restart your terminal."
        $status.cursorCli = "installed (restart terminal to verify)"
    }
}

# --- 3. cli-config.json ---

Write-Host ""
Write-Host "--- Step 3: cli-config.json ---"

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
    Write-Host "Created $cursorDir"
}

if (Test-Path $cliConfig) {
    $existingConfig = (Get-Content -Path $cliConfig -Raw).TrimEnd()
    if ($existingConfig -eq $expectedConfig) {
        Write-Host "Already up to date: $cliConfig"
        $status.cliConfig = "already up to date"
    } else {
        Set-Content -Path $cliConfig -Value $expectedConfig -Encoding UTF8 -NoNewline
        Write-Host "Updated: $cliConfig"
        $status.cliConfig = "updated"
    }
} else {
    Set-Content -Path $cliConfig -Value $expectedConfig -Encoding UTF8 -NoNewline
    Write-Host "Created: $cliConfig"
    $status.cliConfig = "created"
}

# --- 4. Copy User Rules to clipboard ---

Write-Host ""
Write-Host "--- Step 4: User Rules ---"

if (Test-Path $UserRulesPath) {
    $rulesContent = Get-Content -Path $UserRulesPath -Raw
    Set-Clipboard -Value $rulesContent
    Write-Host "Copied to clipboard from: $UserRulesPath"
    Write-Host "Paste into: Cursor Settings > Rules"
    Write-Host ""
    Write-Host "--- Preview ---"
    Write-Host $rulesContent
    Write-Host "--- End ---"
    $status.userRules = "copied to clipboard -- paste into Cursor Settings > Rules"
} else {
    Write-Host "WARNING: User Rules file not found at $UserRulesPath"
    Write-Host "Skipping clipboard copy. Check the path and re-run."
    $status.userRules = "SKIPPED (file not found)"
}

# --- Summary ---

Write-Host ""
Write-Host "=============================="
Write-Host "Summary:"
Write-Host "  ripgrep:       $($status.ripgrep)"
Write-Host "  Cursor CLI:    $($status.cursorCli)"
Write-Host "  cli-config:    $($status.cliConfig)"
Write-Host "  User Rules:    $($status.userRules)"
Write-Host "=============================="

# Open User Rules file so user can see what to paste
if (Test-Path $UserRulesPath) {
    Start-Process $UserRulesPath
}
