#!/usr/bin/env bash
# Run the brief schema check on the three language reviewers' briefs.
set -euo pipefail
d=/Users/new-jose/repos/aitools/.scratch/session-dbd05b0c-2365-4159-9976-bc64a2af874d
for m in 874d-7-normative-language 874d-8-consistency 874d-9-implementer-read; do
    printf '%s: ' "$m"
    python3 "$d/check-brief-schema.py" "$d/$m-brief.json"
done
