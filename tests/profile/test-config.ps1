# test-config.ps1 -- tests for scripts/setup-user-config.ps1 (the config.json
# writer) and the installer Step 3/5 helpers (the "install log helpers" block of
# scripts/aitools-install.ps1). The Windows harness of this suite;
# tests/profile/test-config.sh is the macOS/Linux harness of the same cases for
# setup-user-config.sh and the aitools-install.sh block.
#
# Each case builds an isolated HOME (fake dotprofile + config.json) and runs the
# writer in a child pwsh with an injected machine id and hostname
# (AITOOLS_PROFILE_TEST_MACHINE_ID / _HOSTNAME). Asserts exit codes, the written
# config.json and the summary rows.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .ps1 writer and helper block with native pwsh on
# Windows only. Paths handed to the writer are in the mixed form (C:/...),
# long (no 8.3 component), as the earlier Git Bash harness passed them. Parity
# with the .sh writer is checked against the committed golden results, one per
# case: exit code, summary rows and config.json (temp root as <TMP>, path
# separators as /), tests/profile/golden/config-*.txt (Test-GoldenMatch in
# tests/lib/platform-lib.ps1). No NAME.windows golden is needed.
#
# Safe to re-run: every case runs in a child pwsh under a temp HOME (HOME and
# USERPROFILE; removed on exit); the real HOME is never read or written. Exit 1
# on failure.
#
# Usage: pwsh -NoProfile -File tests/profile/test-config.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 26 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/profile/test-config.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$Writer = Join-Path $root "scripts/setup-user-config.ps1"
$WORK = New-TestTempRoot "test-config"
$GoldenDir = Join-Path $root "tests/profile/golden"
$GoldenTmp = $WORK
$L = "ps1"

$script:PASS = 0; $script:FAIL = 0; $script:SKIP = 0
function ok([string]$Name) { $script:PASS++; Write-Output "  ok   $Name" }
function bad([string]$Name) { $script:FAIL++; Write-Output "  FAIL $Name" }
function skip([string]$Text) { $script:SKIP++; Write-Output "  skip $Text" }
# Show-Indented TEXT: TEXT with every line indented by 7 spaces (the .sh's perl -pe 's/^/       /')
function Show-Indented([string]$Text) {
    $lines = @($Text -split "`n")
    if ($lines.Count -gt 0 -and $lines[-1] -eq "") { $lines = @($lines | Select-Object -SkipLast 1) }
    foreach ($ln in $lines) { Write-Output "       $ln" }
}
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text) }

$ID_MAC = "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"   # as macOS reports it (upper case)
$KEY_MAC = "3d4df2a5-7d91-5af9-9944-4feebaae3cf5"  # the profiles key (lower-cased id)
# NWORK: the temp root as the writer reads it, in the mixed form (C:/...): the form
# the Git Bash harness passed (cygpath -m -l), so fixtures and arguments are the
# same bytes as before. New-TestTempRoot already returns the long form (no 8.3
# RUNNER~1 component; PR #139 run 41265193554 saw one directory under two names).
$NWORK = $WORK -replace '\\', '/'
# H / DP: the case HOME and the dotprofile in it. Every path written into a
# fixture or passed as an argument uses them.
$H = "$NWORK/home"
$DP = "$H/repos/aitools-nobul-jose"
$CFG = "$H/.aitools/config.json"
$script:CaseEnv = @{}

# Get-BaseEnv: the variables of every child run. The AITOOLS_* variables the writer,
# aitools-lib.ps1 and aitools-profile.ps1 read are removed ($null), so a developer
# shell that sets one cannot change a result; the earlier harness inherited them,
# and CI sets none of them. A case adds its own on top ($script:CaseEnv).
function Get-BaseEnv {
    $e = @{}
    foreach ($k in @("AITOOLS_ENVIRONMENT", "AITOOLS_USER_REPO_PATH", "AITOOLS_MACHINE_ALIAS", "AITOOLS_PROFILE_FILE",
            "AITOOLS_PROFILE_PS1", "AITOOLS_DRY_RUN", "AITOOLS_FORCE", "AITOOLS_RUN_ID", "AITOOLS_SUMMARY_FILE",
            "AITOOLS_PRESERVE_SUMMARY", "AITOOLS_TEST_UPDATE_GOLDEN")) { $e[$k] = $null }
    $e["HOME"] = $H; $e["USERPROFILE"] = $H
    $e["AITOOLS_LOG_DIR"] = "$H/.aitools/logs"
    return $e
}

# write_profile KEY ALIAS_LINE ID HOSTNAME -- profile.json, revision 2.2 shape: this
# machine's profile under KEY, plus "laptop", an unclaimed 2.1 entry (alias-keyed, no
# machine.id). ALIAS_LINE is the entry's "alias" line ("" = none); ID "" = no
# machine.id. The same bytes as the .sh harness's here-document.
function write_profile([string]$Key, [string]$AliasLine, [string]$Id, [string]$Hn) {
    $idLine = ""
    if ($Id) { $idLine = "`"id`": `"$Id`"," }
    New-Item -ItemType Directory -Path $DP -Force | Out-Null
    $lines = @(
        '{',
        '  "version": 2,',
        '  "meta": { "schemaRevision": "2.2" },',
        '  "identity": {',
        '    "github": "nobul-jose",',
        '    "name": "Jose",',
        '    "company": "nobul-tech",',
        '    "git": {',
        '      "name": "Jose",',
        '      "email": "jose@nobul.tech"',
        '    }',
        '  },',
        '  "profiles": {',
        "    `"$Key`": {",
        "      $AliasLine",
        '      "machine": {',
        "        $idLine",
        "        `"hostname`": `"$Hn`"",
        '      }',
        '    },',
        '    "laptop": {',
        '      "company": "Nobul",',
        '      "machine": {',
        '        "hostname": "Joses-MBP"',
        '      }',
        '    }',
        '  }',
        '}'
    )
    WriteText "$DP/profile.json" (($lines -join "`n") + "`n")
}
# profile_with_id -- this machine registered under its id (revision 2.2)
function profile_with_id { write_profile $KEY_MAC '"alias": "nobul-mac",' $KEY_MAC "nobul-mac" }
# profile_legacy -- the same machine, still keyed by alias (revision 2.1): the
# resolver matches it by machine.id and advises migrate
function profile_legacy { write_profile "nobul-mac" "" $ID_MAC "nobul-mac" }

function reset_home {
    if (Test-Path -LiteralPath $H) { Remove-Item -LiteralPath $H -Recurse -Force }
    New-Item -ItemType Directory -Path "$H/repos", "$H/.aitools" -Force | Out-Null
}

# Invoke-Writer ARGS -- run setup-user-config.ps1 in a child pwsh (stdin at EOF);
# sets $script:RC; summary rows in $H/summary.txt, console output in $WORK/out.txt.
function Invoke-Writer([string[]]$WArgs) {
    WriteText "$H/summary.txt" ""
    $envs = Get-BaseEnv
    $envs["AITOOLS_SUMMARY_FILE"] = "$H/summary.txt"
    $envs["AITOOLS_PROFILE_TEST_MACHINE_ID"] = $ID_MAC
    $envs["AITOOLS_PROFILE_TEST_HOSTNAME"] = "nobul-mac"
    foreach ($k in @($script:CaseEnv.Keys)) { $envs[$k] = $script:CaseEnv[$k] }
    $argv = @("-NoProfile", "-NonInteractive", "-File", $Writer) + @($WArgs)
    $script:RC = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile "$WORK/out.txt"
}

# norm_json FILE -- config.json as compared: CR removed, JSON-escaped backslashes
# (Windows path separators, "C:\\Users\\...") turned into slashes, and NWORK (letter
# case ignored) replaced by <TMP>. The .sh harness's norm_json, unchanged.
function norm_json([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    $t = $t.Replace('\\', '/')
    return [regex]::Replace($t, [regex]::Escape($NWORK), '<TMP>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

# case_run NAME RC SETUP [ARGS...] -- SETUP (a function name) builds the fixture;
# one writer run. RAWJ: config.json as written (empty file = none); OUTJ: normalized
# (norm_json); SUMM: summary rows; OUT: console output (CR and colours removed). The
# result (exit code, rows, config.json) must equal the golden file config-NAME.txt.
function case_run([string]$Name, [int]$Want, [string]$Setup, [string[]]$WArgs = @()) {
    $script:CASE = $Name
    & $Setup
    Invoke-Writer $WArgs
    $script:RAWJ = "$WORK/$Name.json"; $script:OUTJ = "$WORK/$Name.njson"; $script:SUMM = "$WORK/$Name.summary"; $script:OUT = "$WORK/$Name.out"
    if (Test-Path -LiteralPath $CFG -PathType Leaf) { Copy-Item -LiteralPath $CFG -Destination $script:RAWJ -Force }
    else { WriteText $script:RAWJ "" }   # no config = empty copy (asserted by the cases)
    WriteText $script:OUTJ (norm_json $script:RAWJ)
    WriteText $script:SUMM ((ReadText "$H/summary.txt") -replace "`r", "")
    WriteText $script:OUT (Strip (ReadText "$WORK/out.txt"))
    if ($script:RC -eq $Want) { ok "${Name}: $L exit $($script:RC)" }
    else { bad "${Name}: $L exit $($script:RC), want $Want"; Show-Indented (ReadText $script:OUT) }
    WriteText "$WORK/$Name.result" ("exit $($script:RC)`n-- summary rows`n" + (ReadText $script:SUMM) + "-- config.json`n" + (ReadText $script:OUTJ))
    if (Test-GoldenMatch "config-$Name.txt" "$WORK/$Name.result") { ok "${Name}: exit, rows and config.json match golden (sh and ps1 share it)" }
    else { bad "${Name}: result differs from golden config-$Name.txt" }
}
function SummLines { @((ReadText $script:SUMM) -split "`n") }
# has_json REGEX -- the written config (normalized) matches (whole file; . matches
# newline, as perl -0777 /s)
function has_json([string]$Re) {
    if ([regex]::IsMatch((ReadText $script:OUTJ), $Re, [Text.RegularExpressions.RegexOptions]::Singleline)) { ok "$($script:CASE): config /$Re/" }
    else { bad "$($script:CASE): config lacks /$Re/"; Show-Indented (ReadText $script:OUTJ) }
}
# has_row LINE -- the summary has this exact row
function has_row([string]$Row) {
    if (@(SummLines) -ccontains $Row) { ok "$($script:CASE): row $Row" }
    else { bad "$($script:CASE): no row '$Row'"; Show-Indented (ReadText $script:SUMM) }
}
function no_row_like([string]$Re) {
    if (@(SummLines | Where-Object { $_ -cmatch $Re }).Count -gt 0) { bad "$($script:CASE): unexpected row /$Re/"; Show-Indented (ReadText $script:SUMM) }
    else { ok "$($script:CASE): no row /$Re/" }
}
# no_json REGEX -- the written config (normalized) does not match
function no_json([string]$Re) {
    if (-not [regex]::IsMatch((ReadText $script:OUTJ), $Re, [Text.RegularExpressions.RegexOptions]::Singleline)) { ok "$($script:CASE): config has no /$Re/" }
    else { bad "$($script:CASE): config has /$Re/"; Show-Indented (ReadText $script:OUTJ) }
}
# rows_n N PREFIX -- the summary has exactly N rows starting with PREFIX
function rows_n([int]$Want, [string]$Prefix) {
    $cnt = @(SummLines | Where-Object { $_ -cmatch "^$Prefix" }).Count
    if ($cnt -eq $Want) { ok "$($script:CASE): $Want row(s) $Prefix" }
    else { bad "$($script:CASE): $cnt row(s) $Prefix, want $Want"; Show-Indented (ReadText $script:SUMM) }
}
# out_has TEXT -- the writer's console output contains TEXT
function out_has([string]$Text) {
    if ((ReadText $script:OUT).Contains($Text)) { ok "$($script:CASE): $L output has '$Text'" }
    else { bad "$($script:CASE): $L output lacks '$Text'"; Show-Indented (ReadText $script:OUT) }
}
# log_has TEXT -- deploy.log (of the last writer run) contains TEXT
function log_has([string]$Text) {
    if ((ReadText "$H/.aitools/logs/deploy.log").Contains($Text)) { ok "$($script:CASE): deploy.log has '$Text'" }
    else { bad "$($script:CASE): deploy.log lacks '$Text'" }
}
function SameFile([string]$A, [string]$B) {
    (Test-Path -LiteralPath $A -PathType Leaf) -and (Test-Path -LiteralPath $B -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $A).Hash -ceq (Get-FileHash -LiteralPath $B).Hash)
}
# AitoolsDirHas REGEX -- a name in $H/.aitools matches (the .sh's ls | grep -q)
function AitoolsDirHas([string]$Re) { @(Get-ChildItem -LiteralPath "$H/.aitools" -Force -Name | Where-Object { $_ -match $Re }).Count -gt 0 }

try {
    Write-Output "setup-user-config tests (windows: $L writer)"
    $BOOT = @("-ReposPath", "$H/repos", "-RepoPath", "$H/repos/aitools")

    # C1 fresh machine with a dotprofile: created, derived values, meta
    function fix_fresh { reset_home; profile_with_id }
    case_run c1-fresh 0 fix_fresh ($BOOT + @("-GithubUser", "nobul-jose"))
    has_row "OK|aitools config|created"
    has_json ('\A\{\n  "version": 3,\n  "reposPath": "[^"]+\/repos",\n  "repoPath": "[^"]+\/repos\/aitools",\n  "googleDrives": \[\],\n  "githubUser": "nobul-jose",\n  "userRepoPath": "[^"]+\/aitools-nobul-jose",\n  "machineId": "' + $KEY_MAC + '",\n  "machineAlias": "nobul-mac",\n  "meta": \{\n    "intent": \{\n      "purpose": "Per-machine pointers')
    has_json '"writer": "setup-user-config",\n    "derivedFrom": "profile.json"\n  \}\n\}\n\z'
    rows_n 0 "ACTION"

    # C2 re-run on the result: verified, no write
    function fix_rerun { fix_fresh; Copy-Item -LiteralPath "$WORK/c1-fresh.json" -Destination $CFG -Force }
    case_run c2-verified 0 fix_rerun
    has_row "OK|aitools config|verified"
    if (SameFile $RAWJ "$WORK/c1-fresh.json") { ok "c2-verified: file unchanged" } else { bad "c2-verified: file changed" }
    if (AitoolsDirHas 'config.json.bak') { bad "c2-verified: a backup was written" } else { ok "c2-verified: no backup (no write)" }

    # C3 existing v2 config: extra keys kept in place, stale alias re-derived, version 3
    function fix_v2 {
        reset_home; profile_with_id
        WriteText $CFG ((@(
                '{',
                '  "version": 2,',
                "  `"reposPath`": `"$H/repos`",",
                "  `"repoPath`": `"$H/repos/aitools`",",
                '  "custom": { "keep": true },',
                '  "googleDrives": [ { "path": "/gd", "account": "a@b.c", "label": "" } ],',
                "  `"userRepoPath`": `"$DP`",",
                '  "machineAlias": "new-mac"',
                '}'
            ) -join "`n") + "`n")
    }
    case_run c3-upgrade 0 fix_v2
    has_row "OK|aitools config|updated"
    has_row "DETAIL|aitools config|version updated"
    has_row "DETAIL|aitools config|machineAlias updated"
    has_row "DETAIL|aitools config|machineId updated"
    has_json '"custom": \{\n    "keep": true\n  \},\n  "googleDrives": \[\n    \{\n      "path": "\/gd"'
    has_json ('"machineAlias": "nobul-mac",\n  "githubUser": "nobul-jose",\n  "machineId": "' + $KEY_MAC + '",\n  "meta"')
    if (AitoolsDirHas 'config.json.bak') { ok "c3-upgrade: backup written" } else { bad "c3-upgrade: no backup" }

    # C4 corrupt config: rebuilt with salvaged keys, WARN
    function fix_corrupt {
        reset_home; profile_with_id
        WriteText $CFG ('{ "reposPath": "' + "$H/repos" + '", "repoPath": "' + "$H/repos/aitools" + '", "machineAlias": "laptop", oops' + "`n")
    }
    case_run c4-corrupt 0 fix_corrupt
    has_row "WARN|aitools config|rebuilt (was invalid)"
    has_json '\A\{\n  "reposPath": "[^"]+",\n  "repoPath": "[^"]+",\n  "machineAlias": "nobul-mac",\n  "version": 3'
    has_json ('"machineId": "' + $KEY_MAC + '"')

    # C5 no dotprofile: bootstrap keys only, githubUser from the argument
    function fix_nodp { reset_home }
    case_run c5-no-dotprofile 0 fix_nodp ($BOOT + @("-GithubUser", "someone"))
    has_row "OK|aitools config|created"
    has_json '"githubUser": "someone",\n  "meta"'
    has_json '"derivedFrom": "bootstrap only"'

    # C6 missing bootstrap values: error, nothing written
    case_run c6-no-bootstrap 1 fix_nodp
    has_row "ERROR|aitools config|missing bootstrap values"
    if ((Get-Item -LiteralPath $RAWJ).Length -eq 0) { ok "c6-no-bootstrap: no config written" } else { bad "c6-no-bootstrap: config written" }

    # C7 no machine match: ERROR + ACTION, existing alias kept
    $KEY_OTHER = "aaaaaaaa-1111-2222-3333-444444444444"
    function fix_nomatch {
        fix_v2
        write_profile $KEY_OTHER '"alias": "nobul-mac",' $KEY_OTHER "elsewhere"
    }
    case_run c7-no-match 1 fix_nomatch
    has_row "ERROR|machine profile|no machine match"
    has_row "ACTION||Run: aitools user init (profiles: nobul-mac, laptop)"
    rows_n 1 "ACTION"
    has_json '"machineAlias": "new-mac"'
    no_json '"machineId"'

    # C8 dry run: nothing written
    case_run c8-dry-run 0 fix_v2 @("-DryRun")
    has_row "OK|aitools config|dry-run: would update"
    if ((ReadText $RAWJ).Contains('"version": 2')) { ok "c8-dry-run: config untouched" } else { bad "c8-dry-run: config changed" }

    # C8b dry run writes nothing under ~/.aitools, not even a temp file. The .sh
    # harness makes ~/.aitools read-only with chmod 555; Windows has no counterpart
    # (chmod in Git Bash did not make the directory read-only either), so the case
    # checks the dry run with a writable directory, as the Git Bash harness did.
    function fix_dry_ro {
        fix_v2
        New-Item -ItemType Directory -Path "$H/.aitools/logs" -Force | Out-Null
    }
    case_run c8b-dry-run-readonly 0 fix_dry_ro @("-DryRun")
    has_row "OK|aitools config|dry-run: would update"
    no_row_like "merge failed"

    # C9 drives: a non-empty array replaces, an empty one keeps
    case_run c9-drives 0 fix_v2 @("-DrivesJson", '[{"path":"/Volumes/GD/My Drive","account":"x@y.z","label":""}]')
    has_json '"googleDrives": \[\n    \{\n      "path": "\/Volumes\/GD\/My Drive",\n      "account": "x\@y.z",\n      "label": ""\n    \}\n  \]'
    case_run c9-drives-empty 0 fix_v2 @("-DrivesJson", '[]')
    has_json '"path": "\/gd"'

    # C10 explicit choice (user init's): -MachineId selects this machine's profile by
    # its key (any case); machineId + display machineAlias are saved
    case_run c10-machine-id 0 fix_v2 @("-MachineId", $ID_MAC)
    has_row "OK|aitools config|updated"
    out_has "machineAlias=nobul-mac via=override"
    has_json '"machineAlias": "nobul-mac"'
    has_json ('"machineId": "' + $KEY_MAC + '"')
    # C10b the deprecated -MachineAlias is still accepted for one release (detail line);
    # the chosen 2.1 profile has no machine.id: advisory, one ACTION, the row stays OK
    case_run c10b-deprecated-alias 0 fix_v2 @("-MachineAlias", "laptop")
    has_json '"machineAlias": "laptop"'
    no_json '"machineId"'
    has_row "OK|aitools config|updated"
    has_row "ACTION||Run: aitools user init (registers this machine)"
    rows_n 1 "ACTION"
    log_has "[detail] deprecated flag:"
    # C10c both flags: bad arguments
    case_run c10c-both-flags 1 fix_v2 @("-MachineId", $ID_MAC, "-MachineAlias", "nobul-mac")
    has_row "ERROR|aitools config|bad arguments"
    # C10d an unknown -MachineId: no machine match, nothing derived is saved
    case_run c10d-unknown-id 1 fix_v2 @("-MachineId", $KEY_OTHER)
    has_row "ERROR|machine profile|no machine match"
    has_json '"machineAlias": "new-mac"'

    # C11 AITOOLS_USER_REPO_PATH: used for the run, not saved
    function fix_v2_cfg_only { WriteText $CFG ('{ "version": 3, "reposPath": "' + "$H/repos" + '", "repoPath": "' + "$H/repos/aitools" + '" }' + "`n") }
    function fix_env { reset_home; profile_with_id; Copy-Item -LiteralPath $DP -Destination "$H/envdp" -Recurse; fix_v2_cfg_only }
    $script:CaseEnv = @{ AITOOLS_USER_REPO_PATH = "$H/envdp" }
    case_run c11-env 0 fix_env
    $script:CaseEnv = @{}
    if ((ReadText $RAWJ).Contains('"userRepoPath"')) { bad "c11-env: userRepoPath saved from the env override" } else { ok "c11-env: userRepoPath not saved" }
    has_json '"machineAlias": "nobul-mac"'

    # C13 cached alias names a 2.1 profile without machine.id (not registered): written;
    # the advice is one ACTION (with its counted warning), the config row stays OK
    function fix_unreg {
        fix_v2
        write_profile "nobul-mac" "" "" "nobul-mac"
        WriteText $CFG ((ReadText $CFG).Replace('"new-mac"', '"nobul-mac"'))
    }
    case_run c13-unregistered 0 fix_unreg
    has_row "OK|aitools config|updated"
    has_row "ACTION||Run: aitools user init (registers this machine)"
    rows_n 1 "ACTION"
    no_json '"machineId"'
    out_has "COMPLETED with 1 warning(s)"

    # C17 legacy 2.1 profile (alias-keyed, matched by machine.id): the resolver's
    # "run: aitools-profile migrate" advice is ONE ACTION naming the user-facing command
    # (aitools user init re-keys), not a WARN row; no machineId (not an id-keyed profile)
    function fix_legacy { reset_home; profile_legacy }
    case_run c17-legacy-migrate 0 fix_legacy $BOOT
    has_row "OK|aitools config|created"
    has_row "ACTION||Run: aitools user init (re-keys machine profiles by machine id)"
    rows_n 1 "ACTION"
    rows_n 0 "WARN"
    has_json '"machineAlias": "nobul-mac"'
    no_json '"machineId"'
    log_has "run: aitools-profile migrate"

    # C18 a real problem (stored hostname differs: renamed, or a clone sharing the id):
    # a counted warning, the row becomes WARN; plus the one ACTION
    function fix_clone { reset_home; write_profile $KEY_MAC '"alias": "nobul-mac",' $KEY_MAC "other-host" }
    case_run c18-real-warning 0 fix_clone $BOOT
    has_row "WARN|aitools config|created"
    has_row "ACTION||Run: aitools user init (updates this machine's profile)"
    rows_n 1 "ACTION"
    out_has "COMPLETED with 2 warning(s)"
    has_json ('"machineId": "' + $KEY_MAC + '"')

    # C19 this machine's id cannot be detected: the cached machineId selects the profile
    # (via=config) and is kept; the undetectable id is a real warning
    function fix_noid { fix_fresh; Copy-Item -LiteralPath "$WORK/c1-fresh.json" -Destination $CFG -Force }
    $script:CaseEnv = @{ AITOOLS_PROFILE_TEST_MACHINE_ID = "none" }
    case_run c19-id-unavailable 0 fix_noid
    $script:CaseEnv = @{}
    has_row "WARN|aitools config|verified"
    if (SameFile $RAWJ "$WORK/c1-fresh.json") { ok "c19-id-unavailable: machineId kept, file unchanged" } else { bad "c19-id-unavailable: file changed" }
    log_has "machineAlias=nobul-mac via=config"

    # C20 a cached machineId that the match does not confirm (2.1 profile matched by
    # machine.id) is removed, so the machineAlias cache (resolver step 4L) stays usable
    function fix_stale_mid {
        reset_home; profile_legacy
        WriteText $CFG ('{ "version": 3, "reposPath": "' + "$H/repos" + '", "repoPath": "' + "$H/repos/aitools" + '", "machineId": "' + $KEY_OTHER + '", "machineAlias": "nobul-mac" }' + "`n")
    }
    case_run c20-stale-machine-id 0 fix_stale_mid
    has_row "OK|aitools config|updated"
    has_row "DETAIL|aitools config|machineId updated"
    no_json '"machineId"'
    has_json '"machineAlias": "nobul-mac"'
    out_has "cached machineId `"$KEY_OTHER`" removed"

    # C21 machineId is salvaged from a corrupt config (the id is undetectable, so no
    # machineId is derived: the salvaged value is the one written)
    function fix_corrupt_mid {
        reset_home; profile_with_id
        WriteText $CFG ('{ "reposPath": "' + "$H/repos" + '", "repoPath": "' + "$H/repos/aitools" + '", "machineId": "' + $KEY_MAC + '", oops' + "`n")
    }
    $script:CaseEnv = @{ AITOOLS_PROFILE_TEST_MACHINE_ID = "none" }
    case_run c21-salvage-machine-id 0 fix_corrupt_mid
    $script:CaseEnv = @{}
    has_row "WARN|aitools config|rebuilt (was invalid)"
    has_json ('"machineId": "' + $KEY_MAC + '"')
    out_has "Recovered machineId from the invalid config"

    # C22 -NoMachine (user init left this machine unregistered): the caller owns machine
    # registration. No profile matches this machine: no ERROR, no ACTION, exit 0; every
    # other field is written; machineId / machineAlias are kept exactly as they were
    $KEY_KEEP = "bbbbbbbb-5555-6666-7777-888888888888"
    function fix_nm_nomatch {
        fix_nomatch
        WriteText $CFG ((ReadText $CFG).Replace('"machineAlias": "new-mac"', "`"machineAlias`": `"new-mac`",`n  `"machineId`": `"$KEY_KEEP`""))
    }
    case_run c22-no-machine-unmatched 0 fix_nm_nomatch @("-NoMachine", "-GithubUser", "nobul-jose")
    has_row "OK|aitools config|updated"
    rows_n 0 "ERROR"
    rows_n 0 "ACTION"
    has_json '"machineAlias": "new-mac"'
    has_json ('"machineId": "' + $KEY_KEEP + '"')
    has_json '"githubUser": "nobul-jose"'
    has_json '"version": 3'
    has_json '"userRepoPath": "[^"]+\/aitools-nobul-jose"'
    out_has "COMPLETED successfully"
    out_has "machine registration is left to the caller"
    log_has "no profile matches this machine"
    log_has ": left to the caller)"  # "(--no-machine: ..." (bash) / "(-NoMachine: ..." (PowerShell)
    # C22b the same fixture without the flag still reports it (C7 behaviour unchanged)
    case_run c22b-unmatched-without-flag 1 fix_nm_nomatch @("-GithubUser", "nobul-jose")
    has_row "ERROR|machine profile|no machine match"
    rows_n 1 "ACTION"
    # C22c profile.json with no machine profiles: unregistered too, nothing reported
    function fix_nm_empty {
        fix_v2
        WriteText "$DP/profile.json" ('{ "version": 2, "meta": { "schemaRevision": "2.2" }, "identity": { "github": "nobul-jose" }, "profiles": {} }' + "`n")
    }
    case_run c22c-no-machine-no-profiles 0 fix_nm_empty @("-NoMachine")
    rows_n 0 "ERROR"
    rows_n 0 "ACTION"
    has_json '"machineAlias": "new-mac"'
    # C22d unregistered 2.1 profile (C13 fixture): the registration ACTION is the caller's
    case_run c22d-no-machine-unregistered 0 fix_unreg @("-NoMachine")
    has_row "OK|aitools config|updated"
    rows_n 0 "ACTION"
    rows_n 0 "WARN"
    no_json '"machineId"'
    has_json '"machineAlias": "nobul-mac"'
    out_has "COMPLETED successfully"
    # C22e a cached machineId the match would remove (C20) is kept with -NoMachine
    case_run c22e-no-machine-keeps-id 0 fix_stale_mid @("-NoMachine")
    rows_n 0 "ACTION"
    no_row_like "machineId updated"
    has_json ('"machineId": "' + $KEY_OTHER + '"')
    has_json '"machineAlias": "nobul-mac"'
    # C22f a legacy alias-keyed profile (C17): no migrate ACTION, machineAlias not written
    case_run c22f-no-machine-legacy 0 fix_legacy ($BOOT + @("-NoMachine"))
    has_row "OK|aitools config|created"
    rows_n 0 "ACTION"
    no_json '"machineAlias"'
    no_json '"machineId"'
    # C22g other derivation errors are still reported: an invalid profile.json
    function fix_nm_badprofile { fix_v2; WriteText "$DP/profile.json" '{ "version": 2, ' }
    case_run c22g-no-machine-bad-profile 1 fix_nm_badprofile @("-NoMachine")
    has_row "ERROR|profile.json|invalid (see log)"
    # C22h -NoMachine with a machine choice: bad arguments, nothing written
    case_run c22h-no-machine-and-id 1 fix_v2 @("-NoMachine", "-MachineId", $ID_MAC)
    has_row "ERROR|aitools config|bad arguments"
    rows_n 1 "ERROR"
    if ((ReadText $RAWJ).Contains('"version": 2')) { ok "c22h-no-machine-and-id: config untouched" } else { bad "c22h-no-machine-and-id: config changed" }
    case_run c22i-no-machine-and-alias 1 fix_v2 @("-MachineAlias", "laptop", "-NoMachine")
    has_row "ERROR|aitools config|bad arguments"
    # C22k an ambiguous match (this machine.id on two profiles) is still an error
    function fix_nm_dupid {
        fix_v2
        WriteText "$DP/profile.json" ('{ "version": 2, "meta": { "schemaRevision": "2.2" }, "identity": { "github": "nobul-jose" }, "profiles": { "a": { "machine": { "id": "' + $ID_MAC + '", "hostname": "nobul-mac" } }, "b": { "machine": { "id": "' + $ID_MAC + '", "hostname": "nobul-mac" } } } }' + "`n")
    }
    case_run c22k-no-machine-ambiguous 1 fix_nm_dupid @("-NoMachine")
    has_row "ERROR|machine profile|no machine match"
    # C22l -NoMachine with -DryRun: nothing written, no machine rows
    case_run c22l-no-machine-dry-run 0 fix_nm_nomatch @("-NoMachine", "-DryRun")
    has_row "OK|aitools config|dry-run: would update"
    rows_n 0 "ERROR"
    rows_n 0 "ACTION"
    if ((ReadText $RAWJ).Contains('"version": 2')) { ok "c22l-no-machine-dry-run: config untouched" } else { bad "c22l-no-machine-dry-run: config changed" }

    # C22j the help text names the flag (-NoMachine)
    $script:CASE = "c22j-help"
    reset_home
    $flag = "-NoMachine"
    $script:RC = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $Writer, "-Help") -Environment (Get-BaseEnv) -OutFile "$WORK/help.out"
    if ($script:RC -eq 0 -and (ReadText "$WORK/help.out").Contains($flag)) { ok "c22j-help: $L help names $flag" }
    else { bad "c22j-help: $L help (exit $($script:RC)) lacks $flag"; Show-Indented (ReadText "$WORK/help.out") }

    # C14 relative bootstrap path: bad arguments, nothing written
    case_run c14-relative 1 fix_nodp @("-ReposPath", "repos", "-RepoPath", "$H/repos/aitools")
    has_row "ERROR|aitools config|bad arguments"
    if ((Get-Item -LiteralPath $RAWJ).Length -eq 0) { ok "c14-relative: no config written" } else { bad "c14-relative: config written" }

    # C15 double slash in a path value: validation failed, existing file untouched
    case_run c15-double-slash 1 fix_v2 @("-ReposPath", "$H/repos//x")
    has_row "ERROR|aitools config|validation failed"
    if ((ReadText $RAWJ).Contains('"version": 2')) { ok "c15-double-slash: config untouched" } else { bad "c15-double-slash: config changed" }

    # C16 invalid profile.json: its own ERROR row, not "no machine match"
    function fix_badprofile { fix_v2; WriteText "$DP/profile.json" '{ "version": 2, ' }
    case_run c16-bad-profile 1 fix_badprofile
    has_row "ERROR|profile.json|invalid (see log)"
    no_row_like "no machine match"
    # Audit A-10: the ACTION's instruction is in a log line that names its row (error level)
    out_has "config: profile.json invalid -- Fix profile.json in the dotprofile (details in deploy.log)"
    log_has "[error] config: profile.json invalid -- Fix profile.json"

    # C23 the resolver's two "unusable profile.json" states (PR #98 review m1): a v1 file
    # ("is not v2") and a v2 file without a profiles object each have their own message,
    # and both are an invalid profile.json, with or without -NoMachine
    function fix_v1profile { fix_v2; WriteText "$DP/profile.json" ('{ "name": "Jose", "machines": [] }' + "`n") }
    case_run c23-v1-profile 1 fix_v1profile
    has_row "ERROR|profile.json|invalid (see log)"
    has_row "ACTION||Fix profile.json in the dotprofile (details in deploy.log)"
    rows_n 1 "ACTION"
    no_row_like "no machine match"
    log_has "config: profile.json is not v2"
    out_has "config: profile.json invalid -- Fix profile.json in the dotprofile (details in deploy.log)"
    has_json '"machineAlias": "new-mac"'
    function fix_noprofiles {
        fix_v2
        WriteText "$DP/profile.json" ('{ "version": 2, "meta": { "schemaRevision": "2.2" }, "identity": { "github": "nobul-jose" } }' + "`n")
    }
    case_run c23b-no-profiles-object 1 fix_noprofiles
    has_row "ERROR|profile.json|invalid (see log)"
    rows_n 1 "ACTION"
    no_row_like "no machine match"
    log_has "config: profile.json has no profiles object"
    case_run c23c-no-profiles-object-no-machine 1 fix_noprofiles @("-NoMachine")
    has_row "ERROR|profile.json|invalid (see log)"
    rows_n 1 "ACTION"
    case_run c23d-v1-profile-no-machine 1 fix_v1profile @("-NoMachine")
    has_row "ERROR|profile.json|invalid (see log)"
    rows_n 1 "ACTION"
    # C23e audit A-10 for the other ACTION: no machine match (C7 fixture)
    case_run c23e-no-match-log-line 1 fix_nomatch
    has_row "ACTION||Run: aitools user init (profiles: nobul-mac, laptop)"
    out_has "config: machine profile: no machine match -- Run: aitools user init (profiles: nobul-mac, laptop)"

    # C24 a config.json key that differs only in case from a managed key (PR #108 n-2):
    # the merge fails, and the message names both keys; the file is untouched, no temp left
    function fix_case_twin {
        fix_v2
        WriteText $CFG ((ReadText $CFG).Replace('"machineAlias": "new-mac"', "`"machineAlias`": `"new-mac`",`n  `"MachineId`": `"hand-written`""))
    }
    case_run c24-case-twin 1 fix_case_twin
    has_row "ERROR|aitools config|merge failed"
    out_has 'key "MachineId" differs only in case from the managed key "machineId": rename or remove it'
    has_json '"MachineId": "hand-written"'
    if ((ReadText $RAWJ).Contains('"version": 2')) { ok "c24-case-twin: config untouched" } else { bad "c24-case-twin: config changed" }
    if (AitoolsDirHas 'config.json.tmp') { bad "c24-case-twin: temp file left" } else { ok "c24-case-twin: no temp file left" }

    # C25 audit A-11 is a .sh writer case (a failing rm stub on PATH): the .ps1 writer
    # removes with Remove-Item, so there is nothing to stub here
    skip "c25-rm-fails: .sh writer only (the .ps1 removes with Remove-Item)"

    # C12 bad arguments
    case_run c12-bad-arg 1 fix_nodp @("--bogus")
    has_row "ERROR|aitools config|bad arguments"

    # --- Installer Step 3/5 helpers (aitools-install.ps1 "install log helpers" block) ---
    # The full installer cannot run here (incident #89); its helper block is extracted
    # and run against the real writer (setup-user-config.ps1) under the isolated HOME.
    # The same harness text as the earlier Git Bash harness wrote.
    WriteText "$WORK/inst-harness.ps1" @'
param([string]$Repo, [string]$Mode, [string]$ReposPath = "", [string]$RepoPath = "")
. (Join-Path $Repo "scripts/aitools-lib.ps1")
Initialize-Logging "aitools-install"
$logJsonl = Join-Path $logDir "deploy.jsonl"; $runId = "test01"; $hostName = "testhost"; $osName = "Windows"
$text = [IO.File]::ReadAllText((Join-Path $Repo "scripts/aitools-install.ps1"))
$m = [regex]::Match($text, '(?ms)^# --- BEGIN install log helpers[^\n]*\n(.*?)^# --- END install log helpers ---')
if (-not $m.Success) { Write-Output "no helper block"; exit 3 }
Invoke-Expression $m.Groups[1].Value
if ($Mode -eq "abs") { Write-Output (Get-AbsoluteReposPath $ReposPath); exit 0 }
if ($Mode -eq "jsonl") { Write-JsonlRecord "2026-01-01T00:00:00Z" "t" "info" "q`"b\t`tn`nc$([char]1)e$([char]27)[31mr`rz"; exit 0 }
Invoke-ConfigWriter (Join-Path $Repo "scripts/setup-user-config.ps1") @{ ReposPath = $ReposPath; RepoPath = $RepoPath }
Write-Output "COUNTS errors=$($script:errors) warnings=$($script:warnings)"

'@

    # inst_run MODE [REPOS_PATH REPO_PATH] -- run the extracted helpers in a child pwsh
    # (abs: REPOS_PATH only; jsonl: none; run: both); output in $WORK/inst.out (CR and
    # colours removed). $script:INST_CWD: the current directory of the run (default $H).
    $script:INST_CWD = ""
    function inst_run([string]$Mode, [string]$A1 = "", [string]$A2 = "") {
        $script:RC = 0
        WriteText "$H/summary.txt" ""
        $a = @()
        switch ($Mode) { "abs" { $a = @("-ReposPath", $A1) } "run" { $a = @("-ReposPath", $A1, "-RepoPath", $A2) } }
        $envs = Get-BaseEnv
        $envs["AITOOLS_SUMMARY_FILE"] = "$H/summary.txt"
        $envs["AITOOLS_PROFILE_TEST_MACHINE_ID"] = $ID_MAC
        $envs["AITOOLS_PROFILE_TEST_HOSTNAME"] = "nobul-mac"
        $cwd = if ($script:INST_CWD) { $script:INST_CWD } else { $H }
        $argv = @("-NoProfile", "-NonInteractive", "-File", "$WORK/inst-harness.ps1", "-Repo", $root, "-Mode", $Mode) + $a
        $script:RC = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile "$WORK/inst.out" -WorkingDirectory $cwd
        WriteText "$WORK/inst.out" (Strip (ReadText "$WORK/inst.out"))
    }
    function inst_counts {
        $m = [regex]::Match((ReadText "$WORK/inst.out"), '(?m)^COUNTS errors=(\d+) warnings=(\d+)')
        if ($m.Success) { return "$($m.Groups[1].Value) $($m.Groups[2].Value)" }
        return ""
    }
    function inst_got { @((ReadText "$WORK/inst.out") -split "`n" | Where-Object { $_ -match '\S' }) -join "`n" }
    # same_path GOT WANT -- separators and letter case are not significant (Windows paths)
    function same_path([string]$A, [string]$B) { ($A -replace '\\', '/').ToLowerInvariant() -ceq ($B -replace '\\', '/').ToLowerInvariant() }
    # Read-JsonlFile PATH -- parse every line of a deploy.jsonl strictly (RFC 8259:
    # System.Text.Json rejects raw control characters, comments and trailing commas,
    # as perl JSON::PP decode_json does; ConvertFrom-Json would accept some of them).
    # Returns @{ Ok; Error; Records }. A missing or empty file is not Ok.
    function Read-JsonlFile([string]$Path) {
        $res = @{ Ok = $true; Error = ""; Records = [System.Collections.Generic.List[object]]::new() }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $res.Ok = $false; $res.Error = "no file $Path"; return $res }
        try { $lines = [IO.File]::ReadAllLines($Path, [Text.UTF8Encoding]::new($false, $true)) }
        catch { $res.Ok = $false; $res.Error = "cannot read ${Path}: $($_.Exception.Message)"; return $res }
        if ($lines.Count -eq 0) { $res.Ok = $false; $res.Error = "empty file $Path"; return $res }
        $i = 0
        foreach ($ln in $lines) {
            $i++
            try {
                $doc = [System.Text.Json.JsonDocument]::Parse($ln)
                $rec = @{}
                foreach ($p in $doc.RootElement.EnumerateObject()) {
                    $rec[$p.Name] = if ($p.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::String) { $p.Value.GetString() } else { $p.Value.GetRawText() }
                }
                $doc.Dispose()
                $res.Records.Add($rec)
            } catch {
                $res.Ok = $false
                $res.Error = "line ${i}: $($_.Exception.Message)"
                break
            }
        }
        return $res
    }
    # jsonl_check -- every deploy.jsonl line is valid JSON; sets the writer's counts:
    # $script:JlAll (its records), $script:JlWarn (its warn records except the footer),
    # $script:JlFooter (N of its "COMPLETED with N warning(s)" footer, 0 without one)
    function jsonl_check {
        $r = Read-JsonlFile "$H/.aitools/logs/deploy.jsonl"
        $script:JlAll = 0; $script:JlWarn = 0; $script:JlFooter = 0
        foreach ($rec in $r.Records) {
            if ($rec["script"] -ceq "setup-user-config") {
                $script:JlAll++
                if ($rec["level"] -ceq "warn" -and $rec["msg"] -cnotmatch '^(COMPLETED|FAILED) with ') { $script:JlWarn++ }
                $fm = [regex]::Match([string]$rec["msg"], '^COMPLETED with (\d+) warning')
                if ($fm.Success) { $script:JlFooter = [int]$fm.Groups[1].Value }
            }
        }
        if ($r.Ok) { ok "$L step5: deploy.jsonl lines are valid JSON" }
        else { bad "$L step5: deploy.jsonl has an invalid line"; Show-Indented $r.Error }
    }

    # Step 3: a relative answer becomes absolute (relative to the current directory)
    $want = "$H/repos"; $want_l = $want
    $abs_in = "C:/abs/repos"   # a Windows user answers with a drive path
    # "/" for a native Windows program is the root of the current drive (pwsh
    # Set-Location /); the Git Bash harness ran from Git's "/", the Git install
    # directory (C:\Program Files\Git). The case checks the same thing: a run from a
    # root gives no double separator.
    $driveRoot = [IO.Path]::GetPathRoot($WORK)
    $root_tmp = Join-Path $driveRoot "tmp"
    inst_run abs repos
    $got = inst_got
    $REL_GOT = $got
    if ((same_path $got $want) -or (same_path $got $want_l)) { ok "$L step3: relative 'repos' -> $got" }
    else { bad "$L step3: relative 'repos' -> '$got', want $want_l" }
    inst_run abs $abs_in
    $got = inst_got
    if ($got -ceq $abs_in) { ok "$L step3: absolute path unchanged" } else { bad "$L step3: absolute -> '$got'" }
    # normalised: ../ collapsed, and a run from / gives no double separator
    inst_run abs ../home/repos
    $got = inst_got
    if ((same_path $got $want) -or (same_path $got $want_l)) { ok "$L step3: '../home/repos' normalised" } else { bad "$L step3: '../home/repos' -> '$got'" }
    $script:INST_CWD = $driveRoot
    inst_run abs tmp
    $script:INST_CWD = ""
    $got = inst_got
    if (same_path $got $root_tmp) { ok "$L step3: relative from / -> $got" } else { bad "$L step3: relative from / -> '$got', want $root_tmp" }
    # JSONL records stay valid with quotes, backslashes and control characters
    New-Item -ItemType Directory -Path "$H/.aitools/logs" -Force | Out-Null
    if (Test-Path -LiteralPath "$H/.aitools/logs/deploy.jsonl") { Remove-Item -LiteralPath "$H/.aitools/logs/deploy.jsonl" -Force }
    inst_run jsonl
    $jr = Read-JsonlFile "$H/.aitools/logs/deploy.jsonl"
    if ($jr.Ok) { ok "$L jsonl: control characters give valid JSON" }
    else { bad "$L jsonl: invalid record"; Show-Indented ((ReadText "$H/.aitools/logs/deploy.jsonl") + "`n" + $jr.Error) }

    # Step 5 relays the writer: its lines reach deploy.jsonl, its warnings are counted
    # (C13 fixture: an unregistered profile warns), and the relative-path regression
    # is gone (Step 3's absolute path is accepted and config.json is written)
    fix_unreg
    Remove-Item -LiteralPath $CFG -Force
    inst_run run $REL_GOT "$H/repos/aitools"   # REL_GOT: Step 3's answer for the relative 'repos'
    $counts = inst_counts
    if ($script:RC -eq 0 -and (Test-Path -LiteralPath $CFG -PathType Leaf) -and (Get-Item -LiteralPath $CFG).Length -gt 0) { ok "$L step5: config.json written" }
    else { bad "$L step5: rc=$($script:RC), config missing"; Show-Indented (ReadText "$WORK/inst.out") }
    jsonl_check
    if ($script:JlAll -gt 0) { ok "$L step5: writer lines in deploy.jsonl ($($script:JlAll))" } else { bad "$L step5: no writer lines in deploy.jsonl" }
    # the installer's count = the writer's own N (its footer) = its warn lines minus the footer
    $cw = if ($counts) { ($counts -split ' ')[1] } else { "" }
    if ($cw -ceq [string]$script:JlFooter -and $script:JlWarn -eq $script:JlFooter -and $script:JlFooter -gt 0) { ok "$L step5: writer warnings counted ($cw)" }
    else { bad "$L step5: counts '$counts', writer warn lines $($script:JlWarn), writer footer N $($script:JlFooter)"; Show-Indented (ReadText "$WORK/inst.out") }
    if ((ReadText "$WORK/inst.out") -cmatch '\[setup-user-config\] \[warn\]') { ok "$L step5: writer lines shown on the console" } else { bad "$L step5: writer lines not shown" }

    # A failing writer (relative path reaching it) is one installer error
    reset_home
    inst_run run repos "$H/repos/aitools"
    $counts = inst_counts
    $ce = if ($counts) { ($counts -split ' ')[0] } else { "" }
    if ($ce -ceq "1") { ok "$L step5: failed writer = 1 error" } else { bad "$L step5: failed writer counts '$counts'"; Show-Indented (ReadText "$WORK/inst.out") }
    if (@(((ReadText "$H/summary.txt") -replace "`r", "") -split "`n") -ccontains "ERROR|aitools config|bad arguments") { ok "$L step5: writer ERROR row kept" } else { bad "$L step5: no writer ERROR row" }
} finally {
    Remove-TestTempRoot $WORK
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} writer)" -f $script:PASS, $script:FAIL, $script:SKIP, $L)
if ($script:FAIL -ne 0) { exit 1 }
exit 0
