# check-prereq-detection.ps1 -- verify build prerequisite KnownPaths coverage
# and Ensure-ToolOnPath availability
# Usage: .\scripts\check-prereq-detection.ps1
# Platform: Windows
param([switch]$Fix)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    Write-Host "Use check-prereq-detection.sh on macOS"; exit 1
}

ResolveConfig
CheckLogInit "prereq-detection"

Set-Location $script:RepoRoot

Write-Host ""
Write-Host "=== PREREQ DETECTION CHECKLIST ===" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Ensure-ToolOnPath function exists
# ---------------------------------------------------------------------------
# Get-Command exempt: checking function existence with explicit fallback
$etop = Get-Command Ensure-ToolOnPath -ErrorAction SilentlyContinue
if ($etop) {
    StepPass "1" "Ensure-ToolOnPath function exists"
} else {
    StepFail "1" "Ensure-ToolOnPath function exists" "not found after sourcing aitools-lib"
}

# ---------------------------------------------------------------------------
# 2. BuildPrereqs table loaded
# ---------------------------------------------------------------------------
$prereqTable = $script:BuildPrereqs
if (-not $prereqTable) {
    StepFail "2" "BuildPrereqs table loaded" "table is null or empty"
} else {
    StepPass "2" "BuildPrereqs table loaded" "$($prereqTable.Keys.Count) ecosystem(s)"
}

# ---------------------------------------------------------------------------
# 3. Each Windows entry with a Check scriptblock has KnownPaths + ToolName
# ---------------------------------------------------------------------------
$missingFields = @()
foreach ($ecosystem in $prereqTable.Keys) {
    foreach ($entry in $prereqTable[$ecosystem]) {
        if ($entry.Platform -eq "mac") { continue }
        # MSVC Build Tools uses vswhere, not Get-Command -- exempt from KnownPaths
        if ($entry.Name -eq "MSVC Build Tools") { continue }
        if ($entry.Check -and -not $entry.KnownPaths) {
            $missingFields += "$ecosystem/$($entry.Name) (no KnownPaths)"
        }
        if ($entry.Check -and -not $entry.ToolName) {
            $missingFields += "$ecosystem/$($entry.Name) (no ToolName)"
        }
    }
}
if ($missingFields.Count -eq 0) {
    StepPass "3" "KnownPaths + ToolName coverage" "all Windows entries have fallback fields"
} else {
    StepFail "3" "KnownPaths + ToolName coverage" "missing: $($missingFields -join ', ')"
}

# ---------------------------------------------------------------------------
# 4. KnownPaths entries use valid path formats
# ---------------------------------------------------------------------------
$badPaths = @()
foreach ($ecosystem in $prereqTable.Keys) {
    foreach ($entry in $prereqTable[$ecosystem]) {
        if (-not $entry.KnownPaths) { continue }
        if ($entry.Platform -eq "mac") { continue }
        foreach ($kp in $entry.KnownPaths) {
            if ($kp -notmatch '\.\w+$') {
                $badPaths += "$($entry.Name): $kp (no file extension)"
            }
        }
    }
}
if ($badPaths.Count -eq 0) {
    StepPass "4" "KnownPaths format validation" "all paths have file extensions"
} else {
    StepFail "4" "KnownPaths format validation" "issues: $($badPaths -join '; ')"
}

# ---------------------------------------------------------------------------
# 5. Check-BuildPrereqs function exists and is callable
# ---------------------------------------------------------------------------
# Get-Command exempt: checking function existence with explicit fallback
$fn = Get-Command Check-BuildPrereqs -ErrorAction SilentlyContinue
if ($fn) {
    StepPass "5" "Check-BuildPrereqs function exists"
} else {
    StepFail "5" "Check-BuildPrereqs function exists" "not found after sourcing aitools-lib"
}

# ---------------------------------------------------------------------------
# 6. Check-BuildPrereqs returns array (not error) for known ecosystem
# ---------------------------------------------------------------------------
if ($fn) {
    try {
        $result = Check-BuildPrereqs "cargo"
        StepPass "6" "Check-BuildPrereqs callable" "returned $($result.Count) missing prereq(s)"
    } catch {
        StepFail "6" "Check-BuildPrereqs callable" "threw error: $_"
    }
} else {
    StepSkip "6" "Check-BuildPrereqs callable" "function not loaded"
}

# ---------------------------------------------------------------------------
# 7. Check-BuildPrereqs returns empty for unknown ecosystem (no crash)
# ---------------------------------------------------------------------------
if ($fn) {
    try {
        $result = Check-BuildPrereqs "nonexistent_ecosystem_test"
        if ($result.Count -eq 0) {
            StepPass "7" "Unknown ecosystem handling" "returns empty array"
        } else {
            StepWarn "7" "Unknown ecosystem handling" "returned $($result.Count) items unexpectedly"
        }
    } catch {
        StepFail "7" "Unknown ecosystem handling" "threw error: $_"
    }
} else {
    StepSkip "7" "Unknown ecosystem handling" "function not loaded"
}

# ---------------------------------------------------------------------------
# 8. setup-rust.ps1 uses Ensure-ToolOnPath for NASM (not bare Get-Command)
# ---------------------------------------------------------------------------
$rustScript = Join-Path $script:RepoRoot "scripts\setup-rust.ps1"
if (Test-Path $rustScript) {
    $rustContent = Get-Content $rustScript -Raw
    if ($rustContent -match 'Ensure-ToolOnPath.*nasm') {
        StepPass "8" "setup-rust.ps1 uses Ensure-ToolOnPath" "NASM post-install PATH fix"
    } else {
        StepFail "8" "setup-rust.ps1 uses Ensure-ToolOnPath" "NASM install still uses bare Get-Command"
    }
} else {
    StepSkip "8" "setup-rust.ps1 uses Ensure-ToolOnPath" "file not found"
}

# ---------------------------------------------------------------------------
# 9. setup-datadog.ps1 calls Refresh-Path before Check-BuildPrereqs
# ---------------------------------------------------------------------------
$ddScript = Join-Path $script:RepoRoot "scripts\setup-datadog.ps1"
if (Test-Path $ddScript) {
    $ddContent = Get-Content $ddScript -Raw
    if ($ddContent -match 'Refresh-Path[\s\S]{0,200}Check-BuildPrereqs') {
        StepPass "9" "setup-datadog.ps1 Refresh-Path" "called before Check-BuildPrereqs"
    } else {
        StepFail "9" "setup-datadog.ps1 Refresh-Path" "not found before Check-BuildPrereqs"
    }
} else {
    StepSkip "9" "setup-datadog.ps1 Refresh-Path" "file not found"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
PrintSummary
exit $script:FailCount
