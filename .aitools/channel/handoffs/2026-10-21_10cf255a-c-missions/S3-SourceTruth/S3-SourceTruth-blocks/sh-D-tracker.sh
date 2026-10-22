# ---------------------------------------------------------------------------
# Deploy tracker: centralizes outcome counting and summary writing for
# loops that deploy multiple managed files (rules, skills, hooks).
# ---------------------------------------------------------------------------

# Reset all deploy tracker counters. Call before a deploy loop.
_DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
_DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
DEPLOY_TRACKER_TEXT=""

deploy_tracker_init() {
    _DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
    _DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
    DEPLOY_TRACKER_TEXT=""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# Args: $1=outcome $2=tool_name $3=item_name
deploy_tracker_record() {
    local outcome="$1" tool_name="$2" item_name="$3"
    case "$outcome" in
        added|created) _DT_ADDED=$((_DT_ADDED + 1))
                   write_summary DETAIL "$tool_name" "added: $item_name" ;;
        updated)   _DT_UPDATED=$((_DT_UPDATED + 1))
                   write_summary DETAIL "$tool_name" "updated: $item_name" ;;
        "accept & adopt") _DT_ACCEPTED=$((_DT_ACCEPTED + 1))
                       write_summary DETAIL "$tool_name" "accept & adopt: $item_name" ;;
        skipped)   _DT_SKIPPED=$((_DT_SKIPPED + 1))
                   write_summary DETAIL "$tool_name" "skipped: $item_name" ;;
        failed)    _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
    esac
}

# Write aggregate summary for a deploy loop. Uses non-zero counts.
# ERROR when any file failed, WARN when any was skipped, else OK.
# Sets DEPLOY_TRACKER_TEXT for use in log lines.
# Args: $1=tool_name
deploy_tracker_summary() {
    local tool_name="$1"
    local parts=""
    if [ "$_DT_ADDED" -gt 0 ];    then parts="$_DT_ADDED added"; fi
    if [ "$_DT_UPDATED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_UPDATED updated"; fi
    if [ "$_DT_ACCEPTED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_ACCEPTED accepted"; fi
    if [ "$_DT_VERIFIED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_VERIFIED verified"; fi
    if [ "$_DT_FAILED" -gt 0 ];   then parts="${parts:+$parts, }$_DT_FAILED failed"; fi
    if [ -z "$parts" ]; then parts="verified"; fi
    DEPLOY_TRACKER_TEXT="$parts"

    if [ "$_DT_FAILED" -gt 0 ]; then
        write_summary ERROR "$tool_name" "$_DT_FAILED failed"
    elif [ "$_DT_SKIPPED" -gt 0 ]; then
        write_summary WARN "$tool_name" "$_DT_SKIPPED skipped (user review)"
    else
        write_summary OK "$tool_name" "$parts"
    fi
}
