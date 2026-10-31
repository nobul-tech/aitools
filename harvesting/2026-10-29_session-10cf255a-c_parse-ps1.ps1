# parse-ps1.ps1 -- report PowerShell parse errors for the given file (scratch)
param([string]$Path)
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)
if ($e) { $e; exit 1 } else { "parse OK: $Path" }
