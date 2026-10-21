#!/usr/bin/env bash
# S2-Layout inventory (read-only). Lists artifact locations across source, dotprofile, deployed.
set -euo pipefail
A=/Users/new-jose/repos/aitools
D=/Users/new-jose/repos/aitools-nobul-jose
echo "=== aitools top level"
ls -la "$A"
echo "=== aitools git status (short)"
git -C "$A" status --short | grep -v '^A  harvesting/' | head -80
echo "=== .claude tree"
find "$A/.claude" -maxdepth 3 -not -path '*/tests/*' | sort
echo "=== .cursor tree"
find "$A/.cursor" -maxdepth 3 | sort
echo "=== shared tree"
find "$A/shared" -maxdepth 2 | sort
echo "=== registries"
ls -la "$A/registries"
echo "=== reference (count + list)"
ls "$A/reference" | wc -l
ls "$A/reference"
echo "=== scripts list"
ls "$A/scripts"
echo "=== deploy (aitools frozen)"
ls "$A/deploy" | head -50
echo "=== generated?"
ls -la "$A/generated" 2>&1 | head -5
echo "=== .aitools project"
find "$A/.aitools" -maxdepth 2 | head -40
echo "=== harvesting top"
ls "$A/harvesting" | wc -l
ls -d "$A/.aitools/harvesting" 2>&1
echo "=== dotprofile tree"
find "$D" -maxdepth 3 -not -path '*/.git/*' -not -path '*/deploy/*' | sort | head -120
echo "=== dotprofile deploy list"
ls "$D/deploy" 2>&1 | head -60
echo "=== ~/.claude"
ls -la /Users/new-jose/.claude
echo "=== ~/.claude/skills"
ls -la /Users/new-jose/.claude/skills
echo "=== ~/.claude/rules"
ls -la /Users/new-jose/.claude/rules
echo "=== ~/.claude/hooks"
ls /Users/new-jose/.claude/hooks 2>&1 | head -60
echo "=== ~/.cursor/skills"
ls -la /Users/new-jose/.cursor/skills 2>&1
echo "=== ~/.cursor/rules"
ls -la /Users/new-jose/.cursor/rules 2>&1
echo "=== ~/.aitools"
find /Users/new-jose/.aitools -maxdepth 2 -not -path '*/logs/*' -not -path '*/deploy-state/*' | sort | head -60
echo "=== config.json"
cat /Users/new-jose/.aitools/config.json
