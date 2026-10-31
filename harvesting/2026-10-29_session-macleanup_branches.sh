#!/usr/bin/env bash
# branches.sh -- classify (and optionally delete) remote head branches of merged PRs #50-#120.
# Usage: branches.sh [--delete]
# Deletes only when: PR state MERGED, remote branch exists, branch is ancestor of origin/main,
# branch is not main, and no OPEN PR uses the branch as head or base.
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
OUT=/Users/new-jose/repos/aitools/.scratch/session-macleanup
MODE="${1:-dry}"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [branches] [%s] %s\n' "$(ts)" "$1" "$2"; }

gh pr list -R nobul-tech/aitools --state all --limit 300 \
  --json number,state,headRefName \
  --jq '.[] | select(.number >= 50 and .number <= 120) | [.number, .state, .headRefName] | @tsv' \
  > "$OUT/prs.tsv"
gh pr list -R nobul-tech/aitools --state open --limit 300 \
  --json headRefName,baseRefName --jq '.[] | .headRefName, .baseRefName' > "$OUT/open-refs.txt"
git -C "$REPO" ls-remote --heads origin | cut -f2 > "$OUT/remote-heads.txt"

if [ ! -s "$OUT/prs.tsv" ]; then
  log error "no PRs returned by gh"; exit 1
fi

while IFS="$(printf '\t')" read -r num state br; do
  if [ "$br" = "main" ]; then log info "#$num $br SKIP main"; continue; fi
  if ! grep -qxF "refs/heads/$br" "$OUT/remote-heads.txt"; then
    log info "#$num $state $br ABSENT (already deleted)"; continue
  fi
  if [ "$state" != "MERGED" ]; then log info "#$num $state $br KEEP (not merged)"; continue; fi
  if grep -qxF "$br" "$OUT/open-refs.txt"; then log warn "#$num $br KEEP (used by an open PR)"; continue; fi
  if git -C "$REPO" merge-base --is-ancestor "origin/$br" origin/main; then
    if [ "$MODE" = "--delete" ]; then
      if git -C "$REPO" push origin --delete "$br" > "$OUT/push-$num.log" 2>&1; then
        log ok "#$num $br DELETED (ancestor of origin/main)"
      else
        log error "#$num $br delete FAILED: $(tr '\n' ' ' < "$OUT/push-$num.log")"
      fi
    else
      log info "#$num $br DELETABLE (ancestor of origin/main)"
    fi
  else
    log warn "#$num $br KEEP (not contained in origin/main) tip=$(git -C "$REPO" rev-parse --short "origin/$br")"
  fi
done < "$OUT/prs.tsv"
