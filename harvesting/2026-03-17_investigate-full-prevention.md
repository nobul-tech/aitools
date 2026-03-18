# Full Prevention Stack: Governed Document Drift

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-16
**Classification**: Barrier analysis + combined design
**Incident**: Workspace rule superseded 5 planning brief decisions; brief
never updated; implementing agent built stale architecture.

---

## 1. Incident Reconstruction

### The exact failure sequence

1. Sessions `84280c8b`, `eaacf9da`, `b8a9ed4e` produced decisions #3,
   #22, #26, #34, #50 with "all of `.aitools/channel/` is gitignored."
2. A later session wrote `.claude/rules/aitools-workspace.md` with the
   carry-forward principle: `running-estimate.json` is tracked at a
   fixed path, only `session-*/` is gitignored.
3. The rule noted "Decision #34 is superseded" (line 62) but did not
   touch the planning brief.
4. Session `uyZ7TELqpP` read the brief, implemented the stale
   architecture (running estimate inside `session-XXX/`, gitignored).
5. Three critical inconsistencies: decisions #22, #34, #50 all
   contradict the governing rule on gitignore scope and running
   estimate placement.

### Root cause chain (5 Whys)

1. **Why did the implementing agent build the wrong architecture?**
   It read the planning brief, which described the old architecture.
2. **Why was the brief stale?**
   The workspace rule was written without updating the brief.
3. **Why wasn't the brief updated when the rule was written?**
   No mechanism reminded or forced the rule author to check for
   affected brief decisions.
4. **Why is there no such mechanism?**
   The harness governs data access (skill gates) and data format
   (schema validation), but not data consistency across document
   types (rule-to-brief cross-reference integrity).
5. **Why is cross-document consistency ungoverned?**
   The three-layer governance model was designed for single-document
   correctness (each governed file has its own skill gate). The
   case where Document A supersedes parts of Document B—with A and
   B having different governance skills—was not anticipated.

### The class of problem

This is **governed document drift**: when a governing artifact (rule)
supersedes decisions in a dependent artifact (brief), and the dependent
artifact is not updated. It is distinct from:

- **Configuration drift** (code vs spec): governed by check scripts
- **Cross-reference breakage** (dead links): governed by /audit
- **Schema violation** (malformed data): governed by PreToolUse hooks

Governed document drift is a **semantic** consistency problem—two
documents that are individually well-formed but collectively
contradictory. No existing governance layer catches this.

---

## 2. Three Partial Solutions: Summary of Findings

### 2a. FRAGORD (military delta overlay)

**Score**: PARTIAL. O(1) per-change via overlay files, but requires
the /brief skill (not yet built) to apply overlays. Without the skill,
FRAGORD files are inert. Does not prevent the forgetting—just makes
the amendment cheaper to issue. Best suited for mid-execution plan
changes (its military purpose), not pre-execution brief maintenance.

**Key insight**: The FRAGORD pattern solves a distribution problem
(pushing changes to consumers), but our drift problem is a detection
problem (knowing that changes need to be pushed).

### 2b. `governedBy` schema field (CM/DRY)

**Score**: PARTIAL. Strongest long-term fix. Eliminates structural
duplication—once in place, the brief cannot drift from the rule for
governed assertions. But requires discipline to ADD the field when
writing the rule. Reduces per-change cost from O(n components) to
O(0), but does not force the initial back-patch.

**Key insight**: `governedBy` prevents drift for governed decisions
but does not detect when a new decision SHOULD be governed.

### 2c. Amendment + codification (legal)

**Score**: PARTIAL (negative ROI). Same forgetting problem with more
infrastructure. The amendment record format has audit value but the
operational overhead exceeds the benefit for a planning brief that
will be consumed once.

**Key insight**: The legal analogy reveals that prevention comes from
the legislative PROCESS (committee review, impact assessment), not
from the documentation FORMAT (amendment records, codification).

### Consensus across all three

All three agreed on two points:
1. Do the 10 amendments now (immediate alignment).
2. The real prevention is in DETECTION—knowing when a rule change
   affects the brief—not in the remediation format.

---

## 3. Combined Prevention Stack Design

### The five elements

| # | Element | Layer | Type | Exists? |
|---|---------|-------|------|---------|
| 1 | `governedBy` schema field | Prevention | Structural | No |
| 2 | Rule-write impact hook | Detection | Hook | No |
| 3 | Drift telemetry (Datadog) | Audit | External | Roadmap |
| 4 | S2 intelligence prep check | Detection | Process | Decision #26 |
| 5 | Plan-gate hook extension | Prevention | Hook | Decision #41 |

### Element 1: `governedBy` schema field

**What it does**: Decisions that defer structural assertions to a
governing rule carry `"governedBy": ".claude/rules/some-rule.md"`.
The /brief skill resolves the reference—reads the rule, presents
the current structural facts from the rule alongside the decision's
implementation details.

**Prevention mechanism**: A decision with `governedBy` cannot drift
from the rule because it does not contain the driftable text. The
structural assertion is stored once (in the rule) and referenced
(in the decision). This is database normalization applied to
governed documents.

**What it does NOT do**: Force the field to be added when a new rule
supersedes new decisions. The "forgetting to add `governedBy`"
failure mode requires Element 2.

**Implementation cost**: Schema change to planning-brief.json + /brief
skill overlay logic + selective simplification of 5 decisions' structural
components. Approximately 1 session of work.

**Marginal value**: HIGH. Eliminates the entire class of structural drift
for governed decisions. Every future workspace rule change requires zero
brief amendments.

### Element 2: Rule-write impact hook

**What it does**: A PostToolUse hook on Write/Edit that fires when the
target is `.claude/rules/*.md`. The hook:

1. Reads the modified rule file.
2. Scans the planning brief for decisions that reference the affected
   domain (workspace paths, gitignore, channel, etc.). This is a
   keyword/path match, not semantic analysis.
3. If matches found, emits a stderr reminder: "Rule change detected in
   `{rule}`. Planning brief decisions {IDs} reference this domain.
   Check for brief-rule consistency. Use /brief to review affected
   decisions."
4. Does NOT block the write (PostToolUse cannot block; this is
   feedback only).

**Why PostToolUse, not PreToolUse**: PreToolUse on Write to rules
would fire BEFORE the rule is written, so the hook cannot compare
the new rule content against the brief. PostToolUse fires after the
write, and stderr feedback is shown to Claude—the agent sees the
reminder immediately after writing the rule.

**Alternative: PreToolUse on Read of planning-brief.json**: A
complementary hook that fires when any agent reads the brief. It
checks the `governedBy` references, reads the governing rules, and
flags any decisions where the rule has changed since the brief was
last updated (using file modification timestamps or a hash stored
in brief metadata). This catches the case where Element 1 is in
place but the rule was modified after the `governedBy` was set up.

**Implementation cost**: One bash hook script (~80 lines), similar
in structure to `glossary-skill-guard.sh`. Requires the brief to
exist at a known path. Hook registration in `settings.json`.
Approximately 0.5 sessions.

**Marginal value**: HIGH. This is the only element that addresses
the "forgetting" failure mode. Without it, `governedBy` must be
manually added and there is no prompt to do so.

**Failure modes**:
- False negatives: keyword matching misses affected decisions.
  Mitigation: err on the side of over-matching. Better to flag 10
  decisions and have 7 be unaffected than to miss 3 critical ones.
- False positives: rule change in a domain that doesn't actually
  affect any decisions. Mitigation: the reminder is advisory, not
  blocking. A false positive costs the agent 30 seconds of
  checking.
- No brief exists: not all projects have planning briefs. Hook must
  check for brief existence and no-op if absent.

### Element 3: Drift telemetry (Datadog)

**What it does**: When the rule-write impact hook (Element 2) fires
and finds affected decisions, it logs a drift event to the local
telemetry SQLite:

```
event_type: "brief-rule-drift"
details: {rule, affected_decisions, timestamp}
```

SessionEnd ships aggregated metrics to Datadog. A Datadog monitor
alerts when:
- Drift events exceed a threshold (e.g., 3 unresolved in 7 days).
- A specific decision has been flagged as drifted for > 2 sessions
  without resolution.

**Implementation cost**: Depends on Datadog integration (roadmap
item). The SQLite event logging is ~20 lines added to the
rule-write hook. The Datadog monitor is configuration, not code.

**Marginal value**: LOW-MEDIUM. Provides visibility and alerting
but does not prevent or catch drift in real-time. Its value is
longitudinal—tracking whether the prevention stack is working over
time. Without Elements 1 and 2, this just measures how often drift
happens without preventing it.

**Sequencing dependency**: Requires Datadog log integration roadmap
item. The SQLite logging can be implemented immediately; the
Datadog monitor waits for the integration.

### Element 4: S2 intelligence prep check

**What it does**: Decision #26 already specifies that S2 is spawned
at plan start for intelligence preparation. Extend S2's
intelligence prep checklist to include:

1. Read all planning brief decisions with `governedBy` fields.
2. For each, read the governing rule.
3. Compare: has the rule changed since the brief was last amended?
   (Check file modification dates, or a `lastVerified` timestamp
   in brief metadata.)
4. If drift detected, flag in the intelligence brief: "STALE
   DECISIONS: #22, #34, #50 may be inconsistent with
   `.claude/rules/aitools-workspace.md`. Verify before executing."

**Implementation cost**: Addition to S2's intelligence prep prompt
(the /brief skill or a dedicated intelligence-prep mode). No new
infrastructure—this is process, not mechanism. Approximately 0.25
sessions to document.

**Marginal value**: MEDIUM. Catches drift that Elements 1 and 2
missed, but only at plan start—not when the rule is written. There
is a window between rule change and next plan execution where drift
exists undetected. For long-lived briefs (weeks between plan
executions), this window can be large.

**Key advantage**: This is the only element that catches drift in
decisions that do NOT have `governedBy` (because the field was
never added). S2 performs a semantic check, not just a mechanical
reference resolution.

### Element 5: Plan-gate hook extension

**What it does**: Decision #41 specifies a plan-gate hook that
blocks plan mode for unresolved blockers. Extend the gate to also
check for brief-rule drift:

1. When an agent enters plan mode (PreToolUse on Agent/Task with
   "plan" context), the hook reads the planning brief.
2. Checks `governedBy` references against governing rules.
3. If drift detected, blocks plan mode with stderr: "Brief-rule
   drift detected in decisions {IDs}. Resolve via /brief before
   proceeding with plan."

**Implementation cost**: Extension to the plan-gate hook (not yet
built). Approximately 0.25 sessions once the plan-gate
infrastructure exists.

**Marginal value**: MEDIUM-HIGH. This is the last line of defense
before an agent executes a plan based on stale decisions. Unlike
Element 4 (advisory), this BLOCKS execution. The implementing
agent in session `uyZ7TELqpP` would have been stopped here.

**Failure modes**:
- Plan-gate hook not yet built (decision #41 is planned, not
  implemented).
- Agent bypasses plan mode (writes plan without entering plan
  context). Mitigation: the plan-gate is a convention, not a
  hard enforcement. But it catches the normal path.
- Brief has no `governedBy` fields. The hook can only check what
  is annotated. Unannotated decisions pass through unchecked.

---

## 4. Barrier Analysis: Incident Replay with Full Stack

### Step-by-step replay

**Step 1**: Sessions produce decisions #3, #22, #26, #34, #50 with
detailed workspace architecture.

*No stack element fires. The decisions are written fresh with no
governing rule yet. This is the expected case—the stack prevents
drift, not initial authoring.*

**Step 2**: A later session writes `.claude/rules/aitools-workspace.md`.

**Element 2 fires** (rule-write impact hook): PostToolUse detects
write to `.claude/rules/aitools-workspace.md`. Scans the planning
brief. Finds decisions #3, #22, #34, #50 referencing workspace
paths, channel, gitignore. Emits:

> "Rule change: `aitools-workspace.md`. Planning brief decisions
> #3, #22, #34, #50 reference this domain. Check for brief-rule
> consistency via /brief."

The rule-writing agent now knows the brief is affected. Two outcomes:

**2a. Agent acts on the reminder**: Adds `governedBy` to affected
decisions, simplifies structural components. **Drift prevented at
source.** No downstream elements needed.

**2b. Agent ignores the reminder** (the original failure mode):
The agent writes the rule and moves on. The drift now exists.
Element 3 logs a drift event.

**Step 3** (if 2b): A new session begins. S2 intelligence prep runs.

**Element 4 fires**: S2 reads the brief. Even without `governedBy`
(since the agent in step 2b didn't add it), S2's semantic check
compares the brief's workspace assertions against the workspace
rule. Flags:

> "STALE: Decision #34 says channel is entirely gitignored.
> `.claude/rules/aitools-workspace.md` says `running-estimate.json`
> is tracked. Resolve before plan execution."

If S2's intelligence brief reaches the user or the executing agent,
the drift is caught before execution.

**Step 4** (if S2 finding is also missed): The executing agent
enters plan mode.

**Element 5 fires** (plan-gate hook): Checks `governedBy` references
(if present) or does a baseline consistency check. If drift detected:

> "BLOCKED: Brief-rule drift in decisions #22, #34, #50. Resolve
> via /brief before entering plan mode."

The agent cannot proceed until the brief is aligned.

**Step 5** (if agent reads the brief directly without plan mode):
The brief has `governedBy` fields (if Element 1 was applied during
initial setup).

**Element 1 operates**: The /brief skill resolves `governedBy`
references, presenting the current rule content. The agent sees
the correct workspace structure, not the stale decision text.

### Layer at which the incident would have been caught

| Element | Step | Catches? | Mechanism |
|---------|------|----------|-----------|
| 1. `governedBy` | 5 | YES (if applied) | Structural: cannot drift |
| 2. Rule-write hook | 2 | YES | Detection: flags affected decisions |
| 3. Drift telemetry | 2+ | Visibility only | Logs event, no prevention |
| 4. S2 intel prep | 3 | YES | Semantic: compares assertions |
| 5. Plan-gate | 4 | YES (if present) | Prevention: blocks execution |

**Earliest catch**: Element 2 (rule-write hook) at Step 2—the exact
moment the drift is created. This is the optimal intervention point.

---

## 5. Swiss Cheese Model

### Layer mapping

```
PREVENTION          DETECTION           AUDIT
─────────────       ─────────────       ─────────────
Element 1:          Element 2:          Element 3:
governedBy field    Rule-write hook     Drift telemetry
(structural)        (real-time)         (longitudinal)

Element 5:          Element 4:          /audit skill
Plan-gate hook      S2 intel prep       (periodic)
(execution gate)    (pre-execution)
```

### Hole analysis

**Hole in Element 1**: New decisions that SHOULD have `governedBy`
but don't. A rule supersedes a decision and nobody adds the field.
This hole is covered by Element 2 (the hook reminds the agent) and
Element 4 (S2 catches it semantically).

**Hole in Element 2**: The hook fires but the agent ignores the
reminder. PostToolUse feedback is advisory, not blocking. This hole
is covered by Element 4 (S2 catches it at plan start) and Element 5
(plan-gate blocks execution).

**Hole in Element 4**: S2 intelligence prep doesn't run (no plan
execution in this session; or the session is ad-hoc, not
plan-driven). This hole is covered by Element 5 (plan-gate fires
when plan mode is entered, even without S2).

**Hole in Element 5**: Agent reads the brief without entering plan
mode (writes implementation code directly based on brief decisions,
bypassing the plan-gate). This hole is covered by Element 1
(`governedBy` resolution means the agent sees correct data).

**Remaining gap (path through all layers)**:

1. New rule supersedes brief decisions.
2. Rule-write hook fires; agent ignores (hole in E2).
3. No `governedBy` added (hole in E1).
4. No S2 intelligence prep runs (hole in E4).
5. Agent reads brief directly, no plan mode (hole in E5).
6. Agent reads JSON directly, not via /brief skill (bypasses E1
   resolution).

This path requires ALL FOUR detection/prevention elements to fail
simultaneously. The probability is very low but nonzero. The
residual risk vector is **governed data bypass** (reading JSON
directly instead of through the skill). This is the same bypass
vector that threatens ALL governed data, not specific to brief-rule
drift. It is governed by `.claude/rules/governed-data-access.md`
and enforced by pre-commit step 16.

**Assessment**: The combined stack has no unique gap. The residual
gap (governed data bypass) is a general governance problem already
tracked, not specific to this prevention design.

---

## 6. Failure Modes of the Combined Stack

### Most likely failure: Element 2 false negatives

The rule-write hook uses keyword/path matching to find affected
decisions. If the rule uses different terminology than the brief
(e.g., rule says "carry-forward state" but brief says "archived
estimate"), the hook misses the connection.

**Likelihood**: Medium. Domain vocabulary is not standardized
across documents.

**Mitigation**: The /glossary skill governs vocabulary. As more
terms are governed, the matching becomes more reliable. In the
interim, the hook should match broadly (any workspace-related path
or term) and accept false positives.

### Second most likely: Hook infrastructure changes

Claude Code hook APIs evolve. A CC update could change PostToolUse
behavior, stdin format, or stderr handling. All five elements
depend on the hook infrastructure to some degree.

**Likelihood**: Medium over a 6-month horizon.

**Mitigation**: Tool-ops framework (`reference/tool-ops-claude-code.md`)
tracks CC version dependencies. Hook scripts have version-pinned
behavior. The tool-ops session audit hook detects behavior changes.

### Third most likely: `governedBy` applied too broadly

If every decision gets `governedBy`, the brief becomes a stub that
says "see the rules for everything." The brief loses its value as a
self-contained execution document.

**Likelihood**: Medium (scope creep in applying the field).

**Mitigation**: The barrier analysis (barrier-governed-by.md section
2d) already identified this. The rule is: `governedBy` applies to
STRUCTURAL assertions only (directory layout, gitignore
classification, scope boundaries). IMPLEMENTATION details (hook
behavior, seeding logic, read paths) stay in decision components.

### Adversarial scenario: Rule written in a project without a brief

The rule-write hook fires, scans for a planning brief, finds none,
no-ops. The rule supersedes information that was communicated
verbally or in a different document type (not a JSON brief).

**Assessment**: Out of scope. This prevention stack is designed for
the governed-brief pattern. Projects without structured briefs have
different (and weaker) governance. The stack degrades gracefully
(no false blocking, just no detection).

---

## 7. Cost-Benefit Analysis

### Implementation cost per element

| # | Element | New code | Dependencies | Effort |
|---|---------|----------|-------------|--------|
| 1 | `governedBy` field | Schema + /brief skill update + 5 decisions | /brief skill exists or is built | ~1 session |
| 2 | Rule-write hook | ~80-line bash script + settings.json registration | Brief at known path | ~0.5 session |
| 3 | Drift telemetry | ~20 lines added to hook + Datadog monitor config | Datadog integration (roadmap) | ~0.25 session (code) + roadmap wait |
| 4 | S2 intel prep | Process documentation + /brief skill mode | S2 spawning convention | ~0.25 session |
| 5 | Plan-gate extension | Extension to plan-gate hook | Plan-gate hook (decision #41) | ~0.25 session once plan-gate exists |

**Total**: ~2.25 sessions of implementation work, spread across
multiple roadmap dependencies.

### Marginal prevention value (cumulative)

| Stack size | Elements | Catches | Residual gap |
|-----------|----------|---------|-------------|
| 0 | None | Nothing | Full drift risk |
| 1 | E2 (hook) | Rule-write moment | Agent ignores reminder |
| 2 | E2 + E1 | Rule-write + future reads | Missing `governedBy` on new decisions |
| 3 | E2 + E1 + E5 | Above + execution gate | Brief read without plan mode |
| 4 | E2 + E1 + E5 + E4 | Above + semantic pre-check | Only governed data bypass remains |
| 5 | All | All above + longitudinal visibility | Same (E3 adds visibility, not prevention) |

### Minimal viable stack

**Two elements achieve near-full prevention**:

1. **Element 2** (rule-write impact hook): Catches drift at creation
   time. Cost: 0.5 sessions.
2. **Element 1** (`governedBy` field): Prevents drift for governed
   decisions permanently. Cost: 1 session.

Together, E1 + E2 cover the two failure modes:
- E2 reminds the agent to add `governedBy` when writing a rule.
- E1 prevents drift for decisions that have `governedBy`.

The remaining gap (decisions without `governedBy` where the agent
ignored E2's reminder) is caught by Elements 4 and 5, which are
nice-to-have defense-in-depth, not critical path.

**Element 3** (telemetry) has the lowest marginal prevention value.
It measures, it does not prevent. Build it when Datadog integration
ships, not before.

### Recommendation: Build E2 first, E1 second

**Rationale**: E2 (the hook) provides immediate value with the lowest
implementation cost. It works even without E1 (the `governedBy` field)
because it provides the REMINDER that `governedBy` should be added.
E1 without E2 requires agents to know the field exists and remember
to use it—the same forgetting problem.

E2 is the keystone. Without E2, every other element is reactive
(catching drift after the fact). With E2, drift is flagged at the
exact moment it is created.

---

## 8. Build Sequencing

### What we can do TODAY

| Action | Type | Effort | Prereqs |
|--------|------|--------|---------|
| Do the 10 amendments | Data fix | ~30 min | Audit proposals exist |
| Design `governedBy` schema | Design | ~30 min | None |
| Write rule-write impact hook (E2) | Code | ~2 hours | Brief at known path |
| Register hook in settings.json | Config | ~5 min | E2 code complete |

### What requires planned infrastructure

| Action | Dependency | Status |
|--------|-----------|--------|
| /brief skill overlay logic (E1 resolution) | /brief skill | Not yet built (decision #49) |
| Plan-gate extension (E5) | Plan-gate hook | Not yet built (decision #41) |
| Drift telemetry (E3) | Datadog integration | Roadmap (plans/datadog-log-integration.md) |
| S2 intelligence prep check (E4) | S2 spawning + /brief | Designed (decision #26) but not coded |

### Proposed build order

**Phase 0: Immediate fix** (this session or next)
- Apply the 10 amendments to the planning brief.
- Add `governedBy` field to decisions #3, #22, #26, #34, #50 (schema
  change + data change together).
- This is the "stop the bleeding" action. Every other phase prevents
  recurrence.

**Phase 1: Keystone hook** (next focused session)
- Write `rule-write-impact.sh` (PostToolUse on Write/Edit, matcher
  for `.claude/rules/`).
- Register in `settings.json` hook config.
- Test: write a trivial rule change, verify the hook fires and finds
  affected decisions.
- This gives us real-time detection of the class of drift.

**Phase 2: /brief skill with `governedBy` resolution** (governance
plan step 3.x or dedicated session)
- Build /brief skill (decision #49).
- Include `governedBy` resolution: read the governing rule, present
  current structural facts.
- Include staleness check: compare rule mtime against brief
  `lastVerified` field.
- This gives us structural prevention for governed decisions.

**Phase 3: Plan-gate extension** (when plan-gate hook is built per
decision #41)
- Add brief-rule consistency check to the plan-gate.
- This gives us execution-time prevention (last line of defense).

**Phase 4: Telemetry** (when Datadog integration ships)
- Add drift event logging to rule-write hook.
- Configure Datadog monitor for drift thresholds.
- This gives us longitudinal visibility.

**Phase 5: S2 intelligence prep** (when Mission Command plan
execution begins)
- Document brief-rule consistency check in S2's intelligence prep
  protocol.
- This gives us semantic pre-execution checking.

---

## 9. Operational Learning Loop Integration

### How this fits the AAR cycle (decision #36)

The AAR at plan end should ask: "Were any stale brief decisions
followed?" With Elements 2 and 5 in place, this question is
automatically answered:

- Element 2 logs fire/ignore events. The AAR can check: "Did the
  rule-write hook fire during this plan's execution? Were its
  reminders acted on?"
- Element 5 logs gate decisions. The AAR can check: "Was plan mode
  ever blocked for brief-rule drift? How was it resolved?"

These become AAR line items, not manual questions.

### How this feeds the S2 intelligence cycle

S2 intelligence prep (decision #26) currently reads: "read brief,
prior channel, known states." With Element 4, the instruction
becomes: "read brief, check `governedBy` freshness, flag stale
decisions, read prior channel, known states." The intelligence
brief output includes a "brief freshness" section.

This creates a closed loop:
1. Rule changes → hook flags drift (E2)
2. If drift persists → S2 catches at next plan start (E4)
3. If S2 misses → plan-gate blocks execution (E5)
4. AAR reviews the full cycle → identifies process gaps
5. Process gaps → new rule or hook adjustment → loop restarts

### Relationship to plan-gate hook (decision #41)

Decision #41 specifies the plan-gate for `blocksPlanning=true`
items (critical blockers in the brief). Brief-rule drift is a
different class of blocker: it is not marked in the brief (the brief
does not know it is stale). The plan-gate extension for drift must
use a different detection mechanism:

- `blocksPlanning`: read brief metadata, check for `true` flags.
  Static check.
- Brief-rule drift: read `governedBy` references, read governing
  rules, compare. Dynamic check.

Both produce the same outcome (block plan mode with an explanation),
but the detection logic is different. The plan-gate hook should have
two check functions: `check_blockers()` and `check_drift()`.

---

## 10. Decision Recommendation

### Proposed decision for the planning brief

> **Governed document drift prevention**: The harness must detect
> when a rule change creates inconsistency with planning brief
> decisions and prevent plan execution based on stale decisions.
>
> **Components**:
> (1) `governedBy` schema field on planning brief decisions—defers
> structural assertions to a governing rule via file path reference.
> /brief skill resolves references at read time.
> (2) `rule-write-impact.sh` PostToolUse hook on Write/Edit to
> `.claude/rules/*.md`—scans the planning brief for affected
> decisions, emits stderr reminder to check consistency.
> (3) S2 intelligence prep includes brief-rule freshness check as a
> standard step.
> (4) Plan-gate hook (decision #41) extended with drift detection
> that blocks plan mode when `governedBy` references are stale.
> (5) Drift telemetry events logged to SQLite for longitudinal
> tracking; shipped to Datadog when integration is available.
>
> **Build order**: Phase 0 (amendments + schema), Phase 1 (hook),
> Phase 2 (/brief skill), Phase 3 (plan-gate), Phase 4 (telemetry),
> Phase 5 (S2 protocol).

### Whether to add this as a new decision

**Yes.** This addresses a class of problem (governed document drift)
that the current harness does not govern. The root cause is
structural—cross-document consistency is ungoverned—and the fix
requires both schema changes and hook infrastructure. This is not
a point fix to a single incident; it is a new governance capability.

The decision should be added to the planning brief with:
- Framework attribution: Configuration Management (single source of
  truth / DRY), Three-Layer Governance (existing harness pattern)
- KPIs: drift events detected per session, time-to-resolution for
  flagged drift, false positive rate on rule-write hook
- Artifacts: `shared/hooks/rule-write-impact.sh`, `governedBy`
  field in planning-brief.json schema, S2 intelligence prep protocol
  update, plan-gate hook extension

---

## 11. Cross-References

| Artifact | Relevance |
|----------|-----------|
| `.claude/rules/aitools-workspace.md` | The governing rule that caused the incident |
| `plans/mission-command-briefing/planning-brief.json` | The dependent artifact with stale decisions |
| `.claude/rules/governed-data-access.md` | Existing principle (skill-gated access) that `governedBy` extends |
| `.claude/rules/incident-governance.md` | Three-layer governance model that frames the stack |
| `plans/governance-and-compliance-framework.md` | Hook specifications and telemetry architecture |
| Decision #26 | S2 intelligence prep (Element 4 extends this) |
| Decision #41 | Plan-gate hook (Element 5 extends this) |
| Decision #32 | Datadog/SQLite telemetry (Element 3 depends on this) |
| Decision #36 | Operational Learning / AAR (feeds the learning loop) |
| `barrier-governed-by.md` | Partial solution analysis — Element 1 |
| `barrier-fragord.md` | Partial solution analysis — rejected for brief maintenance |
| `barrier-amendment.md` | Partial solution analysis — negative ROI |
| `workspace-audit.json` | The audit that discovered the 3 critical inconsistencies |
