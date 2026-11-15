# probe-nocli.ps1 -- why does Get-Command claude still resolve after removing the fake function
# and pointing PATH at an empty dir?
$ErrorActionPreference = "Stop"
function Show([string]$t) { "$t : $((Get-Command claude -ErrorAction SilentlyContinue | ForEach-Object { "$($_.CommandType):$($_.Source)" }) -join ';')" }
function global:claude { "fake" }
Show "defined"
Remove-Item function:global:claude
Show "after Remove-Item function:global:claude"
Remove-Item -Path Function:\claude
Show "after Remove-Item Function:\claude"
