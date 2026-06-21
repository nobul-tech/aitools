$ErrorActionPreference = "Stop"
# Parse-check the 4 changed .ps1 files
$files = @(
    "/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1",
    "/Users/new-jose/repos/aitools/scripts/aitools.ps1",
    "/Users/new-jose/repos/aitools/scripts/check-lib.ps1",
    "/Users/new-jose/repos/aitools/shared/shell/aliases.ps1"
)
$fail = 0
foreach ($f in $files) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) { Write-Host "PARSE FAIL: $(Split-Path $f -Leaf)"; foreach ($x in $e) { Write-Host "  $($x.Message)" }; $fail++ }
    else { Write-Host "parse OK: $(Split-Path $f -Leaf)" }
}
Write-Host "---"
# Behavioral: dot-source lib, Initialize-Logging, check logDir
. /Users/new-jose/repos/aitools/scripts/aitools-lib.ps1
Initialize-Logging "test-logging"
Write-Host "default logDir=$script:logDir"
Write-Host "default logFile=$script:logFile"
$env:AITOOLS_LOG_DIR = "/tmp/aitools-logtest-ps"
Initialize-Logging "test-logging"
Write-Host "override logDir=$script:logDir"
$env:AITOOLS_LOG_DIR = $null
Write-Host "parse failures: $fail"
