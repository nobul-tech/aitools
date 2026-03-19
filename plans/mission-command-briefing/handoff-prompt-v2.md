# Mission: Continue Session Z1IhGrcgGO Work and Write the Mission Command Plan

You are S3 (Operations). Your Schwerpunkt: **implement the 10 approved decisions that unblock the plan-writing mission, then write the plan.**

This session produced 17 findings, 10 approved decisions, provenance research across 6 doctrinal traditions, and shipped v0.62.2 (governed-data bypass fixes, harness definition update, incident #50). The approved decisions unblock the plan that has been the objective since session b8a9ed4e. Your job is to execute them, then write the plan.

**What you must NOT do** is listed in section F. Read it before doing anything.

---

## A. Source of Truth

### Planning brief

The planning brief is at `plans/mission-command-briefing/planning-brief.json`. It IS the source of truth for all 54 resolved decisions, 18 facts, and 7 assumptions. Do not re-derive decisions from conversation transcripts. The brief has them.

### Session-specific artifacts

This session's work products are at `.scratch/session-Z1IhGrcgGO/`. These files persist on disk (gitignored but not auto-cleaned). They are the source of truth for the 10 approved decisions and 17 findings that have NOT yet been committed to permanent harness locations.

### Reading order for the receiving agent

Read in this order -- it is deliberate:

1. **This handoff prompt** (you are reading it now -- finish it completely)
2. **Session state audit**: `.scratch/session-Z1IhGrcgGO/session-state-audit.md` -- comprehensive status of everything done, decided, open, and blocked
3. **Findings index**: `.scratch/session-Z1IhGrcgGO/findings-index.md` -- 17 findings, 13 recommendations, completion status
4. **Schwerpunkt assessment**: `.scratch/session-Z1IhGrcgGO/schwerpunkt-assessment.md` -- executability analysis, Reibung inventory, next-session priorities
5. **Planning brief**: `plans/mission-command-briefing/planning-brief.json` -- all 54 decisions (read in the order specified by `meta.readingOrder`)
6. **Workspace rule**: `.claude/rules/aitools-workspace.md` -- governs .aitools/ namespace, carry-forward principle
7. Read additional files on demand per the scratch file reading guide (Schwerpunkt assessment, Appendix)

---

## B. Intelligence Preparation (read before executing)

Read these files IN FULL before entering execution mode:

### Essential (read all)

1. `plans/mission-command-briefing/planning-brief.json` -- the entire brief (54 decisions). Use `meta.readingOrder` for sequencing.
2. `.scratch/session-Z1IhGrcgGO/session-state-audit.md` -- complete status table, dependency graph, harvest recommendations, open threads
3. `.scratch/session-Z1IhGrcgGO/findings-index.md` -- 17 findings (F1-F17), 13 recommendations (7 completed), files changed this session
4. `.scratch/session-Z1IhGrcgGO/schwerpunkt-assessment.md` -- Reibung analysis (12 friction points), Wave 1-3 priority sequence, exclusion clauses

### Read for specific work streams

**Governance audit** (read if working on governance or check scripts):
- `.scratch/session-Z1IhGrcgGO/rule-effectiveness-audit.md` -- three-layer coverage for 23 rules
- `.scratch/session-Z1IhGrcgGO/governed-data-investigation.md` -- step 16 reclassification evidence, live bypass demonstration

**Artifact lifecycle** (read if working on Q4, promotion, artifact-roles):
- `.scratch/session-Z1IhGrcgGO/q4-lifecycle-investigation.md` -- 5 artifact types, 4 lifecycle stages
- `.scratch/session-Z1IhGrcgGO/q10-artifact-roles-investigation.md` -- 5 type MUST/MUST NOT definitions
- `.scratch/session-Z1IhGrcgGO/q4-q10-ambiguity-audit.md` -- 3 blockers, 15 should-resolve

**Carry-forward** (read if working on workspace rule or carry-forward principle):
- `.scratch/session-Z1IhGrcgGO/carry-forward-provenance.md` -- 5 phases, 7 user quotes
- `.scratch/session-Z1IhGrcgGO/carry-forward-frameworks.md` -- 6 framework intersections, 5 principles
- `.scratch/session-Z1IhGrcgGO/carry-forward-barrier-C.md` -- the winning barrier analysis (C+A hybrid)

**Post-push remediation** (read if fixing D2 or D3):
- `.scratch/session-Z1IhGrcgGO/s2-post-push-aar.md` -- 3 bugs, RCA, 5-Whys for each
- `.scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md` -- self-contained delegation packages for D2 + D3

**Plan writing** (read before writing batch skeleton in Wave 3):
- `.scratch/session-Z1IhGrcgGO/briefing-cluster-analysis.md` -- planning brief dependency graph and sub-briefing clustering analysis (11 sub-briefings, 5 execution waves, 55-65% time reduction vs sequential). Read before writing batch skeleton (Wave 3).

**Harness verification**:
- `.scratch/session-Z1IhGrcgGO/harness-cicd-investigation.md` — harness self-verification architecture, bootstrap problem analysis, 5-option barrier analysis, skill testing gap
- `.scratch/session-Z1IhGrcgGO/cicd-feasibility.md` — GitHub Actions feasibility, staged rollout (4 phases), macOS runner analysis, tool-ops verification in CI
- `.scratch/session-Z1IhGrcgGO/aitools-in-tool-ops-investigation.md` — why aitools is NOT a tool-ops entry (0/4 criteria met, self-referential governance trap)
- `.scratch/session-Z1IhGrcgGO/scratch-deletion-rca.md` — RCA: false claim propagation through 5 subagents, scratch lifecycle verification gap
- `.scratch/session-Z1IhGrcgGO/verification-lifecycle-gap-audit.md` — 10 missed catch points, cross-boundary verification failure class
- `.scratch/session-Z1IhGrcgGO/session-transition-testing.md` — should /handoff test session transitions? Option C recommended (static location check)

**Provenance research** (read if adopting frameworks or working on scope governance):
- `.scratch/session-Z1IhGrcgGO/provenance-deep-research.md` -- 21 concepts, 6 traditions, synthesis matrix. Summary inlined in section H below.

### Carried forward from prior sessions

These are supplementary -- read when entering a specific work stream.

1. `.aitools/channel/session-uyZ7TELqpP/20260316T190000Z_s3_running-estimate.json` -- S3 running estimate from session uyZ7TELqpP. NOTE: lives at session-scoped path; should migrate to `.aitools/channel/running-estimate.json` per decision #50 when channel infrastructure is built.
2. `harvesting/2026-03-16_carry-forward-design.md` -- running estimate schema, lifecycle, integration with decisions #4/#22/#26/#44
3. `plans/mission-command-briefing/delegation-evolution.md` -- how the execution protocol was born (7 user interventions)
4. `harvesting/2026-03-16_aar-tool-ops-plan.md` -- AAR from tool-ops plan execution (read first 100 lines minimum for executive summary)
5. `harvesting/2026-03-16_investigate-estimate-enforcement.md` -- barrier analysis on running estimate enforcement (Option 4 selected)
6. `harvesting/2026-03-16_briefing-analysis.md` -- S2 quality audit of the brief

---

## C. Session Chain

These sessions produced the decisions in the brief and subsequent work. The transcripts are in the dotprofile archive at `~/repos/aitools-nobul-jose/sessions/aitools/`:

| Session | Date | What it produced |
|---------|------|-----------------|
| `84280c8b` | 2026-03-15 20:08-22:57 UTC | Tool-ops plan, delegation protocol (7 rewrites), execution protocol, military doctrine grounding |
| `eaacf9da` | 2026-03-15 22:57-00:22 UTC | Tool-ops plan execution (8 batches), AAR + test suite, intent approval pattern (15min to 42sec) |
| `b8a9ed4e` | 2026-03-16 | Formulated planning brief, 52 decisions, all critical blockers resolved |
| `uyZ7TELqpP` | 2026-03-16 | S2 intelligence prep: carry-forward design, estimate enforcement investigation, running estimate |
| `79b05dd0` | 2026-03-16 | Continuation: decisions #49-52 (flat verb naming, running estimate, plan-writing protocol, Plan Writer role) |
| `RTzBnBupE6` | 2026-03-16 | Workspace governance, brief consistency, decisions #53-54, v0.62.0 |
| **`Z1IhGrcgGO`** | **2026-03-17/18** | **v0.62.2, 17 findings, incident #50, harness definition update, 10 approved decisions, provenance research. See section D** |

---

## D. What Session Z1IhGrcgGO Built

### D.1. Shipped work (5 commits)

| Commit | What |
|--------|------|
| d534f3c | Governed-data bypass fixes (28 JSON paths removed across 10 files), harness definition update (CLAUDE.md, harness.md, glossary.json), incident #50 filed |
| c3dd426 | v0.62.1 release notes |
| 66d7351 | Reading order fix: 6 missing decisions added, phase 13 eliminated |
| a77beb4 | Decision #54 integrated into planning brief + handoff prompt |
| 43c1b41 | Handoff prompt v0.62.0 session continuity update |

### D.2. Incident filed

**Incident #50**: `sources-of-truth.md` protected files table exposes all governed registry JSON paths as bypass vectors. Severity: High. Status: Open. This needs a barrier analysis before execution -- it is NOT in scope for this session (see exclusion clause 3 in section F).

### D.3. Ten approved decisions (not yet implemented)

These are the decisions that unblock plan writing. Each has been approved by the user but exists only in scratch files. The essential content for each:

**D-BRIEFINGS: Briefings live at `.aitools/briefings/`**
- Briefings are a harness capability (like scratch, channel, harvesting)
- Amends decision #34: add component `(14) .aitools/briefings/ -- structured decision documents`
- Amends workspace rule: add `briefings/` row to workspace structure table
- BLOCKED by OT-2 (`.gitignore` blanket pattern must be replaced with selective patterns first)
- Full analysis: `.scratch/session-Z1IhGrcgGO/briefings-location-decision.md`

**D-PROMOTION: "Promotion" governed term (Option 3 with 3 amendments)**
- Definition: "Advancing a tracked item from an evaluation stage to a permanent or enforced state after it meets criteria defined by the governing lifecycle. The transition is recorded in the item's governing artifact (harvest manifest, tool-ops registry, hook mode variables). Distinct from harvesting (entering evaluation) and pruning (leaving without advancement)."
- Source: `.claude/rules/artifact-harvesting.md`
- Three amendments from audit: (1) "hook enforcement table" -> "hook mode variables", (2) "registry" -> "governing artifact", (3) add meaning D barrier test
- Unblocks Q4 blocker #1
- File via `/glossary` skill
- Full analysis: `.scratch/session-Z1IhGrcgGO/promotion-definition-draft.md` + `promotion-definition-audit.md`

**D-REPO-PROJECT: "repo" and "project" governed terms**
- "repo": Any OS-accessible folder where a user works -- local filesystem, NAS, or cloud-synced (Google Drive, Dropbox, OneDrive, LucidLink). May also be a git repository, gaining tracking, branching, and pull-based carry-forward. The harness provides capabilities (.aitools/) regardless of backing storage. Distinct from aitools repo and dotprofile repo (specific named repos).
- "project": The body of work a user develops or maintains within a repo -- codebase, configuration, artifacts, and operational state. A repo contains one project. Project-scoped data lives in `<repo>/.aitools/`. Distinct from the scope modifier "project" (which qualifies composed terms like "project rule" for the current repo).
- Source for both: `.claude/rules/aitools-workspace.md`
- File via `/glossary` skill
- Full analysis: `.scratch/session-Z1IhGrcgGO/repo-project-definition-draft.md`

**D-CARRY-FORWARD: Two-layer carry-forward principle (C+A hybrid)**
- Replace current workspace rule lines 19-29 with per-mechanism guidance
- Wording direction: "MUST be persisted in the repo. In git repos, this means tracked (not gitignored). In cloud-synced folders, this means saved to the synced location. In local-only repos, the user is responsible for ensuring cross-machine access."
- The C+A hybrid was selected from 3 barrier analyses: A (AMEND, mild regression in clarity), B (REJECT, too abstract), C (ACCEPT, explicit per-mechanism guidance)
- Blocks workspace rule update
- Full analysis: `.scratch/session-Z1IhGrcgGO/carry-forward-barrier-A.md`, `carry-forward-barrier-B.md`, `carry-forward-barrier-C.md`

**D-ARTIFACT-ROLES: Dedicated `/artifact-roles` skill (Option 1)**
- Create `.claude/rules/artifact-roles.md` (lean rule), `.claude/skills/artifact-roles/SKILL.md` (full role definitions for all 5 artifact types), `reference/framework-artifact-roles.md` (source discipline), `shared/hooks/artifact-role-guard.sh` (detection layer)
- Option 1 won over Option 2 (enrich /governed-data) and Option 3 (hybrid delegation) because artifact roles govern ALL five artifact types while governed-data governs only one (registries) -- embedding the broader concept inside the narrower one is architecturally inverted
- NOT in scope for pre-plan work (exclusion clause 2 in section F). This is plan-scale work requiring 4 artifacts. Document the decision; build it in a plan batch.
- Full analysis: `.scratch/session-Z1IhGrcgGO/artifact-roles-tension-investigation.md`

**D2: Fix bash 3.2 heredoc bug in check-post-push.sh step 21**
- Process-substitution + heredoc construct `< <(python3 - <<'PYEOF' ...)` fails on macOS bash 3.2
- Step 21 (tool version freshness) has NEVER produced correct results on macOS since 2026-03-02
- Fix: write Python to temp file, execute from file (Option A: write-then-execute)
- Self-contained delegation package ready at `.scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md`

**D3: Fix BSD paste incompatibility (11 call sites)**
- macOS BSD `paste -sd,` requires explicit `-` for stdin; 11 call sites across steps 27, 29, 30, 31
- Under `set -euo pipefail`, any `paste` failure aborts the script before the exit footer runs
- Options: A (add `-` for stdin), B (replace with perl), C (check-lib helper `join_lines`)
- Self-contained delegation package ready at `.scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md`

**D4: Paste compliance check (after D3)**
- Add a compliance check to `scripts/check-script-compliance.sh` for `paste` without stdin file arg
- Same class as existing `grep -P` check (BSD/GNU divergence detection)
- Blocked by D3 (needs to know the chosen replacement pattern)

### D.4. Provenance research

21 concepts from 6 doctrinal traditions investigated. 5 high-leverage concepts identified (see section H). The research produced a scope-creep governance framework design combining Schwerpunkt (German doctrine) and exclusions clauses (legal drafting). This framework was applied to THIS session's handoff: section E declares a Schwerpunkt, section F declares exclusions.

### D.5. Write failure RCA

During this session, a background subagent was denied Write permission because Claude Code auto-denies Write for subagents unless pre-approved. Finding: when delegating file-writing tasks, either run the subagent in foreground or pre-approve Write by creating an empty file at the target path using the Write tool. The WRITE_BLOCKED signal pattern was added to delegation prompts: if a subagent's first output line is `WRITE_BLOCKED`, the delegating agent knows to retry in foreground.

### D.6. Remaining bypass vectors

After removing 28 JSON paths from rules and reference files:
- 6 remain in `.claude/rules/sources-of-truth.md` (incident #50 -- needs overhaul)
- 3 remain in `.claude/rules/incident-governance.md` (user has approach, pending explanation)
- Total: 9 remaining (down from 37)

### D.8. Harness verification findings

Two S2 investigations and one tool-ops assessment produced:

- **aitools is NOT a tool-ops entry** — 0 of 4 entry criteria met. Hooks and deny rules are tracked in the claude-code tool-ops entry where they manifest at runtime. Self-referential governance (tool-ops auditing itself) creates complexity without solving problems.

- **The bootstrap problem** — the harness has 70+ structural check steps but zero functional testing of skills (18 artifacts, 0 coverage), only 1 of 9 hooks has tool-ops verification specs, and check-post-push.sh itself is broken on macOS (bash 3.2 + BSD paste, undetected 16 days). The tester is broken.

- **CI/CD feasibility confirmed** — no .github/ directory exists today. Phase 1 (shellcheck + syntax + tool-ops mock tests on Ubuntu, ~30 lines YAML) can ship immediately. macOS CI runner would have caught all post-push bugs on day one.

- **Top 5 verification actions** (prioritized):
  1. Fix check-post-push.sh (D2+D3 in post-push briefing — test infra is broken)
  2. CI Phase 1: shellcheck + syntax + tool-ops mock tests (~30 lines YAML)
  3. Extend tool-ops verification specs to all 9 hooks (only 1 tested)
  4. Add skill structural checks to check-pre-commit (18 skills, 0 coverage)
  5. Design /skill-verify skill (generalize /handoff 9-criteria pattern)

- **Reconciliation**: tool-ops governs tools at runtime. The harness governs ITSELF via the three-layer pattern extended to verification infrastructure: check scripts (structural), CI (external automation), subagent verification (semantic), KPIs (production monitoring). Each layer catches what others miss.

### D.7. Not yet approved work products

Work products R1 (intent-writing heuristic), R2 (intent-audit heuristic), R3 (shared signal vocabulary) are drafted but unapproved. Located in `.scratch/session-Z1IhGrcgGO/intent-heuristic-findings.md` and `.scratch/session-Z1IhGrcgGO/intent-audit-findings.md`. Related to soft exclusion 6 (intent backfill).

---

## E. Schwerpunkt for Next Session

**Implement the approved decisions that unblock the plan-writing mission, then write the plan.**

### Wave 1 -- Foundation (unblock everything)

1. **File D-PROMOTION via /glossary** -- unblocks Q4 blocker #1. Definition drafted, audited, approved with 3 amendments.
2. **File D-REPO-PROJECT via /glossary** -- closes 5 should-resolve findings from Q4-Q10 ambiguity audit. Both definitions ready.
3. **Fix OT-2: replace `.gitignore` blanket** -- replace `.aitools/` in root `.gitignore` with selective patterns (`.aitools/scratch/`, `.aitools/channel/session-*/`, `.aitools/.current-session`, `.aitools/channel/.current-session`). This unblocks namespace consolidation, briefings tracking, and running-estimate tracking (see exclusion 1 in section F for the migration boundary).
4. **Execute D2 + D3 via parallel sub-agents** -- fix shipped bugs in check-post-push.sh. Delegation packages ready at `.scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md`. Then execute D4 (paste compliance check) after D3 completes.

### Wave 2 -- Amendments

5. **Amend planning brief** with this session's decisions via `/brief` skill:
   - D-BRIEFINGS: add component 14 to decision #34
   - D-PROMOTION: note Q4 blocker #1 resolved
   - D-CARRY-FORWARD: note carry-forward principle amended
   - D-ARTIFACT-ROLES: note Option 1 approved, implementation deferred to plan
6. **Draft carry-forward principle replacement** (OT-3) for workspace rule lines 19-29, using the C+A hybrid direction from barrier analysis C.
7. **Amend workspace rule** (`aitools-workspace.md`): add briefings row to workspace structure table, apply carry-forward principle update, rename "Tracked" column to reflect per-mechanism persistence.

### Wave 3 -- Plan writing

8. **Write `plans/mission-command-and-platform-engineering.md`** per the plan-writing protocol in section J of this handoff.

### Why this sequence

- Wave 1 items are small, independent, and unblock downstream work
- Wave 2 items update governing documents so the plan reflects current decisions
- Wave 3 is the original mission, now unblocked
- D-ARTIFACT-ROLES is deliberately NOT in this sequence -- it is plan-scale work (4 artifacts) that should be a plan batch, not pre-plan work

---

## F. Exclusion Clauses (Scope Governance)

These are explicit scope boundaries. Any work outside these boundaries requires a formal FRAGORD (documented rationale for scope amendment).

### Hard exclusions

1. **Do NOT start the namespace consolidation migration.** Do not move `harvesting/` to `.aitools/harvesting/` or `plans/mission-command-briefing/` to `.aitools/briefings/`. Fix the `.gitignore` blocker (Wave 1 item 3) but defer the actual file migration to a plan batch. The migration affects 59+ file references and requires careful sequencing.

2. **Do NOT build the artifact-roles skill and rule** (D-ARTIFACT-ROLES). This is plan-scale work requiring 4 artifacts (rule, skill, reference, hook). The approved decision (Option 1) is documented; the implementation waits for the plan.

3. **Do NOT overhaul sources-of-truth.md** (incident #50, open thread OT-7). This needs a barrier analysis before execution. It is a high-severity incident but not blocking plan writing.

4. **Do NOT start the registries directory migration** (recommendation R12, moving governed JSON files from `reference/` to `registries/`). This affects 59 files and needs its own plan.

5. **Do NOT adopt new frameworks from the provenance research.** The research identifies 5 high-leverage concepts (section H). These are candidates for future adoption via the framework adoption lifecycle, not for immediate implementation. You may USE concepts informally (e.g., applying Schwerpunkt thinking to scope decisions, using Reibung to identify friction) but must not create new framework artifacts without a plan.

### Soft exclusions (allowed if naturally encountered, do not seek out)

6. **Intent backfill** (R4, 14 rules + 6 skills missing intents). Only add intents to files being edited for other reasons.
7. **CI/CD pipeline build** — CI Phase 1 (~30 lines YAML) is high leverage and could ship quickly, but building it is implementation work that belongs in the plan. Allowed if the post-push bug fixes (Wave 1 item 4) naturally lead to "let's prevent this class of bug" and the agent judges Phase 1 as a 15-minute task.
8. **Recency heuristic provenance research** (OT-5). Only continue if it directly supports plan writing.
9. **Observe-mode promotion review** (R6, 1003 log entries). Analyze only if hook enforcement changes are part of a plan batch.

### What IS in scope

- The 3 waves defined in section E
- Bug fixes D2 + D3 + D4 (fix shipped, broken code -- always in scope)
- Filing incidents if ambiguities are discovered (surfacing duty is always on)
- Using provenance concepts informally as thinking tools

---

## G. Open Threads (Carry-Forward)

12 open threads from this session. Classified by actionability:

### READY (can execute now)

| # | Thread | Next action |
|---|--------|-------------|
| OT-2 | Root `.gitignore` blocker for `.aitools/` consolidation | Replace blanket `.aitools/` in root `.gitignore` with selective patterns. Wave 1 item 3 |
| OT-3 | Carry-forward principle wording | Draft replacement for workspace rule L19-29 using C+A hybrid. Wave 2 item 6 |
| OT-6 | Post-push bug fixes (D2, D3, D4) | Execute via sub-agents. Briefing ready. Wave 1 item 4 |
| OT-10 | Workspace "Tracked" column rename | Bundle with carry-forward update. Wave 2 item 7 |
| OT-12 | Scope modifier "project" facet | "In the aitools repo" -> "In the current repo". Bundle with D-REPO-PROJECT |

### BLOCKED (dependency must be resolved first)

| # | Thread | Blocking dependency |
|---|--------|-------------------|
| OT-1 | `incident-governance.md`: 3 `incidents.json` paths | User to explain approach (user has a specific plan for this) |
| OT-7 | `sources-of-truth.md` overhaul (#50) | Needs barrier analysis. Hard exclusion 3 |
| OT-8 | R5: Extend governed-data hook to all registries | Build after artifact-roles hook ships |
| OT-9 | R9: `rules-json-guard.sh` hook | Build after `artifact-role-guard.sh` |
| OT-11 | Q4 AAR lifecycle alignment (channel->harvesting, not scratch->harvesting) | Depends on carry-forward principle finalization |

### DEFERRED (not priority for this session)

| # | Thread | Why deferred |
|---|--------|-------------|
| OT-4 | Scope-creep as framework concept | Research discipline mapping. Interesting but not blocking |
| OT-5 | Recency heuristic provenance | Continue web research. Soft exclusion 8 |

---

## H. New Concepts from Provenance Research

Session Z1IhGrcgGO produced a deep research investigation across 6 doctrinal traditions (German military, Clausewitz, Japanese/Toyota, IDF, NATO, decision frameworks). 21 concepts were evaluated. The top 5 by leverage score:

| Concept | Source | Leverage | Why it matters |
|---------|--------|----------|---------------|
| **Schwerpunkt** | German/Clausewitz | 17/25 | Singular decisive point. Every scope-bearing artifact declares ONE most important objective. Forces prioritization. Already applied to this handoff (section E) |
| **Catchball** | Hoshin Kanri (Japanese) | 19/25 | Bidirectional negotiation after decomposition. "Can you execute this scope? What conflicts?" Prevents top-down decomposition from being infeasible |
| **A3 Thinking** | Toyota | 19/25 | Structured single-page constraint for sub-briefings. Schwerpunkt, current state, target state, key decisions (max 7-10), dependencies, acceptance criteria. Prevents sub-briefings from becoming mini planning briefs |
| **Cynefin** | Snowden | 18/25 | Domain classification (Clear/Complicated/Complex/Chaotic) determines not just WHAT to do but HOW to approach each decision. Our 54 decisions span all 4 domains |
| **Lagebeurteilung** | Bundeswehr | 15/25 | Structured situation assessment with fixed categories examined every time, even if nothing changed. Prevents blind spots from accumulating across sessions |

Two additional concepts are already in informal use:
- **Mitdenken** (German): Agents actively model the superior's decision space, not just execute their task. Connect findings to higher-level decisions.
- **Reibung** (Clausewitz): Friction analysis. Applied in the Schwerpunkt assessment (section 2, "Reibung Inventory").
- **Bootstrap problem** (Gödel/QA): a system cannot fully verify itself. The harness needs at least one external verification layer (CI, production KPIs) to catch when the internal verification (check scripts) is itself broken. Evidence: check-post-push.sh broken 16 days undetected.

Full research: `.scratch/session-Z1IhGrcgGO/provenance-deep-research.md` (21 concepts, synthesis matrix, integration paths, source URLs). Per exclusion clause 5, do NOT create framework artifacts from these concepts. Use them as thinking tools only.

---

## I. Delegation Duty Updates

### Write failure RCA finding

Background subagents in Claude Code are auto-denied Write permissions not pre-approved in the session's allow list. When delegating file-writing tasks:
- **Preferred**: Run the subagent in foreground (not background)
- **Alternative**: Pre-approve Write by creating an empty file at the target path using the Write tool before launching the subagent
- **Signal**: Add to delegation prompts: "If the Write tool is denied, your FIRST output line must be: WRITE_BLOCKED". The delegating agent monitors for this signal and retries in foreground.

### Schwerpunkt declaration

From the provenance research: every session should declare its Schwerpunkt at the start. This handoff declares it in the opening line and section E. When writing delegation briefings, include the Schwerpunkt for the delegated scope.

### /handoff skill

A new `/handoff` skill was built and deployed during this session (`shared/skills/handoff/SKILL.md`). It captures the full handoff workflow: Schwerpunkt declaration, session state audit, Lagebeurteilung, handoff writing, verification, amendments, commit. Use it to end future sessions.

### Subagent transcript search

Per incident #49 (session RTzBnBupE6): session transcripts are JSONL format. User messages appear in MULTIPLE message types: "human", "queue-operation" (multi-line input buffering), and "user". Search ALL types -- not just "human". A subagent that missed queue-operation messages produced a false fabrication claim.

---

## J. Plan-Writing Protocol (carried forward from prior handoff)

The plan-writing protocol and Plan Writer delegation template are defined in sections E and F of the PRIOR handoff (`plans/mission-command-briefing/handoff-prompt.md`). They remain valid and unchanged. Key points:

### Protocol summary (decision #51)

You (S3) write the plan directly. You are the author.

**Write-review loop** for each section:
1. S3 writes the section (consuming the brief in reading order)
2. S3 presents the section to the Plan Writer subagent for review
3. Plan Writer reviews as the user would (calibrated from session transcripts)
4. S3 revises based on Plan Writer feedback
5. If Plan Writer flags a SYSTEMIC finding, apply the improvement cycle (decision #54): investigate, structural-first generalization, barrier analysis. S3 decides inline vs deferred.
6. Plan Writer approves -> move to next section

**Section order**: Plan opening, Execution protocol, Known states, Context and session references, Identity model, Running estimate, Batch skeleton, Batch details, Verification section, Risk register.

**S3 self-verification** after all sections pass: 10-criterion checklist (execution protocol, known states, identity model, session references, delegation context, harness constraints, verification criteria, running estimate integration, all 54 decisions mapped, S2 intelligence consumed).

### Plan Writer role (decision #52)

The Plan Writer delegation template is at `plans/mission-command-briefing/handoff-prompt.md`, section F. The Plan Writer:
- Identity is the user (Jose) -- reviews as Jose would
- Has access to the dotprofile session archive for calibration (`~/repos/aitools-nobul-jose/sessions/`)
- Uses preference extraction heuristic (approvals, rejections, redirections, escalations, corrections) weighted by recency
- Must invoke `/intent-audit` on intent statements, `/investigate` with barrier analysis on structure decisions
- Applies the 10-criterion quality checklist
- Flags systemic findings for S3 escalation (not self-resolution)
- Session transcripts are JSONL -- search ALL message types (human, queue-operation, user)

### What the prior handoff provides

Read `plans/mission-command-briefing/handoff-prompt.md` for:
- Section G: Critical context (4 frameworks, staff functions, harness constraints, infrastructure dependencies, workspace rule)
- Section H: Step-by-step execution instructions

Note: the prior handoff was written for session RTzBnBupE6. This handoff (Z1IhGrcgGO) SUPPLEMENTS it with:
- Session Z1IhGrcgGO's outputs (section D above)
- Updated Schwerpunkt (section E -- Wave 1-3 sequence)
- Exclusion clauses (section F -- 5 hard, 3 soft)
- Open threads with actionability classification (section G)
- Provenance research summary (section H)
- Delegation duty updates (section I)

Both handoffs together provide the complete context. The prior handoff has the plan-writing protocol and critical context. This handoff has the most recent session's work and updated priorities.

---

## K. Planning Brief Amendments Needed

This session's 10 decisions require amendments to the planning brief before plan writing begins. Apply via `/brief` skill:

| Decision | Amendment needed |
|----------|-----------------|
| D-BRIEFINGS | Add component `(14) .aitools/briefings/` to decision #34 |
| D-PROMOTION | Note Q4 blocker #1 resolved in relevant artifact-lifecycle decisions |
| D-REPO-PROJECT | Update any decision that assumes "repo" = git repo |
| D-CARRY-FORWARD | Amend carry-forward references in decisions #3, #22, #26, #34, #50 to reflect per-mechanism persistence |
| D-ARTIFACT-ROLES | Note Option 1 approved, implementation deferred to plan batch |
| D2, D3, D4 | Note bug fixes in infrastructure dependencies section (check-post-push.sh operational status) |

Additionally, this session's amendments from commit 43c1b41 (handoff prompt update) and commit a77beb4 (decision #54 integration) are already in the brief.

---

## L. Provenance

This handoff prompt was produced during session `Z1IhGrcgGO` on 2026-03-18 (v0.62.2). It updates the prior handoff from session `RTzBnBupE6` (v0.62.0).

Changes from prior version:
- Session chain updated with Z1IhGrcgGO (7th session in the chain)
- Brief remains at 54 decisions; 10 new approved decisions exist in scratch files awaiting implementation
- Schwerpunkt shifted from "write the plan" to "implement approved decisions that unblock plan writing, then write the plan"
- 5 hard exclusion clauses added (scope governance from provenance research)
- 12 open threads documented with actionability classification
- Provenance research: 21 new concepts from 6 doctrinal traditions, 5 high-leverage recommendations
- Delegation duty updated: Write failure RCA, WRITE_BLOCKED signal, Schwerpunkt declaration
- Post-push bug fixes documented with self-contained delegation packages
- Incident #50 filed (sources-of-truth.md bypass vectors)
- Harness definition updated (CLAUDE.md mission paragraph, harness.md, glossary.json)

The user's intent: execute the 10 approved decisions that unblock plan writing (small, well-defined tasks), then write the plan using the protocol from session 84280c8b with Plan Writer review from decision #52. The Plan Writer replaces the user in the iterative review loop, calibrated from session transcripts. S3 is the author. The Plan Writer is the quality gate with the user's voice. The user sees only the finished product.
