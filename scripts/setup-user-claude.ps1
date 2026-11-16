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
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
# Managed: ~/.claude/skills/<name>/** fanned out from ~/.aitools/skills (additive;
#   the copy of a skill the skills manifest retires is backed up to
#   ~/.claude/skills.bak.<UTC>/ and removed)
# Preserved: ~/.claude/skills/ directories and symlinks not deployed from ~/.aitools/skills
# Rules and skills come from ~/.aitools only (deploy-harness fills it: run it
# first); the dotprofile's claude/rules and claude/skills reach Claude Code through it.

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
    Log "Install: winget install --id Microsoft.PowerShell --source winget"
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- END preamble (extracted by build-deploy) ---

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
# The directory this script runs from (aitools scripts/ on the dev path, the
# dotprofile's deploy/ for the generated copy): the rules fan-out derives the
# aitools checkout from it (SCRIPT_DIR in setup-user-claude.sh)
$claudeScriptDir = $PSScriptRoot

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        try {
            New-Item -ItemType Directory -Path $claudeDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-AitError "claude.md" "cannot create ~/.claude" (Get-AitErrorReason -ErrorRecord $_)
            exit 1
        }
        Log "Created $claudeDir"
    }
}

# --- Dotprofile and this machine's profile: one resolver (reference/user-repo.md
# "Resolution"). This script reads only the wrapper results (PR #80 contract),
# never profile.json or config.json itself: no alias lookup, no hostname or
# first-profile fallback. A miss never takes another machine's values: on no
# match the profile/identity values are identity-level only. The wrappers record
# the error and ACTION for their own failures; this script adds none. ---
$urpRc = Resolve-UserRepoPath       # 1 = shared-only (expected); 3 = error, recorded by the wrapper
$userRepoPath = $script:AitLibUserRepoPath
$userRepoVia = $script:AitLibUserRepoVia
if ($urpRc -eq 3) {
    # A dotprofile error is not "no dotprofile": deploying the shared template
    # would replace the personal CLAUDE.md and rules. The wrapper recorded the
    # error once (Write-AitError "dotprofile", counted here); what is not run
    # because of it is logged at info, not recorded again (one cause, one red
    # line: reference/logging.md 8.3). Exit 1: the wrapper's error is counted.
    Log "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"
    exit 1
}
$profileRc = Resolve-MachineProfile # 1 = shared-only; 3 = no match / error (recorded by the wrapper, + ACTION)
$machineAlias = $script:AitLibMachineAlias
$machineVia = $script:AitLibMachineVia
$profileName = $script:AitLibProfileName
$profileCompany = $script:AitLibProfileCompany
$identityGitName = $script:AitLibIdentityGitName
$identityGitEmail = $script:AitLibIdentityGitEmail
LogDetail "setup-user-claude: dotprofile rc=$urpRc via=$userRepoVia; machine profile rc=$profileRc"
$userRepoDisplay = ""
if ($userRepoPath) {
    $userRepoDisplay = $userRepoPath
    $up = $env:USERPROFILE
    if ($up -and ($userRepoDisplay -eq $up -or $userRepoDisplay.StartsWith($up + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
        $userRepoDisplay = '%USERPROFILE%' + $userRepoDisplay.Substring($up.Length)
    }
}

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""
if ($userRepoPath) {
    $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
    if (Test-Path $userClaudeMd) {
        $sourcePath = $userClaudeMd
        $sourceLabel = "user repo"
    }
}

if (-not $sourcePath) {
    if (Test-Path $SharedPath) {
        $sourcePath = $SharedPath
        $sourceLabel = "shared template"
    } else {
        Write-AitError "claude.md" "no template found" "checked the dotprofile and $SharedPath"
        exit 1
    }
}

Log "Template source: $sourcePath ($sourceLabel)"

# --- Read template content ---
try {
    $sharedContent = Get-Content -Path $sourcePath -Raw -ErrorAction Stop
} catch {
    Write-AitError "claude.md" "template unreadable" (Get-AitErrorReason -ErrorRecord $_)
    exit 1
}
if (-not $sharedContent) {
    Write-AitError "claude.md" "template empty" "$sourcePath is empty"
    exit 1
}

# --- Profile interpolation ---
# Values come from Resolve-MachineProfile above. String.Replace is literal ("$" in
# a value is not a regex group: the evaluator returns it as is). An empty value
# leaves its token in place. One pass: a value that contains token text is not
# substituted again (parity with setup-user-claude.sh).
$tokens = @{
    "PROFILE_NAME" = $profileName; "PROFILE_COMPANY" = $profileCompany
    "IDENTITY_GIT_NAME" = $identityGitName; "IDENTITY_GIT_EMAIL" = $identityGitEmail
    "USER_REPO_PATH" = $userRepoDisplay
}
$sharedContent = [regex]::Replace($sharedContent,
    '\{\{(PROFILE_NAME|PROFILE_COMPANY|IDENTITY_GIT_NAME|IDENTITY_GIT_EMAIL|USER_REPO_PATH)\}\}',
    [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $v = [string]$tokens[$m.Groups[1].Value]
        if ($v) { $v } else { $m.Value }
    })
if ($profileRc -eq 0) {
    Log "Profile interpolation: alias=$machineAlias via=$machineVia name=$profileName company=$profileCompany"
} elseif ($profileRc -eq 1) {
    Write-AitWarn "claude.md" "template tokens unresolved: no dotprofile"
} else {
    Log "Profile interpolation: identity-level values only (no machine profile) -- machine-specific tokens may stay unresolved"
}

# --- Write or preview CLAUDE.md ---
try {
    $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
} catch {
    LogDetail "footer OS: Get-CimInstance Win32_OperatingSystem failed ($_) -- using 'Windows'"
    $osInfo = ""
}
if (-not $osInfo) { $osInfo = "Windows" }
# Footer hostname: the resolver's (P-Q5, one hostname source: COMPUTERNAME,
# short, lower-case), read from Resolve-MachineProfile above. "unknown" when the
# resolver gave none (the resolver says why in a warning, logged as a detail line).
$machineHost = [string]$script:AitLibMachineHostname
if (-not $machineHost) { $machineHost = "unknown" }
$profileShown = if ($machineAlias) { $machineAlias } else { "unresolved" }

$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($machineHost; profile $profileShown)
- Shell: PowerShell and Git Bash (Claude Code on Windows: a PowerShell tool, and a Bash tool that runs Git Bash)
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
    # One pass over all values, longest first: a value inside a longer one
    # (company "nobul.tech" in email "jose@nobul.tech") never breaks the longer
    # one's token. Equal text keeps the first token in this order, so
    # {{PROFILE_NAME}} wins over {{IDENTITY_GIT_NAME}} (P-Q13). Case-sensitive,
    # like setup-user-claude.sh.
    $tok = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $vals = [System.Collections.Generic.List[object]]::new()
    $i = 0
    foreach ($pair in @(
            @($userRepoDisplay, 'USER_REPO_PATH'),
            @($profileName, 'PROFILE_NAME'),
            @($profileCompany, 'PROFILE_COMPANY'),
            @($identityGitName, 'IDENTITY_GIT_NAME'),
            @($identityGitEmail, 'IDENTITY_GIT_EMAIL'))) {
        $i++
        $v = [string]$pair[0]
        if (-not $v -or $tok.ContainsKey($v)) { continue }
        $tok[$v] = $pair[1]
        $vals.Add([pscustomobject]@{ V = $v; I = $i })
    }
    if ($vals.Count -eq 0) { return $Deployed }
    $ordered = $vals | Sort-Object @{ Expression = { $_.V.Length }; Descending = $true }, @{ Expression = { $_.I } }
    $pattern = ($ordered | ForEach-Object { [regex]::Escape($_.V) }) -join '|'
    return [regex]::Replace($Deployed, $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '{{' + $tok[$m.Value] + '}}' })
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
        try {
            $existingContent = Get-Content -LiteralPath $claudeMd -Raw -ErrorAction Stop
        } catch {
            Write-AitWarn "claude.md" "dry run: cannot read $claudeMd for the comparison: $_"
            $existingContent = ""
        }
        # Compared as Deploy-ManagedFile compares (trailing newlines removed,
        # case-sensitive; parity with setup-user-claude.sh)
        if (("$existingContent" -replace '[\r\n]+$', '') -ceq ($content -replace '[\r\n]+$', '')) {
            Log "[DRY RUN] Content unchanged"
            Write-Summary "OK" "claude.md" "verified"
        } else {
            Log "[DRY RUN] Content differs -- would overwrite"
            Write-Summary "OK" "claude.md" "dry-run: would update"
        }
    } else {
        Log "[DRY RUN] File does not exist -- would create"
        Write-Summary "OK" "claude.md" "dry-run: would create"
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
            # Post-write validation: check structure AND content (not just a
            # marker). The first problem found is the one error (its cause;
            # parity with setup-user-claude.sh).
            $claudeInvalid = ""
            if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
                $claudeInvalid = "$claudeMd is empty or missing"
            } else {
                $written = Get-Content $claudeMd -Raw
                if ($written -notmatch '## Machine-Specific') {
                    $claudeInvalid = "missing the Machine-Specific section"
                } elseif ($written -notmatch '## Coaching|## Code Style|## Tool') {
                    # Template body must be present -- a file with only the footer is corrupt
                    $claudeInvalid = "missing the template body (only the footer?)"
                }
            }
            # --- END post-write validation (extracted by build-deploy) ---
            if ($claudeInvalid) {
                Write-AitError "claude.md" "validation failed" $claudeInvalid
            } elseif ($claudeResult -eq "accept & adopt") {
                Write-Summary "OK" "claude.md" "accepted to profile"
            } else {
                Write-Summary "OK" "claude.md" "$claudeResult"
            }
        }
        "skipped" {
            # The library recorded the skip once (Write-AitWarn "claude.md")
        }
        "verified" {
            Log "CLAUDE.md verified (no differences)"
            Write-Summary "OK" "claude.md" "verified"
        }
        "failed" {
            # The library restored the files and recorded the error once
            # (Write-AitError "claude.md", with the write, merge or filter error)
        }
    }
}

# --- BEGIN rules deployment (extracted by build-deploy) ---
# Rules fan-out: .aitools\rules -> .claude\rules. deploy-harness fills
# .aitools\rules from aitools shared/rules, aitools .claude/rules and the
# dotprofile's claude/rules (first source wins) and writes its rules manifest
# (PR #100 contract). Claude Code gets every rule there except the ones the
# manifest retires (commander decisions 2026-10-22): *.md only, *.bak.* and
# hidden files skipped, names compared case-insensitively. The dotprofile's
# claude/rules is not read here. Additive: managed files updated, unmanaged
# files preserved; the copy of a retired rule is backed up and removed when it
# matches a harness copy. Adopt target: the repo file the manifest names as the
# rule's source, when it is on this machine. Parity: setup-user-claude.sh.
$rulesSrc = Join-Path (Join-Path $env:USERPROFILE ".aitools") "rules"
$rulesDest = Join-Path $claudeDir "rules"
$rulesManifest = Join-Path $rulesSrc ".aitools-rules-manifest"
# The aitools checkout this script runs from: adopt targets of shared and
# aitools rules. Only a git checkout counts: the generated deploy/ copy runs
# from the dotprofile's deploy/ directory, and a package payload (git archive,
# read-only) has no .git; adopt is then offered for dotprofile rules only.
# A linked git worktree (.git is a file there) counts too: run from a
# worktree, accept & adopt writes that worktree's shared/rules or
# .claude/rules, not the main checkout's.
$rulesAitoolsRepo = ""
if ($claudeScriptDir) {
    $rulesRepoCand = Split-Path -Parent $claudeScriptDir
    if ((Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "scripts") "aitools-lib.ps1") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "shared") "claude-shared.md") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $rulesRepoCand ".git"))) {
        $rulesAitoolsRepo = $rulesRepoCand
    }
}

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
# The repo file that a rule from Source (a rules manifest source) came from, or
# "" when that file is not on this machine (adopt and merge are then not
# offered). A dotprofile adopt target is committed and pushed by the library
# (N-Q2); an aitools one is a working-tree change. Parity: rule_adopt_target in
# setup-user-claude.sh.
function Get-RuleAdoptTarget([string]$Name, [string]$Source) {
    $target = ""
    if ($Source -ceq "shared" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo "shared") "rules") $Name
    } elseif ($Source -ceq "aitools" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo ".claude") "rules") $Name
    } elseif ($Source -ceq "dotprofile" -and $userRepoPath) {
        $target = Join-Path (Join-Path (Join-Path $userRepoPath "claude") "rules") $Name
    }
    if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) { return $target }
    return ""
}

# Byte comparison of a retired rule's copy with its harness copies and
# backups: the lib's Test-FanoutTextEqual (0 equal apart from trailing CR/LF,
# 1 differ, 2 unreadable; parity fanout_text_equal).

$rulesGo = $false
$rulesEntries = @()
if (-not (Test-Path -LiteralPath $rulesSrc -PathType Container)) {
    Log "No harness rules at $rulesSrc (deploy-harness has not run) -- skipping"
    Write-Summary "OK" "claude rules" "n/a (no harness rules)"
} else {
    try {
        $rulesEntries = @(Get-ChildItem -LiteralPath $rulesSrc -ErrorAction Stop)
        # Ordinal order, as the .sh (LC_ALL=C sort): Sort-Object compares by culture
        # (a.md before A.md), the .sh glob by LC_COLLATE, so they could disagree
        [Array]::Sort($rulesEntries, [Comparison[object]]{ param($x, $y) [string]::CompareOrdinal($x.Name, $y.Name) })
        $rulesGo = $true
    } catch {
        Write-AitError "claude rules" "cannot read harness rules" (Get-AitErrorReason -ErrorRecord $_)
    }
}

# Rules manifest: each rule's source (adopt target) and the retired names.
# Without one (deploy-harness before PR #100) every rule is fanned out, none
# is retired and adopt is not offered.
$manifestOk = $false
$manifestFailed = $false   # unreadable: one error, and a failed tracker item
$ruleSourceOf = @{}   # name -> source; PowerShell hashtable keys are case-insensitive
$retiredNames = New-Object System.Collections.Generic.List[string]
$retiredSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
if ($rulesGo) {
    # Absent only when nothing is at the path: a directory or a dangling link
    # there (Test-Path is true for one on pwsh 7) goes to the reader, which
    # reports it as unreadable
    if (-not (Test-Path -LiteralPath $rulesManifest)) {
        Log "No rules manifest at $rulesManifest -- every rule fanned out, none retired, adopt not offered"
    } else {
        $manifest = $null
        try {
            $manifest = Read-RulesManifest $rulesManifest
        } catch {
            Write-AitError "claude rules" "cannot read rules manifest" (Get-AitErrorReason -ErrorRecord $_)
            Log "every rule fanned out, none retired"
            $manifestFailed = $true
        }
        if ($manifest -and $manifest.Status -eq "header-bad") {
            LogDetail "rules manifest ${rulesManifest}: the first line is not `"$rulesManifestHeader`""
            Write-AitAction "claude rules" "bad rules manifest header -- run: aitools (every rule fanned out, none retired, adopt not offered)" "Run aitools to rebuild ~/.aitools/rules and its manifest"
        } elseif ($manifest) {
            $manifestOk = $true
            foreach ($bad in $manifest.Invalid) { Write-AitWarn "claude rules" "rules manifest line ignored: $bad" }
            # One ACTION for every ignored line (parity with setup-user-cursor)
            if (@($manifest.Invalid).Count -gt 0) {
                Write-Summary "ACTION" "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
            }
            foreach ($r in $manifest.Rules) {
                if ($r.Source -ceq "retired") {
                    $retiredNames.Add($r.Name); [void]$retiredSet.Add($r.Name)
                } else {
                    $ruleSourceOf[$r.Name] = $r.Source
                }
            }
        }
    }
}

# Source files: every *.md in .aitools\rules (flat, the deploy-harness
# contract) that the manifest does not retire. Hidden files are skipped.
$ruleSources = @()
$ruleBroken = @()   # dangling symlinks: failed in the deploy loop
if ($rulesGo) {
    foreach ($entry in $rulesEntries) {
        $kind = Get-RuleNameKind $entry.Name
        if ($kind -eq "backup" -or $kind -eq "hidden") { continue }
        if ($kind -ne "rule") {
            Log "Ignoring non-rule file in harness rules: $($entry.Name) (only *.md is fanned out)"
            continue
        }
        if ($retiredSet.Contains($entry.Name)) {
            Log "Not fanned out: $($entry.Name) (retired in the rules manifest)"
            continue
        }
        if ($entry.LinkType) {
            # Test-Path is true for a dangling link on pwsh 7; check the final target
            $linkOk = $false
            try {
                $linkOk = [bool]$entry.ResolveLinkTarget($true).Exists
            } catch {
                LogDetail "claude rules: cannot resolve the link $($entry.FullName): $_"
                $linkOk = $false
            }
            if (-not $linkOk) { $ruleBroken += $entry.Name; continue }
        }
        if ($entry.PSIsContainer) { Log "Ignoring non-file in harness rules: $($entry.Name)"; continue }
        $ruleSources += $entry
    }

    if ($ruleSources.Count -eq 0 -and $ruleBroken.Count -eq 0 -and $retiredNames.Count -eq 0) {
        Log "No rules in $rulesSrc -- skipping"
        # An unreadable manifest already recorded this tool's error
        if (-not $manifestFailed) { Write-Summary "OK" "claude rules" "n/a (no harness rules)" }
        $rulesGo = $false
    } elseif ($DryRun) {
        # The dry run previews the error the real run reports: something that
        # is not a directory where .claude\rules goes
        if ((Test-Path -LiteralPath $rulesDest) -and -not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
            Write-AitError "claude rules" "cannot create rules dir" "$rulesDest is not a directory (dry run)"
            $rulesGo = $false
        }
    } else {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
            $mkdirError = ""
            try {
                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
            } catch {
                $mkdirError = "$_"
            }
            # New-Item -Force can return without an error when a file is in
            # the way: check the result (parity with mkdir -p in the .sh)
            if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
                if (-not $mkdirError) { $mkdirError = "$rulesDest is not a directory" }
                Write-AitError "claude rules" "cannot create rules dir" $mkdirError
                $rulesGo = $false
            }
        }
    }
}

if ($rulesGo) {
    Initialize-DeployTracker
    $errorsBefore = $errors
    if ($manifestFailed) {
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName ".aitools-rules-manifest"
    }
    # Each failed item below is one error record (Write-AitError "claude rules"
    # "failed: <item>" <cause>) and one tracker DETAIL item; the tracker's OK
    # status counts them, with no aggregate error record (logging.md 8.3)
    foreach ($brokenName in $ruleBroken) {
        Write-AitError "claude rules" "failed: $brokenName" "dangling symlink in $rulesSrc"
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $brokenName
    }

    # Deploy loop. [x]abort exits 2 from the library here: no "claude rules" row
    # is written, and the calling installer or aitools loop records
    # "script failed (exit 2)".
    $ruleDests = New-Object System.Collections.Generic.List[string]   # deployed names
    $ruleDestsLc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($src in $ruleSources) {
        $ruleName = $src.Name
        # Two harness rules whose names differ only in case (possible on a
        # case-sensitive file system) map to one file here: the first wins
        if ($ruleDestsLc.Contains($ruleName)) {
            Write-AitError "claude rules" "failed: $ruleName" "a harness rule whose name differs only in case was already deployed"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleDests.Add($ruleName); [void]$ruleDestsLc.Add($ruleName)
        $ruleSource = ""
        $ruleAdoptPath = ""
        if ($manifestOk -and $ruleSourceOf.ContainsKey($ruleName)) {
            $ruleSource = $ruleSourceOf[$ruleName]
            $ruleAdoptPath = Get-RuleAdoptTarget $ruleName $ruleSource
        }
        $ruleSourceShown = if ($ruleSource) { $ruleSource } else { "unknown" }
        $ruleAdoptShown = if ($ruleAdoptPath) { $ruleAdoptPath } else { "none" }
        LogDetail "claude rules: $ruleName source=$ruleSourceShown adopt=$ruleAdoptShown"
        try {
            $ruleContent = [System.IO.File]::ReadAllText($src.FullName, [System.Text.UTF8Encoding]::new($false))
        } catch {
            Write-AitError "claude rules" "failed: $ruleName" (Get-AitErrorReason -ErrorRecord $_)
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath (Join-Path $rulesDest $ruleName) -ToolName "claude rules" -ItemName $ruleName -AdoptPath $ruleAdoptPath
        switch ($ruleResult) {
            { $_ -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed") } {
                # The library wrote LOCAL and the adopt target itself (it commits
                # and pushes a dotprofile adopt target, N-Q2) and recorded a
                # failed or skipped file once; the tracker counts every outcome.
            }
            default {
                Write-AitError "claude rules" "failed: $ruleName" "unexpected deploy result: $ruleResult"
                $ruleResult = "failed"
            }
        }
        Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $ruleName
    }

    # Retired rules: the copy in .claude\rules is backed up and removed when it
    # is this fan-out's copy -- the same text as the harness copy or as a backup
    # deploy-harness made when it retired the rule. Any other file of that name
    # may be the user's own: kept, with a warning.
    $rmKept = New-Object System.Collections.Generic.List[string]
    foreach ($rmName in $retiredNames) {
        # Deployed this run under a name that differs only in case
        if ($ruleDestsLc.Contains($rmName)) { continue }
        # The copy in .claude\rules, found case-insensitively (a case-sensitive
        # file system may hold it as Gone.md for the manifest's gone.md)
        $rmPath = ""
        if (Test-Path -LiteralPath $rulesDest -PathType Container) {
            try {
                foreach ($f in @([System.IO.Directory]::GetFiles($rulesDest) | Sort-Object -CaseSensitive)) {
                    if ([string]::Equals([System.IO.Path]::GetFileName($f), $rmName, [System.StringComparison]::OrdinalIgnoreCase)) { $rmPath = $f; break }
                }
            } catch {
                Write-AitWarn "claude rules" "cannot list $rulesDest for retired rule ${rmName}: $_"
            }
        }
        if (-not $rmPath) { continue }
        $rmFile = [System.IO.Path]::GetFileName($rmPath)
        try {
            $null = [System.IO.File]::ReadAllBytes($rmPath)
        } catch {
            Write-AitError "claude rules" "retired rule $rmFile not removed" (Get-AitErrorReason -ErrorRecord $_)
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        $rmCands = New-Object System.Collections.Generic.List[string]
        $rmCands.Add((Join-Path $rulesSrc $rmName))
        try {
            $rmBaks = @([System.IO.Directory]::GetFiles($rulesSrc) |
                Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmName.bak.", [System.StringComparison]::Ordinal) } |
                Sort-Object -Property { [System.IO.Path]::GetFileName($_) } -CaseSensitive)
            foreach ($b in $rmBaks) { $rmCands.Add($b) }
        } catch {
            Write-AitWarn "claude rules" "cannot list the backups of $rmName in ${rulesSrc}: $_"
        }
        $rmWhy = ""
        foreach ($rmCand in $rmCands) {
            if (-not (Test-Path -LiteralPath $rmCand -PathType Leaf)) { continue }
            $rmRc = Test-FanoutTextEqual $rmPath $rmCand
            if ($rmRc -eq 0) {
                $rmWhy = "same text as $([System.IO.Path]::GetFileName($rmCand))"
                break
            }
            if ($rmRc -ne 1) { Write-AitWarn "claude rules" "cannot compare $rmPath with $rmCand" }
        }
        if (-not $rmWhy) {
            Write-AitWarn "claude rules" "kept ${rmFile}: the rules manifest retires $rmName, but it matches no harness copy -- delete it if it is an old fan-out copy"
            $rmKept.Add($rmFile)
            continue
        }
        if ($DryRun) {
            Log "[DRY RUN] Would back up and remove $rmFile (retired rule; $rmWhy)"
            continue
        }
        # The file is removed only with a backup, so this script makes its own
        # copy (not Backup-File, which warns and proceeds): one failure is one
        # error (the G3 rule for retired-rule backups). Belt and braces: the
        # copy must exist and hold the same text (a copy that reports success
        # without writing must not lose the file). Parity: setup-user-claude.sh.
        $rmBak = "$rmPath.bak.$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmmssZ'))"
        try {
            Copy-Item -LiteralPath $rmPath -Destination $rmBak -Force -ErrorAction Stop
        } catch {
            Write-AitError "claude rules" "retired rule $rmFile not removed" "backup failed: $(Get-AitErrorReason -ErrorRecord $_)"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        if (-not (Test-Path -LiteralPath $rmBak -PathType Leaf) -or (Test-FanoutTextEqual $rmPath $rmBak) -ne 0) {
            Write-AitError "claude rules" "retired rule $rmFile not removed" "backup failed: $rmBak missing or different after the copy"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        Log "Backed up $rmPath"
        try {
            Remove-Item -LiteralPath $rmPath -Force -ErrorAction Stop
        } catch {
            Write-AitError "claude rules" "cannot remove retired rule $rmFile" (Get-AitErrorReason -ErrorRecord $_)
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        if (Test-Path -LiteralPath $rmPath) {
            Write-AitError "claude rules" "cannot remove retired rule $rmFile" "still present after Remove-Item"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        Log "Removed $rmFile (retired rule; $rmWhy; backup kept)"
        Record-DeployOutcome -Outcome "removed" -ToolName "claude rules" -ItemName $rmFile
    }
    if ($rmKept.Count -gt 0) {
        Write-Summary "ACTION" "" "Claude Code still loads retired rules in ~/.claude/rules: $($rmKept -join ', ') -- delete them unless you wrote them"
    }

    if ($DryRun) {
        # Each failed item already recorded its own error
        Write-Summary "OK" "claude rules" "dry run (no files written)"
    } else {
        # Preserved: rules in .claude\rules not fanned out this run
        $destEntries = @()
        try {
            $destEntries = @(Get-ChildItem -LiteralPath $rulesDest -File -ErrorAction Stop)
            # Ordinal order, as the .sh (LC_ALL=C sort): Sort-Object compares by culture
            # (a.md before A.md), the .sh glob by LC_COLLATE, so they could disagree
            [Array]::Sort($destEntries, [Comparison[object]]{ param($x, $y) [string]::CompareOrdinal($x.Name, $y.Name) })
        } catch {
            Write-AitWarn "claude rules" "cannot list $rulesDest for the preserved report: $_"
        }
        foreach ($existing in $destEntries) {
            if ((Get-RuleNameKind $existing.Name) -ne "rule") { continue }
            if (-not $ruleDestsLc.Contains($existing.Name)) {
                Log "Preserved unmanaged rule: $($existing.Name)"
                Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $existing.Name
            }
        }

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($ruleName in $ruleDests) {
            $destFile = Join-Path $rulesDest $ruleName
            if ((Test-Path -LiteralPath $destFile -PathType Leaf) -and (Get-Item -LiteralPath $destFile).Length -eq 0) {
                Write-AitError "claude rules" "validation failed: $ruleName" "empty after deploy"
            }
        }

        # The tracker writes the OK status (its counts include "N failed");
        # every failure, validation included, is already its own error record
        Write-DeployTrackerSummary -ToolName "claude rules"
        if ($script:dtFailed -eq 0 -and $errors -eq $errorsBefore) {
            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } else {
            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        }
    }
}
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN skills fan-out (extracted by build-deploy) ---
# Skills fan-out: .aitools\skills -> .claude\skills (lib
# Invoke-HarnessSkillsFanout; plans/skills-and-rules-fanout.md section 3.4).
# Every skill deploy-harness collected there except the retired ones; a user's
# own skill (a directory or symlink the fan-out did not deploy) is never
# touched. Adopt targets: this aitools checkout ($rulesAitoolsRepo, a git
# checkout only) and the dotprofile. Parity: setup-user-claude.sh.
Invoke-HarnessSkillsFanout -ToolName "claude skills" -DestDir (Join-Path $claudeDir "skills") -AitoolsRepo $rulesAitoolsRepo -Dotprofile $userRepoPath
# --- END skills fan-out (extracted by build-deploy) ---

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
