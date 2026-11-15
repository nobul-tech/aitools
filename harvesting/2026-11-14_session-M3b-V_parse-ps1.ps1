# parse-ps1.ps1 -- M3b-Finish-V: run the PowerShell parser on every *.ps1 in -Dir.
param([Parameter(Mandatory)][string]$Dir)
$files = Get-ChildItem -Path $Dir -Filter "*.ps1" -File
if (-not $files) { Write-Output "no .ps1 files in $Dir"; exit 1 }
$bad = 0
foreach ($f in $files) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        Write-Output "FAIL parse: $($f.Name)"
        foreach ($e in $errs) { Write-Output "  line $($e.Extent.StartLineNumber): $($e.Message)" }
        $bad++
    }
}
Write-Output "pwsh parse: $($files.Count) files, $bad failed"
if ($bad -gt 0) { exit 1 }
exit 0
