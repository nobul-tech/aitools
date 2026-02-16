# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run — replaces existing file with latest version.

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md")
)

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-claude"
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

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Log "Created $claudeDir"
}

# Remove existing file so we always write the latest version
if (Test-Path $claudeMd) {
    Remove-Item $claudeMd
    Log "Removed existing $claudeMd"
}

# Verify shared file exists
if (-not (Test-Path $SharedPath)) {
    LogError "Shared preferences not found at: $SharedPath"
    exit 1
}

# Read shared preferences and write inline (Cursor doesn't resolve @import)
$sharedContent = Get-Content -Path $SharedPath -Raw

$content = @"
$sharedContent

## Machine-Specific

- Machine: $([System.Environment]::OSVersion.VersionString) ($env:COMPUTERNAME)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

Set-Content -Path $claudeMd -Value $content -Encoding UTF8
LogOk "Wrote $claudeMd"
Log "Inlined shared preferences from: $SharedPath"
