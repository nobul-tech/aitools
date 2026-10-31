# ps1-parse.ps1 -- parse each given .ps1 with the PowerShell parser; exit 1 on any error
$bad = 0
foreach ($f in $args) {
    $tokens = $null
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        Write-Output "FAIL $f"
        $errs | ForEach-Object { Write-Output ("  " + $_.Extent.StartLineNumber + ": " + $_.Message) }
        $bad++
    } else {
        Write-Output "PASS $f"
    }
}
Write-Output ("PowerShell " + $PSVersionTable.PSVersion)
if ($bad -gt 0) { exit 1 }
exit 0
