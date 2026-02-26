# Claude Code Practices & Setup Notes

Baseline: Claude Code 2.1.51 (2026-02-16)

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
- **Template source** (priority order):
  1. `<userRepoPath>/claude/CLAUDE.md` -- personal copy in the user's dotfile repo (syncs across machines via git). Contains `{{PLACEHOLDER}}` tokens.
  2. `shared/claude-shared.md` -- fallback template in the ai-tooling repo.
- **Deploy flow** (`scripts/setup-user-claude.sh/.ps1`):
  1. Read template from user repo (fallback: shared template)
  2. Read `profile.json` from user repo to get identity values for current machine
  3. Interpolate `{{PLACEHOLDER}}` tokens (`PROFILE_NAME`, `PROFILE_COMPANY`, `IDENTITY_GIT_NAME`, `IDENTITY_GIT_EMAIL`)
  4. Append `## Machine-Specific` footer (OS, hostname, shell)
  5. Write to `~/.claude/CLAUDE.md`
- **MDM deploy** (`deploy/setup-user-claude.sh/.ps1`): Self-contained with build-time embedded content. No repo or profile needed.
- **Scaffolding**: `aitools user init` copies `shared/claude-shared.md` to `<userRepoPath>/claude/CLAUDE.md` if missing.

## Session Management Commands

| Command | What it does |
|---------|--------------|
| `claude -c` | Resume most recent session in current directory |
| `claude --resume` | Interactive session picker (current directory only) |
| `claude --resume "name"` | Resume a named session |
| `/resume` | Switch sessions from inside a running session |
| `/rename <name>` | Name the current session for easy recall |
| `claude --continue --fork-session` | Fork current session into a new one |

## Session Storage Internals

Claude Code stores session transcripts as JSONL files under `~/.claude/projects/`:

```
~/.claude/projects/
├── -Users-pepe-repos-ai-tooling/     # sanitized CWD path
│   ├── <session-uuid>.jsonl
│   └── <session-uuid>/subagents/     # subagent transcripts
└── -Users-pepe-repos-mbx-ext/
    └── ...
```

### Path Sanitization

The project directory name is the CWD with `/` replaced by `-`. This is **lossy** for project names containing hyphens — you cannot split on `-` to recover the project name.

Example: `/Users/pepe/repos/ai-tooling` becomes `-Users-pepe-repos-ai-tooling`. Naive split yields `tooling`, not `ai-tooling`.

**Correct approach:** Read the `cwd` field from the JSONL transcript, then derive the project name from the real path.

### JSONL Transcript Structure

Each line is a JSON object. Fields available in most entries:

- `type` — message type (`human`, `assistant`)
- `cwd` — original working directory (absolute path)
- `sessionId` — full session UUID

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
- [x] Shared rules in repo (`shared/claude-shared.md`), embedded into deploy scripts by `build-deploy.sh`
- [x] Shell alias (`cc`) for auto-CLAUDE.md check (see `shared/shell/`)
- [x] "Home base" directory for general conversations: this repo (`ai-tooling/`)
- [x] Self-contained deploy scripts in `deploy/` — MDM-ready, no repo or Drive dependency
