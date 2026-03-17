# Mission: Write the Mission Command & Platform Engineering Plan

You are S3 (Operations). Your mission is to write the plan file `plans/mission-command-and-platform-engineering.md` from the planning brief. The brief contains 54 decisions, 18 facts, and 7 assumptions across 4 new frameworks. All critical blockers are resolved. The shallow plan (moonlit-wibbling-newt.md) was deleted because it was produced by a single subagent with a summary prompt that never read the brief — write from scratch.

---

## A. Source of Truth

The planning brief is at `plans/mission-command-briefing/planning-brief.json`. It IS the source of truth — every resolved decision point, every verified fact, every planning assumption. Do not re-derive decisions from conversation transcripts. The brief has them all.

### Reading order (from meta.readingOrder, extended)

Read the brief in this order — it is deliberate and prevents context rot:

1. **Critical blockers** (all resolved): F1, F2, F3, F17
2. **All facts**: F4-F16, F18 (14 verified ground truths)
3. **All assumptions**: A1-A7 (accepted for planning, unverified)
4. **Framework definitions** (build mental model before details): #3, #8, #13, #36, #37, #38
5. **Critical blocker resolution**: #29, #39, #40, #41
6. **Mission Command**: #4, #5, #6, #7, #15, #16, #49, #17, #19, #20, #22, #23, #24, #25, #26, #27, #28, #44
7. **Platform Engineering**: #9
8. **Mission Analysis**: #21, #43, #45
9. **Operational Learning**: #1, #2, #10, #11, #12, #14, #18, #30, #46, #47
10. **Infrastructure**: #32, #33, #34, #50, #42, #53
11. **Process**: #35, #48, #54
12. **Plan-writing protocol**: #51, #52

Decision #31 is merged into #8. Total: 53 active decisions + 1 merged = 54. All decisions are in the brief's `meta.readingOrder` — no gaps.

---

## B. Intelligence Preparation (read before writing)

Read these files IN FULL before entering plan mode. They are the S2 intelligence products for this plan:

1. `plans/mission-command-briefing/planning-brief.json` — the entire brief (54 decisions)
2. `.aitools/channel/session-uyZ7TELqpP/20260316T190000Z_s3_running-estimate.json` — S3 running estimate from prior session (59 lines). NOTE: this file follows the pre-workspace-rule model (session-scoped). Per decision #50 (amended) and `.claude/rules/aitools-workspace.md`, the running estimate should live at `.aitools/channel/running-estimate.json` (tracked, fixed path). Migrate when building channel infrastructure.
3. `harvesting/2026-03-16_carry-forward-design.md` — carry-forward system design: running estimate schema, lifecycle, integration with decisions #4/#22/#26/#44
4. `plans/mission-command-briefing/delegation-evolution.md` — how the execution protocol was born through 7 user interventions in session 84280c8b
5. `harvesting/2026-03-16_aar-tool-ops-plan.md` — AAR from the tool-ops plan execution (first 100 lines minimum for executive summary; full file is 731 lines)
6. `harvesting/2026-03-16_investigate-estimate-enforcement.md` — S2 barrier analysis on running estimate enforcement (Option 4 selected: SessionStart hook + /delegate skill)
7. `harvesting/2026-03-16_briefing-analysis.md` — S2 quality audit of the brief itself
8. `.claude/rules/aitools-workspace.md` — **NEW**: workspace governance rule. Cross-machine carry-forward principle, `.aitools/` namespace structure, scope boundaries. This rule governs decisions #3, #22, #26, #34, #50.

### What the running estimate says

Plan-ready. All critical blockers resolved. Primary risk: scope (54 decisions across 4 frameworks). Key recommendations:
- Batch 1 must bootstrap channel + running estimate + minimal /delegate
- Sequence decision #32 (log_ship + SQLite) early for KPI measurement
- Deploy fixed harvest-session.sh before plan execution produces artifacts

---

## C. Session Chain

These sessions produced the decisions in the brief. The transcripts are in the dotprofile archive at `~/repos/aitools-nobul-jose/sessions/aitools/`:

| Session | Date | What it produced |
|---------|------|-----------------|
| `84280c8b` | 2026-03-15 20:08-22:57 UTC | Tool-ops plan, delegation protocol (7 rewrites), execution protocol, military doctrine grounding |
| `eaacf9da` | 2026-03-15 22:57-00:22 UTC | Tool-ops plan execution (8 batches), AAR + test suite, intent approval pattern (15min to 42sec) |
| `b8a9ed4e` | 2026-03-16 | Formulated planning brief, 52 decisions, all critical blockers resolved |
| `uyZ7TELqpP` | 2026-03-16 | S2 intelligence prep: carry-forward design, estimate enforcement investigation, running estimate |
| `79b05dd0` | 2026-03-16 | Continuation: decisions #49-52 (flat verb naming, running estimate, plan-writing protocol, Plan Writer role) |
| `RTzBnBupE6` | 2026-03-16 | **Current**: workspace governance, brief consistency, decisions #53-54. See section C2 below |

### C2. What session RTzBnBupE6 built (most recent)

This session started from the handoff prompt and deviated to fix workspace governance before plan writing. Key outputs:

**New artifacts:**
- `.claude/rules/aitools-workspace.md` — workspace governance rule (carry-forward principle, scope boundaries)
- `reference/tool-registry.json` — unified JSON registry (merged tool-registry.md + tool-versions.json)
- `plans/mission-command-briefing/` — 13 investigation/audit files

**Brief changes:**
- Decisions #53 and #54 added (governed document drift prevention, harness improvement cycle)
- Decisions #3, #22, #26, #34, #50 amended — aligned with workspace rule carry-forward principle (14→1 inconsistencies, 0 intent preservation issues, verified by independent re-audit)
- Brief now has 54 decisions

**Rules/skills refined:**
- frameworks.md (deduplicated registry table into skill)
- sources-of-truth.md (tool-registry.md→json)
- tool-lifecycle.md (install method discovery, trigger directive)
- intent-writing skill (pre-write audit, multi-pass ambiguity removal, quality criteria, style calibration)
- intent-audit skill (quality/ambiguity checks, exemplar comparison)
- tool-registry skill (schema v1.0 alignment)
- incident skill (known limitations noted)
- harvest-session.sh (JSON/YAML/unknown extension handling — was silently deleting .json files)

**Incidents filed:**
- #48: agent asserts behavioral constraints without checking source (3rd occurrence)
- #49: subagent transcript search missed queue-operation messages, produced false fabrication claim

**Dotprofile updated:**
- Cross-machine carry-forward intent added to CLAUDE.md template and live copy

**Version:** v0.62.0 tagged and pushed

**Investigation artifacts in `.scratch/session-RTzBnBupE6/` (may be harvested):**
- `workspace-audit.json` — AAR-format audit of all 54 decisions against workspace rule
- `workspace-reaudit.json` — verification audit (14→1 after amendments)
- `investigate-full-prevention.md` — 5-element prevention stack design with Swiss cheese analysis
- `investigate-governed-drift-decision.md` — decision #53 design investigation
- `decision-workflow-pattern.md` — decision #54 design with 2 rounds of self-refinement
- `barrier-governed-by.md`, `barrier-fragord.md`, `barrier-amendment.md` — parallel barrier analyses
- `channel-placement-investigation.md` — initial investigation (NOTE: central claim was wrong, spot-check caught it — see incident #49)
- `workflow-description.md` — workflow pattern description for decision #54

**Pre-commit check step 16 FAIL (known):** 3 governed data file paths in rules files — governance descriptions ("it gates framework-registry.json"), not bypass instructions. Check script can't distinguish.

---

## D. What the Shallow Plan Got Wrong

A Plan subagent was launched with a single summary prompt. It produced 190 lines that:
- Never read the planning brief (3349 lines of resolved decisions ignored)
- Invented its own structure instead of mapping the 52 decisions
- Had no execution protocol, no delegation duty, no identity model
- Had no known states, no harness constraints, no verification section
- Was a generic framework plan, not an actionable execution document

The root cause: delegating plan writing to a single subagent with a summary bypasses everything the execution protocol exists to prevent. A FRAGORD without the base OPORD.

---

## E. Plan-Writing Protocol (Decision #51)

You (S3) write the plan directly. You are the author.

### Write-review loop

For each section:
1. S3 writes the section (consuming the brief in reading order)
2. S3 presents the section to the Plan Writer subagent for review
3. Plan Writer reviews as the user would (see section F below for delegation template)
4. S3 revises based on Plan Writer feedback
5. Plan Writer approves or pushes back again
5a. If Plan Writer flags a SYSTEMIC finding (governance gap, cross-cutting pattern, missing structural enforcement — not just "rewrite this paragraph"), escalate to the harness improvement cycle rather than ad-hoc revision. Investigate, look for structural fixes before mechanical ones, run barrier analysis if multiple options exist. S3 decides whether to run inline or defer to a later batch.
6. S3 moves to the next section

### Section order

Write the plan in this order, with each section going through the write-review loop before moving on:

1. **Plan opening** — addressee framing ("To the executing agent"), mission statement, the 4 frameworks being built
2. **Execution protocol** — all 6 steps from delegation-evolution.md, updated with decisions #39/#40 (intent skills), #41 (plan-gate hook), #42 (intent-enforcement hook)
3. **Known states** — current harness state: what exists, what is broken, what is in transition. Include F1-F18 status. Include session RTzBnBupE6 outputs (workspace rule, brief amendments, decisions #53/#54)
4. **Context and session references** — session chain (including RTzBnBupE6), work products, the brief's location
5. **Identity model** — S1/S2/S3 staff functions (decision #38), Plan Writer role (decision #52), batch agent identities
6. **Running estimate** — schema, lifecycle, integration (decision #50 as amended, carry-forward-design.md). NOTE: running estimate now at fixed tracked path per workspace rule
7. **Batch skeleton** — map all 54 decisions into batches with dependencies. Infrastructure first (channel, estimate, log_ship), then frameworks. Include #53 (drift prevention) and #54 (improvement cycle) placement
8. **Batch details** — 1-2 batches at a time through the write-review loop. Each batch: identity for delegated agent, delegation context (all 8 components from decision #4), verification criteria
9. **Verification section** — S3 self-verification checklist, S2 consolidation at plan end, S1 incident filing
10. **Risk register** — from the brief's assumptions + running estimate risks

### S3 self-verification (after Plan Writer approves all sections)

Read the complete plan as if you were a fresh agent. Apply the 10-criterion checklist:
1. Execution protocol present and complete
2. Known states documented with current status
3. Identity model defined (S1/S2/S3 + Plan Writer + batch roles)
4. Session references present for all source sessions
5. Delegation context per batch (all 8 components from decision #4)
6. Harness constraints documented (the 4 constraints from delegation-evolution.md)
7. Verification section with concrete criteria per batch
8. Running estimate integration (how S3 maintains, how extracts feed delegations)
9. All 54 brief decisions mapped to batches (none missing, none invented)
10. S2 intelligence prep consumed (findings from carry-forward design, estimate enforcement, briefing analysis, workspace audit)

### Three review layers

1. **Plan Writer review** — calibrated as the user's voice (section F)
2. **S3 self-verification** — the 10-criterion checklist above
3. **User final approval** — present the complete plan to the user

---

## F. Plan Writer Delegation Template (Decision #52)

When you launch the Plan Writer subagent, use this delegation template. The Plan Writer is a reviewer, not a writer.

### Identity

```
You are the Plan Writer. Your identity is the user (Jose). You REVIEW, you
do not write. When S3 presents a plan section, evaluate it as Jose would:
does it meet the standards demonstrated in recent sessions? What would Jose
push back on? What would get a one-word approval like "beautiful"? What
would get "wtf is bootstrap?" — meaning an undefined term slipped through?
```

### Session history access

```
You have access to the full dotprofile session archive for calibration:
  ~/repos/aitools-nobul-jose/sessions/

This directory contains session transcripts across multiple projects. The
dotprofile archive is CANONICAL — if you find local copies of archived
sessions elsewhere (e.g., .scratch/, .aitools/), skip the duplicates.

Read USER MESSAGES to calibrate your review judgment. Agent tool calls and
file contents are noise. The user's voice is the signal.

IMPORTANT: Session transcripts are JSONL format. User messages appear in
MULTIPLE message types: "human", "queue-operation" (multi-line input
buffering), and "user". Search ALL types — not just "human". Incident #49
documents a subagent that missed queue-operation messages and produced a
false finding as a result.
```

### Preference extraction heuristic

```
Extract preference patterns from user messages:
- APPROVALS: what preceded "beautiful", "thats pretty damn beautiful",
  "thats good", single-word "yes"
- REJECTIONS: what preceded "wtf is bootstrap?", "weak sauce", "no thats
  not right", "this feels very inefficient"
- REDIRECTIONS: "actually think about X", "remember the limitations",
  "re-read from the beginning and re-write from scratch", "think outside
  the current capabilities"
- ESCALATIONS: "do barrier analysis", "audit our recent conversations",
  "do multiple passes of this", "search our framework provenance"
- CORRECTIONS: "that is ONE of the places to put it", "the plan writer
  doesnt self-review, you review him", "their identity is me",
  "you assume i can see it" (when subagent results not presented)

Weight by recency:
- March 14-16: highest weight (current standards, framework adoption,
  workspace governance, harness improvement cycle)
- March 9-13: high weight (early framework work)
- March 1-6: medium weight (initial harness)
- February: low weight (initial setup)
- Cross-project sessions: different signal (implementation style, not
  governance standards)
- Same session: later exchanges override earlier (standards tighten)
```

### Skills mandate

```
During review, you MUST use these skills (invoke them, do not just
reference them):
- /intent-audit on any section containing intent statements
- /investigate with barrier analysis on plan structure decisions
- Apply the 10-criterion plan quality checklist as a gate

You are a general-purpose subagent (you need all tools including Skill).
```

### Quality checklist for review

```
For each section S3 presents, evaluate against these 10 criteria:
1. Does it map to specific brief decisions? (cite decision IDs)
2. Are all intent statements concrete (not "about X")?
3. Are governed terms used correctly? (check /glossary)
4. Are cross-references valid (files exist, sections exist)?
5. Would a fresh agent know what to do from this section alone?
6. Are harness constraints acknowledged where delegation is discussed?
7. Are components from the brief present (not summarized away)?
8. Is the delegation context complete (all 8 components from decision #4)?
9. Are KPIs from the brief preserved?
10. Does the section match the user's demonstrated quality bar?
```

### Escalation to improvement cycle

```
When your review reveals a finding that is SYSTEMIC — it affects multiple
sections, reveals a governance gap, or indicates a class of problem the
harness does not govern — do not attempt to fix it within the review loop.
Flag it explicitly:

  SYSTEMIC FINDING: [description]. This requires investigation and
  structural-first generalization, not a section rewrite.

S3 decides the response: run the improvement cycle inline, defer to a
later batch, or file an incident for future resolution. Your job is to
DETECT and FLAG, not to resolve systemic findings.
```

### Deduplication rule

```
The dotprofile archive (~/repos/aitools-nobul-jose/sessions/) is the
canonical source. Session transcripts may also exist locally:
- ~/.claude/projects/ (CC auto-saves)
- .scratch/ or .aitools/ (session artifacts)

When you encounter the same session in multiple locations, read the
dotprofile copy. Skip local copies. This prevents double-counting
preference signals.
```

---

## G. Critical Context

### The 4 frameworks being built

| Framework | Intent summary | Key decisions |
|-----------|---------------|---------------|
| **Mission Command** | Govern delegation, communication, coordination, staff functions. Adapted from Auftragstaktik + FM 101-5-2 | #3, #4, #5, #6, #7, #15-#17, #19-#20, #22-#28, #44, #50 |
| **Platform Engineering** | Govern platform correctness across all code. Prevention + detection + audit | #8, #9 |
| **Mission Analysis** | Govern pre-plan requirements enumeration. Adapted from MDMP Step 2 | #13, #21, #43, #45 |
| **Operational Learning** | Govern AAR debrief, artifact harvesting, session persistence, channel archival. Closes the learning loop | #1, #2, #10-#12, #14, #18, #30, #36, #46-#47 |

### Cross-cutting decisions (not framework-specific)

| Decision | What it governs |
|----------|----------------|
| #32, #33 | Infrastructure: Datadog telemetry + Auth0 credential management |
| #34 | Infrastructure: `.aitools/` namespace consolidation (superseded by workspace rule, amendments applied) |
| #35 | Process: structural fixes over behavioral coaching |
| #42 | Process: intent-enforcement write hook |
| #48 | Process: fix-right decision tree with barrier analysis |
| #49 | Naming: flat verb skill naming |
| #51, #52 | Plan-writing protocol + Plan Writer role |
| **#53** | **Governance: governed document drift prevention (governedBy + hooks)** |
| **#54** | **Process: harness improvement cycle (finding to verified fix). Escalation target from Plan Writer when systemic findings surface during plan writing** |

### Staff functions (decision #38)

- **S1 (Administration)**: incident filing, registry cleanup. Delegated by S2 at plan end
- **S2 (Intelligence)**: AAR debrief, findings consolidation, intelligence prep. Spawned at plan start and plan end
- **S3 (Operations)**: plan execution, batch delegation, inter-batch verification. Assigned by plan writer in preamble
- **User = Commander**: approves decisions, validates proposals, authorizes delegations. Not a staff function

### Harness constraints on delegation (from delegation-evolution.md)

1. Delegated agents do not persist (start fresh, no memory)
2. Delegated agents do not inherit project rules or CLAUDE.md
3. Delegated agents cannot receive updates mid-execution
4. Delegated agents cannot communicate with each other

### Infrastructure dependencies (sequencing)

- Decision #22 (channel directory) must be built before delegation (#4) works
- Decision #32 (log_ship + SQLite) must be early — all KPIs are aspirational until telemetry exists
- Decision #50 (running estimate) depends on #22 (channel) and #23 (channel schemas)
- Decision #34 (.aitools/ namespace) is superseded by workspace rule — path migration must be sequenced carefully with hooks that reference old paths
- Decision #53 (drift prevention) Phase 0 is done (amendments applied, workspace rule written). Phase 1 (rule-write-impact hook) should be early in plan execution
- Decision #54 (improvement cycle) is a process pattern — no infrastructure to build, but should be documented in the operational learning rule

### Workspace rule (NEW — `.claude/rules/aitools-workspace.md`)

Key principles that affect plan execution:
- `.aitools/scratch/` — gitignored (session-ephemeral)
- `.aitools/channel/session-*/` — gitignored (session-ephemeral messages)
- `.aitools/channel/running-estimate.json` — **TRACKED** (carry-forward state across machines)
- `.aitools/harvesting/` — tracked (artifact lifecycle)
- `~/.aitools/` — user-scoped (config, auth, telemetry)
- Cross-machine carry-forward: state that needs to survive machine switch MUST be in git

### Key sequencing from running estimate recommendations

1. **Immediate**: Channel infrastructure (#22, #23) + running estimate (#50) + minimal /delegate (#4)
2. **Next**: log_ship (#32) for KPI measurement
3. **Then**: Framework artifacts in dependency order
4. **Early**: Decision #53 Phase 1 (rule-write-impact hook) — prevents drift during plan execution itself
5. **Throughout**: The harness improvement cycle (#54) governs how findings surfaced during plan writing and execution become verified fixes. Not infrastructure — a process pattern that S3 and Plan Writer both reference

---

## H. What to Do — Step by Step

1. **Read the full planning brief** in the reading order specified in section A above. Read it completely. This is the single most important step.

2. **Read the S2 intelligence products** listed in section B. These are: running estimate, carry-forward design, delegation evolution, AAR executive summary, estimate enforcement investigation, briefing analysis, AND the workspace rule.

3. **Enter plan mode** in Claude Code (the plan tool).

4. **Write the plan section by section** per the protocol in section E. For each section:
   - Write it
   - Launch the Plan Writer subagent using the template in section F
   - Revise based on Plan Writer review
   - If Plan Writer flags a systemic finding, apply the improvement cycle (investigate, structural-first, barrier analysis) or defer to a later batch
   - Get Plan Writer approval
   - Move to next section

5. **After all sections pass Plan Writer review**, do S3 self-verification using the 10-criterion checklist in section E.

6. **Present the complete plan** to the user for final approval.

---

## I. Provenance

This handoff prompt was produced during session `RTzBnBupE6` on 2026-03-16 (v0.62.0). It updates the prior handoff from session `0qW2xi3JDx`. Changes from prior version:

- Brief grew from 52 to 54 decisions (#53 governed document drift, #54 harness improvement cycle)
- 5 decisions amended for workspace rule consistency (#3, #22, #26, #34, #50)
- New workspace rule (`.claude/rules/aitools-workspace.md`) added to intelligence products
- Session chain updated with RTzBnBupE6 and 79b05dd0
- Section C2 documents everything RTzBnBupE6 built
- Plan Writer template updated: JSONL message type warning (incident #49), new preference patterns from this session
- Reading order extended with phase 13 (decisions #53, #54)
- Infrastructure dependencies updated (workspace rule supersedes #34, drift prevention Phase 0 complete)
- Cross-cutting decisions table added (decisions that span frameworks)
- Known states section order updated to include RTzBnBupE6 outputs

The user's intent: write the plan properly, with the Plan Writer replacing the user in the iterative review loop, calibrated from session transcripts. S3 is the author. The Plan Writer is the quality gate with the user's voice. The user sees only the finished product.
