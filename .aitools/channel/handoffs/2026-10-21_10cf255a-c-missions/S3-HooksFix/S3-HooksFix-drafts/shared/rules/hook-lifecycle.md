---
paths:
  - shared/hooks/**
  - scripts/setup-user-hooks.sh
  - scripts/setup-user-hooks.ps1
  - scripts/build-deploy.sh
  - .claude/rules/hook-rollout.md
  - shared/rules/hook-lifecycle.md
  - reference/managed-file-deployment.md
---

## Hook Lifecycle

**Intent**: **Purpose**: Govern the lifecycle of every Claude Code hook the
aitools harness manages: one source per hook, equivalent deployment on the dev
and MDM paths, the single target of an `[a]dopt`, the place of user-created
hooks, and the steps to retire a hook. **Scope**: Source of truth, deployment
equivalence, the adopt target, user-created hooks, dotprofile shadow warnings,
prompt safety in the hook deploy, retirement, verification. NOT the
observe-then-enforce rollout of a check (aitools `.claude/rules/hook-rollout.md`).
NOT the managed-file state machine or menu options (aitools
`reference/managed-file-deployment.md`, `.claude/rules/interactive-menus.md`).
NOT hook portability (aitools `.claude/rules/cross-platform.md` "Hook
portability"). NOT what an individual hook enforces (its header comment).
**Audience**: Every agent, in any repo on any machine, that adds, changes,
adopts or retires an aitools-managed hook, or edits the aitools files
`scripts/setup-user-hooks.*`, `shared/hooks/hooks-manifest.json`, or the hook
sections of `scripts/build-deploy.sh`.

Paths below are relative to the aitools clone (`~/repos/aitools/` on macOS,
`%USERPROFILE%\repos\aitools\` on Windows) unless they start with `~/` or
`<userRepoPath>/`.

### Decisions

| ID | Decision | Date | By |
|----|----------|------|----|
| SD-2 | One hook version, in `shared/hooks/`. The dotprofile hook copies are removed (verified: no `claude/hooks/` in the dotprofile). The setup-user-hooks "adopt" path must write `shared/hooks` only | 2026-10-21 | commander |

SD-2 removed the copies once, by hand. The scripts do not delete a dotprofile
copy that appears later: they ignore it and warn (see "Deployment" below).

### One source per hook

- A harness hook is one entry in `shared/hooks/hooks-manifest.json` (`hooks[]`
  for a registered hook: event, file, matcher; `deploy[]` for a deploy-only
  helper) plus one file: `shared/hooks/<file>`, or `scripts/<file>` for a
  deploy-only helper such as `ait-harvest.py`.
- No other copy is a source: not `<userRepoPath>/claude/hooks/`, not
  `~/.claude/hooks/`.
- Adding a hook is the manifest entry plus the file. The setup scripts and
  `build-deploy.sh` generate deployment and registration from the manifest;
  do not add per-hook code to them.

### Deployment: both paths deploy the same file

| Path | Source resolution | Write |
|------|-------------------|-------|
| Dev: `scripts/setup-user-hooks.sh/.ps1` | `shared/hooks/`, then `scripts/` | `~/.claude/hooks/` via `deploy_managed_file` / `Deploy-ManagedFile` (diff review) |
| MDM: `<userRepoPath>/deploy/setup-user-hooks.*` | embedded by `build-deploy.sh` at build time, same order | `~/.claude/hooks/` overwritten, no review |

- The resolution order lives in both `setup-user-hooks.*` and the
  `build-deploy.sh` embed loops (duplicated logic, aitools
  `.claude/rules/deploy-paths.md`). Change it in all of them together.
- A dotprofile copy of a manifest hook is ignored, not deleted. The dev path
  logs a warning and a `WARN` summary row (`dotprofile copy ignored`); delete
  the copy by hand.

### Adopt writes `shared/hooks` only

- `[a]dopt` on a manifest hook (the `accept & adopt` outcome) copies the
  deployed hook to `shared/hooks/<file>` in the aitools clone, never to the
  dotprofile (SD-2). The user reviews (`git diff` in the aitools repo) and ships
  it through a PR; until it ships, other machines keep deploying the old version.
- The MDM path has no adopt: it has no aitools clone.

### User-created hooks

- A `*.sh` in `~/.claude/hooks/` that is in neither `shared/hooks/` nor
  `<userRepoPath>/claude/hooks/` is user-created. Reverse discovery offers
  `[a]dopt to dotprofile` / `[s]kip`. `<userRepoPath>/claude/hooks/` holds only
  these hooks.
- setup-user-hooks deploys and registers manifest hooks only. It never deploys
  or registers a user-created hook.
- To make a user-created hook harness-managed: move it to `shared/hooks/`, add
  its manifest entry, and delete the dotprofile copy in the same change.

### Prompts in the hook deploy

- Every prompt is gated by `tty_interactive` / `Test-InteractiveConsole` and
  read with `read_tty_choice` / `Read-ConsoleChoice`. Never a bare `read` or
  `[Console]::ReadLine()`.
- EOF at a prompt: `read_tty_choice` / `Read-ConsoleChoice` log a warning and
  take the default.
- Diff review of a manifest hook: non-interactive stdin, `--force`, or EOF take
  overwrite (aitools `.claude/rules/interactive-menus.md`).
- Reverse discovery: non-interactive stdin skips the prompt and logs it at info
  (`Non-interactive: skipped adoption prompt for <hook>`); EOF takes `[s]kip`,
  the choice that writes nothing. `--force` does not change this menu.

### Retiring a hook

1. Remove its manifest entry and `git rm` its file.
2. Add its file name to the stale lists: `STALE_HOOKS` in `setup-user-hooks.sh`,
   `$staleHooks` in `.ps1`, and a `removeHookEntry` / `RemoveHookEntry` call in
   each merge block. These lists are hand-maintained, not manifest-driven.
3. The MDM path removes the registration (the merge block is extracted) but not
   the file: stale-file cleanup sits in the section `build-deploy.sh` replaces.

### Verification

- Any hook change: the pre-deploy verification in aitools
  `.claude/rules/hook-rollout.md`.
- Any `setup-user-hooks.*` change: `bash -n` and the pwsh parser on both
  scripts; a run under an isolated `HOME` (fake config and dotprofile) through
  the adopt path and the EOF path; an isolated-`HOME` `build-deploy.sh` run with
  `bash -n` and the pwsh parser on the generated `deploy/setup-user-hooks.*`.
- These verification runs, by an agent or a delegate, use an isolated `HOME`,
  never the real one: `build-deploy.sh` deletes and rebuilds the real dotprofile
  `deploy/` (#86). This does not change the propagation steps that deploy a
  merged change to the machine (aitools `.claude/rules/deploy-paths.md` step 2,
  `.claude/rules/tool-lifecycle.md` "Rebuild + propagate"); those run against
  the real `HOME` by design.

### Cross-references

- Rollout of a check: aitools `.claude/rules/hook-rollout.md`
- Deployment types and the shell-script adopt target: aitools
  `.claude/rules/managed-file-deployment.md`,
  `reference/managed-file-deployment.md` "Shell Script Deployment Detail"
- Duplicated setup logic: aitools `.claude/rules/deploy-paths.md`
- Menus and non-interactive fallback: aitools `.claude/rules/interactive-menus.md`
- Hook portability: aitools `.claude/rules/cross-platform.md`
- Incidents #80, #81, #82, #86: `/incident` skill (aitools repo)
