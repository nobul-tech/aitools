# setup-bash.ps1 -- Verifies Git Bash version >= 5.0 on Windows
# Safe to re-run -- detection only, no install.
#
# Windows: Bash comes from Git for Windows (Git Bash). Version depends on
# Git for Windows release. Git Bash 5.x ships with Git for Windows 2.42+.
# If bash is below 5.0, directs user to update Git for Windows.
#
# See reference/tool-registry.json for install source details.

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-bash"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$minMajor = 5
$minMinor = 0

# --- Find Git Bash ---
$bashExe = $null
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)

# Try command lookup first
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCmd) {
    $bashExe = $bashCmd.Source
} else {
    foreach ($p in $gitBashPaths) {
        if (Test-Path $p) {
            $bashExe = $p
            break
        }
    }
}

if (-not $bashExe) {
    LogError "bash not found. Install Git for Windows: https://git-scm.com/downloads/win"
    Write-Summary "ERROR" "bash" "not found"
    Write-Summary "ACTION" "" "Install Git for Windows (includes Git Bash)"
    exit 1
}

# --- Check version ---
$versionOutput = & $bashExe --version 2>&1 | Select-Object -First 1
Log "Git Bash: $versionOutput"

# Parse version number
$versionMatch = [regex]::Match($versionOutput, 'version\s+(\d+)\.(\d+)')
if (-not $versionMatch.Success) {
    LogWarn "Could not parse bash version from: $versionOutput"
    Write-Summary "WARN" "bash" "version unknown"
} else {
    $major = [int]$versionMatch.Groups[1].Value
    $minor = [int]$versionMatch.Groups[2].Value
    $fullVer = "$major.$minor"

    if ($major -gt $minMajor -or ($major -eq $minMajor -and $minor -ge $minMinor)) {
        LogOk "bash $fullVer at $bashExe (>= $minMajor.$minMinor)"
        Write-Summary "OK" "bash" "$fullVer (Git Bash)"
    } else {
        LogWarn "bash $fullVer is below minimum $minMajor.$minMinor"
        Log "Update Git for Windows to get a newer bash:"
        Log "  winget upgrade Git.Git"
        Log "  or download from https://git-scm.com/downloads/win"
        Write-Summary "WARN" "bash" "$fullVer (below minimum $minMajor.$minMinor)"
        Write-Summary "ACTION" "" "Update Git for Windows for bash >= $minMajor.$minMinor"
    }
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s)" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
