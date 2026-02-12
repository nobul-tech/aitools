# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — removes and re-adds each server to ensure latest config.
#
# NOTE: Chrome DevTools is added by editing ~/.claude.json directly because
# `claude mcp add` mangles the `/c` flag in `cmd /c` (interprets it as a path).

# Check that claude CLI is available
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "Error: 'claude' CLI not found in PATH."
    Write-Host "Install Claude Code first: https://claude.ai/download"
    exit 1
}

$claudeJson = Join-Path $env:USERPROFILE ".claude.json"

# --- Chrome DevTools (stdio, needs direct JSON edit on Windows) ---

Write-Host ""
Write-Host "=== chrome-devtools ==="

if (-not (Test-Path $claudeJson)) {
    Write-Host "  Error: $claudeJson not found. Run Claude Code at least once first."
    exit 1
}

$config = Get-Content $claudeJson -Raw | ConvertFrom-Json

# Ensure top-level mcpServers exists
if (-not $config.mcpServers) {
    $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
}

# Remove existing chrome-devtools if present
if ($config.mcpServers.PSObject.Properties["chrome-devtools"]) {
    $config.mcpServers.PSObject.Properties.Remove("chrome-devtools")
    Write-Host "  Removed existing chrome-devtools config"
}

# Add chrome-devtools with correct cmd /c args
$chromeServer = [PSCustomObject]@{
    type    = "stdio"
    command = "cmd"
    args    = @("/c", "npx", "-y", "chrome-devtools-mcp@latest")
    env     = [PSCustomObject]@{}
}
$config.mcpServers | Add-Member -NotePropertyName "chrome-devtools" -NotePropertyValue $chromeServer
Write-Host "  Added chrome-devtools (stdio via cmd /c npx)"

# Write back
$config | ConvertTo-Json -Depth 20 | Set-Content $claudeJson -Encoding UTF8
Write-Host "  Done."

# --- HTTP servers (these work fine via CLI) ---

function Add-HttpServer {
    param(
        [string]$Name,
        [string]$Url
    )
    Write-Host ""
    Write-Host "=== $Name ==="

    # Remove existing (ignore errors if not found)
    $null = claude mcp remove $Name --scope user 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Removed existing $Name config"
    }

    Write-Host "  Adding $Name..."
    claude mcp add --transport http --scope user $Name $Url
    Write-Host "  Done."
}

# Vercel — remote HTTP server with OAuth
Add-HttpServer -Name "vercel" -Url "https://mcp.vercel.com"

# Webflow — remote HTTP server with OAuth
Add-HttpServer -Name "webflow" -Url "https://mcp.webflow.com/mcp"

Write-Host ""
Write-Host "All MCP servers configured."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Start a Claude Code session"
Write-Host "  2. Run /mcp to verify all servers show green status"
Write-Host "  3. Authenticate Vercel and Webflow via the OAuth browser flow"
