# analyze.ps1 -- print block count, end markers, parse errors, CR count, fragment lines of profile files
param([Parameter(ValueFromRemainingArguments)][string[]]$Paths)
foreach ($p in $Paths) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Output "$p : missing"; continue }
    $t = [IO.File]::ReadAllText($p)
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($t, [ref]$null, [ref]$errs)
    $starts = ([regex]::Matches($t, '(?m)^[ \t]*# >>> aitools managed >>>[ \t]*\r?$')).Count
    $ends = ([regex]::Matches($t, '(?m)^[ \t]*# <<< aitools managed <<<[ \t]*\r?$')).Count
    $i1 = ([regex]::Matches($t, '(?m)^[ \t]*# >>> aitools shell integration >>>[ \t]*\r?$')).Count
    $leg = ([regex]::Matches($t, '(?m)^[ \t]*# (aitools|ai-tooling) shell integration[ \t]*\r?$')).Count
    $cr = ([regex]::Matches($t, "`r")).Count
    $frag = ([regex]::Matches($t, '(?m)^.*_aitoolsLocalBin.*$')).Count
    Write-Output ("{0} : bytes={1} starts={2} ends={3} integ={4} legacy={5} parseErrors={6} CR={7} linesWith_aitoolsLocalBin={8}" -f (Split-Path $p -Leaf), $t.Length, $starts, $ends, $i1, $leg, @($errs).Count, $cr, $frag)
}
