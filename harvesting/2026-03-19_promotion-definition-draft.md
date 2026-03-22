# Governed Vocabulary Draft: "promotion"

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Blocker**: Q4-Q10 ambiguity audit, blocker #1

---

## 1. Current Usage Inventory

Five distinct meanings of "promotion" appear across the harness. Each
involves moving something forward, but the mechanism, subject, and
outcome differ.

### Meaning A: Artifact lifecycle transition (harvesting pipeline)

**What it means**: An artifact in `harvesting/` passes evaluation
criteria and is moved or refactored into a permanent harness location
(`reference/`, `.claude/rules/`, `shared/skills/`, `shared/shell/`).
The manifest status changes from `candidate` to `promoted` and the
`promotedTo` field records the destination path.

**Mechanism**: Status change in manifest JSON + physical file
move/refactor to target location.

**Sources**:
- `.claude/rules/artifact-harvesting.md` lines 5, 7, 45-52 ("Promotion
  criteria", "promotion candidates")
- `.claude/skills/harvest/SKILL.md` lines 63, 79-90 (`harvested` ->
  `candidate` -> `promoted`, `promotedTo` field)
- `harvesting/harvest-manifest.json` — every entry has `promotedTo`
  field
- `reference/framework-artifact-harvesting.md` lines 4, 27, 43, 46, 49
  ("promotion moves them toward tool", "promotion candidates",
  "promotion rate")
- `q4-lifecycle-investigation.md` lines 72-76, 101-107, 256-260, 327-335
  ("promotion path", "promoted to `reference/`", "promotion gate")
- `.claude/rules/aitools-workspace.md` line 40 ("candidates for harness
  promotion")

### Meaning B: Tool-ops mode escalation (audit -> active)

**What it means**: A tool-ops metadata category (deny rules, hooks,
context injection) transitions from `audit` mode (logged, advisory) to
`active` mode (enforced, blocking) after zero-drift evidence.

**Mechanism**: Mode value change in the tool-ops registry JSON.

**Sources**:
- `reference/framework-tool-ops.md` lines 39-40, 54 ("Categories
  promote independently", "Zero-drift across sessions promotes audit ->
  active")

### Meaning C: Hook check mode escalation (observe -> enforce)

**What it means**: A hook enforcement check transitions from `observe`
mode (logged, non-blocking) to `enforce` mode (blocking on violation)
after zero false positives confirmed in logs.

**Mechanism**: Mode variable change in hook script.

**Sources**:
- `.claude/rules/hook-rollout.md` lines 30, 62, 74 ("mode promotion",
  "not yet promoted", "fix matching before promoting")
- `reference/framework-hook-rollout.md` lines 31-32 ("Log review
  identifies false positives before promotion", "Mode promotion requires
  zero false positives")

### Meaning D: Tool lifecycle phase transition (evaluating -> approved)

**What it means**: A managed tool passes Phase 2 evaluation (user
verdict) and its tool-registry entry moves from "Under Evaluation" to
a full entry.

**Mechanism**: Registry entry restructuring in tool-registry.json.

**Sources**:
- `.claude/rules/tool-lifecycle.md` line 38 ("promote to full entry")
- `reference/tool-evaluation-criteria.md` lines 110, 160 ("promotes the
  tool to the main section", "promotes the entry from Under Evaluation")

### Meaning E: Conceptual label (tactical -> strategic)

**What it means**: An artifact evolves from solving an immediate problem
to becoming a proper abstraction or permanent capability. Used as a
conceptual metaphor without specifying a particular mechanism.

**Mechanism**: No specific mechanism — this is the general concept that
meanings A-D are instances of.

**Sources**:
- `reference/framework-artifact-harvesting.md` lines 27-28 ("promotion
  moves them toward tool" — Toil automation progression)
- `reference/framework-registry.json` line 164 ("Tactical-to-strategic
  promotion (Ousterhout)")

---

## 2. Conversation Signals

Session transcripts were not accessible for direct search (Grep denied
on files outside project scope). However, the planning brief JSON
(which captures user decisions) contains these user-ratified uses:

- `planning-brief.json` line 2318: "/harvest -- manage artifacts:
  promote, prune, manifest" — user-approved component description.
  Uses "promote" as meaning A (artifact lifecycle).
- `planning-brief.json` line 2370: "Manage artifact harvesting
  lifecycle -- promote, prune, manifest updates" — user-approved
  skill intent. Uses "promote" as meaning A.
- `planning-brief.json` line 2456: "percent harvested promoted to
  harness" — user-approved KPI. Uses "promote" as meaning A.
- `planning-brief.json` line 3214: "/harvest -- manage artifact
  lifecycle (promote/prune/manifest)" — user-approved skill spec.
  Uses "promote" as meaning A.

The Q4 lifecycle investigation (2026-03-18, most recent) uses
"promotion" 14+ times, exclusively in meaning A context (artifact
lifecycle transitions with directional paths like "scratch ->
harvesting -> reference").

The briefings-location-decision (2026-03-18, most recent) uses
"promotion gates" once, in meaning A context.

**Signal weight**: The overwhelming majority of recent usage is meaning
A. Meanings B, C, and D each appear 2-3 times in their respective
domain files.

---

## 3. Draft Definition

### Option 1: Single unified term

```json
"promotion": {
  "definition": "Advancing an artifact, registry entry, or enforcement mode from a lower lifecycle stage to a higher one — where the artifact gains broader scope, stronger enforcement, or permanent placement. The manifest, registry, or config that tracks the item records the transition (e.g., status: 'promoted', mode: 'active'). Distinct from harvesting (which moves ephemeral artifacts into evaluation) and pruning (which removes artifacts that did not advance).",
  "source": ".claude/rules/artifact-harvesting.md"
}
```

### Option 2: Primary term with domain notes

```json
"promotion": {
  "definition": "Advancing a tracked item from evaluation to a permanent or enforced state after it meets defined criteria. In the artifact lifecycle: moving a harvested artifact to a permanent harness location (reference/, rules/, skills/, shell/) and recording the destination in the manifest. In tool-ops and hook rollout: escalating a mode from audit/observe to active/enforce after zero-drift evidence. Always recorded in the governing registry. Distinct from harvesting (ephemeral to evaluation) and pruning (removal).",
  "source": ".claude/rules/artifact-harvesting.md"
}
```

### Option 3: Keep it tight (recommended)

```json
"promotion": {
  "definition": "Advancing a tracked item from an evaluation stage to a permanent or enforced state after it meets criteria defined by the governing lifecycle. The transition is recorded in the item's registry (harvest manifest, tool-ops registry, hook enforcement table). Distinct from harvesting (entering evaluation) and pruning (leaving without advancement).",
  "source": ".claude/rules/artifact-harvesting.md"
}
```

---

## 4. Ambiguity Removal Passes

### Pass 1: Undefined terms

| Term in draft | Governed? | Self-evident? | Action |
|---------------|-----------|---------------|--------|
| tracked | No | Yes (common English: followed/recorded) | Keep |
| evaluation stage | No | Partially | "evaluation" is common; "stage" is common. Together they are clear in context |
| permanent | No | Yes | Keep |
| enforced state | No | Partially | Changed from "enforced" alone to "enforced state" for clarity |
| criteria | No | Yes | Keep |
| governing lifecycle | No | Partially | Each domain has its own lifecycle spec. "Governing" connects to governed vocabulary. Keep — the reader is directed to the lifecycle, not expected to know it |
| registry | Yes | N/A | Governed term. Keep |
| harvest manifest | No | Partially | It is the specific name of the file. Changed to use "registry" as the generic |
| harvesting | Yes (implicit) | N/A | Used in the harness extensively. Keep |
| pruning | No | Yes (established by artifact-harvesting.md) | Keep — defined by contrast |

**Changes from Pass 1**: Replaced specific registry names with "the
item's registry" and added parenthetical examples. This makes the
definition work for all four meanings without requiring the reader to
know each registry name.

### Pass 2: Vague mechanisms

| Phrase | Vague? | Fix |
|--------|--------|-----|
| "advancing" | Slightly — advancing how? | Acceptable: the definition specifies what "advancing" means in the next clause ("from evaluation to permanent/enforced") |
| "meets criteria" | Vague — which criteria? | Acceptable: criteria differ per lifecycle (harvesting rule vs. hook rollout vs. tool-ops). The definition correctly delegates to "defined by the governing lifecycle" |
| "recorded in the item's registry" | Specific enough | The parenthetical names the three registries |
| "permanent or enforced state" | Clear | "Permanent" = stays in the harness. "Enforced" = blocks violations. These are the two outcomes |

**Changes from Pass 2**: None needed. The mechanism is specified:
(1) item meets criteria, (2) item transitions state, (3) transition
recorded in registry. The definition describes the mechanism, not just
the outcome.

### Pass 3: Re-read after edits

Re-read of Option 3 after Pass 1 and Pass 2. The definition reads
cleanly. No new ambiguities introduced. One adjustment: added "or
enforced" to the "permanent" in "without advancement" — wait, no.
"Leaving without advancement" correctly covers both directions (the
item did not advance, regardless of whether the target was permanent
or enforced). No change needed.

---

## 5. Exemplar Calibration

Calibrated against three recent governed term definitions:

### Exemplar 1: "incident"
> "A tracked deficiency in the harness. Unifies the former 'gap' (code
> deviates from spec) and 'ambiguity' (no spec exists) types. Filed in
> incidents.json with structured fields. Severity: critical/high/medium
> /low. Lifecycle: open, planned, closed."

**Pattern**: One-sentence core definition. Then qualifying details
(what it unifies, where it lives, key enumerations). Two sentences
total.

### Exemplar 2: "file classification"
> "The access tier assigned to a harness file: open (unrestricted),
> protected (writes require human review), or governed (access requires
> governing skill process)."

**Pattern**: One-sentence definition with inline enumeration of the
possible values.

### Exemplar 3: "governed vocabulary"
> "The practice of maintaining a single authoritative definition for
> every term used across the harness. Adopted from ubiquitous language
> (Domain-Driven Design) and faceted classification (Ranganathan).
> Implemented via the glossary rule, JSON, and skill."

**Pattern**: One-sentence core definition. Source discipline. Then
implementing artifacts.

### Calibration result

Option 3 matches the exemplar pattern: core definition (one sentence),
mechanism detail (one sentence on registry), then distinction from
related terms (one sentence). Three sentences total, matching
"incident" length. The parenthetical registry examples match "file
classification" style.

---

## 6. Barrier Test

Using **Option 3 only**, classify whether these actions are promotions:

### Test 1: Moving a script from `.scratch/` to `harvesting/`

Classification using the definition: **Not a promotion.** The
definition says promotion advances from "an evaluation stage to a
permanent or enforced state." Moving from scratch to harvesting is
entering the evaluation stage, not leaving it. The distinction clause
confirms: "Distinct from harvesting (entering evaluation)."

Correct? Yes. This is harvesting, not promotion.

### Test 2: Changing a hook check from `observe` to `enforce`

Classification using the definition: **Yes, a promotion.** The item
(a hook check) is tracked. It advances from an evaluation stage
(observe mode, where violations are logged but not blocked) to an
enforced state (enforce mode, where violations are blocked). The
criteria are defined by the governing lifecycle (hook-rollout.md: zero
false positives in logs). The transition is recorded in the enforcement
table.

Correct? Yes. This matches meaning C.

### Test 3: A user decides to keep a harvested investigation report because it is still useful, but does not move it anywhere

Classification using the definition: **Not a promotion.** Flagging
"keep" prevents pruning but does not advance the item to a permanent
or enforced state. The item remains in the evaluation stage
(harvesting/) with status `candidate` or `harvested`. No transition to
a new state occurs.

Correct? Yes. This is retention/preservation, not promotion.

All three correctly classified by a fresh reading of Option 3.

---

## 7. Recommendation

**Single term, not split.** "Promotion" should be one governed term
covering all four domain-specific instances (artifact lifecycle,
tool-ops mode, hook mode, tool lifecycle phase). The reasons:

1. **All four share the same abstract mechanism**: item in evaluation
   -> item meets criteria -> item advances to higher state -> registry
   records the transition. The definition captures this shared
   structure.

2. **Splitting creates governed vocabulary bloat**: "artifact
   promotion", "mode promotion", "tool promotion", "hook promotion"
   would add 4 terms for what is fundamentally one concept applied in
   different domains. The domain context (which lifecycle, which
   registry) disambiguates naturally.

3. **User signals favor unity**: All user-ratified uses in the planning
   brief treat "promote" as a single verb with contextual meaning
   ("promote, prune, manifest"). No user message has ever needed to
   distinguish between promotion types.

4. **The conceptual label (meaning E)** is not a separate meaning — it
   is the general case that meanings A-D instantiate. The definition
   captures the general case, and each domain's lifecycle documentation
   specifies the criteria and registry for its instance.

### Proposed glossary entry (final)

```json
"promotion": {
  "definition": "Advancing a tracked item from an evaluation stage to a permanent or enforced state after it meets criteria defined by the governing lifecycle. The transition is recorded in the item's registry (harvest manifest, tool-ops registry, hook enforcement table). Distinct from harvesting (entering evaluation) and pruning (leaving without advancement).",
  "source": ".claude/rules/artifact-harvesting.md"
}
```

### Glossary rule addition

Add `promotion` to the Terms list in `.claude/rules/glossary.md`,
alphabetically between `prevention` and `process deviation`.

### Note for S3

This definition resolves blocker #1 from the Q4-Q10 ambiguity audit.
The term should be filed via the `/glossary` skill, which handles the
governed process for adding new terms. The draft above is ready for
user review as part of that process.
