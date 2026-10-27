# aitools-profile.ps1 -- the one resolver for "where is my dotprofile" and
# "which machine profile is this machine" (Windows; on macOS/Linux use
# aitools-profile.sh, which implements the same commands, options and output).
#
# Intent: Resolve, deterministically and with a stated reason ("via"), the
# dotprofile repo path and this machine's profile in profile.json, and derive
# the config.json values that come from them. NOT a writer of config.json
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves, the `exception-set` subcommand, the only writer
# of toolExceptions, and the `migrate` subcommand, which re-keys profiles by
# machine id; those two write in place (temp, validate, backup, move) and commit
# and push profile.json. NOT the settings.json sync
# (Sync-ManagedJson). Consumed by: the PowerShell shared-lib wrappers
# Resolve-UserRepoPath / Resolve-MachineProfile / Get-ToolException /
# Set-ToolException, setup-user-config.ps1, aitools.ps1 `user init`, and the
# generated deploy/setup-user-claude.ps1, setup-user-settings.ps1 and
# setup-user-cursor.ps1 (embedded copies).
#
# Usage: aitools-profile.ps1 <command> [options]   (--help for details)
#   In-process: $out = & aitools-profile.ps1 resolve; $rc = $LASTEXITCODE
# Machine profiles (profile.json revision 2.2, re-key design): keyed by this
#   machine's raw id, lower-cased (`profiles.<machineId>`; `machine.id` repeats
#   the key), or `environment:<name>` for an environment without a stable id
#   (claude-code-web). The human-readable name is the profile's `alias` field.
#   Profiles keyed by alias (revision 2.1, "legacy") are still read; `migrate`
#   re-keys them. Key lookups ignore case; `alias` lookups do not.
# Exit codes: 0 resolved / ok; 1 nothing found (expected states, e.g. before
#   `aitools user init`); 2 error (bad input, unreadable or invalid JSON,
#   ambiguous match, machine id on two profiles); 3 refused (exception-set
#   without a profile registered to this machine; register without a machine
#   id; a write to an AITOOLS_PROFILE_FILE snapshot); 4 refused (register: the
#   alias is used by another profile; pass --allow-duplicate-alias only after an
#   interactive confirm). Callers must not pass 2 through as their own exit
#   code: exit 2 from a setup script means a user abort (D-TS13).
# Output: data on the success stream only -- key<TAB>value lines (default) or
#   one JSON object (--json). Diagnostics go to deploy.log and stderr.
#   Logging contract (library-style tool): every warning and error is returned
#   as a `warn` / `error` line (and logged at detail); the caller logs each at
#   its level and owns the summary rows and counters.
# Machine fields in resolve / derive-config / exception-get output:
#   key (the profiles key that matched), alias (its alias field, else the key),
#   via (override|environment|id|config|alias|hostname|none), owner (this |
#   other | unregistered | unknown | absent: whose profile it is; unknown = it
#   has a machine.id but this machine's id cannot be detected), legacy (true
#   when the profile is still keyed by alias). exception-get returns only this
#   machine's decisions (owner this); another profile's are ignored with a warning.
# JSON: ConvertFrom-Json / ConvertTo-Json (PS 7). Key order is kept and the
#   written layout (2-space indent, LF) is byte-identical to node and to the
#   bash engine for strings, integers, booleans and null (what profile.json
#   holds). Known PowerShell-side limits: property names are case-insensitive
#   (keys differing only in case, or an empty key, are rejected), and
#   non-integer number literals are re-formatted. Path lookups (Get-JNode) are
#   case-sensitive, as in the perl engine; the case-insensitive profile-key
#   lookups are explicit (ConvertTo-AsciiLower).
# Safe to re-run: every command except `register`, `exception-set` and
#   `migrate` is read-only; `register` writes only the --out file;
#   `exception-set` rewrites one toolExceptions entry and reports "unchanged"
#   when it is identical; `migrate` reports "unchanged" once every profile is
#   keyed by id.
# Platform: Windows. Reference: reference/user-repo.md "Resolution".
# Decisions: P-Q2 (raw machine ids), P-Q3 (native bash + PowerShell, no node).
# Tests only: AITOOLS_PROFILE_TEST_ANY_OS=1 lets the parity tests run this file
#   with pwsh on macOS/Linux, always with --machine-id-value and --hostname-value.

$cliArgs = @($args)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Console]::Error.WriteLine("aitools-profile: PowerShell 7 (pwsh) is required; this is $($PSVersionTable.PSVersion)")
    exit 1
}
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
# The success stream carries data: console log lines go to stderr (deploy.log unchanged).
# Defined before Initialize-Logging, whose environment check may already log a warning.
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    $resolvedLog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logFile)
    [IO.File]::AppendAllText($resolvedLog, "$line`n", [System.Text.UTF8Encoding]::new($false))
    [Console]::Error.WriteLine($line)
}
Initialize-Logging "aitools-profile"

# Any exception that escapes a command is an error (exit 2), never "not found" (1)
trap {
    LogDetail "unhandled: $($_.Exception.Message)"
    [Console]::Error.WriteLine("aitools-profile: $($_.Exception.Message)")
    exit 2
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows -and $env:AITOOLS_PROFILE_TEST_ANY_OS -ne "1") {
    LogError "This script is for Windows. On macOS/Linux, use aitools-profile.sh."
    exit 1
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
  resolve         Which profile this machine uses and why (key, alias, via,
                  owner, legacy). Options: --config F, --profile F,
                  --alias A (a profiles key, else an alias field), --environment E
  derive-config   The config.json values derived from profile.json
                  (derived.machineId, derived.machineAlias). Options: --config F,
                  --github-user U, --user-repo-path P, --repos-path P,
                  --alias A, --environment E
  snapshot        Compact JSON of version, identity, cursor, profiles from
                  --profile F (for embedding in generated deploy scripts)
  register        Write --profile F with this machine's profile,
                  profiles.<machine id> (claude-code-web: environment:<name>),
                  to --out TMP. Options: --alias A (default: short hostname),
                  --allow-duplicate-alias (after an interactive confirm only),
                  --claim KEY (move an alias-keyed profile without machine.id
                  under this machine's key; after an interactive choice only),
                  --name N, --company C, --shell S, --environment E,
                  --create (new profile.json; with --github-user U, --email E).
                  Exit 3 = no machine id; exit 4 = alias used by another profile
  migrate         Re-key alias-keyed profiles by machine.id (alias = old key):
                  --profile F (default: the dotprofile's), --dry-run. Writes
                  in place (temp, validate, backup, move), commits, pushes
  exception-get   This machine's recorded tool exception for --slug S (found
                  true/false and the stored fields). Options: --config F,
                  --profile F, --alias A, --environment E
  exception-set   Record a [k]eep decision for --slug S: --platform P, --method M,
                  --path PATH, --version V, --by SCRIPT [--reason R]
                  [--decided-at UTC]. Writes profile.json in place (temp,
                  validate, backup, move), then commits profile.json and pushes.
                  Exit 3 = refused (no dotprofile, or no profile registered to
                  this machine: matched by hostname, cache or another machine)

Output: key<TAB>value lines; --json prints one JSON object instead.
Environment: AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS, AITOOLS_PROFILE_FILE,
  AITOOLS_ENVIRONMENT (see reference/user-repo.md "Resolution").
Test options: --machine-id-value ID, --hostname-value NAME (replace detection;
  --machine-id-value none = no detectable id).
Exit: 0 ok, 1 not found, 2 error, 3 refused, 4 refused (alias in use).
'@ -split "`n" | ForEach-Object { Write-Output ($_ -replace "`r$", "") }
}

# JSON helpers: aitools-json.ps1 (the PowerShell counterpart of aitools-json.pl)
. (Join-Path $PSScriptRoot "aitools-json.ps1")

# Read-ResolverJson PATH -- Read-JsonFile, except that a UTF-16 file is invalid
# with the bash resolver's message (perl cannot decode it; .NET would)
function Read-ResolverJson([string]$Path) {
    $r = Read-JsonFile $Path
    if ($r.State -ne "valid") { return $r }
    $head = [byte[]]::new(2); $n = 0
    try {
        $fs = [IO.File]::OpenRead($Path)
        try { $n = $fs.Read($head, 0, 2) } finally { $fs.Dispose() }
    } catch {
        return @{ State = "invalid"; Value = $null; Message = "cannot read ${Path}: $($_.Exception.Message)" }
    }
    if ($n -eq 2 -and (($head[0] -eq 0xFF -and $head[1] -eq 0xFE) -or ($head[0] -eq 0xFE -and $head[1] -eq 0xFF))) {
        return @{ State = "invalid"; Value = $null; Message = "$Path is UTF-16 encoded, not UTF-8 -- save it as UTF-8" }
    }
    return $r
}

# Expand-Home PATH -- a leading ~ (alone, ~/ or ~\) becomes $HOME, as in the bash resolver
function Expand-Home([string]$p) {
    if ($p -ceq "~") { return $HOME }
    if ($p.StartsWith("~/") -or $p.StartsWith("~\")) { return (Join-Path $HOME $p.Substring(2)) }
    return $p
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
# Option names are case-sensitive, as in bash (an ordinal dictionary, not a hashtable)
$opt = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
foreach ($k in @("config", "profile", "alias", "environment", "github-user", "user-repo-path", "repos-path",
        "name", "company", "shell", "email", "out", "machine-id-value", "hostname-value",
        "slug", "platform", "method", "path", "version", "by", "reason", "decided-at", "claim")) { $opt[$k] = "" }
$opt["path-form"] = "native"
$script:OptCreate = $false; $script:OptJson = $false; $script:OptPlain = $false
$script:OptDryRun = $false; $script:OptAllowDup = $false
for ($i = 1; $i -lt $cliArgs.Count; $i++) {
    $a = [string]$cliArgs[$i]
    switch -CaseSensitive ($a) {
        "--create" { $script:OptCreate = $true; continue }
        "--json" { $script:OptJson = $true; continue }
        "--plain" { $script:OptPlain = $true; continue }
        "--dry-run" { $script:OptDryRun = $true; continue }
        "--allow-duplicate-alias" { $script:OptAllowDup = $true; continue }
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

# Paths: resolve against the PowerShell location, because .NET file APIs use the
# process working directory, which differs when this runs in-process (& script)
# after Set-Location (cross-platform.md ".NET working directory").
function Resolve-OptPath([string]$p) {
    if (-not $p) { return $p }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
}
foreach ($k in @("config", "profile", "out", "user-repo-path", "repos-path")) { $opt[$k] = Resolve-OptPath $opt[$k] }

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
# Tests only: AITOOLS_PROFILE_TEST_MACHINE_ID / AITOOLS_PROFILE_TEST_HOSTNAME act as
# --machine-id-value / --hostname-value for callers that do not pass options
# (setup-user-config tests).
if (-not $opt["machine-id-value"] -and $env:AITOOLS_PROFILE_TEST_MACHINE_ID) { $opt["machine-id-value"] = $env:AITOOLS_PROFILE_TEST_MACHINE_ID }
if (-not $opt["hostname-value"] -and $env:AITOOLS_PROFILE_TEST_HOSTNAME) { $opt["hostname-value"] = $env:AITOOLS_PROFILE_TEST_HOSTNAME }
function Find-MachineId {
    # Tests: the value "none" stands for "this machine's id cannot be detected"
    if ($opt["machine-id-value"] -ceq "none") { $script:ThisId = ""; $script:ThisIdError = "no machine id (test value)"; return }
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
# ConvertTo-ShortHost NAME -- text before the first dot, ends trimmed, ASCII
# lower-cased (the same rule as short_host in aitools-profile.sh)
function ConvertTo-ShortHost([string]$h) {
    $s = ((([string]$h) -split '\.')[0]).Trim([char[]]" `t`r`n")
    return [regex]::Replace($s, '[A-Z]', { param($m) $m.Value.ToLowerInvariant() })
}
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
    $r = Read-ResolverJson $script:CfgFile
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
    $p = Expand-Home (Get-Cfg "userRepoPath")
    if ($p) {
        if (Test-Path -LiteralPath $p -PathType Container) { $script:RurPath = Remove-TrailingSlash $p; $script:RurVia = "config"; return 0 }
        Add-Warn "config.json userRepoPath does not exist: $p"
    }
    $base = $opt["repos-path"]
    if (-not $base) { $base = Expand-Home (Get-Cfg "reposPath") }
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
# Which machine profile (reference/user-repo.md "Which machine profile"; re-key
# design section b), first decisive step wins:
#   1 override (--alias, AITOOLS_MACHINE_ALIAS): a profiles key (ignoring
#     case), else an alias field; one alias on two profiles = error  via=override
#   2 environment claude-code-web: key environment:claude-code-web
#     (legacy: the profile whose machine.environment matches)         via=environment
#   3 profiles[<this machine's id>] (legacy: the alias-keyed profile
#     whose machine.id equals it; warns: migrate)                     via=id
#   4 config.json machineId, only when this machine's id is unknown  via=config
#   4L config.json machineAlias naming an alias-keyed profile without
#     machine.id (legacy cache; skipped when config.json has machineId) via=alias
#   5 hostname (legacy; warns)                                        via=hostname
#   6 none: error; never another profile's values
# Returns 0 resolved, 2 no match or error.
# ---------------------------------------------------------------------------
$script:RmKey = ""; $script:RmAlias = ""; $script:RmVia = "none"; $script:RmOwner = "absent"; $script:RmLegacy = "false"
$script:RmKind = ""; $script:RmOverrideSource = ""
$script:Rm = @{ name = ""; company = ""; gitName = ""; gitEmail = ""; github = "" }

# ConvertTo-AsciiLower TEXT -- ASCII lower case (the same rule as lc in the .sh)
function ConvertTo-AsciiLower([string]$s) {
    return [regex]::Replace([string]$s, '[A-Z]', { param($m) $m.Value.ToLowerInvariant() })
}

# Profile entries (objects only), in file order. Kind: id (key equals its
# machine.id, ignoring case), env (key environment:<name>), legacy (keyed by
# alias). Alias: the alias field, else the key.
$script:Entries = @()
function Import-Entries($P) {
    $list = [System.Collections.Generic.List[object]]::new()
    $ignored = $false
    foreach ($k in (Get-JKeys $P @("profiles"))) {
        if (-not $k) { continue }
        if ((Get-JType $P @("profiles", $k)) -ne "object") { $ignored = $true; continue }
        $al = Get-JText $P @("profiles", $k, "alias")
        $mid = Get-JText $P @("profiles", $k, "machine", "id")
        $e = [ordered]@{
            Key = $k; KeyLc = (ConvertTo-AsciiLower $k); Mid = $mid; MidLc = (ConvertTo-AsciiLower $mid)
            Env = (Get-JText $P @("profiles", $k, "machine", "environment")); HasAlias = [bool]$al
            Alias = $(if ($al) { $al } else { $k }); Kind = "legacy"
        }
        $e.AliasLc = ConvertTo-AsciiLower $e.Alias
        if ($e.KeyLc.StartsWith("environment:")) { $e.Kind = "env" }
        elseif ($mid -and $e.MidLc -ceq $e.KeyLc) { $e.Kind = "id" }
        $list.Add($e)
    }
    if ($ignored) { Add-Warn "profile.json has profile entries that are not objects -- ignored" }
    $script:Entries = $list.ToArray()
}
function Get-AliasCsv { return (@($script:Entries | ForEach-Object { $_.Alias }) -join ", ") }
function Get-KeysCsv($List) { return (@($List | ForEach-Object { $_.Key }) -join ", ") }

# Test-LooksLikeId TEXT -- the shape of a machine id (a UUID, as IOPlatformUUID and
# MachineGuid, or 32 hex digits, as /etc/machine-id)
function Test-LooksLikeId([string]$s) {
    $l = ConvertTo-AsciiLower $s
    return ($l -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -or $l -cmatch '^[0-9a-f]{32}$')
}

# Get-EntryOwner ENTRY VIA -- this | other | unregistered | unknown: whose profile it
# is (unknown: it has a machine.id, but this machine's id cannot be detected)
function Get-EntryOwner($E, [string]$Via) {
    if ($E.Kind -eq "env") { if ($E.KeyLc -ceq "environment:$($script:ThisEnv)") { return "this" } else { return "other" } }
    if ($Via -eq "environment") { return "this" }
    if (-not $E.Mid) {
        if ($E.Kind -eq "legacy" -and $script:ThisId -and $E.KeyLc -ceq (ConvertTo-AsciiLower $script:ThisId)) { return "this" }
        return "unregistered"
    }
    if (-not $script:ThisId) {
        # This machine's id is unknown: only the cached key (config.json machineId) vouches for it
        if ($Via -eq "config") { return "this" } else { return "unknown" }
    }
    if ($E.MidLc -ceq (ConvertTo-AsciiLower $script:ThisId)) { return "this" }
    return "other"
}

function Set-IdentityValues($P) {
    $n = Read-JScalar $P @("identity", "name")
    $script:Rm.name = if ($n.Found) { $n.Text } else { Get-JText $P @("identity", "git", "name") }
    $script:Rm.company = Get-JText $P @("identity", "company")
    $script:Rm.gitName = Get-JText $P @("identity", "git", "name")
    $script:Rm.gitEmail = Get-JText $P @("identity", "git", "email")
    $script:Rm.github = Get-JText $P @("identity", "github")
}

function Set-ProfileValues($P, [string]$K) {
    Set-IdentityValues $P
    $n = Read-JScalar $P @("profiles", $K, "name")
    if ($n.Found) { $script:Rm.name = $n.Text }
    $c = Read-JScalar $P @("profiles", $K, "company")
    if ($c.Found) { $script:Rm.company = $c.Text }
}

# Complete-Match P ENTRY VIA -- ENTRY is this run's profile: values, owner, warnings
function Complete-Match($P, $E, [string]$Via) {
    $script:RmKey = $E.Key; $script:RmAlias = $E.Alias; $script:RmVia = $Via; $script:RmKind = $E.Kind
    $script:RmOwner = Get-EntryOwner $E $Via
    $script:RmLegacy = if ($E.Kind -eq "legacy") { "true" } else { "false" }
    Set-ProfileValues $P $E.Key
    $a = $E.Alias
    if ($Via -ne "id" -and $Via -ne "environment" -and $E.Kind -ne "env") {
        if ($script:RmOwner -eq "other" -and $script:ThisId) {
            Add-Warn "profile `"$a`" is registered to another machine (machine.id $($E.Mid), this machine $($script:ThisId))"
        }
        if ($Via -ne "hostname" -and $script:ThisId -and -not $E.Mid) {
            Add-Warn "profile `"$a`" has no machine.id -- run: aitools user init (registers this machine)"
        }
    }
    # A cloned machine shares its id: a differing stored hostname is the only signal
    if ($Via -eq "id" -and $script:ThisHost) {
        $names = @(@(Get-JText $P @("profiles", $E.Key, "machine", "hostname")) + @(Get-JItems $P @("profiles", $E.Key, "machine", "hostnames")) | Where-Object { $_ })
        if ($names.Count -gt 0 -and @($names | Where-Object { (ConvertTo-ShortHost $_) -ceq $script:ThisHost }).Count -eq 0) {
            Add-Warn "profile `"$a`" was registered with hostname `"$($names[0])`", this machine is `"$($script:ThisHost)`" -- renamed (run: aitools user init to update it), or a clone that shares machine id $($script:ThisId)"
        }
    }
    # An alias on two profiles (allowed after an interactive confirm) warns on every run
    $dups = @($script:Entries | Where-Object { $_.Alias -ceq $a })
    if ($dups.Count -gt 1) { Add-Warn "alias `"$a`" is used by $($dups.Count) machines ($(Get-KeysCsv $dups))" }
    return 0
}

function Resolve-Machine($P, [string]$ConfigId, [string]$ConfigAlias) {
    $script:RmKey = ""; $script:RmAlias = ""; $script:RmVia = "none"; $script:RmOwner = "absent"; $script:RmLegacy = "false"
    $script:RmKind = ""; $script:RmOverrideSource = ""
    # Two states, two messages (callers tell them apart; PR #98 review m1)
    if ((Get-JText $P @("version")) -ne "2") { Add-Err "profile.json is not v2"; return 2 }
    if ((Get-JType $P @("profiles")) -ne "object") { Add-Err "profile.json has no profiles object"; return 2 }
    Import-Entries $P
    $E = $script:Entries
    if ($E.Count -eq 0) { Add-Err "profile.json has no machine profiles"; return 2 }

    $override = $opt["alias"]
    if ($override) { $script:RmOverrideSource = "argument" }
    elseif ($env:AITOOLS_MACHINE_ALIAS) { $override = $env:AITOOLS_MACHINE_ALIAS; $script:RmOverrideSource = "env" }
    if ($override) {
        $ol = ConvertTo-AsciiLower $override
        $kh = @($E | Where-Object { $_.KeyLc -ceq $ol })
        if ($kh.Count -eq 1) { return (Complete-Match $P $kh[0] "override") }
        if ($kh.Count -gt 1) { Add-Err "override `"$override`" matches more than one profile key: $(Get-KeysCsv $kh)"; return 2 }
        $lh = @($E | Where-Object { $_.Alias -ceq $override })
        if ($lh.Count -eq 1) { return (Complete-Match $P $lh[0] "override") }
        if ($lh.Count -gt 1) { Add-Err "alias `"$override`" is used by more than one profile: $(Get-KeysCsv $lh) -- select one by its key"; return 2 }
        Add-Err "override alias `"$override`" not in profiles ($(Get-AliasCsv))"; return 2
    }

    if ($script:ThisEnv -eq "claude-code-web") {
        $kh = @($E | Where-Object { $_.KeyLc -ceq "environment:claude-code-web" })
        $lh = @($E | Where-Object { $_.KeyLc -cne "environment:claude-code-web" -and $_.Kind -ne "env" -and $_.Env -ceq "claude-code-web" })
        if ($kh.Count -eq 1) { return (Complete-Match $P $kh[0] "environment") }
        if ($lh.Count -eq 1) {
            Add-Warn "profile `"$($lh[0].Key)`" is keyed by alias -- run: aitools-profile migrate (re-keys profiles by machine id)"
            return (Complete-Match $P $lh[0] "environment")
        }
        if ($lh.Count -gt 1) { Add-Err "more than one claude-code-web profile: $(Get-KeysCsv $lh)"; return 2 }
        Add-Warn "no profile has machine.environment `"claude-code-web`""
    } elseif ($script:ThisId) {
        $idl = ConvertTo-AsciiLower $script:ThisId
        $hits = @($E | Where-Object { $_.KeyLc -ceq $idl -or ($_.Mid -and $_.MidLc -ceq $idl) })
        if ($hits.Count -eq 1) {
            $h = $hits[0]
            if ($h.KeyLc -cne $idl) {
                Add-Warn "profile `"$($h.Key)`" is keyed by alias -- run: aitools-profile migrate (re-keys profiles by machine id)"
            } elseif ($h.Mid -and $h.MidLc -cne $idl) {
                Add-Warn "profile key `"$($h.Key)`" disagrees with its machine.id `"$($h.Mid)`" -- fix profile.json by hand"
            }
            if ($ConfigId -and (ConvertTo-AsciiLower $ConfigId) -cne $h.KeyLc) {
                Add-Warn "config.json machineId `"$ConfigId`" disagrees with machine.id match `"$($h.Key)`" -- machine.id wins"
            } elseif (-not $ConfigId -and $ConfigAlias -and $ConfigAlias -cne $h.Alias -and $ConfigAlias -cne $h.Key) {
                Add-Warn "config.json machineAlias `"$ConfigAlias`" disagrees with machine.id match `"$($h.Alias)`" -- machine.id wins"
            }
            return (Complete-Match $P $h "id")
        }
        if ($hits.Count -gt 1) { Add-Err "machine.id $($script:ThisId) is registered on more than one profile: $(Get-KeysCsv $hits)"; return 2 }
    }

    # 4: the cached key, only when this machine's id cannot be detected
    if ($script:ThisEnv -ne "claude-code-web" -and -not $script:ThisId -and $ConfigId) {
        $cl = ConvertTo-AsciiLower $ConfigId
        $hits = @($E | Where-Object { $_.KeyLc -ceq $cl })
        if ($hits.Count -eq 1) { return (Complete-Match $P $hits[0] "config") }
        Add-Warn "config.json machineId `"$ConfigId`" not in profiles -- ignored"
    }

    # 4L: legacy cache (config.json machineAlias names an alias-keyed profile)
    if (-not $ConfigId -and $ConfigAlias) {
        $hits = @($E | Where-Object { $_.Kind -eq "legacy" -and $_.Key -ceq $ConfigAlias })
        if ($hits.Count -gt 0) {
            $h = $hits[0]
            if ($h.Mid -and $script:ThisId -and $h.MidLc -cne (ConvertTo-AsciiLower $script:ThisId)) {
                Add-Warn "config.json machineAlias `"$ConfigAlias`" names a profile registered to another machine (machine.id $($h.Mid)) -- ignored"
            } else {
                return (Complete-Match $P $h "alias")
            }
        } else {
            Add-Warn "config.json machineAlias `"$ConfigAlias`" not in profiles ($(Get-AliasCsv))"
        }
    }

    $m = @()
    if ($script:ThisHost) {
        $m = @($E | Where-Object {
            $names = @(Get-JText $P @("profiles", $_.Key, "machine", "hostname")) + @(Get-JItems $P @("profiles", $_.Key, "machine", "hostnames"))
            @($names | Where-Object { $_ -and (ConvertTo-ShortHost $_) -ceq $script:ThisHost }).Count -gt 0
        })
    }
    if ($m.Count -eq 1) {
        Add-Warn "matched by hostname only (legacy) -- run: aitools user init (registers machine.id)"
        return (Complete-Match $P $m[0] "hostname")
    }
    if ($m.Count -gt 1) { Add-Err "hostname matches more than one profile: $(Get-KeysCsv $m)"; return 2 }
    $idText = if ($script:ThisId) { $script:ThisId } else { "unavailable" }
    $hostText = if ($script:ThisHost) { $script:ThisHost } else { "unavailable" }
    Add-Err "no profile matches this machine (machine.id $idText, hostname $hostText) -- run: aitools user init"
    return 2
}

# Resolve-This P -- Resolve-Machine with the config.json cache values
function Resolve-This($P) { return (Resolve-Machine $P (Get-Cfg "machineId") (Get-Cfg "machineAlias")) }

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
# Add-MatchLines -- the machine fields of a resolution (key, owner, legacy)
function Add-MatchLines { Put "key" $script:RmKey; Put "owner" $script:RmOwner; Put "legacy" $script:RmLegacy }
function Add-ResolveHead([string]$ProfileFile) {
    Put "alias" $script:RmAlias; Put "via" $script:RmVia; Add-MatchLines; Put "environment" $script:ThisEnv
    Put "machineId" $script:ThisId; Put "hostname" $script:ThisHost; Put "profileFile" (Format-OutPath $ProfileFile)
    Put "userRepoPath" (Format-OutPath $script:RurPath); Put "userRepoVia" $script:RurVia
}

# Find-ThisMachine -- machine id + hostname, unavailability reported as warnings
function Find-ThisMachine {
    Find-MachineId
    Find-Hostname
    if ($script:ThisIdError) { Add-Warn "machine id unavailable: $($script:ThisIdError)" }
    if ($script:ThisHostError) { Add-Warn "hostname unavailable: $($script:ThisHostError)" }
}

# Find-ProfileFile -- $script:Pf = the profile.json to read: --profile, else
# AITOOLS_PROFILE_FILE, else <dotprofile>\profile.json; $script:PfFromEnv for
# AITOOLS_PROFILE_FILE (a read-only snapshot in generated deploy scripts);
# $script:PfValue = the parsed file. Returns 0 readable, 1 none (shared-only
# mode), 2 error.
$script:Pf = ""; $script:PfFromEnv = $false; $script:PfValue = $null
function Find-ProfileFile {
    $script:Pf = $opt["profile"]; $script:PfFromEnv = $false; $script:PfValue = $null
    if (-not $script:Pf -and $env:AITOOLS_PROFILE_FILE) { $script:Pf = $env:AITOOLS_PROFILE_FILE; $script:PfFromEnv = $true }
    if ($script:Pf) {
        if (-not (Test-Path -LiteralPath $script:Pf -PathType Leaf)) {
            if ($script:PfFromEnv) { Add-Err "profile file set but missing: $($script:Pf) (AITOOLS_PROFILE_FILE)" }
            else { Add-Err "profile file set but missing: $($script:Pf)" }
            return 2
        }
    } else {
        $repoRc = Resolve-UserRepo
        if ($repoRc -ne 0) { return $repoRc }
        $script:Pf = Join-Path $script:RurPath "profile.json"
    }
    $r = Read-ResolverJson $script:Pf
    if ($r.State -eq "missing") { Add-Warn "profile.json not found: $($script:Pf)"; return 1 }
    if ($r.State -eq "invalid") { Add-Err $r.Message; return 2 }
    $script:PfValue = $r.Value
    return 0
}

function Invoke-Resolve {
    Import-Config
    Find-ThisMachine
    $rc = Find-ProfileFile
    if ($rc -ne 0) { Add-ResolveHead $script:Pf; Add-IdentityLines; Complete-Command $rc }
    $rc = Resolve-This $script:PfValue
    # No machine match: report identity-level values only (never another profile's)
    if (-not $script:RmKey) { Set-IdentityValues $script:PfValue }
    Add-ResolveHead $script:Pf
    Add-IdentityLines
    Complete-Command $rc
}

# ---------------------------------------------------------------------------
# Tool exceptions (reference/tool-support-decision-tree.md section 8; storage
# shape in reference/user-repo.md "Profile Schema"). Location:
# profiles.<key>.toolExceptions.<slug>, <key> = this machine's resolved profile
# (its machine id; a legacy alias key until `migrate`).
# exception-get returns the stored entry; matching it against the detected
# install (platform, method, path unless versionedPath) is the caller's job,
# because it needs the registry.
# ---------------------------------------------------------------------------
function Test-Slug {
    if (-not $opt["slug"]) { Stop-Usage "$($script:Cmd) needs --slug" }
    if ($opt["slug"] -cnotmatch '^[a-z0-9][a-z0-9._-]*$') { Stop-Usage "invalid slug: $($opt['slug'])" }
}

function Invoke-ExceptionGet {
    Test-Slug
    Import-Config
    Find-ThisMachine
    $e = [ordered]@{ found = "false"; platform = ""; method = ""; path = ""; version = ""; decidedAt = ""; decidedBy = ""; reason = "" }
    $putExc = {
        Put "slug" $opt["slug"]; Put "alias" $script:RmAlias; Put "via" $script:RmVia; Add-MatchLines; Put "profileFile" $script:Pf
        foreach ($k in $e.Keys) { Put $k $e[$k] }
    }
    $rc = Find-ProfileFile
    if ($rc -ne 0) { & $putExc; Complete-Command $rc }
    $rc = Resolve-This $script:PfValue
    if ($rc -ne 0) { & $putExc; Complete-Command $rc }
    $slug = $opt["slug"]
    $base = @("profiles", $script:RmKey, "toolExceptions", $slug)
    $t = Get-JType $script:PfValue $base
    # Never another machine's decision (R18): only this machine's profile counts
    if ($t -and $script:RmOwner -ne "this") {
        Add-Warn "toolExceptions.$slug in profile `"$($script:RmAlias)`" is not this machine's (owner $($script:RmOwner)) -- ignored"
        $t = ""
    }
    if ($t -eq "object") {
        $decision = Get-JText $script:PfValue ($base + "decision")
        if ($decision -ceq "keep") {
            $e.found = "true"
            $e.platform = Get-JText $script:PfValue ($base + @("detected", "platform"))
            $e.method = Get-JText $script:PfValue ($base + @("detected", "method"))
            $e.path = Get-JText $script:PfValue ($base + @("detected", "path"))
            $e.version = Get-JText $script:PfValue ($base + @("detected", "version"))
            $e.decidedAt = Get-JText $script:PfValue ($base + "decidedAt")
            $e.decidedBy = Get-JText $script:PfValue ($base + "decidedBy")
            $e.reason = Get-JText $script:PfValue ($base + "reason")
        } else {
            Add-Warn "toolExceptions.$slug in profile `"$($script:RmAlias)`" has decision `"$decision`" (only `"keep`" is defined) -- ignored"
        }
    } elseif ($t) {
        Add-Warn "toolExceptions.$slug in profile `"$($script:RmAlias)`" is not an object -- ignored"
    }
    & $putExc
    Complete-Command 0
}

# Test-ProfileDirtyBefore DIR -- $true when profile.json has uncommitted changes in
# git (checked BEFORE this command writes, so an unrelated hand edit is not
# committed under this command's message); $false when clean, untracked or not a
# repository.
function Test-ProfileDirtyBefore([string]$Dir) {
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { return $false }
    $null = & git -C $Dir rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0) { return $false }   # not a repo: Invoke-ProfileCommit reports it
    $null = & git -C $Dir ls-files --error-unmatch -- profile.json 2>&1
    if ($LASTEXITCODE -ne 0) { return $false }   # untracked: nothing to protect
    $null = & git -C $Dir diff --quiet -- profile.json 2>&1
    if ($LASTEXITCODE -ne 0) { return $true }
    $null = & git -C $Dir diff --cached --quiet -- profile.json 2>&1
    return ($LASTEXITCODE -ne 0)
}

# Invoke-ProfileCommit DIR MESSAGE DIRTY -- commit only profile.json in the dotprofile
# and push (N-Q2: dotprofile writes auto-commit and push). Failures are warnings:
# the file is already written. Sets $script:Committed / $script:Pushed.
$script:Committed = "false"; $script:Pushed = "false"
function Invoke-ProfileCommit([string]$Dir, [string]$Message, [bool]$Dirty) {
    $script:Committed = "false"; $script:Pushed = "false"
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        Add-Warn "git not found -- profile.json written but not committed"; return
    }
    $out = (& git -C $Dir rev-parse --is-inside-work-tree 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $out -ne "true") {
        Add-Warn "$Dir is not a git repository -- profile.json written but not committed"; return
    }
    if ($Dirty) {
        Add-Warn "profile.json had uncommitted changes before this write -- not committed automatically; review and commit profile.json in $Dir by hand"
        return
    }
    # No git identity on this machine yet (fresh machine): commit as the profile's
    # identity.git, the person the dotprofile belongs to. Empty = git's own error.
    $who = @()
    $curName = (& git -C $Dir config user.name 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $curName = "" }   # unset = exit 1
    $curMail = (& git -C $Dir config user.email 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $curMail = "" }   # unset = exit 1
    if (-not $curName -or -not $curMail) {
        $gname = Get-JText $script:PfValue @("identity", "git", "name")
        $gmail = Get-JText $script:PfValue @("identity", "git", "email")
        if ($gname -and $gmail) { $who = @("-c", "user.name=$gname", "-c", "user.email=$gmail") }
    }
    $out = (& git -C $Dir add -- profile.json 2>&1 | Out-String).Trim()
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        $out = (& git -C $Dir @who commit -m $Message -- profile.json 2>&1 | Out-String).Trim()
        $rc = $LASTEXITCODE
    }
    if ($rc -ne 0) {
        LogDetail "git commit in ${Dir}: $out"
        Add-Warn "dotprofile commit failed (exit $rc) -- commit profile.json in $Dir by hand"; return
    }
    $script:Committed = "true"
    # No prompts: GIT_TERMINAL_PROMPT covers https; BatchMode covers ssh (unless the
    # user already set GIT_SSH_COMMAND)
    $prevPrompt = $env:GIT_TERMINAL_PROMPT
    $prevSsh = $env:GIT_SSH_COMMAND
    try {
        $env:GIT_TERMINAL_PROMPT = "0"
        if (-not $prevSsh) { $env:GIT_SSH_COMMAND = "ssh -o BatchMode=yes" }
        $out = (& git -C $Dir push 2>&1 | Out-String).Trim()
        $rc = $LASTEXITCODE
    } finally {
        $env:GIT_TERMINAL_PROMPT = $prevPrompt
        $env:GIT_SSH_COMMAND = $prevSsh
    }
    if ($rc -ne 0) {
        LogDetail "git push in ${Dir}: $out"
        if ($out -cmatch 'rejected|non-fast-forward|fetch first') {
            Add-Warn "dotprofile push rejected (exit $rc): the remote has newer commits -- run git pull --rebase, then git push in $Dir"
        } else {
            Add-Warn "dotprofile push failed (exit $rc) -- run git push in $Dir"
        }
        return
    }
    $script:Pushed = "true"
}

# Backup-Pf -- Backup-File $script:Pf; a failed backup is returned as a warning (the
# write goes ahead, config-file-safety.md: backup failures are non-fatal)
function Backup-Pf {
    Backup-File $script:Pf
    if (-not $script:BackupFileOk) { Add-Warn "could not back up $($script:Pf) -- written without a backup" }
}

# Remove-TempFile FILE -- delete a temp file; a failure is a warning, never silent
function Remove-TempFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
    catch { LogDetail "remove ${Path}: $($_.Exception.Message)"; Add-Warn "could not remove $Path" }
}

# Get-WriteErrorText ERRORRECORD -- why a file write failed, worded as the bash
# resolver's perl engine words it ($!) for the common cases ("Permission denied",
# "No such file or directory"); otherwise the .NET reason. A .NET method call wraps
# the real exception in a MethodInvocationException ("Exception calling ...").
function Get-WriteErrorText($Err) {
    $ex = $Err.Exception
    if ($ex -is [System.Management.Automation.MethodInvocationException] -and $ex.InnerException) { $ex = $ex.InnerException }
    if ($ex -is [System.UnauthorizedAccessException]) { return "Permission denied" }
    if ($ex -is [System.IO.DirectoryNotFoundException] -or $ex -is [System.IO.FileNotFoundException]) { return "No such file or directory" }
    return $ex.Message
}

function Invoke-ExceptionSet {
    Test-Slug
    if (@("macos", "linux", "windows") -cnotcontains $opt["platform"]) { Stop-Usage "--platform must be macos, linux or windows" }
    if (-not $opt["method"] -or -not $opt["path"] -or -not $opt["by"]) {
        Stop-Usage "exception-set needs --slug, --platform, --method, --path and --by"
    }
    foreach ($o in @($opt["method"], $opt["path"], $opt["version"], $opt["by"], $opt["reason"], $opt["decided-at"])) {
        if ($o -match "[`t`r`n]") { Stop-Usage "exception-set values must be one line (no tab or newline)" }
    }
    $at = $opt["decided-at"]
    if (-not $at) { $at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
    Import-Config
    Find-ThisMachine
    $slug = $opt["slug"]
    $s = @{ state = "created" }
    $putSet = {
        Put "result" $s.state; Put "slug" $slug; Put "alias" $script:RmAlias; Put "via" $script:RmVia; Add-MatchLines
        Put "profileFile" $script:Pf; Put "committed" $script:Committed; Put "pushed" $script:Pushed
    }
    $rc = Find-ProfileFile
    if ($rc -eq 1) { $s.state = "refused"; Add-Err "no dotprofile profile.json -- run: aitools user init to remember tool choices"; & $putSet; Complete-Command 3 }
    if ($rc -ne 0) { $s.state = "failed"; & $putSet; Complete-Command 2 }
    if ($script:PfFromEnv) {
        $s.state = "refused"; Add-Err "profile from AITOOLS_PROFILE_FILE is a read-only snapshot -- not written"; & $putSet; Complete-Command 3
    }
    $p = $script:PfValue
    $rc = Resolve-This $p
    # Writes need THIS machine's profile: profiles[<this id>] (a legacy alias-keyed
    # profile whose machine.id is this id is accepted; resolve warned "migrate"),
    # the environment profile, or an override naming one of those. A hostname,
    # cache (machineId/machineAlias) or another machine's profile is refused, or
    # this machine's choice would be recorded in -- and honoured by -- another
    # machine's profile.
    if ($rc -ne 0) {
        $s.state = "refused"; Add-Err "tool choice not saved -- run: aitools user init to remember tool choices"; & $putSet; Complete-Command 3
    }
    if ($script:RmVia -eq "hostname") {
        $s.state = "refused"
        Add-Err "machine profile `"$($script:RmAlias)`" matched by hostname only -- run: aitools user init to remember tool choices"
        & $putSet; Complete-Command 3
    }
    if ($script:RmVia -eq "config") {
        $s.state = "refused"
        Add-Err "machine profile `"$($script:RmAlias)`" matched by config.json machineId only (machine id unavailable) -- tool choice not saved"
        & $putSet; Complete-Command 3
    }
    if ($script:RmOwner -ne "this" -or $script:RmVia -eq "alias") {
        $s.state = "refused"
        Add-Err "machine profile `"$($script:RmAlias)`" is not registered to this machine -- run: aitools user init to remember tool choices"
        & $putSet; Complete-Command 3
    }
    $alias = $script:RmAlias
    $k = $script:RmKey
    $before = ""
    $oldAt = ""
    if (Get-JType $p @("profiles", $k, "toolExceptions", $slug)) {
        $s.state = "updated"
        $before = ConvertTo-NodeJson (Get-JNode $p @("profiles", $k, "toolExceptions", $slug)).Value -Compress
        $oldAt = Get-JText $p @("profiles", $k, "toolExceptions", $slug, "decidedAt")
    }
    # An identical decision keeps its original timestamp (no commit, no push):
    # unless --decided-at is given, the first comparison uses the stored decidedAt.
    if (-not $opt["decided-at"] -and $oldAt) { $at = $oldAt }
    if ($env:AITOOLS_DRY_RUN -eq "1") {
        $s.state = "dry-run"; LogDetail "[DRY RUN] would record toolExceptions.$slug in $($script:Pf)"; & $putSet; Complete-Command 0
    }
    $tmp = "$($script:Pf).tmp.$PID"
    # Write-Entry AT -- build the entry with decidedAt AT into $tmp, validate it;
    # returns the compact JSON of the written entry
    $writeEntry = {
        param([string]$When)
        # A failed edit (e.g. a key that differs only in case, aitools-json.ps1
        # Set-JValue) is reported like the bash engine's edit failure
        try {
            if ((Get-JType $p @("profiles", $k, "toolExceptions")) -ne "object") {
                Set-JValue $p ([PSCustomObject]@{}) @("profiles", $k, "toolExceptions")
            }
            $detected = [PSCustomObject]@{}
            $detected | Add-Member -NotePropertyName platform -NotePropertyValue $opt["platform"]
            $detected | Add-Member -NotePropertyName method -NotePropertyValue $opt["method"]
            $detected | Add-Member -NotePropertyName path -NotePropertyValue $opt["path"]
            $detected | Add-Member -NotePropertyName version -NotePropertyValue $opt["version"]
            $entry = [PSCustomObject]@{}
            $entry | Add-Member -NotePropertyName decision -NotePropertyValue "keep"
            $entry | Add-Member -NotePropertyName detected -NotePropertyValue $detected
            $entry | Add-Member -NotePropertyName decidedAt -NotePropertyValue $When
            $entry | Add-Member -NotePropertyName decidedBy -NotePropertyValue $opt["by"]
            $reason = if ($opt["reason"]) { $opt["reason"] } else { $null }
            $entry | Add-Member -NotePropertyName reason -NotePropertyValue $reason
            Set-JValue $p $entry @("profiles", $k, "toolExceptions", $slug)
        } catch {
            Remove-TempFile $tmp
            $s.state = "failed"; Add-Err "exception-set failed: $($_.Exception.Message)"; & $putSet; Complete-Command 2
        }
        # Write path: temp -> validate -> backup -> move (config-file-safety.md)
        try {
            [IO.File]::WriteAllText($tmp, (ConvertTo-NodeJson $p) + "`n", $script:Utf8NoBom)
        } catch {
            $why = Get-WriteErrorText $_
            Remove-TempFile $tmp
            $s.state = "failed"; Add-Err "exception-set failed: cannot write ${tmp}: $why"; & $putSet; Complete-Command 2
        }
        $v = Read-ResolverJson $tmp
        if ($v.State -ne "valid" -or (Get-JType $v.Value @("profiles", $k, "toolExceptions", $slug)) -ne "object") {
            Remove-TempFile $tmp
            $s.state = "failed"; Add-Err "validation failed: toolExceptions.$slug missing after write"; & $putSet; Complete-Command 2
        }
        return (ConvertTo-NodeJson (Get-JNode $v.Value @("profiles", $k, "toolExceptions", $slug)).Value -Compress)
    }
    $after = & $writeEntry $at
    if ($s.state -eq "updated" -and $before -ceq $after) {
        Remove-TempFile $tmp
        $s.state = "unchanged"; & $putSet; Complete-Command 0
    }
    # A changed decision gets a fresh timestamp
    if (-not $opt["decided-at"] -and $at -eq $oldAt) {
        $at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $after = & $writeEntry $at
    }
    $dirty = Test-ProfileDirtyBefore (Split-Path -Parent $script:Pf)
    Backup-Pf
    try {
        Move-Item -LiteralPath $tmp -Destination $script:Pf -Force -ErrorAction Stop
    } catch {
        Remove-TempFile $tmp
        $s.state = "failed"; Add-Err "could not replace $($script:Pf)"; & $putSet; Complete-Command 2
    }
    LogDetail "exception-set: toolExceptions.$slug ($($opt['platform']) $($opt['method']) $($opt['path'])) written to $($script:Pf) (profile $k, alias $alias)"
    Invoke-ProfileCommit (Split-Path -Parent $script:Pf) "Record tool exception: keep $slug ($($opt['method'])) on $alias" $dirty
    & $putSet
    Complete-Command 0
}

function Invoke-DeriveConfig {
    Import-Config
    Find-MachineId
    Find-Hostname
    if ($script:ThisIdError) { Add-Warn "machine id unavailable: $($script:ThisIdError)" }
    if ($script:ThisHostError) { Add-Warn "hostname unavailable: $($script:ThisHostError)" }
    $d = @{ gh = ""; urp = ""; id = ""; alias = "" }
    $putDerived = {
        Put "derived.githubUser" $d.gh; Put "derived.userRepoPath" $d.urp; Put "derived.machineId" $d.id
        Put "derived.machineAlias" $d.alias
        Put "userRepoVia" $script:RurVia; Put "via" $script:RmVia; Add-MatchLines; Put "company" $script:Rm.company
        Put "machineId" $script:ThisId; Put "hostname" $script:ThisHost; Put "aliases" (Get-AliasCsv)
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
    $r = Read-ResolverJson $pf
    if ($r.State -eq "missing") { Add-Warn "profile.json not found in $($script:RurPath)"; $d.gh = $opt["github-user"]; & $putDerived; Complete-Command 1 }
    if ($r.State -eq "invalid") { Add-Err $r.Message; & $putDerived; Complete-Command 2 }
    $gh = $opt["github-user"]
    if (-not $gh) { $gh = Get-JText $r.Value @("identity", "github") }
    if (-not $gh) { $gh = Get-Cfg "githubUser" }
    $d.gh = $gh
    $rc = Resolve-This $r.Value
    if ($script:RmKey) {
        if ($script:RmVia -eq "override" -and $script:RmOverrideSource -eq "env") {
            Add-Warn "machine alias from AITOOLS_MACHINE_ALIAS -- not saved to config.json"
        } elseif ($script:RmVia -eq "hostname") {
            # A hostname match is a legacy guess, not a registration: caching it would
            # turn it into via=alias on the next run (PR #76 review M1)
            Add-Warn "machine alias `"$($script:RmAlias)`" matched by hostname only -- not saved to config.json"
        } else {
            # machineId: the matched key, only for this machine's id-keyed profile
            # (read back only when live id detection fails). machineAlias: display
            # value, and the legacy cache for an alias-keyed profile (step 4L).
            if ($script:RmKind -eq "id" -and $script:RmOwner -eq "this") { $d.id = $script:RmKey }
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
    $r = Read-ResolverJson $opt["profile"]
    if ($r.State -eq "missing") {
        LogDetail "snapshot: profile.json not found: $($opt['profile'])"
        [Console]::Error.WriteLine("aitools-profile: profile.json not found: $($opt['profile'])"); exit 1
    }
    if ($r.State -eq "invalid") {
        LogDetail "snapshot: $($r.Message)"
        [Console]::Error.WriteLine("aitools-profile: $($r.Message)"); exit 2
    }
    $snap = [ordered]@{}
    foreach ($k in @("version", "identity", "cursor", "profiles")) {
        $n = Get-JNode $r.Value @($k)
        # Assign directly: capturing an if-expression would unroll an array value
        if ($n.Found) { $snap[$k] = $n.Value } else { $snap[$k] = [PSCustomObject]@{} }
    }
    LogDetail "snapshot of $($opt['profile'])"
    Write-Output (ConvertTo-NodeJson $snap -Compress)
    exit 0
}

function Invoke-Register {
    if (-not $opt["profile"] -or -not $opt["out"]) { Stop-Usage "register needs --profile and --out" }
    if ($opt["alias"] -and $opt["alias"] -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { Stop-Usage "invalid alias: $($opt['alias'])" }
    if ($opt["alias"] -and (Test-LooksLikeId $opt["alias"])) { Stop-Usage "invalid alias: $($opt['alias']) (looks like a machine id)" }
    foreach ($o in @($opt["name"], $opt["company"], $opt["shell"], $opt["email"], $opt["github-user"], $opt["claim"])) {
        if ($o -match "[`t`r`n]") { Stop-Usage "register values must be one line (no tab or newline)" }
    }
    $g = @{ state = "created"; key = ""; alias = ""; owner = ""; ownerKey = ""; claimed = "" }
    $putReg = {
        Put "result" $g.state; Put "key" $g.key; Put "alias" $g.alias; Put "owner" $g.owner; Put "ownerKey" $g.ownerKey
        Put "claimed" $g.claimed; Put "machineId" $script:ThisId; Put "hostname" $script:ThisHost
    }
    $r = Read-ResolverJson $opt["profile"]
    $created = $false
    if ($r.State -eq "invalid") { $g.state = "failed"; Add-Err $r.Message; & $putReg; Complete-Command 2 }
    if ($r.State -eq "missing") {
        if (-not $script:OptCreate) { $g.state = "failed"; Add-Err "profile.json not found (use --create): $($opt['profile'])"; & $putReg; Complete-Command 1 }
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
        $meta = [PSCustomObject]@{}
        $meta | Add-Member -NotePropertyName schemaRevision -NotePropertyValue "2.2"
        $p = [PSCustomObject]@{}
        $p | Add-Member -NotePropertyName version -NotePropertyValue 2
        $p | Add-Member -NotePropertyName meta -NotePropertyValue $meta
        $p | Add-Member -NotePropertyName identity -NotePropertyValue $ident
        $p | Add-Member -NotePropertyName profiles -NotePropertyValue ([PSCustomObject]@{})
    } else {
        $p = $r.Value
        if ((Get-JText $p @("version")) -ne "2") { $g.state = "failed"; Add-Err "profile.json is not v2 -- migrate first"; & $putReg; Complete-Command 2 }
        if ((Get-JType $p @("profiles")) -ne "object") { Set-JValue $p ([PSCustomObject]@{}) @("profiles") }
    }
    Find-Hostname
    # The one key this command writes: this machine's id, lower-cased, or the
    # environment profile on claude-code-web (no stable id there)
    $web = ($script:ThisEnv -eq "claude-code-web")
    if ($web) {
        $key = "environment:claude-code-web"
    } else {
        Find-MachineId
        if (-not $script:ThisId) {
            $g.state = "refused"
            $why = if ($script:ThisIdError) { $script:ThisIdError } else { "empty machine id" }
            Add-Err "no machine id: $why -- a machine profile is keyed by this machine's id"
            & $putReg; Complete-Command 3
        }
        $key = ConvertTo-AsciiLower $script:ThisId
    }
    $g.key = $key
    $script:Entries = @()
    if (-not $created) { Import-Entries $p }
    $E = $script:Entries
    # This machine's entry: profiles[<key>] (any case), or a legacy alias-keyed entry
    # whose machine.id (machine.environment on claude-code-web) is this machine's
    $own = @($E | Where-Object { $_.KeyLc -ceq $key })
    if ($own.Count -gt 1) { $g.state = "failed"; Add-Err "profiles has two keys for $key ($($own[0].Key), $($own[1].Key))"; & $putReg; Complete-Command 2 }
    $leg = @($E | Where-Object {
        $_.KeyLc -cne $key -and $_.Kind -eq "legacy" -and (
            ($web -and $_.Env -ceq "claude-code-web") -or (-not $web -and $_.Mid -and $_.MidLc -ceq $key))
    })
    $who = if ($web) { "machine.environment claude-code-web" } else { "machine.id $($script:ThisId)" }
    if ($own.Count -eq 1 -and $leg.Count -gt 0) {
        $g.state = "failed"; Add-Err "$who is already registered on profile `"$($leg[0].Key)`" -- run: aitools-profile migrate after removing the duplicate"; & $putReg; Complete-Command 2
    }
    if ($leg.Count -gt 1) {
        $g.state = "failed"; Add-Err "$who is already registered on profile `"$($leg[0].Key)`" and another profile"; & $putReg; Complete-Command 2
    }
    $src = $null
    if ($own.Count -eq 1) { $src = $own[0] }
    elseif ($leg.Count -eq 1) { $src = $leg[0]; $g.claimed = $leg[0].Key }
    # --claim KEY (passed by user init only after the user picked KEY at a terminal):
    # move an alias-keyed profile that belongs to no machine under this machine's key
    if ($opt["claim"]) {
        $c = @($E | Where-Object { $_.Key -ceq $opt["claim"] })
        if ($c.Count -eq 0) { $g.state = "failed"; Add-Err "--claim: no profile `"$($opt['claim'])`""; & $putReg; Complete-Command 2 }
        $c = $c[0]
        if ($src -and -not [object]::ReferenceEquals($src, $c)) {
            $g.state = "failed"; Add-Err "--claim: this machine already has profile `"$($src.Key)`""; & $putReg; Complete-Command 2
        }
        if (-not [object]::ReferenceEquals($src, $c)) {
            if ($c.Kind -ne "legacy" -or $c.Mid -or $c.Env) {
                $g.state = "refused"; $g.owner = Get-EntryOwner $c ""; $g.ownerKey = $c.Key
                Add-Err "--claim: profile `"$($opt['claim'])`" is registered to another machine -- not claimed"
                & $putReg; Complete-Command 4
            }
            $src = $c; $g.claimed = $c.Key
        }
    }
    # The alias: --alias, else this entry's alias, else the short hostname
    $alias = $opt["alias"]
    if (-not $alias -and $src) { $alias = $src.Alias }
    if (-not $alias) { $alias = $script:ThisHost }
    $g.alias = $alias
    if (-not $alias) {
        $why = if ($script:ThisHostError) { $script:ThisHostError } else { "empty" }
        $g.state = "failed"; Add-Err "no alias: pass --alias (hostname unavailable: $why)"; & $putReg; Complete-Command 2
    }
    if ($alias -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$' -or (Test-LooksLikeId $alias)) {
        $g.state = "failed"; Add-Err "invalid alias: $alias (pass --alias)"; & $putReg; Complete-Command 2
    }
    # Another profile already answers to this alias (its alias field or its key,
    # ignoring case: laptop and Laptop are the same name to a person)
    $al = ConvertTo-AsciiLower $alias
    $conf = @($E | Where-Object { -not [object]::ReferenceEquals($_, $src) -and ($_.AliasLc -ceq $al -or $_.KeyLc -ceq $al) })
    if ($conf.Count -gt 0) {
        $g.ownerKey = $conf[0].Key
        $g.owner = Get-EntryOwner $conf[0] ""
        # An alias this profile already has (a duplicate confirmed earlier) is not a new conflict
        if (-not $script:OptAllowDup -and -not ($src -and $alias -ceq $src.Alias)) {
            $g.state = "refused"
            if ($g.owner -eq "unregistered") {
                Add-Err "alias `"$alias`" is used by profile $($g.ownerKey), which is not registered to any machine -- claim it (--claim $($g.ownerKey)) or choose another alias"
            } else {
                Add-Err "alias `"$alias`" is used by another machine's profile ($($g.ownerKey)) -- choose another alias, or confirm interactively (--allow-duplicate-alias)"
            }
            & $putReg; Complete-Command 4
        }
        Add-Warn "alias `"$alias`" is used by $($conf.Count + 1) machines ($(Get-KeysCsv $conf), $key)"
        $g.owner = ""; $g.ownerKey = ""
    }
    $before = ""
    try {
    if ($src) {
        $g.state = "updated"
        $before = ConvertTo-NodeJson (Get-JNode $p @("profiles", $src.Key)).Value -Compress
        $srcName = Read-JScalar $p @("profiles", $src.Key, "name")
        $srcCompany = Read-JScalar $p @("profiles", $src.Key, "company")
        $srcHosts = @(@(Get-JText $p @("profiles", $src.Key, "machine", "hostname")) + @(Get-JItems $p @("profiles", $src.Key, "machine", "hostnames")) | Where-Object { $_ })
        # Re-key a claimed or differently-cased entry under this machine's key (position kept)
        if ($src.Key -cne $key) { Rename-JKey $p $key @("profiles", $src.Key) }
        if ($alias -cne $src.Alias -or (-not $src.HasAlias -and $g.claimed)) {
            if ((ConvertTo-AsciiLower $alias) -cne $key) { Set-JValue $p $alias @("profiles", $key, "alias") }
        }
    } else {
        $srcName = @{ Found = $false }; $srcCompany = @{ Found = $false }; $srcHosts = @()
        Set-JValue $p $alias @("profiles", $key, "alias")
    }
    # Per-profile name/company only when neither the profile nor identity has one
    if ($opt["name"] -and -not $created) {
        if (-not $srcName.Found -and -not (Read-JScalar $p @("identity", "name")).Found) { Set-JValue $p $opt["name"] @("profiles", $key, "name") }
    }
    if ($opt["company"] -and -not $created) {
        if (-not $srcCompany.Found -and -not (Read-JScalar $p @("identity", "company")).Found) { Set-JValue $p $opt["company"] @("profiles", $key, "company") }
    }
    if ($web) {
        Set-JValue $p "claude-code-web" @("profiles", $key, "machine", "environment")
    } else {
        # machine.id repeats the key; an existing value differing only in case is kept
        $mid = if ($src) { $src.Mid } else { "" }
        if (-not $mid -or (ConvertTo-AsciiLower $mid) -cne $key) { Set-JValue $p $key @("profiles", $key, "machine", "id") }
    }
    # machine.hostname follows the live name unless it (or machine.hostnames) already
    # matches: a renamed machine clears the clone warning on its next registration
    $hmatch = @($srcHosts | Where-Object { (ConvertTo-ShortHost $_) -ceq $script:ThisHost }).Count -gt 0
    if (-not $hmatch -and $script:ThisHost) { Set-JValue $p $script:ThisHost @("profiles", $key, "machine", "hostname") }
    $os = switch ($script:AitoolsPlatform) { "windows" { "win32" } "macos" { "darwin" } default { $script:AitoolsPlatform } }
    $arch = ([string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToLowerInvariant()
    Set-JValue $p $os @("profiles", $key, "machine", "os")
    Set-JValue $p $arch @("profiles", $key, "machine", "arch")
    if ($opt["shell"]) { Set-JValue $p $opt["shell"] @("profiles", $key, "machine", "shell") }
    } catch {
        $g.state = "failed"; Add-Err "register failed: $($_.Exception.Message)"; & $putReg; Complete-Command 2
    }
    try {
        [IO.File]::WriteAllText($opt["out"], (ConvertTo-NodeJson $p) + "`n", $script:Utf8NoBom)
    } catch {
        $g.state = "failed"; Add-Err "register failed: cannot write $($opt['out']): $(Get-WriteErrorText $_)"; & $putReg; Complete-Command 2
    }
    $v = Read-ResolverJson $opt["out"]
    if ($v.State -ne "valid" -or (Get-JType $v.Value @("profiles", $key)) -ne "object") {
        $g.state = "failed"; Add-Err "validation failed: profile $key missing after write"; & $putReg; Complete-Command 2
    }
    if (-not $web) {
        $vid = Get-JText $v.Value @("profiles", $key, "machine", "id")
        if ((ConvertTo-AsciiLower $vid) -cne $key) { $g.state = "failed"; Add-Err "validation failed: profiles.$key machine.id is `"$vid`""; & $putReg; Complete-Command 2 }
    }
    $after = ConvertTo-NodeJson (Get-JNode $v.Value @("profiles", $key)).Value -Compress
    if ($g.state -eq "updated" -and -not $g.claimed -and $src.Key -ceq $key -and $before -ceq $after) { $g.state = "unchanged" }
    $g.owner = "this"
    & $putReg
    Complete-Command 0
}

# ---------------------------------------------------------------------------
# migrate (re-key design section f): every alias-keyed profile with machine.id is
# renamed to that id, lower-cased (with machine.environment: environment:<name>),
# keeping its position; `alias` is set to the old key when the profile has none.
# Profiles with neither stay as they are (unclaimed; registration claims them).
# Two profiles with one id = error, nothing written. Write path: temp -> validate
# (every re-keyed profile's key = its machine.id) -> backup -> move, then commit
# only profile.json and push (N-Q2). The one command that changes profiles other
# than this machine's: a mechanical rename of keys, never of their contents.
# ---------------------------------------------------------------------------
function Invoke-Migrate {
    Import-Config
    $g = @{ state = "unchanged"; renamed = ""; unclaimed = "" }
    $putMig = {
        Put "result" $g.state; Put "profileFile" $script:Pf; Put "renamed" $g.renamed; Put "unclaimed" $g.unclaimed
        Put "committed" $script:Committed; Put "pushed" $script:Pushed
    }
    $rc = Find-ProfileFile
    if ($rc -eq 1) { $g.state = "failed"; & $putMig; Complete-Command 1 }
    if ($rc -ne 0) { $g.state = "failed"; & $putMig; Complete-Command 2 }
    if ($script:PfFromEnv) {
        $g.state = "refused"; Add-Err "profile from AITOOLS_PROFILE_FILE is a read-only snapshot -- not written"; & $putMig; Complete-Command 3
    }
    $p = $script:PfValue
    if ((Get-JText $p @("version")) -ne "2") { $g.state = "failed"; Add-Err "profile.json is not v2"; & $putMig; Complete-Command 2 }
    if ((Get-JType $p @("profiles")) -ne "object") { $g.state = "failed"; Add-Err "profile.json has no profiles object"; & $putMig; Complete-Command 2 }
    Import-Entries $p
    $E = $script:Entries
    # Target: the key each entry ends up with
    $targets = [System.Collections.Generic.List[string]]::new()
    $unclaimed = [System.Collections.Generic.List[string]]::new()
    # (the loop variable is not $e: PowerShell names ignore case, $e would be $E)
    foreach ($en in $E) {
        $t = $en.Key
        if ($en.Kind -eq "id" -or $en.Kind -eq "env") { $t = $en.KeyLc }
        elseif ($en.Mid -and (Test-LooksLikeId $en.Key)) {
            # A key that is itself an id but disagrees with machine.id: a hand edit;
            # re-keying it could move this machine's key onto another id
            $g.state = "failed"
            Add-Err "profile key `"$($en.Key)`" disagrees with its machine.id `"$($en.Mid)`" -- fix profile.json by hand; nothing written"
            & $putMig; Complete-Command 2
        }
        elseif ($en.Mid) { $t = $en.MidLc }
        elseif ($en.Env) { $t = "environment:$(ConvertTo-AsciiLower $en.Env)" }
        else {
            $unclaimed.Add($en.Key)
            Add-Warn "profile `"$($en.Key)`" has no machine.id -- left as is (aitools user init claims it)"
        }
        $targets.Add($t)
    }
    $g.unclaimed = $unclaimed -join ", "
    # Two profiles that would share a key: nothing is written
    for ($i = 0; $i -lt $E.Count; $i++) {
        for ($j = $i + 1; $j -lt $E.Count; $j++) {
            if ((ConvertTo-AsciiLower $targets[$i]) -ceq (ConvertTo-AsciiLower $targets[$j])) {
                $g.state = "failed"
                Add-Err "profiles `"$($E[$i].Key)`" and `"$($E[$j].Key)`" would both be keyed `"$($targets[$i])`" (one machine id on two profiles) -- nothing written"
                & $putMig; Complete-Command 2
            }
        }
    }
    $renamed = [System.Collections.Generic.List[string]]::new()
    try {
        for ($i = 0; $i -lt $E.Count; $i++) {
            if ($targets[$i] -cne $E[$i].Key) {
                $renamed.Add("$($E[$i].Key) -> $($targets[$i])")
                Rename-JKey $p $targets[$i] @("profiles", $E[$i].Key)
                if ($E[$i].Kind -eq "legacy" -and -not $E[$i].HasAlias) { Set-JValue $p $E[$i].Key @("profiles", $targets[$i], "alias") }
            }
        }
    } catch {
        $g.state = "failed"; Add-Err "migrate failed: $($_.Exception.Message)"; & $putMig; Complete-Command 2
    }
    $g.renamed = $renamed -join ", "
    if ($renamed.Count -eq 0) { & $putMig; Complete-Command 0 }
    if ($script:OptDryRun -or $env:AITOOLS_DRY_RUN -eq "1") {
        $g.state = "dry-run"; LogDetail "[DRY RUN] would re-key in $($script:Pf): $($g.renamed)"; & $putMig; Complete-Command 0
    }
    $tmp = "$($script:Pf).tmp.$PID"
    try {
        [IO.File]::WriteAllText($tmp, (ConvertTo-NodeJson $p) + "`n", $script:Utf8NoBom)
    } catch {
        $why = Get-WriteErrorText $_
        Remove-TempFile $tmp
        $g.state = "failed"; Add-Err "migrate failed: cannot write ${tmp}: $why"; & $putMig; Complete-Command 2
    }
    $v = Read-ResolverJson $tmp
    if ($v.State -ne "valid") {
        Remove-TempFile $tmp
        $g.state = "failed"; Add-Err "validation failed: $($v.Message)"; & $putMig; Complete-Command 2
    }
    for ($i = 0; $i -lt $E.Count; $i++) {
        if ($targets[$i] -cne $E[$i].Key -and $E[$i].Kind -ne "env") {
            $t = $targets[$i]
            $got = if ($t.StartsWith("environment:")) { "environment:" + (ConvertTo-AsciiLower (Get-JText $v.Value @("profiles", $t, "machine", "environment"))) }
                   else { ConvertTo-AsciiLower (Get-JText $v.Value @("profiles", $t, "machine", "id")) }
            if ($v.State -ne "valid" -or (Get-JType $v.Value @("profiles", $t)) -ne "object" -or $got -cne $t) {
                Remove-TempFile $tmp
                $g.state = "failed"; Add-Err "validation failed: profile `"$t`" does not match its machine.id after the re-key"
                & $putMig; Complete-Command 2
            }
        }
    }
    $dirty = Test-ProfileDirtyBefore (Split-Path -Parent $script:Pf)
    Backup-Pf
    try {
        Move-Item -LiteralPath $tmp -Destination $script:Pf -Force -ErrorAction Stop
    } catch {
        Remove-TempFile $tmp
        $g.state = "failed"; Add-Err "could not replace $($script:Pf)"; & $putMig; Complete-Command 2
    }
    $g.state = "migrated"
    LogDetail "migrate: re-keyed $($g.renamed) in $($script:Pf)"
    $script:PfValue = $v.Value
    Invoke-ProfileCommit (Split-Path -Parent $script:Pf) "Migrate machine profiles to id keys" $dirty
    & $putMig
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
    "migrate" { Invoke-Migrate }
    "exception-get" { Invoke-ExceptionGet }
    "exception-set" { Invoke-ExceptionSet }
    "" { Show-Usage; exit 2 }
    default { Stop-Usage "unknown command: $($script:Cmd)" }
}
