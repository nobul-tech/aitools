# run-evidence.ps1 -- real-console before/after matrix for fix 1 (driver-owned consoles only),
# plus the redirected-stdin runs. Every target writes result-<label>.log here; the deploy.log of
# each run is appended below it. Output: evidence-run.log.
$here = $PSScriptRoot
$all = New-Object System.Collections.Generic.List[string]
function Add-Run([string]$Label) {
    $res = Join-Path $here "result-$Label.log"
    $all.Add("=================== $Label")
    if (Test-Path $res) { foreach ($l in Get-Content $res) { $all.Add($l) } }
    $ld = Join-Path $here "logs\$Label"
    if (Test-Path $ld) {
        $all.Add("--- deploy.log (console-input lines and warn/error):")
        foreach ($f in Get-ChildItem $ld -File) {
            foreach ($l in Get-Content $f.FullName) { if ($l -match 'console input|\[warn\]|\[error\]') { $all.Add($l) } }
        }
    }
}
$cook = "wait:READY|sleep:500|mode|send:o<CR>|sleep:1500|peek|sendunless:GOT:o<CR>|wait:DONE|mode|peek|exit:5000"
foreach ($v in @("main", "new")) {
    foreach ($m in @("2E8", "208")) {
        $null = & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "cook-$v-$m" -Target "target-cook.ps1" -Variant $v -Extra $m -Steps $cook
        Add-Run "cook-$v-$m"
    }
}
foreach ($v in @("main", "new")) {
    $null = & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "guard-$v-2E8" -Target "target-guard.ps1" -Variant $v -Extra "2E8" -Steps $cook
    Add-Run "guard-$v-2E8"
}
foreach ($k in @("1", "2")) {
    $null = & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "timing-$k" -Target "target-timing.ps1" -Variant "new" -Extra $k -Steps "wait:DONE|mode|exit:5000"
    Add-Run "timing-$k"
}
$t = Join-Path $here "target-redir.ps1"
foreach ($v in @("main", "new")) {
    foreach ($e in @("piped", "eof")) {
        $label = "redir-$v-$e"
        $log = Join-Path $here "result-$label.log"
        if (Test-Path $log) { Remove-Item $log }
        if ($e -eq "piped") {
            $cap = "o" | & pwsh -NoProfile -File $t -Out $log -Variant $v -Extra $e 2>&1 | Out-String
        } else {
            $cap = $null | & pwsh -NoProfile -File $t -Out $log -Variant $v -Extra $e 2>&1 | Out-String
        }
        $all.Add("console output (exit $LASTEXITCODE): [" + ($cap -replace "`r", '<CR>' -replace "`n", '<LF>' -replace "`e", '<ESC>') + "]")
        Add-Run $label
    }
}
[IO.File]::WriteAllLines((Join-Path $here "evidence-run.log"), $all)
$all
