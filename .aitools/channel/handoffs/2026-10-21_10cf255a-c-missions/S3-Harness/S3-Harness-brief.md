# S3-Harness brief (shared by every S3-H-* delegate)

Written by S3-Harness (orchestrator, delegated by Session Commander
10cf255a-c), 2026-10-22. Read in full after the mission packet. Do not edit
while delegates run.

**Intent**: **Purpose**: Build ~/.aitools as the deployed harness:
scripts/deploy-harness.sh/.ps1 populate it from the repos, generate
config.json from profile.json, and the rules it holds are fanned out to the
agent tools. **Scope**: deploy-harness (new), its installer and sync hook-ins,
config.json generation (by calling the existing writer), rules fan-out in
setup-user-claude and setup-user-cursor, the MDM generator in build-deploy.sh,
tests, protected drafts. NOT the profile schema or resolver (M3-LEAD).
**Audience**: aitools install / aitools on every machine.

## Commander requirements (verbatim from the S3-Harness launch prompt)

- scripts/deploy-harness.sh and .ps1 (scripts/, standard block order,
  script-standards logging, write_summary under the single name "harness
  files", bash 3.2, parity).
- Creates ~/.aitools/{reference,registries,hooks,rules,skills,bin} (Windows:
  %USERPROFILE%\.aitools\...). Sources: reference/** and registries/**
  (git-tracked files only, recursive); hooks <- shared/hooks + .claude/hooks;
  skills <- shared/skills + .claude/skills; rules <- shared/rules +
  .claude/rules + dotprofile claude/rules, ALL in ONE flat directory
  ~/.aitools/rules; bin <- the installer's ~/.aitools/bin step, moved here.
- Name conflicts: the first source found wins silently; each skipped
  duplicate is log_error + an ERROR row under "harness files". Document
  conflict handling and its assumptions in reference/harness.md (protected;
  approved to write).
- Each file through deploy_managed_file with ADOPT_PATH = its repo source;
  adopting into a protected file logs a WARN naming it.
- config.json: GENERATED from profile.json by deploy-harness, by calling the
  existing single writer scripts/setup-user-config.sh/.ps1 (owned by mission
  M3-LEAD, which is changing profile.json to be keyed by machine id).
  Coordinate through the writer's interface; do not edit setup-user-config.*
  or aitools-profile.*; if you need an interface change, report it.
- Hook-ins: aitools-install Step 8b (after Node) on both platforms; first in
  the deploy_configs loop of scripts/aitools and scripts/aitools.ps1.
  settings.json keeps pointing at ~/.claude/hooks.
- Rules fan-out: setup-user-claude and setup-user-cursor copy EVERYTHING in
  ~/.aitools/rules into each tool's rules location (Claude Code
  ~/.claude/rules; Cursor: establish its user-level rules location from
  official docs via chrome-devtools and /tool-ops first, and verify with a
  canary test). setup-user-claude stops deploying dotprofile rules directly,
  with a regression test (tests/rules-fanout/). setup-user-claude has an open
  M3 PR (#83, owned by M3-LEAD): wait for it to merge, rebase, then change
  it; do setup-user-cursor first.
- /tool-ops and its skills read ~/.aitools/reference/tool-ops-*.md, falling
  back to the repo.
- MDM: build-deploy.sh generates an embedded deploy/deploy-harness.*
  (isolated HOME only).
- Protected drafts approved to write: aitools-workspace.md user-scoped table
  rows for the new directories; managed-file-deployment content sources; the
  "harness files" tool name in script-standards-detail.md.
- Verify under isolated HOME: first run, rerun, edit then review, adopt,
  conflict, dry run, --force, MDM parse, fan-out canary. Each delegate runs an
  independent reviewer that posts its verdict as a PR comment.

## Shared contract (deploy-harness <-> fan-out consumers)

- `~/.aitools/rules/` is ONE flat directory of `*.md` rule files. Consumers
  (setup-user-claude, setup-user-cursor) copy every regular file in it to the
  tool's rules location. They do not read the repos for rules.
- `~/.aitools/reference/` mirrors the repo `reference/` tree (git-tracked
  files only, same relative paths). /tool-ops readers look for
  `~/.aitools/reference/tool-ops-*.md` first, then the repo copy.
- `~/.aitools/skills/<name>/...` mirrors skill directories; `hooks/` is flat;
  `registries/` mirrors `registries/`; `bin/` holds the harness Python CLIs
  (today: harness-db.py, read-session.py, read-session-full.py -- verify in
  scripts/aitools-install.sh "Harness Python CLIs" block).
- Source order for conflicts (first wins): rules = shared/rules,
  .claude/rules, <dotprofile>/claude/rules; hooks = shared/hooks,
  .claude/hooks; skills = shared/skills, .claude/skills. A missing source
  directory (e.g. .claude/hooks does not exist on main) is an info log, not
  an error.
- If a delegate must change this contract it records a "Contract change"
  section with the reason in its PR body and its hand-back.

## Ownership (do not edit)

- M3-LEAD: scripts/aitools-profile.*, scripts/setup-user-config.*, aitools
  user init code, and every file in open M3 PRs #79, #80, #82, #83, #84 --
  which include scripts/aitools-install.sh/.ps1, scripts/aitools-lib.sh/.ps1,
  scripts/aitools, scripts/aitools.ps1, scripts/setup-user-claude.sh/.ps1,
  .claude/rules/config-file-safety.md, .github/workflows/check.yml,
  tests/profile/. Check `gh pr list -R nobul-tech/aitools --state open`
  before touching any file; if a file is in an open PR you do not own, do not
  edit it -- report what you would change.
- DIFF-UX (PR #81): prompt_diff_review display code, tests/managed-files,
  reference/managed-file-deployment.md until #81 merges.
- Between S3-H delegates: each prompt lists the files the delegate owns.

## Missions (sequenced by S3-Harness)

| Delegate | PR scope | Depends on |
|----------|----------|-----------|
| S3-H-Core | scripts/deploy-harness.sh/.ps1, tests/deploy-harness/, reference/harness.md conflict section, approved protected rows (aitools-workspace.md, script-standards-detail.md) | none |
| S3-H-Cursor | setup-user-cursor.sh/.ps1 rules fan-out + canary test | none (seeds ~/.aitools/rules in isolated HOME) |
| S3-H-ToolOps | /tool-ops and /aitool-ops skill fallback to ~/.aitools/reference | none |
| S3-H-MDM | build-deploy.sh deploy/deploy-harness.* + setup-user-cursor MDM port | Core, Cursor merged |
| S3-H-Hookin | aitools-install Step 8b, deploy_configs loop, bin step moved out of installer | Core merged, M3 PRs on those files merged |
| S3-H-Claude | setup-user-claude fan-out, stop direct dotprofile rules, tests/rules-fanout/ | Core merged, #83 merged |
