# parse51.ps1 -- parse each given file with the running PowerShell's parser; print errors.
# Usage: powershell.exe -NoProfile -File parse51.ps1 <file> [<file> ...]
$rc = 0
foreach ($f in $args) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        $rc = 1
        Write-Output ("PARSE ERRORS ({0}) in {1} [PS {2}]" -f $errs.Count, $f, $PSVersionTable.PSVersion)
        $errs | Select-Object -First 10 | ForEach-Object { Write-Output ("  line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) }
    } else {
        Write-Output ("OK {0} [PS {1}]" -f $f, $PSVersionTable.PSVersion)
    }
}
exit $rc
