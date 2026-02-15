#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
#
# Does four things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Writes ~/.cursor/cli-config.json (skips if already up to date)
#   4. Copies User Rules to clipboard for pasting into Cursor Settings > Rules

set -euo pipefail

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        echo "ERROR: This script is for macOS/Linux. On Windows, use the .ps1 version." >&2
        exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_RULES_PATH="${1:-$SCRIPT_DIR/../shared/cursor-rules/user-rules.md}"

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# Track status for summary (plain vars -- bash 3.2 compat, no associative arrays)
STATUS_ripgrep=""
STATUS_cursorCli=""
STATUS_cliConfig=""
STATUS_userRules=""

# --- 1. ripgrep (rg) ---

echo ""
echo "--- Step 1: ripgrep (rg) ---"

if command -v rg &>/dev/null; then
    RG_VERSION=$(rg --version | head -1)
    echo "Already installed: $RG_VERSION"
    STATUS_ripgrep="already installed ($RG_VERSION)"
else
    if command -v brew &>/dev/null; then
        echo "Installing ripgrep via brew..."
        brew install ripgrep

        if command -v rg &>/dev/null; then
            RG_VERSION=$(rg --version | head -1)
            echo "Installed: $RG_VERSION"
            STATUS_ripgrep="installed ($RG_VERSION)"
        else
            echo "WARNING: brew install completed but 'rg' not found in PATH."
            echo "You may need to restart your terminal."
            STATUS_ripgrep="installed (restart terminal to verify)"
        fi
    else
        echo "WARNING: Homebrew not found. Install ripgrep manually:"
        echo "  brew install ripgrep"
        echo "  -- or --"
        echo "  https://github.com/BurntSushi/ripgrep#installation"
        STATUS_ripgrep="SKIPPED (brew not found)"
    fi
fi

# --- 2. Cursor CLI (agent) ---

echo ""
echo "--- Step 2: Cursor CLI (agent) ---"

if command -v agent &>/dev/null; then
    AGENT_VERSION=$(agent --version)
    echo "Already installed: $AGENT_VERSION"
    STATUS_cursorCli="already installed ($AGENT_VERSION)"
else
    echo "Installing Cursor CLI..."
    curl https://cursor.com/install -fsS | bash

    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        echo "Installed: $AGENT_VERSION"
        STATUS_cursorCli="installed ($AGENT_VERSION)"
    else
        echo "WARNING: Cursor CLI install completed but 'agent' not found in PATH."
        echo "You may need to restart your terminal."
        STATUS_cursorCli="installed (restart terminal to verify)"
    fi
fi

# --- 3. cli-config.json ---

echo ""
echo "--- Step 3: cli-config.json ---"

EXPECTED_CONFIG='{
  "version": 1,
  "editor": {
    "vimMode": false
  },
  "permissions": {
    "allow": [],
    "deny": []
  }
}'

mkdir -p "$CURSOR_DIR"

if [ -f "$CLI_CONFIG" ]; then
    EXISTING_CONFIG=$(cat "$CLI_CONFIG")
    if [ "$EXISTING_CONFIG" = "$EXPECTED_CONFIG" ]; then
        echo "Already up to date: $CLI_CONFIG"
        STATUS_cliConfig="already up to date"
    else
        printf '%s' "$EXPECTED_CONFIG" > "$CLI_CONFIG"
        echo "Updated: $CLI_CONFIG"
        STATUS_cliConfig="updated"
    fi
else
    printf '%s' "$EXPECTED_CONFIG" > "$CLI_CONFIG"
    echo "Created: $CLI_CONFIG"
    STATUS_cliConfig="created"
fi

# --- 4. Copy User Rules to clipboard ---

echo ""
echo "--- Step 4: User Rules ---"

if [ -f "$USER_RULES_PATH" ]; then
    if command -v pbcopy &>/dev/null; then
        pbcopy < "$USER_RULES_PATH"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$USER_RULES_PATH"
    else
        echo "WARNING: No clipboard command found (pbcopy/xclip). Content shown below — copy manually."
    fi

    echo "Copied to clipboard from: $USER_RULES_PATH"
    echo "Paste into: Cursor Settings > Rules"
    echo ""
    echo "--- Preview ---"
    cat "$USER_RULES_PATH"
    echo "--- End ---"
    STATUS_userRules="copied to clipboard -- paste into Cursor Settings > Rules"
else
    echo "WARNING: User Rules file not found at $USER_RULES_PATH"
    echo "Skipping clipboard copy. Check the path and re-run."
    STATUS_userRules="SKIPPED (file not found)"
fi

# --- Summary ---

echo ""
echo "=============================="
echo "Summary:"
echo "  ripgrep:       ${STATUS_ripgrep}"
echo "  Cursor CLI:    ${STATUS_cursorCli}"
echo "  cli-config:    ${STATUS_cliConfig}"
echo "  User Rules:    ${STATUS_userRules}"
echo "=============================="

# Open User Rules file so user can see what to paste
if [ -f "$USER_RULES_PATH" ]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        open "$USER_RULES_PATH"
    else
        xdg-open "$USER_RULES_PATH" 2>/dev/null || true
    fi
fi
