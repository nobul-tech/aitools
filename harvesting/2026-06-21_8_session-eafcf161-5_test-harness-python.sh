#!/usr/bin/env bash
set -uo pipefail
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
logging_init "test-harness-python" >/dev/null 2>&1 || true
echo "harness_python -> $(harness_python)"
P="$(harness_python)"
echo "version       -> $("$P" --version 2>&1)"
echo "executable    -> $("$P" -c "print(__import__('sys').executable)" 2>&1)"
