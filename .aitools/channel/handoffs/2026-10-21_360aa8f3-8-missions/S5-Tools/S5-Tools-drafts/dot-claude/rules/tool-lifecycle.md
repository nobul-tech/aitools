---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - registries/**
  - plans/**
  - rfcs/**
  - .claude/rules/**
  - .claude/skills/**
  - .cursor/rules/**
  - CLAUDE.md
  - RELEASE_NOTES.md
  - ROADMAP.md
  - README.md
---

## Tool Lifecycle (this repo)

> DRAFT — needs commander approval (modified intent statement).

**Intent**: **Purpose**: Govern the lifecycle gates, the tool support
decision tree, and the update policy for managed tools, so a tool is
installed only by its registry-preferred method, kept current on its
update channel, and never silently replaced or left shadowed. **Scope**:
Phase 2 gate, Under Evaluation guard, decision-tree directives, update
policy, install cleanup, onboarding, trigger directives for `/tool-registry`
and `/tool-adopt`. NOT evaluation principles
(`@.claude/rules/tool-evaluation.md`). NOT the tree detail, leaves, helper
contract, or schema (`@reference/tool-support-decision-tree.md`). NOT
registry data (`/tool-registry` skill). **Audience**: Every agent adding,
changing, or removing a managed tool or a `scripts/setup-*` script.

### Phase 2 gate

**Hard stop.** After installing and providing a test command, MUST wait for
the user's explicit approval before writing integration code. Do not plan or
batch Phase 3+ with it. Rejected: uninstall, remove the "Under Evaluation"
entry, stop. Approved: promote the entry, proceed. Plans with Phases 3-5 MUST
note the gate.

### Under Evaluation guard

Tools with `evaluating` status on ALL platforms MUST NOT have setup scripts,
installer entries, aliases in `shared/shell/`, build pipeline entries, or a
row in the CLAUDE.md Managed CLI Tools table.

### Tool support decision tree

Every managed-tool setup script MUST run the tree in
`@reference/tool-support-decision-tree.md` through `tool_support_run` /
`Invoke-ToolSupport` (`@scripts/aitools-lib.sh` / `.ps1`):

1. **Registry decides.** The preferred method for the platform and
   environment comes from the tool registry. None: ERROR + ACTION to run
   `/tool-eval` (text per the reference). A script never picks a method itself.
2. **Detect first.** Classify the install by the registry's detection
   signatures: none, preferred, non-preferred, unknown.
3. **Non-interactive and `--force` change nothing** for a non-preferred or
   unknown install: WARN in the summary panel and the log, plus ACTION.
4. **Interactive**: replace / keep / abort. Replace installs the preferred
   method FIRST, verifies it resolves, THEN removes the old copy (#12).
   Keep is remembered per machine as a tool exception.
5. **Unknown-source installs are never removed** or offered for removal.
6. **Post-check**: "supported" means the command resolves to the managed
   binary (tooling-resolution plan decision 10); shadowed or off PATH is
   ERROR (script-standards Standard 4).

### Update policy

Each tool has an `updateChannel` in the registry, default `latest-stable`
(others: `lts`, `pinned-major` / `pinned-minor` with `pin` and `reason`,
`vendor-auto`). Every installer run updates a preferred install to its
channel's latest and verifies it. Moving a pin or LTS line is a registry
change via `/tool-eval` that keeps the old line as a non-preferred method.
Kept (exception) installs are not updated.

### Install cleanup

Removal happens only in the replace branch, only after the preferred copy is
verified, and only through the registry's removal recipe. Setup scripts MUST
NOT uninstall or delete a tool before its replacement is verified.

### PATH refresh after install

A package-manager install may not be on PATH yet. Do not hardcode package
manager paths. Ask the user to relaunch Claude Code, then verify.

### Install method discovery

Install methods, detection signatures, removal recipes, and `BuildPrereqs`
entries MUST come from official documentation via `/tool-eval` — never from
assumption or memory.

### Onboarding and graduation

Onboard a tool that passed Phase 2 with `/tool-adopt`; it carries the full
checklist (registry, setup scripts, installer, build pipeline, check entries,
CLAUDE.md and dotprofile template rows, rebuild). A bundled tool that becomes
a project requirement (USO, standing order, widespread script dependency)
MUST graduate to a managed tool through the same lifecycle.

### When to invoke /tool-registry and /tool-adopt

- `/tool-registry`: checking or changing a tool's methods, channel, version,
  or health; adding an entry after `/tool-eval`; user says /tool-registry or /tools
- `/tool-adopt`: integrating a tool that passed Phase 2; creating, migrating,
  or fixing a `scripts/setup-*` script; a script reports `no method for
  <platform>`; user says /tool-adopt

`/tool-adopt` runs after `/tool-eval` and invokes it when the registry has no
preferred method. Both read and maintain the registry and this rule: a
decision that changes a directive above is drafted here for review.

### Cross-references

- Tree, leaves, helpers, schema: `@reference/tool-support-decision-tree.md`
- Framework: `@reference/framework-tool-lifecycle.md`
- Principles: `@.claude/rules/tool-evaluation.md`; menus: `@.claude/rules/interactive-menus.md`
- Skills: `/tool-eval`, `/tool-adopt`, `/tool-registry`
