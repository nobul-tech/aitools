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
# Adopt filter for CLAUDE.md (Deploy-ManagedFile -AdoptFilter): takes LOCAL
# content, returns the dotprofile template. Strips the machine-specific footer
# and reverse-tokenizes profile values, so the next run rebuilds the same
# CLAUDE.md from the template and verifies it. Empty profile values are never
# substituted (an empty pattern would match everywhere).
# ---------------------------------------------------------------------------
$claudeMdAdoptFilter = {
    param([string]$Deployed)
    # Everything before ## Machine-Specific; trailing newlines removed (parity
    # with claude_md_adopt_filter in setup-user-claude.sh)
    $m = [regex]::Match($Deployed, '(?m)^## Machine-Specific')
    if ($m.Success) {
        $Deployed = $Deployed.Substring(0, $m.Index)
    }
    $Deployed = $Deployed -replace '[\r\n]+$', ''
    if ($profileName) {
        foreach ($pair in @(
                @($profileName, '{{PROFILE_NAME}}'),
                @($profileCompany, '{{PROFILE_COMPANY}}'),
                @($identityGitName, '{{IDENTITY_GIT_NAME}}'),
                @($identityGitEmail, '{{IDENTITY_GIT_EMAIL}}'))) {
            if ($pair[0]) {
                $Deployed = $Deployed.Replace([string]$pair[0], [string]$pair[1])
            }
        }
    }
    return $Deployed
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
    # Adopt target: the dotprofile template (the source of truth when a user
    # repo is configured). The library writes it, through $claudeMdAdoptFilter.
    $claudeAdoptPath = ""
    if ($userRepoPath) { $claudeAdoptPath = Join-Path $userRepoPath "claude\CLAUDE.md" }
    $claudeResult = Deploy-ManagedFile -Content $content -DestPath $claudeMd -ToolName "claude.md" -ItemName "CLAUDE.md" `
        -AdoptPath $claudeAdoptPath -AdoptFilter $claudeMdAdoptFilter

    switch ($claudeResult) {
        { $_ -eq "created" -or $_ -eq "updated" -or $_ -eq "accept & adopt" } {
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
            if ($errors -ne 0) {
                Write-Summary "ERROR" "claude.md" "validation failed"
            } elseif ($claudeResult -eq "accept & adopt") {
                Write-Summary "OK" "claude.md" "accepted to profile"
            } else {
                Write-Summary "OK" "claude.md" "$claudeResult"
            }
        }
        "skipped" {
            Write-Summary "WARN" "claude.md" "skipped (user review)"
        }
        "verified" {
            Log "CLAUDE.md verified (no differences)"
            Write-Summary "OK" "claude.md" "verified"
        }
        "failed" {
            # The library restored the files and logged the reason (LogError).
            Write-Summary "ERROR" "claude.md" "deploy failed"
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
            # Adopt target: the dotprofile rule (the file deployed from). Empty
            # in the MDM deploy script (no user repo): adopt and merge not offered.
            $ruleAdoptPath = ""
            if ($userRepoPath) { $ruleAdoptPath = Join-Path (Join-Path $userRepoPath "claude\rules") $rf.Name }

            try {
                $ruleContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
            } catch {
                LogWarn "Cannot read source rule $($rf.Name): $_"
                continue
            }
            $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath $destFile -ToolName "claude rules" -ItemName $rf.Name -AdoptPath $ruleAdoptPath

            if ($ruleResult -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed")) {
                # The library wrote LOCAL and the adopt target itself; the
                # tracker records every outcome (failed -> ERROR row).
            }
            Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $rf.Name
            # After a merge & adopt (the library already wrote the merge to the
            # dotprofile), auto commit+push to keep the dotprofile in sync.
            # Kept: commander confirmed 2026-10-21 (contract item #11).
            if ($ruleResult -eq "accept & adopt" -and $script:MergedContent -and $userRepoPath) {
                try {
                    Push-Location $userRepoPath
                    & git add "claude/rules/$($rf.Name)"
                    # Suppress git stderr noise; LASTEXITCODE checked on next line
                    & git diff --cached --quiet "claude/rules/$($rf.Name)" 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        # Has staged changes -- commit and push
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

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
                LogError "Validation failed: $($rf.Name) is empty after deploy"
            }
        }

        if ($script:dtFailed -gt 0) {
            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
            Write-DeployTrackerSummary -ToolName "claude rules"
            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } elseif ($errors -eq $errorsBefore) {
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
