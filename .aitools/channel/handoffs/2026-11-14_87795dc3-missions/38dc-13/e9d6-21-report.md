# e9d6-21-port-check-steps report (v1.0)

**Intent**: **Purpose**: Record the platform split of three check-script test suites: each `.sh`
harness now tests only the `.sh` check twin plus the platform-neutral cases, and refuses Windows;
a new `.ps1` harness per suite tests the `.ps1` twin plus the same neutral cases natively on
Windows. **Scope**: `tests/check-pre-push/test-pre-push-step7.*`,
`tests/check-post-push/test-post-push-step7.*`, `tests/check-post-push/test-menu-parity.*`.
NOT the check scripts under `scripts/`, NOT check.yml, NOT e9d6-22's suites. **Audience**:
38dc-13 (ended) / 38dc-27-windows-ci-finish, who verifies, commits and ships, and the verifiers
08de-01 and 08de-02.

Author: e9d6-21-port-check-steps, delegated by 38dc-13 (a615ff0218609e9d6); finished under
38dc-27 (a0d866a721d3108de). Date: 2026-11-14. Worktree W =
`C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13` (branch head 15ce209 at the end).
Nothing was committed or pushed (prompt, and 38dc-27's message).

## Summary

- 3 `.sh` harnesses edited: POSIX test-suite guard (the `cross-platform.md` "Test suites" block,
  with the `BASH_VERSINFO[5]` case) first after `set`; every pwsh / Windows / `cygpath` branch and
  every case that ran `.ps1` code removed; header updated (platform, what moved where, the
  commander's words); `AITOOLS_TEST_BASH` picks the inner bash (38dc-27 review item 2).
- 3 `.ps1` harnesses created: Windows guard first after `param`/`-Help`; they run the `.ps1`
  twin and the neutral cases natively; none runs bash or a `.sh` check section.
- Windows runs: pre-push step 7 3/0/0, post-push step 7 7/0/0, menu parity 22/0/0; each equals
  the expected set (Windows CI lines of run 43655061089 minus the `(s)` lines), in order.
- Mutation proof: 11 mutations (4 + 4 + 3), all killed (exit 1, named FAIL); every harness
  restored byte-identical (SHA256 checked).
- `bash -n` clean, refusal runs exit 1 with the guard message and nothing written, the guard
  classifier gives `posix` for the three `.sh` and `win` for the three `.ps1`, pwsh parser 0
  errors.

## Classification of every CI line

Key: (s) runs the `.sh` check twin (whole or a section); (p) runs the `.ps1` twin; (n) neutral:
perl (`scripts/check-menu-parity.pl`, perl one-liners) or a static read of a file's text (nothing
is run). Source: `.scratch/session-38dc-13/ci-windows-154.log` and `ci-linux-154.log`, extracted
with `ci-section.py` into `.scratch/session-e9d6-21/ci-{windows,linux}-<suite>.txt`.

Judgment applied (record, so the verifiers can check it): the "section was found" and "step 29
calls scripts/check-menu-parity.pl" lines are static reads of a twin's text, so they are (n) by
the prompt's definition and appear in both harnesses. The alternative (count them with the run
they precede) would drop two lines from each harness; it was not chosen.

### tests/check-pre-push/test-pre-push-step7 (CI Windows 3/0/0, Linux 3/0/0)

Each case runs the whole check script: on Linux `check-pre-push.sh` (s), on Windows
`check-pre-push.ps1` through pwsh (p) (old `.sh` `:89-95`). So the same three names are (s) in
the `.sh` harness and (p) in the `.ps1` harness.

| # | Line | Linux | Windows |
|---|------|-------|---------|
| 1 | untracked deploy/: step 7 PASS, comparison skipped | s | p |
| 2 | untracked deploy/: the fixture dotprofile is left clean (deploy/ built there is ignored) | s | p |
| 3 | committed deploy/ that differs from a fresh build: step 7 FAIL, stale | s | p |

### tests/check-post-push/test-post-push-step7 (CI Windows 10/0/0, Linux 10/0/0; same lines)

| # | Line | Class |
|---|------|-------|
| 1 | sh: the step 7 section was found | n |
| 2 | sh run: exit 0 | s |
| 3 | sh run: build-deploy.sh was not run | s |
| 4 | sh run: one result, SKIP 7, pointing to check-pre-push step 7 | s |
| 5 | sh static: no line runs build-deploy | n |
| 6 | ps1: the step 7 section was found | n |
| 7 | ps1 run: exit 0 | p |
| 8 | ps1 run: build-deploy.sh was not run | p |
| 9 | ps1 run: one result, SKIP 7, pointing to check-pre-push step 7 | p |
| 10 | ps1 static: no line runs build-deploy | n |

### tests/check-post-push/test-menu-parity (CI Windows 24/0/0, Linux 24/0/0; same lines)

| # | Line | Class |
|---|------|-------|
| 1-5 | lib: ... (5 lines) | n (perl) |
| 6-11 | planted: ... (6 lines) | n (perl) |
| 12-14 | fixture: ... (3 lines) | n (perl) |
| 15-18 | nothing found / one argument / unreadable file / --help | n (perl) |
| 19 | sh twin: step 29 calls scripts/check-menu-parity.pl | n |
| 20 | sh twin: step 29 on the ok pair: exit 0, ^PASS 29 PS1 and bash menus match: menus | s |
| 21 | sh twin: step 29 on the bad pair: exit 0, ^FAIL 29 .*prompts only in bash | s |
| 22 | ps1 twin: step 29 calls scripts/check-menu-parity.pl | n |
| 23 | ps1 twin: step 29 on the ok pair: exit 0, ^PASS 29 PS1 and bash menus match: menus | p |
| 24 | ps1 twin: step 29 on the bad pair: exit 0, ^FAIL 29 .*prompts only in bash | p |

## The .ps1 harnesses: lines vs the expected set

Expected = the Windows CI lines minus the (s) lines, in order (`compare.sh`; outputs
`.scratch/session-e9d6-21/expect-ps1-*.txt`, `got-ps1-*.txt`, `compare.log`). `diff` empty for
all three:

- pre-push step 7: 3 lines = lines 1-3 above. `3 passed, 0 failed, 0 skipped`.
- post-push step 7: 7 lines = 1, 5, 6, 7, 8, 9, 10. `7 passed, 0 failed, 0 skipped`.
- menu parity: 22 lines = 1-19, 22, 23, 24. `22 passed, 0 failed, 0 skipped`.

Differences from the CI lines: none in the PASS lines. Names are identical, including the
trailing space of "...menus match: menus ". The summary line has no "(windows: ...)" suffix.

Also run (logs in `.scratch/session-e9d6-21/`): both perl-using harnesses under two PATH setups
(`run-perl-variants.ps1`): no perl on PATH (v1, before the check-lib block was added: Git's
`usr\bin\perl.exe` fallback taken) and Strawberry first: 22/0 and 7/0 each; and after the
conversion of the three `.ps1` files to CRLF (what checkout gives them, `.gitattributes`
`eol=crlf`): menu 22/0, post-push step 7 7/0 (`clean-crlf.sh`); the pre-push CRLF evidence is
the mutation run (below). `-Help` prints the header from line 1 to the Usage line, exit 0.

## The .sh harnesses: expected macOS/Linux lines (not runnable here)

Expected = the Linux CI lines minus the (p) lines (`expect-sh-*.txt`); macOS/Linux CI is the
evidence:

- pre-push step 7 (3): the three lines above (running `check-pre-push.sh`).
- post-push step 7 (7): `sh: the step 7 section was found`, `sh run: exit 0`,
  `sh run: build-deploy.sh was not run`, `sh run: one result, SKIP 7, pointing to check-pre-push
  step 7`, `sh static: no line runs build-deploy`, `ps1: the step 7 section was found`,
  `ps1 static: no line runs build-deploy`.
- menu parity (22): lines 1-21 and 22 (`ps1 twin: step 29 calls ...`).

Local checks: `bash -n` exit 0 on all three. Plain refusal run in Git Bash (no spoofing),
isolated HOME and TMPDIR: each exits 1, stdout empty, stderr `This script is for macOS/Linux. On
Windows, run tests/<dir>/test-<name>.ps1 with pwsh.`, 0 files written (`refuse.sh`).
`perl tests/os-guards/classify-guards.pl W W/.claude/rules/cross-platform.md <6 files>`:
`posix` x3 (.sh), `win` x3 (.ps1), exit 0. Index mode of the three `.sh` stays 100755.

## Mutation results (`mutate.ps1`; in place, restored in `finally`, SHA256 compared)

| Suite | Mutation | Result |
|-------|----------|--------|
| menu | M1 expected value `'^menus a,m,o,s,x; prompts '` -> `...,z; ...` | KILLED: FAIL lib: summary..., 21/1, exit 1 |
| menu | M2 fixture text: var.sh prompt `[n]o` -> `[x]o` | KILLED: FAIL fixture: prompts in variables..., 21/1, exit 1 |
| menu | M3 environment: STEP_REPO of the ok run -> repo-bad | KILLED: FAIL ps1 twin: step 29 on the ok pair..., 21/1, exit 1 |
| menu | M4 argument: one-argument case given two | KILLED: FAIL one argument: exit 2 (usage), 21/1, exit 1 |
| post7 | M1 expected value `check-pre-push` -> `check-post-push` | KILLED: FAIL ps1 run: one result..., 6/1, exit 1 |
| post7 | M2 fixture text: stub StepSkip writes `SKP` | KILLED: FAIL ps1 run: one result..., 6/1, exit 1 |
| post7 | M3 environment: POST_PUSH_PS1 = pre-fix `check-post-push.ps1` (`4eb80ab^`) | KILLED: FAIL build-deploy.sh was not run, one result, ps1 static; 4/3, exit 1 |
| post7 | M4 environment: POST_PUSH_SH = pre-fix `check-post-push.sh` (`4eb80ab^`) | KILLED: FAIL sh static, 6/1, exit 1 |
| pre7 | M1 expected value `is stale` -> `is fresh` | KILLED: FAIL committed deploy/ ... stale, 2/1, exit 1 |
| pre7 | M2 fixture text: config.json key `userRepoPath` -> `userRepoPathX` | KILLED: FAIL untracked ... and FAIL committed ... stale, 1/2, exit 1 |
| pre7 | M3 environment: AITOOLS_USER_REPO_PATH set to a missing dir instead of removed | KILLED: FAIL untracked deploy/: step 7 PASS..., 1/2, exit 1 |

Restore: byte-identical for all three (SHA256 F9D2203D... menu, 84079904... post7, 14A0F56E...
pre7). Every mutation run used the CRLF files; the unmutated cases in them passed (21/1, 6/1,
2/1), which is also the pre-push CRLF evidence. Logs: `mut-<suite>-M<n>.log`, `mutate-pre7.log`.
Post7 M3 is the pre-fix proof the old `.sh` header offered: the retired step's
`& $bashExe (Join-Path $scriptDir "build-deploy.sh")` hits the stub `bash.cmd`, which writes the
marker.

## Design notes (for the verifiers)

- No Git Bash in the `.ps1` harnesses. post-push step 7: the old harness set `$bashExe` to the
  real bash so a regressed step would run the fake `build-deploy.sh`; the port sets `$bashExe`
  (and `bash` first on PATH) to a stub `bash.cmd` that writes the marker. Strictly stronger: it
  catches any `& $bashExe ...`, needs no Git Bash. pre-push step 7: the harness runs only
  `check-pre-push.ps1`; that script's step 7 runs `build-deploy.sh` with Git for Windows bash
  (the approved cross-language exception). The harness SKIPs without node (as the `.sh`) or
  without Git for Windows bash (step 7 could only WARN).
- Perl: check-lib.ps1's Strawberry-first PATH block is loaded from that file's AST and run in the
  harness (one source, as platform-lib.ps1 loads ResolveGitBash; 38dc-27 review item 1), then
  the perl on PATH, else `Git\usr\bin\perl.exe` (the prompt's order). Programs go to temp `.pl`
  files (no command-line quoting) and perl writes its own stdout file (`BEGIN { open STDOUT }`),
  so copies and sections are byte-exact; `PERLIO=:perlio` (no CRLF layer).
- Here-strings (fixtures, the stub runners) are normalized to LF, so the CRLF checkout of the
  harness does not change the fixtures.
- The `.sh` static "no line runs build-deploy" check passes when perl writes nothing, even if
  perl failed; the `.ps1` port also requires perl's exit 0 (stricter; no PASS changes).
- The pre-push `.ps1` helper is `GitChecked`, not `Git`: a function named `Git` shadows `git`
  (case-insensitive) and recursed (first run: "call depth overflow"; fixed before any result).

## Files changed

- Edited: `tests/check-pre-push/test-pre-push-step7.sh`, `tests/check-post-push/test-post-push-step7.sh`,
  `tests/check-post-push/test-menu-parity.sh` (112+/112-).
- Created: `tests/check-pre-push/test-pre-push-step7.ps1`, `tests/check-post-push/test-post-push-step7.ps1`,
  `tests/check-post-push/test-menu-parity.ps1` (CRLF in the working tree).
- This report. Scratch: `W\.scratch\session-e9d6-21\` (scripts, logs, CI extracts, pre-fix
  copies of check-post-push).

## Not run

- The `.sh` harnesses past their guard (macOS/Linux CI is their evidence; never spoofed).
- With PR #167 (38dc-23) merged: it changes `check-post-push.ps1` and `check-pre-push.ps1`;
  38dc-27 will re-run. The post-push step 7 section and step 29 text the harnesses cut are not
  in #167's check-lib hunk; its check-post-push.ps1 changes are steps 4 and 6 (per its commit
  message).
- CI. check.yml still runs the three `.sh` suites in the windows job (`check.yml:881, 886, 896`
  at 15ce209); 38dc-27 holds check.yml.

## Lines

- WRITE_BLOCKED: a stray Write to `C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\placeholder-not-used.txt`
  (main checkout, outside my access; my mistake, not needed) -- "Permission for this action was
  denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]."
  Not retried. A second Monitor call (a duplicate wait) was denied with the same text; not
  retried, the existing monitor was used.
- WRITE_BLOCKED: none other.
- CONFLICT: 38dc-27 review item 1 ("no Git-perl fallback") vs this prompt ("the perl on PATH or
  Git for Windows' own usr\bin\perl.exe") -- resolved by tier 2 (prompt; an agent's message is
  not the commander's words): kept the fallback, and added check-lib's Strawberry-first block
  (the part of item 1 that does not conflict).
- CONFLICT: none other.
- INCIDENT: none new. (The cross-run these suites did is e9d6-01's INCIDENT line; this change
  removes it for these three suites.)

## Review items from 38dc-27

1. Perl selection: done in part (above).
2. `AITOOLS_TEST_BASH`: done in all three `.sh` (inner `bash` -> `"$TB"`, default `bash`).
3. `scripts/check-menu-parity.pl:40` "Tests:" names only the `.sh`: not changed (`scripts/` is
   outside my scope). Suggested text: `# Tests: tests/check-post-push/test-menu-parity.sh
   (macOS/Linux) and test-menu-parity.ps1 (Windows).`

## Open questions (each with a suggested answer)

- Q1. Should the (n) "section found" / "step 29 calls" lines stay in both harnesses? Suggested:
  yes (prompt's definition; each platform then checks both twins' text). If not, drop
  `ps1: ...section was found` and `ps1 twin: step 29 calls ...` from the `.sh` and the `sh` ones
  from the `.ps1`.
- Q2. pre-push `.ps1` SKIPs without Git for Windows bash. Suggested: keep (step 7 cannot build
  without it; the same WARN would only make the case fail with a confusing message). CI has it.
