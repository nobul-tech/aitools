NON-BLOCKING -- S3-H2-DraftsM3b-Review verdict on PR #105 (head f0eab8a, base origin/main 8a9dcb5) and dotprofile commit 525ee49

**Intent**: **Purpose**: Record an independent check of whether PR #105 and dotprofile 525ee49 write the #96 rows 5-8, 12 and 13 exactly as the commander approved them, and whether the rows held back were held for valid reasons. **Scope**: Rows 5, 6, 7, 8, 12 and 13, the corrected row 8 draft, and the no-behaviour-change claim. NOT a review of any other #96 row. NOT approval or merge of the PR. **Audience**: S3-H2-DraftsM3b (commits this file), S3-Harness2, the commander.

Blocking findings: 0. Minor findings: 4 (M1-M4 below). Reviewer: S3-H2-DraftsM3b-Review, 2026-10-22, macOS.

## Method

- `.scratch/session-h2rev/verify-rows.pl` (worktree scratch): for each target it takes the base bytes (`git show origin/main:<file>`, or `525ee49^` for the dotprofile), applies only the approved OLD->NEW pairs parsed from the draft `.edit.txt` files (plus, for row 7, the deletion of the interim `# Writers:` lines that the draft orders), and compares the result with the head bytes. Every OLD block had to occur exactly once. The script also checks that the approval page's fenced copy of each draft equals the draft file byte for byte, so the text compared is the text the commander approved.
- Code claims were checked with `git grep` / `git show` against origin/main 8a9dcb5, and with `gh pr diff` for the open PRs #98, #103 and #106.

## Per-row findings

| Row | Target | Applied? | Result |
|---|---|---|---|
| 5 | setup-user-config.sh/.ps1 `CONFIG_INTENT_JSON` scope | No (deferred) | Deferral holds |
| 6 | setup-user-config.sh/.ps1 header `Intent:` | No (deferred) | Deferral holds |
| 7 | aitools-profile.sh/.ps1 header `Intent:` | Yes | Byte-exact, nothing else changed |
| 8 | aitools-lib.sh/.ps1 relay section `Intent:` | No (held) | Hold valid; the corrected draft needs one more re-check (M1) |
| 12 | shared/claude-shared.md | Yes | Byte-exact, nothing else changed |
| 13 | dotprofile claude/CLAUDE.md | Yes (525ee49) | Byte-exact, nothing else changed |

### Row 7: applied, exact

- `PASS row 7 aitools-profile.sh: head == base + approved edits (byte-exact, 76168 bytes)`: edits 1a and 1b (sh), and the three `# Writers:` lines removed.
- `PASS row 7 aitools-profile.ps1: head == base + approved edits (byte-exact, 75435 bytes)`: edits 1a and 1b (ps1), and the `# Writers:` lines removed.
- Claims hold on main. `register` writes only `--out` (aitools-profile.sh:58, "`register` writes only the --out file"). `exception-set` and `migrate` call `commit_profile` (aitools-profile.sh:1132, 1545). build-deploy reads `AITOOLS_USER_REPO_PATH` (build-deploy.sh:188) and otherwise calls `resolve_user_repo_path` (build-deploy.sh:200). The embedded resolver is asserted in setup-user-claude/-settings/-cursor .sh and .ps1 (build-deploy.sh:2210-2211).
- The PR's follow-up note is accurate: build-deploy also copies `deploy/aitools-profile.sh/.ps1` as-is (build-deploy.sh:1636-1650), and the approved consumer list does not name those copies. That is an omission, not a false claim.

### Row 12: applied, exact

- `PASS row 12 shared/claude-shared.md: head == base + approved edits (byte-exact, 12299 bytes)`.
- Claims hold. `{{USER_REPO_PATH}}` is substituted (setup-user-claude.sh:111-112, 158-159; setup-user-claude.ps1:145, 148). `resolve_user_repo_path` and `Resolve-UserRepoPath` exist (aitools-lib.sh:286, .ps1:218, the PR's citations; I did not re-open those two lines).

### Row 13: applied in dotprofile 525ee49, exact

- `PASS row 13 dotprofile claude/CLAUDE.md: head == base + approved edits (byte-exact, 16093 bytes)`: edit 1 (R19) and edit 2 (the `nobul-{{PROFILE_NAME}}` -> `nobul-jose` repair).
- `PASS row 12/13 NEW R19 text identical`: the two templates now carry the same R19 lines.
- 525ee49 changes only `claude/CLAUDE.md` and is on the dotprofile's `origin/main` (`git branch -r --contains 525ee49`). The repair matches shared/claude-shared.md:29, which uses `nobul-jose`.

### Rows 5 and 6: not applied, deferral holds

- Open PR #98 changes `scripts/setup-user-config.sh` and `.ps1` (`gh pr diff 98 --name-only`). Under the mission-order rule, a file another open PR touches is skipped and handed to M3-FINISH.
- #98 does not change the row 5 or row 6 OLD text itself. No `+`/`-` line in its patch touches the header `Intent:`, `pass --machine-*`, or `CONFIG_INTENT_JSON` / `$configIntentJson`. Row 5 should therefore still apply unchanged after #98 merges, as the PR says.
- Row 6's VERIFY condition now holds on main: user init passes `--machine-id` / `-MachineId` (scripts/aitools:1027, 1021; aitools.ps1:1640). After #98, the one open question for row 6 is the PR's own point: callers can also pass `--no-machine`, so "then pass --machine-id" no longer names every caller option.

### Row 8: not applied, hold valid

- The approved text says "Consumed by: ... deploy-harness.sh/.ps1". On main this is false. deploy-harness.sh runs the writer directly (deploy-harness.sh:107, 109). deploy-harness.ps1 also runs it directly, in-process: `& $configWriter` at deploy-harness.ps1:98. Neither file calls `run_child_relayed` or `Invoke-ChildRelayed`: `git grep` over scripts/, tests/ and shared/ finds no relay call in either file.
- The other claims in the approved text hold. A failed child gets one `log_error` (aitools-lib.sh:613, 617; .ps1:518, 523, 527). The throw row is written only when SUMMARYTOOL is given (aitools-lib.ps1:519). The insertion anchors are aitools-lib.sh:468 and .ps1:398.
- **M2**: row 8 would have been deferred in any case. Open PR #103 changes `scripts/aitools-lib.sh` and `.ps1`, so the mission-order rule also applies. The PR body gives only the false-claim reason.

### Corrected row 8 draft (S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt)

- **M1 (re-check before re-approval)**: on 8a9dcb5, "Consumed by: no script yet" is true. Open PR #106 makes it stale. #106 adds `run_child_relayed` to scripts/aitools and aitools-install.sh to relay deploy-harness.sh, and adds `Invoke-ChildRelayed` to aitools-install.ps1 and aitools.ps1 for deploy-harness.ps1. See `gh pr diff 106`, the hunks containing `run_child_relayed "$script" ...`, `run_child_relayed "Step 8b: deploy-harness.sh"`, `Invoke-ChildRelayed "Step 8b: deploy-harness.ps1"` and `$harnessRc = Invoke-ChildRelayed $script ...`. Once #106 merges, the lib's relay is consumed by the installers and the `aitools` entry points, and deploy-harness is the child being relayed, not a consumer. Both the approved text and the corrected text then name the wrong consumers, and the opening "every parent script (installers, deploy-harness)" leaves out the entry points. Suggested: write the row 8 text after #106 (and #103) merge, with "Consumed by: aitools-install.sh/.ps1 and aitools / aitools.ps1 (relaying deploy-harness)". Use whatever #106 ships as the source.
- **M3**: the draft's rationale says its grep "finds only aitools-lib.sh/.ps1 and aitools-install.sh". It then says the only caller of the lib's copy is tests/profile/test-lib.sh, a file that the same grep pattern also matches. The conclusion is right, but the sentence contradicts itself. This affects the rationale only, not the proposed intent text.

## No behaviour change

- `git diff -U0 origin/main HEAD -- scripts`: every added or removed line in scripts/ starts with `#`. There are 0 non-comment changes.
- `bash -n scripts/aitools-profile.sh`: OK. The pwsh parser (`[Parser]::ParseFile`) on scripts/aitools-profile.ps1: PARSE OK. These are the only scripts the PR touches; setup-user-config and aitools-lib are unchanged in this PR.
- Tests run from the worktree (each test isolates HOME itself):
  - tests/profile/test-config.sh: 190 passed, 0 failed
  - tests/profile/test-lib.sh: 209 passed, 0 failed
  - tests/profile/test-profile.sh: 689 passed, 0 failed
  - tests/profile/test-user-init.sh: 200 passed, 0 failed
  - tests/logging/test-logging.sh: 24 passed, 0 failed
  - tests/logging/test-logging.ps1: 15 passed, 0 failed, 5 skipped

## Other

- **M4**: the PR body cites "register writes only `--out` (aitools-profile.sh:56)". The line on main is :58. This is a citation nit only.
- Intent format (/intent-writing): row 7 keeps the code-intent shape (purpose, NOT exclusions, "Consumed by"). The text is the approved text, so I did not suggest any wording change.
- Not run by this reviewer: check-pre-commit and check-pre-push, build-deploy, Windows / Git Bash.
- INCIDENT: none new.
