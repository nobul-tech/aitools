#!/usr/bin/env bash
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Safe to re-run — replaces existing file with latest version.

set -euo pipefail

SHARED_PATH="${1:-$HOME/Google Drive/My Drive/nobul co/ai-tooling/shared/claude-shared.md}"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Verify shared file exists
if [ ! -f "$SHARED_PATH" ]; then
    echo "Error: Shared preferences not found at: $SHARED_PATH" >&2
    exit 1
fi

# Remove existing file so we always write the latest version
if [ -f "$CLAUDE_MD" ]; then
    rm "$CLAUDE_MD"
    echo "Removed existing $CLAUDE_MD"
fi

# Read shared preferences and write inline (Cursor doesn't resolve @import)
SHARED_CONTENT=$(cat "$SHARED_PATH")

cat > "$CLAUDE_MD" << EOF
${SHARED_CONTENT}

## Machine-Specific

- Machine: macOS laptop
- Shell: zsh, bash, pwsh (when PowerShell needed)
- Google Drive mount: ~/Google Drive/My Drive/
EOF

echo "Wrote user-level CLAUDE.md at $CLAUDE_MD"
echo "Inlined shared preferences from: $SHARED_PATH"
