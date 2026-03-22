# Artifact Roles Tension Investigation

## S2 Intelligence Report — 2026-03-18

## 1. The Tension

Two artifacts produced in the v0.62.2 session (2026-03-17) contradict each other:

**`reference/harness.md`** (committed) references a `/artifact-roles` skill
at two locations:
- Line 10-11 (intent scope exclusion): "NOT artifact roles ... (see `/artifact-roles` skill)"
- Line 71 (cross-references): "Artifact roles: `/artifact-roles` skill"

**Q10 investigation** (`.scratch/session-Z1IhGrcgGO/q10-artifact-roles-investigation.md`)
recommended **Option C: NO dedicated `/artifact-roles` skill**. Instead: enrich
the existing `/governed-data` skill with full role definitions, add a lean
`artifact-roles.md` rule (that triggers `/governed-data`, not a dedicated skill),
and build an `artifact-role-guard.sh` enforcement hook.

The committed `harness.md` promises a skill the session's own investigation
says should not exist.

### How the tension arose

The user initially proposed a standalone artifact-roles rule. The agent drafted
it, but the user caught that the rule itself violated the artifact-roles principle
— it contained process content (role definitions) that belongs in a skill.
The user said: "lolol that kind of contradicts our own definition of rules."

This led to the Q10 investigation about where artifact-role definitions belong.
Q10 concluded they belong in the existing `/governed-data` skill (which already
has a "Content placement standard" section). But `harness.md` was already
committed with `/artifact-roles` skill references — likely written before
Q10 reached its conclusion.

---

## 2. Three Options

### Option 1: Create `/artifact-roles` as its own skill

Honor what `harness.md` promises. Override Q10's recommendation. Build:
- `.claude/rules/artifact-roles.md` — lean rule with governing principle and trigger
- `.claude/skills/artifact-roles/SKILL.md` — full role definitions, content placement
  decision tree, the "what goes where" process
- `reference/framework-artifact-roles.md` — source discipline, adoption rationale
- `shared/hooks/artifact-role-guard.sh` — detection layer

**Pros:**
- Resolves the tension by making `harness.md` truthful — the skill exists
- Follows the user's principle: "the skill is the capability-based gate access
  control mechanism for artifacts, definitions, what goes where"
- Clean three-layer governance: dedicated rule, dedicated skill, dedicated hook
- Artifact roles are conceptually big enough — they govern ALL five artifact
  types. That is a broader scope than governed-data (which governs registries)
- No scope creep in `/governed-data` — it stays focused on registry access

**Cons:**
- Q10's analysis found significant overlap with `/governed-data`'s existing
  "Content placement standard" section — that content would need to move
  or be deduplicated
- Q10 noted that a skill without a registry is unusual in this harness (most
  skills gate access to governed JSON data; artifact roles have no JSON registry)
- Creates a new rule always in context (~30-80 lines of context cost)
- Q10 flagged the irony: the agent writing the artifact-roles rule is at risk
  of putting process content in it — the exact failure mode artifact-roles
  is designed to prevent
- The existing content placement standard in `/governed-data` becomes orphaned
  or duplicated

**Works with standalone rule?** Yes — the rule triggers `/artifact-roles` directly.

---

### Option 2: Follow Q10 — enrich `/governed-data`, no dedicated skill

Follow Q10's recommendation. Update `harness.md` to remove `/artifact-roles`
references and point to `/governed-data` content placement instead. Build:
- `.claude/rules/artifact-roles.md` — lean rule, but its trigger directive
  points to `/governed-data` (not a skill that doesn't exist)
- Enriched "Content placement standard" in `/governed-data` skill — expand
  from the current ~15-line section to include full role definitions for all
  five artifact types (MUST contain, MUST NOT contain, enforcement signals)
- `reference/framework-artifact-roles.md` — source discipline, rationale
- `shared/hooks/artifact-role-guard.sh` — detection layer (same as Option 1)

Changes to `harness.md`:
- Line 10-11: "NOT artifact roles ... (see `/governed-data` skill, content
  placement standard)"
- Line 71: "Artifact roles: `/governed-data` skill (content placement standard)"

**Pros:**
- Resolves the tension cleanly — `harness.md` no longer promises a nonexistent skill
- Follows Q10's full analysis, which examined barrier prevention, overlap, and
  the original failure mode
- Zero new skills — no new context cost for skill loading
- Builds on existing infrastructure — `/governed-data` already owns content
  placement; this deepens what's already there
- The hook provides the detection layer that Q10 identified as the real gap

**Cons:**
- `/governed-data` grows significantly. It already has four concerns: access
  principle implementation, adding registries, auditing compliance, content
  placement. Adding full five-type role definitions makes it the largest skill
  in the harness. Q10 itself flagged: "the governed-data skill grows larger
  (it's already the most conceptually loaded skill)"
- Scope mismatch: governed-data-access is about registry access (one artifact
  type). Artifact roles govern ALL five types. The child (registry access) hosts
  the parent concept (all artifact types). This is architecturally inverted
- The trigger path is indirect: agent reads `artifact-roles.md` rule → rule says
  "invoke `/governed-data`" → agent must find the content placement section within
  a skill whose name suggests it's about data access. Q10 flagged: "may not fire
  as reliably as a dedicated trigger"
- Contradicts the user's principle that the skill IS the capability-based gate.
  Under Option 2, the "gate" for artifact roles is a subsection of a skill
  primarily about something else
- Requires modifying a committed, protected file (`harness.md`) to fix the references

**Works with standalone rule?** Yes — the rule exists but triggers a different skill.

---

### Option 3: Hybrid — thin `/artifact-roles` skill delegating to `/governed-data`

Create `/artifact-roles` as a lightweight entry-point skill that serves as the
"front door" for artifact-role questions but delegates to `/governed-data` for
the actual definitions. Build:
- `.claude/rules/artifact-roles.md` — lean rule triggering `/artifact-roles`
- `.claude/skills/artifact-roles/SKILL.md` — thin skill (~40 lines) that:
  (a) states intent, (b) provides a quick-reference table of the five types,
  (c) delegates to `/governed-data` for full role definitions and content
  placement process
- Full role definitions live in the enriched `/governed-data` content
  placement standard
- `reference/framework-artifact-roles.md` — source discipline, rationale
- `shared/hooks/artifact-role-guard.sh` — detection layer

**Pros:**
- Resolves the tension — `harness.md`'s `/artifact-roles` references are truthful
- The skill exists as a real entry point, not just a subsection
- Avoids duplicating the full role definitions in two places — `/artifact-roles`
  is a router, `/governed-data` holds the substance
- Follows the user's gating principle — `/artifact-roles` IS the capability gate;
  it just happens to delegate
- Low context cost — the thin skill loads only ~40 lines

**Cons:**
- Creates a delegation pattern not seen elsewhere in the harness — every other
  skill owns its content directly. A skill that says "go load another skill"
  adds a hop that agents may or may not follow
- Doesn't fully resolve the scope concern: `/governed-data` still grows with
  the full role definitions
- Two skills partially responsible for the same domain — agents may get confused
  about which one to actually use
- The delegation itself is fragile: if an agent loads `/artifact-roles` and
  finds a quick-reference table, it may use the quick reference and skip loading
  `/governed-data` for the full definitions — defeating the purpose
- Neither fish nor fowl: if artifact roles are big enough for their own skill,
  give them their own skill fully. If they're not, don't create one at all

**Works with standalone rule?** Yes — rule triggers `/artifact-roles`, which
delegates.

---

## 3. Preliminary Recommendation

**Option 1: Create `/artifact-roles` as its own skill.**

The reasoning:

### The scope argument is decisive

Artifact roles govern ALL five artifact types — rules, skills, reference files,
registries, and hooks. Governed data access governs ONE type (registries).
Embedding the broader concept inside the narrower one is architecturally
inverted. Q10 identified this weakness but underweighted it.

### The user's principle points to Option 1

The user said: "the skill is the capability-based gate access control mechanism
for artifacts, definitions, what goes where." This describes a dedicated
capability, not a subsection of another skill. When the user says "the skill
is the gate," they mean a skill that IS the gate — not a subsection of a
skill that also does three other things.

### The "no registry" concern is surmountable

Q10 noted that a skill without a governed JSON registry is unusual. But not
every skill needs a registry. `/intent-writing`, `/intent-audit`, `/audit`,
`/harvest`, `/scratch` — several skills provide process capabilities without
gating a JSON file. Artifact roles define stable knowledge (the five types
and their boundaries) that can live directly in the skill. No registry needed.

### The overlap with `/governed-data` is resolvable

The current "Content placement standard" section in `/governed-data` (lines
22-40 of SKILL.md) is ~18 lines covering the three-layer pattern in brief.
Under Option 1:
- Move the full role definitions to `/artifact-roles`
- Reduce `/governed-data`'s content placement section to a cross-reference:
  "For content placement and artifact role definitions, see `/artifact-roles`"
- `/governed-data` stays focused on its core: governed registry access

This actually REDUCES `/governed-data`'s scope rather than expanding it.

### The Q10 irony concern is manageable

Q10 warned that the agent writing the artifact-roles rule might put process
content in it — the exact failure mode. This is real but manageable: the rule
is lean (governing principle + trigger + cross-references, ~30 lines), and
the full Q10 report provides the detailed role definitions that go in the
skill, not the rule. The role definitions from Q10 Section 1 are the skill's
content.

### harness.md stays truthful

No need to modify a committed protected file. The references to `/artifact-roles`
are correct as written.

---

## 4. What S3 Needs to Decide

1. **Is the scope argument correct?** Artifact roles govern all five types;
   governed-data governs one. Does S3 agree this means artifact roles deserve
   their own skill rather than being a subsection of governed-data?

2. **What happens to `/governed-data`'s content placement section?** If
   Option 1 proceeds, the existing content placement standard (lines 22-40
   of `/governed-data` SKILL.md) needs to either:
   - Move entirely to `/artifact-roles` (clean but removes existing content
     from an established skill)
   - Shrink to a cross-reference (keeps the section header as a redirect)
   - Stay as-is alongside `/artifact-roles` (creates duplication — not
     recommended)

3. **Priority and sequencing.** The Q10 report identified four artifacts
   to build. What is the build order and does this block other v0.62.2 work?

4. **The lean rule.** Q10's recommended rule content (Section 4, ~30 lines)
   is the right starting point for `.claude/rules/artifact-roles.md`. But
   the trigger directive changes depending on the option:
   - Option 1: "Invoke `/artifact-roles` when..."
   - Option 2: "Invoke `/governed-data` when..."
   - Which trigger?

5. **The hook.** All three options agree an `artifact-role-guard.sh` hook is
   needed (the detection layer). Is this approved to build regardless of which
   option wins? Q10 Section 4 "What the hook checks" provides the spec.
