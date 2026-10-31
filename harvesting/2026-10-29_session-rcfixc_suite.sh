#!/usr/bin/env bash
# suite.sh REF LABEL [OUT_DIR...] -- local clone at REF (+ the scripts/ of each OUT_DIR
# copied over it), then the build under an isolated HOME and the repo's bash suites,
# each with HOME pointed at a temp dir. Results: /tmp/rcfixc-suite-LABEL.txt
set -uo pipefail
ref="$1"; label="$2"; shift 2
parser=/Users/new-jose/repos/aitools/.scratch/session-rcfixc/parse.ps1
T=$(mktemp -d /tmp/rcfixc-suite.XXXXXX)
R="/tmp/rcfixc-suite-$label.txt"
: > "$R"
say() { printf '%s\n' "$*" | tee -a "$R"; }
say "T=$T ref=$ref label=$label"
git clone --quiet /Users/new-jose/repos/aitools "$T/aitools"
git -C "$T/aitools" fetch --quiet /Users/new-jose/repos/aitools "$ref:refs/heads/under-test"
git -C "$T/aitools" checkout --quiet under-test
for o in "$@"; do cp -R "$o/scripts/." "$T/aitools/scripts/"; done
git -C "$T/aitools" status --short | tee -a "$R"
# commit the overlay so tests that use git ls-files / work trees see a clean tree
git -C "$T/aitools" -c user.name=t -c user.email=t@t commit --quiet -am "overlay" || say "(nothing to commit)"
git clone --quiet /Users/new-jose/repos/aitools-nobul-jose "$T/dotprofile"
mkdir -p "$T/home/.aitools"
cd "$T/aitools" || exit 1
rc=0
HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/dotprofile" bash scripts/build-deploy.sh > "$T/build.out" 2>&1 || rc=$?
say "build rc=$rc"
bad=0
for f in "$T/dotprofile/deploy/"*.sh; do bash -n "$f" || bad=$((bad + 1)); done
say "generated bash -n failures: $bad"
pwsh -NoProfile -File "$parser" "$T/dotprofile/deploy/"*.ps1 > "$T/parse.out" 2>&1
say "generated ps1 parse ok: $(grep -c 'parse ok' "$T/parse.out"), errors: $(grep -c 'PARSE-ERROR' "$T/parse.out")"
for t in tests/managed-files/test-managed-files.sh tests/profile/test-lib.sh tests/profile/test-config.sh \
         tests/profile/test-user-init.sh tests/logging/test-logging.sh tests/deploy-harness/test-deploy-harness.sh \
         tests/deploy-harness-mdm/test-deploy-harness-mdm.sh tests/rules-fanout-cursor/test-rules-fanout-cursor.sh; do
    trc=0
    HOME="$T/home" bash "$t" > "$T/$(basename "$t").out" 2>&1 < /dev/null || trc=$?
    say "$t rc=$trc :: $(grep -E -i 'passed|failed|PASS:|FAIL:|[0-9]+/[0-9]+' "$T/$(basename "$t").out" | tail -1)"
done
say "done"
