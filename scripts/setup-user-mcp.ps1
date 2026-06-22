# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — checks existing config, only re-adds when changed or -Force used.
#
# Registers all three servers at user level (chrome-devtools, vercel, webflow).
# This script does NOT write ~/.claude/settings.json: permission rules
# (allow/ask/deny) are profile-sourced and reconciled by setup-user-settings.
#
# Managed: MCP server registration (via `claude mcp add`).
# Preserved: ~/.claude/settings.json (not touched here).

# --- BEGIN mcp body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-mcp"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

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

# --- Check existing MCP server configs via claude mcp list ---
$mcpCurrent = @{}

$savedClaudeCode = $env:CLAUDECODE
Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue

try {
    $mcpListOutput = claude mcp list 2>$null
    $mcpListRc = $LASTEXITCODE
} catch {
    $mcpListOutput = $null
    $mcpListRc = 1
}

if ($savedClaudeCode) {
    $env:CLAUDECODE = $savedClaudeCode
}

if ($mcpListRc -eq 0 -and $mcpListOutput) {
    foreach ($line in $mcpListOutput) {
        $clean = $line -replace '\e\[[0-9;]*m', ''
        if ($clean -match '^(.+?):\s+(.+)\s+-\s+.+$') {
            $name = $Matches[1]
            $details = $Matches[2] -replace '\s+\(HTTP\)$', ''
            $details = $details.TrimEnd()
            $mcpCurrent[$name] = $details
        }
    }
    LogOk "Checked existing MCP config ($($mcpCurrent.Count) servers found)"
} else {
    LogWarn "Could not check existing MCP config; will re-add all servers"
}

function Test-ServerConfigMatches {
    param([string]$Name, [string]$Expected)
    $current = $mcpCurrent[$Name]
    return ($null -ne $current -and $current -eq $Expected)
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
        $script:mcpChanged = $true
    } else {
        LogError "Failed to add $Name`: $addResult"
        Write-Summary "ERROR" "claude mcp" "failed to add $Name"
    }

    # Restore CLAUDECODE
    if ($savedClaudeCode) {
        $env:CLAUDECODE = $savedClaudeCode
    }
}

$mcpChanged = $false
Log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools -- local stdio server via npx (Windows needs cmd /c wrapper)
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: chrome-devtools (-Force)"
    } else {
        Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest", "--", "--isolated")
    }
} elseif (Test-ServerConfigMatches "chrome-devtools" "cmd /c npx chrome-devtools-mcp@latest --isolated") {
    LogOk "chrome-devtools already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: chrome-devtools (stdio, --isolated)"
    } else {
        Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest", "--", "--isolated")
    }
}

# Vercel -- remote HTTP server
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: vercel (-Force)"
    } else {
        Add-McpServer -Name "vercel" -AddArgs @("--transport", "http", "--scope", "user", "vercel", "https://mcp.vercel.com")
    }
} elseif (Test-ServerConfigMatches "vercel" "https://mcp.vercel.com") {
    LogOk "vercel already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: vercel (http)"
    } else {
        Add-McpServer -Name "vercel" -AddArgs @("--transport", "http", "--scope", "user", "vercel", "https://mcp.vercel.com")
    }
}

# Webflow -- remote HTTP server
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: webflow (-Force)"
    } else {
        Add-McpServer -Name "webflow" -AddArgs @("--transport", "http", "--scope", "user", "webflow", "https://mcp.webflow.com/mcp")
    }
} elseif (Test-ServerConfigMatches "webflow" "https://mcp.webflow.com/mcp") {
    LogOk "webflow already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: webflow (http)"
    } else {
        Add-McpServer -Name "webflow" -AddArgs @("--transport", "http", "--scope", "user", "webflow", "https://mcp.webflow.com/mcp")
    }
}

# --- Settings.json: not managed here ---
# This script no longer writes ~/.claude/settings.json. Permission rules
# (allow/ask/deny) are profile-sourced and reconciled by setup-user-settings
# against profile.json. Obsolete deny rules (MCP(vercel)/MCP(webflow)/
# Agent(claude-code-guide)) are purged there. setup-user-mcp only registers
# MCP servers via `claude mcp add`.

if ($DryRun) {
    Log "[DRY RUN] Would configure user-level MCP (chrome-devtools, vercel, webflow)"
} else {
    LogOk "User-level MCP configured (chrome-devtools, vercel, webflow)"
    if ($errors -eq 0) {
        Write-Summary "OK" "claude mcp" $(if ($mcpChanged) { "configured" } else { "verified" })
    }
}
Log "To check status: aitools mcp"

# Display cloud MCP servers configured at claude.ai.
# Silent no-op if claude CLI unavailable or no cloud servers found.
function Show-CloudMcpStatus {
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { return }
    $savedClaudeCode = $env:CLAUDECODE
    Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue
    try {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = claude mcp list 2>$null
        [Console]::OutputEncoding = $savedEncoding
    } catch { $raw = $null }
    if ($savedClaudeCode) { $env:CLAUDECODE = $savedClaudeCode }
    if (-not $raw) { return }
    $entries = @()
    foreach ($line in $raw) {
        $clean = $line -replace '\e\[[0-9;]*m', ''
        if ($clean -match '^claude\.ai\s+(.+?):\s+.+\s+-\s+(.+)$') {
            $name = $Matches[1].Trim()
            $status = $Matches[2].Trim()
            $entries += [PSCustomObject]@{ Name = $name; Status = $status }
        }
    }
    if ($entries.Count -eq 0) { return }
    Log "Cloud MCP servers (configured at claude.ai):"
    foreach ($entry in $entries) {
        $pad = if ($entry.Name.Length -lt 24) { " " * (24 - $entry.Name.Length) } else { " " }
        Log "  $($entry.Name)$pad$($entry.Status)"
    }
}

# --- END mcp body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Show-CloudMcpStatus
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Show-CloudMcpStatus
    Log "COMPLETED successfully" "ok"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
