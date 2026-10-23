# check-lib.ps1 -- shared library for check-pre-commit/pre-push/post-push scripts
# Dot-sourced, not executed directly. PS 5.1 compatible.

# Source base lib (provides ReadConfigKey, Resolve-UserRepoPath)
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")

# Check scripts use perl for regex extraction (steps 22a, 26, 29, 31).
# On Windows, prepend managed Strawberry Perl so it takes priority over
# Git-bundled perl (v5.38.2) inherited from Git Bash's PATH.
# Per PSO "Fail, don't mask": if Strawberry Perl isn't installed, do not
# fall back to Git's bundled version. Run `aitools install` to fix.
# See .claude/rules/cross-platform.md "Git Bash PATH shadowing".
if ($IsWindows) {
    $_spBin = "C:\Strawberry\perl\bin"   # Verified: 2026-03-12 (v5.42.0.1)
    if (Test-Path $_spBin) {
        $env:Path = "$_spBin;$env:Path"
    }
    # If Strawberry isn't installed, perl-dependent check steps fail visibly
}

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0
$script:SkipCount = 0

# ---------------------------------------------------------------------------
# File logging (checks.log + checks.jsonl)
# ---------------------------------------------------------------------------
$script:CheckLogDir = ""
$script:CheckLog = ""
$script:CheckJsonl = ""
$script:CheckName = ""

function CheckLogInit {
    param([string]$Name)
    $script:CheckName = $Name
    $script:CheckLogDir = if ($env:AITOOLS_LOG_DIR) { $env:AITOOLS_LOG_DIR } else { Join-Path $HOME ".aitools" "logs" }
    $script:CheckLog = Join-Path $script:CheckLogDir "checks.log"
    $script:CheckJsonl = Join-Path $script:CheckLogDir "checks.jsonl"
    if (-not (Test-Path $script:CheckLogDir)) {
        New-Item -ItemType Directory -Path $script:CheckLogDir -Force | Out-Null
    }
    Rotate-Log $script:CheckLog
    Rotate-Log $script:CheckJsonl
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $hostName = $env:COMPUTERNAME
    if (-not $hostName) { $hostName = hostname }
    # Record the real platform (pwsh also runs these checks on macOS and Linux).
    $osName = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } elseif ($IsLinux) { "Linux" } else { "unknown" }
    Add-Content -Path $script:CheckLog -Value "[$ts] [$Name] === RUN START ==="
    Add-Content -Path $script:CheckJsonl -Value "{`"ts`":`"$ts`",`"check`":`"$Name`",`"event`":`"run_start`",`"host`":`"$hostName`",`"os`":`"$osName`"}"

    # Bridge: initialize aitools-lib logging vars so lib functions
    # (Log, Ensure-ToolOnPath, Deploy-ManagedFile, etc.) work in check context.
    # Operational messages go to deploy.log alongside setup script output.
    $script:scriptName = $Name
    $script:logDir = $script:CheckLogDir
    $script:logFile = Join-Path $script:CheckLogDir "deploy.log"
    $script:errors = 0
    $script:warnings = 0
}

function CheckLogStep {
    param([string]$Num, [string]$Label, [string]$Result, [string]$Detail = "")
    if (-not $script:CheckLog) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $padded = $Label.PadRight(42)
    $line = "[$ts] [$($script:CheckName)] $("{0,3}" -f $Num). $padded [$Result]"
    if ($Detail) { $line += " $Detail" }
    Add-Content -Path $script:CheckLog -Value $line
    # Escape detail for JSON
    $jsonDetail = $Detail -replace '\\', '\\' -replace '"', '\"'
    Add-Content -Path $script:CheckJsonl -Value "{`"ts`":`"$ts`",`"check`":`"$($script:CheckName)`",`"step`":`"$Num`",`"label`":`"$Label`",`"result`":`"$Result`",`"detail`":`"$jsonDetail`"}"
}

# ---------------------------------------------------------------------------
# Step formatters
# ---------------------------------------------------------------------------
function StepPass {
    param([string]$Num, [string]$Label, [string]$Detail = "")
    $padded = $Label.PadRight(42)
    Write-Host ("{0,3}. {1}" -f $Num, $padded) -NoNewline
    Write-Host "[PASS]" -ForegroundColor Green -NoNewline
    if ($Detail) { Write-Host " $Detail" -NoNewline }
    Write-Host ""
    $script:PassCount++
    CheckLogStep $Num $Label "PASS" $Detail
}

function StepFail {
    param([string]$Num, [string]$Label, [string]$Detail = "")
    $padded = $Label.PadRight(42)
    Write-Host ("{0,3}. {1}" -f $Num, $padded) -NoNewline
    Write-Host "[FAIL]" -ForegroundColor Red -NoNewline
    if ($Detail) { Write-Host " $Detail" -NoNewline }
    Write-Host ""
    $script:FailCount++
    CheckLogStep $Num $Label "FAIL" $Detail
}

function StepWarn {
    param([string]$Num, [string]$Label, [string]$Detail = "")
    $padded = $Label.PadRight(42)
    Write-Host ("{0,3}. {1}" -f $Num, $padded) -NoNewline
    Write-Host "[WARN]" -ForegroundColor Yellow -NoNewline
    if ($Detail) { Write-Host " $Detail" -NoNewline }
    Write-Host ""
    $script:WarnCount++
    CheckLogStep $Num $Label "WARN" $Detail
}

function StepSkip {
    param([string]$Num, [string]$Label, [string]$Detail = "")
    $padded = $Label.PadRight(42)
    Write-Host ("{0,3}. {1}" -f $Num, $padded) -NoNewline
    Write-Host "[SKIP]" -ForegroundColor DarkGray -NoNewline
    if ($Detail) { Write-Host " $Detail" -NoNewline }
    Write-Host ""
    $script:SkipCount++
    CheckLogStep $Num $Label "SKIP" $Detail
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
function PrintSummary {
    StepDotprofileResolution
    Write-Host ""
    Write-Host "=== SUMMARY: " -NoNewline
    Write-Host "$($script:PassCount) PASS" -ForegroundColor Green -NoNewline
    Write-Host ", " -NoNewline
    Write-Host "$($script:SkipCount) SKIP" -ForegroundColor DarkGray -NoNewline
    Write-Host ", " -NoNewline
    Write-Host "$($script:WarnCount) WARN" -ForegroundColor Yellow -NoNewline
    Write-Host ", " -NoNewline
    Write-Host "$($script:FailCount) FAIL" -ForegroundColor Red -NoNewline
    Write-Host " ==="
    # Log summary to files
    if ($script:CheckLog) {
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $summaryLine = "[$ts] [$($script:CheckName)] === SUMMARY: $($script:PassCount) PASS, $($script:SkipCount) SKIP, $($script:WarnCount) WARN, $($script:FailCount) FAIL ==="
        Add-Content -Path $script:CheckLog -Value $summaryLine
        $jsonLine = "{`"ts`":`"$ts`",`"check`":`"$($script:CheckName)`",`"event`":`"run_end`",`"pass`":$($script:PassCount),`"skip`":$($script:SkipCount),`"warn`":$($script:WarnCount),`"fail`":$($script:FailCount)}"
        Add-Content -Path $script:CheckJsonl -Value $jsonLine
    }
}

# ReadConfigKey is provided by aitools-lib.ps1

# ---------------------------------------------------------------------------
# Repo root and config resolution
# ---------------------------------------------------------------------------
# $script:RepoRoot must be set by the sourcing script (via $PSScriptRoot).

# ResolveConfig -- sets $script:ConfigFile (the config.json path; check-pre-push
# step 7 copies it) and $script:UserRepoPath (the dotprofile), taken from the lib's
# one resolver (Resolve-UserRepoPath in aitools-lib.ps1; order: aitools-profile.ps1
# Resolve-UserRepo), so a check sees the same dotprofile as the setup scripts.
# $script:UserRepoVia says how it was found (env|config|convention|scan|none):
# ait-harvest.py reads only config.json, so a check about archiving must not
# treat a non-config answer as "archiving works" (check-post-push step 5).
# Called before CheckLogInit: the resolver's lines go to deploy.log under the
# init-logging name (bridge pattern, reference/script-standards-detail.md).
# rc 1 (no dotprofile, shared-only mode) is not an error in a check: UserRepoPath
# stays empty and callers skip their dotprofile steps.
# rc 3 was already logged by the lib (LogError, ERROR row when a run summary
# exists); UserRepoPath stays empty, so those steps skip too. CheckLogInit
# then resets $script:errors, so the rc is kept in $script:UserRepoRc and
# PrintSummary adds one WARN step for it: a broken dotprofile is never a clean
# check run (audit A-24; the exit code still follows FAIL steps only).
$script:UserRepoRc = 0
function ResolveConfig {
    $script:ConfigFile = Join-Path $HOME ".aitools/config.json"
    $script:UserRepoPath = ""
    $script:UserRepoVia = "none"
    $script:UserRepoRc = 0
    $rc = Resolve-UserRepoPath
    $script:UserRepoPath = $script:AitLibUserRepoPath
    if ($script:AitLibUserRepoVia) { $script:UserRepoVia = $script:AitLibUserRepoVia }
    $script:UserRepoRc = $rc
    if ($rc -ne 0 -and $rc -ne 1) {
        Log "dotprofile unresolved (resolver error above) -- dotprofile steps skip as 'not configured'; the run reports a WARN step"
    }
}

# StepDotprofileResolution -- the WARN step for a resolver error kept by
# ResolveConfig ($script:UserRepoRc other than 0 or 1). Called by PrintSummary,
# so it is counted in the run summary. No-op when ResolveConfig did not run.
function StepDotprofileResolution {
    $rc = $script:UserRepoRc
    if ($rc -ne 0 -and $rc -ne 1) {
        StepWarn "0" "Dotprofile resolution" "resolver error (rc $rc, see deploy.log) -- dotprofile steps reported 'not configured'"
    }
}

# ---------------------------------------------------------------------------
# Git wrapper (suppress stderr warnings under $ErrorActionPreference = Stop)
# ---------------------------------------------------------------------------
# PowerShell treats ANY stderr output from native commands as a terminating
# error when $ErrorActionPreference is 'Stop'. Git emits harmless warnings
# (CRLF conversion, etc.) to stderr, which crashes the script. This wrapper
# temporarily lowers the preference so git can run without blowing up.
function InvokeGit {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @args 2>$null
        return $output
    } finally {
        $ErrorActionPreference = $prev
    }
}

# Platform detection ($IsMacOS, $IsWindows) is built-in to PS 7+.
