# Shared Claude Code Preferences

These preferences apply to all Claude Code sessions across all projects.
Imported via `@` from user-level `~/.claude/CLAUDE.md` on each machine.

## Identity

- Name: Jose
- Git: `Jose <jose@nobul.tech>`
- Company: Nobul

## Code Style Defaults

- Prefer simple, minimal solutions over clever abstractions
- Use type hints in Python; use TypeScript over plain JS
- Favor standard library over third-party when the gap is small
- Write CLI tools with `--help` support

## Cross-Platform Awareness

- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either
- Use forward slashes and `$HOME`/`~` in path references
- Projects live in git repos under `~/repos/` (macOS) / `C:\repos\` (Windows)
- Some legacy projects still on Google Drive (`G:\My Drive\` / `~/Google Drive/My Drive/`) -- migrate to git repos over time
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing -- Windows doesn't set the Unix executable bit

## Tools & Workflow

- **Cursor**: IDE and workspace environment -- used to create projects, open folders, browse files, and use extensions. Provides embeddings
- **Claude Code**: AI coding assistant, run within Cursor's integrated terminal
- **Marker**: Preferred PDF-to-markdown converter

### Per-Platform Tools

- **macOS**: Terminal.app, zsh, bash, Cursor, Warp, Claude Code, pwsh (when PowerShell needed)
- **Windows**: PowerShell, Cursor, Claude Code, Command Prompt, WSL/bash (when Linux/Unix environment needed)
- **Note**: Claude Code on Windows always uses Git Bash (not configurable). Use Unix shell syntax in all Claude Code sessions regardless of platform.

## MCP Servers

Three servers at user level. Chrome DevTools enabled globally; Vercel/Webflow disabled by default.

- **Enable for project**: `aitools --addmcp vercel` (or `vercel webflow`)
- **Check status**: `aitools mcp`
- **Manual enable** (Claude Code): add `MCP(vercel)` to `.claude/settings.local.json` `permissions.allow`
- **Manual enable** (Cursor CLI): `agent mcp enable vercel`

## Knowledge Management

- **Strongly prefer CLAUDE.md and project docs over auto memory.** Auto memory (`~/.claude/projects/.../memory/`) is local to each machine and does not sync. Durable project knowledge belongs in git-tracked files: `CLAUDE.md`, `reference/`, or `.claude/rules/`.
- Auto memory should only hold ephemeral, machine-specific notes (e.g., tool quirks on this OS).
- **Planning workflow:** When starting a major plan, spot-check auto memory (`MEMORY.md`) and migrate any project knowledge into the repo before proceeding.

## Git Conventions

- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes
- Always set local git identity before first commit in a new repo
