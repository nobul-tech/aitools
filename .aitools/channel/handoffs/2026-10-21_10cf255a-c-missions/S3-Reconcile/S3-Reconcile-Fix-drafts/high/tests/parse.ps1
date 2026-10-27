param([string]$Path)
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)
if ($e -and $e.Count -gt 0) {
    $e | ForEach-Object { Write-Output ("  line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) }
    exit 1
}
exit 0
