# 38dc-12 report: how tests run on Windows (v1.0)

**Intent**: **Purpose**: hand M6-Polish and the commander what mission
38dc-12-windows-test-practice-doc changed, the evidence behind each fact it
recorded, and what is still open. **Scope**: the facts of the brief (verified,
refined or falsified), files changed, checks, conflicts, open questions,
operational learning. NOT the section's text itself (it is in
`reference/cross-platform-detail.md` "Running tests on Windows"). **Audience**:
M6-Polish, the independent reviewer, the commander.

Version 1.0, 2026-11-14. PR: https://github.com/nobul-tech/aitools/pull/159
(branch `docs/38dc-12-windows-test-practice`). Merge SHA and main CI run: in the
hand-back (they come after this file is committed).

## Summary

1. New section `reference/cross-platform-detail.md` "Running tests on Windows":
   the commander's rule, quoted from both of his 2026-11-14 messages; the eight
   `.ps1` suites and `pwsh -NoProfile -File`; eight known Git Bash issues with
   sources; the Windows CI job today; the bash AI merge has no Windows path.
2. Pointers where a file would otherwise lead an agent elsewhere: the `CLAUDE.md`
   tests line and the `/delegate` skill "Checks" item (v2.2).
3. RELEASE_NOTES v0.77.6. Documentation only: no script, test or CI change.
4. The CI layout is decided (commander, 2026-11-14T18:58:47Z) and owned by
   follow-up mission 38dc-13; one RFI remains (local Git Bash runs for
   explicitly cross-platform scripts).

## Facts of the brief

1. **Verified.** `tests/menus/test-menu-choice.sh` has no OS guard; lines
   53-60 set `IS_WINDOWS=true` on `MINGW*|MSYS*|CYGWIN*` and use pywinpty for
   the pty. Its header: "Platform: macOS, Linux, Windows Git Bash
   (aitools-lib.sh also runs there)". `check.yml` windows job runs it ("Menu-choice
   wrapper tests (bash, via Git Bash, ConPTY)", `shell: bash`) and the `.ps1`
   twin ("(PowerShell, native)").
2. **Answered: no Windows runtime path reaches the bash AI merge.**
   `_invoke_ai_merge` is called only from `prompt_diff_review` (`[m]`), which is
   called only from `deploy_managed_file` (`scripts/aitools-lib.sh`; also via
   `fanout_harness_skills`). `git grep` over `scripts shared packaging` for
   `deploy_managed_file|prompt_diff_review|adopt_managed_file|fanout_harness_skills`:
   callers are `setup-user-claude.sh`, `setup-user-cursor.sh`,
   `setup-user-hooks.sh`, `setup-user-skills.sh`, `deploy-harness.sh` (each has
   the POSIX guard: "This script is for macOS/Linux"); `build-deploy.sh` only
   emits text for generated `deploy/*.sh` (which keep the guard: 24 files in the
   dotprofile `deploy/`, `deploy-harness.sh` included); `check-post-push.*`,
   `check-lib.sh`, `aitools-lib.ps1` mention it in comments or parse it.
   `scripts/aitools` on Windows (Git Bash) sources `aitools-lib.sh` but
   dispatches the `.ps1` deploy scripts (`deploy_configs`, line 1112). Why the
   `.sh` suite has no guard: `aitools-lib.sh` is an exempt shared library that
   does run in Git Bash on Windows; `scripts/aitools` uses its
   `read_menu_choice` / `read_tty_choice` in `aitools user init` (`ui_choose`,
   line 397, and others). So the menu cases test real Windows code; the AI-merge
   cases do not.
3. **Verified and counted.** Windows job (`.scratch/session-38dc-12/win-steps.pl`
   over `check.yml` at 2ee68d9): 42 suite steps: 32 `.sh` with `shell: bash`, 8
   `.ps1` with `pwsh`, 2 Python. The 32: 4 `.sh` twins of `.ps1` suites
   (logging, managed-files, adopt-push, menu-choice); 18 `.sh` drivers of `.ps1`
   code (b8-consumers, claude-mdm, hookin, 5 profile suites, fanout-lib,
   rules-fanout, rules-fanout-cursor, skills-fanout, skills-legacy,
   deploy-harness, deploy-harness-mdm, pre-push step 7, post-push step 7, menu
   parity); 10 for bash code whose Windows runtime is Git Bash (6 hook suites,
   build-deploy backup, build-package CLI, pywinpty `.sh`, os-guards). CLAUDE.md's
   "Windows runs the `.ps1` halves on native pwsh" holds for the code under test
   of the 18, not for their drivers.
4. **Collected, with corrections.**
   - `find` hang: verified in the M6-Polish transcript
     (`subagents/agent-a0c459c8f689338dc.jsonl` lines 711-724: "my new `.cmd`
     stub calls `find`, which under Git Bash's PATH resolves to Unix `find` and
     walks C:"; `Git's usr\bin\find.exe has been running since 10:30:10`). It was
     the `.ps1` suite, started from a Git Bash script (`verify-n1.sh` in the
     m6-eof scratch), so pwsh inherited Git Bash's PATH. The fix is on PR #155
     (`tests/menus/test-menu-choice.ps1` line 230). Probe: pwsh from Git Bash
     lists `C:\Program Files\Git\usr\bin\find.exe | C:\WINDOWS\system32\find.exe`;
     the PowerShell tool lists only System32.
   - `chmod 000`: **partly falsified.** On a file, Git Bash does enforce it
     (append refused: probe; M5-L1 report line 220). On a directory, `cd` and
     file creation both succeed (probe; M6-F report line 97).
   - `grep` and CR: **refined.** Probe: `grep -c $'\r'` counted 2 lines on a file
     whose only CR ends line 1 (it matched the LF-only line too); M6-B (report
     line 89) saw it never fire. Either way unusable; perl works.
   - MSYS: **refined.** Probe: `/c/Users/x` -> `C:/Users/x`, `--opt=/tmp/x` ->
     `--opt=C:/Users/jdpal/AppData/Local/Temp/x`; `origin/main:reference/x.md`
     was **not** rewritten, and `git show origin/main:reference/cross-platform-detail.md`
     worked from Git Bash without `MSYS_NO_PATHCONV`. With `MSYS_NO_PATHCONV=1`,
     `/c/Users/x` arrives unconverted (probe), and `git.exe` then fails (38dc-09
     report line 140). The section records only what was reproduced.
   - GNU vs BSD: `.claude/rules/cross-platform.md` "Hook portability".
   - Slow pty: `verify-n1.txt` (m6-eof scratch): `.sh` 62 s branch, 171-173 s
     mutant; `.ps1` 31 s.
   - `uname` spoof: M6-F report lines 83, 97, 193.
   - `bash` in native pwsh = WSL launcher: PowerShell tool probe
     (`C:\Users\jdpal\AppData\Local\Microsoft\WindowsApps\bash.exe`); RELEASE_NOTES
     v0.77.2 item 1.
5. **Recorded** as the rule, quoted from both messages (verified verbatim in the
   transcripts: 18:49:44Z, type `user`; 18:58:47Z, `queued_command`, origin
   `human`).

Probe script and output: `.scratch/session-38dc-12/probe-gitbash.sh`, `.log`
(worktree scratch, not tracked).

## Files changed

- `reference/cross-platform-detail.md` (new section at the end)
- `CLAUDE.md` (tests line, one sentence)
- `shared/skills/delegate/SKILL.md` (v2.2, "Checks")
- `RELEASE_NOTES.md` (v0.77.6)
- this report

Considered and left unchanged: `.claude/rules/cross-platform.md` (no test-run
guidance to contradict; its exemptions table is 38dc-13's),
`.claude/rules/smoke-test-pattern.md` and `reference/smoke-test-pattern-detail.md`
(already `pwsh -File` for `.ps1` on Windows, "Never run `.sh` setup scripts on
Windows").

## Checks

- `check-pre-commit.ps1` (no -Fix, `AITOOLS_LOG_DIR` in scratch): 8 PASS, 9 SKIP,
  2 WARN (3 build freshness: `shared/` modified, -Fix not run; 11 dotprofile
  changes, not mine), 0 FAIL.
- `check-pre-push.ps1`: 7 PASS, 1 SKIP, 2 WARN (1, 6), 0 FAIL; step 7 fresh build OK.

## Conflicts

- CONFLICT: the brief (raise the CI layout as an open question) vs the
  commander's answer of 2026-11-14T18:58:47Z, relayed by M6-Polish and verified
  verbatim in its transcript -- resolved by tier 1: documented as decided, no CI
  RFI, CI and tests left to 38dc-13.
- CONFLICT: CLAUDE.md "Channel exception" (CLAUDE.md is committed directly to
  main) vs the brief's access (main checkout read-only; ship by PR) -- resolved by
  tier 2, reading the exception as a permission, not a prohibition: the CLAUDE.md
  sentence travels in PR #159, as 5b84b8c and 295ea11 did through PRs.
- CONFLICT: the session's auto-mode note (Bash allowed for file edits) vs USO
  "Dedicated tools for file ops" -- resolved by tier 1: Read/Edit/Write/Grep for
  every file operation.

WRITE_BLOCKED: none. INCIDENT: none.

## Open questions

RFI 38dc-12-1: May an agent on Windows run, locally in Git Bash, the tests of a
`.sh` script explicitly marked cross-platform?
The rule says `.sh` tests run only on Linux/macOS "unless a script is explicitly
marked as cross-platform for good reasons". Hooks, `build-deploy.sh`,
`build-package.sh` and the bash entry points are in the exemptions table because
their Windows runtime is Git Bash; their suites have no `.ps1` form. The section
as written leaves every suite without a `.ps1` form to the Windows CI job.
Suggest: yes, for those scripts only (Git Bash is the runtime under test there,
so the run is real evidence); everything else stays `.ps1`-only. If yes, one
sentence is added to the section's rule list.

## Observations

- PRs #155 and #158 both add `## v0.77.4` to RELEASE_NOTES; #158 also adds a
  `/delegate` v2.2 line, as this PR does. Whichever merges second renumbers.

## New operational learning

- A pwsh started from the Claude Code Bash tool inherits Git Bash's PATH (Git
  `usr/bin` first): a bare `find`, `sort` or `perl` in a test stub is the Unix
  one. The PowerShell tool's pwsh has the Windows PATH.
- Git for Windows `grep -c $'\r'` over-matches (it counted an LF-only line);
  test CR with perl.
- MSYS rewrites `/c/...` and `--opt=/tmp/...` arguments to native programs, not
  `origin/main:<relative path>`.
- A relayed "commander's answer" can be verified in the delegating agent's
  transcript: `queued_command` attachments with `origin.kind == "human"` are his
  words (`.scratch/session-38dc-12/extract-quote.py`).
