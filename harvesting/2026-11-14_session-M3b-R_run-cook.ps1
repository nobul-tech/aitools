# Runs the fix-1 real-console matrix: {current, proto} x {2E8, 208}.
$here = $PSScriptRoot
$steps = "wait:READY|sleep:500|mode|send:o<CR>|sleep:1500|peek|sendunless:GOT:o<CR>|wait:DONE|mode|peek|exit:5000"
foreach ($v in @("current", "proto")) {
    foreach ($m in @("2E8", "208")) {
        "=================== cook-$v-$m"
        & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "cook-$v-$m" -Target "target-cook.ps1" -Variant $v -Extra $m -Steps $steps
    }
}
