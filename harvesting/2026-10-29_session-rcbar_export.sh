#!/usr/bin/env bash
# export origin/main into scratch tree and init a throwaway git repo for diffs
set -euo pipefail
T=/Users/new-jose/repos/aitools/.scratch/session-rcbar/tree
git -C /Users/new-jose/repos/aitools archive origin/main | tar -x -C "$T"
cd "$T"
git init -q
git add -A
git -c user.name=barrier -c user.email=barrier@localhost commit -q -m "export origin/main" --no-verify
git log --oneline -1
