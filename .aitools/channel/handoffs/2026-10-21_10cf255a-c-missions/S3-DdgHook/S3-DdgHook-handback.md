# S3-DdgHook hand-back (v1.2, 2026-10-26)

## v1.2: review round 2 (verdict v1.1 "no blocking findings" at ad72004)

Non-blocking N8 and N11 fixed after the verdict: JSON string values (prompt,
script) are unescaped before matching, so a path or "rules" right after a
`\n` is no longer missed (the Windows-path alternative now takes `C:\` or
`C:/`); the suite's telemetry runs no longer print the hook's stdout. Suite:
50 passed under bash 5.3.15 and /bin/bash 3.2.57; fixtures and tool-ops cases
unchanged. N9 (window and 256 KB limits) and N10 (a nested "prompt" key
before the real one, not possible with the Agent tool today) stay as
documented. Commit of these fixes was not re-reviewed.

## v1.1: review round 1 (S3-DdgHook-Review, verdict "blocking findings")

Verdict: `S3-DdgHook-Review-verdict.md` in this folder (PR #122 comment).
Fixed on the branch:

- **B1 (reminder never reached Claude)**: Claude Code ignores stderr of a hook
  that exits 0, so since 2026-03-24 no observe-mode output of this hook ever
  reached the delegating agent. The hook now also prints
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":...}}`
  on stdout (the `glossary-skill-guard.sh` pattern); stderr keeps the text for
  the transcript; enforce (exit 2) stays stderr-only. Limit (header): the
  context reaches Claude with the tool result, so it corrects the next launch.
- **B2 (access always present)**: the check ran on the whole payload, whose
  `cwd` / `transcript_path` are always absolute. Now only `tool_input.prompt`
  (Agent/Task) or `tool_input.script` / the `scriptPath` file (Workflow) is
  checked; an Agent payload with no prompt reports "not checked". Test
  fixtures now carry the real common fields.
- **N1**: identity `S[1-9]` is case-sensitive and not inside a word ("s3",
  tool_use_id noise no longer count); "conflict resolution" dropped and
  `CONFLICT:` case-sensitive. On the real fixtures this turned workflow-045
  from 8/8 to 7/8: its "conflict resolution" was about git merge conflicts,
  a false positive.
- **N2**: md-prefix searches only windows around the first 200 ".md"/"markdown"
  hits; 300 KB of "name prefix " now 41-51 ms (was ~760 ms); scriptPath cap
  2 MB -> 512 KB; only the first 256 KB of text is checked.
- Suite: 48 passed under bash 5.3.15 and /bin/bash 3.2.57; tool-ops.json
  cases updated (`expectStdout` now the additionalContext JSON) and passing.
- hook-rollout.md row and .mdc: now say the output goes to Claude as
  additionalContext JSON (and that before 2026-10-26 it did not).

N3 (`\uXXXX` in scriptPath not decoded: reported "not checked"), N4
(scriptPath unverified), N5 (whole-script limit) stay as documented.

Mission DDG-HOOK, delegated by Session Commander 10cf255a-c (level 1).
Branch `feature/ddg-agent-workflow`, PR base `main` (URL in the final
response and the PR itself).

## Summary

- `shared/hooks/delegation-duty-guard.sh` now runs on Agent, Task (old name)
  and Workflow, prints one reminder line to load `/delegate` on every such
  call (even at 8/8), and checks the eight `/delegate` v2.0 elements.
- Workflow: checks `tool_input.script`; with only `scriptPath`, reads that
  file (relative paths against the payload `cwd`, regular readable file,
  2 MB cap); with neither, reminds and says "not checked". The script is
  checked as one text (documented limit in the header and in the guidance).
- Matcher `Agent|Workflow` in `shared/hooks/hooks-manifest.json`.
- Telemetry: one `delegation` event per call (was: only on gaps), `total` 8,
  new `tool` and `checked` fields.
- Mode stays `observe` (a widening change, `.claude/rules/hook-rollout.md`).

## Element matching (lenient, per the mission)

| # | Element | Matches |
|---|---------|---------|
| 1 | identity | `S[1-9]`, "you are", "your identity", "your role" (unchanged) |
| 2 | rules | "CLAUDE.md" AND "rule(s)" (was: either) |
| 3 | skills | "/delegate", "delegate skill", "skills/delegate" (was: any "skills") |
| 4 | OL | "operational learning", "carry forward", "OL-" |
| 5 | conflict (new) | "D-DEL6", "CONFLICT:", "conflict priority/resolution" |
| 6 | WRITE_BLOCKED | unchanged |
| 7 | access | was "explicit paths", "Glob/Grep", "cross-repo", "OL-O12"; adds "absolute path(s)" and any absolute path (`/Users/`, `/home/`, `/root/`, `/tmp/`, `~/`, `C:/`, JSON-escaped `C:\\`) |
| 8 | md-prefix | D-DEL1 logic, plus ".md" inside a "name ... prefix" span ("Name every .md file you write with the prefix S2-") |

The md-prefix addition fixes a pre-existing false negative: the registry
verification case in `registries/tool-ops.json` (prompt "Name every .md file
you write with the prefix S2-Audit-", expected no stderr) failed against the
origin/main hook too (scratch `old-hook.sh`, same regex).

## Evidence

- Matcher syntax: `hooks-manifest.json` already registers `Read|Grep`
  (glossary-skill-guard) and `Write|Edit` (sh-file-fixup); the live
  `~/.claude/settings.json` PreToolUse array holds `Read|Grep` as one
  matcher. `setup-user-hooks.sh` `mergeHookEntry` / `.ps1` `MergeHookEntry`
  pass the manifest string through verbatim and overwrite the matcher of
  an existing entry (`rule.matcher = matcher`), and each hook has its own
  rule, so the deployed Agent entry is updated in place on the next run.
- Workflow payload shape: the 5 Workflow tool_use inputs in session
  10cf255a-c carry only `script` (extracted by scratch
  `extract-fixtures.py`); `scriptPath` support follows the mission text and
  is not seen in a real payload.

## Verification (macOS, 2026-10-26)

- `bash -n` and `/bin/bash -n` on the hook and the test: 0.
- `tests/hooks/test-delegation-duty-guard.sh`: 39 passed, 0 failed under
  bash 5.3.15 and /bin/bash 3.2.57; large prompt (216 KB) best of 5:
  28-36 ms.
- rule smoke test (Bash payload): exit 0, no output; violation test
  (Agent "do the thing"): exit 0, reminder + 0/8 guidance.
- 51 real launch payloads from session 10cf255a-c (46 Agent, 5 Workflow):
  identical results under bash 5 and 3.2; two at 8/8 (this mission's own
  prompt and one Workflow written after /delegate v2.0); the rest miss
  `conflict` (D-DEL6 dated 2026-10-26, after most launches) and/or the
  stricter `rules`/`skills`. Spot-checks: agent-050 really has no
  /delegate instruction although it spawns sub-agents; agent-020/037/039
  have no "CLAUDE.md" at all.
- `registries/tool-ops.json` claude-code delegation-duty-guard cases (4)
  pass against the new hook (scratch `toolops-verify.py`).

## Not run

- Windows Git Bash and Linux (CI will run the suite; the perl-absent case
  is skipped on Git Bash, and the 50 ms timing is advisory there).
- A live Claude Code Workflow call through the deployed hook (needs
  `aitools install` against the real HOME, which this mission may not run).
  Unknown until then: that PreToolUse fires for Workflow with
  `tool_name` "Workflow".
- `scripts/build-deploy.sh` (frozen shared `deploy/`; the dotprofile
  `deploy/` is rebuilt by the commander's flow).

## Review after (protected files, D-DEL5)

- `.claude/rules/hook-rollout.md`, delegation-duty-guard row: added "since
  2026-10-26 matcher `Agent|Workflow` (D-DEL7), checks the eight `/delegate`
  v2.0 elements (Agent prompt, or the Workflow `script` / `scriptPath` file
  as one text) and prints a reminder to load `/delegate` on every Agent and
  Workflow call -- a widening change, so it stays observe"; "a `delegation`
  event" -> "one `delegation` event per call (with `tool`)"; added the test
  path. State unchanged: observe.
- `.cursor/rules/hook-rollout.mdc`: the delegation-duty-guard sentence gains
  the matcher, the every-call reminder and the eight elements.
- `registries/tool-ops.json`: hook matcher `Agent` -> `Agent|Workflow`,
  purpose rewritten for eight elements and the reminder; KPI unit
  "/ 7" -> "/ 8 (7 before 2026-10-26; each event carries its total)";
  verification cases updated to the new output (+1 Workflow case);
  `meta.lastUpdated` 2026-10-26.
- `reference/tool-ops-claude-code.md`: "element 7" -> "element 8 of eight
  since 2026-10-26".

## Notes

CONFLICT: /tool-ops skill "Present for user review ... Write if approved" vs
D-DEL5 (commander, 2026-10-26: protected files written as versions, reviewed
after) and this prompt -- resolved by tier 1 (commander's words): wrote
tool-ops.json and the rule rows, listed them under Review after.

INCIDENT: registries/tool-ops.json delegation-duty-guard verification case 1
expected no stderr but the origin/main hook reported md-prefix missing for
its prompt; no runner executes these cases (tool-ops-session-audit.sh tests
only block-claude-code-guide.sh), so the drift went unseen. Fixed here; the
missing runner remains.

INCIDENT (from the reviewer, verified against glossary-skill-guard.sh and the
transcript evidence it cites): delegation-duty-guard.sh wrote its observe-mode
reminder to stderr with exit 0 from 2026-03-24 to this PR, so it never reached
the delegating agent; other observe-mode / stderr-on-exit-0 hooks need the same
audit.

INCIDENT (partial fix): the inline_lib_bash embed bug (hooks naming the
shared lib get the whole lib inlined) had delegation-duty-guard.sh line 38 as
one instance; the header no longer names the library. The build-deploy
pattern itself is unchanged.
