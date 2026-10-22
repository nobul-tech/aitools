# convert-rule.ps1 -- test helper: run ConvertTo-CursorRule from scripts/setup-user-cursor.ps1
# on one file and write the result (UTF-8, no BOM) to an output file. The function
# is loaded from the script's AST, so the script body (and its Windows OS guard)
# never runs. Used by test-rules-fanout-cursor.sh for the bash/PS1 parity check.
# Platform: any pwsh 7 (macOS, Linux, Windows).
# Usage: pwsh -NoProfile -File convert-rule.ps1 <setup-user-cursor.ps1> <in-file> <out-file>
param([string]$Script, [string]$InFile, [string]$OutFile)
$ErrorActionPreference = "Stop"

$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$null, [ref]$errs)
if ($errs) { Write-Error "parse errors in $Script"; exit 1 }
$fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "ConvertTo-CursorRule" }, $true) | Select-Object -First 1
if (-not $fn) { Write-Error "ConvertTo-CursorRule not found in $Script"; exit 1 }
. ([scriptblock]::Create($fn.Extent.Text))

$text = [System.IO.File]::ReadAllText($InFile, [System.Text.UTF8Encoding]::new($false))
$out = ConvertTo-CursorRule $text
[System.IO.File]::WriteAllText($OutFile, $out, [System.Text.UTF8Encoding]::new($false))
