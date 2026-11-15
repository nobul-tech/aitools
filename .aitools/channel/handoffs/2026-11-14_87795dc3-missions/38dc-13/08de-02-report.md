# 08de-02 report: verification of e9d6-21's three check-step suite ports (v1.0)

**Intent**: **Purpose**: An independent verdict on e9d6-21's port of three check-script suites:
the three `.ps1` harnesses rerun, mutation-proofed through copies, the three `.sh` diffs reviewed,
the case mapping against the pre-port files, the perl selection, the OS-guard suite, and the
macOS evidence. **Scope**: `tests/check-pre-push/test-pre-push-step7.{ps1,sh}`,
`tests/check-post-push/test-post-push-step7.{ps1,sh}`, `tests/check-post-push/test-menu-parity.{ps1,sh}`
at branch head eaf261a. NOT the deploy-steps and pre-commit suites (08de-01, e9d6-22). NOT
check.yml or `scripts/` (findings only). **Audience**: 38dc-27 (who fixes and commits), the PR
reviewer, the commander.

Author: 08de-02-post-push-ps1, delegated by 38dc-27-windows-ci-finish. Date: 2026-11-14.
Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`, branch
`fix/38dc-13-windows-ci-ps1-only`, head eaf261a. I edited no file in `tests/` or `scripts/`, made
no commits and pushed nothing. Scratch: `W\.scratch\session-08de-02\`.

## Verdict

**No blocking findings.** Every case group in the three `.ps1` harnesses catches a mutation of the
code it tests. The one exception is the static "step 29 calls `scripts/check-menu-parity.pl`"
check, which a comment line satisfies (N1); that weakness was inherited from the pre-port suite.
The three `.sh` diffs do what the port promised: the guard comes first, no pwsh is left, every
`.sh`-twin and Perl case is kept, `"$TB"` is used and the `--help` ranges are right. The local
`.ps1` runs and CI (run 43659071174 at 3065a2a: macos, linux and windows jobs) agree on 3 / 7 / 22.

### Non-blocking findings

| # | Where | Finding | Suggested fix |
|---|---|---|---|
| N1 | `tests/check-post-push/test-menu-parity.ps1:266` and `:270`; `tests/check-post-push/test-menu-parity.sh:206` (sh twin) and `:228` (ps1 twin) | The static "step 29 calls scripts/check-menu-parity.pl" checks match any line of the step 29 section, comments included. Step 29's comment names the script (`scripts/check-post-push.sh:752`, `scripts/check-post-push.ps1:874`), so pointing the code line at a different script leaves the check passing. Mutation menu-S1b (`.sh` twin) **survived**. For the `.ps1` twin (menu-S2b) only the run cases caught it. The weakness is inherited: the pre-port `.sh` used the same `grep -q 'check-menu-parity.pl'` (5f962b1). | Drop full-line comments before matching. In the `.ps1`, filter `Lines` with `-notmatch '^\s*#'`. In the `.sh`, use `perl -ne 'next if /^\s*#/; ...'` (or `grep -v '^[[:space:]]*#' \| grep -q ...`). |
| N2 | `tests/check-post-push/test-menu-parity.ps1:91-99`, `:282-287`; `tests/check-post-push/test-post-push-step7.ps1:80-88` | The Git-perl fallback is kept (section "Perl" below). When Strawberry is not installed and no perl is on PATH, the harness falls back to Git's `usr\bin\perl.exe`. In the same environment `check-post-push.ps1` step 29 reports SKIP "perl not available". So in that environment the harness tests a perl the check never uses, and puts it on the PATH of the step 29 run (`:282-287`). That runs against `cross-platform.md` "Git Bash PATH shadowing" ("no fallback to bundled versions"). It does not happen on this machine or in CI today: Strawberry is first on PATH (probe below). | Replace the fallback with a FAIL "perl not found (Strawberry or PATH)". Or add a ps1-twin case for the SKIP branch with no perl on PATH. |
| N3 | `tests/check-post-push/test-menu-parity.ps1`, `test-post-push-step7.ps1` | Neither harness prints which perl it ran, so CI logs cannot show which interpreter the Windows job used. | Print one line before the cases, e.g. `Write-Output "perl: $perl"` (not a PASS line, so the expected-line compare still holds). |
| N4 | `.github/workflows/check.yml:298` (macos job) | `test-pre-push-step7.sh` now honours `AITOOLS_TEST_BASH` (it picks the bash that runs `check-pre-push.sh`). The macos job runs it only with bash 5, while the other two suites also have a `/bin/bash 3.2` step (`:324`, `:332`). | Add `check-pre-push step 7 tests (macOS /bin/bash 3.2)` with `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/check-pre-push/test-pre-push-step7.sh`, or record why not (it runs a full build-deploy, so it is slow). |
| N5 | `scripts/check-menu-parity.pl:40` | Its "Tests:" line names only the `.sh` harness (already in e9d6-21's report). | `# Tests: tests/check-post-push/test-menu-parity.sh (macOS/Linux) and test-menu-parity.ps1 (Windows).` |

## Counts

| Suite | Local Windows (eaf261a, pwsh 7.6.10) | CI windows (43659071174, 3065a2a) | CI macos bash 5 / 3.2 | CI linux |
|---|---|---|---|---|
| pre-push step 7 | 3 passed, 0 failed, 0 skipped (`.ps1`) | 3/0/0 | 3/0/0 / no 3.2 step | 3/0/0 |
| post-push step 7 | 7/0/0 (`.ps1`) | 7/0/0 | 7/0/0 / 7/0/0 | 7/0/0 |
| menu parity | 22/0/0 (`.ps1`) | 22/0/0 | 22/0/0 / 22/0/0 | 22/0/0 |

Logs: `W\.scratch\session-08de-02\run-v-pre7.log`, `run-v-post7.log`, `run-v-menu.log` (local).
CI log `ci-43659071174.log`, summary lines extracted with `ci-counts.pl`. All eleven CI steps
concluded success (`ci-steps.sh 43659071174`).

`tests/os-guards/test-os-guards.ps1` (Windows, pwsh 7.6.10): **68 passed, 0 failed, 0 skipped**,
exit 0. The three `.sh` are refused as expected (`run-osg.log` lines 46, 48, 50), each with
"refuses windows (exit 1, guard message, only logs written)".

`bash -n`: exit 0 on all three `.sh`, and each keeps index mode 100755 (`bash-n.sh`).

## Mutation proofs

Method (38dc-27's order: never mutate a file in `scripts/` or `tests/` in place):

- **post-push step 7**: fresh copies of `scripts/check-post-push.ps1` / `.sh` under
  `W\.scratch\session-08de-02\mut\`, passed through the harness's `POST_PUSH_PS1` / `POST_PUSH_SH`.
  The worktree's own harness ran.
- **menu parity, pre-push step 7**: these harnesses have no override variable (menu parity reads
  `scripts/check-menu-parity.pl`, the libs and both twins from `$root`; pre-push step 7 clones
  `$root` and copies `$root/scripts` over the clone). They ran from a scratch clone of the branch,
  `W\.scratch\session-08de-02\mirror\` (HEAD eaf261a; `tests/lib/platform-lib.ps1` copied byte for
  byte from W so the harness inputs match, as `cmp-mirror.ps1` checked). Only mirror files were
  mutated, each restored and checked byte-identical by SHA256 after its run. Afterwards
  `git -C mirror status` shows only the deliberate platform-lib copy.
- Driver: `mutate.ps1`; one log per mutation in `mutlogs\mut-<id>.log`. A mutation is KILLED when
  the suite exits 1 and the check aimed at fails; other checks that also fail are listed.

| Id | Case group (check aimed at) | Mutation | Result |
|---|---|---|---|
| post7-1 | sh section found | `.sh` copy: `# 7.` heading -> `# 7:` | KILLED: 6/1, FAIL sh: the step 7 section was found |
| post7-2 | sh static | `.sh` copy: step 7 runs `bash "$SCRIPT_DIR/build-deploy.sh"` | KILLED: 6/1, FAIL sh static |
| post7-3 | ps1 section found | `.ps1` copy: `# 7.` heading -> `# 7:` | KILLED: 5/2, FAIL section found, one result |
| post7-4 | ps1 run: exit 0 | `.ps1` copy: `throw "mutant"` before the SKIP | KILLED: 5/2, FAIL exit 0, one result |
| post7-5 | ps1 run: build-deploy not run | `.ps1` copy: `$bd = "build-deploy.sh"` + `& $bashExe (Join-Path $scriptDir $bd)` (passes the static regex, so only the run sees it) | KILLED: 6/1, FAIL build-deploy.sh was not run |
| post7-6 | ps1 run: one result | `.ps1` copy: an extra `StepPass "7"` | KILLED: 6/1, FAIL one result |
| post7-7 | ps1 run: one result (text) | `.ps1` copy: SKIP text `check-pre-push` -> `check-post-push` | KILLED: 6/1, FAIL one result |
| post7-8 | ps1 static | `.ps1` copy: after the section, `if ($false) { & $bashExe (Join-Path $scriptDir "build-deploy.sh") }` | KILLED: 6/1, FAIL ps1 static |
| menu-L1 | lib: pair matches (exit 0) | perl: a match exits 5 | KILLED: 19/3 (lib exit 0, fixture exit 0, ps1 ok run) |
| menu-L2 | lib: summary | perl: summary `menus` -> `menu` | KILLED: 20/2 (lib summary, ps1 ok run) |
| menu-L3 | lib: n,r,y both sides | perl `letters()`: the letter r dropped | KILLED: 20/2 (lib AI-merge prompt, planted [q]uit) |
| menu-L4 | lib: every call found | perl: the first bash call not reported | KILLED: 13/9 (incl. "every call found ... (3 bash, 4 PS1 ...)") |
| menu-L5 | lib: run-time prompt counts as ? | perl `letters()`: no-letter prompt -> `-` | KILLED: 21/1 |
| menu-P1 | planted bash prompt, named | perl: `prompts only in bash` -> `prompts only bash` | KILLED: 19/3 (P1, list plant, ps1 bad run) |
| menu-P2 | planted: pre-v0.77.2 gap (bash) | mirror `aitools-lib.sh`: a `printf '  [z]ap'` line appended | KILLED: 17/5 (both gap checks, lib x2, ps1 ok run) |
| menu-P3 | planted PS1 prompt, named | perl: `prompts only in PS1` -> `prompts only PS1` | KILLED: 19/3 (P3, P1, fixture mismatch) |
| menu-P4 | planted: pre-v0.77.2 gap (PS1) | mirror `aitools-lib.ps1`: a `[Console]::WriteLine("  [z]ap")` line appended | KILLED: 17/5 (both gap checks, lib x2, ps1 ok run) |
| menu-P5 | planted [o/a/s/x] list | perl `letters()`: every list read as o/a/m/s/x | KILLED: 21/1 |
| menu-P6 | planted printf menu line | perl: menu-letter mismatch never reported | KILLED: 21/1 |
| menu-F1 | fixture: variables resolve | perl: bash `name=` lookup never matches | KILLED: 21/1 |
| menu-F2 | fixture: comments do not count | perl `logical_lines()`: full-line comments kept | KILLED: 14/8 (incl. "one call each") |
| menu-F3 | fixture: mismatch through a variable | perl: PowerShell `-Prompt $var` always "[y]es / [n]o" | KILLED: 21/1 |
| menu-E1 | nothing found: exit 1 | perl: "extraction broken?" -> "extraction failed?" | KILLED: 21/1 |
| menu-E2 | one argument: exit 2 | perl: usage exits 3 | KILLED: 21/1 |
| menu-E3 | unreadable file: exit 2 | perl: unreadable exits 4 | KILLED: 21/1 |
| menu-E4 | --help | perl: `--help` prints nothing | KILLED: 21/1 |
| menu-S1 | sh twin calls the checker (static) | mirror `check-post-push.sh`: both mentions -> `check-menu-parity2.pl` | KILLED: 21/1 |
| menu-S1b | same | the code line only (the comment keeps the name) | **SURVIVED**: 22/0 (N1) |
| menu-S2 | ps1 twin calls the checker (static) | mirror `check-post-push.ps1`: both mentions -> `check-menu-parity2.pl` | KILLED: 19/3 (static, ok run, bad run) |
| menu-S2b | same | the code line only | static check passed; the ok and bad runs failed: 20/2 (N1) |
| menu-R1 | ps1 twin step 29 on the ok pair | mirror `check-post-push.ps1`: PASS only on exit 9 | KILLED: 21/1 |
| menu-R2 | ps1 twin step 29 on the bad pair | mirror `check-post-push.ps1`: FAIL text drops the checker summary | KILLED: 21/1 |
| pre7-1 | untracked: step 7 PASS, comparison skipped | mirror `check-pre-push.ps1`: PASS text loses ", not compared" | KILLED: 2/1 |
| pre7-2 | untracked: fixture dotprofile left clean | mirror `check-pre-push.ps1`: step 7 writes `mutant.txt` into the configured dotprofile | KILLED: 2/1 |
| pre7-3 | committed deploy/ stale: FAIL | mirror `check-pre-push.ps1`: stale files never reported (`-gt 0` -> `-gt 99`) | KILLED: 2/1 |

Summary: 35 mutations (post7 8, menu 24, pre7 3). 34 killed (each with exit 1). 33 failed the
check they were aimed at; menu-S2b failed only the run checks (its static check passed). menu-S1b survived (N1). Every mutated
mirror file was restored and checked byte-identical (SHA256), and every post7 mutation was on a
copy.

## `.sh` diffs against the pre-port files (5f962b1 -> eaf261a)

Reviewed with `git diff 5f962b1 HEAD -- <file>`. origin/main (after #167) does not touch these
three files.

| Item | pre-push step 7 | post-push step 7 | menu parity |
|---|---|---|---|
| Guard form | the `cross-platform.md` "Test suites" block verbatim (`uname -s` case + `BASH_VERSINFO[5]` case, `printf ... >&2`, exit 1), first thing after `set -uo pipefail` and its comment (`:33-42`) | same (`:36-45`) | same (`:45-54`) |
| Guard message names the `.ps1` | `tests/check-pre-push/test-pre-push-step7.ps1` | `tests/check-post-push/test-post-push-step7.ps1` | `tests/check-post-push/test-menu-parity.ps1` |
| No pwsh / Windows branch left | `IS_WINDOWS`, `native()`, the pwsh branch of `run_step7` and the pwsh SKIP condition removed | `IS_WINDOWS`, `native()` and the whole `.ps1` run block removed; the `.ps1` static checks are kept (perl reads) | `IS_WINDOWS`, `native()` and the `.ps1` step 29 run block removed; the `.ps1` static check is kept |
| `.sh`-twin and Perl cases kept | all 3 (untracked x2, stale), check lines byte-identical | sh section found, sh run x3, sh static; ps1 section found, ps1 static | all 18 Perl cases, sh static, sh run ok/bad, ps1 static; unchanged lines |
| `"$TB"` | `TB="${AITOOLS_TEST_BASH:-bash}"` runs `check-pre-push.sh` | runs `run.sh` (the section) | runs `run29.sh` (the section) |
| `--help` range | `$. <= 26`, Usage line 26 | `<= 29`, Usage line 29 | `<= 38`, Usage line 38 |
| bash 3.2 | no new construct: `"$TB"`, `${BASH_VERSINFO[5]:-}` and `case` work in 3.2; the removed array `envs=(...)` was the only array use in `run_step7` | same | same; `paste -s -d , -`, `sort -u`, `cmp -s`, `wc -l \| tr -d ' '` work on BSD |
| `bash -n` | 0 | 0 | 0 |

The `.ps1` `-Help` ranges also match: `-TotalCount 29` (pre-push step 7, Usage line 29), `30`
(post-push step 7, line 30), `36` (menu parity, line 36).

## Case mapping against the pre-port files (5f962b1)

Pre-port: each `.sh` ran on all three platforms, with a pwsh branch for the `.ps1` twin.

| Pre-port case (5f962b1 `.sh`) | `.sh` now (macOS/Linux) | `.ps1` now (Windows) |
|---|---|---|
| pre7 untracked deploy/: step 7 PASS (whole `check-pre-push.ps1` on Windows, `.sh` elsewhere) | same name, `check-pre-push.sh` | same name, `check-pre-push.ps1` |
| pre7 untracked: fixture dotprofile left clean | same | same |
| pre7 committed deploy/ stale: FAIL | same | same |
| post7 sh: section found | kept | kept (perl read) |
| post7 sh run: exit 0 / no marker / one result (3) | kept | sh twin only (not ported: runs bash code) |
| post7 sh static | kept | kept (perl read) |
| post7 ps1: section found | kept (perl read) | kept |
| post7 ps1 run: exit 0 / no marker / one result (3) | removed (ran `.ps1` code in pwsh) | kept; `$bashExe` and `bash` on PATH are a stub `bash.cmd` (the old run used the real bash) |
| post7 ps1 static | kept (perl read) | kept |
| menu lib (5), planted (6), fixture (3), errors (4) | kept | kept (perl from pwsh) |
| menu sh twin: calls the checker (static) | kept | kept (perl read) |
| menu sh twin run ok / bad (2) | kept | sh twin only |
| menu ps1 twin: calls the checker (static) | kept | kept |
| menu ps1 twin run ok / bad (2) | removed | kept |

Totals: pre7 3 -> 3 + 3; post7 10 -> 7 (`.sh`) + 7 (`.ps1`); menu 24 -> 22 (`.sh`) + 22 (`.ps1`).
The `.ps1` names and order equal the Windows CI lines of the pre-port suite minus the `.sh`-twin
run lines. Spot-checked against e9d6-21's CI extract
`W\.scratch\session-e9d6-21\ci-windows-test-menu-parity.txt` and `...-post-push-step7.txt`.

## Perl

Current behaviour, confirmed by reading and by a replay (`probe-perl2.ps1`, the harnesses'
selection code run from Git Bash):

- `test-menu-parity.ps1:85-90` and `test-post-push-step7.ps1:74-79` load `scripts/check-lib.ps1`'s
  top-level `if ($IsWindows)` Strawberry block (check-lib lines 13-19) from its syntax tree and run
  it. Replay: before the block, `C:\Program Files\Git\usr\bin\perl.exe` was first; after it,
  `C:\Strawberry\perl\bin\perl.exe` (v5.42.0). That is the perl `check-post-push.ps1` step 29 gets
  through `check-lib.ps1`.
- The step 29 run child inherits that PATH, so the `.ps1` twin runs `perl` as the real step does.
- Kept: if no perl is on PATH after the block, the harness takes Git for Windows' own
  `usr\bin\perl.exe` (`test-menu-parity.ps1:91-99`, `test-post-push-step7.ps1:80-88`) and puts it
  first on the step 29 child's PATH (`test-menu-parity.ps1:282-287`).
- **Risk** (N2): only on a Windows machine with no Strawberry and no perl on PATH (a native pwsh
  outside Git Bash). There the real step 29 reports SKIP "perl not available", while the harness
  tests the checker, and the `.ps1` twin's PASS/FAIL paths, with a perl the product would never
  use. The suite then passes green on an environment where the check would SKIP. Nothing tests the
  SKIP branch. It is not reachable on this machine or in the windows-2022 CI job as they are
  (Strawberry is installed). The cost is masking, not a wrong PASS of the product. This is the
  conflict e9d6-21 recorded (38dc-27 review item 1 vs its prompt); its resolution kept the
  fallback.

## macOS finding

- **Why the two post-push suites were missing from the macos job:** no reason was recorded. The
  commits that added them say only "a CI step in the linux and windows jobs" and list macOS bash
  3.2 as "Not run (written 3.2-safe)" (`4eb80ab` for post-push step 7, `c3803f9` for menu parity;
  `git log -S` finds no other check.yml commit naming them).
- **Now:** check.yml runs both in the macos job with bash 5 and `/bin/bash 3.2` (`:320`, `:324`,
  `:328`, `:332`). CI run 43659071174 (3065a2a) macos: post-push step 7 7/0/0 under both bash
  versions, menu parity 22/0/0 under both, pre-push step 7 3/0/0 (bash 5 only, N4). Linux has the
  same counts.
- **By reading:** no `grep -P`, `sed -i`, `stat -c`, `readlink -f` or GNU-only flag in the three
  `.sh`. CI confirms it at 3065a2a. eaf261a does not change these files.

## Not run

- The `.sh` harnesses past their guard: never on Windows. macOS/Linux CI at 3065a2a is their
  evidence; eaf261a only merges #167, which does not touch these files. CI on eaf261a (run
  43662443876) was in progress when I checked.
- A Windows run without Strawberry Perl (the N2 path): it cannot be produced here without
  uninstalling Strawberry.
- Whole `check-*` scripts against the real HOME: never.

## Lines

- WRITE_BLOCKED: none.
- CONFLICT: none in this task. (First task, recorded in my earlier hand-back:
  my prompt's "write the harnesses" vs the concurrent-agents rule while e9d6-21 was writing the
  same files. Resolved by tier 2, 38dc-27's newer direction: I stopped without editing.)
- INCIDENT: none new. N1 is a test-strength gap and N2 a test-environment deviation from
  `cross-platform.md` "Git Bash PATH shadowing". Both are fix items for 38dc-27, not incidents (no
  incidents on this mission).

## Files

- Created: this report.
- Scratch only, `W\.scratch\session-08de-02\`:
  - scripts: `run-suite.sh`, `mutate.ps1` (+ `rename.pl`, `rename2.pl`), `cmp-mirror.ps1`, `probe-eol.ps1`, `probe-perl.ps1`, `probe-perl2.ps1`, `bash-n.sh`, `ci-steps.sh`, `ci-counts.sh`, `ci-counts.pl`
  - output: the logs, `mutlogs\`, `mut\`, and the `mirror\` clone
- Changed in `tests/` or `scripts/`: none (`git -C W status` clean at the end).

## Open questions (each with a suggested answer)

- Q1. Fix N1 in both harnesses now? Suggested: yes, a one-line change per check (skip comment
  lines); it makes the static checks mean what their names say.
- Q2. N2: drop the Git-perl fallback or test the SKIP branch? Suggested: drop it (FAIL "perl not
  found") to match `cross-platform.md` "no fallback to bundled versions" and check-lib's "Fail,
  don't mask". The SKIP branch can get its own case later.
