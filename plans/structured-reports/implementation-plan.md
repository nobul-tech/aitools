# Implementation plan: structured running estimates, mission briefs and AARs

**Intent**: **Purpose**: Sequence the implementation of RFC 0011 into small
batches of two or three files, each with its verification, so the
implementing mission can ship it work package by work package and the
commander can see where it stands. **Scope**: The gates before the work
starts, the work packages WP-1 to WP-6 and their batches, how each batch is
verified and shipped, risks and their fallbacks, and the status table. NOT
the specification (RFC 0011, normative). NOT the decisions (issue #180
section 1). NOT the implementing mission's brief
(`874d-2-structured-reports-brief.json`). **Audience**: The implementing
mission (874d-2-structured-reports) and its delegates; the commander,
tracking progress.

v1.0 (2026-11-16), session dbd05b0c. WP-0 (RFC 0011 and this plan) is done
by this version.

## Sources of truth

| What | Where | Precedence |
|---|---|---|
| The commander's decisions | Issue nobul-tech/aitools#180, section 1 (`D874d-<n>`) | 1: fixed; not reopened |
| The specification | `rfcs/RFC-0011-structured-reports.md` | 2: normative; its section 4 points are review-after |
| This plan | `plans/structured-reports/implementation-plan.md` | 3: sequencing only |
| The mission brief | `<session scratch dir of dbd05b0c>/874d-2-structured-reports-brief.json` | The implementing mission's objectives, constraints and reading list |

When two disagree, the higher one wins (D-DEL6). A conflict found is
reported as an ambiguity in the AAR, and a point that needs the commander
becomes an RFI with a suggested answer.

## Gates

| Gate | Condition | State |
|---|---|---|
| G0 | The commander orders the implementation launched (D874d-45: "21) no" for now) | closed |
| G1 | The six working-copy files of session dbd05b0c are on `origin/main`: `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md`, `registries/glossary.json`, `.claude/rules/glossary.md`, `reference/framework-intelligence-types.md`, `ROADMAP.md`. The commander takes care of this (R874d-27). The same holds for this plan, RFC 0011 and the `rfcs/README.md` row | open |
| G2 | RFC 0011 has an independent reviewer's verdict (issue #180, WP-0 "Done when") | open |

WP-1 starts when G0, G1 and G2 are met.

## How every batch is shipped (D-DEL4)

- **Worktree and branch.** One worktree, `<aitools>/.scratch/worktrees/874d-2-structured-reports`, off `origin/main`. One branch and one PR per work package, each based on `main`: `feature/874d-2-wp1-schemas`, `-wp2-harness-text`, `-wp3-schema5`, `-wp4-hooks`, `-wp5-skills`, `-wp6-release`. A later branch merges the earlier one in with `--no-ff`; it never stacks its PR base on another PR.
- **Commits.** Commit and push after every batch, with `git commit -F` from the scratch directory.
- **Checks before every push.** `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` on macOS or Linux; the `.ps1` twins on Windows.
- **CI.** Watch CI until it passes on macOS, Linux and Windows.
- **Review.** An independent reviewer (a separate delegate that did not see the author's notes) posts its verdict as a PR comment before merge.
- **Never:** push to `main`, force-push, merge or approve your own PR, or run `aitools`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real `HOME`.
- **Hooks.** A new or widened hook check starts in observe mode (`.claude/rules/hook-rollout.md`).
- **After each batch,** update the status table at the end of this plan.

## WP-1: reference, schemas, templates, validation

RFC 0011 sections 3.1 to 3.4, 3.7 and 3.8.

| Batch | Files | Verify |
|---|---|---|
| 1.1 | `reference/schemas/mission-brief.schema.json`, `reference/schemas/aar.schema.json` | Both parse (`python3 -m json.tool`). Each node and field is checked against RFC 0011 3.3 and 3.4 line by line, and the forbidden nodes are rejected (`additionalProperties: false`) |
| 1.2 | `reference/schemas/running-estimate.schema.json`, `reference/templates/mission-brief.json` | The schema parses and is checked against RFC 0011 3.5; the template is an empty instance of the brief schema |
| 1.3 | `reference/templates/aar.json`, `reference/templates/running-estimate.json` | Each is an empty instance of its schema |
| 1.4 | `scripts/harness-db.py` (`validate --kind brief\|aar\|estimate <file>`, the stdlib subset of RFC 0011 3.7.2), `tests/harness-db/test-validate.py` | The templates and one full example of each document validate. Negative cases fail: a missing required node, a forbidden node (`facts`, `meta`, `findings`, `report_at_once_if`), a bad enum. `tests/harness-db/test-validate.py` is added to `.github/workflows/check.yml` |
| 1.5 | `reference/structured-reports.md` (intent statement; naming, schema, store and write rules, pointing to RFC 0011), `reference/README.md` (index row) | `/intent-audit` passes on the reference |

## WP-2: the harness text, in line with RFC 0011 (D874d-49)

First, check G1: the six files are on `origin/main`.

| Batch | Files | Verify |
|---|---|---|
| 2.1 | `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md` | D-DEL10: the brief is `<session scratch dir>/<mission name>-brief.json` (D874d-42). D-DEL11: the AAR is the hand-back, JSON in one fenced block (D874d-50), and a file only on request (D874d-47). `/delegate` "Mission brief file": the name, JSON with one key per node, the schema's path, `rules[]` holding every file to read in full (RFC 0011 S-8), the fallback for isolated delegates (S-9); element 10; the prompt skeleton; "Final response shape" (JSON). Each file is read back against RFC 0011 3.3, 3.4 and 3.9 |
| 2.2 | `registries/glossary.json`, `.claude/rules/glossary.md` (through `/glossary`) | `mission brief`: a JSON file named `<mission name>-brief.json`. `after action review`: the hand-back is JSON, a file only on request. The JSON parses, and the word list matches the JSON |
| 2.3 | `shared/rules/prompt-turn.md` (L67), `reference/prompt-turn-checklist.md` (L219) | `R<sid4>-<n>` for session RFIs, `D<sid4>-<n>` for decisions (D874d-41), in both files (the rule condenses the reference) |
| 2.4 | `reference/framework-intelligence-types.md` (v1.3: points to `reference/structured-reports.md`), `ROADMAP.md` (the issue #180 row to In Progress, linked to this plan) | Read back |

WP-2 is done when no harness file names `<sid4>_<mission name>-brief.md`, a Markdown brief, a default AAR file, `RFI <sid4>-<n>` or `D-<sid4>-<n>`. Check with `grep -rn` over `shared/`, `.claude/`, `reference/` and `registries/`.

## WP-3: session DB, schema 5 (RFC 0011 section 3.6)

`--session` is removed in the same PR that switches the hooks to `--db` (S-15).

| Batch | Files | Verify |
|---|---|---|
| 3.1 | `scripts/harness-db.py` (schema 5: `items`, `refs`, the `observations` view, the v4 to v5 migration of RFC 0011 3.6.7), `reference/harness-db-schema.sql` (generated) | The `.sql` matches the generated output (`tests/harness-db/test-schema.py`) |
| 3.2 | `scripts/harness-db.py` (CLI: `--db`, `--agent-id`, `--agent-type`, `--mission`; `item add\|update\|list`; `aar --agent-id`; per-session `export`; the lock retry of 3.6.6; the prefix check of 3.6.2; the old verbs writing `items`) | `harness-db.py --help` and each verb's help |
| 3.3 | `tests/harness-db/test-schema.py` (v5), a v4 fixture, `tests/harness-db/test-concurrency.py` (new: several parallel writers, ASM-2; the prefix collision, ASM-6) | All harness-db suites pass on macOS, Linux and Windows. The migration runs on copies of the live DBs (made with the sqlite3 backup API, as in PR #181) with no row lost |
| 3.4 | `shared/hooks/harness-db-sessionstart.sh`, `shared/hooks/harness-db-sessionend.sh` (`--db`), `.gitignore` (`.aitools/channel/estimates/`) | The hooks' smoke tests (`.claude/rules/hook-rollout.md`) pass; `tests/hooks/` pass |
| 3.5 | Probes, no file changes: ASM-1 (a running background delegate and a foreground delegate each find their own agentId, the two ways `/delegate` documents) and ASM-3 (a delegate in an isolated worktree writes the session DB) | Results in the PR body. If ASM-1 or ASM-3 fails, the fallbacks of RFC 0011 3.4.8 and 3.4.9 go into `/delegate` (a follow-up batch of WP-2) |

## WP-4: hooks and the dotprofile copy (RFC 0011 3.3.5, 3.4, 3.5.5, section 7)

| Batch | Files | Verify |
|---|---|---|
| 4.1 | `shared/hooks/delegation-duty-guard.sh`, `shared/hooks/workflow-delegation-guard.sh` (their shared element block): element 10 is scored by a brief path and an instruction to read the brief in full | Observe mode. The smoke, violation and parity tests in `tests/hooks/` pass |
| 4.2 | An AAR check of the hand-back (PostToolUse on `Agent`, or `SubagentStop`; a new hook or an existing one), validating the fenced JSON with `harness-db.py validate --kind aar`; `shared/hooks/hooks-manifest.json`; `.claude/rules/hook-rollout.md` (state table) | Observe mode; tests in `tests/hooks/`; the manifest's parity check passes |
| 4.3 | `scripts/ait-harvest.py` (copy the export to `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json`, commit and push the dotprofile's `main`, detached like `archive`), `shared/hooks/session-catchup.sh` (recover a missed copy) | Under an isolated `HOME` with a copy of the dotprofile: the copy lands at the right path and is committed and pushed, and a cut-off copy is recovered at the next start. Check how the archive path handles a push that is not a fast-forward, and reuse it |
| 4.4 | `scripts/ait-harvest.py` (`_is_ephemeral`: `*-brief.json`, `*-aar.json`; RFC 0011 S-14), its tests | A brief and an AAR file in a session scratch directory are not copied to `harvesting/` |

## WP-5: the skills that use the documents

| Batch | Files | Verify |
|---|---|---|
| 5.1 | `shared/skills/handoff/SKILL.md` (carries the running estimate), `shared/skills/aitool-continue/SKILL.md` (loads the project's last record from the dotprofile's `running-estimates/`) | Read back against RFC 0011 3.5 |
| 5.2 | `shared/skills/mission-control/SKILL.md` (reads `missions[]`); retire `.aitools/channel/running-estimate.json` and `.aitools/templates/mission-running-estimate.json` (`git rm`) | `grep -rn` finds no reference to the retired files |

## WP-6: release

| Batch | Files | Verify |
|---|---|---|
| 6.1 | `RELEASE_NOTES.md` (one version entry per merged PR, or one for the set), `ROADMAP.md` (the row to Completed) | The PR body lists every change old -> new under "Review after" (D-DEL5) |

## Risks and fallbacks

| Risk | Fallback | Source |
|---|---|---|
| A delegate cannot find its own agentId while running (ASM-1) | It writes an empty `agent_id` and its `mission`; the session agent fills the id from its AAR | RFC 0011 3.4.9 |
| A delegate confined to its worktree cannot write the session DB (ASM-3) or a deeper brief (ASM-4) | The AAR alone, recorded by the session agent; the brief in the delegating agent's own scratch | RFC 0011 3.3.8, 3.4.8 |
| Lock contention (ASM-2) | Three retries with backoff, then a loud failure | RFC 0011 3.6.6 |
| The SessionEnd window is too short for the copy and the push | Detached, like `session-archive.sh`; recovered by `session-catchup.sh` | RFC 0011 3.5.5 |
| A harvested brief reaches tracked `harvesting/` before batch 4.4 ships | Do not commit `harvesting/*-brief.json` or `harvesting/*-aar.json` | RFC 0011 section 7 |
| The migration loses data | Forward-only and tested on copies of the live DBs; RFC 0010 section 5: delete the `.db`, re-initialize, re-import from the export | RFC 0011 3.6.7 |

## Status

| WP | Batch | State | PR | Notes |
|---|---|---|---|---|
| WP-0 | RFC 0011, this plan | written (working copy, uncommitted) | | Session dbd05b0c; independent verifiers 874d-3 to 874d-6 |
| WP-1 | 1.1 to 1.5 | not started | | Waits for G0, G1, G2 |
| WP-2 | 2.1 to 2.4 | not started | | |
| WP-3 | 3.1 to 3.5 | not started | | |
| WP-4 | 4.1 to 4.4 | not started | | |
| WP-5 | 5.1, 5.2 | not started | | |
| WP-6 | 6.1 | not started | | |
