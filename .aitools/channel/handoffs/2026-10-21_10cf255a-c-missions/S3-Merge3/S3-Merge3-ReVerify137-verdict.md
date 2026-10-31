VERDICT: MERGEABLE

**PR 137, head `5c98ffd70a335bdbec2bcd050ca9ca02b0fed37f`.** S3-Merge3-ReVerify137 (mission MERGE-3), v1.0, 2026-10-29.

This is the first independent review of PR 137. I did not write the change, and I did not read the author's or the Prep's notes. It covers the author commit 193f51c and the three main merges, 38c1edb, f4d7758 and 5c98ffd. Commander, 2026-10-28: "learn from past mistakess". Accordingly, every result below comes from git, gh or test output that I ran myself.

## Blocking findings

None.

## Non-blocking findings (follow-ups; none of them is needed for this merge)

1. **Stale comment.** `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` lines 513-515 still say that the lib reader rejects an `Up.MD` manifest line. After this PR, it accepts that line. The PR already lists this as a follow-up.
2. **Stale lib comment (it predates this PR).** The comment at `scripts/aitools-lib.sh` lines 2653-2654 says setup-user-cursor "still defines its own copies of lower_name, in_list and read_rules_manifest". It no longer does: those functions are defined only in aitools-lib.sh (checked with grep). Line 2722 says the same thing.
3. **The `.bak.` check differs in case between the lib reader and deploy-harness.**
   - The lib reader matches `.bak.` case-sensitively (`/\.bak\./` in the .sh, `-clike` in the .ps1).
   - deploy-harness's manifest plan and `rule_name_kind` match it case-insensitively.
   - The PR lists this as a follow-up. It is harmless today, because deploy-harness never writes such names.
4. **A case-only rename leaves a stale file on Linux (the defect class predates this PR; this PR makes one more case of it reachable).**
   - Scenario: on a case-sensitive file system, a source renames `x.md` to `x.MD`.
   - deploy-harness sees the new name as already claimed (names are compared case-insensitively), so it neither retires nor reports the old `~/.aitools/rules/x.md`.
   - The Cursor fan-out then maps both files to `x.mdc`. It does this in a fixed, ordinal order (`LC_ALL=C sort`, so `x.MD` sorts before `x.md`): the first file is deployed, and the second gets the "Skipped duplicate" ERROR row.
   - A stem-only rename (`Foo.md` to `foo.md`) already behaves this way on main. Before this PR, the .sh dropped `x.MD` entirely, so this particular variant could not happen.
   - This is code-read only; I did not run it. It is a candidate for the `/incident` process, not a blocker.
5. **No Windows CI coverage for the .ps1 change.** The windows CI job does not run `tests/deploy-harness`, so the .ps1 change is exercised only by pwsh on macOS and Linux CI. This gap predates the PR, and the PR's body says so under "Not run".

## Evidence

### Scope

- `git diff origin/main...origin/fix/cursor-fanout-md-case --stat` lists exactly 5 files, with 102 insertions and 11 deletions:
  - `scripts/deploy-harness.sh/.ps1`
  - `scripts/aitools-lib.sh/.ps1`
  - `tests/deploy-harness/test-deploy-harness.sh`
- No unrelated change. The two-dot diff against the current main tip a10073e also shows 3 mission files under `.aitools/channel/handoffs/`. These come from main's newer docs-only commit a10073e, not from the branch.

### The three main merges add nothing but main

For each of 38c1edb, f4d7758 and 5c98ffd, I checked three things:

- **Two parents.** 38c1edb merges 193f51c and 63dff19. f4d7758 merges 38c1edb and ee01b3d. 5c98ffd merges f4d7758 and 81c4e54.
- **`git diff <m>^2 <m> --stat`** is the same 5 files, with 102 insertions and 11 deletions each time.
- **`git show --remerge-diff`** is empty for all three, so no merge had a manual resolution. Each second parent is an ancestor of origin/main.

The changed (+/-) lines in all 5 files are identical between the author commit (193f51c^..193f51c) and the net PR diff at the head.

### Correctness

**The .sh source filter** (`*.[mM][dD]` in a `case` statement) works under bash 3.2, which supports bracket expressions. It now agrees with the .ps1's `-notlike '*.md'`, which is case-insensitive.

**The manifest name checks** are byte-identical in meaning across the 4 sites:
- `harness_manifest_plan`
- `Get-HarnessManifestPlan`, through `-cnotmatch`
- `read_harness_manifest`
- `Read-HarnessManifest`, through `-cnotmatch`

**Other places that filter `*.md` already ignore case, so they agree with the manifest:**
- `rule_name_kind` / `Get-RuleNameKind` (lower-cased name, or `-like`)
- setup-user-claude and setup-user-cursor, through `rule_name_kind`
- the .mdc stem in setup-user-cursor: `${rule_base%.[mM][dD]}` in the .sh, and `Substring(0, Length-3)` in the .ps1, both on names already classed as rules
- the prune lookup, which compares case-insensitively
- backup_dir's `/\.md\z/i`
- build-deploy, which embeds every `git ls-files` entry with no filter of its own and extracts the deploy-harness code from it

**Case collisions** (`dup.md` in shared and `DUP.MD` in the dotprofile): the first source wins, and there is exactly one ERROR row and exit 1. This is tested on both paths and runs on Linux CI, a case-sensitive file system. Inside the Cursor fan-out the order is ordinal and deterministic.

**Error-handling standards:** the changed lines add no error suppression and no new code paths. The new test code uses no `|| true` and no `2>/dev/null` without a check.

**CRLF:** the `.ps1` blobs are LF, and `.gitattributes` sets `*.ps1 text eol=crlf`. All 827 lines of the checked-out deploy-harness.ps1 end in CRLF, so line endings are consistent.

### Negative control (the new tests fail without the fix)

I took the head's tree (`git archive 5c98ffd`) and replaced the 4 scripts with the merge-base versions (81c4e54). On that tree, `tests/deploy-harness` gives **138 passed, 9 failed**. The 9 failures are exactly the new cases:

- sh upper: deploy/list
- sh upper: listed
- sh upper: dup
- sh upper: retire
- ps1 upper: rerun
- ps1 upper: `.bak.` lines
- ps1 upper: retire
- reader sh
- reader ps1

The ps1 first-run deploy passes even before the fix, which matches the PR's description: the .ps1 deployed the rule, then rejected its manifest line on the next run.

### Suites at the head

I ran these in the new detached worktree `.claude/worktrees/m3-rr137`, with an isolated HOME and TMPDIR under its scratch directory, using the commands from check.yml.

| Suite | bash 5.3.15 + pwsh 7.6.3 | /bin/bash 3.2.57 (`bash` on PATH is 3.2; `--bash-only` where CI uses it) |
|---|---|---|
| deploy-harness | 147 passed, 0 failed, 0 skipped | 147 / 0 / 0 |
| deploy-harness-mdm | 67 / 0 / 0 | 67 / 0 / 0 |
| rules-fanout-cursor | 215 / 0 / 1 | 140 / 0 / 22 |
| rules-fanout | 118 / 0 / 1 | 44 / 0 / 23 |

### Syntax checks

- `bash -n` passes under bash 5 and 3.2 on deploy-harness.sh, aitools-lib.sh and test-deploy-harness.sh.
- The pwsh `Parser::ParseFile` reports no errors in deploy-harness.ps1 or aitools-lib.ps1.

### FO-0 step

The body of the "Every test suite is in CI" step, run at the head, prints "All 21 test suites are in CI or exempt" (rc 0).

### CI on 5c98ffd

- CI run 40832227219 (linux, macos and windows) and CodeQL run 40832222451: every check SUCCESS.
- The job logs show the new `sh upper`, `ps1 upper`, `reader sh` and `reader ps1` cases PASS on both linux and macos, and deploy-harness at 147 passed, 0 failed on macos.
- `gh pr view 137 --json mergeStateStatus` returns CLEAN with base main. I read it twice, before and after the suites ran.

## Not run

- Native Windows.
- setup-user-claude end to end with an `X.MD` rule (code-read only).
- Whether Claude Code or Cursor actually loads a `.MD` rule. This is still unknown (reference/rules.md R10).
- check-pre-commit and check-pre-push.
- The finding 4 scenario (code-read only).
