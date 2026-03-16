---
name: tool-ops
description: Read and write per-tool operational metadata — governance modes, deny rules, hooks, context injection, KPIs, and verification specs
---

## Intent

**Purpose**: Governed access to tool-ops.json — read operational
metadata, update governance modes, manage per-tool entries.
**Scope**: CRUD operations on tool-ops.json only. NOT the governance
principle (`.claude/rules/tool-ops.md`). NOT the framework documentation
(`reference/framework-tool-ops.md`). NOT per-tool ops references.
**Audience**: Agents checking tool behavior, `/audit` skill validating
ops coverage, setup scripts reading governance modes.

## Reading tool ops

To look up a tool's operational metadata:

1. Read `reference/tool-ops.json`
2. Find the tool key under `tools` (e.g., `tools.claude-code`)
3. Return the requested section: `governanceModes`, `denyRules`,
   `hooks`, `contextInjection`, `kpis`, `verifications`, `docAccess`,
   or `verificationMethod`

If the tool has no entry, report that it has no ops metadata. Most
managed tools do not need an ops entry — only those with deep harness
integration (hooks, deny rules, context injection).

### Common lookups

- **Deny rules**: `tools.<name>.denyRules` — what permission patterns
  are blocked and why
- **Hooks**: `tools.<name>.hooks` — what hooks fire for this tool,
  their event/matcher/script/purpose
- **Doc access**: `tools.<name>.docAccess` — how to read this tool's
  documentation (e.g., chrome-devtools vs WebFetch)
- **Governance modes**: `tools.<name>.governanceModes` — per-category
  audit/active status
- **Verifications**: `tools.<name>.verifications` — how to test hooks
  and deny rules

## Updating tool ops

### Governance mode changes

Mode changes follow observe-to-enforce graduation:

1. **Evidence**: Show zero-drift telemetry (SessionEnd hook data or
   manual audit) for the category being promoted
2. **Read** current entry via this skill
3. **Draft** the mode change: `"audit"` -> `"active"`
4. **Present** for user review (protected file gate)
5. **Write** if approved
6. Update `meta.lastUpdated`

Mode demotion (`active` -> `audit`) does not require evidence — it is
a safety action. Log the reason in the commit message.

### Adding/updating entries within a tool

For adding deny rules, hooks, KPIs, or verification cases:

1. Read the current tool entry
2. Draft the new/modified entry with all required fields
3. Present for user review
4. Write if approved
5. Update `meta.lastUpdated`

Required fields per section:

- **denyRules**: `id`, `permissionPattern`, `hook`, `reason`, `incidentRef`
- **hooks**: `event`, `matcher`, `script`, `purpose`
- **kpis**: `name`, `source`, `unit`
- **verifications**: `type`, `target`, `cases[]` (each with `input`,
  `expectExit`, `expectStdout`)

## Adding a new tool

Not every managed tool needs an ops entry. Create one only when:

- The tool has hooks that fire during sessions
- The tool has deny rules blocking specific permissions
- The tool requires special documentation access methods
- The tool has version-dependent behaviors that affect the harness

To add a new tool:

1. Create the tool key under `tools` with all governance modes set to
   `"audit"`
2. Populate at minimum: `governanceModes`, and whichever sections
   triggered the entry (e.g., `denyRules` if a deny rule was the cause)
3. Empty sections may be omitted — their absence means "no metadata
   for this category"
4. Present for user review
5. Write if approved
6. Update `meta.lastUpdated`
7. Create `reference/tool-ops-<toolname>.md` for the full ops reference
   (separate from the JSON registry)

## Cross-references

- Governance rule: `.claude/rules/tool-ops.md`
- Framework documentation: `reference/framework-tool-ops.md`
- Per-tool ops references: `reference/tool-ops-*.md`
- Framework registry: `reference/framework-registry.json`
- Governed data access pattern: `.claude/rules/governed-data-access.md`
