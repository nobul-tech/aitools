VERDICT: MERGEABLE

# S3-Merge3-ReVerify124 verdict v1.0 -- PR 124 (FO-4, Claude skills fan-out)

- **Head SHA reviewed:** `a34df8d05eca97db7a8c06d1ce22e7ee9c0ee3f5`
- **Previously reviewed head:** `282c28b` (S3-Merge2-Review124: MERGEABLE with conditions)
- **Base:** main. origin/main is `bf1daf2`; it is `3e00085` (the merged-in main) plus handoff `.md` files only.
- **mergeStateStatus:** CLEAN (read twice). Every check is SUCCESS on `a34df8d`: CI run 40800394370 (macos, linux, windows) and CodeQL run 40800389667.
- **Blocking findings:** 0. **Non-blocking:** 0 new.

I am S3-Merge3-ReVerify124, an independent re-reviewer delegated by S3-Merge3 (mission MERGE-3). I did not write this change, and I did not read the Prep notes. Commander, 2026-10-28: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise." Learning from past mistakes, I checked the things that went wrong before: a UTF-8 check that failed silently on large files, CI steps that were dropped in check.yml unions, sort order that depended on the locale, and close keywords in messages.

## Scope

I reviewed the two first-parent commits since `282c28b`:

- `45c5afd`: the NB1 fix plus the `utf8large` test.
- `a34df8d`: the merge of origin/main `3e00085` (PRs 136, 117, 118, 119, 121).

## Findings

### 1. The NB1 fix is correct and tested

`_fanout_is_binary` in `scripts/aitools-lib.sh` now walks the file with `pos($c)=0; 1 while $c =~ /\G(...)/gc;`. It calls the file text only when `pos == length`. Every match consumes one sequence or one ASCII run, so no match repeats a complex group. Each `/gc` failure keeps `pos` where it was. The alternation is the same RFC 3629 set as before.

I ran a probe over 34 files. It ran the perl program extracted verbatim from the lib, and `Test-FanoutBinary` extracted verbatim from `aitools-lib.ps1`.

- **sh and ps agree on all 34 files.**
- Binary in both:
  - surrogate ED A0 80, and CESU surrogate pairs
  - above max: F4 90, and F5
  - FE, FF, and the 5-byte F8 lead
  - overlong C0, C1, E0 80 and F0 80
  - truncated in the middle, at the end, and a truncated 4-byte sequence
  - a lone continuation byte, and NUL
  - a 120 KB file ending in FF
  - FF followed by 5 MB, and a bad byte in the middle of 5 MB
- Text in both:
  - an empty file and plain ASCII
  - valid mixed 2-, 3- and 4-byte text
  - the noncharacter U+FFFE, and a BOM
  - U+10FFFF, U+D7FF and U+E000
  - CRLF text
  - 200 KB of e-acute and the 120 KB mixed file
  - 5 MB of e-acute, 10 MB of 4-byte characters, 20 MB of ASCII, and 5 MB mixed
- **Speed:** at most 0.22 s per file (10 MB). The probe shows no catastrophic backtracking. `perl -w` prints no warning on any file.
- **The old code (282c28b) on the same files:**
  - It calls the 200 KB, 120 KB, 5 MB, 10 MB and 5 MB-mixed valid files binary.
  - `perl -w` prints "Complex regular subexpression recursion limit (65534) exceeded" for each of them.
  - The new `utf8large` test (100,000 x e-acute) therefore fails on the old code and passes on the new one.
- **Linux CI ran the new test cases**, run 40800394370, linux job: `PASS utf8 large sh/ps` (eacute, mixed, badtail) and `PASS parity ps1: utf8large` (exit code, tree, summary rows).

### 2. The README sentence matches the code

The new sentence reads: "The skills fan-out in `setup-user-claude` reads `~/.aitools/skills`: run before `deploy-harness`, it deploys no skills and leaves them to `setup-user-skills`."

- When `~/.aitools/skills` is missing, `fanout_harness_skills` (aitools-lib.sh) and `Invoke-HarnessSkillsFanout` (aitools-lib.ps1) log an info line, write no row, and return.
- The only callers are `setup-user-claude.sh` and `setup-user-claude.ps1`.
- tests/claude-mdm checks "no claude skills row" in this case.
- An empty, existing directory writes `OK n/a (no harness skills)`. The sentence is about the missing directory, so it is correct.

### 3. Skills fan-out ordering is ordinal and does not depend on the locale

- The .sh side is `_fanout_list_dir`: perl `sort` with no `use locale`, so it sorts by byte.
- The .ps1 side is `Get-FanoutSortedNames`: `[Array]::Sort($names, [StringComparer]::Ordinal)`.
- Probe: 18 names, including `_x`, `~t`, `10`/`9`, mixed case, `a-b`/`a.b`, and NFC and NFD e-acute. Both functions ran under `LC_ALL=en_US.UTF-8` and under `LC_ALL=C`. All four lists equal the `LC_ALL=C sort` reference. `en_US` `sort` gives a different order, which shows the probe can tell the two apart.
- The skills code has no shell `sort`. The rules code from 9c2d025 is main's and came in through the merge unchanged.

### 4. The merge followed the plan

I read `git show --remerge-diff a34df8d`:

- **The only conflict** was `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`. The merge took PR 121's comment and kept `mkdir -p "$DOT_BIG/claude"`. That is the NB4 resolution exactly.
- **README:** main's text plus the one sentence in finding 2.
- **Everything else** merged without conflicts.

### 5. check.yml keeps every main step

I parsed both files as YAML with Ruby Psych and compared each step as a whole hash:

- All 44 macos, 30 linux and 16 windows steps from main are present, unchanged and in order. Top-level and job-level keys are identical.
- The branch adds only three steps, each with `if: ${{ !cancelled() }}`:
  - macos: skills-fanout with bash 5 + pwsh;
  - macos: skills-fanout with /bin/bash 3.2 `--bash-only`;
  - linux: skills-fanout.
- The FO-0 "Every test suite is in CI" step body is unchanged. It passed in CI: "All 20 test suites are in CI or exempt".

### 6. No test was dropped, and there are no unrelated changes

`git diff origin/main...origin/feature/fanout-claude-skills --stat` lists 10 files, all of them this PR's: check.yml, README.md, aitools-lib.sh/.ps1, build-deploy.sh, setup-user-claude.sh/.ps1, tests/claude-mdm, tests/deploy-harness-mdm (+1 line), and tests/skills-fanout (new).

- The only removed lines in the test files are the `--help` line range in tests/claude-mdm (26 -> 27).
- No commit message since 282c28b and no line of the PR body contains a close keyword followed by `#N` or a URL.

## Suites (macOS, detached worktree m3-rr124 at a34df8d, isolated HOME per suite)

Versions: bash 5.3.15, /bin/bash 3.2, pwsh 7.6.3.

| Suite | LC_ALL=en_US.UTF-8 | LC_ALL=C |
|---|---|---|
| skills-fanout (bash 5 + pwsh) | 194 passed, 0 failed, 1 skipped | 194 passed, 0 failed, 1 skipped |
| skills-fanout (/bin/bash 3.2 --bash-only) | 76 passed, 0 failed, 33 skipped | 76 passed, 0 failed, 33 skipped |
| fanout-lib (bash 5 + pwsh) | 374 passed, 0 failed | 374 passed, 0 failed |
| fanout-lib (/bin/bash 3.2 --bash-only) | 134 passed, 0 failed, 1 skipped | 134 passed, 0 failed, 1 skipped |

These suites ran in the default locale:

| Suite | Result |
|---|---|
| claude-mdm (bash 5) | 38 passed, 0 failed |
| claude-mdm (/bin/bash 3.2) | 38 passed, 0 failed |
| deploy-harness-mdm | 67 passed, 0 failed |

The skipped skills-fanout case is the case-only duplicate, which cannot run on APFS. Linux CI runs it: 198 passed, 0 skipped.

Syntax checks: `bash -n` under bash 5 and /bin/bash 3.2 passes on aitools-lib.sh, setup-user-claude.sh, build-deploy.sh and the three touched tests. The pwsh parser passes on aitools-lib.ps1 and setup-user-claude.ps1.

The C-locale fanout-lib, claude-mdm and deploy-harness-mdm runs happened twice, at the same time. I read the first runner's progress output too early, took it as stopped, and started a second runner. Both runners passed every suite. The logs on disk come from the second runner.

## Not run

- Native Windows. The windows CI job is green, but it does not run the skills suite.
- Linux locally. Linux rests on CI run 40800394370.
- check-pre-commit and check-pre-push. Those are Prep duties, and this review changes no file.
- A static re-read of the whole fan-out function. Earlier reviews and audits covered it; I reviewed the delta since 282c28b.

## Scratch

`/Users/new-jose/repos/aitools/.claude/worktrees/m3-rr124/.scratch/session-m3r124/` holds:

- probe scripts: `probe-gen.pl`, `probe-sh.sh`, `probe-ps.ps1`, `order-probe.sh`;
- comparison and syntax scripts: `yml-compare.rb`, `syntax.sh`, `parse.ps1`;
- suite runners: `suites.sh`, `suites2.sh`;
- the suite logs in `suites/`.
