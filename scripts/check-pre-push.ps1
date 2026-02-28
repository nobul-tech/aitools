# check-pre-push.ps1 -- automated pre-push checklist for aitools
# Usage: .\scripts\check-pre-push.ps1
# Read-only -- no -Fix mode (all checks are verification or reminders)
# Platform: Windows (PS 5.1 compatible)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    Write-Host "Use check-pre-push.sh on macOS"; exit 1
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
$scriptsSharedChanged = @($pushFiles | Where-Object { $_ -match '^(scripts/|shared/).*\.(sh|ps1)$' })
$deployChanged = @($pushFiles | Where-Object { $_ -match '^deploy/' })
if ($scriptsSharedChanged.Count -eq 0) {
    StepSkip "7" "deploy/ matches source" "no scripts/shared changes"
} elseif ($deployChanged.Count -gt 0) {
    StepPass "7" "deploy/ matches source"
} else {
    StepFail "7" "deploy/ matches source" "scripts/shared changed but deploy/ not updated"
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
