#!/usr/bin/env bash
# build-iso2.sh REF OVERLAY_DIR -- like build-iso.sh, but first copies OVERLAY_DIR/scripts/*
# (patched files) over the clone. Isolated HOME, temp dotprofile copy. Then bash -n /
# pwsh parser on every generated deploy script.
set -uo pipefail
ref="$1"; overlay="$2"
parser=/Users/new-jose/repos/aitools/.scratch/session-rcfixc/parse.ps1
T=$(mktemp -d /tmp/rcfixc-build2.XXXXXX)
echo "T=$T"
git clone --quiet /Users/new-jose/repos/aitools "$T/aitools"
git -C "$T/aitools" fetch --quiet /Users/new-jose/repos/aitools "$ref:refs/heads/under-test"
git -C "$T/aitools" checkout --quiet under-test
cp -R "$overlay/scripts/." "$T/aitools/scripts/"
git -C "$T/aitools" status --short
git clone --quiet /Users/new-jose/repos/aitools-nobul-jose "$T/dotprofile"
mkdir -p "$T/home/.aitools"
cd "$T/aitools" || exit 1
rc=0
HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/dotprofile" bash scripts/build-deploy.sh > "$T/build.out" 2>&1 || rc=$?
echo "build rc=$rc"
tail -3 "$T/build.out"
bad=0
for f in "$T/dotprofile/deploy/"*.sh; do bash -n "$f" || bad=$((bad + 1)); done
echo "bash -n failures: $bad"
pwsh -NoProfile -File "$parser" "$T/dotprofile/deploy/"*.ps1 | grep -c "parse ok"
pwsh -NoProfile -File "$parser" "$T/dotprofile/deploy/"*.ps1 | grep "PARSE-ERROR"
echo "done"
