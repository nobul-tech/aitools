#!/usr/bin/env bash
# test-delegation-duty-guard.sh -- tests for shared/hooks/delegation-duty-guard.sh
# (PreToolUse, matcher Agent|Workflow; the eight /delegate v2.0 elements).
#
# Covers: the reminder line on every Agent/Task/Workflow call (alone at 8/8),
# on stderr and as stdout hookSpecificOutput.additionalContext JSON;
# real-shape payloads whose cwd/transcript_path absolute paths must not count
# as access; each of the eight elements missing (named in the output, and only
# it); Workflow with an inline script, with scriptPath (absolute, relative to
# the payload cwd, missing, over the 512 KB cap) and with neither; another tool
# (silent); malformed, truncated, empty and pretty-printed JSON (exit 0, no
# crash); perl absent from PATH (reminder, elements not checked); the
# delegation telemetry event (total 8, tool, checked); enforce mode (exit 2 on
# a gap, 0 at 8/8); timing of a large prompt (best of 5 < 100 ms; advisory on
# Windows Git Bash, where process start-up alone can exceed it). The bound was
# 50 ms until 2026-10-28: CI runners measured 40-54 ms for the same hook, so it
# failed on runner variance; 100 ms still catches a 2x regression.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/test-delegation-duty-guard.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-delegation-duty-guard.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO/shared/hooks/delegation-duty-guard.sh"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
BASH_ABS="$(command -v "$BASH_BIN")"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

REMINDER="[delegation-guard] Load /delegate before every Agent and Workflow call; the prompt must tell the delegate to read every user- and project-scope rule and CLAUDE.md, load /delegate, and pass both on."

# One sentence per element; removing one sentence removes only that element.
E_identity="You are Alpha-Test, a delegate."
E_rules="Read every CLAUDE.md and rule file in full."
E_skills="Load /delegate first."
E_OL="Operational learning: hooks must be smoke-tested."
E_conflict="Conflict priority (D-DEL6): commander first."
E_WRITE_BLOCKED="On a denial output WRITE_BLOCKED."
E_access="Access: /Users/test/repo/file.txt"
E_mdprefix="D-DEL1: prefix every markdown file with your name."
ELEMENTS="identity rules skills OL conflict WRITE_BLOCKED access mdprefix"

prompt_without() {  # prompt_without <element|none>
    local out="" e v
    for e in $ELEMENTS; do
        [ "$e" = "$1" ] && continue
        eval "v=\$E_$e"
        out="$out $v"
    done
    printf '%s' "$out"
}

OUT=""; ERR=""; RC=0
run_hook() {  # run_hook <payload-file> [hook]  -> RC, ERR (stderr), OUT (stdout)
    local h="${2:-$HOOK}"
    RC=0
    "$BASH_BIN" "$h" < "$1" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
    OUT="$(cat "$WORK/out.txt")"
    ERR="$(cat "$WORK/err.txt")"
}

# Real-shape payload: Claude Code always sends absolute paths in session
# fields, which must not count as the access element (review B2, PR #122).
COMMON='"session_id":"abc","transcript_path":"/Users/x/.claude/projects/p/abc.jsonl","cwd":"/Users/x/repos/r","permission_mode":"default","hook_event_name":"PreToolUse"'
agent_payload() {  # agent_payload <tool> <prompt> > file
    printf '{%s,"tool_name":"%s","tool_input":{"description":"t","prompt":"%s","subagent_type":"general-purpose"},"tool_use_id":"toolu_01S3abcS9"}' "$COMMON" "$1" "$2"
}

# ctx_matches: stdout is one hookSpecificOutput JSON whose additionalContext
# equals the stderr text (the channel Claude reads on exit 0, review B1).
HAVE_JSONPP=false
if perl -MJSON::PP -e 1 >/dev/null 2>&1; then HAVE_JSONPP=true; fi
ctx_matches() {
    $HAVE_JSONPP || return 0
    printf '%s' "$OUT" | perl -MJSON::PP -0777 -e '
        my $j = eval { decode_json(<STDIN>) } or exit 1;
        my $h = $j->{hookSpecificOutput} or exit 1;
        exit 1 unless ($h->{hookEventName} // "") eq "PreToolUse";
        print $h->{additionalContext} // "";' > "$WORK/ctx.txt" || return 1
    [ "$(cat "$WORK/ctx.txt")" = "$ERR" ]
}

echo "== Agent and Task: all eight elements =="
for tool in Agent Task; do
    agent_payload "$tool" "$(prompt_without none)" > "$WORK/p.json"
    run_hook "$WORK/p.json"
    if [ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER" ]; then
        ok "$tool 8/8: exit 0, reminder line only"
    else
        bad "$tool 8/8: rc=$RC stderr=[$ERR]"
    fi
    ctx_matches && ok "$tool 8/8: stdout additionalContext JSON = reminder" || bad "$tool 8/8: stdout=[$OUT]"
done
agent_payload Agent "$(prompt_without access)" > "$WORK/p.json"
run_hook "$WORK/p.json"
ctx_matches && ok "gap: additionalContext carries reminder + guidance" || bad "gap ctx: stdout=[$OUT]"
case "$ERR" in *"Missing: access."*) ok "absolute paths in cwd/transcript_path do not count as access" ;; *) bad "payload paths counted: [$ERR]" ;; esac
agent_payload Agent "Do the thing." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Agent: 0/8 duty elements."*) ok "bare prompt in a real-shape payload: 0/8" ;; *) bad "bare prompt: [$ERR]" ;; esac
printf '{"tool_name":"Agent","tool_input":{"description":"You are S3-X","subagent_type":"Explore"}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in "$REMINDER"*"no prompt in the input; duty elements not checked."*) ok "Agent without prompt: reminder, not checked" ;; *) bad "no prompt: [$ERR]" ;; esac

echo "== Agent: each element missing =="
for e in $ELEMENTS; do
    name="$e"; [ "$e" = "mdprefix" ] && name="md-prefix"
    agent_payload Agent "$(prompt_without "$e")" > "$WORK/p.json"
    run_hook "$WORK/p.json"
    first="$(printf '%s\n' "$ERR" | sed -n '1p')"
    second="$(printf '%s\n' "$ERR" | sed -n '2p')"
    case "$second" in
        "[delegation-guard] Agent: 7/8 duty elements. Missing: ${name}. "*"See the /delegate skill.")
            if [ "$RC" -eq 0 ] && [ "$first" = "$REMINDER" ]; then ok "missing $name: named, exit 0"; else bad "missing $name: rc=$RC first=[$first]"; fi ;;
        *) bad "missing $name: stderr line 2=[$second]" ;;
    esac
done

echo "== Lenient and strict matching =="
agent_payload Agent "$(prompt_without rules) Read the CLAUDE.md files." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: rules."*) ok "CLAUDE.md without rules: rules missing" ;; *) bad "CLAUDE.md without rules: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without rules) Read every .claude/rules file." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: rules."*) ok "rules without CLAUDE.md: rules missing" ;; *) bad "rules without CLAUDE.md: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without skills) Load the delegate skill, then scratch." > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "'delegate skill' counts as /delegate" || bad "'delegate skill': [$ERR]"
agent_payload Agent "$(prompt_without skills) Load the skills you need." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: skills."*) ok "skills without /delegate: skills missing" ;; *) bad "skills without /delegate: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without access) Repo: C:\\\\Users\\\\jose\\\\repos\\\\x" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "JSON-escaped Windows path counts as access" || bad "Windows path: [$ERR]"
agent_payload Agent "$(prompt_without mdprefix) Name every .md file you write with the prefix S2-Audit-." > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "'Name every .md file ... prefix' counts as md-prefix" || bad "md wrapped in name/prefix: [$ERR]"
agent_payload Agent "$(prompt_without mdprefix) Use a date prefix for log.md files." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: md-prefix."*) ok "bare 'date prefix' does not count" ;; *) bad "date prefix: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without identity) Fix the s3 bucket config." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: identity."*) ok "lower-case 's3' does not count as identity" ;; *) bad "s3 identity: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without conflict) Do the merge conflict resolution in git." > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Missing: conflict."*) ok "'merge conflict resolution' does not count as conflict priority" ;; *) bad "conflict resolution: [$ERR]" ;; esac
agent_payload Agent "$(prompt_without access)"'\n/Users/test/repo/file.txt' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "path right after a JSON \\n counts as access (JSON unescaped)" || bad "path after \\n: [$ERR]"
agent_payload Agent "$(prompt_without rules | perl -pe 's/Read every CLAUDE.md and rule file in full.//') Read CLAUDE.md and the"'\n'"rules in full." > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "'rules' right after a JSON \\n counts" || bad "rules after \\n: [$ERR]"
agent_payload Agent "$(prompt_without conflict) Report each CONFLICT: line." > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "'CONFLICT:' counts as conflict priority" || bad "CONFLICT: [$ERR]"

echo "== Workflow =="
WF_FULL="export const meta = {}; agent({prompt: '$(prompt_without none)'})"
printf '{"tool_name":"Workflow","tool_input":{"script":"%s"}}' "$WF_FULL" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER" ] && ok "inline script 8/8: reminder only" || bad "inline script 8/8: rc=$RC [$ERR]"
printf '{"tool_name":"Workflow","tool_input":{"script":"agent({prompt: %s})"}}' "'$(prompt_without WRITE_BLOCKED)'" > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Workflow: 7/8 duty elements. Missing: WRITE_BLOCKED."*"checked as one text"*) ok "inline script missing WRITE_BLOCKED: named, Workflow limit noted" ;; *) bad "inline missing: [$ERR]" ;; esac

printf '%s\n' "$WF_FULL" > "$WORK/wf-full.js"
printf 'agent({prompt: "%s"})\n' "$(prompt_without access)" > "$WORK/wf-gap.js"
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s"}}' "$WORK/wf-full.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER" ] && ok "scriptPath (absolute) 8/8: reminder only" || bad "scriptPath 8/8: rc=$RC [$ERR]"
printf '{"cwd":"%s","tool_name":"Workflow","tool_input":{"scriptPath":"wf-gap.js"}}' "$WORK" > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"Workflow: 7/8 duty elements. Missing: access."*) ok "scriptPath relative to cwd: file read, access missing" ;; *) bad "relative scriptPath: [$ERR]" ;; esac
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s/nope.js"}}' "$WORK" > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in "$REMINDER"*"not checked."*) [ "$RC" -eq 0 ] && ok "missing scriptPath file: reminder, not checked, exit 0" || bad "missing file rc=$RC" ;; *) bad "missing file: [$ERR]" ;; esac
perl -e 'print "x" x 524289' > "$WORK/wf-big.js"
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s"}}' "$WORK/wf-big.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in *"over 512 KB; duty elements not checked."*) ok "scriptPath over 512 KB: not read" ;; *) bad "big file: [$ERR]" ;; esac
printf '{"tool_name":"Workflow","tool_input":{}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in "$REMINDER"*"no script or scriptPath"*) [ "$RC" -eq 0 ] && ok "no script and no scriptPath: reminder, not checked" || bad "no script rc=$RC" ;; *) bad "no script: [$ERR]" ;; esac

echo "== Other tools and malformed input =="
printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ -z "$OUT" ] && ok "Bash tool: silent, exit 0" || bad "Bash tool: rc=$RC [$ERR]"
printf '{"tool_name":"AgentX","tool_input":{}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && ok "tool AgentX: silent" || bad "AgentX: rc=$RC [$ERR]"
printf '{not json' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && ok "malformed JSON: silent, exit 0" || bad "malformed: rc=$RC [$ERR]"
printf '{"tool_name":"Agent","tool_input":{"prompt":"You are S3-X' > "$WORK/p.json"
run_hook "$WORK/p.json"
case "$ERR" in "$REMINDER"*"Missing: rules,skills,"*) [ "$RC" -eq 0 ] && ok "truncated Agent JSON: reminder + gaps, exit 0" || bad "truncated rc=$RC" ;; *) bad "truncated: [$ERR]" ;; esac
: > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && ok "empty stdin: silent, exit 0" || bad "empty: rc=$RC [$ERR]"
printf '{\n  "tool_name": "Agent",\n  "tool_input": {\n    "prompt": "%s"\n  }\n}\n' "$(prompt_without none)" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$ERR" = "$REMINDER" ] && ok "pretty-printed JSON 8/8: reminder only" || bad "pretty: [$ERR]"

echo "== perl absent =="
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        # Git Bash keeps perl in /usr/bin beside cat and sed, and a copied
        # cat.exe cannot start without the msys DLLs: not testable here.
        printf '  skip perl absent (Windows Git Bash: perl shares /usr/bin with the tools the hook needs)\n' ;;
    *)
        mkdir -p "$WORK/bin"
        for t in cat sed date; do ln -sf "$(command -v "$t")" "$WORK/bin/$t"; done
        agent_payload Agent "$(prompt_without none)" > "$WORK/p.json"
        RC=0
        PATH="$WORK/bin" "$BASH_ABS" "$HOOK" < "$WORK/p.json" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
        ERR="$(cat "$WORK/err.txt")"
        case "$ERR" in "$REMINDER"*"perl not found: duty elements not checked."*) [ "$RC" -eq 0 ] && ok "no perl: reminder + not checked, exit 0" || bad "no perl rc=$RC" ;; *) bad "no perl: rc=$RC [$ERR]" ;; esac ;;
esac

echo "== Telemetry =="
mkdir -p "$WORK/repo/.scratch/session-t"
git -C "$WORK/repo" init -q
printf '%s\n' "$WORK/repo/.scratch/session-t" > "$WORK/repo/.scratch/.current-session"
agent_payload Agent "$(prompt_without conflict)" > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
printf '{"tool_name":"Workflow","tool_input":{"script":"%s"}}' "$WF_FULL" > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
EV="$WORK/repo/.scratch/session-t/events.jsonl"
n="$(sed -n '$=' "$EV" 2>/dev/null || echo 0)"
[ "$n" = "2" ] && ok "one event per Agent/Workflow call, none for Bash" || bad "event count=$n"
grep -q '"type":"delegation","src":"ddg","d":{"score":7,"total":8,"missing":"conflict","mode":"observe","tool":"Agent","checked":1}' "$EV" \
    && ok "Agent event: score 7, total 8, tool Agent" || bad "Agent event: $(sed -n '1p' "$EV")"
grep -q '"d":{"score":8,"total":8,"missing":"","mode":"observe","tool":"Workflow","checked":1}' "$EV" \
    && ok "Workflow event at 8/8 is emitted" || bad "Workflow event: $(sed -n '2p' "$EV")"
if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$EV" && ok "events are valid JSON" || bad "events not valid JSON"
fi

echo "== Enforce mode =="
perl -pe 's/^MODE_DUTY="observe"$/MODE_DUTY="enforce"/' "$HOOK" > "$WORK/enforce.sh"
agent_payload Agent "$(prompt_without OL)" > "$WORK/p.json"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 2 ] && ok "enforce + gap: exit 2" || bad "enforce gap rc=$RC"
agent_payload Agent "$(prompt_without none)" > "$WORK/p.json"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 0 ] && ok "enforce + 8/8: exit 0" || bad "enforce full rc=$RC"

echo "== Timing (large prompt) =="
# Bound with headroom for shared CI runners (measured 40-54 ms on 2026-10-27/28).
TIMING_MAX_MS=100
big="$(prompt_without none) $(perl -e 'print "lorem ipsum dolor sit amet " x 8000')"
agent_payload Agent "$big" > "$WORK/big.json"
ms="$(perl -MTime::HiRes=time -e '
    my ($bash, $hook, $in) = @ARGV; my $best = 1e9;
    for (1..5) { my $t = time; system("\"$bash\" \"$hook\" < \"$in\" >/dev/null 2>&1"); my $d = (time - $t) * 1000; $best = $d if $d < $best; }
    printf "%d", $best;' "$BASH_ABS" "$HOOK" "$WORK/big.json")"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        if [ "$ms" -lt "$TIMING_MAX_MS" ]; then ok "large prompt ($(wc -c < "$WORK/big.json") bytes): ${ms} ms"; else printf '  WARN large prompt: %s ms (>= %s; advisory on Windows Git Bash)\n' "$ms" "$TIMING_MAX_MS"; fi ;;
    *)
        if [ "$ms" -lt "$TIMING_MAX_MS" ]; then ok "large prompt ($(wc -c < "$WORK/big.json" | tr -d ' ') bytes): best of 5 = ${ms} ms (< ${TIMING_MAX_MS})"; else bad "large prompt: ${ms} ms (>= ${TIMING_MAX_MS})"; fi ;;
esac

perl -e 'print q({"tool_name":"Agent","tool_input":{"prompt":"), "name prefix " x 25000, q("}})' > "$WORK/adv.json"
ms="$(perl -MTime::HiRes=time -e '
    my ($bash, $hook, $in) = @ARGV; my $t = time;
    system("\"$bash\" \"$hook\" < \"$in\" >/dev/null 2>&1"); printf "%d", (time - $t) * 1000;' "$BASH_ABS" "$HOOK" "$WORK/adv.json")"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) printf '  info adversarial 300 KB "name prefix" text: %s ms (advisory on Windows)\n' "$ms" ;;
    *) if [ "$ms" -lt 300 ]; then ok "adversarial 300 KB 'name prefix' text: ${ms} ms (< 300; was ~760 ms before the md-window bound)"; else bad "adversarial text: ${ms} ms (>= 300)"; fi ;;
esac

echo
printf 'delegation-duty-guard: %d passed, %d failed (bash: %s)\n' "$PASS" "$FAIL" "$("$BASH_BIN" -c 'echo $BASH_VERSION')"
[ "$FAIL" -eq 0 ]
