# S2 Investigation: Governed Document Drift Prevention Decision Design

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-16
**Classification**: Decision design investigation — barrier analysis, interaction mapping, schema analysis
**Incident origin**: Workspace rule superseded 5 planning brief decisions; brief never updated; implementing agent built stale architecture.
**Prior investigations**: `investigate-full-prevention.md` (5-element prevention stack), `barrier-governed-by.md` (governedBy field), `barrier-fragord.md` (FRAGORD rejected), `barrier-amendment.md` (amendment+codification rejected)

---

## Q1: Intent of `governedBy` — One Field or Many?

### The question

Should `governedBy` be a concept that applies to ANY governed document, not just briefs? Could a rule `governedBy` another rule? A reference file `governedBy` a rule? Or is the brief the only document type where decisions can drift from rules?

### Analysis: Audit of cross-document consistency risks in the full briefing

I audited all 52 decisions for cross-document consistency relationships. The findings fall into distinct classes:

#### Class A: Brief decisions that assert structural facts also governed by a rule

These are the cases `governedBy` was designed for. The structural assertion exists in both the decision and a rule, creating a duplication vector.

| Decision | Structural assertion | Governing rule |
|----------|---------------------|----------------|
| #22 | `.aitools/channel/` gitignore model | `aitools-workspace.md` |
| #34 | `.aitools/` directory structure, gitignore spec | `aitools-workspace.md` |
| #50 | Running estimate path, carry-forward mechanism | `aitools-workspace.md` |
| #3 | Channel directory structure (component 6) | `aitools-workspace.md` |
| #26 | Running estimate read path (component 2) | `aitools-workspace.md` |

This is the class the incident exposed. Count: 5 decisions, 1 governing rule.

#### Class B: Brief decisions that define hook behavior also specified in tool-ops.json

| Decision | Hook specification | tool-ops.json entry |
|----------|-------------------|-------------------|
| #5 | block-explore-agent.sh behavior | cc-deny-explore-agent (proposed) |
| #6 | Explore deny rule pattern | cc-deny-explore-agent (proposed) |
| #41 | plan-gate.sh behavior | plan-gate (proposed) |
| #42 | intent-enforcement.sh behavior | intent-enforcement (proposed) |
| #47 | scratch-skill-guard.sh behavior | scratch-skill-guard (proposed) |

These are PROPOSED, not yet in tool-ops.json. Once built, the hook behavior in tool-ops.json and the brief would be duplicated. But the brief is a pre-execution planning artifact — once the hooks are built, the brief is consumed. The drift risk window is narrow: between brief authoring and hook implementation. After implementation, the brief is archival.

**Assessment**: NOT a `governedBy` case. The brief defines the future hook behavior; tool-ops.json records the implemented behavior. They are in different lifecycle phases, not competing sources of truth.

#### Class C: Brief decisions that define skill intents also in SKILL.md files

| Decision | Skill intent | SKILL.md |
|----------|-------------|----------|
| #36 | /debrief intent | shared/skills/debrief/SKILL.md (proposed) |
| #45 | /brief intent | shared/skills/brief/SKILL.md (proposed) |
| #49 | 6 skill intents | 6 proposed SKILL.md files |
| #52 | Plan Writer intent | shared/skills/delegate/SKILL.md (proposed) |

Same lifecycle argument as Class B. The brief defines the intent; the SKILL.md implements it. Once implemented, the brief's intent definition is archival. The SKILL.md IS the governing artifact — the brief's intent definition is the planning snapshot.

**Assessment**: NOT a `governedBy` case. If anything, the SKILL.md files are governed by their own intents (self-referential). The brief captures planning-time intent, not operational truth.

#### Class D: Rules that could `governedBy` other rules?

Auditing the rules directory:

| Rule | Could be governed by another? |
|------|------------------------------|
| `artifact-harvesting.md` | Operational learning framework (decision #36 absorbs it) |
| `glossary.md` | No — it is self-governing (defines the vocab) |
| `frameworks.md` | No — it is the meta-governance rule |
| `tool-ops.md` | No — it is self-governing |
| `incident-governance.md` | No — it is self-governing |
| `aitools-workspace.md` | No — it IS the governing rule for workspace decisions |

The only cross-rule governance relationship I found is the absorption of `artifact-harvesting.md` into the Operational Learning framework. But that is a replacement, not a governance relationship. When `operational-learning.md` is created, `artifact-harvesting.md` will redirect to it. This is a one-time migration, not an ongoing consistency relationship.

**Assessment**: Rules do NOT need `governedBy`. Rules are authoritative — they govern, they are not governed by other rules. The hierarchy is: rules govern decisions in briefs, decisions in briefs do not govern rules.

#### Class E: Reference files `governedBy` rules?

Reference files (`reference/*.md`, `reference/*.json`) are the detailed documentation that rules summarize. The relationship is: the rule says "DO X" and the reference says "here's how X works in detail." Could a reference file drift from its rule?

Yes — and this already happened (incident #12: cross-reference breakage). But the solution is cross-reference validation (the /audit skill), not `governedBy`. The reference file IS the source of truth for its domain; the rule is a summary pointer. If they drift, the fix is to update the rule pointer, not to mark the reference as governed by the rule.

**Assessment**: Reference files do NOT need `governedBy`. Cross-reference validation is the correct mechanism.

### Barrier analysis: one field or many?

**Scenario 1: `governedBy` only on planning brief decisions.**

| Failure mode | Caught? | By what? |
|-------------|---------|----------|
| Brief decision drifts from rule | YES | `governedBy` resolution via /brief |
| Rule drifts from another rule | NO — but this isn't a real risk (rules are authoritative) | N/A |
| Reference drifts from rule | NO — but /audit catches cross-reference breakage | /audit skill |
| SKILL.md drifts from brief intent | NO — but once implemented, brief is archival | N/A |
| tool-ops.json drifts from brief hook spec | NO — but once implemented, brief is archival | N/A |

**Scenario 2: `governedBy` on all governed documents (rules, references, briefs, JSON registries).**

Same catch rate for the real failure modes, but much higher implementation complexity: every governed JSON schema needs the field, every skill needs resolution logic, every audit check needs to validate the reference. The marginal value over Scenario 1 is near zero for the marginal cost.

### Q1 Verdict

**`governedBy` should apply ONLY to planning brief decisions.** This is the only document type where:

1. Decisions can semantically contradict a governing rule
2. The brief is consumed by agents who act on its content
3. The brief's lifecycle extends long enough for drift to cause harm
4. The rule IS the authoritative source and the decision IS the subordinate that should defer

The concept does NOT need to generalize to rules (authoritative, not subordinate), reference files (cross-reference validation is sufficient), SKILL.md files (archival once implemented), or tool-ops.json (hook specs are archival once implemented).

Over-engineering this into a universal pattern would be scope creep that delays the actual fix.

---

## Q2: Hook Architecture — One Hook or Many?

### The question

Is governed document drift detection ONE feature (one hook) or MULTIPLE features (separate hooks for rule-writes, brief-reads, plan-gate)? Should it be integrated into an existing hook?

### Current hook inventory analysis

**Existing hooks (9):**

| Hook | Event | Responsibility |
|------|-------|---------------|
| block-claude-code-guide.sh | PreToolUse | Deny claude-code-guide agent |
| glossary-skill-guard.sh | PreToolUse | Inject glossary skill on glossary.json access |
| harvest-session.sh | SessionEnd | Harvest scratch artifacts |
| scratch-init.sh | SessionStart | Create scratch dir |
| session-archive.sh | SessionEnd | Archive transcript |
| sh-file-fixup.sh | PostToolUse | Fix CRLF/chmod on .sh files |
| standing-order-guard.sh | PreToolUse | Enforce standing orders |
| surfacing-duty-stop.sh | Stop | Remind surfacing duty |
| tool-ops-session-audit.sh | SessionStart | Audit tool-ops state |

**Proposed hooks from the brief (8):**

| Hook | Decision | Event | Responsibility |
|------|----------|-------|---------------|
| block-explore-agent.sh | #5 | PreToolUse | Deny Explore agents |
| channel-archive.sh | #36 | SessionEnd | Archive channel messages |
| aar-reminder.sh | #36 | Stop | Nudge AAR production |
| channel-init.sh | #36/#50 | SessionStart | Channel readiness |
| plan-gate.sh | #41 | PreToolUse | Block plan mode on unresolved blockers |
| intent-enforcement.sh | #42 | PreToolUse | Require intent on new framework files |
| scratch-skill-guard.sh | #47 | PreToolUse | Inject scratch skill on scratch access |
| brief-read-guard.sh | #45 | PreToolUse | Redirect raw brief reads to /brief skill |

**Proposed from prior investigation (1):**

| Hook | Element | Event | Responsibility |
|------|---------|-------|---------------|
| rule-write-impact.sh | E2 | PostToolUse | Flag brief decisions affected by rule changes |

Total proposed: 9 + 8 + 1 = 18 hooks.

### Decision #20 analysis: "one hook per feature"

Decision #20 says: "New capability = new hook. New hook = entry in tool-ops.json. Exception: extending existing only when explicitly stated."

The question is: what constitutes ONE feature?

**Drift detection feature decomposition:**

| Detection point | When it fires | What it catches |
|----------------|---------------|-----------------|
| Rule-write impact (E2) | Write/Edit to `.claude/rules/*.md` | Drift at creation time |
| Plan-gate drift check (E5) | EnterPlanMode | Drift at execution time |
| Brief-read guard (existing #45) | Read of planning-brief.json | Drift at consumption time |

These fire at different events (PostToolUse on Write, PreToolUse on EnterPlanMode, PreToolUse on Read), on different targets, at different lifecycle points. They are THREE features by decision #20's standard.

### Barrier analysis: one hook vs three specialized hooks

**Scenario A: One "drift-detection" hook that fires on all three events.**

This would require a hook registered for PostToolUse (Write/Edit) AND PreToolUse (EnterPlanMode, Read). Claude Code hooks are registered per event type. A single script could check its invocation context, but it would need to handle three fundamentally different detection mechanisms:

1. PostToolUse on Write: read the new rule content, scan brief for affected decisions by keyword
2. PreToolUse on EnterPlanMode: read brief, check `governedBy` references against rule mtimes
3. PreToolUse on Read: check if target is planning-brief.json, inject /brief reminder

These are three different algorithms with three different inputs and three different outputs. Combining them violates the single-responsibility principle that decision #20 established.

**Failure mode of combined hook:** A bug in the keyword-matching algorithm (E2) could cause the hook to crash on all three events, disabling plan-gate checking (E5) and brief-read-guard (#45). The user explicitly rejected conflating hooks: "i dont like conflating hooks" (decision #20 context).

**Scenario B: Three specialized hooks, each with one responsibility.**

| Hook | Feature | Failure impact if buggy |
|------|---------|----------------------|
| rule-write-impact.sh | Drift detection at creation | Only loses creation-time alerting |
| plan-gate.sh (extended) | Drift detection at execution | Only loses plan-gate drift check |
| brief-read-guard.sh | Brief access governance | Only loses brief access redirection |

Blast radius per bug: ONE feature, not three.

### Integration with existing decisions

**Decision #41 (plan-gate hook)**: The plan-gate hook already fires on PreToolUse for EnterPlanMode and reads the planning brief. Adding drift detection to plan-gate.sh is an EXTENSION of an existing hook's feature, not a new hook. The plan-gate's responsibility is "planning readiness enforcement" — drift detection is another dimension of planning readiness, alongside `blocksPlanning=true` checks. Decision #41 component (4): "Checks: any fact with blocksPlanning=true, any decision with blocksPlanning=true." Extending to also check `governedBy` staleness is the same feature: "is the brief ready for plan execution?"

**Decision #45 (brief-read-guard hook)**: Already fires on PreToolUse for Read of planning-brief.json. Its job is "redirect raw reads to /brief skill." The /brief skill is where `governedBy` resolution happens. The brief-read-guard does NOT need drift detection — it just redirects to the skill, and the skill handles everything including `governedBy` resolution. No extension needed.

**Rule-write-impact (E2)**: This is genuinely new. No existing hook fires on PostToolUse for Write/Edit to `.claude/rules/`. This is a new feature: "alert when rule changes may affect brief decisions." New feature = new hook per decision #20.

### Q2 Verdict

**TWO hooks, not three. One new, one extended.**

1. **New hook: `rule-write-impact.sh`** (PostToolUse on Write/Edit to `.claude/rules/`). Responsibility: scan brief for affected decisions when a rule changes. Advisory only (PostToolUse cannot block). This is a genuinely new feature.

2. **Extended hook: `plan-gate.sh`** (decision #41, PreToolUse on EnterPlanMode). Extend with `check_drift()` alongside existing `check_blockers()`. Same feature (planning readiness), two check functions. This is the explicitly stated exception in decision #20: "Exception: extending existing only when explicitly stated."

3. **No change to `brief-read-guard.sh`** (decision #45). The /brief skill handles `governedBy` resolution at read time. The hook just redirects to the skill. No drift detection logic needed in the hook.

This respects decision #20 (one hook per feature), avoids conflation, and integrates with the existing decision landscape rather than creating parallel infrastructure.

---

## Q3: Where Does `governedBy` Live in the Schema?

### The question

Only on planning brief decisions? Or on any governed JSON's entries?

### Analysis by governed JSON registry

| Registry | Governing skill | Could entries have `governedBy`? | Analysis |
|----------|----------------|----------------------------------|----------|
| `planning-brief.json` | /brief | YES — decisions defer structural assertions to rules | This is the incident case |
| `incidents.json` | /incident | Maybe — incidents reference rules as `expected` field | But `expected` already cites the rule. Adding `governedBy` is redundant |
| `tool-registry.json` | /tool-registry | Maybe — entries reference install methods governed by tool-eval playbook | But install methods are data, not assertions that can drift from a rule |
| `glossary.json` | /glossary | No — glossary IS the source of truth for terms | Nothing governs terms above the glossary |
| `framework-registry.json` | /frameworks | No — registry IS the source of truth for frameworks | Nothing governs frameworks above the registry |
| `tool-ops.json` | /tool-ops | No — tool-ops IS the source of truth for hook behavior | Nothing governs hook ops above tool-ops |
| `harvest-manifest.json` | /harvest | No — manifest IS the source of truth for artifacts | Nothing governs artifacts above the manifest |

### The `incidents.json` case

Incidents have an `expected` field: "What specific rule, reference, principle, or convention says the state should be different? Cite the source." This is already a pointer to the governing rule. Adding `governedBy` would be redundant — `expected` serves the same purpose with richer context (it names the specific section and explains why).

The incident does not DEFER to the rule; it CITES the rule as evidence of a violation. The relationship is different from `governedBy`: incidents reference rules as evidence, decisions defer to rules as authority.

### The `tool-registry.json` case

Tool registry entries have install methods, platform versions, lifecycle phases. These are governed by the tool evaluation playbook (`reference/tool-evaluation-playbook.md`). But a tool entry saying "install via cargo" cannot drift from the playbook in the way a decision saying "channel is gitignored" can drift from a workspace rule. The playbook governs the PROCESS of choosing install methods, not the FACT of which method was chosen. `governedBy` tracks factual assertions that can become stale, not process provenance.

### Minimal viable scope analysis

**What `governedBy` must cover to solve the actual problem:**

Planning brief decisions that contain structural assertions also asserted by a rule. This is 5 decisions out of 52, all governed by one rule (`aitools-workspace.md`). The number may grow as more rules are written, but the pattern is always: brief decision asserts X, rule also asserts X, X changes in the rule, decision becomes stale.

**What `governedBy` does NOT need to cover:**

- Incident `expected` fields (already cite rules — different purpose)
- Tool registry install methods (process provenance, not assertion governance)
- Glossary, framework-registry, tool-ops (self-governing registries)
- Harvest manifest (artifact lifecycle, not governed assertions)

### Q3 Verdict

**`governedBy` lives ONLY in the planning brief schema, on the decision object.** The field is an optional string containing the path to a governing rule. The /brief skill resolves the reference at read time. No other governed JSON needs this field because no other governed JSON has the specific failure mode of "entries asserting facts also asserted by an external rule."

The minimal schema addition:

```json
{
  "id": 22,
  "decision": "...",
  "governedBy": ".claude/rules/aitools-workspace.md",
  // ... rest of decision fields
}
```

The /brief skill, when presenting a decision with `governedBy`:
1. Reads the governing rule
2. Extracts the structural assertions relevant to this decision
3. Presents the rule's current structural facts alongside the decision's implementation components
4. Flags if the rule's mtime is newer than the brief's last update (potential drift)

---

## Q4: Interaction with Existing Decisions

### Decision #41 (plan-gate hook) — Extension, not new decision

Decision #41 specifies: "PreToolUse on EnterPlanMode reads the planning brief, checks for unresolved blocksPlanning=true items, and denies with corrective context."

Drift detection extends this with a second check function. The plan-gate hook's components would become:

- Original: `check_blockers()` — reads blocksPlanning=true items
- Extended: `check_drift()` — reads `governedBy` references, checks rule mtimes

Both produce the same outcome: deny plan mode entry with corrective context listing the specific problem. Both serve the same feature: planning readiness enforcement.

**Interaction**: The new decision EXTENDS #41 by adding a component to plan-gate.sh. Decision #41's `related` array should include the new decision ID. The new decision's components should reference decision #41 as the infrastructure being extended. Build dependency: plan-gate.sh must exist (decision #41) before drift detection can be added.

### Decision #45 (brief as governed data, /brief skill) — Schema extension

Decision #45 specifies: "Planning brief is governed data — /brief skill gates access." The `governedBy` field is a schema extension to the planning brief JSON. The /brief skill's read mode needs `governedBy` resolution logic.

**Interaction**: The new decision EXTENDS #45's schema. The /brief skill (proposed in #45) must include `governedBy` resolution as part of its read mode. The `governedBy` field becomes part of the brief schema defined by #45. The new decision should list #45 as a dependency (the /brief skill must exist for `governedBy` resolution to work). Decision #45's components could add: "(10) Resolve `governedBy` references at read time — present governing rule's current structural facts alongside decision's implementation components."

### Decision #50 (running estimate) — Same pattern, different scope

Decision #50 is a cross-session state document. Could it drift from its schema?

The running estimate (`running-estimate.json`) is governed by its own schema (`reference/running-estimate-schema.json`, proposed). The schema is the authority; the estimate instance is the data. This is standard schema validation — the PreToolUse hook on Write to running-estimate.json validates against the schema.

This is NOT the same pattern as governed document drift. Governed document drift is when two SEPARATELY-MAINTAINED documents assert the same fact differently. The running estimate is an instance of a schema, not a decision that duplicates a rule.

However, the running estimate DOES have a cross-session consistency concern: if the schema changes between sessions, an old estimate may not parse under the new schema. This is SCHEMA MIGRATION, not DRIFT. The channel-init.sh hook (decision #50 component 3) handles this: "If it exists (carry-forward from prior session), reads and continues from current state."

**Interaction**: No direct interaction. Different class of problem. The new decision should note in its scope: "NOT schema migration for cross-session state documents (running estimate — handled by channel-init.sh)."

### Decision #35 (UCIs not effective, structural fixes needed) — Partial closure

Decision #35 says: "UCIs are not effective for recurring behavioral patterns — hooks are the preferred structural mechanism."

The governed document drift prevention IS a structural fix for a behavioral problem. The behavioral version would be a UCI: "When writing a rule, check the brief for affected decisions." The structural version: a hook (rule-write-impact.sh) that fires when rules are written and alerts the agent.

But decision #35 is broader — it covers ALL recurring behavioral patterns, not just document drift. The drift prevention decision closes ONE instance of #35's class, not the entire class. Other instances include: the band-aid pattern (decision #48), the assert-without-checking pattern (incidents #34/#35/#48), and the intent-skipping pattern (decision #42).

**Interaction**: The new decision is EVIDENCE that #35's principle works. It should reference #35 in its rationale: "Per decision #35: structural enforcement (hooks) over behavioral coaching (UCIs). The rule-write-impact hook structurally enforces what was previously a behavioral expectation (check the brief when writing rules)."

### Interaction map summary

| Decision | Relationship | How they interact |
|----------|-------------|-------------------|
| #41 | Extends | Adds drift detection to plan-gate hook |
| #45 | Extends schema | Adds `governedBy` field to brief schema, resolution logic to /brief skill |
| #50 | Different pattern | Running estimate is schema validation, not document drift |
| #35 | Evidence of | Drift prevention is a structural fix for a behavioral pattern |
| #20 | Governed by | One hook per feature — new hook for rule-write-impact, extension for plan-gate |
| #3/#22/#26/#34 | Beneficiaries | Decisions that receive `governedBy` field pointing to workspace rule |
| #29 | Complementary | Critical facts resolved before planning; drift detection catches stale decisions |
| #36 | Framework source | Operational learning's barrier analysis concept applied to drift detection |
| #48 | Related pattern | Band-aid prevention is a related class of "fix-right" structural enforcement |

---

## Q5: Draft Decision

Based on the analysis above, here is the complete decision entry:

```json
{
  "id": 53,
  "decision": "Governed document drift prevention: `governedBy` schema field + rule-write impact hook + plan-gate drift check — structural enforcement against stale brief decisions",
  "rationale": "Workspace rule superseded 5 planning brief decisions (#3, #22, #26, #34, #50); brief never updated; implementing agent built stale architecture (session uyZ7TELqpP). Root cause: cross-document consistency is ungoverned — the harness governs single-document correctness (skill gates, schema validation) but not the case where Rule A supersedes Decision B across different governance scopes. S2 barrier analysis evaluated 3 partial solutions: governedBy (structural, PARTIAL — prevents drift but not forgetting), FRAGORD (distribution, REJECTED — solves wrong problem), amendment+codification (audit, REJECTED — negative ROI). Combined prevention stack: `governedBy` field eliminates structural duplication (prevention), rule-write-impact hook catches drift at creation time (detection), plan-gate extension catches drift at execution time (prevention). Per decision #35: structural enforcement via hooks over behavioral coaching via UCIs.",
  "context": "Session RTzBnBupE6: S2 investigation produced 3 barrier analyses, full prevention stack design, and incident replay. Prior session: `.claude/rules/aitools-workspace.md` written without updating brief. Session uyZ7TELqpP: agent implemented stale architecture from brief. S2 investigations: barrier-governed-by.md, barrier-fragord.md, barrier-amendment.md, investigate-full-prevention.md, investigate-governed-drift-decision.md.",
  "components": [
    "(1) Add optional `governedBy` field to planning brief decision schema — string containing path to governing rule (e.g., `.claude/rules/aitools-workspace.md`). Decisions with `governedBy` defer STRUCTURAL assertions to the rule; IMPLEMENTATION details remain in decision components. Scope: structural facts (directory layout, gitignore classification, scope boundaries). Not: implementation details (hook behavior, seeding logic, read paths)",
    "(2) /brief skill `governedBy` resolution: when presenting a decision with the field, read the governing rule, extract structural assertions, present alongside decision's implementation components. Flag if rule mtime is newer than brief's last update (potential staleness)",
    "(3) New hook: shared/hooks/rule-write-impact.sh — PostToolUse on Write/Edit to `.claude/rules/*.md`. Scans planning brief for decisions referencing the affected domain (keyword/path matching, err toward over-matching). Emits stderr reminder: 'Rule change in {rule}. Brief decisions {IDs} reference this domain. Check consistency via /brief.' Advisory only (PostToolUse cannot block). Handles: no brief exists (no-op), brief parse error (warn, continue)",
    "(4) Extend plan-gate.sh (decision #41) with check_drift() alongside existing check_blockers(). Reads `governedBy` references, checks governing rules exist and are not newer than brief's last verified timestamp. If drift detected: deny plan mode with corrective context listing stale decisions. Same hook, same event (PreToolUse on EnterPlanMode), extended feature (planning readiness enforcement). NOT a new hook per decision #20 — explicit extension of existing",
    "(5) Apply `governedBy` to decisions #3, #22, #26, #34, #50 — all governed by `.claude/rules/aitools-workspace.md`. Simplify structural components (directory layout, gitignore rules) to one-line references. Keep implementation components (hook behavior, seeding logic, read paths) detailed",
    "(6) Apply the 10 amendments from workspace-audit.json proposals — align stale component text with current workspace rule assertions. These amendments are the initial data fix; `governedBy` prevents recurrence",
    "(7) S2 intelligence prep (decision #26) includes brief-rule freshness as a standard check — reads `governedBy` references, flags stale decisions in intelligence brief. Semantic check catches drift in decisions without `governedBy`",
    "(8) Scope exclusions: NOT schema migration for cross-session state documents (running estimate — channel-init.sh handles this). NOT cross-reference breakage (/audit skill handles this). NOT hook behavior governance (tool-ops.json handles this). NOT skill intent drift (brief intents are archival once skill is implemented)"
  ],
  "frameworks": [
    {
      "name": "Three-layer governance",
      "status": "existing",
      "note": "Prevention (governedBy field), Detection (rule-write-impact hook, plan-gate drift check), Audit (S2 intelligence prep, /audit skill)"
    },
    {
      "name": "Governed data access",
      "status": "existing",
      "note": "Extends the existing skill-gated access pattern — /brief skill resolves governedBy references"
    },
    {
      "name": "Incident investigation",
      "status": "existing",
      "note": "Barrier analysis methodology applied to evaluate each prevention element"
    },
    {
      "name": "Mission command",
      "status": "proposed",
      "note": "S2 intelligence prep includes brief freshness check"
    }
  ],
  "artifacts": [
    {
      "path": "shared/hooks/rule-write-impact.sh",
      "status": "proposed",
      "scope": "user hook",
      "intent": {
        "purpose": "Alert agents when rule changes may affect planning brief decisions — advisory drift detection at the moment drift is created",
        "scope": "PostToolUse on Write/Edit to .claude/rules/*.md only. Advisory feedback via stderr, never blocking. Single responsibility: rule-to-brief impact alerting. NOT brief access governance (brief-read-guard.sh). NOT planning readiness enforcement (plan-gate.sh). NOT schema validation",
        "audience": "Claude Code hook infrastructure, deployed to ~/.claude/hooks/"
      }
    },
    {
      "path": "shared/hooks/plan-gate.sh",
      "status": "proposed",
      "scope": "user hook — extends decision #41",
      "intent": "Add check_drift() function alongside check_blockers(). Reads governedBy references, validates governing rules exist and are current. Deny plan mode if stale decisions detected"
    },
    {
      "path": "shared/skills/brief/SKILL.md",
      "status": "proposed",
      "scope": "extends decision #45",
      "intent": "Add governedBy resolution mode: read governing rule, extract structural assertions, present alongside implementation components. Flag staleness when rule is newer than brief"
    },
    {
      "path": "plans/mission-command-briefing/planning-brief.json",
      "status": "existing",
      "intent": "Add optional governedBy field to decision schema. Apply to decisions #3, #22, #26, #34, #50"
    },
    {
      "path": "reference/tool-ops.json",
      "status": "existing",
      "intent": "Register rule-write-impact hook with verification cases"
    }
  ],
  "kpis": [
    {
      "name": "driftDetectionRate",
      "source": "rule-write-impact hook logs",
      "unit": "percent rule changes that fire the hook and find affected decisions",
      "target": "100% of rule changes to domains with brief decisions"
    },
    {
      "name": "driftResolutionTime",
      "source": "brief update timestamps after hook fires",
      "unit": "sessions between drift detection and brief amendment",
      "target": "<= 1 (resolved in the session that creates the drift)"
    },
    {
      "name": "governedByAdoptionRate",
      "source": "planning brief schema audit",
      "unit": "percent decisions with structural assertions that have governedBy",
      "target": ">= 90%"
    },
    {
      "name": "planGateDriftDenyRate",
      "source": "plan-gate hook logs",
      "unit": "plan mode denials due to stale governedBy references",
      "target": "trending to 0 (drift caught earlier by rule-write hook)"
    },
    {
      "name": "falsePositiveRate",
      "source": "rule-write-impact hook logs — flagged decisions that were not actually affected",
      "unit": "percent false positives",
      "target": "< 30% (err toward over-matching per design)"
    }
  ],
  "status": "proposed",
  "related": [3, 20, 22, 26, 29, 34, 35, 41, 45, 50]
}
```

---

## Recommendations Summary

### 1. Scope `governedBy` narrowly

`governedBy` is a planning brief schema field ONLY. Not a universal governed-document concept. The brief is the only document type where decisions assert structural facts also asserted by rules, creating the duplication-to-drift pipeline. Rules, references, and other JSON registries have different governance relationships that are adequately served by existing mechanisms (cross-reference validation, schema validation, skill gates).

### 2. Two hooks, not five

The prior investigation proposed 5 elements. The optimal architecture is:

- **Element 1 (`governedBy` field)**: YES — build as designed. Prevention layer.
- **Element 2 (rule-write-impact hook)**: YES — new hook, ~80 lines. Detection layer. The keystone — catches drift at creation time.
- **Element 3 (drift telemetry)**: DEFER — build when Datadog integration ships. Low marginal value until then.
- **Element 4 (S2 intelligence prep)**: YES — but it is a PROCESS addition to S2's checklist, not a hook or code artifact. Near-zero implementation cost.
- **Element 5 (plan-gate extension)**: YES — but as an EXTENSION of decision #41's hook, not a new hook. Respects decision #20.

Net: 1 new hook (rule-write-impact.sh), 1 extended hook (plan-gate.sh), 1 schema field, 1 process addition.

### 3. Build order

**Phase 0 (immediate, this session or next):**
- Apply 10 amendments to planning brief (data fix)
- Add `governedBy` field to decisions #3, #22, #26, #34, #50
- Simplify structural components, keep implementation components

**Phase 1 (next focused session):**
- Build rule-write-impact.sh (~80 lines bash)
- Register in tool-ops.json via /tool-ops
- Test: modify a rule, verify hook fires and finds affected decisions

**Phase 2 (when /brief skill is built per decision #45):**
- Add `governedBy` resolution to /brief skill read mode
- Include staleness check (rule mtime vs brief update timestamp)

**Phase 3 (when plan-gate hook is built per decision #41):**
- Add `check_drift()` function to plan-gate.sh
- Test: create stale `governedBy` reference, verify plan mode is denied

**Phase 4 (process, when Mission Command plan is executed):**
- Document brief-rule freshness check in S2 intelligence prep protocol
- Add to /delegate skill's S2 delegation template

### 4. The decision extends existing decisions, it does not replace them

- Decision #41: extended by adding drift detection to plan-gate
- Decision #45: extended by adding `governedBy` to brief schema and resolution to /brief skill
- Decision #35: evidenced by this structural fix for a behavioral pattern
- Decision #20: respected — one new hook for one new feature, one explicit extension

### 5. Watch for scope creep

The `governedBy` field must apply to STRUCTURAL assertions only. If every decision gets `governedBy`, the brief becomes a stub that says "see the rules." The brief exists to give executing agents all resolved decisions without re-derivation. Implementation details (hook behavior, seeding logic, read paths) must stay in decision components. The barrier analysis identified this as the highest-likelihood failure mode (section 2d of barrier-governed-by.md).

---

## Cross-References

| Artifact | Relevance |
|----------|-----------|
| `investigate-full-prevention.md` | Prior S2 investigation — 5-element stack, build sequencing |
| `barrier-governed-by.md` | Barrier analysis on governedBy — selective application guidance |
| `barrier-fragord.md` | FRAGORD rejected for brief maintenance |
| `barrier-amendment.md` | Amendment+codification rejected — negative ROI |
| `workspace-audit.json` | Audit that discovered 3 critical inconsistencies |
| `.claude/rules/aitools-workspace.md` | The governing rule that caused the incident |
| `.claude/rules/governed-data-access.md` | Existing skill-gated access pattern being extended |
| `.claude/rules/incident-governance.md` | Three-layer governance model framing the stack |
| Decision #20 | One hook per feature — governs hook architecture choice |
| Decision #35 | UCIs not effective — this decision is evidence of the structural fix principle |
| Decision #41 | Plan-gate hook — extended with drift detection |
| Decision #45 | Brief as governed data — schema extended with `governedBy` |
| Decision #50 | Running estimate — different pattern (schema migration, not document drift) |
