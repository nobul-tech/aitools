#!/usr/bin/env bash
# run-ps1-test.sh -- prepare an isolated HOME and run test-lib-ps1.ps1 under pwsh
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
T="$M/tests/run-ps1"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose" "$T/logs"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
printf '{"version":3,"reposPath":"%s/home/repos","repoPath":"/x","githubUser":"nobul-jose","machineAlias":"new-mac"}\n' "$T" > "$T/home/.aitools/config.json"
HOME="$T/home" pwsh -NoProfile -File "$M/tests/test-lib-ps1.ps1"
