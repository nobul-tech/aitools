---
name: tool-registry
description: "Read and update managed tool entries in the registry.
  Use when checking a tool's install method, verifying versions,
  adding a new tool entry, or updating an existing entry."
---

## Intent

**Purpose**: Provide governed access to the tool registry — reading
tool entries, adding new entries, updating install methods, and
tracking versions. **Scope**: Registry data operations only. NOT the
evaluation process (use `/tool-eval`). NOT lifecycle gates or
onboarding checklists (`@.claude/rules/tool-lifecycle.md`).
**Audience**: Any agent that needs to look up a tool's install method,
verify a version, or write a registry entry after evaluation.

## Reading tool entries

1. Read `@registries/tool-registry.json`
2. Find the tool in `tools.<slug>` (CLI tools) or `mcpServers.<slug>` (MCP servers)
3. Present: displayName, source, purpose, install methods per platform,
   lifecycle (platformStatus, concurrency, postInstallConfig, dependencies,
   invocation), versions (per-platform lastVerified), authentication (if
   present), notes, pathIssues, platformGotchas
4. For MCP servers: also present transport, auth, scope, installClaudeCode
5. If any platform version is null, note it as "not yet verified"

## Adding or updating a tool entry

Prerequisite: evaluation completed via `/tool-eval` skill, or user
provides the exact content to write.

1. Verify all required data fields are present:
   - **source** — official project URL
   - **purpose** — what the tool does and why we manage it
   - **install** — per platform: preferred method, command,
     update command, version check
   - **delivery** — per platform: package maintainer, upstream
     source, official endorsement, provenance verified date
   - **health** — per platform: flag (green/yellow/red) with reasons
   - **lifecycle** — platform status, concurrency, post-install
     config, dependencies, invocation command and anti-patterns
   - **versions** — per platform: last verified version and date
   - **maintenance** — harness, last run per platform, workarounds,
     upstream risks
   - **evaluation** — status (current/stale/pending-migration),
     provenance file link, pending changes description
   - **authentication** — if required: method, setup/status/refresh
     commands, token storage, env var override, auth0 migration phase
2. Verify all required onboarding artifacts exist or are planned:
   - **Setup scripts** — `scripts/setup-<tool>.sh` + `.ps1`
   - **Installer integration** — step in `aitools-install.sh/.ps1`
   - **Build pipeline** — copy block in `build-deploy.sh`
   - **Tool skill** — `shared/skills/<tool>/SKILL.md`
   - **Check script entries** — `TOOL_CMDS` dictionary in check scripts
   - **CLAUDE.md entries** — Managed CLI Tools table + deploy list
   - **Evaluation provenance** — `reference/evaluations/<tool>-*.md`
3. Draft the registry entry
4. Present for review — protected per `@.claude/rules/sources-of-truth.md`
5. Write if approved

## Updating version tracking

When a tool is verified on a platform:

1. Read `@registries/tool-registry.json`
2. Navigate to `tools.<slug>.versions.<platform>`
3. Update `lastVerifiedVersion` and `lastVerified`
4. For MCP servers: update `mcpServers.<slug>.versions.lastReviewed`
5. Update `meta.lastUpdated` to today's date
6. Present for review (protected file)
7. Write if approved

## Schema

`registries/tool-registry.json` uses `schemaVersion: "1.0"`. Top-level
keys: `meta`, `tools`, `mcpServers`, `mcpManagement`, `overrides`.
Key sections per CLI tool (`tools.<slug>`):

| Section | Purpose |
|---------|---------|
| `install` | Per-platform preferred method + alternatives |
| `delivery` | Provenance: who maintains the package, upstream source, endorsement |
| `health` | Per-platform green/yellow/red flags with reasons |
| `evaluation` | Status (current/stale/pending-migration), provenance link |
| `lifecycle` | Platform status, concurrency, config, dependencies, invocation |
| `versions` | Per-platform verified version + date |
| `maintenance` | Harness, workarounds (with severity), upstream risks |
| `authentication` | Auth method, commands, token storage, Auth0 migration phase |
| `nonPreferredMethods` | Cleanup targets for setup scripts |
| `buildPrereqs` | Per-platform build dependencies |
| `knownPaths` | Verified install paths for PATH fallback detection |
| `overrides` | Intentional deviations from upstream defaults |

## When to invoke /tool-registry

- Checking a tool's install method, version, or health status
- Adding a new tool entry (after `/tool-eval` completes)
- Updating an existing entry's fields or version
- User says /tool-registry or /tools

## Cross-References

- Evaluation process: `/tool-eval` skill
- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Lifecycle gates: `@.claude/rules/tool-lifecycle.md`
- Registry data: `@registries/tool-registry.json`
- Evaluation research: `reference/evaluations/`
