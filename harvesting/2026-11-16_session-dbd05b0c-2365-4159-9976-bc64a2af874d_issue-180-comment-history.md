## History: the commander's March 2026 schemas (moved from body v2.0, verbatim)

Body v3.0 (2026-11-15, session dbd05b0c) replaces these sections with the schemas the commander decided on 2026-11-15. They are kept here word for word, as the record the decisions build on. Where this history says `insights` or `findings`, read the decisions in the body: the AAR node became `findings` (D-SR2) and then `deviations` (D-SR22). Citation conventions (`<dp>`, `L<n>`) are in the body under "How to read the citations".

## 1. AAR (after-action review)

### Latest version (D-SR1, D-SR2, D-SR3, D-SR4)

An AAR is a JSON document with three top-level nodes, plus `meta`. The commander set the node names on 2026-03-16 (D-SR1) and renamed the middle node on 2026-11-15 (D-SR2). The three March names (observation, insight, lesson) echo the CALL taxonomy (Center for Army Lessons Learned). Mission fa81-04 found no CALL source to read (`reference/framework-intelligence-types.md` "Not read"), so the names rest on the commander's decisions, not on CALL.

Every entry is an intelligence item of a type defined in `reference/framework-intelligence-types.md` (PR #181), with that file's common and provenance fields (`attributed_to`, `source_kind`, `source`, `quote`, `created_at`). The fields below are what each node adds.

| Node | Meaning | Holds types | Fields (this issue) | Source |
|---|---|---|---|---|
| `meta` | Who, which mission, when | | `mission`, `agent`, `session`, `produced`; `intent_as_understood` if RFI fa81-40 is answered yes | `harvesting/2026-03-22_6_m1-running-estimate-lifecycle-aar.json` |
| `observations[]` | "what happened — facts" | observation, fact, assumption (with its status) | `id` (`OBS-<n>`), `type`, `text`, `evidence`, `severity` (optional), `status` | planning-brief #36 (3); D-SR5; PR #181 |
| `findings[]` | why: the analysis | finding, operational learning (D-SR4) | finding: `id` (`F-<n>`), `observation_refs[]`, `text` (the condition), `criteria`, `cause`, `effect`, `suggestion`, `confidence`, `severity`. Operational learning: `id` (`OL-<n>`), `text`, `finding_refs[]` | D-SR2, D-SR3; GAO elements in PR #181 |
| `proposals[]` | "what to change — with barrier analysis field validating each proposal" | proposal, rfi | proposal: `id` (`P-<n>`), `finding_refs[]`, `what`, `why`, `barrier_analysis`, `severity`, `affected` (files, decisions), `disposition`. rfi: `id` (`<sid4>-<n>`), `title`, `question`, `suggestion`, `answer` | D-SR1; planning-brief #36 (3), #44 (3); D-SR3 |

- **Earlier field names.** The 2026-03-21 delegate AARs (harvested, `harvesting/2026-03-22_6_m*-aar.json`) used `insights[]`, `I-<n>`, `analysis`, `insight_refs[]`, and `fact` for the observation text. D-SR2 and D-SR3 rename them. The harvested files keep their names as history.
- **`finding_refs[]` on operational learning.** The commander asked for `finding_refs[]` on proposals (D-SR3). Giving operational learning the same field follows the reference file's `refs` from an OL to its findings. *(suggested)*
- **`INCIDENT:` and `CONFLICT:`.** These lines and `WRITE_BLOCKED` stay mandatory in the hand-back. An incident is a finding about the harness, tracked in the incident registry (PR #181, "A finding and an incident").

Planning-brief #44 component (3), verbatim: "Each proposal includes: what to change, why, barrier analysis (would this have prevented the issue?), severity, affected decisions".

Planning-brief #36 component (13) (agent-written, status "agreed"): each validated proposal becomes a harness change, a fact in the next brief, an incident (through S2 and S1), or is dismissed.

### Timeline

| When (UTC) | Who | What | Source |
|---|---|---|---|
| 2026-03-15 | agent | First AAR: prose Markdown, nine sections (executive summary, timeline, key decisions, framework adoption, plan evolution, military doctrine parallels, what went right, what could improve, lessons for future plans). The prompt that ordered it was not found in the archive | `harvesting/2026-03-16_aar-tool-ops-plan.md` |
| 2026-03-16 18:48:52Z | agent | Proposes three nodes: "1. **Observations** — what happened (facts) 2. **Insights** — why it happened (analysis) 3. **Decisions** — what to change (proposed actions)" (line breaks removed) | `<dp>/sessions/aitools/2026-03-16_79b05dd0.jsonl` L414 |
| 2026-03-16 18:53:09Z | **commander** (approves and amends; D-SR1) | "ok so the aar is a json file with 3 top level nodes, but we need to change the name of the last one from decisions to proposals.  this is also where we need to formalize "barrier analsis"" | same file, L419 |
| 2026-03-16 19:13:15Z | **commander** (approves the agent's text he quotes, then adds) | Quotes the agent: "The AAR is ALWAYS harvested". Adds: "you have a tendancy to want to use one hook for everything, remember each hook needs an intent" | same file, L507 |
| 2026-03-16 19:32:00Z | **commander** | "s2 should have produced something like an AAR no? with proposed decisions?" (led to planning-brief #44: every S2 output uses the AAR schema) | same file, L689 |
| 2026-03-17 02:14:44Z | **commander** | On a delegate's output: "nope, the output defined with a schema, similar to an AAR.  capture this intent by auditing the briefing and my past recent conversations first" | `<dp>/sessions/aitools/2026-03-16_37ab88e4.jsonl` L449 |
| 2026-03-17 03:17:43Z | **commander** | Generalises it: "where you are an agent you delegate produces an AAR, from a briefing audit or check or investigate or post-plan or whatever (generalize)" | same file, L705 |
| 2026-03-16 (commit) | agent (status "agreed") | Planning-brief #36 (AAR schema, `/debrief`, `reference/aar-schema.json`), #44 (S2 output uses the AAR schema), #49 (`/debrief` as a flat-verb skill) | `plans/mission-command-briefing/planning-brief.json`, first commit `c6ab931` |
| 2026-03-21 15:16:09Z | **commander** | "at the end i need you to produce a brieefing or aar.  (what does the military call this, what it is we are using, how doeos it map to your /frameworks and our provenance?)" | `<dp>/sessions/aitools/2026-03-21_ab5da7ea.jsonl` L163 |
| 2026-03-21 15:18:11Z | agent (not adopted) | Offers the TC 25-20 five-part AAR (intent, what happened, sustain, improve, lessons learned). The commander answered the agent's other questions and left the AAR shape to be settled "when we find our briefings" (L173) | same file, L168, L173 |
| 2026-03-21 16:50:54Z | **commander** | "i want two things: a json file from the ad-hoc briefing in handof-prompt as well as an aar and/or briefing for this session as well as aars/briefings when delegating where appropriate"; "then report back in the formal way we described in this conversation." | same file, L643 |
| 2026-03-21 17:24:00Z | **commander** | "produce a formal aar, including aars and proposals."; "report back using formal aar with observations and proposal." | same file, L666 |
| 2026-03-21 17:30:12Z | agent (used under the commander's order) | Delegation prompts carry "## Output format — AAR (required)", with Observations, Insights, Proposals and "Do NOT produce prose reports." The AARs returned are in `harvesting/2026-03-22_6_m*-aar.json` | same file, L675, L678 |
| 2026-03-22 15:23:40Z | **commander** | "an OL estimate looks very similar to the AARs we have been using on mac" | `<dp>/sessions/aitools/2026-03-22_77a33baf.jsonl` L1359 |
| 2026-03-23 15:10:26Z | **commander** (lighter form, for a handoff) | "just say your session name, what we did, the rfcs we drafted, the source material i gave you (the repos and directories).  why we did what we did sources, work product generated (all the research, things we discovered, like an after action report in the military (you can see how i do that very structured way in aitools but i dont want all that formal stuff but i do want to capture its intentn" | `<dp>/sessions/nobul-ops/2026-03-23_28bbf7f7.jsonl` L1750 |
| 2026-03-30 14:51:37Z | **commander** | "telemtry, AARs, that is all part of mission analysis, and part of operational learning, and part of provenace tracing right?" | `<dp>/sessions/aitools/2026-03-30_ddfe01cb.jsonl` L947 |
| 2026-11-15 | **commander** (answer 4; D-SR5) | "in the AAR.  dont call them post-merge facts, they are either observations or operational learning.  use the governed vocabulary.  there should be a schema for defined intelligence types" | session 87795dc3, live transcript L8030 |
| 2026-11-15 | **commander** (D-SR3, D-SR4, D-SR2) | "i kind of like findings over insights ..."; answer 45 "keep under insights"; "46) yes, add it to gh issue mission thing or whatever" | session 87795dc3 (comment on this issue; PR #181) |
| 2026-11-15 08:54:54Z | mission fa81-04 (PR #181 merged) | Harness-DB schema v4 with the intelligence types; `finding` is the analysis type; SALUTE FINDING retired (D-SR6); glossary updated | PR #181, merge commit `b1b7b5e` |
| 2026-11-15 20:04:17Z | **commander** (D-SR3) | "lets use finding as intelligence type, not insight.  so we want finding_refs[]." | session dbd05b0c L79 |

## 2. Running estimate

### Latest version

**Structure.** Planning-brief #50 (2026-03-16, agent-written, status "agreed"), as extended by the commander's orders of 2026-03-21/22. The session estimate that resulted is `harvesting/2026-03-22_6_running-estimate-authoritative.json`.

| Section | Fields | Source |
|---|---|---|
| `meta` | `estimateId`, `maintainer`, `scope` (session, plan or delegation: "One schema, all levels"), `sessionId`, `created`, `updated`, `version`, `versionHistory[]` | #50 (2), (9); authoritative estimate |
| `schwerpunkt`, `acceptingSessionSchwerpunkt` | main effort now, and for the next session | authoritative estimate |
| `situation` | `currentState` (required), `completedWork[]`, `deviations[]`, `facts[]`, `assumptions[]` (status, evidence, verifiedBy), `decisions[]` (decidedBy, status) | #50 (9), (10) |
| `observations[]`, `hardRequirements[]`, `planScaleItems[]` | added by the commander's 2026-03-21/22 orders (below) | authoritative estimate |
| `findings[]`, `openThreads[]` | In March, `findings[]` held SALUTE FINDINGs consolidated from the channel; threads READY, BLOCKED or DEFERRED. Under D-SR6 those SALUTE reports are observations (SPOTREPs), and `findings[]` holds analysis findings (D-SR3). PR #181 left the export key `findings` fed from SPOTREP messages and named the rename as work for this issue | #50 (9); PR #181 "Follow-ups" |
| `conclusions` | `assessment` (required), `recommendations[]`, `risksAndOpportunities[]`: "conclusions first per doctrine" | #50 (9), (10) |
| `delegationLog[]` | execution trace for the AAR | #50 (9), (11) |

Planning-brief #50 component (11): the estimate feeds the AAR. `completedWork` feeds observations, `deviations` are the basis for findings (#50 says "insights"; renamed by D-SR2), and `conclusions.recommendations` seed proposals.

**Scope and writers.** One estimate per session, as JSON, edited directly by the session commander and every delegate (D-SR8). It is not shared across sessions (D-SR9). Several sessions coordinating through their estimates is a roadmap item (D-SR10). How parallel delegates within one session share the file is RFI 874d-1.

**Store and format.** The commander's March statements, below, pointed to SQLite. His November answers name JSON or Markdown, with a schema and a template (D-SR7), and make the running estimate JSON (D-SR8):

- 2026-03-25: JSON is too cumbersome; use SQLite.
- 2026-03-26: the friction comes from the implementation, not SQLite. He deferred the format by order.
- 2026-03-28: the decision is recorded: "JSON has too much friction".
- 2026-03-29: SQLite during agentic turns, with "SOME stuff" in context.
- 2026-03-30: every entry is an intelligence item that carries its own provenance.
- 2026-11-15: D-SR7, D-SR8.

All quotes and sources are in the timeline below.

**Content the commander named for an estimate** (2026-03-26, `<dp>/sessions/aitools/2026-03-26_8236ca9c.jsonl`):
- L115: "print succintly your running estimate, operational learning, orders, assumptions, role, duty, identity and what yu know about yoru superior."
- L755: "produce your assessment and running estimate and OL that you've gatherered from this session and assumptions identified and their status and carry everything forward to the next turn, write it to a persisitent store", then "for each assumption observation, decision, knew knowlege, incident, operational learning gathered, produce a set of proposals of how to deal with them in this session", "peforming barrier analysis and using provenance tracing".

The estimate written under that order is `harvesting/2026-03-27_session-8236ca9c-b_running-estimate-v1.md`. Its sections: a header (session, commander, status, context, mission), Operational Learning, Decisions, Assumptions (Verified, Corrected, Invalidated, Open, Deferred, Blockers), Incidents, Provenance Mapping, Proposals (with a barrier analysis summary).

### Timeline

| When (UTC) | Who | What | Source |
|---|---|---|---|
| 2026-03-16 | agent (status "agreed") | Planning-brief #50: running estimate adapted from ADP 5-0. "One schema, all levels". S3 maintains it, S2 contributes. It lives at `.aitools/channel/running-estimate.json` (tracked). The SessionStart hook seeds it. `reference/running-estimate-schema.json` was proposed. The conversation that agreed #50 was not found in the archive. | `planning-brief.json` #50; first commit `c6ab931` |
| 2026-03-21 17:28:30Z | **commander** (AskUserQuestion answer) | Per-session estimates with reconciliation at handoff: `="Per-session estimates (Recommended)"` | `<dp>/sessions/aitools/2026-03-21_ab5da7ea.jsonl` L672 |
| 2026-03-21 18:33:54Z | **commander** | "operational learning is continous." | same file, L1138 |
| 2026-03-21 21:34:47Z | **commander** | "our running estimate: can we use a hook at every user prompt to get that updated?" | same file, L1341 |
| 2026-03-22 02:03:15Z | **commander** | "capture this as decisions/observations/ plan-scale in the running estimate." | same file, L1797 |
| 2026-03-22 14:13:29Z | **commander** | "capture this as one ore many obeservations in our running estimate, as well as assumptions, ambigutiots etc.. the whole schema." | `<dp>/sessions/aitools/2026-03-22_77a33baf.jsonl` L861 |
| 2026-03-25 03:15:49Z | **commander** | "im making an observation that json is too cumborsome a format for running estimate and operational learning.  it creates too much friction.  we should be using sqlite for these." | `<dp>/sessions/aitools/2026-03-24_c0dc2ddc.jsonl` L1313 |
| 2026-03-25 12:20:11Z | **commander** | "our remote githit repo and issues there, and commit history and release notes are another form of a running estimate/carry forward/operational history" | same file, L1901 |
| 2026-03-26 13:16:25Z | **commander** | "using json for incidents, operational learning, running esitmates during sessions or during the lifcycle of a running agent has proven to be the wrong format" | `<dp>/sessions/aitools/2026-03-26_8236ca9c.jsonl` L75 |
| 2026-03-26 13:17:06Z | **commander** | "correction, SQLITE has not been proven to be high-friction, it's the way we have iimplemented it that has proven to be high-friction." | same file, L78 |
| 2026-03-26 13:40:22Z | **commander** | On the running estimate format: "1) we will answer that later, it is deferred, dont bring it up until i say so, thats an order" | same file, L110 |
| 2026-03-26 13:43:16Z, 18:16:52Z | **commander** | The content lists quoted above | same file, L115, L755 |
| 2026-03-28 23:02:59Z | **commander** | "we have made the decision JSON has too much friction for incidents/ols/decisions/assumptions/briefings/ (what else am i missing) and have partially implemented this in python sqlite3." | `<dp>/sessions/aitools/2026-03-28_fbf7decb.jsonl` L707 |
| 2026-03-29 16:07:52Z | **commander** | "sqlite at agentic turns to query the knowledge db and to write to it. not here, in context, where it eats up our window,  i want to see SOME stuff here, but when you are in your agentic turns, can you keep track of intelligence/briefings/aars/running estimates that way as well?" | `<dp>/sessions/nobulai-tools/2026-03-29_f5fa32f9.jsonl` L675 |
| 2026-03-30 14:57:41Z | agent (the commander affirmed the per-item principle, not every field) | A universal intelligence item schema: identity, content, bitemporal validity, attribution, authority and trust, staleness, source, domain context, measurement, promotion, lifecycle; edges `derived_from`, `informed`, `triggered`, `validated`, `invalidated`, `superseded` | `<dp>/sessions/aitools/2026-03-30_ddfe01cb.jsonl` L985 |
| 2026-03-30 16:04:00Z | **commander** | "so the intelligence schema per item, includes provenance, and provenance is its own schema and a graph itself" | same file, L1129 |
| 2026-03-30 16:05:39Z | **commander** | "intelligence is continuous, provenance is eternal" | same file, L1133 |
| 2026-11-15 | **commander** (answers 1 and 3; D-SR7, D-SR8) | "json or markdown not sure, for either we need schema and template/defined structure"; "one per session, as json, all delegates edit directly, json allows for this right? the multi-writer, without issue? its the main reason to do json" | session 87795dc3, live transcript L8030 |
| 2026-11-15 20:04:17Z | **commander** (D-SR9, D-SR10) | "41) running estimates, for now, will NOT be shared across sessions ..."; "that roadmap item is a decision." | session dbd05b0c L79 |

## 3. Briefings

March produced four kinds of briefing. A fifth arrived on 2026-11-15.

### 3a. Planning brief (before a plan)

- **2026-03-16 13:04:39Z, commander** (`<dp>/sessions/aitools/2026-03-16_b8a9ed4e.jsonl` L851): "we probably need a json file with some schema that will capture capture each decision/requirement/intent".
- **17:02:06Z, commander** (L1887): "wait why are you recommending types for decisions i hate that.  decisioins re decisions, this is something else."
- **17:04:33Z, agent** (L1892): proposes `decisions`, `facts`, `assumptions`, from the MDMP mission-analysis outputs.
- **17:07:45Z, commander** (L1897): "bam, you nailed the briefing top level nodes".
- **Result**: `plans/mission-command-briefing/planning-brief.json`, schema 6.0. Top-level `meta`, `facts`, `assumptions`, `decisions`. Each decision has `id`, `decision`, `rationale`, `context`, `components`, `frameworks`, `artifacts` (each with an intent), `kpis`, `status`, `related`.
- Planning-brief #45 and #49 proposed a `/brief` skill to gate it; it was never built, and is not built now (D-SR11).
- **2026-11-15, commander** (D-SR12): the planning brief defines the delegate's mission objectives (section 3e).

### 3b. SITREP and SPOTREP (was FINDING) messages (during a mission)

- **2026-03-16 15:35:28Z, commander** (`b8a9ed4e` L1505): "we need to define the SALUTE schema."
- **15:36:40Z, agent** (L1507): maps SALUTE to `severity`, `finding`, `location`, `agent`, `timestamp`, `context`.
- **15:44:51Z, commander** (L1519): "also i noticed you didnt list SALUTE in subagent whats." No field-level approval was found. The fields landed in planning-brief #23, status "agreed":
  - SITREP: `{type, agent, timestamp, batch, status, filesWritten, filesModified, summary}`
  - FINDING (SALUTE): `{type, severity, finding, location:{file,line}, agent, timestamp, context, actionTaken, recommendation}`; "FINDING severity=critical is the SPOTREP"
- **2026-11-15, D-SR6**: the FINDING message is retired. Its content is an observation with a severity, sent as a SPOTREP (`harness-db.py log --type spotrep`, PR #181). The word "finding" now means the analysis type (D-SR3).
- Planning-brief #24 (status "agreed"): agents are sensors, not filers. Their reports go from the channel to S2 consolidation, then to S1 incident filing.
- The `/channel` skill and `reference/channel-schemas.json` were never built, and are not built now (D-SR11).

### 3c. Handoff briefing (between sessions)

- **2026-03-21, commander** (`ab5da7ea` L643): "a json file from the ad-hoc briefing in handof-prompt".
- **Result**: `harvesting/2026-03-22_6_handoff-briefing.json`, `schemaName: "handoff-briefing"`, 14 sections: `meta`, `sourceOfTruth`, `intelligencePrep`, `sessionChain`, `shippedWork`, `approvedDecisions`, `schwerpunkt`, `exclusionClauses`, `openThreads`, `provenanceResearch`, `delegationDutyUpdates`, `planWritingProtocol`, `briefAmendments`, `provenance`.
- **2026-03-23, commander** (lighter, `28bbf7f7` L1750, quoted in section 1): session name, what we did, RFCs drafted, source material, why and sources, work product, with the intent of an AAR but without "all that formal stuff".

### 3d. Brief to the commander (a backbrief)

- **2026-03-26, commander** (`8236ca9c` L115): running estimate, operational learning, orders, assumptions, role, duty, identity, what you know about your superior.
- The agent's reply (L117) used these headings. The commander then corrected the process, not the headings (L120 onward).

### 3e. Mission Brief (2026-11-15, the commander's own edit)

- `/delegate` element 10, commit `1b34fa2` (2026-11-15 01:21:44Z): "Mission Brief | A structured briefing of all mission objects, citing source of user/commander/agent directives verbatim and their source".
- No field list yet. This issue proposes one.
- **2026-11-15, commander** (D-SR12): "The planning brief should define the mission objectives for the delegate." The planning brief and this Mission Brief element are the same thing: the brief that sets a delegate's mission objectives.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
