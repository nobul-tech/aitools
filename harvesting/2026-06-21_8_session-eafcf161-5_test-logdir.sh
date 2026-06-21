#!/usr/bin/env bash
set -uo pipefail
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
logging_init "test-logging"
echo "default LOG_DIR=$LOG_DIR"
echo "default LOG_FILE=$LOG_FILE"
# Override test
AITOOLS_LOG_DIR="/tmp/aitools-logtest-$$" bash -c '
  source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
  logging_init "test-logging"
  echo "override LOG_DIR=$LOG_DIR"
'
