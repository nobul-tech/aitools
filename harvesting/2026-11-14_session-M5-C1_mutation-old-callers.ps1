# mutation-old-callers.ps1 -- the new suite must FAIL against the pre-fix check-*.ps1
# (origin/main versions) with the new check-lib.ps1: proves the caller cases bite.
$ErrorActionPreference = "Stop"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-checks"
$mut = Join-Path $wt ".scratch\session-M5-C1\mut"
if (Test-Path $mut) { Remove-Item -Recurse -Force $mut }
New-Item -ItemType Directory -Path (Join-Path $mut "scripts"), (Join-Path $mut "tests\check-lib") -Force | Out-Null
Copy-Item (Join-Path $wt "scripts\aitools-lib.ps1"), (Join-Path $wt "scripts\aitools-profile.ps1"), (Join-Path $wt "scripts\check-lib.ps1") (Join-Path $mut "scripts")
foreach ($f in @("check-pre-commit.ps1", "check-pre-push.ps1", "check-post-push.ps1")) {
    $old = & git -C $wt show "origin/main:scripts/$f"
    if ($LASTEXITCODE -ne 0) { throw "git show $f failed" }
    [IO.File]::WriteAllText((Join-Path $mut "scripts\$f"), ($old -join "`n"))
}
Copy-Item (Join-Path $wt "tests\check-lib\test-resolve-git-bash.ps1") (Join-Path $mut "tests\check-lib")
& pwsh -NoProfile -File (Join-Path $mut "tests\check-lib\test-resolve-git-bash.ps1")
"mutation suite exit: $LASTEXITCODE (want 1)"
