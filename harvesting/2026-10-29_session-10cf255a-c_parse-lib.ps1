$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile('/Users/new-jose/repos/aitools/.claude/worktrees/mfchoices/scripts/aitools-lib.ps1', [ref]$null, [ref]$e)
if ($e.Count -gt 0) { foreach ($x in $e) { Write-Output "line $($x.Extent.StartLineNumber): $($x.Message)" }; exit 1 }
Write-Output "parse ok"
