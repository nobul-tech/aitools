# S3-Hook2-Parser hand-back v1.1 (2026-10-28): phases 1 and 2

**Intent**: **Purpose**: Hand S3-Hook2 the state of the workflow-delegation-guard
build (hook, tests, fixtures, registration, PR #135) with the evidence a
reviewer needs. **Scope**: What was built, how it was verified, what is not run,
open questions. NOT the spec (S3-Hook2-spec.md v1.0). **Audience**: S3-Hook2,
the reviewer, the commander.

v1.1 adds phase 2 (after PR #122 merged at 2026-10-28T17:34:47Z, d8f0aed) and
the PR. v1.0 (commit 1428e35) covered phase 1 only.

## Summary

- `shared/hooks/workflow-delegation-guard.sh` (new, observe, `MODE_WF_DUTY`):
  PreToolUse(Workflow); a Perl lexer finds every static `agent(` call site,
  resolves its prompt and scores it with the eight-element block shared
  verbatim with delegation-duty-guard.sh.
- `delegation-duty-guard.sh` back to matcher `Agent`, Workflow branch removed,
  element block wrapped in the markers; its Workflow tests moved to the new
  suite.
- Registered: hooks-manifest, hook-rollout rows (rule + Cursor twin),
  tool-ops.json, tool-ops-claude-code.md rows #28/#29, check.yml (4 steps),
  /delegate SKILL.md step 13 (S3-Hook2's correction).
- PR: https://github.com/nobul-tech/aitools/pull/135 (base main, branch
  `feature/hook2-workflow-agents`).

## Commits

| SHA | What |
|-----|------|
| a486900 | hook, suite, fixtures |
| 7acdeaa | timing budget hard on macOS only |
| 1428e35 | hand-back v1.0 |
| (merge) | `git merge --no-ff origin/main` (PR #122), no conflicts |
| 4aaf714 | delegation-duty-guard back to Agent, markers, Workflow tests moved |
| da43dc5 | manifest, rollout rows, tool-ops.json, tool-ops-claude-code.md, check.yml |
| 706c711 | suite fixes from CI: Windows CRLF in the python ctx write; stress-case limit 250 ms |
| (this) | /delegate SKILL.md step 13, hand-back v1.1 |

## Per-fixture agent() counts (asserted by the suite)

| Fixture | Prompts | All eight | Unresolved | Scores |
|---------|---------|-----------|------------|--------|
| workflow-001.json (issue9-reconcile) | 3 | 0 | 1 | verify:e2e 2/8, critic 2/8; `agent(r.prompt, ...)` L24 unresolved (member access) |
| workflow-010.json = missions-gate-ledger.js | 2 | 0 | 2 | L198 `agent(missionPrompt(m))`, L199 `agent(reviewPrompt(m, r))`: unresolved (call) |
| workflow-011.json = nesting-depth-probe.js | 1 | 0 | 0 | Probe-L1 1/8 |
| workflow-045.json = merge-all-prs.js | 14 | 0 | 0 | each 7/8, missing conflict (predates D-DEL6) |
| workflow-046.json = probe-workflow-nesting.js | 2 | 0 | 2 | `agent(PROMPT(...))`: unresolved (call); the `agent(` inside the PROMPT template is not counted |

Hand spot-checks: workflow-001 (decoded script: `agent(` only at L24, L27,
L31 = 3) and probe-workflow-nesting.js (L35, L36 call sites; L28 inside a
template = 2). merge-all-prs.js: 14 sites by grep (L48 ... L193).

## Verification

- Both suites under bash 5.3.15 and /bin/bash 3.2.57: test-workflow-delegation-guard 68/68,
  test-delegation-duty-guard 44/44; parity "marked blocks identical
  (shared/hooks/delegation-duty-guard.sh)". Before the markers existed, the
  parity case compared against the PR #122 worktree copy, and printed SKIP
  (not pass) with `AITOOLS_TEST_DDG_REF=/nonexistent`.
- Timing best of 5, local macOS: stress (270 prompts, 500 KB) 72-83 ms; one
  486 KB prompt 23-29 ms; adversarial 540 KB 48-58 ms. CI run 40738051844:
  macOS runner 126 ms on the stress case (now WARN band 100-250 ms, hard fail
  at 250); Windows Git Bash 238 / 130 / 170 ms (advisory).
- tool-ops.json: 8/8 cases of both hooks pass (scratch
  verify-toolops-cases.py). Manifest and tool-ops.json parse; check.yml parses
  (ruby yaml, 4 new steps); check-hook-parity.py OK (19 hooks).
- check-pre-commit: only step 6 FAIL (known:
  harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh at 100644).
  check-pre-push: only step 7 FAIL (known: dotprofile deploy/ stale).
- CI run 40738051844 (da43dc5): linux green; windows failed on the CRLF ctx
  compare; macos failed on the stress timing; both fixed in 706c711.

## Not run

- The 2 s time guard firing (nesting and budget guards fire first).
- Any deploy (`aitools install`, `build-deploy.sh`).

## Review after (D-DEL5)

See the PR body: hook-rollout.md and .mdc rows, tool-ops.json,
tool-ops-claude-code.md, the Intent headers of both hooks, and (not
protected) shared/skills/delegate/SKILL.md step 13.

## Contract notes

Listed in the PR body "Contract change": enforce blocks on a fallback gap too;
summary line printed at 8/8; worst-list order; telemetry written by perl;
first definition of a duplicate constant wins; the Agent guard keeps its
reminder text; the stress-case timing limit.

## Slip, corrected

My first Write of v1.0 went to the main checkout instead of the worktree; I
removed that file and the empty directory it created within a minute.

## Open questions

- None blocking. Follow-ups: the dotprofile delegation.md "Detection"
  paragraph still describes one hook on Agent and Workflow; resolve
  `agent(r.prompt)` over const arrays of object literals.
