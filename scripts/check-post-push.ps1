# check-post-push.ps1 -- automated post-push checklist for aitools
# Usage: .\scripts\check-post-push.ps1 [-Extensive]
# Default: 5 always-tier steps. -Extensive: all 22 steps.
# Platform: Windows (PS 5.1 compatible)
param([switch]$Extensive)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    Write-Host "Use check-post-push.sh on macOS"; exit 1
}

ResolveConfig
CheckLogInit "post-push"

Set-Location $script:RepoRoot

Write-Host ""
Write-Host "=== POST-PUSH CHECKLIST ===" -ForegroundColor White
if ($Extensive) { Write-Host "  (extensive mode)" }
Write-Host ""

# ===================================================================
# ALWAYS TIER (steps 1-5)
# ===================================================================

# ---------------------------------------------------------------------------
# 1. Verify push landed
# ---------------------------------------------------------------------------
InvokeGit fetch origin main --quiet
$localHead = InvokeGit rev-parse HEAD
$remoteHead = InvokeGit rev-parse origin/main
if ($localHead -eq $remoteHead) {
    $short = InvokeGit log --oneline -1 HEAD
    StepPass "1" "Verify push landed" $short
} else {
    StepFail "1" "Verify push landed" "HEAD != origin/main"
}

# ---------------------------------------------------------------------------
# 2. Smoke-test deploy scripts
# ---------------------------------------------------------------------------
$deployErrors = 0
$bashExe = (Get-Command bash -ErrorAction SilentlyContinue).Source
if ($bashExe) {
    $deployFiles = Get-ChildItem (Join-Path $script:RepoRoot "deploy") -Filter "*.sh" -ErrorAction SilentlyContinue
    if (-not $deployFiles) {
        StepFail "2" "Smoke-test deploy scripts" "no .sh files found in deploy/"
    } else {
        foreach ($f in $deployFiles) {
            & $bashExe -n $f.FullName 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "      FAIL: $($f.Name)"
                $deployErrors++
            }
        }
        if ($deployErrors -eq 0) {
            StepPass "2" "Smoke-test deploy scripts"
        } else {
            StepFail "2" "Smoke-test deploy scripts" "$deployErrors file(s) failed bash -n"
        }
    }
} else {
    StepSkip "2" "Smoke-test deploy scripts" "bash not found"
}

# ---------------------------------------------------------------------------
# 3. MCP config integrity
# ---------------------------------------------------------------------------
$claudeJson = Join-Path $HOME ".claude.json"
$cursorMcp = Join-Path (Join-Path $HOME ".cursor") "mcp.json"
$mcpOk = $true

foreach ($cfg in @($claudeJson, $cursorMcp)) {
    if (-not (Test-Path $cfg)) {
        Write-Host "      missing: $cfg"
        $mcpOk = $false
        continue
    }
    $content = Get-Content $cfg -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "      cannot read: $(Split-Path -Leaf $cfg)"
        $mcpOk = $false
        continue
    }
    if ($content -notmatch 'chrome-devtools') {
        Write-Host "      chrome-devtools missing in $(Split-Path -Leaf $cfg)"
        $mcpOk = $false
    }
    if ($content -notmatch 'isolated') {
        Write-Host "      --isolated missing in $(Split-Path -Leaf $cfg)"
        $mcpOk = $false
    }
}
if ($mcpOk) {
    StepPass "3" "MCP config integrity"
} else {
    StepFail "3" "MCP config integrity" "see details above"
}

# ---------------------------------------------------------------------------
# 4. CLI entry point + version
# ---------------------------------------------------------------------------
$aitoolsVersion = "FAILED"
if ($bashExe) {
    $aitoolsVersion = & $bashExe (Join-Path $scriptDir "aitools") --version 2>$null
}
$tagVersion = InvokeGit describe --tags --match "v*" --abbrev=0
if (-not $tagVersion) { $tagVersion = "none" }
if ($aitoolsVersion -ne "FAILED") {
    StepPass "4" "CLI entry point + version" "$aitoolsVersion (tag: $tagVersion)"
} else {
    StepFail "4" "CLI entry point + version" "aitools --version failed"
}

# ---------------------------------------------------------------------------
# 5. Session archive readiness
# ---------------------------------------------------------------------------
$settingsFile = Join-Path (Join-Path $HOME ".claude") "settings.json"
$hookPresent = $false
if (Test-Path $settingsFile) {
    $settingsContent = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
    # Null guard: if file is unreadable (locked/corrupt), treat as not configured
    # rather than reporting misleading "not configured" vs "cannot read" distinction
    if ($settingsContent -match 'session-archive') { $hookPresent = $true }
}
if ($hookPresent) {
    if (-not $script:UserRepoPath -or -not (Test-Path $script:UserRepoPath)) {
        StepWarn "5" "Session archive readiness" "hook present but userRepoPath missing -- run aitools user init"
    } else {
        $sessionsDir = Join-Path $script:UserRepoPath "sessions"
        if (-not (Test-Path $sessionsDir)) {
            StepWarn "5" "Session archive readiness" "hook configured but sessions/ dir missing -- hook may have never fired"
        } else {
            $jsonlFiles = Get-ChildItem -Path $sessionsDir -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue
            if (-not $jsonlFiles -or $jsonlFiles.Count -eq 0) {
                StepWarn "5" "Session archive readiness" "sessions/ exists but has no .jsonl files -- hook may be failing silently"
            } else {
                $newest = $jsonlFiles | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                $ageDays = [math]::Floor(((Get-Date).ToUniversalTime() - $newest.LastWriteTimeUtc).TotalDays)
                if ($ageDays -gt 7) {
                    StepWarn "5" "Session archive readiness" "last archive is ${ageDays}d old -- hook may have stopped working"
                } else {
                    StepPass "5" "Session archive readiness" "$($jsonlFiles.Count) archives, last within 7d"
                }
            }
        }
    }
} else {
    StepSkip "5" "Session archive readiness" "SessionEnd hook not configured"
}

# ===================================================================
# EXTENSIVE TIER (steps 6-22)
# ===================================================================
if (-not $Extensive) {
    PrintSummary
    if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}

Write-Host ""
Write-Host "--- Extensive tier ---" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# 6. Full script syntax validation
# ---------------------------------------------------------------------------
# .sh validation
$shErrors = 0
if ($bashExe) {
    $allSh = @()
    $allSh += Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "*.sh" -ErrorAction SilentlyContinue
    $allSh += Get-ChildItem (Join-Path $script:RepoRoot "deploy") -Filter "*.sh" -ErrorAction SilentlyContinue
    $hooksDir = Join-Path (Join-Path $script:RepoRoot "shared") "hooks"
    if (Test-Path $hooksDir) {
        $allSh += Get-ChildItem $hooksDir -Filter "*.sh" -ErrorAction SilentlyContinue
    }
    if ($allSh.Count -eq 0) {
        StepFail "6" "Full syntax (.sh)" "no .sh files found in scripts/, deploy/, or shared/hooks/"
    } else {
        foreach ($f in $allSh) {
            & $bashExe -n $f.FullName 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "      FAIL: $($f.FullName)"
                $shErrors++
            }
        }
        if ($shErrors -eq 0) {
            StepPass "6" "Full syntax (.sh)"
        } else {
            StepFail "6" "Full syntax (.sh)" "$shErrors file(s) failed"
        }
    }
} else {
    StepSkip "6" "Full syntax (.sh)" "bash not found"
}

# .ps1 validation (native on Windows)
$ps1Errors = 0
$allPs1 = @()
$allPs1 += Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "*.ps1" -ErrorAction SilentlyContinue
$allPs1 += Get-ChildItem (Join-Path $script:RepoRoot "deploy") -Filter "*.ps1" -ErrorAction SilentlyContinue
if ($allPs1.Count -eq 0) {
    StepFail "6" "Full syntax (.ps1)" "no .ps1 files found in scripts/ or deploy/"
} else {
    foreach ($f in $allPs1) {
        $e = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e)
        if ($e.Count -gt 0) {
            Write-Host "      FAIL: $($f.Name)"
            foreach ($err in $e) {
                Write-Host "        line $($err.Extent.StartLineNumber): $($err.Message)"
            }
            $ps1Errors++
        }
    }
    if ($ps1Errors -eq 0) {
        StepPass "6" "Full syntax (.ps1)"
    } else {
        StepFail "6" "Full syntax (.ps1)" "$ps1Errors file(s) failed"
    }
}

# ---------------------------------------------------------------------------
# 7. deploy/ drift audit
# ---------------------------------------------------------------------------
if ($bashExe) {
    & $bashExe (Join-Path $scriptDir "build-deploy.sh") 2>$null | Out-Null
    $drift = InvokeGit diff deploy/
    if (-not $drift) {
        StepPass "7" "deploy/ drift audit"
    } else {
        StepFail "7" "deploy/ drift audit" "deploy/ is stale -- rebuild needed"
        InvokeGit checkout -- deploy/
    }
} else {
    StepSkip "7" "deploy/ drift audit" "bash not found"
}

# ---------------------------------------------------------------------------
# 8. Rule parity audit
# ---------------------------------------------------------------------------
$claudeOnly = @("git-identity", "python-style", "surface-silent-failures")
$parityErrors = 0
$claudeRulesDir = Join-Path (Join-Path $script:RepoRoot ".claude") "rules"
$cursorRulesDir = Join-Path (Join-Path $script:RepoRoot ".cursor") "rules"
$claudeRules = Get-ChildItem $claudeRulesDir -Filter "*.md" -ErrorAction SilentlyContinue
if (-not $claudeRules) {
    StepFail "8" "Rule parity audit" "no rules found in .claude/rules/"
} else {
    foreach ($f in $claudeRules) {
        $base = $f.BaseName
        if ($claudeOnly -contains $base) { continue }
        $cursorFile = Join-Path $cursorRulesDir "$base.mdc"
        if (-not (Test-Path $cursorFile)) {
            Write-Host "      missing cursor counterpart: .cursor/rules/$base.mdc"
            $parityErrors++
        }
    }
    if ($parityErrors -eq 0) {
        StepPass "8" "Rule parity audit"
    } else {
        StepFail "8" "Rule parity audit" "$parityErrors missing counterpart(s)"
    }
}

# ---------------------------------------------------------------------------
# 9. Source-of-truth consistency
# ---------------------------------------------------------------------------
$toolSourcesFile = Join-Path (Join-Path $script:RepoRoot "reference") "tool-registry.md"
$lifecycleCount = 0
if (Test-Path $toolSourcesFile) {
    $lines = Get-Content $toolSourcesFile
    $lifecycleCount = @($lines | Where-Object { $_ -match '^\- \*\*Platform Status' }).Count
}
if ($lifecycleCount -gt 0) {
    StepPass "9" "Source-of-truth consistency" "$lifecycleCount lifecycle blocks found"
} else {
    StepWarn "9" "Source-of-truth consistency" "could not parse lifecycle fields"
}

# ---------------------------------------------------------------------------
# 10. Protected files inventory
# ---------------------------------------------------------------------------
$inventoryErrors = 0
$protectedFiles = @(
    "reference/tool-registry.md",
    "reference/tool-evaluation-criteria.md",
    "reference/tool-versions.json",
    "CLAUDE.md",
    "shared/claude-shared.md",
    "ROADMAP.md",
    "reference/claude-code-maintenance.md",
    "reference/user-repo.md"
)
foreach ($pf in $protectedFiles) {
    $fullPath = Join-Path $script:RepoRoot $pf
    if (-not (Test-Path $fullPath)) {
        Write-Host "      missing: $pf"
        $inventoryErrors++
    }
}
if ($inventoryErrors -eq 0) {
    StepPass "10" "Protected files inventory"
} else {
    StepFail "10" "Protected files inventory" "$inventoryErrors file(s) missing"
}

# ---------------------------------------------------------------------------
# 11. Cross-platform pairing
# ---------------------------------------------------------------------------
$pairingErrors = 0
$setupSh = Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.sh" -ErrorAction SilentlyContinue
$setupPs1 = Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.ps1" -ErrorAction SilentlyContinue
if ((-not $setupSh) -and (-not $setupPs1)) {
    StepFail "11" "Cross-platform pairing" "no setup scripts found in scripts/"
} else {
    if ($setupSh) {
        foreach ($f in $setupSh) {
            $ps1Name = $f.BaseName + ".ps1"
            if (-not (Test-Path (Join-Path $f.DirectoryName $ps1Name))) {
                Write-Host "      unpaired: scripts/$($f.Name) (no .ps1)"
                $pairingErrors++
            }
        }
    }
    if ($setupPs1) {
        foreach ($f in $setupPs1) {
            $shName = $f.BaseName + ".sh"
            if (-not (Test-Path (Join-Path $f.DirectoryName $shName))) {
                Write-Host "      unpaired: scripts/$($f.Name) (no .sh)"
                $pairingErrors++
            }
        }
    }
    if ($pairingErrors -eq 0) {
        StepPass "11" "Cross-platform pairing"
    } else {
        StepFail "11" "Cross-platform pairing" "$pairingErrors unpaired script(s)"
    }
}

# ---------------------------------------------------------------------------
# 12. CLAUDE.md limits
# ---------------------------------------------------------------------------
$claudeMd = Join-Path $script:RepoRoot "CLAUDE.md"
$claudeLines = (Get-Content $claudeMd).Count
if ($claudeLines -lt 200) {
    StepPass "12" "CLAUDE.md limits" "$claudeLines lines (< 200)"
} else {
    StepFail "12" "CLAUDE.md limits" "$claudeLines lines (>= 200)"
}

# ---------------------------------------------------------------------------
# 13. Reference link audit
# ---------------------------------------------------------------------------
$refErrors = 0
$claudeContent = Get-Content $claudeMd -Raw
$refs = [regex]::Matches($claudeContent, '@reference/[^\s]+')
foreach ($ref in $refs) {
    $refPath = ($ref.Value -replace '^@', '') -replace '[`''")\]]+$', ''
    $fullPath = Join-Path $script:RepoRoot $refPath
    if (-not (Test-Path $fullPath)) {
        Write-Host "      broken @import: $refPath"
        $refErrors++
    }
}
if ($refErrors -eq 0) {
    StepPass "13" "Reference link audit"
} else {
    StepFail "13" "Reference link audit" "$refErrors broken link(s)"
}

# ---------------------------------------------------------------------------
# 14. Line ending audit
# ---------------------------------------------------------------------------
$crlfCount = 0
$allShFiles = @()
$allShFiles += Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "*.sh" -ErrorAction SilentlyContinue
$allShFiles += Get-ChildItem (Join-Path $script:RepoRoot "deploy") -Filter "*.sh" -ErrorAction SilentlyContinue
$hooksDir2 = Join-Path (Join-Path $script:RepoRoot "shared") "hooks"
if (Test-Path $hooksDir2) {
    $allShFiles += Get-ChildItem $hooksDir2 -Filter "*.sh" -ErrorAction SilentlyContinue
}
if ($allShFiles.Count -eq 0) {
    StepFail "14" "Line ending audit" "no .sh files found"
} else {
    foreach ($f in $allShFiles) {
        $content = [System.IO.File]::ReadAllText($f.FullName)
        if ($content -match "`r`n") {
            Write-Host "      CRLF: $($f.FullName)"
            $crlfCount++
        }
    }
    if ($crlfCount -eq 0) {
        StepPass "14" "Line ending audit"
    } else {
        StepFail "14" "Line ending audit" "$crlfCount file(s) with CRLF"
    }
}

# ---------------------------------------------------------------------------
# 15. MCP config deploy
# ---------------------------------------------------------------------------
StepSkip "15" "MCP config deploy" "side-effect -- run setup scripts manually if needed"

# ---------------------------------------------------------------------------
# 16. Roadmap freshness
# ---------------------------------------------------------------------------
$staleCount = 0
$roadmapFile = Join-Path $script:RepoRoot "ROADMAP.md"
if (Test-Path $roadmapFile) {
    $roadmapContent = Get-Content $roadmapFile -Raw
    $planRefs = [regex]::Matches($roadmapContent, 'plans/[^\s|)]+')
    foreach ($ref in $planRefs) {
        $planPath = Join-Path $script:RepoRoot $ref.Value
        if (Test-Path $planPath) {
            $lastWrite = (Get-Item $planPath).LastWriteTimeUtc
            $ageDays = ((Get-Date).ToUniversalTime() - $lastWrite).Days
            if ($ageDays -gt 14) {
                Write-Host "      stale ($ageDays days): $($ref.Value)"
                $staleCount++
            }
        }
    }
}
if ($staleCount -eq 0) {
    StepPass "16" "Roadmap freshness"
} else {
    StepWarn "16" "Roadmap freshness" "$staleCount plan(s) not updated in 14+ days"
}

# ---------------------------------------------------------------------------
# 17. Hook verification
# ---------------------------------------------------------------------------
if ($hookPresent) {
    if ($script:UserRepoPath -and (Test-Path $script:UserRepoPath)) {
        StepPass "17" "Hook verification"
    } else {
        StepWarn "17" "Hook verification" "hook present but user repo dir missing"
    }
} else {
    StepWarn "17" "Hook verification" "SessionEnd hook not in settings.json"
}

# ---------------------------------------------------------------------------
# 18. Untracked file hygiene
# ---------------------------------------------------------------------------
$untrackedRaw = InvokeGit status --porcelain
$untracked = @()
if ($untrackedRaw) {
    $untracked = @($untrackedRaw -split "`n" | Where-Object { $_ -match '^\?\?' -and $_ -match '\.(md|sh|ps1|mdc)$' })
}
if ($untracked.Count -eq 0) {
    StepPass "18" "Untracked file hygiene"
} else {
    StepWarn "18" "Untracked file hygiene" "$($untracked.Count) untracked script/doc file(s)"
}

# ---------------------------------------------------------------------------
# 19. Config merge audit
# ---------------------------------------------------------------------------
$overwriteCount = 0
$setupScripts = @()
$setupScripts += Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.sh" -ErrorAction SilentlyContinue
$setupScripts += Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.ps1" -ErrorAction SilentlyContinue
if (-not $setupScripts -or $setupScripts.Count -eq 0) {
    StepFail "19" "Config merge audit" "no setup scripts found in scripts/"
} else {
    foreach ($f in $setupScripts) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) {
            Write-Host "      cannot read: $($f.Name)"
            $overwriteCount++
            continue
        }
        # Detect blind-overwrite patterns per language
        $hasOverwrite = $false
        if ($f.Extension -eq ".sh") {
            # Bash: cat > file (without prior read)
            if ($content -match 'cat\s*>') { $hasOverwrite = $true }
        } else {
            # PS1: WriteAllText or Set-Content without prior Get-Content/ReadAllText
            if ($content -match 'WriteAllText|Set-Content') {
                if ($content -notmatch 'Get-Content|ReadAllText|ConvertFrom-Json') {
                    $hasOverwrite = $true
                }
            }
        }
        if ($hasOverwrite) {
            # Check first 15 lines for "sole owner" exemption (header may be multi-line)
            $header = Get-Content $f.FullName -TotalCount 15 -ErrorAction SilentlyContinue
            if (-not $header) {
                Write-Host "      cannot read header: $($f.Name)"
                $overwriteCount++
                continue
            }
            $headerStr = $header -join " "
            if ($headerStr -notmatch 'sole owner') {
                Write-Host "      potential blind overwrite: $($f.Name)"
                $overwriteCount++
            }
        }
    }
    if ($overwriteCount -eq 0) {
        StepPass "19" "Config merge audit"
    } else {
        StepWarn "19" "Config merge audit" "$overwriteCount script(s) with potential blind overwrite"
    }
}

# ---------------------------------------------------------------------------
# 20. CC version-dep review
# ---------------------------------------------------------------------------
$ccVersion = "unknown"
try {
    $ccVersion = claude --version 2>$null | Select-Object -First 1
} catch {
    # claude CLI not found or errored -- $ccVersion stays "unknown",
    # handled by StepSkip below
}
$registryFile = Join-Path (Join-Path $script:RepoRoot "reference") "claude-code-maintenance.md"
$registryVersion = "unknown"
if (Test-Path $registryFile) {
    $regContent = Get-Content $registryFile -Raw
    if ($regContent -match 'Current version.*?(\d+\.\d+\.\d+)') {
        $registryVersion = $Matches[1]
    }
}
if ($ccVersion -eq "unknown") {
    StepSkip "20" "CC version-dep review" "claude CLI not found"
} elseif ($ccVersion -match $registryVersion) {
    StepPass "20" "CC version-dep review" "v$registryVersion"
} else {
    StepWarn "20" "CC version-dep review" "CLI: $ccVersion vs registry: $registryVersion"
}

# ---------------------------------------------------------------------------
# 21. Tool version freshness
# ---------------------------------------------------------------------------
$versionsJson = Join-Path (Join-Path $script:RepoRoot "reference") "tool-versions.json"
if (-not (Test-Path $versionsJson)) {
    StepSkip "21" "Tool version freshness" "tool-versions.json not found"
} else {
    $toolData = Get-Content $versionsJson -Raw | ConvertFrom-Json
    $today = [datetime]::UtcNow.Date
    $ver21Warns = 0; $ver21Ok = 0; $ver21Skip = 0
    $ver21Details = @()
    $platformKey = if ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' } else { 'windows' }
    $toolCmds = @{
        'vercel-cli'       = @('vercel', '--version')
        'cursor-agent-cli' = @('agent', '--version')
        'node'             = @('node', '--version')
        'pandoc'           = @('pandoc', '--version')
        'pwsh'             = @('pwsh', '--version')
        'rust-cargo'       = @('cargo', '--version')
        'typst'            = @('typst', '--version')
        'gh-cli'           = @('gh', '--version')
        'modal-cli'        = @('modal', '--version')
    }
    foreach ($entry in $toolData.tools.PSObject.Properties) {
        $key = $entry.Name
        $val = $entry.Value
        if ($val.PSObject.Properties['maintenanceFile']) {
            continue  # covered by step 20
        } elseif ($val.PSObject.Properties['pinned']) {
            $lastReviewed = $val.lastReviewed
            if (-not $lastReviewed) {
                $ver21Details += ("      WARN {0}: lastReviewed not set" -f $key)
                $ver21Warns++
            } else {
                $reviewedDate = [datetime]::ParseExact($lastReviewed, 'yyyy-MM-dd', $null)
                $days = ($today - $reviewedDate).Days
                if ($days -gt 30) {
                    $ver21Details += ("      WARN {0}: lastReviewed {1} ({2}d ago, >30d)" -f $key, $lastReviewed, $days)
                    $ver21Warns++
                } else {
                    $ver21Ok++
                }
            }
        } else {
            $platformVer = $null
            $platformProp = $val.PSObject.Properties[$platformKey]
            if ($platformProp -and $platformProp.Value -and $platformProp.Value.lastVerifiedVersion) {
                $platformVer = $platformProp.Value.lastVerifiedVersion
            }
            if (-not $platformVer) {
                $ver21Details += ("      SKIP {0}: no {1} version in manifest" -f $key, $platformKey)
                $ver21Skip++
                continue
            }
            $cmd = $toolCmds[$key]
            if (-not $cmd) {
                $ver21Details += ("      SKIP {0}: no version command defined" -f $key)
                $ver21Skip++
                continue
            }
            try {
                $out = (& $cmd[0] $cmd[1..($cmd.Length-1)] 2>&1 | Select-Object -First 1) -as [string]
                if ($out -and $out.Contains($platformVer)) {
                    $ver21Ok++
                } elseif ($out) {
                    $ver21Details += ("      WARN {0}: installed='{1}' manifest='{2}'" -f $key, $out, $platformVer)
                    $ver21Warns++
                } else {
                    $ver21Details += ("      SKIP {0}: not installed (manifest: {1})" -f $key, $platformVer)
                    $ver21Skip++
                }
            } catch {
                $ver21Details += ("      SKIP {0}: not installed (manifest: {1})" -f $key, $platformVer)
                $ver21Skip++
            }
        }
    }
    foreach ($line in $ver21Details) { Write-Host $line }
    if ($ver21Warns -eq 0) {
        StepPass "21" "Tool version freshness" "$ver21Ok OK, $ver21Skip skipped"
    } else {
        StepWarn "21" "Tool version freshness" "$ver21Warns tool(s) out of date; $ver21Ok OK, $ver21Skip skipped"
    }
}

# ---------------------------------------------------------------------------
# Step 22: Logging hygiene audit
# ---------------------------------------------------------------------------
$step22Fail = 0

# 22a: Winget output filtering -- check that no setup-*.ps1 has unfiltered
#      winget Split/ForEach logging (single-line ForEach without a filter guard)
$badWingetFiles = @()
foreach ($ps1 in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.ps1") {
    $content = Get-Content $ps1.FullName -Raw
    if ($content -match '\$wingetOutput\.Trim\(\)\.Split\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*Log\s+\$_\.TrimEnd\(\)\s*\}') {
        $badWingetFiles += $ps1.Name
    }
}
if ($badWingetFiles.Count -gt 0) {
    StepFail "22a" "Winget output filtering" "unfiltered logging in: $($badWingetFiles -join ', ')"
    $step22Fail = 1
} else {
    StepPass "22a" "Winget output filtering" "all setup-*.ps1 filter winget progress chars"
}

# 22b: Cloud MCP in install path -- verify both entry points call show_cloud_mcp /
#      Show-CloudMcp in the install success block
$step22bFail = 0
# PS1 entry point: extract install runner block (anchored on unique $installerRc)
$aitoolsPs1 = Get-Content (Join-Path $script:RepoRoot "scripts" "aitools.ps1") -Raw
$installBlockPs1 = ""
if ($aitoolsPs1 -match '(?s)\$installerRc(.+?)\} elseif ') {
    $installBlockPs1 = $Matches[1]
}
if ($installBlockPs1 -notmatch 'Show-CloudMcp') {
    $step22bFail = 1
    Write-Host "      FAIL: scripts/aitools.ps1 missing Show-CloudMcp in install path"
}
# Bash entry point: extract install runner block (anchored on unique installer_rc)
$aitoolsBash = Get-Content (Join-Path $script:RepoRoot "scripts" "aitools") -Raw
$installBlockBash = ""
if ($aitoolsBash -match '(?s)installer_rc=(.+?)elif ') {
    $installBlockBash = $Matches[1]
}
if ($installBlockBash -notmatch 'show_cloud_mcp') {
    $step22bFail = 1
    Write-Host "      FAIL: scripts/aitools missing show_cloud_mcp in install path"
}
if ($step22bFail -eq 0) {
    StepPass "22b" "Cloud MCP in install path" "both entry points call show_cloud_mcp"
} else {
    StepFail "22b" "Cloud MCP in install path" "missing from one or both entry points"
    $step22Fail = 1
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
