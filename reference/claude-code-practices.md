# Claude Code Practices & Setup Notes

Reference notes extracted from session setup work. For project instructions, see the root `CLAUDE.md`.

---

## Session Sync Across Devices

- Claude Code CLI sessions are **local to each machine** and do **not sync** across devices.
- Claude Code web (claude.ai) sessions are separate from CLI sessions entirely.
- Sessions are also **tied to the directory** they were started in — you can only resume from the same directory.
- Syncing raw session files (JSONL) via git is **not recommended** — they contain absolute paths, aren't portable across OS, and there's no `--resume <file>` mechanism.
- **Best practice:** Use `CLAUDE.md` and auto-memory as the cross-device "session transfer" layer. Put valuable decisions and context there, let sessions be ephemeral.

## CLAUDE.md Hierarchy (5 levels)

| Level | Path | Scope |
|-------|------|-------|
| Managed (org/IT) | `C:\Program Files\ClaudeCode\CLAUDE.md` | All users on machine |
| **User (personal global)** | `~/.claude/CLAUDE.md` | You, all projects, this machine |
| **Project (team)** | `./CLAUDE.md` in repo root | All team members via git |
| Project (personal) | `./CLAUDE.local.md` | You only, auto-gitignored |
| Subdirectory | `./some-dir/CLAUDE.md` | Loaded on-demand when working in that dir |

All levels merge together. More specific wins on conflict.

## User-Level CLAUDE.md Setup

- Applies to **every** Claude Code session on that machine, regardless of project.
- Locations:
  - Windows: `C:\Users\jdpal\.claude\CLAUDE.md`
  - Mac: `~/.claude/CLAUDE.md`
- For shared rules across machines, use `@import` syntax pointing to a synced location (e.g., Google Drive).
- Setup scripts: `scripts/setup-user-claude.ps1` (Windows), `scripts/setup-user-claude.sh` (macOS)

## Session Management Commands

| Command | What it does |
|---------|--------------|
| `claude -c` | Resume most recent session in current directory |
| `claude --resume` | Interactive session picker (current directory only) |
| `claude --resume "name"` | Resume a named session |
| `/resume` | Switch sessions from inside a running session |
| `/rename <name>` | Name the current session for easy recall |
| `claude --continue --fork-session` | Fork current session into a new one |

## Best Practices for CLAUDE.md Content

**Include:** build/test/lint commands, code style rules, project architecture, gotchas, tool preferences.
**Exclude:** things Claude can infer from code, standard conventions, long tutorials, frequently-changing info.
**Size:** Keep under 200 lines (auto-load limit). Use `@path` imports for more detail.

## Auto-Creating CLAUDE.md in New Projects

- No built-in auto-create. Use `claude /init` to scaffold per project.
- Use the `cc` shell alias (see `shared/shell/`) that checks for CLAUDE.md before launching.

## Machines

| Machine | OS | IDE | Claude Code |
|---------|-----|-----|-------------|
| Workstation | Windows 11 Pro for Workstations | Cursor | CLI (in Cursor terminal) |
| Laptop | macOS | Cursor | CLI (in Cursor terminal) |
| Web | Any browser | — | claude.ai (separate sessions) |

---

## Setup Checklist

- [x] Create `~/.claude/CLAUDE.md` on Windows workstation (via `scripts/setup-user-claude.ps1`)
- [x] Create `~/.claude/CLAUDE.md` on Mac laptop (via `scripts/setup-user-claude.sh`)
- [x] Shared rules file in Google Drive with `@import` from both machines (`shared/claude-shared.md`)
- [x] Shell alias (`cc`) for auto-CLAUDE.md check (see `shared/shell/`)
- [x] "Home base" directory for general conversations: this repo (`ai-tooling/`)
