# User Repo Pattern

Private per-user companion repo for session archives and profile data.

## Naming Convention

`aitools-<github-username>` (e.g., `aitools-nobul-jose`)

## Directory Structure

```
aitools-<username>/
├── profile.json          # User identity and machine inventory
├── sessions/             # Archived Claude Code transcripts
│   ├── ai-tooling/       # One directory per project
│   │   └── 2026-02-19_abc12345.jsonl
│   └── mbx-ext/
│       └── 2026-02-17_e065274c.jsonl
└── README.md
```

## Session Naming

`<YYYY-MM-DD>_<session-id-prefix-8>.jsonl`

- Date: session creation date (from transcript file birth time, fallback to today)
- Session ID prefix: first 8 characters of the Claude Code session ID

## Project Derivation

Sessions are filed under a project name derived from the working directory:

1. If cwd is inside a git repo: `basename $(git rev-parse --show-toplevel)`
2. Otherwise: sanitized basename of cwd (lowercased, non-alphanumeric replaced with `-`)

**Known limitation:** cwd may not match the project being worked on (e.g., running Claude Code from `~/scratch` while working on `mbx-ext`). Use `aitools sessions move` to refile.

## Configuration

The user repo path is stored in `~/.config/ai-tooling/config.json`:

```json
{
  "userRepoPath": "/Users/pepe/repos/aitools-nobul-jose"
}
```

Set automatically by `aitools user init` or manually.

## Archiving Mechanism

A Claude Code `SessionEnd` hook (`shared/hooks/session-archive.sh`) copies transcript files to the user repo after each session ends. The hook:

- Reads `userRepoPath` from config
- Derives project name from the session's working directory
- Copies the transcript JSONL to `sessions/<project>/<date>_<prefix>.jsonl`
- Silently skips if config is missing or user repo doesn't exist
- Never runs git operations (user commits/pushes on their own schedule)

## Relationship to ai-tooling

The user repo is a companion to `ai-tooling`, not a submodule. It contains personal data (session transcripts, profile) that shouldn't be in the shared repo. The `ai-tooling` repo provides the hook script and CLI commands that operate on the user repo.

## CLI Commands

| Command | Description |
|---------|-------------|
| `aitools user init` | Set up user repo and configure hook |
| `aitools sessions list [project]` | List archived sessions |
| `aitools sessions archive <session-id>` | Manually archive a session |
| `aitools sessions move <file> <project>` | Refile a session under a different project |
