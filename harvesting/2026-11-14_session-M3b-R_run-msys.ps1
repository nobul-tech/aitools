# Git Bash read_tty_choice-style read after a raw child, and a cooked control.
$here = $PSScriptRoot
$steps = "wait:READY|sleep:1200|mode|send:o<CR>|sleep:1500|peek|sendunless:MSYS GOT:o<CR>|sleep:1500|sendunless:MSYS GOT:<CR>|wait:DONE|mode|peek|exit:5000"
foreach ($v in @("none", "raw")) {
    & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "msys-$v" -Target "target-msys.ps1" -Variant $v -Extra "2E8" -Steps $steps -Timeout 20 | Out-Null
}
foreach ($v in @("none", "raw")) { "=== msys-$v"; Get-Content (Join-Path $here "result-msys-$v.log") }
