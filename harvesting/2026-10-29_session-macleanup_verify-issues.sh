#!/usr/bin/env bash
# verify-issues.sh -- grep origin/main for evidence on open issues (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
g() { printf '\n--- %s\n' "$*"; git -C "$R" grep -n "$@" || printf '(no match)\n'; }

echo "=== #29 EOF prompts"
g -E "read_tty_choice\(\)|read -r [a-z_]+ < /dev/tty" origin/main -- scripts/aitools-lib.sh
g -E "function Read-ConsoleChoice|ReadLine\(\)\.ToLower|UserInteractive|IsInputRedirected" origin/main -- scripts/aitools-lib.ps1

echo "=== #24 piped [ ] && log"
g -E "do \[ .* \] && log" origin/main -- scripts
g -E "tail -3|Select-Object -Last 3|head -3|Select-Object -First 3" origin/main -- scripts/setup-rust.sh scripts/setup-rust.ps1 scripts/aitools scripts/aitools.ps1

echo "=== #27 exit \$? inside if !"
g -E "failed \(exit \\\$\?\)" origin/main -- scripts/aitools
g -E "agent mcp (remove|disable)" origin/main -- scripts/setup-cursor-ide-mcp.sh scripts/setup-cursor-ide-mcp.ps1

echo "=== #28 log override order"
g -nE "^(log|log_error|log_warn)\(\)|logging_init \"aitools\"|source .*aitools-lib.sh" origin/main -- scripts/aitools

echo "=== #31 setup order"
g -nE "setup-user-settings|setup-user-hooks" origin/main -- scripts/aitools scripts/aitools-install.sh
g -nE "No settings.json yet|nothing to sync" origin/main -- scripts

echo "=== #25 Write-Host WARN in ReadConfigKey"
g -nE "Write-Host \"      WARN" origin/main -- scripts/aitools-lib.ps1

echo "=== #14 brew-only scripts"
g -nE "uname -s|apt-get|dnf|install_via_apt|install_via_brew" origin/main -- scripts/setup-typst.sh scripts/setup-uv.sh scripts/setup-go.sh scripts/setup-datadog.sh

echo "=== #19 linux-install job"
g -nE "linux-install" origin/main -- .github

echo "=== #72 Windows interactive skip"
g -nE "SKIP interactive" origin/main -- tests
