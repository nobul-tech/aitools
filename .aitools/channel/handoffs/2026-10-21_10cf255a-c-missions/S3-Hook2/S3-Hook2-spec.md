# S3-Hook2 spec v1.0 (2026-10-28): workflow-delegation-guard

**Intent**: **Purpose**: The contract for the per-`agent()` delegation check on
Workflow tool calls, shared by its builder (S3-Hook2-Parser) and its reviewer.
**Scope**: Hook behaviour, extraction rules, output, telemetry, tests,
registration. NOT the Agent-tool guard's logic (delegation-duty-guard.sh,
PR #122). NOT the hook audit or harness-db (separate PRs). **Audience**:
S3-Hook2's delegates and reviewers, the commander.

## 1. Facts this design rests on (verified 2026-10-28, Claude Code 2.1.309)

- Hooks reference, https://code.claude.com/docs/en/hooks (read with
  chrome-devtools, saved text in S3-Hook2's scratch):
  - "Claude never sees stderr from a hook that exits 0."
  - PreToolUse "Matches on any tool name except EndConversation: built-in
    tools such as Bash, ..., Agent, Workflow, ...".
  - "When a subagent calls a tool, tool events such as PreToolUse and
    PostToolUse fire the same configured hooks as in the main conversation,
    and the input carries the agent_id and agent_type common input fields".
  - PreToolUse `hookSpecificOutput.additionalContext`: "String added to
    Claude's context alongside the tool result"; additionalContext is capped
    at 10,000 characters.
- Live record, session 10cf255a-c: the transcripts of the agents of workflow
  wf_11a87d20-2c7 (`subagents/workflows/wf_11a87d20-2c7/agent-*.jsonl`) hold
  34 `PreToolUse:Bash` hook notices, 1 `PreToolUse:Read` and 68
  `PostToolUse:Write` hook records: hooks fire on the tool calls made INSIDE
  workflow agents.
- `agent()` is a function of the workflow runtime, not a tool call of the
  session; workflow agents have no Agent, Task or Workflow tool (probe
  wf_e09cb1ca-dca, 2026-10-21; re-verified 2026-10-26). So no PreToolUse
  event exists per `agent()`; the only event that sees the prompts is the
  ONE PreToolUse(Workflow) event, whose `tool_input` carries the whole
  `script` (the 5 real Workflow payloads of session 10cf255a-c carry only
  `script`).
- Conclusion: the per-agent() check must parse the script at the Workflow
  PreToolUse event. The commander (2026-10-28): "if it doesnt, then we need a
  workflow delegattioin duty guard hook that mirrors what the agent
  delegation duty guard hook does. it will need to be adopted to how scripts
  work".

## 2. Decision: a separate hook

`shared/hooks/workflow-delegation-guard.sh`, PreToolUse matcher `Workflow`.
`delegation-duty-guard.sh` returns to matcher `Agent` and drops its
Workflow branch (a narrowing change for that hook). Why separate: the
commander asked for a workflow guard that mirrors the Agent guard; the script
parser is the larger, riskier part and gets its own mode variable
(`MODE_WF_DUTY`), its own tests and its own rollout row; the Agent guard stays
small and fast. The eight-element regexes must not drift: both hooks carry
the same Perl block between the markers

    # --- BEGIN delegation elements block ---
    # --- END delegation elements block ---

copied verbatim (the precedent: the "aitools environment block" in
cross-platform.md), and a test fails when the two blocks differ.

## 3. Input

- `tool_name` must be `Workflow`; any other tool: silent, exit 0.
- Script text: `tool_input.script` (JSON-unescaped as in
  delegation-duty-guard.sh); else the `scriptPath` file (same rules as that
  hook: relative to `cwd`, regular readable file, at most 512 KB, read as
  is); else the reminder plus "not checked".
- Only the first 512 KB of script text is parsed.

## 4. Extraction (Perl, no modules beyond core; no node)

1. Lexer driven by `\G...` / `/gc` regexes (no per-character substr loop):
   line comments, block comments, `'...'` and `"..."` strings with escapes,
   template literals with `${ ... }` (brace depth, nested strings and nested
   templates inside the expression), regex literals by the previous-token
   heuristic (a `/` after `( , = : [ ! & | ? { } ; return` or at the start is
   a regex), identifiers, punctuation.
2. Constants: every `const|let|var NAME = <string expression>` where the
   expression is string literals, template literals, identifiers, `+` and
   parentheses only. Stored unresolved; resolved lazily with cycle detection
   and depth at most 10.
3. Call sites: every `agent(` whose `agent` is a whole identifier not
   preceded by `.` and not a declaration (`function agent`). Comments and
   strings never count. The first argument is parsed up to the depth-0 `,`
   or `)`:
   - string literal: its text;
   - template literal: literal chunks plus, for each `${e}`: if `e` is a
     bare identifier bound to a resolvable constant, its text; otherwise the
     literal text `${e}` stays in place (runtime value, e.g. `${l.k}`,
     `${BRIEF}`);
   - identifier: the constant's text;
   - `+` concatenation of the above;
   - anything else (call, ternary, member access as the whole argument):
     **unresolved**.
4. Label: a string or template literal `label:` in the second argument's
   object literal, else `agent@L<line>`. Sanitised to `[A-Za-z0-9 :#._/-]`,
   at most 60 characters.
5. A static call site counts once, even inside a loop or `map()`.
6. Fallback to the whole-script check (one score, as PR #122 does) when the
   lexer fails (unterminated string, template or comment), when no
   `agent(` call is found, or on the time guard (Perl `alarm`, 2 s).

## 5. Scoring

Each resolved prompt is scored by the shared eight-element block
(identity, rules, skills, OL, conflict, WRITE_BLOCKED, access, md-prefix),
on at most its first 256 KB.

## 6. Output (exit 0 in observe; `MODE_WF_DUTY="enforce"` exits 2 when any
resolved prompt misses an element, stderr only)

stdout: one `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"..."}}`
line (valid JSON, at most 4,000 characters of context). stderr: the same
text. Content:

1. The reminder line: `[workflow-guard] Load /delegate before every
   Workflow call; every agent() prompt is a delegation prompt and needs all
   eight elements.`
2. `[workflow-guard] Workflow: <N> agent() prompts, <M> with all eight,
   <U> unresolved.` then at most 5 worst prompts:
   `<label> <s>/8 missing <a,b,c>`; unresolved ones as
   `<label> unresolved (<reason>)`.
3. Per-element guidance (the texts of delegation-duty-guard.sh) for each
   element missing in any prompt.
4. In fallback: `[workflow-guard] per-agent() extraction failed (<reason>);
   the script was checked as one text: <s>/8, missing <...>.`

## 7. Telemetry (session `events.jsonl`, src `wdg`, as delegation-duty-guard)

One `delegation` event per resolved prompt:
`{"score":s,"total":8,"missing":"...","mode":"observe","tool":"Workflow","checked":1,"scope":"agent","agent":"<label>"}`;
an unresolved prompt: `score 0, checked 0, scope agent`; fallback: one event
with `scope "script"`, `checked 1`. Nothing to check: one event,
`checked 0`.

## 8. Limits to document in the header

Static call sites, not runtime calls; runtime values (`${l.k}`) are left as
text and can neither add nor hide an element unless the literal text names
it; prompts built by functions are unresolved; only the first 512 KB parsed.

## 9. Performance and robustness

Under 100 ms for a 500 KB script, best of 5, macOS bash 5 and /bin/bash
3.2 (advisory on Git Bash). Never crashes, never hangs, never blocks in
observe; perl absent: reminder only.

## 10. Tests (`tests/hooks/test-workflow-delegation-guard.sh`)

Smoke (Bash and Agent payloads: silent, exit 0); violation (a prompt that
misses elements, per-agent output); string literal; template with a const;
concatenation; const reference; a shared COMMON const; nested template in
`${}`; `agent(` inside a comment and inside a string (not counted);
`.agent(` (not counted); a regex literal containing a backtick; map lambda
with `${l.k}`; an unresolved argument; scriptPath (relative); a malformed
script (fallback); 500 KB timing; stdout parses as JSON (`python3 -c
'import json,sys; json.load(sys.stdin)'`); telemetry event count per prompt;
the element-block parity check against delegation-duty-guard.sh; the real
fixtures (the 5 Workflow payloads of session 10cf255a-c and the 4 scripts
in its `workflows/scripts/`, copied to `tests/hooks/fixtures/workflow/`)
with their expected per-agent counts; bash 5 and /bin/bash 3.2 (the
suite honours `AITOOLS_TEST_BASH`).

## 11. Registration and documentation (after PR #122 is on main)

- `shared/hooks/hooks-manifest.json`: `delegation-duty-guard.sh` matcher
  `Agent`; new entry `workflow-delegation-guard.sh`, PreToolUse, `Workflow`.
- `delegation-duty-guard.sh`: Workflow branch removed, the element block
  wrapped in the markers (no logic change); its Workflow tests move to the
  new suite.
- `.claude/rules/hook-rollout.md` and `.cursor/rules/hook-rollout.mdc`: a new
  row (observe) and the delegation-duty-guard row updated.
- `registries/tool-ops.json` through the tool-ops skill process: the new hook
  and its verification cases; the delegation-duty-guard matcher.
- `reference/tool-ops-claude-code.md`: version-dependency rows for the hook
  output channel (stderr at exit 0 is invisible; additionalContext) and the
  Workflow event shape (one PreToolUse per Workflow call with the script;
  no event per `agent()`; tool calls inside workflow agents fire hooks with
  `agent_id`), verified 2.1.309.
- `.github/workflows/check.yml`: the new suite on macOS (bash 5 and
  /bin/bash 3.2), Linux and Windows Git Bash, next to the
  delegation-duty-guard steps.
