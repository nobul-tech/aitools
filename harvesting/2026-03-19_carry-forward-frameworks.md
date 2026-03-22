# Carry-Forward: Framework Provenance Investigation

**Author**: S2 (Intelligence), session Z1IhGrcgGO
**Date**: 2026-03-18
**Method**: Framework registry analysis, discipline source research, cross-artifact citation tracing

---

## 1. Frameworks That Relate to Carry-Forward

Six frameworks in the harness directly inform the carry-forward principle. Each addresses a different facet of state persistence across boundaries (session, machine, delegation, plan).

### 1.1 Framework Adoption (Organizational Learning)

**Citation**: `reference/framework-adoption.md`, DTCC step 9 ("Continue")

The DTCC step 9 says: "Resume the work that was interrupted by the discovery. Before continuing, assess whether the discovery changed the plan." This is carry-forward within a session: after the framework evolves, the agent must carry the evolved state forward into remaining work. The double-loop learning concept (Argyris) explicitly requires this: "not just fixing the problem, but recognizing that the framework evolved and downstream work may need adjustment."

**Relevance**: Carry-forward within a single context (session, plan execution) where the governing framework itself has changed.

### 1.2 Artifact Harvesting (Reuse Engineering)

**Citation**: `reference/framework-artifact-harvesting.md`, `.claude/rules/artifact-harvesting.md`

The harvesting lifecycle IS a carry-forward mechanism: artifacts produced in session N are harvested at SessionEnd, evaluated at SessionStart of session N+1, and either promoted or pruned. The two-directory pattern (`.scratch/` ephemeral, `harvesting/` tracked) is the structural separation of session-scoped vs carry-forward state.

Source discipline concepts:
- **DA harvesting pipeline** (identify -> obtain -> generalize -> validate -> publish): state transitions across time boundaries
- **Staging pipeline** (Linux kernel): explicit expectation of promotion or removal -- no permanent parking lot
- **Tactical-to-strategic** (Ousterhout): the carry-forward itself is the bridge from one-off to reusable

**Relevance**: Carry-forward of artifacts (code, patterns, research) across sessions.

### 1.3 Managed File Deployment (Configuration Management)

**Citation**: `reference/framework-managed-file-deployment.md`

Configuration management's core problem is state persistence across machines. Drift detection, reconciliation, and the adoption flow (user modifications flow back to source) are all carry-forward mechanisms -- ensuring that configuration state produced on machine A is available on machine B. The three-outcome tracking (created/updated/unchanged) ensures the carry-forward is auditable.

**Relevance**: Carry-forward of configuration state across machines.

### 1.4 Source-of-Truth Protection (Change Management)

**Citation**: `reference/framework-source-of-truth.md`

The approval gate protects files "that propagate across machines and affect real workflows." The propagation IS carry-forward: a change to a source-of-truth file carries forward to every machine that receives it via deployment. The review gate exists because carry-forward amplifies errors -- a bad change on one machine becomes a bad change on all machines.

**Relevance**: Carry-forward governance -- ensuring what carries forward is correct.

### 1.5 Incident Governance (Quality Management)

**Citation**: `reference/framework-incident-governance.md`, `.claude/rules/incident-governance.md`

The incident lifecycle (open -> planned -> closed) is carry-forward of deficiency knowledge across sessions. The surfacing duty ("every session must actively look for incidents") ensures that knowledge discovered in session N is not lost. The `discoveryContext` field in the incident schema is explicitly a carry-forward artifact: it captures context that would otherwise be lost when the discovering session ends.

The staleness rule (90 days without a linked plan = stale) is a carry-forward health check: if an incident has been carrying forward for 90 days without action, the carry-forward is failing its purpose.

**Relevance**: Carry-forward of deficiency knowledge and investigation context.

### 1.6 Incident Investigation (Safety Engineering)

**Citation**: `reference/framework-incident-investigation.md`

James Reason's Swiss cheese model does not directly address state persistence, but its barrier analysis concept is foundational to HOW carry-forward is enforced. The estimate enforcement investigation (`harvesting/2026-03-16_investigate-estimate-enforcement.md`) used barrier analysis to evaluate four carry-forward enforcement options. The finding: behavioral enforcement alone (the /delegate skill) fails exactly when carry-forward is most needed -- under pressure, agents bypass it. Structural enforcement (SessionStart hook) is the barrier that cannot be bypassed.

**Relevance**: Enforcement mechanism design for carry-forward.

---

## 2. Source Discipline Concepts for Each

### 2.1 Organizational Learning: Double-Loop Learning (Argyris)

**What the discipline calls it**: "Double-loop learning" -- learning that changes the governing variables (mental models, assumptions, frameworks), not just the actions within them.

**What it says about state persistence**: Single-loop learning corrects errors within existing frameworks. Double-loop learning changes the frameworks themselves. When a framework changes, the agent must carry the evolved framework forward into remaining work. If the agent continues operating under the old framework, the learning is lost. Argyris calls this "Model I" behavior -- defensive routines that prevent new mental models from being adopted.

**Harness adaptation**: DTCC step 9 ("Continue") implements double-loop carry-forward. The agent pauses, assesses whether the plan's sequencing still holds after the framework evolved, and adjusts. Without this step, framework adoption would be single-loop -- fix the immediate problem, continue as if nothing changed.

### 2.2 Reuse Engineering: Harvesting Pipeline (Disciplined Agile)

**What the discipline calls it**: "Asset harvesting" -- the deliberate identification, extraction, generalization, and publication of reusable assets from working code.

**What it says about state persistence**: Reuse engineering distinguishes between tactical assets (solve the immediate problem) and strategic assets (solve a class of problems). The transition from tactical to strategic requires a pipeline with explicit gates. Without the pipeline, tactical assets are lost when the context that produced them ends (the session closes, the developer moves on). The pipeline IS the carry-forward mechanism.

**Harness adaptation**: SessionEnd harvesting moves artifacts from ephemeral to tracked. SessionStart evaluation assesses them for promotion. The pipeline ensures tactical work product survives across session boundaries.

### 2.3 Configuration Management: Drift Detection and Reconciliation

**What the discipline calls it**: "Configuration drift" -- when the actual state of a system diverges from its intended state over time, across deployments, or across machines.

**What it says about state persistence**: State deployed to multiple targets WILL drift. The system must detect drift (compare actual vs intended), reconcile (present options: overwrite, adopt, merge), and track outcomes (three-outcome reporting). Without drift detection, carry-forward degrades silently -- each machine diverges until they are effectively different systems.

**Harness adaptation**: `deploy_managed_file` / `Deploy-ManagedFile` implements drift detection and reconciliation. The adoption flow (user modifications flow back to source) prevents fork divergence -- a form of bidirectional carry-forward.

### 2.4 Change Management: Change Advisory Board Pattern

**What the discipline calls it**: "Change advisory" -- the practice of reviewing changes before they propagate to production systems.

**What it says about state persistence**: Changes to authoritative state propagate. The more targets that receive the change, the higher the blast radius of an error. The review gate exists because carry-forward is an amplifier -- it multiplies both correct and incorrect state. The cost of pausing to review is low; the cost of propagating a bad change is proportional to the number of targets.

**Harness adaptation**: Source-of-truth protection gates all writes to files that carry forward across machines. The gate prevents incorrect state from entering the carry-forward pipeline.

### 2.5 Quality Management: Defect Tracking and PDCA

**What the discipline calls it**: "Continuous improvement cycle" (Plan-Do-Check-Act, Deming/Shewhart). Also "defect lifecycle" (open -> in-progress -> resolved -> verified).

**What it says about state persistence**: Deficiencies must persist across organizational boundaries (shifts, teams, time periods) until resolved. A defect tracking system IS a carry-forward mechanism for quality signals. The staleness rule (aged items without action) is a carry-forward health metric -- if items carry forward indefinitely without resolution, the system is hoarding state, not acting on it.

**Harness adaptation**: Incident lifecycle, surfacing duty, staleness rule. The `discoveryContext` field is the carry-forward of investigation state -- it preserves what the filer knew so the resolver doesn't start from zero.

### 2.6 Safety Engineering: Barrier Analysis (Reason)

**What the discipline calls it**: "Defense in depth" and "barrier analysis" -- evaluating whether proposed defenses would actually prevent the incident class.

**What it says about state persistence**: Barriers come in two types: structural (physically prevent the failure) and behavioral (rely on human/agent compliance). Behavioral barriers fail under pressure. For state persistence, this means: if carry-forward depends on an agent remembering to do something, it will fail when the agent is under load. Structural carry-forward (hooks that create infrastructure unconditionally) cannot be bypassed.

**Harness adaptation**: The estimate enforcement investigation concluded: "Option 3 (/delegate skill alone) is necessary but not sufficient. It cannot be the creation or enforcement mechanism because it can be bypassed." Option 4 (SessionStart hook + skill) provides structural + behavioral layers.

---

## 3. The "Carry Awareness" Connection

### Source: Mission Command / Auftragstaktik

**Citation**: `plans/mission-command-briefing/delegation-evolution.md`, Section 10 ("Final Carry Awareness Framing")

The "carry awareness" concept emerged in session `84280c8b` (2026-03-15). The user's exact words (L1283):

> "yeah i think the answer is yes. re-write the plan one more time from scratch to implement that 'carry awareness' in the opening of the plan itself"

This produced three reinforcement points in the plan:
1. **Opening addressee** (line 3) -- "you (the executing agent reading this plan)"
2. **Protocol opening** (line 48) -- "you (the executing agent reading this plan)"
3. **Batch plan intro** (lines 436-442) -- "You are the only element that persists"

### What Auftragstaktik says

Auftragstaktik (mission-type tactics) delegates WHAT and WHY to subordinates, who devise HOW. The critical concept for carry-forward: the executing commander must "carry awareness" -- maintain situational awareness across all subordinate operations because subordinates cannot communicate with each other and do not persist between missions.

In the harness adaptation, this becomes: **S3 is the carry-forward mechanism for execution state.** Delegated agents start fresh with no memory. S3 is "the only element that persists" across batches. What S3 carries forward in each delegation briefing is the only context the delegated agent receives.

### Is "carry awareness" the same as "carry-forward"?

**No -- they are complementary concepts at different levels.**

- **Carry-forward** is the principle: state must persist across boundaries (sessions, machines, delegations).
- **Carry awareness** is the agent-level behavior: the executing agent must actively maintain and communicate accumulated state. Carry awareness is HOW an agent fulfills the carry-forward principle during plan execution.

The carry-forward design document (`harvesting/2026-03-16_carry-forward-design.md`) explicitly addresses this relationship: the "running estimate" is the artifact that S3 uses to carry awareness. The workspace rule's carry-forward principle governs the infrastructure (what is tracked vs ephemeral). Together, they form a complete stack:

| Level | Concept | Source |
|-------|---------|--------|
| Principle | Carry-forward | Workspace rule, configuration management, reuse engineering |
| Behavior | Carry awareness | Mission Command / Auftragstaktik |
| Artifact | Running estimate | Military operations (ADP 5-0) |
| Infrastructure | SessionStart hook + git tracking | Safety engineering (barrier analysis) |

---

## 4. The "Continuation" Connection

### Source: DTCC Step 9 / Framework Adoption

**Citation**: `reference/framework-adoption.md`, step 9 ("Continue")

The DTCC's ninth step is named "Continue" -- resume the work that was interrupted by the discovery. This is a specific form of carry-forward: carrying the evolved framework state forward into the interrupted work.

### What organizational learning says

Argyris's double-loop learning distinguishes:
- **Single-loop**: detect error, correct action, continue. The governing framework is unchanged.
- **Double-loop**: detect error, change the governing framework, then continue. The framework itself carries forward in its evolved form.

The DTCC's "Continue" step is the double-loop moment: "If the harness itself changed (new principle, new framework, new convention), the plan that was in progress may need to account for that."

### How continuation relates to carry-forward

Continuation is carry-forward of framework evolution within a session. The broader carry-forward principle (workspace rule) governs persistence across sessions and machines. Both serve the same purpose -- preventing knowledge loss at boundaries -- but at different scales:

| Boundary | Carry-forward mechanism | Source concept |
|----------|----------------------|----------------|
| Within a plan step | DTCC step 9 (Continue) | Double-loop learning |
| Between delegations | Running estimate + delegation duty | ADP 5-0 running estimate + Auftragstaktik |
| Between sessions | Harvesting + channel archive | DA harvesting pipeline + configuration management |
| Between machines | Git tracking + deployment | Configuration management drift detection |

---

## 5. Additional Discipline Concepts Found

### 5.1 Military Operations: Running Estimate (ADP 5-0)

**Citation**: `harvesting/2026-03-16_carry-forward-design.md`, Section 1

ADP 5-0 (The Operations Process, July 2019) defines a running estimate as "the continuous assessment of the current situation used to determine if the current operation is proceeding according to the commander's intent and if planned future operations are supportable."

Key doctrinal property for carry-forward: "At handoff, the running estimate IS the carry-forward. During relief in place or battle handover, the outgoing staff passes running estimates to the incoming staff. The estimate contains everything the incoming officer needs to continue operations without re-deriving the situation."

This is the most direct discipline analog to the harness carry-forward principle. The military does not have a separate "carry-forward" concept -- the running estimate IS the mechanism, and the relief-in-place procedure IS the protocol.

### 5.2 Military Operations: Relief in Place / Battle Handover

In military operations, when one unit replaces another, the outgoing unit passes all running estimates, operational overlays, and situational awareness to the incoming unit. The incoming unit does not re-derive the situation from scratch. This is structurally identical to the harness's SessionEnd/SessionStart carry-forward: the outgoing session archives its running estimate; the incoming session's S2 intelligence prep reads it.

### 5.3 Healthcare: SBAR Handoff

While not explicitly adopted in the harness, SBAR (Situation-Background-Assessment-Recommendation) is the healthcare discipline's carry-forward pattern for shift handovers. It shares the same structure as the running estimate: current state first, supporting context second, conclusions and recommendations third. SBAR was designed to prevent information loss at clinical shift boundaries -- the same class of problem as session boundaries.

### 5.4 SRE: Operational Runbooks and On-Call Handoff

The tool-ops framework (`reference/framework-tool-ops.md`) adopts SRE operational readiness concepts. SRE on-call handoff procedures require outgoing engineers to pass a structured summary of active incidents, ongoing investigations, and pending changes to incoming engineers. This is another carry-forward pattern: state persistence across personnel boundaries, using a structured artifact (the handoff summary).

### 5.5 Knowledge Management: Organizational Memory

The intent documentation framework (`reference/framework-intent-documentation.md`) adopts knowledge management principles. Intent statements are a form of carry-forward: they persist the author's purpose across time, ensuring future readers interpret the file correctly. Without intent, each new session re-derives (or assumes) the file's purpose -- a carry-forward failure at the document level.

---

## 6. Synthesis: What All Disciplines Together Say

Seven disciplines inform the carry-forward principle:

| Discipline | Core carry-forward concept | Key insight |
|------------|--------------------------|-------------|
| Military operations | Running estimate + relief in place | State must be a continuously maintained artifact, not a snapshot. Handoff = pass the artifact. |
| Auftragstaktik | Carry awareness | The persistent element (commander/S3) must actively maintain state because subordinates cannot. |
| Organizational learning | Double-loop continuation | When the framework itself evolves, the evolved state must carry forward into remaining work. |
| Reuse engineering | Harvesting pipeline | Tactical artifacts carry forward through explicit staging gates. No permanent parking lot. |
| Configuration management | Drift detection + reconciliation | State deployed to multiple targets WILL drift. Detect, reconcile, track. |
| Safety engineering | Barrier analysis | Behavioral carry-forward (rely on compliance) fails under pressure. Structural carry-forward (hooks, infrastructure) cannot be bypassed. |
| Knowledge management | Intent as organizational memory | Persist the WHY, not just the WHAT. Each file's purpose carries forward via intent statements. |

### Cross-discipline convergence

All seven disciplines converge on five principles:

1. **State must be an artifact, not a behavior**: Every discipline that solves carry-forward creates a structured artifact (running estimate, harvesting manifest, configuration file, incident record, intent statement). None relies on memory alone. The artifact IS the carry-forward.

2. **Carry-forward must be structural, not voluntary**: Safety engineering and barrier analysis show that behavioral mechanisms (rely on the agent to remember) fail when most needed. Configuration management and military operations both use infrastructure-level mechanisms (deployment systems, handover procedures) that cannot be skipped.

3. **State must be continuously maintained, not snapshot-produced**: Military doctrine is explicit: the running estimate is a living document updated throughout the operations process, not a snapshot taken at handoff. Organizational learning agrees: framework evolution must carry forward in real-time (DTCC step 9), not at session boundaries.

4. **Carry-forward must be bidirectional**: Configuration management's adoption flow (user modifications flow back to source) prevents fork divergence. The DTCC's continuation step carries framework evolution back into the interrupted plan. Unidirectional carry-forward (only pushing state forward) leads to drift.

5. **Carry-forward health must be measured**: Quality management tracks defect staleness. Reuse engineering tracks promotion rates. Configuration management tracks drift. The carry-forward system itself needs health metrics: Is the running estimate being maintained? Are harvested artifacts being evaluated? Is state actually carrying forward, or is it being lost at boundaries?

---

## 7. Proposed Wording for the Carry-Forward Principle

The current wording in `.claude/rules/aitools-workspace.md`:

> A user working on the same project across multiple machines (macOS, Windows) must be able to pick up where they left off. Project state that carries forward between sessions -- running estimates, consolidated findings, harvested artifacts -- MUST be tracked in git so it survives machine switches via pull.
>
> Session-ephemeral data (scratch files, in-flight channel messages) is gitignored -- it belongs to one session on one machine.
>
> This principle governs every workspace design decision: if data needs to survive a machine switch, it must be tracked.

This wording addresses machine-to-machine carry-forward but is silent on:
- Session-to-session carry-forward on the same machine
- Delegation-to-delegation carry-forward within a session
- Carry-forward of framework evolution (DTCC continuation)
- The structural vs behavioral enforcement requirement
- The continuous maintenance requirement (not snapshot)

### Proposed revision (discipline-informed)

> ### Cross-boundary state persistence principle
>
> State must persist across every boundary where knowledge would otherwise be lost: between machines, between sessions, between delegations, and between framework evolutions. The carry-forward principle governs all four.
>
> **State must be an artifact, not a behavior.** Every class of carry-forward state has a structured artifact: running estimates for execution state, harvested artifacts for reusable work product, incident records for deficiency knowledge, intent statements for document purpose. Rely on the artifact, not on memory. (ADP 5-0 running estimate; DA harvesting pipeline; ISO 9001 document control)
>
> **Carry-forward must be structural where bypass would cause loss.** Behavioral mechanisms (skills, rules) are necessary for maintenance but insufficient for creation. Structural mechanisms (hooks, git tracking, deployment scripts) ensure infrastructure exists unconditionally. The more critical the state, the more structural the mechanism. (Reason barrier analysis; SRE operational readiness)
>
> **State must be continuously maintained, not produced at boundaries.** The running estimate is updated before and after every delegation -- not created at session end. Incidents are filed when discovered -- not collected at session end. Carry-forward artifacts that are only written at boundaries are snapshots, not living state. (ADP 5-0 "continuous assessment"; Argyris double-loop learning)
>
> **Machine-to-machine persistence**: project state that must survive a machine switch is tracked in git. Session-ephemeral data (scratch files, in-flight channel messages) is gitignored. This principle governs every workspace design decision.
>
> **Session-to-session persistence**: harvested artifacts, running estimates archived to tracked paths, and incident records persist across sessions. SessionEnd hooks archive; SessionStart hooks evaluate. (DA harvesting lifecycle; configuration management drift detection)
>
> **Delegation-to-delegation persistence**: S3 maintains the running estimate as a continuously updated artifact. Each delegation briefing includes an extract. S3 is the persistent element -- delegated agents do not persist. (Auftragstaktik carry awareness; ADP 5-0 staff running estimate)
>
> **Framework evolution persistence**: when a framework changes mid-session (DTCC step 9), the executing agent carries the evolved framework forward into remaining work. Plans may need amendment. (Argyris double-loop learning)

### Notes on the proposal

- The proposed wording is significantly longer than the current wording. The user may prefer the current brevity with the discipline provenance documented in a separate reference file.
- "Cross-boundary state persistence" is the discipline-neutral term for what the harness currently calls "carry-forward." The user may prefer to keep "carry-forward" as the governed term and document the discipline connections in a `reference/framework-carry-forward.md` file.
- The proposed wording conflates the principle (what to do) with the mechanism (how to do it). The user may prefer to separate these: principle in the rule, mechanism details in the reference file.

---

## Sources Consulted

### Harness artifacts
- `reference/framework-registry.json` -- all 13 frameworks + 1 pending
- `reference/framework-adoption.md` -- DTCC, double-loop learning
- `reference/framework-artifact-harvesting.md` -- DA harvesting pipeline
- `reference/framework-managed-file-deployment.md` -- configuration management
- `reference/framework-source-of-truth.md` -- change management
- `reference/framework-incident-governance.md` -- quality management
- `reference/framework-incident-investigation.md` -- safety engineering, barrier analysis
- `reference/framework-tool-ops.md` -- SRE operational readiness
- `reference/framework-intent-documentation.md` -- knowledge management
- `.claude/rules/aitools-workspace.md` -- current carry-forward principle
- `plans/mission-command-briefing/delegation-evolution.md` -- carry awareness origin
- `plans/mission-command-briefing/handoff-prompt.md` -- operational learning framework
- `harvesting/2026-03-16_carry-forward-design.md` -- running estimate design (ADP 5-0)
- `harvesting/2026-03-16_investigate-estimate-enforcement.md` -- barrier analysis on enforcement
- `harvesting/2026-03-15_aar-tool-ops-plan.md` -- Argyris/double-loop references

### External discipline sources (referenced by harness artifacts)
- ADP 5-0, The Operations Process (July 2019) -- running estimate definition
- Argyris, C. -- double-loop learning theory
- PMI Disciplined Agile -- harvesting pipeline
- Reason, J. -- Swiss cheese model, barrier analysis
- ISO 9001 -- document control
- Google SRE -- toil automation, operational readiness
- Ousterhout, J. -- tactical-to-strategic programming
- Ranganathan, S.R. -- faceted classification (governed vocabulary)
- Dennis & Van Horn -- capability-based security
- Evans, E. -- ubiquitous language (DDD)
