#!/usr/bin/env bash
# Wait (max 20 min) for the verifier report. Scratch.
set -euo pipefail
f=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/S3-Handoff-V-verification.md
for _ in $(seq 1 240); do
    if [ -s "$f" ]; then
        sleep 5
        echo "report ready"
        exit 0
    fi
    sleep 5
done
echo "timeout"
exit 1
