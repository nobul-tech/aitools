# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — removes and re-adds each server to ensure latest config.

# Check that claude CLI is available
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "Error: 'claude' CLI not found in PATH."
    Write-Host "Install Claude Code first: https://claude.ai/download"
    exit 1
}

function Add-StdioServer {
    param(
        [string]$Name,
        [string[]]$Args
    )
    Write-Host ""
    Write-Host "=== $Name ==="

    # Remove existing (ignore errors if not found)
    $null = claude mcp remove $Name --scope user 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Removed existing $Name config"
    }

    Write-Host "  Adding $Name..."
    claude mcp add $Name --scope user -- @Args
    Write-Host "  Done."
}

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

Write-Host "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx (needs cmd /c wrapper on Windows)
Add-StdioServer -Name "chrome-devtools" -Args @("cmd", "/c", "npx", "-y", "chrome-devtools-mcp@latest")

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
