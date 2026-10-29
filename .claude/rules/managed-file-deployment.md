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
| Markdown | Interactive diff review via `deploy_managed_file` (SOURCE is the source of truth; one menu: overwrite / accept & adopt / merge & adopt / skip / abort) | CLAUDE.md, `~/.claude/rules/*.md`, `~/.cursor/rules/*.mdc` (converted, no adopt), every file of a skill directory (`~/.claude/skills/<name>/**`, `~/.cursor/skills/<name>/**`) |
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
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles); user rules and user skills too, but through `~/.aitools` (row below), where `shared/` and `.claude/` win a name conflict |
| aitools repo (`shared/`) | Fallback | claude-shared.md template, hook scripts, skills, shell aliases |
| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then the dotprofile `claude/rules/` / `claude/skills/` | reference, registries, hooks, skills (one directory per skill), rules (one flat directory), bin, and a manifest for rules and one for skills; config.json generated from profile.json. Rules and skills reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-outs: each tool gets every name except the retired ones. Detail: `@reference/harness.md` "Deployed harness (`~/.aitools`)", `@reference/rules.md`, `@reference/skills.md` |

- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with this machine's profile values when the setup script runs on that machine (dev path and generated deploy/ scripts alike)
- **Machine profile selection**: one resolver (`aitools-profile.sh` / `.ps1`, through `resolve_machine_profile` / `Resolve-MachineProfile`): override → environment → `profiles[<machine id>]` → config.json `machineId` (only when the id cannot be detected) → config.json `machineAlias` (2.1 profiles only) → hostname (warns) → no match = ERROR, never another machine's profile. Order and failure behaviour: `@reference/user-repo.md` "Resolution"
- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`). The fan-out consumers copy from there, every rule except the retired ones: `setup-user-claude` into `~/.claude/rules/` (adopt target: the rule's source file, when it is on the machine), `setup-user-cursor` into `~/.cursor/rules/` (converted to `.mdc`, no adopt). Both update managed files, preserve unmanaged files, and back up and remove their own copy of a retired rule. Detail: `@reference/harness.md` "Rules manifest and retired rules"
- **Skills**: user-level skills in `shared/skills/` (aitools-authored; `chrome-devtools` and `a11y-debugging` vendored from upstream), project skills in `.claude/skills/` and personal skills in the dotprofile `claude/skills/`. deploy-harness collects the three into `~/.aitools/skills/<name>/` (first source wins) and writes `~/.aitools/skills/.aitools-skills-manifest` (each skill's source, or `retired`). `setup-user-claude` fans out every non-retired skill directory to `~/.claude/skills/` (adopt target: the source file), `setup-user-cursor` to `~/.cursor/skills/` (no adopt). A skill directory the fan-out did not create (a user's own skill, a symlink) is never overwritten or removed. `setup-user-skills` deploys only when `~/.aitools/skills` does not exist (fallback: `shared/skills/` and the dotprofile `claude/skills/`, the dotprofile wins on a name clash) and keeps reverse discovery. Detail: `@reference/skills.md`
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
   is an ERROR row and the run continues with the next file. A fan-out
   consumer that backs up and deletes its copy of a retired rule or skill
   records `removed`; an outcome the tracker does not know is logged and
   counted as `failed`.

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
