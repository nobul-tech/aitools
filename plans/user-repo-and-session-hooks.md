# User Repo & Session Auto-Archive

- **Status**: Phase A implemented (macOS verified, Windows untested)
- **Priority**: High
- **Created**: 2026-02-19
- **Origin**: Sessions `e065274c` + `7cae3cc3` — designed the per-profile user repo pattern

## Problem

Claude Code session transcripts accumulate in `~/.claude/projects/` with opaque names and no organization. They're not backed up, not searchable by project, and will eventually be pruned by Claude Code itself. Additionally, `shared/claude-shared.md` contains Jose-specific identity that should live in a per-user profile for multi-profile support.

## Solution

Two-phase approach:

1. **Phase A** — Session auto-archive via Claude Code SessionEnd hook + CLI commands
2. **Phase B** — Templatize `shared/claude-shared.md` with profile-driven interpolation

The private user repo `aitools-nobul-jose` already exists at `~/repos/aitools-nobul-jose/` (created in session `7cae3cc3`).

---

## Phase A: Session Auto-Archive

### A1. Reference Documentation

**File**: `reference/user-repo.md`

Document the user repo pattern:

- Naming convention: `aitools-<gh-username>`
- Directory structure (sessions/, profile.json)
- Session naming: `<YYYY-MM-DD>_<session-id-prefix-8>.jsonl`
- Project derivation logic (git toplevel → basename, else sanitized cwd basename)
- Known limitation: cwd may not match the project being worked on (e.g., working on mbx-ext from ~/scratch)
- Relationship to ai-tooling (companion, not submodule)
- Config key: `userRepoPath` in `~/.config/ai-tooling/config.json`

### A2. Stop Hook Script

**File**: `shared/hooks/session-archive.sh`

Claude Code SessionEnd hook that fires after every session ends. Bash-only (hooks always execute in bash on both platforms — no `.ps1` needed).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Claude Code SessionEnd hook — archives session transcript to user repo
# Input: JSON on stdin with { session_id, cwd, transcript_path, ... }

INPUT=$(cat)
SESSION_ID=$(json_field "$INPUT" "session_id")
CWD=$(json_field "$INPUT" "cwd")
TRANSCRIPT=$(json_field "$INPUT" "transcript_path")

# Read user repo path from ai-tooling config
CONFIG_FILE="${HOME}/.config/ai-tooling/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0  # Silently skip if ai-tooling not configured
fi

USER_REPO=$(grep -o '"userRepoPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
    | sed 's/.*"userRepoPath"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

if [ -z "$USER_REPO" ] || [ ! -d "$USER_REPO" ]; then
    exit 0  # Silently skip if user repo not configured or missing
fi

# Derive project name
REPO_ROOT=$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ]; then
    PROJECT=$(basename "$REPO_ROOT")
else
    PROJECT=$(basename "$CWD" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g')
fi

# Derive date from transcript file creation or fall back to today
if [ "$(uname -s)" = "Darwin" ]; then
    DATE=$(stat -f "%SB" -t "%Y-%m-%d" "$TRANSCRIPT" 2>/dev/null || date -u +%Y-%m-%d)
else
    DATE=$(stat -c "%W" "$TRANSCRIPT" 2>/dev/null | xargs -I{} date -u -d @{} +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)
fi

# Session ID prefix (first 8 chars)
PREFIX=$(echo "$SESSION_ID" | cut -c1-8)

# Target path
DEST_DIR="${USER_REPO}/sessions/${PROJECT}"
DEST_FILE="${DEST_DIR}/${DATE}_${PREFIX}.jsonl"

# Skip if already archived
if [ -f "$DEST_FILE" ]; then
    exit 0
fi

mkdir -p "$DEST_DIR"
cp "$TRANSCRIPT" "$DEST_FILE"
```

**Important design decisions:**
- Silent exit on any misconfiguration (hook must never break Claude Code)
- No git operations inside the hook (user commits/pushes on their own schedule)
- Uses pure-bash JSON extraction (`grep` + `sed`), matching the `read_config_key` pattern in `aitools`
- Creation date for naming (session start date), not modification date

**Resolved:** SessionEnd hooks provide `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `reason`.

### A3. Hook Setup Script

**Files**: `scripts/setup-user-hooks.sh` + `scripts/setup-user-hooks.ps1`

Deploys hook configuration to `~/.claude/settings.json`. Following ai-tooling conventions:

- OS guard at top
- Structured logging
- Backup before overwrite
- Reads/merges existing settings.json (don't clobber user's other hooks)

The hook config in `~/.claude/settings.json`:
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/ai-tooling/shared/hooks/session-archive.sh"
          }
        ]
      }
    ]
  }
}
```

**Note on `scripts/` vs `deploy/`**: Hook setup scripts go in `scripts/` (require repo), not `deploy/` (self-contained). The hook script itself (`shared/hooks/session-archive.sh`) runs from the repo path, so the repo must be present. This matches the existing pattern where `scripts/` contains repo-dependent scripts.

**Build integration**: `build-deploy.sh` does NOT need to embed this — the hook runs directly from the repo. Only the setup script (which writes `settings.json`) needs the repo path, and it already knows it from `config.json`.

### A4. CLI Subcommands

**File**: `scripts/aitools` (extend existing CLI)

New command group pattern — add alongside existing `mcp` command:

#### `aitools user init`

Interactive setup for the user repo:
1. Prompt for GitHub username (or detect from `gh auth status`)
2. Check if `aitools-<username>` repo exists locally
3. If not, create directory structure + `git init` + `profile.json`
4. Optionally create private GitHub repo via `gh repo create`
5. Write `userRepoPath` to `~/.config/ai-tooling/config.json`
6. Deploy SessionEnd hook via `setup-user-hooks.sh`

#### `aitools sessions list`

List archived sessions, optionally filtered by project:
```bash
aitools sessions list                    # All projects
aitools sessions list mbx-ext            # Specific project
```

Output:
```
mbx-ext/2026-02-17_e065274c.jsonl  (787K)
mbx-ext/2026-02-17_7cae3cc3.jsonl  (1.5M)
ai-tooling/2026-02-19_abc12345.jsonl  (423K)
```

#### `aitools sessions archive <session-id>`

Manually archive a specific session (same logic as the SessionEnd hook, but triggered manually). Useful for sessions that started before the hook was installed.

#### `aitools sessions move <session-file> <project>`

Refile a session under a different project:
```bash
aitools sessions move scratch/2026-02-17_7cae3cc3.jsonl mbx-ext
```

This handles the known limitation where cwd doesn't match the actual project.

### A5. Config Extension

**File**: `~/.config/ai-tooling/config.json`

Add `userRepoPath` key. The installer (`aitools-install.sh/.ps1`) should detect and set this if the user repo exists. Example:

```json
{
  "aiToolingRepoPath": "/Users/pepe/repos/ai-tooling",
  "userRepoPath": "/Users/pepe/repos/aitools-nobul-jose",
  "googleDrives": ["/Users/pepe/Library/CloudStorage/GoogleDrive-jose@strat-accs.com"]
}
```

### A6. Integration with Existing Commands

- **`aitools` (no args)**: After deploy, also verify hook is installed (warn if missing)
- **`aitools install`**: Prompt for user repo setup if `userRepoPath` not configured
- **`aitools --help`**: Add `user` and `sessions` to help output

---

## Phase B: shared/ Refactoring (Follow-on)

### B1. Templatize shared/claude-shared.md

Replace personal identity with placeholders. Identity fields come from `identity.*`, display fields from the active profile:

```markdown
## Identity

- Name: {{PROFILE_NAME}}
- Git: `{{IDENTITY_GIT_NAME}} <{{IDENTITY_GIT_EMAIL}}>`
- Company: {{PROFILE_COMPANY}}
```

Machine-specific section:
```markdown
## Machine-Specific

- Machine: {{MACHINE_OS}} {{MACHINE_ARCH}} ({{MACHINE_HOSTNAME}})
- Shell: {{MACHINE_SHELL}}
```

Remove coaching section from shared (move to profile.json or a separate personal file in user repo).

### B2. Profile Values

Source: `aitools-<username>/profile.json` (v2 schema, implemented):

```json
{
  "version": 2,
  "identity": {
    "github": "nobul-jose",
    "email": "jose@nobul.tech",
    "git": { "name": "Jose", "email": "jose@nobul.tech" }
  },
  "profiles": {
    "laptop": {
      "name": "Jose",
      "company": "Nobul",
      "machine": { "hostname": "Joses-MBP", "os": "darwin", "arch": "arm64", "shell": "zsh" }
    },
    "workstation": {
      "name": "pepe",
      "company": "nobul.tech",
      "machine": { "hostname": "NewcoPC", "os": "win32", "arch": "x64", "shell": "powershell" }
    }
  }
}
```

Machine selection: `config.json` on each machine stores `"machineAlias"`. Build reads alias, selects matching profile. Fallback chain: alias -> hostname match -> first profile.

Template placeholder mapping:
- `{{IDENTITY_GIT_NAME}}`, `{{IDENTITY_GIT_EMAIL}}` -- from `identity.git`
- `{{IDENTITY_GITHUB}}` -- from `identity.github`
- `{{PROFILE_NAME}}`, `{{PROFILE_COMPANY}}` -- from `profiles.<alias>`
- `{{MACHINE_OS}}`, `{{MACHINE_ARCH}}`, `{{MACHINE_HOSTNAME}}`, `{{MACHINE_SHELL}}` -- from `profiles.<alias>.machine`

### B3. Build Integration

`build-deploy.sh` changes:
1. Read `machineAlias` and `userRepoPath` from config
2. Read `profile.json` from user repo, detect version
3. If v2: select profile by alias (fallback: hostname, then first)
4. If v1: use flat fields directly (backwards compat)
5. Read `shared/claude-shared.md` as template
6. Interpolate placeholders with identity + selected profile values
7. Embed interpolated content into deploy scripts (same as today)

**Fallback**: If no profile.json found, use current hardcoded values and warn. This ensures `build-deploy.sh` doesn't break for users who haven't set up a user repo yet.

### B4. Migration Path

For Jose (existing user):
1. `profile.json` already exists in `aitools-nobul-jose`
2. Run `aitools` after Phase B implementation
3. Build regenerates deploy scripts with interpolated values
4. Deploy writes `~/.claude/CLAUDE.md` — identical content, new source of truth
5. Verify: `diff` old vs new CLAUDE.md should show no changes

For new users:
1. `aitools user init` creates profile.json with prompted values
2. `aitools install` builds and deploys with their identity
3. No manual editing of `shared/claude-shared.md` needed

---

## Implementation Order

```
Phase A (this session or next):
  A1  reference/user-repo.md               — docs first
  A2  shared/hooks/session-archive.sh       — the hook script
  A3  scripts/setup-user-hooks.sh + .ps1    — deploys the hook
  A4  scripts/aitools (extend)              — user + sessions commands
  A5  config.json extension                 — userRepoPath
  A6  integration touchpoints               — help, install, no-args

Phase B (follow-on, after Phase A is stable):
  B1  shared/claude-shared.md               — templatize
  B2  profile.json schema                   — finalize
  B3  scripts/build-deploy.sh               — interpolation
  B4  migration + testing                   — verify identical output
```

## Resolved Questions

1. **Claude Code hook schema** — `SessionEnd` (not `Stop`) is the correct event. Provides: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `reason`. Stop hooks fire after every Claude response (wrong for archiving).
2. **jq dependency** — jq is NOT guaranteed in hook environment. Implementation uses pure-bash JSON extraction (`grep` + `sed`), matching the `read_config_key` pattern in `aitools`.
3. **Project derivation from Claude projects dirs** — Claude sanitizes CWD by replacing `/` with `-` in directory names, which is lossy for project names containing hyphens (e.g., `ai-tooling`). The hook reads `cwd` from hook stdin; the `sessions archive` command reads `cwd` from the JSONL transcript directly.

## Open Questions

1. **Subagent transcripts** — Should the hook also archive subagent JSONL files from `<session-id>/subagents/`? Probably yes for completeness, but increases storage.
2. **Auto-commit** — Should the hook auto-commit to the user repo? Current design says no (user controls commit cadence). But could add `aitools sessions push` for convenience.
3. **Transcript size** — Large sessions can be 2+ MB. Monitor repo size over time. Consider `.gitattributes` LFS threshold if it grows too large.

## Files Modified/Created

| File | Action | Phase |
|------|--------|-------|
| `reference/user-repo.md` | Create | A1 |
| `shared/hooks/session-archive.sh` | Create | A2 |
| `scripts/setup-user-hooks.sh` | Create | A3 |
| `scripts/setup-user-hooks.ps1` | Create | A3 |
| `scripts/aitools` | Modify | A4 |
| `scripts/aitools-install.sh` | Modify | A5 |
| `scripts/aitools-install.ps1` | Modify | A5 |
| `shared/claude-shared.md` | Modify | B1 |
| `scripts/build-deploy.sh` | Modify | B3 |

## Verification Checklist

### Phase A
- [ ] `aitools user init` creates/detects user repo and writes config
- [ ] SessionEnd hook fires on session end and copies transcript
- [ ] `aitools sessions list` shows archived sessions
- [ ] `aitools sessions move` refiles correctly
- [ ] `aitools` (no args) warns if hook not installed
- [ ] Works on macOS; Windows tested separately

### Phase B
- [ ] `shared/claude-shared.md` has no personal identity (all placeholders)
- [ ] `build-deploy.sh` reads profile.json and interpolates
- [ ] `diff` of old vs new `~/.claude/CLAUDE.md` shows zero changes
- [ ] New user flow: `aitools install` prompts for identity, builds correctly
- [ ] Fallback: build works without profile.json (uses defaults + warns)
