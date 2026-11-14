#!/usr/bin/env bash
# make-integ.sh M1_REF -- throwaway integration worktree (detached) at M1_REF,
# with fix/menus-reask merged in and the prepared libs copied over, to run the
# suites before M1-Ship's PR merges. Never pushed.
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=C:/Users/jdpal/repos/aitools
I="$S/integ"
if [ ! -d "$I" ]; then
    git -C "$REPO" worktree add --detach "$I" "$1"
else
    git -C "$I" reset -q --hard
    git -C "$I" checkout -q --detach "$1"
    git -C "$I" reset -q --hard "$1"
fi
git -C "$I" -c user.name=M2-Reask -c user.email=noreply@anthropic.com merge --no-ff --no-edit fix/menus-reask
# The prepared libs were made from M1_REF's blobs (LF); let git apply the
# checkout line endings by writing them through the index.
for f in aitools-lib.sh aitools-lib.ps1; do
    blob=$(git -C "$I" hash-object -w "$S/prep/scripts/$f")
    mode=$(git -C "$I" ls-files -s "scripts/$f" | cut -d' ' -f1)
    git -C "$I" update-index --cacheinfo "$mode,$blob,scripts/$f"
    git -C "$I" checkout -- "scripts/$f"
done
git -C "$I" status --short
git -C "$I" log --oneline -3
