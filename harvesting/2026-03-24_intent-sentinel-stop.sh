#!/usr/bin/env bash
# intent-sentinel-stop.sh — Claude Code Stop hook (command type)
# Detects when the agent has been operating without user input for
# multiple turns and resurfaces the user's last instruction.
#
# Two functions:
#   1. Turns-since-human tracker: counts agent turns since the last
#      human message appeared in the transcript. After N turns of
#      agent-only activity, extracts and injects the user's last
#      instruction via stderr.
#   2. Phase transition detector: when recent activity has been
#      Read-heavy (research phase) and the latest turn includes a
#      Write or Edit, injects a hard checkpoint reminder before the
#      agent continues into execution mode.
#
# Hook contract:
#   - Stop hook, command type (stderr -> shown to agent as feedback)
#   - Exit 0 = allow, Exit 2 = block (we always allow)
#   - Must be fast (<50ms) — fires on every agent turn
#   - Must never crash or hang
#   - Standalone — cannot source aitools-lib.sh
#
# Complements:
#   - estimate-refresh-stop.sh (Lagebeurteilung checkpoint — context growth)
#   - surfacing-duty-stop.sh (incident/ambiguity filing duty)
#   This hook addresses a different failure mode: within-conversation
#   context rot on the USER'S INTENT, not on situation awareness.
#
# Platform: macOS + Windows Git Bash (uname -s dispatch for stat)

set -euo pipefail

# --- Configuration (tune after deployment) ---
TURNS_THRESHOLD=3        # Agent turns without user input before injecting intent
READ_STREAK_THRESHOLD=5  # Consecutive Read/Grep turns to qualify as "research phase"
MAX_INTENT_CHARS=300     # Truncate injected intent to this length
COOLDOWN_TURNS=5         # After injecting, wait this many turns before re-injecting

# --- Read JSON from stdin ---
input=$(cat)

# --- Pure-bash JSON field extraction ---
# Same pattern as harvest-session.sh / standing-order-guard.sh.
# Handles simple top-level string values only.
json_field() {
    local json="$1" key="$2"
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
    if [[ "$json" =~ $pattern ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

session_id=$(json_field "$input" "session_id")
transcript_path=$(json_field "$input" "transcript_path")

# Both required — silent exit if missing
[ -n "$session_id" ] || exit 0
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

# --- Marker directory ---
marker_dir="/tmp/aitools-intent-$session_id"
mkdir -p "$marker_dir" 2>/dev/null || exit 0

# --- Turn counter (shared with other logic) ---
turn_file="$marker_dir/turn-count"
turn_count=0
if [ -f "$turn_file" ]; then
    turn_count=$(cat "$turn_file" 2>/dev/null || echo "0")
    if ! [[ "$turn_count" =~ ^[0-9]+$ ]]; then turn_count=0; fi
fi
turn_count=$((turn_count + 1))
printf '%d' "$turn_count" > "$turn_file"

reminders=""

# ==========================================================================
# FUNCTION 1: Turns-since-human tracker
# ==========================================================================
#
# Strategy: on each turn, scan the last ~200 lines of the transcript to
# count how many assistant entries appear after the last human entry.
# Only extract the actual human message text when the threshold is hit.
# Cache the extracted intent to avoid re-parsing on subsequent turns.

# Check cooldown: skip if we injected recently
last_inject_file="$marker_dir/last-intent-inject-turn"
last_inject_turn=0
if [ -f "$last_inject_file" ]; then
    last_inject_turn=$(cat "$last_inject_file" 2>/dev/null || echo "0")
    if ! [[ "$last_inject_turn" =~ ^[0-9]+$ ]]; then last_inject_turn=0; fi
fi
turns_since_inject=$((turn_count - last_inject_turn))

if [ "$turns_since_inject" -ge "$COOLDOWN_TURNS" ] || [ "$last_inject_turn" -eq 0 ]; then
    # Count turns since last human message by scanning tail of transcript.
    # Each JSONL line with "type":"assistant" after the last "type":"human"
    # is one agent turn.
    #
    # Use perl for reliable JSONL scanning — grep -P is not portable (macOS
    # BSD grep lacks it; cross-platform.md hook portability rules).
    agent_turns_since_human=$(tail -500 "$transcript_path" 2>/dev/null | \
        perl -ne '
            if (/"type"\s*:\s*"human"/ && !/"isSidechain"\s*:\s*true/) {
                $count = 0;
            } elsif (/"type"\s*:\s*"assistant"/ && !/"isSidechain"\s*:\s*true/) {
                $count++;
            }
            END { print $count // 0; }
        ' 2>/dev/null || echo "0")

    if ! [[ "$agent_turns_since_human" =~ ^[0-9]+$ ]]; then
        agent_turns_since_human=0
    fi

    if [ "$agent_turns_since_human" -ge "$TURNS_THRESHOLD" ]; then
        # Threshold hit — extract the user's last instruction.
        # Check cache first (avoid re-parsing transcript every time).
        cached_intent_file="$marker_dir/cached-intent"
        cached_intent_line_file="$marker_dir/cached-intent-line"
        intent_text=""

        # Find the last human message line number in the transcript tail.
        # We need the line content, not just the count.
        last_human_line=$(tail -500 "$transcript_path" 2>/dev/null | \
            perl -ne '
                if (/"type"\s*:\s*"human"/ && !/"isSidechain"\s*:\s*true/) {
                    $last = $_;
                }
                END { print $last if $last; }
            ' 2>/dev/null || true)

        if [ -n "$last_human_line" ]; then
            # Extract the text content from the human message.
            # JSONL structure: {"type":"human","message":{"content":[{"type":"text","text":"..."}]}}
            # Use perl to extract the first text block from message.content.
            intent_text=$(printf '%s' "$last_human_line" | \
                perl -ne '
                    # Extract the text field from the first text content block.
                    # The content array may have multiple blocks; we want the first text one.
                    # Pattern: "text":"<captured>" after "content":[ and "type":"text"
                    if (/"message"\s*:\s*\{.*?"content"\s*:\s*\[/) {
                        # Find text blocks — greedy but works for single-line JSONL
                        while (/"type"\s*:\s*"text"\s*,\s*"text"\s*:\s*"((?:[^"\\]|\\.)*)"/g) {
                            print $1;
                            last;  # First text block only
                        }
                    }
                ' 2>/dev/null || true)

            # Unescape JSON string escapes (\\n -> newline, \\" -> ", etc.)
            if [ -n "$intent_text" ]; then
                intent_text=$(printf '%s' "$intent_text" | \
                    perl -pe 's/\\n/ /g; s/\\"/"/g; s/\\\\/\\/g; s/\\t/ /g;' \
                    2>/dev/null || echo "$intent_text")
            fi
        fi

        # Truncate to MAX_INTENT_CHARS
        if [ -n "$intent_text" ] && [ "${#intent_text}" -gt "$MAX_INTENT_CHARS" ]; then
            intent_text="${intent_text:0:$MAX_INTENT_CHARS}..."
        fi

        if [ -n "$intent_text" ]; then
            # Record injection turn for cooldown
            printf '%d' "$turn_count" > "$last_inject_file"

            reminders="INTENT CHECK (${agent_turns_since_human} agent turns since last user input): The user's instruction was: \"${intent_text}\" — Are you still aligned with this intent? If you are transitioning from research to execution, confirm with the user first. Do not jump from investigation into code changes without explicit permission. "
        fi
    fi
fi

# ==========================================================================
# FUNCTION 2: Phase transition detector (Read-heavy -> Write/Edit)
# ==========================================================================
#
# Detects when the agent has been in a research phase (consecutive Read/Grep
# tool calls) and the most recent turn includes a Write or Edit. This is the
# specific failure mode: agent reads 100K tokens of files, then starts writing
# without checking back with the user.
#
# Strategy: scan the last ~100 lines of the transcript for tool_name fields.
# Build a sequence of recent tool calls. If the last tool is Write/Edit and
# the preceding N tools are Read/Grep, inject a phase transition warning.
#
# Only fires if Function 1 did NOT already inject (avoid double-injection).

if [ -z "$reminders" ]; then
    # Parse recent tool calls from transcript.
    # Tool calls appear in assistant messages as tool_use blocks.
    # In the JSONL, tool names appear in "name":"ToolName" within tool_use content blocks.
    # We look for the pattern in the last 200 lines.
    recent_tools=$(tail -200 "$transcript_path" 2>/dev/null | \
        perl -ne '
            # Match tool_use entries: "type":"tool_use"..."name":"ToolName"
            # Also match tool_name in tool_result entries for PostToolUse tracking
            while (/"type"\s*:\s*"tool_use".*?"name"\s*:\s*"(\w+)"/g) {
                print "$1\n";
            }
            # Alternate pattern: name before type
            while (/"name"\s*:\s*"(\w+)".*?"type"\s*:\s*"tool_use"/g) {
                print "$1\n";
            }
        ' 2>/dev/null || true)

    if [ -n "$recent_tools" ]; then
        # Get the last tool and count the preceding read-like tools
        last_tool=""
        read_streak=0
        saw_write=false

        # Process tools in order — we want to know:
        # 1. Is the last tool a Write or Edit?
        # 2. How many Read/Grep tools preceded it in an unbroken streak?
        while IFS= read -r tool; do
            case "$tool" in
                Read|Grep|Glob)
                    read_streak=$((read_streak + 1))
                    saw_write=false
                    ;;
                Write|Edit)
                    saw_write=true
                    last_tool="$tool"
                    ;;
                *)
                    # Bash, Agent, etc. — reset read streak
                    read_streak=0
                    saw_write=false
                    ;;
            esac
        done <<< "$recent_tools"

        if [ "$saw_write" = "true" ] && [ "$read_streak" -ge "$READ_STREAK_THRESHOLD" ]; then
            # Phase transition detected — also check if we already injected
            # a phase warning recently (separate cooldown from intent injection)
            phase_inject_file="$marker_dir/last-phase-inject-turn"
            last_phase_turn=0
            if [ -f "$phase_inject_file" ]; then
                last_phase_turn=$(cat "$phase_inject_file" 2>/dev/null || echo "0")
                if ! [[ "$last_phase_turn" =~ ^[0-9]+$ ]]; then last_phase_turn=0; fi
            fi
            turns_since_phase=$((turn_count - last_phase_turn))

            if [ "$turns_since_phase" -ge "$COOLDOWN_TURNS" ] || [ "$last_phase_turn" -eq 0 ]; then
                printf '%d' "$turn_count" > "$phase_inject_file"

                reminders="PHASE TRANSITION DETECTED: You have been reading files (${read_streak}+ consecutive Read/Grep calls) and just performed a ${last_tool}. This looks like a shift from research to execution. Before continuing: (1) Does this write align with the user's instruction? (2) Did you report your findings to the user before acting? (3) If this is a scratch/notes file, carry on. If this changes repo files, confirm with the user first. "
            fi
        fi
    fi
fi

# --- Output reminders (if any) to stderr (shown to agent as feedback) ---
if [ -n "$reminders" ]; then
    printf '%s' "$reminders" >&2
fi

exit 0
