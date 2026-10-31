#!/usr/bin/env bash
# merge-revert-test.sh -- does an accepted-but-not-adopted merge survive the next run?
# Simulates the [m]erge -> [y] outcome of deploy_managed_file, then re-runs a deploy
# with the unchanged source. Isolated HOME; never touches the real ~/.aitools.
set -euo pipefail
T="/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/merge-revert-home"
rm -rf "$T"
mkdir -p "$T"
export HOME="$T"
export AITOOLS_LOG_DIR="$T/logs"
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
logging_init "merge-revert-test"
DEST="$T/.aitools/reference/sample.md"
SRC_V1=$'# Sample\nline from source v1'
SRC_V2=$'# Sample\nline from source v2'
LOCAL_EDIT=$'# Sample\nline from source v1\nmy local note'
MERGED=$'# Sample\nline from source v2\nmy local note'

deploy_managed_file "$SRC_V1" "$DEST" "test" "sample.md" ""
echo "run1: $MANAGED_FILE_RESULT"
printf '%s\n' "$LOCAL_EDIT" > "$DEST"
# Simulate deploy_managed_file's [m]erge -> [y] branch exactly: write merged, record state.
printf '%s\n' "$MERGED" > "$DEST"
update_deploy_state "$DEST" "$MERGED"
echo "after merge, file:"
cat "$DEST"
# Next run: source unchanged (still v2), non-interactive.
deploy_managed_file "$SRC_V2" "$DEST" "test" "sample.md" "" < /dev/null
echo "run3: $MANAGED_FILE_RESULT"
echo "file now:"
cat "$DEST"
