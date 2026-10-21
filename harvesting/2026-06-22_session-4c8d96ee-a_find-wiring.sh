#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
echo "=== aitools-install.ps1: deploy script list ==="
grep -nE 'setup-user-(hooks|mcp|skills|cursor|claude)|deployScripts|DeployScripts' scripts/aitools-install.ps1 | head -20
echo ""
echo "=== aitools (entry): references to setup-user-hooks / setup-user-mcp / deploy dispatch ==="
grep -nE 'setup-user-hooks|setup-user-mcp|setup-user-settings|setup-user-skills' scripts/aitools | head -30
echo ""
echo "=== aitools.ps1 (entry): same ==="
grep -nE 'setup-user-hooks|setup-user-mcp|setup-user-settings|setup-user-skills' scripts/aitools.ps1 | head -30