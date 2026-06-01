#!/usr/bin/env bash
# aitools-deploy.sh — deploy all aitools from repo to ~/.local/bin
#
# [PROVENANCE]
# tool: aitools-deploy
# version: 1.0.0
# created: 2026-04-09T16:25Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: (unnamed — session agent)
# session: 727aaa5e-fc4f-4754-aecb-f527924fe334
#
# [INTENT]
# purpose: Deploy all aitools from the repo to ~/.local/bin.
#   Strips extensions, chmod +x, runs version check.
# scope: Full repo deployment. For single session artifacts,
#   use aitools-session-deploy.sh instead.
# audience: The Commander, any aitools operator.
#
# Usage:
#   aitools-deploy.sh [repo-tools-dir]
#
# Default repo-tools-dir: ~/repos/aitools/tools

set -euo pipefail

TOOLS_DIR="${1:-${HOME}/repos/aitools/tools}"
BIN_DIR="${HOME}/.local/bin"

if [ ! -d "$TOOLS_DIR" ]; then
    echo "ERROR: Tools directory not found: $TOOLS_DIR"
    echo "Usage: aitools-deploy.sh [repo-tools-dir]"
    exit 1
fi

mkdir -p "$BIN_DIR"

DEPLOYED=0

# Deploy Python tools
for tool in "$TOOLS_DIR"/*.py; do
    [ -f "$tool" ] || continue
    name=$(basename "$tool" .py)
    echo "Deploying $name..."
    cp "$tool" "$BIN_DIR/$name"
    chmod +x "$BIN_DIR/$name"
    if "$BIN_DIR/$name" version 2>/dev/null; then
        :
    else
        echo "  (no version command)"
    fi
    DEPLOYED=$((DEPLOYED + 1))
done

# Deploy shell tools
for tool in "$TOOLS_DIR"/*.sh; do
    [ -f "$tool" ] || continue
    name=$(basename "$tool" .sh)
    echo "Deploying $name..."
    cp "$tool" "$BIN_DIR/$name"
    chmod +x "$BIN_DIR/$name"
    DEPLOYED=$((DEPLOYED + 1))
done

echo ""
echo "✓ Deployed $DEPLOYED tools to $BIN_DIR"
echo ""
ls -la "$BIN_DIR"/ai* 2>/dev/null || echo "(no ai* tools found)"