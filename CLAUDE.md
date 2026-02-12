# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, Warp, and MCP across Windows and macOS.

## Project Structure

```
ai-tooling/
├── .claude/rules/       # Claude Code project rules (modular)
├── .cursor/rules/       # Cursor rules (.mdc format)
├── shared/              # Cross-machine shared configs (synced via Drive)
│   ├── claude-shared.md # @import target for user-level CLAUDE.md
│   ├── cursor-rules/    # Template rules for scaffolding new projects
│   ├── shell/           # Shell aliases (bash/zsh + PowerShell)
│   └── mcp/             # MCP server configs (placeholder)
├── scripts/             # Setup scripts (Windows + macOS)
├── conversionutils/     # PDF-to-markdown conversion tools
├── docs/                # RAG knowledge base (vendor docs)
└── reference/           # Setup notes and how-tos
```

## Git Identity

- Name: `Jose`
- Email: `jose@nobul.tech`

## Build & Run

```bash
# PDF conversion (requires marker or pymupdf)
python conversionutils/pdf_to_markdown.py --help
python conversionutils/pdf_to_man_markdown.py --help

# Setup user-level CLAUDE.md
# Windows:  .\scripts\setup-user-claude.ps1
# macOS:    bash scripts/setup-user-claude.sh
```

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `G:\My Drive\nobul co\ai-tooling` | `~/Google Drive/My Drive/nobul co/ai-tooling` |
| User CLAUDE.md | `C:\Users\jdpal\.claude\CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `G:\My Drive\nobul co\ai-tooling\shared\claude-shared.md` | Via Google Drive sync |

## Key Decisions

- **Marker** is the preferred PDF-to-markdown converter (better output than PyMuPDF alone)
- This directory is the **"home base"** for general/cross-project AI conversations
- Session notes are ephemeral; durable knowledge goes in CLAUDE.md or auto-memory
- Shared preferences live in `shared/claude-shared.md`, imported via `@` from user-level CLAUDE.md

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI, `pathlib.Path` over `os.path`
- Scripts: always provide both `.ps1` and `.sh` variants
- Keep this file under 200 lines; use `@reference/` imports for detail

@reference/claude-code-practices.md
