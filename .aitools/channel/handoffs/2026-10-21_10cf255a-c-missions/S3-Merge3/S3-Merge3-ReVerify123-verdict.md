VERDICT: MERGEABLE

# S3-Merge3-ReVerify123 verdict on PR 123 (FO-5 Cursor), v1.0

This is an independent re-review of PR 123's final head, written by S3-Merge3-ReVerify123 for the MERGE-3 orchestrator (S3-Merge3). It follows the commander's order of 2026-10-28: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise."

- **Head SHA:** `25a32861fbbc1ca5e05689ba22518697625ea9f2` (`feature/fanout-cursor`), base `main`, mergeStateStatus `CLEAN` (read twice)
- **Earlier review:** S3-Merge2-Review123, MERGEABLE at `096a8bf`, 0 blocking findings
- **Reviewed here:** `096a8bf..25a3286`. That is 8dbbea1 (merge b5a881a), 9c2d025 (ordinal fan-out), 0151f53 (merge add7a09), 1c3d87c (merge 3e00085, PR 121) and 25a3286 (merge ba8ec2c, PR 124). I read `git show --remerge-diff` for every merge.
- **Blocking findings:** 0

## Blocking findings

None.

## Non-blocking findings

1. **The cursor suite does not test the pwsh side of dupcase.**
   - In `tests/rules-fanout-cursor`, the dupcase case runs only the .sh. It has no `parity` call.
   - So nothing in CI tests 9c2d025's `CompareOrdinal` sort in `setup-user-cursor.ps1`. The same lines in `setup-user-claude.ps1` are covered by `parity dupcase` in `tests/rules-fanout`.
   - I checked it by hand. A scratch copy of the suite added a dupcase parity probe and ran on a case-sensitive APFS volume under LC_ALL=en_US.UTF-8 and LC_ALL=C. The .ps1 deploys `Foo.mdc` and not `foo.mdc`, and its tree, rows and exit code equal the .sh's (5/5 PASS in each locale).
   - Follow-up: add `parity dupcase <seed>` to the cursor suite.
2. **Two retired-prune lookups still use locale order.** This is the earlier review's finding 2, unchanged since 096a8bf.
   - In `setup-user-cursor.sh`, the loop over `"$CURSOR_RULES_DIR"/*` (about line 781) and the backup candidates `"$rm_name".bak.*` (about line 810) are globs, so they sort by LC_COLLATE.
   - The .ps1 twins (about lines 752 and 782) use `Sort-Object -CaseSensitive`, which sorts by culture.
   - This is the class of bug that broke CI on the new runner image. Here it only changes which of two case-variant files is pruned first; the other goes on the next run. The yes/no decision on a candidate does not depend on order, and no test exercises it.
   - Follow-up: make both ordinal, the same way 9c2d025 did (`LC_ALL=C sort` / `CompareOrdinal`). main's `setup-user-claude` has the same pattern, so the fix is outside this PR.
3. **Ordinal means two slightly different things in the two shells** (cosmetic). `LC_ALL=C sort` compares UTF-8 bytes, and `CompareOrdinal` compares UTF-16 code units. The two orders differ only between characters above U+FFFF and characters U+E000-U+FFFF. Rule names are ASCII, so this does not affect anything today.
4. **The PR body still has stale lines.**
   - Line 11 says "Merge those two first".
   - Line 83 says the verification ran "after merging ... origin/main 167dcbe".
   - The body's new section, which covers 9c2d025, 1c3d87c and 25a3286, is current.
   - The title and body have no closing keyword followed by `#N` or a URL. Neither do the commit messages in `origin/main..25a3286` (all read).

## Checks

**9c2d025 is correct in both languages and runs on bash 3.2.**
- The .sh collects the paths, all in one directory, then pipes them through `LC_ALL=C sort`. It handles a sort failure with a `log_warn` and falls back to directory order. The preserved loop reads a here-string on fd 3, which bash 3.2 supports.
- The .ps1 replaces `Sort-Object Name` with `[Array]::Sort(..., CompareOrdinal(Name))`.
- The four sites match in setup-user-claude and setup-user-cursor: the rule sources, the dangling links, and the preserved listing in each language.
- The tests now assert the ordinal winner: A.md in rules-fanout, Foo.md in rules-fanout-cursor.

**setup-user-claude has exactly one copy of the ordinal lines.**
- `.sh` has one "Deploy in ordinal" block (2 sorts, lines 457-477) and one sort in the preserved listing (line 686).
- `.ps1` has two `CompareOrdinal` sites (lines 391 and 671).
- `git diff origin/main...HEAD` does not touch setup-user-claude, because PR 121's lines are byte-identical.

**setup-user-cursor ordering is ordinal** at all four 9c2d025 sites (.sh lines 633-648 and 873-898, .ps1 lines 538 and 870). The exceptions are in non-blocking finding 2.

**The conflict resolutions keep both sides' intent.**
- 8dbbea1, README: main's #132 layout, plus FO's run-order sentence.
- 1c3d87c, README: main's sentence (PR 121's wording).
- 1c3d87c, deploy-harness-mdm: main's size-gate comment, and FO-4's `mkdir -p "$DOT_BIG/claude"` kept.
- 0151f53 and 25a3286: no conflicts. 25a3286 brings PR 124's NB1 `utf8large` case, auto-merged with the Cursor cases.

**check.yml keeps every main step.** I compared the parsed YAML of origin/main `f681e8f` and the head with a Ruby YAML step-by-step compare:
- Every main step is present, identical and in order: macos 46/47, linux 31/31, windows 16/16 (main/head).
- The only head-only step is `Cursor rules fan-out tests (macOS /bin/bash 3.2)`.
- The FO-0 step "Every test suite is in CI", run on the head tree, prints: "All 20 test suites are in CI or exempt" (rc 0).

**No test is dropped.**
- `tests/rules-fanout-cursor` at 25a3286 equals 096a8bf plus 9c2d025: 5 lines, 1 assertion replaced by 2 stricter ones.
- The `check` lines it drops relative to main are FO-5's reworked scenarios, already reviewed at 096a8bf. Each has a rewritten counterpart (users, nomanifest, badheader, invalid, onlyremove, bracket, edited, bodymark, lonecr, dryprune, empty, cursor MDM header).

**No unrelated change.** `git diff --stat origin/main...origin/feature/fanout-cursor` lists 7 files, all FO-5:
- check.yml
- setup-user-cursor.sh and .ps1
- the tests deploy-harness-mdm, fanout-lib, rules-fanout-cursor and skills-fanout

The two-dot diff also shows 3 mission-record files that main gained after ba8ec2c. A merge keeps them.

**CI on 25a3286 is all SUCCESS.**
- CI run 40807831568: macos, linux, windows.
- CodeQL run 40807826983: actions, javascript-typescript, python, ruby, plus the CodeQL check.
- Both runs' headSha is 25a3286.
- The linux log shows the dupcase cases ran and passed. That includes "dupcase: Foo.md deployed (ordinal order)" and "case-only duplicate: ordinal order, A.md deployed and a.md failed", with the parity checks.

## What I ran

All runs were on macOS arm64 in a new detached worktree, `/Users/new-jose/repos/aitools/.claude/worktrees/m3-rr123` at 25a3286. Every suite ran under an isolated HOME. The shells were bash 5.3.15, `/bin/bash` 3.2.57 and pwsh 7.6.3.

Syntax:
- `bash -n` (bash 5 and 3.2): setup-user-cursor.sh, setup-user-claude.sh, aitools-lib.sh and the five touched tests, all rc 0.
- pwsh ParseFile: setup-user-cursor.ps1, setup-user-claude.ps1, aitools-lib.ps1, all parse OK.

On the default case-insensitive APFS volume, results were identical under LC_ALL=en_US.UTF-8 and LC_ALL=C:

| Suite | Result |
|---|---|
| rules-fanout-cursor (bash 5 + pwsh) | 215 passed, 0 failed, 1 skipped |
| rules-fanout-cursor (/bin/bash 3.2 --bash-only) | 140 passed, 0 failed, 22 skipped |
| rules-fanout (bash 5 + pwsh) | 118 passed, 0 failed, 1 skipped |
| rules-fanout (3.2) | 44 passed, 0 failed, 23 skipped |
| skills-fanout (bash 5 + pwsh) | 219 passed, 0 failed, 1 skipped |
| skills-fanout (3.2) | 88 passed, 0 failed, 37 skipped |

On a case-sensitive APFS scratch volume, where the dupcase cases run, results were again identical under en_US.UTF-8 and C:

| Suite | Result |
|---|---|
| rules-fanout-cursor (bash 5 + pwsh) | 219 passed, 0 failed, 0 skipped |
| rules-fanout-cursor (3.2) | 144 passed, 0 failed, 21 skipped |
| rules-fanout (bash 5 + pwsh) | 123 passed, 0 failed, 0 skipped |
| rules-fanout (3.2) | 46 passed, 0 failed, 23 skipped |
| skills-fanout (bash 5 + pwsh) | 223 passed, 0 failed, 0 skipped |
| skills-fanout (3.2) | 89 passed, 0 failed, 37 skipped |
| cursor suite + dupcase pwsh parity probe (scratch copy) | 224 passed, 0 failed, 0 skipped |

Lessons from this run:
- macOS `mktemp -d` ignores TMPDIR when it gets no template. My first "case-sensitive" pass therefore silently ran on the default volume; it reported the same counts and the dupcase cases skipped.
- I reran the pass with a scratch `mktemp` shim on PATH, and confirmed with a probe file that the temp dir was case-sensitive.
- A suite run "on volume X" is only proven by its skip lines.

## Not run

- Windows (native pwsh and Git Bash). Linux was not run locally either; CI covers both and is green.
- check-pre-commit, check-pre-push and check-post-push.
- build-deploy.sh against a real dotprofile.
- The suites not named in my prompt (fanout-lib, deploy-harness-mdm and others). CI ran them green on 25a3286.

S3-Merge3-ReVerify123
