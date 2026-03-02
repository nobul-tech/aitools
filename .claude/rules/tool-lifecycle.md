---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - plans/**
  - rfcs/**
  - .claude/rules/**
  - .cursor/rules/**
  - CLAUDE.md
  - RELEASE_NOTES.md
  - ROADMAP.md
  - README.md
---

## Tool Lifecycle Gate (this repo)

When adding a new managed tool, follow the lifecycle in `reference/tool-evaluation-criteria.md`.

**Hard stop at Phase 2:** After installing the tool and providing a test command, you MUST wait for the user's explicit approval before writing any integration code (aliases, setup scripts, installer steps, build changes).

- Do not plan Phase 3+ implementation until Phase 2 is approved
- Do not batch Phase 2 approval with Phase 3+ work in a single plan
- If the user rejects: uninstall, remove the "Under Evaluation" entry, stop
- If the user approves: promote to full entry, then proceed to Phase 3+

This applies in plan mode too — a plan that includes Phases 3-5 must note the Phase 2 gate and flag that implementation is contingent on approval.

### PATH refresh after install

When a tool is installed via a package manager (winget, brew, npm), the new binary
may not be on PATH in the current shell session. Do not attempt to invoke the tool
using hardcoded package manager paths. Instead:

1. Install the tool
2. Ask the user to relaunch Claude Code to pick up the new PATH
3. After relaunch, verify with the version check command and proceed with testing

### Lifecycle field completeness

Every tool entry in `reference/tool-registry.md` (including Under Evaluation) must have all 6 fields:
- **Platform Status** (per platform: `evaluating`/`approved`/`supported`/`n/a`)
- **Concurrency** (can multiple instances run simultaneously?)
- **Post-Install Config** (steps required after install, or "None")
- **Dependencies** (other tools/runtimes required)
- **Invocation** (direct CLI command and anti-patterns, or "N/A" for non-CLI)
- **Last verified version** — versioned tools: `macOS: X.Y.Z (YYYY-MM-DD) | Windows: X.Y.Z | Linux: X.Y.Z`.
  Use `pending` for unverified platforms. Tools with `maintenanceFile` in `tool-versions.json`: use `See <filename>`.
  `@latest`/remote tools: `Last reviewed: YYYY-MM-DD` (platform-agnostic). Missing = flag.

Verify all 6 fields are present before committing changes to tool entries.

### Under Evaluation guard

Tools with `evaluating` status on ALL platforms must NOT have:
- Setup scripts in `scripts/`
- Entries in `aitools-install.sh/.ps1`
- Aliases in `shared/shell/`
- Build pipeline entries in `build-deploy.sh`
- Entry in CLAUDE.md Managed CLI Tools table

If any of these exist for an `evaluating`-only tool, flag it as a lifecycle error.

### New tool onboarding checklist

When a tool is approved (Phase 2 gate passed), complete ALL of these steps in order.
Missing any causes drift between the pipeline, documentation, and deployed configs.

#### Non-protected (implement directly)
- `scripts/setup-<tool>.sh` — install/update (macOS+Linux; OS guard exits on Windows)
- `scripts/setup-<tool>.ps1` — install/update (Windows; OS guard exits on macOS/Linux)
- `scripts/aitools-install.sh` — add `validate_and_run "$SCRIPT_DIR/setup-<tool>.sh"` step
- `scripts/aitools-install.ps1` — add `Invoke-ValidatedScript $toolScript` step
- `scripts/build-deploy.sh` — add numbered copy-as-is block pair after last tool block

#### Protected (present for review before writing)
- `reference/tool-registry.md` — full entry with all 6 lifecycle fields
- `shared/claude-shared.md` — add row to Managed CLI Tools table (shared template + MDM source)
- `<userRepoPath>/claude/CLAUDE.md` (dotprofile repo) — same row addition; commit + push dotprofile repo separately
- `reference/tool-versions.json` — add tool entry with per-platform version tracking
- `CLAUDE.md` — add `setup-<tool>` to "Deploy using MDM" tool scripts list
- `.claude/rules/tool-lifecycle.md` + `.cursor/rules/tool-lifecycle.mdc` — update this checklist if pattern changes

#### Rebuild + propagate
1. `bash scripts/build-deploy.sh` — verify count increments by 2
2. `bash scripts/setup-user-claude.sh` — propagate dotprofile CLAUDE.md → `~/.claude/CLAUDE.md`
3. `bash scripts/check-post-push.sh --extensive` — all checks pass
4. Commit + push both repos (aitools + dotprofile)

### Dotprofile priority

`setup-user-claude.sh/.ps1` reads the user's dotprofile `<userRepoPath>/claude/CLAUDE.md` first.
If `userRepoPath` is configured in `~/.aitools/config.json` and the file exists, it wins over
`shared/claude-shared.md`. This means any Managed CLI Tools row (or other shared preference) added
to `shared/claude-shared.md` must ALSO be added to the dotprofile file — otherwise the live
`~/.claude/CLAUDE.md` will not reflect the change.

Longer-term: a future `aitools user sync` command will merge shared template sections into the
dotprofile automatically (see ROADMAP.md).

### Install cleanup

When a setup script installs a tool via a preferred method (e.g., Homebrew), it should
also detect and remove old installs from non-preferred sources (e.g., npm/bun global,
manual binary). Prevents stale versions shadowing the preferred one due to PATH order.
See `setup-vercelcli` for the pattern.

### Cross-platform vetting

When recommending tools in this project, verify availability on both macOS and Windows.
Disclose if a tool is single-platform or has limited support on one OS.

### MCP server isolation

Chrome DevTools MCP uses `--isolated` flag for throwaway temp Chrome profiles, enabling
concurrent Claude Code + Cursor sessions without Chrome profile lock conflicts. Apply
the same pattern to any future stdio MCP server that creates persistent local state.
