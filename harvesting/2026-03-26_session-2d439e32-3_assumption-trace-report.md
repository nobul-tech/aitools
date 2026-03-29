# Assumption Trace Report: Session 2d439e32-3

**Date**: 2026-03-25/26
**Investigator**: Assumption trace commander (Opus 4.6)
**Scope**: Every incorrect assumption made during this session, what actions were taken based on each, and blast radius assessment.

---

## Executive Summary

This session started in failure mode (delegates failing, context lost from prior session c0dc2ddc-f) and recovered through conversation, context loading, and parallel delegation. The investigation identified **13 incorrect assumptions** across the session, its delegates, and its commits. Of these:

- **4 had material blast radius** (affected committed code, deployed artifacts, or database state)
- **5 had contained blast radius** (affected scratch files or ephemeral state only)
- **4 had zero blast radius** (corrected before any action was taken)

The most impactful was the `.current-session` pointer issue, which caused 17 observations and 4 decisions to be written to a phantom session database (d3dae79d-9) instead of the correct one (2d439e32-3).

---

## Incorrect Assumptions Traced

### IA-1: "Delegates can't use Bash/read outside the repo"

**What was assumed**: Early in the session, 3 of 4 initial delegates failed. The working theory was that delegates have limited permissions -- they cannot use Bash, cannot read files outside the repo, cannot query SQLite databases. This was framed as a "permission asymmetry" between the main agent and its delegates.

**What was actually true**: Delegates have FULL access -- read, write, Bash, python3, SQLite queries, chrome-devtools, Vercel deploy, sub-delegation. The failures were a permission-approval timing issue: permission grants are asynchronous, and the early delegates ran before the user had approved the necessary permissions. Once permissions were granted for the session, subsequent delegates worked perfectly.

**Actions taken based on assumption**:
1. A special "delegation test" mission was launched to empirically verify delegate capabilities (`.scratch/session-2d439e32-3/delegation-test-results.md`)
2. The session paused delegation work while diagnosing the "permission asymmetry"
3. Early delegation prompts were written with workarounds for assumed limitations

**Work product affected**: `delegation-test-results.md` (scratch file). The test results CORRECTED the assumption and became OBS-24 / OL-24.

**Blast radius**: CONTAINED. No committed code or deployed artifacts were affected. The test was the correction mechanism. The only cost was time spent investigating a non-issue.

**Corrected?**: Yes. By the delegation test mission itself. OBS-24 records the correction.

---

### IA-2: "The consolidated OL from last session (c0dc2ddc-f) was reliable"

**What was assumed**: The consolidated operational learning from session c0dc2ddc-f could be trusted as a starting foundation for this session's work.

**What was actually true**: The consolidated OL was produced by a delegate during that session's own failure mode period. It contained partially stale claims. OBS-9 in the phantom session notes: "The consolidated OL itself is partially stale (declares items as working that are actually aspirational)." The staleness audit found 3 fully stale files and 5 partially stale files, all in scratch/harvesting from the prior session.

**Actions taken based on assumption**:
1. The provenance framing work used the consolidated OL as a basis for the "triggering experience" narrative in `reference/framework-provenance.md` (line 80-92)
2. Multiple delegates were briefed using the consolidated OL as context

**Work product affected**:
- `reference/framework-provenance.md` (COMMITTED in 40951fc, unpushed) -- the "triggering experience" section (lines 80-92) references the OL and the "/tmp assumption propagation" narrative from c0dc2ddc-f. The narrative itself is factually correct (it did happen), but the OL that described it was partially stale in other areas.
- Several delegate briefing prompts (ephemeral, no committed artifact)

**Blast radius**: LOW. The narrative in framework-provenance.md is factually accurate about the specific incident it describes. The stale portions of the consolidated OL were about other claims (features described as "working" that were aspirational), not about the provenance triggering experience.

**Corrected?**: Partially. OBS-7 records the staleness finding. The specific framework-provenance.md cross-references to scratch files (lines 222-227) remain dangling -- this is audit finding F-3.

---

### IA-3: "Commander's 'both are orders' was approval to ship protected files"

**What was assumed**: When the commander said "both are orders, one depends on the other" (referring to provenance proposals and a mission control deployment), the agent interpreted this as approval to commit the provenance changes to the three protected files (CLAUDE.md, reference/harness.md, reference/framework-provenance.md).

**What was actually true**: "Both are orders" meant "do A then B" -- a sequencing instruction, not an approval gate. The sources-of-truth review gate requires explicit "yes, write it" approval. Process instructions are not the same as content approval.

**Actions taken based on assumption**:
1. Commit 40951fc was created, modifying 3 protected files (CLAUDE.md, reference/harness.md, new reference/framework-provenance.md)
2. The commit was NOT pushed (remains local)

**Work product affected**:
- Commit 40951fc: 3 files, 270 insertions, 3 deletions. Unpushed.

**Blast radius**: MEDIUM. The commit exists locally but was never pushed or CI-tested. The content itself was reviewed via mission control (proposals were presented at nobulai.tools), but the formal sources-of-truth approval gate was not explicitly satisfied. The audit (OBS-29 / F-5) flagged this.

**Corrected?**: Partially. OL-23 records the lesson: "When the commander says 'both are orders, one depends on the other' -- that means do A then B, not 'A is approved.'" The commit remains unpushed and can be amended or dropped.

---

### IA-4: "Known list of 5 issues was everything wrong with mission control"

**What was assumed**: When a fix mission was launched for mission control / nobulai.tools, the initial delegation included a constrained list of ~5 known issues (feedback form missing, API 404, data stale, etc.).

**What was actually true**: The full audit (`.scratch/session-2d439e32-3/full-audit-report.md`) found 14 issues across 4 severity levels. The initial constrained list missed: phantom session, dangling cross-references, events table empty, schwerpunkt never set, .current-session pointer missing, Node.js deprecation, .bak file accumulation, harness-db.py `ol` subcommand targeting nonexistent table, and the command-channel-stop.sh registration gap.

**Actions taken based on assumption**:
1. Initial fix mission was scoped too narrowly (addressed only the known 5)
2. A second, broader audit mission was launched after the commander's correction ("give broad authority to DISCOVER and fix")

**Work product affected**:
- `mission-control-investigation.md` -- addresses the initial narrow scope (11 items found)
- `full-audit-report.md` -- addresses the broader scope (14 findings)

**Blast radius**: LOW. The narrow initial mission still fixed the critical issues (feedback form, API, deployment). The broader audit caught the rest. No incorrect fixes were applied.

**Corrected?**: Yes. OL-19 records: "When launching a fix mission, give broad authority to DISCOVER and fix -- not a constrained list of known issues."

---

### IA-5: "harness-db.py calls without --session flag write to the current session"

**What was assumed**: When delegates called `python3 harness-db.py observation add "..."` or `python3 harness-db.py decision add "..."` without the `--session` flag, the entries would go to session 2d439e32-3 (the active session).

**What was actually true**: Without `--session`, harness-db.py reads `.scratch/.current-session` to determine the target. That file pointed to `d3dae79d-9` (the phantom session created 47 minutes after 2d439e32-3 started). All writes went to the wrong database.

**Actions taken based on assumption**:
1. 17 observations were written to d3dae79d-9.db instead of 2d439e32-3.db
2. 4 decisions were written to d3dae79d-9.db instead of 2d439e32-3.db

**Work product affected**:
- **Phantom session d3dae79d-9.db**: Contains 17 observations and 4 decisions that belong to this session's delegates:
  - OBS-1 through OBS-17: Session operational findings (delegate capabilities, hook bugs, staleness audit, dashboard zombie, provenance status)
  - DEC-D-CONTEXT-PRECIOUS, DEC-D-CONTEXT-PRESERVE (duplicate), DEC-D-FLAT-ORG, DEC-D-MC-PREREQUISITE: Session decisions about operating principles
- **Session 2d439e32-3.db**: Missing those 17 observations and 4 decisions. The DB has observations written LATER (after the --session flag was used), but the early delegate findings are absent.
- **nobulai.tools**: Deploys read from 2d439e32-3.db, so the phantom session data is invisible on mission control.

**Blast radius**: HIGH. 21 structured data entries are in the wrong database. The phantom session has no messages (it's not a real Claude Code session), so those entries are effectively orphaned. The data is not lost (d3dae79d-9.db exists), but it is not visible through any standard interface. The .current-session pointer remains wrong.

**Corrected?**: Partially. OBS-9 documents the pointer trap. OL-9 records the lesson. But the 21 entries have NOT been migrated from d3dae79d-9.db to 2d439e32-3.db, and the .current-session pointer has NOT been fixed.

**Corrective action needed**:
1. Fix `.scratch/.current-session` to point to the correct session
2. Migrate observations and decisions from d3dae79d-9.db to 2d439e32-3.db (or document d3dae79d-9.db as a satellite)
3. Fix harness-db.py to be more robust about session resolution (prefer CLAUDE_SESSION_ID env var over file pointer)

---

### IA-6: "The bandit mission was a valid response to a blocker"

**What was assumed**: When a hurdle blocked an ongoing mission (possibly a mission control deployment issue or a hook pipeline bug), the correct response was to launch a separate "bandit mission" -- an uncoordinated one-off task that overlapped with running commanders.

**What was actually true**: Bandit missions create coordination problems. They operate without awareness of other running missions, can make conflicting changes, and fragment the session's work history. The correct pattern is to fix the hurdle within scope or delegate it through the existing command chain.

**Actions taken based on assumption**:
1. At least one uncoordinated mission was launched mid-session
2. This may have contributed to the phantom session creation (a hook firing from the bandit mission's context)

**Work product affected**: The bandit mission's work products are mixed into the session's scratch directory without clear provenance markers distinguishing coordinated vs uncoordinated work.

**Blast radius**: LOW-MEDIUM. The bandit mission pattern was corrected mid-session. OL-20 records: "Do not launch bandit missions -- uncoordinated one-off missions that overlap with running commanders."

**Corrected?**: Yes, as a behavioral correction. OL-20 is recorded.

---

### IA-7: "Provenance tables didn't exist in harness.db"

**What was assumed**: A cleanup/housekeeping mission included a task to "create provenance tables in harness.db," implying they didn't exist.

**What was actually true**: The tables already existed and were populated with seed data: 5 knowledge_items, 2 provenance_edges, 1 nogood_set. The cleanup report (`cleanup-report.md`, Task 5) confirms: "ALREADY DONE (no action needed) -- All three tables already exist in harness.db with data."

**Actions taken based on assumption**:
1. The housekeeping mission checked for the tables (found them already present)
2. No destructive action was taken -- the delegate verified before acting

**Blast radius**: ZERO. The delegate checked before writing, found the tables already existed, and reported "no action needed." This is a case of incorrect assumption with correct verification behavior.

**Corrected?**: Yes, self-corrected by the delegate during execution.

---

### IA-8: "setup-user-hooks.sh was working correctly"

**What was assumed**: The hook deployment pipeline (setup-user-hooks.sh/.ps1) was functional and could deploy new hooks.

**What was actually true**: The script had 4 bugs: undefined variables, no removal logic for stale hooks, no cleanup of deleted hooks from disk, and a stale header comment. Running `aitools sync` would have crashed.

**Actions taken based on assumption**:
1. The command-channel-stop.sh hook was written and committed (934d50c), but the deployment pipeline to actually install it was broken
2. Early in the session, the assumption delayed diagnosis of why hooks weren't deploying correctly

**Work product affected**:
- Commit 924b380: Fixed the 4 bugs in setup-user-hooks.sh/.ps1
- The command-channel-stop.sh hook remains unregistered in the deployment pipeline (audit finding F-1)
- 3 stale Stop hooks (surfacing-duty, estimate-refresh, intent-sentinel) were removed

**Blast radius**: MEDIUM. The hook pipeline fix was correct and shipped (pushed, CI green). But the command-channel-stop.sh hook was committed to shared/hooks/ without being registered in the deployment pipeline -- it is inert. The hook exists in source but will never fire until setup-user-hooks.sh/.ps1 is updated to deploy it.

**Corrected?**: Partially. The pipeline bugs are fixed (924b380). But command-channel-stop.sh registration is still missing (F-1 HIGH).

---

### IA-9: "Export script would produce correct data for nobulai.tools"

**What was assumed**: The export-mission-control.py script, when run against the current session DB, would produce a complete and accurate representation of the session.

**What was actually true**: Multiple data gaps exist because write-side hooks for several tables were never implemented:
- delegation_log: 0 rows (despite dozens of delegations during the session)
- missions: 0 rows (despite multiple missions being run)
- completed_work: 0 rows (despite significant work being completed)
- The dashboard correctly shows these as zero, but a viewer would incorrectly conclude no delegations or missions occurred

**Actions taken based on assumption**:
1. 18+ Vercel deployments during the session, all showing 0 delegations, 0 missions, 0 completed work
2. Mission control investigation report correctly identified this as a "data gap, not render bug"

**Work product affected**:
- nobulai.tools (live deployment) -- shows incomplete session data
- All 18+ Vercel deployments during the session reflect the same gap

**Blast radius**: LOW. The data is structurally correct (the tables exist, the counts are accurate for what's IN the tables). The gap is upstream -- no process writes to those tables during sessions. This is a known gap, not an error. The mission control investigation (problem #4, #5, #6) correctly documents this.

**Corrected?**: No -- the write-side hooks are not yet implemented. The gap is documented.

---

### IA-10: "The local dashboard on port 8411 was serving current data"

**What was assumed**: The dashboard server started by the SessionStart hook on port 8411 was serving current session data.

**What was actually true**: PID 4685 was a zombie process from a prior session, listening on port 8411 but not responding (curl returns exit code 28 / connection timeout). It was serving stale running-estimate.json from session c0dc2ddc-f. The cleanup report confirms it required `kill -9` to terminate.

**Actions taken based on assumption**:
1. The zombie was eventually detected and killed (`cleanup-report.md`, Task 1)
2. Investigation into data flow revealed generate-dashboard.py has no `--db` flag for direct SQLite access

**Work product affected**:
- No committed code affected
- The zombie was killed during the session

**Blast radius**: ZERO (for this session). The zombie was serving stale data from the prior session, but no one was relying on it for decisions. The public dashboard at nobulai.tools was the active viewing interface.

**Corrected?**: Yes. Process killed. Architecture documented in `mission-control-data-flow-investigation.md`.

---

### IA-11: "Commit 40951fc content was fully reviewed before writing"

**What was assumed**: The provenance proposals were presented at mission control, reviewed by the commander, and approved before being committed.

**What was actually true**: The proposals were presented at nobulai.tools (OBS-10 through OBS-13 document the 3 proposals). The commander's "both are orders" was interpreted as approval (see IA-3). The actual committed content DIFFERS from the proposals in some details:
- The proposal included an "Agent Operating Principles" section for CLAUDE.md -- this was NOT committed (the commit only changed the mission statement and added the design principle)
- The proposal included "(may be stale)" markers -- NOT committed
- reference/framework-provenance.md was committed with dangling scratch cross-references (lines 222-227) that the proposal didn't highlight as an issue

**Actions taken based on assumption**:
1. Commit 40951fc was created with a subset of the proposed changes
2. The subset was the least controversial part (mission statement + design principle + framework doc)
3. The more substantive "Agent Operating Principles" section was deferred

**Work product affected**:
- Commit 40951fc (unpushed): content is technically sound but the review gate was not cleanly satisfied
- `reference/framework-provenance.md` has dangling cross-references to gitignored scratch files

**Blast radius**: LOW. The commit is unpushed. The content is factually correct. The review process was irregular but the content was presented for review. The dangling cross-references (F-3) are the main actionable issue.

**Corrected?**: No. The commit remains unpushed. The cross-references remain dangling.

---

### IA-12: "The web portal proposal from c0dc2ddc-f was a valid starting point"

**What was assumed**: The portal proposal (proposal-web-portal.md from session c0dc2ddc-f) could be used as a starting point for portal development.

**What was actually true**: The proposal was written BEFORE several key architectural decisions and was completely stale. It assumed Cloudflare Pages + Workers + D1, Auth0 authentication, POST/sync endpoints, Preact SPA framework, mc.nobul.tech domain, and 10-14 day timeline. ALL of these were superseded by decisions made later in c0dc2ddc-f: D-VERCEL-STOPGAP, D-RELAY-PATTERN, D-DOMAIN (nobulai.tools), and Phase 0 shipped same-session.

**Actions taken based on assumption**:
1. The stale proposal was identified and rewritten as `proposal-web-portal-v2.md`
2. The feedback-analysis.md (Item 4) documents the staleness

**Work product affected**:
- `proposal-web-portal-v2.md` -- the corrected replacement (scratch file)
- The stale proposal was in harvesting/ from c0dc2ddc-f -- it remains there with its stale content

**Blast radius**: ZERO. The stale proposal was identified before any action was taken from it. The corrected version was written. OL-4 records: "The web portal proposal was stale because decisions moved faster than documentation."

**Corrected?**: Yes. Rewritten proposal exists. This is actually a META example of what the provenance system is designed to catch.

---

### IA-13: "harness-db.py 'ol add' subcommand works correctly"

**What was assumed**: The `ol add` lean subcommand (added in commit d395d50, session c0dc2ddc-f) would work for adding operational learning entries to the session DB.

**What was actually true**: The `ol add` subcommand targets an `operational_learning` table that does NOT exist in the session DB schema (v2). The session DB has `observations`, `decisions`, `messages`, etc. -- but no `operational_learning` table. The subcommand will fail at runtime with a SQLite error. This was filed as audit finding F-10 (LOW).

**Actions taken based on assumption**:
1. The subcommand was committed in d395d50 (prior session, pushed)
2. Agents attempting to use `ol add` during this session would have hit an error

**Work product affected**:
- `scripts/harness-db.py` -- the `ol add` subcommand is dead code
- No downstream impact observed (agents used `observation add` instead)

**Blast radius**: LOW. The subcommand exists but fails gracefully (SQLite error on missing table). No data was lost because no one successfully wrote to a nonexistent table.

**Corrected?**: No. The subcommand remains in the codebase. F-10 is filed.

---

## Phantom Session Deep Dive

The phantom session d3dae79d-9 warrants special attention because it is the accumulation point for IA-5's blast radius.

### How it was created

The session was registered in the harness DB index at 2026-03-25T23:45:41Z, 47 minutes after session 2d439e32-3 started (22:58:10Z). Most likely cause: a SessionStart hook fired from a nested context (possibly a delegate or a bandit mission that triggered its own session initialization). The scratch-init.sh hook updated `.scratch/.current-session` to point to this new session, redirecting all subsequent harness-db.py calls without `--session`.

### What's in it

**17 observations** (all findings and observations from early-to-mid session delegates):
- OBS-1 through OBS-5: Operating principles (delegate everything, flat org, full capabilities, MC communication, self-learning loop)
- OBS-6: setup-user-hooks.sh bugs
- OBS-7: nobulai.tools data pipeline description
- OBS-8: Provenance tables not created (incorrect -- they existed)
- OBS-9: Staleness blast radius (3 fully stale, 5 partially stale)
- OBS-10: aitools vs harness terminology
- OBS-11: Commander feedback items
- OBS-12: Batch DB operations critical
- OBS-13-17: Duplicates/restatements of earlier findings

**4 decisions** (all operating principle decisions):
- D-CONTEXT-PRECIOUS and D-CONTEXT-PRESERVE (duplicates): Main context for synthesis only
- D-FLAT-ORG: Flat delegation organization
- D-MC-PREREQUISITE: Reviews go through mission control

### Status

- Session status: active (never ended -- no SessionEnd hook fired)
- Schwerpunkt: unspecified (never set)
- Messages: 0 (confirming it's not a real Claude Code session)
- Scratch directory: `.scratch/session-d3dae79d-9/` exists but is empty

### Corrective actions needed

1. End the phantom session (`harness-db.py session end --id d3dae79d-9`)
2. Decide whether to migrate the 21 entries to 2d439e32-3.db or annotate them as belonging there
3. Fix `.scratch/.current-session` to point to the correct session or remove it
4. Root-cause: prevent scratch-init.sh from creating phantom sessions when a session is already active

---

## Vercel Deployment Audit

18 production deployments to nobulai.tools occurred during this session, spanning approximately 7 hours. All deployments:

- Targeted the same Vercel project (nobul/mission-control-deploy, prj_YCZBY1wSiHzH1r0cmNNct1Csr3yv)
- Deployed to production (--prod flag)
- Completed successfully (all show "Ready" status)
- Deploy time: 3-14 seconds each

**Were any based on stale or incorrect data?**

The deployments fall into three phases:

1. **Early deployments (6-7h ago)**: Deployed from session c0dc2ddc-f data. These showed the PRIOR session's data -- stale relative to the current session but correct for the data they contained.

2. **Mid-session deployments (3-4h ago)**: Deployed after export-mission-control.py was updated with feedback form support. These showed current session data (2d439e32-3) with all data gaps (0 delegations, 0 missions, 0 completed work). Data was accurate for what was in the DB.

3. **Late deployments (7-41min ago)**: Post-audit deployments with full current data. These are current.

**Verdict**: No deployment was based on INCORRECT data. Some were based on INCOMPLETE data (missing the phantom session entries and the write-side hook gaps), but the data they showed was accurate. The dashboard correctly reflects what's in the session DB.

---

## Committed Code Audit

### Commit 924b380: Fix hook deployment pipeline
- Based on correct understanding (setup-user-hooks.sh was genuinely broken)
- Protected file: Yes (scripts/setup-user-hooks.sh/.ps1, settings.json manipulation)
- Review process: Fix was developed and applied based on diagnosed bugs
- No incorrect assumptions in the commit itself
- **Verdict**: CLEAN

### Commit 8a5e869: Harvest 49 session artifacts
- Based on correct understanding (artifacts from c0dc2ddc-f needed harvesting)
- Protected file: Yes (harvesting/harvest-manifest.json)
- 49 artifacts were correctly classified and harvested
- **Verdict**: CLEAN (the artifacts themselves may have stale content from c0dc2ddc-f, but the harvesting process was correct)

### Commit 934d50c: Rebuild deploy/ and add command-channel-stop.sh hook
- Based on PARTIALLY incorrect understanding -- the hook was committed but not registered in the deployment pipeline (IA-8)
- The hook source code is correct; the deployment gap is the issue
- **Verdict**: PARTIAL -- hook code is sound, but the commit is incomplete without the registration step

### Commit d33fcf3: v0.67.1 release notes
- Based on correct understanding of what was shipped
- Protected file: Yes (RELEASE_NOTES.md)
- **Verdict**: CLEAN

### Commit 40951fc: Define Provenance as 6th harness component (UNPUSHED)
- Based on partially incorrect review process (IA-3, IA-11)
- Protected files: CLAUDE.md, reference/harness.md, reference/framework-provenance.md (new)
- Content is factually sound but:
  - Review gate was not cleanly satisfied (IA-3)
  - framework-provenance.md has dangling scratch cross-references (F-3)
  - The "Agent Operating Principles" section from the proposal was NOT included (reducing blast radius)
- **Verdict**: NEEDS REVIEW before push. Content is good; process was irregular; cross-references need fixing.

---

## Summary Table

| ID | Incorrect Assumption | Blast Radius | Corrected? |
|----|---------------------|-------------|------------|
| IA-1 | Delegates have limited permissions | CONTAINED | Yes (OBS-24) |
| IA-2 | Consolidated OL from c0dc2ddc-f was reliable | LOW | Partially (OBS-7) |
| IA-3 | "Both are orders" = approval to ship | MEDIUM | Partially (OL-23, commit unpushed) |
| IA-4 | 5 known issues = everything wrong | LOW | Yes (OL-19) |
| IA-5 | harness-db.py writes to current session | HIGH | Partially (OBS-9, data not migrated) |
| IA-6 | Bandit missions are valid | LOW-MEDIUM | Yes (OL-20) |
| IA-7 | Provenance tables don't exist | ZERO | Yes (self-corrected) |
| IA-8 | Hook pipeline was working | MEDIUM | Partially (924b380, F-1 open) |
| IA-9 | Export shows complete session data | LOW | Documented, not fixed |
| IA-10 | Local dashboard serving current data | ZERO | Yes (zombie killed) |
| IA-11 | Provenance commit was properly reviewed | LOW | No (commit unpushed) |
| IA-12 | Web portal proposal was current | ZERO | Yes (rewritten) |
| IA-13 | harness-db.py `ol add` works | LOW | No (F-10 filed) |

---

## Outstanding Corrective Actions

### Must-fix (before pushing or starting next session)

1. **Fix `.scratch/.current-session`** -- currently points to phantom session d3dae79d-9. Must point to active session or be removed.

2. **End phantom session d3dae79d-9** -- run `harness-db.py session end --id d3dae79d-9` so it doesn't interfere with future sessions.

3. **Review commit 40951fc before pushing** -- the provenance content is sound, but:
   - Fix dangling cross-references in framework-provenance.md (lines 222-227) -- either harvest the referenced scratch files or remove the references
   - Get explicit commander approval for the 3 protected file changes
   - Run CI after push

4. **Register command-channel-stop.sh** -- add to setup-user-hooks.sh/.ps1 deployment pipeline so the hook actually deploys and fires. Currently inert (F-1 HIGH).

### Should-fix (next session)

5. **Migrate phantom session data** -- the 17 observations and 4 decisions in d3dae79d-9.db belong to session 2d439e32-3's work. Either migrate them or document d3dae79d-9 as a satellite DB of this session.

6. **Fix harness-db.py session resolution** -- the tool should prefer CLAUDE_SESSION_ID env var over .current-session file pointer to prevent recurrence of the pointer trap.

7. **Fix `ol add` subcommand** -- either add the operational_learning table to the session DB schema or redirect the subcommand to an existing table (observations with a special category).

### Track (future work)

8. **Write-side hooks for delegation_log, missions, completed_work** -- these tables exist in the schema but nothing writes to them during sessions.

9. **Events table / JSONL pipeline** -- the telemetry rebuild designed event emission but the pipeline is not producing observable output.

10. **Set session schwerpunkt** -- the session ran to completion with schwerpunkt="unspecified". The SessionStart hook or the agent should set this early.

---

## Meta-Observation

This session is itself a demonstration of why provenance tracking matters. The incorrect assumptions propagated through delegation chains: IA-5 (wrong session pointer) cascaded through at least 3 delegate invocations before being detected. IA-3 (misinterpreted approval) led to a commit of protected files. IA-2 (stale OL) influenced the framing of the provenance framework document.

The provenance system being built in this session (reference/framework-provenance.md) is designed to catch exactly these patterns: tracking what decisions were based on, flagging when the basis is invalidated, and recording known contradictions. The session's own failures are the validation data for the system it produced.

---

**Investigation completed**: 2026-03-26T01:15Z
**Method**: Direct DB queries (session 2d439e32-3.db, phantom d3dae79d-9.db, harness.db), all 20 delegate work product files, 5 git commits with diffs, 18 Vercel deployments, full audit report cross-reference
