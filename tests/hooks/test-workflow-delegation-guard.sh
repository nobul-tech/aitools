#!/usr/bin/env bash
# test-workflow-delegation-guard.sh -- tests for shared/hooks/workflow-delegation-guard.sh
# (PreToolUse, matcher Workflow; one eight-element score per agent() prompt).
#
# Covers (spec S3-Hook2-spec.md v1.0 section 10): smoke (Bash and Agent
# payloads silent); violation (per-agent output, elements split across two
# prompts are not pooled); string literal; template with a const;
# concatenation; const reference and chain; a shared COMMON const; nested
# template in ${}; agent( inside comments and strings (not counted); .agent(,
# ?.agent( and function agent( (not counted); a regex literal containing a
# backtick; division is not a regex; map lambda with ${l.k}; a runtime ${...}
# adds no element; unresolved arguments (call, member access, cycle);
# scriptPath (absolute, relative to cwd, missing, over 512 KB, none); malformed
# scripts (fallback to one whole-script score); no agent( (fallback); stdout
# parses as JSON and equals stderr; the 4,000-character context cap;
# telemetry (one event per prompt, fallback and none events); enforce mode;
# perl absent; the element-block parity check against delegation-duty-guard.sh;
# the real fixtures of session 10cf255a-c with their per-agent counts; timing
# (500 KB, best of 5, < 100 ms on macOS; advisory on Linux and Windows Git Bash).
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Also (fix batch, review of PR #135): a Strawberry-style PERLIO=:unix:crlf
# layer (enforce still exits 2, Bash stays silent, last guidance kept); a
# nested "script" decoy in tool_input; no agent( call = nothing to check
# (spec v1.1); resolution and scoring budgets; a CRLF backslash line
# continuation; the "why" telemetry field. Without python3 the JSON checks
# are SKIPs (counted), and timing WARNs are counted.
# Usage: bash tests/hooks/test-workflow-delegation-guard.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-workflow-delegation-guard.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO/shared/hooks/workflow-delegation-guard.sh"
DDG="$REPO/shared/hooks/delegation-duty-guard.sh"
FX="$REPO/tests/hooks/fixtures/workflow"
WORK="$(mktemp -d)"
cleanup() { cd /; rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
BASH_ABS="$(command -v "$BASH_BIN")"
# Run every hook call from a directory outside any git repo, so no real
# session's events.jsonl ever receives test telemetry.
cd "$WORK"

PASS=0
FAIL=0
SKIP=0
WARN=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP %s\n' "$1"; }
warn() { WARN=$((WARN + 1)); printf '  WARN %s\n' "$1"; }

REMINDER="[workflow-guard] Load /delegate before every Workflow call; every agent() prompt is a delegation prompt and needs all eight elements."

# One sentence per element (no quotes, backticks or ${ inside).
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
    printf '%s' "${out# }"
}
FULL="$(prompt_without none)"

# wf_payload <script file> > payload: a real-shape Workflow payload whose
# tool_input.script is the file's text, JSON-escaped.
COMMON='"session_id":"abc","transcript_path":"/Users/x/.claude/projects/p/abc.jsonl","cwd":"/Users/x/repos/r","permission_mode":"default","hook_event_name":"PreToolUse"'
wf_payload() {
    perl -0777 -e '
        my $s = <STDIN>; $s = "" unless defined $s;
        $s =~ s/([\\"])/\\$1/g; $s =~ s/\n/\\n/g; $s =~ s/\t/\\t/g; $s =~ s/\r/\\r/g;
        $s =~ s/([\x00-\x1f])/sprintf("\\u%04x", ord $1)/ge;
        print "{$ARGV[0],\"tool_name\":\"Workflow\",\"tool_input\":{\"script\":\"$s\"},\"tool_use_id\":\"toolu_01\"}";
    ' "$COMMON" < "$1"
}

OUT=""; ERR=""; RC=0
run_hook() {  # run_hook <payload-file> [hook]  -> RC, ERR (stderr), OUT (stdout)
    local h="${2:-$HOOK}"
    RC=0
    "$BASH_BIN" "$h" < "$1" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
    OUT="$(cat "$WORK/out.txt")"
    ERR="$(cat "$WORK/err.txt")"
}
# run_js <script text>: write it, wrap it, run the hook.
run_js() {
    printf '%s\n' "$1" > "$WORK/s.js"
    wf_payload "$WORK/s.js" > "$WORK/p.json"
    run_hook "$WORK/p.json"
}
has() { case "$ERR" in *"$1"*) return 0 ;; esac; return 1; }
summary() { printf '[workflow-guard] Workflow: %s agent() prompts, %s with all eight, %s unresolved.' "$1" "$2" "$3"; }

# ctx_check <name>: stdout is one hookSpecificOutput JSON (python3 json.load)
# whose additionalContext equals the stderr text and is at most 4,000
# characters. Without python3 the check is a counted SKIP, never a pass.
HAVE_PY=false
if command -v python3 >/dev/null 2>&1; then HAVE_PY=true; fi
ctx_check() {
    if ! $HAVE_PY; then skip "$1 (python3 not found)"; return 0; fi
    if ctx_matches; then ok "$1"; else bad "$1: stdout=[$OUT]"; fi
}
ctx_matches() {
    printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' || return 1
    printf '%s' "$OUT" | python3 -c '
import json, sys
h = json.load(sys.stdin)["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse"
c = h["additionalContext"]
assert len(c) <= 4000, len(c)
sys.stdout.buffer.write(c.encode("utf-8"))' > "$WORK/ctx.txt" || return 1
    [ "$(cat "$WORK/ctx.txt")" = "$ERR" ]
}

echo "== Smoke: other tools are silent =="
printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ -z "$OUT" ] && ok "Bash payload: silent, exit 0" || bad "Bash: rc=$RC [$ERR] [$OUT]"
printf '{%s,"tool_name":"Agent","tool_input":{"description":"t","prompt":"%s"}}' "$COMMON" "$FULL" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ -z "$OUT" ] && ok "Agent payload: silent, exit 0" || bad "Agent: rc=$RC [$ERR]"
run_hook "$FX/agent-012.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ -z "$OUT" ] && ok "real Agent payload (agent-012.json): silent" || bad "agent-012: rc=$RC [$ERR]"
: > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && ok "empty stdin: silent, exit 0" || bad "empty: rc=$RC [$ERR]"
printf '{not json' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && ok "malformed JSON: silent, exit 0" || bad "malformed: rc=$RC [$ERR]"

echo "== Per-agent scoring =="
run_js "agent('$FULL', { label: 'full' })"
if [ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER"$'\n'"$(summary 1 1 0)" ]; then ok "string literal 8/8: reminder + summary only"; else bad "string 8/8: rc=$RC [$ERR]"; fi
ctx_check "stdout is JSON; additionalContext = stderr"
run_js "const a = await agent('$FULL', { label: 'full' })
const b = await agent('$(prompt_without WRITE_BLOCKED)', { label: 'gap-wb', phase: 'X' })"
has "$(summary 2 1 0)" && has "  gap-wb 7/8 missing WRITE_BLOCKED" && has "WRITE_BLOCKED: on a denied write" \
    && ok "violation: per-agent line names the prompt and the element; guidance" || bad "violation: [$ERR]"
ctx_check "violation: stdout JSON = stderr"
run_js "agent('$E_identity $E_rules $E_skills $E_OL', { label: 'half-a' })
agent('$E_conflict $E_WRITE_BLOCKED $E_access $E_mdprefix', { label: 'half-b' })"
has "$(summary 2 0 0)" && has "  half-a 4/8 missing conflict,WRITE_BLOCKED,access,md-prefix" && has "  half-b 4/8 missing identity,rules,skills,OL" \
    && ok "elements split across two prompts are not pooled (4/8 each)" || bad "split: [$ERR]"
run_js "const ID = 'You are S3-X.'
agent(\`\${ID} $(prompt_without identity)\`, { label: 'tpl' })"
has "$(summary 1 1 0)" && ok "template literal with \${CONST}: resolved, 8/8" || bad "template const: [$ERR]"
run_js "agent('$E_identity $E_rules' + \" $E_skills $E_OL\" + \` $E_conflict $E_WRITE_BLOCKED\` + ('$E_access' + ' $E_mdprefix'))"
has "$(summary 1 1 0)" && ok "concatenation of string, template and parenthesised parts: 8/8" || bad "concat: [$ERR]"
run_js "const A = '$E_identity $E_rules $E_skills'
let B = A + ' $E_OL $E_conflict'
var P = (B + ' $E_WRITE_BLOCKED') + ' $E_access $E_mdprefix'
agent(P, { label: 'ref' })"
has "$(summary 1 1 0)" && ok "const reference through a chain of three constants: 8/8" || bad "const ref: [$ERR]"
run_js "const R = '/Users/test/repo'
const COMMON = \`
$E_rules $E_skills $E_OL $E_conflict $E_WRITE_BLOCKED Repo: \${R}. $E_mdprefix\`
const x = await agent(\`You are S3-One. \${COMMON}\`, { label: 'one' })
const y = await agent(\`You are S3-Two. \${COMMON}\`, { label: 'two' })
const z = await agent(\`Task only. \${COMMON}\`, { label: 'three' })"
has "$(summary 3 2 0)" && has "  three 7/8 missing identity" && ok "shared COMMON const (with \${R} inside): one score per agent" || bad "COMMON: [$ERR]"
run_js "const T = \`x\`
agent(\`\${flag ? \`nested \${T} agent('not counted')\` : \`b\`} $FULL\`, { label: 'nest' })"
has "$(summary 1 1 0)" && ok "nested template in \${}: lexed, one prompt, 8/8" || bad "nested: [$ERR]"

echo "== What counts as a call site =="
run_js "// agent('in a line comment')
/* agent('in a block comment') */
const s = 'agent(\"in a string\")'
const d = \"agent('in a double-quoted string')\"
const t = \`agent('in a template')\`
agent('$FULL', { label: 'real' })"
has "$(summary 1 1 0)" && ok "agent( inside comments, strings and templates: not counted" || bad "comments/strings: [$ERR]"
run_js "obj.agent('x')
obj?.agent('y')
function agent(p) { return p }
async function agent2() {}
agent('$FULL', { label: 'real' })"
has "$(summary 1 1 0)" && ok ".agent(, ?.agent( and function agent(: not counted" || bad "member/function: [$ERR]"
run_js "const re = /\`+/g
const q = (a) / 2 / (b)
const r2 = [/x\\/\`y/, 1]
agent('$FULL', { label: 'after-regex' })"
has "$(summary 1 1 0)" && ok "regex literal containing a backtick; division is not a regex" || bad "regex: [$ERR]"
run_js "const lenses = [{ k: 'A' }, { k: 'B' }]
const out = await parallel(lenses.map(l => () => agent(\`You are S3-Lens\${l.k}. $(prompt_without identity)\`, { label: \`lens:\${l.k}\` })))"
has "$(summary 1 1 0)" && ok "map lambda with \${l.k}: one static call site, 8/8" || bad "map lambda: [$ERR]"
run_js "const BRIEF = brief ? brief.details : 'none'
agent(\`\${BRIEF} You are S3-B.\`, { label: 'runtime' })"
has "  runtime 1/8 missing rules,skills,OL,conflict,WRITE_BLOCKED,access,md-prefix" && ok "runtime \${BRIEF} stays as text and adds no element" || bad "runtime: [$ERR]"
run_js "agent(lens.map(x => x)) "
has "agent@L1 unresolved (member access)" && ok "member access as the argument: unresolved, default label agent@L1" || bad "member: [$ERR]"
run_js "const P = (who) => \`You are \${who}\`

agent(P('Default'), { label: 'probe:default' })
agent(r.prompt, { label: 'read:' + r.key })
const A = B
const B = A
agent(A)
agent()"
has "$(summary 4 0 4)" && has "  probe:default unresolved (call)" && has "  agent@L4 unresolved (member access)" \
    && has "  agent@L7 unresolved (constant cycle at A)" && has "  agent@L8 unresolved (no prompt)" \
    && ok "unresolved: call, member access (non-literal label), const cycle, no argument" || bad "unresolved: [$ERR]"
[ "$RC" -eq 0 ] && ! has "Guidance:" && ok "unresolved only: exit 0, no guidance" || bad "unresolved rc=$RC [$ERR]"
run_js "const A = '$FULL', B = '$FULL'
class K { agent(p) { return p } }
agent(B, { label: 'second-declarator' })"
has "$(summary 2 0 2)" && has "  second-declarator unresolved (identifier B is not a string constant)" && has "agent@L2 unresolved" \
    && ok "documented limits: second declarator and a class method named agent are unresolved" || bad "limits: [$ERR]"
printf "agent('You are S3-X. \\\\\r\n%s', { label: 'crlf' })\r\n" "$(prompt_without identity)" > "$WORK/s.js"
wf_payload "$WORK/s.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 1 1 0)" && ok "CRLF file with a backslash line continuation in a string: 8/8" || bad "crlf continuation: [$ERR]"

echo "== Budgets =="
perl -e 'my $p = shift; print "const COMMON = `$p ", "x" x 20000, "`\n"; print "agent(COMMON, { label: \"s$_\" })\n" for 1..500;' "$FULL" > "$WORK/s.js"
wf_payload "$WORK/s.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 500 500 0)" && ok "20 KB constant at 500 sites: charged once, all 500 scored (was a fallback)" || bad "budget once: [$(printf '%s\n' "$ERR" | sed -n '2p')]"
perl -e 'my $p = shift; print "const COMMON = `$p ", "x" x 200000, "`\n"; print "agent(COMMON, { label: \"s$_\" })\n" for 1..100;' "$FULL" > "$WORK/s.js"
wf_payload "$WORK/s.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 100 83 17)" && has "unresolved (scoring budget exceeded)" && ok "200 KB constant at 100 sites: 16 MB scoring budget, the rest unresolved" || bad "scoring budget: [$(printf '%s\n' "$ERR" | sed -n '2,3p')]"

echo "== scriptPath and no script =="
printf "agent('%s', { label: 'file' })\n" "$FULL" > "$WORK/wf-full.js"
printf "agent('%s', { label: 'file-gap' })\n" "$(prompt_without access)" > "$WORK/wf-gap.js"
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s"}}' "$WORK/wf-full.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 1 1 0)" && ok "scriptPath (absolute): file read, 8/8" || bad "abs scriptPath: [$ERR]"
printf '{"cwd":"%s","tool_name":"Workflow","tool_input":{"scriptPath":"wf-gap.js"}}' "$WORK" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "  file-gap 7/8 missing access" && ok "scriptPath relative to cwd: file read, access missing" || bad "rel scriptPath: [$ERR]"
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s/nope.js"}}' "$WORK" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && has "scriptPath missing, unreadable or over 512 KB; duty elements not checked." && ok "missing scriptPath: reminder, not checked" || bad "missing file: [$ERR]"
perl -e 'print "x" x 524289' > "$WORK/wf-big.js"
printf '{"tool_name":"Workflow","tool_input":{"scriptPath":"%s"}}' "$WORK/wf-big.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "over 512 KB; duty elements not checked." && ok "scriptPath over 512 KB: not read" || bad "big file: [$ERR]"
printf '{"tool_name":"Workflow","tool_input":{}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER"$'\n'"[workflow-guard] Workflow: no script or scriptPath in the input; duty elements not checked." ] \
    && ok "no script and no scriptPath: reminder, not checked" || bad "no script: [$ERR]"
ctx_check "not-checked output: stdout JSON = stderr"
printf '{"tool_name":"Workflow","tool_input":{"args":{"script":"agent(\\u0027decoy\\u0027)","n":[1,{"x":"}"}]},"script":"agent(\\u0027%s\\u0027, { label: \\u0027real\\u0027 })"}}' "$FULL" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 1 1 0)" && ! has "decoy" && ok "nested args.script decoy before the real script: only the top-level key counts" || bad "decoy: [$ERR]"
printf '{"tool_name":"Workflow","tool_input":{"args":{"scriptPath":"/nope.js"},"name":"saved-flow"}}' > "$WORK/p.json"
run_hook "$WORK/p.json"
has "no script or scriptPath in the input" && ok "nested args.scriptPath only (saved workflow by name): not checked" || bad "nested scriptPath: [$ERR]"
run_js "const x = '$FULL'
return x"
[ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER"$'\n'"[workflow-guard] Workflow: no agent() call in the script; duty elements not checked." ] \
    && ok "no agent( call: nothing to check (spec v1.1), not a fallback" || bad "no agent: [$ERR]"

echo "== Fallback: whole-script score =="
run_js "agent(\`You are S3-X. $E_rules"
has "per-agent() extraction failed (unterminated template); the script was checked as one text: 2/8, missing skills,OL,conflict,WRITE_BLOCKED,access,md-prefix." \
    && ok "unterminated template: fallback, one score" || bad "unterminated tpl: [$ERR]"
run_js "agent('You are S3-X. $E_rules
')"
has "extraction failed (unterminated string)" && ok "unterminated string: fallback" || bad "unterminated str: [$ERR]"
run_js "/* $FULL
agent('x')"
has "extraction failed (unterminated comment); the script was checked as one text: 8/8, missing none." && ok "unterminated comment: fallback 8/8" || bad "unterminated comment: [$ERR]"
perl -e 'print "agent(`", "\${`" x 5000, "\n"' > "$WORK/deep.js"
wf_payload "$WORK/deep.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
[ "$RC" -eq 0 ] && has "extraction failed (nesting too deep)" && ok "5000 nested templates: fallback (nesting too deep), exit 0" || bad "deep: rc=$RC [$ERR]"
ctx_check "fallback output: stdout JSON = stderr"

echo "== Context cap =="
: > "$WORK/many.js"
i=0
while [ "$i" -lt 60 ]; do
    printf "agent('%s', { label: 'gap-%s-%s' })\n" "$(prompt_without OL)" "$i" "$(perl -e 'print "x" x 50')" >> "$WORK/many.js"
    i=$((i + 1))
done
wf_payload "$WORK/many.js" > "$WORK/p.json"
run_hook "$WORK/p.json"
has "$(summary 60 0 0)" && has "  ... and 55 more" && ok "60 gaps: at most 5 listed, then '... and 55 more'" || bad "many: [$ERR]"
ctx_check "additionalContext <= 4000 characters"

echo "== Telemetry =="
mkdir -p "$WORK/repo/.scratch/session-t"
git -C "$WORK/repo" init -q
printf '%s\n' "$WORK/repo/.scratch/session-t" > "$WORK/repo/.scratch/.current-session"
EV="$WORK/repo/.scratch/session-t/events.jsonl"
printf "agent('%s', { label: 'full' })\nagent('%s', { label: 'gap' })\nagent(mk(1), { label: 'un' })\n" "$FULL" "$(prompt_without conflict)" > "$WORK/t.js"
wf_payload "$WORK/t.js" > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
n="$(sed -n '$=' "$EV" 2>/dev/null || echo 0)"
[ "$n" = "3" ] && ok "one event per agent() prompt (3)" || bad "event count=$n"
grep -q '"type":"delegation","src":"wdg","d":{"score":8,"total":8,"missing":"","mode":"observe","tool":"Workflow","checked":1,"scope":"agent","agent":"full"}' "$EV" \
    && ok "8/8 event: score 8, scope agent, agent label" || bad "full event: $(sed -n '1p' "$EV")"
grep -q '"d":{"score":7,"total":8,"missing":"conflict","mode":"observe","tool":"Workflow","checked":1,"scope":"agent","agent":"gap"}' "$EV" \
    && ok "gap event: score 7, missing conflict" || bad "gap event: $(sed -n '2p' "$EV")"
grep -q '"d":{"score":0,"total":8,"missing":"","mode":"observe","tool":"Workflow","checked":0,"scope":"agent","agent":"un","why":"call"}' "$EV" \
    && ok "unresolved event: score 0, checked 0, why call" || bad "un event: $(sed -n '3p' "$EV")"
printf "agent(\`You are S3-X.\n" > "$WORK/t.js"
wf_payload "$WORK/t.js" > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
printf '{"tool_name":"Workflow","tool_input":{}}' > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
printf "const x = 1\n" > "$WORK/t.js"
wf_payload "$WORK/t.js" > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' > "$WORK/p.json"
(cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$WORK/p.json" >/dev/null 2>&1)
n="$(sed -n '$=' "$EV" 2>/dev/null || echo 0)"
[ "$n" = "6" ] && ok "fallback: 1 event, no script: 1, no agent(: 1, Bash: none" || bad "event count after fallback/none/Bash=$n"
sed -n '4p' "$EV" | grep -q '"score":1,.*"checked":1,"scope":"script","why":"unterminated template"}' && ok "fallback event: scope script, checked 1, why" || bad "fallback event: $(sed -n '4p' "$EV")"
sed -n '5p' "$EV" | grep -q '"score":0,.*"checked":0,"scope":"script","why":"no script or scriptPath in the input"}' && ok "no-script event: checked 0, why" || bad "none event: $(sed -n '5p' "$EV")"
sed -n '6p' "$EV" | grep -q '"checked":0,"scope":"script","why":"no agent() call in the script"}' && ok "no-agent( event: checked 0, why" || bad "no-agent event: $(sed -n '6p' "$EV")"
if $HAVE_PY; then
    python3 -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$EV" && ok "events are valid JSON" || bad "events not valid JSON"
else
    skip "events are valid JSON (python3 not found)"
fi

echo "== Enforce mode =="
perl -pe 's/^MODE_WF_DUTY="observe"$/MODE_WF_DUTY="enforce"/' "$HOOK" > "$WORK/enforce.sh"
run_js "agent('$(prompt_without OL)')"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 2 ] && [ -z "$OUT" ] && has "missing OL" && ok "enforce + gap: exit 2, stderr only" || bad "enforce gap rc=$RC out=[$OUT]"
run_js "agent('$FULL')"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 0 ] && ok "enforce + 8/8: exit 0" || bad "enforce full rc=$RC"
run_js "agent(mk())"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 0 ] && ok "enforce + unresolved only: exit 0" || bad "enforce unresolved rc=$RC"
run_js "const x = 1"
run_hook "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 0 ] && ok "enforce + no agent( call: exit 0 (never blocks)" || bad "enforce no agent rc=$RC"

echo "== Strawberry-style CRLF output layer (PERLIO=:unix:crlf) =="
# run_crlf <payload> [hook]: the hook under a :crlf PerlIO layer, as
# Strawberry Perl defaults to (review N1, PR #135).
run_crlf() {
    local h="${2:-$HOOK}"
    RC=0
    PERLIO=:unix:crlf "$BASH_BIN" "$h" < "$1" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
    OUT="$(cat "$WORK/out.txt")"
    ERR="$(cat "$WORK/err.txt")"
}
run_js "agent('$E_identity $E_rules $E_skills $E_conflict $E_WRITE_BLOCKED $E_access', { label: 'crlf-gap' })"
run_crlf "$WORK/p.json" "$WORK/enforce.sh"
[ "$RC" -eq 2 ] && has "  crlf-gap 6/8 missing OL,md-prefix" && ok "crlf layer, enforce copy + gap: exit 2" || bad "crlf enforce: rc=$RC [$ERR]"
run_crlf "$WORK/p.json"
[ "$RC" -eq 0 ] && has "Name prefix (D-DEL1): tell the delegate" && ok "crlf layer: guidance for the last missing element (md-prefix) kept" || bad "crlf guidance: [$ERR]"
printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' > "$WORK/p.json"
run_crlf "$WORK/p.json"
[ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ -z "$OUT" ] && ok "crlf layer, Bash payload: silent" || bad "crlf Bash: rc=$RC [$ERR]"

echo "== perl absent =="
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        skip "perl absent (Windows Git Bash: perl shares /usr/bin with the tools the hook needs)" ;;
    *)
        mkdir -p "$WORK/bin"
        for t in cat date; do ln -sf "$(command -v "$t")" "$WORK/bin/$t"; done
        run_js "agent('$FULL')"
        RC=0
        PATH="$WORK/bin" "$BASH_ABS" "$HOOK" < "$WORK/p.json" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
        ERR="$(cat "$WORK/err.txt")"
        [ "$RC" -eq 0 ] && [ "$ERR" = "$REMINDER"$'\n'"[workflow-guard] perl not found: duty elements not checked." ] && ok "no perl: reminder + not checked, exit 0" || bad "no perl: rc=$RC [$ERR]"
        printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' > "$WORK/p.json"
        RC=0
        PATH="$WORK/bin" "$BASH_ABS" "$HOOK" < "$WORK/p.json" > "$WORK/out.txt" 2> "$WORK/err.txt" || RC=$?
        [ "$RC" -eq 0 ] && [ ! -s "$WORK/err.txt" ] && ok "no perl, Bash payload: silent" || bad "no perl Bash: rc=$RC" ;;
esac

echo "== Element-block parity with delegation-duty-guard.sh =="
# block_of <file>: the lines between the markers (empty when a marker or the
# file is missing). A missing block in either hook FAILS: it is the drift
# guarantee both hook headers promise (review N9, PR #135).
block_of() {
    [ -f "$1" ] || return 0
    perl -ne 'print if /# --- BEGIN delegation elements block ---/ .. /# --- END delegation elements block ---/' "$1" \
        | perl -ne 'print unless /# --- (BEGIN|END) delegation elements block ---/'
}
block_of "$HOOK" > "$WORK/blk-wdg.txt"
block_of "$DDG" > "$WORK/blk-ddg.txt"
grep -q '"md-prefix"' "$WORK/blk-wdg.txt" && ok "workflow guard carries the marked block" || bad "workflow guard: marked block missing"
grep -q '"md-prefix"' "$WORK/blk-ddg.txt" && ok "delegation-duty-guard carries the marked block" || bad "delegation-duty-guard ($DDG): file or marked block missing"
if cmp -s "$WORK/blk-wdg.txt" "$WORK/blk-ddg.txt"; then
    ok "marked blocks identical (shared/hooks/delegation-duty-guard.sh)"
else
    bad "element blocks differ:"
    # diff exits 1 when the files differ (expected here); its output is the evidence.
    diff "$WORK/blk-ddg.txt" "$WORK/blk-wdg.txt" || true
fi

echo "== Real fixtures (session 10cf255a-c) =="
# <file> <prompts> <all eight> <unresolved> [expected score of every scored prompt]
check_fixture() {
    local f="$1" n="$2" m="$3" u="$4" p
    case "$f" in
        *.js)
            printf '{"tool_name":"Workflow","cwd":"%s","tool_input":{"scriptPath":"%s"}}' "$FX" "$f" > "$WORK/p.json"
            p="$WORK/p.json" ;;
        *) p="$FX/$f" ;;
    esac
    run_hook "$p"
    [ "$RC" -eq 0 ] && has "$(summary "$n" "$m" "$u")" && ok "$f: $n prompts, $m with all eight, $u unresolved" || bad "$f: rc=$RC [$(printf '%s\n' "$ERR" | sed -n '2p')]"
}
check_fixture workflow-001.json 3 0 1
check_fixture workflow-010.json 2 0 2
check_fixture workflow-011.json 1 0 0
check_fixture workflow-045.json 14 0 0
check_fixture workflow-046.json 2 0 2
check_fixture merge-all-prs.js 14 0 0
check_fixture missions-gate-ledger.js 2 0 2
check_fixture nesting-depth-probe.js 1 0 0
check_fixture probe-workflow-nesting.js 2 0 2
# Per-agent scores, read from the telemetry of a temp repo.
fixture_scores() {  # fixture_scores <payload> -> "label=score" list, one line
    : > "$EV"
    (cd "$WORK/repo" && "$BASH_BIN" "$HOOK" < "$1" >/dev/null 2>&1)
    perl -ne 'print "$2=$1 " if /"score":(\d+),.*"checked":1,"scope":"agent","agent":"([^"]*)"/' "$EV"
}
s045="$(fixture_scores "$FX/workflow-045.json")"
exp045="brief=7 friction:l.k=7 friction:plan=7 friction:review=7 merge:#n=7 verify:#n=7 post:s.k=7 verify:s.k=7 scrub:a.k=7 release:notes=7 release:apply=7 release:cleanup=7 release:verify=7 final=7 "
[ "$s045" = "$exp045" ] && ok "workflow-045 (merge-all-prs): 14 labels, each 7/8 (conflict missing: written before D-DEL6)" || bad "045 scores: [$s045]"
s001="$(fixture_scores "$FX/workflow-001.json")"
[ "$s001" = "verify:e2e=2 critic=2 " ] && ok "workflow-001: verify:e2e 2/8, critic 2/8 (read:... prompts unresolved)" || bad "001 scores: [$s001]"
s011="$(fixture_scores "$FX/workflow-011.json")"
[ "$s011" = "Probe-L1 workflow=1 " ] && ok "workflow-011: Probe-L1 1/8" || bad "011 scores: [$s011]"

echo "== Timing (500 KB, best of 5) =="
# best_ms <payload>: best of 5 runs in ms; prints "rc=<n>" instead when any
# run exits with a status other than 0 (a crash must not pass as fast).
best_ms() {
    perl -MTime::HiRes=time -e '
        my ($bash, $hook, $in) = @ARGV; my $best = 1e9;
        for (1..5) {
            my $t = time; system("\"$bash\" \"$hook\" < \"$in\" >/dev/null 2>&1");
            my $rc = $? >> 8;
            if ($? != 0) { print "rc=$rc"; exit 0; }
            my $d = (time - $t) * 1000; $best = $d if $d < $best;
        }
        printf "%d", $best;' "$BASH_ABS" "$HOOK" "$1"
}
timing() {  # timing <name> <payload> <expected stderr text> [hard limit ms, default 100]
    local ms size hard="${4:-100}"
    run_hook "$2"
    if [ "$RC" -ne 0 ] || ! has "$3"; then bad "$1: output check failed: rc=$RC [$(printf '%s\n' "$ERR" | sed -n '2p')]"; return 0; fi
    ms="$(best_ms "$2")"
    case "$ms" in rc=*) bad "$1: a timed run exited with $ms"; return 0 ;; esac
    size="$(wc -c < "$2" | tr -d ' ')"
    # The budget (spec v1.1 section 9: 100 ms for a 500 KB script) is hard on
    # macOS; elsewhere it is advisory (Windows process start-up alone can
    # exceed it; Linux CI runners vary). A stress case may pass a higher hard
    # limit: between 100 ms and it, the result is a (counted) WARN.
    case "$(uname -s)" in
        Darwin)
            if [ "$ms" -lt 100 ]; then ok "$1 ($size bytes): best of 5 = ${ms} ms"
            elif [ "$ms" -lt "$hard" ]; then warn "$1: $ms ms (>= 100, < $hard hard limit)"
            else bad "$1: ${ms} ms (>= $hard)"; fi ;;
        *)
            if [ "$ms" -lt 100 ]; then ok "$1 ($size bytes): best of 5 = ${ms} ms"; else warn "$1: $ms ms (>= 100; advisory on $(uname -s))"; fi ;;
    esac
}
perl -e 'local $/; open(my $f, "<", $ARGV[0]) or die; my $s = <$f>; my $o = ""; $o .= $s while length($o) < 512000; $o = substr($o, 0, 520000); $o =~ s/[^\n]*\z//; print $o;' "$FX/merge-all-prs.js" > "$WORK/big.js"
wf_payload "$WORK/big.js" > "$WORK/big.json"
# Stress case (19 merge-all scripts in one): ~80 ms on an M-series Mac, 126 ms
# on the GitHub macOS runner (PR #135 CI); 250 ms catches a 2x regression.
timing "500 KB script, 270 agent() prompts (stress)" "$WORK/big.json" "$(summary 270 0 0)" 250
perl -e 'my $p = shift; print "const COMMON = `$p ", "lorem ipsum dolor sit amet " x 18000, "`\n", "// padding\n" x 2000, "agent(COMMON, { label: q })\n"' "$FULL" > "$WORK/one.js"
wf_payload "$WORK/one.js" > "$WORK/one.json"
timing "500 KB script, one 486 KB prompt" "$WORK/one.json" "$(summary 1 1 0)"
# Adversarial: under the 512 KB cap (so the template closes and the prompt is
# scored per agent), with ".md" hits so the bounded md-prefix loop runs.
perl -e 'print "agent(`", "name prefix x.md " x 28000, "`)\n"' > "$WORK/adv.js"
wf_payload "$WORK/adv.js" > "$WORK/adv.json"
timing "adversarial 476 KB 'name prefix x.md' prompt" "$WORK/adv.json" "$(summary 1 0 0)"

echo
printf 'workflow-delegation-guard: %d passed, %d failed, %d skipped, %d warnings (bash: %s)\n' "$PASS" "$FAIL" "$SKIP" "$WARN" "$("$BASH_BIN" -c 'echo $BASH_VERSION')"
[ "$FAIL" -eq 0 ]
