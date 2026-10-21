---
name: tool-adopt
description: "Make a managed tool supported on a platform and environment:
  confirm the registry's preferred method (running /tool-eval when there is
  none), complete the decision-tree data, create or migrate its setup
  scripts onto the tool support decision tree, integrate, verify, and keep
  the registry and tool-lifecycle rule current. Use after /tool-eval, when
  a setup script reports no method for a platform, or when changing any
  scripts/setup-* script."
---

## Intent

> DRAFT — needs commander approval (new skill, new intent statement).

**Purpose**: Carry a managed tool from "evaluated" to "supported" on each
target platform and environment, so its setup scripts follow the tool
support decision tree and its registry entry holds every field the tree
reads. **Scope**: Preferred-method confirmation (invoking `/tool-eval` when
missing), registry decision-tree data (channel, detection, removal),
setup-script creation or migration, onboarding integration, verification,
and maintenance of the registry and `tool-lifecycle.md`. NOT install-method
research or health flags (`/tool-eval`). NOT the registry write process
(`/tool-registry`). NOT managed-file deployment, whose `[a]dopt` choice and
"accept & adopt" outcome are unrelated to tool adoption
(`@reference/managed-file-deployment.md`). NOT framework adoption
(`@reference/framework-adoption.md`). **Audience**: Any agent integrating a
tool, migrating a setup script, or answering a `no method for <platform>`
ERROR; the commander, who approves every protected change it drafts.

## Load first (every run)

Read these before step 1; do not work from memory:

1. `@.claude/rules/tool-lifecycle.md` — gates, decision directives, update policy
2. `@.claude/rules/tool-evaluation.md` — evaluation principles
3. `@reference/tool-support-decision-tree.md` — tree, leaves, schema 1.1, helpers
4. `/tool-registry` skill — how to read and write the registry
5. `/tool-eval` skill — the evaluation process you may have to run
6. `@.claude/rules/script-standards.md`, `@.claude/rules/cross-platform.md`,
   `@.claude/rules/interactive-menus.md` — when you touch scripts

## Process

### 1. Scope the target

- Name the tool slug and the targets: every platform and environment where
  the registry status is `approved` or `supported`, plus the one the
  commander asked for. Record the current machine's platform and
  environment (`$AITOOLS_PLATFORM`, `$AITOOLS_ENVIRONMENT`).
- Read the entry through `/tool-registry`. Note missing schema 1.1 fields.

### 2. Preferred method per target

For each target, check that exactly one preferred method applies.

- **None, or more than one**: invoke the `/tool-eval` skill now and run it
  with the commander interactively — automated research (official docs via
  the chrome-devtools skill, method catalog, provenance checks), then the
  commander's decision at the Phase 2 gate. Return here with its
  recommendation; write it through `/tool-registry` (protected: present,
  wait for approval).
- Do not continue a target without an approved preferred method. A setup
  script for that target ends at NO-METHOD, which is the correct state
  until the evaluation lands.

### 3. Decision-tree data

Draft the fields the tree reads, from `/tool-eval` research only (never
from memory):

- `updateChannel` (default `latest-stable`; `pin` and `reason` for pinned-*)
- `kind`, `package`, `environments`, `family` (Linux) for each preferred
  method; method ids unique across the tool's platforms
- `versionedPath` for version managers and other version-dependent paths
- after a pin or LTS line move: the old line kept as a non-preferred method
- `detection` for every method on the platform, preferred and not
  (`@reference/tool-support-decision-tree.md` section 5 probe kinds)
- `removal` for each non-preferred method, or null when it must never be
  removed automatically
- `update.<method>` for each preferred method, or `autoUpdates: true`
- verified `knownPaths` as `{path, verified}` objects (script-standards
  "KnownPaths empirical verification"); migrate string entries
- `lifecycle.setupScript`
- migrate any `nonPreferredMethods` rows into `install.<platform>[]`

Present all drafted registry changes together via `/tool-registry`.

### 4. Setup scripts

Create or migrate `scripts/setup-<tool>.sh` and `.ps1`:

- Shape per section 7.6 of the decision tree reference: lib, OS guard, spec,
  `rc=0; tool_support_run ... || rc=$?` (never a bare call under `set -e`),
  exit 2 on abort, tool-specific steps only when `rc` is 0, exit footer.
- Remove every hand-written install, upgrade, detection, and removal block
  the helpers now own. Keep tool-specific post-config (auth checks, GOPATH,
  NSS trust) after the tree, and only when the tree did not exit 2.
- `custom` kinds define `tool_custom_install` / `Invoke-ToolCustomInstall`.
- Plans touching 3+ code files follow `@.claude/rules/plan-execution.md`
  (verbatim edits, fresh sub-agent per 2-3 file batch, verification between).

### 5. Onboarding checklist (first support on a platform)

Non-protected (implement): setup script pair; installer step in
`aitools-install.sh/.ps1`; `build-deploy.sh` copy block; auth status check
when the tool needs auth.

Protected (present for review): registry entry; `shared/claude-shared.md`
Managed CLI Tools row and the same row in `<userRepoPath>/claude/CLAUDE.md`
(the dotprofile template is read first); check script `TOOL_CMDS` entries;
deployment types table for a new file type; `reference/evaluations/<tool>-*.md`
evaluation provenance; tool skill in `shared/skills/<tool>/` when the tool
has one. (No "CLAUDE.md deploy list" item: that list no longer exists —
open incident #65.)

Regenerate tool specs (`scripts/gen-tool-specs.py`). Rebuild and propagate:
`bash scripts/build-deploy.sh` (count grows by 2),
`bash scripts/setup-user-claude.sh`, `bash scripts/check-post-push.sh`,
then commit and push both repos when the commander authorises it.

### 6. Verify

- Run the decision tree reference section 10 test matrix for each changed
  script, isolated `HOME`, smoke test pattern (log to file, check exit code).
- `bash -n` and the PS1 parser on every changed script.
- Run the pre-commit "Tool support conformance" step.
- Spot-check one leaf's log line and summary row against section 3.

### 7. Maintain (every run, before reporting)

- **Registry**: record verified versions and dates per platform through
  `/tool-registry`; mark health flags that changed via `/tool-eval`.
- **Rule**: if this run settled a decision the tool-lifecycle rule does not
  state (a new channel, a new menu option, a new exception rule), draft the
  `@.claude/rules/tool-lifecycle.md` edit and present it — do not leave the
  decision only in a script or a plan.
- **Reference**: new probe kinds, install kinds, or leaves go into
  `@reference/tool-support-decision-tree.md` (protected, present for review).

### 8. Report

Targets and their final leaf on this machine, registry fields changed
(approved or pending), scripts changed, tests run with results, open items,
and `INCIDENT:` lines for deviations found.

## What this skill does NOT do

- Does NOT research or choose install methods — `/tool-eval`
- Does NOT write the registry directly — `/tool-registry`
- Does NOT touch managed-file `[a]dopt` or "accept & adopt" behaviour
- Does NOT remove a tool installed from an unknown source
- Does NOT commit, push, or open PRs without the commander's authorisation

## Cross-References

- Lifecycle rule: `@.claude/rules/tool-lifecycle.md`
- Decision tree: `@reference/tool-support-decision-tree.md`
- Framework: `@reference/framework-tool-lifecycle.md`
- Evaluation: `/tool-eval`, `@.claude/rules/tool-evaluation.md`
- Registry: `/tool-registry`
- Profile exceptions contract: `@reference/user-repo.md` (`profiles.<alias>.toolExceptions`)
