# Cursor Practices & Setup Notes

Reference notes for Cursor IDE configuration. For project instructions, see the root `CLAUDE.md`.

---

## Rules System

Cursor uses `.mdc` files (Markdown with YAML frontmatter) for AI rules. Three scopes:

| Scope | Location | Synced? |
|-------|----------|---------|
| Project rules | `.cursor/rules/*.mdc` | Yes (via git) |
| User rules | Cursor Settings > Rules | No (local to machine) |
| Team rules | `.cursor/rules/*.mdc` (shared) | Yes (via git) |

### Rule Frontmatter

```yaml
---
description: When/why this rule applies
globs: "*.py"        # Optional file pattern filter
alwaysApply: true    # true = always active, false = on-demand
---
```

### Best Practices

- Keep rules focused and actionable — concrete instructions, not vague guidelines
- Use `alwaysApply: true` for conventions that apply everywhere
- Use `globs` to scope rules to specific file types (e.g., `"*.py"` for Python)
- Cursor injects matching rules into the AI context automatically
- Template for new projects: `shared/cursor-rules/default.mdc`

## MCP in Cursor

Cursor has its own MCP configuration, **separate from Claude Code**.

| Tool | Config file | Format |
|------|------------|--------|
| Claude Code | `~/.claude.json` | `mcpServers` with `type`, `command`, `args` |
| Cursor | `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project) | `mcpServers` with `command`/`args` or `url` |

### Key Differences from Claude Code

- Remote servers use `"url"` key directly (no `--transport http` flag)
- No `type` field needed in the JSON
- Setup is done by writing the JSON file directly (no CLI like `claude mcp add`)
- OAuth flows happen in Cursor's Agent chat when tools are first used

### Setup

```powershell
# Windows
.\scripts\setup-cursor-mcp.ps1

# macOS
bash scripts/setup-cursor-mcp.sh
```

After running, restart Cursor and go to **Cursor Settings > Tools & MCP** to verify servers appear and authenticate Vercel + Webflow.

## Cursor CLI (`agent` command)

Cursor has a standalone CLI, separate from the IDE. The command is `agent` (not `cursor`).

### Prerequisites

- **ripgrep (`rg`)** — required at runtime. The CLI shells out to `rg` for code search and will fail with "Could not find ripgrep (rg) binary" if it's missing.
  - Windows: `winget install BurntSushi.ripgrep.MSVC`
  - macOS: `brew install ripgrep`
  - The `setup-user-cursor` scripts install this automatically.

### Installation

```powershell
# Windows
irm 'https://cursor.com/install?win32=true' | iex

# macOS
curl https://cursor.com/install -fsS | bash
```

Or use `scripts/setup-user-cursor.ps1` / `.sh` which handles this automatically.

### CLI Config

Config lives at `~/.cursor/cli-config.json`:

```json
{
  "version": 1,
  "editor": { "vimMode": false },
  "permissions": { "allow": [], "deny": [] }
}
```

### Key Commands

| Command | What it does |
|---------|--------------|
| `agent` | Start interactive session in current directory |
| `agent --version` | Show CLI version |
| `agent "prompt"` | Start session with initial prompt |

### User Rules (deprecated workflow)

Cursor User Rules live in **Cursor Settings > Rules** (UI only) — they're stored in a SQLite database (`state.vscdb`), not an accessible file.

The automated clipboard-copy workflow (via `setup-user-cursor`) has been removed as of v3.11. Cursor project rules (`.cursor/rules/*.mdc`) are auto-loaded and cover the same ground. If manual User Rules are still needed, copy from `shared/cursor-rules/user-rules.md` directly.

### CLAUDE.md Interop

When **"Include third party skills, subagents and other configs"** is enabled in Cursor Settings, Cursor reads `~/.claude/CLAUDE.md` at the user level (same as Claude Code).

**Important:** Cursor does **not** resolve `@import` / `@"path"` directives — it reads the file as-is. Content must be inlined for Cursor to see it.

The deploy scripts handle this automatically: `deploy/setup-user-claude.sh/.ps1` have the shared content embedded at build time. Re-run `scripts/build-deploy.sh` after editing the shared file, then re-deploy to propagate changes.

> **Open question:** Whether Cursor actually reads `~/.claude/CLAUDE.md` at runtime is unverified. Test by asking Cursor about git identity in a project that has no local CLAUDE.md.

## Rule Correspondence

Cursor project rules mirror Claude Code rules for consistency. When changing rules, update both sets.

| Claude Code | Cursor | Notes |
|------------|--------|-------|
| `.claude/rules/cross-platform.md` | `.cursor/rules/cross-platform.mdc` | Condensed |
| `.claude/rules/sources-of-truth.md` | `.cursor/rules/sources-of-truth.mdc` | Near-identical |
| `.claude/rules/tool-lifecycle.md` | `.cursor/rules/tool-lifecycle.mdc` | Near-identical |
| `.claude/rules/concurrent-agents.md` | `.cursor/rules/concurrent-agents.mdc` | Identical |
| `.claude/rules/git-identity.md` | `.cursor/rules/general.mdc` | Folded in |
| `.claude/rules/python-style.md` | `.cursor/rules/general.mdc` | Folded in |
| `.claude/rules/pre-commit.md` | `.cursor/rules/pre-commit.mdc` | Identical |
| `.claude/rules/pre-push.md` | `.cursor/rules/pre-push.mdc` | Identical |
| `.claude/rules/post-push.md` | `.cursor/rules/post-push.mdc` | Identical |
| `.claude/rules/script-standards.md` | `.cursor/rules/script-standards.mdc` | Condensed |
| `.claude/rules/documentation-standards.md` | `.cursor/rules/documentation-standards.mdc` | Condensed |
| `.claude/rules/surface-silent-failures.md` | -- | Claude Code-specific |

### Changing rules

When adding or modifying a rule in either `.claude/rules/` or `.cursor/rules/`:

1. Make the change in the primary file
2. Mirror or update the corresponding file in the other rules directory
3. Update the table above if the correspondence changes

## Skills

Cursor supports a Skills system for reusable AI capabilities:

- Skills live in `.cursor/skills/` directories
- Each skill has a `SKILL.md` file describing what it does
- Skills can include example code, patterns, and instructions
- Useful for encoding project-specific workflows (e.g., "how to add a new API endpoint")

We don't use skills yet — this is noted for future reference.

## Machines

| Machine | Cursor Config |
|---------|--------------|
| Windows workstation | `~/.cursor/mcp.json` |
| Mac laptop | `~/.cursor/mcp.json` |

Both machines need their own MCP setup (run `deploy/setup-cursor-mcp.sh` or `.ps1` on each).
