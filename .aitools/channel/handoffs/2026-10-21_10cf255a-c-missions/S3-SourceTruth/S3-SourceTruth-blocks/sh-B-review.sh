# ---------------------------------------------------------------------------
# Review choices -- what each one does. Applies to prompt_diff_review,
# deploy_managed_file and review_json_fields below (PS1 twins:
# Prompt-DiffReview, Deploy-ManagedFile, Review-JsonFields). Spec:
# reference/managed-file-deployment.md. Model and AI merge rules:
# .claude/rules/agentic-standards.md "Managed-file review choices and merge".
#
# Terms:
#   SOURCE       the content being deployed (repo or dotprofile); the source
#                of truth
#   LOCAL        the deployed file on disk
#   ADOPT TARGET the repo file SOURCE comes from (ADOPT_PATH). The caller
#                passes its path; this library writes it. "" = no adopt
#                target: adopt and merge are not offered.
# There is no ancestor and no deploy state: the only comparison is SOURCE
# against LOCAL (trailing newlines normalized).
#
# No menu is shown when:
#   LOCAL missing                       -> SOURCE written, "created"
#   LOCAL == SOURCE                     -> nothing written, "verified"
#   no terminal, EOF, or AITOOLS_FORCE  -> SOURCE written (backup), "updated"
#
# Text files (DEST not ending in .json), one review per file:
#   [o]verwrite      -> SOURCE written to LOCAL (backup kept); "updated"
#   [a]ccept & adopt -> LOCAL kept; LOCAL copied to the adopt target now;
#                       "accept & adopt"
#   [m]erge & adopt  -> AI merge (_invoke_ai_merge: invoke_ai balanced/none,
#                       validated, previewed; [y]es / [r]efine / [n]o). [y]:
#                       the merge is written to LOCAL and to the adopt target
#                       now; "accept & adopt". [n]: back to this menu. No valid
#                       merge output: nothing written; "failed".
#   [s]kip           -> nothing written; "skipped"; reviewed again next run
#   [x]abort         -> log_error, exit 2: ends this script
# After adopt or merge, SOURCE, LOCAL and the adopt target agree, so the next
# run verifies the file and asks nothing. A caller whose adopt target is not a
# plain copy of LOCAL (CLAUDE.md: machine footer stripped, profile tokens
# restored) passes an adopt filter; the adopt target gets the filtered content.
#
# JSON files (DEST ending in .json; review_json_fields): node compares SOURCE
# and LOCAL field by field (key path; a whole array is one field). Each
# differing field is one prompt_json_field_review: [o]verwrite (SOURCE value
# to LOCAL), [a]dopt (LOCAL value to the adopt target), [s]kip, [x]abort. No
# merge. A field only in LOCAL stays in LOCAL: with an adopt target and a
# terminal it gets [a]dopt / [s]kip / [x]abort (no overwrite); otherwise it is
# kept without a prompt. Key order is preserved in both files. One result per
# file, by precedence: failed > accept & adopt > skipped > updated > verified.
#
# Failure: every file a step writes (LOCAL, and the adopt target for adopt or
# merge) is snapshotted and backed up first (a failed backup of an existing
# file fails the step: nothing written) and validated after (non-empty; JSON
# parses and keeps SOURCE's top-level keys, except keys the review chose to
# leave absent). If a write, the merge or a validation fails, the files are
# restored, the reason is logged (log_error), the result is "failed" (the
# caller records it; deploy_tracker_summary writes an ERROR row) and the run
# continues with the next file. An adopt target listed in its repo's
# protected-files table (.claude/rules/sources-of-truth.md) gets a WARN that
# names it: working tree only; the review gate applies at commit. The library
# never commits or pushes: after adopt or merge it logs that the adopt
# target's repo has an uncommitted change to review and ship.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Show SOURCE against LOCAL and ask what to do ("Review choices" above).
#
# Args:
#   $1 = DEST, the deployed file on disk (LOCAL)
#   $2 = NEW_CONTENT, the SOURCE content
#   $3 = ADOPT_OFFERED: 1 offers [a]ccept & adopt and [m]erge & adopt; 0 hides them
#   $4 = CUR_CONTENT, LOCAL content (optional; read from DEST when empty)
#
# Sets DIFF_REVIEW_RESULT to "overwrite", "adopt", "merge", "skip" or
# "failed"; "merge" also sets MERGED_CONTENT; "failed" (the AI merge produced
# no valid output) sets MANAGED_MERGE_ERROR. Exits 2 on [x]abort
# (_managed_abort).
# Non-interactive, EOF at the prompt, --force / AITOOLS_FORCE: "overwrite".
# ---------------------------------------------------------------------------
DIFF_REVIEW_RESULT=""
_PDR_ADOPT_TARGET=""   # set by deploy_managed_file; shown in the review header only
prompt_diff_review() {
    local file_path="$1"
    local new_content="$2"
    local adopt_offered="${3:-0}"
    local cur_content="${4:-}"

    DIFF_REVIEW_RESULT="overwrite"
    MERGED_CONTENT=""

    # --force or AITOOLS_FORCE: auto-overwrite
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log_warn "Diff in $(display_path "$file_path") -- overwriting (--force)"
        return 0
    fi

    # Non-interactive: auto-overwrite
    if ! tty_interactive; then
        log_warn "Diff in $(display_path "$file_path") -- overwriting (non-interactive)"
        return 0
    fi

    # Read current file if not provided
    if [ -z "$cur_content" ] && [ -f "$file_path" ]; then
        cur_content=$(cat "$file_path")
    fi

    # Context header
    printf '\n\033[33m[REVIEW]\033[0m %s differs from source.\n' \
        "$(display_path "$file_path")" > /dev/tty
    printf '  source = the repo version (would deploy)\n' > /dev/tty
    printf '  local  = current file on disk\n' > /dev/tty
    if [ "$adopt_offered" = "1" ] && [ -n "$_PDR_ADOPT_TARGET" ]; then
        printf '  repo   = %s (adopt target)\n' "$(display_path "$_PDR_ADOPT_TARGET")" > /dev/tty
    fi
    printf '\n' > /dev/tty

    # Show diff
    local diff_output
    # diff exits 1 on differences (expected), suppress set -e abort
    diff_output=$(diff -u <(printf '%s' "$new_content") <(printf '%s' "$cur_content") \
        --label "source (would deploy)" --label "local (on disk)" 2>&1) || true
    local diff_lines
    diff_lines=$(printf '%s\n' "$diff_output" | wc -l | tr -d ' ')
    if [ "$diff_lines" -le 40 ]; then
        printf '%s\n' "$diff_output" > /dev/tty
    else
        printf '%s\n' "$diff_output" | head -30 > /dev/tty
        printf '  ... (%d more lines -- full diff in deploy log)\n' \
            "$((diff_lines - 30))" > /dev/tty
    fi
    # Full diff as structured [detail] records at every size (raw appends broke the log format).
    local diff_line
    while IFS= read -r diff_line; do
        log_detail "diff $(basename "$file_path"): $diff_line"
    done <<< "$diff_output"

    # Menu (parity: Prompt-DiffReview in aitools-lib.ps1). A rejected merge
    # preview ("menu") shows the menu again.
    local choice
    while true; do
        printf '\n' > /dev/tty
        printf '  [o]verwrite      : source wins -> written to local (backup kept)\n' > /dev/tty
        if [ "$adopt_offered" = "1" ]; then
            printf '  [a]ccept & adopt : local wins -> copied to the repo now\n' > /dev/tty
            printf '  [m]erge & adopt  : AI merge of source + local -> local and the repo\n' > /dev/tty
        fi
        printf '  [s]kip           : nothing written; asked again next run\n' > /dev/tty
        printf '  [x]abort         : stop this script (exit 2)\n' > /dev/tty
        if [ "$adopt_offered" = "1" ]; then
            printf '  choice [o/a/m/s/x]: ' > /dev/tty
        else
            printf '  choice [o/s/x]: ' > /dev/tty
        fi

        read_tty_choice choice "overwrite"
        case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
            a)  if [ "$adopt_offered" = "1" ]; then
                    printf '  >> accept & adopt: local kept, copied to the repo\n' > /dev/tty
                    DIFF_REVIEW_RESULT="adopt"
                else
                    printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                    DIFF_REVIEW_RESULT="overwrite"
                fi ;;
            m)  if [ "$adopt_offered" = "1" ]; then
                    _invoke_ai_merge "$file_path" "$new_content" "$cur_content" "$diff_output"
                else
                    printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                    DIFF_REVIEW_RESULT="overwrite"
                fi ;;
            s)  printf '  >> skipped: local file unchanged\n' > /dev/tty
                DIFF_REVIEW_RESULT="skip" ;;
            x)  _managed_abort ;;
            *)  printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                DIFF_REVIEW_RESULT="overwrite" ;;
        esac
        if [ "$DIFF_REVIEW_RESULT" != "menu" ]; then break; fi
    done
    return 0
}
