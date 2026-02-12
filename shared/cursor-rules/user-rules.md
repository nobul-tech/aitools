# Cursor User Rules

**How to apply:** Copy everything below the `---` line and paste it into
**Cursor Settings > Rules** on each machine.

Source of truth: `shared/cursor-rules/user-rules.md` in the ai-tooling repo.
The `setup-user-cursor` script copies this to your clipboard automatically.

---

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

- I work on both Windows 11 and macOS — both are first-class
- Use forward slashes and `$HOME`/`~` in path references when possible
- Projects live in git repos under `~/repos/` (macOS) / `C:\repos\` (Windows)
- Some legacy projects still on Google Drive (`G:\My Drive\` / `~/Google Drive/My Drive/`) — migrate to git repos over time

## Git Conventions

- Always set local git identity (`Jose <jose@nobul.tech>`) before first commit in a new repo
- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes

## Communication Style

- Be concise — skip filler and caveats
- Explain the "why" behind non-obvious decisions
- Don't add docstrings, comments, or type annotations to code you didn't change
