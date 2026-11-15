# 38dc-26 report: PR #159 refreshed against main 5f962b1 (v1.0)

**Intent**: **Purpose**: hand M6-Polish and the commander what mission
38dc-26-pr159-refresh-merge corrected in PR #159 after main moved (#160, #154,
#158, #162, #164, d21994b), the source behind each correction, and how the
counts were derived. **Scope**: the four places PR #159 touches
(`reference/cross-platform-detail.md` "Running tests on Windows", the
`CLAUDE.md` tests line, the `/delegate` "Checks" lines, RELEASE_NOTES v0.77.6).
NOT check.yml, tests or the exemptions table (missions 38dc-13 and 38dc-23).
NOT the merge result (in the hand-back: it comes after this file is committed).
**Audience**: M6-Polish, the independent reviewer, the commander.

Version 1.0, 2026-11-14. PR: https://github.com/nobul-tech/aitools/pull/159
(branch `docs/38dc-12-windows-test-practice`), on top of M6-Polish's merge
commit 0a5a0ae (origin/main 5f962b1 into the branch).

## Stale facts and their corrections

1. **`scripts/aitools` on Windows.** Old: the twins row said the bash entry
   point "sources it and uses, for example, `read_menu_choice` and
   `read_tty_choice` in `aitools user init`". New: until PR #162 it did; since
   #162 `scripts/aitools` forwards every command to `aitools.ps1` before it
   sources the library, so `aitools` runs no library code on Windows, and the
   `scripts/aitools` cases of `tests/logging/test-logging.sh` run on macOS and
   Linux only. The library still loads in Git Bash on Windows from
   `aitools-install.sh` (before its forward to `aitools-install.ps1`),
   `build-package.sh`, and a `build-deploy.sh` child that runs
   `resolve_user_repo_path`. Sources: `scripts/aitools` "Windows (Git Bash):
   hand off to aitools.ps1 before anything else runs" block and the
   `case "$(uname -s)"` call of `aitools_win_forward` inside `main()`;
   `tests/logging/test-logging.sh` header ("the scripts/aitools run cases are
   macOS/Linux only"); `scripts/aitools-install.sh` (sources the library, then
   the Windows forward, `exit $?`); `scripts/build-package.sh` ("No OS guard");
   `scripts/build-deploy.sh` (`source "$1/aitools-lib.sh"` in the resolver
   child). A `git grep` for `read_menu_choice|read_tty_choice|deploy_managed_file|prompt_diff_review|fanout_harness_skills|review_json_fields`
   over tracked `*.sh` found no unguarded script that reaches them on Windows
   (`scripts/aitools` and `aitools-install.sh` forward first; the setup scripts
   carry the POSIX guard; `build-deploy.sh` only emits them as text).
2. **`tests/hookin/test-hookin.sh`.** Old: covers "the Windows branch of
   `scripts/aitools`". New: it runs the Windows branch of `deploy_configs`, cut
   out of `scripts/aitools`, a branch that since #162 is not reached when
   `scripts/aitools` runs on Windows. Sources: `tests/hookin/test-hookin.sh`
   header ("loop -- deploy_configs (extracted from scripts/aitools)");
   `scripts/aitools` forward comment ("The Windows branches further down are
   not reached on Windows").
3. **Where the marks are recorded.** Old: "not settled (open question to the
   commander, 2026-11-14)". New: the `.claude/rules/cross-platform.md` "OS
   guard exemptions" table. RFI 38dc-7 (M6-Polish, 2026-11-14T21:58:27Z) put
   it to the commander as "the record of what is explicitly cross-platform";
   he answered row by row at 2026-11-14T22:04:21Z (M6-Polish transcript
   `subagents/agent-a0c459c8f689338dc.jsonl` line 2483, a message typed while
   it worked), verbatim: "7) build-package.sh is approved, relay-outbound.sh/.ps1
   need os guards they are not exempt, the aitools dependency needs to be
   resolved (how to resolve it and resolving it need to be part of same
   mission), the aitools-json and validate should be recorded as exempt for
   those reasons, for the check-*.ps1 can youj explain this further? id like to
   avoid calling git bash on thowse ps1 scripts.  delegate this as a mission."
   The section quotes up to "for those reasons," and elides the rest. The
   paragraph on the table now matches main 5f962b1: no Perl or Python rows;
   `build-package.sh` "(P-1, pending approval)"; entry-point and helper-module
   rows "rationale unrecorded, pending approval" (`git grep` on
   `origin/main:.claude/rules/cross-platform.md`). Mission 38dc-13's branch
   `fix/38dc-13-windows-ci-ps1-only` (no PR yet) has the answer for
   `build-package.sh` and the helper modules and a "Perl and Python scripts
   (2026-11-14, commander)" row (`git grep` on that branch); 38dc-23 owns the
   relay-outbound guards. RFI 38dc-12-2 is answered by RFI 38dc-7.
4. **`build-package.sh` suites locally.** New: `tests/build-package/` joins
   the hooks and `build-deploy.sh` suites that may run in Git Bash on a Windows
   machine, citing "build-package.sh is approved" (RFI 38dc-7).
5. **`.ps1` suites.** Old: eight (2026-11-14, 2ee68d9). New: ten on main
   5f962b1; added `tests/aitools-entry/test-win-forwarder.ps1` (step added by
   #162, f345c41) and `tests/bootstrap/test-bootstrap.ps1` (#160, 91dba98).
   Source: `git ls-files "tests/*.ps1"` filtered to `test-*.ps1`;
   `git log --first-parent -S` on check.yml.
6. **Checks.** New: the compliance check `scripts/check-script-compliance.ps1`,
   the Windows job's last step (#160, 91dba98), named beside the other `.ps1`
   checks. It is a check, not a suite, and is not counted.
7. **Windows CI counts.** Old: 42 suite steps (8 `.ps1`, 2 Python, 32 `.sh`).
   New: 46 (10, 2, 34). The drivers group grows from 18 to 20:
   `tests/check-pre-commit/test-pre-commit-steps3-10.sh` and
   `tests/check-post-push/test-post-push-deploy-steps.sh` (both #154,
   5f962b1). Both also cut steps out of a POSIX-guarded `.sh` check and run
   them in bash, so they join the "cut skips the guard" sentence (their
   headers: "Cases, for each twin (.sh in bash; ...)"; the `.sh` section runs
   at `"$TB" "$TMP_ROOT/run.sh"` with no Windows gate).
8. **Bash AI merge.** Old: "on Windows `scripts/aitools` dispatches the `.ps1`
   deploy scripts". New: "forwards to `aitools.ps1` (PR #162), which runs the
   `.ps1` deploy scripts". The three CI suites that reach `_invoke_ai_merge` on
   Windows are unchanged (check.yml windows job).
9. **RELEASE_NOTES v0.77.6.** Item 1: "where the marks are recorded is an
   open question" -> the exemptions table, answered in RFI 38dc-7, not yet on
   main's table; "eight `.ps1` suites" -> ten; "42 suite steps: 8, 2, 32" ->
   "46 ... on main at 5f962b1: 10, 2, 34"; the #162 forward named. The entry
   stays between v0.77.7 and v0.77.5.
10. **Unchanged, checked.** `CLAUDE.md` tests line: still true (the `.ps1`
    suites with `pwsh -NoProfile -File`; `.sh` suites in Git Bash only for
    explicitly cross-platform scripts). `/delegate` "Checks" (v2.3 line): the
    three `check-*.sh` still carry the POSIX guard ("This script is for
    macOS/Linux"), so "the `.sh` checks refuse Windows" holds.

## Counts: how derived

`.scratch/session-38dc-26/win-suites.pl` (worktree scratch, not tracked)
parses the windows job of `.github/workflows/check.yml` step by step: each
step's `shell:` and every `tests/**/test-*.{ps1,sh,py}` in its `run:` block.
Result on 5f962b1: 58 steps; 46 run a suite, one suite each, so steps = unique
suites = 46 (`ps1 via pwsh=10, py via pwsh=2, sh via bash=34`); 12 run none
(setup, syntax, the inline profile-resolver step, build-deploy, drift, the
compliance check). M6-Polish's `count-win-steps.pl` (unique suites) gives the
same 10/2/34. The three groups were assigned by hand from each suite's step
name and header and sum to 4 + 20 + 10 = 34.

## Checks, review, merge

In the hand-back (they run after this file is committed).

## Conflicts

- CONFLICT: the session's auto-mode note (Bash allowed for file reads and
  edits) vs USO "Dedicated tools for file ops" -- resolved by tier 1:
  Read/Edit/Write/Grep for files; Bash for git, gh, perl and python only.
- CONFLICT: the brief ("NOT the exemptions table") vs RFI 38dc-12-2's
  suggestion that the section name the table as the record -- not a conflict
  in practice: the section names the table and states what main shows; the
  table itself is not edited.

WRITE_BLOCKED: none so far. INCIDENT: none.

## Open questions

None new from the text. Observation: `tests/hookin/test-hookin.sh` still
tests a `deploy_configs` Windows branch that #162 made unreachable at run time;
M6-Polish's open RFI 38dc-12 (remove the dead Windows branches in the bash
`aitools`) covers it.
