#!/usr/bin/env bash
# setup-user-mcp.sh — Installs/updates user-level MCP servers for Claude Code on macOS/Linux
# Safe to re-run — removes and re-adds each server to ensure latest config.

set -euo pipefail

# Check that claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "Error: 'claude' CLI not found in PATH."
    echo "Install Claude Code first: https://claude.ai/download"
    exit 1
fi

# MCP servers to configure (name, args)
# Each server is installed by removing any existing config then re-adding.

add_stdio_server() {
    local name="$1"
    shift
    echo ""
    echo "=== $name ==="

    # Remove existing (ignore errors if not found)
    if claude mcp remove "$name" --scope user 2>/dev/null; then
        echo "  Removed existing $name config"
    fi

    echo "  Adding $name..."
    claude mcp add "$name" --scope user -- "$@"
    echo "  Done."
}

add_http_server() {
    local name="$1"
    local url="$2"
    echo ""
    echo "=== $name ==="

    # Remove existing (ignore errors if not found)
    if claude mcp remove "$name" --scope user 2>/dev/null; then
        echo "  Removed existing $name config"
    fi

    echo "  Adding $name..."
    claude mcp add --transport http --scope user "$name" "$url"
    echo "  Done."
}

echo "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx (no cmd /c needed on macOS)
add_stdio_server "chrome-devtools" npx -y chrome-devtools-mcp@latest

# Vercel — remote HTTP server with OAuth
add_http_server "vercel" "https://mcp.vercel.com"

# Webflow — remote HTTP server with OAuth
add_http_server "webflow" "https://mcp.webflow.com/mcp"

echo ""
echo "All MCP servers configured."
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code session"
echo "  2. Run /mcp to verify all servers show green status"
echo "  3. Authenticate Vercel and Webflow via the OAuth browser flow"
