# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from aitools repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/user-repo.md.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
# Preserved: ~/.claude/rules/ files not in user repo source

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md"),
    [switch]$DryRun,
    [switch]$Force
)

# --- BEGIN preamble (extracted by build-deploy) ---

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-claude"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- PS 7 version guard ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    LogError "This script requires PowerShell 7+. Current: $($PSVersionTable.PSVersion)"
    LogWarn "Install: winget install --id Microsoft.PowerShell --source winget"
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- END preamble (extracted by build-deploy) ---

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Log "Created $claudeDir"
    }
}

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""
$userRepoPath = ""

if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $userRepoPath = $cfg["userRepoPath"]
            $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
            if (Test-Path $userClaudeMd) {
                $sourcePath = $userClaudeMd
                $sourceLabel = "user repo"
            }
        }
    } catch {
        LogWarn "Could not read config: $_"
    }
}

if (-not $sourcePath) {
    if (Test-Path $SharedPath) {
        $sourcePath = $SharedPath
        $sourceLabel = "shared template"
    } else {
        LogError "No template found. Checked user repo and $SharedPath"
        exit 1
    }
}

Log "Template source: $sourcePath ($sourceLabel)"

# --- Read template content ---
try {
    $sharedContent = Get-Content -Path $sourcePath -Raw -ErrorAction Stop
} catch {
    LogError "Cannot read template: $sourcePath ($_)"
    exit 1
}
if (-not $sharedContent) {
    LogError "Template is empty: $sourcePath"
    exit 1
}

# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
$profileName = ""
$profileCompany = ""
$identityGitName = ""
$identityGitEmail = ""

if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $profilePath = Join-Path $cfg["userRepoPath"] "profile.json"
            if (Test-Path $profilePath) {
                $pf = ConvertPSObjectToHashtable (Get-Content $profilePath -Raw | ConvertFrom-Json)
                $alias = ""
                if ($cfg.ContainsKey("machineAlias")) { $alias = $cfg["machineAlias"] }

                $prof = $null
                $ident = $null
                if ($pf.ContainsKey("version") -and $pf["version"] -eq 2) {
                    # v2: profiles + identity
                    if ($pf.ContainsKey("profiles")) {
                        $profiles = $pf["profiles"]
                        if ($alias -and $profiles.ContainsKey($alias)) {
                            $prof = $profiles[$alias]
                        } else {
                            # Fallback: hostname match, then first profile
                            $hn = $env:COMPUTERNAME
                            foreach ($key in $profiles.Keys) {
                                $p = $profiles[$key]
                                if ($p.ContainsKey("machine") -and $p["machine"].ContainsKey("hostname")) {
                                    $phn = ($p["machine"]["hostname"] -split '\.')[0]
                                    if ($phn -eq $hn) { $prof = $p; break }
                                }
                            }
                            if (-not $prof) {
                                $firstKey = @($profiles.Keys)[0]
                                if ($firstKey) { $prof = $profiles[$firstKey] }
                            }
                        }
                    }
                    if ($pf.ContainsKey("identity")) { $ident = $pf["identity"] }
                } else {
                    # v1: flat schema
                    $prof = @{}
                    if ($pf.ContainsKey("name")) { $prof["name"] = $pf["name"] }
                    if ($pf.ContainsKey("company")) { $prof["company"] = $pf["company"] }
                    $ident = @{ git = @{} }
                    if ($pf.ContainsKey("git")) {
                        $ident["git"] = $pf["git"]
                    } else {
                        if ($pf.ContainsKey("name")) { $ident["git"]["name"] = $pf["name"] }
                        if ($pf.ContainsKey("email")) { $ident["git"]["email"] = $pf["email"] }
                    }
                }

                if ($prof -and $prof.ContainsKey("name")) { $profileName = $prof["name"] }
                if ($prof -and $prof.ContainsKey("company")) { $profileCompany = $prof["company"] }
                if ($ident -and $ident.ContainsKey("git")) {
                    $gitIdent = $ident["git"]
                    if ($gitIdent.ContainsKey("name")) { $identityGitName = $gitIdent["name"] }
                    if ($gitIdent.ContainsKey("email")) { $identityGitEmail = $gitIdent["email"] }
                }
            }
        }
    } catch {
        LogWarn "Could not read profile: $_"
    }
}

if ($profileName) {
    $sharedContent = $sharedContent -replace [regex]::Escape('{{PROFILE_NAME}}'), $profileName
    $sharedContent = $sharedContent -replace [regex]::Escape('{{PROFILE_COMPANY}}'), $profileCompany
    $sharedContent = $sharedContent -replace [regex]::Escape('{{IDENTITY_GIT_NAME}}'), $identityGitName
    $sharedContent = $sharedContent -replace [regex]::Escape('{{IDENTITY_GIT_EMAIL}}'), $identityGitEmail
    Log "Profile interpolation: name=$profileName company=$profileCompany"
} else {
    LogWarn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"
    Write-Summary "WARN" "claude.md" "template tokens unresolved"
}

# --- Write or preview CLAUDE.md ---
$osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
$hostname = $env:COMPUTERNAME

$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($hostname)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

# ---------------------------------------------------------------------------
# Adopt deployed CLAUDE.md back to profile template.
# Strips machine-specific footer and reverse-tokenizes profile values.
# ---------------------------------------------------------------------------
function Adopt-ClaudeMd {
    param([string]$DeployedPath, [string]$DestPath)

    try {
        $deployed = Get-Content $DeployedPath -Raw -ErrorAction Stop
    } catch {
        LogError "Cannot read deployed CLAUDE.md: $_"
        return $false
    }

    # Strip ## Machine-Specific section to end
    $idx = $deployed.IndexOf("`n## Machine-Specific")
    if ($idx -ge 0) {
        $deployed = $deployed.Substring(0, $idx).TrimEnd() + "`n"
    }

    # Reverse-substitute profile values back to {{PLACEHOLDER}} tokens
    if ($profileName) {
        $deployed = $deployed -replace [regex]::Escape($profileName), '{{PROFILE_NAME}}'
        $deployed = $deployed -replace [regex]::Escape($profileCompany), '{{PROFILE_COMPANY}}'
        $deployed = $deployed -replace [regex]::Escape($identityGitName), '{{IDENTITY_GIT_NAME}}'
        $deployed = $deployed -replace [regex]::Escape($identityGitEmail), '{{IDENTITY_GIT_EMAIL}}'
    }

    $destDir = Split-Path -Parent $DestPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Backup-File -FilePath $DestPath
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestPath)
    [System.IO.File]::WriteAllText($resolved, $deployed, [System.Text.UTF8Encoding]::new($false))
    LogOk "Adopted CLAUDE.md to profile: $DestPath"
    if ([Environment]::UserInteractive) {
        [Console]::WriteLine("  Review: cd $(Split-Path -Parent $destDir) && git diff")
    }
    return $true
}

if ($DryRun) {
    $existingLines = 0
    if (Test-Path $claudeMd) {
        $existingLines = (Get-Content $claudeMd).Count
    }
    $newLines = ($content -split "`n").Count
    Log "[DRY RUN] $claudeMd`: overwrite (sole owner)"
    Log "  Template source: $sourcePath ($sourceLabel)"
    if ($profileName) {
        Log "  Profile interpolation: name=$profileName company=$profileCompany"
    } else {
        Log "  Profile interpolation: none (tokens unresolved)"
    }
    Log "  Existing: $existingLines lines"
    Log "  New: $newLines lines"
    if (Test-Path $claudeMd) {
        $existingContent = Get-Content $claudeMd -Raw
        if ($existingContent -eq $content) {
            Log "[DRY RUN] Content unchanged"
        } else {
            Log "[DRY RUN] Content differs -- would overwrite"
        }
    } else {
        Log "[DRY RUN] File does not exist -- would create"
    }
} else {
    # --- Deploy CLAUDE.md via managed-file flow ---
    $adoptLabel = ""
    if ($userRepoPath) { $adoptLabel = "profile" }
    $claudeResult = Deploy-ManagedFile -Content $content -DestPath $claudeMd -ToolName "claude.md" -ItemName "CLAUDE.md" -AdoptLabel $adoptLabel

    switch ($claudeResult) {
        "adopted" {
            $adoptDest = Join-Path $userRepoPath "claude\CLAUDE.md"
            if (Adopt-ClaudeMd -DeployedPath $claudeMd -DestPath $adoptDest) {
                Write-Summary "OK" "claude.md" "adopted to profile"
            } else {
                Write-Summary "ERROR" "claude.md" "adopt failed"
            }
        }
        "merge-adopted" {
            # Validate (same as created/updated)
            if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
                LogError "Validation failed: $claudeMd is empty or missing"
            } else {
                $written = Get-Content $claudeMd -Raw
                if ($written -notmatch '## Machine-Specific') {
                    LogError "Validation failed: $claudeMd missing Machine-Specific section"
                }
                if ($written -notmatch '## Coaching|## Code Style|## Tool') {
                    LogError "Validation failed: $claudeMd missing template body"
                }
            }
            # Adopt back to profile
            $adoptDest = Join-Path $userRepoPath "claude\CLAUDE.md"
            if (Adopt-ClaudeMd -DeployedPath $claudeMd -DestPath $adoptDest) {
                if ($errors -eq 0) {
                    Write-Summary "OK" "claude.md" "merge-adopted to profile"
                } else {
                    Write-Summary "ERROR" "claude.md" "validation failed"
                }
            } else {
                Write-Summary "ERROR" "claude.md" "adopt failed after merge"
            }
        }
        "skipped" {
            Write-Summary "WARN" "claude.md" "skipped (user review)"
        }
        { $_ -eq "created" -or $_ -eq "updated" } {
            # --- BEGIN post-write validation (extracted by build-deploy) ---
            # Post-write validation: check structure AND content (not just a marker)
            if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
                LogError "Validation failed: $claudeMd is empty or missing"
            } else {
                $written = Get-Content $claudeMd -Raw
                if ($written -notmatch '## Machine-Specific') {
                    LogError "Validation failed: $claudeMd missing Machine-Specific section"
                }
                # Template body must be present -- a file with only the footer is corrupt
                if ($written -notmatch '## Coaching|## Code Style|## Tool') {
                    LogError "Validation failed: $claudeMd missing template body (only footer present?)"
                }
            }
            # --- END post-write validation (extracted by build-deploy) ---
            if ($errors -eq 0) {
                Write-Summary "OK" "claude.md" "$claudeResult"
            } else {
                Write-Summary "ERROR" "claude.md" "validation failed"
            }
        }
        "unchanged" {
            Log "CLAUDE.md unchanged (no differences)"
            Write-Summary "OK" "claude.md" "unchanged"
        }
    }
}

# --- BEGIN rules deployment (extracted by build-deploy) ---
# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
$rulesSrc = ""
if ($userRepoPath) {
    $candidateRules = Join-Path $userRepoPath "claude\rules"
    if (Test-Path $candidateRules) {
        $rulesSrc = $candidateRules
    }
}

$rulesDest = Join-Path $claudeDir "rules"

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
if ($rulesSrc) {
    $sourceRules = Get-ChildItem -Path $rulesSrc -Filter "*.md" -File -ErrorAction Stop
    if (-not $sourceRules -or $sourceRules.Count -eq 0) {
        Log "User repo claude/rules/ exists but has no .md files -- skipping"
    } elseif ($DryRun) {
        $existingCount = 0
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            if ($existingFiles) { $existingCount = $existingFiles.Count }
        }
        Log "[DRY RUN] $rulesDest`: additive deploy"
        Log "  Source: $rulesSrc ($($sourceRules.Count) rule files)"
        Log "  Existing: $existingCount rule files"
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if (Test-Path $destFile) {
                try {
                    $oldContent = Get-Content $destFile -Raw -ErrorAction Stop
                    $newContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
                } catch {
                    LogWarn "Cannot compare $($rf.Name): $_"
                    Log "  Would update (cannot compare): $($rf.Name)"
                    continue
                }
                if ($oldContent -eq $newContent) {
                    Log "  Would skip (unchanged): $($rf.Name)"
                } else {
                    Log "  Would update (changed): $($rf.Name)"
                }
            } else {
                Log "  Would add (new): $($rf.Name)"
            }
        }
        # Show preserved files
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "  Would preserve (unmanaged): $($ef.Name)"
                }
            }
        }
    } else {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path $rulesDest)) {
            New-Item -ItemType Directory -Path $rulesDest -Force | Out-Null
        }

        Initialize-DeployTracker
        $errorsBefore = $errors
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            $ruleAdoptLabel = ""
            if ($userRepoPath) { $ruleAdoptLabel = "profile" }

            try {
                $ruleContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
            } catch {
                LogWarn "Cannot read source rule $($rf.Name): $_"
                continue
            }
            $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath $destFile -ToolName "claude rules" -ItemName $rf.Name -AdoptLabel $ruleAdoptLabel

            if ($ruleResult -eq "adopted" -or $ruleResult -eq "merge-adopted") {
                $adoptRuleDest = Join-Path (Join-Path $userRepoPath "claude\rules") $rf.Name
                $adoptRuleDir = Split-Path -Parent $adoptRuleDest
                if (-not (Test-Path $adoptRuleDir)) {
                    New-Item -ItemType Directory -Path $adoptRuleDir -Force | Out-Null
                }
                Copy-Item -Path $destFile -Destination $adoptRuleDest -Force -ErrorAction Stop
                LogOk "Adopted rule to profile: $($rf.Name)"
            }
            Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $rf.Name
            # Write-back: sync merged content to dotprofile repo
            if ($ruleResult -eq "merge-adopted" -and $userRepoPath) {
                $wbDest = Join-Path $userRepoPath "claude\rules\$($rf.Name)"
                $wbDir = Split-Path -Parent $wbDest
                if (-not (Test-Path $wbDir)) { New-Item -ItemType Directory -Path $wbDir -Force | Out-Null }
                $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($wbDest)
                [System.IO.File]::WriteAllText($resolved, "$($script:MergedContent)`n")
                Log "Wrote merged $($rf.Name) back to $(Display-Path $wbDest)"
                # Auto commit+push to keep dotprofile in sync
                try {
                    Push-Location $userRepoPath
                    & git add "claude/rules/$($rf.Name)"
                    # Suppress git stderr noise; LASTEXITCODE checked on next line
                    & git diff --cached --quiet "claude/rules/$($rf.Name)" 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        # Has staged changes — commit and push
                        & git commit -m "Sync merged $($rf.Name) from deploy"
                        if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
                        & git push
                        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
                        LogOk "Pushed merged $($rf.Name) to user repo"
                    } else {
                        Log "No diff to commit in user repo for $($rf.Name)"
                    }
                } catch {
                    LogWarn "Failed to push merged $($rf.Name) to user repo: $_"
                } finally {
                    Pop-Location
                }
            }
        }

        # Log preserved files (in target but not in source)
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "Preserved unmanaged rule: $($ef.Name)"
                    Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $ef.Name
                }
            }
        }

        # Post-write validation: each deployed file is non-empty
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
                LogError "Validation failed: $($rf.Name) is empty after deploy"
            }
        }

        if ($errors -eq $errorsBefore) {
            Write-DeployTrackerSummary -ToolName "claude rules"
            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } else {
            Write-Summary "ERROR" "claude rules" "validation failed"
        }
    }
} else {
    Log "No user rules to deploy (no claude/rules/ in user repo)"
}
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
