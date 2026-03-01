# User Repo Pattern

Private per-user companion repo for session archives and profile data.

## Naming Convention

`aitools-<github-username>` (e.g., `aitools-nobul-jose`)

## Directory Structure

```
aitools-<username>/
├── profile.json          # User identity and machine inventory
├── claude/
│   ├── CLAUDE.md          # Personal CLAUDE.md template ({{PLACEHOLDER}} tokens)
│   └── rules/             # User-level Claude Code rules (deployed to ~/.claude/rules/)
│       └── concurrent-agents.md
├── sessions/             # Archived Claude Code transcripts
│   ├── aitools/          # One directory per project
│   │   └── 2026-02-19_abc12345.jsonl
│   └── mbx-ext/
│       └── 2026-02-17_e065274c.jsonl
└── README.md
```

## Profile Schema (v2)

`profile.json` separates global identity from per-machine profiles:

```json
{
  "version": 2,
  "identity": {
    "github": "<github-username>",
    "email": "<primary-email>",
    "git": { "name": "<git-name>", "email": "<git-email>" }
  },
  "cursor": {
    "cli": { "vimMode": true, "model": "auto" }
  },
  "claude": {
    "autoMemory": false,
    "alwaysThinking": true
  },
  "profiles": {
    "<alias>": {
      "name": "<display-name>",
      "company": "<company>",
      "machine": {
        "hostname": "<hostname>",
        "os": "<platform>",
        "arch": "<arch>",
        "shell": "<shell>"
      }
    }
  },
  "overrides": {
    "<tool-name>": {
      "<flag-or-setting>": {
        "reason": "<why this deviates from upstream>",
        "added": "<YYYY-MM-DD>"
      }
    }
  }
}
```

- **`identity`** -- global, shared across all machines. Git identity, GitHub username, primary email.
- **`cursor`** -- Cursor CLI preferences. Read by `setup-user-cursor`.
- **`claude`** -- Claude Code settings preferences. Read by `setup-user-hooks`. Keys: `autoMemory` (default true), `alwaysThinking` (default true). Maps to `autoMemoryEnabled` / `alwaysThinkingEnabled` in `~/.claude/settings.json`.
- **`profiles`** -- keyed by user-chosen alias (e.g., "laptop", "workstation"). Display name and company can vary per machine.
- **`overrides`** -- intentional deviations from upstream tool defaults. Informational only -- CLI does not read this yet. Mirrors the Overrides table in `reference/tool-install-sources.md` in machine-readable form. Future `aitools audit` could validate overrides against live config.
- **Machine matching** -- `config.json` stores `"machineAlias"` on each machine. Fallback: hostname match, then first profile.
- **v1 migration** -- v1 (flat schema) is auto-detected by absence of `"version": 2`. Future `aitools user init` will migrate v1 to v2.

## Session Naming

`<YYYY-MM-DD>_<session-id-prefix-8>.jsonl`

- Date: session creation date (from transcript file birth time, fallback to today)
- Session ID prefix: first 8 characters of the Claude Code session ID

## Project Derivation

Sessions are filed under a project name derived from the working directory:

1. If cwd is inside a git repo: `basename $(git rev-parse --show-toplevel)`
2. Otherwise: sanitized basename of cwd (lowercased, non-alphanumeric replaced with `-`)

**Known limitation:** cwd may not match the project being worked on (e.g., running Claude Code from `~/scratch` while working on `mbx-ext`). Use `aitools sessions move` to refile.

## Config Schema

`~/.aitools/config.json` stores per-machine aitools configuration.

### v2 (current)

Added `userRepoPath` and `machineAlias` fields for user repo support.

```json
{
  "version": 2,
  "reposPath": "/Users/pepe/repos",
  "repoPath": "/Users/pepe/repos/aitools",
  "userRepoPath": "/Users/pepe/repos/aitools-nobul-jose",
  "machineAlias": "laptop",
  "googleDrives": [
    { "path": "...", "account": "user@example.com", "label": "" }
  ]
}
```

- **`version`** -- schema version. Bump when fields are added, removed, or semantically changed.
- **`reposPath`** -- base directory for git repos. Set by `aitools install`.
- **`repoPath`** -- path to the aitools repo. Set by `aitools install`.
- **`userRepoPath`** -- path to the user's private companion repo. Set by `aitools user init`.
- **`machineAlias`** -- selects the profile from `profile.json`. Set during `user init` or manually.
- **`googleDrives`** -- auto-detected Google Drive mount points. Set by `aitools install`.

All fields use read-then-merge: re-running the installer preserves existing values and adds new ones.

### v1 (original)

Only `reposPath`, `repoPath` (originally `aiToolingRepoPath`), and `googleDrives`. No user repo support.

### Migration (v1 to v2)

v1 configs are additive-compatible -- existing fields are preserved. The installer detects existing `userRepoPath` and `machineAlias` and preserves them during re-runs. Running `aitools install` on a v1 config upgrades it to v2.

## Archiving Mechanism

A Claude Code `SessionEnd` hook copies transcript files to the user repo after each session ends.
The hook source lives at `shared/hooks/session-archive.sh` in the aitools repo. Setup scripts
(`scripts/` and `deploy/` variants) copy it to `~/.claude/hooks/session-archive.sh` and point
the `settings.json` hook command to the deployed copy. The hook:

- Reads `userRepoPath` from config
- Derives project name from the session's working directory
- Copies the transcript JSONL to `sessions/<project>/<date>_<prefix>.jsonl`
- Silently skips if config is missing or user repo doesn't exist
- Never runs git operations (user commits/pushes on their own schedule)

## Template Resolution (CLAUDE.md)

Setup scripts read CLAUDE.md templates in priority order:

1. `<userRepoPath>/claude/CLAUDE.md` -- personal template (syncs across machines via git)
2. `aitools/shared/claude-shared.md` -- fallback for users without a companion repo

Both templates use `{{PLACEHOLDER}}` tokens interpolated from `profile.json`:
- `{{PROFILE_NAME}}`, `{{PROFILE_COMPANY}}`, `{{IDENTITY_GIT_NAME}}`, `{{IDENTITY_GIT_EMAIL}}`

The deployed file at `~/.claude/CLAUDE.md` includes an auto-appended `## Machine-Specific`
footer with OS, hostname, and shell from the current machine's profile.

## User Rules Deployment

Setup scripts deploy user-level Claude Code rules from `<userRepoPath>/claude/rules/` to `~/.claude/rules/`.

**Semantics**: additive deploy — managed files are added/updated, unmanaged files in the target are preserved.

- **Source**: `<userRepoPath>/claude/rules/*.md`
- **Target**: `~/.claude/rules/*.md`
- **Backup**: full directory copy (`rules.bak.<TIMESTAMP>/`), max 5, auto-prune
- **Diff logging**: unified diff of changes logged to deploy log; console shows summary
- **Managed vs preserved**: files matching a source file are managed; all other files in the target are preserved and logged

**Scope guidance**: user-level rules should be universal conventions that apply across all projects. Project-specific rules belong in `.claude/rules/` within the project repo.

**Build-time embedding**: `build-deploy.sh` reads user rules at build time and embeds them in deploy scripts via heredocs. If no rules exist at build time, deploy scripts skip rules deployment.

## Relationship to aitools

The user repo is a companion to `aitools`, not a submodule. It contains personal data (session transcripts, profile) that shouldn't be in the shared repo. The `aitools` repo provides the hook script and CLI commands that operate on the user repo.

## What Stays in aitools/shared/

The `shared/` directory contains framework content shared across all users.
User repos hold personal data only. This boundary is intentional:

| aitools/shared/ | Purpose | Why not user repo |
|--------------------|---------|-------------------|
| `claude-shared.md` | Fallback CLAUDE.md template | Bootstrap for new users; user repo takes priority |
| `hooks/session-archive.sh` | SessionEnd hook source (deployed to `~/.claude/hooks/`) | Framework code operating on user data |
| `shell/aliases.sh` + `.ps1` | Cross-platform shell aliases | Shared tooling, not personal |
| `skills/` | Chrome DevTools / a11y skills | Vendored from upstream |
| `mcp/` | MCP server config docs | Reference docs |
| `cursor-rules/` | Template Cursor rules | Project-level, not personal |

## CLI Commands

| Command | Description |
|---------|-------------|
| `aitools user init` | Set up user repo and configure hook |
| `aitools sessions list [project]` | List archived sessions |
| `aitools sessions archive <session-id>` | Manually archive a session |
| `aitools sessions move <file> <project>` | Refile a session under a different project |

## Known Limitations

### `sessions move` is archive-only

`aitools sessions move` refiles the archived transcript in the user repo's `sessions/`
directory. It does **not** affect Claude Code's internal session resolution, which is
tied to the sanitized CWD path in `~/.claude/projects/`. A session started from
`/Users/pepe/repos/ai-tooling` will always resolve to the `-Users-pepe-repos-ai-tooling/`
directory -- `sessions move` only changes where the archive copy lives.
