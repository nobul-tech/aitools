# Q10: Artifact Roles and Intent Enforcement

## Investigation Summary

How does the artifact-roles framework feed into intent enforcement hooks?
What are the roles of each artifact type, and how does knowing those roles
enable enforcement?

Investigated: `reference/harness.md`, `.claude/rules/governed-data-access.md`,
`.claude/rules/frameworks.md`, `reference/framework-three-layer-governance.md`,
`reference/framework-governed-data-access.md`, `reference/framework-adoption.md`,
`shared/hooks/standing-order-guard.sh`, `shared/hooks/glossary-skill-guard.sh`,
`shared/hooks/sh-file-fixup.sh`, `shared/hooks/surfacing-duty-stop.sh`,
`shared/hooks/tool-ops-session-audit.sh`, `.claude/skills/governed-data/SKILL.md`,
`shared/skills/intent-writing/SKILL.md`, `shared/skills/intent-audit/SKILL.md`,
`plans/governance-and-compliance-framework.md`.

---

## 1. Role Definitions for Each Artifact Type

### Rules (`.claude/rules/*.md`)

**What it IS**: Governance. A rule is a declaration that is always in context
and states what MUST or MUST NOT happen, the governing principle behind it, and
WHEN to invoke the corresponding skill. It is the prevention layer — the
agent reads it and knows the right way before issues are created.

**MUST contain**:
- Intent statement (`**Intent**: **Purpose**: ... **Scope**: ... **Audience**: ...`)
- Governing principle (the "why" — one or two sentences)
- Scope boundaries (what this rule covers and explicitly does NOT cover)
- Trigger directive ("Invoke /skill when ANY of these arise: ...")
- Cross-references to implementing artifacts (skill, reference file, hook)

**MUST NOT contain**:
- Process steps (how to do something — that belongs in a skill)
- Mutable data or state (that belongs in a registry JSON)
- JSON file paths to governed data (capability bypass vector — reference the skill)
- How-to guides, templates, or examples (that belongs in a reference file or skill)
- Definitions that could drift (e.g., a list of current registries with their paths)

**Relationship to other types**:
- Governs one or more skills (trigger directive)
- Points to reference files for depth (`@reference/...`)
- Specifies detection hook behavior (what the hook should catch)
- Never reads or writes registries directly

**Enforcement signal**: A rule containing process steps, JSON paths, or mutable
state is a role violation. A rule without a trigger directive for its skill is a
governance gap (ungoverned process exists). A rule with definitions that can drift
will diverge from the source of truth.

---

### Skills (`.claude/skills/*/SKILL.md`, `shared/skills/*/SKILL.md`)

**What it IS**: Process implementation. A skill is a capability that is loaded on
demand and provides the governed process for interacting with a domain. In the
capability-based security model, a loaded skill IS the capability — it grants
access and defines the operations permitted on governed data.

**MUST contain**:
- Intent section stating what the skill equips the agent to do
- The governed process (numbered steps, validation criteria, templates)
- When-to-use guidance (complements the rule's trigger directive)
- Cross-references to its governing rule and related artifacts

**MUST NOT contain**:
- Governance principles (that belongs in the rule — always in context)
- Mutable state or data snapshots (that belongs in a registry JSON)
- Deep rationale, provenance, or discipline documentation (that belongs in a
  reference file)
- Standing orders or MUST/MUST NOT requirements that should be always-in-context
  (those belong in rules)

**Relationship to other types**:
- Implements the process that a rule governs
- Is the ONLY non-programmatic artifact that may reference governed JSON file paths
- Points to its governing rule for authority
- Points to reference files for depth and rationale
- Read and write skills correspond to registries (e.g., `/incident` writes
  `incidents.json`, `/frameworks` reads `framework-registry.json`)

**Enforcement signal**: A skill containing governance principles (MUST/MUST NOT
at the harness level) is duplicating its rule. A skill containing rationale
paragraphs is duplicating its reference file. A skill with embedded state
(hardcoded lists, version numbers) will drift from the registry.

---

### Reference Files (`reference/*.md`, `reference/framework-*.md`)

**What it IS**: Deep documentation. A reference file describes WHAT was adopted
and WHY — source disciplines, adoption rationale, design patterns, provenance,
specifications, and examples. It is consulted on demand for depth.

**MUST contain**:
- Intent statement
- Source discipline identification (for framework references)
- Adoption rationale (why this approach, what alternatives exist)
- Implementing artifacts list (what rules, skills, hooks implement this)
- Cross-references to governing rules, skills, and other references

**MUST NOT contain**:
- Operational requirements (MUST/MUST NOT directives — those belong in rules)
- Operational procedures (step-by-step processes — those belong in skills)
- Mutable state or current-state snapshots (those belong in registries)
- Trigger directives (those belong in rules — always in context)

**Relationship to other types**:
- Provides depth behind rules (rules are lean; references are deep)
- Names concepts and points to rules/skills for requirements and processes
- Documents the "why" behind decisions that rules enforce
- Framework references (`framework-*.md`) bridge disciplines to harness artifacts

**Enforcement signal**: A reference file stating requirements ("MUST do X") is
duplicating the rule. A reference file containing step-by-step procedures is
duplicating the skill. Both create drift vectors — the requirement or process
can be updated in one place and not the other.

---

### Registries (`reference/*.json`)

**What it IS**: Governed state. A registry is a machine-readable JSON file that
holds the current state of a governed domain. It is the single source of truth
for its domain's data.

**MUST contain**:
- `meta` object with `governance` (path to governing rule), `intent`
  (purpose/scope/audience), and `lastUpdated`
- Schema-compliant entries (schema documented in governing rule or skill)

**MUST NOT contain**:
- Process documentation (that belongs in the governing skill)
- Governance principles (that belongs in the governing rule)
- Rationale or provenance (that belongs in reference files; per-entry reference
  files for complex entries)

**Relationship to other types**:
- Accessed exclusively through the governing skill (capability-based security)
- Schema defined in the governing rule or skill
- Protected by the source-of-truth review gate
- Validated by `/audit` for schema compliance and cross-reference integrity
- May have per-entry reference files (`reference/<concept>-*.md`) for entries
  with enough detail to stand alone

**Enforcement signal**: A registry whose JSON path appears in rules or reference
files is a capability bypass vector — agents will read it directly instead of
through the skill. A registry modified outside its governing skill process
bypasses validation. Pre-commit step 16 catches this.

---

### Hooks (`shared/hooks/*.sh`)

**What it IS**: Enforcement, automation, and context injection. A hook is a
script that fires in real-time during session events (PreToolUse, PostToolUse,
SessionStart, SessionEnd, Stop) to enforce rules, inject context, track KPIs,
or automate lifecycle tasks. It is the detection layer.

**MUST contain**:
- Header comment: name, purpose, hook contract (event, exit codes, timing)
- Referenced framework or rule it enforces
- Mode declarations for rollout (observe/enforce)
- Robust error handling (must never crash or hang)

**MUST NOT contain**:
- Governance principles (those belong in rules)
- Process documentation (those belong in skills)
- Deep rationale (those belong in reference files)
- Mutable configuration state (managed through deploy scripts, not hardcoded)

**Relationship to other types**:
- Enforces what rules declare (the detection layer backing the prevention layer)
- References skills in stderr messages to close the detection-to-prevention loop
  (hook fires, tells agent "use /skill instead")
- Validated by tool-ops session audit (contract tests at session end)
- Follows the observe-then-enforce rollout practice (`.claude/rules/hook-rollout.md`)

**Enforcement signal**: A hook is code — its role is the most clearly delineated
of all artifact types. The enforcement question for hooks is not about content
role (hooks already know what they are) but about what hooks can check in OTHER
artifact types.

---

## 2. How Roles Enable Enforcement (What Hooks Can Check)

The key insight: knowing what MUST and MUST NOT be in each artifact type creates
a set of machine-checkable heuristics. A hook does not need to understand
content semantically — it needs to detect structural signals that indicate
role violations.

### On Write/Edit to a Rule (`.claude/rules/*.md`)

A PreToolUse or PostToolUse hook can check for:

| Signal | Detection method | Indicates |
|--------|-----------------|-----------|
| JSON file path patterns | Regex: `reference/.*\.json` in non-cross-reference sections | Capability bypass — rule is advertising governed data |
| Process steps (numbered lists) | Regex: `^\d+\.\s` in the body (outside Cross-references) | Process content belongs in skill |
| Mutable data tables | Regex: tables with concrete current values | State belongs in registry |
| Missing trigger directive | Absence of "Invoke /", "invoke /", "invoke the /" | Governance gap — ungoverned process |
| Missing intent | Absence of `**Intent**:` | Every rule needs intent |

Limitation: distinguishing a "requirement list" (belongs in rule) from a
"process list" (belongs in skill) requires semantic understanding beyond
simple regex. A numbered list of MUST requirements is legitimate in a rule;
a numbered list of steps-to-follow is not. Heuristic: check for imperative
process verbs ("Run X", "Execute Y", "Create Z") vs declarative requirement
verbs ("MUST contain", "MUST NOT reference").

### On Write/Edit to a Skill (`.claude/skills/*/SKILL.md`)

| Signal | Detection method | Indicates |
|--------|-----------------|-----------|
| Governance language | Regex: `\bMUST\b`, `\bMUST NOT\b` in declarative context | Rule content leaking into skill |
| Standing-order patterns | Regex: `USO:`, `PSO:`, `Standing Order` | Governance belongs in rules |
| Principle statements | Heuristic: paragraphs with "governing principle" language | Rule content |

Limitation: skills legitimately contain MUST/MUST NOT when describing process
requirements (e.g., "entries MUST have these fields"). The distinction is
between harness-level governance ("all agents MUST invoke this skill") vs
process-level requirements ("the JSON entry MUST include an ID field"). This
is difficult to distinguish mechanically.

### On Write/Edit to a Reference File (`reference/*.md`)

| Signal | Detection method | Indicates |
|--------|-----------------|-----------|
| Requirement language | Regex: `\bMUST\b`, `\bMUST NOT\b` as standalone directives | Rule content leaking into reference |
| Numbered process steps | Regex: `^\d+\.\s` with imperative verbs | Skill content leaking into reference |
| Trigger directives | Regex: `[Ii]nvoke /\w+` as directives (not as cross-references) | Rule content |

Limitation: reference files legitimately describe what frameworks require as
part of documenting the discipline. The distinction is between documenting a
requirement ("ISO 9001 requires controlled distribution") and imposing one
("controlled distribution MUST be used"). Context-dependent — harder to automate.

### On Read of a Governed JSON File

Already implemented: `glossary-skill-guard.sh` demonstrates the pattern. On
Read/Grep of governed files, inject context reminding the agent to use the
governing skill.

### Cross-Artifact Consistency Check (Audit Layer)

Knowing the roles enables `/audit` and `/intent-audit` to check:
- Rules without trigger directives (governance gap)
- Skills without governing rules (ungoverned process)
- Reference files containing MUST requirements (role violation)
- Rules containing JSON file paths (capability bypass)
- Registry entries without governing skills (ungoverned data)

This is the existing `check-pre-commit.sh` step 16 scope, but generalized
to all five artifact types.

---

## 3. Barrier Analysis

### Option A: Separate `/artifact-roles` skill + rule + enforcement hook

**What it builds**:
- `.claude/rules/artifact-roles.md` — rule stating the governing principle
  (each artifact type has a defined role), trigger directive ("Invoke
  /artifact-roles when creating or auditing harness artifacts"), cross-references
- `.claude/skills/artifact-roles/SKILL.md` — the process for checking and
  applying artifact roles: role definitions, content placement decision tree,
  pre-write role check
- `reference/framework-artifact-roles.md` — source discipline (separation of
  concerns, document control), adoption rationale
- `shared/hooks/artifact-role-guard.sh` — PreToolUse on Write/Edit, checks
  target file path, applies role-specific heuristics, injects reminders or blocks

**Barrier: Does it prevent the original failure?**
The original failure: agent drafted a rule that contained process content (role
definitions, howtos). An artifact-role-guard hook on Write to `.claude/rules/`
could detect process signals (numbered steps, imperative verbs) and inject a
reminder: "Rules contain governance only — process steps belong in the skill."

Verdict: **Partial prevention.** The hook catches clear structural violations
(numbered process steps in a rule, JSON paths in a rule). It cannot catch
semantic violations (a principle that reads like a process, or a process
disguised as a principle). The prevention layer (rule always in context) is
the primary defense; the hook is backup.

**Strengths**:
- Clean separation: artifact roles get their own governed domain
- The skill becomes the single entry point for "what goes where?" questions
- The hook provides detection-layer enforcement
- Three-layer completeness: rule (prevention), hook (detection), audit (via
  `/intent-audit` enrichment)

**Weaknesses**:
- Yet another rule always in context (cost: ~60-80 lines of context in every session)
- Significant overlap with existing `/governed-data` skill (which already has a
  "Content placement standard" section defining reference vs rule vs skill)
- Significant overlap with `/intent-audit` skill (which already classifies
  "state in process", "process in state", "scope creep")
- The role definitions are stable knowledge — they do not need a registry
  (no JSON). A skill without a registry is unusual in this harness (most
  skills gate access to governed data)

**Risk**: The irony is real — creating a dedicated artifact-roles rule risks
exactly the failure mode described. The rule would need to be extremely lean
(governing principle + trigger only), with all definitions in the skill. If
the agent writing the rule is not disciplined about this, the rule itself
will contain the role definitions, violating its own purpose.

---

### Option B: Artifact roles embedded in `/intent-writing` and `/intent-audit`

**What it builds**:
- Extend `/intent-writing` with a "Role-appropriate content" section: before
  drafting intent, identify the artifact type and its role constraints
- Extend `/intent-audit` with artifact-role checking: when auditing a file,
  check not just "does content match intent?" but "does the content type match
  the artifact's role?"
- Add a brief "artifact roles" section to an existing rule (e.g., extend
  `governed-data-access.md` or `frameworks.md`) with the governing principle
  and trigger
- No separate hook — rely on existing prevention (rules in context + skills)
  and the audit layer (`/intent-audit`)

**Barrier: Does it prevent the original failure?**
The original failure happened during drafting — the agent was writing a rule
and included process content. `/intent-writing` fires when the agent is
writing intent statements, but the agent was not writing an intent statement
— it was writing the rule body. `/intent-audit` fires on demand, after the
fact. Neither provides real-time detection during Write operations.

Verdict: **Insufficient detection.** Prevention-only (rule in context +
enriched skills). No detection-layer enforcement. Relies entirely on the
agent remembering the roles while writing — which is exactly what failed
in the original incident.

**Strengths**:
- No new artifacts (reduces context cost)
- Leverages existing skills that already handle adjacent concerns
- Conceptually clean — artifact roles ARE part of intent (what should be in
  a file is defined by its role)

**Weaknesses**:
- No detection layer — the original failure would recur
- `/intent-writing` and `/intent-audit` are user-level skills
  (`shared/skills/`), not project-level. Artifact roles are harness-specific
  (aitools project). Embedding harness-specific definitions in user-level
  skills pollutes them
- Overloads two skills with a third concern (intent writing, intent auditing,
  AND artifact-role enforcement)

---

### Option C: Artifact roles as reference file, enforcement via existing hooks

**What it builds**:
- `reference/framework-artifact-roles.md` — comprehensive reference documenting
  roles, source discipline (separation of concerns), adoption rationale, the
  five artifact types and their role definitions
- Extend `standing-order-guard.sh` (or a new lightweight hook) with
  artifact-role checks on Write/Edit to harness file paths
- Add artifact-role awareness to the existing content placement standard in
  `/governed-data` skill
- Brief mention in an existing rule (governed-data-access or frameworks) as
  a cross-reference, not a standalone rule

**Barrier: Does it prevent the original failure?**
The hook provides detection. The reference file provides depth for the agent
when it needs to understand roles. The existing governed-data skill already
has the content placement standard — enriching it with explicit role
definitions strengthens prevention. The agent reads the governed-data-access
rule (always in context), which points to the skill, which has the placement
standard.

Verdict: **Adequate prevention + detection.** The content placement standard
in the governed-data skill is already in the right place conceptually — it
describes what goes where in the three-layer pattern. Enriching it with
explicit role definitions (rather than the current brief paragraph) adds
specificity. A lightweight hook on Write/Edit to `.claude/rules/` and
`reference/` paths provides the detection layer that Option B lacks.

**Strengths**:
- No new rule in context (zero context cost increase)
- Builds on the existing content placement standard (already approved,
  already in the right skill)
- Hook enforcement via extension of existing infrastructure
- Reference file provides depth without polluting always-in-context space
- Follows the pattern: "most governance is already in place — close the gap"

**Weaknesses**:
- No dedicated trigger directive ("Invoke /artifact-roles when..."). Instead,
  the trigger is the existing "Invoke /governed-data when discussing content
  placement standard" directive. This may not fire as reliably as a dedicated
  trigger
- The governed-data skill grows larger (it's already the most conceptually
  loaded skill)
- Artifact roles are arguably a bigger concept than a subsection of
  governed-data — they apply to ALL harness artifacts, not just governed
  registries

---

## 4. Recommended Decision

**Option C with one amendment from Option A: a lightweight standalone rule.**

The reasoning:

1. **Option B is eliminated** — no detection layer means the original failure
   recurs. Prevention-only for a failure that already happened once is
   insufficient.

2. **Between A and C**, the question is whether artifact roles deserve their
   own three-layer stack (rule + skill + hook + reference) or can be integrated
   into existing infrastructure.

3. **The content already exists in two places**: the governed-data skill's
   "Content placement standard" section and `/intent-audit`'s finding
   classifications ("state in process", "process in state", "scope creep").
   Creating a completely separate skill would fragment this.

4. **The hook is the real gap.** Neither the governed-data skill guard nor the
   standing-order-guard currently check for role violations on Write/Edit to
   harness files. That is the detection layer that needs building.

### Recommended architecture

| Layer | Artifact | What it does |
|-------|----------|-------------|
| Prevention | `.claude/rules/artifact-roles.md` (LEAN) | States the governing principle: each harness artifact type has a defined role. Lists the five types and their one-line role. Trigger: "Invoke /governed-data when checking content placement." Cross-refs only. ~30 lines total. |
| Prevention | Enriched content placement in `/governed-data` skill | Expand the existing "Content placement standard" section with full role definitions, MUST/MUST NOT boundaries, and a decision tree for "where does this content go?" |
| Detection | `shared/hooks/artifact-role-guard.sh` | PreToolUse on Write/Edit. Checks target path against harness file patterns. Applies role-specific heuristics. Observe mode first. |
| Audit | Enriched `/intent-audit` | Add artifact-role checking to the audit process: for each finding, also classify whether the content type matches the file's artifact role. |
| Depth | `reference/framework-artifact-roles.md` | Source discipline (separation of concerns, document control), adoption rationale, full role specifications, examples of violations and corrections. |

### Why a lean standalone rule and not just extending governed-data-access

The user's insight was precise: "it's not for general purpose code, it's for
our harness." Artifact roles govern ALL five artifact types — rules, skills,
reference files, registries, and hooks. Governed-data-access governs ONE type
(registries) with depth. The governed-data-access rule is the wrong parent
for a concept that is broader than its scope.

A standalone artifact-roles rule keeps the concept visible and discrete. But
it must be LEAN — the original failure was a rule containing process content.
The rule states: there are five artifact types, each has a role, here's the
principle, invoke /governed-data for the content placement process. That's it.

The skill that implements the process is `/governed-data` — it already owns
content placement. Enriching it with full role definitions is natural. No new
skill needed.

### What the hook checks

The `artifact-role-guard.sh` hook (PreToolUse on Write/Edit) would:

1. **Identify the target file's artifact type** from its path:
   - `.claude/rules/*.md` -> rule
   - `.claude/skills/*/SKILL.md` or `shared/skills/*/SKILL.md` -> skill
   - `reference/*.md` (non-framework) -> reference file
   - `reference/framework-*.md` -> framework reference
   - `reference/*.json` -> registry
   - `shared/hooks/*.sh` -> hook

2. **Apply role-specific heuristics** to the content being written:
   - Rule getting numbered process steps? -> "Process steps belong in the
     skill. Rules contain governance only."
   - Rule containing `reference/.*\.json` path? -> "JSON paths bypass the
     skill gate. Reference the skill instead."
   - Reference file containing standalone MUST directives? -> "Requirements
     belong in the governing rule."
   - Skill containing governance principle language? -> "Governance principles
     belong in the rule. Skills implement process."

3. **Start in observe mode** per hook-rollout.md. Log what would be flagged.
   Promote to enforce after reviewing the log for false positives.

4. **Stderr feedback** references the skill: "Check /governed-data content
   placement standard for what belongs in each artifact type."

### Key advantage

This architecture means the agent gets three shots at doing it right:
1. **Prevention**: reads the lean artifact-roles rule (always in context) and
   knows the principle
2. **Prevention**: loads /governed-data when doing content placement and gets
   the full role definitions
3. **Detection**: hook fires if the Write/Edit violates role boundaries,
   injecting a reminder before (PreToolUse) or after (PostToolUse)

The audit layer (`/intent-audit` enriched with role checking) catches anything
that slipped through both layers during on-demand review.
