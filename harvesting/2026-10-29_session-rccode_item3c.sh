#!/usr/bin/env bash
# Item 3: uniqueness of OLD anchors on #106 and other child-run sites
set -euo pipefail
R=/Users/new-jose/repos/aitools
B=origin/feature/harness-hookin
echo "-- aitools.ps1 '\$scriptRc = \$LASTEXITCODE' count:"
git -C "$R" show "$B:scripts/aitools.ps1" | grep -c 'scriptRc = \$LASTEXITCODE' || true
echo "-- aitools 'bash \"\$script_path\" || script_rc' count:"
git -C "$R" show "$B:scripts/aitools" | grep -c 'bash "\$script_path" || script_rc' || true
echo "-- aitools-install.ps1 'scriptRc = \$LASTEXITCODE' count:"
git -C "$R" show "$B:scripts/aitools-install.ps1" | grep -c 'scriptRc = \$LASTEXITCODE' || true
echo "-- installer sh: validate_and_run callers and other child runs"
git -C "$R" show "$B:scripts/aitools-install.sh" | grep -n -E 'validate_and_run |bash "\$|run_child_relayed|run_harness_step ' || true
echo "-- installer ps1: Invoke-ValidatedScript callers and other child runs"
git -C "$R" show "$B:scripts/aitools-install.ps1" | grep -n -E 'Invoke-ValidatedScript |Invoke-ChildRelayed|Invoke-HarnessStep|& \$' | tr -d '\r' || true
echo "-- line numbers of OLD anchors"
git -C "$R" show "$B:scripts/aitools-install.sh" | grep -n 'bash "\$script" || script_rc' || true
git -C "$R" show "$B:scripts/aitools-install.ps1" | grep -n 'scriptRc = \$LASTEXITCODE' || true
git -C "$R" show "$B:scripts/aitools.ps1" | grep -n 'scriptRc = \$LASTEXITCODE' || true
