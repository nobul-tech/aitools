# ai-tooling

Cross-machine AI tooling hub — shared configs, rules, and scripts for Claude Code, Cursor, Warp, and MCP across Windows 11 and macOS.

## What's here

| Directory | Purpose |
|-----------|---------|
| `shared/` | Cross-machine configs synced via Google Drive: Claude shared preferences, Cursor rule templates, shell aliases, MCP configs |
| `scripts/` | Setup scripts for Claude Code, Cursor, and MCP configuration on new machines |
| `.claude/rules/` | Claude Code project rules (git identity, cross-platform, Python style) |
| `.cursor/rules/` | Cursor project rules (.mdc format) |
| `conversionutils/` | PDF-to-markdown conversion utilities (Marker + PyMuPDF) |
| `docs/` | RAG knowledge base — vendor documentation (Quantum/StorNext) |
| `reference/` | Setup notes and how-tos for AI tool configuration |

## Quick start

**Set up user-level Claude Code config:**

```powershell
# Windows
.\scripts\setup-user-claude.ps1

# macOS
bash scripts/setup-user-claude.sh
```

**Set up Cursor CLI + User Config:**

```powershell
# Windows
.\scripts\setup-user-cursor.ps1

# macOS
bash scripts/setup-user-cursor.sh
```

**Set up Claude Code MCP servers:**

```powershell
# Windows
.\scripts\setup-user-mcp.ps1

# macOS
bash scripts/setup-user-mcp.sh
```

**Set up Cursor MCP servers:**

```powershell
# Windows
.\scripts\setup-cursor-mcp.ps1

# macOS
bash scripts/setup-cursor-mcp.sh
```

**Add shell aliases** (optional):

```bash
# bash/zsh — add to ~/.bashrc or ~/.zshrc
source "/path/to/ai-tooling/shared/shell/aliases.sh"
```

```powershell
# PowerShell — add to $PROFILE
. "G:\My Drive\nobul co\ai-tooling\shared\shell\aliases.ps1"
```

**PDF conversion:**

```bash
python conversionutils/pdf_to_markdown.py input.pdf -o output.md
python conversionutils/pdf_to_man_markdown.py input.pdf -o output.md
```

## License

MIT
