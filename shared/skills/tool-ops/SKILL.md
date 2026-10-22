---
name: tool-ops
description: Read and write per-tool operational metadata — governance modes, deny rules, hooks, context injection, KPIs, and verification specs
---

## Intent

**Purpose**: Governed access to tool-ops.json — read operational
metadata, update governance modes, manage per-tool entries.
**Scope**: CRUD operations on tool-ops.json, and where to read per-tool
ops references (deployed copy first, then the aitools repo). NOT the
governance principle (`.claude/rules/tool-ops.md`). NOT the framework
documentation (`reference/framework-tool-ops.md`). NOT the content of
per-tool ops references.
**Audience**: Agents checking tool behavior, `/audit` skill validating
ops coverage, setup scripts reading governance modes.

## Where the files live

This is a user-level skill: `aitools install` deploys it to
`~/.claude/skills/` and `~/.cursor/skills/`, so it loads in every repo.
Its source is `shared/skills/tool-ops/` in the aitools repo. Every repo path
below (`registries/`, `reference/`, `.claude/rules/`, `scripts/`) is relative
to the aitools clone:

- **Session on aitools** (the clone or one of its worktrees): the paths
  resolve from the repo root. Reads and reviewed writes happen here.
- **Session on any other repo**: open the clone named by `repoPath` in
  `~/.aitools/config.json` (`%USERPROFILE%\.aitools\config.json` on
  Windows) and read from there. A reviewed write lands in that clone; tell
  the user it needs a commit there.
- **No clone on this machine**: read the read-only copies under
  `~/.aitools/registries/` and `~/.aitools/reference/` once deploy-harness
  installs them. Never edit those copies; propose the change as an issue on
  `nobul-tech/aitools` instead.
- **None of these exist**: say the data is unavailable and stop. Do not
  answer from memory.

## Reading tool ops

To look up a tool's operational metadata:

1. Read `registries/tool-ops.json`
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

### Per-tool ops references (where to read them)

A tool's full ops reference is `reference/tool-ops-<toolname>.md`
(e.g. `tool-ops-claude-code.md`). Read it from the first location
that has it:

1. **Deployed copy**: `~/.aitools/reference/tool-ops-<toolname>.md`
   (macOS/Linux), `%USERPROFILE%\.aitools\reference\tool-ops-<toolname>.md`
   (Windows). `aitools` (deploy-harness) mirrors the repo `reference/`
   tree there, same relative paths.
2. **Repo copy**: `reference/tool-ops-<toolname>.md` in the aitools
   repo (this checkout; from elsewhere, the `repoPath` key of
   `~/.aitools/config.json`, default `~/repos/aitools/` /
   `%USERPROFILE%\repos\aitools\`).

If neither exists, the tool has no ops reference; say so. The
deployed copy refreshes only on the next `aitools` run, so it can lag
the repo. When you are changing a reference in this session, read and
write the repo copy; never edit the deployed copy.

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
7. Create `reference/tool-ops-<toolname>.md` in the aitools repo for
   the full ops reference (separate from the JSON registry); the
   deployed copy appears after the next `aitools` run

## Cross-references

- Governance rule: `.claude/rules/tool-ops.md`
- Framework documentation: `reference/framework-tool-ops.md`
- Per-tool ops references: `reference/tool-ops-*.md` (read order:
  deployed copy, then repo; see "Per-tool ops references" above)
- Framework registry: `registries/framework-registry.json`
- Governed data access pattern: `.claude/rules/governed-data-access.md`
