#!/usr/bin/env bash
# delegation-duty-guard.sh — Claude Code PreToolUse hook (matcher: Agent)
# Checks subagent delegation prompts for 7 duty elements and injects
# a corrective reminder via stderr when elements are missing.
#
# Intent: Detect delegation prompts that omit delegation-duty elements
# (detection layer for the user rule delegation.md and the /delegate
# skill). NOT the duty itself (rule + skill). NOT a prompt rewriter.
# Consumed by: Claude Code PreToolUse(Agent), registered via
# hooks-manifest.json; rollout governed by .claude/rules/hook-rollout.md.
#
# OBSERVE mode: always allows (exit 0), reminds on gaps.
# MODE_DUTY="enforce" blocks (exit 2) when any element is missing;
# promote only per .claude/rules/hook-rollout.md (zero false positives).
#
# Seven delegation duty elements:
#   1. Identity (role name, "you are", etc.)
#   2. Rules instruction (CLAUDE.md, .claude/rules)
#   3. Skills instruction (skills, SKILL.md, shared/skills)
#   4. Operational learning (OL, carry forward)
#   5. WRITE_BLOCKED signal
#   6. Access workaround (explicit paths, Glob/Grep, OL-O12)
#   7. Markdown name prefix (decision D-DEL1, 2026-10-05): the prompt
#      tells the delegate to start every *.md file name with its name.
#      Matches either the decision ID "D-DEL1", or a name-prefix
#      phrase within 160 characters of ".md"/"markdown" (either order).
#      Name-prefix phrase: "name" and "prefix" within 60 characters of
#      each other, or "start(s)/begin(s) with your/the (agent) name".
#      A bare "prefix" (e.g. "date prefix") does not count.
#
# Hook contract:
#   - PreToolUse hook, matcher: Agent
#   - Receives JSON on stdin (tool_name, tool_input)
#   - Exit 0 = allow (OBSERVE mode); exit 2 = block (ENFORCE mode only)
#   - stderr -> feedback text
#   - Must be fast (<50ms)
#   - Must never crash or hang
#   - Standalone — cannot source aitools-lib.sh
#
# KPI definitions (logged to harness DB via session events.jsonl):
#   - delegation.score: duty elements present / 7
#   - delegation.missing: comma-separated list of missing elements
#
# Framework: reference/framework-hook-rollout.md (observe-then-enforce)
# Platform: macOS + Linux + Windows Git Bash

set -euo pipefail

MODE_DUTY="observe"
DUTY_TOTAL=7
ALL_ELEMENTS="identity,rules,skills,OL,WRITE_BLOCKED,access,md-prefix"

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

# --- Only delegation launches are checked ---
# The manifest matcher is Agent; this guard keeps a mis-registered or
# manually piped non-Agent payload from producing a false reminder.
# "Task" is the tool's former name. Depends on perl like the main check;
# without perl every launch is allowed unchecked (observe semantics).
if ! printf '%s' "$input" | perl -0777 -ne 'exit(/"tool_name"\s*:\s*"(?:Agent|Task)"/ ? 0 : 1)'; then
    exit 0
fi

# --- Check duty elements using Perl (portable, no grep -P) ---
# -0777 slurps the whole input so a pretty-printed (multi-line) JSON
# payload is checked as one text; the previous per-line -ne printed one
# score per input line and the caller read only the first.
# perl failure falls back to "all missing" (|| printf ...), which the
# score check below treats as 0/7 -- visible, never a silent pass.
result=$(printf '%s' "$input" | \
    perl -0777 -ne '
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

        # 7. Markdown name prefix (D-DEL1)
        my $md = qr/(?:\.md\b|markdown)/i;
        my $pfx = qr/(?:name.{0,60}?prefix|prefix.{0,60}?name|(?:start|begin)s?\s+with\s+(?:your|the)\s+(?:agent\s+)?name)/is;
        if (/D-DEL1/ || /$pfx.{0,160}?$md/is || /$md.{0,160}?$pfx/is) {
            $score++; push @present, "md-prefix";
        } else {
            push @missing, "md-prefix";
        }

        print "$score\n";
        print join(",", @missing) . "\n";
        print join(",", @present) . "\n";
    ' 2>/dev/null || printf '0\n%s\n\n' "$ALL_ELEMENTS")

# Parse result
score=$(printf '%s\n' "$result" | head -1)
missing=$(printf '%s\n' "$result" | head -2 | tail -1)

if ! [[ "$score" =~ ^[0-9]+$ ]]; then
    score=0
    missing="$ALL_ELEMENTS"
fi

# --- Inject reminder if elements are missing ---
if [ "$score" -lt "$DUTY_TOTAL" ] && [ -n "$missing" ]; then
    reminder="[delegation-guard] Delegation ${score}/${DUTY_TOTAL} duty elements."
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
    case ",$missing," in
        *,md-prefix,*)
            guidance="${guidance} Name prefix (D-DEL1): tell the delegate to start every .md file name with its name, e.g. 'S2-report.md'."
            ;;
    esac

    reminder="${reminder}${guidance} See the /delegate skill."

    printf '%s\n' "$reminder" >&2

    # --- Emit telemetry event (JSONL) ---
    emit_hook_event "delegation" "{\"score\":$score,\"total\":$DUTY_TOTAL,\"missing\":\"$missing\",\"mode\":\"$MODE_DUTY\"}"

    if [ "$MODE_DUTY" = "enforce" ]; then
        exit 2
    fi
fi

# OBSERVE mode (or all elements present): allow
exit 0
