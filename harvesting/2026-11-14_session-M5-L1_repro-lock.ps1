# repro-lock.ps1 -- does Log/LogDetail/LogWarn/LogError throw when deploy.log is locked?
param([string]$Lib = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-lib\scripts\aitools-lib.ps1")
$dir = Join-Path $PSScriptRoot "repro-lock"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$env:AITOOLS_LOG_DIR = $dir
$logPath = Join-Path $dir "deploy.log"
[IO.File]::WriteAllText($logPath, "")
$h = [IO.File]::Open($logPath, 'Open', 'ReadWrite', 'None')
try {
    $code = ". '$Lib'; Initialize-Logging 't'; try { Log 'info-line'; LogDetail 'detail-line'; LogWarn 'warn-line'; LogError 'err-line'; Write-Output ""COUNTS=`$(`$script:errors)/`$(`$script:warnings)"" } catch { Write-Output ""CAUGHT: `$(`$_.Exception.Message)"" }; `$ErrorActionPreference='Stop'; try { Log 'stop-line'; Write-Output 'AFTER-STOP' } catch { Write-Output ""CAUGHT-STOP: `$(`$_.Exception.Message)"" }"
    & pwsh -NoProfile -Command $code *>&1 | ForEach-Object { Write-Output "child> $_" }
    Write-Output "child rc=$LASTEXITCODE"
} finally {
    $h.Dispose()
}
