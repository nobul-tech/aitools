# Scripts

Setup and utility scripts for configuring AI tooling across machines.

## Setup Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `setup-user-claude.ps1` | Windows | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-claude.sh` | macOS/Linux | Creates `~/.claude/CLAUDE.md` with shared import |

## Usage

**Windows (PowerShell):**
```powershell
.\scripts\setup-user-claude.ps1
```

**macOS/Linux:**
```bash
bash scripts/setup-user-claude.sh
```

Both scripts are safe to re-run — they replace the existing `~/.claude/CLAUDE.md` with the latest version.
