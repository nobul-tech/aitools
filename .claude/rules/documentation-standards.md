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
