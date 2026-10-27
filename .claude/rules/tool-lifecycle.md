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
- Check script entries (`TOOL_CMDS` dictionaries)
- Deployment types table if new file type

#### Rebuild + propagate
1. Agents: `bash scripts/build-deploy.sh` under an isolated `HOME` with a
   copy of the dotprofile (`@.claude/rules/deploy-paths.md`); verify the new
   `setup-<tool>.sh/.ps1` pair is in the generated `deploy/`. The real
   dotprofile rebuild is the commander's (or a mission ordered to do it).
2. Propagate CLAUDE.md with `aitools` (commander), never `setup-user-claude`
   against the real HOME from an agent.
3. `bash scripts/check-post-push.sh` — all checks pass
4. Commit + push both repos (aitools via a PR; dotprofile to its main)

### Lifecycle field completeness

Every tool in the registry (`/tool-registry` skill, including Under
Evaluation entries) carries its lifecycle fields (platform status,
concurrency, post-install config, dependencies, invocation) and a last
verified version per platform (`pending` when unverified). Verify them
before committing.

### Install command verification gate

Before writing or modifying a setup script for any managed tool (new
onboarding, bug fixes, upgrades, platform additions, install-failure RCA),
verify the current upstream install method with the chrome-devtools skill:
the official README or docs install section, the GitHub releases page, and
the package-manager presence (Homebrew, crates.io, npm, winget, apt).
Record the findings, date and source URL through the `/tool-registry`
skill first, then change the scripts to match. The same gate applies to
`BuildPrereqs` entries and `BuildFailureSignatures` remedies.

### Cross-platform vetting

When recommending a tool, verify availability on macOS, Windows and Linux
(and the supported environments: `@reference/cross-platform-detail.md`).
Disclose single-platform or limited support.

### MCP servers

- **Isolation**: stdio MCP servers that keep local state run isolated
  (chrome-devtools: `--isolated`, a throwaway profile, so concurrent Claude
  Code and Cursor sessions never hit a profile lock).
- **Disable scope**: `agent mcp disable` (Cursor CLI) is per project, not per
  user. Always-available servers (chrome-devtools) belong in user config;
  opt-in servers (vercel, webflow) in project config. Claude Code
  `permissions.deny` in `~/.claude/settings.json` is user-scoped; record the
  asymmetry in each MCP server's `/tool-registry` entry.

### Deployment pattern updates

When a new tool deploys a config file type not in the deployment types table
of `@.claude/rules/managed-file-deployment.md`, add a row (rule, reference and
Cursor `.mdc`); when deployment behaviour of an existing type changes, update
its entries.

### Dotprofile priority

`setup-user-claude.sh/.ps1` reads dotprofile first. Rows added to
`@shared/claude-shared.md` MUST also be added to the dotprofile
template.

### When to invoke /tool-adopt

Invoke the `/tool-adopt` skill after `/tool-eval` passes Phase 2, when a
setup script reports no method for a platform, when a tool is requested
from any repo, or when changing a tool setup script. It walks the
onboarding checklist above.

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
- Onboarding and platform adoption: `/tool-adopt` skill
- Discovery playbook: `@reference/tool-evaluation-playbook.md`
- Evaluation criteria: `@reference/tool-evaluation-criteria.md`
- Registry data: `/tool-registry` skill
