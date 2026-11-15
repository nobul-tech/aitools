#!/usr/bin/env bash
# Ship decision 13: remove the Source-of-truth protection framework.
set -euo pipefail
cd /Users/new-jose/repos/aitools
s=/Users/new-jose/repos/aitools/.scratch/session-S3-Clean
git fetch -q origin main
counts=$(git rev-list --left-right --count HEAD...origin/main)
behind=${counts##*[[:space:]]}
if [ "$behind" != "0" ]; then git pull --ff-only origin main; fi
if [ -n "$(git diff --cached --name-only)" ]; then
    printf 'ERROR: index already has staged changes\n' >&2; exit 1
fi
bash "$s/stage-readme.sh"
git rm -q -- reference/framework-source-of-truth.md
git add -- registries/framework-registry.json reference/framework-managed-file-deployment.md
git diff --cached --stat
git commit -q -F "$s/commit-msg-5.txt"
git log --oneline -1
git push origin main
