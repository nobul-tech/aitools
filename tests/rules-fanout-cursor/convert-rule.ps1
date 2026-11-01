# convert-rule.ps1 -- test helper: run ConvertTo-CursorRule from scripts/setup-user-cursor.ps1
# on one file and write the result (UTF-8, no BOM) to an output file. The function
# is loaded from the script's AST, so the script body (and its Windows OS guard)
# never runs: a unit-test entry to one function, not a run of the script.
# Used by test-rules-fanout-cursor.sh on Windows only (plans/ci-platform-targeting.md:
# the .ps1 code is tested where it runs): its converter cases compare the output
# with the .want texts the bash converter must also give, and it writes the
# converted fixtures of the fan-out cases. With a rule name, the aitools-fanout
# marker is written (as the fan-out does).
# Platform: Windows (pwsh 7; called from Git Bash with native paths).
# Usage: pwsh -NoProfile -File convert-rule.ps1 <setup-user-cursor.ps1> <in-file> <out-file> [rule-name]
param([string]$Script, [string]$InFile, [string]$OutFile, [string]$Name = "")
$ErrorActionPreference = "Stop"

$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$null, [ref]$errs)
if ($errs) { Write-Error "parse errors in $Script"; exit 1 }
$fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "ConvertTo-CursorRule" }, $true) | Select-Object -First 1
if (-not $fn) { Write-Error "ConvertTo-CursorRule not found in $Script"; exit 1 }
$mk = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$cursorFanoutMarker' }, $true) | Select-Object -First 1
if (-not $mk) { Write-Error "`$cursorFanoutMarker not found in $Script"; exit 1 }
. ([scriptblock]::Create($mk.Extent.Text))
. ([scriptblock]::Create($fn.Extent.Text))

$text = [System.IO.File]::ReadAllText($InFile, [System.Text.UTF8Encoding]::new($false))
$out = ConvertTo-CursorRule $text $Name
[System.IO.File]::WriteAllText($OutFile, $out, [System.Text.UTF8Encoding]::new($false))
