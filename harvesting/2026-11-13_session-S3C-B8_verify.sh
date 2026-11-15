#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools
echo "== grep residue"
grep -nE 'sources-of-truth|/audit|`audit`|artifact-harvesting|protected' reference/rules.md reference/skills.md || echo "none"
echo "== check-path-refs"
set +e
python3 scripts/check-path-refs.py --root /Users/new-jose/repos/aitools > .scratch/session-S3C-B8/path-refs.out 2>&1
rc=$?
set -e
echo "exit: $rc"
grep -nE 'reference/(rules|skills)\.md' .scratch/session-S3C-B8/path-refs.out || echo "neither file listed"
tail -5 .scratch/session-S3C-B8/path-refs.out
echo "== diffstat"
git diff --stat -- reference/rules.md reference/skills.md
