# Exercise the real manifest-driven registration logic from setup-user-hooks.ps1
# (MergeHookEntry + the $regs loop) against a fake settings object on macOS,
# bypassing the Windows-only OS guard. Verifies all 18 hooks register once.
$ErrorActionPreference = "Stop"

$manifestObj = Get-Content "/Users/new-jose/repos/aitools/shared/hooks/hooks-manifest.json" -Raw | ConvertFrom-Json
$regs = @($manifestObj.hooks)
$hooksDir = "/Users/new-jose/.claude/hooks"
$settings = @{ hooks = @{} }

# --- Copied verbatim from setup-user-hooks.ps1 ---
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

# --- The register loop (verbatim from the script) ---
foreach ($r in $regs) {
    $destUnix = (Join-Path $hooksDir $r.file) -replace '\\', '/'
    $rCmd = "bash `"$destUnix`""
    $matcherVal = if ($r.matcher) { $r.matcher } else { "" }
    MergeHookEntry $r.event $r.file $matcherVal $rCmd
}

# --- Verify (mirrors the script's post-write validation loop) ---
$mismatch = 0
foreach ($r in $regs) {
    $c = @($settings.hooks[$r.event] | Where-Object { $_.hooks.command -match [regex]::Escape($r.file) }).Count
    if ($c -ne 1) { Write-Host "MISMATCH: $($r.event) $($r.file) -> $c"; $mismatch++ }
}
Write-Host "regs: $($regs.Count) | mismatches: $mismatch"

$be = @($settings.hooks['PreToolUse'] | Where-Object { $_.hooks.command -match 'block-explore-agent' })
Write-Host "block-explore: count=$($be.Count) matcher=$($be[0].matcher) cmd=$($be[0].hooks.command)"

# Idempotency: run the loop again, re-verify counts stay 1
foreach ($r in $regs) {
    $destUnix = (Join-Path $hooksDir $r.file) -replace '\\', '/'
    $rCmd = "bash `"$destUnix`""
    $matcherVal = if ($r.matcher) { $r.matcher } else { "" }
    MergeHookEntry $r.event $r.file $matcherVal $rCmd
}
$mismatch2 = 0
foreach ($r in $regs) {
    $c = @($settings.hooks[$r.event] | Where-Object { $_.hooks.command -match [regex]::Escape($r.file) }).Count
    if ($c -ne 1) { $mismatch2++ }
}
Write-Host "after 2nd pass (idempotency) | mismatches: $mismatch2"
