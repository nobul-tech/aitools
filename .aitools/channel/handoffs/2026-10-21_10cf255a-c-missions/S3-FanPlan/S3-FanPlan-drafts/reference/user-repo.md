# Draft: reference/user-repo.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: the text PR #101 (`docs/m3-approved-drafts`) writes (main's text differs
only in the "Build-time embedding" paragraph, Edit 4). Four edits. Apply
verbatim after the plan's Batches B and C.

## Edit 1 -- "## Directory Structure", the rules line

OLD:

```
│   ├── rules/             # User-level Claude Code rules (deployed to ~/.claude/rules/)
```

NEW:

```
│   ├── rules/             # User-level rules (via ~/.aitools/rules to ~/.claude/rules/)
```

## Edit 2 -- the generated deploy scripts paragraph (#101 text)

OLD:

```
point `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1` at it. `setup-user-claude` also
embeds the build-time template, rules and a snapshot of `profile.json` (`aitools-json.pl
```

NEW:

```
point `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1` at it. `setup-user-claude` also
embeds the build-time template and a snapshot of `profile.json` (`aitools-json.pl
```

## Edit 3 -- "## User Rules Deployment", the section body down to (not including) "**Scope guidance**"

OLD:

```
Setup scripts deploy user-level Claude Code rules from `<userRepoPath>/claude/rules/` to `~/.claude/rules/`.

**Semantics**: additive deploy — managed files are added/updated, unmanaged files in the target are preserved.

- **Source**: `<userRepoPath>/claude/rules/*.md`
- **Target**: `~/.claude/rules/*.md`
- **Backup**: full directory copy (`rules.bak.<TIMESTAMP>/`), max 5, auto-prune
- **Diff logging**: unified diff of changes logged to deploy log; console shows summary
- **Managed vs preserved**: files matching a source file are managed; all other files in the target are preserved and logged
```

NEW:

```
The dotprofile's rules reach Claude Code in two steps. `deploy-harness` copies
`<userRepoPath>/claude/rules/*.md`, with aitools `shared/rules/` and
`.claude/rules/`, into `~/.aitools/rules/` (first source wins) and writes the
rules manifest there. `setup-user-claude` then fans out `~/.aitools/rules/` to
`~/.claude/rules/`; it no longer reads `<userRepoPath>/claude/rules/` itself.

**Semantics**: additive deploy — managed files are added/updated, unmanaged files in the target are preserved; the copy of a rule the manifest retires is backed up and removed.

- **Source**: every `*.md` in `~/.aitools/rules/` (case-insensitive; `*.bak.*` and hidden files skipped) except the names the rules manifest retires
- **Target**: `~/.claude/rules/<same name>`
- **Adopt target**: the rule's source file named by the manifest (`<userRepoPath>/claude/rules/<name>` for a dotprofile rule, committed and pushed; the aitools file for a shared or aitools rule, a working-tree change), when it is on the machine; none without a manifest
- **Retired**: the copy is removed (backup kept) only when it matches the harness copy or a backup deploy-harness made when it retired the rule; any other file of that name is kept with a warning and an ACTION row
- **No `~/.aitools/rules/`** (deploy-harness has not run): `claude rules` `n/a (no harness rules)`, the target is left untouched
- **Backup**: full directory copy (`rules.bak.<TIMESTAMP>/`), max 5, auto-prune
- **Diff logging**: unified diff of changes logged to deploy log; console shows summary
- **Managed vs preserved**: files fanned out this run are managed; all other rule files in the target are preserved and logged
```

## Edit 4 -- "**Scope guidance**" and "**Build-time embedding**"

OLD (#101 text; on main the second paragraph reads "**Build-time embedding**:
`build-deploy.sh` reads user rules at build time and embeds them in deploy
scripts via heredocs. If no rules exist at build time, deploy scripts skip rules
deployment." -- replace that one instead):

```
**Scope guidance**: user-level rules should be universal conventions that apply across all projects. Project-specific rules belong in `.claude/rules/` within the project repo.

**Build-time embedding**: `build-deploy.sh` embeds the dotprofile's rules at build time
as the fallback for a machine without the dotprofile; a machine with the dotprofile
deploys its own `claude/rules/`. If no rules exist at build time, the fallback is empty.
```

NEW:

```
**Scope guidance**: rules in the dotprofile's `claude/rules/` should be universal conventions that apply across all projects. Note: aitools' own `.claude/rules/` is fanned out too (commander decision 2026-10-22, "Put aitools rules in the user space of claude code"), so those rules also load in every project on the machine.

**MDM**: the generated `deploy/setup-user-claude.*` embed no rules. `deploy/deploy-harness.*`
embeds the build-time dotprofile's `claude/rules/` in its snapshot and fills
`~/.aitools/rules/`; run it before `setup-user-claude`.
```

## Why

Plan `plans/rules-fanout-claude.md` (Batches B, C). The "Scope guidance" NEW
text states the consequence of D5 instead of contradicting it; if the commander
takes risk R1's variant (skip aitools rules), drop the "Note" sentence.
