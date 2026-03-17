# Mission: Write the Mission Command & Platform Engineering Plan

You are S3 (Operations). Your mission is to write the plan file `plans/mission-command-and-platform-engineering.md` from the planning brief. The brief contains 52 decisions, 18 facts, and 7 assumptions across 4 new frameworks. All critical blockers are resolved. The shallow plan (moonlit-wibbling-newt.md) was deleted because it was produced by a single subagent with a summary prompt that never read the brief — write from scratch.

---

## A. Source of Truth

The planning brief is at `plans/mission-command-briefing/planning-brief.json`. It IS the source of truth — every resolved decision point, every verified fact, every planning assumption. Do not re-derive decisions from conversation transcripts. The brief has them all.

### Reading order (from meta.readingOrder)

Read the brief in this order — it is deliberate and prevents context rot:

1. **Critical blockers** (all resolved): F1, F2, F3, F17
2. **All facts**: F4-F16, F18 (14 verified ground truths)
3. **All assumptions**: A1-A7 (accepted for planning, unverified)
4. **Framework definitions** (build mental model before details): decisions #3, #8, #13, #36, #37, #38
5. **Critical blocker resolution decisions**: #29, #39, #40, #41
6. **Mission Command decisions**: #4, #5, #6, #7, #15, #16, #17, #19, #20, #22, #23, #24, #25, #26, #27, #28, #44
7. **Platform Engineering decisions**: #9
8. **Mission Analysis decisions**: #21, #43, #45
9. **Operational Learning decisions**: #1, #2, #10, #11, #12, #14, #18, #30, #46, #47
10. **Infrastructure decisions**: #32, #33, #34, #42
11. **Process decisions**: #35, #48
12. **Plan-writing protocol**: #49, #50, #51, #52

Decision #31 is merged into #8. Total: 51 active decisions + 1 merged = 52.

---

## B. Intelligence Preparation (read before writing)

Read these files IN FULL before entering plan mode. They are the S2 intelligence products for this plan:

1. `plans/mission-command-briefing/planning-brief.json` — the entire brief (3349 lines)
2. `.aitools/channel/session-uyZ7TELqpP/20260316T190000Z_s3_running-estimate.json` — S3 running estimate from prior session (59 lines, current state assessment and recommendations)
3. `harvesting/2026-03-16_carry-forward-design.md` — carry-forward system design: running estimate schema (813 lines), lifecycle, integration with decisions #4/#22/#26/#44, artifacts required
4. `plans/mission-command-briefing/delegation-evolution.md` — how the execution protocol was born through 7 user interventions in session 84280c8b (322 lines)
5. `harvesting/2026-03-16_aar-tool-ops-plan.md` — AAR from the tool-ops plan execution session (first 100 lines minimum for executive summary; full file is 731 lines)
6. `harvesting/2026-03-16_investigate-estimate-enforcement.md` — S2 barrier analysis on running estimate enforcement (Option 4: SessionStart hook + /delegate skill was selected)
7. `harvesting/2026-03-16_briefing-analysis.md` — S2 quality audit of the brief itself (findings on stale framework references, schema inconsistencies, sequencing concerns)

### What the running estimate says

Plan-ready. All critical blockers resolved. Primary risk: scope (52 decisions across 4 frameworks). Key recommendations:
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
| `b8a9ed4e` | 2026-03-16 | Current audit session: formulated this planning brief, 52 decisions, all critical blockers resolved |
| `uyZ7TELqpP` | 2026-03-16 | S2 intelligence prep: carry-forward design, estimate enforcement investigation, running estimate |

### What was built in the current session chain

- `reference/tool-registry.json` created (merged tool-registry.md + tool-versions.json, incident #21 resolved)
- `/intent-writing` and `/intent-audit` skills updated with proven heuristics
- `.claude/rules/frameworks.md` rewritten from scratch (pure governance, no state)
- `.claude/rules/tool-lifecycle.md` rewritten
- 102 reciprocal `related` links fixed in the brief
- `shared/hooks/harvest-session.sh` .json bug fixed (was silently deleting .json files)
- Incident #48 filed (assertion without checking — 3rd occurrence of same pattern)
- Flat verb skill naming decided: /brief, /debrief, /harvest, /delegate, /channel, /compat

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
6. S3 moves to the next section

### Section order

Write the plan in this order, with each section going through the write-review loop before moving on:

1. **Plan opening** — addressee framing ("To the executing agent"), mission statement, the 4 frameworks being built
2. **Execution protocol** — all 6 steps from delegation-evolution.md, updated with decisions #39/#40 (intent skills), #41 (plan-gate hook), #42 (intent-enforcement hook)
3. **Known states** — current harness state: what exists, what is broken, what is in transition. Include F1-F18 status
4. **Context and session references** — session chain, work products, the brief's location
5. **Identity model** — S1/S2/S3 staff functions (decision #38), Plan Writer role (decision #52), batch agent identities
6. **Running estimate** — schema, lifecycle, integration (decision #50, carry-forward-design.md)
7. **Batch skeleton** — map all 52 decisions into batches with dependencies. Infrastructure first (channel, estimate, log_ship), then frameworks
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
9. All 52 brief decisions mapped to batches (none missing, none invented)
10. S2 intelligence prep consumed (findings from carry-forward design, estimate enforcement, briefing analysis)

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

This directory contains 237 transcripts across 20 projects. The dotprofile
archive is CANONICAL — if you find local copies of archived sessions
elsewhere (e.g., .scratch/, .aitools/), skip the duplicates.

Read USER MESSAGES to calibrate your review judgment. Agent tool calls and
file contents are noise. The user's voice is the signal.
```

### Preference extraction heuristic

```
Extract preference patterns from user messages:
- APPROVALS: what preceded "beautiful", "thats pretty damn beautiful",
  "thats good", single-word "yes"
- REJECTIONS: what preceded "wtf is bootstrap?", "weak sauce", "no thats
  not right"
- REDIRECTIONS: "actually think about X", "remember the limitations",
  "re-read from the beginning and re-write from scratch"
- ESCALATIONS: "do barrier analysis", "audit our recent conversations",
  "do multiple passes of this"
- CORRECTIONS: "that is ONE of the places to put it", "the plan writer
  doesnt self-review, you review him", "their identity is me"

Weight by recency:
- March 14-16: highest weight (current standards, framework adoption)
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
- Decision #34 (.aitools/ workspace) is a path migration that must be sequenced carefully with hooks that reference old paths

### Key sequencing from running estimate recommendations

1. **Immediate**: Channel infrastructure (#22, #23) + running estimate (#50) + minimal /delegate (#4)
2. **Next**: log_ship (#32) for KPI measurement
3. **Then**: Framework artifacts in dependency order

---

## H. What to Do — Step by Step

1. **Read the full planning brief** in the reading order specified in section A above. Read it completely — all 3349 lines. This is the single most important step.

2. **Read the S2 intelligence products** listed in section B. These are: running estimate, carry-forward design, delegation evolution, AAR executive summary, estimate enforcement investigation, briefing analysis.

3. **Enter plan mode** in Claude Code (the plan tool).

4. **Write the plan section by section** per the protocol in section E. For each section:
   - Write it
   - Launch the Plan Writer subagent using the template in section F
   - Revise based on Plan Writer review
   - Get Plan Writer approval
   - Move to next section

5. **After all sections pass Plan Writer review**, do S3 self-verification using the 10-criterion checklist in section E.

6. **Present the complete plan** to the user for final approval.

---

## I. Provenance

This handoff prompt was produced by S2 (Intelligence) at the end of session `0qW2xi3JDx` on 2026-03-16. It synthesizes:
- The complete planning brief (52 decisions, 18 facts, 7 assumptions)
- The S3 running estimate from session `uyZ7TELqpP`
- The carry-forward design (running estimate schema and lifecycle)
- The delegation evolution report (how the execution protocol was born)
- The AAR from the tool-ops plan execution
- The S2 investigation on running estimate enforcement
- The S2 briefing quality analysis
- User decisions #51 (plan-writing protocol) and #52 (Plan Writer role) made during this session chain

The user's intent: write the plan properly this time, with the Plan Writer replacing the user in the iterative review loop, calibrated from 237 session transcripts. S3 is the author. The Plan Writer is the quality gate with the user's voice. The user sees only the finished product.
