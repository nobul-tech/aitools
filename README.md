# ai-tooling

Cross-machine AI tooling hub — shared configs, rules, and scripts for Claude Code, Cursor, and MCP across Windows 11 and macOS.

## What's here

| Directory | Purpose |
|-----------|---------|
| `shared/` | Source of truth: Claude prefs, Cursor rules, shell aliases, MCP docs |
| `scripts/` | `aitools` CLI, installers, setup scripts, `build-deploy.sh` pipeline |
| `deploy/` | Generated self-contained scripts (MDM-ready, no repo needed) |
| `.claude/rules/` | Claude Code project rules |
| `.cursor/rules/` | Cursor project rules (.mdc format) |
| `conversionutils/` | PDF-to-markdown conversion utilities |
| `docs/` | Vendor docs for offline/RAG use |
| `reference/` | Setup notes, practices, session showcase |
| `plans/` | Detailed implementation plans for roadmap items |
| `shared/hooks/` | Claude Code hooks (session archive) |
| `ROADMAP.md` | Active and planned work items |
| `RELEASE_NOTES.md` | Version history and changelog |

## How it works

`shared/` is the single source of truth for all configuration. `scripts/build-deploy.sh` reads from `shared/` and embeds the content into self-contained deploy scripts in `deploy/`. The workflow is: edit `shared/` → run `build-deploy.sh` → commit `deploy/` → deploy to endpoints. Deploy scripts need only bash or PowerShell on the target machine — no repo clone required.

## Quick start

### Install on a new machine

Clone the repo and run the installer:

```bash
# macOS/Linux
git clone https://github.com/nobul-jose/ai-tooling.git ~/repos/ai-tooling
bash ~/repos/ai-tooling/scripts/aitools-install.sh

# Windows (PowerShell)
git clone https://github.com/nobul-jose/ai-tooling.git C:\repos\ai-tooling
C:\repos\ai-tooling\scripts\aitools-install.ps1
```

After install, the `aitools` command is available:

```bash
aitools                          # Sync configs: pull + rebuild + deploy all
aitools gitpull                  # Update source + deploy + changelog + version tag
aitools install                  # Full setup: install tools + deploy configs
aitools mcp                      # Show MCP server status
aitools --addmcp vercel          # Enable MCP server for current project
aitools --version                # Show installed and repo version
aitools user init                # Set up user repo + session archive hook
aitools sessions list [project]  # List archived sessions
aitools sessions archive <id>    # Manually archive a session by ID
```

### Deploy to a machine (no repo needed)

Run these from the `deploy/` directory -- self-contained, MDM-ready:

```powershell
# Claude Code user preferences
bash deploy/setup-user-claude.sh        # macOS
.\deploy\setup-user-claude.ps1          # Windows

# Cursor CLI + User Rules
bash deploy/setup-user-cursor.sh        # macOS
.\deploy\setup-user-cursor.ps1          # Windows

# Claude Code MCP servers
bash deploy/setup-user-mcp.sh           # macOS
.\deploy\setup-user-mcp.ps1             # Windows

# Cursor MCP servers
bash deploy/setup-cursor-mcp.sh         # macOS
.\deploy\setup-cursor-mcp.ps1           # Windows

# Vercel CLI
bash deploy/setup-vercelcli.sh          # macOS
.\deploy\setup-vercelcli.ps1            # Windows

# Pandoc
bash deploy/setup-pandoc.sh             # macOS
.\deploy\setup-pandoc.ps1               # Windows
```

### Develop / maintain configs

Work inside the repo to update shared configuration:

```bash
# Edit shared source files
vim shared/claude-shared.md

# Rebuild deploy scripts
bash scripts/build-deploy.sh

# Commit both shared/ and deploy/ changes
git add shared/ deploy/ && git commit -m "Update shared config"
```

See `reference/` for deeper setup notes and practices.

**Add shell aliases** (optional):

```bash
# bash/zsh — add to ~/.bashrc or ~/.zshrc
source ~/repos/ai-tooling/shared/shell/aliases.sh
```

```powershell
# PowerShell — add to $PROFILE
. "$HOME\repos\ai-tooling\shared\shell\aliases.ps1"
```

Key aliases: `cc` (Claude Code with CLAUDE.md check), `ccr`/`ccs` (resume/pick sessions), `clip2md` (clipboard to markdown).

**PDF conversion** (Marker is preferred -- see `conversionutils/COMPARISON_REPORT.md`):

```bash
# Legacy utilities (still available):
python conversionutils/pdf_to_markdown.py input.pdf -o output.md
python conversionutils/pdf_to_man_markdown.py input.pdf -o output.md
```

**Clipboard to Markdown** (requires pandoc; optional: claude CLI for auto-naming):

```bash
clip2md                          # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes            # Explicit name: meeting-notes.md
```

## Version history

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for the full changelog.

## License

MIT
