#!/usr/bin/env bash
# simulate.sh NAME PR... -- in a throwaway clone under scratch, merge the given PR
# heads (origin refs of the main repo) onto origin/main in order with --no-ff, and
# report clean / conflict (files) per step. A conflicting merge is aborted and the
# simulation continues without it. The main repo is only read (fetch from it).
set -uo pipefail
R=/Users/new-jose/repos/aitools
S=/Users/new-jose/repos/aitools/.scratch/session-rcgit/sim-$1
shift
declare -A BR=(
 [97]=docs/m3-lead-plan [98]=feature/mf-config-no-machine [99]=docs/harness-approved-drafts
 [100]=feature/harness-rules-manifest [101]=docs/m3-approved-drafts [102]=docs/mf-incidents
 [103]=fix/mf-dotprofile-adopt-push [104]=docs/mf-audit [105]=docs/m3-approved-intents
 [106]=feature/harness-hookin [108]=fix/mf-audit-profile-json [109]=fix/mf-audit-consumers
 [110]=feature/harness-cursor-user-rules [111]=feature/harness-mdm-followups
 [112]=fix/mf-audit-claude-build [113]=fix/mf-lib-runner-result [114]=fix/mf-audit-config
 [115]=fix/mf-lib-relay [116]=fix/mf-installer-relay )
if [ ! -d "$S/.git" ]; then
  git init -q "$S" || exit 1
fi
git -C "$S" fetch -q "$R" '+refs/remotes/origin/*:refs/remotes/src/*' || exit 1
git -C "$S" -c advice.detachedHead=false checkout -q -f --detach src/main || exit 1
git -C "$S" config user.name sim
git -C "$S" config user.email sim@example.invalid
for n in "$@"; do
  b="src/${BR[$n]}"
  if git -C "$S" merge -q --no-ff --no-edit -m "sim merge #$n" "$b" >/dev/null 2>&1; then
    echo "#$n merged clean"
  else
    files=$(git -C "$S" diff --name-only --diff-filter=U | tr '\n' ' ')
    echo "#$n CONFLICT: $files"
    git -C "$S" merge --abort
  fi
done
