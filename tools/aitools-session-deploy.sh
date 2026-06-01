#!/usr/bin/env bash
# aitools-session-deploy.sh — deploy a session artifact to ~/.local/bin
#
# [PROVENANCE]
# tool: aitools-session-deploy
# version: 1.0.0
# created: 2026-04-09T16:25Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: (unnamed — session agent)
# session: 727aaa5e-fc4f-4754-aecb-f527924fe334
#
# [INTENT]
# purpose: Deploy a downloaded session artifact to ~/.local/bin with
#   hash verification, chmod +x, and version check. One command.
# scope: Single-artifact deployment from Downloads. NOT repo deployment
#   (see aitools-deploy.sh for that). NOT cross-platform (macOS/Linux only).
# audience: The Commander, any aitools operator.
#
# Usage:
#   aitools-session-deploy.sh <downloaded-file> <tool-name> [expected-sha256]
#
# Examples:
#   aitools-session-deploy.sh ~/Downloads/aidefend-727aaa5e-04091625Z.py aidefend 8e554...
#   aitools-session-deploy.sh ~/Downloads/aicatalog-abcd1234-04101200Z.py aicatalog

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: aitools-session-deploy.sh <file> <tool-name> [expected-sha256]"
    echo ""
    echo "  file           Path to downloaded session artifact"
    echo "  tool-name      Clean name for ~/.local/bin (e.g. aidefend)"
    echo "  expected-sha256  Optional hash to verify before deploying"
    exit 1
fi

FILE="$1"
NAME="$2"
EXPECTED_HASH="${3:-}"
BIN_DIR="${HOME}/.local/bin"
BIN="${BIN_DIR}/${NAME}"

# Check file exists
if [ ! -f "$FILE" ]; then
    echo "ERROR: File not found: $FILE"
    exit 1
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Verify hash if provided
if [ -n "$EXPECTED_HASH" ]; then
    if command -v shasum &>/dev/null; then
        ACTUAL=$(shasum -a 256 "$FILE" | awk '{print $1}')
    elif command -v sha256sum &>/dev/null; then
        ACTUAL=$(sha256sum "$FILE" | awk '{print $1}')
    else
        echo "WARNING: No sha256 tool found — skipping verification"
        ACTUAL=""
    fi

    if [ -n "$ACTUAL" ]; then
        if [ "$ACTUAL" != "$EXPECTED_HASH" ]; then
            echo "HASH MISMATCH — DO NOT DEPLOY"
            echo "  Expected: $EXPECTED_HASH"
            echo "  Actual:   $ACTUAL"
            exit 1
        fi
        echo "✓ Hash verified: ${ACTUAL:0:16}..."
    fi
else
    echo "⚠ No hash provided — deploying without verification"
fi

# Check if existing version is present
if [ -f "$BIN" ]; then
    echo "  Replacing existing: $BIN"
    OLD_HASH=""
    if command -v shasum &>/dev/null; then
        OLD_HASH=$(shasum -a 256 "$BIN" | awk '{print $1}')
    fi
    if [ -n "$OLD_HASH" ]; then
        echo "  Old hash: ${OLD_HASH:0:16}..."
    fi
fi

# Deploy
cp "$FILE" "$BIN"
chmod +x "$BIN"

echo "✓ Deployed: $BIN"

# Version check
if "$BIN" version 2>/dev/null; then
    :
else
    echo "  (no version command)"
fi

echo ""
echo "Done. Run: $NAME check graphite"