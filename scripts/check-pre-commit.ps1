# check-pre-commit.ps1 -- automated pre-commit checklist for aitools
# Usage: .\scripts\check-pre-commit.ps1 [-Fix]
# -Fix: auto-fix line endings, exec bits, and build freshness
# Platform: Windows (PS 5.1 compatible)
param([switch]$Fix)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    Write-Host "Use check-pre-commit.sh on macOS"; exit 1
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
    StepWarn "7" "Install cmd consistency" "verify against reference/tool-registry.md"
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
# Summary + exit
# ---------------------------------------------------------------------------
PrintSummary

if ($script:FailCount -gt 0) {
    exit 1
} else {
    exit 0
}
