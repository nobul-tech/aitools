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
## vX.Y -- Title (YYYY-MM-DD)

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

- **Rules** (`.claude/rules/`) = concise behavioral directives, ~40-100 lines
- **References** (`reference/`) = implementation detail, unlimited length
- **No duplication** — one authoritative location per fact
- **Tool configs** documented per-tool in `@reference/tool-registry.md`
- **Specs vs state** — rules and references are specs;
  `@reference/known-gaps.json` tracks out-of-spec code.
  See `@.claude/rules/gap-governance.md` for lifecycle and classification

### `@` link convention

- `@` can reference ANY repo file: `@reference/`, `@.claude/rules/`,
  `@shared/`, `@scripts/`, `@plans/`
- In `.claude/rules/*.md`: `@path/file.md` is NOT resolved — it remains
  plain text. Use `@` consistently for all cross-references to signal
  "this is a linked file" and enable grep-based link auditing
- In `CLAUDE.md`: `@path/file.md` IS resolved at load time and pulls the
  file into context. Only use `@` for files you want auto-loaded. Use
  plain paths for references you want to keep lazy (most references)
- Standardize existing rules files to use `@` for all cross-refs

### Function and library attribution

- When referencing shared library functions (`deploy_managed_file()`,
  `backup_file()`, `invoke_ai()`, etc.), cite file + function name:
  `deploy_managed_file()` in `@scripts/aitools-lib.sh` /
  `Deploy-ManagedFile` in `@scripts/aitools-lib.ps1`
- Never cite line numbers in rules or reference files — they drift.
  Function names are stable identifiers
- Plan files may use line numbers for one-time edit instructions
