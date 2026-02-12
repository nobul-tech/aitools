# AI Tooling Setup & Practices

This workspace tracks Jose's AI tooling configuration, preferences, and setup notes across machines (Windows 11 workstation + macOS laptop).

---

## Context from prior session

This continues a conversation originally held in `G:\My Drive\nobul co\ess` (session name: `ai-tooling-setup`). Key topics covered:

### Session sync across devices

- Claude Code CLI sessions are **local to each machine** and do **not sync** across devices.
- Claude Code web (claude.ai) sessions are separate from CLI sessions entirely.
- Sessions are also **tied to the directory** they were started in — you can only resume from the same directory.
- Syncing raw session files (JSONL) via git is **not recommended** — they contain absolute paths, aren't portable across OS, and there's no `--resume <file>` mechanism.
- **Best practice:** Use `CLAUDE.md` and auto-memory as the cross-device "session transfer" layer. Put valuable decisions and context there, let sessions be ephemeral.

### CLAUDE.md hierarchy (5 levels)

| Level | Path | Scope |
|-------|------|-------|
| Managed (org/IT) | `C:\Program Files\ClaudeCode\CLAUDE.md` | All users on machine |
| **User (personal global)** | `~/.claude/CLAUDE.md` | You, all projects, this machine |
| **Project (team)** | `./CLAUDE.md` in repo root | All team members via git |
| Project (personal) | `./CLAUDE.local.md` | You only, auto-gitignored |
| Subdirectory | `./some-dir/CLAUDE.md` | Loaded on-demand when working in that dir |

All levels merge together. More specific wins on conflict.

### User-level CLAUDE.md (`~/.claude/CLAUDE.md`)

- Applies to **every** Claude Code session on that machine, regardless of project.
- Create on both machines:
  - Windows: `C:\Users\jdpal\.claude\CLAUDE.md`
  - Mac: `~/.claude/CLAUDE.md`
- For shared rules across machines, use `@import` syntax pointing to a synced location (e.g., Google Drive).

### Auto-creating CLAUDE.md in new projects

- No built-in auto-create. Use `claude /init` to scaffold per project.
- Optionally wrap with a shell alias (`cc`) that checks for CLAUDE.md before launching.

### Session management commands

| Command | What it does |
|---------|--------------|
| `claude -c` | Resume most recent session in current directory |
| `claude --resume` | Interactive session picker (current directory only) |
| `claude --resume "name"` | Resume a named session |
| `/resume` | Switch sessions from inside a running session |
| `/rename <name>` | Name the current session for easy recall |
| `claude --continue --fork-session` | Fork current session into a new one |

### Best practices for CLAUDE.md content

**Include:** build/test/lint commands, code style rules, project architecture, gotchas, tool preferences.
**Exclude:** things Claude can infer from code, standard conventions, long tutorials, frequently-changing info.
**Size:** Keep under 200 lines (auto-load limit). Use `@path` imports for more detail.

---

## TODO / Open items

- [ ] Create `~/.claude/CLAUDE.md` on Windows workstation
- [ ] Create `~/.claude/CLAUDE.md` on Mac laptop
- [ ] Consider shared rules file in Google Drive with `@import` from both machines
- [ ] Set up shell alias (`cc`) for auto-CLAUDE.md check on both machines
- [ ] Decide on a "home base" directory for general/cross-project conversations (this directory?)

---

## Git Identity

When working with git in any workspace or repo:

- `git config --global user.name "Jose"`
- `git config --global user.email "jose@nobul.tech"`

---

## Machines

| Machine | OS | Claude Code | Notes |
|---------|-----|-------------|-------|
| Workstation | Windows 11 Pro for Workstations | CLI (VS Code) | Primary |
| Laptop | macOS | CLI | Secondary |
| Web | Any browser | claude.ai | Separate sessions |
