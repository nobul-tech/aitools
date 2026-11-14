# Dot-source: defines Save-ConsoleInputMode and Restore-ConsoleInputMode from the
# worktree's scripts/aitools.ps1 (PowerShell AST), so the harness runs the real code.
$m3bEntry = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\scripts\aitools.ps1"
$m3bErrors = $null
$m3bAst = [System.Management.Automation.Language.Parser]::ParseFile($m3bEntry, [ref]$null, [ref]$m3bErrors)
if ($m3bErrors.Count -gt 0) { throw "aitools.ps1 has parse errors: $($m3bErrors[0].Message)" }
foreach ($m3bName in @("Save-ConsoleInputMode", "Restore-ConsoleInputMode")) {
    $m3bFn = $m3bAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $m3bName }, $true)
    if (-not $m3bFn) { throw "aitools.ps1 defines no $m3bName" }
    . ([scriptblock]::Create($m3bFn.Extent.Text))
}
