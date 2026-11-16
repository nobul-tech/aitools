# Implementation plan: structured running estimates, mission briefs and AARs

**Intent**: **Purpose**: Sequence the implementation of RFC 0011 into small
batches of two or three files, each with its verification, so the
implementing mission can ship it work package by work package and the
commander can see where it stands. **Scope**: The sources of truth, the
gates before the work starts, the work packages WP-1 to WP-6 and their
batches, how each batch is verified and shipped, risks and their fallbacks,
and the status table. NOT the specification (RFC 0011, normative). NOT the
decisions (issue #180 section 1). NOT the implementing mission's brief
(`874d-2-structured-reports-brief.json`). **Audience**: The implementing
mission (874d-2-structured-reports) and its delegates; the commander,
tracking progress.

v1.0 (2026-11-16), session dbd05b0c.
v1.1 (2026-11-16), session dbd05b0c: the plan findings of the four
verifiers (missions 874d-3 to 874d-6) and the commander's answers
D874d-54 to D874d-70. WP-0 is done: RFC 0011 v1.2 and this plan are on
main (D874d-59, D874d-69), with no separate verdict (D874d-68).

## Sources of truth

| Rank | What | Where |
|---|---|---|
| 1 | The commander's decisions, newest first | Issue nobul-tech/aitools#180, section 1 (`D874d-<n>`), and the session transcripts they quote |
| 2 | The mission brief and the delegation prompt | `<session scratch dir of dbd05b0c>/874d-2-structured-reports-brief.json`; the prompt that launches the mission |
| 3 | The specification | `rfcs/RFC-0011-structured-reports.md` (normative; its section 4 points are review-after) |
| 4 | This plan | `plans/structured-reports/implementation-plan.md` (sequencing only) |

When two disagree, D-DEL6 decides: the commander's words first, then the
brief and the prompt, then harness documents such as RFC 0011 and this
plan. A disagreement between the brief and RFC 0011 is a defect in one of
them: record it in the AAR as an ambiguity, and raise an RFI with a
suggested answer.

## Gates

| Gate | Condition | State |
|---|---|---|
| G0 | The commander orders the implementing mission launched (D874d-45: "21) no" for now) | open |
| G1 | The six working-copy files of session dbd05b0c are on `origin/main`: `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md`, the glossary's two files (through `/glossary`: its definitions and `.claude/rules/glossary.md`), `reference/framework-intelligence-types.md`, `ROADMAP.md`. The commander takes care of them (R874d-27) | open |

WP-1 starts on G0. WP-2 starts when G1 is met. If G1 is still open when
WP-1 is done, raise an RFI, and do not edit `origin/main`'s versions of
the six files while the main checkout holds different ones. WP-3 to WP-6
follow in order. Gate G2 of v1.0, an independent verdict on the RFC, is
dropped (D874d-68).

## How every batch is shipped (D-DEL4)

- **Worktree and branches.** One worktree made with `git worktree add` off `origin/main`: `<aitools>/.scratch/worktrees/874d-2-structured-reports`. One branch and one PR per work package, each based on `main` and named `feature/874d-2-structured-reports-wp<n>` (`/delegate`: `<type>/<mission name>`). A later work package's branch merges the earlier one in with `--no-ff`; a PR is never based on another PR's branch.
- **Merging and hand-back.** The mission does not merge; the commander merges the PRs, in order (D-DEL5: a merge needs his order). The mission hands back its AAR when every work package's PR is open with CI green, or at once when a blocker stops it (D-DEL9).
- **Orchestration.** The mission may run each batch through a delegate of its own. It writes that delegate's brief by RFC 0011 3.3, in the session scratch directory of dbd05b0c, with the batch's files as `read in full` artifacts, and it verifies each batch before the next.
- **Commits.** Commit and push after every batch, with `git commit -F` from the scratch directory.
- **Status table.** After each batch, update the status table of this plan in the work package's branch, so it ships in that PR (D874d-60). Nothing is pushed to `main`, so `.aitools/channel/relay.md`, a direct-to-main file, is not written.
- **Checks before every push.** `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` on macOS or Linux; `pwsh -NoProfile -File scripts/check-pre-commit.ps1` and `pwsh -NoProfile -File scripts/check-pre-push.ps1` on Windows.
- **CI.** Every new test suite gets a step in each job of `.github/workflows/check.yml` that runs it (a Python suite: all three jobs, `python3` on Linux and macOS, `python` on Windows). Watch CI until it passes on all three.
- **Review.** An independent reviewer (a separate delegate that did not see the author's notes) posts its verdict as a PR comment before the PR goes to the commander.
- **Never:**
  - push to `main`, force-push, or merge or approve your own PR;
  - run `aitools`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real `HOME`;
  - open a live session DB or the harness DB with a branch's `harness-db.py`: tests and probes use throwaway copies (RFC 0011 3.6.12);
  - push to the real dotprofile: tests use a clone whose `origin` is a local bare repo.
- **Hooks.** A new or widened hook check starts in observe mode and passes the pre-deploy checks of `.claude/rules/hook-rollout.md` (syntax, smoke, violation).

## WP-0: RFC and plan (done)

RFC 0011 v1.2 and this plan v1.1 are on main (D874d-59, D874d-69). The
findings of the four verifiers (missions 874d-3 to 874d-6) are applied; no
separate verdict is kept (D874d-68).

## WP-1: reference, schemas, templates, validation

RFC 0011 sections 3.1 to 3.4, 3.7 and 3.8.

| Batch | Files | Verify |
|---|---|---|
| 1.1 | `reference/schemas/mission-brief.schema.json`, `reference/schemas/aar.schema.json` | Both parse (`python3 -m json.tool`). Each node and field is checked against RFC 0011 3.2, 3.3 and 3.4 line by line: the brief's ten nodes (3.3.2), `artifacts[]` (3.3.3a), deliverables (3.2.6), plain entries against items (3.2.1a). Forbidden nodes are rejected (`additionalProperties: false`), among them, in a brief, `rules`, `skills`, `ambiguities`, `access`, `name_prefix`, `duties` and `return` |
| 1.2 | `reference/schemas/running-estimate.schema.json`, `reference/templates/mission-brief.json` | The schema parses and is checked against RFC 0011 3.5; the template is an empty instance of the brief schema |
| 1.3 | `reference/templates/aar.json`, `reference/templates/running-estimate.json` | Each is an empty instance of its schema |
| 1.4 | `scripts/harness-db.py` (`validate --kind brief\|aar\|estimate <file>`, RFC 0011 3.7.2), `tests/harness-db/test-validate.py`, `.github/workflows/check.yml` (a step for the suite in each of the three jobs) | The templates and one full example of each document validate. One negative case per rule fails: a missing required node; a forbidden node; a bad enum; a commander source with no quote; an objective not accomplished that cites no deviation; a malformed id; a timestamp without Z; an item in a plain node; a relative artifact path; a brief with no AAR deliverable. The suite passes in CI on macOS, Linux and Windows |
| 1.5 | `reference/structured-reports.md` (intent statement; naming, schema, store and write rules, pointing to RFC 0011), `reference/README.md` (index row) | `/intent-audit` passes on the reference |

## WP-2: the harness text, in line with RFC 0011 (D874d-49)

First, check G1.

| Batch | Files | Verify |
|---|---|---|
| 2.1 | `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md` | D-DEL10: the brief is `<session scratch dir>/<mission name>-brief.json` (D874d-42), with `artifacts[]` and `deliverables[]` (D874d-65, D874d-70). D-DEL11: the AAR is the hand-back, JSON in the last fenced block (D874d-50), a file only when its deliverable names one (D874d-47). `/delegate` "Mission brief file": the ten nodes; what goes in `artifacts[]` (RFC 0011 3.3.3a); what the prompt carries instead (the scratch directory, the writable paths, the sources that are not files, the name prefix: 3.3.5); standing duties in the skill only (D874d-64); the fallback for isolated delegates (3.3.8). Also element 10, the prompt skeleton, "Final response shape", and one permission signal, `WRITE_BLOCKED` (a `PERMISSION_DENIED` remains in the skill). Each file is read back against RFC 0011 3.3, 3.4 and 3.9 |
| 2.2 | The glossary (through `/glossary`: its definitions and `.claude/rules/glossary.md`) | `mission brief`: a JSON file `<mission name>-brief.json` with the nodes of RFC 0011 3.3.2. `after action review`: the hand-back is JSON, a file only on request. `artifact`: widened as RFC 0011 section 2 defines it (D874d-67). `session RFI`: `R<sid4>-<n>`. No entries for the schema's nodes and fields (D874d-66). The word list matches the definitions |
| 2.3 | `shared/rules/prompt-turn.md`, `reference/prompt-turn-checklist.md` | Item 5.1: `R<sid4>-<n>` for session RFIs and `D<sid4>-<n>` for decisions (D874d-41). Item 12: once schema 5 ships, the session agent updates intent, main effort, assessment and the session's objectives (RFC 0011 3.5.3). Both files say the same (the rule condenses the reference) |
| 2.4 | `reference/framework-intelligence-types.md` (v1.3: the types of RFC 0011 3.2, with objective, deviation and ambiguity added, finding retired, fact kept; a pointer to `reference/structured-reports.md`), `ROADMAP.md` (an In Progress row for issue #180, linked to this plan; in the Distributed-sessions row, D-SR10 and D-SR9 become D874d-10 and D874d-9) | Read back |
| 2.5 | `.claude/rules/aitools-workspace.md` (the running estimate's record is tracked in the dotprofile's `running-estimates/`; `channel/estimates/` is untracked; the `channel/running-estimate.json` row is retired: D874d-52, D874d-61), `rfcs/0010-python-sqlite-engineering.md` (a note at sections 5 and 7: superseded by RFC 0011 3.6.8) | Read back against RFC 0011 3.5.5 and section 7 |

WP-2 is done when no harness file names `<sid4>_<mission name>-brief.md`, a
Markdown brief, a default AAR file, the brief nodes `rules[]` or
`skills[]`, `RFI <sid4>-<n>`, `D-<sid4>-<n>`, a `D-SR<n>` id or
`PERMISSION_DENIED`. Check with
`grep -rnE 'D-SR[0-9]|RFI [0-9a-f]{4}-|D-[0-9a-f]{4}-|PERMISSION_DENIED|brief\.md|rules\[\]|skills\[\]'`
over `shared/`, `.claude/`, `reference/`, `ROADMAP.md` and the glossary's
data (located through `/glossary`).

## WP-3: session DB, schema 5 (RFC 0011 section 3.6)

| Batch | Files | Verify |
|---|---|---|
| 3.0 | `scripts/harness-db.py` (schema 4: check the DB's schema version before `migrate_v4`, and leave a newer DB untouched), `tests/harness-db/test-schema.py` | A v4 helper opened on a throwaway v5-shaped DB changes nothing and exits 1 (a hook exits 0). It ships first, so every deployed v4 helper refuses a v5 DB (RFC 0011 3.6.12) |
| 3.1 | `scripts/harness-db.py` (schema 5: `items` keyed by (`id`, `version`); `refs`; the `session` columns `intent`, `main_effort`, `assessment`; the views `observations`, `decisions` and `deviations` with the v4 columns; the migration of RFC 0011 3.6.7; the version check first), `reference/harness-db-schema.sql` (generated) | The `.sql` matches the generated output (`tests/harness-db/test-schema.py`) |
| 3.2 | `scripts/harness-db.py` (CLI: `--db`, `--agent-id`, `--mission`, with `agent_type` derived and no flag for it; `item add\|update\|list`; `estimate set`; `aar --agent-id`; the per-session `export`; the verbs of RFC 0011 3.6.10; the lock retry for agents and none for hooks; `ensure_schema` at session start only; the prefix check of 3.6.2) | Each verb's `--help`, and smoke runs on a throwaway DB: `item add` then `item list`, `estimate set`, `aar --agent-id`, `export`; a locked DB prints the retry message; a prefix mismatch uses the full-id DB |
| 3.3 | `tests/harness-db/test-schema.py` (v5, with a v4 fixture), `tests/harness-db/test-concurrency.py` (new: parallel writers, ASM-2; the prefix collision, ASM-6), `.github/workflows/check.yml` (the new suite in all three jobs) | All harness-db suites pass on macOS, Linux and Windows. Every v4 column value of a fixture row is found in its v5 row or its `fields`. The migration runs on copies of the live DBs (sqlite3 backup API, as in PR #181) with no row lost |
| 3.4 | `shared/hooks/harness-db-sessionend.sh` (`--db`; the export goes to `.aitools/channel/estimates/<prefix>.json`, and no longer to `channel/running-estimate.json`), `shared/hooks/harness-db-sessionstart.sh` (adds `.aitools/` and `.scratch/` to `.git/info/exclude` where nothing ignores them, reported once per repo: D874d-58), `.gitignore` (`.aitools/channel/estimates/`) | The hook checks of `.claude/rules/hook-rollout.md` (syntax, smoke, violation); `tests/hooks/` pass; the exclude case in a temporary repo |
| 3.5 | `shared/hooks/intelligence-stop.py` (reads the v5 views; its silent `except` blocks log), its test in `tests/hooks/` | A v5 decision and deviation appear in its output; a DB error is logged, not swallowed |
| 3.6 | Probes, no file changes, on throwaway DB copies only: ASM-1 (a background and a foreground delegate each find their own agentId by the `.meta.json`, a `TaskStop` error and the parent transcript; record when the `.meta.json` appears); ASM-3 (a delegate in a worktree made with `git worktree add`, and one under the Agent tool's isolation, each write a DB copy in the main checkout); ASM-4 (a level-2 delegating agent writes a brief into the top-level session's scratch directory) | Results in the PR body. A probe that fails puts its fallback (RFC 0011 3.3.8, 3.4.8, 3.4.9) into `/delegate` in a follow-up batch of WP-2 |

## WP-4: hooks, the SessionEnd job, the harvester (RFC 0011 3.4, 3.5.5, 3.9.3, section 7)

| Batch | Files | Verify |
|---|---|---|
| 4.1 | `shared/hooks/delegation-duty-guard.sh`, `shared/hooks/workflow-delegation-guard.sh` (their shared element block): element 10 is scored by a brief path and an instruction to read the brief in full (RFC 0011 3.9.3) | Observe mode. The syntax, smoke, violation and parity tests in `tests/hooks/` pass |
| 4.2a | A probe first: which event sees a background delegate's final hand-back (`SubagentStop`; `PostToolUse` on `Agent` sees only the launch)? Then the AAR check hook (`shared/hooks/aar-check.sh`, or a named existing hook), validating the last fenced JSON block with `harness-db.py validate --kind aar`, and `shared/hooks/hooks-manifest.json` | Observe mode; the syntax, smoke and violation tests |
| 4.2b | `.claude/rules/hook-rollout.md` and `.cursor/rules/hook-rollout.mdc` (a state row), the hook's tests in `tests/hooks/` | The manifest's parity check passes; `tests/hooks/` pass |
| 4.3 | `shared/hooks/harness-db-sessionend.sh` (starts one detached job: export, copy, commit, push; RFC 0011 3.5.5), `scripts/ait-harvest.py` (the copy to `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json`; one lock shared with `archive`; pull with rebase before the push; push only from `main`) | Under an isolated `HOME`, with a clone of the dotprofile whose `origin` is a local bare repo (checked before any push: the URL does not contain `github.com`): the copy lands at the right path, dated by the session's start, and is committed and pushed to the bare repo; two archive jobs and one copy started together all commit; a remote one commit ahead is pulled and the push succeeds; the hook returns well within 1.5 seconds. On Windows 11, the detached job finishes after Claude Code exits (`ait-harvest.log`) |
| 4.4 | `shared/hooks/session-catchup.sh` (recovers a missing export, copy, commit or push, and reports a failed step in the SessionStart output), its test | A cut-off job is completed at the next start, and a failed step is reported |
| 4.5 | `scripts/ait-harvest.py` (`_is_ephemeral`: `*-brief.json`, `*-aar.json`, `*.tmp`; RFC 0011 S-14), its test | A brief, an AAR file and a `.tmp` file in a session scratch directory are not copied to `harvesting/` |

## WP-5: the skills and readers that use the documents (D874d-61)

| Batch | Files | Verify |
|---|---|---|
| 5.1 | `shared/skills/handoff/SKILL.md` (carries the running estimate), `shared/skills/aitool-continue/SKILL.md` (loads the project's last record from the dotprofile's `running-estimates/`) | Read back against RFC 0011 3.5 |
| 5.2 | `shared/skills/mission-control/SKILL.md` (reads `missions[]`); `git rm` of `.aitools/channel/running-estimate.json` and `.aitools/templates/mission-running-estimate.json` | Read back |
| 5.3 | `scripts/generate-dashboard.py`, `shared/hooks/dashboard-serve.sh` (read the per-session export) | The dashboard renders from a sample export |
| 5.4 | `scripts/aitools-dashboard.sh`, `scripts/aitools-dashboard.ps1` (read the per-session export), `reference/artifact-harvesting.md` | `git grep -n -e running-estimate.json -e mission-running-estimate -- scripts shared .claude reference` finds no live reference; the history in `RELEASE_NOTES.md`, `rfcs/` and `plans/` is kept |

## WP-6: release

| Batch | Files | Verify |
|---|---|---|
| 6.1 | `RELEASE_NOTES.md` (one version entry per merged PR, or one for the set), `ROADMAP.md` (the row to Completed) | The PR body lists every change old -> new under "Review after" (D-DEL5). The glossary check: every governed term the new files use is in the word list |
| 6.2 | `reference/framework-mission-command.md` (a pointer to the adopted doctrine: the AAR from TC 7-0.1, the running estimate from FM 5-0 and ADP 5-0), the framework registry (through `/frameworks`) | Read back |

## Risks and fallbacks

| Risk | Fallback | Source |
|---|---|---|
| A delegate cannot find its own agentId (ASM-1) | The delegating agent fills it from the agentId the launch returned | RFC 0011 3.4.9 |
| A delegate confined to its worktree cannot write the session DB (ASM-3) or a deeper brief (ASM-4) | Prefer `git worktree add`; else the AAR alone, recorded by the delegating agent, and the brief in its own scratch | RFC 0011 3.3.8, 3.4.8 |
| Lock contention (ASM-2) | Agents retry three times, then record a blocker; hooks do not retry | RFC 0011 3.6.6 |
| Version skew: a v4 helper meets a v5 DB, or a deploy skips one of the pair | Batch 3.0 first; the migration only through the deployed v5 pair; a skipped helper or hook is a WARN | RFC 0011 3.6.12 |
| The SessionEnd window (1.5 seconds), or git contention in the dotprofile | One detached job, with a lock and a rebase; catch-up completes it and reports a failure | RFC 0011 3.5.5 |
| A test pushes to the real dotprofile | A clone whose `origin` is a local bare repo, checked before every push | Batch 4.3 |
| A harvested brief or AAR reaches `harvesting/` before batch 4.5 ships | Do not commit `harvesting/*-brief.json` or `harvesting/*-aar.json`; nothing is done about the files already published (D874d-54) | RFC 0011 section 7 |
| The migration loses data | Forward-only; every v4 column checked against v5 (batch 3.3); tested on copies of the live DBs | RFC 0011 3.6.7 |

## Status

| WP | Batch | State | PR | Notes |
|---|---|---|---|---|
| WP-0 | RFC 0011, this plan | done | | On main: commit 419d32dd (RFC v1.1, plan v1.0) and the commit that adds RFC v1.2 and plan v1.1. Verifiers 874d-3 to 874d-6 |
| WP-1 | 1.1 to 1.5 | not started | | Waits for G0 |
| WP-2 | 2.1 to 2.5 | not started | | Waits for G1 |
| WP-3 | 3.0 to 3.6 | not started | | |
| WP-4 | 4.1 to 4.5 | not started | | |
| WP-5 | 5.1 to 5.4 | not started | | |
| WP-6 | 6.1, 6.2 | not started | | |
