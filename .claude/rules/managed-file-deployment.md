---
paths:
  - scripts/**
  - deploy/**
  - shared/**
---

## Managed File Deployment (this repo)

All setup scripts that deploy files to user directories must follow the
deployment type matching the file format. Every type has the same
correctness requirements: backup, logging, and validation. They differ
only in merge strategy.

### Deployment types

| Type | Merge strategy | Files |
|------|---------------|-------|
| Markdown | Interactive diff review via `deploy_managed_file` | CLAUDE.md, `~/.claude/rules/*.md`, skill SKILL.md files |
| JSON config | Read-then-merge on managed fields only | settings.json, cli-config.json, mcp.json |
| Shell script | Interactive diff review via `deploy_managed_file` | Hook scripts (`~/.claude/hooks/*.sh`) |

`deploy_managed_file()` / `Deploy-ManagedFile` is defined in
`@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`.
Full state machine spec: `@reference/managed-file-deployment.md`.

### Content sources

Deployed content originates from two repos:

| Source | Priority | What it provides |
|--------|----------|-----------------|
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, user rules, profile.json (preferences, identity, machine profiles) |
| aitools repo (`shared/`) | Fallback | claude-shared.md template, hook scripts, skills, shell aliases |

- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with `profile.json` values at deploy time
- **Machine profile selection**: `config.json` `machineAlias` → `profile.json` `profiles[alias]`. Fallback: hostname match, then first profile
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
- **Skills**: vendored from upstream in `shared/skills/`, deployed to `~/.claude/skills/` and `~/.cursor/skills/`
- **Hooks**: canonical source in `shared/hooks/`, deployed to `~/.claude/hooks/`

Full spec: `@reference/user-repo.md`

### Shared requirements (all types)

These apply equally regardless of file type:

1. **Backup before write**: call `backup_file` / `Backup-File` before
   writing to an existing file. For markdown and shell script types,
   `deploy_managed_file` handles this internally. For JSON config type,
   the caller MUST call it explicitly.
2. **Diff logging**: log what changed to deploy.log before writing.
   Markdown/shell: handled by `deploy_managed_file`. JSON config: log
   changed fields with old → new values.
3. **Post-write validation**: verify the written file immediately.
   JSON: valid parse + required keys. Markdown: non-empty + required
   sections. Shell: non-empty + executable bit.
4. **Three-outcome tracking**: every deployment must resolve to
   created, updated, or unchanged — and report via `write_summary`.

### Platform-specific config values

JSON config files may contain values that differ by platform. OS guards
in setup scripts ensure the correct variant is deployed. Examples:

| Config | Field | Windows | macOS |
|--------|-------|---------|-------|
| mcp.json | chrome-devtools command | `cmd /c npx -y chrome-devtools-mcp@latest --isolated` | `npx -y chrome-devtools-mcp@latest --isolated` |
| settings.json | hook paths | `bash "C:/Users/.../hooks/session-archive.sh"` | `bash "/Users/.../hooks/session-archive.sh"` |

Scripts must NEVER write cross-platform values (e.g., macOS paths on
Windows). The OS guard + platform dispatch pattern prevents this — see
`@.claude/rules/cross-platform.md`.

### Updating this table

Adding a row (new file type) or column (new attribute) requires updating:
this rule, `@reference/managed-file-deployment.md`,
`@.cursor/rules/managed-file-deployment.mdc`, and
`@reference/known-gaps.md` if there are implementation gaps. See
`@.claude/rules/tool-lifecycle.md` "Deployment pattern updates".

### Cross-references

- State machine + detail: `@reference/managed-file-deployment.md`
- Text + JSON menus: `@.claude/rules/interactive-menus.md`
- JSON write safety: `@.claude/rules/config-file-safety.md`
- AI merge: `@.claude/rules/agentic-standards.md`
- Content sources: `@reference/user-repo.md`
- Known gaps: `@reference/known-gaps.md`
