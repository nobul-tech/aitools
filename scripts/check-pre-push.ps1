# check-pre-push.ps1 -- automated pre-push checklist for aitools
# Usage: .\scripts\check-pre-push.ps1
# Read-only -- no -Fix mode (all checks are verification or reminders)
# Platform: Windows (PS 5.1 compatible)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")
. (Join-Path $scriptDir "init-logging.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use check-pre-push.sh."
    exit 1
}

ResolveConfig
CheckLogInit "pre-push"

Set-Location $script:RepoRoot

Write-Host ""
Write-Host "=== PRE-PUSH CHECKLIST ===" -ForegroundColor White
Write-Host ""

# Commits in this push
$commitsRaw = InvokeGit log --oneline origin/main..HEAD
$commits = @()
if ($commitsRaw) { $commits = @($commitsRaw -split "`n" | Where-Object { $_ }) }
$commitCount = $commits.Count

if ($commitCount -eq 0) {
    Write-Host "No unpushed commits found."
    StepSkip "1-10" "All steps" "nothing to push"
    PrintSummary
    exit 0
}

# Files changed in this push
$pushFilesRaw = InvokeGit log --name-only --pretty=format: origin/main..HEAD
$pushFiles = @()
if ($pushFilesRaw) {
    $pushFiles = @($pushFilesRaw -split "`n" | Where-Object { $_ } | Sort-Object -Unique)
}

# ---------------------------------------------------------------------------
# 1. Pre-commit passed
# ---------------------------------------------------------------------------
StepWarn "1" "Pre-commit passed" "confirm pre-commit checklist was run for each commit"

# ---------------------------------------------------------------------------
# 2. No scratch/sensitive files
# ---------------------------------------------------------------------------
# scratch.<ext> is limited to throwaway extensions so the user rule
# shared/rules/scratch.md is not flagged (2026-10-21; keep in sync with .sh).
$blocklist = '(chat\.txt|\.tmp$|\.env$|credentials|\.secret|scratch\.(txt|sh|ps1|py|js|log|out|json)$|temp\.|TODO\.txt)'
$badFiles = @($pushFiles | Where-Object { $_ -match $blocklist })
if ($badFiles.Count -eq 0) {
    StepPass "2" "No scratch/sensitive files"
} else {
    StepFail "2" "No scratch/sensitive files" "found: $($badFiles -join ', ')"
}

# ---------------------------------------------------------------------------
# 3. Secret scan
# ---------------------------------------------------------------------------
$pushDiff = InvokeGit diff origin/main..HEAD
$secretPattern = '^\+.*(password|secret|api_key|api-key|apikey|token|bearer|private_key|AWS_ACCESS|ANTHROPIC_API)\s*[=:]'
$secretsFound = @()
if ($pushDiff) {
    $secretsFound = @($pushDiff -split "`n" | Where-Object { $_ -match $secretPattern })
}
if ($secretsFound.Count -eq 0) {
    StepPass "3" "Secret scan"
} else {
    StepFail "3" "Secret scan" "$($secretsFound.Count) suspicious line(s) -- review git diff origin/main..HEAD"
}

# ---------------------------------------------------------------------------
# 4. No WIP commits
# ---------------------------------------------------------------------------
$wipCommits = @($commits | Where-Object { $_ -match '^[a-f0-9]+ (WIP|fixup!|squash!|TODO)' })
if ($wipCommits.Count -eq 0) {
    StepPass "4" "No WIP commits"
} else {
    StepFail "4" "No WIP commits" "found: $($wipCommits[0..2] -join '; ')"
}

# ---------------------------------------------------------------------------
# 5. Release notes current
# ---------------------------------------------------------------------------
$nonDocsPush = @($pushFiles | Where-Object { $_ -notmatch '\.(md|mdc)$' })
$rnInDiff = $pushFiles -contains 'RELEASE_NOTES.md'
if ($nonDocsPush.Count -eq 0) {
    StepSkip "5" "Release notes current" "docs-only push"
} elseif ($rnInDiff) {
    StepPass "5" "Release notes current"
} else {
    StepWarn "5" "Release notes current" "non-docs changes without RELEASE_NOTES.md"
}

# ---------------------------------------------------------------------------
# 6. Roadmap reflects reality
# ---------------------------------------------------------------------------
StepWarn "6" "Roadmap reflects reality" "check if push completes or starts a roadmap item"

# ---------------------------------------------------------------------------
# 7. deploy/ matches source
# ---------------------------------------------------------------------------
# Generated deploy scripts live in the dotprofile repo (deploy-paths.md; aitools/deploy/
# is frozen). When a deploy-relevant source changes (setup scripts, the build script,
# aitools-lib -- inlined into every deploy script --, the profile resolver and its JSON
# engine -- embedded in the resolver-consuming deploy scripts (M3 B5, review M7) -- or
# shared/), rebuild from this branch into a temporary copy of the dotprofile's committed
# tree and compare its deploy/. Then smoke-run the generated resolver consumers
# (-DryRun, isolated USERPROFILE): a deploy script that cannot find its resolver fails
# here, not on an endpoint (B8a INCIDENT). The smoke run lives here, not in
# build-deploy, so build-deploy stays a pure generator.
# The build gets the temp copy through AITOOLS_USER_REPO_PATH (build-deploy's
# entry-point input) and no AITOOLS_PROFILE_FILE / AITOOLS_MACHINE_ALIAS from this
# session (review H5): an inherited value would otherwise point the build, which
# deletes and rebuilds <dotprofile>/deploy, at the real dotprofile.
$deploySources = @($pushFiles | Where-Object { $_ -match '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)' })
# build-deploy.sh runs under Git Bash (approved cross-language exception); same lookup
# order as check-pre-commit step 3 after the known Git for Windows locations.
$d7Bash = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $d7Bash) {
    $d7BashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($d7BashCmd) { $d7Bash = $d7BashCmd.Source }
}
if ($deploySources.Count -eq 0) {
    StepSkip "7" "deploy/ matches source" "no deploy-relevant source changes"
} elseif (-not $script:UserRepoPath -or -not (Test-Path (Join-Path $script:UserRepoPath ".git"))) {
    StepSkip "7" "deploy/ matches source" "userRepoPath not configured -- dotprofile deploy/ not verified"
} elseif (-not $d7Bash) {
    StepWarn "7" "deploy/ matches source" "Git Bash not found -- dotprofile deploy/ not verified"
} else {
    $d7Tmp = Join-Path ([IO.Path]::GetTempPath()) ("aitools-prepush7-" + [guid]::NewGuid())
    $d7Dot = Join-Path $d7Tmp "dot"
    $d7Committed = Join-Path $d7Tmp "committed"
    $d7Home = Join-Path $d7Tmp "home"
    $d7Tar = Join-Path $d7Tmp "dot.tar"
    $prevEap = $ErrorActionPreference
    # Environment the build and the smoke run override; restored in finally
    $d7EnvNames = @("HOME", "USERPROFILE", "AITOOLS_USER_REPO_PATH", "AITOOLS_PROFILE_FILE", "AITOOLS_MACHINE_ALIAS",
        "AITOOLS_SUMMARY_FILE", "AITOOLS_PROFILE_SH", "AITOOLS_PROFILE_PS1", "AITOOLS_LOG_DIR")
    $d7EnvPrev = @{}
    foreach ($n in $d7EnvNames) { $d7EnvPrev[$n] = [Environment]::GetEnvironmentVariable($n) }
    # Native tools write progress and warnings to stderr; Stop would turn those into
    # terminating errors (see InvokeGit). Every step's exit code is checked instead.
    $ErrorActionPreference = "Continue"
    $d7Log = ""
    $d7Rc = 0
    $d7Smoke = @()
    $d7Built = $false
    try {
        $d7CfgDir = Join-Path $d7Home ".aitools"
        New-Item -ItemType Directory -Path $d7Dot, $d7Committed, $d7CfgDir -Force | Out-Null
        $d7Log += & git -C $script:UserRepoPath archive -o $d7Tar HEAD 2>&1 | Out-String
        $d7Rc = $LASTEXITCODE
        if ($d7Rc -eq 0) { $d7Log += & tar -xf $d7Tar -C $d7Dot 2>&1 | Out-String; $d7Rc = $LASTEXITCODE }
        if ($d7Rc -eq 0) { $d7Log += & tar -xf $d7Tar -C $d7Committed 2>&1 | Out-String; $d7Rc = $LASTEXITCODE }
        if ($d7Rc -eq 0) {
            $d7Cfg = [pscustomobject]@{}
            if (Test-Path $script:ConfigFile) {
                $d7Cfg = Get-Content $script:ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            }
            $d7Cfg | Add-Member -NotePropertyName "repoPath" -NotePropertyValue $script:RepoRoot -Force
            $d7Cfg | Add-Member -NotePropertyName "userRepoPath" -NotePropertyValue $d7Dot -Force
            [IO.File]::WriteAllText((Join-Path $d7CfgDir "config.json"), ($d7Cfg | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
            # The copy's committed deploy/ goes first: a build that skips (exit 0, no
            # dotprofile found) then leaves no deploy/, instead of passing the compare.
            $d7DotDeploy = Join-Path $d7Dot "deploy"
            if (Test-Path $d7DotDeploy) { Remove-Item -Recurse -Force $d7DotDeploy -ErrorAction Stop }
            foreach ($n in @("AITOOLS_PROFILE_FILE", "AITOOLS_MACHINE_ALIAS", "AITOOLS_SUMMARY_FILE")) { [Environment]::SetEnvironmentVariable($n, $null) }
            $env:HOME = $d7Home
            # Forward-slash form (C:/...), as the entry point passes it to Git Bash
            $env:AITOOLS_USER_REPO_PATH = $d7Dot -replace '\\', '/'
            $d7Log += & $d7Bash "$script:RepoRoot/scripts/build-deploy.sh" 2>&1 | Out-String
            $d7Rc = $LASTEXITCODE
        }
        $d7Built = ($d7Rc -eq 0) -and (Test-Path (Join-Path $d7Dot "deploy"))
        if ($d7Built) {
            # Smoke run of the fresh build's resolver consumers (see the step comment).
            # Exit 0/1 is a run (1 = a counted error such as this machine having no
            # profile); 2+ is a crash or a parse error. "resolver missing" in the output
            # or the run summary is the B8a failure. The claude script must also report
            # its profile source.
            $d7Sum = Join-Path $d7Tmp "smoke-summary"
            foreach ($n in @("AITOOLS_PROFILE_SH", "AITOOLS_PROFILE_PS1")) { [Environment]::SetEnvironmentVariable($n, $null) }
            $env:USERPROFILE = $d7Home
            $env:AITOOLS_LOG_DIR = Join-Path $d7Tmp "logs"
            $env:AITOOLS_USER_REPO_PATH = $d7Dot
            $env:AITOOLS_SUMMARY_FILE = $d7Sum
            foreach ($s in @("setup-user-claude.ps1", "setup-user-settings.ps1", "setup-user-cursor.ps1")) {
                [IO.File]::WriteAllText($d7Sum, "", (New-Object System.Text.UTF8Encoding($false)))
                $sOut = & pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path (Join-Path $d7Dot "deploy") $s) -DryRun 2>&1 | Out-String
                $sRc = $LASTEXITCODE
                foreach ($l in $sOut.Split("`n")) { if ($l.Trim()) { LogDetail "pre-push 7 smoke ${s}: $($l.TrimEnd())" } }
                $sSum = [IO.File]::ReadAllText($d7Sum)
                if ($sRc -gt 1) {
                    $d7Smoke += "$s(exit $sRc)"
                } elseif ($sOut -match 'resolver missing' -or $sSum -match 'resolver missing') {
                    $d7Smoke += "$s(resolver missing)"
                } elseif ($s -eq "setup-user-claude.ps1" -and (Test-Path (Join-Path $d7Dot "profile.json")) -and $sOut -notmatch 'Profile source: live') {
                    $d7Smoke += "$s(live profile not used)"
                }
            }
            # The endpoint path (review m2): the same claude script on a machine without
            # the dotprofile (empty config.json, no AITOOLS_USER_REPO_PATH) must resolve
            # from the embedded build-time snapshot.
            if (Test-Path (Join-Path $d7Dot "profile.json")) {
                $d7Endpoint = Join-Path $d7Tmp "endpoint"
                $d7EndpointCfg = Join-Path $d7Endpoint ".aitools"
                New-Item -ItemType Directory -Path $d7EndpointCfg -Force -ErrorAction Stop | Out-Null
                [IO.File]::WriteAllText((Join-Path $d7EndpointCfg "config.json"), "{}`n", (New-Object System.Text.UTF8Encoding($false)))
                [IO.File]::WriteAllText($d7Sum, "", (New-Object System.Text.UTF8Encoding($false)))
                $env:HOME = $d7Endpoint
                $env:USERPROFILE = $d7Endpoint
                [Environment]::SetEnvironmentVariable("AITOOLS_USER_REPO_PATH", $null)
                $sOut = & pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path (Join-Path $d7Dot "deploy") "setup-user-claude.ps1") -DryRun 2>&1 | Out-String
                $sRc = $LASTEXITCODE
                foreach ($l in $sOut.Split("`n")) { if ($l.Trim()) { LogDetail "pre-push 7 smoke endpoint setup-user-claude.ps1: $($l.TrimEnd())" } }
                if ($sRc -gt 1) {
                    $d7Smoke += "endpoint:setup-user-claude.ps1(exit $sRc)"
                } elseif ($sOut -notmatch 'Profile source: embedded build-time snapshot') {
                    $d7Smoke += "endpoint:setup-user-claude.ps1(snapshot not used)"
                }
            }
        }
    } catch {
        $d7Log += "$_"
        $d7Rc = 1
    } finally {
        foreach ($n in $d7EnvNames) { [Environment]::SetEnvironmentVariable($n, $d7EnvPrev[$n]) }
        $ErrorActionPreference = $prevEap
    }
    if ($d7Rc -ne 0) {
        foreach ($l in $d7Log.Split("`n")) { if ($l.Trim()) { LogDetail "pre-push 7 build: $($l.TrimEnd())" } }
        StepFail "7" "deploy/ matches source" "rebuild into a dotprofile copy failed (exit $d7Rc) -- see deploy.log"
    } elseif (-not $d7Built) {
        # The copy's committed deploy/ was removed before the build, and build-deploy
        # exits 0 without building when it finds no dotprofile.
        foreach ($l in $d7Log.Split("`n")) { if ($l.Trim()) { LogDetail "pre-push 7 build: $($l.TrimEnd())" } }
        StepFail "7" "deploy/ matches source" "build-deploy built nothing into the dotprofile copy -- see deploy.log"
    } else {
        $d7Problems = @()
        $d7Stale = @()
        $d7BuiltDir = Join-Path $d7Dot "deploy"
        $d7Ref = Join-Path $d7Committed "deploy"
        $d7Names = @(Get-ChildItem $d7BuiltDir -File | ForEach-Object Name) + @(Get-ChildItem $d7Ref -File | ForEach-Object Name) | Sort-Object -Unique
        foreach ($n in $d7Names) {
            $a = Join-Path $d7Ref $n
            $b = Join-Path $d7BuiltDir $n
            if (-not (Test-Path $a) -or -not (Test-Path $b) -or (Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) { $d7Stale += $n }
        }
        if ($d7Stale.Count -gt 0) {
            $d7Problems += "dotprofile deploy/ is stale ($($d7Stale -join ' ')) -- run build-deploy.sh and commit in $($script:UserRepoPath)"
        }
        if ($d7Smoke.Count -gt 0) {
            $d7Problems += "generated deploy scripts failed a dry run: $($d7Smoke -join ' ') -- see deploy.log"
        }
        if ($d7Problems.Count -eq 0) {
            StepPass "7" "deploy/ matches source" "dotprofile deploy/ matches a fresh build; resolver consumers dry-run clean"
        } else {
            StepFail "7" "deploy/ matches source" ($d7Problems -join "; ")
        }
    }
    if (Test-Path $d7Tmp) { Remove-Item -Recurse -Force $d7Tmp }
}

# ---------------------------------------------------------------------------
# 8. Commit count check
# ---------------------------------------------------------------------------
if ($commitCount -gt 5) {
    StepWarn "8" "Commit count" "$commitCount commits -- review full list before pushing"
} else {
    StepPass "8" "Commit count" "$commitCount commit(s)"
}

# ---------------------------------------------------------------------------
# 9. Branch hygiene
# ---------------------------------------------------------------------------
$currentBranch = InvokeGit rev-parse --abbrev-ref HEAD
if ($currentBranch -eq "main") {
    StepPass "9" "Branch hygiene" "pushing to main (OK for single-maintainer)"
} else {
    StepPass "9" "Branch hygiene" "branch: $currentBranch"
}

# ---------------------------------------------------------------------------
# 10. User repo push
# ---------------------------------------------------------------------------
if ($script:UserRepoPath -and (Test-Path $script:UserRepoPath)) {
    $unpushedRaw = InvokeGit -C $script:UserRepoPath log --oneline origin/main..HEAD
    $unpushed = @()
    if ($unpushedRaw) { $unpushed = @($unpushedRaw -split "`n" | Where-Object { $_ }) }
    if ($unpushed.Count -gt 0) {
        StepWarn "10" "User repo push" "$($unpushed.Count) unpushed commit(s) in user repo"
    } else {
        StepPass "10" "User repo push"
    }
} else {
    StepSkip "10" "User repo push" "userRepoPath not configured"
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
