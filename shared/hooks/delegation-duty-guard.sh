#!/usr/bin/env bash
# delegation-duty-guard.sh — Claude Code PreToolUse hook (matcher: Agent|Workflow)
# Reminds the caller to load the /delegate skill on EVERY Agent and
# Workflow call, and checks the delegation prompt (Agent) or workflow
# script (Workflow) for the eight duty elements of /delegate v2.0.
#
# Intent: Detect delegation prompts that omit delegation-duty elements
# and remind the delegating agent of the duty on every launch (detection
# layer for the user rule delegation.md, D-DEL7, and the /delegate
# skill). NOT the duty itself (rule + skill). NOT a prompt rewriter.
# Consumed by: Claude Code PreToolUse(Agent|Workflow), registered via
# hooks-manifest.json; rollout governed by .claude/rules/hook-rollout.md.
#
# OBSERVE mode: always allows (exit 0). Prints one reminder line to
# stderr on every Agent/Task/Workflow call, plus per-element guidance
# when elements are missing.
# MODE_DUTY="enforce" blocks (exit 2) when any element is missing;
# promote only per .claude/rules/hook-rollout.md (zero false positives).
#
# What is checked:
#   - Agent (and Task, its former name): the whole hook payload, which
#     carries tool_input.prompt.
#   - Workflow: the payload when tool_input.script is present; else the
#     file named by tool_input.scriptPath (relative paths resolve
#     against the payload's "cwd"; must be a readable regular file of at
#     most 2 MB); else nothing is checked, but the reminder still prints.
#     LIMIT: a workflow script holds many agent() prompts; the script is
#     checked as ONE text, so an element present in any agent() prompt
#     counts for all of them. The hook does not check each agent() prompt.
#   - Any other tool: silent, exit 0.
#
# Eight delegation duty elements (/delegate v2.0):
#   1. identity      Name and role ("You are S3-Alpha", "Your identity")
#   2. rules         Rules AND CLAUDE.md files: the text must mention
#                    both "CLAUDE.md" and "rule(s)"
#   3. skills        /delegate first: "/delegate", "delegate skill" or
#                    "skills/delegate"
#   4. OL            Operational learning ("operational learning",
#                    "carry forward", "OL-")
#   5. conflict      Conflict priority (D-DEL6): "D-DEL6", "CONFLICT:",
#                    "conflict priority" or "conflict resolution"
#   6. WRITE_BLOCKED The WRITE_BLOCKED signal
#   7. access        Explicit paths: "explicit paths", "absolute path(s)",
#                    "Glob/Grep", "cross-repo", "OL-O12", or an absolute
#                    path (/Users/, /home/, /root/, /tmp/, ~/, or a drive
#                    path C:/ or C:\, JSON-escaped as C:\\)
#   8. md-prefix     Markdown name prefix (D-DEL1, 2026-10-05): "D-DEL1",
#                    or a name-prefix phrase within 160 characters of
#                    ".md"/"markdown" (either order). Name-prefix phrase:
#                    "name" and "prefix" within 60 characters of each
#                    other, or "start(s)/begin(s) with your/the (agent)
#                    name"; or ".md"/"markdown" inside a "name ... prefix"
#                    span of up to 80 + 80 characters ("Name every .md
#                    file with the prefix S2-"). A bare "prefix" (e.g.
#                    "date prefix") does not count.
#
# Hook contract:
#   - PreToolUse hook, matcher: Agent|Workflow
#   - Receives JSON on stdin (tool_name, tool_input, cwd)
#   - Exit 0 = allow (OBSERVE mode); exit 2 = block (ENFORCE mode only)
#   - stderr -> feedback text
#   - Must be fast (<50ms)
#   - Must never crash or hang
#   - Standalone: loads no shared library (deployed hooks cannot)
#   - Without perl the reminder still prints; elements are not checked
#
# KPI definitions (logged to harness DB via session events.jsonl; one
# "delegation" event per Agent/Task/Workflow call):
#   - delegation.score: duty elements present (of "total", now 8)
#   - delegation.missing: comma-separated list of missing elements
#   - tool: Agent, Task or Workflow; checked: 1 when elements were
#     checked, 0 when there was nothing to check (or no perl)
#
# Framework: reference/framework-hook-rollout.md (observe-then-enforce)
# Platform: macOS + Linux + Windows Git Bash (bash 3.2 compatible)

set -euo pipefail

MODE_DUTY="observe"
DUTY_TOTAL=8
ALL_ELEMENTS="identity,rules,skills,OL,conflict,WRITE_BLOCKED,access,md-prefix"
SCRIPT_MAX_BYTES=2097152

REMINDER="[delegation-guard] Load /delegate before every Agent and Workflow call; the prompt must tell the delegate to read every user- and project-scope rule and CLAUDE.md, load /delegate, and pass both on."

# --- Telemetry: JSONL event emission ---
# Appends one structured line to the session event log (~0.1ms).
# git may be absent or the cwd may not be a repo: both yield no session
# dir, and telemetry is skipped (the hook itself still runs).
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    # Telemetry is best effort: an unwritable log must not fail the hook.
    printf '{"t":"%s","type":"%s","src":"ddg","d":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

# --- Read JSON from stdin ---
input=$(cat)

# --- Only delegation launches are checked ---
# The manifest matcher is Agent|Workflow; this guard keeps a
# mis-registered or manually piped payload of another tool silent.
# "Task" is the Agent tool's former name. Pure bash (no perl needed).
_tool_re='"tool_name"[[:space:]]*:[[:space:]]*"(Agent|Task|Workflow)"'
if [[ "$input" =~ $_tool_re ]]; then
    tool="${BASH_REMATCH[1]}"
else
    exit 0
fi

# The reminder prints on every delegation call, whatever the score.
printf '%s\n' "$REMINDER" >&2

if ! command -v perl >/dev/null 2>&1; then
    printf '%s\n' "[delegation-guard] perl not found: duty elements not checked." >&2
    emit_hook_event "delegation" "{\"score\":0,\"total\":$DUTY_TOTAL,\"missing\":\"\",\"mode\":\"$MODE_DUTY\",\"tool\":\"$tool\",\"checked\":0}"
    exit 0
fi

# --- Check duty elements using Perl (portable, no grep -P) ---
# -0777 slurps the whole input so a pretty-printed (multi-line) JSON
# payload is checked as one text.
# Output lines: status (checked | none:<reason>), score, missing, present.
# perl failure falls back to "all missing" (|| printf ...), which the
# score check below treats as 0/8 -- visible, never a silent pass.
result=$(printf '%s' "$input" | \
    DDG_TOOL="$tool" DDG_MAX="$SCRIPT_MAX_BYTES" perl -0777 -ne '
        my $text = $_;
        my $status = "checked";

        if ($ENV{DDG_TOOL} eq "Workflow" && !/"script"\s*:\s*"/) {
            # No inline script: read tool_input.scriptPath, if any.
            if (/"scriptPath"\s*:\s*"((?:[^"\\]|\\.)*)"/) {
                my $p = $1;
                $p =~ s/\\(["\\\/])/$1/g;
                if ($p !~ m{^(?:/|~|[A-Za-z]:[\\/])} && /"cwd"\s*:\s*"((?:[^"\\]|\\.)*)"/) {
                    my $cwd = $1;
                    $cwd =~ s/\\(["\\\/])/$1/g;
                    $p = "$cwd/$p";
                }
                $p =~ s{^~(?=/)}{$ENV{HOME} // ""}e;
                if (-f $p && -r _ && -s _ <= $ENV{DDG_MAX}) {
                    if (open(my $fh, "<", $p)) {
                        local $/;
                        $text = <$fh> // "";
                        close($fh);
                    } else {
                        $status = "none:scriptPath unreadable";
                    }
                } else {
                    $status = "none:scriptPath missing, unreadable or over 2 MB";
                }
            } else {
                $status = "none:no script or scriptPath in the input";
            }
        }

        if ($status ne "checked") {
            print "$status\n0\n\n\n";
            exit 0;
        }

        $_ = $text;
        my $score = 0;
        my (@missing, @present);
        my $check = sub {
            my ($name, $ok) = @_;
            if ($ok) { $score++; push @present, $name; } else { push @missing, $name; }
        };

        # 1. Identity (role name)
        $check->("identity", /S[1-9]|you\s+are|your\s+identity|your\s+role/i);

        # 2. Rules AND CLAUDE.md files (both must be mentioned)
        $check->("rules", /CLAUDE\.md/i && /\brules?\b/i);

        # 3. Skills, /delegate first
        $check->("skills", /\/delegate\b|delegate\s+skill|skills[\/\\]+delegate\b/i);

        # 4. Operational learning
        $check->("OL", /operational\s+learning|carry[\s-]+forward|OL-/i);

        # 5. Conflict priority (D-DEL6)
        $check->("conflict", /D-DEL6|CONFLICT:|conflict\s+(?:priority|resolution)/i);

        # 6. WRITE_BLOCKED signal
        $check->("WRITE_BLOCKED", /WRITE_BLOCKED/);

        # 7. Access: explicit / absolute paths
        $check->("access", /explicit\s+(?:absolute\s+)?paths|absolute\s+paths?|Glob\/Grep|cross-repo|OL-O12|(?<![\w.])(?:\/Users\/|\/home\/|\/root\/|\/tmp\/|~\/)[\w.-]|\b[A-Za-z]:(?:\\\\|\/)[\w.-]/i);

        # 8. Markdown name prefix (D-DEL1)
        my $md = qr/(?:\.md\b|markdown)/i;
        my $pfx = qr/(?:name.{0,60}?prefix|prefix.{0,60}?name|(?:start|begin)s?\s+with\s+(?:your|the)\s+(?:agent\s+)?name)/is;
        # The phrase may also wrap the extension: "Name every .md file with the prefix S2-".
        $check->("md-prefix", /D-DEL1/ || /$pfx.{0,160}?$md/is || /$md.{0,160}?$pfx/is
            || /name.{0,80}?$md.{0,80}?prefix/is || /prefix.{0,80}?$md.{0,80}?name/is);

        print "checked\n$score\n";
        print join(",", @missing) . "\n";
        print join(",", @present) . "\n";
    ' 2>/dev/null || printf 'checked\n0\n%s\n\n' "$ALL_ELEMENTS")

# Parse result (bash 3.2 compatible: no mapfile)
status=$(printf '%s\n' "$result" | sed -n '1p')
score=$(printf '%s\n' "$result" | sed -n '2p')
missing=$(printf '%s\n' "$result" | sed -n '3p')

case "$status" in
    none:*)
        printf '%s\n' "[delegation-guard] ${tool}: ${status#none:}; duty elements not checked." >&2
        emit_hook_event "delegation" "{\"score\":0,\"total\":$DUTY_TOTAL,\"missing\":\"\",\"mode\":\"$MODE_DUTY\",\"tool\":\"$tool\",\"checked\":0}"
        exit 0
        ;;
esac

if ! [[ "$score" =~ ^[0-9]+$ ]]; then
    score=0
    missing="$ALL_ELEMENTS"
fi

# --- Telemetry: one event per delegation call ---
emit_hook_event "delegation" "{\"score\":$score,\"total\":$DUTY_TOTAL,\"missing\":\"$missing\",\"mode\":\"$MODE_DUTY\",\"tool\":\"$tool\",\"checked\":1}"

# --- Per-element guidance if elements are missing ---
if [ "$score" -lt "$DUTY_TOTAL" ] && [ -n "$missing" ]; then
    reminder="[delegation-guard] ${tool}: ${score}/${DUTY_TOTAL} duty elements. Missing: ${missing}."

    guidance=""
    case ",$missing," in
        *,identity,*)
            guidance="${guidance} Identity: give the delegate a name and role (e.g. 'You are S3-Alpha')." ;;
    esac
    case ",$missing," in
        *,rules,*)
            guidance="${guidance} Rules and CLAUDE.md: tell the delegate to read in full every user- and project-scope CLAUDE.md and rule (~/.claude/CLAUDE.md, ~/.claude/rules/*.md, <repo>/CLAUDE.md, <repo>/.claude/rules/*.md), by absolute path." ;;
    esac
    case ",$missing," in
        *,skills,*)
            guidance="${guidance} Skills: tell the delegate to load /delegate first, before any delegate of its own, and to pass that on; then name the task skills." ;;
    esac
    case ",$missing," in
        *,OL,*)
            guidance="${guidance} OL: include the operational learning relevant to the task, with sources." ;;
    esac
    case ",$missing," in
        *,conflict,*)
            guidance="${guidance} Conflict priority (D-DEL6): commander's words newest first, then the prompt, then skills; report CONFLICT: lines." ;;
    esac
    case ",$missing," in
        *,WRITE_BLOCKED,*)
            guidance="${guidance} WRITE_BLOCKED: on a denied write or tool call, output 'WRITE_BLOCKED: <what> -- <denial text>' and do not route around it." ;;
    esac
    case ",$missing," in
        *,access,*)
            guidance="${guidance} Access: give absolute paths to every file and directory, including the delegate's scratch dir." ;;
    esac
    case ",$missing," in
        *,md-prefix,*)
            guidance="${guidance} Name prefix (D-DEL1): tell the delegate to start every .md file name with its name, e.g. 'S2-report.md'." ;;
    esac
    if [ "$tool" = "Workflow" ]; then
        guidance="${guidance} (Workflow: the script is checked as one text; every agent() prompt needs all eight.)"
    fi

    printf '%s\n' "${reminder}${guidance} See the /delegate skill." >&2

    if [ "$MODE_DUTY" = "enforce" ]; then
        exit 2
    fi
fi

# OBSERVE mode (or all elements present): allow
exit 0
