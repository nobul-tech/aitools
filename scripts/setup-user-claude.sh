#!/usr/bin/env bash
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Run once per machine. Idempotent (won't overwrite existing file).

set -euo pipefail

SHARED_PATH="${1:-$HOME/Google Drive/My Drive/nobul co/ai-tooling/shared/claude-shared.md}"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Don't overwrite existing
if [ -f "$CLAUDE_MD" ]; then
    echo "User-level CLAUDE.md already exists at $CLAUDE_MD"
    echo "To regenerate, delete it first and re-run this script."
    exit 0
fi

cat > "$CLAUDE_MD" << EOF
@"${SHARED_PATH}"

## Machine-Specific

- Machine: macOS laptop
- Shell: zsh, bash, pwsh (when PowerShell needed)
- Google Drive mount: ~/Google Drive/My Drive/
EOF

echo "Created user-level CLAUDE.md at $CLAUDE_MD"
echo "It imports shared preferences from: $SHARED_PATH"
