# Tool Lifecycle

**Intent**: **Purpose**: Document the framework for evaluating,
approving, integrating, and deprecating managed tools. **Scope**: What
software asset management principles we adopted and why. NOT the
operational checklist (that's in `@.claude/rules/tool-lifecycle.md`).
NOT the tool data (that's in `@reference/tool-registry.md`).
**Audience**: Agents onboarding new tools, framework adoption work.

## Source Discipline

Software asset management — lifecycle phases, approval gates,
deprecation paths. Tools are assets with costs (maintenance, security
surface, PATH complexity) and benefits. The lifecycle gates cost
evaluation before committing to benefits.

## How We Adopted It

- **5-phase lifecycle** → Discovery, Evaluation, Approved, Integrated,
  Deprecated
- **Phase 2 gate** → hard stop requiring user approval before
  integration code. Prevents sunk-cost commitment.
- **Per-platform status** → tools approved on one platform may still
  be evaluating on another
- **Install method discovery** → verify upstream install commands via
  official docs before writing scripts
- **Tool registry** → `@reference/tool-registry.md` as single source
  of truth for install commands, platform status, versions

## How It's Maintained

- Onboarding checklist in `@.claude/rules/tool-lifecycle.md`
- Post-push checks verify tool command availability and version
- `@reference/tool-versions.json` tracks per-platform versions
- Install methods re-verified via Chrome DevTools skill when modifying
  setup scripts

## Implementing Artifacts

- `@.claude/rules/tool-lifecycle.md` (operational rule + checklist)
- `@reference/tool-evaluation-criteria.md` (evaluation framework)
- `@reference/tool-evaluation-playbook.md` (install discovery process)
- `@reference/tool-registry.md` (tool data)
- `@reference/tool-versions.json` (version manifest)
- `scripts/setup-*.sh/.ps1` (per-tool setup scripts)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
