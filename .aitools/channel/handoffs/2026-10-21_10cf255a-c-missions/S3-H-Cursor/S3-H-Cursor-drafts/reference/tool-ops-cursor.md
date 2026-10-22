# Tool ops: Cursor (IDE and CLI)

<!-- S3-H-Cursor DRAFT (not applied): proposed new file reference/tool-ops-cursor.md.
     Protected (sources-of-truth.md: reference/tool-ops-*.md). Includes an Intent
     statement, which is protected in any file: commander review required. -->

**Intent**: **Purpose**: Hold operational knowledge about Cursor (desktop IDE
and the `agent` CLI) that the harness depends on: where Cursor reads
user-level rules, in what format, and how to verify it. **Scope**: Rules
location, format and loading behaviour, doc access, and verification. NOT
install methods (`/tool-registry` skill). NOT the ops metadata registry
(`/tool-ops` skill). NOT project rule parity (`reference/cursor-practices.md`).
**Audience**: Agents that change `setup-user-cursor`, the harness rules
fan-out, or anything Cursor loads from `~/.cursor/`.

## User-level rules

| Item | Value | Source |
|------|-------|--------|
| Location | `~/.cursor/rules/` (Windows: `%USERPROFILE%\.cursor\rules\`) | cursor.com/help/customization/rules.md, "Where are rules stored?" (2026-10-22) |
| Format | `*.mdc` with a leading `---` frontmatter block | cursor.com/docs/rules.md "Rule file structure"; loader code |
| Plain `.md` | ignored | same |
| `.mdc` without frontmatter | skipped silently | loader code (frontmatter parser returns null) |
| Reach | workspaces under the home directory only | loader code (ancestor walk) |
| Sync | none (stays on the machine) | help page |

Verbatim (help page): "**User rule files** in `~/.cursor/rules` (Windows:
`%USERPROFILE%\.cursor\rules`) stay on the machine and do not sync."

"User Rules" set in **Customize → Rules** are a different thing. They are stored
on the Cursor account, not in files. cursor.com/docs/skills.md ("User rules are
also not migrated since they are not stored on the file system") refers to them.

### Loading behaviour

Cursor IDE 3.13.10 (`extensions/cursor-agent-exec/dist/main.js`) and CLI
2026.05.21-f84ab11 (`index.js`) share `LocalCursorRulesService`.
`loadRulesFromDirAndAncestors` starts at the workspace directory and walks up
to the filesystem root. At each directory it loads:

- `<dir>/.cursor/rules/**/*.mdc`
- `<dir>/AGENTS.md`
- `<dir>/CLAUDE.md` and `<dir>/CLAUDE.local.md`, only when third-party
  extensibility is enabled

There is no separate home lookup. `~/.cursor/rules` applies because `~` is an
ancestor of the workspace. A workspace outside `~` (`/tmp/x`, `C:\repos\x`)
does not see user rule files.

### Frontmatter to rule type

| Frontmatter | Type |
|-------------|------|
| `alwaysApply: true` | always included |
| `globs:` (comma string or YAML list) | auto-attached when a matching file is in context |
| `description:` only | agent decides when relevant |
| none of these | only when @-mentioned |

### Harness deployment

`setup-user-cursor` step 4 fans `~/.aitools/rules` out here. It converts each
Claude Code `<name>.md` to `<name>.mdc`:

- A rule without frontmatter gets `alwaysApply: true`.
- A Claude Code `paths:` key becomes `globs:` with `alwaysApply: false`.

## Known gaps

- `~/.cursor/AGENTS.md` (the relay mirror written by `aitools` / install step
  22) is not read by the rules loader in either bundle. The loader reads
  `<ancestor>/AGENTS.md`, that is, `~/AGENTS.md`.
- Live canary not yet run (needs `agent login`).

## Doc access

Use the chrome-devtools skill. Every docs page has a `.md` variant listed in
https://cursor.com/llms.txt (`/docs/<page>.md`, `/help/<area>/<page>.md`).
Fetch it in-page for verbatim text. Do not use WebFetch for content that
feeds protected files.

## Verification (manual canary)

Requires `agent login`. Run from a workspace under `~`:

```bash
mkdir -p ~/.cursor/rules ~/hcursor-canary-ws
printf -- '---\nalwaysApply: true\n---\nThe secret token is AITOOLS-CANARY-MDC-7Q4.\n' > ~/.cursor/rules/aitools-canary.mdc
cd ~/hcursor-canary-ws
agent -p --trust --mode ask "Do not use any tools. Print every token in your rules that starts with AITOOLS-CANARY-, or NONE."
rm ~/.cursor/rules/aitools-canary.mdc
```

Expected result: `AITOOLS-CANARY-MDC-7Q4`.
