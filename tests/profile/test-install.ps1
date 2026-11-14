# test-install.ps1 -- the installer's Step 3 and Step 5 helpers and log override on
# the lib relay (M3-FINISH item 7, FIX-2; audit A-1, A-16, A-17, A-18), PowerShell
# half: scripts/aitools-install.ps1 with scripts/aitools-lib.ps1. The Windows
# harness of this suite; tests/profile/test-install.sh is the macOS/Linux harness
# (scripts/aitools-install.sh with scripts/aitools-lib.sh).
#
# The full installer cannot run here (incident #89). Each case extracts the two
# blocks "# --- BEGIN install log helpers" and "# --- BEGIN install log override"
# from the installer, dot-sources aitools-lib.ps1 with Initialize-Logging
# "aitools-install" in a child pwsh under an isolated HOME, and runs one step
# against a stub:
#   step5-warn     a writer warning is counted in the installer's warnings, its
#                  lines reach deploy.jsonl (one run_id with the installer's own)
#                  and the console; its own OK row is kept
#   step5-runid    the child sees the installer's AITOOLS_RUN_ID, every record has it
#   step5-crash    a writer that dies without a row: one error and the relay's
#                  "ERROR|aitools config|script failed (exit 1)"
#   step5-ownrow   a writer that wrote its own ERROR row and exits 1: one error,
#                  no second row
#   jsonl-blocked  deploy.jsonl cannot be written: one warning, the run goes on
#   step3-*        Step 3 (Resolve-ReposDir): a relative path made absolute and
#                  created; a path that cannot be created is one error and one
#                  ERROR row "aitools config"
#   log-*          the log override's deploy.log write is fail-safe
#                  (reference/logging.md section 5; incident #174): with deploy.log
#                  a directory, or held open with no sharing, under
#                  $ErrorActionPreference = "Stop" and inside a try, the run goes
#                  on, the console lines print and the counters count; a writable
#                  deploy.log still gets the lines
#   relaysync-*    Step 22's Invoke-RelaySync: the sync runs and its exit code is
#                  returned whether or not deploy.log can be written; its output
#                  (stdout and stderr) reaches a writable one
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14: "sh
# scripts and tests should only run on linux/mac and ps1 on windows"): this
# harness runs the PowerShell installer blocks with native pwsh on Windows only;
# tests/profile/test-install.sh runs the bash blocks on macOS/Linux and refuses
# Windows. The cases, check names and order are those the .sh harness ran on
# Windows before (its "ps" branch); its bash-only cases print the same skip
# lines. HOME and USERPROFILE are set to the case home, paths in the mixed form
# (C:/...) the Git Bash harness passed. Every check is an explicit expectation,
# the same text for both languages, so the suite has no golden files.
#
# Safe to re-run: every case runs in a child pwsh under a temp HOME (removed on
# exit); the real HOME is never read or written. Exit 1 on failure.
#
# Usage: pwsh -NoProfile -File tests/profile/test-install.ps1 [-Help]

param([switch]$Help)
if ($Help) { foreach ($ln in (Get-Content -LiteralPath $PSCommandPath)) { if ($ln -notmatch '^#') { break }; Write-Output ($ln -replace '^# ?', '') }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/profile/test-install.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path

$script:PASS = 0; $script:FAIL = 0; $script:SKIP = 0
function ok([string]$Name) { $script:PASS++; Write-Output "  ok   $Name" }
function bad([string]$Name) { $script:FAIL++; Write-Output "  FAIL $Name" }
function skip([string]$Text) { $script:SKIP++; Write-Output "  skip $Text" }
# Show-Indented TEXT: every line indented by 7 spaces (the .sh's perl -pe 's/^/       /')
function Show-Indented([string]$Text) {
    $lines = @($Text -split "`n")
    if ($lines.Count -gt 0 -and $lines[-1] -eq "") { $lines = @($lines | Select-Object -SkipLast 1) }
    foreach ($l in $lines) { Write-Output "       $l" }
}
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text) }
# WriteLf PATH TEXT: TEXT with LF line ends. This file checks out CRLF (.gitattributes
# *.ps1 eol=crlf), so its here-strings carry CRLF; the stubs are written with the
# bytes the .sh harness's here-documents wrote.
function WriteLf([string]$Path, [string]$Text) { WriteText $Path ((($Text -replace "`r`n", "`n").TrimEnd("`n")) + "`n") }
function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }

# The relay-sync cases run their stub with "pwsh" from PATH, as the installer's
# Step 22 runs python from PATH (the .sh harness had the same check)
if (-not (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Output "  FAIL pwsh is not on PATH: the .ps1 installer blocks cannot be tested on Windows"
    exit 1
}

$WORK = New-TestTempRoot "test-install"
# NWORK: the temp root in the mixed form (C:/...), long (New-TestTempRoot expands
# 8.3 components): the form the Git Bash harness passed (cygpath -m). H: the case HOME.
$NWORK = $WORK -replace '\\', '/'
$H = "$NWORK/home"
$REPO = $root -replace '\\', '/'

try {
    # Stub config writer. WRITER_MODE: warn (one warning, its own OK row, exit 0),
    # crash (one warning, then exit 1 without a row or footer), ownrow (LogError-like
    # line, its own ERROR row, exit 1), runid (logs the AITOOLS_RUN_ID it sees),
    # anything else (one info line, exit 0). The .sh harness's writer.ps1, unchanged.
    WriteLf "$WORK/writer.ps1" @'
param([string]$ReposPath = "", [string]$RepoPath = "")
$ts = "2026-01-01T00:00:00Z"
Write-Host "[$ts] [setup-user-config] [info] stub writer"
switch ($env:WRITER_MODE) {
    "warn" {
        Write-Host "[$ts] [setup-user-config] [warn] stub warning"
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "OK|aitools config|stub`n")
        Write-Host "[$ts] [setup-user-config] [warn] COMPLETED with 1 warning(s)"
        exit 0
    }
    "crash" { Write-Host "[$ts] [setup-user-config] [warn] stub warning"; exit 1 }
    "runid" {
        $rid = if ($env:AITOOLS_RUN_ID) { $env:AITOOLS_RUN_ID } else { "unset" }
        Write-Host "[$ts] [setup-user-config] [info] run id $rid"
        exit 0
    }
    "ownrow" {
        Write-Host "[$ts] [setup-user-config] [error] stub failed"
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "ERROR|aitools config|stub failed`n")
        Write-Host "[$ts] [setup-user-config] [error] FAILED with 1 error(s)"
        exit 1
    }
}
exit 0
'@

    # Stub relay sync (Step 22): one stdout and one stderr line, a marker file (it
    # ran), exit SYNC_RC (default 0). The .sh harness's sync.ps1, unchanged.
    WriteLf "$WORK/sync.ps1" @'
Write-Output "sync-out-line"
[Console]::Error.WriteLine("sync-err-line")
[IO.File]::WriteAllText($env:SYNC_MARK, "ran")
$c = 0
if ($env:SYNC_RC) { $c = [int]$env:SYNC_RC }
exit $c
'@

    # Harness: the two installer blocks, then MODE (step5 / step3 PATH / logprobe /
    # relaysync), then a last log line and the counters (reaching "END" = the
    # installer went on). The .sh harness's harness.ps1, unchanged.
    WriteLf "$WORK/harness.ps1" @'
param([string]$Repo, [string]$Mode, [string]$ReposPath = "")
. (Join-Path $Repo "scripts/aitools-lib.ps1")
Initialize-Logging "aitools-install"
$text = [IO.File]::ReadAllText((Join-Path $Repo "scripts/aitools-install.ps1"))
$ms = [regex]::Matches($text, '(?ms)^# --- BEGIN install log (?:helpers|override)[^\n]*\n(.*?)^# --- END install log (?:helpers|override) ---')
if ($ms.Count -ne 2) { Write-Output "installer blocks: $($ms.Count), want 2"; exit 3 }
foreach ($m in $ms) { Invoke-Expression $m.Groups[1].Value }
Log "harness start"
switch ($Mode) {
    "step5" { Invoke-ConfigWriter $env:WRITER @{ ReposPath = "/x/repos"; RepoPath = "/x/repos/aitools" } }
    "step3" { $p = Resolve-ReposDir $ReposPath; if ($p) { Write-Output "REPOS=$p" } else { Write-Output "REPOS_FAILED" } }
    "logprobe" {
        # LOCK_LOG=1: this process holds deploy.log open with no sharing while the
        # probe logs (Windows enforces the share mode per handle, so the installer's
        # write fails as it would against another process's lock)
        $hold = $null
        if ($env:LOCK_LOG -eq "1") { $hold = [IO.File]::Open($logFile, 'OpenOrCreate', 'ReadWrite', 'None') }
        $ErrorActionPreference = "Stop"
        try { LogWarn "probe-warn"; LogError "probe-error"; Write-Output "PROBE-DONE" }
        catch { Write-Output "CAUGHT: $($_.Exception.Message)" }
        finally { $ErrorActionPreference = "Continue"; if ($hold) { $hold.Dispose() } }
    }
    "relaysync" {
        $rc = Invoke-RelaySync "pwsh" @("-NoProfile", "-NonInteractive", "-File", $env:SYNC)
        Write-Output "SYNC-RC=$rc"
    }
}
Log "harness end"
Write-Output "END errors=$($script:errors) warnings=$($script:warnings)"
'@

    # Get-CaseEnv: the variables of every child run. The AITOOLS_* variables
    # aitools-lib.ps1 and the installer blocks read (other than the ones set here) are
    # removed ($null), so a developer shell that sets one (AITOOLS_RUN_ID above all:
    # step5-runid needs the installer block to set it) cannot change a result; the Git
    # Bash harness inherited them, and CI sets none of them. MSYS_NO_PATHCONV and
    # MSYS2_ARG_CONV_EXCL are gone: no MSYS layer sits between this pwsh and its child.
    function Get-CaseEnv {
        $e = @{}
        foreach ($k in @("AITOOLS_ENVIRONMENT", "AITOOLS_RUN_ID", "AITOOLS_DRY_RUN", "AITOOLS_FORCE",
                "AITOOLS_PRESERVE_SUMMARY", "AITOOLS_PROFILE_PS1", "AITOOLS_USER_REPO_PATH",
                "AITOOLS_SYNC_DEPLOY_LOG", "AITOOLS_SUPPRESS_SUMMARY_DISPLAY")) { $e[$k] = $null }
        $e["HOME"] = $H; $e["USERPROFILE"] = $H
        $e["AITOOLS_LOG_DIR"] = "$H/.aitools/logs"; $e["AITOOLS_SUMMARY_FILE"] = "$H/summary.txt"
        $e["WRITER"] = "$NWORK/writer.ps1"; $e["WRITER_MODE"] = "quiet"
        $e["SYNC"] = "$NWORK/sync.ps1"; $e["SYNC_MARK"] = "$H/sync.mark"; $e["SYNC_RC"] = "0"; $e["LOCK_LOG"] = "0"
        return $e
    }

    # run_h MODE [PATH] [VARS] -- run the harness in a child pwsh from $H (stdin at EOF,
    # stdout and stderr to $WORK/out.txt); VARS overrides WRITER_MODE / SYNC_RC /
    # LOCK_LOG. Sets $script:RC, $script:OUT (console, colour codes and CRs removed)
    # and $script:SUM (the summary rows, CRs and trailing newlines removed, as the
    # .sh's $(...) gave them). -ReposPath is passed only with a PATH: the .sh passed
    # an empty value, which is the parameter's default.
    function run_h([string]$Mode, [string]$PathArg = "", [hashtable]$Vars = @{}) {
        $script:RC = 0
        WriteText "$H/summary.txt" ""
        $envs = Get-CaseEnv
        foreach ($k in @($Vars.Keys)) { $envs[$k] = $Vars[$k] }
        $argv = @("-NoProfile", "-NonInteractive", "-File", "$NWORK/harness.ps1", "-Repo", $REPO, "-Mode", $Mode)
        if ($PathArg) { $argv += @("-ReposPath", $PathArg) }
        $script:RC = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile "$WORK/out.txt" -WorkingDirectory $H
        WriteText "$WORK/out.txt" (Strip (ReadText "$WORK/out.txt"))
        $script:OUT = "$WORK/out.txt"
        $script:SUM = ((ReadText "$H/summary.txt") -replace "`r", "").TrimEnd("`n")
    }
    function fresh {
        if (Test-Path -LiteralPath $H) { Remove-Item -LiteralPath $H -Recurse -Force }
        New-Item -ItemType Directory -Path "$H/.aitools/logs" -Force | Out-Null
    }
    function OutLines { @((ReadText $script:OUT) -split "`n") }
    function want_end([string]$Name, [string]$Want) {  # want_end NAME "errors=E warnings=W"
        $got = @(OutLines | ForEach-Object { $m = [regex]::Match($_, '^END (errors=\d+ warnings=\d+)'); if ($m.Success) { $m.Groups[1].Value } }) -join "`n"
        if ($script:RC -eq 0 -and $got -ceq $Want) { ok "${Name}: reached the end, $Want" }
        else { bad "${Name}: rc=$($script:RC) end '$got', want '$Want'"; Show-Indented (ReadText $script:OUT) }
    }
    function want_sum([string]$Name, [string]$Want) {
        if ($script:SUM -ceq $Want) { ok "${Name}: summary rows" }
        else { bad "${Name}: summary '$($script:SUM)', want '$Want'" }
    }
    function want_out([string]$Name, [string]$Text) {
        if (@(OutLines | Where-Object { $_.Contains($Text) }).Count -gt 0) { ok "${Name}: console has '$Text'" }
        else { bad "${Name}: console lacks '$Text'"; Show-Indented (ReadText $script:OUT) }
    }
    function count_out([string]$Name, [string]$Text, [int]$Want) {
        $n = @(OutLines | Where-Object { $_.Contains($Text) }).Count
        if ($n -eq $Want) { ok "${Name}: '$Text' $Want time(s)" }
        else { bad "${Name}: '$Text' $n time(s), want $Want"; Show-Indented (ReadText $script:OUT) }
    }
    function want_no_out([string]$Name, [string]$Re) {  # no console line matches (case-sensitive, as perl)
        if (@(OutLines | Where-Object { $_ -cmatch $Re }).Count -gt 0) { bad "${Name}: console matches /$Re/"; Show-Indented (ReadText $script:OUT) }
        else { ok "${Name}: console has no /$Re/" }
    }
    function log_has([string]$Name, [string]$Text) {  # deploy.log (a file) contains TEXT
        $f = "$H/.aitools/logs/deploy.log"
        if ((Test-Path -LiteralPath $f -PathType Leaf) -and @(((ReadText $f) -split "`n") | Where-Object { $_.Contains($Text) }).Count -gt 0) { ok "${Name}: deploy.log has '$Text'" }
        else { bad "${Name}: deploy.log lacks '$Text'" }
    }
    # Fail-safe log probe (incident #174): the run went on, both console lines printed,
    # both counters counted, no catch and no write error on the console
    function want_probe([string]$Name) {
        want_end $Name "errors=1 warnings=1"
        want_out $Name "PROBE-DONE"
        want_out $Name "[aitools-install] [warn] probe-warn"
        want_out $Name "[aitools-install] [error] probe-error"
        want_no_out $Name 'CAUGHT|Exception|Add-Content|tee:|Is a directory|Permission denied|cannot access|being used by another process'
    }
    # The sync ran (marker), returned WANT_RC, and the installer went on
    function want_sync([string]$Name, [string]$WantRc) {
        want_end $Name "errors=0 warnings=0"
        want_out $Name "SYNC-RC=$WantRc"
        if (Test-Path -LiteralPath "$H/sync.mark" -PathType Leaf) { ok "${Name}: the sync ran" } else { bad "${Name}: the sync did not run" }
        want_no_out $Name 'Exception|Add-Content|Is a directory|Permission denied|cannot access'
    }

    # Get-JsonlLines PATH -- the lines of a deploy.jsonl as the .sh's perl read them
    # (<:raw, chomp): split on LF, no empty piece after a final LF; $null when PATH is
    # not a file. Each line is decoded as strict UTF-8 later (a bad byte = invalid).
    function Get-JsonlLines([string]$Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
        $bytes = [IO.File]::ReadAllBytes($Path)
        $lines = [System.Collections.Generic.List[byte[]]]::new()
        $start = 0
        for ($i = 0; $i -le $bytes.Length; $i++) {
            if ($i -lt $bytes.Length -and $bytes[$i] -ne 10) { continue }
            if ($i -eq $bytes.Length -and $start -eq $i) { break }   # no piece after a final LF
            $seg = [byte[]]::new($i - $start)
            [Array]::Copy($bytes, $start, $seg, 0, $i - $start)
            $lines.Add($seg)
            $start = $i + 1
        }
        return , $lines
    }
    # ConvertFrom-JsonlLine BYTES -- a hashtable of the record's top-level members
    # (strings as their value, others as raw JSON), parsed strictly (RFC 8259:
    # System.Text.Json, as perl JSON::PP decode; ConvertFrom-Json would accept raw
    # control characters); throws when the line is not a valid JSON object.
    $script:Utf8Strict = [Text.UTF8Encoding]::new($false, $true)
    function ConvertFrom-JsonlLine([byte[]]$Bytes) {
        $doc = [System.Text.Json.JsonDocument]::Parse($script:Utf8Strict.GetString($Bytes))
        try {
            if ($doc.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw "not a JSON object" }
            $rec = @{}
            foreach ($p in $doc.RootElement.EnumerateObject()) {
                $rec[$p.Name] = if ($p.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::String) { $p.Value.GetString() } else { $p.Value.GetRawText() }
            }
            return $rec
        } finally { $doc.Dispose() }
    }
    # jsonl_check FILE -- the .sh's jsonl-check.pl: every line valid JSON; returns
    # "records=N invalid=M runids=K child=C childwarn=W" (C: setup-user-config
    # records, W: its "stub warning" warn records); "records=0 (no file)" without one
    function jsonl_check([string]$Path) {
        $lines = Get-JsonlLines $Path
        if ($null -eq $lines) { return "records=0 (no file)" }
        $n = 0; $bad = 0; $c = 0; $w = 0
        $run = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($b in $lines) {
            $n++
            try { $o = ConvertFrom-JsonlLine $b } catch { $bad++; continue }
            [void]$run.Add([string]$o["run_id"])
            if ([string]$o["script"] -ceq "setup-user-config") {
                $c++
                if ([string]$o["level"] -ceq "warn" -and [string]$o["msg"] -ceq "stub warning") { $w++ }
            }
        }
        return "records=$n invalid=$bad runids=$($run.Count) child=$c childwarn=$w"
    }
    # runid_check FILE -- the .sh's inline perl: "same" when every record has one
    # run_id and the child logged that id (not "unset"); else "ids=... child=...".
    # A line that is not valid JSON made the perl die (no output); here it is named.
    function runid_check([string]$Path) {
        $lines = Get-JsonlLines $Path
        if ($null -eq $lines) { return "no file" }
        $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $child = ""; $i = 0
        foreach ($b in $lines) {
            $i++
            try { $o = ConvertFrom-JsonlLine $b } catch { return "invalid line ${i}: $($_.Exception.Message)" }
            [void]$ids.Add([string]$o["run_id"])
            $m = [regex]::Match([string]$o["msg"], '^run id (\S+)$')
            if ($m.Success) { $child = $m.Groups[1].Value }
        }
        $k = @($ids)
        if ($k.Count -eq 1 -and $child -ne "" -and $child -ne "unset" -and $k[0] -ceq $child) { return "same" }
        return "ids=$($k -join ' ') child=$child"
    }

    $impl = "ps"
    Write-Output "installer Step 3 / Step 5 on the lib relay (windows: $impl)"

    # A-1: a writer warning is counted, its lines reach deploy.jsonl and the console
    fresh; run_h step5 -Vars @{ WRITER_MODE = "warn" }
    want_end "step5-warn ($impl)" "errors=0 warnings=1"
    want_sum "step5-warn ($impl)" "OK|aitools config|stub"
    want_out "step5-warn ($impl)" "[setup-user-config] [warn] stub warning"
    $got = jsonl_check "$H/.aitools/logs/deploy.jsonl"
    # harness start + end (installer) and the writer's three lines (info, warn, footer)
    if ($got -ceq "records=5 invalid=0 runids=1 child=3 childwarn=1") { ok "step5-warn ($impl): deploy.jsonl ($got)" }
    else { bad "step5-warn ($impl): deploy.jsonl '$got', want records=5 invalid=0 runids=1 child=3 childwarn=1" }

    # Review B m-4: the installer exports one AITOOLS_RUN_ID; the child sees it and
    # every record (the installer's and the relayed child's) carries it
    fresh; run_h step5 -Vars @{ WRITER_MODE = "runid" }
    $got = runid_check "$H/.aitools/logs/deploy.jsonl"
    if ($got -ceq "same") { ok "step5-runid ($impl): the child's AITOOLS_RUN_ID is every record's run_id" }
    else { bad "step5-runid ($impl): $got" }

    # A-18 / A-3: a writer that dies without a row gets the relay's ERROR row
    fresh; run_h step5 -Vars @{ WRITER_MODE = "crash" }
    want_end "step5-crash ($impl)" "errors=1 warnings=1"
    want_sum "step5-crash ($impl)" "ERROR|aitools config|script failed (exit 1)"
    want_out "step5-crash ($impl)" "Step 5: setup-user-config"

    # ... and a writer that wrote its own ERROR row gets no second one
    fresh; run_h step5 -Vars @{ WRITER_MODE = "ownrow" }
    want_end "step5-ownrow ($impl)" "errors=1 warnings=0"
    want_sum "step5-ownrow ($impl)" "ERROR|aitools config|stub failed"

    # A-16: deploy.jsonl cannot be written (a directory in its place): one warning,
    # the installer goes on, the writer still runs
    fresh; New-Item -ItemType Directory -Path "$H/.aitools/logs/deploy.jsonl" -Force | Out-Null
    run_h step5 -Vars @{ WRITER_MODE = "warn" }
    want_end "jsonl-blocked ($impl)" "errors=0 warnings=2"
    count_out "jsonl-blocked ($impl)" "deploy.jsonl: cannot write" 1
    want_out "jsonl-blocked ($impl)" "[aitools-install] [info] harness end"
    want_sum "jsonl-blocked ($impl)" "OK|aitools config|stub"

    # A-17: Step 3. A relative path is made absolute (relative to the current
    # directory, $H) and created. pwsh prints a Windows path (C:\...\home\repos);
    # separators and letter case are not significant on Windows. The Git Bash
    # harness mapped it back to its own spelling of the temp root (/tmp/...) first,
    # so the path in this check's name differs from its CI line.
    fresh; run_h step3 "repos"
    $got = @(OutLines | ForEach-Object { $m = [regex]::Match($_, '^REPOS=(.*)$'); if ($m.Success) { $m.Groups[1].Value } }) -join "`n"
    $gotN = ($got -replace '\\', '/').ToLowerInvariant()
    if ($gotN -ceq "$H/repos".ToLowerInvariant()) { ok "step3-relative ($impl): $got" }
    elseif ((Test-Path -LiteralPath "$H/repos" -PathType Container) -and $got -match '^[A-Za-z]:[\\/].*[\\/]home[\\/]repos$') {
        # pwsh printed the temp root in another spelling (8.3 short name or long name)
        ok "step3-relative ($impl): $got (absolute, created)"
    }
    else { bad "step3-relative ($impl): '$got', want $H/repos"; Show-Indented (ReadText $script:OUT) }
    want_sum "step3-relative ($impl)" ""
    # a path that cannot be created (under a file): one error, one row
    fresh; WriteText "$H/afile" "x`n"
    run_h step3 "$H/afile/repos"
    want_out "step3-uncreatable ($impl)" "REPOS_FAILED"
    want_end "step3-uncreatable ($impl)" "errors=1 warnings=0"
    want_sum "step3-uncreatable ($impl)" "ERROR|aitools config|repos dir not created"

    # Incident #174: the log override's deploy.log write is fail-safe. A writable
    # deploy.log still gets the lines ...
    fresh; run_h logprobe
    want_probe "log-written ($impl)"
    log_has "log-written ($impl)" "[aitools-install] [warn] probe-warn"
    log_has "log-written ($impl)" "[aitools-install] [error] probe-error"
    # ... and one that cannot be written (a directory in its place) ends nothing
    fresh; New-Item -ItemType Directory -Path "$H/.aitools/logs/deploy.log" -Force | Out-Null
    run_h logprobe
    want_probe "log-blocked ($impl)"

    # Step 22 relay sync: its output (stdout and stderr) reaches deploy.log ...
    fresh; run_h relaysync
    want_sync "relaysync-ok ($impl)" 0
    log_has "relaysync-ok ($impl)" "sync-out-line"
    log_has "relaysync-ok ($impl)" "sync-err-line"
    # ... its exit code comes back ...
    fresh; run_h relaysync -Vars @{ SYNC_RC = "3" }
    want_sync "relaysync-rc ($impl)" 3
    # ... and a deploy.log that cannot be written neither skips it nor ends the run
    fresh; New-Item -ItemType Directory -Path "$H/.aitools/logs/deploy.log" -Force | Out-Null
    run_h relaysync
    want_sync "relaysync-blocked ($impl)" 0

    # Incident #174, bash: deploy.log without write permission (mode 000) is a case of
    # the bash installer (macOS/Linux, tests/profile/test-install.sh)
    skip "log-unwritable (bash installer only: macOS/Linux)"

    # Incident #174, PowerShell: deploy.log held open with no sharing (a lock) while
    # the probe logs under $ErrorActionPreference = "Stop" inside a try
    fresh; run_h logprobe -Vars @{ LOCK_LOG = "1" }
    want_probe "log-locked ($impl)"
    if ((ReadText "$H/.aitools/logs/deploy.log").Contains("probe-warn")) { bad "log-locked ($impl): the lock did not hold (probe line in deploy.log)" }
    else { ok "log-locked ($impl): nothing written while the lock held" }

    # A-17, bash: a relative path that exists but cannot be entered is not resolved.
    # PowerShell resolves it with GetFullPath, which does not enter the directory.
    skip "step3-unresolvable (bash installer only: macOS/Linux)"

    # M5-Fixes item 10: the bash Step 3 prompt (prompt_repos_path) on a
    # pseudo-terminal is a case of the bash installer (macOS/Linux)
    skip "step3-prompt (bash installer only: macOS/Linux)"
} finally {
    Remove-TestTempRoot $WORK
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: ps)" -f $script:PASS, $script:FAIL, $script:SKIP)
if ($script:FAIL -ne 0) { exit 1 }
exit 0
