# setup-user-skills.ps1 — Deploys user-level skills for Claude Code and Cursor on Windows
# Safe to re-run — uses managed file deployment with diff review.
#
# Discovers skills dynamically from shared\skills\ (framework) and dotprofile
# repo claude\skills\ (personal). Dotprofile skills take priority over shared.
# Deploys to %USERPROFILE%\.claude\skills\ and %USERPROFILE%\.cursor\skills\.
# Reverse discovery: detects user-created skills in deploy target and offers
# to adopt them to the dotprofile repo.
#
# Fallback deployer (FD-9, plans/skills-and-rules-fanout.md FO-6): when
# %USERPROFILE%\.aitools\skills exists (deploy-harness has run), the fan-out
# owns the skills -- setup-user-claude writes .claude\skills (row "claude
# skills") and setup-user-cursor writes .cursor\skills (row "cursor skills").
# This script then deploys nothing, writes neither row, writes OK "skills"
# "n/a (fanned out)" and keeps reverse discovery, which treats every name in
# .aitools\skills (an entry or a manifest line, any source) and every backup or
# hidden name as not user-created. Reverse discovery's own rows (a failed
# adopt, an unreadable directory) then use the tool "skills" too. A resolver
# error, or an unreadable .aitools\skills, manifest or .claude\skills, means
# reverse discovery does not run (its adopt target is the dotprofile): ERROR
# "skills" "no adopt: <reason>". Without .aitools\skills it deploys as before (an MDM endpoint run
# before deploy-harness, or a machine where deploy-harness failed). The check
# sits in the extracted body, so the generated MDM script (build-deploy)
# carries it. Same rows as setup-user-skills.sh (parity).
# Platform: Windows; macOS/Linux use setup-user-skills.sh.
# Tool data: /tool-registry skill.

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

# --- Harness check (FD-9): one writer per skill file ---
# .aitools\skills exists -> the setup-user-claude / setup-user-cursor fan-out
# deploys the skills, so this script does not (no second review menu, no second
# adopt target for one file). In the extracted body: the MDM script has it too.
# $skillsRowTool: the summary tool for reverse discovery's rows ("skills" when
# fanned out: the two fan-out tool names belong to the fan-out scripts).
$skillsHarnessDir = Join-Path (Join-Path $env:USERPROFILE ".aitools") "skills"
$skillsFannedOut = $false
$skillsRowTool = "claude skills"
if (Test-Path -LiteralPath $skillsHarnessDir -PathType Container) {
    $skillsFannedOut = $true
    $skillsRowTool = "skills"
    Log "Skills are fanned out from ~/.aitools/skills by setup-user-claude (claude skills) and setup-user-cursor (cursor skills): not deploying them here"
    Write-Summary "OK" "skills" "n/a (fanned out)"
}

# --- BEGIN skill discovery (replaced by build-deploy) ---

# --- Resolve paths ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$skillsSrc = Join-Path (Join-Path $repoDir "shared") "skills"

# User repo for dotprofile overrides and adopt target: the one dotprofile
# resolver (reference/user-repo.md "Resolution"; SD-7). The rc is captured, not
# suppressed: 0 found, 1 no dotprofile (shared-only mode, expected), 3 resolver
# error (the lib already logged it: LogError + ERROR row "dotprofile").
# On 1 $userRepoPath is empty: shared skills only, no adopt offer. On 3 the
# deploy is not run (S3-M3Lead decision): shared copies must never overwrite
# deployed dotprofile versions while the dotprofile cannot be read. Same rows
# and message as setup-user-skills.sh (parity).
$urpRc = Resolve-UserRepoPath
$userRepoPath = $script:AitLibUserRepoPath
$skillsBlocked = $false
if ($urpRc -ne 0 -and $urpRc -ne 1) {
    $skillsBlocked = $true
    if ($skillsFannedOut) {
        # The fan-out deploys; reverse discovery adopts into the dotprofile, so
        # it cannot run. Reported under "skills": the two fan-out rows are not ours.
        LogError "Dotprofile unresolved (resolver error above) -- reverse discovery not run, so no skill can be adopted to the dotprofile"
        Write-Summary "ERROR" "skills" "no adopt: dotprofile error"
    } else {
        LogError "Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions"
        Write-Summary "ERROR" "claude skills" "not deployed: dotprofile error"
        Write-Summary "ERROR" "cursor skills" "not deployed: dotprofile error"
    }
}
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
if ($skillsBlocked) {
    # resolver error: nothing is discovered, deployed or offered for adoption
} elseif ($skillsFannedOut) {
    # the fan-out deploys: nothing is discovered for deployment here
} elseif (Test-Path $skillsSrc) {
    foreach ($skillDir in Get-ChildItem -Path $skillsSrc -Directory) {
        if (Test-Path (Join-Path $skillDir.FullName "SKILL.md")) {
            $skillNames += $skillDir.Name
        }
    }
}
# Add dotprofile skills not already in shared
if ($dotprofileSkills -and -not $skillsFannedOut) {
    foreach ($skillDir in Get-ChildItem -Path $dotprofileSkills -Directory) {
        if ((Test-Path (Join-Path $skillDir.FullName "SKILL.md")) -and ($skillDir.Name -notin $skillNames)) {
            $skillNames += $skillDir.Name
        }
    }
}

if ($skillNames.Count -eq 0 -and -not $skillsBlocked -and -not $skillsFannedOut) {
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

    try {
        $srcContent = Get-Content $src -Raw -ErrorAction Stop
    } catch {
        LogError "Cannot read skill source $SkillName`: $_"
        return
    }

    # Adopt target: the file actually read (the dotprofile copy when that was
    # the source, else shared\skills in the aitools repo). The library writes it.
    $skillResult = Deploy-ManagedFile -Content $srcContent -DestPath $dest -ToolName $ToolName -ItemName $SkillName -AdoptPath $src

    switch ($skillResult) {
        "accept & adopt" {
            # Copy the adopted content to the other deploy targets too, so their
            # deploy sees LOCAL == SOURCE instead of asking again.
            foreach ($otherBase in $allSkillDests) {
                if ($otherBase -eq $DestBase) { continue }
                $otherDir = Join-Path $otherBase $SkillName
                $other = Join-Path $otherDir "SKILL.md"
                try {
                    if (-not (Test-Path $otherDir)) {
                        New-Item -ItemType Directory -Path $otherDir -Force -ErrorAction Stop | Out-Null
                    }
                    Backup-File -FilePath $other
                    Copy-Item -Path $dest -Destination $other -Force -ErrorAction Stop
                    Log "Synced adopted skill to $other"
                } catch {
                    LogError "Failed: ${SkillName}: could not copy the adopted skill to ${other}: $_"
                    Write-Summary "ERROR" $ToolName "sync failed: $SkillName"
                }
            }
        }
        { $_ -in @("created", "updated", "skipped", "verified", "failed") } {
            # The tracker records the outcome (failed -> ERROR row).
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

# --- Harness skill names (fan-out mode only) ---
# Every name in .aitools\skills, as an entry or as a manifest line (any source,
# retired included), is a harness skill: the fan-out put it in .claude\skills,
# so it is never offered for adoption. Compared case-insensitively (HashSet,
# OrdinalIgnoreCase). Returns $false after LogError + ERROR "skills" when
# .aitools\skills or its manifest cannot be read: reverse discovery is then
# not run, so a harness skill is never mistaken for a user-created one. A
# manifest with a bad header adds no names (the fan-out reports it); its
# directory names still count. Parity: collect_harness_skill_names (.sh).
$harnessSkillNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
function Get-HarnessSkillNames {
    try {
        $entries = @(Get-ChildItem -LiteralPath $skillsHarnessDir -Force -ErrorAction Stop)
    } catch {
        LogError "Cannot read ~/.aitools/skills -- reverse discovery not run, so no harness skill is offered for adoption: $($_.Exception.Message)"
        Write-Summary "ERROR" "skills" "no adopt: harness unreadable"
        return $false
    }
    foreach ($entry in $entries) {
        if ((Get-SkillNameKind $entry.Name) -eq "skill") { [void]$harnessSkillNames.Add($entry.Name) }
    }
    $manifest = Join-Path $skillsHarnessDir ".aitools-skills-manifest"
    if (Test-Path -LiteralPath $manifest) {
        $m = $null
        $why = $null
        if (Test-Path -LiteralPath $manifest -PathType Container) {
            # Read-HarnessManifest would report "access denied": say what the .sh says
            $why = "is a directory"
        } else {
            try {
                $m = Read-HarnessManifest -Path $manifest -Kind "skills"
            } catch {
                $why = $_.Exception.Message
            }
        }
        if ($null -ne $why) {
            LogError "Cannot read the skills manifest ~/.aitools/skills/.aitools-skills-manifest -- reverse discovery not run, so no harness skill is offered for adoption: $why"
            Write-Summary "ERROR" "skills" "no adopt: manifest unreadable"
            return $false
        }
        if ($m.Status -eq "header-bad") {
            Log "Skills manifest header not recognised: harness skill names taken from ~/.aitools/skills only"
            return $true
        }
        foreach ($r in $m.Rules) { [void]$harnessSkillNames.Add($r.Name) }
        foreach ($inv in $m.Invalid) { LogDetail "skills manifest: ignored line $inv" }
    }
    return $true
}

# --- Reverse discovery ---
# Scan deployed skills for user-created skills not in shared or dotprofile.
# Fan-out mode: only with a dotprofile (the adopt target) and the harness names.
$runReverse = $false
if ($skillsBlocked) {
    # resolver error: no adopt target (logged and reported above)
} elseif (-not $skillsFannedOut) {
    $runReverse = $true
} elseif ($userRepoPath) {
    $runReverse = [bool](Get-HarnessSkillNames)
}
# No adopt target: nothing would be offered, so the scan is not needed (as the .sh)
$destSkillDirs = @()
if ($runReverse -and $userRepoPath -and (Test-Path -LiteralPath $skillsDest -PathType Container)) {
    try {
        $destSkillDirs = @(Get-ChildItem -LiteralPath $skillsDest -Directory -ErrorAction Stop)
    } catch {
        LogError "Cannot read ~/.claude/skills -- reverse discovery not run, so no user-created skill is offered for adoption: $($_.Exception.Message)"
        Write-Summary "ERROR" $skillsRowTool "no adopt: target unreadable"
        $destSkillDirs = @()
    }
}
if ($destSkillDirs.Count -gt 0) {
    foreach ($skillDir in $destSkillDirs) {
        $skillName = $skillDir.Name
        if (-not (Test-Path (Join-Path $skillDir.FullName "SKILL.md"))) { continue }

        # Fan-out mode: the fan-out's own backup and hidden names, and every
        # harness skill, are not user-created
        if ($skillsFannedOut) {
            if ((Get-SkillNameKind $skillName) -ne "skill") { continue }
            if ($harnessSkillNames.Contains($skillName)) { continue }
        }

        # Skip if in shared
        if (Test-Path (Join-Path $skillsSrc $skillName)) { continue }
        # Skip if in dotprofile
        if ($dotprofileSkills -and (Test-Path (Join-Path $dotprofileSkills $skillName))) { continue }

        # Found a user-created skill
        if ($userRepoPath) {
            Log "Found user-created skill: $skillName"
            if ($DryRun) {
                Log "[DRY RUN] Would offer to adopt $skillName to dotprofile"
            } elseif (-not (Test-InteractiveConsole)) {
                Log "Non-interactive: skipped adoption prompt for $skillName"
            } else {
                # Test-InteractiveConsole + Read-ConsoleChoice (GitHub #29): EOF at
                # the prompt logs a warning and takes the default, [s]kip.
                [Console]::WriteLine("")
                [Console]::WriteLine("  User-created skill detected: $skillName")
                [Console]::WriteLine("  [a]dopt to dotprofile  [s]kip")
                [Console]::Write("  > ")
                $choice = Read-ConsoleChoice "skip"
                switch ($choice) {
                    { $_ -in @("a", "adopt") } {
                        $errorsBeforeAdopt = $errors
                        $adoptedCount = Adopt-ManagedFile -SourceFile (Join-Path $skillDir.FullName "SKILL.md") `
                            -Targets @(Join-Path $userRepoPath "claude\skills\$skillName\SKILL.md")
                        if ($errors -gt $errorsBeforeAdopt -or -not $adoptedCount) {
                            Write-Summary "ERROR" $skillsRowTool "adopt failed: $skillName"
                        }
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
