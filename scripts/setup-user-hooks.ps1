# setup-user-hooks.ps1 -- Deploys Claude Code hooks to ~/.claude/settings.json
# Safe to re-run -- merges the `hooks` key without clobbering existing settings.
# UNTESTED on Windows: authored on macOS (no pwsh). Mirrors setup-user-hooks.sh.
#
# Hook deployment + registration are GENERATED from shared/hooks/hooks-manifest.json
# (the single source of truth). Adding a hook = one manifest entry; no edits here.
# Closes the recurring "deployed but not registered" / parallel-list-drift class
# (RCA: .scratch investigation 2026-06-20; issue #7 / plan §5).
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields
#
# Claude preferences (autoMemoryEnabled/alwaysThinkingEnabled/effortLevel) and all
# other non-hook settings are profile-sourced and synced by setup-user-settings.
# See reference/user-repo.md and shared/hooks/hooks-manifest.json for details.
#
# Note: Hook scripts are bash-only (Claude Code hooks always run in bash on
# both platforms). This PS1 script only deploys the hook configuration.

# --- BEGIN hooks body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-hooks"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- BEGIN hook deployment (replaced by build-deploy) ---
# --- Resolve repo path + manifest ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

$manifestPath = Join-Path $repoDir "shared\hooks\hooks-manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-AitError "claude hooks" "hooks not deployed" "hook manifest not found: $manifestPath"
    exit 1
}
try {
    $manifestObj = Get-Content $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-AitError "claude hooks" "hook manifest unreadable" (Get-AitErrorReason -ErrorRecord $_)
    exit 1
}

# User repo: home of user-created (non-manifest) hooks only (SD-2, incident #80).
# Manifest hooks have one version, in shared/hooks; a dotprofile copy is never
# deployed (it would freeze the hook on this machine and diverge from the MDM
# path, which embeds shared/hooks only).
$userRepoPath = ReadConfigKey -File (Join-Path $env:USERPROFILE ".aitools\config.json") -Key "userRepoPath"
$dotprofileHooks = $null
if ($userRepoPath) {
    $dpHooksPath = Join-Path $userRepoPath "claude\hooks"
    if (Test-Path $dpHooksPath) {
        $dotprofileHooks = $dpHooksPath
    }
}

# Resolve hook source: shared/hooks, then scripts/ (for deploy-only .py helpers
# like ait-harvest.py that live in scripts/). Same order as build-deploy.sh's
# embed loops, so the dev and MDM paths deploy the same file.
function Resolve-HookSource {
    param([string]$HookName)
    if (Test-Path (Join-Path $repoDir "shared\hooks\$HookName")) {
        return (Join-Path $repoDir "shared\hooks\$HookName")
    }
    return (Join-Path $repoDir "scripts\$HookName")
}

# Registration list + file list, from the manifest (single source of truth).
# build-deploy embeds $regs statically for the self-contained MDM path.
$regs = @($manifestObj.hooks)
$hookFiles = @($manifestObj.hooks | ForEach-Object { $_.file } | Where-Object { $_ })
if ($manifestObj.deploy) { $hookFiles += @($manifestObj.deploy) }
if ($hookFiles.Count -eq 0) {
    Write-AitError "claude hooks" "hooks not deployed" "manifest lists no hooks"
    exit 1
}

# Existence check (resolve every manifest file before deploying any).
foreach ($hookName in $hookFiles) {
    $src = Resolve-HookSource $hookName
    if (-not (Test-Path $src)) {
        Write-AitError "claude hooks" "hooks not deployed" "hook script not found: $src"
        exit 1
    }
    # A dotprofile copy of a manifest hook is ignored (SD-2): say so, so the
    # user can delete it instead of believing their edit is live. One warning
    # per copy, named.
    if ($dotprofileHooks -and (Test-Path (Join-Path $dotprofileHooks $hookName))) {
        Write-AitWarn "claude hooks" "dotprofile copy of $hookName ignored -- delete $(Join-Path $dotprofileHooks $hookName)"
    }
}

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"

$hooksChanged = $false

# Adopt target for manifest hooks: the file the hook is deployed from --
# shared\hooks\<name>, or scripts\<name> for deploy-only helpers
# (Resolve-HookSource). Never the dotprofile (SD-2, incident #80). The library
# writes it.


if ($DryRun) {
    foreach ($hookName in $hookFiles) {
        $src = Resolve-HookSource $hookName
        Log "[DRY RUN] Would deploy hook: $src -> $(Join-Path $hooksDir $hookName)"
    }
    # Stale hook cleanup preview
    foreach ($staleHook in @("surfacing-duty-stop.sh", "estimate-refresh-stop.sh", "intent-sentinel-stop.sh")) {
        if (Test-Path (Join-Path $hooksDir $staleHook)) {
            Log "[DRY RUN] Would remove stale hook: $staleHook"
        }
    }
} else {
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

    Initialize-DeployTracker

    foreach ($hookName in $hookFiles) {
        $src = Resolve-HookSource $hookName
        $dst = Join-Path $hooksDir $hookName
        try {
            $srcContent = Get-Content $src -Raw -ErrorAction Stop
        } catch {
            # Without the guard a read error would end the script with no record
            Write-AitError "claude hooks" "cannot read $hookName" (Get-AitErrorReason -ErrorRecord $_)
            Record-DeployOutcome -Outcome failed -ToolName "claude hooks" -ItemName $hookName
            continue
        }

        $hookResult = Deploy-ManagedFile -Content $srcContent -DestPath $dst -ToolName "claude hooks" -ItemName $hookName -AdoptPath $src

        switch ($hookResult) {
            { $_ -in @("created", "updated", "accept & adopt") } {
                # accept & adopt: the library also wrote the source file in the repo.
                $hooksChanged = $true
            }
            { $_ -in @("skipped", "verified", "failed") } {
                # The library recorded a skipped (warning) or failed (error)
                # deploy once; the tracker writes the OK status and DETAIL only.
            }
        }
        Record-DeployOutcome -Outcome $hookResult -ToolName "claude hooks" -ItemName $hookName
    }

    Write-DeployTrackerSummary -ToolName "claude hooks"

    # --- Stale hook cleanup ---
    # Remove hook files previously deployed but no longer managed (deleted from
    # shared/hooks/ in commit e070043). Registration cleanup is RemoveHookEntry below.
    $staleHooks = @("surfacing-duty-stop.sh", "estimate-refresh-stop.sh", "intent-sentinel-stop.sh")
    foreach ($staleHook in $staleHooks) {
        $stalePath = Join-Path $hooksDir $staleHook
        if (Test-Path $stalePath) {
            Remove-Item $stalePath -Force
            LogOk "Removed stale hook: $staleHook"
            $hooksChanged = $true
        }
        $bakPattern = Join-Path $hooksDir "$staleHook.bak.*"
        $staleBaks = Get-ChildItem -Path $bakPattern -File -ErrorAction SilentlyContinue
        if ($staleBaks) {
            foreach ($bak in $staleBaks) {
                Remove-Item $bak.FullName -Force
                Log "Removed stale backup: $($bak.Name)"
            }
        }
    }

    # --- Reverse discovery ---
    # Scan deployed hooks for user-created hooks not in shared or dotprofile
    if (Test-Path $hooksDir) {
        foreach ($hookFile in Get-ChildItem -Path $hooksDir -Filter "*.sh" -File) {
            $hookName = $hookFile.Name

            if (Test-Path (Join-Path $repoDir "shared\hooks\$hookName")) { continue }
            if ($dotprofileHooks -and (Test-Path (Join-Path $dotprofileHooks $hookName))) { continue }

            if ($userRepoPath) {
                Log "Found user-created hook: $hookName"
                # Test-InteractiveConsole + Read-MenuChoice (incident #81, GitHub
                # #29): a redirected stdin never prompts. Read-MenuChoice prints
                # the prompt, lowercases the answer, logs it at detail, and
                # re-asks on an empty or unrecognised answer; only EOF
                # ([Console]::ReadLine() -> $null) takes the default, [s]kip --
                # the choice that writes nothing (this menu has no overwrite
                # option).
                if (-not (Test-InteractiveConsole)) {
                    Log "Non-interactive: skipped adoption prompt for $hookName"
                    continue
                }
                [Console]::WriteLine("")
                [Console]::WriteLine("  User-created hook detected: $hookName")
                [Console]::WriteLine("  [a]dopt to dotprofile  [s]kip")
                $choice = Read-MenuChoice -Valid @("a", "adopt", "s", "skip") -Default "s" -DefaultDesc "skip" `
                    -Context "adopt hook $hookName" -Prompt "  > "
                switch ($choice) {
                    { $_ -in @("a", "adopt") } {
                        # Net-new user hook -> dotprofile only (not a managed
                        # shared/ hook). Same helper for consistent backups. The
                        # library records each failure once under -Tool; a
                        # failure it did not record (no file adopted) is
                        # recorded here.
                        $errorsBeforeAdopt = $errors
                        $adoptedCount = Adopt-ManagedFile -SourceFile $hookFile.FullName `
                            -Targets @(Join-Path $userRepoPath "claude\hooks\$hookName") -Tool "claude hooks"
                        if (-not $adoptedCount -and $errors -eq $errorsBeforeAdopt) {
                            Write-AitError "claude hooks" "adopt failed: $hookName" "no file adopted"
                        }
                    }
                    { $_ -in @("s", "skip") } {
                        Log "Skipped adoption of $hookName"
                    }
                    default {
                        # Unreachable: Read-MenuChoice returns only a VALID
                        # answer. Skip (writes nothing) and say so.
                        Write-AitWarn "claude hooks" "unexpected answer `"$choice`" at adopt hook $hookName -- adoption skipped"
                    }
                }
            }
        }
    }
}
# --- END hook deployment (replaced by build-deploy) ---

# Claude preferences (autoMemoryEnabled/alwaysThinkingEnabled/effortLevel) are NOT
# managed here -- they are profile-sourced and synced by setup-user-settings.
# This script manages only the `hooks` key.

# --- Merge hooks + preferences into ~/.claude/settings.json ---
# Registrations are GENERATED from the manifest ($regs) -- loop MergeHookEntry +
# validation over every entry. No per-hook *_Cmd vars or hardcoded calls.
$settingsFile = Join-Path $claudeDir "settings.json"
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
}

# Read existing settings
$settings = @{}
$corrupt = $false
$corruptReason = ""
if (Test-Path $settingsFile) {
    try {
        $raw = Get-Content $settingsFile -Raw -ErrorAction Stop
        $settings = ConvertPSObjectToHashtable ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        # Recorded once, below: an error, or a warning under -Force
        $corrupt = $true
        $corruptReason = ($_.Exception.Message -replace '\s+', ' ').Trim()
        $settings = @{}
    }
}
$beforeKeys = @($settings.Keys)

# --- Merge hooks ---
if (-not $settings.ContainsKey("hooks")) { $settings["hooks"] = @{} }

# Helper: ensure exactly one entry for a hookId in an event array.
function MergeHookEntry($eventName, $hookIdentifier, $matcherValue, $cmd, $hookType) {
    if (-not $hookType) { $hookType = "command" }
    if (-not $settings["hooks"].ContainsKey($eventName)) {
        $settings["hooks"][$eventName] = @()
    }
    $arr = @($settings["hooks"][$eventName])

    $found = $false
    foreach ($rule in $arr) {
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    if (-not $found) {
                        $h["command"] = $cmd
                        $h["type"] = $hookType
                        $rule["matcher"] = $matcherValue
                        $found = $true
                    }
                }
            }
        }
    }
    if (-not $found) {
        $arr += @{
            matcher = $matcherValue
            hooks   = @(@{ type = $hookType; command = $cmd })
        }
    }

    foreach ($rule in $arr) {
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks") -and $rule["hooks"] -isnot [array]) {
            $rule["hooks"] = @($rule["hooks"])
        }
    }

    $seen = $false
    $deduped = @()
    foreach ($rule in $arr) {
        $isMatch = $false
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    $isMatch = $true
                    break
                }
            }
        }
        if ($isMatch -and $seen) { continue }
        if ($isMatch) { $seen = $true }
        $deduped += $rule
    }
    $settings["hooks"][$eventName] = $deduped
}

# Helper: remove all entries for a hookId from an event array.
function RemoveHookEntry($eventName, $hookIdentifier) {
    if (-not $settings["hooks"].ContainsKey($eventName)) { return }
    $arr = @($settings["hooks"][$eventName])
    $filtered = @()
    foreach ($rule in $arr) {
        $isMatch = $false
        if ($rule -is [System.Collections.Hashtable] -and $rule.ContainsKey("hooks")) {
            foreach ($h in @($rule["hooks"])) {
                if ($h -is [System.Collections.Hashtable] -and $h.ContainsKey("command") -and $h["command"] -match [regex]::Escape($hookIdentifier)) {
                    $isMatch = $true
                    break
                }
            }
        }
        if (-not $isMatch) { $filtered += $rule }
    }
    if ($filtered.Count -eq 0) {
        $settings["hooks"].Remove($eventName)
    } else {
        $settings["hooks"][$eventName] = $filtered
    }
}

# Remove stale Stop hooks (deleted from shared/hooks/ in commit e070043)
RemoveHookEntry "Stop" "surfacing-duty-stop.sh"
RemoveHookEntry "Stop" "estimate-refresh-stop.sh"
RemoveHookEntry "Stop" "intent-sentinel-stop.sh"

# Register every manifest hook (generated -- no hardcoded list).
# Hook command uses Unix-style path (hooks run in bash even on Windows).
foreach ($r in $regs) {
    $destUnix = (Join-Path $hooksDir $r.file) -replace '\\', '/'
    $rCmd = "bash `"$destUnix`""
    $matcherVal = if ($r.matcher) { $r.matcher } else { "" }
    MergeHookEntry $r.event $r.file $matcherVal $rCmd
}

# --- Clobber detection ---
$managedKeys = @("hooks")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $settings.Keys })

if ($DryRun) {
    Log "[DRY RUN] $settingsFile`: merge"
    Log "  Managed fields: $($managedKeys -join ', ')"
    if ($lostKeys.Count -gt 0) {
        Write-AitWarn "claude hooks" "[DRY RUN] CLOBBER: would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        Write-AitWarn "claude hooks" "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
    Log "[DRY RUN] Registered hooks: $($regs.Count)"
} else {
    if ($corrupt -and -not $Force) {
        Write-AitError "claude hooks" "settings.json is corrupt -- use -Force to overwrite" $corruptReason
    } elseif ($lostKeys.Count -gt 0 -and -not $Force) {
        Write-AitError "claude hooks" "merge would lose fields -- use -Force to proceed" "would lose: $($lostKeys -join ', ')"
    } else {
        # -Force writes that lose data stay warnings (reference/logging.md 8.3)
        if ($corrupt) { Write-AitWarn "claude hooks" "settings.json was invalid JSON ($corruptReason) -- overwritten (-Force)" }
        if ($lostKeys.Count -gt 0) { Write-AitWarn "claude hooks" "fields dropped (-Force): $($lostKeys -join ', ')" }

        $mergedJson = $settings | ConvertTo-Json -Depth 10
        $mergedNorm = Normalize-JsonForComparison $settings -Depth 10
        # A corrupt file (rewritten under -Force) is never equal to the merge
        $existingNorm = if ((Test-Path $settingsFile) -and -not $corrupt) {
            try { Normalize-JsonForComparison (ConvertPSObjectToHashtable (Get-Content $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json)) -Depth 10 }
            catch { $null }
        } else { $null }
        if ($mergedNorm -eq $existingNorm) {
            LogOk "Settings unchanged: $settingsFile"
        } else {
            # Validate the merged content before it is written (parity with the
            # .sh, which validates a staging file): invalid content is never
            # written. Each failure is collected; the first is the reason of one
            # error, the rest are detail lines.
            $valErrs = @()
            $vParsed = $null
            try {
                $vParsed = $mergedJson | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $valErrs += "validation failed: the merged settings are not valid JSON: $($_.Exception.Message)"
            }
            if ($vParsed) {
                $requiredKeys = @("hooks")
                foreach ($rk in $requiredKeys) {
                    if (-not ($vParsed.PSObject.Properties.Name -contains $rk)) {
                        $valErrs += "validation failed: missing $rk"
                    }
                }

                # Validate: every manifest hook registered exactly once (generated check).
                foreach ($r in $regs) {
                    $rc = @($vParsed.hooks.$($r.event) | Where-Object { $_.hooks.command -match [regex]::Escape($r.file) }).Count
                    if ($rc -ne 1) { $valErrs += "validation failed: expected 1 $($r.event) $($r.file) hook, got $rc" }
                }

                # Validate hook schema: command-type must have command,
                # prompt-type must have prompt (not command).
                foreach ($eventName in $vParsed.hooks.PSObject.Properties.Name) {
                    foreach ($rule in @($vParsed.hooks.$eventName)) {
                        foreach ($h in @($rule.hooks)) {
                            if ($h.type -eq "command" -and -not $h.command) {
                                $valErrs += "validation failed: $eventName hook has type `"command`" but no command field"
                            }
                            if ($h.type -eq "prompt") {
                                if (-not $h.prompt) {
                                    $valErrs += "validation failed: $eventName hook has type `"prompt`" but no prompt field."
                                }
                                if ($h.command) {
                                    $valErrs += "validation failed: $eventName hook has type `"prompt`" with a command field."
                                }
                            }
                        }
                    }
                }
            }

            if ($valErrs.Count -gt 0) {
                foreach ($ve in ($valErrs | Select-Object -Skip 1)) { LogDetail "settings-merge: $ve" }
                Write-AitError "claude hooks" "settings.json hooks merge failed" $valErrs[0]
            } else {
                # Back up only now that the file changes (config-file-safety.md
                # "Backup before overwrite"); then write and read it back.
                Backup-File -FilePath $settingsFile
                $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($settingsFile)
                $written = $false
                try {
                    [System.IO.File]::WriteAllText($resolvedPath, $mergedJson, [System.Text.UTF8Encoding]::new($false))
                    $written = $true
                } catch {
                    Write-AitError "claude hooks" "could not write $settingsFile" (Get-AitErrorReason -ErrorRecord $_)
                }
                if ($written) {
                    $readBack = $null
                    try { $readBack = [System.IO.File]::ReadAllText($resolvedPath) } catch {
                        Write-AitError "claude hooks" "could not write $settingsFile" (Get-AitErrorReason -ErrorRecord $_)
                        $written = $false
                    }
                    if ($written -and $readBack -cne $mergedJson) {
                        Write-AitError "claude hooks" "could not write $settingsFile" "the written file differs from the merged settings"
                        $written = $false
                    }
                }
                if ($written) {
                    $hooksChanged = $true
                    LogOk "Hooks deployed to $settingsFile"
                }
            }
        }
    }
}
# --- END hooks body (extracted by build-deploy) ---

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
