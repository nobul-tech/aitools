param([Parameter(Mandatory)][string]$Path)
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
if ($errs) {
    $errs | ForEach-Object { Write-Output ("PARSE ERROR: " + $_.Message + " at line " + $_.Extent.StartLineNumber) }
    exit 1
}
Write-Output "PARSE OK: $Path"
