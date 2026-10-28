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
| Markdown | Interactive diff review via `deploy_managed_file` (SOURCE is the source of truth; one menu: overwrite / accept & adopt / merge & adopt / skip / abort) | CLAUDE.md, `~/.claude/rules/*.md`, skill SKILL.md files |
| JSON config | Read-then-merge on managed fields. Profile-sourced fields (settings.json) use granular field-level review (`sync_managed_json` / `Sync-ManagedJson`: auto-adopt when profile silent, per-leaf overwrite/adopt/skip/abort on divergence); harness-managed keys (e.g. `hooks`) reconcile silently. JSON deployed through `deploy_managed_file` is reviewed field by field with SOURCE owning every field (`review_json_fields` / `Review-JsonFields`; no merge) | settings.json, cli-config.json, mcp.json, deployed JSON |
| Shell script | Interactive diff review via `deploy_managed_file` (same menu as markdown) | Hook scripts (`~/.claude/hooks/*.sh`) |

`deploy_managed_file()` / `Deploy-ManagedFile` is defined in
`@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`.
Full state machine spec: `@reference/managed-file-deployment.md`.
Choices and failure handling: `@.claude/rules/agentic-standards.md`
"Managed-file review choices and merge". There is no ancestor and no deploy
state.

**Adopt target.** Callers pass the absolute path of the repo file the
content came from (`ADOPT_PATH` / `-AdoptPath`, `""` for none). On accept &
adopt or merge & adopt the library writes that file itself, in the same
step. Callers never copy files back. An adopt target in the aitools repo is
a working-tree change only (no commit, no push). An adopt target in the
dotprofile repo is committed and pushed to its main automatically (N-Q2).
CLAUDE.md, a template, passes an adopt filter that strips the machine
footer and reverses the interpolation (bash: 6th argument `ADOPT_FILTER`,
a function name — `claude_md_adopt_filter` in `setup-user-claude.sh`;
PS1: `-AdoptFilter` scriptblock — `$claudeMdAdoptFilter` in
`setup-user-claude.ps1`).

### Content sources

Deployed content originates from two repos:

| Source | Priority | What it provides |
|--------|----------|-----------------|
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, user rules, profile.json (preferences, identity, machine profiles) |
| aitools repo (`shared/`) | Fallback | claude-shared.md template, hook scripts, skills, shell aliases |
| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then dotprofile `claude/rules/` | reference, registries, hooks, skills, rules (one flat directory), bin; config.json generated from profile.json. Rules reach Cursor through the `setup-user-cursor` fan-out; `setup-user-claude` does not fan out yet (it deploys the dotprofile `claude/rules/` only). Detail: `@reference/harness.md` "Deployed harness (`~/.aitools`)" |

- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with this machine's profile values when the setup script runs on that machine (dev path and generated deploy/ scripts alike)
- **Machine profile selection**: one resolver (`aitools-profile.sh` / `.ps1`, through `resolve_machine_profile` / `Resolve-MachineProfile`): override → environment → `profiles[<machine id>]` → config.json `machineId` (only when the id cannot be detected) → config.json `machineAlias` (2.1 profiles only) → hostname (warns) → no match = ERROR, never another machine's profile. Order and failure behaviour: `@reference/user-repo.md` "Resolution"
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
- **Skills**: user-level skills in `shared/skills/` (aitools-authored; `chrome-devtools` and `a11y-debugging` vendored from upstream) and personal skills in the dotprofile `claude/skills/` (wins on a name clash), deployed by `setup-user-skills` to `~/.claude/skills/` and `~/.cursor/skills/`; `deploy-harness` also copies `shared/skills/` and `.claude/skills/` to `~/.aitools/skills/`
- **Hooks**: canonical source in `shared/hooks/`, deployed to `~/.claude/hooks/`

Full spec: `@reference/user-repo.md`

### Shared requirements (all types)

These apply equally regardless of file type:

1. **Backup before write**: call `backup_file` / `Backup-File` before
   writing to an existing file. For markdown and shell script types and
   deployed JSON, `deploy_managed_file` handles this internally, for LOCAL
   and for the adopt target, and restores the backups when a write, merge or
   validation fails. For the other JSON config writers, the caller MUST call
   it explicitly.
2. **Diff logging**: log what changed to deploy.log before writing.
   Markdown/shell: handled by `deploy_managed_file`. JSON config: log
   changed fields with old → new values.
3. **Post-write validation**: verify the written file immediately.
   JSON: valid parse + required keys. Markdown: non-empty + required
   sections. Shell: non-empty + executable bit.
4. **Outcome tracking**: every deployment must resolve to a governed
   outcome and report via `write_summary`.
   `deploy_managed_file` results (created, updated, verified, accept &
   adopt, skipped, failed) are recorded with the deploy tracker; `failed`
   is an ERROR row and the run continues with the next file.

### Platform-specific config values

JSON config files may contain values that differ by platform, and a few
by environment. OS guards in setup scripts ensure the correct platform
variant is deployed; the environment API selects environment variants.
Examples:

| Config | Field | Windows | macOS | Linux |
|--------|-------|---------|-------|-------|
| Claude Code MCP registration (`claude mcp add --scope user`, `~/.claude.json`) | chrome-devtools command | `cmd /c npx chrome-devtools-mcp@latest -- --isolated` | `npx chrome-devtools-mcp@latest --isolated` | same as macOS |
| mcp.json, ~/.claude.json | chrome-devtools command, Claude Code web environment (D-CHR2) | n/a | n/a | `npx -y chrome-devtools-mcp@latest --isolated --headless --chromeArg=--no-sandbox` |
| settings.json | hook paths | `bash "C:/Users/.../hooks/session-archive.sh"` | `bash "/Users/.../hooks/session-archive.sh"` | `bash "/home/.../hooks/session-archive.sh"` (`/root/...` as root) |

Scripts must NEVER write cross-platform values (e.g., macOS paths on
Windows) or another environment's values. The OS guard + platform
dispatch pattern and the environment API prevent this — see
`@.claude/rules/cross-platform.md` "Environment branches".

### Updating this table

Adding a row (new file type) or column (new attribute) requires updating:
this rule, `@reference/managed-file-deployment.md`,
`@.cursor/rules/managed-file-deployment.mdc`, and
the `/incident` skill if there are implementation gaps. Tool onboarding checks
this table through `/tool-adopt` step 5 ("deployment types table for a new file
type").

### Cross-references

- State machine + detail: `@reference/managed-file-deployment.md`
- Text + JSON menus: `@.claude/rules/interactive-menus.md`
- JSON write safety: `@.claude/rules/config-file-safety.md`
- AI merge: `@.claude/rules/agentic-standards.md`
- Content sources: `@reference/user-repo.md`
- Known incidents: `/incident` skill
