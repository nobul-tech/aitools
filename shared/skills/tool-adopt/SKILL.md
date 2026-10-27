---
name: tool-adopt
description: "Make a managed tool supported on a platform and environment:
  confirm the registry's preferred method (running /tool-eval when there is
  none), complete the registry data, create or migrate its setup scripts,
  integrate, verify, and keep the registry and tool-lifecycle rule current.
  Use after /tool-eval, when a setup script reports no method for a
  platform, when a tool is requested from any repo, or when changing a tool
  setup script (one named by a registry lifecycle.setupScript)."
---

## Intent

**Purpose**: Carry a managed tool from "evaluated" to "supported" on each
target platform and environment, so its registry entry and setup scripts
meet the tool lifecycle rule today and the tool support decision tree once
it lands. **Scope**: Preferred-method confirmation (invoking `/tool-eval`
when missing), registry data through `/tool-registry`, setup-script creation
or migration in the aitools repo, onboarding integration, verification, and
maintenance of the registry and the tool-lifecycle rule; which steps wait
for the decision-tree machinery (M2). NOT install-method research or health
flags (`/tool-eval`). NOT the registry write process (`/tool-registry`). NOT
the managed-file review choices `[a]ccept & adopt` and `[m]erge & adopt`,
which copy the deployed file or an AI merge back to the repo (the source of
truth) and are unrelated to tool adoption (aitools
`reference/managed-file-deployment.md`). NOT framework adoption (aitools
`reference/framework-adoption.md`). **Audience**: Any agent, in any repo,
that integrates a tool, migrates a setup script, or answers a
`no method for <platform>` ERROR; the commander, who approves every
protected change it drafts.

## This skill does the work

`/tool-adopt` is not a checklist to read: invoking it means you carry the
tool to supported in this run. You do each of these yourself:

- **Evaluate when needed**: when a target has no approved preferred method,
  run the `/tool-eval` skill now, with the commander, and bring its result
  back here (step 2).
- **Write the registry entry**: draft every missing field and write it
  through the `/tool-registry` skill once the commander approves (step 3).
- **Write the setup scripts**: create or migrate `scripts/setup-<tool>.sh`
  and `.ps1` (step 4), wire them into the installers and build (step 5),
  and test them (step 6).

Stop only at an approval gate (the `/tool-eval` Phase 2 gate, a protected
file) or when a step waits for M2; report what remains.

## Where this runs

This skill is user-level, so it loads in every repo. The work it describes
changes the aitools repo (`~/repos/aitools/` on macOS,
`%USERPROFILE%\repos\aitools\` on Windows): its registry, setup scripts,
installers and rules. Paths below are relative to that repo.

- In the aitools repo: run every step.
- In another repo: run steps 1-2 to scope the request, then either open the
  aitools repo in this session and continue, or open an issue on
  `nobul-tech/aitools` (`gh issue create -R nobul-tech/aitools`) with the scope and the `/tool-eval` result (RFC 0001,
  `rfcs/RFC-0001-workspace-tool-requests.md`). Do not create setup scripts
  or registry entries in the other repo.

Registry data is read and written only through the `/tool-registry` skill.
Never read or name a registry JSON file directly.

## Today and after M2

The tool support decision tree (`reference/tool-support-decision-tree.md`),
tool registry schema 1.1, the generated tool specs and the `tool_*` helpers
are mission M2 work and do not exist yet. Until they land, use the "Today"
column. Check which applies at the start of every run: the tree applies once
`reference/tool-support-decision-tree.md` exists and the `/tool-registry`
skill reports schema `1.1`.

| Step | Today (current rules, hand-written scripts) | After M2 |
|------|----------------------|----------|
| 3 Registry data | Fields the current `/tool-registry` skill requires | Every field in the tree reference "Tool registry schema 1.1" |
| 4 Setup scripts | `.claude/rules/script-standards.md` and `.claude/rules/tool-lifecycle.md` ("Install cleanup", "PATH refresh after install") | The tree reference "Setup script shape after migration" |
| 5 Onboarding | As written | Plus: regenerate tool specs (`scripts/gen-tool-specs.py`) and commit them with the registry change |
| 6 Verify | Smoke test pattern, `bash -n`, PS1 parser | Plus: the tree reference "Test matrix" and the pre-commit "Tool support conformance" step |

## Load first (every run)

Read these before step 1; do not work from memory:

1. `.claude/rules/tool-lifecycle.md` — gates, onboarding checklist, update policy
2. `.claude/rules/tool-evaluation.md` — evaluation principles
3. `reference/tool-support-decision-tree.md` — only after M2 (see above)
4. `/tool-registry` skill — how to read and write the registry
5. `/tool-eval` skill — the evaluation process you may have to run
6. `.claude/rules/script-standards.md`, `.claude/rules/cross-platform.md`,
   `.claude/rules/interactive-menus.md` — when you touch scripts

## Process

### 1. Scope the target

- Name the tool slug and the targets: every platform and environment where
  the registry status is `approved` or `supported`, plus the one the
  commander asked for. Record the current machine's platform and
  environment (`$AITOOLS_PLATFORM`, `$AITOOLS_ENVIRONMENT`).
- Read the entry through `/tool-registry`. Note the fields it lacks for the
  column (Today / After M2) that applies.

### 2. Preferred method per target

For each target, check that exactly one preferred method applies.

- **None, or more than one**: invoke the `/tool-eval` skill now and run it
  with the commander interactively — automated research (official docs via
  the chrome-devtools skill, method catalog, provenance checks), then the
  commander's decision at the Phase 2 gate. Return here with its
  recommendation; write it through `/tool-registry` (protected: present,
  wait for approval).
- Do not continue a target without an approved preferred method. After M2 a
  setup script for that target ends at NO-METHOD, which is the correct state
  until the evaluation lands.

### 3. Registry data

Draft every registry field the entry lacks for each target platform (the
column that applies), including the update channel once schema 1.1 exists.
After M2, validate the draft against the tree reference "Pre-commit
conformance check", checks 1-6. Take the values from `/tool-eval` research
only, never from memory.

Present all drafted registry changes together via `/tool-registry`.

### 4. Setup scripts

Create or migrate `scripts/setup-<tool>.sh` and `.ps1` (always both):

- Today: follow `.claude/rules/script-standards.md` block order, logging,
  summary rows and external-command error handling; install via the
  approved preferred method; detect and replace old installs from
  non-preferred sources (`.claude/rules/tool-lifecycle.md` "Install
  cleanup").
- After M2: shape per the tree reference "Setup script shape after
  migration" (bash and PowerShell): lib, OS guard, spec,
  `rc=0; tool_support_run ... || rc=$?` (never a bare call under `set -e`),
  exit 2 on abort, tool-specific steps only when `rc` is 0, exit footer.
  Remove every hand-written install, upgrade, detection, and removal block
  the helpers now own. `custom` kinds define `tool_custom_install` /
  `Invoke-ToolCustomInstall`.
- Keep tool-specific post-config (auth checks, GOPATH, NSS trust) after the
  install, and only when the script did not exit 2.
- Plans touching 3+ code files follow `.claude/rules/plan-execution.md`
  (verbatim edits, fresh sub-agent per 2-3 file batch, verification between).

### 5. Onboarding checklist (first support on a platform)

Non-protected (implement): setup script pair; installer step in
`scripts/aitools-install.sh/.ps1`; `scripts/build-deploy.sh` copy block; auth
status check when the tool needs auth.

Protected (present for review): registry entry (through `/tool-registry`);
`shared/claude-shared.md` Managed CLI Tools row and the same row in
`<userRepoPath>/claude/CLAUDE.md` (the dotprofile template is read first);
check script `TOOL_CMDS` entries; deployment types table for a new file type;
`reference/evaluations/<tool>-*.md` evaluation provenance; tool skill in
`shared/skills/<tool>/` when the tool has one. (No "CLAUDE.md deploy list"
item: that list no longer exists — open incident #65.)

After M2, regenerate tool specs (`scripts/gen-tool-specs.py`) and commit them
with the registry change. Rebuild and propagate under an isolated `HOME`
(`build-deploy.sh` deletes and rebuilds the real dotprofile `deploy/`
otherwise): `bash scripts/build-deploy.sh` (count grows by 2),
`bash scripts/setup-user-claude.sh`, `bash scripts/check-post-push.sh`, then
commit and push when the commander authorises it.

### 6. Verify

- Smoke test each changed script under an isolated `HOME`
  (`.claude/rules/smoke-test-pattern.md`: log to file, check exit code).
- `bash -n` and the PS1 parser on every changed script.
- After M2: run the tree reference "Test matrix" for each changed script and
  the pre-commit "Tool support conformance" step, and spot-check one leaf's
  log line and summary row against the reference "Leaves: log line, summary
  row, ACTION, exit".

### 7. Maintain (every run, before reporting)

- **Registry**: record verified versions and dates per platform through
  `/tool-registry`; mark health flags that changed via `/tool-eval`.
- **Rule**: if this run settled a decision the tool-lifecycle rule does not
  state (a new channel, a new menu option, a new deviation from the decision
  tree), draft the `.claude/rules/tool-lifecycle.md` edit and present it —
  do not leave the decision only in a script or a plan.
- **Reference**: after M2, new probe kinds, install kinds, or leaves go into
  `reference/tool-support-decision-tree.md` (protected, present for review).

### 8. Report

Targets and their final state on this machine, registry fields changed
(approved or pending), scripts changed, tests run with results, open items,
and `INCIDENT:` lines for deviations found.

## What this skill does NOT do

- Does NOT research or choose install methods — `/tool-eval`
- Does NOT read or write the registry directly — `/tool-registry`
- Does NOT touch the managed-file review choices (`[a]ccept & adopt`,
  `[m]erge & adopt`)
- Does NOT remove a tool installed from an unknown source
- Does NOT create setup scripts or registry entries outside the aitools repo
- Does NOT commit, push, or open PRs without the commander's authorisation

## Cross-References (aitools repo paths)

- Lifecycle rule: `.claude/rules/tool-lifecycle.md`
- Decision tree: `reference/tool-support-decision-tree.md`
- Framework: `reference/framework-tool-lifecycle.md`
- Evaluation: `/tool-eval`, `.claude/rules/tool-evaluation.md`
- Registry: `/tool-registry`
- Workspace tool requests from other repos: `rfcs/RFC-0001-workspace-tool-requests.md`
- Profile exceptions contract: `reference/user-repo.md` (`profiles.<machineId>.toolExceptions`)
