# Implementation plan: structured running estimates, mission briefs and AARs

**Intent**: **Purpose**: Sequence the implementation of RFC 0011 into
specified tasks, each shipped as one PR, and each specified task into small
batches of two or three files, each with its verification, so the
implementing mission can ship it specified task by specified task and the
commander can see where it stands. **Scope**: The sources of truth, the
specified tasks and their ids, the gates before the work starts, the
specified tasks ST874d-1 to ST874d-6 and their batches, how each batch is
verified and shipped, risks and their fallbacks, and the status table. NOT
the specification (RFC 0011, normative). NOT the decisions (issue #180
section 1; RFC 0011 appendix A). NOT the implementing mission's brief
(`874d-2-structured-reports-brief.json`). **Audience**: The implementing
mission (874d-2-structured-reports), whoever carries it out, and its
delegates; the commander, tracking progress.

v1.0 (2026-11-16), session dbd05b0c.
v1.1 (2026-11-16), session dbd05b0c: the plan findings of the four
verifiers (missions 874d-3 to 874d-6) and the commander's answers
D874d-54 to D874d-70. WP-0 is done: RFC 0011 v1.2 and this plan are on
main (D874d-59, D874d-69), with no separate verdict (D874d-68).
v1.2 (2026-11-16), session dbd05b0c: the implementing mission's brief
resides in the briefs directory, `briefs/874d-2-structured-reports-brief.json`
(D874d-71 to D874d-74); the briefs of batch delegates remain in the
session scratch directory; batch 4.1 scores the elements a brief carries.
v1.3 (2026-11-16), session dbd05b0c: RFC 0011 v1.5 (the language review
of missions 874d-7, 874d-9 and 874d-11): batch 3.4b removes the hooks' fallbacks to
repo copies of `harness-db.py`; the exclude rule covers linked worktrees.
v1.4 (2026-11-16), session 86d6da03: the work packages WP-1 to WP-6 are
specified tasks ST874d-1 to ST874d-6 (D0036-3, RFC 0011 v1.6); batch ids
are `<specified task id>.<m>`; branches, PR titles and commit subjects
carry the ids; the order of the specified tasks is stated on its own, since
an id implies none; gate G1 is met (commit 311ad1ff); a later session may
carry the mission out from the same brief (D0036-2).

## Sources of truth

| Rank | What | Where |
|---|---|---|
| 1 | The commander's decisions, newest first | Issue nobul-tech/aitools#180, section 1 (`D874d-<n>`); the decisions of session 86d6da03 (`D0036-<n>`, RFC 0011 appendix A); and the session transcripts they quote |
| 2 | The mission brief and the delegation prompt | `briefs/874d-2-structured-reports-brief.json`, a long-lifecycle brief placed in the briefs directory on the commander's order (RFC 0011 3.3.1, D874d-71); the prompt that launches the mission, if a delegate carries it out |
| 3 | The specification | `rfcs/RFC-0011-structured-reports.md` (normative; its section 4 points are review-after) |
| 4 | This plan | `plans/structured-reports/implementation-plan.md` (sequencing only) |

When two disagree, D-DEL6 decides: the commander's words first, then the
brief and the prompt, then harness documents such as RFC 0011 and this
plan. A disagreement between the brief and RFC 0011 is a defect in one of
them: record it in the AAR as an ambiguity, and raise an RFI with a
suggested answer.

## Specified tasks and their ids

The work is split into specified tasks (RFC 0011 section 2; D0036-3). They
were created in session dbd05b0c, so their ids are `ST874d-<n>`; the ids
do not change when another session carries them out. A batch of a
specified task is `<specified task id>.<m>` (RFC 0011 3.8). An id is not an
order: the order is in "Gates" below. The brief records each specified task
as one objective:

| Specified task | Objective in the brief | What |
|---|---|---|
| ST874d-1 | OBJ-2 | Reference, schemas, templates, validation |
| ST874d-2 | OBJ-3 | The harness text, in line with RFC 0011 |
| ST874d-3 | OBJ-4 | Session DB, schema 5 |
| ST874d-4 | OBJ-5 | Hooks, the SessionEnd job, the harvester |
| ST874d-5 | OBJ-6 | The skills and readers that use the documents |
| ST874d-6 | OBJ-7 | Release |

OBJ-1, the commander's objective ("implement structured running estimates,
briefings, aars"), is served by all six.

## Gates

| Gate | Condition | State |
|---|---|---|
| G0 | The commander orders the implementing mission launched (D874d-45: "21) no" for now; D0036-1: "dont launch the missin yet.") | open |
| G1 | The six working-copy files of session dbd05b0c are on `origin/main`: `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md`, the glossary's two files (through `/glossary`: its definitions and `.claude/rules/glossary.md`), `reference/framework-intelligence-types.md`, `ROADMAP.md`. The commander takes care of them (R874d-27) | met: commit 311ad1ff (2026-11-16), on the commander's order (session 86d6da03, L95) |

ST874d-1 starts on G0. ST874d-2 needs G0 and G1; G1 is met. ST874d-3 to
ST874d-6 follow in order, each after the one before. Gate G2
of v1.0, an independent verdict on the RFC, is dropped (D874d-68).

## How every batch is shipped (D-DEL4)

- **Worktree and branches.** One worktree made with `git worktree add` off `origin/main`: `<aitools>/.scratch/worktrees/874d-2-structured-reports`. One branch and one PR per specified task, each based on `main` and named `feature/874d-2-structured-reports-<specified task id in lowercase>`, for example `feature/874d-2-structured-reports-st874d-1` (`/delegate`: `<type>/<mission name>`, then the specified task's id). A later specified task's branch merges the earlier one in with `--no-ff`; a PR is never based on another PR's branch.
- **Ids in titles and commits.** Each PR's title starts with its specified task's id (`ST874d-1: reference, schemas, templates, validation`), and each commit subject with its batch id (`ST874d-1.1: ...`), so a PR, a commit and a status row can be traced to one another.
- **Merging and hand-back.** The mission does not merge; the commander merges the PRs, in order (D-DEL5: a merge needs his order). The mission hands back its AAR when every specified task's PR is open with CI green, or at once when a blocker stops it (D-DEL9).
- **Orchestration.** Whoever carries the mission out, a delegate or the session agent of a later session (D0036-2), may run each batch through a delegate of its own. It writes that delegate's brief by RFC 0011 3.3, in the top-level session's scratch directory (the default location, RFC 0011 3.3.1), with the batch's files as `read in full` artifacts, and it verifies each batch before the next.
- **Commits.** Commit and push after every batch, with `git commit -F` from the scratch directory.
- **Status table.** After each batch, update the status table of this plan in the specified task's branch, so it ships in that PR (D874d-60). Nothing is pushed to `main`, so `.aitools/channel/relay.md`, a direct-to-main file, is not written.
- **Checks before every push.** `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` on macOS or Linux; `pwsh -NoProfile -File scripts/check-pre-commit.ps1` and `pwsh -NoProfile -File scripts/check-pre-push.ps1` on Windows.
- **CI.** Every new test suite gets a step in each job of `.github/workflows/check.yml` that runs it (a Python suite: all three jobs, `python3` on Linux and macOS, `python` on Windows). Watch CI until it passes on all three.
- **Review.** An independent reviewer (a separate delegate that did not see the author's notes) posts its verdict as a PR comment before the PR goes to the commander.
- **Never:**
  - push to `main`, force-push, or merge or approve your own PR;
  - run `aitools`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real `HOME`;
  - open a live session DB or the harness DB with a branch's `harness-db.py`: tests and probes use throwaway copies (RFC 0011 3.6.12);
  - push to the real dotprofile: tests use a clone whose `origin` is a local bare repo.
- **Hooks.** A new or widened hook check starts in observe mode and passes the pre-deploy checks of `.claude/rules/hook-rollout.md` (syntax, smoke, violation).

## The RFC and the plan (done)

RFC 0011 and this plan are on main (D874d-59, D874d-69). The findings of
the four verifiers (missions 874d-3 to 874d-6) are applied; no separate
verdict is kept (D874d-68). This work, called WP-0 until v1.3, was done
before the specified tasks were named and has no specified task id.

## ST874d-1: reference, schemas, templates, validation

RFC 0011 sections 3.1 to 3.4, 3.7 and 3.8.

| Batch | Files | Verify |
|---|---|---|
| ST874d-1.1 | `reference/schemas/mission-brief.schema.json`, `reference/schemas/aar.schema.json` | Both parse (`python3 -m json.tool`). Each node and field is checked against RFC 0011 3.2, 3.3 and 3.4 line by line: the brief's ten nodes (3.3.2), `artifacts[]` (3.3.3a), deliverables (3.2.6), plain entries against items (3.2.1a). Forbidden nodes are rejected (`additionalProperties: false`), among them, in a brief, `rules`, `skills`, `ambiguities`, `access`, `name_prefix`, `duties` and `return` |
| ST874d-1.2 | `reference/schemas/running-estimate.schema.json`, `reference/templates/mission-brief.json` | The schema parses and is checked against RFC 0011 3.5; the template is an empty instance of the brief schema |
| ST874d-1.3 | `reference/templates/aar.json`, `reference/templates/running-estimate.json` | Each is an empty instance of its schema |
| ST874d-1.4 | `scripts/harness-db.py` (`validate --kind brief\|aar\|estimate <file>`, RFC 0011 3.7.2), `tests/harness-db/test-validate.py`, `.github/workflows/check.yml` (a step for the suite in each of the three jobs) | The templates and one full example of each document validate. One negative case per rule fails: a missing required node; a forbidden node; a bad enum; a commander source with no quote; an objective not accomplished that cites no deviation; a malformed id; a timestamp without Z; an item in a plain node; a relative artifact path; a brief with no AAR deliverable. The suite passes in CI on macOS, Linux and Windows |
| ST874d-1.5 | `reference/structured-reports.md` (intent statement; naming, schema, store and write rules, the specified task's id among the names, pointing to RFC 0011), `reference/README.md` (index row) | `/intent-audit` passes on the reference |

## ST874d-2: the harness text, in line with RFC 0011 (D874d-49)

Gate G1 is met (commit 311ad1ff).

| Batch | Files | Verify |
|---|---|---|
| ST874d-2.1 | `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md` | D-DEL10: the brief is `<session scratch dir>/<mission name>-brief.json` (D874d-42), with `artifacts[]` and `deliverables[]` (D874d-65, D874d-70). D-DEL11: the AAR is the hand-back, JSON in the last fenced block (D874d-50), a file only when its deliverable names one (D874d-47). `/delegate` "Mission brief file": the ten nodes; what goes in `artifacts[]` (RFC 0011 3.3.3a); what the prompt carries instead (the scratch directory, the writable paths, the sources that are not files, the name prefix: 3.3.5); standing duties in the skill only (D874d-64); the fallback for isolated delegates (3.3.8). Also element 10, the prompt skeleton, "Final response shape", and one permission signal, `WRITE_BLOCKED` (a `PERMISSION_DENIED` remains in the skill). `/delegate` naming conventions: the specified task's id, `ST<sid4>-<n>`, and its batch ids, beside the mission name (RFC 0011 section 2 and 3.8). Each file is read back against RFC 0011 3.3, 3.4 and 3.9 |
| ST874d-2.2 | The glossary (through `/glossary`: its definitions and `.claude/rules/glossary.md`) | `mission brief`: a JSON file `<mission name>-brief.json` with the nodes of RFC 0011 3.3.2. `after action review`: the hand-back is JSON, a file only on request. `artifact`: widened as RFC 0011 section 2 defines it (D874d-67). `session RFI`: `R<sid4>-<n>`. `specified task` and `ST` are already governed (session 86d6da03, D0036-3); check that they still match RFC 0011 section 2. No entries for the schema's nodes and fields (D874d-66). The word list matches the definitions |
| ST874d-2.3 | `shared/rules/prompt-turn.md`, `reference/prompt-turn-checklist.md` | Item 5.1: `R<sid4>-<n>` for session RFIs and `D<sid4>-<n>` for decisions (D874d-41). Item 12: once schema 5 ships, the session agent updates intent, main effort, assessment and the session's objectives (RFC 0011 3.5.3). Both files say the same (the rule condenses the reference) |
| ST874d-2.4 | `reference/framework-intelligence-types.md` (v1.3: the types of RFC 0011 3.2, with objective, deviation and ambiguity added, finding retired, fact kept; a pointer to `reference/structured-reports.md`), `ROADMAP.md` (an In Progress row for issue #180, linked to this plan; in the Distributed-sessions row, D-SR10 and D-SR9 become D874d-10 and D874d-9) | Read back |
| ST874d-2.5 | `.claude/rules/aitools-workspace.md` (the running estimate's record is tracked in the dotprofile's `running-estimates/`; `channel/estimates/` is untracked; the `channel/running-estimate.json` row is retired: D874d-52, D874d-61), `rfcs/0010-python-sqlite-engineering.md` (a note at sections 5 and 7: superseded by RFC 0011 3.6.8) | Read back against RFC 0011 3.5.5 and section 7 |

ST874d-2 is done when no harness file names `<sid4>_<mission name>-brief.md`,
a Markdown brief, a default AAR file, the brief nodes `rules[]` or
`skills[]`, `RFI <sid4>-<n>`, `D-<sid4>-<n>`, a `D-SR<n>` id,
`PERMISSION_DENIED` or a `WP-<n>` id. Check with
`grep -rnE 'D-SR[0-9]|RFI [0-9a-f]{4}-|D-[0-9a-f]{4}-|PERMISSION_DENIED|brief\.md|rules\[\]|skills\[\]|WP-[0-9]'`
over `shared/`, `.claude/`, `reference/`, `ROADMAP.md` and the glossary's
data (located through `/glossary`). The words "work package" may remain
where a file records that the specified task replaced it (the glossary,
`reference/framework-mission-command.md`).

## ST874d-3: session DB, schema 5 (RFC 0011 section 3.6)

| Batch | Files | Verify |
|---|---|---|
| ST874d-3.0 | `scripts/harness-db.py` (schema 4: check the DB's schema version before `migrate_v4`, and leave a newer DB untouched), `tests/harness-db/test-schema.py` | A v4 helper opened on a throwaway v5-shaped DB changes nothing and exits 1 (a hook exits 0). It ships first, so every deployed v4 helper refuses a v5 DB (RFC 0011 3.6.12) |
| ST874d-3.1 | `scripts/harness-db.py` (schema 5: `items` keyed by (`id`, `version`); `refs`; the `session` columns `intent`, `main_effort`, `assessment`; the views `observations`, `decisions` and `deviations` with the v4 columns; the migration of RFC 0011 3.6.7; the version check first), `reference/harness-db-schema.sql` (generated) | The `.sql` matches the generated output (`tests/harness-db/test-schema.py`) |
| ST874d-3.2 | `scripts/harness-db.py` (CLI: `--db`, `--agent-id`, `--mission`, with `agent_type` derived and no flag for it; `item add\|update\|list`; `estimate set`; `aar --agent-id`; the per-session `export`, with `missions[]` derived as RFC 0011 3.5.4 says; the verbs of RFC 0011 3.6.10; the lock retry for agents and none for hooks; `ensure_schema` at session start only; the prefix check of 3.6.2) | Each verb's `--help`, and smoke runs on a throwaway DB: `item add` then `item list`, `estimate set`, `aar --agent-id`, `export`; a mission whose brief is in the briefs directory with another session's provenance gets that brief in `missions[]`; a locked DB prints the retry message; a prefix mismatch uses the full-id DB |
| ST874d-3.3 | `tests/harness-db/test-schema.py` (v5, with a v4 fixture), `tests/harness-db/test-concurrency.py` (new: parallel writers, ASM-2; the prefix collision, ASM-6), `.github/workflows/check.yml` (the new suite in all three jobs) | All harness-db suites pass on macOS, Linux and Windows. Every v4 column value of a fixture row is found in its v5 row or its `fields`. The migration runs on copies of the live DBs (sqlite3 backup API, as in PR #181) with no row lost |
| ST874d-3.4 | `shared/hooks/harness-db-sessionend.sh` (`--db`; the export goes to `.aitools/channel/estimates/<prefix>.json`, and no longer to `channel/running-estimate.json`; it resolves only `~/.aitools/bin/harness-db.py`, without the repo fallbacks: RFC 0011 3.6.12), `shared/hooks/harness-db-sessionstart.sh` (the same resolution; appends `.aitools/` and `.scratch/` to the file `git rev-parse --git-path info/exclude` names where `git check-ignore` reports them not ignored: RFC 0011 section 7, D874d-58) | The hook checks of `.claude/rules/hook-rollout.md` (syntax, smoke, violation); `tests/hooks/` pass; the exclude case in a temporary repo and in a linked worktree |
| ST874d-3.4b | `shared/hooks/scratch-init.sh` and `shared/hooks/command-channel-stop.sh` (resolve only the deployed helper: RFC 0011 3.6.12), `.gitignore` (`.aitools/channel/estimates/`: RFC 0011 3.5.5) | The hook checks of `.claude/rules/hook-rollout.md`; `tests/hooks/` pass; `grep -rn 'scripts/harness-db.py' shared/hooks/` finds no fallback |
| ST874d-3.5 | `shared/hooks/intelligence-stop.py` (reads the v5 views; its silent `except` blocks log), its test in `tests/hooks/` | A v5 decision and deviation appear in its output; a DB error is logged, not swallowed |
| ST874d-3.6 | Probes, no file changes, on throwaway DB copies only: ASM-1 (a background and a foreground delegate each find their own agentId by the `.meta.json`, a `TaskStop` error and the parent transcript; record when the `.meta.json` appears); ASM-3 (a delegate in a worktree made with `git worktree add`, and one under the Agent tool's isolation, each write a DB copy in the main checkout); ASM-4 (a level-2 delegating agent writes a brief into the top-level session's scratch directory) | Results in the PR body. A probe that fails puts its fallback (RFC 0011 3.3.8, 3.4.8, 3.4.9) into `/delegate` in a follow-up batch of ST874d-2, numbered after its last batch (ST874d-2.6) |

## ST874d-4: hooks, the SessionEnd job, the harvester (RFC 0011 3.4, 3.5.5, 3.9.3, section 7)

| Batch | Files | Verify |
|---|---|---|
| ST874d-4.1 | `shared/hooks/delegation-duty-guard.sh`, `shared/hooks/workflow-delegation-guard.sh` (their shared element block): element 10 is scored by a brief path and an instruction to read the brief in full (RFC 0011 3.9.3); when the prompt gives a brief path, elements 2 (rules and CLAUDE.md files) and 4 (operational learning) are scored from the brief's `artifacts[]` and `operational_learning[]` (observed on 2026-11-16: three launches whose briefs carried both were scored 6 of 8) | Observe mode. The syntax, smoke, violation and parity tests in `tests/hooks/` pass |
| ST874d-4.2a | A probe first: which event sees a background delegate's final hand-back (`SubagentStop`; `PostToolUse` on `Agent` sees only the launch)? Then the AAR check hook (`shared/hooks/aar-check.sh`, or a named existing hook), validating the last fenced JSON block with `harness-db.py validate --kind aar`, and `shared/hooks/hooks-manifest.json` | Observe mode; the syntax, smoke and violation tests |
| ST874d-4.2b | `.claude/rules/hook-rollout.md` and `.cursor/rules/hook-rollout.mdc` (a state row), the hook's tests in `tests/hooks/` | The manifest's parity check passes; `tests/hooks/` pass |
| ST874d-4.3 | `shared/hooks/harness-db-sessionend.sh` (starts one detached job: export, copy, commit, push; RFC 0011 3.5.5), `scripts/ait-harvest.py` (the copy to `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json`; one lock shared with `archive`; pull with rebase before the push; push only from `main`) | Under an isolated `HOME`, with a clone of the dotprofile whose `origin` is a local bare repo (checked before any push: the URL does not contain `github.com`): the copy lands at the right path, dated by the session's start, and is committed and pushed to the bare repo; two archive jobs and one copy started together all commit; a remote one commit ahead is pulled and the push succeeds; the hook returns well within 1.5 seconds. On Windows 11, the detached job finishes after Claude Code exits (`ait-harvest.log`) |
| ST874d-4.4 | `shared/hooks/session-catchup.sh` (recovers a missing export, copy, commit or push, and reports a failed step in the SessionStart output), its test | A cut-off job is completed at the next start, and a failed step is reported |
| ST874d-4.5 | `scripts/ait-harvest.py` (`_is_ephemeral`: `*-brief.json`, `*-aar.json`, `*.tmp`; RFC 0011 S-14), its test | A brief, an AAR file and a `.tmp` file in a session scratch directory are not copied to `harvesting/` |

## ST874d-5: the skills and readers that use the documents (D874d-61)

| Batch | Files | Verify |
|---|---|---|
| ST874d-5.1 | `shared/skills/handoff/SKILL.md` (carries the running estimate), `shared/skills/aitool-continue/SKILL.md` (loads the project's last record from the dotprofile's `running-estimates/`) | Read back against RFC 0011 3.5 |
| ST874d-5.2 | `shared/skills/mission-control/SKILL.md` (reads `missions[]`); `git rm` of `.aitools/channel/running-estimate.json` and `.aitools/templates/mission-running-estimate.json` | Read back |
| ST874d-5.3 | `scripts/generate-dashboard.py`, `shared/hooks/dashboard-serve.sh` (read the per-session export) | The dashboard renders from a sample export |
| ST874d-5.4 | `scripts/aitools-dashboard.sh`, `scripts/aitools-dashboard.ps1` (read the per-session export), `reference/artifact-harvesting.md` | `git grep -n -e running-estimate.json -e mission-running-estimate -- scripts shared .claude reference` finds no live reference; the history in `RELEASE_NOTES.md`, `rfcs/` and `plans/` is kept |

## ST874d-6: release

| Batch | Files | Verify |
|---|---|---|
| ST874d-6.1 | `RELEASE_NOTES.md` (one version entry per merged PR, or one for the set), `ROADMAP.md` (the row to Completed) | The PR body lists every change old -> new under "Review after" (D-DEL5). The glossary check: every governed term the new files use is in the word list |
| ST874d-6.2 | `reference/framework-mission-command.md` (v1.1 already adopts the specified task; add a pointer to the adopted doctrine of the AAR, from TC 7-0.1, and of the running estimate, from FM 5-0 and ADP 5-0), the framework registry (through `/frameworks`) | Read back |

## Risks and fallbacks

| Risk | Fallback | Source |
|---|---|---|
| A delegate cannot find its own agentId (ASM-1) | The delegating agent fills it from the agentId the launch returned | RFC 0011 3.4.9 |
| A delegate confined to its worktree cannot write the session DB (ASM-3) or a deeper brief (ASM-4) | Prefer `git worktree add`; else the AAR alone, recorded by the delegating agent, and the brief in its own scratch | RFC 0011 3.3.8, 3.4.8 |
| Lock contention (ASM-2) | Agents retry three times, then record a blocker; hooks do not retry | RFC 0011 3.6.6 |
| Version skew: a v4 helper meets a v5 DB, or a deploy skips one of the pair | Batch ST874d-3.0 first; the migration only through the deployed v5 pair; a skipped helper or hook is a WARN | RFC 0011 3.6.12 |
| The SessionEnd window (1.5 seconds), or git contention in the dotprofile | One detached job, with a lock and a rebase; catch-up completes it and reports a failure | RFC 0011 3.5.5 |
| A test pushes to the real dotprofile | A clone whose `origin` is a local bare repo, checked before every push | Batch ST874d-4.3 |
| A harvested brief or AAR reaches `harvesting/` before batch ST874d-4.5 ships | Do not commit `harvesting/*-brief.json` or `harvesting/*-aar.json`; nothing is done about the files already published (D874d-54) | RFC 0011 section 7 |
| The migration loses data | Forward-only; every v4 column checked against v5 (batch ST874d-3.3); tested on copies of the live DBs | RFC 0011 3.6.7 |

## Status

| Specified task | Batches | State | PR | Notes |
|---|---|---|---|---|
| The RFC and the plan | | done | | On main: commits 419d32dd (RFC v1.1, plan v1.0), 72ebefbc (RFC v1.2, plan v1.1), 2b16d2c0 (RFC v1.5, plan v1.3 and the brief in the briefs directory), and the commit that adds RFC v1.6, this plan v1.4 and brief v1.4. Verifiers 874d-3 to 874d-6; language reviewers 874d-7, 874d-9 and 874d-11 (874d-8 was stopped by an API safeguard; 874d-10 examined why) |
| ST874d-1 | ST874d-1.1 to ST874d-1.5 | not started | | Waits for G0 |
| ST874d-2 | ST874d-2.1 to ST874d-2.5 | not started | | Waits for G0; G1 met (311ad1ff) |
| ST874d-3 | ST874d-3.0 to ST874d-3.6 (with ST874d-3.4b) | not started | | |
| ST874d-4 | ST874d-4.1 to ST874d-4.5 (with ST874d-4.2a, ST874d-4.2b) | not started | | |
| ST874d-5 | ST874d-5.1 to ST874d-5.4 | not started | | |
| ST874d-6 | ST874d-6.1, ST874d-6.2 | not started | | |
