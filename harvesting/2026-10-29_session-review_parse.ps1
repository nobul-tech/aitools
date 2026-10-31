param([string]$Path)
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)
if ($e) { foreach ($x in $e) { "PARSE FAIL $Path line $($x.Extent.StartLineNumber): $($x.Message)" } } else { "parse OK: $Path" }
