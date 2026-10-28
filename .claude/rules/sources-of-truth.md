## Source-of-Truth Review Gate (this repo)

Certain files are authoritative references that feed scripts, deploy pipelines, or govern Claude's behavior. Changes to these files propagate across machines and affect real workflows, so every change is reviewed by the user. Review happens after the write (review-after, decision D-DEL5, commander 2026-10-26): agents write a version, commit it, and present the diff.

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
| `reference/user-repo.md` | User repo pattern, template resolution, session archive — scripts reference this | Any |
| `reference/agentic-framework.md` | Agentic AI invocation spec — speed/permission tiers, prompt design, validation patterns | Any |
| `reference/managed-file-deployment.md` | Managed file deployment state machine -- menus, return values, caller contracts | Any |
| Intent statements in any file | Defines how all future sessions interpret the file's purpose and scope | Any |
| `reference/framework-*.md` | Framework documentation — discipline source, adoption rationale, maintenance | Any |
| `registries/framework-registry.json` | Framework registry — source of truth for all adopted frameworks | Any |
| `.claude/rules/frameworks.md` | Framework rule — check-before-assuming principle, three-layer registry pattern, /frameworks trigger | Any |
| `reference/incident-*.md` | Incident reference files — full discovery context for framework-level incidents | Any |
| `reference/harness.md` | Harness architecture — the six components and their relationships | Any |
| `registries/glossary.json` | Governed vocabulary definitions — source of truth for all terms | Any |
| `registries/tool-ops.json` | Tool operations registry — per-tool governance modes and verification specs | Any |
| `reference/framework-tool-ops.md` | Tool operations framework — SRE discipline source and adoption rationale | Any |
| `reference/tool-ops-*.md` | Per-tool ops references — operational knowledge for deeply-integrated tools | Any |

### The rule

When writing, editing, or deleting content in any protected file (review-after, D-DEL5):

1. **Write the version** — make the change in place as a version (v1.0, v1.1, ...), never as a "draft" file to apply later. The change must serve a commander order or decision; cite it.
2. **Commit it reviewably** — in a PR, list every protected edit old → new under a "Review after" section of the PR body; for a direct-to-main commit (CLAUDE.md "Channel exception"), list them in the commit body. When multiple protected files change in one task, list them together.
3. **Present the diff** — tell the user which protected files changed and where the old → new list is. The user reviews after; if they ask for changes, make them as the next version (or revert), and record what changed.

Outward-facing or destructive actions (merging, tagging, deleting, publishing) are not covered by review-after: they still need the commander's explicit order.

### Exceptions

- **Trivial fixes** (typos, whitespace, markdown formatting) that do not change meaning may be made without review, but mention them in your response so the user is aware.
- **User-dictated content** — if the user provides the exact text to write (e.g., "add this bullet to CLAUDE.md: ..."), that counts as pre-approved. Write it directly.

### Intent statements

Intent statements (`**Intent**:` blocks in markdown, `intent:` header
comments in code) are protected regardless of which file they appear
in. They follow the same review-after rule: write the intent, list it
old → new for review, and revise it as the next version if the user
asks. This applies to new intent statements and modifications to
existing ones. See `@reference/framework-adoption.md` for why intent
is part of the harness.

### Why this matters

These files are the "single source of truth" pattern — downstream scripts and behaviors derive from them. A silent change here can propagate incorrect install commands, alter behavioral rules, or deploy wrong configs across machines. The review step keeps Claude and user in sync; review-after keeps it without blocking work on a pre-write approval, and no protected change is ever silent.
