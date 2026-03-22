# Audit: Governed Vocabulary Draft for "promotion"

**Auditor**: S2 (Intelligence, audit mode)
**Date**: 2026-03-18
**Subject**: `/Users/pepe/repos/aitools/.scratch/session-Z1IhGrcgGO/promotion-definition-draft.md`, Option 3 (recommended)

---

## 1. Quality Check Results

The definition under review (Option 3):

> "Advancing a tracked item from an evaluation stage to a permanent or
> enforced state after it meets criteria defined by the governing
> lifecycle. The transition is recorded in the item's registry (harvest
> manifest, tool-ops registry, hook enforcement table). Distinct from
> harvesting (entering evaluation) and pruning (leaving without
> advancement)."

| Criterion | Result | Notes |
|-----------|--------|-------|
| Names a specific deliverable (not "promotion is about...") | PASS | "Advancing a tracked item from X to Y" is concrete. |
| Uses active verbs | PASS | "Advancing," "meets," "recorded." |
| Concise / comparable to exemplars | PASS | 3 sentences, ~55 words. Comparable to "incident" (3 sentences, ~50 words). |
| Adds information beyond restated title | PASS | Specifies mechanism (criteria + registry recording), boundaries (not harvesting, not pruning). |
| Resolves the SPECIFIC ambiguity flagged (4 interpretations) | PARTIAL | See section 5 below. Resolves 3 of 4. The "change status in the manifest" interpretation is not clearly distinguished from "move file" -- the definition covers both under one umbrella without clarifying their relationship. |

**Quality check overall: PASS with one finding.**

---

## 2. Ambiguity Scan

### Pass 1 -- Undefined Terms

| Term | Governed? | Self-evident? | Finding |
|------|-----------|---------------|---------|
| tracked item | "tracked" is not governed; "item" is common English | Partially | "Tracked" is clear in isolation (something the system follows). But the draft earlier says "tracked item" covers artifacts, registry entries, and enforcement modes. These are quite different things. A fresh agent might not know a hook mode variable is a "tracked item." FINDING: "tracked item" is doing heavy lifting as an abstraction that unifies three dissimilar subjects. |
| evaluation stage | Neither word governed | Partially | What counts as an "evaluation stage" differs per domain: `harvested`/`candidate` status in harvest manifest vs. `audit` mode in tool-ops vs. `observe` mode in hooks. The definition does not enumerate these. A fresh agent encountering a tool-registry entry in "Under Evaluation" phase (meaning D) must infer this is an "evaluation stage." FINDING: acceptable if meaning D is covered; see barrier test. |
| permanent | Not governed | Yes | Clear in context. |
| enforced state | Not governed | Partially | "Enforced" maps clearly to hooks (enforce mode) and tool-ops (active mode). But "enforced" and "active" are different words. FINDING: minor -- the reader must know "active" = "enforced." |
| criteria | Not governed | Yes | Common English, correctly delegated to "the governing lifecycle." |
| governing lifecycle | "lifecycle" not governed | Partially | Each domain has its own lifecycle spec. "Governing" is clear (the lifecycle that owns this item). FINDING: acceptable -- the definition intentionally delegates specifics to the lifecycle. |
| registry | Governed | N/A | In glossary. |
| harvest manifest | Not governed | Partially | Specific artifact name. FINDING: see Pass 2. |
| tool-ops registry | Not governed | Partially | Specific artifact name. The actual file is `reference/tool-ops.json`. FINDING: see Pass 2. |
| hook enforcement table | Not governed | NO | **This artifact does not exist.** Hook modes are stored as shell variables (`MODE_AND`, `MODE_REST`, etc.) in the hook script itself, not in a table or registry. The hook-rollout rule (`.claude/rules/hook-rollout.md` lines 59-75) documents the mode variables inline. There is no "hook enforcement table" file. FINDING: FACTUAL ERROR. The parenthetical example names a nonexistent artifact. |
| harvesting | Not governed explicitly, but in glossary rule word list | Yes | Well-established in the harness. |
| pruning | Not governed | Yes | Defined by contrast in artifact-harvesting.md. |

**Pass 1 findings:**
1. FACTUAL ERROR: "hook enforcement table" does not exist as a named artifact
2. MINOR: "tracked item" abstracts over dissimilar subjects without guidance
3. MINOR: "enforced state" maps to "active" mode in tool-ops (different word)

### Pass 2 -- Terms with Multiple Meanings

| Term | Risk | Assessment |
|------|------|------------|
| "evaluation stage" | Could mean: harvest `harvested`/`candidate` status, tool-ops `audit` mode, hook `observe` mode, tool-registry "Under Evaluation" phase | MEDIUM -- the definition is intentionally abstract here, but a fresh agent may not connect "evaluation stage" to `observe` mode. The word "evaluation" does not appear in hook-rollout.md at all. |
| "permanent" | Could mean: permanent file location (artifact moved to reference/), permanent status (status field changed to "promoted"), permanent in the sense of "won't be pruned" | LOW -- context disambiguates. The "or enforced" alternative covers the non-permanence cases. |
| "registry" | Could mean: the three-layer registry pattern (rule+JSON+skill) or any JSON file that tracks state | LOW -- governed term, definition is clear. The parenthetical examples help. |
| "advancement" | Used once in "leaving without advancement." Could mean: file movement, status change, or mode escalation | LOW -- the definition establishes all three as forms of promotion. "Leaving without advancement" correctly covers all. |
| "governing lifecycle" | Could mean: the lifecycle that governs the item, or a lifecycle defined by a governance framework | LOW -- both readings lead to the same practical outcome (look up the lifecycle spec for the domain). |

**Pass 2 findings:**
1. MEDIUM: "evaluation stage" may not map obviously to hook `observe` mode. The word "evaluation" is not used in hook-rollout.md; it uses "observe" exclusively. A reader familiar only with hooks might not recognize observe mode as an "evaluation stage."

### Pass 3 -- Barrier Test

Reading ONLY the definition:

> "Advancing a tracked item from an evaluation stage to a permanent or
> enforced state after it meets criteria defined by the governing
> lifecycle. The transition is recorded in the item's registry (harvest
> manifest, tool-ops registry, hook enforcement table). Distinct from
> harvesting (entering evaluation) and pruning (leaving without
> advancement)."

**Test 1: Moving a script from `.scratch/` to `harvesting/` -- is this promotion?**

Applying the definition: The script moves from an ephemeral location to an evaluation stage. The distinction clause says "harvesting (entering evaluation)." This is entering evaluation, not leaving it. **Classification: NOT promotion.**

Expected: NO. **PASS.**

**Test 2: Moving a harvested script from `harvesting/` to `reference/` -- is this promotion?**

Applying the definition: The script is a tracked item (in the harvest manifest). It advances from the evaluation stage (`harvested`/`candidate` status) to a permanent state (`reference/` is a permanent harness location). The criteria are defined by the governing lifecycle (artifact-harvesting.md promotion criteria). The transition is recorded in the registry (harvest manifest `promotedTo` field). **Classification: YES, this is promotion.**

Expected: YES. **PASS.**

**Test 3: Changing a hook from observe to enforce mode -- is this promotion?**

Applying the definition: The hook check is a tracked item (mode variable in the script). It advances from an evaluation stage (observe mode) to an enforced state (enforce mode). Criteria are defined by the governing lifecycle (hook-rollout.md: zero false positives). The transition is recorded in the item's registry... wait. The definition says "hook enforcement table." No such table exists. The mode is changed by editing a shell variable in the hook script. Is the hook script a "registry"?

The governed definition of "registry" is: "A structured data store following the three-layer pattern: rule (intent, always in context), JSON (data, source of truth), skill (access layer)." A shell variable in a hook script is NOT a registry by this definition. It is not JSON, it does not have a skill access layer, and it is not a data store.

**Classification: AMBIGUOUS.** The action itself fits ("advancing from evaluation to enforced state"), but the "recorded in the item's registry" clause fails -- there is no registry for hook modes. The recording mechanism is a variable change in a shell script, which is not a registry.

Expected: YES. **PARTIAL PASS.** The barrier is the nonexistent "hook enforcement table" and the mismatch between hook mode storage (shell variables) and the definition's requirement of a registry.

**Test 4: An agent reading `glossary.json` directly instead of using /glossary skill -- is this promotion?**

Applying the definition: This is an access pattern, not a lifecycle transition. No "tracked item" is advancing between stages. **Classification: NOT promotion.**

Expected: NO. **PASS.**

**Test 5: A user flagging a harvested artifact as "keep" -- is this promotion?**

Applying the definition: The artifact remains in the evaluation stage. Flagging "keep" prevents pruning but does not advance the item to a permanent or enforced state. The `keepFlag` field in the manifest changes, but the `status` does not advance past `candidate`. No transition to a new lifecycle stage occurs. **Classification: NOT promotion.**

Expected: NO. **PASS.**

**Barrier test overall: 4/5 PASS, 1 PARTIAL PASS.**

The partial pass on test 3 is caused by the "hook enforcement table" error and the definition's requirement that transitions be "recorded in the item's registry." Hook mode changes are recorded in shell variables, not registries.

---

## 3. Exemplar Comparison

### Structure comparison

| Aspect | Exemplar pattern | Draft (Option 3) | Match? |
|--------|-----------------|-------------------|--------|
| Core definition | One sentence | One sentence ("Advancing...lifecycle.") | YES |
| Mechanism/detail | One sentence with specifics | One sentence ("The transition is recorded...") | YES |
| Distinction/boundary | Inline or enumerated | One sentence ("Distinct from...") | YES |
| Total length | 2-3 sentences | 3 sentences | YES |

### Length comparison

| Term | Words |
|------|-------|
| "incident" (exemplar) | ~48 |
| "file classification" (exemplar) | ~30 |
| "governed vocabulary" (exemplar) | ~38 |
| "promotion" (draft) | ~55 |

Slightly longer than average but within range. The parenthetical registry examples add ~10 words. Acceptable.

### Specificity comparison

| Aspect | Exemplars | Draft | Assessment |
|--------|-----------|-------|------------|
| Enumerates possible values/types | "incident": severity levels, lifecycle states; "file classification": three tiers | Registry names in parenthetical | Comparable |
| Names implementing artifacts | "governed vocabulary": "glossary rule, JSON, and skill" | "harvest manifest, tool-ops registry, hook enforcement table" | Comparable, BUT one artifact ("hook enforcement table") is fictional |
| Source discipline | "governed vocabulary" includes it; "incident" does not | Not included | Acceptable -- promotion is a harness-native concept, not adopted from an external discipline |

### Source field

The draft proposes `"source": ".claude/rules/artifact-harvesting.md"`. This is the most prominent user of "promotion" in the harness. However, this source file only covers meaning A (artifact lifecycle). Meanings B (tool-ops), C (hooks), and D (tool lifecycle) have different source files. For a unified definition covering all four, the source should arguably point to whatever harness artifact is most authoritative for the general concept.

FINDING: The source field is defensible (artifact harvesting is where the concept is most prominent and where the user ratified its usage), but a note acknowledging the other domains would be more honest. Alternatively, the source could point to a future cross-reference or to CLAUDE.md design principles. This is a minor issue -- other governed terms (e.g., "registry") also have a single source despite being used broadly.

### Exemplar comparison overall: PASS with one finding (fictional registry name).

---

## 4. Single Term vs Split Assessment

The draft recommends keeping "promotion" as a single unified term. Evaluation:

### Can the unified definition cover all 5 meanings without ambiguity?

| Meaning | Covered by definition? | Clear to a fresh agent? |
|---------|----------------------|------------------------|
| A: Artifact lifecycle (harvesting -> reference) | YES -- "permanent state" + "harvest manifest" | YES |
| B: Tool-ops mode (audit -> active) | YES -- "enforced state" + "tool-ops registry" | MOSTLY -- "enforced" maps to "active" indirectly |
| C: Hook mode (observe -> enforce) | PARTIALLY -- "enforced state" fits, but registry clause fails | NO -- "hook enforcement table" is fictional; hook modes are not stored in a registry |
| D: Tool lifecycle (evaluating -> approved) | PARTIALLY -- "evaluation stage to permanent state" fits conceptually | MAYBE -- tool-registry entries don't use "promoted" status; they restructure from "Under Evaluation" to full entry |
| E: Conceptual (tactical -> strategic) | YES -- the definition IS the generalization of E | YES |

### Would separate terms be clearer?

Splitting into "artifact promotion" and "mode promotion" (or "enforcement promotion") would:
- PRO: Allow meaning C to have its own definition that accurately describes the shell-variable mechanism instead of a nonexistent registry
- PRO: Allow meaning D to address the "restructure entry" mechanism distinct from "change status field"
- CON: Add 2+ governed terms for what IS conceptually one operation
- CON: User signals overwhelmingly favor a single "promote" verb

### Assessment

The unified approach is conceptually correct -- all four meanings share the pattern "item passes criteria, advances stage." However, the definition's MECHANISM clause ("recorded in the item's registry") does not accurately describe meanings C and D. Hook modes are not registries. Tool-registry entries are not "promoted" -- they are restructured.

**Recommendation: Keep as single term, but fix the mechanism clause.** The parenthetical examples are the problem, not the abstraction. Replace "hook enforcement table" with something accurate (e.g., "hook mode variables" or simply drop the third example). The definition works when the mechanism clause is correct.

---

## 5. Blocker Resolution Assessment

The ambiguity audit said: "promotion used 14+ times with four different interpretations -- move file, change status, upgrade tier, make permanent."

### Does this definition resolve each interpretation?

| Interpretation | Resolved? | How |
|----------------|-----------|-----|
| Move file (artifact from harvesting/ to reference/) | YES | "Advancing...to a permanent...state" covers physical relocation |
| Change status (manifest status: harvested -> candidate -> promoted) | YES | "The transition is recorded in the item's registry" covers status field changes |
| Upgrade tier (audit -> active, observe -> enforce) | PARTIALLY | "to...enforced state" covers the outcome, but the registry clause fails for hooks |
| Make permanent (general concept) | YES | "permanent or enforced state" directly addresses this |

### Would Q4 be unambiguous with this definition?

Reading Q4's 14+ uses of "promotion" against this definition:

- Lines 61, 76, 107 ("Promotion path: scratch -> harvesting -> reference"): YES, unambiguous -- this is advancing to a permanent state.
- Lines 72-76 ("promoted to reference/"): YES -- clear instance of artifact promotion.
- Line 331 ("Each arrow is a promotion gate"): MOSTLY -- the definition covers this as "meets criteria defined by the governing lifecycle." However, Q4's line 332 says "scratch -> harvesting" is a promotion gate. The definition says this is NOT promotion (it is harvesting = "entering evaluation"). Q4's own usage contradicts the definition here.

FINDING: Q4 line 332 calls the scratch-to-harvesting transition a "promotion gate." The definition explicitly excludes this ("Distinct from harvesting (entering evaluation)"). If this definition is adopted, Q4 line 332 must be corrected to say "harvesting gate" or "lifecycle gate," not "promotion gate." This is not a definition failure -- it is a Q4 usage that the definition correctly disallows.

### Blocker resolution overall: MOSTLY RESOLVED.

The definition resolves the core ambiguity (what does "promotion" mean?). It correctly unifies the four interpretations under one concept while distinguishing promotion from harvesting and pruning. The remaining issues are:
1. The mechanism clause has a factual error ("hook enforcement table")
2. The "evaluation stage" framing may not map obviously to hook observe mode
3. Q4 itself has one usage (line 332) that the definition disallows

---

## 6. Additional Findings

### 6.1 Missing meaning D in barrier tests

The draft's own barrier tests (section 6) cover meanings A (test 1, 2), C (test 2 in draft), and a non-promotion case (test 3). They do not test meaning D (tool lifecycle: evaluating -> approved). The draft's barrier tests are incomplete.

Applying the definition to meaning D: A tool-registry entry moves from "Under Evaluation" to a full entry. Is this "advancing a tracked item from an evaluation stage to a permanent or enforced state"? Conceptually yes -- "Under Evaluation" is an evaluation stage and a "full entry" is a permanent state. But the mechanism differs: the entry is not "promoted" in the tool-registry (there is no `promotedTo` field, no `promoted` status). The entry is restructured -- fields are filled in, the "Under Evaluation" heading is removed, and the entry joins the main section. Is restructuring "promotion"? The definition does not address this variant.

### 6.2 Source field scope

The `source` field points to `.claude/rules/artifact-harvesting.md`. This file governs meaning A only. For a unified definition, this source is misleading -- it suggests the definition is scoped to artifact harvesting. The most honest source would be the glossary definition itself (self-referential, which is not the convention) or a cross-cutting file. Since artifact harvesting is the primary use, this is defensible but worth noting.

---

## 7. Overall Verdict

**APPROVE WITH AMENDMENTS.**

The definition is well-structured, concisely written, calibrated to exemplars, and resolves the core ambiguity that blocked Q4. The concept of a single unified term is correct. Three amendments are required:

### Required amendments

1. **Fix "hook enforcement table"** -- This artifact does not exist. Hook modes are stored as shell variables in hook scripts (`MODE_AND`, `MODE_REST`, etc.), governed by `.claude/rules/hook-rollout.md`. Replace the parenthetical example. Suggested fix: change `(harvest manifest, tool-ops registry, hook enforcement table)` to `(harvest manifest, tool-ops registry, hook mode variables)` or simply `(harvest manifest, tool-ops registry)` if the goal is to name only actual registries.

2. **Weaken or remove the "recorded in the item's registry" requirement** -- Hook mode changes are recorded in shell variables, not registries. Tool-lifecycle phase transitions are recorded by entry restructuring, not by a `status` field. The requirement that the transition be "recorded in the item's registry" is accurate for meaning A and B but not for C and D. Suggested fix: change "recorded in the item's registry" to "recorded in the item's governing artifact" (broader) or "tracked by the governing lifecycle" (delegates to each domain's spec).

3. **Add meaning D (tool lifecycle) to barrier tests** before finalizing -- The draft's barrier tests omit this case entirely. This should be tested to confirm the definition covers it.

### Optional improvements

- Consider whether "evaluation stage" is sufficiently clear for hooks, where the word "evaluation" never appears in hook-rollout.md. The hook documentation uses "observe" exclusively. A reader familiar only with hooks may not recognize observe mode as an "evaluation stage."
- The draft notes Q4 line 332 uses "promotion gate" for the scratch-to-harvesting transition. If the definition is adopted, flag this as a Q4 correction needed.
