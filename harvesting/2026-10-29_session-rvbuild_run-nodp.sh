#!/usr/bin/env bash
# run-nodp.sh -- build-deploy.sh with an EMPTY directory as the "dotprofile"
# (no personalisation), isolated HOME and TMPDIR. Read-only on both repos.
set -euo pipefail
R=/Users/new-jose/repos/aitools/.scratch/session-rvbuild/run1
rc=0
env HOME="$R/home" TMPDIR="$R/tmp" AITOOLS_USER_REPO_PATH="$R/nodp" \
    bash /Users/new-jose/repos/aitools/scripts/build-deploy.sh > "$R/build.log" 2>&1 || rc=$?
printf 'rc=%s\n' "$rc"
ls -la "$R/nodp/deploy" | wc -l
ls "$R/home" "$R/tmp"
grep -n -E "warn|error|Template|Profile|User rules|snapshot" "$R/build.log" | head -40
ls -l "$R/nodp/deploy" | perl -ane 'print "$F[4] $F[8]\n" if $F[4] && $F[4] >= 200000'
