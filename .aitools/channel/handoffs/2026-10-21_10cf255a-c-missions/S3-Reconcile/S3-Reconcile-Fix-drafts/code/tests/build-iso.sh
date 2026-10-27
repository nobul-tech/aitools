#!/usr/bin/env bash
# build-iso.sh REF -- build-deploy.sh from a local clone at REF (a ref in the main
# checkout, e.g. refs/remotes/origin/main) into a temp copy of the dotprofile,
# under an isolated HOME. Never touches the real HOME or the real dotprofile.
# Prints the temp dir; sizes of the generated deploy/ files go to $T/sizes.txt.
set -euo pipefail
ref="${1:-refs/remotes/origin/main}"
T=$(mktemp -d /tmp/rcfixc-build.XXXXXX)
echo "T=$T"
git clone --quiet /Users/new-jose/repos/aitools "$T/aitools"
git -C "$T/aitools" fetch --quiet /Users/new-jose/repos/aitools "$ref:refs/heads/under-test"
git -C "$T/aitools" checkout --quiet under-test
git clone --quiet /Users/new-jose/repos/aitools-nobul-jose "$T/dotprofile"
mkdir -p "$T/home/.aitools"
cd "$T/aitools"
rc=0
HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/dotprofile" bash scripts/build-deploy.sh > "$T/build.out" 2>&1 || rc=$?
echo "build rc=$rc"
tail -5 "$T/build.out"
wc -c "$T/dotprofile/deploy/"* | sort -n -r > "$T/sizes.txt"
head -25 "$T/sizes.txt"
