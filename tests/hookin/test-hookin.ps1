# test-hookin.ps1 -- tests for the deploy-harness hook-ins on Windows: the
# Windows branch of the deploy_configs loop of scripts/aitools (the bash entry
# point, cross-platform), Deploy-Configs (scripts/aitools.ps1) and
# Invoke-HarnessStep (scripts/aitools-install.ps1). The Windows harness of this
# suite; tests/hookin/test-hookin.sh is the macOS/Linux harness (aitools-install.sh
# Step 8b and the .sh list of deploy_configs).
#
# Each case builds a fixture aitools repo (git) whose scripts/ holds copies of the
# real aitools-install.sh, aitools, aitools-lib.sh/.ps1 and deploy-harness.sh/.ps1
# (guards intact), plus stub setup scripts (they record that they ran) and a stub
# config writer (it records its arguments). Everything runs under an isolated HOME
# and USERPROFILE in a temp directory, removed on exit; `claude` and `node` are
# stubs on PATH, as in the .sh harness. The real HOME and the real repos are never
# touched.
# Cases:
#   static   -- installer has no ~/.aitools/bin step; Step 8b sits between Step 8
#               (Node) and Step 9 on both platforms; the sync deploy lists start with
#               deploy-harness and no longer list setup-user-config (file checks)
#   loop     -- deploy_configs (extracted from scripts/aitools), its Windows branch
#               (the .ps1 list with pwsh), run by Git Bash: writer runs once,
#               deploy-harness first, the other 7 scripts run
#   loop exit 1 / loop abort (pty) -- a duplicate hook: ERROR row; [x]abort
#   ps loop / ps step -- the same for Deploy-Configs (aitools.ps1) and
#               Invoke-HarnessStep (aitools-install.ps1) under native pwsh, through
#               tests/hookin/hookin-driver.ps1
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs on Windows only. scripts/aitools is a bash entry point with
# a Windows branch (cross-platform.md exemption table), so the loop cases run it
# with Git Bash (Resolve-TestGitBash, never a bare bash: in native pwsh that can
# be the WSL launcher; SKIP without Git Bash). aitools-install.sh refuses
# Windows, so its install cases are in the .sh harness only. On Windows the bash
# loop does not relay deploy-harness.ps1 to deploy.jsonl (by design,
# scripts/aitools), so that check is not made for the loop. No sh-vs-ps1 parity
# is asserted here, so there are no golden files.
# Interactive cases use tests/managed-files/pty-run.py (python3 with pywinpty);
# skipped without it. Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/hookin/test-hookin.ps1 [-Help]

param([switch]$Help)
if ($Help) { foreach ($l in (Get-Content -LiteralPath $PSCommandPath)) { if ($l -notmatch '^#') { break }; $l -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/hookin/test-hookin.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$PTY = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = New-TestTempRoot "hookin"
$langRun = "ps1"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:C = ""

function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines FILE: the lines of FILE, CRs removed (none when the file is missing)
function Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $t = ([IO.File]::ReadAllText($Path)) -replace "`r", ""
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    if ($t -eq "") { return @() }
    return @($t -split "`n")
}
# Mixed PATH: C:\a\b -> C:/a/b (what cygpath -m gave the Git Bash harness)
function Mixed([string]$Path) { $Path -replace '\\', '/' }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:C -and (Test-Path -LiteralPath (Join-Path $script:C "out") -PathType Leaf)) {
        @((Strip (ReadText (Join-Path $script:C "out"))) -split "`n") | Select-Object -Last 30 | ForEach-Object { Write-Output "      | $_" }
    }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }

# Invoke-Git ARGS...: git with a fixed identity; output captured, a failure throws
function Invoke-Git {
    $o = & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE): $($o -join ' ')" }
}
function WriteLf([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text) }
# LocalEdit FILE: the "local edit" that makes the next run show a review menu. When
# the first run deployed nothing the directory is missing: the error is printed and
# the suite goes on (the abort checks then fail), as the .sh harness's printf does.
function LocalEdit([string]$Path) {
    try { WriteLf $Path "local edit`n" } catch { Write-Output "      | local edit not written: $($_.Exception.Message)" }
}

$deployStubs = @("setup-user-claude", "setup-user-cursor", "setup-user-mcp", "setup-user-skills", "setup-cursor-ide-mcp", "setup-user-settings", "setup-user-hooks")

# Setup-Case NAME: fixture repo ($R), HOME ($H), stub bin ($B)
function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    $script:R = Join-Path $script:C "repo"; $script:H = Join-Path $script:C "home"; $script:B = Join-Path $script:C "bin"
    foreach ($d in @("$R/scripts", "$R/reference", "$R/shared/hooks", "$R/shared/rules", "$H/.aitools", $B, "$C/repos")) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    foreach ($f in @("aitools-install.sh", "aitools", "aitools-lib.sh", "deploy-harness.sh", "aitools-lib.ps1", "deploy-harness.ps1")) {
        Copy-Item -LiteralPath (Join-Path $root "scripts/$f") -Destination (Join-Path $R "scripts/$f")
    }
    # Stub config writers: record their arguments (the installer passes flags at
    # Step 5; deploy-harness calls them bare)
    WriteLf "$R/scripts/setup-user-config.sh" ('#!/usr/bin/env bash' + "`n" + 'printf "%s\n" "called $*" >> "$HOME/writer-calls"' + "`n" + "exit 0`n")
    WriteLf "$R/scripts/setup-user-config.ps1" ('param([switch]$DryRun)' + "`n" + 'Add-Content -Path (Join-Path $env:USERPROFILE "writer-calls") -Value ("called " + $(if ($DryRun) { "-DryRun" } else { "" }))' + "`n" + "exit 0`n")
    foreach ($s in $deployStubs) {
        WriteLf "$R/scripts/$s.sh" ('#!/usr/bin/env bash' + "`n" + 'printf "%s\n" "' + $s + '" >> "$HOME/calls"' + "`n" + "exit 0`n")
        WriteLf "$R/scripts/$s.ps1" ('Add-Content -Path (Join-Path $env:USERPROFILE "calls") -Value "' + $s + '"' + "`n" + "exit 0`n")
    }
    foreach ($f in @("harness-db.py", "read-session.py", "read-session-full.py")) {
        WriteLf "$R/scripts/$f" ("#!/usr/bin/env python3`nprint(`"$f`")`n")
    }
    WriteLf "$R/reference/harness.md" "# Harness`n`nsource text`n"
    WriteLf "$R/shared/hooks/h1.sh" "#!/usr/bin/env bash`necho hook`n"
    WriteLf "$R/shared/rules/r1.md" "shared rule`n"
    # rules come from shared/rules only (deploy-harness, commander 2026-11-06)
    WriteLf "$R/shared/rules/p1.md" "project rule`n"
    Invoke-Git -C $R init -q
    Invoke-Git -C $R add -A
    Invoke-Git -C $R commit -q -m fixture
    WriteLf "$H/.aitools/config.json" ("{`n  `"version`": 3,`n  `"reposPath`": `"" + (Mixed "$C/repos") + "`",`n  `"repoPath`": `"" + (Mixed $R) + "`"`n}`n")
    # claude/node stubs (bash scripts, as the .sh harness puts on PATH: Git Bash runs
    # them; native pwsh does not, as under the Git Bash harness)
    WriteLf "$B/claude" ('#!/usr/bin/env bash' + "`n" + 'case "$1" in' + "`n" + '  --version) echo "9.9.9 (stub)" ;;' + "`n" + '  update) echo "already up to date" ;;' + "`n" + "esac`nexit 0`n")
    WriteLf "$B/node" "#!/usr/bin/env bash`necho v22.0.0`n"
}

# Add-DuplicateRule: the same hook name in shared/hooks and .claude/hooks (hooks
# keep two sources) -> deploy-harness exit 1
function Add-DuplicateRule {
    New-Item -ItemType Directory -Path "$R/.claude/hooks" -Force | Out-Null
    WriteLf "$R/shared/hooks/dup.sh" "dup a`n"
    WriteLf "$R/.claude/hooks/dup.sh" "dup b`n"
    Invoke-Git -C $R add -A
    Invoke-Git -C $R commit -q -m dup
}

# Run-Env INPUT HOMEVALUE EXE ARGS: run EXE under the case HOME (stdin at EOF, or a
# pty with INPUT). USERPROFILE (pwsh's home) and the log and summary paths are
# native (forward slashes, as cygpath -m gave the Git Bash harness); HOMEVALUE is
# the MSYS form for Git Bash and the native form for pwsh. CRs that pwsh writes
# are removed from the files the checks read.
function Run-Env([string]$InputText, [string]$HomeValue, [string]$Exe, [string[]]$ExeArgs) {
    WriteLf "$C/summary" ""
    WriteLf "$H/calls" ""
    $envs = @{
        AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_RUN_ID = $null; AITOOLS_SUPPRESS_SUMMARY_DISPLAY = $null
        HOME = $HomeValue; USERPROFILE = (Mixed $H); PATH = ($B + [IO.Path]::PathSeparator + $env:PATH)
        AITOOLS_LOG_DIR = (Mixed "$C/logs"); AITOOLS_SUMMARY_FILE = (Mixed "$C/summary")
    }
    if (-not $InputText) {
        $script:rc = Invoke-TestScript -FilePath $Exe -ArgumentList $ExeArgs -Environment $envs -OutFile "$C/out"
    } else {
        $old = @{}
        foreach ($k in @($envs.Keys)) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $envs[$k]) }
        try {
            # pty-run.py decodes \n escapes; the input is passed as typed
            & python3 $PTY --input $InputText --log "$C/out" -- $Exe @ExeArgs
            $script:rc = $LASTEXITCODE
        } finally {
            foreach ($k in @($old.Keys)) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
        }
    }
    foreach ($f in @("$C/out", "$C/summary", "$H/calls", "$H/writer-calls")) {
        if (Test-Path -LiteralPath $f -PathType Leaf) { WriteLf $f (([IO.File]::ReadAllText($f)) -replace "`r", "") }
    }
    $script:LOG = Join-Path $C "logs/deploy.log"
    if (-not (Test-Path -LiteralPath $script:LOG)) {
        New-Item -ItemType Directory -Path (Join-Path $C "logs") -Force | Out-Null
        WriteLf $script:LOG ""
    }
}

function OutHasLine([string]$Line) { @(Lines "$C/out") -ccontains $Line }
function OutMatch([string]$Regex) { [bool](@(Lines "$C/out") | Where-Object { $_ -cmatch $Regex }) }
function Row([string]$Line) { @(Lines "$C/summary") -ccontains $Line }
# Calls: the stub calls, each line followed by a space (perl -pe 's/\n/ /')
function Calls { (ReadText "$H/calls") -replace "`n", " " }
# CountLines FILE: the number of newlines (wc -l)
function CountLines([string]$Path) { ([regex]::Matches((ReadText $Path), "`n")).Count }
# CountMatch REGEX FILE: lines matching (grep -c)
function CountMatch([string]$Regex, [string]$Path) { @(Lines $Path | Where-Object { $_ -cmatch $Regex }).Count }
function IsEmpty([string]$Path) { -not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -eq 0 }

$loopStubs = "setup-user-claude setup-user-mcp setup-user-skills setup-cursor-ide-mcp setup-user-cursor setup-user-settings setup-user-hooks "

try {
    $gitBash = Resolve-TestGitBash
    $havePty = [bool](Get-Command python3 -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $PTY -PathType Leaf)
    # Get-Command exempt: command-existence check; $havePty is the fallback branch
    if ($havePty) {
        # Windows pty = pywinpty (ConPTY); a failing import means "not installed".
        & python3 -c "import winpty" 2>$null
        $havePty = ($LASTEXITCODE -eq 0)
    }

    # The loop functions: deploy_abort + deploy_configs extracted from scripts/aitools
    # (top-level functions inside main()), as the .sh harness's perl range does:
    # each from its "name() {" line to the next line that starts with "}".
    $loopFuncs = Join-Path $tmpRoot "loop-funcs.sh"
    $inAbort = $false; $inConfigs = $false
    $sb = [Text.StringBuilder]::new()
    foreach ($l in @(Lines (Join-Path $root "scripts/aitools"))) {
        if (-not $inAbort -and $l -cmatch '^deploy_abort\(\) \{') { $inAbort = $true }
        if ($inAbort) { [void]$sb.Append($l + "`n"); if ($l -cmatch '^\}') { $inAbort = $false } }
        if (-not $inConfigs -and $l -cmatch '^deploy_configs\(\) \{') { $inConfigs = $true }
        if ($inConfigs) { [void]$sb.Append($l + "`n"); if ($l -cmatch '^\}') { $inConfigs = $false } }
    }
    WriteLf $loopFuncs $sb.ToString()
    $loopDriver = Join-Path $tmpRoot "loop-driver.sh"
    WriteLf $loopDriver ((@(
            '#!/usr/bin/env bash',
            '# loop-driver.sh SCRIPTS_DIR FUNCS -- run deploy_configs SCRIPTS_DIR as scripts/aitools does',
            'source "$1/aitools-lib.sh"',
            'logging_init "aitools"',
            'LOG_DISPLAY="$LOG_FILE"',
            'dry_run=false',
            'force=false',
            'show_cloud_mcp() { :; }',
            'source "$2"',
            'deploy_configs "$1"',
            'printf ''LOOP rc=%s aborted=%s\n'' "$?" "$deploy_aborted"'
        ) -join "`n") + "`n")

    # Run-Loop [INPUT]: the loop driver under Git Bash, MSYS paths (the bash code
    # builds script paths from SCRIPTS_DIR and converts them with cygpath -w)
    function Run-Loop([string]$InputText = "") {
        Run-Env $InputText (ConvertTo-MsysPath $H) $gitBash @((ConvertTo-MsysPath $loopDriver), (ConvertTo-MsysPath "$R/scripts"), (ConvertTo-MsysPath $loopFuncs))
    }

    # ---------------------------------------------------------------------------
    # Static checks (both platforms' files; file reads)
    # ---------------------------------------------------------------------------
    $script:C = ""
    $instSh = Join-Path $root "scripts/aitools-install.sh"
    $instPs1 = Join-Path $root "scripts/aitools-install.ps1"
    Check "static: aitools-install.sh Step 8b passes --skip-config after Step 5 ran the writer" `
        ((CountMatch '^ +run_harness_step "\$SCRIPT_DIR/deploy-harness.sh" --skip-config ' $instSh) -ge 1 -and (CountMatch '^ +CONFIG_WRITER_RAN=true$' $instSh) -ge 1)
    Check "static: aitools-install.ps1 Step 8b passes SkipConfig after Step 5 ran the writer" `
        ((ReadText $instPs1).Contains('if ($configWriterRan) { @{ SkipConfig = $true } }') -and (CountMatch '^ +\$configWriterRan = \$true' $instPs1) -ge 1)
    foreach ($f in @("aitools-install.sh", "aitools-install.ps1")) {
        $fp = Join-Path $root "scripts/$f"
        Check "static: $f has no harness bin step" ((CountMatch 'harness bin|_hbin_deployed|hbinDeployed' $fp) -eq 0)
        # the last line matching each marker, as the .sh harness's perl does
        $a = 0; $b = 0; $c = 0; $n = 0
        foreach ($l in @(Lines $fp)) {
            $n++
            if ($l -cmatch 'Step 8: Node') { $a = $n }
            if ($l -cmatch 'Step 8b: Deployed harness"') { $b = $n }
            if ($l -cmatch 'Step 9: Claude') { $c = $n }
        }
        Check "static: $f Step 8b between Step 8 (Node) and Step 9" ($a -and $b -and $c -and $a -lt $b -and $b -lt $c)
    }
    $aitoolsBash = Join-Path $root "scripts/aitools"
    Check "static: aitools deploy lists start with deploy-harness, no setup-user-config" `
        ((CountMatch '^ +local deploy_scripts="deploy-harness\.(sh|ps1) ' $aitoolsBash) -eq 2 -and (CountMatch '^ +local deploy_scripts=.*setup-user-config' $aitoolsBash) -eq 0)
    $aitoolsPs1 = Join-Path $root "scripts/aitools.ps1"
    Check "static: aitools.ps1 deploy list starts with deploy-harness, no setup-user-config" `
        ((CountMatch '^ +\$deployScripts = @\("deploy-harness\.ps1", ' $aitoolsPs1) -ge 1 -and (CountMatch '^ +\$deployScripts = .*setup-user-config' $aitoolsPs1) -eq 0)
    Check "static: loop functions extracted" `
        ((CountMatch '^deploy_abort\(\) \{' $loopFuncs) -ge 1 -and (CountMatch '^deploy_configs\(\) \{' $loopFuncs) -ge 1)

    # ---------------------------------------------------------------------------
    # deploy_configs (scripts/aitools sync loop), its Windows branch: the .ps1 list
    # with pwsh, under Git Bash
    # ---------------------------------------------------------------------------
    if (-not $gitBash) {
        Skip "loop cases (Git Bash not found; scripts/aitools is bash)"
    } else {
        Setup-Case loop
        Run-Loop
        Check "loop ($langRun list): rc 0, not aborted" (OutHasLine 'LOOP rc=0 aborted=false')
        Check "loop ($langRun list): writer runs once (inside deploy-harness)" `
            ((CountLines "$H/writer-calls") -eq 1 -and (CountMatch '^called $' "$H/writer-calls") -eq 1)
        Check "loop ($langRun list): deploy-harness first, then the 7 scripts" `
            ((Calls) -ceq $loopStubs -and (Row 'OK|harness files|7 added'))
        # deploy-harness.ps1 runs unrelayed on Windows (scripts/aitools, review prompt):
        # no deploy.jsonl check for the loop

        Setup-Case loop-err
        Add-DuplicateRule
        Run-Loop
        Check "loop ($langRun list) exit 1: one error counted, ERROR row, the 7 scripts ran" `
            ((OutHasLine 'LOOP rc=1 aborted=false') -and (Row 'ERROR|harness files|script failed (exit 1)') -and (Calls) -ceq $loopStubs)

        if ($havePty) {
            Setup-Case loop-abort
            Run-Loop
            LocalEdit "$H/.aitools/rules/p1.md"
            Run-Loop 'x\n'
            Check "loop ($langRun list) abort: aborted, no later script ran" `
                ((OutMatch 'LOOP rc=0 aborted=true') -and (IsEmpty "$H/calls") -and (Row 'WARN|harness files|aborted by user'))
        } else {
            Skip "loop abort (no python3 / pty-run.py)"
        }
    }

    # ---------------------------------------------------------------------------
    # PowerShell: Deploy-Configs (aitools.ps1) and Invoke-HarnessStep
    # (aitools-install.ps1), loaded from the real files by hookin-driver.ps1, native pwsh
    # ---------------------------------------------------------------------------
    $driver = Join-Path $root "tests/hookin/hookin-driver.ps1"
    # Run-Ps MODE [INPUT] [SWITCH]: the driver, HOME and USERPROFILE native
    function Run-Ps([string]$Mode, [string]$InputText = "", [string]$Switch = "") {
        $argv = @("-NoProfile", "-File", $driver, "-Mode", $Mode, "-ScriptsDir", (Mixed "$R/scripts"), "-RepoRoot", (Mixed $root))
        if ($Switch) { $argv += $Switch }
        Run-Env $InputText (Mixed $H) $pwshExe $argv
    }
    $fixtureHarness = Join-Path $tmpRoot "loop/repo/scripts/deploy-harness.ps1"
    if (-not (Test-Path -LiteralPath $fixtureHarness)) { Setup-Case loop }
    Check "ps: fixture deploy-harness.ps1 is the real script (Windows guard intact)" `
        ([Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes((Join-Path $root "scripts/deploy-harness.ps1")), [IO.File]::ReadAllBytes($fixtureHarness)))

    Setup-Case ps-loop
    Run-Ps loop
    Check "ps loop: rc 0, not aborted" (OutHasLine 'LOOP rc=0 aborted=False')
    Check "ps loop: writer runs once (inside deploy-harness)" `
        ((CountLines "$H/writer-calls") -eq 1 -and (CountMatch '^called $' "$H/writer-calls") -eq 1)
    Check "ps loop: deploy-harness first, then the 7 scripts" `
        ((Calls) -ceq $loopStubs -and (Row 'OK|harness files|7 added'))
    Check "ps loop: deploy-harness lines relayed to deploy.jsonl" ((ReadText "$C/logs/deploy.jsonl").Contains('"script":"deploy-harness"'))

    Setup-Case ps-loop-err
    Add-DuplicateRule
    Run-Ps loop
    Check "ps loop exit 1: one error counted, ERROR row, the 7 scripts ran" `
        ((OutHasLine 'LOOP rc=1 aborted=False') -and (Row 'ERROR|harness files|script failed (exit 1)') -and (Calls) -ceq $loopStubs)

    Setup-Case ps-step
    Run-Ps step
    Check "ps step: returns 0, one OK row" `
        ((OutHasLine 'STEP rc=0') -and (Row 'OK|harness files|7 added') -and (CountMatch '\|harness files\|' "$C/summary") -eq 1)
    Check "ps step: bin deployed" (Test-Path -LiteralPath "$H/.aitools/bin/harness-db.py" -PathType Leaf)
    Check "ps step (no SkipConfig): writer runs once inside deploy-harness" ((CountLines "$H/writer-calls") -eq 1)

    Setup-Case ps-step-skip
    Run-Ps step "" "-SkipConfig"
    Check "ps step -SkipConfig: returns 0, writer not run, OK config.json n/a (written by installer)" `
        ((OutHasLine 'STEP rc=0') -and (IsEmpty "$H/writer-calls") -and (Row 'OK|config.json|n/a (written by installer)') -and (Row 'OK|harness files|7 added'))

    Setup-Case ps-step-err
    Add-DuplicateRule
    Run-Ps step
    Check "ps step exit 1: returns 0 (install continues), ERROR row" `
        ((OutHasLine 'STEP rc=0') -and (Row 'ERROR|harness files|script failed (exit 1)'))

    Setup-Case ps-step-missing
    Remove-Item -LiteralPath "$R/scripts/deploy-harness.ps1" -Force
    Run-Ps step
    Check "ps step missing script: WARN row" ((OutHasLine 'STEP rc=0') -and (Row 'WARN|harness files|deploy-harness.ps1 not found'))

    if ($havePty) {
        Setup-Case ps-loop-abort
        Run-Ps loop
        LocalEdit "$H/.aitools/rules/p1.md"
        Run-Ps loop 'x\n'
        Check "ps loop abort: aborted, no later script ran, WARN row" `
            ((OutMatch 'LOOP rc=0 aborted=True') -and (IsEmpty "$H/calls") -and (Row 'WARN|harness files|aborted by user'))
        Check "ps loop abort: abort line logged as [aitools]" `
            ((CountMatch '\[aitools\] \[info\] deploy-harness.ps1: aborted by user' $script:LOG) -ge 1)

        Setup-Case ps-step-abort
        Run-Ps step
        LocalEdit "$H/.aitools/rules/p1.md"
        Run-Ps step 'x\n'
        Check "ps step abort: returns 2, WARN row, file unchanged" `
            ((OutMatch 'STEP rc=2') -and (Row 'WARN|harness files|aborted by user') -and (@(Lines "$H/.aitools/rules/p1.md") -ccontains 'local edit'))
    } else {
        Skip "ps abort cases (no python3 / pty-run.py with pywinpty)"
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $langRun)
if ($script:fail -ne 0) { exit 1 }
exit 0
