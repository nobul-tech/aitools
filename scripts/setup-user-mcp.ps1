# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — removes and re-adds each server to ensure latest config.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled by default (deny rules).
# Use `aitools --addmcp` to enable per project.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-mcp"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
$errors = 0
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }

# Backup a file before overwriting. Keeps at most $MaxBackups copies.
function Backup-File {
    param([string]$FilePath, [int]$MaxBackups = 20)
    if (-not (Test-Path $FilePath)) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${FilePath}.bak.${ts}"
    Copy-Item -Path $FilePath -Destination $backupPath
    # Prune oldest beyond limit
    $backups = Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -gt $MaxBackups) {
        $backups | Select-Object -Skip $MaxBackups | Remove-Item -Force
    }
    Log "Backed up $FilePath"
}

# --- PS 5.1 compatibility helper ---
# ConvertFrom-Json -AsHashtable is PS 6+ only. This converts PSCustomObject trees
# to nested hashtables so .ContainsKey() and bracket indexing work on PS 5.1.
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

    # Unset CLAUDECODE to allow running inside a Claude Code session
    $savedClaudeCode = $env:CLAUDECODE
    Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue

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

    # Restore CLAUDECODE
    if ($savedClaudeCode) {
        $env:CLAUDECODE = $savedClaudeCode
    }
}

Log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx (Windows needs cmd /c wrapper)
Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest", "--", "--isolated")

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

# Back up before merge
Backup-File -FilePath $settingsFile

# Read existing settings or start fresh
$settings = @{}
if (Test-Path $settingsFile) {
    try {
        $raw = Get-Content $settingsFile -Raw
        $settings = ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)
    } catch {
        LogWarn "$settingsFile could not be parsed ($_), starting with empty config"
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

$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settingsFile, $json, [System.Text.UTF8Encoding]::new($false))

# Post-write validation
try {
    $vContent = [System.IO.File]::ReadAllText($settingsFile)
    $vParsed = $vContent | ConvertFrom-Json
    if (-not ($vParsed.PSObject.Properties.Name -contains "permissions")) {
        LogError "Validation failed: $settingsFile missing required field 'permissions'"
    }
} catch {
    LogError "Validation failed: $settingsFile is not valid JSON -- $_"
}

LogOk "Deny rules set for vercel, webflow in $settingsFile"

LogOk "User-level MCP configured (all servers; vercel/webflow disabled by default)"
Log "To enable per project: aitools --addmcp vercel"
Log "To check status: aitools mcp"

# --- Deploy Chrome DevTools skills ---
# Vendored from https://github.com/ChromeDevTools/chrome-devtools-mcp/tree/main/skills
# These provide structured workflows for browser automation and a11y auditing.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path (Join-Path (Split-Path -Parent $scriptDir) "shared") "skills"
$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"

function Deploy-Skill {
    param([string]$SkillName, [string]$DestBase)

    $src = Join-Path (Join-Path $skillsSrc $SkillName) "SKILL.md"
    $destDir = Join-Path $DestBase $SkillName
    $dest = Join-Path $destDir "SKILL.md"

    if (-not (Test-Path $src)) {
        LogError "Skill source not found: $src"
        return
    }

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -Path $src -Destination $dest -Force
    LogOk "Deployed skill: $SkillName -> $dest"
}

Log "Deploying Chrome DevTools skills to $skillsDest..."
Deploy-Skill "chrome-devtools" $skillsDest
Deploy-Skill "a11y-debugging" $skillsDest

Log "Deploying Chrome DevTools skills to $skillsDestCursor..."
Deploy-Skill "chrome-devtools" $skillsDestCursor
Deploy-Skill "a11y-debugging" $skillsDestCursor

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
