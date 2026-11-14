#!/usr/bin/env bash
# Fetch PR metadata, bodies and file lists for PRs 143-148 (read-only gh).
set -euo pipefail
out="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-docs/.scratch/session-M5-D2"
for n in 143 144 145 146 147 148; do
  gh pr view "$n" --repo nobul-tech/aitools --json number,title,mergedAt,mergeCommit,headRefName,baseRefName,body,files,commits > "$out/pr-$n.json"
  python -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); print(d['number'], d['mergedAt'], d['mergeCommit']['oid'] if d['mergeCommit'] else None, d['headRefName'], d['baseRefName'], '|', d['title'], '| files', len(d['files']))" "$out/pr-$n.json"
done
