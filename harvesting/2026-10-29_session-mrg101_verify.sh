#!/usr/bin/env bash
# verify.sh - post-merge local checks for PR #101 (docs-only) on an exported tree.
set -euo pipefail
tree="/Users/new-jose/repos/aitools/.scratch/session-mrg101/tree"
export HOME="/Users/new-jose/repos/aitools/.scratch/session-mrg101/home"
cd "$tree"
printf '%s\n' "== glossary.json parse"
python3 -c 'import json,sys; d=json.load(open("registries/glossary.json")); print("ok, top-level keys:", sorted(d.keys()))'
printf '%s\n' "== managed-files tests (bash)"
bash tests/managed-files/test-managed-files.sh > "$HOME/../mf.log" 2>&1
printf '%s\n' "managed-files exit 0"
printf '%s\n' "== logging tests (bash)"
bash tests/logging/test-logging.sh > "$HOME/../log.log" 2>&1
printf '%s\n' "logging exit 0"
printf '%s\n' "done"
