$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)
if ($e) { $e; exit 1 }
"parse OK: $($args[0])"
