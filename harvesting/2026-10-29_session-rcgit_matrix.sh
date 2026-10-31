#!/usr/bin/env bash
# matrix.sh -- for open PRs 97-116 (not 107): merge-base vs origin/main, ancestry
# between heads, and pairwise textual conflicts (git merge-tree --write-tree), plus
# each PR's conflict state against current origin/main.
set -uo pipefail
R=/Users/new-jose/repos/aitools
declare -a N B
N=(97 98 99 100 101 102 103 104 105 106 108 109 110 111 112 113 114 115 116)
B=(docs/m3-lead-plan feature/mf-config-no-machine docs/harness-approved-drafts feature/harness-rules-manifest docs/m3-approved-drafts docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit docs/m3-approved-intents feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay)
git --version
echo "## merge-base with origin/main, and merge-tree vs origin/main"
for i in "${!N[@]}"; do
  b="origin/${B[$i]}"
  mb=$(git -C "$R" merge-base origin/main "$b" | cut -c1-7)
  out=$(git -C "$R" merge-tree --write-tree --name-only origin/main "$b" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then st=clean; else st="CONFLICT: $(printf '%s\n' "$out" | sed -n '2,/^$/p' | tr '\n' ' ')"; fi
  echo "#${N[$i]} mb=$mb vs-main=$st"
done
echo "## ancestry (A < B means A's head is an ancestor of B's head)"
for i in "${!N[@]}"; do for j in "${!N[@]}"; do
  [ "$i" = "$j" ] && continue
  if git -C "$R" merge-base --is-ancestor "origin/${B[$i]}" "origin/${B[$j]}"; then echo "#${N[$i]} < #${N[$j]}"; fi
done; done
echo "## pairwise merge-tree (only pairs that share a changed file)"
for i in "${!N[@]}"; do
  fi_=$(git -C "$R" diff --name-only origin/main..."origin/${B[$i]}" | sort)
  for j in "${!N[@]}"; do
    [ "$j" -le "$i" ] && continue
    fj=$(git -C "$R" diff --name-only origin/main..."origin/${B[$j]}" | sort)
    common=$(comm -12 <(printf '%s\n' "$fi_") <(printf '%s\n' "$fj") | tr '\n' ' ')
    [ -z "${common// /}" ] && continue
    out=$(git -C "$R" merge-tree --write-tree --name-only "origin/${B[$i]}" "origin/${B[$j]}" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then st=clean; else st="CONFLICT in: $(printf '%s\n' "$out" | sed -n '2,/^$/p' | tr '\n' ' ')"; fi
    echo "#${N[$i]} x #${N[$j]}: $st | shared: $common"
  done
done
