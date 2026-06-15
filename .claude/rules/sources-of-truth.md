## Source-of-Truth Review Gate (this repo)

Certain files are authoritative references that feed scripts, deploy pipelines, or govern Claude's behavior. Changes to these files propagate across machines and affect real workflows, so they require user review before being written.

### Protected files

| File | What it controls | Agent |
|------|-----------------|-------|
| `registries/tool-registry.json` | Registry of managed tools — install methods, platform versions, lifecycle, operational knowledge (via `/tool-registry` skill) | Any |
| `reference/tool-evaluation-criteria.md` | Tool evaluation framework and lifecycle phases | Any |
| `reference/tool-evaluation-playbook.md` | Install method discovery process and criteria — feeds BuildPrereqs and tool-registry entries | Any |
| `CLAUDE.md` | Project-level instructions and Key Decisions | Any |
| `shared/claude-shared.md` | User-level preferences embedded into deploy scripts (propagates to all machines) | Any |
| `shared/cursor-rules/user-rules.md` | Cursor User Rules template (manual copy if needed) | Any |
| `.claude/rules/*.md` | Claude Code behavioral rules (this file included) | Any |
| `.claude/rules/managed-file-deployment.md` | Deployment type definitions, content sources, platform config rules | Any |
| `registries/incidents.json` | Incident tracking — governed by `.claude/rules/incident-governance.md` | Any |
| `.cursor/rules/*.mdc` | Cursor behavioral rules | Any |
| `ROADMAP.md` | Active/planned work items — drives project priorities | Any |
| `plans/*.md` | Detailed implementation plans — referenced by roadmap | Any |
| `reference/tool-ops-claude-code.md` | Claude Code operations — version deps, session behavior, platform workarounds | Any |
| `registries/tool-versions.json` | Per-platform tool version manifest — read by `check-post-push` version-freshness checks | Any |
| `reference/user-repo.md` | User repo pattern, template resolution, session archive — scripts reference this | Any |
| `reference/agentic-framework.md` | Agentic AI invocation spec — speed/permission tiers, prompt design, validation patterns | Any |
| `reference/managed-file-deployment.md` | Managed file deployment state machine -- menus, return values, caller contracts | Any |
| Intent statements in any file | Defines how all future sessions interpret the file's purpose and scope | Any |
| `reference/framework-*.md` | Framework documentation — discipline source, adoption rationale, maintenance | Any |
| `registries/framework-registry.json` | Framework registry — source of truth for all adopted frameworks | Any |
| `.claude/rules/frameworks.md` | Framework rule — intent of frameworks, registry of registries | Any |
| `reference/incident-*.md` | Incident reference files — full discovery context for framework-level incidents | Any |
| `reference/harness.md` | Harness architecture — the five components and their relationships | Any |
| `registries/glossary.json` | Governed vocabulary definitions — source of truth for all terms | Any |
| `registries/tool-ops.json` | Tool operations registry — per-tool governance modes and verification specs | Any |
| `reference/framework-tool-ops.md` | Tool operations framework — SRE discipline source and adoption rationale | Any |
| `reference/tool-ops-*.md` | Per-tool ops references — operational knowledge for deeply-integrated tools | Any |

### The rule

Before writing, editing, or deleting content in any protected file:

1. **Draft the change** — prepare the exact content but do not write it yet
2. **Present for review** — show the proposed change to the user. Use full content for new sections, diff-style (old → new) for edits to existing content. When multiple protected files change in one task, present them together as a batch.
3. **Wait for approval** — do not write until the user confirms. If the user requests modifications, revise and re-present.

### Exceptions

- **Trivial fixes** (typos, whitespace, markdown formatting) that do not change meaning may be made without review, but mention them in your response so the user is aware.
- **User-dictated content** — if the user provides the exact text to write (e.g., "add this bullet to CLAUDE.md: ..."), that counts as pre-approved. Write it directly.

### Intent statements

Intent statements (`**Intent**:` blocks in markdown, `intent:` header
comments in code) are protected regardless of which file they appear
in. Draft the intent, present for user review, write only after
approval. This applies to new intent statements and modifications to
existing ones. See `@reference/framework-adoption.md` for why intent
is part of the harness.

### Why this matters

These files are the "single source of truth" pattern — downstream scripts and behaviors derive from them. A silent change here can propagate incorrect install commands, alter behavioral rules, or deploy wrong configs across machines. The review step keeps Claude and user in sync.
