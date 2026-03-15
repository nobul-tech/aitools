# Governed Data Access

**Intent**: **Purpose**: Document the governed data access framework
— how governed files (JSON registries) are accessed only through
their governing skills, and the three-layer enforcement pattern
(prevention, detection, telemetry). **Scope**: File classification
tiers, skill-as-capability pattern, controlled distribution,
enforcement mechanisms, and source discipline credits. NOT the
individual skill processes (those are in the skill SKILL.md files).
NOT the deployment state machine (see
`@reference/managed-file-deployment.md`). **Audience**: Agents
designing new registries, agents building detection hooks, `/audit`
skill verifying three-layer completeness.

## Source Disciplines

This framework adopts concepts from three established disciplines:

### Information security

**Capability-based security** (Dennis & Van Horn, 1966): A capability
is an unforgeable token that grants specific access AND defines what
operations are permitted. In our harness: a loaded skill IS the
capability. Having `/gap` loaded grants access to `known-gaps.json`
AND provides the governed process. Without the skill — no capability,
no governed access.

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
governed process (interface), JSON files are the implementation
detail (hidden behind the skill).

**Encapsulation**: Data accessible only through methods. The skill IS
the method; the JSON IS the private data.

## File Classification

Every file in the harness has an access tier:

| Tier | Read | Write | Enforcement | Examples |
|------|------|-------|-------------|---------|
| **Open** | Any agent | Any agent | None | Code, scripts, scratch files |
| **Protected** | Any agent | Human review required | Source-of-truth rule | CLAUDE.md, rules, plans, reference files |
| **Governed** | Through governing skill | Through governing skill | Skill = capability | `known-gaps.json`, `glossary.json`, `framework-registry.json` |

Protected and governed are not mutually exclusive. Governed files are
also protected (they appear in the protected files list). Governed
adds skill-gated process enforcement on top of human review.

## Skill-as-Capability Pattern

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

## Controlled Distribution

Rules and documentation reference skills, not raw file paths. The
skill is the only documented entry point to governed data:

- **Do**: "Definitions: `/glossary` skill"
- **Don't**: "Definitions: `@reference/glossary.json`"

The `@reference/` syntax resolves at load time and pulls file content
into context — this gives agents the data without the process.
Referencing the skill instead routes access through the governed
process.

Files remain discoverable via filesystem tools (Glob, Grep). Controlled
distribution changes the default path, not physical access. The
detection layer (hooks) catches direct access that bypasses the skill.

## Three-Layer Enforcement

Every governed file has three enforcement layers:

| Layer | Mechanism | What it catches |
|-------|-----------|----------------|
| Prevention | Trigger directive in rule | Agent reads rule, knows to invoke skill. Always in context. |
| Detection | PreToolUse hook on Read/Edit | Agent accesses governed file directly — hook injects process reminder or logs bypass. |
| Telemetry | KPI: governed file access without skill invocation | Measures whether prevention and detection are working. Ships to Datadog. |

A governed file without all three layers has gaps:
- Prevention only = suggestion (agent can ignore)
- Prevention + detection = enforced (agent is reminded)
- Prevention + detection + telemetry = governed (effectiveness is measured)

### Current coverage

| Governed file | Prevention | Detection | Telemetry |
|--------------|-----------|-----------|-----------|
| `known-gaps.json` | `/gap` trigger in gap-governance.md ✓ | Planned | Planned |
| `glossary.json` | `/glossary` trigger in glossary.md ✓ | Planned | Planned |
| `framework-registry.json` | `/frameworks` trigger in frameworks.md ✓ | Planned | Planned |

### Detection hook pattern

PreToolUse command hook (exit 0, observe only) on Read/Edit/Write/Grep.
When `file_path` or `path` matches a governed file:

1. Inject governing process via `additionalContext` (prompt injection)
2. Log event to telemetry: `event_type=governed_file_access`,
   `tool_name`, governed file, governing skill
3. Do NOT block — the skill also uses Read, and hooks cannot
   distinguish skill reads from direct reads

The standing-order-guard (PreToolUse on Bash) additionally checks for
governed file paths in bash commands (`cat`, `jq`, `node -e`, etc.)
to prevent Bash tool bypass.

### Telemetry KPIs

| KPI | Metric | What it tells you |
|-----|--------|-------------------|
| Governance compliance rate | Skill invocations / governed file accesses | Are agents using skills or bypassing them? |
| Bypass rate by file | Direct accesses per governed file | Which files are most bypassed? |
| Prevention effectiveness | Compliance rate delta after trigger directives | Did the rule fix work? |
| Time-to-correction | Time between direct access and skill invocation | Do agents self-correct? |

## Adding a New Governed File

When creating a new JSON registry:

1. **Create the skill** — the governed process for reading and writing
2. **Add trigger directive** to the governing rule — when to invoke
3. **Design the detection hook spec** — what to detect on direct access
4. **Register in this framework** — add to the coverage table above
5. **Apply controlled distribution** — reference the skill, not the
   file path, in rules and documentation

All five artifacts are created together. A governed file without its
skill is ungoverned data. A skill without its trigger directive is
ungoverned process.

## Cross-References

- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Framework registry: `/frameworks` skill
- Glossary terms: `file classification`, `governed file`,
  `skill-as-capability`, `controlled distribution`
- Gap governance: `@.claude/rules/gap-governance.md`
- Managed file deployment: `@reference/managed-file-deployment.md`
- Harness architecture: `@reference/harness.md`
