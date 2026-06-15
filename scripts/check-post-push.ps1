# check-post-push.ps1 -- automated post-push checklist for aitools
# Usage: .\scripts\check-post-push.ps1
# Platform: Windows (PS 5.1 compatible)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")
. (Join-Path $scriptDir "init-logging.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use check-post-push.sh."
    exit 1
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
$Extensive = $true

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
    "reference/tool-evaluation-playbook.md",
    "reference/tool-versions.json",
    "CLAUDE.md",
    "shared/claude-shared.md",
    "ROADMAP.md",
    "reference/tool-ops-claude-code.md",
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
$registryFile = Join-Path (Join-Path $script:RepoRoot "reference") "tool-ops-claude-code.md"
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
    $platformKey = 'windows'
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
        'python'           = @('python', '--version')
        'uv'               = @('uv', '--version')
        'go'               = @('go', 'version')
        'datadog-pup'      = @('pup', 'version')
        'perl'             = @('perl', '--version')
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
                # Lower ErrorActionPreference so stderr from native commands
                # (perl warnings, modal deprecation notices) doesn't throw.
                # Pattern: same as InvokeGit in check-lib.ps1.
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                try {
                    $allOutput = @(& $cmd[0] $cmd[1..($cmd.Length-1)] 2>&1)
                } finally {
                    $ErrorActionPreference = $prevEAP
                }
                # Search ALL output lines for version string (not just first).
                # Handles tools that emit warnings before the version line
                # (e.g., modal DeprecationWarning, perl stderr preamble).
                $matched = $false
                foreach ($outLine in $allOutput) {
                    $lineStr = "$outLine"
                    if ($lineStr -and $lineStr.Contains($platformVer)) {
                        $ver21Ok++
                        $matched = $true
                        break
                    }
                }
                if (-not $matched) {
                    $firstLine = ($allOutput | Select-Object -First 1) -as [string]
                    if ($firstLine) {
                        $ver21Details += ("      WARN {0}: installed='{1}' manifest='{2}'" -f $key, $firstLine, $platformVer)
                        $ver21Warns++
                    } else {
                        $ver21Details += ("      SKIP {0}: not installed (manifest: {1})" -f $key, $platformVer)
                        $ver21Skip++
                    }
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

# 22b: Cloud MCP in setup-user-mcp -- verify both source scripts define
#      show_cloud_mcp_status / Show-CloudMcpStatus and call it in exit section
$step22bFail = 0
# PS1: check exit section calls Show-CloudMcpStatus
$mcpPs1 = Get-Content (Join-Path $script:RepoRoot "scripts" "setup-user-mcp.ps1") -Raw
$mcpExitPs1 = ""
if ($mcpPs1 -match '(?s)BEGIN exit(.+?)END exit') {
    $mcpExitPs1 = $Matches[1]
}
if ($mcpExitPs1 -notmatch 'Show-CloudMcpStatus') {
    $step22bFail = 1
    Write-Host "      FAIL: scripts/setup-user-mcp.ps1 missing Show-CloudMcpStatus in exit section"
}
# Bash: check exit section calls show_cloud_mcp_status
$mcpBash = Get-Content (Join-Path $script:RepoRoot "scripts" "setup-user-mcp.sh") -Raw
$mcpExitBash = ""
if ($mcpBash -match '(?s)BEGIN exit(.+?)END exit') {
    $mcpExitBash = $Matches[1]
}
if ($mcpExitBash -notmatch 'show_cloud_mcp_status') {
    $step22bFail = 1
    Write-Host "      FAIL: scripts/setup-user-mcp.sh missing show_cloud_mcp_status in exit section"
}
if ($step22bFail -eq 0) {
    StepPass "22b" "Cloud MCP in setup-user-mcp" "both source scripts call show_cloud_mcp_status in exit"
} else {
    StepFail "22b" "Cloud MCP in setup-user-mcp" "missing from one or both source scripts"
    $step22Fail = 1
}

# ---------------------------------------------------------------------------
# 23. Script standards compliance (extensive only)
# ---------------------------------------------------------------------------
if ($Extensive) {
    $complianceScript = Join-Path $repoRoot "scripts/check-script-compliance.ps1"
    if (Test-Path $complianceScript) {
        Write-Host ""
        Write-Host "--- Step 23: Script standards compliance ---" -ForegroundColor White
        try {
            & $complianceScript
            if ($LASTEXITCODE -eq 0) {
                StepPass "23" "Script standards compliance" "all checks passed"
            } else {
                StepFail "23" "Script standards compliance" "one or more checks failed"
            }
        } catch {
            StepFail "23" "Script standards compliance" "script error: $_"
        }
    } else {
        StepSkip "23" "Script standards compliance" "check-script-compliance.ps1 not found"
    }
}

# ---------------------------------------------------------------------------
# 24. Summary panel DETAIL support (extensive only)
# ---------------------------------------------------------------------------
if ($Extensive) {
    $step24Ok = $true
    # Verify show_summary in aitools-lib.sh handles DETAIL
    $libSh = Join-Path $repoRoot "scripts/aitools-lib.sh"
    if (Test-Path $libSh) {
        $content = Get-Content $libSh -Raw -ErrorAction Stop
        if ($content -notmatch 'DETAIL') { $step24Ok = $false }
    } else { $step24Ok = $false }

    # Verify Show-Summary in aitools-lib.ps1 handles DETAIL
    $libPs1 = Join-Path $repoRoot "scripts/aitools-lib.ps1"
    if (Test-Path $libPs1) {
        $content = Get-Content $libPs1 -Raw -ErrorAction Stop
        if ($content -notmatch 'DETAIL') { $step24Ok = $false }
    } else { $step24Ok = $false }

    # Verify write_summary DETAIL is used in scripts
    $detailUsage = Get-ChildItem (Join-Path $repoRoot "scripts") -Filter "*.sh" -ErrorAction Stop |
        ForEach-Object { Select-String -Path $_.FullName -Pattern 'write_summary DETAIL' -ErrorAction Stop } |
        Where-Object { $_.Line -notmatch '^\s*#' }
    if (-not $detailUsage) { $step24Ok = $false }

    if ($step24Ok) {
        StepPass "24" "Summary panel DETAIL support" "DETAIL category in lib + scripts"
    } else {
        StepFail "24" "Summary panel DETAIL support" "DETAIL not fully implemented"
    }
}

# ---------------------------------------------------------------------------
# 25. CLI tools table sync
# ---------------------------------------------------------------------------
# Extract direct invocation commands from tool-registry.md
$registryFile = Join-Path $script:RepoRoot "reference" "tool-registry.md"
$sharedFile = Join-Path $script:RepoRoot "shared" "claude-shared.md"
$registryCmds = @()
if (Test-Path $registryFile) {
    $registryLines = Get-Content $registryFile -ErrorAction Stop
    foreach ($line in $registryLines) {
        if ($line -match '\*\*Invocation:\*\*\s*`([^`]+)`.*\(direct\)') {
            $registryCmds += $Matches[1]
        }
    }
}
if ($registryCmds.Count -eq 0) {
    StepSkip "25" "CLI tools table sync" "could not parse registry invocations"
} else {
    $sharedCmds = @()
    if (Test-Path $sharedFile) {
        $sharedLines = Get-Content $sharedFile -ErrorAction Stop
        foreach ($line in $sharedLines) {
            if ($line -match '^\|[^|]+\|\s*`([^`]+)`') {
                $cmd = $Matches[1] -replace '\s*\(.*?\)', ''
                $sharedCmds += $cmd
            }
        }
    }
    $missing = @()
    foreach ($cmd in $registryCmds) {
        if ($cmd -notin $sharedCmds) {
            $missing += $cmd
        }
    }
    if ($missing.Count -eq 0) {
        StepPass "25" "CLI tools table sync" "shared/claude-shared.md matches registry"
    } else {
        StepWarn "25" "CLI tools table sync" "missing from Managed CLI Tools: $($missing -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# 26. Deploy scripts list sync
# ---------------------------------------------------------------------------
$buildScript = Join-Path $script:RepoRoot "scripts" "build-deploy.sh"
if (-not (Test-Path $buildScript)) {
    StepSkip "26" "Deploy scripts list sync" "build-deploy.sh not found"
} else {
    $buildContent = Get-Content $buildScript -ErrorAction Stop
    # Use Perl for extraction (USO: Perl for non-trivial string manipulation)
    # Matches bash approach: \S+ stops at whitespace (handles parenthetical suffixes),
    # then strip .sh/.ps1 extensions
    $deployBases = ($buildContent | Out-String | perl -ne 'print "$1\n" if m{blog "(?:Copying|Generating) deploy/(\S+)"}' |
        perl -pe 's/\.sh$//; s/\.ps1$//' | Sort-Object -Unique)
    if (-not $deployBases) { $deployBases = @() }
    $claudeMdPath = Join-Path $script:RepoRoot "CLAUDE.md"
    $claudeContent = Get-Content $claudeMdPath -Raw -ErrorAction Stop
    $deployLine = ""
    if ($claudeContent -match '(?m)^.*build-deploy\.sh.*generates.*$') {
        $deployLine = $Matches[0]
    }
    if (-not $deployLine) {
        StepSkip "26" "Deploy scripts list sync" "could not find deploy reference in CLAUDE.md"
    } else {
        $missingDeploy = @()
        foreach ($base in $deployBases) {
            if ($deployLine -notmatch [regex]::Escape($base)) {
                # Check abbreviated forms used in CLAUDE.md:
                #   setup-go -> -go (strip setup-)
                #   setup-user-mcp -> -mcp (strip setup-user-)
                $short = ($base | perl -pe 's/^setup-user-//; s/^setup-//')
                if ($deployLine -notmatch [regex]::Escape("-$short") -and $deployLine -notmatch [regex]::Escape($short)) {
                    $missingDeploy += $base
                }
            }
        }
        if ($missingDeploy.Count -eq 0) {
            StepPass "26" "Deploy scripts list sync" "CLAUDE.md lists all deploy scripts"
        } else {
            StepWarn "26" "Deploy scripts list sync" "missing from CLAUDE.md: $($missingDeploy -join ', ')"
        }
    }
}

# ---------------------------------------------------------------------------
# 27. Build prerequisites installed
# ---------------------------------------------------------------------------
# Get-Command exempt: command-existence check with explicit fallback
$cargoInstalled = Get-Command cargo -ErrorAction SilentlyContinue
if ($cargoInstalled) {
    $missingPrereqs = Check-BuildPrereqs "cargo"
    if ($missingPrereqs.Count -gt 0) {
        foreach ($p in $missingPrereqs) {
            Write-Host "      Missing: $($p.Name) -- $($p.Install)"
        }
        StepWarn "27" "Build prerequisites installed" "missing: $(($missingPrereqs | ForEach-Object { $_.Name }) -join ', ')"
    } else {
        StepPass "27" "Build prerequisites installed"
    }
} else {
    StepSkip "27" "Build prerequisites installed" "cargo not installed"
}

# ---------------------------------------------------------------------------
# 28. Deploy state integrity: manifest and shadows consistent
# ---------------------------------------------------------------------------
$deployStateDir = "$env:USERPROFILE\.aitools\deploy-state"
$manifestPath = Join-Path $deployStateDir "manifest.json"
if (Test-Path $manifestPath) {
    $issues = @()
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.files) {
            $files = $manifest.files
            $keys = if ($files -is [hashtable]) { $files.Keys } else { $files.PSObject.Properties.Name }
            foreach ($key in $keys) {
                $shadowPath = Join-Path $deployStateDir "shadows" $key
                if (-not (Test-Path $shadowPath)) {
                    $issues += "missing shadow: $key"
                }
            }
        }
    } catch {
        $issues += "manifest parse error: $_"
    }
    if ($issues.Count -eq 0) {
        StepPass "28" "Deploy state integrity" "manifest and shadows consistent"
    } else {
        StepWarn "28" "Deploy state integrity" ($issues -join '; ')
    }
} else {
    StepSkip "28" "Deploy state integrity" "no deploy state (first run will create)"
}

# ---------------------------------------------------------------------------
# 29. Deployment menu parity audit
# ---------------------------------------------------------------------------
if ($Extensive) {
    $ps1Lib = Join-Path $script:RepoRoot "scripts\aitools-lib.ps1"
    $shLib = Join-Path $script:RepoRoot "scripts\aitools-lib.sh"
    # Extract [letter] patterns from menu lines
    $ps1Choices = (Select-String -Path $ps1Lib -Pattern 'Console.*Write.*\[(\w)\]' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ','
    $shChoices = (Select-String -Path $shLib -Pattern 'printf.*\[(\w)\]' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ','
    if ($ps1Choices -eq $shChoices) {
        StepPass "29" "Deployment menu parity audit" "PS1 and bash menus match: $ps1Choices"
    } else {
        StepFail "29" "Deployment menu parity audit" "PS1: $ps1Choices vs bash: $shChoices"
    }
}

# ---------------------------------------------------------------------------
# 30. Return value coverage audit
# ---------------------------------------------------------------------------
if ($Extensive) {
    $ps1Lib = Join-Path $script:RepoRoot "scripts\aitools-lib.ps1"
    $shLib = Join-Path $script:RepoRoot "scripts\aitools-lib.sh"
    # Extract MANAGED_FILE_RESULT values from bash
    $shReturns = (perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/' $shLib | Sort-Object -Unique) -join ','
    # Audit the inline-handling caller (setup-user-claude). setup-user-mcp no longer calls
    # deploy_managed_file (skills moved to setup-user-skills); skills/hooks delegate handling
    # to deploy_tracker_record, covered by step 30 tracker extraction + step 31.
    $callers = @(
        (Join-Path $script:RepoRoot "scripts\setup-user-claude.sh"),
        (Join-Path $script:RepoRoot "scripts\setup-user-claude.ps1")
    )
    $missing = @()
    foreach ($caller in $callers) {
        $cname = Split-Path -Leaf $caller
        $content = Get-Content $caller -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        foreach ($val in ($shReturns -split ',')) {
            if ($content -notmatch [regex]::Escape($val)) {
                $missing += "$cname missing $val"
            }
        }
    }
    if ($missing.Count -eq 0) {
        StepPass "30" "Return value coverage audit" "all callers handle: $shReturns"
    } else {
        StepFail "30" "Return value coverage audit" ($missing -join '; ')
    }
}

# ---------------------------------------------------------------------------
# 31. Deployment state machine sync
# ---------------------------------------------------------------------------
if ($Extensive) {
    $ps1Lib = Join-Path $script:RepoRoot "scripts\aitools-lib.ps1"
    $shLib = Join-Path $script:RepoRoot "scripts\aitools-lib.sh"
    # Compare return value sets (scoped to target functions via flip-flop)
    $shResults = (perl -ne 'if (/^deploy_managed_file\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_managed_file/)) { print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/ }' $shLib | Sort-Object -Unique) -join ','
    $ps1Results = (perl -ne 'if (/^function Deploy-ManagedFile\b/ .. (/^function / && !/Deploy-ManagedFile/)) { print "$1\n" if /return\s+"([\w-]+)"/ }' $ps1Lib | Sort-Object -Unique) -join ','
    $issues = @()
    if ($shResults -ne $ps1Results) {
        $issues += "return values: bash=$shResults ps1=$ps1Results"
    }
    # Compare tracker cases (scoped to target functions via flip-flop)
    $shTracker = (perl -ne 'if (/^deploy_tracker_record\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_tracker_record/)) { if (/^\s+([\w|.-]+)\)\s/) { for (split /\|/, $1) { print "$_\n" } } }' $shLib | Sort-Object -Unique) -join ','
    $ps1Tracker = (perl -ne 'if (/^function Record-DeployOutcome\b/ .. (/^function / && !/Record-DeployOutcome/)) { while (/-eq\s+"([\w-]+)"|"([\w-]+)"\s*\{/g) { print(($1 // $2) . "\n") } }' $ps1Lib | Sort-Object -Unique) -join ','
    if ($shTracker -ne $ps1Tracker) {
        $issues += "tracker cases: bash=$shTracker ps1=$ps1Tracker"
    }
    if ($issues.Count -eq 0) {
        StepPass "31" "Deployment state machine sync" "PS1 and bash return values match"
    } else {
        StepFail "31" "Deployment state machine sync" ($issues -join '; ')
    }
}

# ---------------------------------------------------------------------------
# 32. Hook-registration parity audit
# ---------------------------------------------------------------------------
# Single-source check: every hook in shared/hooks/hooks-manifest.json must be
# registered in BOTH setup-user-hooks.sh and .ps1. Closes the bash<->PS1 drift
# that left scratch-init/harvest unregistered on Windows (RCA, plan §5).
if ($Extensive) {
    $manifest = Join-Path $script:RepoRoot "shared\hooks\hooks-manifest.json"
    $shSetup = Join-Path $script:RepoRoot "scripts\setup-user-hooks.sh"
    $ps1Setup = Join-Path $script:RepoRoot "scripts\setup-user-hooks.ps1"
    $pyCmd = $null
    if (Get-Command python -ErrorAction SilentlyContinue) { $pyCmd = "python" }
    elseif (Get-Command python3 -ErrorAction SilentlyContinue) { $pyCmd = "python3" }
    if (-not (Test-Path $manifest) -or -not (Test-Path $shSetup) -or -not (Test-Path $ps1Setup)) {
        StepSkip "32" "Hook-registration parity audit" "manifest or setup script missing"
    } elseif (-not $pyCmd) {
        StepSkip "32" "Hook-registration parity audit" "python not available"
    } else {
        # Parity comparison done entirely in python (scripts/check-hook-parity.py) --
        # set-based, no perl-in-PowerShell quoting or platform sort-order fragility.
        $parityScript = Join-Path $script:RepoRoot "scripts\check-hook-parity.py"
        $parityOut = (& $pyCmd $parityScript $manifest $shSetup $ps1Setup 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            StepPass "32" "Hook-registration parity audit" $parityOut
        } else {
            StepFail "32" "Hook-registration parity audit" $parityOut
        }
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
