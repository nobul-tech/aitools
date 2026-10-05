# setup-google-chrome.ps1 -- Google Chrome for chrome-devtools-mcp on Windows: not applicable
# Safe to re-run -- changes nothing.
#
# D-CHR1 (reference/tool-ops-google-chrome.md): Google Chrome is a managed tool in the
# Claude Code web environment only, and that environment runs on Linux. On Windows the
# environment is always "local" (cross-platform.md "Environment branches", D-ENV4), so this
# script reports one "n/a (local)" summary row and exits. It exists so the .sh/.ps1 pair is
# complete and both installers run the same step (D-ENV8). Install source details:
# reference/tool-registry.md (Google Chrome).

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-google-chrome"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

Write-EnvironmentSkip -Tool "google chrome" -Reason "Google Chrome is managed only in the Claude Code web environment (D-CHR1); nothing changed"

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
