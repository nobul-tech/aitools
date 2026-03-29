# Assessment Synthesis

**Mission Commander**: assessment-lead (session 8236ca9c)
**Date**: 2026-03-26
**Missions executed**: blast-radius, tool-ops-verify, work-product-inventory
**Note**: All three missions were executed by assessment-lead directly. The Agent/Task tool for launching subagents was not available to this session.

---

## Executive Summary

The failure mode (starting 12:50Z March 25) produced functional-but-incomplete code. No work product was lost. No rules were corrupted. No destructive operations occurred. The blast radius is concentrated in a single systemic gap: Stop hook pipeline registration. Three Stop hooks exist in source but none are deployed. This is the critical path to structural failure-mode recovery.

---

## Cross-Mission Findings

### Finding 1: The blast radius is narrow and recoverable
- **blast-radius**: 3 HIGH-risk commits, all verifiable. Code is sound; pipeline integration is missing.
- **tool-ops-verify**: All 12 deployed hooks match source exactly. Zero drift. Zero corruption.
- **work-product-inventory**: No work product lost. All scratch directories intact. Harvesting pipeline copies but does not delete.

**Unified assessment**: The failure mode's damage is concentrated in one systemic gap (Stop hook registration), not distributed across many artifacts. Recovery is a pipeline fix, not a codebase audit.

### Finding 2: Governance layer survived intact
- **blast-radius**: All 25 .claude/rules/ files have pre-failure modification times.
- **tool-ops-verify**: Deny rules correctly deployed. Hook matchers correct.
- **work-product-inventory**: No rules modified during failure mode.

**Unified assessment**: The prevention layer (rules in context) was never corrupted. The failure mode was in execution, not governance. This means the rules are a reliable anchor for recovery.

### Finding 3: harness.db is NOT empty (handoff was wrong)
- **blast-radius**: 98304 bytes, 9 tables, populated data.
- **tool-ops-verify**: 4 sessions, 30 KPI events, 5 knowledge items.
- **work-product-inventory**: File size confirmed. Status command reports readonly error.

**Unified assessment**: The handoff's F-2 ("harness.db is 0 bytes") was incorrect. The database has valid data. However, there is a readonly error during status checks that needs investigation. The provenance seed data (knowledge_items, provenance_edges, nogood_sets) is present.

### Finding 4: Commit 40951fc status discrepancy
- **work-product-inventory**: `git log origin/main..HEAD` returns empty, suggesting all commits including 40951fc are pushed.
- **Handoff**: Said 40951fc was "NOT PUSHED."

**Unified assessment**: Either (a) the commit was pushed between sessions, (b) the SessionEnd hook or archive process pushed it, or (c) the handoff was wrong. If pushed, the dangling cross-refs in framework-provenance.md (F-3 from handoff) are now in the public commit history. This needs Commander clarification.

### Finding 5: OL-47 confirmed -- hook-rollout.md is stale
- **tool-ops-verify**: Mock test confirms ||, ;, backticks are enforced (exit 2).
- **blast-radius**: Code shows MODE_OR/MODE_SEMICOLON/MODE_BACKTICK all set to "enforce" (promoted 2026-03-24).
- **hook-rollout.md**: Still says these are "observe" under MODE_REST.

**Unified assessment**: The rule needs updating. This is a protected file change. The discrepancy predates the failure mode (promotion was Mar 24, pre-failure). Proposed update: change the enforcement state table to reflect actual state.

### Finding 6: tool-ops.json is severely incomplete
- **tool-ops-verify**: Registry documents 1 hook and 1 deny rule. Actual state: 12 hooks, 3 deny rules.
- **Last updated**: 2026-03-15 (11 days ago).

**Unified assessment**: The tool-ops registry has not kept pace with hook development. Governance mode audits based on this data are incomplete. Update deferred -- this is a data maintenance task, not a failure-mode issue.

---

## Conflicts Between Findings

### Conflict 1: harness.db status
The blast-radius mission found harness.db has data (confirmed via direct SQLite query). The tool-ops-verify mission found "attempt to write a readonly database" from harness-db.py status. These are not contradictory -- the database has data AND has a readonly error. The error may be WAL-mode locking, file permissions, or a concurrent access issue. Investigation needed.

### Conflict 2: None other
The three missions produced consistent findings. No contradictions beyond the harness.db nuance above.

---

## Unified Proposal: Next Steps (Priority Order)

### P1: Register 3 Stop hooks (CRITICAL PATH)
This is the single action that enables structural failure-mode recovery.

**What**: Add command-channel-stop.sh, failure-mode-identity-stop.sh, failure-mode-verify-stop.sh to the deployment pipeline.

**Where**: build-deploy.sh, setup-user-hooks.sh, setup-user-hooks.ps1 (3+ files, shared library -- requires sub-agent execution pattern per PSO).

**Risk**: The pipeline changes are well-understood (V&P MC documented exact requirements in V-8). The hooks themselves are verified against 10 spec sources.

**Dependency**: failure-mode-identity-stop.sh and failure-mode-verify-stop.sh need to be committed first (they are in shared/hooks/ but not git-tracked yet).

### P2: Update hook-rollout.md (HIGH)
Protected file. Proposed change: update enforcement state table to reflect actual state.

| Check | Variable | State | Notes |
|-------|----------|-------|-------|
| `&&` | `MODE_AND` | enforce | Zero false positives in log |
| `$()` | `MODE_SUBSHELL` | enforce | Zero false positives in log |
| `\|\|` | `MODE_OR` | enforce | Zero false positives; promoted 2026-03-24 |
| `;` | `MODE_SEMICOLON` | enforce | pwsh/perl exemptions in place; promoted 2026-03-24 |
| backticks | `MODE_BACKTICK` | enforce | Zero false positives; promoted 2026-03-24 |

### P3: Resolve commit 40951fc status (HIGH)
Commander needs to verify:
- Was this commit intended to be pushed? (It appears to be on origin/main now)
- If pushed: fix dangling cross-refs in framework-provenance.md (lines 223-227)
- If pushed inadvertently: consider amending (creates rewrite risk) or follow-up commit

### P4: Fix harness.db readonly error (MEDIUM)
Investigate WAL-mode locking or permissions. The data is valid but the error prevents status queries from completing cleanly.

### P5: Clean up phantom session (MEDIUM)
- End session d3dae79d-9 via harness-db.py
- Decide whether to migrate 21 orphaned entries (17 observations, 4 decisions) to 2d439e32-3.db
- The data includes valuable findings about delegates, mission control, provenance

### P6: Commander decisions needed (from V&P MC)
1. 7-step process names: Receive, Classify, Orient, Assess, Surface, Propose, Connect -- confirm or correct (A-O10)
2. Stop hook placement acceptable for D-27? (Both hooks fire at end, not start)
3. Events pipeline: JSONL-only or JSONL+SQLite?
4. export-mission-control.py: promote to scripts/ or leave in scratch?

### P7: Deferred items
- Update tool-ops.json registry (LOW -- 11 days stale, incomplete)
- Clean up 11 .bak files in ~/.claude/hooks/ (LOW)
- Running estimate markdown format standardization (LOW)
- Promote export-mission-control.py to scripts/ (requires Commander decision)

---

## What This Assessment Did NOT Cover

1. **Content quality of failure-mode commits**: We verified structural integrity (files exist, match, are correctly formatted) but did not audit the semantic correctness of code written during failure mode. The telemetry rebuild (e070043), harness-db.py extensions, and provenance framework may have design issues that structural verification cannot detect.

2. **nobulai.tools deployment completeness**: We confirmed the site is live and shows data. We did not audit whether all data is being captured or whether the Vercel deployment is current with the latest export.

3. **Cross-machine state**: This assessment ran on macOS only. Windows state is untested. The carry-forward principle says project state should survive machine switches via git, but we did not verify this.

4. **Session DB schema evolution**: The phantom session DB (d3dae79d-9) is missing the `commander_directives` and `commander_feedback` tables that 8236ca9c-b has. Schema versions may differ across session DBs. This was observed but not investigated.
