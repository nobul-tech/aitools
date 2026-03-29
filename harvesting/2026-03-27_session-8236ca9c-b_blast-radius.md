# Blast Radius Assessment

**Mission Commander**: blast-radius (executed by assessment-lead)
**Session**: 8236ca9c | **Date**: 2026-03-26
**Failure mode boundary**: 12:50Z March 25 2026 (05:50 AM local PDT)

---

## Commit Classification

All 74 commits from March 14-25 classified by failure mode boundary.

### PRE-FAILURE (before 12:50Z March 25) -- TRUSTED

All commits on March 14-22 are from separate sessions, definitively pre-failure.

March 24 commits (session c0dc2ddc-f started ~01:54Z March 25 = 6:54 PM local March 24):
- These are early in session c0dc2ddc-f when delegation scores were still 5/6.
- All March 24 commits are PRE-FAILURE.

| Commit | Date (local) | Summary |
|--------|-------------|---------|
| f38e555 | Mar 24 18:51 | v0.66.0 release notes |
| 33bbc25 | Mar 24 18:44 | Ship intent-sentinel + delegation-duty-guard hooks |
| 517cbd7 | Mar 24 17:57 | Fix USO violation: stop suppressing stderr |
| 154fd46 | Mar 24 17:56 | Promote standing-order-guard checks to enforce |
| ... | Mar 24 earlier | 8 more commits (CI, skills, SQLite, dashboard) |
| ... | Mar 14-22 | 40+ commits across multiple sessions |

**Total PRE-FAILURE**: ~55 commits. All trusted.

### FAILURE-MODE (after 12:50Z March 25) -- SUSPECT

All March 25 commits are after the boundary (earliest at 08:19 local = 15:19Z, well after 12:50Z).

| Commit | Date (local) | UTC | Summary | Risk |
|--------|-------------|-----|---------|------|
| afd4c67 | 08:19 | 15:19Z | Fix CI: CLAUDE_EFFORT_LEVEL guard | LOW -- trivial fix |
| ca4d918 | 08:38 | 15:38Z | Rebuild deploy/ | LOW -- generated |
| 21f9344 | 09:57 | 16:57Z | Register harness-db hooks in settings.json | MEDIUM -- pipeline change |
| e75b107 | 09:57 | 16:57Z | Update harvest manifest | LOW -- data update |
| a417ae7 | 09:58 | 16:58Z | Add harvested artifacts | LOW -- artifact copy |
| 8c1441e | 09:58 | 16:58Z | Add harness state files and handoff plan | LOW -- state files |
| 1636ff1 | 09:58 | 16:58Z | v0.66.1 release notes | LOW -- documentation |
| 3a8a1bf-6f29196 | 10:02-10:10 | 17:02-17:10Z | 4 CI fixes | LOW -- CI-only |
| e070043 | 14:18 | 21:18Z | **TELEMETRY REBUILD** | **HIGH** -- deleted 3 Stop hooks, rewrote event pipeline |
| ceda9db | 14:19 | 21:19Z | Rebuild deploy/ after telemetry | LOW -- generated |
| b3ebc66 | 14:19 | 21:19Z | v0.67.0 release notes | LOW -- documentation |
| d395d50 | 15:05 | 22:05Z | harness-db.py lean CLI subcommands | MEDIUM -- new functionality |
| ef572f0 | 15:49 | 22:49Z | Fix harness-db.py context consumption | LOW -- bug fix |
| 0e01902 | 15:49 | 22:49Z | Add provenance schema + rewind-aware /aitool-continue | MEDIUM -- schema change |
| 924b380 | 17:00 | 00:00Z+1 | Fix hook pipeline: remove stale refs | **HIGH** -- pipeline fix |
| 8a5e869 | 17:23 | 00:23Z+1 | Harvest 49 artifacts | LOW -- artifact copy |
| 934d50c | 17:23 | 00:23Z+1 | Rebuild deploy/ + add command-channel-stop.sh | MEDIUM -- new hook |
| d33fcf3 | 17:23 | 00:23Z+1 | v0.67.1 release notes | LOW -- documentation |
| 40951fc | 17:27 | 00:27Z+1 | **Define Provenance as 6th component** | **HIGH** -- 3 protected files, UNPUSHED |

**Total FAILURE-MODE**: 19 commits. 3 rated HIGH risk.

### POST-FAILURE (session 8236ca9c, March 26) -- IN PROGRESS

No commits from this session. 2 new hook files written to shared/hooks/ but not committed:
- failure-mode-identity-stop.sh (created Mar 26 12:05)
- failure-mode-verify-stop.sh (created Mar 26 12:05)

---

## File Modification Analysis

### Repo-level artifacts modified during failure mode (March 25)

**shared/hooks/** (source):
- block-claude-code-guide.sh: Mar 25 11:43 -- FAILURE-MODE
- command-channel-stop.sh: Mar 25 17:18 -- FAILURE-MODE (NEW)
- delegation-duty-guard.sh: Mar 25 11:42 -- FAILURE-MODE
- glossary-skill-guard.sh: Mar 25 11:43 -- FAILURE-MODE
- harness-db-sessionend.sh: Mar 25 11:46 -- FAILURE-MODE
- sh-file-fixup.sh: Mar 25 11:42 -- FAILURE-MODE
- standing-order-guard.sh: Mar 25 11:42 -- FAILURE-MODE

Hooks NOT modified during failure mode (pre-failure):
- dashboard-serve.sh: Mar 21 -- PRE-FAILURE
- harness-db-sessionstart.sh: Mar 24 -- PRE-FAILURE
- harvest-session.sh: Mar 24 -- PRE-FAILURE
- scratch-init.sh: Mar 24 -- PRE-FAILURE
- session-archive.sh: Mar 24 -- PRE-FAILURE
- tool-ops-session-audit.sh: Mar 15 -- PRE-FAILURE

**scripts/**:
- build-deploy.sh: Mar 25 11:47 -- FAILURE-MODE
- harness-db.py: Mar 25 17:16 -- FAILURE-MODE
- setup-user-hooks.sh: Mar 25 16:59 -- FAILURE-MODE
- setup-user-hooks.ps1: Mar 25 16:59 -- FAILURE-MODE
- Most other scripts: Mar 24 or earlier -- PRE-FAILURE

**reference/**:
- framework-provenance.md: Mar 25 17:26 -- FAILURE-MODE (NEW, in unpushed commit)
- harness-db-schema.sql: Mar 25 14:37 -- FAILURE-MODE
- harness.md: Mar 25 17:24 -- FAILURE-MODE (modified in unpushed commit)
- tool-ops-claude-code.md: Mar 24 14:39 -- PRE-FAILURE

**.claude/rules/**:
- ALL rules files are pre-failure (latest: Mar 24 17:31 for aitool-eval.md)
- No rules were modified during failure mode

### User-level artifacts (~/.claude/)

- settings.json: Mar 25 17:23 -- FAILURE-MODE (last written by aitools deploy)
- All deployed hooks: Mar 24-25 -- mix of pre-failure and failure-mode
- .bak files: 11 backup files, growing unbounded (F-9 from handoff)

---

## Artifact Classification

### TRUSTED (pre-failure or verified)

| Category | Count | Notes |
|----------|-------|-------|
| .claude/rules/ | 25 files | All pre-failure (none modified Mar 25+) |
| Pre-failure hooks (source) | 7 of 15 | dashboard-serve, harness-db-sessionstart, harvest-session, scratch-init, session-archive, tool-ops-session-audit + 1 new from this session |
| reference/ (pre-failure) | 42 of 48 | Most reference files unchanged |
| All March 14-24 commits | ~55 | Definitively pre-failure |
| Session DBs: c0dc2ddc-f.db | 1 | 200 messages, ended, pre-failure data valid |
| Dotprofile session archives | 20 | All archived sessions are transcript snapshots |
| Running estimate v1 | 1 | Written this session (POST-FAILURE), verified by V&P MC |
| Verify-and-propose reports | 3 files | Written this session, verified against specs |

### SUSPECT (failure-mode artifacts)

| Artifact | Risk | Verification Status |
|----------|------|-------------------|
| commit e070043 (telemetry rebuild) | HIGH | VERIFIED SOUND -- deleted hooks were genuinely broken (/tmp state), JSONL replacement is better. But introduced Stop hook registration gap. |
| commit 924b380 (hook pipeline fix) | HIGH | VERIFIED SOUND -- correctly removed undefined variables. But failed to add command-channel-stop.sh registration. |
| commit 40951fc (provenance framework) | HIGH | PARTIALLY VERIFIED -- content appears sound, but: (1) review gate not cleanly satisfied, (2) dangling cross-refs in framework-provenance.md, (3) UNPUSHED. Needs Commander review. |
| command-channel-stop.sh | MEDIUM | VERIFIED SOUND by V&P MC -- structurally correct, valid JSONL output. Registration gap is the issue. |
| harness-db.py modifications | MEDIUM | PARTIALLY VERIFIED -- lean CLI subcommands work (tested via `status` command). Full verification would require testing all subcommands. |
| harness-db-schema.sql | MEDIUM | VERIFIED -- schema is used by harness.db which has valid tables and data. |
| settings.json | LOW | VERIFIED -- 12 hooks registered across 4 events, all match source. Zero Stop hooks is a gap, not corruption. |
| build-deploy.sh | LOW | Generated output -- rebuild resolves. |
| setup-user-hooks.sh/.ps1 | MEDIUM | PARTIALLY VERIFIED -- correctly registers 12 hooks. Missing Stop hook registration is a known gap, not corruption. |
| 49 harvested artifacts | LOW | Artifact copies -- source was pre-failure sessions. Metadata may be imprecise but artifacts are safe. |

### UNTESTED (this session, in progress)

| Artifact | Notes |
|----------|-------|
| failure-mode-identity-stop.sh | Written this session. V&P MC verified against 10 specs. Not committed. Not registered. |
| failure-mode-verify-stop.sh | Written this session. V&P MC verified. Not committed. Not registered. |
| This assessment | In progress. |
| Session DB 8236ca9c-b.db | Active, currently empty (0 messages, no observations/decisions). |

---

## Hook Modification Check (Phase 5)

### scratch-init.sh
- **Modified during failure mode?** NO. Last modified Mar 24 17:51 (pre-failure).
- **Does it delete work product?** NO. Explicitly comments: "Previously rm -rf'd here, but that destroyed 30 unharvested artifacts." Only creates new session directories.
- **Does it overwrite .current-session?** YES -- writes the new session's scratch path. This is by design but caused the phantom session hijack (F-2).

### harvest-session.sh
- **Modified during failure mode?** NO. Last modified Mar 24 17:51 (pre-failure).
- **Does it delete work product?** NO. Comments: "No rm -rf of session dirs (30-file-loss fix)." Copies to harvesting/ but does not remove from .scratch/.
- **Does it relocate files?** YES -- copies .scratch/ files to harvesting/ with date + session ID prefix. This is harvesting, not deletion.

### Can we recover anything lost?
- **Git reflog** shows 11 entries since March 25, all forward-moving commits. No resets, no force pushes. No destructive operations.
- **No work product appears lost.** Session scratch directories from c0dc2ddc-f (176 files), 2d439e32-3 (90 files), and 8236ca9c-b (8 files) are all intact.
- The phantom session d3dae79d-9 has minimal scratch (only events.jsonl) but its DB has 21 orphaned entries.

---

## Key Findings

### F-BR1: No catastrophic damage from failure mode
The failure mode produced functional code with registration gaps, not corrupted or destructive code. The 3 HIGH-risk commits are all verifiable:
- e070043: Sound architecture decision (delete broken hooks, add JSONL events), incomplete execution (no Stop hook re-registration)
- 924b380: Correct fix, incomplete scope (didn't add new hooks)
- 40951fc: Content likely sound, process flawed (review gate bypassed)

### F-BR2: The blast radius is concentrated in the Stop hook registration gap
All 3 Stop hooks (command-channel, failure-mode-identity, failure-mode-verify) share the same gap: source tree presence without pipeline registration. This is a single point of failure in the deployment pipeline, not 3 independent bugs.

### F-BR3: Rules were NOT touched during failure mode
All 25 .claude/rules/ files have pre-failure modification times. This means the governance layer is intact. The stale hook-rollout.md (OL-47) predates failure mode -- the code was promoted on Mar 24, but the rule was never updated to match.

### F-BR4: harness.db is NOT empty (contradicts handoff)
The handoff said "0 bytes, no tables." Current state: 98304 bytes, 9 tables, populated data (4 sessions, 30 KPI events, 5 knowledge items, 2 provenance edges, 1 nogood set). Either: (a) the file was recreated by sessionstart hook, or (b) the handoff was wrong and the data was in WAL journal. Observation, not diagnosis.

### F-BR5: Phantom session orphaned data is recoverable
d3dae79d-9.db has 17 observations and 4 decisions. All are content from session 2d439e32-3 that was redirected when .current-session was hijacked. The data is intact and could be migrated to 2d439e32-3.db if desired.

### F-BR6: No deployed hooks were corrupted
All 12 deployed hooks match their source versions exactly (zero drift verified). The hooks that were modified during failure mode (7 of 15 source hooks) were deployed correctly -- the deployment pipeline worked for existing hooks, it just didn't register new ones.
