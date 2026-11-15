#!/usr/bin/env bash
# Find scripts/tests/hooks that name the moved skills as skill paths or list entries.
set -euo pipefail
cd /Users/new-jose/repos/aitools
git ls-files scripts tests shared/hooks .github packaging | grep -v '^tests/hooks/fixtures/' \
  | xargs grep -nIE "skills/(frameworks|glossary|incident)|['\"](frameworks|glossary|incident)['\"]|\b(frameworks|glossary|incident)\b.*skill|skill.*\b(frameworks|glossary|incident)\b" \
  | cut -c1-220 || true
