# Cursor User Rules

**How to apply:** Copy everything below the `---` line and paste it into
**Cursor Settings > Rules** on each machine.

Source of truth: `shared/cursor-rules/user-rules.md` in the aitools repo.
No script deploys it: paste it into Cursor Settings by hand. (Cursor user rule
files from `~/.aitools/rules` are fanned out by `setup-user-cursor`.)

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

- aitools supports macOS, Windows, Linux (Ubuntu), Claude Code web and Cursor cloud; each is first-class (list: `~/.aitools/reference/cross-platform-detail.md`, "Supported platforms and environments")
- Use forward slashes and `$HOME`/`~` in path references when possible
- Projects live in git repos under `~/repos/` (macOS, Linux) / `%USERPROFILE%\repos\` (Windows)
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them

## Git Conventions

- Always set local git identity (`Jose <jose@nobul.tech>`) before first commit in a new repo
- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes

## Delegation Duty

- Load the `delegate` skill (`~/.cursor/skills/delegate/SKILL.md`) before every delegation (D-DEL7). Every delegation prompt (sub-agent, background agent, cloud agent) carries eight elements: identity; rules and CLAUDE.md files to read in full; skills (`delegate` first); operational learning; conflict priority (D-DEL6: the commander's own words, newest first, then the prompt, then skills); the `WRITE_BLOCKED` signal; explicit paths; the name prefix (D-DEL1: every `*.md` named `<name>-...`, e.g. `S2-report.md`)
- Delegates write versions (v1.0, v1.1, ...), never drafts (D-DEL5)
- Verify a delegate's output before relying on it

## Communication Style

- Be concise -- skip filler and caveats
- Explain the "why" behind non-obvious decisions
- Don't add docstrings, comments, or type annotations to code you didn't change
