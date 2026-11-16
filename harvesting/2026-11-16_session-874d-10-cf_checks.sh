#!/usr/bin/env bash
# checks.sh -- forensic checks on 874d-8 work products (read-only)
set -uo pipefail  # no -e: diff/grep exit 1 is an expected result here (throwaway forensic script)
S8=/Users/new-jose/repos/aitools/.scratch/session-874d-8-cns
SS=/Users/new-jose/repos/aitools/.scratch/session-dbd05b0c-2365-4159-9976-bc64a2af874d
RFC=/Users/new-jose/repos/aitools/rfcs/RFC-0011-structured-reports.md
T=/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d/subagents/agent-af0c5e479d52a9629.jsonl

echo "== issue body copy vs session versions (cmp exit 0 = identical)"
for f in issue-180-body-v5.4-final.md.tmp issue-180-body-v5.5.md.tmp; do
  if cmp -s "$S8/issue-180-body.tmp" "$SS/$f"; then echo "identical: $f"; else echo "differs: $f"; diff "$S8/issue-180-body.tmp" "$SS/$f" | wc -l | tr -d ' ' | sed 's/^/  diff lines: /'; fi
done

echo "== first-person words in RFC (lines; checks scan.pl coverage)"
grep -nwE 'we|our|us|I|my|me' "$RFC" | cut -c1-160 || echo "(none)"

echo "== issue-180.tmp head (format check)"
sed -n '1,5p' "$S8/issue-180.tmp"
grep -c '^--$' "$S8/issue-180.tmp" | sed 's/^/comment separators: /'

echo "== files listed as 'Contents of' in the initial context (L14) of 874d-8"
sed -n '14p' "$T" | grep -oE 'Contents of [^ ]+' | sort -u

echo "== AAR file present?"
ls -la "$SS/874d-8-consistency-aar.json" 2>&1 || true
