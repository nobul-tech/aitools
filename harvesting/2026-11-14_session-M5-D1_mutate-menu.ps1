# mutate-menu.ps1 -- does breaking a Prompt-DiffReview branch fail tests/managed-files/test-managed-files.ps1?
# For each mutation: copy scripts/ and tests/managed-files/ of the worktree into a scratch tree,
# apply one literal replacement to scripts/aitools-lib.ps1 (must match exactly once), run the suite,
# report exit code and FAIL lines. The worktree itself is never modified.
param([Parameter(Mandatory)][string]$Worktree)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$mutations = @(
    @{ Name = "skip-returns-overwrite"; Old = 'return "skip"'; New = 'return "overwrite"' },
    @{ Name = "adopt-returns-skip"; Old = 'return "adopt"'; New = 'return "skip"' },
    @{ Name = "abort-not-called"; Old = '                Invoke-ManagedAbort'; New = '                return "skip"' }
)
$results = @()
foreach ($m in $mutations) {
    $dst = Join-Path $here ("mut-" + $m.Name)
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    New-Item -ItemType Directory -Path (Join-Path $dst "tests") -Force | Out-Null
    Copy-Item -Recurse (Join-Path $Worktree "scripts") (Join-Path $dst "scripts")
    Copy-Item -Recurse (Join-Path $Worktree "tests/managed-files") (Join-Path $dst "tests/managed-files")
    $libPath = Join-Path $dst "scripts/aitools-lib.ps1"
    $text = [IO.File]::ReadAllText($libPath)
    $start = $text.IndexOf("function Prompt-DiffReview")
    $end = $text.IndexOf("`nfunction ", $start + 10)
    $body = $text.Substring($start, $end - $start)
    $count = ([regex]::Matches($body, [regex]::Escape($m.Old))).Count
    if ($count -ne 1) {
        Write-Output "MUTATION $($m.Name): '$($m.Old)' found $count times in Prompt-DiffReview -- not applied"
        $results += "$($m.Name): NOT APPLIED"
        continue
    }
    $newBody = $body.Replace($m.Old, $m.New)
    [IO.File]::WriteAllText($libPath, $text.Substring(0, $start) + $newBody + $text.Substring($end))
    $log = Join-Path $here ("mut-" + $m.Name + ".log")
    & pwsh -NoProfile -File (Join-Path $dst "tests/managed-files/test-managed-files.ps1") *> $log
    $rc = $LASTEXITCODE
    $fails = @(Select-String -Path $log -Pattern '^FAIL ' | ForEach-Object { $_.Line })
    $summary = @(Select-String -Path $log -Pattern 'passed, \d+ failed' | ForEach-Object { $_.Line })
    Write-Output "MUTATION $($m.Name): exit $rc; $($summary -join ' ')"
    $fails | ForEach-Object { Write-Output "  $_" }
    $results += "$($m.Name): exit $rc, $($fails.Count) FAIL"
}
Write-Output "---"
$results | ForEach-Object { Write-Output $_ }
