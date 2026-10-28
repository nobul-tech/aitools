VERDICT: MERGEABLE

# S3-Merge2-Review119 verdict v1.0 -- PR #119 (FO-2, deploy-harness skills manifest)

- Head SHA reviewed: `fd660a999b86a671d616571b83f653ccfb73d7f0` (feature/fanout-harness-skills)
- Reviewed against: origin/main `86a0ea8` (trial 1) and `2a505c4` (trial 2; it adds one line to `plans/build-package/design.md` and nothing else)
- Reviewer: S3-Merge2-Review119, independent, delegated by S3-Merge2. I did not read the other MERGE-2 reviewers' output.
- Ordered by the commander, 2026-10-28: "have the orchestrator launch a review first."
- Mergeable only after #118, as the train requires. GitHub shows `mergeStateStatus: DIRTY` because two files conflict with main. Both conflicts are mechanical; the resolutions are below.

## Blocking findings

None.

## What the PR changes once merged (effective diff against main)

After the trial merge the PR's net change on top of main is 4 files: `scripts/deploy-harness.sh` (320 lines changed), `scripts/deploy-harness.ps1` (390), `tests/deploy-harness/test-deploy-harness.sh` (232) and `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (13), 807 insertions and 148 deletions in total. That is the same on main+#117+#118. GitHub's "Files changed" list (45 files) is inflated: the branch merged integration bases and the #120 head whose content later reached main through other PRs. `scripts/build-deploy.sh` ends up identical to main's.

The last commit, fd660a9, came after the earlier re-verify at 58ff866 and no reviewer had looked at it. It is covered here: `discard_skill_backup` runs `chmod -R u+w` before `rm -rf`, and if the cleanup still fails it renames the leftover to `<name>.bak.incomplete.<UTC>` with an ERROR row. The `.ps1` twin clears ReadOnly and then calls Directory.Delete. The `.sh` and `.ps1` produce the same rows, and the error handling follows script-standards: each `2>&1` capture is read back, the one `> /dev/null 2>&1` has a comment and an exit-code check plus `[ ! -e ]`, and every catch logs.

## Expected conflicts and how to resolve them

### Trial 1: PR head merged with origin/main (`git merge --no-ff origin/main`)

Two files conflict. Both come from the old #120 head 978e72d that #119 merged at 4839571. Main already holds the later, reviewed #120 work (1b5ab5d, 44a4845: size-gate hints, the `SIZE_OVER` count, the forced over-1 MB case).

1. `scripts/build-deploy.sh`, 4 hunks (size gate comment, `SIZE_OVER=0`, the over-limit message with its hint, the end-of-build summary). **Take origin/main's side in all 4.** Main's side is a superset of the old #120 head. FO-2 makes no build-deploy change of its own, so the result equals main's file.
2. `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, 5 hunks.
   - **Header comment (hunk 1):** take main's wording, then add the PR's case back. Change `# port and step 4 (MDM), no adopt target in MDM, first run / rerun / edit / dry` to two lines: `# port and step 4 (MDM), no adopt target in MDM, dotprofile rules and skills` and `# embedded (skills manifest same as dev), first run / rerun / edit / dry`.
   - **`--help` range (hunk 2):** the header is now one line longer, so set `$. <= 30` (main has 29, the PR has 28).
   - **Hunks 3-5:** take main's side: `SIZE_GATE_OVER`, `size_gate_warned` with hints, and the forced `dot-big` case. Never drop main's forced size-gate test. The PR's two dotprofile-skill checks sit outside the conflict and auto-merge.

### Trial 2: origin/main with #117 and #118 merged first, then #119

#117 and #118 each conflict with main in `.github/workflows/check.yml`. Their reviewers own those conflicts; I kept both sides only to build the base. On that base #119 conflicts **only in `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, hunks 1-2**: the same header and `--help` range as above, resolved the same way (main's wording plus the skills phrase, `<= 30`). `scripts/build-deploy.sh` merges cleanly there.

None of this touches #128's or #129's layout. FO-2 changes no skill path: the fixtures build their own `shared/skills` and `.claude/skills`, and nothing references `aitool-ops`, `aitool-eval` or the moved governance skills.

## What I ran (macOS, isolated HOME under `.claude/worktrees/m2-rv119/.scratch/session-rv119/`, AITOOLS_USER_REPO_PATH and AITOOLS_LOG_DIR unset)

| Suite | Trial 1 (main + #119) | Trial 2 (main + #117 + #118 + #119) |
|---|---|---|
| tests/deploy-harness/test-deploy-harness.sh | 131 passed, 0 failed | 131 passed, 0 failed |
| same, /bin/bash 3.2 first on PATH | 131 passed, 0 failed | 131 passed, 0 failed |
| tests/deploy-harness-mdm/test-deploy-harness-mdm.sh | 67 passed, 0 failed (size gate included) | 67 passed, 0 failed |
| tests/claude-mdm/test-claude-mdm.sh | 34 passed | 34 passed |
| tests/build-deploy/test-build-deploy-backup.sh (#131) | 24 passed | 24 passed |
| tests/rules-fanout-cursor/test-rules-fanout-cursor.sh | 164 passed, 1 skipped | 164 passed, 1 skipped |
| tests/fanout-lib/test-fanout-lib.sh (#118) | n/a | 374 passed |
| tests/hookin/test-hookin.sh | not run | 46 passed |
| tests/b8-consumers/test-b8-consumers.sh | not run | 60 passed |
| tests/build-package/test-cli.sh | not run | 36 passed |

- `bash -n scripts/deploy-harness.sh`: OK. `/bin/bash -n` on the merged MDM test: OK.
- PowerShell parser on `scripts/deploy-harness.ps1`: OK. CRLF on all 827 lines.
- Section markers that build-deploy extracts (`BEGIN/END scope`, `body`, `config bootstrap check`, `dotprofile lookup`) are unchanged. The new `add_source skills "dotprofile/skills" ...` line sits inside the dotprofile block, and the MDM suite proves the parser embeds and deploys the dotprofile skill (deploy-paths rule, extract + embed).
- CI on head fd660a9: macos, linux, windows, CodeQL and all four Analyze jobs pass. Main's workflow does not run the deploy-harness suites yet; #117 adds them, and in trial 2 they pass locally.

**Not run:**
- Windows: no machine available. The `.ps1` ran on pwsh (macOS) inside the suite's trace-parity check.
- The #117 "every tests/*/test-*.sh is in CI" step. #119 adds no new suite, so the step has nothing new to flag.
- `check-pre-commit`, `check-pre-push`, `check-post-push`.

## Non-blocking findings

1. **The PR body is stale on several points; the orchestrator should correct it or add a note before merging.**
   - It says "Contains #120 ... Merge #120 first". #120's reviewed content (1b5ab5d, 44a4845) is already on main through other merged PRs. The old #120 head inside #119 is superseded, and that is the source of the build-deploy conflict.
   - It says "tests/deploy-harness-mdm fails on the base already" and calls the size gate a blocker. On main the gate is a WARN, and the suite now passes 67/67.
   - The test counts (113, then 127) are out of date: it is now 131.
2. **Old `.bak.incomplete.<UTC>` leftovers are never pruned and never reported again.**
   - In the `.sh`, `discard_skill_backup` (around line 575) leaves a leftover that the prune skips by design.
   - The preserved scan skips it too, because of its `.bak.` component.
   - After its one ERROR row it stays silently. Suggest FO-7 docs or a later WARN on any `*.bak.incomplete.*` found.
3. **Upgrade path: skill directories deployed before the first skills manifest are never retired.**
   - For example, `aitool-ops` or `aitool-eval` copies in `~/.aitools/skills` from before #129.
   - On the first run nothing is retired (the contract says so), so they are logged as "Preserved" on every run.
   - This is the contract working as designed. Suggest #125 (skills legacy) or FO-7 records it.
4. **Comment drift in `scripts/deploy-harness.ps1:624`.** `Remove-RetiredSkill` says "(Copy-Item -Recurse; ...)", but the code uses `Copy-SkillTree` (.NET). Also, `deploy-harness.sh:525` and `.ps1:490` say "as backup_dir keeps 5", but the retire no longer calls backup_dir. Fix in FO-7 or the next touch.
5. **Noise in the summary log line.** The final log line always contains `N would retire (dry run)`, even on a real run (`0 would retire (dry run)`). It is cosmetic and identical in `.sh` and `.ps1`.
6. **Stale comments in `scripts/build-deploy.sh`.** As the PR body already notes, they still say "5b rules manifest" and "section 4 reads $DOTPROFILE/claude/rules". The MDM generator needed no change, so this is comment drift only.

## Merge note for the orchestrator

Merge after #118. Resolve as described above (`git merge --no-ff origin/main` on the branch), push the fix commit, and wait for CI to go green on the new head. Then get a re-verify comment on the new head before merging. The resolution is mechanical, but the brief requires a verdict on the final SHA.
