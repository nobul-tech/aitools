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

## Documentation Standards (this repo)

### RELEASE_NOTES.md format

Each version entry follows this structure:

```
## vX.Y.Z -- Title (YYYY-MM-DD)

### Bug fixes           (table: #, Severity, Fix)
### New features        (table: #, Change)
### Improvements        (table: #, Change)
### Documentation       (table: #, Change)
### Files created       (table: File, Purpose)

**Verified on:** platform notes
```

Sections are optional -- include only those that apply. Number items sequentially across all sections within a release.

### Version numbering

`major.minor.patch` -- not semver, but follows the same spirit:

- **Major** (v0 -> v1): structural changes to CLI commands, architecture, or project layout
- **Minor** (v0.14): new features, new managed tools, batches of improvements
- **Patch** (v0.14.1): isolated bug fixes with no new functionality

Multiple changes on the same day roll into one release. Bug fixes ship alongside features in the same minor if they land together.

### ROADMAP.md format

Three sections: **In Progress**, **Planned**, **Completed**.

Each section uses a table: `| Item | Plan | Priority | Summary |`

- In Progress items must link to `plans/*.md`
- Completed items move to RELEASE_NOTES.md (with version reference)

### Reference doc threshold

Content exceeding ~20 lines of detail belongs in `reference/`, not `CLAUDE.md`. Keep `CLAUDE.md` under 200 lines.

### When to create a plan

Create a `plans/*.md` file when work:
- Spans multiple sessions
- Has phased gates or dependencies
- Needs detailed design beyond a roadmap row

### Layered reference architecture

- **Rules** (`.claude/rules/`) = concise behavioral directives, target ~40-100
  lines; a rule over 150 lines should move its detail to `reference/` (today:
  script-standards, incident-governance, cross-platform, deploy-paths,
  config-file-safety, agentic-standards)
  (what a rule is, its anatomy, scopes and deployment: `@reference/rules.md`)
- **Skills** (`.claude/skills/`, `shared/skills/`) = the governed process,
  loaded on demand (what a skill is, its anatomy, scopes and deployment:
  `@reference/skills.md`)
- **References** (`reference/`) = implementation detail, unlimited length
- **No duplication** — one authoritative location per fact
- **Tool configs** documented per-tool via `/tool-registry` skill
- **Specs vs state** — rules and references are specs;
  the `/incident` skill tracks out-of-spec code.
  See `@.claude/rules/incident-governance.md` for lifecycle and classification

### Skill placement

Where a skill's source lives decides what it is written for, not where it
is deployed: every skill in `shared/skills/`, `.claude/skills/` and the
dotprofile `claude/skills/` is deployed to user scope (`~/.claude/skills/`,
`~/.cursor/skills/`) through `~/.aitools/skills` (commander, 2026-10-26).

- **Shared** (`shared/skills/`): user level. Managed tool patterns,
  project-agnostic conventions, USO enablement, and the governance skills
  useful in a session on any repo, even read-only. Content must be factual
  (patterns, gotchas, platform behavior), not project-specific opinions,
  and must work in any repo (write aitools paths as "aitools `<path>`").
- **Project** (`.claude/skills/` in the aitools repo; today `audit` and
  `governed-data`): only skills meaningful solely inside the aitools
  working tree (they edit or audit aitools source). Deployed to user scope
  too, so they are listed in every repo; a project skill may cite aitools
  repo-relative paths only if it says it works inside aitools only.
- **Dotprofile** (`<userRepoPath>/claude/skills/`): the user's own skills.
- **One name, one place**: a skill name exists in exactly one of the
  three sources. Pre-commit step 21 fails on a collision between
  `shared/skills/`, `.claude/skills/` and the dotprofile's
  `claude/skills/`, and a duplicate is an ERROR on every deploy-harness
  run (first source wins: shared, then project, then dotprofile). Inside
  aitools the two project skills exist at both levels (the
  `.claude/skills/` source and the deployed `~/.claude/skills/` copy), and
  Claude Code runs the user-level copy, so a branch that edits a project
  skill sees the old copy until the next `aitools` run.
- **Governed data**: user-level skills say where their repo paths
  resolve (a "Where the files live" section): the aitools clone, else
  `repoPath` in `~/.aitools/config.json`, else the read-only
  `~/.aitools/registries/` copy deploy-harness installs.
- **Split personas**: a tool needs both user and project skills only
  when it serves two distinct personas (end user vs developer). Use
  `<name>` for user-level and `<name>-dev` for project-level. No level
  prefixes (`aitool-`, `aitools-`) in new names.
- Anatomy, scopes and deployment: `@reference/skills.md`; inventory and
  architecture: `@plans/governance-and-compliance-framework.md`

### `@` link convention

- `@` can reference ANY repo file: `@reference/`, `@.claude/rules/`,
  `@shared/`, `@scripts/`, `@plans/`
- In `.claude/rules/*.md`: `@path/file.md` is NOT resolved — it remains
  plain text. Use `@` consistently for all cross-references to signal
  "this is a linked file" and enable grep-based link auditing
- In `CLAUDE.md`: `@path/file.md` IS resolved at load time and pulls the
  file into context. Only use `@` for files you want auto-loaded. Use
  plain paths for references you want to keep lazy (most references)
- Standardize existing rules files to use `@` for all cross-refs (not yet
  done: several rules still cite `reference/` paths without `@`)

### Function and library attribution

- When referencing shared library functions (`deploy_managed_file()`,
  `backup_file()`, `invoke_ai()`, etc.), cite file + function name:
  `deploy_managed_file()` in `@scripts/aitools-lib.sh` /
  `Deploy-ManagedFile` in `@scripts/aitools-lib.ps1`
- Never cite line numbers in rules or reference files — they drift.
  Function names are stable identifiers
- Plan files may use line numbers for one-time edit instructions
