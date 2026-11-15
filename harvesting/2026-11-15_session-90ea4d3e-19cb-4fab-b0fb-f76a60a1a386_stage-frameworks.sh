#!/usr/bin/env bash
# stage-frameworks.sh -- stage this session's framework files and only this
# session's two README rows (another session's uncommitted row stays unstaged).
set -euo pipefail

repo="/Users/new-jose/repos/aitools"
tmp="/Users/new-jose/repos/aitools/.scratch/session-90ea4d3e-19cb-4fab-b0fb-f76a60a1a386/readme-frameworks.tmp"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cd "$repo"

if [ -n "$(git diff --cached --name-only)" ]; then
    printf '%s [stage-frameworks] [error] index already has staged changes; refusing\n' "$(ts)" >&2
    exit 1
fi

git show HEAD:reference/README.md > "$tmp"
perl -0pi -e 's/(\| `framework-managed-file-deployment\.md` \|[^\n]*\n)/$1| `framework-mission-command.md` | Mission command (disciplined initiative, backbrief, confirmation brief): sources for checklist items 2 and 4 |\n/' "$tmp"
perl -0pi -e 's/(\| `framework-provenance\.md` \|[^\n]*\n)/$1| `framework-request-for-information.md` | Request for information (construction and military RFIs): sources for session RFIs, checklist item 5 |\n/' "$tmp"
for name in framework-mission-command.md framework-request-for-information.md; do
    if ! grep -q "$name" "$tmp"; then
        printf '%s [stage-frameworks] [error] README row for %s not inserted\n' "$(ts)" "$name" >&2
        exit 1
    fi
done
blob=$(git hash-object -w "$tmp")
git update-index --cacheinfo "100644,$blob,reference/README.md"

git add reference/framework-mission-command.md reference/framework-request-for-information.md registries/framework-registry.json reference/prompt-turn-checklist.md

printf '%s [stage-frameworks] [ok] staged:\n' "$(ts)"
git diff --cached --stat
