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
