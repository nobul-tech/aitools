VERDICT: MERGEABLE

# PR 121 re-verify v1.0 (FO-3: Claude rules fan-out), final head

- **Head verified:** `b86a99d8109c37ff5dba7ebcc37a0b1c57bff2af` (`feature/fanout-claude-rules`), base `main`
- **Reviewer:** S3-Merge3-ReVerify121, an independent level-2 delegate of S3-Merge3 (mission MERGE-3, delegated by Session Commander 10cf255a-c), 2026-10-29. I did not write the change and did not read the Prep's notes files; I read the PR comments.
- **Order:** the commander, 2026-10-28: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise." Learning from past mistakes, I checked the things that went wrong before: locale-dependent order on CI runners, check.yml steps lost in a union, dropped tests, and a merge commit that strays from the planned resolution.
- **GitHub state (read 2026-10-29):** mergeStateStatus CLEAN (UNKNOWN on the first read, CLEAN when read again), state OPEN. Every check SUCCESS: CI run 40787724135 (linux, macos, windows) and CodeQL run 40787720435 (actions, javascript-typescript, python, ruby, CodeQL), both on headSha b86a99d.
- **Scope:** the two commits since the reviewed head 4339c08 (Review121 verdict: MERGEABLE, no blocking findings): `ef6e715` (the ordinal-sort fix plus its test) and `b86a99d` (merge of origin/main ac2c189).

## Blocking findings

None.

## Checks

1. **ef6e715 matches PR 123 byte for byte.** I stripped the `index` and `@@` lines from both diffs and compared the rest. The hunks of `git show ef6e715` and `git show 9c2d025` (PR 123) are IDENTICAL for `scripts/setup-user-claude.sh`, `scripts/setup-user-claude.ps1` and `tests/rules-fanout/test-rules-fanout.sh`. In `git merge-tree b86a99d 9c2d025`, setup-user-claude.sh and .ps1 auto-merge. The two files that do conflict, README.md and the deploy-harness-mdm test, conflict only because PR 123 has not merged main yet. PR 121 already resolved the same conflict, so PR 123's Prep resolves it the same way.
2. **The sort is ordinal in both languages, bash 3.2 included.**
   - What the code sorts:
     - The .sh sorts with `printf '%s' "$LIST" | LC_ALL=C sort`. RULE_SOURCES and the preserved list hold full paths that share one directory prefix, and RULE_BROKEN holds bare names, so in every case the names are what gets ordered.
     - The .ps1 sorts by `.Name` with `[Array]::Sort(..., [Comparison[object]]{ [string]::CompareOrdinal(...) })`.
   - A probe under LC_ALL=en_US.UTF-8, with the names a.md, A.md, b.md, B.md and _x.md:
     - bash 5.3.15 and /bin/bash 3.2.57: `LC_ALL=C sort` gives `A.md B.md _x.md a.md b.md`. The locale sort gives `_x.md a.md A.md b.md B.md`.
     - pwsh, with the exact .ps1 line: CompareOrdinal gives `A.md B.md _x.md a.md b.md`. The old `Sort-Object Name` gives `_x.md a.md A.md b.md B.md`.
   - Parity: the deploy loop and the preserved loop use the same order in sh and ps1. The fd-3 here-string (`done 3<<< "$preserved_list"`) is valid in bash 3.2.
3. **The merge resolutions follow Review121's plan.** I read `git show --remerge-diff b86a99d`.
   - README.md is the only textual conflict. The resolution takes main's "Deploy to a machine" layout and adds the FO-3 run-order sentence word for word.
   - check.yml auto-merged.
   - tests/deploy-harness-mdm auto-merged to the PR's `claude/CLAUDE.md` padding, as the plan says. Compared with ac2c189, only the comment and the padding line change.
4. **Every check.yml step from main is kept.** I parsed both workflow files with Ruby YAML and compared them step by step, origin/main against b86a99d.
   - In every job, every step from main is present and unchanged, and in its original order. The top-level and per-job keys are equal.
   - Added on macos: "Claude rules fan-out tests (bash 5 + pwsh parity)" and "(macOS /bin/bash 3.2)".
   - Added on linux: "Claude rules fan-out tests (bash + pwsh parity)".
   - Windows: no change.
   - Each added step has `if: ${{ !cancelled() }}`.
5. **No test was dropped.**
   - `git diff --diff-filter=D origin/main...b86a99d` lists nothing.
   - The files deleted relative to the first parent are main's PR 129 deletions (aitool-eval and aitool-ops).
   - The number of check, parity and skip lines in the PR-touched suites is equal to or higher than main's.
   - The FO-0 coverage step body, taken from check.yml and run in the worktree, prints "All 19 test suites are in CI or exempt".
6. **No unrelated change.** `git diff --stat origin/main...origin/feature/fanout-claude-rules` lists 8 files: check.yml, README.md, build-deploy.sh, setup-user-claude.sh, setup-user-claude.ps1, and the claude-mdm, deploy-harness-mdm and rules-fanout tests.
   - The net change in setup-user-claude.sh, setup-user-claude.ps1, claude-mdm and rules-fanout has the same patch-id as the change from the merge base to ef6e715.
   - build-deploy.sh lost only lines that are already on main: the PR 120 size gate, `SIZE_OVER` and the chmod result check.
   - Review121 counted 11 files. The other 3 (aitools-lib.sh, aitools-lib.ps1 and the fanout-lib test) reached main with PR 118.

## Non-blocking notes

1. **Sort-failure handling differs between sh and ps1.**
   - In the .sh, a failed `sort` is a `log_warn`, and the rules deploy in directory order.
   - In the .ps1, the sort runs inside the listing `try`, so a throw there would be the `Cannot list` LogError. That throw is practically unreachable.
   - The two failure paths log differently. This is the same kind of finding as earlier audit A N2 (log text, not summary rows).
2. **Non-ASCII names.** C `sort` orders UTF-8 bytes, which is code-point order. `CompareOrdinal` orders UTF-16 code units. The two can disagree only between supplementary-plane characters and U+E000 to U+FFFF. That does not matter for rule names in practice.
3. **The pre-commit step 6 note is stale.** Main 1771636 ("Set the executable bit on the S3-CursorVerify mission scripts") has fixed the 19 mission scripts the Prep comment mentions. Main moved to 1771636 after the head was cut, but it changes only file modes under `.aitools/channel/handoffs`, and GitHub still reports CLEAN.
4. **Earlier non-blocking items stay open.** These are Review121 items 3 and 4: the tracker rows over 30 characters, and the docs drift that FO-7 (PR 126) fixes. Merge PR 126 promptly after this PR.

## What I ran (macOS 27 arm64)

All runs were in a new detached worktree, `/Users/new-jose/repos/aitools/.claude/worktrees/m3-rr121` at b86a99d. Each run had its own isolated HOME and USERPROFILE under `.scratch/session-m3r121/runs/<label>/home`, with `AITOOLS_ENVIRONMENT`, `AITOOLS_USER_REPO_PATH`, `AITOOLS_FORCE` and `CLAUDE_CODE_REMOTE` unset. I pushed nothing.

The dupcase case needs a case-sensitive file system. This machine's `/usr/bin/mktemp -d` ignored `TMPDIR`, so a first round of runs on a case-sensitive APFS sparse image still skipped dupcase. I reran them with a `mktemp` shim that puts the suite's temp root on that volume. Those reruns are the "case-sensitive" rows below.

| Suite | Interpreter | LC_ALL=en_US.UTF-8 | LC_ALL=C |
|---|---|---|---|
| rules-fanout, case-insensitive temp | bash 5 + pwsh | 118 / 0 / 1 (dupcase skipped) | 118 / 0 / 1 |
| rules-fanout, case-insensitive temp | /bin/bash 3.2 --bash-only | 44 / 0 / 23 | 44 / 0 / 23 |
| rules-fanout, case-sensitive | bash 5 + pwsh | **123 / 0 / 0** (ordinal check and `parity ps1: dupcase` pass) | **123 / 0 / 0** |
| rules-fanout, case-sensitive | /bin/bash 3.2 --bash-only | 46 / 0 / 23 (ordinal check passes) | 46 / 0 / 23 |
| rules-fanout, case-sensitive, **control: unfixed 4339c08** (git archive) | bash 5 + pwsh | 120 / **2 failed** (`parity ps1: dupcase` tree and rows) | 122 / 0 / 0 |
| claude-mdm | bash 5 + pwsh | 35 / 0 / 0 | 35 / 0 / 0 |
| claude-mdm | /bin/bash 3.2 | 35 / 0 / 0 | 35 / 0 / 0 |
| deploy-harness-mdm | bash 5 + pwsh | 67 / 0 / 0 | 67 / 0 / 0 |
| build-deploy backup + swap | bash 5; /bin/bash 3.2 | 24 / 0 each | -- |
| b8-consumers | bash 5 + pwsh | 60 / 0 / 0 | -- |
| fanout-lib | bash 5 + pwsh | 374 / 0 / 0 | -- |

The control fails under en_US and passes under C, and the head passes under both. That shows the fix removes the locale dependence and that the new assertion catches it.

Other checks:
- `bash -n` (bash 5 and /bin/bash 3.2) passes on setup-user-claude.sh, build-deploy.sh and the three touched tests.
- The pwsh `ParseFile` of setup-user-claude.ps1 passes. The file keeps CRLF on 714 of 714 lines (`.gitattributes` eol=crlf), and its index mode is 100644.
- The linux CI log for b86a99d has `PASS case-only duplicate: ordinal order, A.md deployed and a.md failed` and `PASS parity ps1: dupcase` (exit code, tree and rows), plus "All 19 test suites are in CI or exempt".

## Not run

- Windows native and Linux native locally (CI covers both).
- check-pre-commit, check-pre-push and check-post-push.
- Anything against the real HOME, and a real MDM endpoint.
- tests/managed-files and adopt-push. This PR does not touch them.
