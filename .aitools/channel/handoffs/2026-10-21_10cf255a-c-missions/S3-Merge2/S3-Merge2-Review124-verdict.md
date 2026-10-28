VERDICT: MERGEABLE

# S3-Merge2-Review124 verdict v1.0 -- PR #124 (FO-4, Claude skills fan-out)

Reviewer: S3-Merge2-Review124. I am an independent reviewer delegated by S3-Merge2 (mission MERGE-2). Date: 2026-10-28. I review this PR because of the commander's order of 2026-10-28: "have the orchestrator launch a review first."

- **Head SHA reviewed:** `282c28b99c586ca2df6aea74b108af9523029303`
- **Reviewed against:** current origin/main `86a0ea8`
- **Blocking findings:** 0
- **Non-blocking findings:** 4 (NB1 to NB4)

The verdict has conditions. The code is correct. But the PR cannot merge as it stands, because GitHub reports it `DIRTY` and the linux CI job is red. It becomes mergeable when all of these are true:

1. #118 and #121 are on main.
2. origin/main is merged into `feature/fanout-claude-skills` with `--no-ff`, and the three conflicts below are resolved as described.
3. CI is green on the new head.
4. A reviewer re-verifies the new head SHA.

Merge order: #124 merges after #121.

## CI status at 282c28b (run 40452345346)

These jobs passed: macos, windows, CodeQL and Analyze.

The **linux** job failed in one step, "Fan-out lib helper tests". The suite ran 356 tests: 356 passed and 2 failed, `FAIL ps bd-special` and `FAIL parity bd-special`. In that case, Linux pwsh `Backup-Dir` pruned the decoy `r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z` and kept `r[1]*?.bak.2020-01-02T000000Z`, which it should have pruned.

**This clears once #118 is merged in.** The evidence:

- `git log origin/feature/fanout-claude-skills..origin/feature/fanout-lib` lists 11 #118 commits that #124 does not have yet. One of them is `32a1354` "Prune old directory backups with .NET calls in Backup-Dir". Its message describes this exact Linux failure and fixes it.
- #118's own CI at `d29dc5f` (run 40460911036, linux job) shows `ok sh bd-special`, `ok ps bd-special` and `ok parity bd-special`. Every check on #118 is green.
- I merged #118's head into #124 and ran tests/fanout-lib on macOS: 374 passed, 0 failed. I could not run Linux pwsh locally, so the Linux result rests on #118's CI.

The red linux job is therefore not a defect in #124. It must still be green on #124's next head before the merge.

## Trial merges

### 1. #124 head onto origin/main 86a0ea8 (`--no-ff --no-commit`, then aborted)

The merge stops with three conflicts. All three are mechanical. `scripts/aitools-lib.sh/.ps1`, `scripts/build-deploy.sh` and the other script files merged without conflicts.

- **`.github/workflows/check.yml`** (4 hunks, in the macos and linux jobs): keep both sides.
  - Keep main's "Installer Step 3/5 relay tests" steps for `tests/profile/test-install.sh`.
  - Keep main's "build-deploy backup + swap tests" steps for `tests/build-deploy/test-build-deploy-backup.sh`, from #131.
  - Keep all of #124's fan-out, deploy-harness, hookin, cursor and build-package steps.
  - Why it matters: dropping either side makes #117's "Every test suite is in CI" step fail, because `test-install.sh` and `test-build-deploy-backup.sh` are tracked suites.
- **`README.md`** ("Deploy to a machine" section): take main's text, which was rewritten in the #132 docs scrub. From #124, keep only the facts main lacks:
  - deploy-harness runs first;
  - the rules and skills fan-outs in setup-user-claude and setup-user-cursor read `~/.aitools`;
  - run before deploy-harness, they report `n/a (no harness ...)`.
- **`tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`**: take #124's side in all three hunks:
  - the header comment that says "dotprofile rules and skills embedded";
  - `--help` printing lines 2-30, because the header is one line longer;
  - the CLAUDE.md template padding.
  Main pads a rule file instead. That is no longer embedded once FO-3 is in, so main's version would make the forced size-gate case fail after #121.

### 2. Chain: origin/main + #117 + #118 + #119 + #121 heads, then #124

The chain stopped at the first step. `origin/feature/fanout-ci` (#117, `dbe8f46`) conflicts with origin/main in `.github/workflows/check.yml`. The conflict is the same kind of union: main's build-deploy-backup steps against #117's b8-consumers, deploy-harness, hookin, cursor and build-package steps. As instructed, I stopped there. #117's reviewer owns that conflict.

### 3. Extra trial: #124 + #118 head + #121 head, without main

I added this one because the chain stopped early. It predicts what #124 will look like once #118 and #121 are on main.

- #118 (`d29dc5f`) merged clean.
- #121 (`4339c08`) conflicted only in `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`. Both sides made the same fix there, the CLAUDE.md template padding (#121 in `4339c08`, #124 in `fcf6edc`). The differences are the comment wording and #124's extra `mkdir -p "$DOT_BIG/claude"`. To resolve: take #121's comment and keep the `mkdir -p`. It does no harm.

Suites I ran on the merged result. Each ran under an isolated outer HOME, and the suites also make their own temp HOMEs:

| Suite | Result |
|---|---|
| fanout-lib (bash 5 + pwsh) | 374 passed, 0 failed (includes bd-special) |
| fanout-lib (/bin/bash 3.2 --bash-only) | 134 passed, 0 failed, 1 skipped |
| skills-fanout (bash 5 + pwsh) | 185 passed, 0 failed, 1 skipped (case-only duplicate on APFS) |
| skills-fanout (/bin/bash 3.2 --bash-only) | 73 passed, 0 failed, 32 skipped |
| rules-fanout | 118 passed, 0 failed, 1 skipped |
| claude-mdm (bash 5 / 3.2) | 38 / 38 passed, 0 failed |
| deploy-harness-mdm | 67 passed, 0 failed |

The `bash -n` check (/bin/bash 3.2) passes on `scripts/aitools-lib.sh`, `setup-user-claude.sh` and `build-deploy.sh`. The PowerShell parser passes on `aitools-lib.ps1`, `setup-user-claude.ps1` and `deploy-harness.ps1`.

#118's `f69e2db` changes the tracker's empty fallback from "verified" to "n/a (nothing to deploy)". That fixes audit B N3 for the skills fan-out too, and no skills-fanout test breaks.

## Prior reviews

I read the earlier reviews; I did not re-derive them:

- S3-FanoutImpl-Review124: APPROVE WITH CHANGES at `fcf6edc`, then RE-VERIFY APPROVE at `7296a38`.
- Audits A and B: 0 blocking findings.
- Fixes: `5267e9e`, `3d351ac`, `2fdcefb`, and `282c28b` for R1.

**No reviewer has looked at `282c28b`, the current head.** I reviewed its diff. It changes `_fanout_is_binary` to an RFC 3629 regex and adds the utf8edge test case. NB1 below is a defect in that change. R2 and R3 from the re-verify are documentation items for FO-7; I confirmed they are still open.

## Blocking findings

None.

## Non-blocking findings

### NB1: large valid UTF-8 text files are classified as binary in .sh but not in .ps1

**Where:** `scripts/aitools-lib.sh`, `_fanout_is_binary`, introduced in 282c28b.

**What happens:** The new check is one match, `$c =~ /\A(?:[\x00-\x7F]+|...)*\z/`. Perl caps how many times a complex group like this can repeat, and when a file needs more repetitions than the cap, the match fails without any warning. A failed match means "binary". Each multi-byte character and each ASCII run between them is one repetition.

| Probe file | Size | sh result | ps result (`Test-FanoutBinary`) |
|---|---|---|---|
| 40,000 x `aé` | 120 KB | binary | text |
| 100,000 x `é` | 200 KB | binary | text |
| 40,000 x `é` | 80 KB | text | text |
| 1.9 MB of ASCII | 1.9 MB | text | text |

The probe used the function body extracted from the lib, perl on macOS. Scripts: `rv124-utf8probe.sh` and `rv124-utf8ps.ps1`.

**Effect:** For such a file, sh copies it byte for byte with no review menu, so a user's edit is overwritten (a backup is kept). ps shows the review menu. That breaks sh/ps parity, and the misclassification is silent.

**Why it is not blocking:** Today's largest tracked skill file is `shared/skills/delegate/SKILL.md`, at 29 KB (`git ls-tree -r -l origin/main -- shared/skills .claude/skills`). That is well under the size where this starts. Also, the bytes deployed are the same either way.

**Fix:** Walk the string with a `\G` loop, so no single regex match has to repeat the group:

```perl
pos($c) = 0;
1 while $c =~ /\G(?:[\x00-\x7F]+|[\xC2-\xDF][\x80-\xBF]|\xE0[\xA0-\xBF][\x80-\xBF]|[\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}|\xED[\x80-\x9F][\x80-\xBF]|\xF0[\x90-\xBF][\x80-\xBF]{2}|[\xF1-\xF3][\x80-\xBF]{3}|\xF4[\x80-\x8F][\x80-\xBF]{2})/gc;
exit((pos($c) // 0) == length($c) ? 1 : 0);
```

I tested this fix (`rv124-utf8fix.pl`). All the large files above come out as text. The R1 edge cases keep their expected results:

- binary: surrogate, above U+10FFFF, FF, overlong, truncated;
- text: noncharacter EF BF BE and an empty file.

Add a test case with a large multi-byte file of about 200 KB. This can go in this PR or in FO-5.

### NB2: the PR body has stale claims

- "Review diff: `git diff f897b74...fcf6edc`": the head is now `282c28b`.
- The Verification table says skills-fanout 168 / 66. At 282c28b the counts are 185 passed / 1 skipped, and 73 / 32 on 3.2. These come from the 282c28b commit message, and my run on the merged result matches them.
- "Contract change 7" does not list R1, the strict UTF-8 check.

Fix: update the body when the main merge commit is pushed.

### NB3: skills deleted before FO-2 shipped are never retired

`aitool-ops` and `aitool-eval` were deleted by #129. They were never in a `~/.aitools/skills` manifest, so the manifest-based retired prune (from FO-2) will never remove them from `~/.claude/skills` on existing machines. The fan-out counts them as preserved, unmanaged directories, and Claude Code keeps loading them.

This is a gap between #119, #124 and #125, not a defect in #124. Suggested route: have FO-6 (#125) prune the legacy setup-user-skills copies, or seed those two names as `retired` in the first manifest. Either way, record the choice in FO-7 (#126).

### NB4: the size-gate fix is duplicated

The size-gate fix in `tests/deploy-harness-mdm` exists in both #121 (`4339c08`) and #124 (`fcf6edc`). It will conflict a second time when main, with #121 in it, is merged into #124. Resolve it as described in trial 3.

## What I ran

- I ran `git fetch origin`, `gh pr view 124` (JSON, including comments and reviews), `gh run view 40452345346 --log-failed`, and the #118 run 40460911036 job log.
- I created the detached worktree `/Users/new-jose/repos/aitools/.claude/worktrees/m2-rv124` and ran:
  - trial 1, then `merge --abort`;
  - trial 2, which stopped at #117, then `merge --abort`;
  - trial 3 as local detached commits, never pushed.
  - At the end I checked the worktree back out to detached `282c28b`.
- I ran the suites in the table above. Nothing ran against the real HOME. I did not run aitools, setup-user-*, deploy-harness or build-deploy.sh myself; build-deploy runs only inside deploy-harness-mdm, under its temp HOME and fixture dotprofile.
- Scratch scripts and logs are in `/Users/new-jose/repos/aitools/.claude/worktrees/m2-rv124/.scratch/session-rv124/`:
  - `rv124-chain.sh`, `rv124-fold.sh`, `rv124-suites.sh`;
  - `rv124-utf8probe.sh`, `rv124-utf8fix.pl`, `rv124-utf8fixtest.sh`, `rv124-utf8ps.ps1`, `rv124-parse.ps1`;
  - `suites-fold/` for the suite logs.

## Not run

- Linux pwsh: the bd-special result on Linux rests on #118's CI, not on a run of mine.
- Native Windows.
- The fully resolved merge of #124 onto main, because the chain stopped at #117.
- A static re-read of the whole fan-out function. Three earlier reviews covered it, and I reviewed only the 282c28b delta in detail.
