# check-lib.ps1 -- shared library for check-pre-commit/pre-push/post-push scripts
# Dot-sourced, not executed directly. PS 5.1 compatible.

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
    $script:CheckLogDir = Join-Path $env:LOCALAPPDATA "aitools"
    $script:CheckLog = Join-Path $script:CheckLogDir "checks.log"
    $script:CheckJsonl = Join-Path $script:CheckLogDir "checks.jsonl"
    if (-not (Test-Path $script:CheckLogDir)) {
        New-Item -ItemType Directory -Path $script:CheckLogDir -Force | Out-Null
    }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $hostName = $env:COMPUTERNAME
    if (-not $hostName) { $hostName = hostname }
    Add-Content -Path $script:CheckLog -Value "[$ts] [$Name] === RUN START ==="
    Add-Content -Path $script:CheckJsonl -Value "{`"ts`":`"$ts`",`"check`":`"$Name`",`"event`":`"run_start`",`"host`":`"$hostName`",`"os`":`"Windows`"}"
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

# ---------------------------------------------------------------------------
# Config reader (PS 5.1 compatible)
# ---------------------------------------------------------------------------
function ReadConfigKey {
    param([string]$File, [string]$Key)
    if (-not (Test-Path $File)) { return $null }
    try {
        $json = Get-Content $File -Raw -ErrorAction Stop | ConvertFrom-Json
        $val = $json.$Key
        if ($val) { return $val }
    } catch {
        # File exists but is invalid JSON -- warn so callers know the null
        # return means "corrupt", not "missing key"
        Write-Host "      WARN: could not parse $File" -ForegroundColor Yellow
    }
    return $null
}

# ---------------------------------------------------------------------------
# Repo root and config resolution
# ---------------------------------------------------------------------------
# $script:RepoRoot must be set by the sourcing script (via $PSScriptRoot).

function ResolveConfig {
    $script:ConfigFile = Join-Path $HOME ".aitools/config.json"
    $script:UserRepoPath = ""
    if (Test-Path $script:ConfigFile) {
        $val = ReadConfigKey -File $script:ConfigFile -Key "userRepoPath"
        if ($val) { $script:UserRepoPath = $val }
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

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
$script:IsMacOS = ($PSVersionTable.PSEdition -eq "Core") -and $IsMacOS
$script:IsWindowsOS = (-not $script:IsMacOS)
# On PS 5.1 (Windows only), $IsMacOS doesn't exist, so IsWindowsOS defaults to true
if ($PSVersionTable.PSVersion.Major -le 5) {
    $script:IsWindowsOS = $true
    $script:IsMacOS = $false
}
