#!/usr/bin/env bash
# Run the tests/ suites that CI does not run, on the origin/main clone, isolated HOME (scratch)
set -u
root=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/main-clone
logs=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/suite-logs
mkdir -p "$logs" "$logs/home"
cd "$root"
for t in tests/deploy-harness/test-deploy-harness.sh tests/deploy-harness-mdm/test-deploy-harness-mdm.sh tests/rules-fanout-cursor/test-rules-fanout-cursor.sh tests/build-package/test-cli.sh; do
    name=$(basename "$t" .sh)
    start=$(date +%s)
    env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
        HOME="$logs/home" bash "$t" > "$logs/$name.log" 2>&1
    rc=$?
    end=$(date +%s)
    tail_line=$(tail -1 "$logs/$name.log")
    fails=$(grep -c '^ *FAIL' "$logs/$name.log")
    echo "$name rc=$rc secs=$((end - start)) fails=$fails last='$tail_line'"
done
