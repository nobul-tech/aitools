# /tool-registry SKILL.md — Required Changes

## Summary

The SKILL.md currently references `reference/tool-registry.md` (the markdown
file). After the migration, it must point to `reference/tool-registry.json`
and update all reading/writing instructions to work with the JSON schema.

## Change 1: Data source reference

**Old** (line 20-21):
```
1. Read `@reference/tool-registry.md`
2. Find the tool in the `tools` object by key
```

**New**:
```
1. Read `@reference/tool-registry.json`
2. Find the tool in `tools.<slug>` (CLI tools) or `mcpServers.<slug>` (MCP servers)
```

## Change 2: Reading tool entries — present fields

**Old** (line 22-24):
```
3. Present: source, install methods per platform, health flags,
   delivery provenance, lifecycle fields, maintenance workarounds
4. If health flags are yellow or red, surface the reasons prominently
```

**New**:
```
3. Present: displayName, source, purpose, install methods per platform,
   lifecycle (platformStatus, concurrency, postInstallConfig, dependencies,
   invocation), versions (per-platform lastVerified), authentication (if
   present), notes, pathIssues, platformGotchas
4. For MCP servers: also present transport, auth, scope, installClaudeCode,
   skills (if present)
5. If any platform version is null, note it as "not yet verified"
```

## Change 3: Adding/updating — required data fields

**Old** (lines 36-56): Lists fields like `delivery`, `health`, `maintenance`,
`evaluation` that existed in the planned-but-never-implemented rich schema.

**New** — required fields per the actual JSON schema:

### CLI tool entry (`tools.<slug>`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `displayName` | string | yes | Human-readable name |
| `source` | string | yes | Official project URL |
| `purpose` | string | no | What the tool does and why we manage it |
| `install` | object | yes | Keyed by platform (macos/windows/linux or all). Array of install method objects |
| `install[].method` | string | yes | Identifier (homebrew, winget, native, etc.) |
| `install[].command` | string | yes | Exact install command |
| `install[].preferred` | boolean | yes | Is this the preferred method? |
| `install[].autoUpdates` | boolean | yes | Does this method auto-update? |
| `install[].ccCompatible` | boolean | yes | Works from Claude Code Bash tool? |
| `install[].notes` | string | no | Method-specific notes |
| `update` | object | no | Keyed by method — update command strings |
| `versionCheck` | string | yes | Command to check installed version |
| `systemRequirements` | string | no | OS/hardware requirements |
| `notes` | string | no | Operational knowledge (prose, preserved verbatim) |
| `lifecycle` | object | yes | See lifecycle sub-schema |
| `lifecycle.platformStatus` | object | yes | macos/windows/linux -> "supported"/"evaluating"/"unsupported" |
| `lifecycle.concurrency` | string | yes | Concurrency model |
| `lifecycle.postInstallConfig` | string | no | What setup is needed after install |
| `lifecycle.dependencies` | array | yes | Runtime dependencies |
| `lifecycle.invocation` | object | yes | command (string) + antiPatterns (array) |
| `versions` | object | yes | See versions sub-schema |
| `versions.<platform>` | object | yes | lastVerifiedVersion (string/null) + lastVerified (date/null) |
| `versions.minVersion` | string | no | Minimum acceptable version |
| `versions.blocked` | array | no | Versions known to be broken |
| `versions.maintenanceFile` | string | no | Reference to ops-specific maintenance doc |
| `authentication` | object | no | Auth method, check command, type, token storage, env override |
| `buildPrereqs` | object | no | Per-platform array of prerequisite objects |
| `knownPaths` | object | no | Per-platform verified install paths |
| `nonPreferredMethods` | array | no | Cleanup targets for setup scripts |
| `pathIssues` | string | no | Known PATH problems (prose) |
| `platformGotchas` | object | no | Per-platform operational warnings (prose) |

### MCP server entry (`mcpServers.<slug>`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `displayName` | string | yes | Human-readable name |
| `officialDocs` | string | yes | Documentation URL |
| `transport` | string | yes | stdio or http |
| `auth` | string | yes | Auth method description |
| `scope` | string | yes | User/project scope + default enabled state |
| `installClaudeCode` | string | yes | Claude Code install command |
| `lifecycle` | object | yes | Same sub-schema as CLI tools |
| `versions.pinned` | boolean | yes | Whether version is pinned |
| `versions.lastReviewed` | string | yes | Date of last review |
| `versions.assumptions` | array | yes | Documented assumptions about the server |

## Change 4: Updating version tracking

**Old** (lines 62-68):
```
1. Read `@reference/tool-registry.md`
2. Update the platform's `lastVerifiedVersion` and `lastVerified`
3. Re-evaluate health flag if version was previously unverified
```

**New**:
```
1. Read `@reference/tool-registry.json`
2. Navigate to `tools.<slug>.versions.<platform>`
3. Update `lastVerifiedVersion` and `lastVerified`
4. For MCP servers: update `mcpServers.<slug>.versions.lastReviewed`
5. Update `meta.lastUpdated` to today's date
6. Present for review (protected file)
```

## Change 5: Schema section

**Old** (lines 72-88): References `reference/tool-registry.md` as markdown,
mentions incident #21 tracking migration to JSON.

**New**: Replace entirely with the schema description above (Change 3 tables).
Remove the incident #21 reference — the migration is now complete.

## Change 6: Cross-references section

**Old** (line 102):
```
- Registry data: `@reference/tool-registry.md`
```

**New**:
```
- Registry data: `@reference/tool-registry.json`
```

## Change 7: Description in frontmatter

**Old**:
```
description: "Read and update managed tool entries in the registry.
  Use when checking a tool's install method, verifying versions,
  adding a new tool entry, or updating an existing entry."
```

No change needed — description is still accurate.

## Files that reference tool-registry.md and need updating

These files reference the old markdown path and will need to be updated
to point to tool-registry.json (accessed via skill per governed data rules):

1. `reference/tool-versions.json` — `_meta.relatedDocs.toolRegistry`
   (this file is being retired — its data is merged into tool-registry.json)
2. `.claude/skills/tool-registry/SKILL.md` — multiple references
3. `.claude/rules/sources-of-truth.md` — protected files table
   (change `reference/tool-registry.md` to `reference/tool-registry.json`)
4. Any check scripts that reference the path directly

Note: per governed-data-access.md, rule files and reference docs should
reference the `/tool-registry` skill, not the JSON path. Only the SKILL.md
and programmatic artifacts (scripts, hooks) should use the file path.
