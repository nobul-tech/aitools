# ---------------------------------------------------------------------------
# Review choices -- what each one does. Applies to Prompt-DiffReview,
# Deploy-ManagedFile and Review-JsonFields below (bash twins:
# prompt_diff_review, deploy_managed_file, review_json_fields). Spec:
# reference/managed-file-deployment.md. Model and AI merge rules:
# .claude/rules/agentic-standards.md "Managed-file review choices and merge".
#
# Terms:
#   SOURCE       the content being deployed (repo or dotprofile); the source
#                of truth
#   LOCAL        the deployed file on disk
#   ADOPT TARGET the repo file SOURCE comes from (-AdoptPath). The caller
#                passes its path; this library writes it. "" = no adopt
#                target: adopt and merge are not offered.
# There is no ancestor and no deploy state: the only comparison is SOURCE
# against LOCAL (trailing newlines normalized, case-sensitive).
#
# No menu is shown when:
#   LOCAL missing                       -> SOURCE written, "created"
#   LOCAL == SOURCE                     -> nothing written, "verified"
#   no console, EOF, or AITOOLS_FORCE   -> SOURCE written (backup), "updated"
#
# Text files (DestPath not ending in .json), one review per file:
#   [o]verwrite      -> SOURCE written to LOCAL (backup kept); "updated"
#   [a]ccept & adopt -> LOCAL kept; LOCAL copied to the adopt target now;
#                       "accept & adopt"
#   [m]erge & adopt  -> AI merge (Invoke-AiMerge: Invoke-AI balanced/none,
#                       validated, previewed; [y]es / [r]efine / [n]o). [y]:
#                       the merge is written to LOCAL and to the adopt target
#                       now; "accept & adopt". [n]: back to this menu. No valid
#                       merge output: nothing written; "failed".
#   [s]kip           -> nothing written; "skipped"; reviewed again next run
#   [x]abort         -> LogError, abort marker (AITOOLS_ABORT_FILE, D-TS13),
#                       exit 2: ends this script
# After adopt or merge, SOURCE, LOCAL and the adopt target agree, so the next
# run verifies the file and asks nothing. A caller whose adopt target is not a
# plain copy of LOCAL (CLAUDE.md: machine footer stripped, profile tokens
# restored) passes -AdoptFilter; the adopt target gets the filtered content.
#
# JSON files (DestPath ending in .json; Review-JsonFields): node compares
# SOURCE and LOCAL field by field (key path; a whole array is one field). Each
# differing field is one Prompt-JsonFieldReview: [o]verwrite (SOURCE value to
# LOCAL), [a]dopt (LOCAL value to the adopt target), [s]kip, [x]abort. No
# merge. A field only in LOCAL stays in LOCAL: with an adopt target and a
# console it gets [a]dopt / [s]kip / [x]abort (no overwrite); otherwise it is
# kept without a prompt. Key order is preserved in both files. One result per
# file, by precedence: failed > accept & adopt > skipped > updated > verified.
#
# Failure: every file a step writes (LOCAL, and the adopt target for adopt or
# merge) is snapshotted and backed up first (a failed backup of an existing
# file fails the step: nothing written) and validated after (non-empty; JSON
# parses and keeps SOURCE's top-level keys, except keys the review chose to
# leave absent). If a write, the merge or a validation fails, the files are
# restored, the reason is logged (LogError), the result is "failed" (the
# caller records it; Write-DeployTrackerSummary writes an ERROR row) and the
# run continues with the next file. An adopt target listed in its repo's
# protected-files table (.claude/rules/sources-of-truth.md) gets a WARN that
# names it: working tree only; the review gate applies at commit. The library
# never commits or pushes: after adopt or merge it logs that the adopt
# target's repo has an uncommitted change to review and ship.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Show SOURCE against LOCAL and ask what to do ("Review choices" above).
#
# Params: -FilePath (LOCAL), -NewContent (SOURCE), -AdoptOffered ($true offers
# [a]ccept & adopt and [m]erge & adopt), -CurrentContent (optional; read from
# FilePath when empty).
# Returns "overwrite", "adopt", "merge", "skip" or "failed"; "merge" also sets
# $script:MergedContent; "failed" (the AI merge produced no valid output) sets
# $script:ManagedMergeError. Exits 2 on [x]abort (Invoke-ManagedAbort).
# Non-interactive, EOF at the prompt, -Force / AITOOLS_FORCE: "overwrite".
# ---------------------------------------------------------------------------
$script:MergedContent = $null
$script:PdrAdoptTarget = ""   # set by Deploy-ManagedFile; shown in the review header only
function Prompt-DiffReview {
    param(
        [string]$FilePath,
        [string]$NewContent,
        [bool]$AdoptOffered = $false,
        [string]$CurrentContent = ""
    )

    $script:MergedContent = $null

    # -Force or AITOOLS_FORCE: auto-overwrite
    if ($env:AITOOLS_FORCE -eq "1" -or $Force) {
        LogWarn "Diff in $FilePath -- overwriting (-Force)"
        return "overwrite"
    }

    # Non-interactive: auto-overwrite
    if (-not (Test-InteractiveConsole)) {
        LogWarn "Diff in $FilePath -- overwriting (non-interactive)"
        return "overwrite"
    }

    # Read current file if not provided
    if (-not $CurrentContent) {
        try {
            $CurrentContent = Get-Content $FilePath -Raw -ErrorAction Stop
        } catch {
            LogWarn "Cannot read $FilePath for diff: $_"
            return "overwrite"
        }
    }

    # Context header
    [Console]::WriteLine("")
    [Console]::WriteLine("[REVIEW] $FilePath differs from source.")
    [Console]::WriteLine("  source = the repo version (would deploy)")
    [Console]::WriteLine("  local  = current file on disk")
    if ($AdoptOffered -and $script:PdrAdoptTarget) {
        [Console]::WriteLine("  repo   = $($script:PdrAdoptTarget) (adopt target)")
    }
    [Console]::WriteLine("")

    # Generate line-level diff
    $srcLines = @($NewContent -split "`n")
    $curLines = @($CurrentContent -split "`n")
    $diffs = Compare-Object $srcLines $curLines -CaseSensitive
    $diffCount = 0
    $diffOutput = ""
    if ($diffs) {
        $diffCount = @($diffs).Count
        # Build diff text for AI merge prompt
        $diffLines = @()
        foreach ($d in $diffs) {
            $prefix = if ($d.SideIndicator -eq "=>") { "+ " } else { "- " }
            $diffLines += "${prefix}$($d.InputObject)"
        }
        $diffOutput = $diffLines -join "`n"
        # Full diff as [detail] records at every size (the console truncates at 30).
        $leafName = Split-Path -Leaf $FilePath
        foreach ($dl in $diffLines) { LogDetail "diff ${leafName}: $dl" }
    }

    if ($diffCount -eq 0) {
        [Console]::WriteLine("  (whitespace-only differences)")
    } elseif ($diffCount -le 40) {
        foreach ($d in $diffs) {
            $indicator = if ($d.SideIndicator -eq "=>") { "+ local  " } else { "- source " }
            [Console]::WriteLine("  $indicator$($d.InputObject)")
        }
    } else {
        $shown = 0
        foreach ($d in $diffs) {
            if ($shown -ge 30) { break }
            $indicator = if ($d.SideIndicator -eq "=>") { "+ local  " } else { "- source " }
            [Console]::WriteLine("  $indicator$($d.InputObject)")
            $shown++
        }
        [Console]::WriteLine("  ... ($($diffCount - 30) more lines -- see deploy log)")
    }

    # Menu (parity: prompt_diff_review in aitools-lib.sh). A rejected merge
    # preview ("menu") shows the menu again.
    while ($true) {
        [Console]::WriteLine("")
        [Console]::WriteLine("  [o]verwrite      : source wins -> written to local (backup kept)")
        if ($AdoptOffered) {
            [Console]::WriteLine("  [a]ccept & adopt : local wins -> copied to the repo now")
            [Console]::WriteLine("  [m]erge & adopt  : AI merge of source + local -> local and the repo")
        }
        [Console]::WriteLine("  [s]kip           : nothing written; asked again next run")
        [Console]::WriteLine("  [x]abort         : stop this script (exit 2)")
        if ($AdoptOffered) {
            [Console]::Write("  choice [o/a/m/s/x]: ")
        } else {
            [Console]::Write("  choice [o/s/x]: ")
        }

        $choice = Read-ConsoleChoice "overwrite"
        switch ($choice.ToLower()) {
            "a" {
                if ($AdoptOffered) {
                    [Console]::WriteLine("  >> accept & adopt: local kept, copied to the repo")
                    return "adopt"
                }
                [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                return "overwrite"
            }
            "m" {
                if ($AdoptOffered) {
                    $mergeResult = Invoke-AiMerge -FilePath $FilePath -SourceContent $NewContent -LocalContent $CurrentContent -DiffOutput $diffOutput
                    if ($mergeResult -ne "menu") { return $mergeResult }
                } else {
                    [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                    return "overwrite"
                }
            }
            "s" {
                [Console]::WriteLine("  >> skipped: local file unchanged")
                return "skip"
            }
            "x" {
                Invoke-ManagedAbort
            }
            default {
                [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                return "overwrite"
            }
        }
    }
}
