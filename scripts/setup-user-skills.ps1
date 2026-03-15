# setup-user-skills.ps1 — Deploys user-level skills for Claude Code and Cursor on Windows
# Safe to re-run — uses managed file deployment with diff review.
#
# Discovers skills dynamically from shared\skills\ (framework) and dotprofile
# repo claude\skills\ (personal). Dotprofile skills take priority over shared.
# Deploys to %USERPROFILE%\.claude\skills\ and %USERPROFILE%\.cursor\skills\.
# Reverse discovery: detects user-created skills in deploy target and offers
# to adopt them to the dotprofile repo.

# --- BEGIN skills body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-skills"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- BEGIN skill discovery (replaced by build-deploy) ---

# --- Resolve paths ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$skillsSrc = Join-Path (Join-Path $repoDir "shared") "skills"

# User repo for dotprofile overrides and adopt target
$userRepoPath = ReadConfigKey -File (Join-Path $env:USERPROFILE ".aitools\config.json") -Key "userRepoPath"
$dotprofileSkills = $null
if ($userRepoPath) {
    $dpSkillsPath = Join-Path $userRepoPath "claude\skills"
    if (Test-Path $dpSkillsPath) {
        $dotprofileSkills = $dpSkillsPath
    }
}

$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"
$allSkillDests = @($skillsDest, $skillsDestCursor)

# --- Discover skills from shared and dotprofile ---
$skillNames = @()
if (Test-Path $skillsSrc) {
    foreach ($skillDir in Get-ChildItem -Path $skillsSrc -Directory) {
        if (Test-Path (Join-Path $skillDir.FullName "SKILL.md")) {
            $skillNames += $skillDir.Name
        }
    }
}
# Add dotprofile skills not already in shared
if ($dotprofileSkills) {
    foreach ($skillDir in Get-ChildItem -Path $dotprofileSkills -Directory) {
        if ((Test-Path (Join-Path $skillDir.FullName "SKILL.md")) -and ($skillDir.Name -notin $skillNames)) {
            $skillNames += $skillDir.Name
        }
    }
}

if ($skillNames.Count -eq 0) {
    LogWarn "No skills found in shared\skills\ or dotprofile"
    Write-Summary "WARN" "claude skills" "no skills found"
}

# --- Deploy function ---
function Deploy-Skill {
    param([string]$SkillName, [string]$DestBase, [string]$ToolName)

    # Determine source: dotprofile wins over shared
    $src = $null
    if ($dotprofileSkills -and (Test-Path (Join-Path (Join-Path $dotprofileSkills $SkillName) "SKILL.md"))) {
        $src = Join-Path (Join-Path $dotprofileSkills $SkillName) "SKILL.md"
    } elseif (Test-Path (Join-Path (Join-Path $skillsSrc $SkillName) "SKILL.md")) {
        $src = Join-Path (Join-Path $skillsSrc $SkillName) "SKILL.md"
    } else {
        LogError "Skill source not found: $SkillName"
        return
    }

    $destDir = Join-Path $DestBase $SkillName
    $dest = Join-Path $destDir "SKILL.md"

    $adoptLabel = ""
    if ($userRepoPath) { $adoptLabel = "dotprofile" }

    try {
        $srcContent = Get-Content $src -Raw -ErrorAction Stop
    } catch {
        LogError "Cannot read skill source $SkillName`: $_"
        return
    }

    $skillResult = Deploy-ManagedFile -Content $srcContent -DestPath $dest -ToolName $ToolName -ItemName $SkillName -AdoptLabel $adoptLabel

    switch ($skillResult) {
        "accept & adopt" {
            if ($userRepoPath) {
                $adoptDir = Join-Path $userRepoPath "claude\skills\$SkillName"
                if (-not (Test-Path $adoptDir)) {
                    New-Item -ItemType Directory -Path $adoptDir -Force | Out-Null
                }
                Copy-Item -Path $dest -Destination (Join-Path $adoptDir "SKILL.md") -Force -ErrorAction Stop
                LogOk "Adopted skill to dotprofile: $SkillName"
            } else {
                LogWarn "Cannot adopt: no user repo configured (run 'aitools user init')"
            }
            # Sync to all other deploy targets
            foreach ($otherBase in $allSkillDests) {
                if ($otherBase -eq $DestBase) { continue }
                $otherDir = Join-Path $otherBase $SkillName
                if (-not (Test-Path $otherDir)) {
                    New-Item -ItemType Directory -Path $otherDir -Force | Out-Null
                }
                Copy-Item -Path $dest -Destination (Join-Path $otherDir "SKILL.md") -Force
            }
        }
        { $_ -in @("created", "updated") } {
            # tracked by deploy tracker
        }
        { $_ -in @("skipped", "verified") } {
            # No action needed
        }
    }
    Record-DeployOutcome -Outcome $skillResult -ToolName $ToolName -ItemName $SkillName
}

# --- Deploy to Claude Code ---
if ($skillNames.Count -gt 0) {
    Log "Deploying skills to $skillsDest..."
    $errorsBeforeClaude = $errors
    Initialize-DeployTracker
    foreach ($skillName in $skillNames) {
        Deploy-Skill $skillName $skillsDest "claude skills"
    }
    if ($errors -eq $errorsBeforeClaude) {
        Write-DeployTrackerSummary -ToolName "claude skills"
    } else {
        Write-Summary "ERROR" "claude skills" "deploy failed"
    }

    # --- Deploy to Cursor ---
    Log "Deploying skills to $skillsDestCursor..."
    $errorsBeforeCursor = $errors
    Initialize-DeployTracker
    foreach ($skillName in $skillNames) {
        Deploy-Skill $skillName $skillsDestCursor "cursor skills"
    }
    if ($errors -eq $errorsBeforeCursor) {
        Write-DeployTrackerSummary -ToolName "cursor skills"
    } else {
        Write-Summary "ERROR" "cursor skills" "deploy failed"
    }
}

# --- Reverse discovery ---
# Scan deployed skills for user-created skills not in shared or dotprofile
if (Test-Path $skillsDest) {
    foreach ($skillDir in Get-ChildItem -Path $skillsDest -Directory) {
        $skillName = $skillDir.Name
        if (-not (Test-Path (Join-Path $skillDir.FullName "SKILL.md"))) { continue }

        # Skip if in shared
        if (Test-Path (Join-Path $skillsSrc $skillName)) { continue }
        # Skip if in dotprofile
        if ($dotprofileSkills -and (Test-Path (Join-Path $dotprofileSkills $skillName))) { continue }

        # Found a user-created skill
        if ($userRepoPath) {
            Log "Found user-created skill: $skillName"
            if ($DryRun) {
                Log "[DRY RUN] Would offer to adopt $skillName to dotprofile"
            } else {
                try {
                    [Console]::WriteLine("")
                    [Console]::WriteLine("  User-created skill detected: $skillName")
                    [Console]::WriteLine("  [a]dopt to dotprofile  [s]kip")
                    [Console]::Write("  > ")
                    $choice = [Console]::ReadLine()
                } catch {
                    $choice = "s"
                }
                switch ($choice) {
                    { $_ -in @("a", "adopt") } {
                        $adoptDir = Join-Path $userRepoPath "claude\skills\$skillName"
                        if (-not (Test-Path $adoptDir)) {
                            New-Item -ItemType Directory -Path $adoptDir -Force | Out-Null
                        }
                        Copy-Item -Path (Join-Path $skillDir.FullName "SKILL.md") -Destination (Join-Path $adoptDir "SKILL.md") -Force
                        LogOk "Adopted user skill to dotprofile: $skillName"
                    }
                    default {
                        Log "Skipped adoption of $skillName"
                    }
                }
            }
        }
    }
}

# --- END skill discovery (replaced by build-deploy) ---

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
