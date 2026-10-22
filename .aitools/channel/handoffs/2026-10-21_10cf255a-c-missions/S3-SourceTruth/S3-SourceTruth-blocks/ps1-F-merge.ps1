# ---------------------------------------------------------------------------
# Agentic merge via Invoke-AI with refinement loop ([m]erge & adopt).
# Uses structured prompts from Get-AiMergePrompt / Get-AiMergeRefinePrompt.
# Parity: _invoke_ai_merge in aitools-lib.sh. Returns:
#   "merge"  -- [y]es: $script:MergedContent holds the accepted merge
#   "menu"   -- [n]o: the preview was rejected; Prompt-DiffReview shows its
#               menu again (nothing written)
#   "failed" -- the AI merge produced no valid output; $script:ManagedMergeError
#               holds the reason (Deploy-ManagedFile logs it; nothing written)
# ---------------------------------------------------------------------------
$script:ManagedMergeError = ""
function Invoke-AiMerge {
    param(
        [string]$FilePath,
        [string]$SourceContent,
        [string]$LocalContent,
        [string]$DiffOutput = ""
    )

    $script:ManagedMergeError = ""

    # Detect backend for transparency display
    # Get-Command exempt: command-existence check with explicit fallback
    $aiBackend = "unknown"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $aiBackend = "claude"
    } elseif (Get-Command agent -ErrorAction SilentlyContinue) {
        $aiBackend = "agent"
    }
    $displayName = Split-Path -Leaf $FilePath
    [Console]::WriteLine("  >> AI merge: $aiBackend (balanced) -- merging $displayName...")

    # Set validation context for _MergeValidateWrapper
    $script:_mergeValidateSource = $SourceContent
    $script:_mergeValidateLocal = $LocalContent

    $currentMerge = ""
    $iteration = 0

    while ($true) {
        $iteration++

        if (-not $currentMerge) {
            $promptText = Get-AiMergePrompt -FilePath $FilePath -SourceContent $SourceContent `
                -LocalContent $LocalContent -DiffOutput $DiffOutput
        } else {
            [Console]::Write("  refinement feedback: ")
            $feedback = Read-ConsoleChoice "no feedback"
            $promptText = Get-AiMergeRefinePrompt -SourceContent $SourceContent `
                -LocalContent $LocalContent -CurrentMerge $currentMerge -Feedback $feedback
        }

        Start-AiSpinner "merging $displayName (attempt $iteration)..."
        $merged = $promptText | Invoke-AI -Speed "balanced" -Permissions "none" `
            -ValidateFn "_MergeValidateWrapper" -MaxRetries 1
        Stop-AiSpinner

        # Defense-in-depth: strip leading/trailing code fences if AI ignored instructions
        if ($merged) {
            $merged = $merged -replace '(?s)\A```[^\n]*\n', '' -replace '\n```\s*\z', ''
        }

        if (-not $merged) {
            $reason = if ($script:AIRejectReason) { $script:AIRejectReason } else { "unknown error" }
            $script:ManagedMergeError = "AI merge failed (iteration $iteration): $reason"
            [Console]::WriteLine("  >> $($script:ManagedMergeError) -- nothing written")
            return "failed"
        }

        # Show merge preview
        [Console]::WriteLine("")
        [Console]::WriteLine("  --- merged result preview (first 30 lines) ---")
        $mergedLines = $merged -split "`n"
        $previewCount = [Math]::Min(30, $mergedLines.Count)
        for ($i = 0; $i -lt $previewCount; $i++) {
            [Console]::WriteLine("  | $($mergedLines[$i])")
        }
        if ($mergedLines.Count -gt 30) {
            [Console]::WriteLine("  | ... ($($mergedLines.Count - 30) more lines)")
        }
        [Console]::WriteLine("")
        [Console]::Write("  [y]es accept / [r]efine / [n]o reject: ")
        $accept = Read-ConsoleChoice "reject the merge (back to the review menu)"
        switch ($accept.ToLower()) {
            "y" {
                $script:MergedContent = $merged
                [Console]::WriteLine("  >> merged: AI-merged content accepted (iteration $iteration)")
                return "merge"
            }
            "r" {
                $currentMerge = $merged
                [Console]::WriteLine("  >> refining merge (iteration $iteration)...")
                # continue loop
            }
            default {
                [Console]::WriteLine("  >> merge rejected -- back to the review menu")
                return "menu"
            }
        }
    }
}
