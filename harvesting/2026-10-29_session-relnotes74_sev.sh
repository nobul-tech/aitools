#!/usr/bin/env bash
# Print id, severity, status, title for incidents referenced by the v0.74.0 notes.
set -euo pipefail
jq -r '[.incidents[], .closed[]] | .[] | select(.id as $i | [9,29,30,31,52,53,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,95,97,98,109,110,112,114,119,122,123,124,129,130,133,134,136,144,145,171] | index($i)) | [.id, .severity, .status, .title] | @tsv' /Users/new-jose/repos/aitools/registries/incidents.json
