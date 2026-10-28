# S3-Hook2-Parser hand-back v1.0 (2026-10-28): phase 1

**Intent**: **Purpose**: Hand S3-Hook2 the state of the workflow-delegation-guard
build (phase 1: hook, tests, fixtures) with the evidence a reviewer needs.
**Scope**: What was built, how it was verified, what is not run, open questions.
NOT the spec (S3-Hook2-spec.md v1.0). NOT phase 2 registration (pending PR #122;
v1.1 of this file records it). **Audience**: S3-Hook2, the reviewer, the
commander.

## Summary

- `shared/hooks/workflow-delegation-guard.sh` (new, observe, `MODE_WF_DUTY`):
  one PreToolUse(Workflow) hook that lexes the script in Perl, finds every
  static `agent(` call site, resolves its prompt and scores it with the
  eight-element block copied verbatim from the PR #122 delegation-duty-guard.sh.
- `tests/hooks/test-workflow-delegation-guard.sh` (new): 68 cases, green under
  bash 5.3.15 and /bin/bash 3.2.57.
- `tests/hooks/fixtures/workflow/`: the 5 real Workflow payloads and the 4
  real scripts of session 10cf255a-c, plus one real Agent payload.
- Branch `feature/hook2-workflow-agents`: a486900 (hook, tests, fixtures),
  7acdeaa (timing budget hard on macOS only).
- Phase 2 (registration, delegation-duty-guard narrowing, rollout rows,
  tool-ops, check.yml, PR) waits for PR #122 to merge.

## Per-fixture agent() counts (asserted by the suite)

| Fixture | Prompts | All eight | Unresolved | Scores |
|---------|---------|-----------|------------|--------|
| workflow-001.json (issue9-reconcile) | 3 | 0 | 1 | verify:e2e 2/8, critic 2/8; `agent(r.prompt, ...)` at L24 unresolved (member access) |
| workflow-010.json = missions-gate-ledger.js | 2 | 0 | 2 | `agent(missionPrompt(m))` L198, `agent(reviewPrompt(m, r))` L199: unresolved (call) |
| workflow-011.json = nesting-depth-probe.js | 1 | 0 | 0 | Probe-L1 1/8 (identity only) |
| workflow-045.json = merge-all-prs.js | 14 | 0 | 0 | every prompt 7/8, missing conflict (the script predates D-DEL6) |
| workflow-046.json = probe-workflow-nesting.js | 2 | 0 | 2 | `agent(PROMPT('Default'))`, `agent(PROMPT('GP'))`: unresolved (call); the `agent('Reply NESTED-WF-OK')` inside the PROMPT template is not counted |

Hand spot-checks (read the script, counted the `agent(` call sites):
- workflow-001: lines 24, 27 and 31 are the only `agent(` sites (read from the
  decoded script); 3 = the hook's count; L24's argument is `r.prompt`.
- workflow-046 / probe-workflow-nesting.js: lines 35 and 36 are the call
  sites; line 28 holds `agent('Reply NESTED-WF-OK')` inside the PROMPT
  template literal, correctly not counted; 2 = the hook's count.
- merge-all-prs.js: the 14 sites at lines 48, 65, 68, 71, 103, 114, 150, 154,
  173, 176, 178, 184, 186, 193 (grep of the payload's script); 14 = the count.

## Verification

- `bash tests/hooks/test-workflow-delegation-guard.sh`: 68 passed, 0 failed
  (bash 5.3.15); `AITOOLS_TEST_BASH=/bin/bash /bin/bash ...`: 68 passed
  (3.2.57). With `AITOOLS_TEST_DDG_REF=/nonexistent` the parity case prints
  SKIP (67 passed, 1 skipped), never a pass.
- Parity: the marked block equals lines "# 1. Identity" .. `$check->("md-prefix", $mdp);`
  of /Users/new-jose/repos/aitools/.claude/worktrees/ddghook/shared/hooks/delegation-duty-guard.sh.
- Timing, best of 5 (macOS, M-series):

  | Input | bash 5 | /bin/bash 3.2 |
  |-------|--------|---------------|
  | 500 KB script (merge-all-prs.js copies), 270 agent() prompts | 79-82 ms | 79-82 ms |
  | 500 KB script, one 486 KB prompt | 27-28 ms | 27 ms |
  | adversarial 540 KB "name prefix" prompt | 53-56 ms | 53 ms |

  First version: 141 / 117 ms. Fixes: perl reads stdin itself (no 500 KB bash
  variable), tokens as arrays, perl writes telemetry and the message header
  (no bash loop per event: ~40 ms in bash 5 at 270 events).
- Smoke and violation tests by hand (hook-rollout.md): every fixture piped in
  from a temp dir outside git (`.scratch/session-h2parser/smoke.sh`): exit 0,
  stdout parsed by `python3 -c 'import json,sys; json.load(sys.stdin)'`.
  Bash and Agent payloads: silent, exit 0. Enforce copy: exit 2 on a gap,
  stderr only.
- `bash -n shared/hooks/workflow-delegation-guard.sh`: clean.

## Not run

- Linux and Windows Git Bash (CI steps come in phase 2).
- The 2 s time guard firing (no input found that reaches it; nesting and
  budget guards fire first).
- check-pre-commit.sh / check-pre-push.sh (phase 2, step 6).

## Contract notes (for the PR's "Contract change" section)

- Enforce also exits 2 when the fallback whole-script score has a gap (the
  spec names "any resolved prompt"); the fallback is the PR #122 behaviour, so
  it blocks the same way.
- Unresolved prompts never block in enforce and get no guidance.
- The worst-prompt list shows scored prompts with gaps (lowest first), then
  unresolved ones, 5 at most, then `... and N more`.
- A summary line is printed even at 8/8 (the Agent guard prints the reminder
  alone).
- Telemetry is written by the perl checker (same file, same line shape, src
  `wdg`), not by a bash function, for speed.
- A constant defined twice keeps its first string definition.

## Slip, corrected

My first Write of this file went to the main checkout
(/Users/new-jose/repos/aitools/.aitools/channel/handoffs/.../S3-Hook2/) instead
of the worktree. I removed that file and the empty directory it created within
a minute; nothing else in the main checkout was touched.

## Open questions

- None blocking. Suggested follow-up: resolve `agent(r.prompt)` where `r`
  iterates a const array of object literals with `prompt:` templates
  (workflow-001's READERS pattern); today those are unresolved.
