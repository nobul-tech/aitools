## Objective

"implement structured running estimates, briefings, aars" (commander, 2026-11-15, session 87795dc3)

## Why now

The commander's order, verbatim (2026-11-15, session 87795dc3, live transcript L7693):

> 34)ignore for now, we want a structured response in the form of an AAR/briefing.  search my claude code session from march for the schema for an AAR/briefing, file gh issue feature request to, objective: implement structured running estimates, briefings, aars.  inform the GH issue body with my claude code session schemas and cite with sessions by file path and date have the schemas.

Question 34 asked where delegates record what they learn after a merge. The answer: a delegate returns a structured AAR/briefing, not free text.

Today a delegate hands back the free-text list in `/delegate` "Final response shape". What a delegate learns after its merge has no home: issue #177 open question 2 asks whether a report update after a merge goes in the hand-back only or straight to main. The commander's answer (2026-11-15, answer 4 below): "in the AAR", as observations or operational learning.

**Update 2026-11-15.** The commander answered the six open questions filed with this issue (session 87795dc3, live transcript L8030). The questions and his answers are posted verbatim in a comment on this issue. This body now reflects them:
- Storage is open: JSON or Markdown, with a schema and a template either way (answer 1).
- One running estimate per session, as JSON, edited directly by every delegate (answer 3). Whether one JSON file can take several writers is an open question below.
- What a delegate learns after a merge goes in its AAR, as observations or operational learning, in governed vocabulary (answer 4). The section "Intelligence types: what exists today and suggested changes" adds the schema he asked for.
- Nothing gets built for `/debrief`, `/brief` or `/channel` now (answer 5).
- The planning brief defines the delegate's mission objectives (answer 6).

The commander designed these structures in March 2026: AAR, running estimate, briefings (planning brief, SITREP/FINDING, handoff briefing, brief to the commander). Most of the designs were never built. This issue collects the commander's schemas, each element cited, so the implementation starts from his words.

**How to read the citations**
- `<dp>` is the commander's dotprofile repo, `aitools-nobul-jose`. Session archives are at `<dp>/sessions/<project>/<YYYY-MM-DD>_<id8>.jsonl`.
- The date in a file name is the session's local start date. Times are UTC, from the JSONL `timestamp`.
- `L<n>` is the line number in the JSONL file.
- "Commander" means the commander's own prompt. "Agent" means text an agent wrote; an agent proposal counts only where the commander approved or used it, and each one is marked.
- Quotes keep the commander's spelling.

## Schemas at a glance

| Schema | Latest commander version | Source | Status in the harness |
|---|---|---|---|
| AAR | 2026-03-16: JSON, three top-level nodes `observations`, `insights`, `proposals`; barrier analysis on each proposal. Used as the delegate return format on 2026-03-21 | `<dp>/sessions/aitools/2026-03-16_79b05dd0.jsonl` L419 | Not built: no schema file, no `/debrief` skill, not in `/delegate` |
| Running estimate | Structure: 2026-03-16 decision #50, extended by the commander on 2026-03-21/22. Store: 2026-03-28 "JSON has too much friction ... partially implemented this in python sqlite3"; 2026-03-30 every entry an intelligence item carrying provenance | `planning-brief.json` #50; `<dp>/sessions/aitools/2026-03-21_ab5da7ea.jsonl` L1797; `2026-03-28_fbf7decb.jsonl` L707; `2026-03-30_ddfe01cb.jsonl` L1129 | Partly built: a stub JSON file, a mission template, SQLite tables; no single schema |
| Briefing | Planning brief top-level nodes (2026-03-16); SITREP and FINDING (SALUTE) messages (2026-03-16); brief to the commander (2026-03-26); handoff "less is more" (2026-03-23); `/delegate` element 10 "Mission Brief" (2026-11-15) | `2026-03-16_b8a9ed4e.jsonl` L1897, L1505; `2026-03-26_8236ca9c.jsonl` L115; `<dp>/sessions/nobul-ops/2026-03-23_28bbf7f7.jsonl` L1750; commit `1b34fa2` | Planning brief exists (one file). The others are not built |

## 1. AAR (after-action review)

### Latest version (commander, 2026-03-16; used for delegates 2026-03-21)

An AAR is a JSON document with three top-level nodes. The names come from the CALL taxonomy (Center for Army Lessons Learned: observation, insight, lesson).

| Node | Meaning | Fields as used (2026-03-21 delegate AARs) | Source |
|---|---|---|---|
| `meta` | Who, which mission, when | `mission`, `agent`, `session`, `produced` | `harvesting/2026-03-22_6_m1-running-estimate-lifecycle-aar.json` |
| `observations[]` | "what happened — facts" | `id` (`O-1`), `fact`, `source` (file:line) | decision #36 component (3); harvested AARs |
| `insights[]` | "why — analysis" | `id` (`I-1`), `observation_refs[]`, `analysis` | same |
| `proposals[]` | "what to change — with barrier analysis field validating each proposal" | `id` (`P-1`), `insight_refs[]`, `what`, `why`, `barrier_analysis`; decision #44 adds `severity` and affected decisions | decision #36 (3), #44 (3) |

Decision #44 component (3), verbatim: "Each proposal includes: what to change, why, barrier analysis (would this have prevented the issue?), severity, affected decisions".

Decision #36 component (13) (agent-written, status "agreed"): each validated proposal becomes a harness change, a fact in the next brief, an incident (through S2 and S1), or is dismissed.

### Timeline

| When (UTC) | Who | What | Source |
|---|---|---|---|
| 2026-03-15 | agent | First AAR: prose Markdown, nine sections (executive summary, timeline, key decisions, framework adoption, plan evolution, military doctrine parallels, what went right, what could improve, lessons for future plans). The prompt that ordered it was not found in the archive | `harvesting/2026-03-16_aar-tool-ops-plan.md` |
| 2026-03-16 18:48:52Z | agent | Proposes three nodes: "1. **Observations** — what happened (facts) 2. **Insights** — why it happened (analysis) 3. **Decisions** — what to change (proposed actions)" (line breaks removed) | `<dp>/sessions/aitools/2026-03-16_79b05dd0.jsonl` L414 |
| 2026-03-16 18:53:09Z | **commander** (approves and amends) | "ok so the aar is a json file with 3 top level nodes, but we need to change the name of the last one from decisions to proposals.  this is also where we need to formalize "barrier analsis"" | same file, L419 |
| 2026-03-16 19:13:15Z | **commander** (approves the agent's text he quotes, then adds) | Quotes the agent: "The AAR is ALWAYS harvested". Adds: "you have a tendancy to want to use one hook for everything, remember each hook needs an intent" | same file, L507 |
| 2026-03-16 19:32:00Z | **commander** | "s2 should have produced something like an AAR no? with proposed decisions?" (led to decision #44: every S2 output uses the AAR schema) | same file, L689 |
| 2026-03-17 02:14:44Z | **commander** | On a delegate's output: "nope, the output defined with a schema, similar to an AAR.  capture this intent by auditing the briefing and my past recent conversations first" | `<dp>/sessions/aitools/2026-03-16_37ab88e4.jsonl` L449 |
| 2026-03-17 03:17:43Z | **commander** | Generalises it: "where you are an agent you delegate produces an AAR, from a briefing audit or check or investigate or post-plan or whatever (generalize)" | same file, L705 |
| 2026-03-16 (commit) | agent (status "agreed") | Planning brief decisions #36 (AAR schema, `/debrief`, `reference/aar-schema.json`), #44 (S2 output uses the AAR schema), #49 (`/debrief` as a flat-verb skill) | `plans/mission-command-briefing/planning-brief.json`, first commit `c6ab931` |
| 2026-03-21 15:16:09Z | **commander** | "at the end i need you to produce a brieefing or aar.  (what does the military call this, what it is we are using, how doeos it map to your /frameworks and our provenance?)" | `<dp>/sessions/aitools/2026-03-21_ab5da7ea.jsonl` L163 |
| 2026-03-21 15:18:11Z | agent (not adopted) | Offers the TC 25-20 five-part AAR (intent, what happened, sustain, improve, lessons learned). The commander answered the agent's other questions and left the AAR shape to be settled "when we find our briefings" (L173) | same file, L168, L173 |
| 2026-03-21 16:50:54Z | **commander** | "i want two things: a json file from the ad-hoc briefing in handof-prompt as well as an aar and/or briefing for this session as well as aars/briefings when delegating where appropriate"; "then report back in the formal way we described in this conversation." | same file, L643 |
| 2026-03-21 17:24:00Z | **commander** | "produce a formal aar, including aars and proposals."; "report back using formal aar with observations and proposal." | same file, L666 |
| 2026-03-21 17:30:12Z | agent (used under the commander's order) | Delegation prompts carry "## Output format — AAR (required)", with Observations, Insights, Proposals and "Do NOT produce prose reports." The AARs returned are in `harvesting/2026-03-22_6_m*-aar.json` | same file, L675, L678 |
| 2026-03-22 15:23:40Z | **commander** | "an OL estimate looks very similar to the AARs we have been using on mac" | `<dp>/sessions/aitools/2026-03-22_77a33baf.jsonl` L1359 |
| 2026-03-23 15:10:26Z | **commander** (lighter form, for a handoff) | "just say your session name, what we did, the rfcs we drafted, the source material i gave you (the repos and directories).  why we did what we did sources, work product generated (all the research, things we discovered, like an after action report in the military (you can see how i do that very structured way in aitools but i dont want all that formal stuff but i do want to capture its intentn" | `<dp>/sessions/nobul-ops/2026-03-23_28bbf7f7.jsonl` L1750 |
| 2026-03-30 14:51:37Z | **commander** | "telemtry, AARs, that is all part of mission analysis, and part of operational learning, and part of provenace tracing right?" | `<dp>/sessions/aitools/2026-03-30_ddfe01cb.jsonl` L947 |
| 2026-11-15 | **commander** (answer 4) | "in the AAR.  dont call them post-merge facts, they are either observations or operational learning.  use the governed vocabulary.  there should be a schema for defined intelligence types" | session 87795dc3, live transcript L8030 |

## 2. Running estimate

### Latest version

**Structure.** Decision #50 (planning brief, 2026-03-16, agent-written, status "agreed"), as extended by the commander's orders of 2026-03-21/22. The session estimate that resulted is `harvesting/2026-03-22_6_running-estimate-authoritative.json`.

| Section | Fields | Source |
|---|---|---|
| `meta` | `estimateId`, `maintainer`, `scope` (session, plan or delegation: "One schema, all levels"), `sessionId`, `created`, `updated`, `version`, `versionHistory[]` | #50 (2), (9); authoritative estimate |
| `schwerpunkt`, `acceptingSessionSchwerpunkt` | main effort now, and for the next session | authoritative estimate |
| `situation` | `currentState` (required), `completedWork[]`, `deviations[]`, `facts[]`, `assumptions[]` (status, evidence, verifiedBy), `decisions[]` (decidedBy, status) | #50 (9), (10) |
| `observations[]`, `hardRequirements[]`, `planScaleItems[]` | added by the commander's 2026-03-21/22 orders (below) | authoritative estimate |
| `findings[]`, `openThreads[]` | consolidated from the channel; threads READY, BLOCKED or DEFERRED | #50 (9) |
| `conclusions` | `assessment` (required), `recommendations[]`, `risksAndOpportunities[]`: "conclusions first per doctrine" | #50 (9), (10) |
| `delegationLog[]` | execution trace for the AAR | #50 (9), (11) |

Decision #50 component (11): the estimate feeds the AAR. `completedWork` feeds observations, `deviations` are the basis for insights, and `conclusions.recommendations` seed proposals.

**Store and format.** The commander's later statements change the store, not the content:

- 2026-03-25: JSON is too cumbersome; use SQLite.
- 2026-03-26: the friction comes from the implementation, not SQLite. He deferred the format by order.
- 2026-03-28: the decision is recorded: "JSON has too much friction".
- 2026-03-29: SQLite during agentic turns, with "SOME stuff" in context.
- 2026-03-30: every entry is an intelligence item that carries its own provenance.

All quotes and sources are in the timeline below.

**Content the commander named for an estimate** (2026-03-26, `<dp>/sessions/aitools/2026-03-26_8236ca9c.jsonl`):
- L115: "print succintly your running estimate, operational learning, orders, assumptions, role, duty, identity and what yu know about yoru superior."
- L755: "produce your assessment and running estimate and OL that you've gatherered from this session and assumptions identified and their status and carry everything forward to the next turn, write it to a persisitent store", then "for each assumption observation, decision, knew knowlege, incident, operational learning gathered, produce a set of proposals of how to deal with them in this session", "peforming barrier analysis and using provenance tracing".

The estimate written under that order is `harvesting/2026-03-27_session-8236ca9c-b_running-estimate-v1.md`. Its sections: a header (session, commander, status, context, mission), Operational Learning, Decisions, Assumptions (Verified, Corrected, Invalidated, Open, Deferred, Blockers), Incidents, Provenance Mapping, Proposals (with a barrier analysis summary).

### Timeline

| When (UTC) | Who | What | Source |
|---|---|---|---|
| 2026-03-16 | agent (status "agreed") | Decision #50: running estimate adapted from ADP 5-0. "One schema, all levels". S3 maintains it, S2 contributes. It lives at `.aitools/channel/running-estimate.json` (tracked). The SessionStart hook seeds it. `reference/running-estimate-schema.json` was proposed. The conversation that agreed #50 was not found in the archive. | `planning-brief.json` #50; first commit `c6ab931` |
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
| 2026-11-15 | **commander** (answers 1 and 3) | "json or markdown not sure, for either we need schema and template/defined structure"; "one per session, as json, all delegates edit directly, json allows for this right? the multi-writer, without issue? its the main reason to do json" | session 87795dc3, live transcript L8030 |

## 3. Briefings

March produced four kinds of briefing. A fifth arrived on 2026-11-15.

### 3a. Planning brief (before a plan)

- **2026-03-16 13:04:39Z, commander** (`<dp>/sessions/aitools/2026-03-16_b8a9ed4e.jsonl` L851): "we probably need a json file with some schema that will capture capture each decision/requirement/intent".
- **17:02:06Z, commander** (L1887): "wait why are you recommending types for decisions i hate that.  decisioins re decisions, this is something else."
- **17:04:33Z, agent** (L1892): proposes `decisions`, `facts`, `assumptions`, from the MDMP mission-analysis outputs.
- **17:07:45Z, commander** (L1897): "bam, you nailed the briefing top level nodes".
- **Result**: `plans/mission-command-briefing/planning-brief.json`, schema 6.0. Top-level `meta`, `facts`, `assumptions`, `decisions`. Each decision has `id`, `decision`, `rationale`, `context`, `components`, `frameworks`, `artifacts` (each with an intent), `kpis`, `status`, `related`.
- Decisions #45 and #49 proposed a `/brief` skill to gate it; it was never built.

### 3b. SITREP and FINDING messages (during a mission)

- **2026-03-16 15:35:28Z, commander** (`b8a9ed4e` L1505): "we need to define the SALUTE schema."
- **15:36:40Z, agent** (L1507): maps SALUTE to `severity`, `finding`, `location`, `agent`, `timestamp`, `context`.
- **15:44:51Z, commander** (L1519): "also i noticed you didnt list SALUTE in subagent whats." No field-level approval was found. The fields landed in decision #23, status "agreed":
  - SITREP: `{type, agent, timestamp, batch, status, filesWritten, filesModified, summary}`
  - FINDING (SALUTE): `{type, severity, finding, location:{file,line}, agent, timestamp, context, actionTaken, recommendation}`; "FINDING severity=critical is the SPOTREP"
- Decision #24 (status "agreed"): agents are sensors, not filers. Findings go from the channel to S2 consolidation, then to S1 incident filing.
- The `/channel` skill and `reference/channel-schemas.json` were never built.

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
- **2026-11-15, commander** (answer 6): "The planning brief should define the mission objectives for the delegate." The planning brief and this Mission Brief element are the same thing: the brief that sets a delegate's mission objectives.

## What exists today, and the gaps

| Artifact | What it has | Gap |
|---|---|---|
| `/delegate` "Final response shape" | Free-text list: 5-line summary, PR URLs, files, verification, not run, `WRITE_BLOCKED`, `CONFLICT:`, `INCIDENT:`, open questions | Not an AAR: no observations/insights/proposals, no barrier analysis, and nowhere to record the observations or operational learning a delegate gains after its merge (issue #177 Q2) |
| `/delegate` element 10 "Mission Brief" (`1b34fa2`) | Requires a structured briefing that cites directives verbatim | No fields defined |
| `.aitools/channel/running-estimate.json` (tracked) | A stub from session d5b52bf2 (2026-03-26/27): 12 top-level keys (`meta`, `openThreads`, `delegationLog`, `findings`, `sitreps`, `decisions`, `assumptions`, `observations`, `completedWork`, `hardRequirements`, `deviations`, `versionHistory`), all empty; last changed `b504c43` (2026-03-28) | Differs from decision #50 (no `situation`, no `conclusions`). Not maintained. No per-session estimate (2026-03-21 decision) |
| `.aitools/templates/mission-running-estimate.json` | The #50 shape plus `m12AssumptionVerification`; `/mission-control` tells missions to copy it | JSON, which the commander ruled too high-friction (2026-03-28). Behavioural only |
| `reference/harness-db-schema.sql`, `scripts/harness-db.py` | SQLite tables `decisions`, `observations`, `messages`, `delegation_log`, `deviations`, `hard_requirements`, `completed_work`, `knowledge_items`, `provenance_edges` | No `intelligence_items` table. A 2026-03-30 mission reported adding one (`ddfe01cb` L2342); the current main has none, and why is unknown. No AAR or briefing tables. Writers were partial: a 2026-03-25 delegate reported that only the `messages` table was being written (`c0dc2ddc` L2002) |
| `/handoff` skill | Markdown handoff, sections A-J; situation assessment (Forces, Terrain, Time, Logistics, Assumptions) | Not structured data. Does not carry the running estimate or AARs by name |
| `/mission-control` skill | Running-estimate maintenance through the template | Same as the template |
| `reference/prompt-turn-checklist.md` "How to respond" | A turn record: 12 items, OL, open RFIs | A per-turn record. Not an AAR or running estimate, though items 3-5 and 12 overlap |
| `reference/framework-mission-command.md` | Backbrief and confirmation brief mapped to checklist item 2 | No running estimate (ADP 5-0), AAR, SITREP or OPORD mapping |
| Planning brief proposals | `reference/aar-schema.json`, `reference/running-estimate-schema.json`, `reference/channel-schemas.json`, `/debrief`, `/brief`, `/channel`, `aar-reminder.sh`, `channel-archive.sh`, `reference/framework-operational-learning.md` | None exist |
| Glossary (`.claude/rules/glossary.md` word list) | "situation assessment", "mission order", "handoff", "observation" | No "running estimate", "after action review", "briefing", "SITREP" |

## Proposed implementation (options)

### Where each schema lives

| Option | What | For | Against |
|---|---|---|---|
| A | One reference file, `reference/structured-reports.md`: field tables for the AAR, running estimate and briefings. `/delegate`, `/handoff` and `/mission-control` point to it | Smallest change; readable in context | No machine check beyond headings |
| B | JSON Schemas under `registries/` behind a governing skill (three-layer pattern), with a JSON template per structure | Machine-checkable. Matches answer 3 (the running estimate is JSON) | The commander called JSON too high-friction in March (2026-03-28); his 2026-11-15 answers reopen it |
| C | SQLite tables in the harness DB (`reference/harness-db-schema.sql`, `scripts/harness-db.py`), each entry an intelligence item with provenance; Markdown renders for context | Matches the March decisions (2026-03-28, -29, -30); handles several writers | The biggest build; March writers were partial; not what answers 1 and 3 name |

**Storage is open** (answer 1: "json or markdown not sure, for either we need schema and template/defined structure"). Whichever format wins, each structure (AAR, Mission Brief, running estimate, intelligence item) gets:
- a schema: fields, types, required fields, allowed values;
- a template: an empty instance a writer copies.

The running estimate is JSON, one per session (answer 3). Its multi-writer setup is open: see RFI fa81-41 below.

### Who produces each, and when

- **AAR**
  - Every delegate at hand-back: the `/delegate` "Final response shape" becomes an AAR.
    - `Intent as understood`: one line, the backbrief (open: RFI fa81-40).
    - Observations, Insights, Proposals (each proposal with barrier analysis). Each entry is an intelligence item (section "Intelligence types" below).
    - What the delegate learns after its merge is recorded the same way, as observations or operational learning (answer 4). There is no separate section for it.
    - The existing mandatory lines stay: PR URLs, `WRITE_BLOCKED`, `CONFLICT:`, `INCIDENT:`, open questions with suggested answers.
  - The session commander at session end, into the relay entry.
  - A mission commander at mission end, into its mission report.
- **Briefing**
  - The delegating agent writes the Mission Brief (element 10) into every delegation prompt. Per answer 6, it is the planning brief that defines the delegate's mission objectives. Suggested fields:
    - Mission objectives.
    - Commander's intent, with directives verbatim and their sources.
    - Mission, scope and exclusions.
    - Situation: facts, assumptions with status, decisions.
    - Coordination: the parallel missions.
    - The return format: the AAR above.
  - The session commander prints a brief to the commander on request, with the 2026-03-26 headings.
  - `/handoff` writes the handoff briefing.
- **Running estimate**
  - One per session, as JSON (answer 3; the 2026-03-21 per-session decision). The session commander and every delegate write to it directly (answer 3); how several writers share it is RFI fa81-41.
  - Updated at each prompt turn (2026-03-21 L1341) and after each delegate returns: the AAR feeds it, per decision #50 (11).
  - Carried forward at session end.

### Who consumes them

- The session commander and orchestrators: AARs, to verify and decide.
- The commander: the brief and the estimate in context, kept short ("i want to see SOME stuff here").
- The relay and the next session (`/aitool-continue`): the estimate, open proposals, OL.
- Mission control: the store.

### How it is checked (observe first, per `.claude/rules/hook-rollout.md`)

- `delegation-duty-guard.sh` / `workflow-delegation-guard.sh`: score element 10 (Mission Brief headings present) in observe mode.
- A new PostToolUse hook on `Agent`, or a `SubagentStop` hook: log whether the returned text has the AAR headings (Observations, Insights, Proposals). Observe mode.
- A check step: the running estimate (file or DB export) has the required fields (`meta`, `situation.currentState`, `conclusions.assessment`).

### Files to change

- `shared/skills/delegate/SKILL.md`: "Final response shape" becomes the AAR; element 10 gets fields; the prompt skeleton gets both.
- `shared/rules/delegation.md`: a decision row for the AAR hand-back and the Mission Brief.
- A new `reference/structured-reports.md`, or the chosen home.
- `reference/framework-mission-command.md`: map the running estimate (ADP 5-0), AAR (CALL; FM 7-0), SITREP, OPORD and FRAGORD. Or a new `reference/framework-operational-learning.md`, which decision #36 proposed.
- `shared/skills/handoff/SKILL.md`, `shared/skills/mission-control/SKILL.md`, `shared/skills/aitool-continue/SKILL.md`: read and write the same structures.
- `.aitools/templates/mission-running-estimate.json` and `.aitools/channel/running-estimate.json`: align with the chosen schema, or retire them.
- `reference/harness-db-schema.sql`, `scripts/harness-db.py`: only with option C, or to align the DB with the intelligence types below.
- `shared/hooks/` (a new hook, `hooks-manifest.json`), `tests/hooks/`, `.claude/rules/hook-rollout.md` (the state table).
- Governed terms through `/glossary`: running estimate, after action review, briefing, SITREP, and the proposed terms in "Intelligence types" below. The framework entry through `/frameworks`.
- `reference/prompt-turn-checklist.md` "How to respond": cross-reference the brief to the commander.

**Deferred** (answer 5: "not now, dont do anything on this yet"): no `/debrief`, `/brief` or `/channel` skill is built.

## Questions answered by the commander (2026-11-15)

The six questions filed with this issue, and the commander's answers, are in the comment "Commander's answers (2026-11-15)", verbatim. Summary:

| # | Question | Answer (short) |
|---|---|---|
| 1 | Store | Open: JSON or Markdown, with a schema and a template either way |
| 2 | The AAR shape for delegates | Not understood. Restated below as RFI fa81-40 |
| 3 | One estimate or per-session | One per session, as JSON, every delegate edits it directly. Multi-writer setup: RFI fa81-41 |
| 4 | What a delegate learns after its merge | In the AAR, as observations or operational learning. Use governed vocabulary. Add a schema for the defined intelligence types (section below) |
| 5 | `/debrief`, `/brief`, `/channel` | Not now. Nothing is built |
| 6 | The planning brief | It defines the delegate's mission objectives |

## Intelligence types: what exists today and suggested changes

Answer 4: "there should be a schema for defined intelligence types, have it included in the gh issue feature request (what is implemented) as well as any suggested changes."

Governed terms are read from `registries/glossary.json` through the `/glossary` skill; the word list is `.claude/rules/glossary.md`. A term marked *(proposed term)* is not governed yet.

### What exists today

**1. Governed terms** (`registries/glossary.json`, read through `/glossary` on 2026-11-15)

| Term | Governed? | What the glossary says |
|---|---|---|
| intelligence | yes | "Everything the harness learns through operation. Four domains: session, tool, spec, harness. One schema across all domains. The harness IS intelligence. OL is the user-facing term." (source: session ddfe01cb, 2026-03-30; RFC 0005 v3) |
| observation | yes, but narrowly | "An incident schema field stating concrete facts about what was observed. Quote specific text, cite files and line numbers, name behaviors. No interpretation — facts only." It is defined only as an incident field, not as an intelligence type |
| assumption | yes | Lifecycle "unverified (default when surfaced), verified (confirmed against evidence, becomes a fact), falsified (contradicted by evidence, becomes a finding). Tracked in running estimates (session-level) and planning briefs (plan-level)." |
| incident | yes | "A tracked deficiency in the harness ... Filed in incidents.json with structured fields." `gap` is deprecated, replaced by incident |
| provenance | yes | "Tracks what everything is based on, when, by whom, and whether the basis has been superseded. Eternal — never deleted, only added to." |
| session RFI | yes | Numbered `<sid4>-<n>`; title, the question with its context, a suggested action |
| key decision | yes | Only the CLAUDE.md "Key Decisions" sense |
| operational learning (OL) | yes, since `4980640` (2026-11-15) | "A lesson about how the work is done: what worked, what failed, and what to do differently next time. It is stated with its source and carried forward so that later sessions and delegates start with it. Distinct from an observation, which states facts only: operational learning is the lesson drawn from observations. It is the user-facing form of intelligence." Numbered entries use `OL-<n>`. Before that commit it had no `glossary.json` entry and no word-list line (checked through `/glossary`) |
| fact, finding, decision, insight, proposal, running estimate, after action review, briefing, SITREP | **no** | Not in `glossary.json` or the word list. `fact`, `finding` and `running estimate` appear inside the `assumption` and `accepting session` definitions |

**2. Session DB and harness DB** (`reference/harness-db-schema.sql`; `scripts/harness-db.py`, `SCHEMA_VERSION = 3`)

| Table (DB) | Holds | Fields |
|---|---|---|
| `observations` (session) | observation, assumption, fact, finding | `category` (one of the four), `text`, `status` (verified, falsified, pending), `evidence`, `severity`, `created_at`. No attribution column: the session is the DB file |
| `decisions` (session) | decisions | `decision_id`, `title`, `description`, `status` (decided, implemented, verified, deferred, reversed), `implementation_evidence`, `decided_at`, `implemented_at` |
| `deviations` (session) | process deviations | `description`, `impact`, `batch_origin`, `created_at` |
| `messages` (session) | SITREP and FINDING | `message_type` (sitrep, finding), `agent_role`, `title`, `message`, `severity`, `actionable`, `created_at` |
| `missions`, `delegation_log` (session) | delegate launches | mission id and parent, type, status, `agent_name`, `prompt_summary`, `outcome` |
| `hard_requirements`, `completed_work`, `events`, `version_history` (session) | running-estimate parts, telemetry | as named |
| `commander_directives`, `commander_feedback` (session) | the command channel | created by `scripts/harness-db.py` only; not in `reference/harness-db-schema.sql` (the two files have drifted) |
| `knowledge_items` (harness) | promoted intelligence | `item_type` (observation, assumption, fact, finding, decision, ol_entry, rule_change, framework_change, commander_directive), `version`, `content`, `t_valid`, `t_invalid`, `attributed_to`, `produced_by_session`, `produced_by_mission`, `authority_level` (0 system, 1 agent, 2 commander-reviewed, 3 commander directive), `warn_after_days`, `error_after_days`, `last_verified_at`, `trust_level`, `created_at`, `updated_at` |
| `provenance_edges` (harness) | the provenance graph | `source_item_id`, `target_item_id`, `relationship` (derived_from, informed, triggered, validated, invalidated, superseded), `session_id`, `created_at` |
| `nogood_sets` (harness) | known contradictions | `item_ids`, `contradiction`, `discovered_in_session`, `discovered_at` |

`scripts/harness-db.py` has CLI verbs for these: `observation`, `decision`, `ol`, `incident`, `knowledge`, `edge`, `nogood`, `log` ("Log a SITREP or FINDING"), `directive`.

**3. Event types in `events.jsonl`** (`<session scratch dir>/events.jsonl`, one JSON object per line: `{"t", "type", "src", "d"}`; turned into KPI metrics at SessionEnd by `shared/hooks/harness-db-sessionend.sh`)

| `type` | Written by (`shared/hooks/`) |
|---|---|
| `hook_block` | `standing-order-guard.sh`, `block-explore-agent.sh`, `block-claude-code-guide.sh` |
| `hook_warn` | `standing-order-guard.sh` (observe mode), `glossary-skill-guard.sh` |
| `hook_fire` | `standing-order-guard.sh`, `sh-file-fixup.sh` |
| `delegation` | `delegation-duty-guard.sh`, `workflow-delegation-guard.sh` |
| `command_channel` | `command-channel-stop.sh` |
| `intelligence_stop` | `intelligence-stop.py` |

These are telemetry events, not intelligence items. The DB `events` table lists `hook_fire`, `hook_block`, `hook_warn`, `delegation`, `session_event`.

**4. Channel message types: SITREP and FINDING.** `.aitools/channel/CLAUDE.md` does not define them; that file never mentions either word. They are defined in:
- planning-brief decision #23 (the field lists in section 3b above);
- the session DB `messages` table (`sitrep`, `finding`);
- `harness-db.py log`.

**5. The incident record** (`registries/incidents.json`, through the `/incident` skill)
- An open record has `id`, `title`, `status` (open, planned, closed), `severity` (critical, high, medium, low), `affected`, `linked`, `referenceFile`, `observation`, `expected`, `impact`, `discoveryContext`, `discipline`, `frameworks`, `suggestedResolution`, `rootCause`, `correctiveAction`, `preventionLayer`, `created`, `updated`.
- A closed record keeps `id`, `title`, `correctiveAction`, `closedIn`, `closedDate` (plus `rootCause` and `preventionLayer` when set).

**6. The 2026-03-30 order and the missing table**
- The commander's order: "so the intelligence schema per item, includes provenance, and provenance is its own schema and a graph itself" (`<dp>/sessions/aitools/2026-03-30_ddfe01cb.jsonl` L1129).
- A mission that day reported adding an `intelligence_items` table: "22 columns, 15 item_types, 4 intelligence domains" (same file, L2342).
- Neither `reference/harness-db-schema.sql` nor `scripts/harness-db.py` on `main` contains `intelligence_items`. Where it went is unknown.

**Gaps**
- One intelligence type has up to five shapes: session `observations`, harness `knowledge_items`, running-estimate JSON, AAR JSON, and `incidents.json` (for an observation, the incident `observation` field).
- Provenance (attribution, trust, edges) exists only on `knowledge_items`. Session rows and AAR entries carry none.
- `observation` is governed only as an incident field.
- `operational learning` was the user-facing term for intelligence without a governed definition until `4980640` (2026-11-15). The DB still calls it `ol_entry`.
- The DB schema file and the CLI have drifted (`commander_directives`, `commander_feedback`).

### Suggested schema for the defined intelligence types

One intelligence item shape for every type, following the `intelligence` definition ("One schema across all domains") and the 2026-03-30 order (provenance on every item). The `knowledge_items` fields are the starting point.

**Types**

| Type | Status | What it is | Lifecycle |
|---|---|---|---|
| observation | governed (widen the definition) | A fact seen at a source, no interpretation | recorded, superseded |
| assumption | governed | An unverified belief the work rests on | unverified, verified (becomes a fact), falsified |
| fact | *(proposed term)* | A verified statement | current, invalidated |
| decision | *(proposed term)* | A choice by the commander, or by an agent within its authority | decided, implemented, verified, deferred, reversed (the existing `decisions.status`) |
| operational learning | governed (`4980640`) | The lesson drawn from observations: what worked, what failed, what to do differently; stated with its source, carried forward | identified, applied, verified |
| insight | *(proposed term)* | Analysis that explains why, citing observations | current, superseded |
| proposal | *(proposed term)* | A change to make, with barrier analysis | proposed, accepted, rejected, deferred (the commander's disposition) |
| incident | governed | A reference to an `incidents.json` record (not copied) | the registry's own (open, planned, closed) |
| session RFI | governed | A question to the commander | open, answered, withdrawn |

Suggested change: drop `finding` as a separate type. A FINDING (SALUTE) is an observation with a severity, and a falsified assumption is recorded as an observation with an `invalidated` edge to the assumption. *(proposed)*

**Common fields (every type)**

| Field | Meaning | Exists today in |
|---|---|---|
| `id` | Stable; type prefix plus number (`OBS-3`, `OL-2`). Incidents keep their registry id; session RFIs keep `<sid4>-<n>` | `knowledge_items.item_id` |
| `type` | One of the types above | `item_type` |
| `version` | Monotonic, never reused | `version` |
| `content` | The statement | `content` |
| `status` | Per the type's lifecycle | `observations.status`, `decisions.status` |
| `severity` | critical, high, medium, low (the incident scale), optional | `observations.severity` |
| `t_valid`, `t_invalid` | When it became true; when it was superseded | `knowledge_items` |
| `last_verified_at` | Last check against its source | `knowledge_items` |

**Provenance fields (every type)**

| Field | Meaning | Exists today in |
|---|---|---|
| `attributed_to` | Who: `commander`, a delegate's name (`fa81-03-aar-schema`), the session commander, or a hook | `knowledge_items.attributed_to` |
| `authority_level` | 3 commander directive, 2 agent and commander-reviewed, 1 agent, 0 system | `knowledge_items.authority_level` |
| `produced_by_session` | Session id | `knowledge_items` |
| `produced_by_mission` | The delegate's mission name, and its parent chain | `knowledge_items` (mission only) |
| `created_at`, `updated_at` | UTC, Z suffix | `knowledge_items` |
| `source` | Where it comes from: `kind` (transcript, file, command output, commit, issue, PR) and `location` (path and line, SHA, URL) | not stored today |
| `quote` | The source text verbatim, when the source is the commander's words | not stored today |
| `edges[]` | `{relationship, target_id}` with the existing six relationships: derived_from, informed, triggered, validated, invalidated, superseded | `provenance_edges` |

**Fields by type**

| Type | Extra fields |
|---|---|
| observation | `evidence` (quoted source text) |
| assumption | `evidence`, `impact_if_falsified`, `verified_by` |
| fact | `evidence`, `verified_by` |
| decision | `decided_by`, `rationale`, `implementation_evidence` |
| operational learning | `principle`, `evidence[]`, `counter_evidence[]`, `carry_forward` (from the consolidated-OL format an agent described on 2026-03-30, `ddfe01cb` L1012) |
| insight | `observation_refs[]`, `analysis` |
| proposal | `insight_refs[]`, `what`, `why`, `barrier_analysis`, `affected` (files, decisions), `disposition` |
| incident | `incident_id` |
| session RFI | `title`, `question`, `suggested_action`, `answer` (verbatim, once answered) |

**How it maps to the AAR's three nodes (2026-03-16)**

| AAR node | Holds items of type |
|---|---|
| `observations` | observation, fact, assumption (with its status), incident (as a reference) |
| `insights` | insight, operational learning |
| `proposals` | proposal, decision (one the delegate made within its authority), session RFI |

What a delegate learns after its merge goes in `observations` or `insights` (operational learning), per answer 4. The running estimate is the session's set of these items, plus its `situation` and `conclusions` parts. A Mission Brief's situation part carries the items the delegate needs: facts, assumptions, decisions.

## Open questions after the commander's answers (2026-11-15)

Both stay open until the commander decides.

**RFI fa81-40: Should a delegate's AAR open with "Intent as understood"?**

This is question 2, restated. The commander's 03-16 AAR has three parts: observations, insights, proposals. The question is whether a delegate's AAR adds one part at the top: the mission restated as the delegate understood it, so that a misreading shows before the rest is read.

Suggest: yes, one line at the top, before the three parts. A misread mission shows first.

**RFI fa81-41: Which multi-writer setup should the per-session running estimate use, given it is JSON?**

A plain JSON file does not handle several writers on its own. Each writer reads the whole file, changes it and writes it back. Two delegates writing at once lose one write, and a crash mid-write corrupts the file. (The 2026-11-15 conflict between PR #172 and commit `235bc51`, both adding to `registries/incidents.json`, is the git form of the same problem: PR #172 is CONFLICTING.) The options:
- (a) one JSON file per writer (one per delegate), merged at session end;
- (b) append-only JSONL, one record per line (appends are atomic only for small records, and Windows needs checking);
- (c) one file with a lock and an atomic replace (write a temp file, then rename);
- (d) SQLite.

Suggest: (a). It stays plain JSON, needs no lock, and cannot lose a write.

**Vocabulary (for the `/glossary` change)**
- `observation` is governed only as an incident field. Suggest: widen its definition to an intelligence type (a fact seen at a source, no interpretation), with the incident field as one use of it.
- `fact`, `decision`, `insight` and `proposal` are not governed. Suggest: add them through `/glossary` together with the schema.
- `finding`: suggest retiring it as a separate type (see above) rather than governing it.

## Sources

Session archives (`<dp>` = the `aitools-nobul-jose` dotprofile repo):

| File | Session date | Used for |
|---|---|---|
| `<dp>/sessions/aitools/2026-03-16_b8a9ed4e.jsonl` | 2026-03-16 | planning brief nodes (L851, L1887, L1892, L1897); SALUTE (L1505, L1507, L1519) |
| `<dp>/sessions/aitools/2026-03-16_79b05dd0.jsonl` | 2026-03-16 | AAR three nodes (L414, L419); AAR harvested (L507); S2 AAR (L689) |
| `<dp>/sessions/aitools/2026-03-16_37ab88e4.jsonl` | 2026-03-16 (lines dated 03-17Z) | delegate output as an AAR (L449, L705) |
| `<dp>/sessions/aitools/2026-03-21_ab5da7ea.jsonl` | 2026-03-21 | briefing or AAR (L163, L168, L173, L643, L666); AAR in delegation prompts (L675, L678); per-session estimates (L672); OL continuous (L1138); estimate hook (L1341); plan-scale (L1797) |
| `<dp>/sessions/aitools/2026-03-22_77a33baf.jsonl` | 2026-03-22 | the whole schema (L861); OL estimate and AARs (L1359) |
| `<dp>/sessions/nobul-ops/2026-03-23_28bbf7f7.jsonl` | 2026-03-23 | lighter AAR-style handoff (L1750) |
| `<dp>/sessions/aitools/2026-03-24_c0dc2ddc.jsonl` | 2026-03-24 (lines dated 03-25Z) | SQLite (L1313); git as running estimate (L1901); DB writers (L2002) |
| `<dp>/sessions/aitools/2026-03-26_8236ca9c.jsonl` | 2026-03-26 | JSON wrong (L75); SQLite correction (L78); format deferred (L110); brief contents (L115, L117); estimate contents (L755) |
| `<dp>/sessions/aitools/2026-03-28_fbf7decb.jsonl` | 2026-03-28 | JSON friction decision (L707) |
| `<dp>/sessions/nobulai-tools/2026-03-29_f5fa32f9.jsonl` | 2026-03-29 | SQLite at agentic turns (L675) |
| `<dp>/sessions/aitools/2026-03-30_ddfe01cb.jsonl` | 2026-03-30 | AARs as intelligence (L947); intelligence item schema (L985, L1129, L1133); intelligence_items reported added (L2342) |
| Session 87795dc3 live transcript, L7693 | 2026-11-15 | the order |
| Session 87795dc3 live transcript, L8030 | 2026-11-15 | the commander's answers to the six questions |

Repository files: `plans/mission-command-briefing/planning-brief.json` (decisions #23, #24, #36, #44, #49, #50; first commit `c6ab931`, 2026-03-16), `harvesting/2026-03-16_aar-tool-ops-plan.md`, `harvesting/2026-03-22_6_m1-running-estimate-lifecycle-aar.json`, `harvesting/2026-03-22_6_running-estimate-authoritative.json`, `harvesting/2026-03-22_6_handoff-briefing.json`, `harvesting/2026-03-27_session-8236ca9c-b_running-estimate-v1.md`, `.aitools/channel/running-estimate.json`, `.aitools/templates/mission-running-estimate.json`, `reference/harness-db-schema.sql`, `shared/skills/delegate/SKILL.md` (`1b34fa2`), `shared/skills/handoff/SKILL.md`, `shared/skills/mission-control/SKILL.md`, `reference/prompt-turn-checklist.md`, `reference/framework-mission-command.md`, issue #177; for the intelligence types: `registries/glossary.json` and `.claude/rules/glossary.md` (through `/glossary`), `registries/incidents.json` (record shape, through `/incident`), `scripts/harness-db.py`, `shared/hooks/*.sh` and `intelligence-stop.py` (event types), `shared/hooks/hooks-manifest.json`, `.aitools/channel/CLAUDE.md`, PR #172 and commit `235bc51`.

Not found:
- The prompt that ordered the first AAR (2026-03-15). No "AAR" hit in the 2026-03-15 archives `84280c8b`, `eaacf9da`, `c8862b68`.
- The conversation that agreed decision #50. The `79b05dd0` archive ends at 20:23:56Z on 2026-03-16 and never mentions a running estimate.
- The 2026-03-18 to 03-20 sessions, including the 40-agent session Z1IhGrcgGO. Not in the archive: on 2026-03-21 the session recorded that the March 18-20 sessions "were never archived" (`ab5da7ea` L456).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

