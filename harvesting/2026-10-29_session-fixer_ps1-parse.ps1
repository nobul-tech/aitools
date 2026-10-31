param([Parameter(Mandatory)][string]$Path)
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
if ($errs -and $errs.Count -gt 0) { $errs | ForEach-Object { [Console]::Error.WriteLine($_.ToString()) }; exit 1 }
exit 0
