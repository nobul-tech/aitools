#!/usr/bin/env bash
# Stage batch 2: the commander's deletions, the two Cursor twins, the moved skills, the allowlist.
set -euo pipefail
cd /Users/new-jose/repos/aitools
git rm --quiet --cached -- \
    .claude/rules/relay-outbound.md \
    .claude/rules/sources-of-truth.md \
    .claude/skills/audit/SKILL.md \
    .claude/skills/audit/tests/expected-behaviors.md \
    reference/framework-artifact-harvesting.md \
    shared/rules/artifact-harvesting.md \
    shared/skills/frameworks/SKILL.md \
    shared/skills/glossary/SKILL.md \
    shared/skills/incident/SKILL.md \
    shared/skills/incident/tests/expected-behaviors.md
git rm --quiet -- .cursor/rules/relay-outbound.mdc .cursor/rules/sources-of-truth.mdc
git add -- \
    .claude/skills/frameworks/SKILL.md \
    .claude/skills/glossary/SKILL.md \
    .claude/skills/incident/SKILL.md \
    .claude/skills/incident/tests/expected-behaviors.md \
    scripts/check-path-refs-allow.txt
git diff --cached --stat -M
