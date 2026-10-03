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
$blocklist = '(chat\.txt|\.tmp$|\.env$|credentials|\.secret|scratch\.|temp\.|TODO\.txt)'
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
# aitools-lib -- inlined into every deploy script -- or shared/), rebuild from this branch
# into a temporary copy of the dotprofile's committed tree and compare its deploy/.
$deploySources = @($pushFiles | Where-Object { $_ -match '^(scripts/(setup-.*|build-deploy|aitools-lib)\.(sh|ps1)$|shared/)' })
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
    $prevHome = $env:HOME
    # Native tools write progress and warnings to stderr; Stop would turn those into
    # terminating errors (see InvokeGit). Every step's exit code is checked instead.
    $ErrorActionPreference = "Continue"
    $d7Log = ""
    $d7Rc = 0
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
            $env:HOME = $d7Home
            $d7Log += & $d7Bash "$script:RepoRoot/scripts/build-deploy.sh" 2>&1 | Out-String
            $d7Rc = $LASTEXITCODE
        }
    } catch {
        $d7Log += "$_"
        $d7Rc = 1
    } finally {
        $env:HOME = $prevHome
        $ErrorActionPreference = $prevEap
    }
    if ($d7Rc -ne 0) {
        foreach ($l in $d7Log.Split("`n")) { if ($l.Trim()) { LogDetail "pre-push 7 build: $($l.TrimEnd())" } }
        StepFail "7" "deploy/ matches source" "rebuild into a dotprofile copy failed (exit $d7Rc) -- see checks.log"
    } else {
        $d7Stale = @()
        $d7Built = Join-Path $d7Dot "deploy"
        $d7Ref = Join-Path $d7Committed "deploy"
        $d7Names = @(Get-ChildItem $d7Built -File | ForEach-Object Name) + @(Get-ChildItem $d7Ref -File | ForEach-Object Name) | Sort-Object -Unique
        foreach ($n in $d7Names) {
            $a = Join-Path $d7Ref $n
            $b = Join-Path $d7Built $n
            if (-not (Test-Path $a) -or -not (Test-Path $b) -or (Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) { $d7Stale += $n }
        }
        if ($d7Stale.Count -eq 0) {
            StepPass "7" "deploy/ matches source" "dotprofile deploy/ matches a fresh build"
        } else {
            StepFail "7" "deploy/ matches source" "dotprofile deploy/ is stale ($($d7Stale -join ' ')) -- run build-deploy.sh and commit in $($script:UserRepoPath)"
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
