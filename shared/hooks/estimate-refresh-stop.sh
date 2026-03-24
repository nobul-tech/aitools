#!/usr/bin/env bash
# estimate-refresh-stop.sh -- Claude Code Stop hook (command type)
# Combined Lagebeurteilung reminder + running estimate freshness tracker.
#
# Two functions:
#   1. Auto-track turn count via marker file (mechanical, no judgment)
#   2. At context threshold (estimated from turn count), inject
#      Lagebeurteilung reminder to update the running estimate
#
# The running estimate auto-update flow:
#   Agent updates estimate -> file mtime changes -> dashboard server's
#   file watcher detects change -> regenerates served HTML -> browser
#   polls and re-renders. This hook's job is to REMIND the agent to
#   update, not to update the estimate itself (that requires judgment).
#
# Freshness sources (checked in order):
#   1. JSON running estimate mtime (primary, always available)
#   2. Session DB updated_at (supplemental, if harness-db.py available)
#   If either source is fresh, suppress the stale reminder.
#
# Hook contract:
#   - Stop hook, command type (stderr -> shown to agent as feedback)
#   - Exit 0 = allow, Exit 2 = block (we always allow)
#   - Must be fast (<50ms) -- fires on every agent turn
#   - Must never crash or hang
#
# Related decisions:
#   D-CONTEXT-ROT-HOOK: Lagebeurteilung checkpoint at 20%+ context
#   D-OPERATIONAL-LEARNING-DUTY: OBSERVE-SURFACE-PROPOSE-CONNECT

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract session_id
session_id=""
if [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
fi

[ -n "$session_id" ] || exit 0

# --- Turn tracking via marker directory ---
marker_dir="/tmp/aitools-estimate-$session_id"
mkdir -p "$marker_dir" 2>/dev/null || exit 0

# Increment turn count
turn_file="$marker_dir/turn-count"
turn_count=0
if [ -f "$turn_file" ]; then
    turn_count=$(cat "$turn_file" 2>/dev/null || echo "0")
    if ! [[ "$turn_count" =~ ^[0-9]+$ ]]; then turn_count=0; fi
fi
turn_count=$((turn_count + 1))
printf '%d' "$turn_count" > "$turn_file"

# --- Lagebeurteilung checkpoint ---
# Heuristic: each agent turn uses ~2-5K tokens of context.
# At 200K total context, 20% = 40K tokens = ~10-20 turns.
# Inject reminder at turn 15, then every 15 turns after.
# This is conservative -- better to remind too early than too late.

LAGE_INTERVAL=15
reminders=""

last_lage_file="$marker_dir/last-lage-turn"
last_lage_turn=0
if [ -f "$last_lage_file" ]; then
    last_lage_turn=$(cat "$last_lage_file" 2>/dev/null || echo "0")
    if ! [[ "$last_lage_turn" =~ ^[0-9]+$ ]]; then last_lage_turn=0; fi
fi

turns_since_lage=$((turn_count - last_lage_turn))

if [ "$turn_count" -ge "$LAGE_INTERVAL" ] && [ "$turns_since_lage" -ge "$LAGE_INTERVAL" ]; then
    printf '%d' "$turn_count" > "$last_lage_file"

    reminders="Lagebeurteilung checkpoint (turn ${turn_count}): Context is growing. Update the running estimate with current situation, new findings, and decisions. If the dashboard server is running, the update will appear automatically. Key fields to refresh: schwerpunkt, situation.currentState, completedWork (append recent), findings (new ones), delegationLog (new entries), meta.version (increment). "
fi

# --- Estimate freshness check ---
# If a running estimate exists and hasn't been modified in 30+ minutes,
# remind the agent it may be stale.
if [ -z "$reminders" ] && [ "$turn_count" -ge 5 ]; then
    # Check every 10 turns
    if [ $((turn_count % 10)) -eq 0 ]; then
        # Find project root
        cwd=""
        if [[ "$input" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
            cwd="${BASH_REMATCH[1]}"
        fi

        if [ -n "$cwd" ]; then
            project_root=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$cwd")

            # Check for running estimate
            estimate=""
            if [ -f "$project_root/.aitools/channel/running-estimate.json" ]; then
                estimate="$project_root/.aitools/channel/running-estimate.json"
            fi
            # Check scratch dirs
            if [ -z "$estimate" ] && [ -d "$project_root/.scratch" ]; then
                for dir in "$project_root"/.scratch/session-*/; do
                    [ -d "$dir" ] || continue
                    for est in "$dir"/*running-estimate*.json; do
                        [ -f "$est" ] || continue
                        estimate="$est"
                        break 2
                    done
                done
            fi

            if [ -n "$estimate" ]; then
                now=$(date +%s)
                # Platform dispatch: macOS BSD stat vs GNU stat (Linux/Git Bash)
                if [ "$(uname -s)" = "Darwin" ]; then
                    est_mod=$(stat -f %m "$estimate" 2>/dev/null || echo "$now")
                else
                    est_mod=$(stat -c %Y "$estimate" 2>/dev/null || echo "$now")
                fi
                est_age=$((now - est_mod))
                if [ "$est_age" -gt 1800 ]; then
                    # Before flagging stale, check if session DB was recently updated
                    # (supplemental: agent may have written to DB but not exported yet)
                    db_fresh=false
                    if [ -n "$session_id" ] && [ -d "$project_root/.aitools/sessions" ]; then
                        db_prefix=$(printf '%s' "$session_id" | cut -c1-10)
                        db_file="$project_root/.aitools/sessions/${db_prefix}.db"
                        if [ -f "$db_file" ]; then
                            if [ "$(uname -s)" = "Darwin" ]; then
                                db_mod=$(stat -f %m "$db_file" 2>/dev/null || echo "0")
                            else
                                db_mod=$(stat -c %Y "$db_file" 2>/dev/null || echo "0")
                            fi
                            db_age=$((now - db_mod))
                            if [ "$db_age" -lt 1800 ]; then
                                db_fresh=true
                            fi
                        fi
                    fi
                    if [ "$db_fresh" = false ]; then
                        minutes=$((est_age / 60))
                        reminders="Running estimate is ${minutes} minutes stale. Consider updating it with current session state. "
                    fi
                fi
            fi
        fi
    fi
fi

# Output reminders (if any) to stderr (shown to agent as feedback)
if [ -n "$reminders" ]; then
    printf '%s' "$reminders" >&2
fi

exit 0
