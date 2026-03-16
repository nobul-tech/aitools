# Tool Operations

**Intent**: **Purpose**: Document the SRE-grounded discipline behind
tool-ops — why per-tool operational metadata exists, how
observe-to-enforce graduation works, and how tool-ops connects to
the broader harness. **Scope**: Discipline source, adoption rationale,
and maintenance guidance. NOT the ops data (`/tool-ops` skill). NOT
the governance principle (`.claude/rules/tool-ops.md`). **Audience**:
Agents understanding why tool-ops exists, harness architects extending
the framework.

## Source Discipline

Three disciplines converge:

- **SRE operational readiness** — production services maintain runbooks
  with dependency maps, alerting rules, and verification procedures.
  Tools with deep harness integration need the same: deny rules, hook
  specifications, context injection patterns, and verification specs.
- **Hook-rollout observe-to-enforce** — from release engineering's
  canary deployment pattern. New operational metadata starts in audit
  mode (logged, not enforced), graduates to active after zero-drift
  verification. This prevents untested governance from breaking
  sessions.
- **Lean pull systems** — entries are created on demand when a tool
  earns deep integration, not speculatively for every managed tool.
  Most tools need only a tool-registry entry. Tool-ops entries exist
  only when operational complexity justifies them.

## How We Adopted It

- **Operational readiness** -> per-tool ops references
  (`reference/tool-ops-*.md`) that consolidate scattered operational
  knowledge — deny rules, hooks, context injection, KPIs, version
  dependencies — into a single governed location per tool.
- **Observe-then-enforce** -> governance modes in `tool-ops.json`.
  Each metadata category (denyRules, hooks, contextInjection, kpis,
  versionDeps, verifications) has its own mode: `audit` (logged,
  advisory) or `active` (enforced, blocking). Categories promote
  independently based on zero-drift evidence.
- **Pull systems** -> tool-ops entries are created when a tool's
  operational complexity causes incidents, scattered knowledge, or
  repeated agent mistakes. Claude Code was the first entry — its deny
  rules, hooks, and version dependencies were scattered across
  multiple harness files before consolidation.

## How It's Maintained

- Governance modes tracked in `reference/tool-ops.json` per tool,
  per category
- SessionEnd hook (`tool-ops-session-audit.sh`) collects drift
  telemetry: did deny rules fire? Did hooks behave as specified?
  Did agents access docs via the correct method?
- Zero-drift across sessions promotes `audit` -> `active`
- Mode changes require `/tool-ops` skill (governed data access)
- New tools enter with all categories in `audit` mode

## Implementing Artifacts

- `.claude/rules/tool-ops.md` (governance rule — always in context)
- `.claude/skills/tool-ops/SKILL.md` (governed access to registry)
- `reference/tool-ops.json` (registry — per-tool metadata)
- `reference/tool-ops-*.md` (per-tool ops references — full detail)
- `shared/hooks/tool-ops-session-audit.sh` (SessionEnd drift telemetry)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Hook rollout (observe-to-enforce source): `@reference/framework-hook-rollout.md`
- Tool lifecycle (install/version tracking): `@reference/framework-tool-lifecycle.md`
- Governed data access (skill-gate pattern): `@reference/framework-governed-data-access.md`
