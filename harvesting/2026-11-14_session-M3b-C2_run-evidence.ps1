param([string]$OnlyList = "")
$Only = @($OnlyList -split ',' | Where-Object { $_ })
# run-evidence.ps1 -- real-console runs (driver-owned consoles only). Each target writes
# result-<label>.log here; this collects them (plus the AI / spinner lines of each run's
# deploy.log) into evidence-run.log (appended per invocation).
$here = $PSScriptRoot
$all = New-Object System.Collections.Generic.List[string]
function Add-Run([string]$Label) {
    $res = Join-Path $here "result-$Label.log"
    $all.Add("=================== $Label")
    if (Test-Path $res) { foreach ($l in Get-Content $res) { $all.Add($l) } }
    $ld = Join-Path $here "logs\$Label"
    if (Test-Path $ld) {
        $all.Add("--- deploy.log (AI / spinner / warn / error lines):")
        foreach ($f in Get-ChildItem $ld -File) {
            foreach ($l in Get-Content $f.FullName) { if ($l -match 'AI invocation|spinner|\[warn\]|\[error\]') { $all.Add($l) } }
        }
    }
}
function Run([string]$Label, [string]$Target, [string]$Variant, [string]$Steps, [switch]$NoExit) {
    if ($Only.Count -gt 0 -and -not ($Only | Where-Object { $Label -like $_ })) { return }
    $a = @{ Label = $Label; Target = $Target; Variant = $Variant; Steps = $Steps }
    if ($NoExit) { $null = & pwsh -NoProfile -File (Join-Path $here "drv.ps1") @a -NoExit }
    else { $null = & pwsh -NoProfile -File (Join-Path $here "drv.ps1") @a }
    Add-Run $Label
}
$spin = "wait:READY|sleep:600|peek|wait:INVOKE|sleep:1500|peek|sleep:900|peek|wait:STOPPED|sleep:300|peek|send:y<CR>|wait:DONE|peek|exit:8000"
foreach ($v in @("main", "new")) { Run "spin-$v" "target-spin.ps1" $v $spin }
$throw = "wait:READY|sleep:900|peek|wait:NEXT-SCRIPT|sleep:500|peek|sleep:900|peek|wait:DONE|exit:8000"
foreach ($v in @("nofin", "new")) { Run "throw-$v" "target-throw.ps1" $v $throw }
$ctrlc = "wait:READY|sleep:1500|peek|ctrlc|sleep:1500|peek|sleep:1000|peek|send:showrs<CR>|sleep:1000|peek|send:exit<CR>|exit:8000"
foreach ($v in @("nofin", "new")) { Run "ctrlc-$v" "target-ctrlc.ps1" $v $ctrlc -NoExit }
$stamp = "######## run at {0:yyyy-MM-ddTHH:mm:ss} local" -f (Get-Date)
[IO.File]::AppendAllLines((Join-Path $here "evidence-run.log"), [string[]](@($stamp) + $all))
$all
