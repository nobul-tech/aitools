# test-postpush-ps1.ps1 -- run the patched PS1 step 30/31 perl extractions
# (native-argument passing from pwsh) on exported libs. Arg: dir with
# scripts/aitools-lib.sh and scripts/aitools-lib.ps1.
param([string]$Root)
$shLib = Join-Path $Root "scripts/aitools-lib.sh"
$ps1Lib = Join-Path $Root "scripts/aitools-lib.ps1"
$shReturns = (perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="([^"]+)"/' $shLib | Sort-Object -Unique) -join ','
Write-Output "step30 shReturns: $shReturns"
$shResults = (perl -ne 'if (/^deploy_managed_file\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_managed_file/)) { print "$1\n" if /MANAGED_FILE_RESULT="([^"]+)"/ }' $shLib | Sort-Object -Unique) -join ','
$ps1Results = (perl -ne 'if (/^function Deploy-ManagedFile\b/ .. (/^function / && !/Deploy-ManagedFile/)) { print "$1\n" if /return\s+"([^"]+)"/ }' $ps1Lib | Sort-Object -Unique) -join ','
Write-Output "step31 results sh=$shResults ps1=$ps1Results equal=$($shResults -eq $ps1Results)"
$shTracker = (perl -ne 'if (/^deploy_tracker_record\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_tracker_record/)) { if (/^\s+((?:"[^"]+"|[\w.-]+)(?:\|(?:"[^"]+"|[\w.-]+))*)\)\s/) { for (split /\|/, $1) { s/"//g; print "$_\n" } } }' $shLib | Sort-Object -Unique) -join ','
$ps1Tracker = (perl -ne 'if (/^function Record-DeployOutcome\b/ .. (/^function / && !/Record-DeployOutcome/)) { while (/-eq\s+"([^"]+)"|"([^"]+)"\s*\{/g) { print(($1 // $2) . "\n") } }' $ps1Lib | Sort-Object -Unique) -join ','
Write-Output "step31 tracker sh=$shTracker ps1=$ps1Tracker equal=$($shTracker -eq $ps1Tracker)"
