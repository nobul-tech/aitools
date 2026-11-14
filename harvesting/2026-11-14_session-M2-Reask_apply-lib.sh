#!/usr/bin/env bash
# apply-lib.sh -- write the prepared libraries (prep/scripts) and the integ
# tree's test-managed-files.ps1 into the menus-reask worktree through the
# index (so git applies the checkout line endings), keeping each file's mode.
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$S/../.."
put() {  # put SRC REPO_PATH
    local blob mode
    blob=$(git -C "$W" hash-object -w "$1")
    mode=$(git -C "$W" ls-files -s "$2" | cut -d' ' -f1)
    git -C "$W" update-index --cacheinfo "$mode,$blob,$2"
    git -C "$W" checkout -- "$2"
}
put "$S/prep/scripts/aitools-lib.sh" scripts/aitools-lib.sh
put "$S/prep/scripts/aitools-lib.ps1" scripts/aitools-lib.ps1
put "$S/integ/tests/managed-files/test-managed-files.ps1" tests/managed-files/test-managed-files.ps1
git -C "$W" status --short
git -C "$W" diff --cached --stat
git -C "$W" diff --cached --summary
