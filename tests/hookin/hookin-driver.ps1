# hookin-driver.ps1 -- run one PowerShell deploy-harness hook-in for test-hookin.ps1
#
# Loads the lib from SCRIPTS_DIR (a fixture copy) and the function under test from
# the real entry point, parsed with the PowerShell AST (only the function
# definitions are loaded; the entry point itself is not run), then runs it once:
#   loop  -- Invoke-DeployAbort + Deploy-Configs from scripts/aitools.ps1, run on
#            SCRIPTS_DIR; prints "LOOP rc=<errors> aborted=<True|False>"
#   step  -- Invoke-HarnessStep from scripts/aitools-install.ps1, run on
#            SCRIPTS_DIR/deploy-harness.ps1 (with @{ SkipConfig = $true } when
#            -SkipConfig is given, as Step 8b passes it); prints "STEP rc=<n>"
# The caller sets USERPROFILE/HOME, AITOOLS_LOG_DIR and AITOOLS_SUMMARY_FILE to an
# isolated test directory. Platform: Windows (pwsh 7), like the entry points it
# loads from; test-hookin.ps1 (the Windows harness) runs it, and the fixture
# deploy-harness.ps1 is the real script with its Windows guard intact
# (plans/ci-platform-targeting.md). Test helper only: not deployed.
#
# Usage: pwsh -NoProfile -File hookin-driver.ps1 -Mode loop|step -ScriptsDir DIR -RepoRoot DIR [-SkipConfig]

param(
    [Parameter(Mandatory)][ValidateSet("loop", "step")][string]$Mode,
    [Parameter(Mandatory)][string]$ScriptsDir,
    [Parameter(Mandatory)][string]$RepoRoot,
    [switch]$SkipConfig
)

. (Join-Path $ScriptsDir "aitools-lib.ps1")
Initialize-Logging "aitools"

# --- OS guard (the functions under test are Windows code) ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Load-Functions FILE NAMES -- define the named top-level functions of FILE here
function Load-Functions([string]$File, [string[]]$Names) {
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "parse errors in $File" }
    $found = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Names -contains $n.Name }, $false)
    if (@($found).Count -ne $Names.Count) { throw "expected functions $($Names -join ', ') in $File, found $(@($found).Count)" }
    foreach ($f in $found) { . ([scriptblock]::Create($f.Extent.Text)) }
    foreach ($f in $found) { Set-Item -Path "function:script:$($f.Name)" -Value (Get-Item "function:$($f.Name)").ScriptBlock }
}

if ($Mode -eq "loop") {
    $DryRun = $false
    $Force = $false
    function Show-CloudMcp { }
    function Sync-RelayToCursorAgents { }
    Load-Functions (Join-Path $RepoRoot "scripts/aitools.ps1") @("Invoke-DeployAbort", "Deploy-Configs")
    $script:deployAborted = $false
    $rc = Deploy-Configs $ScriptsDir
    [Console]::WriteLine("LOOP rc=$rc aborted=$($script:deployAborted)")
} else {
    Load-Functions (Join-Path $RepoRoot "scripts/aitools-install.ps1") @("Invoke-HarnessStep")
    $stepArgs = if ($SkipConfig) { @{ SkipConfig = $true } } else { @{} }
    $rc = Invoke-HarnessStep (Join-Path $ScriptsDir "deploy-harness.ps1") $stepArgs
    [Console]::WriteLine("STEP rc=$rc")
}
exit 0
