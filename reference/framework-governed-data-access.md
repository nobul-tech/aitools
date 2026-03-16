# Governed Data Access

**Intent**: **Purpose**: Document the source disciplines, adoption
rationale, and design patterns behind skill-gated access to governed
registries. **Scope**: Why we adopted capability-based security,
document control, and information hiding — and how they map to our
harness. NOT the operational rules (see
`@.claude/rules/governed-data-access.md`). NOT which registries
exist (see `@.claude/rules/frameworks.md` registries table).
**Audience**: Agents designing new registries, agents building
detection hooks, framework adoption work.

## Source Disciplines

This framework adopts concepts from three established disciplines:

### Information security

**Capability-based security** (Dennis & Van Horn, 1966): A capability
is an unforgeable token that grants specific access AND defines what
operations are permitted. In our harness: a loaded skill IS the
capability. Having a governing skill loaded grants access to the
registry AND provides the governed process. Without the skill — no
capability, no governed access.

**Principle of least privilege** (Saltzer & Schroeder, 1975): Each
agent gets only the access needed for its role. Agents without the
governing context should not access governed data directly.

### Quality management

**Document control** (ISO 9001 §7.5): Controlled documents require
identification (which files are controlled), controlled distribution
(access at point of use, not freely advertised), and approval before
modification. In our harness: governed files are identified (file
classification), distributed through skills (controlled distribution),
and writes require the skill's process (approval).

### Software engineering

**Information hiding** (Parnas, 1972): Modules expose interfaces and
hide implementation details. In our harness: skills expose the
governed process (interface), JSON registries are the implementation
detail (hidden behind the skill).

**Encapsulation**: Data accessible only through methods. The skill IS
the method; the JSON IS the private data.

## How We Adopted It

### File classification

Every file in the harness has an access tier:

| Tier | Read | Write | Enforcement | Examples |
|------|------|-------|-------------|---------|
| **Open** | Any agent | Any agent | None | Code, scripts, scratch files |
| **Protected** | Any agent | Human review required | Source-of-truth rule | CLAUDE.md, rules, plans, reference files |
| **Governed** | Through governing skill | Through governing skill | Skill = capability | JSON registries accessed via their skills |

Protected and governed are not mutually exclusive. Governed files are
also protected (they appear in the protected files list). Governed
adds skill-gated process enforcement on top of human review.

### Skill-as-capability pattern

A loaded skill grants access to governed data AND provides the process
for interacting with it. The capability unifies access and authority:

| Component | Role |
|-----------|------|
| Skill (SKILL.md) | The capability — grants access + defines process |
| JSON registry | Private data — implementation detail behind the skill |
| Rule (trigger directive) | Access policy — states when to invoke the skill |
| Hook (detection) | Enforcement — fires when governed data accessed directly |

Without the skill loaded, the agent has no governed process. With the
skill loaded, access and process are inseparable.

### Controlled distribution

Rules and documentation reference skills, not raw file paths. The
skill is the only documented entry point to governed data:

- **Do**: "Definitions: `/glossary` skill"
- **Don't**: reference governed data file paths in rules or docs

The `@reference/` syntax resolves at load time and pulls file content
into context — this gives agents the data without the process.
Referencing the skill instead routes access through the governed
process.

Files remain discoverable via filesystem tools (Glob, Grep). Controlled
distribution changes the default path, not physical access. The
detection layer (hooks) catches direct access that bypasses the skill.

### Three-layer enforcement

Every governed registry has three enforcement layers:

| Layer | Mechanism | What it catches |
|-------|-----------|----------------|
| Prevention | Trigger directive in rule + governed-data-access rule | Agent reads rule, knows to invoke skill. Always in context. |
| Detection | PreToolUse hook on Read/Edit + pre-commit step 16 | Agent accesses governed data directly — hook injects reminder, pre-commit blocks commit. |
| Telemetry | KPI: governed data access without skill invocation | Measures whether prevention and detection are working. |

A governed registry without all three layers has gaps:
- Prevention only = suggestion (agent can ignore)
- Prevention + detection = enforced (agent is reminded)
- Prevention + detection + telemetry = governed (effectiveness is measured)

## How It's Maintained

- `@.claude/rules/governed-data-access.md` enforces the access principle
- Pre-commit step 16 catches capability bypasses at commit time
- The registries table in `@.claude/rules/frameworks.md` lists all
  governed registries and their skills
- New governed registries: use `/governed-data` skill

## Implementing Artifacts

- `@.claude/rules/governed-data-access.md` (operational rule)
- `@.claude/rules/frameworks.md` (registries table)
- Trigger directives in governing rules (glossary.md, incident-governance.md,
  frameworks.md, tool-evaluation.md)
- `scripts/check-pre-commit.sh/.ps1` step 16 (capability bypass audit)

## Cross-References

- Operational rule: `@.claude/rules/governed-data-access.md`
- Registries table: `@.claude/rules/frameworks.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Framework registry: `/frameworks` skill
- Glossary terms: `file classification`, `skill-as-capability`,
  `controlled distribution`
- Harness architecture: `@reference/harness.md`
