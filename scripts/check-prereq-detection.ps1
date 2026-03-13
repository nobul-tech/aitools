# check-prereq-detection.ps1 -- verify build prerequisite KnownPaths coverage
# and Ensure-ToolOnPath availability
# Usage: .\scripts\check-prereq-detection.ps1
# Platform: Windows
param([switch]$Fix)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")
. (Join-Path $scriptDir "init-logging.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use check-prereq-detection.sh."
    exit 1
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
# 10. KnownPaths empirical verification: installed tools must match KnownPath
# ---------------------------------------------------------------------------
$unverifiedPaths = @()
foreach ($ecosystem in $prereqTable.Keys) {
    foreach ($entry in $prereqTable[$ecosystem]) {
        if (-not $entry.KnownPaths -or -not $entry.ToolName) { continue }
        if ($entry.Platform -eq "mac") { continue }

        # Get-Command exempt: testing presence for conditional validation
        $installed = Get-Command $entry.ToolName -ErrorAction SilentlyContinue
        if (-not $installed) { continue }

        $anyMatch = $false
        foreach ($kp in $entry.KnownPaths) {
            if (Test-Path $kp) { $anyMatch = $true; break }
        }
        if (-not $anyMatch) {
            $unverifiedPaths += "$($entry.Name): installed at $($installed.Source) but no KnownPath matches"
        }
    }
}
if ($unverifiedPaths.Count -eq 0) {
    StepPass "10" "KnownPaths match installed tools" "all installed tools found via KnownPaths"
} else {
    StepFail "10" "KnownPaths match installed tools" ($unverifiedPaths -join '; ')
}

# ---------------------------------------------------------------------------
# 11. KnownPaths vs tool-registry.md: code paths must match documented paths
# ---------------------------------------------------------------------------
$registryPath = Join-Path $scriptDir "..\reference\tool-registry.md"
if (Test-Path $registryPath) {
    $regContent = Get-Content $registryPath -Raw
    $mismatches = @()
    foreach ($ecosystem in $prereqTable.Keys) {
        foreach ($entry in $prereqTable[$ecosystem]) {
            if (-not $entry.KnownPaths -or -not $entry.Name) { continue }
            if ($entry.Platform -eq "mac") { continue }
            foreach ($kp in $entry.KnownPaths) {
                # KnownPaths are expanded at runtime -- reverse-map to doc formats
                $searchVariants = @($kp)
                if ($env:LOCALAPPDATA -and $kp.StartsWith($env:LOCALAPPDATA, [StringComparison]::OrdinalIgnoreCase)) {
                    $searchVariants += $kp -replace [regex]::Escape($env:LOCALAPPDATA), '%LOCALAPPDATA%'
                }
                if ($env:ProgramFiles -and $kp.StartsWith($env:ProgramFiles, [StringComparison]::OrdinalIgnoreCase)) {
                    $searchVariants += $kp -replace [regex]::Escape($env:ProgramFiles), 'C:\Program Files'
                }
                $found = $false
                foreach ($variant in $searchVariants) {
                    $escaped = [regex]::Escape($variant)
                    if ($regContent -match $escaped) { $found = $true; break }
                }
                if (-not $found) {
                    $mismatches += "$($entry.Name): $kp not in tool-registry.md"
                }
            }
        }
    }
    if ($mismatches.Count -eq 0) {
        StepPass "11" "KnownPaths match tool-registry.md" "all code paths documented"
    } else {
        StepWarn "11" "KnownPaths match tool-registry.md" ($mismatches -join '; ')
    }
} else {
    StepSkip "11" "KnownPaths match tool-registry.md" "tool-registry.md not found"
}

# ---------------------------------------------------------------------------
# 12. KnownPaths verification status: entries must have Verified/UNVERIFIED
# ---------------------------------------------------------------------------
$libContent = Get-Content (Join-Path $scriptDir "aitools-lib.ps1") -Raw
$libLines = $libContent -split "`n"
$unmarked = @()
for ($i = 0; $i -lt $libLines.Count; $i++) {
    if ($libLines[$i] -match 'KnownPaths\s*=') {
        $prevLine = if ($i -ge 1) { $libLines[$i - 1] } else { "" }
        if ($prevLine -notmatch 'Verified|UNVERIFIED') {
            $unmarked += "line $($i + 1): missing verification status comment"
        }
    }
}
if ($unmarked.Count -eq 0) {
    StepPass "12" "KnownPaths verification status" "all entries have Verified/UNVERIFIED"
} else {
    StepWarn "12" "KnownPaths verification status" ($unmarked -join '; ')
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
PrintSummary
exit $script:FailCount
