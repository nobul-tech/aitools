# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, Warp, and MCP across Windows and macOS.

## Project Structure

```
ai-tooling/
├── .claude/rules/       # Claude Code project rules (modular)
├── .cursor/rules/       # Cursor rules (.mdc format)
├── shared/              # Source of truth for configs
│   ├── claude-shared.md #   → embedded into deploy scripts by build
│   ├── cursor-rules/    # Template rules + User Rules source of truth
│   ├── shell/           # Shell aliases (bash/zsh + PowerShell)
│   └── mcp/             # MCP server configuration docs
├── scripts/             # Dev/source scripts (read from shared/)
│   ├── aitools          # CLI entry point (bash, macOS/Linux)
│   ├── aitools.ps1      # CLI entry point (PowerShell, Windows)
│   └── build-deploy.sh  # Generates deploy/ from scripts/ + shared/
├── deploy/              # Self-contained scripts for MDM (generated)
├── conversionutils/     # PDF-to-markdown conversion tools
├── docs/                # RAG knowledge base (vendor docs)
└── reference/           # Setup notes and how-tos
```

## Git Identity

- Name: `Jose`
- Email: `jose@nobul.tech`

## Build & Run

```bash
# Generate self-contained deploy/ scripts from scripts/ + shared/
bash scripts/build-deploy.sh

# CLI usage (after install -- same commands on both platforms)
aitools                        # Pull latest + rebuild (self-update)
aitools install                # Install/update all tools + deploy configs
aitools --addmcp vercel        # Add MCP server to current project
aitools --addmcp vercel webflow  # Add multiple MCP servers

# Deploy to an endpoint (no repo needed -- run from deploy/)
# macOS/Linux:
bash deploy/setup-user-claude.sh
# Windows (PowerShell):
# .\deploy\setup-user-claude.ps1

# PDF conversion (requires marker or pymupdf)
python conversionutils/pdf_to_markdown.py --help
python conversionutils/pdf_to_man_markdown.py --help
```

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `C:\repos\ai-tooling` | `~/repos/ai-tooling` |
| User CLAUDE.md | `~/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `shared/claude-shared.md` (in repo) | `shared/claude-shared.md` (in repo) |

## Key Decisions

- **Marker** is the preferred PDF-to-markdown converter (better output than PyMuPDF alone)
- This directory is the **"home base"** for general/cross-project AI conversations
- Session notes are ephemeral; durable knowledge goes in CLAUDE.md or reference/ docs (auto-memory is local to each machine, not shared)
- Shared preferences live in `shared/claude-shared.md`, embedded into deploy scripts by `build-deploy.sh`
- `deploy/` scripts are self-contained (zero dependencies beyond bash/PowerShell) -- MDM-ready
- Each script has `.sh` + `.ps1` pair; OS guards reject wrong-platform execution
- `aitools` (bash) and `aitools.ps1` (PowerShell) are native per-platform CLIs -- no cross-shell dispatch
- `reference/tool-install-sources.md` is the source of truth for install commands -- always check before modifying installer scripts
- Only use official repos/orgs for docs; verify npm package ownership with `npm view <pkg> repository.url`
- `claude mcp add` can't run inside nested Claude Code sessions -- `--addmcp` has a node fallback

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI, `pathlib.Path` over `os.path`
- Scripts (this repo): provide both `.ps1` and `.sh` variants since this repo is cross-platform
- Keep this file under 200 lines; use `@reference/` imports for detail

@reference/claude-code-practices.md
@reference/cursor-practices.md
