#!/usr/bin/env bash
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Safe to re-run — replaces existing file with latest version.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_PATH="${1:-$SCRIPT_DIR/../shared/claude-shared.md}"

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

- Machine: $(uname -s) $(uname -m) ($(hostname -s))
- Shell: $(basename "$SHELL")
EOF

echo "Wrote user-level CLAUDE.md at $CLAUDE_MD"
echo "Inlined shared preferences from: $SHARED_PATH"
