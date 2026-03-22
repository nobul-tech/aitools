#!/usr/bin/env bash
# surfacing-duty-stop.sh — Claude Code Stop hook (command type)
# Surfaces duty reminders via stderr feedback after agent responses.
#
# Fires after every agent response. As a command-type Stop hook,
# stderr output is shown to the agent as feedback on its next turn.
#
# Two functions:
#   1. Periodic reminder: every 30+ minutes, remind about surfacing duty
#   2. Incident-acknowledgment detection: if agent said "incident" or "pre-existing"
#      without invoking /incident or writing TODO(incident):, prompt them to file
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
            # Platform dispatch: macOS BSD stat vs GNU stat (Linux/Git Bash)
            # See session-archive.sh:68 for the canonical pattern
            if [ "$(uname -s)" = "Darwin" ]; then
                file_mod=$(stat -f %m "$transcript_path" 2>/dev/null || echo "$now")
            else
                file_mod=$(stat -c %Y "$transcript_path" 2>/dev/null || echo "$now")
            fi
            age=$(( now - file_mod ))
            # Transcript gets modified constantly; use birth time if available
            if [ "$(uname -s)" = "Darwin" ]; then
                file_birth=$(stat -f %B "$transcript_path" 2>/dev/null || echo "$file_mod")
            else
                # GNU stat: %W = birth time (0 if unsupported), fallback to mod time
                _birth=$(stat -c %W "$transcript_path" 2>/dev/null || echo "0")
                if [ "$_birth" != "0" ] && [ -n "$_birth" ]; then
                    file_birth="$_birth"
                else
                    file_birth="$file_mod"
                fi
            fi
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
        reminders="${reminders}Surfacing duty check: Have you found any incidents or ambiguities this session? File via /incident or leave a TODO(incident): comment. "
    fi
fi

# --- 2. Incident-acknowledgment detection ---
# Scan the last assistant message for incident-acknowledgment language
# without a corresponding /incident invocation or TODO(incident): marker.
#
# Suppression: if incidents.json was modified in the last 30 minutes,
# an incident was recently filed — suppress to avoid false positives when the
# agent is still discussing the incident after filing it.

_suppress_incident_check=false

# Check incidents.json modification time (cross-platform stat)
_incidents_file=""
if [ -n "${AITOOLS_REPO_PATH:-}" ]; then
    _incidents_file="$AITOOLS_REPO_PATH/reference/incidents.json"
elif [ -f "$HOME/repos/aitools/reference/incidents.json" ]; then
    _incidents_file="$HOME/repos/aitools/reference/incidents.json"
fi
if [ -n "$_incidents_file" ] && [ -f "$_incidents_file" ]; then
    # Platform dispatch: macOS BSD stat vs GNU stat (Linux/Git Bash)
    if [ "$(uname -s)" = "Darwin" ]; then
        _incidents_mod=$(stat -f %m "$_incidents_file" 2>/dev/null || echo "0")
    else
        _incidents_mod=$(stat -c %Y "$_incidents_file" 2>/dev/null || echo "0")
    fi
    _now_epoch=$(date +%s)
    _incidents_age=$(( _now_epoch - _incidents_mod ))
    if [ "$_incidents_age" -lt 1800 ]; then
        _suppress_incident_check=true
    fi
fi

if [ "$_suppress_incident_check" = "false" ]; then
    # Read only the last ~100 lines of transcript for speed.
    last_chunk=$(tail -100 "$transcript_path" 2>/dev/null || true)

    if [ -n "$last_chunk" ]; then
        # Check for incident-acknowledgment phrases
        has_incident_language=false
        if echo "$last_chunk" | grep -qiE "pre-existing incident|known incident|that.s an incident|existing incident|there.s an incident|incident I noticed|incident we found|pre-existing gap|known gap|that.s a gap|existing gap|there.s a gap|gap I noticed|gap we found" 2>/dev/null; then
            has_incident_language=true
        fi

        # Check if /incident was invoked or TODO(incident): was written in same chunk
        has_filing=false
        if echo "$last_chunk" | grep -qE '/incident|TODO\(incident\)|incidents\.json' 2>/dev/null; then
            has_filing=true
        fi

        if [ "$has_incident_language" = "true" ] && [ "$has_filing" = "false" ]; then
            reminders="${reminders}You acknowledged an incident but did not file it. Per surfacing duty (.claude/rules/incident-governance.md): invoke /incident now, or write TODO(incident): in the current file if mid-task."
        fi
    fi
fi

# Output reminders (if any) to stderr (shown to agent as feedback).
if [ -n "$reminders" ]; then
    printf '%s' "$reminders" >&2
fi

exit 0
