# proto-fixture.ps1 -- reproduce the #172 corruption with the old buggy splice and measure it
$startMarker = "# >>> aitools managed >>>"
$endMarker = "# <<< aitools managed <<<"
$block = "$startMarker`n# Owned by aitools (scripts/setup-user-shell.ps1). Edit via the script, not by hand.`n`$__aitoolsLocalBin = Join-Path `$HOME `".local\bin`"`nif ((Test-Path `$__aitoolsLocalBin) -and (`$env:PATH -split ';')[0] -ne `$__aitoolsLocalBin) {`n    `$env:PATH = `"`$__aitoolsLocalBin;`$env:PATH`"`n}`n$endMarker"
$pattern = [regex]::Escape($startMarker) + "(?s).*?" + [regex]::Escape($endMarker) + "(\r?\n)?"
$c = "Set-Alias ll Get-ChildItem`n`n" + $block + "`n`n# aitools shell integration`n. `"C:\x\aliases.ps1`"`nfunction aitools { & `"`$HOME\.local\bin\aitools.ps1`" @args }`nfunction hh { & `"`$HOME\.local\bin\hh.ps1`" @args }`n"
for ($i = 1; $i -le 4; $i++) {
    $c = [regex]::Replace($c, $pattern, $block + "`n")
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($c, [ref]$null, [ref]$errs)
    $starts = ([regex]::Matches($c, [regex]::Escape($startMarker))).Count
    $ends = ([regex]::Matches($c, [regex]::Escape($endMarker))).Count
    $frag = ([regex]::Matches($c, '(?m)^_aitoolsLocalBin')).Count
    Write-Output ("run {0}: len={1} starts={2} ends={3} parseErrors={4} fragLinesStarting_={5}" -f $i, $c.Length, $starts, $ends, @($errs).Count, $frag)
}
