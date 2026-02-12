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

- I work on Windows 11 (primary) and macOS (secondary)
- Use forward slashes and `$HOME`/`~` in path references
- Google Drive syncs between machines at:
  - Windows: `G:\My Drive\`
  - macOS: `~/Google Drive/My Drive/`
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing — Windows doesn't set the Unix executable bit

## Tools

- **Claude Code**: Primary AI coding assistant (CLI in VS Code terminal)
- **Cursor**: AI-native editor (secondary, for exploration)
- **Warp**: AI-native terminal (macOS)
- **Marker**: Preferred PDF-to-markdown converter

## Git Conventions

- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes
- Always set local git identity before first commit in a new repo
