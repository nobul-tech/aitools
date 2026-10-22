# ---------------------------------------------------------------------------
# Agentic merge via invoke_ai with refinement loop ([m]erge & adopt).
# Uses structured prompts from _ai_prompt_merge / _ai_prompt_merge_refine.
# Sets DIFF_REVIEW_RESULT to:
#   "merge"  -- [y]es: MERGED_CONTENT holds the accepted merge
#   "menu"   -- [n]o: the preview was rejected; prompt_diff_review shows its
#               menu again (nothing written)
#   "failed" -- the AI merge produced no valid output; MANAGED_MERGE_ERROR
#               holds the reason (deploy_managed_file logs it; nothing written)
# ---------------------------------------------------------------------------
MANAGED_MERGE_ERROR=""
_invoke_ai_merge() {
    local file_path="$1"
    local source_content="$2"
    local local_content="${3:-}"
    local diff_output="${4:-}"

    MANAGED_MERGE_ERROR=""

    # Read local from disk if not provided (backward compat)
    if [ -z "$local_content" ] && [ -f "$file_path" ]; then
        local_content=$(cat "$file_path")
    fi

    # Detect backend for transparency display
    local ai_backend="unknown"
    if command -v claude >/dev/null 2>&1; then
        ai_backend="claude"
    elif command -v agent >/dev/null 2>&1; then
        ai_backend="agent"
    fi
    local display_name
    display_name=$(basename "$file_path")
    printf '  >> AI merge: %s (balanced) -- merging %s...\n' "$ai_backend" "$display_name" > /dev/tty

    # Set validation context for _merge_validate wrapper
    _MERGE_VALIDATE_SOURCE="$source_content"
    _MERGE_VALIDATE_LOCAL="$local_content"

    local current_merge=""
    local iteration=0

    while true; do
        iteration=$((iteration + 1))
        local prompt_text

        if [ -z "$current_merge" ]; then
            prompt_text=$(_ai_prompt_merge "$file_path" "$source_content" "$local_content" "$diff_output")
        else
            local feedback
            printf '  refinement feedback: ' > /dev/tty
            read_tty_choice feedback "no feedback"
            prompt_text=$(_ai_prompt_merge_refine "$source_content" "$local_content" "$current_merge" "$feedback")
        fi

        local merged
        _start_spinner "merging $display_name (attempt $iteration)..."
        # invoke_ai returns 1 on failure with no stdout; || true suppresses set -e abort
        # (the empty result is checked just below)
        merged=$(printf '%s' "$prompt_text" | invoke_ai balanced none _merge_validate 1) || true
        _stop_spinner

        # Defense-in-depth: strip leading/trailing code fences if AI ignored instructions
        if [ -n "$merged" ]; then
            merged=$(printf '%s' "$merged" | perl -0777 -pe 's/\A```[^\n]*\n//; s/\n```\s*\z//')
        fi

        if [ -z "$merged" ]; then
            MANAGED_MERGE_ERROR="AI merge failed (iteration $iteration): ${AI_REJECT_REASON:-unknown error}"
            printf '  >> %s -- nothing written\n' "$MANAGED_MERGE_ERROR" > /dev/tty
            DIFF_REVIEW_RESULT="failed"
            return 0
        fi

        # Show merge preview
        printf '\n  --- merged result preview (first 30 lines) ---\n' > /dev/tty
        printf '%s\n' "$merged" | head -30 | while IFS= read -r line; do
            printf '  | %s\n' "$line" > /dev/tty
        done
        local total_lines
        total_lines=$(printf '%s\n' "$merged" | wc -l | tr -d ' ')
        if [ "$total_lines" -gt 30 ]; then
            printf '  | ... (%d more lines)\n' "$((total_lines - 30))" > /dev/tty
        fi
        printf '\n  [y]es accept / [r]efine / [n]o reject: ' > /dev/tty
        local accept
        read_tty_choice accept "reject the merge (back to the review menu)"
        case "$(printf '%s' "$accept" | tr '[:upper:]' '[:lower:]')" in
            y)
                MERGED_CONTENT="$merged"
                DIFF_REVIEW_RESULT="merge"
                printf '  >> merged: AI-merged content accepted (iteration %d)\n' "$iteration" > /dev/tty
                return 0
                ;;
            r)
                current_merge="$merged"
                printf '  >> refining merge (iteration %d)...\n' "$iteration" > /dev/tty
                continue
                ;;
            *)
                printf '  >> merge rejected -- back to the review menu\n' > /dev/tty
                DIFF_REVIEW_RESULT="menu"
                return 0
                ;;
        esac
    done
}
