# check-pre-commit.ps1 -- automated pre-commit checklist for aitools
# Usage: .\scripts\check-pre-commit.ps1 [-Fix]
# -Fix: auto-fix line endings, exec bits, and build freshness
# Platform: Windows (PS 5.1 compatible)
param([switch]$Fix)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")
. (Join-Path $scriptDir "init-logging.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use check-pre-commit.sh."
    exit 1
}

ResolveConfig
CheckLogInit "pre-commit"

Set-Location $script:RepoRoot

Write-Host ""
Write-Host "=== PRE-COMMIT CHECKLIST ===" -ForegroundColor White
Write-Host ""

# Collect staged files once
$stagedRaw = InvokeGit diff --cached --name-only --diff-filter=ACMR
$stagedFiles = @()
if ($stagedRaw) { $stagedFiles = @($stagedRaw -split "`n" | Where-Object { $_ }) }

$stagedSh = @($stagedFiles | Where-Object { $_ -match '\.sh$' })
$stagedPs1 = @($stagedFiles | Where-Object { $_ -match '\.ps1$' })

# ---------------------------------------------------------------------------
# 1. Git identity
# ---------------------------------------------------------------------------
$gitName = InvokeGit config user.name
$gitEmail = InvokeGit config user.email
if ($gitName -eq "Jose" -and $gitEmail -eq "jose@nobul.tech") {
    StepPass "1" "Git identity"
} else {
    StepFail "1" "Git identity" "expected Jose <jose@nobul.tech>, got $gitName <$gitEmail>"
}

# ---------------------------------------------------------------------------
# 2. Script syntax validation
# ---------------------------------------------------------------------------
if ($stagedSh.Count -eq 0 -and $stagedPs1.Count -eq 0) {
    StepSkip "2" "Script syntax (.sh)" "no scripts staged"
    StepSkip "2" "Script syntax (.ps1)" "no scripts staged"
} else {
    # Bash validation
    if ($stagedSh.Count -gt 0) {
        $shErrors = 0
        foreach ($f in $stagedSh) {
            $result = bash -n $f 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "      FAIL: $f"
                $shErrors++
            }
        }
        if ($shErrors -eq 0) {
            StepPass "2" "Script syntax (.sh)"
        } else {
            StepFail "2" "Script syntax (.sh)" "$shErrors file(s) failed"
        }
    } else {
        StepSkip "2" "Script syntax (.sh)" "no .sh staged"
    }

    # PS1 validation (on Windows, use built-in PowerShell)
    if ($stagedPs1.Count -gt 0) {
        $ps1Errors = 0
        foreach ($f in $stagedPs1) {
            $fullPath = Join-Path $script:RepoRoot $f
            $e = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$null, [ref]$e)
            if ($e.Count -gt 0) {
                Write-Host "      FAIL: $f"
                foreach ($err in $e) {
                    Write-Host "        line $($err.Extent.StartLineNumber): $($err.Message)"
                }
                $ps1Errors++
            }
        }
        if ($ps1Errors -eq 0) {
            StepPass "2" "Script syntax (.ps1)"
        } else {
            StepFail "2" "Script syntax (.ps1)" "$ps1Errors file(s) failed"
        }
    } else {
        StepSkip "2" "Script syntax (.ps1)" "no .ps1 staged"
    }
}

# ---------------------------------------------------------------------------
# 3. Build freshness
# ---------------------------------------------------------------------------
$buildNeeded = $false
foreach ($f in $stagedFiles) {
    if ($f -match '^(scripts/|shared/)' -and $f -notmatch 'README\.md$') { $buildNeeded = $true; break }
}

if ($buildNeeded) {
    if ($Fix) {
        $bashExe = (Get-Command bash -ErrorAction SilentlyContinue).Source
        if ($bashExe) {
            & $bashExe "$script:RepoRoot/scripts/build-deploy.sh" 2>$null | Out-Null
            InvokeGit add deploy/
            StepPass "3" "Build freshness" "(rebuilt + staged)"
        } else {
            StepFail "3" "Build freshness" "bash not found for build-deploy.sh"
        }
    } else {
        StepWarn "3" "Build freshness" "scripts/ or shared/ modified -- run with -Fix"
    }
} else {
    StepSkip "3" "Build freshness" "no scripts/ or shared/ changes"
}

# ---------------------------------------------------------------------------
# 4. Line endings
# ---------------------------------------------------------------------------
if ($stagedSh.Count -eq 0) {
    StepSkip "4" "Line endings (.sh)" "no .sh staged"
} else {
    $crlfFiles = @()
    foreach ($f in $stagedSh) {
        $content = [System.IO.File]::ReadAllText((Join-Path $script:RepoRoot $f))
        if ($content -match "`r`n") { $crlfFiles += $f }
    }
    if ($crlfFiles.Count -eq 0) {
        StepPass "4" "Line endings (.sh)"
    } elseif ($Fix) {
        foreach ($f in $crlfFiles) {
            $fullPath = Join-Path $script:RepoRoot $f
            $content = [System.IO.File]::ReadAllText($fullPath)
            $content = $content -replace "`r`n", "`n"
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($fullPath, $content, $utf8NoBom)
            InvokeGit add $f
        }
        StepPass "4" "Line endings (.sh)" "(fixed CRLF)"
    } else {
        StepFail "4" "Line endings (.sh)" "CRLF in: $($crlfFiles -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# 5. Platform note
# ---------------------------------------------------------------------------
if ($stagedSh.Count -gt 0 -or $stagedPs1.Count -gt 0) {
    StepWarn "5" "Platform note" "include (tested: Windows) or (tested: macOS) in commit message"
} else {
    StepSkip "5" "Platform note" "no scripts staged"
}

# ---------------------------------------------------------------------------
# 6. Executable bit on .sh files
# ---------------------------------------------------------------------------
$nonExec = InvokeGit ls-files -s '*.sh' | Where-Object { $_ -notmatch '^100755' }
if (-not $nonExec) {
    StepPass "6" "Executable bit (.sh)"
} else {
    $badFiles = @($nonExec | ForEach-Object { ($_ -split '\s+')[3] })
    if ($Fix) {
        foreach ($f in $badFiles) {
            InvokeGit update-index --chmod=+x $f
        }
        StepPass "6" "Executable bit (.sh)" "(fixed)"
    } else {
        StepFail "6" "Executable bit (.sh)" "$($badFiles.Count) file(s) missing +x"
    }
}

# ---------------------------------------------------------------------------
# 7. Install command consistency
# ---------------------------------------------------------------------------
$setupStaged = @($stagedFiles | Where-Object { $_ -match '^scripts/setup-' })
if ($setupStaged.Count -eq 0) {
    StepSkip "7" "Install cmd consistency" "no setup-* staged"
} else {
    StepWarn "7" "Install cmd consistency" "verify against the /tool-registry skill entry"
}

# ---------------------------------------------------------------------------
# 8. Config merge safety
# ---------------------------------------------------------------------------
if ($setupStaged.Count -eq 0) {
    StepSkip "8" "Config merge safety" "no setup scripts staged"
} else {
    $diffOutput = InvokeGit diff --cached -- $setupStaged
    $overwriteFound = $false
    if ($diffOutput -match '\+.*cat\s*>' -or $diffOutput -match '\+.*WriteAllText.*ConvertTo-Json') {
        $overwriteFound = $true
    }
    if ($overwriteFound) {
        StepWarn "8" "Config merge safety" "potential blind overwrite detected -- verify merge logic"
    } else {
        StepPass "8" "Config merge safety"
    }
}

# ---------------------------------------------------------------------------
# 9. Release notes
# ---------------------------------------------------------------------------
$nonDocs = @($stagedFiles | Where-Object { $_ -notmatch '\.(md|mdc)$' })
$rnStaged = $stagedFiles -contains 'RELEASE_NOTES.md'
if ($nonDocs.Count -eq 0) {
    StepSkip "9" "Release notes" "docs-only changes"
} elseif ($rnStaged) {
    StepPass "9" "Release notes"
} else {
    StepWarn "9" "Release notes" "non-docs changes without RELEASE_NOTES.md update"
}

# ---------------------------------------------------------------------------
# 10. Deploy drift check
# ---------------------------------------------------------------------------
if ($buildNeeded) {
    $deployDiff = InvokeGit diff deploy/
    if (-not $deployDiff) {
        StepPass "10" "Deploy drift"
    } else {
        StepFail "10" "Deploy drift" "unstaged deploy/ changes remain"
    }
} else {
    StepSkip "10" "Deploy drift" "no build needed"
}

# ---------------------------------------------------------------------------
# 11. User repo changes
# ---------------------------------------------------------------------------
if ($script:UserRepoPath -and (Test-Path $script:UserRepoPath)) {
    $userDirty = InvokeGit -C $script:UserRepoPath status --porcelain
    if ($userDirty) {
        StepWarn "11" "User repo changes" "uncommitted changes in $($script:UserRepoPath)"
    } else {
        StepPass "11" "User repo changes"
    }
} else {
    StepSkip "11" "User repo changes" "userRepoPath not configured"
}

# ---------------------------------------------------------------------------
# 12. Template sync
# ---------------------------------------------------------------------------
if ($stagedFiles -contains 'shared/claude-shared.md') {
    StepWarn "12" "Template sync" "update user repo template (<userRepoPath>/claude/CLAUDE.md)"
} else {
    StepSkip "12" "Template sync" "shared/claude-shared.md not modified"
}

# ---------------------------------------------------------------------------
# 13. Deploy template logic sync
# ---------------------------------------------------------------------------
$hasSetupUser = $stagedFiles | Where-Object {
    $_ -match '^scripts/setup-user-(claude|cursor|mcp|hooks)\.'
}
$hasBuildDeploy = $stagedFiles -contains 'scripts/build-deploy.sh'

if ($hasSetupUser -and -not $hasBuildDeploy) {
    StepWarn "13" "Deploy template sync" "scripts/setup-user-* changed without build-deploy.sh -- verify deploy template is up to date"
} elseif ($hasSetupUser) {
    StepPass "13" "Deploy template sync" "both scripts/ and build-deploy.sh modified"
} else {
    StepSkip "13" "Deploy template sync" "no setup-user-* scripts modified"
}

# ---------------------------------------------------------------------------
# 14. Build prerequisite framework
# ---------------------------------------------------------------------------
$prereqFail = $false

# Check: any script using 'cargo install' must call Check-BuildPrereqs or Diagnose-BuildFailure.
# `cargo install --list` only lists installed packages (no build) and is not counted.
foreach ($script in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.ps1" -ErrorAction SilentlyContinue) {
    $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match 'cargo install(?! --list)') {
        if ($content -notmatch 'Check-BuildPrereqs|Diagnose-BuildFailure') {
            Write-Host "      $($script.Name) uses 'cargo install' without build prereq framework"
            $prereqFail = $true
        }
    }
}
foreach ($script in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.sh" -ErrorAction SilentlyContinue) {
    $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match 'cargo install(?! --list)') {
        if ($content -notmatch 'check_build_prereqs|diagnose_build_failure') {
            Write-Host "      $($script.Name) uses 'cargo install' without build prereq framework"
            $prereqFail = $true
        }
    }
}

if ($prereqFail) {
    StepFail "14" "Build prereq framework" "setup scripts with source builds missing prereq checks -- see script-standards.md"
} else {
    StepPass "14" "Build prereq framework"
}

# Step 15: Deprecated summary terms
Write-Host ""
Write-Host "--- Step 15: Deprecated summary terms ---" -ForegroundColor White
$shHits = Select-String -Path (Get-ChildItem "$script:RepoRoot/scripts/*.sh" | Where-Object { $_.Name -notlike 'check-*' }) -Pattern 'write_summary.*"unchanged"' -ErrorAction SilentlyContinue
$ps1Hits = Select-String -Path (Get-ChildItem "$script:RepoRoot/scripts/*.ps1" | Where-Object { $_.Name -notlike 'check-*' }) -Pattern 'Write-Summary.*"unchanged"' -ErrorAction SilentlyContinue
$allHits = @()
if ($shHits) { $allHits += $shHits }
if ($ps1Hits) { $allHits += $ps1Hits }
if ($allHits.Count -gt 0) {
    StepFail "15" "Deprecated summary terms" "found 'unchanged' in write_summary calls (use 'verified')"
    $allHits | ForEach-Object { Write-Host "  $_" }
} else {
    StepPass "15" "Deprecated summary terms" "no deprecated terms found"
}

# Step 16: Capability bypass — direct @reference/ to governed JSON in rules/CLAUDE.md
Write-Host ""
Write-Host "--- Step 16: Capability bypass audit ---" -ForegroundColor White
# Governed JSON files that require skill access (capability-based security, Dennis & Van Horn 1966)
# @reference/ prefix loads file into context, bypassing the governing skill
# Scope: .claude/rules/*.md, .cursor/rules/*.mdc and CLAUDE.md (the @-referenced
# files of CLAUDE.md are not scanned). Markdown table rows are exempt (#50).
# Same pattern and governed list as check-pre-commit.sh step 16 (#116 parity).
# See .claude/rules/governed-data-access.md for the principle
$rulesDir = Join-Path $script:RepoRoot ".claude/rules"
$cursorRulesDir = Join-Path $script:RepoRoot ".cursor/rules"
$claudeMd = Join-Path $script:RepoRoot "CLAUDE.md"
$scanFiles = @()
# A missing rules directory yields $null; the null checks below handle it.
$ruleFiles = Get-ChildItem "$rulesDir/*.md" -ErrorAction SilentlyContinue
if ($ruleFiles) { $scanFiles += $ruleFiles }
$cursorRuleFiles = Get-ChildItem "$cursorRulesDir/*.mdc" -ErrorAction SilentlyContinue
if ($cursorRuleFiles) { $scanFiles += $cursorRuleFiles }
if (Test-Path $claudeMd) { $scanFiles += Get-Item $claudeMd }
$capHits = @()
if ($scanFiles.Count -gt 0) {
    $rawHits = Select-String -Path $scanFiles -Pattern '@?(reference|registries)/[a-z0-9-]*\.json' -ErrorAction SilentlyContinue
    if ($rawHits) {
        foreach ($h in $rawHits) {
            if ($h.Line -match 'glossary\.json|framework-registry\.json|incidents\.json|tool-registry\.json|tool-ops\.json' -and $h.Line -notmatch '^\|.*\|.*\|.*\|') {
                $capHits += $h
            }
        }
    }
}
if ($capHits.Count -gt 0) {
    StepFail "16" "Capability bypass audit" "rules/CLAUDE.md load governed JSON directly (use governing skill)"
    $capHits | ForEach-Object { Write-Host "  $_" }
} else {
    StepPass "16" "Capability bypass audit" "no direct governed JSON references in rules/CLAUDE.md"
}

# ---------------------------------------------------------------------------
# 20. Path references (#115): every repo path cited in skills, rules, Cursor
#     rules, reference docs, hooks and CLAUDE.md must exist. One Python
#     implementation (scripts/check-path-refs.py) serves both platforms.
#     (Steps 17-19 exist only in check-pre-commit.sh today.)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Step 20: Path references ---" -ForegroundColor White
$python20 = $null
foreach ($candidate in @("python", "python3")) {
    $cmd20 = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd20) { $python20 = $cmd20.Source; break }
}
if (-not $python20) {
    StepFail "20" "Path references" "python not found (required to run scripts/check-path-refs.py)"
} else {
    $pathScript = Join-Path $script:RepoRoot "scripts/check-path-refs.py"
    # The helper exits 1 on dead paths and 2 on errors; native stderr must not throw.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $pathOut = @(& $python20 $pathScript --root $script:RepoRoot 2>&1)
        $pathRc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEAP
    }
    if ($pathRc -eq 0) {
        StepPass "20" "Path references" "every cited repo path exists"
    } elseif ($pathRc -eq 1) {
        $pathOut | ForEach-Object { Write-Host "  $_" }
        StepFail "20" "Path references" "dead repo path references (fix the path or see scripts/check-path-refs-allow.txt)"
    } else {
        $pathOut | ForEach-Object { Write-Host "  $_" }
        StepFail "20" "Path references" "check-path-refs.py error (exit $pathRc)"
    }
}

# ---------------------------------------------------------------------------
# 21. Skill levels: one skill name, one level (shared/skills, .claude/skills,
#     dotprofile claude/skills). See documentation-standards.md "Skill placement".
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Step 21: Skill levels ---" -ForegroundColor White
if (-not $python20) {
    StepFail "21" "Skill levels" "python not found (required to run scripts/check-skill-levels.py)"
} else {
    $skillScript = Join-Path $script:RepoRoot "scripts/check-skill-levels.py"
    $skillArgs = @($skillScript, "--root", $script:RepoRoot)
    if ($script:UserRepoPath) { $skillArgs += @("--dotprofile", $script:UserRepoPath) }
    # The helper exits 1 on collisions and 2 on errors; native stderr must not throw.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $skillOut = @(& $python20 @skillArgs 2>&1)
        $skillRc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEAP
    }
    if ($skillRc -eq 0) {
        StepPass "21" "Skill levels" "no skill name at two levels"
    } elseif ($skillRc -eq 1) {
        $skillOut | ForEach-Object { Write-Host "  $_" }
        StepFail "21" "Skill levels" "same skill name at two levels (keep one; git mv, never copies)"
    } else {
        $skillOut | ForEach-Object { Write-Host "  $_" }
        StepFail "21" "Skill levels" "check-skill-levels.py error (exit $skillRc)"
    }
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
