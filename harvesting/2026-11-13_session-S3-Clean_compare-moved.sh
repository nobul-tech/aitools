#!/usr/bin/env bash
# Compare moved project skills with their HEAD shared/ originals.
set -euo pipefail
cd /Users/new-jose/repos/aitools
for f in frameworks/SKILL.md glossary/SKILL.md incident/SKILL.md incident/tests/expected-behaviors.md; do
    printf '=== %s\n' "$f"
    git show "HEAD:shared/skills/$f" > "/Users/new-jose/repos/aitools/.scratch/session-S3-Clean/head-$(echo "$f" | tr '/' '_')"
    if diff -u "/Users/new-jose/repos/aitools/.scratch/session-S3-Clean/head-$(echo "$f" | tr '/' '_')" ".claude/skills/$f"; then
        printf 'IDENTICAL\n'
    fi
done
