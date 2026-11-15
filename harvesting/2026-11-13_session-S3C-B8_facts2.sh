#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools
echo "== harvest artifact-harvesting"; grep -n 'artifact-harvesting' shared/skills/harvest/SKILL.md || echo none
echo "== delegate sources-of-truth"; grep -n 'sources-of-truth' shared/skills/delegate/SKILL.md || echo none
echo "== delegate other paths"; grep -noE '(\.claude/rules|scripts|reference|registries|plans)/[A-Za-z0-9_./*-]+' shared/skills/delegate/SKILL.md | sort -u -t: -k3 || true
echo "== where files live"; grep -ln 'Where the files live' .claude/skills/*/SKILL.md shared/skills/*/SKILL.md || true
echo "== git log 3cebd24"; git log -1 --format='%h %ad %s' --date=short 3cebd24
echo "== incident tests"; ls .claude/skills/incident/tests
