VERDICT: APPROVE WITH CHANGES

Independent review of PR #120 (FO-0b, FX-12) by S3-FanoutImpl-Review120. Head reviewed: 978e72d. Diff: `git diff d7f6855...978e72d` (scripts/build-deploy.sh post-build step 3 and the end-of-build list; tests/deploy-harness-mdm/test-deploy-harness-mdm.sh).

## Summary

The code does what it says. Every generated `deploy/*.ps1` (200,000 B) and `deploy/*.sh` (1,000,000 B) is measured after the CRLF conversion. A file at or over its limit gets a WARN where it is measured and again in a list after "Build complete". The build exits 0. A missing `deploy-harness.ps1/.sh` still fails the build. Tests and CI are green. Nothing blocks the merge. The three non-blocking items below are one decision to confirm and two small comment fixes.

## Correctness against the decision (FX-12 / D3, Q16 "accepted")

- D3 (`S3-Reconcile-Fix-backlog.md`:323) asks "oversized generated scripts: WARN or FAIL?" and suggests WARN. Q16 accepts that (`plans/fan-plan-reconciliation.md`:104). The PR implements WARN for all generated scripts (`scripts/build-deploy.sh`:2533-2562).
- The FX-12 draft (`S3-Reconcile-Fix-drafts/code/edits-pr111.txt`:10) skipped `deploy-harness.*` in its WARN loop, so #111's deploy-harness FAIL stayed. The PR turns that FAIL into a WARN as well. The PR body declares this deviation and gives a measured reason: `deploy-harness.ps1` is 202,519 B on the integration base, so the FAIL breaks `tests/claude-mdm` and every FO branch. I reproduced the 202,519 B figure (fixture build, below). The mission brief also says "WARN for every generated script". I accept the deviation, but see N1.
- Exit status: build-deploy has no warning counter. `blog_warn` (`:50`) only prints, so the `printf | while` subshell at `:2580` loses nothing, and the build ends with exit 0. The size block runs before the staged-build swap (`:2564`), so a measurement failure (`:2541-2544`, exit 1) still leaves `deploy/` untouched.
- bash 3.2: the change uses no associative arrays or `mapfile`. It passes `/bin/bash -n`.

## Limits: source

- 200 KB and 1 MB are quoted verbatim from learn.microsoft.com. S3-MdmPkg checked both with chrome-devtools on 2026-10-26: "The script must be less than 200 KB (ASCII)." and "The script file must be less than 1 MB in size." (`S3-MdmPkg/S3-MdmPkg-Intune-notes.md`:18,23). The code comment carries the same quotes (`scripts/build-deploy.sh`:2520-2522).
- The decimal byte values 200,000 and 1,000,000 are our reading, not Microsoft's. The docs do not say whether "KB"/"MB" means 10^3/10^6 or 2^10/2^20. The decimal values are the stricter reading, so the gate is safe, but the comment does not say this is a choice (N2).

## Findings

Blocking: none.

Non-blocking:

- **N1 (decision to confirm): `scripts/build-deploy.sh`:2546-2550, the deploy-harness FAIL becomes a WARN.** HARNESS Q4 moved the payload into a data file so that `deploy-harness.*` would fit the Intune script channel, and #111 enforced that with a FAIL. After this PR, a `deploy-harness.ps1` that cannot ship as an Intune platform script (it is over the limit today) builds green with a WARN. D3's "WARN" covers it by its wording, but the accepted FX-12 draft kept the FAIL. Suggested: add one line to the PR's "Review after" section naming this (old: deploy-harness over the limit fails the build; new: WARN), so the commander confirms it after the merge. Link it to FX-35, which brings the file back under the limit.
- **N2 (comment): `scripts/build-deploy.sh`:2520-2526.** Say that 200,000 / 1,000,000 B is the decimal, stricter reading of "200 KB" / "1 MB" and is our choice. Suggested wording: `(KB/MB read as 10^3/10^6 bytes, the stricter reading; our choice)`.
- **N3 (stale comment): `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`:14.** The header still lists the case as "scripts under the Intune size limits". Suggested: "the size gate (a script over the Intune limit is a WARN, the build passes)".
- **N4 (test, for later): `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`:169-190.** The over-limit branch is only tested while real generated scripts are over the limit (7 today). After FX-35 brings them all under, that branch is no longer exercised and the check passes without testing it. The test also no longer guards the HARNESS Q4 property that deploy-harness stays under the limit. Suggested: when FX-35 lands, add a check that `deploy-harness.*` is under the limit, and add a forced over-limit case (for example, pad a copy of the sources). The test is adequate today: reverting to the FAIL makes it fail (build rc 1), and dropping either WARN line makes it fail (count is not 2).

## What I ran (macOS, review worktree at 978e72d; the suites use isolated HOMEs and fixture dotprofiles)

- `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (KEEP_TMP=1): 64 passed, 0 failed. "PASS size gate: a generated script over its Intune limit is a WARN, not a build failure (FX-12)".
- Fixture build output (`build-b1.out`): exit 0. 7 inline WARNs, the same 7 in the end list: aitools-profile.ps1 244457, deploy-harness.ps1 202519, setup-user-claude.ps1 477328, setup-user-cursor.ps1 474386, setup-user-hooks.ps1 313686, setup-user-settings.ps1 435488, setup-user-skills.ps1 368502. `deploy-harness.sh` OK at 188534. No `.sh` over the limit.
- `bash tests/claude-mdm/test-claude-mdm.sh` (bash 5.3.15): 34 passed, 0 failed.
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/claude-mdm/test-claude-mdm.sh` (bash 3.2): 34 passed, 0 failed.
- `bash -n` and `/bin/bash -n` on scripts/build-deploy.sh, and `bash -n` on the test: all rc 0.
- `gh pr checks 120 -R nobul-tech/aitools`: all pass (linux, macos, windows, CodeQL and the Analyze jobs).

## Not run

- Windows / pwsh run of the generated scripts. check-pre-commit and check-pre-push (the author ran them; known failures in steps 6 and 7). A build against the real dotprofile.
- I did not read the author's hand-back or scratch.

-- S3-FanoutImpl-Review120 (level 2, under S3-FanoutImpl, Session Commander 10cf255a-c)
