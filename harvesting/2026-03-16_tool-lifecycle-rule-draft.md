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

## Tool Lifecycle (this repo)

**Intent**: **Purpose**: Govern the lifecycle gates and onboarding
requirements for managed tools — ensuring tools pass evaluation
before integration, and all onboarding artifacts are completed.
**Scope**: Phase 2 gate, Under Evaluation guard, onboarding
checklist, bundled dependency graduation. NOT evaluation principles
(`@.claude/rules/tool-evaluation.md`). NOT the evaluation process
(`/tool-eval` skill). NOT registry data (`/tool-registry` skill).
**Audience**: Every agent adding, modifying, or removing a managed
tool.

### Phase 2 gate

**Hard stop.** After installing and providing a test command, MUST
wait for the user's explicit approval before writing integration
code.

- Do not plan Phase 3+ until Phase 2 is approved
- Do not batch Phase 2 approval with Phase 3+ work
- If rejected: uninstall, remove "Under Evaluation" entry, stop
- If approved: promote to full entry, proceed to Phase 3+
- Plans that include Phases 3-5 MUST note the gate

### Under Evaluation guard

Tools with `evaluating` status on ALL platforms MUST NOT have:
- Setup scripts in `scripts/`
- Entries in `aitools-install.sh/.ps1`
- Aliases in `shared/shell/`
- Build pipeline entries in `build-deploy.sh`
- Entry in CLAUDE.md Managed CLI Tools table

### Bundled dependency graduation

Bundled tools used incidentally may remain as dependencies. If a
bundled tool becomes a project requirement (USO, standing order,
or widespread script dependency), it MUST graduate to a full
managed tool via the standard lifecycle phases.

### PATH refresh after install

When installed via a package manager, the binary may not be on
PATH. Do not hardcode package manager paths. Ask the user to
relaunch Claude Code, then verify.

### Install cleanup

Setup scripts installing via a preferred method SHOULD detect and
remove old installs from non-preferred sources. Prevents PATH
shadowing.

### Install method discovery

Install methods and `BuildPrereqs` entries in setup scripts MUST
be derived from official tool documentation via the `/tool-eval`
skill — never chosen from assumption or memory. The `/tool-eval`
skill uses the chrome-devtools skill to navigate to the tool's
official documentation and extract verified install commands.

### Onboarding checklist

When approved (Phase 2 passed), complete ALL steps. Use the
`/tool-eval` skill for evaluation and the `/tool-registry` skill
for registry writes.

#### Prerequisite
- Verify upstream install method via `/tool-eval` skill
- Record via `/tool-registry` skill (protected)

#### Non-protected (implement directly)
- `scripts/setup-<tool>.sh` + `.ps1`
- `@scripts/aitools-install.sh` + `.ps1` — add step
- `@scripts/build-deploy.sh` — add copy block pair
- If auth required: add status check in setup scripts

#### Protected (present for review)
- Registry entry via `/tool-registry` skill
- `@shared/claude-shared.md` — Managed CLI Tools table
- `<userRepoPath>/claude/CLAUDE.md` — same row
- `CLAUDE.md` — deploy list
- Check script entries (`TOOL_CMDS` dictionaries)
- Deployment types table if new file type

#### Rebuild + propagate
1. `bash scripts/build-deploy.sh` — verify count increments by 2
2. `bash scripts/setup-user-claude.sh` — propagate CLAUDE.md
3. `bash scripts/check-post-push.sh` — all checks pass
4. Commit + push both repos

### Dotprofile priority

`setup-user-claude.sh/.ps1` reads dotprofile first. Rows added to
`@shared/claude-shared.md` MUST also be added to the dotprofile
template.

### When to invoke /tool-registry

Invoke the `/tool-registry` skill when ANY of these arise:

- Checking a tool's install method, version, or health status
- Adding a new tool entry (after `/tool-eval` completes)
- Updating an existing entry's fields or version
- User says /tool-registry or /tools

The skill provides the governed process for reading and writing
the tool registry JSON. Accessing the registry data directly
bypasses that process.

### Cross-references

- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Evaluation process: `/tool-eval` skill
- Registry access: `/tool-registry` skill
- Discovery playbook: `@reference/tool-evaluation-playbook.md`
- Evaluation criteria: `@reference/tool-evaluation-criteria.md`
- Registry data: `reference/tool-registry.json` (accessed via `/tool-registry` skill)
