#!/usr/bin/env bash
# delegation-duty-guard.sh — Claude Code PreToolUse hook (matcher: Agent)
# Checks subagent delegation prompts for 6 duty elements and injects
# a corrective reminder via stderr when elements are missing.
#
# OBSERVE mode: always allows (exit 0), reminds on gaps.
# Future: promote to enforce after observation period.
#
# Six delegation duty elements:
#   1. Identity (role name, "you are", etc.)
#   2. Rules instruction (CLAUDE.md, .claude/rules)
#   3. Skills instruction (skills, SKILL.md, shared/skills)
#   4. Operational learning (OL, carry forward)
#   5. WRITE_BLOCKED signal
#   6. Access workaround (explicit paths, Glob/Grep, OL-O12)
#
# Hook contract:
#   - PreToolUse hook, matcher: Agent
#   - Receives JSON on stdin (tool_name, tool_input)
#   - Exit 0 = allow (always, OBSERVE mode)
#   - stderr -> shown to agent as feedback
#   - Must be fast (<50ms)
#   - Must never crash or hang
#   - Standalone — cannot source aitools-lib.sh
#
# KPI definitions (logged to harness DB):
#   - delegation.score: duty elements present / 6
#   - delegation.missing: comma-separated list of missing elements
#   - delegation.promptLength: approximate prompt length
#
# Platform: macOS + Linux + Windows Git Bash

set -euo pipefail

# --- Telemetry: JSONL event emission ---
# Appends one structured line to the session event log (~0.1ms).
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    printf '{"t":"%s","type":"%s","src":"ddg","d":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

# --- Read JSON from stdin ---
input=$(cat)

# --- Extract tool_input content ---
# The Agent tool_input contains the prompt text. We need to search
# within the full input for delegation duty elements.
# The prompt is inside "tool_input" which contains "prompt" or "task".

# --- Check duty elements using Perl (portable, no grep -P) ---
result=$(printf '%s' "$input" | \
    perl -ne '
        my $score = 0;
        my @missing;
        my @present;

        # 1. Identity (role name)
        if (/S[1-9]|you\s+are|your\s+identity|your\s+role|Your\s+identity/i) {
            $score++; push @present, "identity";
        } else {
            push @missing, "identity";
        }

        # 2. Rules instruction
        if (/rules|CLAUDE\.md|\.claude\/rules/i) {
            $score++; push @present, "rules";
        } else {
            push @missing, "rules";
        }

        # 3. Skills instruction
        if (/skills|SKILL\.md|shared\/skills/i) {
            $score++; push @present, "skills";
        } else {
            push @missing, "skills";
        }

        # 4. Operational learning
        if (/operational\s+learning|carry\s+forward|OL-/i) {
            $score++; push @present, "OL";
        } else {
            push @missing, "OL";
        }

        # 5. WRITE_BLOCKED signal
        if (/WRITE_BLOCKED/) {
            $score++; push @present, "WRITE_BLOCKED";
        } else {
            push @missing, "WRITE_BLOCKED";
        }

        # 6. Access workaround
        if (/explicit\s+paths|Glob\/Grep|cross-repo|OL-O12/i) {
            $score++; push @present, "access";
        } else {
            push @missing, "access";
        }

        print "$score\n";
        print join(",", @missing) . "\n";
        print join(",", @present) . "\n";
    ' 2>/dev/null || echo "0
identity,rules,skills,OL,WRITE_BLOCKED,access
")

# Parse result
score=$(printf '%s' "$result" | head -1)
missing=$(printf '%s' "$result" | head -2 | tail -1)

if ! [[ "$score" =~ ^[0-9]+$ ]]; then score=0; fi

# --- Inject reminder if elements are missing ---
if [ "$score" -lt 6 ] && [ -n "$missing" ]; then
    reminder="[delegation-guard] Delegation ${score}/6 duty elements."
    reminder="${reminder} Missing: ${missing}."

    # Build specific guidance for each missing element
    guidance=""
    case ",$missing," in
        *,identity,*)
            guidance="${guidance} Identity: include role name (e.g. 'You are S3-Alpha')."
            ;;
    esac
    case ",$missing," in
        *,rules,*)
            guidance="${guidance} Rules: instruct subagent to read CLAUDE.md and .claude/rules/."
            ;;
    esac
    case ",$missing," in
        *,skills,*)
            guidance="${guidance} Skills: mention available skills or shared/skills/ path."
            ;;
    esac
    case ",$missing," in
        *,OL,*)
            guidance="${guidance} OL: include operational learning items relevant to the task."
            ;;
    esac
    case ",$missing," in
        *,WRITE_BLOCKED,*)
            guidance="${guidance} WRITE_BLOCKED: signal if subagent cannot write to protected files."
            ;;
    esac
    case ",$missing," in
        *,access,*)
            guidance="${guidance} Access: note cross-repo paths and Glob/Grep workarounds (OL-O12)."
            ;;
    esac

    if [ -n "$guidance" ]; then
        reminder="${reminder}${guidance}"
    fi

    printf '%s' "$reminder" >&2

    # --- Emit telemetry event (JSONL, replaces Python subprocess KPI logging) ---
    emit_hook_event "delegation" "{\"score\":$score,\"missing\":\"$missing\"}"
fi

# OBSERVE mode: always allow
exit 0
