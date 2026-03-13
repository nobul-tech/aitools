# Known Gaps

Consolidated tracking of known out-of-spec code. This is state, not spec.
Rules and references define what SHOULD be; this file tracks what ISN'T yet.

Last updated: 2026-03-13

---

## Gap 1: Hook Script Deployment

**Status**: Open
**Affected scripts**: `setup-user-hooks.sh`, `setup-user-hooks.ps1`

Current implementation uses direct `cp` / `Copy-Item` for hook scripts.
Missing: `backup_file` before overwrite, `deploy_managed_file` interactive
review, adopt/skip/merge options. User customizations are silently lost.

**Planned fix**: Upgrade to `deploy_managed_file` (same as markdown type).
Adopt target: `shared/hooks/<filename>` in aitools repo.

## Gap 2: JSON Config Backup (bash)

**Status**: Open
**Affected scripts**: `setup-user-hooks.sh`, `setup-user-mcp.sh`

Bash versions do NOT call `backup_file` before settings.json merge.
PowerShell versions DO call `Backup-File`. Platform parity gap.

**Planned fix**: Add `backup_file` call in bash before Node.js merge.

## Gap 3: JSON Config Interactive Review

**Status**: Open
**Affected scripts**: All JSON config scripts (`setup-user-hooks`,
`setup-user-mcp`, `setup-user-cursor`, `setup-cursor-ide-mcp`)

All JSON config merges are silent. Clobber detection blocks on field
loss, but there is no "here's what will change, proceed?" prompt.

**Planned fix**: Add field-level review menu showing changed managed
fields with old → new values.

## Gap 4: MCP Disable Scope (Cursor CLI)

**Status**: Open
**Affected scripts**: `setup-cursor-ide-mcp.sh`, `setup-cursor-ide-mcp.ps1`

`agent mcp disable <name>` is project-scoped, not user-scoped. Setup
runs it from the aitools repo directory only. Other projects see
vercel/webflow as enabled, causing authentication errors on launch.

**Planned fix**: Stop deploying vercel/webflow to user-level `mcp.json`.
Add per-project only via `aitools --addmcp`.

## Gap 5: Backup Proliferation

**Status**: Open
**Affected functions**: `backup_dir` in `aitools-lib.sh` / `aitools-lib.ps1`

`backup_dir` copies the entire directory including individual `.bak.*`
files. Each backup contains older backups, causing cascading growth.

**Planned fix**: Exclude `*.bak.*` patterns from directory backup copies.
