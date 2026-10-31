param([string]$Path)
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)
if ($e) { $e | ForEach-Object { Write-Output $_.ToString() }; exit 1 }
exit 0
