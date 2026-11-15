# Parser check of every .ps1 prototype and harness file in this scratch dir.
Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 -File | Where-Object { $_.Name -ne "aitools-lib.ps1" } | ForEach-Object {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e)
    if ($e) { "FAIL $($_.Name): $($e | ForEach-Object { $_.Message })" } else { "OK   $($_.Name)" }
}
