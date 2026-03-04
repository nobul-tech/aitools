# aitools-lib.ps1 -- shared helpers for all aitools PowerShell scripts
# Dot-sourced, not executed directly.
#
# Provides: ReadConfigKey, Initialize-Logging, Log/LogOk/LogError/LogWarn,
# Write-Summary, Show-Summary.
#
# Usage:
#   . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
#   Initialize-Logging "script-name"
#
# Entry points (aitools.ps1, aitools-install.ps1) override log functions after
# sourcing for specialized logging (file-only, JSONL, etc.).
#
# Platform detection uses PS 7+ built-in $IsMacOS/$IsWindows -- no custom variables.

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
# Logging init
# ---------------------------------------------------------------------------
# Sets $script:scriptName, $script:logDir, $script:logFile; resets
# $script:errors, $script:warnings. Creates log directory.
# Usage: Initialize-Logging "setup-foo"
function Initialize-Logging {
    param([Parameter(Mandatory)][string]$Name)
    $script:scriptName = $Name
    if ($IsWindows -or (-not (Test-Path variable:IsMacOS))) {
        # Windows (PS 7+) or PS 5.1 (always Windows)
        $script:logDir = Join-Path $env:LOCALAPPDATA "aitools"
    } else {
        # macOS/Linux
        $script:logDir = Join-Path $HOME "Library/Logs/aitools"
    }
    $script:logFile = Join-Path $script:logDir "deploy.log"
    if (-not (Test-Path $script:logDir)) {
        New-Item -ItemType Directory -Path $script:logDir -Force | Out-Null
    }
    $script:errors = 0
    $script:warnings = 0
}

# ---------------------------------------------------------------------------
# Standard logging (console + log file, with [level] tag)
# ---------------------------------------------------------------------------
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Add-Content -Path $logFile -Value $line
    switch ($level) {
        "error" { Write-Host $line -ForegroundColor Red }
        "warn"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) {
        Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${tool}|${detail}"
    }
}

# ---------------------------------------------------------------------------
# Summary panel renderer
# ---------------------------------------------------------------------------
# Reads AITOOLS_SUMMARY_FILE, displays colored panel, cleans up.
# Silent no-op if file unset, missing, or empty.
function Show-Summary {
    $sfile = $env:AITOOLS_SUMMARY_FILE
    if (-not $sfile -or -not (Test-Path $sfile)) { return }
    $lines = Get-Content $sfile -ErrorAction SilentlyContinue
    if (-not $lines) { Remove-Item $sfile -ErrorAction SilentlyContinue; return }
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        if ($parts[0] -eq 'OK') { Write-Host ("  [ok]  {0,-16} {1}" -f $parts[1], $parts[2]) -ForegroundColor Green }
    }
    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        if ($parts[0] -eq 'WARN') { Write-Host ("  [!]   {0,-16} {1}" -f $parts[1], $parts[2]) -ForegroundColor Yellow }
    }
    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        if ($parts[0] -eq 'ERROR') { Write-Host ("  [ERR] {0,-16} {1}" -f $parts[1], $parts[2]) -ForegroundColor Red }
    }
    $firstAction = $true
    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        if ($parts[0] -eq 'ACTION') {
            if ($firstAction) {
                Write-Host ""
                Write-Host "  ACTION REQUIRED -- run before tools are ready:" -ForegroundColor Magenta
                $firstAction = $false
            }
            Write-Host "  >>  $($parts[2])" -ForegroundColor Magenta
        }
    }
    Write-Host "------------------------------------------------------------"
    Remove-Item $sfile -ErrorAction SilentlyContinue
}
