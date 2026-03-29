# Work Product Inventory

**Mission Commander**: work-product-inventory (executed by assessment-lead)
**Session**: 8236ca9c | **Date**: 2026-03-26

---

## Summary Table

| Area | PRE-FAILURE | FAILURE-MODE | POST-FAILURE | Total |
|------|-------------|-------------|-------------|-------|
| Session transcripts (JSONL) | 19 | 1 | 0 (active) | 20 |
| Session databases | 1 | 3 | 1 | 5 |
| Harness DB | 0 | 1 | 0 | 1 |
| Git commits (aitools) | ~55 | 19 | 0 | 74 |
| Git commits (dotprofile) | 4 | 1 | 0 | 5 |
| Git commits (nobul-ops) | 2 | 0 | 0 | 2 |
| Harvesting artifacts | ~530 | ~49 | 0 | ~579 |
| Scratch session dirs | 8 | 3 | 1 | 12 |
| Channel files | 5 | 3 | 0 | 8 |
| Rules files | 25 | 0 | 0 | 25 |
| Reference files | ~42 | ~6 | 0 | ~48 |
| Hook source files | 7 | 6 | 2 | 15 |
| RFCs (nobul-ops) | 4 impl, 4 draft | 0 | 0 | 22 |
| Vercel deployments | ~15 | ~3 | 0 | ~18 |

---

## Area 1: Session Transcripts

### Dotprofile archives (/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/)

| File | Lines | Category | Session |
|------|-------|----------|---------|
| 2026-03-14_b301ffb1.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-14_b6a51f29.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-15_84280c8b.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-15_c0b392f4.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-15_c8862b68.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-15_eaacf9da.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_276dee5c.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_37ab88e4.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_79b05dd0.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_9dc5dee4.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_b8a9ed4e.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-16_ed02d497.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-17_e059186f.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-21_ab5da7ea.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-22_27270116.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-22_77a33baf.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-23_beaf0ed6.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-24_3cd9a8d1.jsonl | -- | PRE-FAILURE | -- |
| 2026-03-24_c0dc2ddc.jsonl | 4001 | FAILURE-MODE | Session that entered failure mode |
| 2026-03-25_2d439e32.jsonl | 1599 | FAILURE-MODE | Recovery session |

Last dotprofile commit: 88e076f (Mar 26 05:39) -- archive of session 2d439e32.

### Session Databases (/Users/pepe/repos/aitools/.aitools/sessions/)

| DB | Size | Status | Messages | Category |
|----|------|--------|----------|----------|
| c0dc2ddc-f.db | 204800 | ended | 200 | FAILURE-MODE (session that entered failure mode) |
| 2d439e32-3.db | 172032 | ended | 65 | FAILURE-MODE (recovery session) |
| d3dae79d-9.db | 126976 | ended | 0 | FAILURE-MODE (phantom -- 17 obs, 4 decisions orphaned) |
| 8236ca9c-b.db | 135168 | active | 0 | POST-FAILURE (current session) |
| harness.db | 98304 | -- | -- | FAILURE-MODE (has data despite prior report of empty) |

---

## Area 2: Harness DB

File: `/Users/pepe/repos/aitools/.aitools/harness.db` (98304 bytes)

| Table | Rows | Notes |
|-------|------|-------|
| session_index | 4 | All 4 sessions registered |
| kpi_events | 30 | Hook fire/block events |
| knowledge_items | 5 | Provenance seed data |
| provenance_edges | 2 | Dependency relationships |
| nogood_sets | 1 | Known dead-end |
| kpi_ship_log | 0 | No Datadog shipping |
| dashboard_state | 0 | -- |

Schema: `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` (16010 bytes, modified Mar 25 14:37 -- FAILURE-MODE)

harness-db.py CLI: `/Users/pepe/repos/aitools/scripts/harness-db.py` (106054 bytes, modified Mar 25 17:16 -- FAILURE-MODE)

**Issue**: `harness-db.py status` reports "ERROR: attempt to write a readonly database" for harness.db.

---

## Area 3: Git Repos

### aitools (main repo)
- Branch: main
- Last commit: 40951fc (Mar 25 17:27 -- Define Provenance as 6th component)
- Unpushed commits: **0** (origin/main == HEAD, confirmed by empty `git log origin/main..HEAD`)
  - Wait: the git status shows the commit is on main. Let me verify: `git log --oneline origin/main..HEAD` returned empty, meaning 40951fc IS pushed.
  - **Correction**: The handoff said 40951fc was "NOT PUSHED" but it appears to be pushed now (no divergence from origin/main). This contradicts the handoff.
  - **Uncertainty**: I cannot definitively confirm whether it was pushed between sessions or the handoff was wrong. The observation is that origin/main == HEAD right now.
- Uncommitted changes: Modified files (.aitools/channel/running-estimate.json, harvesting/harvest-manifest.json) plus ~52 untracked files (harvesting artifacts, handoff, scratch files)

### aitools-nobul-jose (dotprofile)
- Last commit: 88e076f (Mar 26 05:39 -- Archive session 2d439e32)
- This is a session archive auto-commit from the SessionEnd hook.

### nobul-ops
- Last commit: d54cbf2 (Mar 23 12:15 -- Add session handoff for RFC 0023 P0)
- PRE-FAILURE (March 23, before failure mode started)
- No changes since March 23

---

## Area 4: Harvesting

Directory: `/Users/pepe/repos/aitools/harvesting/`
- **579 files** total
- Most are from session 2d439e32-3 (2026-03-26 prefix) and earlier sessions
- Manifest: harvest-manifest.json tracks status (harvested, candidate, keep)

Key entries:
- 2 "candidate" with keep=true: aar-tool-ops-plan.md, test-tool-ops.py (from Mar 15)
- Most entries: status "harvested", pruneAfter dates 30 days out
- 49 artifacts from session c0dc2ddc-f were harvested in commit 8a5e869

---

## Area 5: Scratch Directories

| Directory | Files | Category | Notable Contents |
|-----------|-------|----------|-----------------|
| session-8236ca9c-b/ | 8 | POST-FAILURE | running-estimate-v1.md, hook-design.md, verify-and-propose.md, events.jsonl |
| session-2d439e32-3/ | 90 | FAILURE-MODE | meaning-reconstruction.md, full-audit-report.md, assumption-trace.md, MC screenshots, export scripts |
| session-c0dc2ddc-f/ | 176 | FAILURE-MODE | Massive session -- delegation prompts, consolidated OL, mission control prototypes, provenance research |
| session-d3dae79d-9/ | 1 | FAILURE-MODE | Only events.jsonl (phantom session) |
| session-delta2/ | ~3 | PRE-FAILURE | Mar 24 |
| session-5HyCwPtSDH/ | ~85 | PRE-FAILURE | Mar 21 |
| session-RnTOD5XJFi/ | ~118 | PRE-FAILURE | Mar 24 |
| session-KHGOmVeNNM/ | ~4 | PRE-FAILURE | Mar 23 |
| session-XgKlTIlRuW/ | ~3 | PRE-FAILURE | Mar 22 |
| 4 empty sessions | 0-2 each | PRE-FAILURE | Mar 24 (short-lived) |

Plus non-session files in .scratch/ root: build logs, commit messages, research docs, test scripts.

---

## Area 6: Channel

Directory: `/Users/pepe/repos/aitools/.aitools/channel/`

| File | Category | Notes |
|------|----------|-------|
| running-estimate.json | FAILURE-MODE | Session 2d439e32 data, 65 delegation-guard findings (mostly low scores: 0-4/6) |
| harness-state.json | FAILURE-MODE | State from session c0dc2ddc-f |
| harness-state-alpha.json | FAILURE-MODE | Variant state files |
| harness-state-bravo.json | FAILURE-MODE | |
| harness-state-charlie.json | FAILURE-MODE | |
| operational-learning.json | FAILURE-MODE | |
| handoffs/handoff-2d439e32-3.md | FAILURE-MODE | Comprehensive handoff document |
| session-uyZ7TELqpP/ | PRE-FAILURE | Older session channel data |

---

## Area 7: RFCs in nobul-ops

### RFC 0020: Identity, Secrets, and Access Management
- Status: Draft (v3)
- Created/Revised: 2026-03-23 (PRE-FAILURE)
- 4-tier architecture: Secrets (SOPS+age), Okta SSO, Auth0/nobul-auth, Datadog
- All vendors subject to SaaS Contingency lifecycle (RFC 0023)
- Prerequisites: uncommitted people.json changes from session uUnE4gUZLG

### RFC 0023: SaaS Contingency Architecture
- Status: Draft (v2)
- Created/Revised: 2026-03-23 (PRE-FAILURE)
- 6-stage lifecycle: Adopt, Extend, Build adapter, Develop replacement, Decision gate, Flip
- Critical constraint: Never sign up retail for cloud providers with startup programs
- Vercel migration (P0) most urgent -- free tier limits being hit NOW

Both RFCs are PRE-FAILURE artifacts from March 23 (before failure mode started on March 25).

---

## Area 8: Release History

| Version | Date | Category | Key Changes |
|---------|------|----------|-------------|
| v0.67.1 | Mar 25 | FAILURE-MODE | Hook pipeline fix, command-channel-stop.sh, harness-db CLI |
| v0.67.0 | Mar 25 | FAILURE-MODE | Telemetry rebuild (deleted 3 Stop hooks), /aitool-continue, JSONL events |
| v0.66.1 | Mar 25 | FAILURE-MODE | CI fix, harness-db registration, artifact catchup |
| v0.66.0 | Mar 24 | PRE-FAILURE | Intent sentinel, delegation guard, managed bash, CI pipeline |
| v0.65.1 | Mar 24 | PRE-FAILURE | Compliance, reference-card skill, intent fixes |
| v0.65.0 | Mar 24 | PRE-FAILURE | SQLite foundation, mission control, dashboard fixes |
| v0.64.1 | Mar 22 | PRE-FAILURE | Remove auto-deletion from session hooks |
| v0.64.0 | Mar 22 | PRE-FAILURE | Platform stabilization, operational learning, process discipline |
| v0.63.0 | Mar 21 | PRE-FAILURE | Dynamic mission control dashboard, .gitignore fix, 30 file recovery |

3 releases during failure mode (v0.66.1, v0.67.0, v0.67.1). 6 releases pre-failure (v0.63.0 through v0.66.0).

---

## Area 9: Lost Work Product Investigation

### Git reflog analysis
11 reflog entries since March 25. All are forward-moving commits. No `reset`, no `checkout --`, no `clean`, no force push. The commit history is clean and intact.

### Hook behavior analysis
- **scratch-init.sh**: Does NOT delete old session directories. Explicitly documents the 30-file-loss fix. Only creates new session dirs and writes .current-session pointer.
- **harvest-session.sh**: Does NOT delete from .scratch/. Copies to harvesting/ with date prefix. Explicitly documents "No rm -rf of session dirs."

### Conclusion: No work product was lost
All session scratch directories are intact with expected file counts. The harvesting pipeline copies but does not remove. The phantom session issue redirected DB writes to the wrong database, but the data is intact in d3dae79d-9.db (17 observations, 4 decisions) and could be migrated.

---

## Area 10: Vercel / Mission Control

### nobulai.tools status
- **LIVE** and operational as of 2026-03-26
- Shows session 2d439e32 data: 65 messages, 3 decisions, 56 observations
- 7 tabs visible: Messages, Documents, Governance, Git Diffs, Delegations, Missions, State, Feedback
- Pending actions: 3 decisions need review, 3 observations pending review
- Snapshot date shown in header: 2026-03-26 (approximately 08:01Z based on screenshot timestamp)
- Quick Directives panel visible with: Correction, Redirect, Approve, Reject, Context, Checkpoint buttons

### Two pipeline problem (from handoff)
1. **JSON pipeline**: generate-dashboard.py reads running-estimate.json, serves on port 8411 (often stale)
2. **SQLite pipeline**: export-mission-control.py reads session DB, generates static HTML for Vercel

### export-mission-control.py
Located at: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/export-mission-control.py` (in scratch, FAILURE-MODE artifact)

---

## Commit 40951fc Status Discrepancy

The handoff says commit 40951fc is "NOT PUSHED." However, `git log --oneline origin/main..HEAD` returned empty, indicating HEAD == origin/main, meaning all commits including 40951fc appear to be pushed.

**Possible explanations**:
1. The commit was pushed between session 2d439e32-3 ending and session 8236ca9c starting
2. The handoff was written before a push that happened later in the same session
3. The SessionEnd hook or another process pushed it

**I surface this as an observation, not a diagnosis.** The Commander should verify whether commit 40951fc was intended to be pushed or whether it was pushed inadvertently.
