# termios mechanism: plain vs guarded read after `stty raw -echo` (Git Bash termios emulation).
$here = $PSScriptRoot
$steps = "wait:BASH-READY|sleep:800|send:o<CR>|sleep:1500|peek|sendunless:BASH GOT:<LF>|sleep:1500|peek|wait:DONE|exit:5000"
foreach ($v in @("plain", "guarded")) {
    & pwsh -NoProfile -File (Join-Path $here "drv.ps1") -Label "stty-$v" -Target "target-stty.ps1" -Variant $v -Steps $steps -Timeout 20 | Out-Null
}
foreach ($v in @("plain", "guarded")) { "=== stty-$v"; Get-Content (Join-Path $here "result-stty-$v.log") }
