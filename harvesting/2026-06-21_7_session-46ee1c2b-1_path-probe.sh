#!/usr/bin/env bash
# Probe: what does an interactive login zsh actually resolve for python3?
set -euo pipefail

echo "=== interactive+login zsh PATH order ==="
zsh -ilc 'print -l $path'

echo
echo "=== interactive zsh python3 resolution ==="
zsh -ilc 'command -v python3; python3 --version'

echo
echo "=== interactive zsh npx/node resolution ==="
zsh -ilc 'command -v node; command -v npx; node --version'
