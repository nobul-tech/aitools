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

- I work on both Windows 11 and macOS — both are first-class, ensure a seamless experience on either
- Use forward slashes and `$HOME`/`~` in path references
- Google Drive syncs between machines at:
  - Windows: `G:\My Drive\`
  - macOS: `~/Google Drive/My Drive/`
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing — Windows doesn't set the Unix executable bit

## Tools & Workflow

- **Cursor**: Primary IDE — used to create projects, open folders, browse files, and use extensions. Provides embeddings and is the main workspace environment
- **Claude Code**: Primary AI coding assistant, run within the Cursor integrated terminal
- **Warp**: AI-native terminal (macOS)
- **Marker**: Preferred PDF-to-markdown converter

## Git Conventions

- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes
- Always set local git identity before first commit in a new repo
