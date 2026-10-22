# ---------------------------------------------------------------------------
# Granular per-leaf review prompt for JSON settings sync (sync_managed_json)
# and the JSON field review (review_json_fields).
# One prompt per divergent setting/rule. overwrite/adopt/skip are per-leaf;
# abort (x) is global and exits the run (code 2, abort marker per D-TS13).
#
# Args:
#   $1 = leaf display name (e.g. "theme" or "permissions.deny MCP(vercel)")
#   $2 = current value display (the local file's side)
#   $3 = proposed value display (the source side)
#   $4 = source label (e.g. "profile.json")
#   $5 = adopt-allowed flag ("1" to offer adopt, else hidden)
#   $6 = local label (default "settings.json")
#   $7 = overwrite-allowed flag (default "1"; "0" for a field only in the
#        local file: no [o]verwrite, and the default answer is skip)
#
# Sets JSON_FIELD_REVIEW_RESULT to "overwrite", "adopt", or "skip".
# --force / AITOOLS_FORCE / non-interactive -> "overwrite" (source wins), or
# "skip" when overwrite is not allowed.
# ---------------------------------------------------------------------------
JSON_FIELD_REVIEW_RESULT=""
prompt_json_field_review() {
    local leaf="$1" current="$2" proposed="$3" source_label="${4:-profile.json}" adopt_allowed="${5:-1}"
    local local_label="${6:-settings.json}" overwrite_allowed="${7:-1}"
    local default_choice="overwrite" default_desc="overwriting from $source_label"
    if [ "$overwrite_allowed" != "1" ]; then
        default_choice="skip"; default_desc="skipping (only in $local_label)"
    fi

    JSON_FIELD_REVIEW_RESULT="$default_choice"

    # --force / AITOOLS_FORCE: source wins
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log "Divergence in $leaf -- $default_desc (--force)"
        return 0
    fi
    # Non-interactive: source wins
    if ! tty_interactive; then
        log "Divergence in $leaf -- $default_desc (non-interactive)"
        return 0
    fi

    printf '\n\033[33m[REVIEW]\033[0m %s differs from %s.\n' "$leaf" "$source_label" > /dev/tty
    printf '  %s : %s\n' "$local_label" "$current" > /dev/tty
    printf '  %s : %s\n' "$source_label" "$proposed" > /dev/tty
    printf '\n' > /dev/tty
    if [ "$overwrite_allowed" = "1" ]; then
        printf '  [o]verwrite : %s value -> %s\n' "$source_label" "$local_label" > /dev/tty
    fi
    if [ "$adopt_allowed" = "1" ]; then
        printf '  [a]dopt     : keep %s value -> write to %s\n' "$local_label" "$source_label" > /dev/tty
    fi
    printf '  [s]kip      : leave this setting unchanged\n' > /dev/tty
    printf '  [x]abort    : stop the run\n' > /dev/tty
    if [ "$overwrite_allowed" != "1" ]; then
        printf '  choice [a/s/x]: ' > /dev/tty
    elif [ "$adopt_allowed" = "1" ]; then
        printf '  choice [o/a/s/x]: ' > /dev/tty
    else
        printf '  choice [o/s/x]: ' > /dev/tty
    fi

    local choice
    read_tty_choice choice "$default_desc"
    case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
        a)  if [ "$adopt_allowed" = "1" ]; then
                printf '  >> adopted: %s value kept -> %s\n' "$local_label" "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="adopt"
            elif [ "$overwrite_allowed" = "1" ]; then
                printf '  >> overwritten from %s\n' "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="skip"
            fi ;;
        s)  printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
            JSON_FIELD_REVIEW_RESULT="skip" ;;
        x)  _managed_abort ;;
        *)  if [ "$overwrite_allowed" = "1" ]; then
                printf '  >> overwritten from %s\n' "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="skip"
            fi ;;
    esac
    return 0
}
