VERDICT: MERGEABLE

# S3-Merge2-Review123 verdict on PR #123 (FO-5 Cursor), v1.0

Independent pre-merge review by S3-Merge2-Review123 for the MERGE-2 orchestrator (S3-Merge2). It follows the commander's order of 2026-10-28: "have the orchestrator launch a review first."

- **Head SHA reviewed:** `096a8bf7c15d30e2faedf80b92d1aaa387091ef0` (`feature/fanout-cursor`)
- **Reviewed against:** origin/main `86a0ea88faec50e13b9d49067f3894bb4c771bea`
- **Blocking findings:** 0
- **Condition:** GitHub shows the PR as `CONFLICTING` / `DIRTY` against main. Both conflicts come from the FO chain the PR carries, not from FO-5's own change (see "Conflicts"). Merge #123 only after #117, #118, #119, #121 and #124 are on main, and after origin/main has been merged into this branch with `--no-ff`. That merge creates a new head SHA, and the new head needs a re-verify comment (suites below plus green CI) before it merges.

## Scope

I reviewed FO-5's own change, `git diff origin/feature/fanout-claude-skills...HEAD` (9 files):
- `scripts/setup-user-cursor.sh` and `.ps1`, steps 4 and 5
- `tests/rules-fanout-cursor`
- the Cursor cases in `tests/skills-fanout`
- the edits to `tests/fanout-lib` and `tests/deploy-harness-mdm`
- `check.yml`

The round-2 fix commit `cb4d986` got a line-by-line read. It is the first review of the round-2 head: the earlier review and audits A and B were on `880749e`.

The lib content in #123 equals #118's: `git diff origin/feature/fanout-lib origin/feature/fanout-cursor -- scripts/aitools-lib.*` shows additions only (the FO-4 skills functions), and #123 does not modify #118's lib.

## Blocking findings

None.

## Non-blocking findings

1. **Stale PR body claims.**
   - "#123 contains #118 (ec6c4ac)": #118's head is now `d29dc5f`, which adds only a merge of main `4ca476f`. ec6c4ac is an ancestor of it, so this is harmless.
   - "Merge those two first": the train also puts #117, #119 and #121 before #123. #123 contains #117 (`dbe8f46`) and #119 (`fd660a9`) but not #121's last commit `4339c08` ("Pad the dotprofile CLAUDE.md template in the forced size-gate test").
   - The Verification table says it was run "after merging ... origin/main 167dcbe". Main is now `86a0ea8`, 44 commits later.
   - Fix: update the body when the final main merge is pushed.
2. **Glob order vs sort order in the case-insensitive retired lookup** (parity, cosmetic).
   - Where: `scripts/setup-user-cursor.sh:759-765` (bash glob, `*` skips dotfiles, locale collation order) and `scripts/setup-user-cursor.ps1:749` (`GetFiles` includes hidden files, `Sort-Object -CaseSensitive`).
   - When it shows: on a case-sensitive file system holding both `Gone.mdc` and `gone.mdc`, the two shells may prune a different file first. Each run handles one file per retired name, so the second file goes on the next run. A retired name that starts with `.` is matched only by the .ps1.
   - Fix: none needed now. Record it as a known limit in FO-7 (`reference/rules.md`).
3. **Legacy-content candidate lookup is case-sensitive.**
   - Where: `setup-user-cursor.sh:788` uses `"$HARNESS_RULES_DIR/$rm_name"` as written in the manifest; the .ps1 twin does the same.
   - When it shows: on Linux, with the manifest saying `Gone.md` and the harness file named `gone.md`, a marker-less PR #87 copy is not recognised. It is kept with a WARN and an ACTION row, never removed wrongly.
   - Fix: none needed. It fails safe.
4. **Follow-ups already listed in the PR body** stay open and do not block: A1 (row text over 30 characters), A5/B5 (`backup_dir` only for `*.md` dirs), A6 (stale lib comments), B7, B8, the case-sensitive `read_harness_manifest`, and FO-6's two writers.

Checks that came out clean:
- Every `log_error` path I traced ends in an ERROR row or a tracker `failed`.
- The `|| true` at sh:875 has its comment, and its result is checked.
- The fd-3 deploy loop is intact (sh:687/739).
- The step 5 calls match the FO-4 contract.
- No AI invocation is added: no adopt target, so no merge & adopt, and agentic-standards does not apply.
- `setup-user-cursor` stays pure extract for build-deploy (deploy-harness-mdm passes, including the "five things" header check).
- bash 3.2 syntax is OK.

## Conflicts (expected) and how to resolve them

**Trial 1: PR head + origin/main** (`git merge --no-ff --no-commit origin/main`). Two files conflict:
- `.github/workflows/check.yml` (macos and linux jobs).
  - Main added the steps for `tests/profile/test-install.sh` (#116) and `tests/build-deploy/test-build-deploy-backup.sh` (#131).
  - The FO chain added the steps for fanout-lib, rules-fanout, skills-fanout, b8-consumers, deploy-harness, deploy-harness-mdm, hookin, rules-fanout-cursor and build-package.
  - Resolve as the union: keep every step from both sides.
  - Keep `if: ${{ !cancelled() }}` on the FO steps, and add it to main's two new suites to match.
  - The "Every test suite is in CI" step then passes: 19 suites, 0 missing, checked on the union tree.
- `README.md`, the "Deploy to a machine" section.
  - Keep main's scrubbed v0.74.0 text and script list (#132).
  - Keep the FO sentence that the rules fan-outs in `setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` and report `n/a (no harness rules)` when run before deploy-harness.
- Auto-merged cleanly: `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`, `scripts/build-deploy.sh`.

Both conflicts are inherited (#117/#118/#121 content). They will already be resolved on main when the train reaches #123, so expect them to come back in the #123 branch as conflicts against the *resolved* versions. Take main's side for every line that is not FO-5's.

**Trial 2: origin/main + #117, #118, #119, #121, #124 heads in train order, then #123.** It stopped at the first PR: **#117 (`feature/fanout-ci`, dbe8f46) conflicts with main in `.github/workflows/check.yml`**, the same union conflict as above. That is the first conflict to report.

To see past it, I ran an extra trial (2b-2d, approximation only, never pushed):
- check.yml and README.md resolved with git's union driver.
- **#118** merged cleanly.
- **#119** conflicts with main in `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`:
  - the header comment, where main's size-gate text meets FO's "dotprofile rules and skills embedded" text;
  - the `--help` range `perl -ne 'print if $. >= 2 && $. <= N'`.
  - Resolve: combine both comment texts, then set N to the last line of the header comment.
- **#121** merged cleanly.
- **#124** conflicts in the same file:
  - the same header and `--help` hunks;
  - the size-gate padding comment;
  - FO-4's `mkdir -p "$DOT_BIG/claude"` line, which should be kept.
- **#123** on top of that tip conflicts only in the same test file's header and `--help` hunks.
  - FO-5's own hunk there (the cursor header check `Does five things:`) merged without conflict and must be kept.
  - Resolve the comment hunks to whatever #119/#124 settled on main.

## What I ran

All runs were on macOS arm64 in the detached worktree `/Users/new-jose/repos/aitools/.claude/worktrees/m2-rv123`. The tree was PR head 096a8bf merged with origin/main 86a0ea8 (no commit; union for check.yml and README.md only). Every suite ran under an isolated HOME and USERPROFILE. The merge was aborted afterwards.

| Suite | Result |
|---|---|
| `bash -n` setup-user-cursor.sh (bash 5 and `/bin/bash` 3.2), aitools-lib.sh | rc 0 |
| pwsh parser: setup-user-cursor.ps1, aitools-lib.ps1 | parse ok |
| tests/rules-fanout-cursor (bash 5 + pwsh) | 215 passed, 0 failed, 1 skipped |
| tests/rules-fanout-cursor (`/bin/bash` 3.2 `--bash-only`) | 140 passed, 0 failed, 22 skipped |
| tests/skills-fanout (bash 5 + pwsh) | 210 passed, 0 failed, 1 skipped |
| tests/skills-fanout (3.2) | 85 passed, 0 failed, 36 skipped |
| tests/fanout-lib (bash 5 + pwsh) | 336 passed, 0 failed |
| tests/fanout-lib (3.2) | 122 passed, 0 failed, 1 skipped |
| tests/deploy-harness-mdm | 67 passed, 0 failed |
| tests/deploy-harness | 131 passed, 0 failed |
| tests/rules-fanout | 118 passed, 0 failed, 1 skipped |
| tests/b8-consumers | 60 passed, 0 failed |
| tests/claude-mdm | 38 passed, 0 failed |
| tests/build-deploy/test-build-deploy-backup.sh (main #131) | 24 passed, 0 failed |
| tests/managed-files | 57 passed, 0 failed |
| check.yml "Every test suite is in CI" logic on the union tree | 19 suites, 0 missing |

**CI on 096a8bf:** all green (macos, linux, windows, CodeQL). These runs predate main's last 44 commits and the PR is now conflicting, so they are stale. A fresh run on the post-merge head is required before merge.

**Not run:**
- Windows (pwsh on Windows, Git Bash)
- Linux locally
- check-pre-commit, check-pre-push, check-post-push
- build-deploy.sh against a real dotprofile
- the exact final train merges, whose resolutions will differ from my union approximation

S3-Merge2-Review123
