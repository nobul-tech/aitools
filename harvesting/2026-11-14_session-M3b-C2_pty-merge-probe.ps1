# pty-merge-probe.ps1 -- the managed-files merge cases under the pty harness
# (tests/managed-files/pty-run.py, pywinpty/ConPTY), with the origin/main lib (Start-Job spinner)
# and the worktree lib (in-process spinner). Shows: the spinner frames in the pty output, no
# "AI invocation" line on the terminal, and whether the read AFTER a rejected merge ([n]o, then
# s at the menu) is taken (test-managed-files.ps1 does not assert it: "console input after the
# AI spinner job (Start-Job) comes back corrupted"). Output: pty-merge-probe.log here.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C2"
$pty = Join-Path $wt "tests\managed-files\pty-run.py"
$pwshExe = (Get-Process -Id $PID).Path
$esc = [string][char]27
$report = New-Object System.Collections.Generic.List[string]
$libs = [ordered]@{ main = (Join-Path $sc "origin-aitools-lib.ps1"); new = (Join-Path $wt "scripts\aitools-lib.ps1") }
$cases = [ordered]@{ "merge-yes" = "m\ny\n"; "merge-reject-then-skip" = "m\nn\ns\n" }
foreach ($lv in $libs.Keys) {
    foreach ($cn in $cases.Keys) {
        $C = Join-Path $sc "pty\$lv-$cn"
        if (Test-Path $C) { Remove-Item -Recurse -Force $C }
        foreach ($d in @("home", "dest", "repo", "bin", "logs")) { New-Item -ItemType Directory -Force -Path (Join-Path $C $d) | Out-Null }
        & git -C (Join-Path $C "repo") init -q
        [IO.File]::WriteAllText((Join-Path $C "bin\claude.cmd"), "@echo off`r`nmore > nul`r`nping -n 3 127.0.0.1 > nul`r`necho # Title`r`necho merged line`r`n")
        [IO.File]::WriteAllText((Join-Path $C "repo\a.md"), "# Title`nsource line`n")
        [IO.File]::WriteAllText((Join-Path $C "dest\a.md"), "# Title`nlocal line`n")
        Set-Content -Path (Join-Path $C "summary") -Value "" -NoNewline
        $snip = Join-Path $C "snippet.ps1"
        $body = @"
. '$($libs[$lv])'
Initialize-Logging "t"
`$C = '$C'
`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'
`$r = Deploy-ManagedFile -Content ([IO.File]::ReadAllText(`$src)) -DestPath `$dest -ToolName "tool" -ItemName "item" -AdoptPath `$adopt; Set-Content -Path "`$C/result" -Value `$r -NoNewline
"@
        [IO.File]::WriteAllText($snip, $body)
        $old = @{ HOME = $env:HOME; USERPROFILE = $env:USERPROFILE; LOG = $env:AITOOLS_LOG_DIR; SUM = $env:AITOOLS_SUMMARY_FILE; PATH = $env:PATH }
        $env:HOME = Join-Path $C "home"; $env:USERPROFILE = $env:HOME
        $env:AITOOLS_LOG_DIR = Join-Path $C "logs"; $env:AITOOLS_SUMMARY_FILE = Join-Path $C "summary"
        $env:PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $old.PATH
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            & python3 $pty --input $cases[$cn] --log (Join-Path $C "out") -- $pwshExe -NoProfile -File $snip
            $rc = $LASTEXITCODE
        } finally {
            $env:HOME = $old.HOME; $env:USERPROFILE = $old.USERPROFILE; $env:AITOOLS_LOG_DIR = $old.LOG; $env:AITOOLS_SUMMARY_FILE = $old.SUM; $env:PATH = $old.PATH
        }
        $sw.Stop()
        $raw = if (Test-Path (Join-Path $C "out")) { Get-Content -Raw (Join-Path $C "out") } else { "" }
        $plain = $raw -replace "$esc\][^\a$esc]*(\a|$esc\\)", "" -replace "$esc\[[0-9;?]*[A-Za-z]", "" -replace "$esc[=>]", ""
        $result = if (Test-Path (Join-Path $C "result")) { (Get-Content -Raw (Join-Path $C "result")).Trim() } else { "<none>" }
        $frames = ([regex]::Matches($plain, '[/\-\\|] merging a\.md \(attempt 1\)\.\.\.')).Count
        $aiOnTerm = ([regex]::Matches($plain, 'AI invocation')).Count
        $menus = ([regex]::Matches($plain, [regex]::Escape("choice [o/a/m/s/x]"))).Count
        $logAi = @(Get-Content (Join-Path $C "logs\deploy.log") | Where-Object { $_ -match 'AI invocation' })
        $report.Add("=== lib=$lv case=$cn input=$($cases[$cn]) rc=$rc $($sw.ElapsedMilliseconds) ms result=[$result] dest=[$(([IO.File]::ReadAllText((Join-Path $C 'dest\a.md'))).Trim() -replace "`n", '\n')]")
        $report.Add("    spinner frames in pty output: $frames; 'AI invocation' on the terminal: $aiOnTerm; menus shown: $menus; deploy.log AI lines: $($logAi.Count)")
        foreach ($l in ($plain -split "`r?`n" | Where-Object { $_ -match 'merging|AI|choice|>>|accept|refine' } | Select-Object -First 14)) {
            $report.Add("    | " + ($l -replace "`r", '<CR>'))
        }
    }
}
[IO.File]::WriteAllLines((Join-Path $sc "pty-merge-probe.log"), $report)
$report
