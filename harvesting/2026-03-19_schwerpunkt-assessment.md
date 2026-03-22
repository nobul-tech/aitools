# Schwerpunkt Assessment: Handoff Prompt Feasibility

**Assessor**: S2 (Intelligence)
**Date**: 2026-03-18
**Schwerpunkt under assessment**: "Produce a verified and thoroughly tested
handoff prompt that captures everything from this session, enabling a fresh
session to continue with clear context."

---

## 1. Lagebeurteilung (Structured Situation Assessment)

### 1.1 Forces (What We Have)

**Committed work (5 commits, shipped)**:
- Governed-data bypass fixes: 28 JSON paths removed across 10 files (d534f3c)
- Incident #50 filed: sources-of-truth.md bypass vectors (d534f3c)
- Harness definition update: CLAUDE.md, harness.md, glossary.json (d534f3c)
- Reading order fix: 6 missing decisions, phase 13 eliminated (66d7351)
- Decision #54 integration into planning brief + handoff prompt (a77beb4)
- Handoff prompt v0.62.0 session continuity update (43c1b41)
- v0.62.1 release notes (c3dd426)

**Uncommitted work (31 scratch files)**:
- 20 markdown investigation/audit/decision documents (harvestable)
- 11 scripts/tools (ephemeral)
- Modified: `harvesting/harvest-manifest.json`
- 34 new files in `harvesting/` (from prior session harvests, untracked)

**Approved decisions (10, not yet implemented)**:
- D-BRIEFINGS: `.aitools/briefings/` location
- D-PROMOTION: governed term, Option 3 with 3 amendments
- D-REPO-PROJECT: governed terms for "repo" and "project"
- D-CARRY-FORWARD: two-layer principle (C+A hybrid)
- D-ARTIFACT-ROLES: dedicated `/artifact-roles` skill (Option 1)
- D1: post-push investigation (COMPLETED)
- D2: bash 3.2 heredoc bug fix (briefing ready)
- D3: BSD paste fix, 11 call sites (briefing ready)
- D4: paste compliance check (blocked by D3)

**Intelligence products (new this session)**:
- Provenance deep research: 21 concepts from 6 doctrinal/organizational
  traditions, 5 recommendations, synthesis matrix (47K)
- Carry-forward provenance: 5 phases, 7 user quotes tracing concept evolution
- Carry-forward frameworks: 6 framework intersections, 5 principles
- 3 carry-forward barrier analyses (A: AMEND, B: REJECT, C+A: ACCEPT)
- Q4 lifecycle investigation, Q10 artifact roles, Q4-Q10 ambiguity audit
- Promotion definition draft + audit (approved Option 3)
- Repo/project definition draft
- Artifact-roles tension investigation (Option 1 approved)
- Post-push AAR (3 bugs, parallel fix strategy)
- Post-push fix briefing (2 delegation packages ready)

### 1.2 Terrain (The Environment)

**The handoff target**: A fresh Claude Code session. It starts with:
- CLAUDE.md and all `.claude/rules/*.md` loaded (project rules)
- No conversation history from this session
- Access to the full filesystem (can read any file referenced)
- `.scratch/session-Z1IhGrcgGO/` survives (same repo, not gitignored)

**Context constraints**:
- The receiving session's context window is finite
- The handoff prompt itself should be readable in one pass
- The receiving session can read scratch files on demand (they persist)
- The receiving session CANNOT read this conversation transcript

**Existing exemplar**: `plans/mission-command-briefing/handoff-prompt.md`
(405 lines, organized in sections A-I). Written for a specific mission
(plan writing). The new handoff is broader (session continuation with
multiple work streams).

### 1.3 Time (Constraints and Deadlines)

- This session is nearing completion
- The harvesting/manifest update is staged but uncommitted
- 34 harvesting files are untracked (from prior session artifacts)
- The scratch files will persist as long as `.scratch/session-Z1IhGrcgGO/`
  exists (gitignored, session-ephemeral, but survives within the same machine)
- No external deadline, but session context is a depleting resource

### 1.4 Logistics (Infrastructure State)

- **Planning brief**: 54 decisions at `plans/mission-command-briefing/planning-brief.json`
  (unchanged this session -- decisions made here are NOT yet in the brief)
- **Handoff prompt**: current version at `plans/mission-command-briefing/handoff-prompt.md`
  was updated this session (commit 43c1b41) for v0.62.0 session continuity
- **harvest-manifest.json**: modified but uncommitted (has entries from this
  session's harvesting cycle)
- **.gitignore**: blocks all `.aitools/` tracking (blanket pattern) -- this
  is a known blocker for namespace consolidation (OT-2)
- **check-post-push.sh**: has 2 active bugs (D2, D3) producing false exits

---

## 2. Reibung Inventory (Friction Analysis)

### 2.1 Critical Friction

| # | Friction | Severity | Mitigation |
|---|---------|----------|------------|
| R1 | **31 scratch files cannot be directly inlined** -- the handoff would be 200K+ tokens if all investigation content were embedded | Critical | Reference by path. Scratch files persist on disk. Provide a reading guide (what each file contains, when to read it) |
| R2 | **10 approved decisions exist only in scratch files** -- they are not in the planning brief, not in any committed file, not in any rule. If the scratch directory is lost, these decisions are lost | Critical | The handoff must list every decision with enough detail to reconstruct it. The scratch files provide depth; the handoff provides the essential content |
| R3 | **The existing handoff prompt is mission-specific** (plan writing). This handoff is broader (session continuation with 6+ parallel work streams) | High | Different structure needed. The existing handoff is a good format reference but the content organization must change |
| R4 | **Provenance research (47K) is too large to inline but too valuable to just reference** -- it contains 21 new concepts the next session needs to know about | High | Inline the synthesis matrix (section 6) and top 5 recommendations (section 7). Reference the full file for depth |
| R5 | **Dependency graph has blocking relationships** -- D-PROMOTION blocks Q4, OT-2 blocks namespace consolidation, D3 blocks D4 | Medium | Include dependency graph in handoff. Receiving session can parallelize non-blocking work |

### 2.2 Moderate Friction

| # | Friction | Severity | Mitigation |
|---|---------|----------|------------|
| R6 | **12 open threads with varying completion states** -- the receiving session must understand which are actionable vs blocked vs deferred | Medium | Classify each thread: READY (can execute now), BLOCKED (state dependency), DEFERRED (not priority) |
| R7 | **Receiving session won't have user preference calibration** from this 2-day session (26 user signals cataloged) | Medium | Include key user signals in the handoff (the 5 signal categories from findings-index F15) |
| R8 | **The planning brief needs amendments** from this session's decisions but the amendments are not yet written | Medium | List the amendments needed. The receiving session can apply them via /brief skill |
| R9 | **Two bug-fix briefings are ready but not executed** -- D2 and D3 are self-contained delegation packages | Low | Include briefing references. Receiving session can launch sub-agents with these packages |
| R10 | **harvest-manifest.json is modified but uncommitted** -- 34 harvesting files are untracked | Low | Either commit before handoff or document the state in the handoff |

### 2.3 Low Friction

| # | Friction | Severity | Mitigation |
|---|---------|----------|------------|
| R11 | **Session chain is now 7 sessions deep** -- context from sessions 84280c8b through Z1IhGrcgGO | Low | Session chain table in handoff. Most context is in the brief and scratch files |
| R12 | **Some scratch files have superseded content** -- early investigations were refined by later ones | Low | Mark supersession in the reading guide |

---

## 3. Schwerpunkt Verification

### 3.1 Is the Schwerpunkt achievable?

**Yes, with a structural decision.**

The core tension: a single handoff prompt cannot inline 200K+ of investigation
content, but a handoff that only references files risks the receiving session
skipping critical context. The resolution is a **layered handoff**:

1. **Layer 1 (in the handoff itself)**: Everything the receiving session needs
   to know WITHOUT reading any other file -- decisions made, their essential
   content, the dependency graph, what to do first, what NOT to do
2. **Layer 2 (referenced files)**: Full investigation depth, provenance
   research, barrier analyses, definition drafts -- read on demand when
   executing specific work streams
3. **Layer 3 (background)**: The planning brief, session transcripts, framework
   references -- the receiving session reads these only if it needs to trace
   a decision's origin

This matches how the existing handoff prompt works: sections A-G provide the
essential content; section B lists files to read for depth.

### 3.2 What must happen FIRST?

**Three prerequisites before the handoff can be written:**

1. **Harvest decision**: The 20 harvestable scratch files should be harvested
   (moved to `harvesting/` with manifest entries) BEFORE the handoff is
   written. Rationale: harvested files have stable paths (`harvesting/YYYY-MM-DD_name.md`)
   while scratch files have session-scoped paths (`.scratch/session-Z1IhGrcgGO/name.md`).
   If the session directory is cleaned up, scratch references break; harvesting
   references persist. The handoff should reference harvested paths, not
   scratch paths.

   **HOWEVER**: The current `.scratch/` session directories are NOT automatically
   cleaned up between sessions -- they persist on disk. And the SessionEnd hook
   handles harvesting. So the handoff CAN reference scratch paths safely if we
   accept the coupling to this specific session directory.

   **Recommendation**: Reference scratch paths in the handoff. The SessionEnd
   hook will harvest the qualifying files. The handoff references will still
   work because the harvested copies at `harvesting/YYYY-MM-DD_name.md` will
   also exist. This avoids a blocking dependency on harvesting before the
   handoff can be written.

2. **Commit the harvest-manifest.json changes**: The modified manifest should
   be committed (or the handoff should note it is uncommitted). This is a minor
   prerequisite -- the receiving session can handle uncommitted state.

3. **Decide the handoff location**: The existing handoff is at
   `plans/mission-command-briefing/handoff-prompt.md`. Per the D-BRIEFINGS
   decision, briefings should live at `.aitools/briefings/`. But `.aitools/`
   is currently gitignored (OT-2 blocker). Options:
   - Write to `plans/mission-command-briefing/` (current location, tracked)
   - Write to `.aitools/briefings/` (approved location, currently gitignored)
   - Write to `.scratch/` (ephemeral, but available immediately)

   **Recommendation**: Write to `plans/mission-command-briefing/` as an update
   to the existing handoff prompt. This is the known location, it is tracked in
   git, and the receiving session will find it at the same path referenced in
   the session chain. The migration to `.aitools/briefings/` is part of the
   namespace consolidation work that the NEXT session will execute -- the
   handoff should not depend on infrastructure it documents as TODO.

---

## 4. Prerequisites Checklist

| # | Prerequisite | Status | Blocking? |
|---|-------------|--------|-----------|
| P1 | Read and catalog all 31 scratch files | DONE (this assessment) | Yes -- needed to write section 5 |
| P2 | Identify which decisions are essential for Layer 1 (inline) | DONE (this assessment) | Yes |
| P3 | Determine handoff location | RECOMMENDED: `plans/mission-command-briefing/handoff-prompt.md` (update existing) | Yes |
| P4 | Commit harvest-manifest.json | NOT DONE -- can proceed without, note in handoff | No |
| P5 | Harvest scratch files | NOT NEEDED before handoff -- SessionEnd hook handles it, paths persist | No |
| P6 | Decide whether to amend the planning brief first | RECOMMENDED: No. List amendments in handoff. Next session applies them | No |

---

## 5. Handoff Structure Proposal

The handoff should update `plans/mission-command-briefing/handoff-prompt.md`
with a new version that replaces the plan-writing-specific content with
session-continuation content. The existing structure (A-I) provides the
template; the content changes substantially.

### Proposed sections:

#### A. Session Chain (updated)

Add session Z1IhGrcgGO to the chain table. Document what this session
produced (parallel to section C2 in the existing handoff for session
RTzBnBupE6).

What this session built:
- 5 commits (governed-data fixes, incident #50, harness update, reading order,
  decision #54, handoff update, release notes)
- 10 approved decisions (D-BRIEFINGS, D-PROMOTION, D-REPO-PROJECT,
  D-CARRY-FORWARD, D-ARTIFACT-ROLES, D1-D4)
- 17 findings (F1-F17), 13 recommendations (7 completed)
- 20 investigation/audit documents
- 1 deep provenance research (21 concepts, 5 recommendations)
- 3 barrier analyses on carry-forward principle
- Post-push AAR + fix briefing

#### B. Intelligence Products (updated)

Replace RTzBnBupE6's investigation list with Z1IhGrcgGO's investigation
artifacts. Organized by work stream:

**Governance audit work stream**:
- `rule-effectiveness-audit.md` -- three-layer coverage for all 23 rules
- `intent-audit-findings.md` -- 14 rules missing intent, 6 skills
- `intent-heuristic-findings.md` -- recency-weighting gap in intent skills
- `governed-data-investigation.md` -- step 16 reclassification evidence
- `findings-index.md` -- master index of all 17 findings

**Artifact lifecycle work stream**:
- `q4-lifecycle-investigation.md` -- 5 artifact types, 4 lifecycle stages
- `q10-artifact-roles-investigation.md` -- 5 type MUST/MUST NOT definitions
- `q4-q10-ambiguity-audit.md` -- 3 blockers, 15 should-resolve
- `promotion-definition-draft.md` + `promotion-definition-audit.md` -- Option 3
- `repo-project-definition-draft.md` -- governed term drafts
- `artifact-roles-tension-investigation.md` -- harness.md vs Q10 resolved

**Carry-forward work stream**:
- `carry-forward-provenance.md` -- 5 phases, 7 user quotes
- `carry-forward-frameworks.md` -- 6 framework intersections, 5 principles
- `carry-forward-barrier-A.md` -- AMEND ("persisted... survives machine switches")
- `carry-forward-barrier-B.md` -- REJECT ("repo's backing storage")
- `carry-forward-barrier-C.md` -- ACCEPT+AMEND (explicit per-mechanism guidance)
- `briefings-location-decision.md` -- formal capture + .gitignore blocker

**Post-push remediation work stream**:
- `s2-post-push-aar.md` -- 3 bugs, RCA, 5-Whys for each
- `post-push-fix-briefing.md` -- delegation packages for D2 + D3

**Provenance research**:
- `provenance-deep-research.md` -- 21 concepts, 5 recommendations, synthesis matrix

#### C. Decisions Made This Session (NEW -- essential for Layer 1)

For each of the 10 decisions: the decision statement, the key rationale
(1-2 sentences), what it amends (if anything), and the next action. This
is the critical Layer 1 content -- a receiving session must have these
decisions WITHOUT reading any scratch file.

Include:
- **D-BRIEFINGS**: `.aitools/briefings/`. Amends decision #34. Blocked by OT-2 (.gitignore)
- **D-PROMOTION**: Option 3 with 3 amendments. Unblocks Q4 blocker #1
- **D-REPO-PROJECT**: "repo" = any OS folder; "project" = body of work
- **D-CARRY-FORWARD**: C+A hybrid (per-mechanism guidance). Replace workspace rule L19-29
- **D-ARTIFACT-ROLES**: Dedicated `/artifact-roles` skill (Option 1). 4 artifacts to build
- **D2**: Bash 3.2 heredoc fix (write-then-execute). Self-contained delegation
- **D3**: BSD paste fix (11 sites). Self-contained delegation
- **D4**: Paste compliance check. After D3

#### D. Open Threads (updated from session-state-audit)

The 12 open threads from the session-state-audit, each classified:
- READY: can execute immediately
- BLOCKED: dependency must be resolved first
- DEFERRED: not priority for next session

#### E. Dependency Graph (NEW)

The dependency graph from session-state-audit section 2, with
parallel groups identified. This tells the receiving session what
can run concurrently and what must be sequenced.

#### F. Schwerpunkt for Next Session (NEW -- see section 6 of this assessment)

The single most important objective for the next session, with
exclusion clauses.

#### G. Planning Brief Amendments Needed (NEW)

List of amendments to the planning brief that this session's decisions
require. The receiving session applies these via /brief skill before
proceeding with plan writing.

- Add D-BRIEFINGS to decision #34 (component 14)
- Amend carry-forward principle in decisions that reference git-only tracking
- Note D-ARTIFACT-ROLES creates artifacts not currently in any brief decision
- Note D-PROMOTION resolves Q4 blocker #1

#### H. Provenance Research Summary (NEW)

Inline the synthesis matrix (section 6) and top 5 recommendations
(section 7) from `provenance-deep-research.md`. This gives the
receiving session awareness of the 21 new concepts without reading
the full 47K file.

#### I. What NOT to Do (NEW -- exclusion clauses)

Explicit scope governance for the next session. See section 7 of this
assessment.

#### J. Plan-Writing Protocol (carried forward from existing handoff)

Sections E and F of the existing handoff (plan-writing protocol,
Plan Writer delegation template) remain valid and should be carried
forward. The plan has not been written yet.

#### K. Provenance (updated)

Version history of the handoff prompt.

---

## 6. Recommended Schwerpunkt for the NEXT Session

### The Schwerpunkt

**Implement the approved decisions that unblock the plan-writing mission.**

The plan-writing mission (writing `plans/mission-command-and-platform-engineering.md`)
is the overarching objective from the prior sessions. This session's
investigations resolved foundational questions that were blocking the plan.
The next session's Schwerpunkt is: execute the decisions that unblock plan
writing, then write the plan.

### Priority sequence

**Wave 1 -- Foundation (unblock everything)**:
1. File D-PROMOTION via /glossary (unblocks Q4 blocker #1)
2. File D-REPO-PROJECT via /glossary (closes 5 should-resolve findings)
3. Fix OT-2: replace `.gitignore` blanket with selective patterns (unblocks
   namespace consolidation)
4. Execute D2 + D3 via parallel sub-agents (fix shipped bugs)

**Wave 2 -- Amendments**:
5. Amend planning brief with this session's decisions (via /brief skill)
6. Draft carry-forward principle replacement (OT-3) for workspace rule
7. Amend workspace rule: add briefings row, carry-forward principle, column rename

**Wave 3 -- Plan writing**:
8. Write `plans/mission-command-and-platform-engineering.md` per the protocol
   in the handoff prompt (sections E-F of existing, section J of proposed)

### Why this sequence

- Wave 1 items are small, independent, and unblock downstream work
- Wave 2 items update governing documents so the plan reflects current decisions
- Wave 3 is the original mission, now unblocked
- D-ARTIFACT-ROLES (4 artifacts) is deliberately NOT in this sequence -- it is
  plan-scale work that should be a plan batch, not pre-plan work

---

## 7. Exclusion Clauses (What the Next Session Must NOT Do)

These are explicit scope boundaries for the next session. Any work outside
these boundaries requires a formal decision (FRAGORD) with documented
rationale.

### Hard exclusions

1. **Do NOT start the namespace consolidation migration** (moving `harvesting/`
   to `.aitools/harvesting/`, moving `plans/mission-command-briefing/` to
   `.aitools/briefings/`). Fix the `.gitignore` blocker (Wave 1 item 3) but
   defer the actual file migration to a plan batch. The migration affects 59+
   file references and requires careful sequencing.

2. **Do NOT build the artifact-roles skill and rule** (D-ARTIFACT-ROLES).
   This is plan-scale work requiring 4 artifacts (rule, skill, reference,
   hook). It belongs in the plan, not as pre-plan work. The approved decision
   (Option 1) is documented; the implementation waits for the plan.

3. **Do NOT overhaul sources-of-truth.md** (Incident #50, OT-7). This needs
   a barrier analysis before execution. It is a high-severity incident but
   not blocking plan writing. It was explicitly marked "NOT now" in the
   session-state-audit.

4. **Do NOT start the registries directory migration** (R12, moving governed
   JSON files from `reference/` to `registries/`). This affects 59 files
   and needs its own plan. It was explicitly deferred this session.

5. **Do NOT adopt new frameworks from the provenance research** during the
   next session. The research identifies 5 high-leverage concepts
   (Schwerpunkt, A3, Catchball, Cynefin, Lagebeurteilung). These are
   candidates for future adoption via the framework adoption lifecycle,
   not for immediate implementation. The next session may USE concepts
   informally (e.g., applying Schwerpunkt thinking to scope decisions)
   but must not create new framework artifacts without a plan.

### Soft exclusions (allowed if naturally encountered, but do not seek out)

6. **Intent backfill** (R4, 14 rules + 6 skills missing intents). Only add
   intents to files being edited for other reasons. Do not run a dedicated
   intent-backfill campaign during this session.

7. **Recency heuristic provenance research** (OT-5). Only continue this
   research if it directly supports plan writing. Do not pursue as an
   independent work stream.

8. **Observe-mode promotion review** (R6, 1003 log entries). Analyze only
   if hook enforcement changes are part of a plan batch.

### What IS in scope

- The 3 waves defined in section 6 (foundation, amendments, plan writing)
- Bug fixes D2 + D3 (these fix shipped, broken code -- always in scope)
- Filing incidents if ambiguities are discovered (surfacing duty is always on)
- Using provenance concepts informally (Schwerpunkt, Reibung, Mitdenken)
  as thinking tools without formalizing them as frameworks

---

## 8. Assessment Summary

### Verdict: Schwerpunkt is ACHIEVABLE

The handoff prompt can capture this session's work product. The key structural
decisions:

1. **Layered approach**: Essential decisions inline (Layer 1), investigation
   depth by reference (Layer 2), background context by reference (Layer 3)
2. **Reference scratch paths**: The files persist on disk. The SessionEnd hook
   will also harvest qualifying files to `harvesting/`. Both paths work.
3. **Update existing handoff**: Write to `plans/mission-command-briefing/handoff-prompt.md`
   (tracked, known location). Namespace migration is future work.
4. **No prerequisites block the handoff**: Harvesting, manifest commits, and
   brief amendments can all happen AFTER the handoff is written.

### Risk register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Scratch directory cleaned up before next session reads it | Low | High | Harvest qualifying files. Also: scratch dirs are NOT auto-cleaned between sessions |
| Next session ignores exclusion clauses | Medium | Medium | Exclusions are explicit and justified. The Schwerpunkt provides positive focus |
| Plan-writing protocol is stale (written 2 sessions ago) | Low | Medium | Review protocol sections during plan writing. Amend via FRAGORD if needed |
| 54 decisions + 10 new decisions overwhelm the receiving session | Medium | Medium | The Schwerpunkt directs focus. Wave 1 is 4 small items. Complexity is sequenced |
| This assessment's recommendations are ignored | Low | Low | The assessment is referenced by the handoff. Its structure (prerequisites, exclusions) is actionable without reading the full text |

---

## Appendix: Scratch File Reading Guide

For the receiving session. Read on demand, not all at once.

### Governance audit (read if working on governance or check scripts)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `rule-effectiveness-audit.md` | Three-layer coverage map for 23 rules, hook test results | -- |
| `intent-audit-findings.md` | 14 rules missing intent, 6 skills, coverage gaps | -- |
| `intent-heuristic-findings.md` | Recency-weighting gap, user signal catalog | -- |
| `governed-data-investigation.md` | Step 16 reclassification evidence, live bypass demo | -- |
| `findings-index.md` | Master index: 17 findings, 13 recommendations, status | -- |

### Artifact lifecycle (read if working on Q4, promotion, artifact-roles)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `q4-lifecycle-investigation.md` | 5 artifact types, 4 stages, path analysis | -- |
| `q10-artifact-roles-investigation.md` | 5 type MUST/MUST NOT, 3 options, hook design | `artifact-roles-tension-investigation.md` (Option 1 wins) |
| `q4-q10-ambiguity-audit.md` | 3 blockers, 15 should-resolve, decision refs | -- |
| `promotion-definition-draft.md` | Option 3 definition with 5 meanings inventory | -- |
| `promotion-definition-audit.md` | Audit of Option 3, 3 amendments needed | -- |
| `repo-project-definition-draft.md` | Governed vocab drafts for "repo" and "project" | -- |
| `artifact-roles-tension-investigation.md` | harness.md vs Q10 resolved: Option 1 wins | -- |
| `briefings-location-decision.md` | Formal capture, .gitignore blocker, Q4 amendments | -- |

### Carry-forward (read if working on workspace rule or carry-forward)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `carry-forward-provenance.md` | 5 phases, 7 user quotes tracing concept evolution | -- |
| `carry-forward-frameworks.md` | 6 framework intersections, 5 principles | -- |
| `carry-forward-barrier-A.md` | "survives machine switches" -- AMEND, mild regression | `carry-forward-barrier-C.md` (C+A wins) |
| `carry-forward-barrier-B.md` | "repo's backing storage" -- REJECT | `carry-forward-barrier-C.md` (C+A wins) |
| `carry-forward-barrier-C.md` | Per-mechanism guidance -- ACCEPT | -- |

### Post-push remediation (read if fixing D2 or D3)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `s2-post-push-aar.md` | 3 bugs, RCA, 5-Whys, fix options | -- |
| `post-push-fix-briefing.md` | Delegation packages for D2 + D3, verification criteria | -- |

### Provenance (read if adopting frameworks or working on scope governance)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `provenance-deep-research.md` | 21 concepts, 6 traditions, synthesis matrix, 5 recs | -- |

### Session state (reference material)
| File | What it contains | Superseded by |
|------|-----------------|---------------|
| `session-state-audit.md` | Complete status: done, decided, open, blocked, metrics | This assessment (section 1) |
