# _validate-ps1.ps1 -- parse a PowerShell file and log its parse errors
# Usage: pwsh -NoProfile -File scripts/_validate-ps1.ps1 <file.ps1>
# Exit 0 when the file parses, 1 when it has parse errors or cannot be read.
# Helper module: no OS guard (.claude/rules/cross-platform.md "OS guard
# exemptions", helper modules). Logs through aitools-lib (reference/logging.md
# 8.1); each error states its cause, so it is LogError under the script name.

# Taken before the library is dot-sourced, which runs in this scope
$target = $args[0]

. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "validate-ps1"

# A missing argument or unreadable file is a parse error of its own ("line 0:
# The file could not be read: ..."), reported below like any other
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
if ($e.Count -gt 0) {
    foreach ($err in $e) { LogError "$target line $($err.Extent.StartLineNumber): $($err.Message)" }
    exit 1
} else {
    LogOk "${target}: no parse errors"
}
