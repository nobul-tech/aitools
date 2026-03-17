# Running Estimate: Carry-Forward System Design

**Author**: S2 (Intelligence), session uyZ7TELqpP
**Date**: 2026-03-16
**Status**: Design proposal for user review

---

## 1. Military Doctrine Foundation

### What is a Running Estimate?

ADP 5-0 (The Operations Process, July 2019) defines a running estimate as
"the continuous assessment of the current situation used to determine if the
current operation is proceeding according to the commander's intent and if
planned future operations are supportable."

Key doctrinal properties:

1. **Continuous, not episodic**: Updated throughout the operations process —
   planning, preparation, execution, assessment. Not a snapshot taken at
   handoff; a living document maintained throughout.

2. **Per staff section**: Each staff officer (S1/S2/S3/S4/etc.) maintains
   their own running estimate within their functional area. The commander's
   running estimate integrates all staff estimates.

3. **Standard format** (ATTP 5-0.1, FM 6-0):
   - Situation (facts, assumptions, enemy/friendly status, civil considerations)
   - Mission (restated mission from mission analysis)
   - Analysis (COA evaluation by functional area)
   - Comparison (COA ranking)
   - Conclusions and Recommendations

4. **At handoff, the running estimate IS the carry-forward**: During relief
   in place or battle handover, the outgoing staff passes running estimates
   to the incoming staff. The estimate contains everything the incoming
   officer needs to continue operations without re-deriving the situation.

5. **Conclusions and recommendations first**: Recent doctrine (2024 LSCO
   article) criticizes estimates that bury conclusions at the end. Best
   practice: lead with assessments, conclusions, and recommendations. Facts
   and assumptions support them — they are not the primary product.

### What We Adapt vs. What We Reject

| Doctrine | Adapt | Reject/Modify |
|----------|-------|---------------|
| Continuous update | Yes — estimate updated between delegations, not just at session boundary | N/A |
| Per staff section | Yes — S2 maintains intelligence estimate, S3 maintains operations estimate | S1/S4/S6 etc. — we only have S1-S3 |
| Standard format (5 paragraphs) | Adapt — our fields map differently (see schema) | Full 5-paragraph format is too heavyweight |
| Conclusions first | Yes — `situation.currentState` and `conclusions` are top-level, facts/assumptions support | N/A |
| Handoff = pass the estimate | Modified — no true "handoff" (agents don't persist). The estimate is injected into the next agent's briefing | Assumption of persistent units |
| Commander integrates all estimates | Modified — S3 (executing agent) integrates estimates from S2 delegations | Commander (user) reviews but doesn't maintain an estimate |

### Harness Constraints That Shape the Design

These five constraints (from AAR Section 6, delegation-evolution.md Section 6)
determine how a running estimate works in our harness vs. military operations:

1. **Agents don't persist** — the estimate must be a complete document, not
   a delta. Every consumer reads it fresh.
2. **Agents don't inherit rules** — the estimate must be self-contained,
   including relevant context that rules would normally provide.
3. **No mid-execution updates** — once a delegation is in flight, the
   estimate cannot be pushed to it. Updates go to the NEXT delegation.
4. **No peer communication** — estimates flow through S3 (the executing
   agent), never between batch agents directly.
5. **Post-execution verification** — S3 verifies after the delegated agent
   completes, not before. The estimate captures verification results.

---

## 2. Naming Decision

### Governed term: "running estimate"

**Rationale**: The military uses "running estimate" (ADP 5-0) and it maps
precisely to what we need. "Carry-forward" describes the action (carrying
information forward) but not the artifact. "Handoff brief" implies a one-time
event. "SITREP" is a message type we already have in the channel (a status
report from a specific moment). The running estimate is the continuously
maintained state document that SITREPs update.

**Term relationships**:
- A **SITREP** is a message that reports status at a point in time (already
  defined in decision #23). SITREPs update the running estimate.
- A **FINDING** is a structured observation (already defined in decision #23).
  FINDINGs are absorbed into the running estimate by S3.
- A **running estimate** is the cumulative state document that integrates
  SITREPs, FINDINGs, verifications, deviations, and conclusions. It is the
  intelligence product, not a message type.
- An **AAR** is the post-execution debrief (decision #36). The running estimate
  feeds the AAR — it provides the "what happened" facts. The AAR produces
  "why" and "what to change."

**Provenance map entry**:
```json
{
  "concept": "Running estimate",
  "source": {
    "discipline": "Military operations",
    "work": "ADP 5-0 The Operations Process (July 2019)",
    "key": "Continuous assessment used to determine if the current operation is proceeding according to the commander's intent"
  },
  "ownedBy": "Mission command",
  "usedBy": ["Mission command", "Mission analysis", "Operational learning"],
  "adaptation": {
    "harnessMeaning": "A continuously updated JSON document maintained by S3 that captures cumulative situation, findings, deviations, conclusions, and recommendations across all delegations in a plan execution. Injected into each delegation briefing as the state of the world. Archived to channel at session end.",
    "implementingSkills": ["/delegate", "/brief", "/debrief"]
  }
}
```

---

## 3. Schema Design

### Design Decision: One Schema, All Levels

There is one running estimate schema. It works at every level — session,
plan execution, and individual delegation — because the structure is the
same at every level: here is the situation, here is what has happened, here
is what I conclude, here is what I recommend.

The difference between levels is scope, not structure:
- **Session-level**: covers the entire session's work (multiple plans possible)
- **Plan-level**: covers one plan execution (the primary use case)
- **Delegation-level**: a subset extracted and injected into a delegation briefing

This mirrors doctrine: the S2 intelligence estimate and the S3 operations
estimate use the same format — the scope is the functional area, not a
different schema.

### Schema: `running-estimate.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Running Estimate",
  "description": "Continuously updated state document for multi-agent operations. Adapted from ADP 5-0.",
  "type": "object",
  "required": ["meta", "situation", "conclusions"],
  "properties": {

    "meta": {
      "type": "object",
      "required": ["estimateId", "maintainer", "scope", "created", "updated", "version"],
      "properties": {
        "estimateId": {
          "type": "string",
          "description": "Unique identifier: {session-prefix}_{scope}_{maintainer}. Example: uyZ7TELqpP_plan_s3"
        },
        "maintainer": {
          "type": "string",
          "enum": ["s1", "s2", "s3"],
          "description": "Staff function maintaining this estimate"
        },
        "scope": {
          "type": "string",
          "enum": ["session", "plan", "delegation"],
          "description": "What this estimate covers"
        },
        "planRef": {
          "type": ["string", "null"],
          "description": "Path to the plan being executed (null for session-scope)"
        },
        "briefRef": {
          "type": ["string", "null"],
          "description": "Path to the planning brief (null if none)"
        },
        "sessionId": {
          "type": "string",
          "description": "Claude Code session ID prefix (8 chars)"
        },
        "created": {
          "type": "string",
          "format": "date-time",
          "description": "When this estimate was first created (UTC with Z suffix)"
        },
        "updated": {
          "type": "string",
          "format": "date-time",
          "description": "When this estimate was last updated (UTC with Z suffix)"
        },
        "version": {
          "type": "integer",
          "minimum": 1,
          "description": "Incremented on each update. Ensures consumers detect missed updates"
        }
      }
    },

    "situation": {
      "type": "object",
      "description": "Current state of the operation — conclusions first, supporting detail after. Adapted from Running Estimate Paragraph 1 (Situation).",
      "required": ["currentState"],
      "properties": {
        "currentState": {
          "type": "string",
          "description": "One to three sentences: where are we RIGHT NOW? What is the most important thing the next consumer needs to know? This is the 'conclusions first' principle from recent doctrine guidance."
        },
        "completedWork": {
          "type": "array",
          "items": { "type": "string" },
          "description": "What has been accomplished. Each entry: one concrete deliverable with enough context to verify. Ordered chronologically."
        },
        "deviations": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["description", "impact"],
            "properties": {
              "description": { "type": "string", "description": "What deviated from the plan" },
              "impact": { "type": "string", "description": "How this affects downstream work" },
              "batchOrigin": { "type": ["string", "null"], "description": "Which batch/delegation discovered this" }
            }
          },
          "description": "Where execution has diverged from the plan. Critical for FRAGORD decisions."
        },
        "facts": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Verified ground truths discovered during execution. New facts not in the original brief."
        },
        "assumptions": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["assumption", "status"],
            "properties": {
              "assumption": { "type": "string" },
              "status": {
                "type": "string",
                "enum": ["valid", "invalid", "unverified"],
                "description": "Has this assumption been confirmed or refuted during execution?"
              },
              "evidence": { "type": ["string", "null"] }
            }
          },
          "description": "Planning assumptions and their current validation status. Includes both brief assumptions (tracked) and new assumptions (discovered)."
        }
      }
    },

    "findings": {
      "type": "array",
      "description": "Consolidated findings from channel messages. S3 absorbs FINDINGs from delegated agents here. Each entry is a finding that has not yet been resolved or filed.",
      "items": {
        "type": "object",
        "required": ["id", "severity", "finding", "status"],
        "properties": {
          "id": { "type": "string", "description": "From original FINDING message ID" },
          "severity": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "finding": { "type": "string" },
          "location": {
            "type": "object",
            "properties": {
              "file": { "type": "string" },
              "line": { "type": ["integer", "null"] }
            }
          },
          "agent": { "type": "string", "description": "Which agent reported this" },
          "batchOrigin": { "type": ["string", "null"] },
          "status": {
            "type": "string",
            "enum": ["outstanding", "resolved", "deferred", "filed"],
            "description": "outstanding: needs action. resolved: fixed by later batch. deferred: will address later. filed: became incident via S1."
          },
          "resolution": { "type": ["string", "null"], "description": "How it was resolved, if resolved" }
        }
      }
    },

    "conclusions": {
      "type": "object",
      "description": "Adapted from Running Estimate Paragraph 5 (Conclusions and Recommendations). The primary product — everything above supports these.",
      "required": ["assessment"],
      "properties": {
        "assessment": {
          "type": "string",
          "description": "Is the operation proceeding according to the commander's intent? One paragraph: on track / at risk / off track, and why."
        },
        "recommendations": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["recommendation", "rationale"],
            "properties": {
              "recommendation": { "type": "string" },
              "rationale": { "type": "string" },
              "urgency": { "type": "string", "enum": ["immediate", "next-batch", "plan-end", "future"] }
            }
          },
          "description": "What the maintainer recommends based on the current situation. S2 recommends intelligence actions. S3 recommends operational adjustments."
        },
        "risksAndOpportunities": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["type", "description"],
            "properties": {
              "type": { "type": "string", "enum": ["risk", "opportunity"] },
              "description": { "type": "string" },
              "mitigation": { "type": ["string", "null"] }
            }
          },
          "description": "Emerging risks and opportunities not in the original plan."
        }
      }
    },

    "delegationLog": {
      "type": "array",
      "description": "Record of all delegations made under this estimate. Enables traceability and supports AAR.",
      "items": {
        "type": "object",
        "required": ["batch", "agentIdentity", "status"],
        "properties": {
          "batch": { "type": "string", "description": "Batch identifier from the plan" },
          "agentIdentity": { "type": "string", "description": "Identity assigned to the delegated agent" },
          "agentType": { "type": "string", "enum": ["general-purpose", "explore"] },
          "status": { "type": "string", "enum": ["delegated", "completed", "failed", "killed"] },
          "estimateVersionAtDelegation": { "type": "integer", "description": "Which version of this estimate was current when delegation occurred" },
          "sitrep": { "type": ["string", "null"], "description": "Reference to SITREP message ID if one was posted" },
          "verificationResult": { "type": ["string", "null"], "description": "S3's assessment after the delegation completed" }
        }
      }
    }
  }
}
```

### Required vs. Optional Fields

| Field | Required | Rationale |
|-------|----------|-----------|
| `meta` (all subfields) | Yes | Identity and versioning are always needed |
| `situation.currentState` | Yes | The minimum useful estimate is "where are we?" |
| `situation.completedWork` | No | Empty at plan start, populated during execution |
| `situation.deviations` | No | Empty when on track |
| `situation.facts` | No | Only new facts discovered during execution |
| `situation.assumptions` | No | Only if brief had assumptions to track |
| `findings` | No | Empty when no findings |
| `conclusions.assessment` | Yes | The primary product — always required |
| `conclusions.recommendations` | No | S2 may have none at plan start |
| `conclusions.risksAndOpportunities` | No | Populated as they emerge |
| `delegationLog` | No | Empty at plan start, populated during execution |

### Relationship to Other Schemas

| Schema | Relationship | Flow |
|--------|-------------|------|
| **SITREP** (decision #23) | SITREPs are point-in-time messages. S3 reads SITREPs and updates the running estimate. | SITREP --> running estimate (absorbed) |
| **FINDING** (decision #23) | FINDINGs are structured observations. S3 absorbs them into `findings[]` with status tracking. | FINDING --> running estimate.findings[] |
| **AAR** (decision #36) | The AAR is produced from the running estimate at plan end. `situation.completedWork` becomes observations, `findings` and `deviations` become the basis for insights, `conclusions.recommendations` inform proposals. | running estimate --> AAR (feeds) |
| **Planning brief** (decision #13/45) | The brief provides the initial `facts`, `assumptions`, and `planRef`. The running estimate tracks their evolution during execution. | planning brief --> running estimate (seeds) |
| **Delegation briefing** (decision #4) | The running estimate is extracted and injected into delegation briefings. Component 3 ("include prior results") IS the running estimate. | running estimate --> delegation briefing (extracted subset) |

---

## 4. Lifecycle Design

### When is a Running Estimate Produced?

The estimate follows the operations process: **plan, prepare, execute, assess**.

| Event | Who Produces | What Happens | Where Stored |
|-------|-------------|--------------|--------------|
| **Plan start** (S2 intelligence prep) | S2 | Creates initial estimate from planning brief: seeds facts, assumptions, known states. Produces intelligence assessment. | `.aitools/channel/session-XXX/{timestamp}_s2_running-estimate.json` |
| **Before each delegation** | S3 | Updates estimate with: completed work from last batch, findings absorbed, deviations noted, conclusions updated. Extracts relevant subset for delegation briefing. | Same file, version incremented |
| **After each delegation** | S3 | Updates estimate with: verification results, new findings, delegation log entry, assessment revision. | Same file, version incremented |
| **Plan end** (S2 consolidation) | S2 | Reads S3's estimate, cross-references all channel messages, produces final consolidated estimate and AAR. | Final version archived |
| **Session end** | S3 (or hook) | Estimate archived to `.aitools/harvesting/` by `channel-archive.sh` (high-severity channel message). | `.aitools/harvesting/YYYY-MM-DD_running-estimate_{session-prefix}.json` |

### Who Produces It?

**S3 (Operations) is the primary maintainer** of the running estimate during
plan execution. This is doctrinally correct: the S3 maintains the operations
running estimate, which is the central integrating document.

**S2 (Intelligence) contributes at two defined points:**
1. **Plan start**: S2 produces an initial intelligence estimate by reading the
   brief, prior channel, known states. This becomes the seed for S3's running
   estimate.
2. **Plan end**: S2 reads S3's running estimate and all channel messages,
   consolidates findings, produces the final AAR.

**S3 does NOT delegate estimate maintenance.** This is a critical design
decision. The estimate captures S3's synthesized understanding — what the
situation means across batches. A delegated agent only sees its own batch.
S3 is "the only element that persists" (plan opening addressee) and the
estimate is the artifact of that persistence.

### Where is it Stored?

The running estimate lives in the **channel directory** (decision #22):

```
.aitools/channel/session-XXXXXXXXXX/
  {timestamp}_s3_running-estimate.json    # S3's operations estimate
  {timestamp}_s2_running-estimate.json    # S2's intelligence estimate (plan start)
  {timestamp}_s2_aar.json                 # S2's AAR (plan end)
  {timestamp}_batch1-agent_sitrep.json    # Batch agent SITREPs
  {timestamp}_batch1-agent_finding.json   # Batch agent FINDINGs
  channel-manifest.json                   # Message index
```

The running estimate IS a channel message — it uses the same naming convention
(`{timestamp}_{agent-role}_{type}.json`), lives in the same directory, is
indexed by the same manifest. But it is a special type: it is updated in place
(version incremented) rather than appended like SITREPs and FINDINGs.

**Rationale for channel, not a separate location**: The running estimate is
the integrating document for all other channel messages. Storing it alongside
the messages it integrates is natural. The channel directory is already
session-scoped, gitignored, and archived by `channel-archive.sh` at session
end. No new infrastructure needed.

### How Does it Flow Between Sessions?

```
Session N                              Session N+1
---------                              -----------
S3 maintains running estimate          SessionStart hook creates channel dir
  |                                      |
  v                                      v
Session ends                           S3 reads brief + harvested estimate
  |                                      |
  v                                      v
channel-archive.sh archives            S2 intelligence prep:
  high-severity channel msgs             reads harvested estimate
  incl. running estimate                 reads brief
  to .aitools/harvesting/                produces new initial estimate
  |                                      |
  v                                      v
session-archive.sh archives            Execution begins with
  transcript to dotprofile              accumulated knowledge
```

The running estimate is archived to `.aitools/harvesting/` (tracked in git)
by `channel-archive.sh`. This makes it available to the next session. The
next session's S2 intelligence prep reads the harvested estimate from the
prior session as one of its inputs — along with the planning brief and any
prior channel archives.

**This is the carry-forward mechanism**: the archived running estimate carries
knowledge from session N into session N+1. The S2 agent at plan start reads
it, synthesizes it with the current brief, and produces a fresh initial
estimate that incorporates prior learning.

### Session-Level vs Plan-Level

Most sessions have exactly one plan execution, making session-level and
plan-level identical. When a session involves multiple plans (rare), S3
maintains one estimate per plan, each with a distinct `estimateId`.

When a session has NO plan (exploratory, research, one-off tasks), no
running estimate is needed. The estimate is a plan execution artifact, not
a general session artifact. Channel messages (SITREPs, FINDINGs) still work
without an estimate — they are standalone messages.

---

## 5. Integration with Existing Decisions

### Decision #4: Delegation Duty Component 3 — "Include Prior Results"

Component 3 says: "Include prior results — actual results, deviations, impact."

**The running estimate IS component 3.** When S3 delegates, it extracts the
relevant subset of the running estimate and includes it in the delegation
briefing. The delegation duty doesn't need a new mechanism — it needs to
reference the running estimate as the source for components 3 (prior results),
6 (deviations), and 7 (new findings).

Updated delegation duty mapping:

| Component | Running Estimate Field |
|-----------|----------------------|
| (1) Identity | Not from estimate (assigned by delegator) |
| (2) Include the plan | Not from estimate (plan file reference) |
| (3) Prior results | `situation.completedWork` + `situation.currentState` |
| (4) What comes after | Not from estimate (plan structure) |
| (5) Inject critical rules | Not from estimate (rules injection) |
| (6) Note deviations | `situation.deviations` |
| (7) Note new findings | `findings` (outstanding items) |
| (8) Match agent type | Not from estimate (task analysis) |

The `/delegate` skill template should include: "Read the current running
estimate. Extract components 3, 6, 7 from it for the delegation briefing."

### Decision #22: Channel Directory

The running estimate lives in `.aitools/channel/session-XXX/` as a channel
message type. No new directory needed. The channel manifest indexes it like
any other message.

New channel message type to register in `reference/channel-schemas.json`:

```json
{
  "type": "RUNNING_ESTIMATE",
  "description": "Continuously updated operations or intelligence state document",
  "schema": "reference/running-estimate-schema.json",
  "lifecycle": "updated-in-place (version incremented), not append-only",
  "archival": "always archived by channel-archive.sh (high severity equivalent)"
}
```

### Decision #26: S2 at Plan Start/End

**Plan start (intelligence preparation)**:
1. S3 delegates to S2 with: brief path, prior harvested estimates, channel
   archive paths
2. S2 reads these inputs
3. S2 produces initial running estimate (`scope: "plan"`, `maintainer: "s2"`)
4. S2 returns estimate to S3
5. S3 absorbs S2's estimate into its own (`maintainer: "s3"`), adding
   operational fields (delegation log, etc.)

**Plan end (consolidation)**:
1. S3 delegates to S2 with: S3's running estimate, all channel messages
2. S2 reads everything, cross-references findings with completed batches
3. S2 produces: final consolidated estimate + AAR (per decision #44)
4. S2 delegates to S1 for incident filing of outstanding findings
5. S3 receives S2's final products, updates its own estimate to version=final

### Decision #44: S2 AAR Format

The AAR and the running estimate are complementary but distinct:

- **Running estimate**: "what IS" — current state, continuously maintained
- **AAR**: "what HAPPENED and what to CHANGE" — retrospective, produced once

The running estimate feeds the AAR:
```
running estimate          AAR
------------------        ---------
completedWork        -->  observations (what happened)
deviations           -->  observations (what diverged)
findings             -->  insights (why things surfaced)
conclusions          -->  proposals (what to change, with barrier analysis)
delegationLog        -->  observations (execution trace)
```

S2 does not need to re-derive the facts — they are in the running estimate.
S2's AAR job is analysis (why) and proposals (what to change), not
re-reporting what happened.

### Decision #3: Mission Command Framework

The running estimate becomes a first-class concept in the Mission Command
framework:

- **Rule** (`.claude/rules/delegation.md`): trigger directive — "maintain
  a running estimate during plan execution; extract relevant fields for
  delegation briefings"
- **Skill** (`/delegate`): produces delegation briefings that include
  running estimate extracts
- **Skill** (`/brief`): at plan start, seeds the initial estimate from the
  brief's facts and assumptions
- **Reference** (`reference/framework-mission-command.md`): documents the
  running estimate concept, its ADP 5-0 provenance, and harness adaptation

---

## 6. The Ad-Hoc Carry-Forward That Prompted This Design

The JSON in the S3 delegation prompt that started this session IS a running
estimate, just without the name or schema:

```json
{
  "situation": {             // <-- situation paragraph
    "completedWork": [...],  // <-- accomplished tasks
    "currentState": "...",   // <-- where we are now
    "deviations": [...]      // <-- plan deviations
  },
  "findings": {              // <-- consolidated findings
    "outstanding": [...]
  },
  "openQuestions": [...]     // <-- maps to conclusions.recommendations
}
```

This validates the design: the ad-hoc carry-forward naturally converges on
the running estimate structure. The schema formalizes what was already
intuitive.

---

## 7. Lifecycle Detail: Step by Step

### Step 1: S3 Starts a Session with a Plan

```
S3 reads the plan
S3 reads the planning brief (via /brief skill)
S3 delegates to S2 for intelligence preparation
```

### Step 2: S2 Intelligence Preparation

S2 receives:
- Planning brief path
- Path to harvested running estimates from prior sessions (if any)
- Path to prior channel archives (if any)

S2 produces:
```json
{
  "meta": {
    "estimateId": "uyZ7TELqpP_plan_s2",
    "maintainer": "s2",
    "scope": "plan",
    "planRef": "plans/mission-command-and-platform-engineering.md",
    "briefRef": "plans/mission-command-briefing/planning-brief.json",
    "sessionId": "uyZ7TELqpP",
    "created": "2026-03-16T14:30:00Z",
    "updated": "2026-03-16T14:30:00Z",
    "version": 1
  },
  "situation": {
    "currentState": "4 critical blockers resolved. 48 decisions captured in brief. 92 reciprocal links still missing. Flat verb naming not yet formalized. This is the first plan execution for the Mission Command framework.",
    "completedWork": [
      "Planning brief built: 48 decisions, 18 facts, 7 assumptions (schema v6.0)",
      "Critical blockers F1/F2/F3/F17 resolved",
      "Tool-registry.json created from migration"
    ],
    "facts": [
      "harvest-session.sh line 80 silently deletes .json files (RCA completed, fix not applied)",
      "Subagents cannot write to scratch (Write permission denied consistently)"
    ],
    "assumptions": [
      { "assumption": "A1: Closing 14 incidents won't break downstream references", "status": "unverified", "evidence": null },
      { "assumption": "A7: Hooks are the most effective structural enforcement", "status": "unverified", "evidence": null }
    ]
  },
  "findings": [],
  "conclusions": {
    "assessment": "Plan is ready for execution. All critical blockers resolved. Primary risk: plan scope is large (48 decisions across 4 frameworks). Recommend sequencing infrastructure (decision #32 log_ship) first to enable KPI measurement for all subsequent work.",
    "recommendations": [
      {
        "recommendation": "Sequence decision #32 (log_ship + SQLite) in first execution phase",
        "rationale": "All KPIs are aspirational until telemetry pipeline exists",
        "urgency": "immediate"
      }
    ],
    "risksAndOpportunities": [
      {
        "type": "risk",
        "description": "Plan scope (48 decisions) may require multiple sessions. Running estimate carry-forward is critical for continuity.",
        "mitigation": "Archive estimate at session end. S2 reads it at next session start."
      }
    ]
  },
  "delegationLog": []
}
```

### Step 3: S3 Absorbs and Maintains

S3 takes S2's estimate, changes `maintainer` to `"s3"`, increments version,
and begins execution. Before each delegation:

1. Read the current estimate
2. Update `situation.completedWork` with results from last batch
3. Absorb new FINDINGs into `findings[]`
4. Update `situation.deviations` if execution diverged
5. Revise `conclusions.assessment`
6. Increment `meta.version`
7. Extract relevant subset for delegation briefing (components 3, 6, 7)
8. Record the delegation in `delegationLog[]`

### Step 4: After Each Delegation

1. Read SITREP from completed batch (if posted)
2. Read any FINDINGs from completed batch
3. Update `findings[]` statuses (some may be resolved by this batch)
4. Update `delegationLog[]` with verification result
5. Revise `conclusions.assessment` — is the operation on track?
6. If deviation detected: add to `situation.deviations`, evaluate FRAGORD

### Step 5: Plan End — S2 Consolidation

S3 delegates to S2 with: current running estimate + all channel messages.

S2 produces:
1. Final consolidated estimate (version = N+1)
2. AAR (per decision #44 schema): observations from estimate, insights
   from analysis, proposals with barrier analysis
3. Outstanding findings list for S1 incident filing

### Step 6: Session End — Archival

`channel-archive.sh` (SessionEnd hook) archives the running estimate to
`.aitools/harvesting/YYYY-MM-DD_running-estimate_{session-prefix}.json`.

The archived estimate is available to the next session's S2 intelligence
prep.

---

## 8. Open Questions Resolved

### Q: When does a carry-forward get produced? Session start? Every delegation? Both?

**A**: The running estimate is **continuously maintained**. Initial creation
at plan start (by S2), updated before and after every delegation (by S3).
There is no single "production" event — that would make it a snapshot, not
a running estimate.

### Q: Does S3 instantiate it at session start via a hook?

**A**: No. S3 delegates to S2 at plan start. S2 creates the initial estimate.
If there is no plan (ad-hoc session), no estimate is created. A hook could
create a stub, but that adds complexity for marginal value — the S2
delegation is already a defined step (decision #26).

### Q: When S3 delegates to a batch agent, does it also spawn S2 to produce a carry-forward?

**A**: No. S3 maintains the estimate itself. S2 is spawned only at plan
start and plan end (decision #26). Between batches, S3 reads channel
messages and updates the estimate directly. S2 is the intelligence analyst;
S3 is the operations coordinator. S3 doesn't need S2 to update its own
running state.

### Q: Or does S3 produce the carry-forward itself as part of the delegation duty?

**A**: Yes. Maintaining the running estimate IS part of S3's operational
duty. Before each delegation, S3 updates the estimate and extracts a
subset for the briefing. This is delegation duty component 3 ("include
prior results") with a concrete mechanism.

### Q: Are the schemas the same for session-level and delegation-level carry-forward?

**A**: Yes. One schema, different scopes. The `meta.scope` field
distinguishes them. A delegation-level extract is a read-only subset of
the plan-level estimate — same fields, possibly fewer entries.

### Q: How does this fit into the channel framework (decision #22)?

**A**: The running estimate IS a channel message type. It lives in
`.aitools/channel/session-XXX/`, uses the channel naming convention, is
indexed by `channel-manifest.json`. Its lifecycle differs (updated in
place vs. append-only), which is documented in the channel schema
registry.

### Q: What naming convention? How do carry-forwards relate to SITREPs and FINDINGs?

**A**: See Section 2. SITREPs and FINDINGs are inputs that S3 absorbs into
the running estimate. The estimate integrates them. The term is "running
estimate" (governed), not "carry-forward" (informal).

### Q: The military uses 'running estimate' (ADP 5-0) — is our carry-forward the same thing or different?

**A**: It is the same concept, adapted to our harness constraints. The
governed term is "running estimate." "Carry-forward" was the working label
before we identified the doctrinal source.

---

## 9. Artifacts Required

| Artifact | Type | Status | Governed By |
|----------|------|--------|-------------|
| `reference/running-estimate-schema.json` | Schema | Proposed | Mission command |
| `reference/framework-mission-command.md` (section) | Reference | Proposed | Mission command |
| `reference/channel-schemas.json` (RUNNING_ESTIMATE type) | Schema | Proposed | Mission command |
| `.claude/skills/delegate/SKILL.md` (estimate extract) | Skill | Proposed | Mission command |
| `shared/skills/brief/SKILL.md` (estimate seeding) | Skill | Proposed | Mission analysis |
| `shared/skills/debrief/SKILL.md` (estimate-to-AAR) | Skill | Proposed | Operational learning |
| `reference/framework-registry.json` (provenance entry) | Registry | Existing | Framework adoption |
| `reference/glossary.json` (running estimate term) | Registry | Existing | Governed vocabulary |

---

## 10. KPIs

| KPI | Source | Unit | Target |
|-----|--------|------|--------|
| `estimateMaintenanceRate` | channel-manifest.json | percent plan executions with running estimate | 100% |
| `estimateVersionsPerPlan` | running estimate meta.version | versions per plan execution | >= batches + 2 (initial + per-batch + final) |
| `estimateFreshness` | delegation briefings vs estimate version | percent delegations using latest version | 100% |
| `findingAbsorptionRate` | findings[] vs channel FINDINGs | percent channel FINDINGs absorbed into estimate | 100% |
| `carryForwardSuccessRate` | S2 intelligence prep inputs | percent sessions where prior estimate was available | >= 90% |

---

## 11. Implementation Sequencing

This design depends on:
1. **Decision #22** (channel directory) — must exist before estimate can be stored
2. **Decision #23** (channel skill + SITREP/FINDING schemas) — estimate integrates these
3. **Decision #26** (S2 at plan start/end) — S2 creates and consolidates estimates
4. **Decision #4** (delegation duty) — estimate extracts feed delegation briefings
5. **Decision #36** (operational learning) — estimate feeds AAR

Recommended sequence: build channel infrastructure (#22, #23) first, then
running estimate schema, then wire into /delegate (#4) and /brief (#13),
then wire into /debrief (#36).

---

## Sources

- [ADP 5-0, The Operations Process (July 2019)](https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN18126-ADP_5-0-000-WEB-3.pdf)
- [Staff Processes in LSCO Pt. 2: Running Estimates](https://www.army.mil/article/279458/staff_processes_in_lsco_pt_2_running_estimates_crawling_when_we_need_to_run)
- [ATTP 5-0.1 Commander and Staff Officer Guide](https://www.globalsecurity.org/military/library/policy/army/attp/attp5-0-1.pdf)
- [FM 6-0 Commander and Staff Organization and Operations](https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN35404-FM_6-0-000-WEB-1.pdf)
- [150-C2-5144 Develop a Running Estimate](https://rdl.train.army.mil/catalog-ws/view/100.ATSC/AE2A7CCF-0DC7-4131-98D2-39A581116CBC-1596204072287/report.pdf)
