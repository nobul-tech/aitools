# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — removes and re-adds each server to ensure latest config.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled by default (deny rules).
# Use `aitools --addmcp` to enable per project.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-mcp"
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

# Check that claude CLI is available
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    LogError "'claude' CLI not found in PATH. Install Claude Code first: https://claude.ai/download"
    exit 1
}

# Check that Node.js is available (required for Chrome DevTools MCP and settings merge)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    LogError "Node.js not found. Install via 'aitools install' or manually: https://nodejs.org"
    exit 1
} else {
    $nodeVersion = (node --version)
    LogOk "Node.js $nodeVersion found"
}

# --- Add all three MCP servers at user scope ---

function Add-McpServer {
    param(
        [string]$Name,
        [string[]]$AddArgs
    )

    # Remove existing (ignore errors if not found)
    $removeResult = claude mcp remove $Name --scope user 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log "Removed existing $Name config"
    }

    Log "Adding $Name..."
    $addResult = & claude mcp add @AddArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        LogOk "$Name configured"
    } else {
        LogError "Failed to add $Name`: $addResult"
    }
}

Log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx (Windows needs cmd /c wrapper)
Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest")

# Vercel — remote HTTP server (disabled by default via deny rules below)
Add-McpServer -Name "vercel" -AddArgs @("--transport", "http", "--scope", "user", "vercel", "https://mcp.vercel.com")

# Webflow — remote HTTP server (disabled by default via deny rules below)
Add-McpServer -Name "webflow" -AddArgs @("--transport", "http", "--scope", "user", "webflow", "https://mcp.webflow.com/mcp")

# --- Merge deny rules into ~/.claude/settings.json ---
# Vercel and Webflow are disabled by default at user level.
# Projects enable them via .claude/settings.local.json (aitools --addmcp).

$settingsFile = Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json"
$settingsDir = Split-Path $settingsFile -Parent
Log "Merging deny rules into $settingsFile..."

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

# Read existing settings or start fresh
$settings = @{}
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $settings = @{}
    }
}

# Ensure permissions.deny exists
if (-not $settings.ContainsKey("permissions")) { $settings["permissions"] = @{} }
if (-not $settings["permissions"].ContainsKey("deny")) { $settings["permissions"]["deny"] = @() }

# Add deny rules if not already present
$denyRules = @("MCP(vercel)", "MCP(webflow)")
foreach ($rule in $denyRules) {
    if ($rule -notin $settings["permissions"]["deny"]) {
        $settings["permissions"]["deny"] += $rule
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
LogOk "Deny rules set for vercel, webflow in $settingsFile"

LogOk "User-level MCP configured (all servers; vercel/webflow disabled by default)"
Log "To enable per project: aitools --addmcp vercel"
Log "To check status: aitools mcp"
