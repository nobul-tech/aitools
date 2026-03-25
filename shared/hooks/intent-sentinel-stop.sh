#!/usr/bin/env bash
# intent-sentinel-stop.sh — Claude Code Stop hook (command type)
# Consolidated telemetry platform: fires every agent turn, collects
# metrics the commander cannot see, and resurfaces intent when drift
# is detected.
#
# Eight telemetry functions:
#   1. Turns-since-human tracker (resurface intent after 3 agent-only turns)
#   2. Phase transition detector (research→execution warning)
#   3. Context consumption tracker (milestones at 25/50/75%)
#   4. Tool usage profile (every 10 turns)
#   5. Subagent tracker (Agent tool launches + completion)
#   6. Running estimate freshness (stale >30min warning)
#   7. Delegation duty compliance score (6 elements)
#   8. Session duration + work product count (every 20 turns)
#
# Output: ONE consolidated status line every INJECT_INTERVAL turns.
# Additional detail lines when specific thresholds are hit.
#
# Hook contract:
#   - Stop hook, command type (stderr -> shown to agent as feedback)
#   - Exit 0 = allow (always)
#   - Must be fast (<50ms) — fires on every agent turn
#   - Must never crash or hang
#   - Standalone — cannot source aitools-lib.sh
#
# Complements:
#   - estimate-refresh-stop.sh (Lagebeurteilung checkpoint — context growth)
#   - surfacing-duty-stop.sh (incident/ambiguity filing duty)
#   This hook consolidates visibility into a single status line.
#
# KPI definitions (logged to harness DB):
#   - sentinel.turnCount: total turns this session
#   - sentinel.turnsSinceHuman: agent turns since last user input
#   - sentinel.contextPercent: estimated context consumption percentage
#   - sentinel.subagentCount: total subagents launched
#   - sentinel.delegationScore: duty elements present / 6
#   - sentinel.reStaleMinutes: running estimate age in minutes
#   - sentinel.scratchFileCount: files in .scratch/session-*
#
# Platform: macOS + Linux + Windows Git Bash (uname -s dispatch for stat)

set -euo pipefail

# --- Configuration (tune after deployment) ---
TURNS_THRESHOLD=3        # Agent turns without user input before injecting intent
READ_STREAK_THRESHOLD=5  # Consecutive Read/Grep turns to qualify as "research phase"
MAX_INTENT_CHARS=300     # Truncate injected intent to this length
INJECT_INTERVAL=5        # Consolidated status line every N turns
RE_STALE_MINUTES=30      # Running estimate stale threshold (minutes)
# Estimated context model: ~2-5K tokens per turn, ~200K total context
TOKENS_PER_TURN=3500     # Average tokens consumed per turn
TOTAL_CONTEXT=200000     # Estimated total context window

# --- Read JSON from stdin ---
input=$(cat)

# --- Pure-bash JSON field extraction ---
# Same pattern as standing-order-guard.sh / harvest-session.sh.
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
cwd=$(json_field "$input" "cwd")

# Both required — silent exit if missing
[ -n "$session_id" ] || exit 0
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

# --- Marker directory ---
marker_dir="/tmp/aitools-sentinel-$session_id"
mkdir -p "$marker_dir" 2>/dev/null || exit 0

# --- Turn counter ---
turn_file="$marker_dir/turn-count"
turn_count=0
if [ -f "$turn_file" ]; then
    turn_count=$(cat "$turn_file" 2>/dev/null || echo "0")
    if ! [[ "$turn_count" =~ ^[0-9]+$ ]]; then turn_count=0; fi
fi
turn_count=$((turn_count + 1))
printf '%d' "$turn_count" > "$turn_file"

# --- Session start marker (for duration tracking) ---
start_file="$marker_dir/session-start"
if [ ! -f "$start_file" ]; then
    date +%s > "$start_file"
fi

# --- Project root ---
project_root=""
if [ -n "$cwd" ]; then
    project_root=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
fi

# --- Accumulator for reminders ---
reminders=""
detail_reminders=""

# ==========================================================================
# FUNCTION 1: Turns-since-human tracker
# ==========================================================================
# Count agent turns since last human message. Only extract intent when
# threshold is hit.

agent_turns_since_human=0
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

intent_text=""
if [ "$agent_turns_since_human" -ge "$TURNS_THRESHOLD" ]; then
    # Extract the user's last instruction
    last_human_line=$(tail -500 "$transcript_path" 2>/dev/null | \
        perl -ne '
            if (/"type"\s*:\s*"human"/ && !/"isSidechain"\s*:\s*true/) {
                $last = $_;
            }
            END { print $last if $last; }
        ' 2>/dev/null || true)

    if [ -n "$last_human_line" ]; then
        intent_text=$(printf '%s' "$last_human_line" | \
            perl -ne '
                if (/"message"\s*:\s*\{.*?"content"\s*:\s*\[/) {
                    while (/"type"\s*:\s*"text"\s*,\s*"text"\s*:\s*"((?:[^"\\]|\\.)*)"/g) {
                        print $1;
                        last;
                    }
                }
            ' 2>/dev/null || true)

        if [ -n "$intent_text" ]; then
            intent_text=$(printf '%s' "$intent_text" | \
                perl -pe 's/\\n/ /g; s/\\"/"/g; s/\\\\/\\/g; s/\\t/ /g;' \
                2>/dev/null || echo "$intent_text")
        fi
    fi

    # Truncate
    if [ -n "$intent_text" ] && [ "${#intent_text}" -gt "$MAX_INTENT_CHARS" ]; then
        intent_text="${intent_text:0:$MAX_INTENT_CHARS}..."
    fi

    if [ -n "$intent_text" ]; then
        detail_reminders="${detail_reminders}INTENT CHECK (${agent_turns_since_human} turns since user): \"${intent_text}\" -- Still aligned? Confirm with user before shifting from research to execution. "
    fi
fi

# ==========================================================================
# FUNCTION 2: Phase transition detector (Read-heavy -> Write/Edit)
# ==========================================================================

if [ -z "$detail_reminders" ]; then
    recent_tools=$(tail -200 "$transcript_path" 2>/dev/null | \
        perl -ne '
            while (/"type"\s*:\s*"tool_use".*?"name"\s*:\s*"(\w+)"/g) {
                print "$1\n";
            }
            while (/"name"\s*:\s*"(\w+)".*?"type"\s*:\s*"tool_use"/g) {
                print "$1\n";
            }
        ' 2>/dev/null || true)

    if [ -n "$recent_tools" ]; then
        read_streak=0
        saw_write=false
        last_tool=""

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
                    read_streak=0
                    saw_write=false
                    ;;
            esac
        done <<< "$recent_tools"

        if [ "$saw_write" = "true" ] && [ "$read_streak" -ge "$READ_STREAK_THRESHOLD" ]; then
            detail_reminders="${detail_reminders}PHASE TRANSITION: ${read_streak}+ Read/Grep calls then ${last_tool}. Confirm with user before continuing execution on repo files. "
        fi
    fi
fi

# ==========================================================================
# FUNCTION 3: Context consumption tracker
# ==========================================================================

context_percent=$((turn_count * TOKENS_PER_TURN * 100 / TOTAL_CONTEXT))
if [ "$context_percent" -gt 100 ]; then context_percent=100; fi

# ==========================================================================
# FUNCTION 4: Tool usage profile (computed on injection turns only)
# ==========================================================================

tool_profile=""
if [ $((turn_count % INJECT_INTERVAL)) -eq 0 ]; then
    tool_profile=$(tail -500 "$transcript_path" 2>/dev/null | \
        perl -ne '
            while (/"type"\s*:\s*"tool_use".*?"name"\s*:\s*"(\w+)"/g) { $c{$1}++; }
            while (/"name"\s*:\s*"(\w+)".*?"type"\s*:\s*"tool_use"/g) { $c{$1}++; }
            END {
                my @parts;
                for my $t (sort { $c{$b} <=> $c{$a} } keys %c) {
                    push @parts, "$c{$t} $t";
                    last if @parts >= 5;
                }
                print join(", ", @parts) if @parts;
            }
        ' 2>/dev/null || true)
fi

# ==========================================================================
# FUNCTION 5: Subagent tracker
# ==========================================================================

subagent_info=""
if [ $((turn_count % INJECT_INTERVAL)) -eq 0 ]; then
    subagent_info=$(tail -1000 "$transcript_path" 2>/dev/null | \
        perl -ne '
            $launched++ if /"type"\s*:\s*"tool_use".*?"name"\s*:\s*"Agent"/;
            $launched++ if /"name"\s*:\s*"Agent".*?"type"\s*:\s*"tool_use"/;
            $complete++ if /"type"\s*:\s*"tool_result"/ && /"name"\s*:\s*"Agent"/;
            $complete++ if /"name"\s*:\s*"Agent"/ && /"type"\s*:\s*"tool_result"/;
            END {
                $launched //= 0;
                $complete //= 0;
                my $running = $launched - $complete;
                $running = 0 if $running < 0;
                print "${launched}L/${complete}C/${running}R" if $launched > 0;
            }
        ' 2>/dev/null || true)
fi

# ==========================================================================
# FUNCTION 6: Running estimate freshness
# ==========================================================================

re_stale_minutes=0
re_status="n/a"
if [ -n "$project_root" ]; then
    estimate=""
    if [ -f "$project_root/.aitools/channel/running-estimate.json" ]; then
        estimate="$project_root/.aitools/channel/running-estimate.json"
    fi

    if [ -n "$estimate" ]; then
        now=$(date +%s)
        if [ "$(uname -s)" = "Darwin" ]; then
            est_mod=$(stat -f %m "$estimate" 2>/dev/null || echo "$now")
        else
            est_mod=$(stat -c %Y "$estimate" 2>/dev/null || echo "$now")
        fi
        est_age=$((now - est_mod))
        re_stale_minutes=$((est_age / 60))
        if [ "$re_stale_minutes" -ge "$RE_STALE_MINUTES" ]; then
            re_status="STALE(${re_stale_minutes}m)"
            detail_reminders="${detail_reminders}Running estimate stale (${re_stale_minutes} min). Update with current state. "
        else
            re_status="fresh(${re_stale_minutes}m)"
        fi
    fi
fi

# ==========================================================================
# FUNCTION 7: Delegation duty compliance score
# ==========================================================================

deleg_score=""
if [ $((turn_count % INJECT_INTERVAL)) -eq 0 ]; then
    # Find the most recent Agent tool_use in transcript tail
    last_agent_prompt=$(tail -500 "$transcript_path" 2>/dev/null | \
        perl -ne '
            if (/"name"\s*:\s*"Agent"/ || /"type"\s*:\s*"tool_use".*?"name"\s*:\s*"Agent"/) {
                $last = $_;
            }
            END { print $last if $last; }
        ' 2>/dev/null || true)

    if [ -n "$last_agent_prompt" ]; then
        deleg_score=$(printf '%s' "$last_agent_prompt" | \
            perl -ne '
                my $score = 0;
                my @missing;
                # 1. Identity
                if (/S[1-9]|you are|your identity|your role/i) { $score++; }
                else { push @missing, "identity"; }
                # 2. Rules instruction
                if (/rules|CLAUDE\.md|\.claude\/rules/i) { $score++; }
                else { push @missing, "rules"; }
                # 3. Skills instruction
                if (/skills|SKILL\.md|shared\/skills/i) { $score++; }
                else { push @missing, "skills"; }
                # 4. Operational learning
                if (/operational learning|carry forward|OL-/i) { $score++; }
                else { push @missing, "OL"; }
                # 5. WRITE_BLOCKED signal
                if (/WRITE_BLOCKED/i) { $score++; }
                else { push @missing, "WRITE_BLOCKED"; }
                # 6. Access workaround
                if (/explicit paths|Glob\/Grep|cross-repo|OL-O12/i) { $score++; }
                else { push @missing, "access"; }
                my $missing_str = @missing ? " missing:" . join(",", @missing) : "";
                print "${score}/6${missing_str}";
            ' 2>/dev/null || true)
    fi
fi

# ==========================================================================
# FUNCTION 8: Session duration + work product count
# ==========================================================================

session_duration=""
scratch_count=0
commit_count=0
if [ $((turn_count % INJECT_INTERVAL)) -eq 0 ]; then
    # Duration
    session_start=0
    if [ -f "$start_file" ]; then
        session_start=$(cat "$start_file" 2>/dev/null || echo "0")
        if ! [[ "$session_start" =~ ^[0-9]+$ ]]; then session_start=0; fi
    fi
    if [ "$session_start" -gt 0 ]; then
        now=$(date +%s)
        elapsed=$((now - session_start))
        hours=$((elapsed / 3600))
        minutes=$(( (elapsed % 3600) / 60 ))
        if [ "$hours" -gt 0 ]; then
            session_duration="${hours}h${minutes}m"
        else
            session_duration="${minutes}m"
        fi
    fi

    # Scratch file count
    if [ -n "$project_root" ] && [ -d "$project_root/.scratch" ]; then
        session_prefix=$(printf '%s' "$session_id" | cut -c1-10)
        session_dir="$project_root/.scratch/session-$session_prefix"
        if [ -d "$session_dir" ]; then
            scratch_count=0
            for _f in "$session_dir"/*; do
                [ -f "$_f" ] || continue
                scratch_count=$((scratch_count + 1))
            done
        fi
    fi
fi

# ==========================================================================
# CONSOLIDATED STATUS LINE
# ==========================================================================

if [ $((turn_count % INJECT_INTERVAL)) -eq 0 ] && [ "$turn_count" -gt 0 ]; then
    # Build the consolidated status line
    status_parts="Turn ${turn_count} | Ctx ~${context_percent}%"
    status_parts="${status_parts} | ${agent_turns_since_human}t since human"

    if [ -n "$subagent_info" ]; then
        status_parts="${status_parts} | Sub: ${subagent_info}"
    fi

    status_parts="${status_parts} | RE: ${re_status}"

    if [ -n "$deleg_score" ]; then
        status_parts="${status_parts} | Deleg: ${deleg_score}"
    fi

    if [ -n "$session_duration" ]; then
        status_parts="${status_parts} | ${session_duration}, ${scratch_count} files"
    fi

    reminders="[sentinel] ${status_parts}"

    # Add tool profile on detail turns
    if [ -n "$tool_profile" ]; then
        reminders="${reminders} | Tools: ${tool_profile}"
    fi
fi

# --- Append detail reminders (intent/phase/stale) when thresholds hit ---
if [ -n "$detail_reminders" ]; then
    if [ -n "$reminders" ]; then
        reminders="${reminders} || ${detail_reminders}"
    else
        reminders="[sentinel] ${detail_reminders}"
    fi
fi

# --- Output to stderr (shown to agent as feedback) ---
if [ -n "$reminders" ]; then
    printf '%s' "$reminders" >&2

    # --- KPI logging to harness DB (only when injecting) ---
    if [ -n "$project_root" ]; then
        PYTHON=""
        if command -v python3 > /dev/null 2>&1; then
            PYTHON="python3"
        elif command -v python > /dev/null 2>&1; then
            PYTHON="python"
        fi

        if [ -n "$PYTHON" ]; then
            HELPER=""
            if [ -f "$project_root/scripts/harness-db.py" ]; then
                HELPER="$project_root/scripts/harness-db.py"
            elif [ -f "$HOME/repos/aitools/scripts/harness-db.py" ]; then
                HELPER="$HOME/repos/aitools/scripts/harness-db.py"
            fi

            if [ -n "$HELPER" ] && "$PYTHON" -c "import sqlite3" 2>/dev/null; then
                "$PYTHON" "$HELPER" log --session "$session_id" --type sitrep \
                    --agent "intent-sentinel" \
                    --message "$reminders" || true
            fi
        fi
    fi
fi

exit 0
