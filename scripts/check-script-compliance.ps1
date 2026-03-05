# check-script-compliance.ps1 -- Verify setup scripts follow script-standards.md
# Usage: pwsh -File scripts/check-script-compliance.ps1
# Checks: log format, exit footers, write_summary coverage, counter tracking,
#          raw echo/Write-Host, OS guards, logging init, cross-platform pairing,
#          SilentlyContinue result checks, summary categories.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Host "Use check-script-compliance.sh on macOS/Linux"
    exit 1
}

CheckLogInit "script-compliance"

Set-Location $repoRoot

Write-Host ""
Write-Host "=== SCRIPT STANDARDS COMPLIANCE ===" -ForegroundColor White
Write-Host ""

# Collect target scripts
$shScripts = @(Get-ChildItem "scripts/setup-*.sh" -ErrorAction SilentlyContinue)
$shScripts += @(Get-Item "scripts/aitools-install.sh" -ErrorAction SilentlyContinue)
$shScripts = @($shScripts | Where-Object { $_ })

$ps1Scripts = @(Get-ChildItem "scripts/setup-*.ps1" -ErrorAction SilentlyContinue)
$ps1Scripts += @(Get-Item "scripts/aitools-install.ps1" -ErrorAction SilentlyContinue)
$ps1Scripts = @($ps1Scripts | Where-Object { $_ })

# ---------------------------------------------------------------------------
# 1. Log format compliance -- verify lib produces [ts] [script] [level] msg
# ---------------------------------------------------------------------------
$libContent = Get-Content "scripts/aitools-lib.ps1" -Raw -ErrorAction SilentlyContinue
if ($libContent -match '\[\$level\]' -or $libContent -match '\[level\]') {
    StepPass "1" "Log format compliance" "aitools-lib.ps1 uses [level] format"
} else {
    StepFail "1" "Log format compliance" "aitools-lib.ps1 missing [level] in format"
}

# ---------------------------------------------------------------------------
# 2. Exit footer pattern -- every setup script has warnings check
# ---------------------------------------------------------------------------
$step2Fail = 0
$step2Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'warnings') {
        $step2Fail++
        $step2Details += $f.Name
    }
}

if ($step2Fail -eq 0) {
    StepPass "2" "Exit footer pattern" "all PS1 scripts check warnings"
} else {
    StepFail "2" "Exit footer pattern" "$step2Fail scripts missing warnings: $($step2Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 3. write_summary coverage -- every exit 1 has preceding Write-Summary
#    Exempt: OS guard exits, main exit footer, log_error exits
# ---------------------------------------------------------------------------
$step3Fail = 0
$step3Details = @()
foreach ($f in $ps1Scripts) {
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue)
    if (-not $lines) { continue }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*exit 1' -and $lines[$i] -notmatch '^\s*#') {
            # Check preceding 10 lines for context
            $start = [Math]::Max(0, $i - 10)
            $context = $lines[$start..$i] -join "`n"
            # Skip if Write-Summary present
            if ($context -match 'Write-Summary') { continue }
            # Skip main exit footer
            if ($context -match '\$errors') { continue }
            # Skip OS guard exits
            if ($context -match 'IsWindows|IsMacOS') { continue }
            # Skip LogError exits (error tracked by counter)
            if ($context -match 'LogError') { continue }
            $step3Fail++
            $step3Details += "$($f.Name):$($i + 1)"
        }
    }
}

if ($step3Fail -eq 0) {
    StepPass "3" "Write-Summary before exit 1" "all early exits have summary"
} else {
    StepFail "3" "Write-Summary before exit 1" "$step3Fail gaps: $($step3Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 4. Error counter tracking -- LogError increments $script:errors in lib
# ---------------------------------------------------------------------------
if ($libContent -match 'LogError.*errors\+\+') {
    StepPass "4" "Error counter tracking (PS1)" "LogError increments errors"
} else {
    StepFail "4" "Error counter tracking (PS1)" "LogError does not increment errors"
}

# ---------------------------------------------------------------------------
# 5. Warning counter tracking -- LogWarn increments $script:warnings in lib
# ---------------------------------------------------------------------------
if ($libContent -match 'LogWarn.*warnings\+\+') {
    StepPass "5" "Warning counter tracking (PS1)" "LogWarn increments warnings"
} else {
    StepFail "5" "Warning counter tracking (PS1)" "LogWarn does not increment warnings"
}

# ---------------------------------------------------------------------------
# 6. No raw Write-Host in setup scripts
# ---------------------------------------------------------------------------
$step6Fail = 0
$step6Details = @()
foreach ($f in $ps1Scripts) {
    # Skip aitools-install.ps1 (has legitimate Write-Host for prompts)
    if ($f.Name -eq "aitools-install.ps1") { continue }
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue)
    $rawCount = 0
    foreach ($line in $lines) {
        if ($line -match '^\s*Write-Host\s' -and $line -notmatch '^\s*#') {
            $rawCount++
        }
    }
    if ($rawCount -gt 0) {
        $step6Fail += $rawCount
        $step6Details += "$($f.Name)($rawCount)"
    }
}

if ($step6Fail -eq 0) {
    StepPass "6" "No raw Write-Host in setup scripts" "all use structured logging"
} else {
    StepWarn "6" "No raw Write-Host in setup scripts" "$step6Fail raw Write-Host(s): $($step6Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 7. Grep pipefail safety (bash only -- skip for PS1)
# ---------------------------------------------------------------------------
StepSkip "7" "Grep pipefail safety" "PS1 only -- not applicable"

# ---------------------------------------------------------------------------
# 8. OS guard present
# ---------------------------------------------------------------------------
$step8Fail = 0
$step8Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'IsWindows' -and $content -notmatch 'IsMacOS') {
        $step8Fail++
        $step8Details += $f.Name
    }
}

if ($step8Fail -eq 0) {
    StepPass "8" "OS guard present (.ps1)" "all have IsWindows/IsMacOS guard"
} else {
    StepFail "8" "OS guard present (.ps1)" "$step8Fail missing: $($step8Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 9. Logging init present
# ---------------------------------------------------------------------------
$step9Fail = 0
$step9Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'Initialize-Logging') {
        $step9Fail++
        $step9Details += $f.Name
    }
}

if ($step9Fail -eq 0) {
    StepPass "9" "Logging init present (.ps1)" "all call Initialize-Logging"
} else {
    StepFail "9" "Logging init present (.ps1)" "$step9Fail missing: $($step9Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 10. Cross-platform pairing
# ---------------------------------------------------------------------------
$step10Fail = 0
$step10Details = @()
foreach ($f in $ps1Scripts) {
    $base = $f.BaseName
    $shFile = "scripts/$base.sh"
    if (-not (Test-Path $shFile)) {
        $step10Fail++
        $step10Details += "$($f.Name)"
    }
}
foreach ($f in $shScripts) {
    $base = $f.BaseName
    $ps1File = "scripts/$base.ps1"
    if (-not (Test-Path $ps1File)) {
        $step10Fail++
        $step10Details += "$($f.Name)"
    }
}

if ($step10Fail -eq 0) {
    StepPass "10" "Cross-platform pairing" "all .sh have .ps1 and vice versa"
} else {
    StepFail "10" "Cross-platform pairing" "$step10Fail unpaired: $($step10Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 11. -ErrorAction SilentlyContinue has result check (PS1 scripts)
# ---------------------------------------------------------------------------
$step11Fail = 0
$step11Details = @()
foreach ($f in $ps1Scripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'ErrorAction SilentlyContinue' -and $lines[$i] -notmatch '^\s*#') {
            $lineno = $i + 1
            # Check next 3 lines for a null/result check
            $checkEnd = [Math]::Min($i + 3, $lines.Count - 1)
            $nearby = ($lines[($i+1)..$checkEnd]) -join "`n"
            if ($nearby -match '-not|if\s|\bif\(|\.Count|\.Length|null|catch') { continue }
            # Exempt: Get-Command checks (command existence)
            $checkStart = [Math]::Max($i - 3, 0)
            $preceding = ($lines[$checkStart..$i]) -join "`n"
            if ($preceding -match 'Get-Command') { continue }
            # Exempt: result check comment on same line
            if ($lines[$i] -match 'checked on') { continue }
            $step11Fail++
            $step11Details += "$(Split-Path $f -Leaf):$lineno"
        }
    }
}

if ($step11Fail -eq 0) {
    StepPass "11" "SilentlyContinue has result check" "all occurrences verified"
} else {
    StepFail "11" "SilentlyContinue has result check" "$step11Fail unchecked: $($step11Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 12. Write-Summary uses valid categories
# ---------------------------------------------------------------------------
$step12Fail = 0
$step12Details = @()
$validCats = @('OK', 'WARN', 'ERROR', 'ACTION', 'DETAIL')
foreach ($f in $ps1Scripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'Write-Summary\s+"(\w+)"' -and $lines[$i] -notmatch '^\s*#') {
            $cat = $Matches[1]
            if ($cat -notin $validCats) {
                $step12Fail++
                $step12Details += "$(Split-Path $f -Leaf):$($i+1)($cat)"
            }
        }
    }
}
foreach ($f in $shScripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'write_summary\s+(\w+)\s' -and $lines[$i] -notmatch '^\s*#') {
            $cat = $Matches[1]
            if ($cat -notin $validCats) {
                $step12Fail++
                $step12Details += "$(Split-Path $f -Leaf):$($i+1)($cat)"
            }
        }
    }
}

if ($step12Fail -eq 0) {
    StepPass "12" "write_summary valid categories" "all use OK/WARN/ERROR/ACTION/DETAIL"
} else {
    StepFail "12" "write_summary valid categories" "$step12Fail invalid: $($step12Details -join ', ')"
}

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
PrintSummary

if ($script:FailCount -gt 0) {
    exit 1
} else {
    exit 0
}
