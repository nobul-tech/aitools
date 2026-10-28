# S3-Hook2-Db handback (v1.0, 2026-10-28)

**Intent**: **Purpose**: Report mission HOOK2-DB (normalise harness-db's delegation scores by each event's total) to S3-Hook2 and the commander. **Scope**: what changed, the scale chosen, consumers, verification, findings, open questions. NOT the hooks (S3-Hook2-Parser, S3-Hook2-Audit). **Audience**: S3-Hook2, Jose.

## Summary

- `delegation.avgScore` / `delegation.minScore` are now fractions 0..1 (score / total per event); `delegation.count` = scored events.
- `"checked": 0` events and malformed score/total values are skipped and logged by reason to `harness-db.log`.
- An event without a `total` key counts as / 6 (evidence below).
- New stdlib test (11 cases) runs in CI on macOS, Linux and Windows.
- PR: https://github.com/nobul-tech/aitools/pull/133 (branch `fix/hook2-delegation-score`, commit 5c0055d plus this handback).

## Commander decision

2026-10-28, item 12 ("normalise harness-db's `delegation.avgScore` by `d.total`"): "12) yes" (quoted in the delegation prompt).

## Scale: fraction 0..1

Chosen over "rescaled to 8" because the element count has changed twice (6 -> 7 on 2026-10-04/05, 7 -> 8 with PR #122) and may change again; a fraction stays comparable without another rescale, and it is what "normalise by `d.total`" means literally. Rescaling to 8 would need re-basing at the next element.

## Default for a missing total: 6

- `git log -p -S total -- shared/hooks/delegation-duty-guard.sh`: only ced624b (2026-10-04, PR #47) adds `total`, in the same commit that moves the hook from 6 to 7 elements (`if [ "$score" -lt 6 ]` -> `DUTY_TOTAL=7`); before it the event was `{"score":$score,"missing":"$missing"}`.
- `deploy/setup-user-hooks.sh:5350` and `.ps1:4168` (frozen MDM deploy) still embed the 6-element hook (comment `/ 6`, no `total`).
- `harvesting/2026-10-21_session-360aa8f3-8_events.jsonl:91` etc.: events from 2026-10-21 with `{"score":5,"missing":"access"}` and no `total`, i.e. a 6-element hook was still deployed after the 7-element source merged.
- A present but unusable `total` (0, negative, string, null, NaN/inf) skips the event instead of defaulting.

## Files changed

- `scripts/harness-db.py`: `DELEGATION_DEFAULT_TOTAL`, `_as_number()`, `delegation_score_metrics()`; `process_session_events` step 5 calls it.
- `tests/harness-db/test-delegation-score.py` (new, mode 755).
- `.github/workflows/check.yml`: one step per job.
- `registries/tool-ops.json` (protected, review-after): `meta.lastUpdated` 2026-10-22 -> 2026-10-28; `delegationDutyScore` source and unit (old -> new in the PR body "Review after").
- This file.

## Consumers (`git grep -n -E "avgScore|minScore"`)

| Consumer | Reads now |
|---|---|
| `scripts/harness-db.py` `process_session_events` -> `kpi_events` | fractions 0..1 |
| `scripts/harness-db.py` `ship_to_datadog` -> `aitools.delegation.avgScore` / `.minScore` gauges | fractions from the merge on; older points raw. Datadog dashboards/monitors are not in the repo: unknown |
| `scripts/harness-db.py` `cmd_process_events` print | fractions, 2 decimals |
| `scripts/generate-dashboard.py` | does not read these metrics (no grep match) |
| `rfcs/0002-mission-control-architecture.md:472`, `rfcs/0002-v2-...:524`, `rfcs/0005-session-intelligence-architecture.md:207`, `rfcs/0005-v2-...:130`, `rfcs/0006-delegation-architecture.md:53,257`, `rfcs/rfc-0004-v3-harness-architecture.md:572` | describe "0-6" raw scores: stale, not changed (out of scope) |
| `.aitools/channel/8236ca9c-full-session.md`, `harvesting/*` | historical raw values, unchanged |

## Verification

- `python3 tests/harness-db/test-delegation-score.py`: 11 OK (macOS, Python 3.14.8).
- `python3 -m py_compile` on both Python files: OK. `python3 -m json.tool registries/tool-ops.json`: OK.
- `check-pre-commit.sh`: 10 PASS, 8 SKIP, 3 WARN, 1 FAIL (step 6, known pre-existing). Log: `.scratch/session-h2db/pre-commit.txt`.
- `check-pre-push.sh`: 6 PASS, 3 WARN, 1 FAIL (step 7, dotprofile deploy/ stale, known pre-existing). Log: `.scratch/session-h2db/pre-push.txt`.
- CI on PR #133 (commit 5c0055d): macos pass (16m28s), linux pass (7m52s), windows pass (4m7s), CodeQL pass. Windows log: "harness-db delegation score tests (Python, native)": `Ran 11 tests ... OK`, python 3.12.10 (run 40726622764).

## Not run

Windows/Linux locally; build-deploy, aitools, deploy-harness (never against the real HOME); RELEASE_NOTES.md (out of scope).

## Findings

- INCIDENT: on main, `shared/hooks/delegation-duty-guard.sh:207` emits the `delegation` event only inside the "elements missing" branch, so complete delegations are never recorded: `delegation.avgScore` and `session.subagentCount` describe incomplete delegations only. PR #122 emits on every call. Suggested: no separate fix if #122 merges.
- INCIDENT: frozen `deploy/setup-user-hooks.sh/.ps1` embed the 6-element hook, and harvested events show it was still the deployed hook on 2026-10-21. Suggested: covered by the dotprofile `deploy/` rebuild (pre-push step 7).

## Conflicts

- PR #122 edits the same `tool-ops.json` lines (`lastUpdated`, the KPI unit). Whichever merges second conflicts; resolution: keep this PR's unit text (harness-db now reports fractions) and the later date.
- No CONFLICT: lines (no prompt/skill/rule conflict). tool-ops skill "present for review" was overridden by the prompt's quoted D-DEL5 review-after (commander, 2026-10-26).

## Open questions

1. Workflow double count: PR #122 emits one `tool:"Workflow"` event per Workflow call (whole script) and S3-Hook2-Parser's guard will emit one `scope:"agent"` event per `agent()` prompt. Suggested answer: once the per-agent guard ships, exclude `tool:"Workflow"` events without `scope` from the score metrics (one line in `delegation_score_metrics`), in that mission's PR.
2. Datadog gauge history changes scale at the merge. Suggested answer: annotate the dashboard on merge day; no metric rename (the commander asked to normalise, not rename).
