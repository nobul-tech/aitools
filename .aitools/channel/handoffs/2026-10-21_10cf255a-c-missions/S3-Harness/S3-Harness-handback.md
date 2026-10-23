# S3-Harness hand-back (mission HARNESS), 2026-10-22

## Summary
1. Four PRs are open: #88 (deploy-harness core), #87 (Cursor rules fan-out), #85 (tool-ops fallback) and #93 (MDM generator). Each has an independent reviewer verdict on the PR, and none has an unresolved blocking finding.
2. Two missions have not started. S3-H-Hookin (installer Step 8b, the deploy_configs loop, removing the installer's bin step) and S3-H-Claude (setup-user-claude fan-out plus tests/rules-fanout/) are blocked by open M3 PRs. For Hookin these are #80, #82, #83 and #89, which touch aitools-install.\*, scripts/aitools\* and aitools-lib.\*; for Claude it is #83.
3. One design question needs a commander decision before Hookin and Claude can run: should `.claude/rules` (the aitools "(this repo)" rules) go to user level at all? See question Q1.
4. Contract correction issued during the mission: fan-out consumers copy only `*.md` from ~/.aitools/rules and skip `*.bak.*`. The cause is that backup_file writes `<file>.bak.<ts>` next to the file (scripts/aitools-lib.sh:382). #87 applies the correction in 118a79c.
5. #92 (M3 B8b) also edits setup-user-cursor.\*. A test merge of its branch with #87's branch is clean (`git merge-tree --write-tree` showed no conflicted files).

## PRs and merge order
1. #85 https://github.com/nobul-tech/aitools/pull/85: independent of the others; mergeable.
2. #88 https://github.com/nobul-tech/aitools/pull/88: deploy-harness.sh/.ps1, tests (45/45), reference/harness.md section, aitools-workspace.md rows, script-standards-detail.md tool name, managed-file-deployment.md (rule) content sources.
3. #87 https://github.com/nobul-tech/aitools/pull/87: Cursor fan-out to ~/.cursor/rules/\*.mdc. Tests: 78 pass, 1 skip. It can merge before or after #92.
4. #93 https://github.com/nobul-tech/aitools/pull/93: build-deploy MDM generation. Merge it after #88 and #87, because its branch already contains both. Tests: 29/29.

After merging, the commander rebuilds the dotprofile deploy/ (build-deploy, real HOME) and commits it. No agent did this.

## Remaining
- **S3-H-Hookin**, after #88 and the M3 PRs on those files merge. Constraints come from the S3-H-Core hand-back:
  - Step 8b runs after Node.
  - setup-user-config is already first in the deploy list, so putting deploy-harness first runs the writer twice.
  - Do not pipe deploy-harness's stdin.
  - Only exit 2 means abort.
  - Remove the installer bin step.
- **S3-H-Claude**, after #83 merges: setup-user-claude copies ~/.aitools/rules/\*.md (skipping \*.bak.\*) to ~/.claude/rules, stops deploying dotprofile rules directly, and gets a regression test in tests/rules-fanout/.
- **reference/managed-file-deployment.md** content sources: a draft is at S3-H-Core/S3-H-Core-drafts/ on #88's branch. PR #81 owns the file, so the change goes in after #81 merges.
- **Hook follow-up**: shared/hooks/tool-ops-session-audit.sh should read ~/.aitools/reference first (S3-H-ToolOps).
- **Live Cursor canary**: not run, because the Cursor CLI is not logged in. The manual procedure is in S3-H-Cursor-research.md section C3 on #87's branch.

## Protected-file drafts awaiting approval
- /tool-ops skill Intent scope (#85 branch, S3-H-ToolOps-drafts/)
- registries/tool-ops.json Cursor entry and reference/tool-ops-cursor.md (#87 branch, S3-H-Cursor-drafts/)
- .claude/rules/deploy-paths.md MDM run order (#93 branch, S3-H-MDM-drafts/). The .mdc twin is not drafted.
- reference/managed-file-deployment.md content sources (#88 branch)

## Open questions, with suggested answers
- **Q1: should project `.claude/rules` reach user level?** The approved source list puts them in ~/.aitools/rules, which fans them out to ~/.claude/rules and ~/.cursor/rules. As a result:
  - the aitools-only "(this repo)" rules load in every repo;
  - in the aitools repo itself they load twice;
  - in Cursor, 17 always-apply rules load in every chat under ~.

  Suggested: limit rules to shared/rules plus the dotprofile claude/rules, and keep `.claude/rules` project-scoped. The same applies to `.claude/skills` (documentation-standards.md: project skills are not deployed). This needs your decision before S3-H-Claude ships.
- **Q2: retired rules.** A removed source rule stays in ~/.aitools/rules and in the tools' rule directories, and stays loaded. Suggested: deploy-harness writes a manifest, and consumers retire files that are no longer in it. This would be a follow-up PR.
- **Q3: MDM fresh endpoint.** The config writer needs reposPath/repoPath, so the MDM run exits 1 with "config.json not generated". Suggested: the MDM variant skips the writer and writes the OK row `config.json n/a (no bootstrap)`.
- **Q4: MDM payload size.** Each generated deploy-harness script is about 2.2 MB of embedded base64. Suggested: check the Jamf and Intune script limits with chrome-devtools. If either limit is exceeded, ship the payload as a data file in deploy/.
- **Q5: Windows repos path.** cross-platform.md says `C:\repos\`, while the user CLAUDE.md and aitools-install.ps1 use `%USERPROFILE%\repos`. Cursor user rules only load under %USERPROFILE%. Suggested: standardise on %USERPROFILE%\repos, which means a protected edit to cross-platform.md.
- **Q6: deploy-harness body markers.** Suggested: a small follow-up PR after #88 adds markers, so build-deploy can stop cutting at section headings.

## INCIDENT markers (not filed; from delegates)
- The managed-file-deployment.md "Adopt target" section and N-Q2 say a dotprofile adopt is committed and pushed. `_managed_adopt_notice` never commits or pushes. This predates the mission (S3-H-Core).
- The reference/harness.md intent says "architecture only", but the approved conflict section is operational (S3-H-Core).
- The fan-out contract has no rule for translating `paths:` scoping per tool. #87 anchors Cursor globs as `**/<p>` (S3-H-Cursor).
- `~/.cursor/AGENTS.md` (install Step 22) appears never to be loaded by Cursor (S3-H-Cursor).
- backup_dir only backs up a directory that contains \*.md, so an all-.mdc ~/.cursor/rules never gets a directory backup (S3-H-Cursor).
- reference/cursor-practices.md is stale about user rules (S3-H-Cursor).
- build-deploy's `rm -rf "$DEPLOY_DIR"` leaves a partial deploy/ if the build fails (S3-H-MDM).
- The pre-push step 7 trigger misses the new deploy-harness inputs (S3-H-MDM).
- The README's MDM run order omits deploy-harness (S3-H-MDM).
- The Windows repos path is inconsistent (S3-H-ToolOps; see Q5).
- scripts/check-path-refs-allow.txt:12 is stale (S3-H-ToolOps).

## Verification by S3-Harness
- #85: I read the aitool-ops diff, which is a read-order section only, and confirmed the PR is mergeable on 15cc56a.
- #88: I grepped for the git ls-files source, the \*.bak.\* skip and the `dup in` ERROR row (scripts/deploy-harness.sh:188,197,239).
- #87: I grepped for the step 4 \*.bak.\* skip (scripts/setup-user-cursor.sh:469) and the .mdc conversion. I also test-merged it with #92: clean.
- #93: I did not read it beyond the hand-back. Its reviewer reproduced the 29/29.
- Not done: I did not read all of reference/*.md as the packet asks of commanders. I kept my context small, as my launch prompt asked, and relied on the delegates reading their named subsets.

## Delegates
S3-H-Core, S3-H-Cursor, S3-H-ToolOps and S3-H-MDM. Each ran its own independent reviewer (-Review). Hand-backs are on each PR branch under .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/<name>/.
