# Plan: Managed Content Cascade Framework

**Status**: Design complete, implementation pending
**Created**: 2026-03-15
**Gap**: New framework adoption (no existing gap — discovered during v0.60 session)
**Research**: `.scratch/research-multi-source-file-sync.md` (750+ lines, 8 disciplines)

## Intent

**Purpose**: Define how managed content flows between shared templates,
dotprofile repos, and deployed files — with per-section merge strategies,
cascade levels, and bidirectional sync. **Scope**: The cascade model,
section marking, merge behavior, and propagation rules. NOT the deploy
mechanism itself (managed-file-deployment framework). NOT the
menu/state-machine (interactive-menus rule). **Audience**: Anyone
modifying shared templates, dotprofile content, or deploy scripts.

## Problem Statement

Three content sources exist for user-level files (CLAUDE.md, hooks, skills):

1. **Shared template** (`shared/`) — framework defaults, maintained by contributors
2. **Dotprofile** (`<userRepoPath>/claude/`) — per-user customization and overrides
3. **Deployed** (`~/.claude/`) — machine-specific interpolated output

Current behavior: dotprofile wins as a whole file. Changes to shared don't
propagate to dotprofile users. No section-level awareness. Users aren't
prompted when framework-critical content updates. Accept & adopt writes to
dotprofile but has no path back to shared.

Discovered when: shared/claude-shared.md had 135 lines, dotprofile had 146
lines (3 sections ahead), deployed matched dotprofile exactly. User ran
`aitools install` multiple times with no merge prompt — "verified" every time.

## Foundational Decisions

### FD-1: Merge strategy is per-section, not per-file

Research across 8 disciplines converges on this. A single CLAUDE.md contains
sections with fundamentally different merge needs (scalar identity, tabular
tool lists, free-text coaching, enforced standing orders). A single strategy
is always wrong for some sections.

Sources: Puppet Hiera `lookup_options`, CSS cascade, Kustomize strategic
merge patch.

### FD-2: Four cascade levels

| Level | Name | Who owns | Behavior |
|---|---|---|---|
| `enforced` | ASO (Aitools Standing Order) | Framework | Shared always wins. User notified, not asked. |
| `default` | Framework-recommended | Framework with opt-out | Shared wins unless dotprofile explicitly overrides. New content propagates. |
| `optional` | User-customizable | User with framework seed | Dotprofile wins. Shared provides initial template only. |
| `user` | User-owned | User exclusively | Not in shared. Preserved always. |

Source: CSS cascade importance inversion, Ansible role defaults vs role vars,
GPO Enforced flag.

### FD-3: ASO vs USO vs PSO distinction

| Type | Scope | Where it lives | Example |
|---|---|---|---|
| **ASO** (Aitools Standing Order) | All aitools users | `shared/` (enforced) | Dedicated tools for file ops, tool evaluation gate |
| **USO** (User Standing Order) | One user, all projects | Dotprofile (user-owned) | Simple Bash commands only, scratch files preference |
| **PSO** (Project Standing Order) | One project | Project CLAUDE.md / `.claude/rules/` | Dual-script rule, script logging, fail don't mask |

Current shared template mixes ASOs and USOs under "### Standing Orders".
This plan splits them.

### FD-4: The managed unit depends on file type

| File type | Managed unit | Cascade marking |
|---|---|---|
| Markdown | Section (`## heading` to next `## heading`) | HTML comment or convention |
| Collections (dirs) | Individual file | Presence in `shared/` = managed |
| JSON | Field (top-level key) | `managedKeys` array in merge logic |

### FD-5: Bidirectional sync flows

```
shared/ (template) ──propagate──> dotprofile ──deploy──> deployed
         ^                            ^                      |
         |                            +── accept & adopt ────+
         +──── PR (automated) ────────+
```

- **Propagate** (shared → dotprofile): cascade level determines behavior
- **Deploy** (dotprofile → deployed): existing deploy_managed_file
- **Accept & adopt** (deployed → dotprofile): existing, fixed in v0.60
- **PR upstream** (dotprofile → shared): new, automated via `gh pr create`

## Section Audit: shared/claude-shared.md

| Section | Proposed Level | Rationale |
|---|---|---|
| `## Identity` | optional | User may want different name/company. Interpolated from profile.json |
| `## Code Style Defaults` | default | Framework-recommended, user may prefer different style |
| `## Tool & Source Evaluation` | enforced (ASO) | Security gate — non-negotiable |
| `## Cross-Platform Awareness` | enforced (ASO) | Framework infrastructure |
| `### Windows tool discovery in Git Bash` | enforced (ASO) | Framework infrastructure |
| `## Tools & Workflow` | enforced (ASO) | Framework description |
| `### Managed CLI Tools` (table) | enforced (ASO) | The tool table IS the framework. Merge by tool name |
| `### Per-Platform Tools` | enforced (ASO) | Framework platform support |
| `## MCP Servers` | default | User may not want vercel/webflow |
| `## Knowledge Management` | default | Framework-recommended, user overrides via profile.json |
| `## Coaching` (UCI items) | optional | Personal improvement areas |
| `### Standing Orders` | **SPLIT** | ASOs stay enforced in shared. USOs move to dotprofile. |
| `## Git Conventions` | default | Framework-recommended, user may have different branch naming |

### Standing Orders split

**ASOs (stay in shared, enforced):**
- Dedicated tools for file ops
- No silent failures in reusable code
- Perl for string manipulation

**USOs (move to dotprofile, user-owned):**
- Scratch files for complex scripting
- Simple Bash commands only
- Investigate user-reported problems

**Litmus test**: "Would this apply to ANY aitools user?" → ASO.
"Is this Jose's personal rule?" → USO.

### Sections only in dotprofile (user-owned)

- `### @ Reference Behavior (CC v2.1.x)`
- `## Session Hygiene`
- `- UCI: Suggest answers with questions`

## Section Marking Convention

For markdown files, sections carry their cascade level via HTML comment
(invisible to rendered output):

```markdown
<!-- cascade: enforced -->
## Tool & Source Evaluation
...

<!-- cascade: default -->
## MCP Servers
...

<!-- cascade: optional -->
## Coaching
...
```

Sections without a marker default to `default` (framework-recommended).
Sections not in shared at all are implicitly `user`.

Alternative: a sidecar JSON manifest mapping section headings to levels.
Tradeoff: less inline noise, but another file to maintain.

## Merge Behavior by Level

### enforced (ASO)

- **Propagate**: shared content replaces dotprofile content. User notified.
- **Deploy**: interpolated shared content deployed. No menu.
- **Accept & adopt**: not applicable (shared owns this content).
- **Table merge**: rows merge by key column (tool name). Shared adds/updates
  rows. User cannot remove managed rows.

### default (framework-recommended)

- **Propagate**: if dotprofile has no override, shared content propagates
  silently. If dotprofile has an override, notify user that shared changed
  but preserve their override.
- **Deploy**: dotprofile version if it exists, else shared version.
- **Accept & adopt**: deployed → dotprofile (existing behavior).
- **New content**: if shared adds a new default section, it appears in
  dotprofile on next sync.

### optional (user-customizable)

- **Propagate**: shared provides seed content only. Once dotprofile has
  any version, shared changes don't propagate.
- **Deploy**: dotprofile version if it exists, else shared version.
- **Accept & adopt**: deployed → dotprofile (existing behavior).
- **PR upstream**: dotprofile changes can be PR'd to shared template.

### user (user-owned)

- **Propagate**: not applicable (not in shared).
- **Deploy**: dotprofile content deployed as-is.
- **Accept & adopt**: deployed → dotprofile (existing behavior).
- **Preserved**: always kept, never overwritten.

## Graceful Conflict Handling

Users may put unexpected content in their dotprofile (PSO-like rules,
conflicting names, sections that overlap with ASOs). The merge engine
should:

1. **Never silently discard user content** — even if it conflicts
2. **Warn on overlap** — if user section heading matches an ASO heading,
   log a warning and keep both (user's under a renamed heading)
3. **Preserve unknown sections** — any section not in the cascade
   manifest is treated as `user`

## Hardcoded data in scripts (anti-pattern)

Several scripts embed managed data directly instead of reading from
a configuration source. The cascade plan must externalize these:

| Script | Hardcoded data | Should come from |
|---|---|---|
| `setup-user-mcp.sh/.ps1` | `denyRules` array (MCP denies + Agent denies) | `shared/` manifest (enforced) + profile.json (user) |
| `scripts/aitools` | `deploy_scripts` list | `shared/` manifest or directory scan |
| `setup-user-hooks.sh/.ps1` | Hook list (7 hooks) | `shared/hooks/` directory scan (partially done for skills) |
| `setup-user-hooks.sh/.ps1` | `managedKeys` in settings.json merge | `shared/` manifest |

The deny rules are particularly urgent: adding `Agent(Claude Code Guide)`
required editing 2 scripts + rebuilding deploy/. Under the cascade model,
framework denies are ASO-level (enforced from shared/), user denies come
from profile.json, and the scripts read both sources at runtime.

## Dependencies

- `profile.json` interpolation handles optional Identity gracefully
  (already uses `{{PLACEHOLDER}}` tokens with fallback)
- `setup-user-cursor` reads Cursor prefs from profile.json (already
  optional with defaults)
- `deploy_managed_file` needs section-aware merge mode (new capability)
- `build-deploy.sh` needs to embed cascade metadata (new)
- Deny rules need external data source (shared/ manifest for ASO,
  profile.json for user overrides)

## Implementation Phases

### Phase 1: ASO/USO split (smallest useful change)

1. Audit current USOs → split into ASOs and USOs
2. Move USOs to dotprofile template
3. Add `### Aitools Standing Orders` section to shared (enforced)
4. Update shared/claude-shared.md and dotprofile CLAUDE.md
5. Sync shared ← dotprofile (catch up the 3 missing sections)

### Phase 2: Section-level cascade marking

1. Add HTML comment markers to shared/claude-shared.md
2. Modify deploy script to parse sections and their levels
3. Implement per-section merge in deploy_managed_file
4. Section-level diff review (show which sections changed, not whole file)

### Phase 3: Propagation engine

1. Shared → dotprofile propagation per cascade level
2. Notification system (log what changed, why)
3. Table merge-by-key for tool table and similar
4. `aitools user diff` command (RSoP-style resultant view)

### Phase 4: Bidirectional sync

1. Automated PR on accept & adopt (dotprofile → shared)
2. Contributor workflow documentation
3. PR template with change context

### Phase 5: Extend to all managed file types

1. Apply cascade model to hooks (managed vs user hooks)
2. Apply to skills (managed vs user skills)
3. Apply to JSON fields (already mostly done)
4. Unified cascade manifest

## Research

Full research document: `.scratch/research-multi-source-file-sync.md`

Key frameworks combined in this design:
1. **CSS cascade** — 3 origins, importance inversion for enforced content
2. **Puppet Hiera** — per-section merge strategy declaration
3. **Kustomize** — merge-by-key for table sections
4. **WordPress child themes** — fallback chain overlay model
5. **GPO Enforced flag** — critical propagation regardless of override
6. **Drupal config sync** — bidirectional per-section conflict resolution

## Cross-References

- Existing framework: Managed file deployment (`reference/framework-managed-file-deployment.md`)
- Deploy mechanism: `.claude/rules/interactive-menus.md`, `reference/managed-file-deployment.md`
- Dotprofile spec: `reference/user-repo.md`
- Template resolution: `scripts/setup-user-claude.sh` (current whole-file approach)
- Research: `.scratch/research-multi-source-file-sync.md`
