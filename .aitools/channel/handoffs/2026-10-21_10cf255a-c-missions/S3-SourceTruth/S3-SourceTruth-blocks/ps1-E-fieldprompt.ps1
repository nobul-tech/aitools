# ---------------------------------------------------------------------------
# Granular per-leaf review prompt for JSON settings sync (Sync-ManagedJson)
# and the JSON field review (Review-JsonFields). Mirror of
# prompt_json_field_review in aitools-lib.sh. One prompt per divergent
# setting/rule. overwrite/adopt/skip are per-leaf; abort (x) exits (code 2).
# -LocalLabel names the local file's side (default "settings.json").
# -OverwriteAllowed "0" (a field only in the local file): no [o]verwrite, and
# the default answer is skip.
# Returns "overwrite", "adopt", or "skip".
# -Force / AITOOLS_FORCE / non-interactive -> "overwrite" (source wins), or
# "skip" when overwrite is not allowed.
# ---------------------------------------------------------------------------
function Prompt-JsonFieldReview {
    param(
        [string]$Leaf,
        [string]$Current,
        [string]$Proposed,
        [string]$SourceLabel = "profile.json",
        [string]$AdoptAllowed = "1",
        [string]$LocalLabel = "settings.json",
        [string]$OverwriteAllowed = "1"
    )

    $defaultChoice = "overwrite"
    $defaultDesc = "overwriting from $SourceLabel"
    if ($OverwriteAllowed -ne "1") {
        $defaultChoice = "skip"
        $defaultDesc = "skipping (only in $LocalLabel)"
    }

    if ($env:AITOOLS_FORCE -eq "1" -or $Force) {
        Log "Divergence in $Leaf -- $defaultDesc (--force)"
        return $defaultChoice
    }
    if (-not (Test-InteractiveConsole)) {
        Log "Divergence in $Leaf -- $defaultDesc (non-interactive)"
        return $defaultChoice
    }

    [Console]::WriteLine("")
    [Console]::WriteLine("[REVIEW] $Leaf differs from $SourceLabel.")
    [Console]::WriteLine("  ${LocalLabel} : $Current")
    [Console]::WriteLine("  ${SourceLabel} : $Proposed")
    [Console]::WriteLine("")
    if ($OverwriteAllowed -eq "1") {
        [Console]::WriteLine("  [o]verwrite : $SourceLabel value -> $LocalLabel")
    }
    if ($AdoptAllowed -eq "1") {
        [Console]::WriteLine("  [a]dopt     : keep $LocalLabel value -> write to $SourceLabel")
    }
    [Console]::WriteLine("  [s]kip      : leave this setting unchanged")
    [Console]::WriteLine("  [x]abort    : stop the run")
    if ($OverwriteAllowed -ne "1") {
        [Console]::Write("  choice [a/s/x]: ")
    } elseif ($AdoptAllowed -eq "1") {
        [Console]::Write("  choice [o/a/s/x]: ")
    } else {
        [Console]::Write("  choice [o/s/x]: ")
    }

    $choice = Read-ConsoleChoice $defaultDesc
    switch ($choice.ToLower()) {
        "a" {
            if ($AdoptAllowed -eq "1") {
                [Console]::WriteLine("  >> adopted: $LocalLabel value kept -> $SourceLabel")
                return "adopt"
            }
            if ($OverwriteAllowed -eq "1") {
                [Console]::WriteLine("  >> overwritten from $SourceLabel")
                return "overwrite"
            }
            [Console]::WriteLine("  >> skipped: $Leaf unchanged")
            return "skip"
        }
        "s" { [Console]::WriteLine("  >> skipped: $Leaf unchanged"); return "skip" }
        "x" { Invoke-ManagedAbort }
        default {
            if ($OverwriteAllowed -eq "1") {
                [Console]::WriteLine("  >> overwritten from $SourceLabel")
                return "overwrite"
            }
            [Console]::WriteLine("  >> skipped: $Leaf unchanged")
            return "skip"
        }
    }
}
