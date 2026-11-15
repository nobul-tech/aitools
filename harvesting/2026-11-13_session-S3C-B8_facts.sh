#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools
echo "== shared skills"; ls shared/skills
echo "== project skills"; ls .claude/skills
echo "== tests dirs"; ls -d shared/skills/*/tests .claude/skills/*/tests 2>&1 || true
echo "== disable-model-invocation"; grep -rl 'disable-model-invocation' shared/skills .claude/skills || echo none
echo "== shared rules"; ls shared/rules
echo "== project rules count"; ls .claude/rules | wc -l
echo "== reference/artifact-harvesting.md"; ls reference/artifact-harvesting.md
echo "== grep rules.md"; grep -nE 'sources-of-truth|protected|/audit|`audit`|artifact-harvesting|shared/skills|governance skills|seven|20 |22 |7 ' reference/rules.md || true
echo "== grep skills.md"; grep -nE 'sources-of-truth|protected|/audit|`audit`|artifact-harvesting|shared/skills|governance skills|seven|Seven|20 |22 |7 ' reference/skills.md || true
