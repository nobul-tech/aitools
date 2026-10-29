# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: /tool-registry skill (registries/tool-registry.json)
#
# Does five things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#   4. Fans the harness rules (%USERPROFILE%\.aitools\rules) out to Cursor's user rule
#      files (%USERPROFILE%\.cursor\rules\*.mdc), converting each Claude Code .md rule
#      to .mdc
#   5. Fans the harness skills (%USERPROFILE%\.aitools\skills) out to
#      %USERPROFILE%\.cursor\skills (Invoke-HarnessSkillsFanout in aitools-lib.ps1;
#      no adopt target)
#
# cli-config.json:
#   Managed fields: version, editor, permissions, model, hasChangedDefaultModel
#   Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields
# %USERPROFILE%\.cursor\rules\ (additive deploy, pruned against the rules manifest):
#   Managed: one <name>.mdc per .aitools\rules\<name>.md that
#            .aitools\rules\.aitools-rules-manifest does not retire: shared,
#            aitools and dotprofile rules alike, and a rule the manifest does
#            not list (commander decision 2026-10-26, RECONCILE Q3: "cursor
#            should get project level rules too in user space"). *.bak.*
#            backups, hidden files (the manifest) and non-.md files are not
#            fanned out; names are compared case-insensitively.
#   Removed (backup kept): <name>.mdc of a retired rule, only if the fan-out
#            created it (the aitools-fanout marker line, or, for files from
#            before the marker, the same content as the conversion of the
#            harness copy or of one of its *.bak.* backups) and a backup with
#            the same text exists beside it; any other file of such a name is
#            kept with a warning and an ACTION row (Cursor still loads it)
#   Preserved: every other .cursor\rules file
#   No manifest: every rule fanned out, none removed (info log). A first line
#   other than the v1 header: the same, plus a WARN log and an ACTION row (run
#   aitools). An unreadable manifest: ERROR row, the fan-out continues.
#   Location and format: S3-H-Cursor-research.md (.aitools/channel/handoffs/
#   2026-10-21_10cf255a-c-missions/S3-H-Cursor/)
# %USERPROFILE%\.cursor\skills\ (step 5): plans/skills-and-rules-fanout.md section 3.4;
#   a skill directory this fan-out did not create is never overwritten or removed

# --- BEGIN cursor body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-cursor"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# Log captured command output to the log file as detail lines (blank lines skipped).
function Write-OutputDetail([string]$Label, [string]$Output) {
    foreach ($l in $Output.Split("`n")) { if ($l.Trim()) { LogDetail "${Label}: $($l.TrimEnd())" } }
}

$cursorDir = Join-Path $env:USERPROFILE ".cursor"
$cliConfig = Join-Path $cursorDir "cli-config.json"

# Track status for summary
$status = @{
    ripgrep   = ""
    cursorCli = ""
    cliConfig = ""
}

# --- 1. ripgrep (rg) ---

Log "Step 1: ripgrep (rg)"

if ($DryRun) {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        Log "[DRY RUN] ripgrep already installed: $rgVersion"
        $status.ripgrep = "already installed ($rgVersion)"
    } else {
        Log "[DRY RUN] Would install ripgrep via winget"
        $status.ripgrep = "would install"
    }
} else {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        LogOk "Already installed: $rgVersion"
        $status.ripgrep = "already installed ($rgVersion)"
    } else {
        Log "Installing ripgrep via winget..."
        # Exit code decides (C-F2); the output goes to the log.
        $rgOutput = winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        $rgRc = $LASTEXITCODE
        Log-WingetOutput $rgOutput
        Refresh-Path

        # Get-Command exempt: command-existence check with if/else fallback
        $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
        if ($rgRc -ne 0 -and $rgOutput -notmatch 'already installed') {
            LogError "winget install ripgrep failed (exit $rgRc) -- see $logFile"
            $status.ripgrep = "FAILED (exit $rgRc)"
            Write-Summary "ERROR" "cursor cli" "ripgrep install failed (exit $rgRc)"
        } elseif ($rgCmd) {
            $rgVersion = (rg --version | Select-Object -First 1)
            LogOk "Installed: $rgVersion"
            $status.ripgrep = "installed ($rgVersion)"
        } else {
            LogWarn "winget install completed but 'rg' not found in PATH. Restart terminal to verify."
            $status.ripgrep = "installed (restart terminal to verify)"
            Write-Summary "WARN" "cursor cli" "ripgrep not on PATH (restart terminal)"
        }
    }
}

# --- 2. Cursor CLI (agent) ---

Log "Step 2: Cursor CLI (agent)"

if ($DryRun) {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        Log "[DRY RUN] Cursor CLI already installed: $agentVersion"
        $status.cursorCli = "already installed ($agentVersion)"
    } else {
        Log "[DRY RUN] Would install Cursor CLI"
        $status.cursorCli = "would install"
    }
} else {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        LogOk "Already installed: $agentVersion"
        $status.cursorCli = "already installed ($agentVersion)"
    } else {
        Log "Installing Cursor CLI..."
        # Installer output (all streams) goes to the log; a failed download or script is an ERROR.
        $installerFailed = $false
        try {
            $installerOutput = Invoke-Expression (Invoke-RestMethod 'https://cursor.com/install?win32=true' -ErrorAction Stop) *>&1 | Out-String
            Write-OutputDetail "cursor-installer" $installerOutput
        } catch {
            $installerFailed = $true
            LogError "Cursor CLI installer failed: $_"
            $status.cursorCli = "FAILED"
            Write-Summary "ERROR" "cursor cli" "installer failed"
        }
        Refresh-Path

        if (-not $installerFailed) {
            # Get-Command exempt: command-existence check with if/else fallback
            $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
            if ($agentCmd) {
                $agentVersion = agent --version
                LogOk "Installed: $agentVersion"
                $status.cursorCli = "installed ($agentVersion)"
            } else {
                LogWarn "Cursor CLI install completed but 'agent' not found in PATH. Restart terminal to verify."
                $status.cursorCli = "installed (restart terminal to verify)"
                Write-Summary "WARN" "cursor cli" "agent not on PATH (restart terminal)"
            }
        }
    }
}

# --- 2b. Detection: warn if `agent` resolves to grok, not Cursor ---
# (Symlink management is POSIX-only; on Windows the Cursor installer owns the shim.)
if (-not $DryRun) {
    $resolvedAgent = Get-Command agent -ErrorAction SilentlyContinue
    if ($resolvedAgent -and $resolvedAgent.Source -like "*\.grok\*") {
        LogWarn "'agent' resolves to grok ($($resolvedAgent.Source)), not Cursor -- ensure the Cursor shim precedes grok on PATH"
        Write-Summary "WARN" "cursor cli" "agent shadowed by grok"
    }
}

# --- 3. cli-config.json (merge, not overwrite) ---

Log "Step 3: cli-config.json"

# Set inside the profile preferences block when the dotprofile resolver failed;
# defined outside it so the generated deploy/ copy (block replaced) has it too.
$prefsUnresolved = $false

# --- BEGIN profile preferences (replaced by build-deploy) ---
# dotprofile (the one resolver, reference/user-repo.md "Resolution"; SD-7)
# -> profile.json -> cursor.cli prefs. The rc is captured, not suppressed:
# 0 found, 1 no dotprofile (shared-only mode: default preferences), 3 resolver
# error (the lib already logged it: LogError + ERROR row "dotprofile");
# on 3 the merge is skipped rather than write defaults over the user's choices.
$vimMode = $false
$modelId = "auto"

$urpRc = Resolve-UserRepoPath
$userRepoPath = $script:AitLibUserRepoPath
if ($urpRc -eq 0 -and $userRepoPath) {
    $profilePath = Join-Path $userRepoPath "profile.json"
    if (Test-Path $profilePath) {
        try {
            $pf = ConvertPSObjectToHashtable (Get-Content $profilePath -Raw -ErrorAction Stop | ConvertFrom-Json)
            # Same checks as the .sh: a non-object cursor / cursor.cli is ignored
            # (defaults), and only a bool vimMode / string model is taken
            if ($pf.ContainsKey("cursor") -and $pf["cursor"] -is [hashtable] -and
                $pf["cursor"].ContainsKey("cli") -and $pf["cursor"]["cli"] -is [hashtable]) {
                $cli = $pf["cursor"]["cli"]
                if ($cli.ContainsKey("vimMode") -and $cli["vimMode"] -is [bool]) { $vimMode = $cli["vimMode"] }
                if ($cli.ContainsKey("model") -and $cli["model"] -is [string]) { $modelId = $cli["model"] }
            }
        } catch {
            LogWarn "Could not read profile preferences from $profilePath`: $_ -- default preferences"
        }
    } else {
        LogDetail "cli-config: no profile.json in $userRepoPath -- default preferences"
    }
} elseif ($urpRc -ne 0 -and $urpRc -ne 1) {
    $prefsUnresolved = $true
}
# --- END profile preferences (replaced by build-deploy) ---

# Back up before merge
if (-not $DryRun) {
    Backup-File -FilePath $cliConfig
}

# Ensure ~/.cursor/ exists
if (-not (Test-Path $cursorDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
        Log "Created $cursorDir"
    }
}

# --- Read existing cli-config.json ---
$config = @{}
$corrupt = $false
if (Test-Path $cliConfig) {
    try {
        $config = ConvertPSObjectToHashtable (Get-Content $cliConfig -Raw | ConvertFrom-Json)
    } catch {
        $corrupt = $true
        LogWarn "$cliConfig could not be parsed ($_)"
    }
}
$beforeKeys = @($config.Keys)
$beforeJson = Normalize-JsonForComparison $config -Depth 10

# Snapshot managed keys before merge for change tracking
$managedKeysList = @("version", "editor", "permissions", "model", "hasChangedDefaultModel")
$beforeManaged = @{}
foreach ($k in $managedKeysList) {
    if ($config.ContainsKey($k)) {
        $beforeManaged[$k] = Normalize-JsonForComparison $config[$k] -Depth 5 -Compress
    } else {
        $beforeManaged[$k] = $null
    }
}

# --- Merge managed fields ---
$config["version"] = 1
if (-not $config.ContainsKey("editor")) { $config["editor"] = @{} }
$config["editor"]["vimMode"] = $vimMode
if (-not $config.ContainsKey("permissions")) { $config["permissions"] = @{} }
if (-not $config["permissions"].ContainsKey("allow")) { $config["permissions"]["allow"] = @() }
if (-not $config["permissions"].ContainsKey("deny")) { $config["permissions"]["deny"] = @() }

# Model: only set if profile specifies 'auto' (the only supported value for now)
if ($modelId -eq "auto") {
    $config["model"] = @{
        modelId          = "default"
        displayModelId   = "auto"
        displayName      = "Auto"
        displayNameShort = "Auto"
        aliases          = @("auto")
        maxMode          = $false
    }
    $config["hasChangedDefaultModel"] = $true
}

# --- Clobber detection ---
$managedKeys = @("version", "editor", "permissions", "model", "hasChangedDefaultModel")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $config.Keys })

$afterJson = Normalize-JsonForComparison $config -Depth 10

if ($prefsUnresolved) {
    # Counted (S3-M3Lead decision, as setup-user-settings and -skills): this
    # step fails too, not only the resolver (the lib logged that one).
    LogError "Dotprofile unresolved (resolver error above) -- $cliConfig not merged, so defaults cannot replace the profile preferences"
    $status.cliConfig = "ERROR (dotprofile error)"
    Write-Summary "ERROR" "cursor cli" "not merged: dotprofile error"
} elseif ($DryRun) {
    # --- Dry-run output ---
    Log "[DRY RUN] $cliConfig`: merge"
    Log "  Managed fields: $($managedKeys -join ', ')"
    if ($lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
    # Same rows as the .sh dry run: unchanged -> verified, else would update.
    if ($beforeJson -eq $afterJson -and -not $corrupt) {
        Log "[DRY RUN] No changes needed (already up to date)"
        $status.cliConfig = "already up to date (dry-run)"
        Write-Summary "OK" "cursor cli" "verified"
    } else {
        Log "[DRY RUN] Would write merged config"
        $status.cliConfig = "would merge (dry-run)"
        Write-Summary "OK" "cursor cli" "dry-run: would update"
    }
} else {
    # --- Normal mode ---
    if ($corrupt -and -not $Force) {
        LogError "$cliConfig is corrupt. Use -Force to overwrite, or fix manually."
        $status.cliConfig = "ERROR (corrupt, needs -Force)"
        Write-Summary "ERROR" "cursor cli" "config corrupt"
    } elseif ($lostKeys.Count -gt 0 -and -not $Force) {
        LogError "$cliConfig merge would lose fields: $($lostKeys -join ', '). Use -Force to proceed."
        $status.cliConfig = "ERROR (clobber, needs -Force)"
        Write-Summary "ERROR" "cursor cli" "merge would lose fields"
    } elseif ($beforeJson -eq $afterJson -and -not $corrupt) {
        LogOk "Already up to date: $cliConfig"
        $status.cliConfig = "already up to date"
        Write-Summary "OK" "cursor cli" "verified"
    } else {
        if ($corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
        if ($lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: $($lostKeys -join ', ')" }

        $json = $config | ConvertTo-Json -Depth 10
        $errorsBeforeWrite = $errors
        try {
            [System.IO.File]::WriteAllText(
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($cliConfig),
                $json,
                [System.Text.UTF8Encoding]::new($false)
            )
        } catch {
            LogError "Could not write $cliConfig -- $_"
        }

        # Post-write validation
        try {
            $vContent = [System.IO.File]::ReadAllText(
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($cliConfig)
            )
            $vParsed = $vContent | ConvertFrom-Json
            if (-not ($vParsed.PSObject.Properties.Name -contains "version")) {
                LogError "Validation failed: $cliConfig missing required field 'version'"
            }
        } catch {
            LogError "Validation failed: $cliConfig is not valid JSON -- $_"
        }

        # Detect per-key changes and emit DETAIL lines
        $keyChanges = @()
        foreach ($k in $managedKeysList) {
            $newVal = if ($config.ContainsKey($k)) { Normalize-JsonForComparison $config[$k] -Depth 5 -Compress } else { $null }
            if ($beforeManaged[$k] -ne $newVal) {
                $oldDisplay = if ($beforeManaged[$k]) { $beforeManaged[$k] } else { "(unset)" }
                $newDisplay = if ($newVal) { $newVal } else { "(removed)" }
                $keyChanges += "${k}: $oldDisplay -> $newDisplay"
            }
        }

        if ($errors -gt $errorsBeforeWrite) {
            # Write or post-write validation failed: ERROR row, never OK after it
            $status.cliConfig = "ERROR (write or validation failed)"
            Write-Summary "ERROR" "cursor cli" "config write/validation failed"
        } elseif ($beforeKeys.Count -eq 0) {
            LogOk "Created: $cliConfig"
            $status.cliConfig = "created"
            if ($keyChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $keyChanges -ToolName "cursor cli"
            }
            Write-Summary "OK" "cursor cli" "created"
        } else {
            LogOk "Merged preferences into: $cliConfig"
            $status.cliConfig = "merged"
            if ($keyChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $keyChanges -ToolName "cursor cli"
            }
            Write-Summary "OK" "cursor cli" "updated"
        }
    }
}

# --- 4. User rules fan-out: .aitools\rules -> .cursor\rules ---
# Cursor (IDE and CLI) loads <dir>\.cursor\rules\**\*.mdc for the workspace and
# every ancestor directory, so %USERPROFILE%\.cursor\rules reaches every
# workspace under %USERPROFILE%. Plain .md files are ignored there, and a .mdc
# needs a leading --- frontmatter block, so each Claude Code .md rule is
# converted (ConvertTo-CursorRule). Adopt is not offered (-AdoptPath ""): the
# harness copy is not the repo source, and the deployed file is a converted
# form of it. Cursor gets every harness rule except the ones the rules
# manifest (deploy-harness, PR #100 contract) retires -- project rules
# included (commander decision 2026-10-26, RECONCILE Q3; reverses PR #110's
# user-level filter), as setup-user-claude fans them out to Claude Code. The
# .mdc of a retired rule is removed when the fan-out created it.
# Parity: step 4 in setup-user-cursor.sh.

Log "Step 4: Cursor user rules"

$harnessRulesDir = Join-Path $env:USERPROFILE ".aitools\rules"
$cursorRulesDir = Join-Path $cursorDir "rules"

# Return the Cursor .mdc form of a Claude Code rule (text in, text out).
#   - No frontmatter: "alwaysApply: true" is added (always loaded, as in Claude Code).
#   - A top-level "paths:" key (Claude Code path scoping: a block list, a list at
#     column 0, one value, or a [a, b] flow list) becomes a "globs:" block list,
#     one "  - " item per pattern (Cursor splits an inline value on commas and
#     reads only indented items). Each relative pattern is anchored as
#     "**/<pattern>": Cursor matches a user rule's glob against the file path
#     relative to the directory that owns .cursor\rules (%USERPROFILE%), and
#     Claude Code paths are project-relative. Absolute and "**/" patterns are kept.
#     "alwaysApply: false" is added unless the frontmatter sets alwaysApply.
#   - Every other frontmatter line and the body are kept; CRLF becomes LF and a
#     UTF-8 BOM is dropped.
#   - With a rule name, the line after the frontmatter is the aitools-fanout
#     marker ($cursorFanoutMarker + name): it tells a file this fan-out created
#     from a user's own .mdc, so pruning never removes the user's file.
#     Parity: cursor_rule_from_md in setup-user-cursor.sh.
$cursorFanoutMarker = "<!-- aitools-fanout: generated by setup-user-cursor from ~/.aitools/rules/"
function ConvertTo-CursorRule([string]$Text, [string]$Name = "") {
    $mark = if ($Name) { "$cursorFanoutMarker$Name; edit that rule, not this file -->`n" } else { "" }
    function Get-AnchoredGlob([string]$Glob) {
        $g = $Glob -replace '^\s+', '' -replace '\s+$', ''
        if ($g -cmatch '^"(.*)"$') { $g = $Matches[1] } elseif ($g -cmatch "^'(.*)'$") { $g = $Matches[1] }
        if ($g -eq "") { return "" }
        if ($g -ceq "**" -or $g -cmatch '^(/|\*\*/|[A-Za-z]:[\\/]|\\\\)') { return $g }
        if ($g.StartsWith("./")) { $g = $g.Substring(2) }
        return "**/$g"
    }
    function Split-FlowItems([string]$Value) {
        $items = New-Object System.Collections.Generic.List[string]
        $depth = 0
        $cur = New-Object System.Text.StringBuilder
        foreach ($c in $Value.ToCharArray()) {
            if ($c -eq [char]'{') { $depth++ } elseif ($c -eq [char]'}' -and $depth -gt 0) { $depth-- }
            if ($c -eq [char]',' -and $depth -eq 0) { $items.Add($cur.ToString()); [void]$cur.Clear(); continue }
            [void]$cur.Append($c)
        }
        $items.Add($cur.ToString())
        return ,$items
    }

    $t = $Text
    if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
    $t = $t -replace "`r`n", "`n"
    $m = [regex]::Match($t, '\A---[ \t]*\n(?:(.*?)\n)?---[ \t]*(?:\n|\z)(.*)\z', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) {
        return "---`nalwaysApply: true`n---`n" + $mark + $t
    }
    $fm = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { "" }
    $body = $m.Groups[2].Value
    $out = New-Object System.Collections.Generic.List[string]
    $hasAlways = $false
    $hasGlobs = $false
    $inPaths = $false
    $lines = if ($fm.Length -gt 0) { $fm -split "`n" } else { @() }
    foreach ($line in $lines) {
        if ($line -cmatch '^paths:[ \t]*(.*?)[ \t]*$') {
            $v = $Matches[1]
            $items = @()
            if ($v -cmatch '^\[(.*)\]$') { $items = Split-FlowItems $Matches[1] } elseif ($v -ne "") { $items = @($v) }
            $out.Add("globs:"); $inPaths = $true
            foreach ($i in $items) {
                $g = Get-AnchoredGlob $i
                if ($g -ne "") { $out.Add("  - $g"); $hasGlobs = $true }
            }
            continue
        }
        if ($inPaths -and $line -cmatch '^\s*#') { continue }   # YAML comment inside the list
        if ($inPaths -and $line -cmatch '^\s*-\s+(.*)$') {
            $g = Get-AnchoredGlob $Matches[1]
            if ($g -ne "") { $out.Add("  - $g"); $hasGlobs = $true }
            continue
        }
        $inPaths = $false
        if ($line -cmatch '^alwaysApply:') { $hasAlways = $true }
        if ($line -cmatch '^globs:') { $hasGlobs = $true }
        $out.Add($line)
    }
    if (-not $hasAlways) {
        if ($hasGlobs) { $out.Add("alwaysApply: false") } else { $out.Add("alwaysApply: true") }
    }
    return "---`n" + ($out -join "`n") + "`n---`n" + $mark + $body
}

# True when the .mdc text was created by this fan-out: the line right after its
# frontmatter starts with $cursorFanoutMarker. Parity: cursor_rule_is_fanout
# in setup-user-cursor.sh.
function Test-CursorFanoutRule([string]$Text) {
    $t = $Text
    if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
    $t = $t -replace "`r`n", "`n"
    # Frontmatter lines may not be "---": the marker must follow the FIRST closing ---
    $pattern = '\A---[ \t]*\n(?:(?!---[ \t]*\n)[^\n]*\n)*---[ \t]*\n' + [regex]::Escape($cursorFanoutMarker)
    return [regex]::IsMatch($t, $pattern)
}

# The rules manifest (deploy-harness section 5b, PR #100 contract) is read with
# the lib's Read-RulesManifest (@{ Status; Rules; Invalid }; throws when it
# cannot be read); names are filtered with Get-RuleNameKind and compared with
# OrdinalIgnoreCase HashSets (aitools-lib.ps1; FAN-PLAN F1).

# Check a converted .mdc the way Cursor parses it: Cursor splits the whole file
# on "---" and takes the first non-empty piece as the frontmatter, so a "---"
# inside a frontmatter value moves the rest of it into the body. The converter
# always writes alwaysApply, so a parsed frontmatter without it means Cursor
# would misread the rule. Returns a reason, or "" when the text is fine.
# Parity: cursor_rule_check in setup-user-cursor.sh.
function Test-CursorRuleParse([string]$Text) {
    $parts = @(($Text -replace '^\s+', '') -split '---' | Where-Object { $_.Length -gt 0 })
    $fm = if ($parts.Count -gt 0) { $parts[0] } else { "" }
    if ($fm -cmatch '(?m)^alwaysApply:') { return "" }
    return "Cursor would not see alwaysApply in its frontmatter (a --- inside a frontmatter value?)"
}

$rulesManifest = Join-Path $harnessRulesDir ".aitools-rules-manifest"
$rulesGo = $false
$entries = @()
if (-not (Test-Path -LiteralPath $harnessRulesDir -PathType Container)) {
    Log "No harness rules at $harnessRulesDir (deploy-harness has not run) -- skipping"
    Write-Summary "OK" "cursor rules" "n/a (no harness rules)"
} else {
    try {
        $entries = @(Get-ChildItem -LiteralPath $harnessRulesDir -ErrorAction Stop)
        # Ordinal order, as the .sh (LC_ALL=C sort): Sort-Object compares by culture
        # (a.md before A.md), the .sh glob by LC_COLLATE, so they could disagree
        [Array]::Sort($entries, [Comparison[object]]{ param($x, $y) [string]::CompareOrdinal($x.Name, $y.Name) })
        $rulesGo = $true
    } catch {
        LogError "Cannot list $harnessRulesDir -- $_"
        Write-Summary "ERROR" "cursor rules" "cannot read harness rules"
    }
}

# Rules manifest: the retired names (pruned) and the names Cursor expects.
# Without one (deploy-harness before PR #100) every rule is fanned out and none
# is removed, as setup-user-claude does (FAN-PLAN Q3).
$manifestFailed = $false   # unreadable: counted as a failed item, so the final row is ERROR
$listedNames = New-Object System.Collections.Generic.List[string]    # manifest names not retired
$retiredNames = New-Object System.Collections.Generic.List[string]
$retiredSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
# Invalid manifest lines or a listed rule with no file: one ACTION row (as the
# skills fan-out writes for its manifest)
$rulesNeedRebuild = $false
$rulesRebuildHint = "Run aitools to rebuild ~/.aitools/rules and its manifest"
if ($rulesGo) {
    # Absent only when nothing is at the path: a directory or a dangling link
    # there (Test-Path is true for one on pwsh 7) goes to the reader, which
    # reports it as unreadable
    if (-not (Test-Path -LiteralPath $rulesManifest)) {
        Log "No rules manifest at $rulesManifest -- every rule fanned out, none removed"
    } else {
        $manifest = $null
        try {
            $manifest = Read-RulesManifest $rulesManifest
        } catch {
            LogError "Cannot read the rules manifest ${rulesManifest}: $_ -- every rule fanned out, none removed"
            Write-Summary "ERROR" "cursor rules" "cannot read rules manifest"
            $manifestFailed = $true
        }
        if ($manifest -and $manifest.Status -eq "header-bad") {
            LogWarn "Rules manifest ${rulesManifest}: the first line is not `"$rulesManifestHeader`" -- every rule fanned out, none removed -- $rulesRebuildHint"
            Write-Summary "ACTION" "" $rulesRebuildHint
        } elseif ($manifest) {
            foreach ($bad in $manifest.Invalid) {
                $rulesNeedRebuild = $true
                LogWarn "Rules manifest ${rulesManifest}: line ignored: $bad -- $rulesRebuildHint"
            }
            foreach ($r in $manifest.Rules) {
                if ($r.Source -ceq "retired") {
                    $retiredNames.Add($r.Name); [void]$retiredSet.Add($r.Name)
                } else {
                    $listedNames.Add($r.Name)
                }
            }
        }
    }
}

# Source files: every *.md in .aitools\rules (flat, the deploy-harness
# contract) that the manifest does not retire. Hidden files are skipped.
$ruleSources = @()
$foundSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$ruleBroken = @()   # dangling symlinks: reported as failed in the deploy loop
if ($rulesGo) {
    foreach ($entry in $entries) {
        # Contract (S3-Harness correction): only *.md rules; *.bak.* are the
        # backups Deploy-ManagedFile leaves next to updated harness files.
        # Case-insensitive (commander decision 2026-10-22).
        $kind = Get-RuleNameKind $entry.Name
        if ($kind -eq "backup" -or $kind -eq "hidden") { continue }
        if ($kind -ne "rule") {
            Log "Ignoring non-rule file in harness rules: $($entry.Name) (only *.md is fanned out)"
            continue
        }
        if ($retiredSet.Contains($entry.Name)) {
            Log "Not fanned out: $($entry.Name) (retired in the rules manifest)"
            continue
        }
        [void]$foundSet.Add($entry.Name)
        if ($entry.LinkType) {
            # Test-Path is true for a dangling link on pwsh 7; check the final target
            $linkOk = $false
            try {
                $linkOk = [bool]$entry.ResolveLinkTarget($true).Exists
            } catch {
                LogDetail "cursor rules: cannot resolve the link $($entry.FullName): $_"
                $linkOk = $false
            }
            if (-not $linkOk) { $ruleBroken += $entry.Name; continue }
        }
        if ($entry.PSIsContainer) { Log "Ignoring non-file in harness rules: $($entry.Name)"; continue }
        $ruleSources += $entry
    }

    # A rule the manifest lists (not retired) with no file: nothing to fan out
    foreach ($name in $listedNames) {
        if (-not $foundSet.Contains($name)) {
            $rulesNeedRebuild = $true
            LogWarn "Not fanned out: $name is in the rules manifest but not in $harnessRulesDir -- $rulesRebuildHint"
        }
    }
    if ($rulesNeedRebuild) { Write-Summary "ACTION" "" $rulesRebuildHint }

    if ($ruleSources.Count -eq 0 -and $ruleBroken.Count -eq 0 -and $retiredNames.Count -eq 0) {
        Log "No rules in $harnessRulesDir -- skipping"
        # An unreadable manifest already wrote this tool's ERROR row
        if (-not $manifestFailed) { Write-Summary "OK" "cursor rules" "n/a (no harness rules)" }
        $rulesGo = $false
    } elseif ($DryRun) {
        # The dry run previews the error the real run reports: something that
        # is not a directory where .cursor\rules goes
        if ((Test-Path -LiteralPath $cursorRulesDir) -and -not (Test-Path -LiteralPath $cursorRulesDir -PathType Container)) {
            LogError "Cannot create ${cursorRulesDir}: not a directory (dry run)"
            Write-Summary "ERROR" "cursor rules" "cannot create rules dir"
            $rulesGo = $false
        }
    } else {
        Backup-Dir -DirPath $cursorRulesDir
        if (-not (Test-Path -LiteralPath $cursorRulesDir -PathType Container)) {
            $mkdirError = ""
            try {
                New-Item -ItemType Directory -Path $cursorRulesDir -Force -ErrorAction Stop | Out-Null
            } catch {
                $mkdirError = "$_"
            }
            # New-Item -Force can return without an error when a file is in
            # the way: check the result (parity with mkdir -p in the .sh)
            if (-not (Test-Path -LiteralPath $cursorRulesDir -PathType Container)) {
                if (-not $mkdirError) { $mkdirError = "not a directory" }
                LogError "Cannot create ${cursorRulesDir}: $mkdirError"
                Write-Summary "ERROR" "cursor rules" "cannot create rules dir"
                $rulesGo = $false
            }
        }
    }
}

if ($rulesGo) {
    Initialize-DeployTracker
    $errorsBeforeCursorRules = $errors
    if ($manifestFailed) {
        Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName ".aitools-rules-manifest"
    }
    foreach ($brokenName in $ruleBroken) {
        LogError "Failed: ${brokenName}: dangling symlink in $harnessRulesDir"
        Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $brokenName
    }

    # Deploy loop. [x]abort exits 2 from the library here: no "cursor rules" row
    # is written, and the calling installer or aitools loop records
    # "script failed (exit 2)".
    $ruleDests = New-Object System.Collections.Generic.List[string]       # deployed names
    $ruleDestsLc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($src in $ruleSources) {
        $ruleBase = $src.Name
        # Get-RuleNameKind matched *.md case-insensitively: drop the last 3 characters
        $destName = $ruleBase.Substring(0, $ruleBase.Length - 3) + ".mdc"

        # Two sources mapping to one target (names that differ only in case,
        # possible on a case-sensitive file system): the first wins
        if ($ruleDestsLc.Contains($destName)) {
            LogError "Skipped duplicate: $ruleBase -> $destName (already deployed from another harness rule)"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $ruleBase
            continue
        }
        $ruleDests.Add($destName)
        [void]$ruleDestsLc.Add($destName)

        try {
            $raw = [System.IO.File]::ReadAllText($src.FullName, [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Failed: ${ruleBase}: cannot read $($src.FullName) -- $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $destName
            continue
        }
        $ruleContent = ConvertTo-CursorRule $raw $ruleBase
        if (-not $ruleContent) {
            LogError "Failed: ${ruleBase}: empty after conversion -- nothing written"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $destName
            continue
        }

        $result = Deploy-ManagedFile -Content $ruleContent -DestPath (Join-Path $cursorRulesDir $destName) `
            -ToolName "cursor rules" -ItemName $destName -AdoptPath ""
        switch ($result) {
            { $_ -in @("created", "updated", "verified", "skipped", "failed") } {
                # The library wrote (or left) LOCAL; the tracker records every
                # outcome (failed -> ERROR row, skipped -> WARN row).
            }
            "accept & adopt" {
                # Not reachable: adopt is not offered without an adopt target
                LogError "Unexpected accept & adopt for $destName (no adopt target)"
            }
            default {
                LogError "Unexpected deploy result for ${destName}: $result"
                $result = "failed"
            }
        }
        Record-DeployOutcome -Outcome $result -ToolName "cursor rules" -ItemName $destName
    }

    # Prune: a retired rule must not stay loaded in Cursor. Its .mdc is removed
    # (backup kept) only when this fan-out created it: the aitools-fanout
    # marker, or, for a file deployed before the marker existed (PR #87), the
    # same content as the conversion of the harness copy or of a backup
    # deploy-harness left beside it. Any other file of that name may be the
    # user's own: kept, with a warning.
    $rmKept = New-Object System.Collections.Generic.List[string]   # retired names kept (not created by the fan-out)
    foreach ($rmName in $retiredNames) {
        $rmDest = $rmName.Substring(0, $rmName.Length - 3) + ".mdc"
        # Deployed this run from a rule whose name differs only in case
        if ($ruleDestsLc.Contains($rmDest)) { continue }
        # The .mdc in .cursor\rules, found case-insensitively (a case-sensitive
        # file system may hold Gone.mdc for the manifest's gone.md), reported
        # under its on-disk name; a regular file or a link to one, as the .sh's
        # [ -f ] (a dangling link is skipped). As setup-user-claude's retired prune
        $rmPath = ""
        if (-not (Test-Path -LiteralPath $cursorRulesDir -PathType Container)) { continue }
        try {
            foreach ($f in @([System.IO.Directory]::GetFiles($cursorRulesDir) | Sort-Object -CaseSensitive)) {
                if (-not [string]::Equals([System.IO.Path]::GetFileName($f), $rmDest, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                if ((Get-FanoutEntryType -Path $f -Follow) -eq "file") { $rmPath = $f; break }
            }
        } catch {
            # The .sh glob matches nothing in a directory it cannot list: detail only
            LogDetail "cursor rules: cannot list $cursorRulesDir for retired rule ${rmName}: $_"
        }
        if (-not $rmPath) { continue }
        $rmDest = [System.IO.Path]::GetFileName($rmPath)
        try {
            $rmText = [System.IO.File]::ReadAllText($rmPath, [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Cannot read $rmPath -- not removed: $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $rmDest
            continue
        }
        $rmWhy = ""
        if (Test-CursorFanoutRule $rmText) {
            $rmWhy = "aitools-fanout marker"
        } else {
            # No marker (a PR #87 file): compare with the conversion of the
            # harness copy and of each backup deploy-harness left beside it
            # (it backs a rule up when it updates or retires it), so a rule
            # edited or retired since the #87 run is still recognised
            $rmCands = New-Object System.Collections.Generic.List[string]
            $rmCands.Add((Join-Path $harnessRulesDir $rmName))
            try {
                $rmBaks = @([System.IO.Directory]::GetFiles($harnessRulesDir) |
                    Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmName.bak.", [System.StringComparison]::Ordinal) } |
                    Sort-Object -Property { [System.IO.Path]::GetFileName($_) } -CaseSensitive)
                foreach ($b in $rmBaks) { $rmCands.Add($b) }
            } catch {
                LogDetail "cursor rules: cannot list backups of $rmName in ${harnessRulesDir}: $_"
            }
            foreach ($rmCand in $rmCands) {
                if (-not (Test-Path -LiteralPath $rmCand -PathType Leaf)) { continue }
                try {
                    $rmLegacy = ConvertTo-CursorRule ([System.IO.File]::ReadAllText($rmCand, [System.Text.UTF8Encoding]::new($false)))
                } catch {
                    LogDetail "cursor rules: cannot read $rmCand for the content check: $_"
                    continue
                }
                # Compared as bash compares them: trailing newlines dropped
                if ($rmLegacy -and ($rmLegacy -replace '\n+\z', '') -ceq ($rmText -replace '\n+\z', '')) {
                    $rmWhy = "same content as the conversion of $([System.IO.Path]::GetFileName($rmCand))"
                    break
                }
            }
        }
        if (-not $rmWhy) {
            # Kept (it may be the user's own file), but Cursor still loads it
            LogWarn "Kept ${rmDest}: the rules manifest retires $rmName, but this file was not created by the fan-out (no aitools-fanout marker, no matching harness copy) -- Cursor still loads it; remove it if it is an old fan-out copy"
            $rmKept.Add($rmDest)
            continue
        }
        if ($DryRun) {
            Log "[DRY RUN] Would back up and remove $rmDest (retired rule; $rmWhy)"
            continue
        }
        # Backup-File uses -LiteralPath (aitools-lib): names with [ ] * ? are backed up too
        Backup-File -FilePath $rmPath
        # Belt and braces: remove only when a backup with the same text exists
        # beside it (a backup step that reports success without a copy must not
        # lose the file)
        $rmBacked = $false
        if ($script:BackupFileOk) {
            try {
                foreach ($b in @([System.IO.Directory]::GetFiles($cursorRulesDir) |
                        Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmDest.bak.", [System.StringComparison]::Ordinal) })) {
                    if ((Test-FanoutTextEqual $rmPath $b) -eq 0) { $rmBacked = $true; break }
                }
            } catch {
                # Detail only (the .sh glob cannot fail this way): the LogError
                # below reports the outcome
                LogDetail "cursor rules: cannot list the backups of $rmDest in ${cursorRulesDir}: $_"
            }
        }
        if (-not $rmBacked) {
            LogError "Not removed: $rmDest (retired rule): backup failed"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $rmDest
            continue
        }
        try {
            Remove-Item -LiteralPath $rmPath -Force -ErrorAction Stop
        } catch {
            LogError "Cannot remove $rmPath (retired rule): $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $rmDest
            continue
        }
        if (Test-Path -LiteralPath $rmPath) {
            LogError "Cannot remove $rmPath (retired rule): still present"
            Record-DeployOutcome -Outcome "failed" -ToolName "cursor rules" -ItemName $rmDest
            continue
        }
        Log "Removed $rmDest (retired rule; $rmWhy; backup kept)"
        Record-DeployOutcome -Outcome "removed" -ToolName "cursor rules" -ItemName $rmDest
    }
    if ($rmKept.Count -gt 0) {
        Write-Summary "ACTION" "" "Cursor still loads retired rules in ~/.cursor/rules: $($rmKept -join ', ') -- delete them unless you wrote them"
    }

    if ($DryRun) {
        if ($script:dtFailed -gt 0) {
            Write-Summary "ERROR" "cursor rules" "$($script:dtFailed) failed (dry run)"
        } elseif ($errors -ne $errorsBeforeCursorRules) {
            # An error not recorded as a failed item still makes the row ERROR
            Write-Summary "ERROR" "cursor rules" "dry run failed"
        } else {
            Write-Summary "OK" "cursor rules" "dry run (no files written)"
        }
    } else {
        # Preserved: files in .cursor\rules not produced from .aitools\rules
        $destEntries = @()
        try {
            $destEntries = @(Get-ChildItem -LiteralPath $cursorRulesDir -File -ErrorAction Stop)
            # Ordinal order, as the .sh (LC_ALL=C sort): Sort-Object compares by culture
            # (a.md before A.md), the .sh glob by LC_COLLATE, so they could disagree
            [Array]::Sort($destEntries, [Comparison[object]]{ param($x, $y) [string]::CompareOrdinal($x.Name, $y.Name) })
        } catch {
            # Detail only (the .sh glob matches nothing in an unlistable directory)
            LogDetail "cursor rules: cannot list $cursorRulesDir for the preserved report: $_"
        }
        foreach ($existing in $destEntries) {
            if ($existing.Name -like "*.bak.*") { continue }
            if (-not $ruleDestsLc.Contains($existing.Name)) {
                Log "Preserved unmanaged rule: $($existing.Name)"
                Record-DeployOutcome -Outcome "preserved" -ToolName "cursor rules" -ItemName $existing.Name
            }
        }

        # Post-write validation: non-empty, and a .mdc starts with frontmatter
        foreach ($destName in $ruleDests) {
            $destPath = Join-Path $cursorRulesDir $destName
            # Skipped unless a regular file or a link to one, as the .sh's [ -f ]:
            # Test-Path -PathType Leaf and File.Exists are true for a dangling
            # link on pwsh 7, whose failed deploy is already reported
            $destType = "missing"
            try {
                $destType = Get-FanoutEntryType -Path $destPath -Follow
            } catch {
                LogDetail "cursor rules: cannot stat ${destPath}: $_"
            }
            if ($destType -ne "file") { continue }
            $item = Get-Item -LiteralPath $destPath
            if ($item.Length -eq 0) {
                LogError "Validation failed: $destName is empty after deploy"
                continue
            }
            try {
                $deployed = [System.IO.File]::ReadAllText($destPath)
            } catch {
                LogError "Validation failed: cannot read $destPath -- $_"
                continue
            }
            if (-not $deployed.TrimStart([char]0xFEFF).StartsWith("---")) {
                LogError "Validation failed: $destName has no frontmatter (Cursor skips it)"
            } else {
                # Check each deployed rule as Cursor parses it (warn: the
                # rule is deployed but Cursor would misread its frontmatter)
                $parseProblem = Test-CursorRuleParse $deployed
                if ($parseProblem) {
                    LogWarn "${destName}: $parseProblem -- fix the source rule in $harnessRulesDir"
                }
            }
        }

        if ($script:dtFailed -gt 0) {
            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
            Write-DeployTrackerSummary -ToolName "cursor rules"
            Log "Cursor rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $cursorRulesDir"
        } elseif ($errors -eq $errorsBeforeCursorRules) {
            # Only retired names, none of them here: the tracker's own text,
            # "n/a (nothing to deploy)", the same row text the skills fan-out
            # (step 5) writes in that case
            Write-DeployTrackerSummary -ToolName "cursor rules"
            LogOk "Cursor rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $cursorRulesDir"
        } else {
            Write-Summary "ERROR" "cursor rules" "validation failed"
        }
    }
}

# --- 5. User skills fan-out: .aitools\skills -> .cursor\skills ---
# The lib's Invoke-HarnessSkillsFanout (plans/skills-and-rules-fanout.md
# section 3.4): every skill directory deploy-harness collected, except the
# ones the skills manifest retires, file by file through Deploy-ManagedFile.
# No adopt target (-AitoolsRepo and -Dotprofile ""), as for Cursor rules. A
# skill directory in .cursor\skills the fan-out did not create is never
# overwritten or removed. Rows: "cursor skills". With no .aitools\skills the
# lib logs and writes no row: setup-user-skills (the fallback deployer, FO-6)
# owns the row then. Until FO-6, setup-user-skills also writes "cursor skills"
# rows (FD-9). Parity: step 5 in setup-user-cursor.sh.

Log "Step 5: Cursor user skills"
Invoke-HarnessSkillsFanout -ToolName "cursor skills" -DestDir (Join-Path $cursorDir "skills") -AitoolsRepo "" -Dotprofile ""

# --- END cursor body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
