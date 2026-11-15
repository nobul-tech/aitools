#!/usr/bin/env bash
# Find live text that still describes the protected-file / pre-write review gate.
set -euo pipefail
cd /Users/new-jose/repos/aitools
git ls-files .claude/rules .cursor/rules shared reference registries scripts tests README.md ROADMAP.md CLAUDE.md .aitools/channel/CLAUDE.md \
  | grep -vE '^(tests/hooks/fixtures/|reference/do-what-feels-right\.md|reference/claude-code-effectiveness\.md)' \
  | xargs grep -nIiE 'protected file|protected per|is protected|are protected|\(protected\)|protected-file|protected files|present (it |them |both )?for (user )?review|presented for review|write (only )?(if|after) approv|review gate|wait for approval' 2>/dev/null \
  | cut -c1-200 || true
