#!/usr/bin/env bash
# surfacing-duty-stop.sh — Claude Code Stop hook (command type)
# Surfaces duty reminders via stderr feedback after agent responses.
#
# Fires after every agent response. As a command-type Stop hook,
# stderr output is shown to the agent as feedback on its next turn.
#
# Two functions:
#   1. Periodic reminder: every 30+ minutes, remind about surfacing duty
#   2. Gap-acknowledgment detection: if agent said "gap" or "pre-existing"
#      without invoking /gap or writing TODO(gap):, prompt them to file
#
# Hook contract:
#   - Stop hook, command type (stderr → shown to agent as feedback)
#   - Exit 0 = allow, Exit 2 = block (we always allow)
#   - Must be fast (<50ms) — fires on every agent turn
#   - Must never crash or hang

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract session_id and transcript_path
session_id=""
transcript_path=""
if [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
fi
if [[ "$input" =~ \"transcript_path\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    transcript_path="${BASH_REMATCH[1]}"
fi

# Need transcript to scan
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

reminders=""

# --- 1. Periodic surfacing duty reminder ---
# Check session age via transcript file birth time.
# Inject reminder every 30 minutes (tracked via marker file).
if [ -n "$session_id" ]; then
    marker_dir="/tmp/aitools-surfacing-$session_id"
    mkdir -p "$marker_dir" 2>/dev/null || true
    marker="$marker_dir/last-reminder"
    now=$(date +%s)
    inject_reminder=false

    if [ ! -f "$marker" ]; then
        # First check: only inject if session is >30 min old
        # Use transcript modification time as proxy for session start
        if [ -f "$transcript_path" ]; then
            file_mod=$(stat -f %m "$transcript_path" 2>/dev/null || stat -c %Y "$transcript_path" 2>/dev/null || echo "$now")
            age=$(( now - file_mod ))
            # Transcript gets modified constantly; use birth time if available
            file_birth=$(stat -f %B "$transcript_path" 2>/dev/null || echo "$file_mod")
            session_age=$(( now - file_birth ))
            if [ "$session_age" -gt 1800 ]; then
                inject_reminder=true
            fi
        fi
    else
        last=$(cat "$marker")
        elapsed=$(( now - last ))
        if [ "$elapsed" -gt 1800 ]; then
            inject_reminder=true
        fi
    fi

    if [ "$inject_reminder" = "true" ]; then
        echo "$now" > "$marker"
        reminders="${reminders}Surfacing duty check: Have you found any gaps or ambiguities this session? File via /gap or leave a TODO(gap): comment. "
    fi
fi

# --- 2. Gap-acknowledgment detection ---
# Scan the last assistant message for gap-acknowledgment language
# without a corresponding /gap invocation or TODO(gap): marker.
#
# Suppression: if known-gaps.json was modified in the last 30 minutes,
# a gap was recently filed — suppress to avoid false positives when the
# agent is still discussing the gap after filing it.

_suppress_gap_check=false

# Check known-gaps.json modification time (cross-platform stat)
_gaps_file=""
if [ -n "${AITOOLS_REPO_PATH:-}" ]; then
    _gaps_file="$AITOOLS_REPO_PATH/reference/known-gaps.json"
elif [ -f "$HOME/repos/aitools/reference/known-gaps.json" ]; then
    _gaps_file="$HOME/repos/aitools/reference/known-gaps.json"
fi
if [ -n "$_gaps_file" ] && [ -f "$_gaps_file" ]; then
    _gaps_mod=$(stat -f %m "$_gaps_file" 2>/dev/null || stat -c %Y "$_gaps_file" 2>/dev/null || echo "0")
    _now_epoch=$(date +%s)
    _gaps_age=$(( _now_epoch - _gaps_mod ))
    if [ "$_gaps_age" -lt 1800 ]; then
        _suppress_gap_check=true
    fi
fi

if [ "$_suppress_gap_check" = "false" ]; then
    # Read only the last ~100 lines of transcript for speed.
    last_chunk=$(tail -100 "$transcript_path" 2>/dev/null || true)

    if [ -n "$last_chunk" ]; then
        # Check for gap-acknowledgment phrases
        has_gap_language=false
        if echo "$last_chunk" | grep -qiE "pre-existing gap|known gap|that.s a gap|existing gap|there.s a gap|gap I noticed|gap we found" 2>/dev/null; then
            has_gap_language=true
        fi

        # Check if /gap was invoked or TODO(gap): was written in same chunk
        has_filing=false
        if echo "$last_chunk" | grep -qE '/gap|TODO\(gap\)|known-gaps\.json' 2>/dev/null; then
            has_filing=true
        fi

        if [ "$has_gap_language" = "true" ] && [ "$has_filing" = "false" ]; then
            reminders="${reminders}You acknowledged a gap but did not file it. Per surfacing duty (.claude/rules/gap-governance.md): invoke /gap now, or write TODO(gap): in the current file if mid-task."
        fi
    fi
fi

# Output reminders (if any) to stderr (shown to agent as feedback).
if [ -n "$reminders" ]; then
    printf '%s' "$reminders" >&2
fi

exit 0
