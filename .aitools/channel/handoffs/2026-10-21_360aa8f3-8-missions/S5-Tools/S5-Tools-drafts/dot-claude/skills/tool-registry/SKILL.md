---
name: tool-registry
description: "Read and update managed tool entries in the registry.
  Use when checking a tool's install method, update channel, detection
  signatures, or versions, adding a new tool entry, or updating an
  existing entry."
---

## Intent

> DRAFT — needs commander approval (modified intent statement).

**Purpose**: Provide governed access to the tool registry — reading
tool entries, adding new entries, updating install methods, update
channels and detection data, and tracking versions. **Scope**: Registry
data operations only. NOT the evaluation process (use `/tool-eval`). NOT
setup-script integration (use `/tool-adopt`). NOT lifecycle gates or the
decision tree (`@.claude/rules/tool-lifecycle.md`,
`@reference/tool-support-decision-tree.md`). **Audience**: Any agent that
needs to look up a tool's install method, verify a version, or write a
registry entry after evaluation; `/tool-eval` and `/tool-adopt`.

## Reading tool entries

1. Read `@registries/tool-registry.json`
2. Find the tool in `tools.<slug>` (CLI tools) or `mcpServers.<slug>` (MCP servers)
3. Present: displayName, source, purpose, install methods per platform
   (preferred method per environment, kind, package, detection, removal),
   update channel, lifecycle (platformStatus, environments, setupScript,
   concurrency, postInstallConfig, dependencies, invocation), versions
   (per-platform lastVerified), authentication (if present), notes,
   pathIssues, platformGotchas
4. For MCP servers: also present transport, auth, scope, installClaudeCode
5. If any platform version is null, note it as "not yet verified"
6. If a platform+environment with status approved or supported has no
   single preferred method, say so: setup scripts will report NO-METHOD

## Adding or updating a tool entry

Prerequisite: evaluation completed via `/tool-eval` skill, or user
provides the exact content to write.

1. Verify all required data fields are present:
   - **source** — official project URL
   - **purpose** — what the tool does and why we manage it
   - **install** — per platform: every known method; exactly one
     `preferred: true` per environment; each with `kind`, `package`,
     `command`, `detection`; non-preferred ones with `removal` (or null)
   - **update** — update command per preferred method id (or `all`), or
     `autoUpdates: true` on the method
   - **updateChannel** — channel (default `latest-stable`), `pin` and
     `reason` when pinned
   - **delivery** — per platform: package maintainer, upstream
     source, official endorsement, provenance verified date
   - **health** — per platform: flag (green/yellow/red) with reasons
   - **lifecycle** — platform status (enum), environment status where it
     differs, setupScript, concurrency, post-install config, dependencies,
     invocation command and anti-patterns
   - **versions** — per platform: last verified version and date
   - **maintenance** — harness, last run per platform, workarounds,
     upstream risks
   - **evaluation** — status (current/stale/pending-migration),
     provenance file link, pending changes description
   - **authentication** — if required: method, setup/status/refresh
     commands, token storage, env var override, auth0 migration phase
2. Verify the onboarding artifacts exist or are planned, per the
   `/tool-adopt` skill step 5 (the single onboarding checklist)
3. Draft the registry entry
4. Validate the draft against the "Tool support conformance" checks
   (`@reference/tool-support-decision-tree.md` section 9, checks 1-6)
5. Present for review — protected per `@.claude/rules/sources-of-truth.md`
6. Write if approved

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

`registries/tool-registry.json` uses `schemaVersion: "1.1"`. Top-level
keys: `meta`, `tools`, `mcpServers`, `mcpManagement`, `overrides`.
Field rules for everything the tool support decision tree reads
(`install[]` method fields, `update`, `updateChannel`, `knownPaths`,
lifecycle enums, `setupScript`) are defined only in
`@reference/tool-support-decision-tree.md` section 6; do not restate them
here. Other sections per CLI tool (`tools.<slug>`):

| Section | Purpose |
|---------|---------|
| `install`, `update`, `updateChannel`, `knownPaths` | Decision-tree data (reference section 6) |
| `delivery` | Provenance: who maintains the package, upstream source, endorsement |
| `health` | Per-platform green/yellow/red flags with reasons |
| `evaluation` | Status (current/stale/pending-migration), provenance link |
| `lifecycle` | Platform status, environment status, setupScript, concurrency, config, dependencies, invocation |
| `versions` | Per-platform verified version + date, minVersion, blocked |
| `maintenance` | Harness, workarounds (with severity), upstream risks |
| `authentication` | Auth method, commands, token storage, Auth0 migration phase |
| `nonPreferredMethods` | Deprecated in 1.1 — migrate rows into `install.<platform>[]` |
| `buildPrereqs` | Per-platform build dependencies |
| `overrides` | Intentional deviations from upstream defaults |

Setup scripts read registry data through generated tool specs
(`generated/tool-specs/`), never the JSON; regenerate them after every
approved registry write.

## When to invoke /tool-registry

- Checking a tool's install method, channel, version, or health status
- Adding a new tool entry (after `/tool-eval` completes)
- Updating an existing entry's fields or version (also from `/tool-adopt`)
- User says /tool-registry or /tools

## Cross-References

- Evaluation process: `/tool-eval` skill
- Integration and script migration: `/tool-adopt` skill
- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Lifecycle gates and update policy: `@.claude/rules/tool-lifecycle.md`
- Field rules and decision tree: `@reference/tool-support-decision-tree.md`
- Registry data: `@registries/tool-registry.json`
- Evaluation research: `reference/evaluations/`
