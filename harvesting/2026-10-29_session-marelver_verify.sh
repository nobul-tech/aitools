#!/usr/bin/env bash
# S3-MA-ReleaseVerify: release-note coverage and branch-deletion checks (throwaway)
set -euo pipefail
R=/Users/new-jose/repos/aitools
D=/Users/new-jose/repos/aitools/.scratch/session-marelver
cd "$R"
git fetch origin --prune --quiet

gh pr list -R nobul-tech/aitools --state merged --limit 300 --json number,headRefName,mergedAt,mergeCommit \
  --jq '.[] | "\(.number)\t\(.headRefName)\t\(.mergedAt)\t\(.mergeCommit.oid)"' | sort -n > "$D/merged.tsv"
gh pr list -R nobul-tech/aitools --state closed --limit 300 --json number,headRefName,state,mergedAt \
  --jq '.[] | select(.mergedAt == null) | "\(.number)\t\(.headRefName)"' | sort -n > "$D/closed-unmerged.tsv"
gh pr list -R nobul-tech/aitools --state open --limit 300 --json number,headRefName \
  --jq '.[] | "\(.number)\t\(.headRefName)"' | sort -n > "$D/open.tsv"

# v0.74.0 section text
perl -ne 'print if /^## v0\.74\.0/../^## v0\.73\.2/' RELEASE_NOTES.md > "$D/v074.txt"
# v0.73.2 section text and older (to know what was already covered)
perl -ne 'print if /^## v0\.73\.2/../^## v0\.73\.1/' RELEASE_NOTES.md > "$D/v0732.txt"

echo "== merged PRs >= 35 not cited as #N in v0.74.0 =="
while IFS=$'\t' read -r n br at oid; do
  if [ "$n" -ge 35 ]; then
    if ! grep -Eq "(#|pull/)$n([^0-9]|$)" "$D/v074.txt"; then
      echo "MISSING #$n $br $at"
    fi
  fi
done < "$D/merged.tsv"

echo "== merged PRs < 35 merged after 2026-10-03 =="
while IFS=$'\t' read -r n br at oid; do
  if [ "$n" -lt 35 ]; then
    case "$at" in
      2026-10-0[3-9]*|2026-10-[1-3]*) echo "LATE #$n $br $at" ;;
    esac
  fi
done < "$D/merged.tsv"

git ls-remote --heads origin | perl -pe 's{.*refs/heads/}{}' | sort > "$D/remote-heads.txt"

echo "== PR head branches no longer on origin =="
cat "$D/merged.tsv" "$D/closed-unmerged.tsv" "$D/open.tsv" > /dev/null
while IFS=$'\t' read -r n br; do
  if ! grep -Fxq "$br" "$D/remote-heads.txt"; then
    echo "OPEN-PR-BRANCH-GONE #$n $br"
  fi
done < "$D/open.tsv"
while IFS=$'\t' read -r n br; do
  if ! grep -Fxq "$br" "$D/remote-heads.txt"; then
    echo "UNMERGED-CLOSED-BRANCH-GONE #$n $br"
  fi
done < "$D/closed-unmerged.tsv"
gone=0
while IFS=$'\t' read -r n br at oid; do
  if ! grep -Fxq "$br" "$D/remote-heads.txt"; then
    gone=$((gone+1))
  fi
done < "$D/merged.tsv"
echo "merged-PR branches absent from origin: $gone"
echo "remote heads: $(wc -l < "$D/remote-heads.txt")"

echo "== tag =="
git rev-parse v0.74.0^{commit}
git merge-base --is-ancestor v0.74.0^{commit} origin/main
echo "tag commit is ancestor of origin/main: yes"
git cat-file -p v0.74.0 | perl -ne 'print if 1..6'
