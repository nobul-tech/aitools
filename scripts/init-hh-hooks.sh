#!/usr/bin/env bash
# One-time: point this repo at scripts/githooks (honest harness pre-commit).
# Run from aitools repo root: bash scripts/init-hh-hooks.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git config core.hooksPath scripts/githooks
echo "core.hooksPath = scripts/githooks (pre-commit regenerates deploy/ when shared/ changes)"
echo "Disable: git config --unset core.hooksPath"
