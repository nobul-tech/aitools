#!/usr/bin/env bash
# stage-checklist.sh -- stage only this session's changes for the prompt-turn
# checklist commit, leaving other sessions' uncommitted work unstaged.
set -euo pipefail

repo="/Users/new-jose/repos/aitools"
tmp="/Users/new-jose/repos/aitools/.scratch/session-90ea4d3e-19cb-4fab-b0fb-f76a60a1a386/readme-staged.tmp"

cd "$repo"

if [ -n "$(git diff --cached --name-only)" ]; then
    printf '%s [stage-checklist] [error] index already has staged changes; refusing\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
    exit 1
fi

# README: HEAD content plus only this session's row (another session's row stays unstaged).
git show HEAD:reference/README.md > "$tmp"
perl -0pi -e 's/(\| `incident-020-process-discipline\.md` \|[^\n]*\n)/$1| `prompt-turn-checklist.md` | The checklist every agent runs at each prompt turn; spec for the prompt-turn hook |\n/' "$tmp"
if ! grep -q 'prompt-turn-checklist.md' "$tmp"; then
    printf '%s [stage-checklist] [error] README row insertion failed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
    exit 1
fi
blob=$(git hash-object -w "$tmp")
git update-index --cacheinfo "100644,$blob,reference/README.md"

git add reference/prompt-turn-checklist.md registries/glossary.json .claude/rules/glossary.md

printf '%s [stage-checklist] [ok] staged:\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
git diff --cached --stat
