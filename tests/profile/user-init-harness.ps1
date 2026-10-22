# user-init-harness.ps1 -- run the user-init block of scripts/aitools.ps1 on any OS
#
# Test helper for tests/profile/test-user-init.sh (not deployed). aitools.ps1 has
# a Windows-only guard, so this harness reads the block between
# "# --- BEGIN user init ---" and "# --- END user init ---" of <RepoPath>/scripts/aitools.ps1,
# sets up what the entry point sets up before it (aitools-lib.ps1, aitools-json.ps1,
# Initialize-Logging "aitools", $repoPath, $configFile, $script:UserAlias, -Force),
# and exits with Invoke-UserInitCommand's code. The caller provides the isolated
# HOME and the resolver test overrides (AITOOLS_PROFILE_TEST_ANY_OS=1, ..._MACHINE_ID, ..._HOSTNAME).
# Platform: PowerShell 7 on macOS/Linux/Windows. Safe to re-run.
param(
    [Parameter(Mandatory)][string]$RepoPath,
    [string]$Alias = "",
    [switch]$Force
)

$src = Join-Path $RepoPath "scripts" "aitools.ps1"
try {
    $text = [IO.File]::ReadAllText($src)
} catch {
    [Console]::Error.WriteLine("user-init-harness: cannot read ${src}: $($_.Exception.Message)")
    exit 3
}
$m = [regex]::Match($text, '(?s)# --- BEGIN user init ---.*?# --- END user init ---')
if (-not $m.Success) {
    [Console]::Error.WriteLine("user-init-harness: no user init block in $src")
    exit 3
}
$repoPath = $RepoPath
$configFile = Join-Path $HOME ".aitools" "config.json"
. (Join-Path $repoPath "scripts" "aitools-lib.ps1")
. (Join-Path $repoPath "scripts" "aitools-json.ps1")
Initialize-Logging "aitools"
$script:UserAlias = $Alias
. ([scriptblock]::Create($m.Value))
exit (Invoke-UserInitCommand)
