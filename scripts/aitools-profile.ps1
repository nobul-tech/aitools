# aitools-profile.ps1 -- the one resolver for "where is my dotprofile" and
# "which machine profile is this machine" (Windows; on macOS/Linux use
# aitools-profile.sh, which implements the same commands, options and output).
#
# Intent: Resolve, deterministically and with a stated reason ("via"), the
# dotprofile repo path and this machine's profile in profile.json, and derive
# the config.json values that come from them. NOT a writer of config.json
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves. NOT the settings.json sync (Sync-ManagedJson).
# Consumed by: the PowerShell shared-lib wrappers Resolve-UserRepoPath /
# Resolve-MachineProfile, setup-user-config.ps1, aitools.ps1 `user init`, and
# the generated deploy/setup-user-claude.ps1 (embedded copy).
#
# Usage: aitools-profile.ps1 <command> [options]   (--help for details)
#   In-process: $out = & aitools-profile.ps1 resolve; $rc = $LASTEXITCODE
# Exit codes: 0 resolved / ok; 1 nothing found (expected states, e.g. before
#   `aitools user init`); 2 error (bad input, unreadable or invalid JSON,
#   ambiguous match). Callers must not pass 2 through as their own exit code:
#   exit 2 from a setup script means a user abort (D-TS13).
# Output: data on the success stream only -- key<TAB>value lines (default) or
#   one JSON object (--json). Diagnostics go to deploy.log and stderr.
# JSON: ConvertFrom-Json / ConvertTo-Json (PS 7). Key order is kept and the
#   written layout (2-space indent, LF) is byte-identical to node and to the
#   bash engine, so every writer of the shared profile.json produces the same file.
# Safe to re-run: every command except `register` is read-only; `register`
#   writes only the --out file.
# Platform: Windows. Reference: reference/user-repo.md "Resolution".
# Decisions: P-Q2 (raw machine ids), P-Q3 (native bash + PowerShell, no node).
# Tests only: AITOOLS_PROFILE_TEST_ANY_OS=1 lets the parity tests run this file
#   with pwsh on macOS/Linux, always with --machine-id-value and --hostname-value.

$cliArgs = @($args)
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "aitools-profile"

# The success stream carries data: console log lines go to stderr (deploy.log unchanged)
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    $resolvedLog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logFile)
    [IO.File]::AppendAllText($resolvedLog, "$line`n", [System.Text.UTF8Encoding]::new($false))
    [Console]::Error.WriteLine($line)
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows -and $env:AITOOLS_PROFILE_TEST_ANY_OS -ne "1") {
    LogError "This script is for Windows. On macOS/Linux, use aitools-profile.sh."
    exit 2
}

function Show-Usage {
    @'
aitools-profile.ps1 -- dotprofile and machine-profile resolver (Windows)

Commands:
  user-repo-path  Which dotprofile. Options: --config F, --github-user U,
                  --user-repo-path P, --repos-path P, --plain (path only),
                  --path-form native|mixed (mixed = forward slashes)
  machine-id      Print this machine's stable id (MachineGuid, UNVERIFIED on
                  the commander's workstation); stored raw in profile.json
  hostname        Print this machine's name ($env:COMPUTERNAME, short form)
  resolve         Which profile this machine uses and why.
                  Options: --config F, --profile F, --alias A, --environment E
  derive-config   The config.json values derived from profile.json.
                  Options: --config F, --github-user U, --user-repo-path P,
                  --repos-path P, --alias A, --environment E
  snapshot        Compact JSON of version, identity, cursor, profiles from
                  --profile F (for embedding in generated deploy scripts)
  register        Write --profile F with this machine registered under --alias A
                  to --out TMP. Options: --name N, --company C, --shell S,
                  --environment E, --create (new profile.json; with
                  --github-user U, --email E)

Output: key<TAB>value lines; --json prints one JSON object instead.
Environment: AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS, AITOOLS_PROFILE_FILE,
  AITOOLS_ENVIRONMENT (see reference/user-repo.md "Resolution").
Test options: --machine-id-value ID, --hostname-value NAME (replace detection).
Exit: 0 ok, 1 not found, 2 error.
'@ -split "`n" | ForEach-Object { Write-Output ($_ -replace "`r$", "") }
}

# ---------------------------------------------------------------------------
# JSON helpers (PSCustomObject trees from ConvertFrom-Json)
# ---------------------------------------------------------------------------
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:JsonDateKind = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) {
    # PS 7.5+: keep ISO date strings as strings (older 7.x converts them to DateTime)
    $script:JsonDateKind = @{ DateKind = "String" }
}

# Read-JsonFile PATH -> @{ State = valid|missing|invalid; Value; Message }
function Read-JsonFile([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ State = "missing"; Value = $null; Message = "" }
    }
    try {
        $raw = [IO.File]::ReadAllText($Path, $script:Utf8NoBom)
    } catch {
        return @{ State = "invalid"; Value = $null; Message = "cannot read ${Path}: $($_.Exception.Message)" }
    }
    $raw = $raw.TrimStart([char]0xFEFF)
    try {
        $v = ConvertFrom-Json -InputObject $raw -Depth 64 -ErrorAction Stop @script:JsonDateKind
    } catch {
        return @{ State = "invalid"; Value = $null; Message = "$Path is invalid JSON: $($_.Exception.Message)" }
    }
    if ($v -isnot [System.Management.Automation.PSCustomObject]) {
        if ($null -eq $v) { return @{ State = "invalid"; Value = $null; Message = "$Path is invalid JSON: empty file" } }
        return @{ State = "invalid"; Value = $null; Message = "${Path}: top level is not an object" }
    }
    return @{ State = "valid"; Value = $v; Message = "" }
}

# Get-JNode ROOT SEG... -> @{ Found; Value } (Found=$false when a segment is absent)
function Get-JNode($Root, [string[]]$Segs) {
    $o = $Root
    foreach ($s in $Segs) {
        if ($o -isnot [System.Management.Automation.PSCustomObject]) { return @{ Found = $false; Value = $null } }
        $p = $o.PSObject.Properties[$s]
        if (-not $p) { return @{ Found = $false; Value = $null } }
        $o = $p.Value
    }
    return @{ Found = $true; Value = $o }
}

function Test-JScalar($v) {
    return ($v -is [string] -or $v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal] -or $v -is [System.Numerics.BigInteger] -or $v -is [datetime])
}

function ConvertTo-JText($v) {
    if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
    if ($v -is [datetime]) { return $v.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
    if ($v -is [double] -or $v -is [decimal]) { return ([System.Convert]::ToString($v, [System.Globalization.CultureInfo]::InvariantCulture)) }
    return [string]$v
}

# Read-JScalar ROOT SEG... -> @{ Found; Text } -- Found only for a non-null scalar
function Read-JScalar($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $null -eq $n.Value -or -not (Test-JScalar $n.Value)) { return @{ Found = $false; Text = "" } }
    return @{ Found = $true; Text = (ConvertTo-JText $n.Value) }
}
function Get-JText($Root, [string[]]$Segs) { return (Read-JScalar $Root $Segs).Text }

function Get-JType($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $null -eq $n.Value) { return "" }
    $v = $n.Value
    if ($v -is [System.Management.Automation.PSCustomObject]) { return "object" }
    if ($v -is [System.Array]) { return "array" }
    if ($v -is [string] -or $v -is [datetime]) { return "string" }
    if ($v -is [bool]) { return "boolean" }
    return "number"
}

function Get-JKeys($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $n.Value -isnot [System.Management.Automation.PSCustomObject]) { return @() }
    return @($n.Value.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-JItems($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $n.Value -isnot [System.Array]) { return @() }
    return @($n.Value | Where-Object { $null -ne $_ -and (Test-JScalar $_) } | ForEach-Object { ConvertTo-JText $_ })
}

# Set-JValue ROOT VALUE SEG... -- creates missing objects; new keys are appended
function Set-JValue($Root, $Value, [string[]]$Segs) {
    $o = $Root
    for ($i = 0; $i -lt $Segs.Count - 1; $i++) {
        $s = $Segs[$i]
        $p = $o.PSObject.Properties[$s]
        if (-not $p) {
            $o | Add-Member -NotePropertyName $s -NotePropertyValue ([PSCustomObject]@{})
            $p = $o.PSObject.Properties[$s]
        }
        if ($p.Value -isnot [System.Management.Automation.PSCustomObject]) { throw "set: '$s' is not an object" }
        $o = $p.Value
    }
    $last = $Segs[$Segs.Count - 1]
    $p = $o.PSObject.Properties[$last]
    if ($p) { $p.Value = $Value } else { $o | Add-Member -NotePropertyName $last -NotePropertyValue $Value }
}

# ConvertTo-NodeJson VALUE [-Compress] -- node JSON.stringify layout (LF, no BOM)
function ConvertTo-NodeJson($Value, [switch]$Compress) {
    $j = ConvertTo-Json -InputObject $Value -Depth 64 -Compress:$Compress
    return ($j -replace "`r`n", "`n")
}

# ---------------------------------------------------------------------------
# Output: key<TAB>value lines, warnings and errors last
# ---------------------------------------------------------------------------
$script:OutLines = [System.Collections.Generic.List[string]]::new()
$script:Warns = [System.Collections.Generic.List[string]]::new()
$script:Errs = [System.Collections.Generic.List[string]]::new()
function ConvertTo-OneLine($v) { return ([string]$v) -replace "[`t`r`n]", " " }
function Put([string]$Key, $Value) { $script:OutLines.Add("$Key`t$(ConvertTo-OneLine $Value)") }
function Add-Warn([string]$m) { $script:Warns.Add((ConvertTo-OneLine $m)) }
function Add-Err([string]$m) { $script:Errs.Add((ConvertTo-OneLine $m)) }

function Complete-Command([int]$Code) {
    $all = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $script:OutLines) { $all.Add($l) }
    foreach ($w in $script:Warns) { $all.Add("warn`t$w"); LogDetail "$($script:Cmd) warning: $w" }
    foreach ($e in $script:Errs) { $all.Add("error`t$e"); LogDetail "$($script:Cmd) error: $e" }
    LogDetail "$($script:Cmd) exit=$Code"
    if ($script:OptJson) {
        $o = [ordered]@{}
        foreach ($l in $script:OutLines) {
            $kv = $l -split "`t", 2
            $o[$kv[0]] = $kv[1]
        }
        $o["warnings"] = [object[]]@($script:Warns)
        $o["errors"] = [object[]]@($script:Errs)
        Write-Output (ConvertTo-NodeJson $o -Compress)
    } else {
        foreach ($l in $all) { Write-Output $l }
    }
    exit $Code
}

function Stop-Usage([string]$m) {
    LogDetail "usage error: $m"
    [Console]::Error.WriteLine("aitools-profile: $m (see --help)")
    exit 2
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
$script:Cmd = ""
if ($cliArgs.Count -gt 0) { $script:Cmd = [string]$cliArgs[0] }
$opt = @{
    config = ""; profile = ""; alias = ""; environment = ""; "github-user" = ""; "user-repo-path" = ""
    "repos-path" = ""; name = ""; company = ""; shell = ""; email = ""; out = ""
    "machine-id-value" = ""; "hostname-value" = ""; "path-form" = "native"
}
$script:OptCreate = $false; $script:OptJson = $false; $script:OptPlain = $false
for ($i = 1; $i -lt $cliArgs.Count; $i++) {
    $a = [string]$cliArgs[$i]
    switch -CaseSensitive ($a) {
        "--create" { $script:OptCreate = $true; continue }
        "--json" { $script:OptJson = $true; continue }
        "--plain" { $script:OptPlain = $true; continue }
        { $_ -eq "--help" -or $_ -eq "-h" } { Show-Usage; exit 0 }
        default {
            if ($a.StartsWith("--") -and $opt.ContainsKey($a.Substring(2))) {
                if ($i + 1 -ge $cliArgs.Count) { Stop-Usage "$a needs a value" }
                $opt[$a.Substring(2)] = [string]$cliArgs[$i + 1]
                $i++
            } else {
                Stop-Usage "unknown option: $a"
            }
        }
    }
}
if ($script:Cmd -eq "--help" -or $script:Cmd -eq "-h") { Show-Usage; exit 0 }

# ---------------------------------------------------------------------------
# This machine: environment, stable id, hostname
# ---------------------------------------------------------------------------
# Environment: the shared lib resolved $AitoolsEnvironment; --environment re-applies
# the same rule (claude-code-web exists only on linux).
$script:ThisEnv = $script:AitoolsEnvironment
if ($opt["environment"]) {
    if ($opt["environment"] -cne "local" -and $opt["environment"] -cne "claude-code-web") {
        Stop-Usage "--environment must be local or claude-code-web"
    }
    $script:ThisEnv = Resolve-AitoolsEnvironment -Platform $script:AitoolsPlatform -Requested $opt["environment"] -Remote ""
}

# Stable machine id, stored raw in profile.json (P-Q2): the MachineGuid value under
# HKLM\SOFTWARE\Microsoft\Cryptography. UNVERIFIED on the commander's workstation;
# it changes on OS reinstall and is duplicated on clones that were not sysprepped.
$script:ThisId = ""; $script:ThisIdSource = ""; $script:ThisIdError = ""
function Find-MachineId {
    if ($opt["machine-id-value"]) { $script:ThisId = $opt["machine-id-value"]; $script:ThisIdSource = "argument"; return }
    try {
        $script:ThisId = [string](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
        $script:ThisIdSource = "MachineGuid"
        if (-not $script:ThisId) { $script:ThisIdError = "MachineGuid is empty" }
    } catch {
        $script:ThisIdError = "MachineGuid not readable: $($_.Exception.Message)"
    }
}

# Hostname: $env:COMPUTERNAME, short and lower-cased (one source, as on macOS P-Q5)
$script:ThisHost = ""; $script:ThisHostError = ""
function ConvertTo-ShortHost([string]$h) { return ((([string]$h) -split '\.')[0]).Trim().ToLowerInvariant() }
function Find-Hostname {
    $raw = $opt["hostname-value"]
    if (-not $raw) { $raw = $env:COMPUTERNAME }
    if (-not $raw) { $script:ThisHostError = "COMPUTERNAME is not set"; return }
    $script:ThisHost = ConvertTo-ShortHost $raw
}

# ---------------------------------------------------------------------------
# Config (read-only here)
# ---------------------------------------------------------------------------
$script:CfgFile = $opt["config"]
if (-not $script:CfgFile) { $script:CfgFile = Join-Path (Join-Path $HOME ".aitools") "config.json" }
$script:Cfg = $null
function Import-Config {
    $r = Read-JsonFile $script:CfgFile
    if ($r.State -eq "valid") { $script:Cfg = $r.Value }
    elseif ($r.State -eq "invalid") { Add-Warn "$($r.Message) -- resolving without it" }
}
function Get-Cfg([string]$Key) {
    if ($null -eq $script:Cfg) { return "" }
    return (Get-JText $script:Cfg @($Key))
}

function Remove-TrailingSlash([string]$p) {
    while ($p.Length -gt 1 -and ($p.EndsWith("/") -or $p.EndsWith("\")) -and -not ($p.Length -eq 3 -and $p[1] -eq ':')) { $p = $p.Substring(0, $p.Length - 1) }
    return $p
}
function Format-OutPath([string]$p) {
    if ($opt["path-form"] -eq "mixed") { return ($p -replace '\\', '/') }
    return $p
}

# ---------------------------------------------------------------------------
# Which dotprofile (reference/user-repo.md "Which dotprofile"), first match wins:
#   1 AITOOLS_USER_REPO_PATH  2 --user-repo-path  3 config.json userRepoPath
#   4 <reposPath>\aitools-<githubUser>  5 the only aitools-* dir with profile.json
#   6 none (shared-only mode; not an error)
# Sets $script:RurPath/RurVia/RurExpected. Returns 0 found, 1 none, 2 error.
# ---------------------------------------------------------------------------
$script:RurPath = ""; $script:RurVia = "none"; $script:RurExpected = ""
function Resolve-UserRepo {
    $script:RurPath = ""; $script:RurVia = "none"; $script:RurExpected = ""
    if ($env:AITOOLS_USER_REPO_PATH) {
        if (Test-Path -LiteralPath $env:AITOOLS_USER_REPO_PATH -PathType Container) {
            $script:RurPath = Remove-TrailingSlash $env:AITOOLS_USER_REPO_PATH; $script:RurVia = "env"; return 0
        }
        Add-Err "AITOOLS_USER_REPO_PATH does not exist: $env:AITOOLS_USER_REPO_PATH"; return 2
    }
    if ($opt["user-repo-path"]) {
        if (Test-Path -LiteralPath $opt["user-repo-path"] -PathType Container) {
            $script:RurPath = Remove-TrailingSlash $opt["user-repo-path"]; $script:RurVia = "argument"; return 0
        }
        Add-Err "--user-repo-path does not exist: $($opt['user-repo-path'])"; return 2
    }
    $p = Get-Cfg "userRepoPath"
    if ($p) {
        if (Test-Path -LiteralPath $p -PathType Container) { $script:RurPath = Remove-TrailingSlash $p; $script:RurVia = "config"; return 0 }
        Add-Warn "config.json userRepoPath does not exist: $p"
    }
    $base = $opt["repos-path"]
    if (-not $base) { $base = Get-Cfg "reposPath" }
    if (-not $base) { $base = Join-Path $HOME "repos" }
    $base = Remove-TrailingSlash $base
    $user = $opt["github-user"]
    if (-not $user) { $user = Get-Cfg "githubUser" }
    if ($user) {
        $p = Join-Path $base "aitools-$user"
        if (Test-Path -LiteralPath $p -PathType Container) { $script:RurPath = $p; $script:RurVia = "convention"; return 0 }
        $script:RurExpected = $p; return 1
    }
    $found = @()
    if (Test-Path -LiteralPath $base -PathType Container) {
        try {
            $found = @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction Stop |
                Where-Object { $_.Name -cmatch '^aitools-[A-Za-z0-9-]+$' -and (Test-Path -LiteralPath (Join-Path $_.FullName "profile.json") -PathType Leaf) } |
                Sort-Object Name)
        } catch {
            Add-Warn "cannot list ${base}: $($_.Exception.Message)"
        }
    }
    if ($found.Count -eq 1) {
        Add-Warn "githubUser unknown -- used the only dotprofile under $base"
        $script:RurPath = $found[0].FullName; $script:RurVia = "scan"; return 0
    }
    if ($found.Count -gt 1) { Add-Warn "githubUser unknown and $($found.Count) aitools-* repos with profile.json under $base" }
    return 1
}

# ---------------------------------------------------------------------------
# Which machine profile (reference/user-repo.md "Which machine profile"),
# first decisive step wins:
#   1 override alias (--alias, AITOOLS_MACHINE_ALIAS)          via=override
#   2 environment claude-code-web: that machine.environment    via=environment
#   3 machine.id equals this machine's id                      via=id
#   4 config.json machineAlias                                 via=alias
#   5 hostname (legacy; warns)                                 via=hostname
#   6 none: error; never another profile's values
# Returns 0 resolved, 2 no match or error.
# ---------------------------------------------------------------------------
$script:RmAlias = ""; $script:RmVia = "none"; $script:RmOverrideSource = ""; $script:Aliases = @()
$script:Rm = @{ name = ""; company = ""; gitName = ""; gitEmail = ""; github = "" }

function Set-IdentityValues($P) {
    $n = Read-JScalar $P @("identity", "name")
    $script:Rm.name = if ($n.Found) { $n.Text } else { Get-JText $P @("identity", "git", "name") }
    $script:Rm.company = Get-JText $P @("identity", "company")
    $script:Rm.gitName = Get-JText $P @("identity", "git", "name")
    $script:Rm.gitEmail = Get-JText $P @("identity", "git", "email")
    $script:Rm.github = Get-JText $P @("identity", "github")
}

function Set-ProfileValues($P, [string]$A) {
    Set-IdentityValues $P
    $n = Read-JScalar $P @("profiles", $A, "name")
    if ($n.Found) { $script:Rm.name = $n.Text }
    $c = Read-JScalar $P @("profiles", $A, "company")
    if ($c.Found) { $script:Rm.company = $c.Text }
}

function Complete-Match($P, [string]$A, [string]$Via) {
    $script:RmAlias = $A; $script:RmVia = $Via
    Set-ProfileValues $P $A
    $pid_ = Get-JText $P @("profiles", $A, "machine", "id")
    if ($Via -ne "id" -and $Via -ne "environment" -and $script:ThisId -and $pid_ -and $pid_.ToLowerInvariant() -ne $script:ThisId.ToLowerInvariant()) {
        Add-Warn "profile `"$A`" is registered to another machine (machine.id $pid_, this machine $($script:ThisId))"
    }
    if ($Via -ne "id" -and $Via -ne "environment" -and $Via -ne "hostname" -and $script:ThisId -and -not $pid_) {
        Add-Warn "profile `"$A`" has no machine.id -- run: aitools user init (registers this machine)"
    }
    return 0
}

function Resolve-Machine($P, [string]$ConfigAlias) {
    $script:RmAlias = ""; $script:RmVia = "none"; $script:RmOverrideSource = ""; $script:Aliases = @()
    if ((Get-JText $P @("version")) -ne "2" -or (Get-JType $P @("profiles")) -ne "object") {
        Add-Err "profile.json is not v2 or has no profiles"; return 2
    }
    $all = Get-JKeys $P @("profiles")
    $script:Aliases = @($all | Where-Object { (Get-JType $P @("profiles", $_)) -eq "object" })
    if ($script:Aliases.Count -ne $all.Count) { Add-Warn "profile.json has profile entries that are not objects -- ignored" }
    if ($script:Aliases.Count -eq 0) { Add-Err "profile.json has no machine profiles"; return 2 }
    $csv = $script:Aliases -join ", "

    $override = $opt["alias"]
    if ($override) { $script:RmOverrideSource = "argument" }
    elseif ($env:AITOOLS_MACHINE_ALIAS) { $override = $env:AITOOLS_MACHINE_ALIAS; $script:RmOverrideSource = "env" }
    if ($override) {
        if ($script:Aliases -ccontains $override) { return (Complete-Match $P $override "override") }
        Add-Err "override alias `"$override`" not in profiles ($csv)"; return 2
    }

    if ($script:ThisEnv -eq "claude-code-web") {
        $m = @($script:Aliases | Where-Object { (Get-JText $P @("profiles", $_, "machine", "environment")) -ceq "claude-code-web" })
        if ($m.Count -eq 1) { return (Complete-Match $P $m[0] "environment") }
        if ($m.Count -gt 1) { Add-Err "more than one claude-code-web profile: $($m -join ', ')"; return 2 }
        Add-Warn "no profile has machine.environment `"claude-code-web`""
    } elseif ($script:ThisId) {
        $idl = $script:ThisId.ToLowerInvariant()
        $m = @($script:Aliases | Where-Object { $v = Get-JText $P @("profiles", $_, "machine", "id"); $v -and $v.ToLowerInvariant() -eq $idl })
        if ($m.Count -eq 1) {
            if ($ConfigAlias -and $ConfigAlias -cne $m[0]) {
                Add-Warn "config.json machineAlias `"$ConfigAlias`" disagrees with machine.id match `"$($m[0])`" -- machine.id wins"
            }
            return (Complete-Match $P $m[0] "id")
        }
        if ($m.Count -gt 1) { Add-Err "machine.id $($script:ThisId) is registered on more than one profile: $($m -join ', ')"; return 2 }
    }

    if ($ConfigAlias) {
        if ($script:Aliases -ccontains $ConfigAlias) { return (Complete-Match $P $ConfigAlias "alias") }
        Add-Warn "config.json machineAlias `"$ConfigAlias`" not in profiles ($csv)"
    }

    $m = @()
    if ($script:ThisHost) {
        $m = @($script:Aliases | Where-Object {
            $names = @(Get-JText $P @("profiles", $_, "machine", "hostname")) + @(Get-JItems $P @("profiles", $_, "machine", "hostnames"))
            @($names | Where-Object { $_ -and (ConvertTo-ShortHost $_) -eq $script:ThisHost }).Count -gt 0
        })
    }
    if ($m.Count -eq 1) {
        Add-Warn "matched by hostname only (legacy) -- run: aitools user init (registers machine.id)"
        return (Complete-Match $P $m[0] "hostname")
    }
    if ($m.Count -gt 1) { Add-Err "hostname matches more than one profile: $($m -join ', ')"; return 2 }
    $idText = if ($script:ThisId) { $script:ThisId } else { "unavailable" }
    $hostText = if ($script:ThisHost) { $script:ThisHost } else { "unavailable" }
    Add-Err "no profile matches this machine (machine.id $idText, hostname $hostText) -- run: aitools user init"
    return 2
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
function Invoke-UserRepoPath {
    Import-Config
    $rc = Resolve-UserRepo
    if ($script:OptPlain) {
        foreach ($w in $script:Warns) { [Console]::Error.WriteLine("warning: $w") }
        foreach ($e in $script:Errs) { [Console]::Error.WriteLine($e) }
        LogDetail "user-repo-path path=$($script:RurPath) via=$($script:RurVia) exit=$rc"
        if ($rc -eq 0) { Write-Output (Format-OutPath $script:RurPath) }
        exit $rc
    }
    Put "path" (Format-OutPath $script:RurPath)
    Put "via" $script:RurVia
    Put "expected" (Format-OutPath $script:RurExpected)
    Complete-Command $rc
}

function Invoke-MachineId {
    Find-MachineId
    if ($script:ThisIdError -or -not $script:ThisId) {
        $m = if ($script:ThisIdError) { $script:ThisIdError } else { "empty machine id" }
        LogDetail "machine-id error: $m"
        [Console]::Error.WriteLine("aitools-profile: $m")
        exit 2
    }
    LogDetail "machine-id source=$($script:ThisIdSource)"
    Write-Output $script:ThisId
    exit 0
}

function Invoke-Hostname {
    Find-Hostname
    if ($script:ThisHostError -or -not $script:ThisHost) {
        $m = if ($script:ThisHostError) { $script:ThisHostError } else { "empty hostname" }
        LogDetail "hostname error: $m"
        [Console]::Error.WriteLine("aitools-profile: $m")
        exit 2
    }
    Write-Output $script:ThisHost
    exit 0
}

function Add-IdentityLines {
    Put "name" $script:Rm.name; Put "company" $script:Rm.company; Put "gitName" $script:Rm.gitName
    Put "gitEmail" $script:Rm.gitEmail; Put "github" $script:Rm.github
}
function Add-ResolveHead([string]$ProfileFile) {
    Put "alias" $script:RmAlias; Put "via" $script:RmVia; Put "environment" $script:ThisEnv
    Put "machineId" $script:ThisId; Put "hostname" $script:ThisHost; Put "profileFile" (Format-OutPath $ProfileFile)
    Put "userRepoPath" (Format-OutPath $script:RurPath); Put "userRepoVia" $script:RurVia
}

function Invoke-Resolve {
    Import-Config
    Find-MachineId
    Find-Hostname
    if ($script:ThisIdError) { Add-Warn "machine id unavailable: $($script:ThisIdError)" }
    if ($script:ThisHostError) { Add-Warn "hostname unavailable: $($script:ThisHostError)" }
    $pf = $opt["profile"]
    $fromEnv = $false
    if (-not $pf -and $env:AITOOLS_PROFILE_FILE) { $pf = $env:AITOOLS_PROFILE_FILE; $fromEnv = $true }
    if ($pf) {
        if (-not (Test-Path -LiteralPath $pf -PathType Leaf)) {
            if ($fromEnv) { Add-Err "profile file set but missing: $pf (AITOOLS_PROFILE_FILE)" } else { Add-Err "profile file set but missing: $pf" }
            Add-ResolveHead $pf; Add-IdentityLines; Complete-Command 2
        }
    } else {
        $repoRc = Resolve-UserRepo
        if ($repoRc -ne 0) { Add-ResolveHead ""; Add-IdentityLines; Complete-Command $repoRc }
        $pf = Join-Path $script:RurPath "profile.json"
    }
    $r = Read-JsonFile $pf
    if ($r.State -eq "missing") { Add-Warn "profile.json not found: $pf"; Add-ResolveHead $pf; Add-IdentityLines; Complete-Command 1 }
    if ($r.State -eq "invalid") { Add-Err $r.Message; Add-ResolveHead $pf; Add-IdentityLines; Complete-Command 2 }
    $rc = Resolve-Machine $r.Value (Get-Cfg "machineAlias")
    # No machine match: report identity-level values only (never another profile's)
    if (-not $script:RmAlias) { Set-IdentityValues $r.Value }
    Add-ResolveHead $pf
    Add-IdentityLines
    Complete-Command $rc
}

function Invoke-DeriveConfig {
    Import-Config
    Find-MachineId
    Find-Hostname
    if ($script:ThisIdError) { Add-Warn "machine id unavailable: $($script:ThisIdError)" }
    if ($script:ThisHostError) { Add-Warn "hostname unavailable: $($script:ThisHostError)" }
    $d = @{ gh = ""; urp = ""; alias = "" }
    $putDerived = {
        Put "derived.githubUser" $d.gh; Put "derived.userRepoPath" $d.urp; Put "derived.machineAlias" $d.alias
        Put "userRepoVia" $script:RurVia; Put "via" $script:RmVia; Put "company" $script:Rm.company
        Put "machineId" $script:ThisId; Put "hostname" $script:ThisHost; Put "aliases" ($script:Aliases -join ", ")
    }
    $repoRc = Resolve-UserRepo
    if ($repoRc -eq 2) { & $putDerived; Complete-Command 2 }
    if ($repoRc -eq 1) {
        Add-Warn "no dotprofile found -- only bootstrap keys written (shared-only mode)"
        $d.gh = $opt["github-user"]
        & $putDerived; Complete-Command 1
    }
    # A value from an environment override is used for this run but not persisted:
    # config.json records the machine's own answer, not a test's or a caller's.
    if ($script:RurVia -ne "env") { $d.urp = $script:RurPath }
    else { Add-Warn "dotprofile from AITOOLS_USER_REPO_PATH -- not saved to config.json" }
    $pf = Join-Path $script:RurPath "profile.json"
    $r = Read-JsonFile $pf
    if ($r.State -eq "missing") { Add-Warn "profile.json not found in $($script:RurPath)"; $d.gh = $opt["github-user"]; & $putDerived; Complete-Command 1 }
    if ($r.State -eq "invalid") { Add-Err $r.Message; & $putDerived; Complete-Command 2 }
    $gh = $opt["github-user"]
    if (-not $gh) { $gh = Get-JText $r.Value @("identity", "github") }
    if (-not $gh) { $gh = Get-Cfg "githubUser" }
    $d.gh = $gh
    $rc = Resolve-Machine $r.Value (Get-Cfg "machineAlias")
    if ($script:RmAlias) {
        if ($script:RmVia -eq "override" -and $script:RmOverrideSource -eq "env") {
            Add-Warn "machine alias from AITOOLS_MACHINE_ALIAS -- not saved to config.json"
        } else {
            $d.alias = $script:RmAlias
        }
    } else {
        $script:Rm.company = ""
    }
    & $putDerived
    Complete-Command $rc
}

function Invoke-Snapshot {
    if (-not $opt["profile"]) { Stop-Usage "snapshot needs --profile" }
    $r = Read-JsonFile $opt["profile"]
    if ($r.State -eq "missing") { [Console]::Error.WriteLine("aitools-profile: profile.json not found: $($opt['profile'])"); exit 1 }
    if ($r.State -eq "invalid") { [Console]::Error.WriteLine("aitools-profile: $($r.Message)"); exit 2 }
    $snap = [ordered]@{}
    foreach ($k in @("version", "identity", "cursor", "profiles")) {
        $n = Get-JNode $r.Value @($k)
        $snap[$k] = if ($n.Found) { $n.Value } else { [PSCustomObject]@{} }
    }
    LogDetail "snapshot of $($opt['profile'])"
    Write-Output (ConvertTo-NodeJson $snap -Compress)
    exit 0
}

function Invoke-Register {
    $alias = $opt["alias"]
    if (-not $opt["profile"] -or -not $alias -or -not $opt["out"]) { Stop-Usage "register needs --profile, --alias and --out" }
    if ($alias -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { Stop-Usage "invalid alias: $alias" }
    $r = Read-JsonFile $opt["profile"]
    $created = $false
    if ($r.State -eq "invalid") { Add-Err $r.Message; Complete-Command 2 }
    if ($r.State -eq "missing") {
        if (-not $script:OptCreate) { Add-Err "profile.json not found (use --create): $($opt['profile'])"; Complete-Command 1 }
        $created = $true
        $git = [PSCustomObject]@{}
        $git | Add-Member -NotePropertyName name -NotePropertyValue $opt["name"]
        $git | Add-Member -NotePropertyName email -NotePropertyValue $opt["email"]
        $ident = [PSCustomObject]@{}
        $ident | Add-Member -NotePropertyName github -NotePropertyValue $opt["github-user"]
        $ident | Add-Member -NotePropertyName email -NotePropertyValue $opt["email"]
        if ($opt["name"]) { $ident | Add-Member -NotePropertyName name -NotePropertyValue $opt["name"] }
        if ($opt["company"]) { $ident | Add-Member -NotePropertyName company -NotePropertyValue $opt["company"] }
        $ident | Add-Member -NotePropertyName git -NotePropertyValue $git
        $p = [PSCustomObject]@{}
        $p | Add-Member -NotePropertyName version -NotePropertyValue 2
        $p | Add-Member -NotePropertyName identity -NotePropertyValue $ident
        $p | Add-Member -NotePropertyName profiles -NotePropertyValue ([PSCustomObject]@{})
    } else {
        $p = $r.Value
        if ((Get-JText $p @("version")) -ne "2") { Add-Err "profile.json is not v2 -- migrate first"; Complete-Command 2 }
        if ((Get-JType $p @("profiles")) -ne "object") { Set-JValue $p ([PSCustomObject]@{}) @("profiles") }
    }
    Find-Hostname
    if ($script:ThisEnv -ne "claude-code-web") {
        Find-MachineId
        if ($script:ThisIdError) { Add-Warn "$($script:ThisIdError) -- profile registered without machine.id" }
    }
    if ($script:ThisId -and -not $created) {
        $idl = $script:ThisId.ToLowerInvariant()
        foreach ($a in (Get-JKeys $p @("profiles"))) {
            if ($a -ceq $alias) { continue }
            $v = Get-JText $p @("profiles", $a, "machine", "id")
            if ($v -and $v.ToLowerInvariant() -eq $idl) { Add-Err "machine.id $($script:ThisId) is already registered on profile `"$a`""; Complete-Command 2 }
        }
    }
    $state = "created"
    $before = ""
    $t = Get-JType $p @("profiles", $alias)
    if ($t) {
        if ($t -ne "object") { Add-Err "profiles.$alias is not an object"; Complete-Command 2 }
        $state = "updated"
        $n = Get-JNode $p @("profiles", $alias, "machine")
        if ($n.Found) { $before = ConvertTo-NodeJson $n.Value -Compress }
    }
    # Per-profile name/company only when neither the profile nor identity has one
    if ($opt["name"] -and -not $created) {
        $hasProf = ($state -eq "updated") -and (Read-JScalar $p @("profiles", $alias, "name")).Found
        $hasIdent = (Read-JScalar $p @("identity", "name")).Found
        if (-not $hasProf -and -not $hasIdent) { Set-JValue $p $opt["name"] @("profiles", $alias, "name") }
    }
    if ($opt["company"] -and -not $created) {
        $hasProf = ($state -eq "updated") -and (Read-JScalar $p @("profiles", $alias, "company")).Found
        $hasIdent = (Read-JScalar $p @("identity", "company")).Found
        if (-not $hasProf -and -not $hasIdent) { Set-JValue $p $opt["company"] @("profiles", $alias, "company") }
    }
    if ($script:ThisId) { Set-JValue $p $script:ThisId @("profiles", $alias, "machine", "id") }
    if ($script:ThisEnv -eq "claude-code-web") { Set-JValue $p "claude-code-web" @("profiles", $alias, "machine", "environment") }
    if (-not (Get-JText $p @("profiles", $alias, "machine", "hostname")) -and $script:ThisHost) {
        Set-JValue $p $script:ThisHost @("profiles", $alias, "machine", "hostname")
    }
    $os = switch ($script:AitoolsPlatform) { "windows" { "win32" } "macos" { "darwin" } default { $script:AitoolsPlatform } }
    $arch = ([string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToLowerInvariant()
    Set-JValue $p $os @("profiles", $alias, "machine", "os")
    Set-JValue $p $arch @("profiles", $alias, "machine", "arch")
    if ($opt["shell"]) { Set-JValue $p $opt["shell"] @("profiles", $alias, "machine", "shell") }
    try {
        [IO.File]::WriteAllText($opt["out"], (ConvertTo-NodeJson $p) + "`n", $script:Utf8NoBom)
    } catch {
        Add-Err "register failed: cannot write $($opt['out']): $($_.Exception.Message)"; Complete-Command 2
    }
    $v = Read-JsonFile $opt["out"]
    if ($v.State -ne "valid" -or (Get-JType $v.Value @("profiles", $alias)) -ne "object") {
        Add-Err "validation failed: profile $alias missing after write"; Complete-Command 2
    }
    $after = ConvertTo-NodeJson (Get-JNode $v.Value @("profiles", $alias, "machine")).Value -Compress
    if ($state -eq "updated" -and $before -ceq $after) { $state = "unchanged" }
    Put "result" $state
    Put "alias" $alias
    Put "machineId" $script:ThisId
    Put "hostname" $script:ThisHost
    Complete-Command 0
}

switch -CaseSensitive ($script:Cmd) {
    "user-repo-path" { Invoke-UserRepoPath }
    "machine-id" { Invoke-MachineId }
    "hostname" { Invoke-Hostname }
    "resolve" { Invoke-Resolve }
    "derive-config" { Invoke-DeriveConfig }
    "snapshot" { Invoke-Snapshot }
    "register" { Invoke-Register }
    "" { Show-Usage; exit 2 }
    default { Stop-Usage "unknown command: $($script:Cmd)" }
}
