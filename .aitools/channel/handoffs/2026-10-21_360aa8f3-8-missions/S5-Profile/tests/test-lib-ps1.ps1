# test-lib-ps1.ps1 -- functional check of the drafted PS1 wrappers on macOS
# (pwsh started with HOME pointing at an isolated test home by the caller).
$M = "/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
$env:AITOOLS_LOG_DIR = Join-Path $M "tests/run-ps1/logs"
$env:AITOOLS_PROFILE_JS = Join-Path $M "S5-Profile-drafts/scripts/aitools-profile.js"
. "/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1"
. (Join-Path $M "S5-Profile-drafts/scripts/aitools-lib.ps1.profile-block.ps1")
Initialize-Logging "s5-test-ps1"
$rc = Resolve-UserRepoPath
Write-Output "P1 rc=$rc path=$script:UserRepoPath via=$script:UserRepoVia"
$rc = Resolve-MachineProfile
Write-Output "P2 rc=$rc alias=$script:MachineAlias via=$script:MachineVia company=$script:ProfileCompany git=$script:IdentityGitEmail errors=$script:errors warnings=$script:warnings"
