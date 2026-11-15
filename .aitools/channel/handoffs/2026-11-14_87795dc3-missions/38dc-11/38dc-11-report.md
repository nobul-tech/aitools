# 38dc-11-report: script compliance in CI, shared delegation rule, bootstrap.ps1 under pwsh 7

**Intent**: **Purpose**: Record what mission 38dc-11 found, changed and verified for
its three orders, so the orchestrator M6-Polish and the commander can check the PR
without re-deriving it. **Scope**: The CI compliance step, `shared/rules/delegation.md`,
`scripts/bootstrap.ps1`, their tests, docs and incident #179. NOT the other M6 PRs.
**Audience**: The commander; M6-Polish (agent id ends 38dc).

Version 1.0, 2026-11-14, by 38dc-11-compliance-ci-bootstrap (agent id ends 4cdc). A
version, not a draft (D-DEL5). Merge SHA and main's CI run are in the hand-back (they
exist only after this file is merged).

## Summary

1. CI now runs the script-compliance check on every PR and push to main: the `.sh` twin
   in the linux job, the `.ps1` twin in the windows job; a FAIL check fails the job.
2. `shared/rules/delegation.md` is a byte-identical copy of the dotprofile rule (git blob
   a703c08 in both), so the next `aitools` run deploys it to `~/.claude/rules` and
   `~/.cursor/rules`; until now it was not deployed at all on the commander's machine.
3. `scripts/bootstrap.ps1` runs the installer and `aitools.ps1` under pwsh 7, installing
   pwsh with the registry's winget command when missing; incident #179 filed and closed.
4. New `tests/bootstrap/test-bootstrap.ps1` (Windows CI; `-File` and `irm | iex` forms):
   26 passed; origin/main's bootstrap fails 15 checks; 8/8 one-line mutants killed.
5. PR #160, independent review 4cdc-1: two rounds of CHANGES REQUESTED, fixed, final
   APPROVE-AS-COMMENT. Both compliance steps fail on `setup-pywinpty.ps1:151` (#177)
   until PR #157 merges (linux job of run 43630454198: the only failing step).

## Part 1: compliance check in CI

**Found.** `git grep check-script-compliance` (origin/main 2ee68d9): only
`scripts/check-post-push.sh:602-611` / `.ps1:707-725` (step 23) and
`reference/post-push-checklist.md:198`; no CI step. `check-post-push` sets
`EXTENSIVE=true` / `$Extensive = $true` (sh:24, ps1:167), so step 23 always runs, but
only after a push. Run on origin/main (`pwsh -NoProfile -File
scripts/check-script-compliance.ps1`, AITOOLS_LOG_DIR in scratch): `11. SilentlyContinue
has result check [FAIL] 1 unchecked: setup-pywinpty.ps1:151`, `SUMMARY: 11 PASS, 1 SKIP,
0 WARN, 1 FAIL`, exit 1. Incident #177 (on PR #157's branch) is that line; its
preventionLayer lists "a pre-push or CI run of check-script-compliance (follow-up)".

**Changed.** `.github/workflows/check.yml`: linux job "Script standards compliance
(check-script-compliance.sh)" `run: bash scripts/check-script-compliance.sh`; windows job
"Script standards compliance (check-script-compliance.ps1, native)" `run: pwsh -NoProfile
-File scripts/check-script-compliance.ps1`. Both `if: ${{ !cancelled() }}`. Twins chosen
because each is OS-guarded (the `.sh` refuses MINGW, the `.ps1` refuses non-Windows) and
they check different things (step 3 for `.sh` vs `.ps1` exits, step 7 bash only); both
check the `.ps1` SilentlyContinue rule (step 11). Not repeated on macOS (static check).
`check-ci-suites.pl` needs no change (it covers `tests/*/test-*`). Each compliance step is
the LAST step of its job (review finding 1): in run 43630454198 the step, placed mid-job,
failed and GitHub skipped the 13 later linux steps that have no `if:` condition.

**Evidence** (scratch copies of `scripts/`, no tracked file touched): as on the branch,
exit 1 (`setup-pywinpty.ps1:151`); with PR #157's `setup-pywinpty.ps1`, exit 0 (12 PASS,
1 SKIP, 0 FAIL); with #157's file plus a planted `setup-zzplant.ps1` holding an unchecked
`Get-ChildItem ... -ErrorAction SilentlyContinue`, exit 1 (`setup-zzplant.ps1:5`). In CI
(run 43630454198, linux job 132555667844) the `.sh` twin reported
`11. SilentlyContinue has result check [FAIL] 1 unchecked: setup-pywinpty.ps1:151`,
`SUMMARY: 12 PASS, 0 SKIP, 0 WARN, 1 FAIL`, exit 1: the same line, nothing else.

**Existing violation**: not fixed here (PR #157 owns it, per the prompt). The CI step
fails on it until #157 merges; this PR merges only after main (with #157) is merged in
and CI is green.

## Part 2: delegation.md

**Found.** `shared/rules/delegation.md` absent on origin/main. `~/.claude/rules/` on the
workstation has concurrent-agents, scratch, tool-evaluation, tool-lifecycle, tool-ops,
web-sources (no delegation.md); `~/.aitools/rules/.aitools-rules-manifest` lists 5
`shared` rules. R-8 (reference/rules.md) deploys `shared/rules` only, so the dotprofile
rule never reached user scope although CLAUDE.md and `/delegate` cite
`~/.claude/rules/delegation.md`.

**Changed.** `cp` from the dotprofile; verified: sha256 of both working files
b501afc6...; `git hash-object` of the copy = dotprofile `HEAD:` and `origin/main:` blob
a703c08739ff; dotprofile clean for that path; no non-ASCII bytes. The dotprofile is not
edited.

**What a new shared rule triggers.** No tracked manifest: deploy-harness writes
`.aitools-rules-manifest` at run time from `shared/rules` (deploy-harness.ps1:290, 387-).
Pre-commit step 21 checks skills only (`check-skill-levels.py`), so the same name in the
dotprofile `claude/rules` is not flagged; under R-8 deploy-harness never reads the
dotprofile, so no deploy ERROR either. reference/rules.md section 8 step 3 still said a
duplicate is an ERROR on every deploy-harness run (true under R-1 only): updated (v1.4).
Cursor: setup-user-cursor's `ConvertTo-CursorRule` (extracted by AST and run on the
file): `alwaysApply: true`, fan-out marker, body unchanged, `Test-CursorRuleParse` "" (OK).
Tests that enumerate shared rules: none (fixtures only).

## Part 3: bootstrap.ps1

**Found.** origin/main `scripts/bootstrap.ps1:48`: `& powershell -NoProfile
-ExecutionPolicy Bypass -File (Join-Path $aitoolsDir 'scripts\aitools-install.ps1')`;
step 4 ran `& aitools user init` / `& aitools` through `Get-Command aitools` (in the
bootstrap's own host; the profile function or `aitools.ps1` would run in-process).
Nothing installed pwsh. `aitools-install.ps1` has no version guard;
`aitools-lib.ps1:639` uses 3-argument Join-Path (PS 6+). The Git Bash forwarder in
`aitools-install.sh:97-117` already winget-installs pwsh.

**Install method.** `/tool-registry` `tools.pwsh.install.windows`: preferred
`winget install --id Microsoft.PowerShell --source winget`. Install-command gate:
read with chrome-devtools on 2026-11-14,
https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.6,
verbatim: "Install the PowerShell 7 MSIX package: ... winget install --id
Microsoft.PowerShell --source winget"; "Beginning with the winget package for PowerShell
7.6.0, winget installs the MSIX package by default."; "Beginning with the PowerShell
7.7.0 release, there is no MSI package available." Recorded in the registry entry's
`install.windows[0].notes` and `reference/tool-registry.md`.

**Changed.** New Step 3 ensures pwsh (`Get-Command pwsh -CommandType Application`;
winget with the registry command plus the agreement flags, as aitools-install.sh;
additive `Update-SessionPath`; `throw` (never `exit`, which would close an `irm | iex`
shell) when winget or pwsh is missing). Step 4 runs the installer with pwsh and reports a
non-zero exit (bootstrap.sh parity). Step 5 runs `%USERPROFILE%\.local\bin\aitools.ps1`
(the installer's Step 6 target; bootstrap.sh uses `$HOME/.local/bin/aitools`) with pwsh,
rebuild only after `user init` exits 0. The whole body is one script block (`& { }`, added
after review findings 5 and 6): under `irm | iex` its `$ErrorActionPreference = 'Stop'`,
variables and functions no longer leak into the caller's session (that leak predates this
PR). ASCII; parses under 5.1. bootstrap.sh unchanged (no parity gap: it already checks the
installer exit and finds aitools by path).

**Choice recorded.** Install pwsh (not stop): the registry has a preferred Windows method,
the bash forwarder already installs pwsh the same way, and the bootstrap's purpose is a
fresh machine. Stop-with-message remains for "no winget" and "still missing after
install".

## Tests and mutation results

`tests/bootstrap/test-bootstrap.ps1` (new; windows CI step "bootstrap.ps1 pwsh 7 launch
tests"): bootstrap.ps1 runs under `powershell.exe` 5.1 with PATH = a stub dir
(`git.cmd`, `winget.cmd` recording arguments), System32 and WindowsPowerShell (plus the
pwsh dir in the "present" cases); AITOOLS_DIR, USERPROFILE and HOME in a temp dir with a
stub installer and stub `aitools.ps1` recording `$PSVersionTable`. Two cases run it
through `Invoke-Expression` in a 5.1 runner (the `irm | iex` form) and check the runner
survives with its `$ErrorActionPreference` and without bootstrap's functions; a static
check counts `ExitStatementAst` nodes (parser, after review round 2: a regex missed an
indented `exit`). Result on Windows 11: 26 passed, 0 failed, 0 skipped. In CI the runner
may be non-interactive (`[Environment]::UserInteractive`): then "present" checks the skip
message and "initrc" is SKIP (unknown until a run's log shows it).

| Mutant (one line each) | Result |
|--------|--------|
| origin/main bootstrap.ps1 (not a mutant: the old file) | 15 FAIL (installer `5\|Desktop`) |
| winget id typo | 2 FAIL |
| no-winget `throw` -> `Say` | 2 FAIL (survived the first test version; killed after adding "stops before calling winget") |
| em dash in a comment | 1 FAIL |
| `aitools.ps1 user init` in-process | 1 FAIL (`5\|user init`) |
| installer via `& powershell` | 4 FAIL |
| `throw` -> `exit 1` in the pwsh branch | 3 FAIL (survived the first test version: reviewer finding 5) |
| body dot-sourced (`. {` for `& {`) | 2 FAIL |
| indented `exit 1` in the git branch | 1 FAIL (survived the regex check: reviewer round 2) |

Independent review (4cdc-1, a fresh delegate with no author notes): round 1 CHANGES
REQUESTED (https://github.com/nobul-tech/aitools/pull/160#issuecomment-6882864827;
blocking: the mid-job compliance step skipped later steps), round 2 CHANGES REQUESTED
(#issuecomment-6882961070; blocking: regex exit check), round 3 APPROVE-AS-COMMENT
(#issuecomment-6883011213). Non-blocking 7, 8, 9, 11 are follow-ups in the PR body; 10
(open-form fields in the closed incident) declined: the `/incident` close step strips
them, as in #172, #173, #176.

`check-ci-suites.pl`: "All 43 test suites are in CI or exempt"; with the bootstrap step
removed from a copy of check.yml: error, exit 1.

Checks: `check-pre-commit.ps1` (no -Fix) 10 PASS, 6 SKIP, 3 WARN, 0 FAIL (WARN 3 build
freshness, 5 platform note, 11 uncommitted changes in the dotprofile, not this
mission's); `check-pre-push.ps1` 8 PASS, 2 WARN, 0 FAIL.

## Not run

- `.sh` suites and the `.sh` compliance twin (Windows; commander 2026-11-14). tests/os-guards
  and tests/ci-suites have no `.ps1` half: CI only.
- bootstrap.ps1 with pwsh still missing after a winget install; a real winget install.
- aitools / deploy-harness against the real HOME.

## Lines

- CONFLICT: reference/rules.md section 8 step 3 ("unique across shared/rules, .claude/rules
  and the dotprofile claude/rules") vs the commander's "make a copy and put it in
  shared/rule/delegation.md" -- resolved by tier 1 (the commander's words): copied; step 3
  updated to say delegation.md is the one deliberate duplicate.
- CONFLICT: the prompt's "use the next free id after the highest on origin/main" (175) vs
  the orchestrator M6-Polish's later correction ("If you file an incident, use **#179**")
  -- resolved by tier 2 (the delegating agent's newer correction of its own prompt; no
  commander words on it): filed first as #175, renumbered to #179 (commit e624154).
- INCIDENT: #179 filed and closed in this PR (duplicate search on origin/main,
  fix/m6-checks and fix/m6-logging: none; #169 only lists bootstrap.ps1 among its
  New-Item call sites).
- WRITE_BLOCKED: none.

## Open questions

1. Keep two copies of delegation.md? Suggested: make `shared/rules/delegation.md` the
   source and delete (or reduce to a pointer) the dotprofile copy, in a dotprofile commit by
   the commander.
2. Add `#Requires -Version 7.0` to `aitools-install.ps1`? Suggested: yes, separate PR
   (as #157 did for hh.ps1); bootstrap.ps1 now never runs it under 5.1, but a manual
   `powershell -File aitools-install.ps1` still would.

## New operational learning

- Glob returns nothing under `.claude/worktrees/` (gitignored path): use `git ls-files` /
  `git grep` in a worktree.
- In a PowerShell `@(a, b + c)` array literal the comma binds tighter than `+`: wrap
  computed elements in parentheses (a mutation harness silently tested the wrong mutant).
- Inside `try {}` every error is terminating: a test suite needs a `catch` that counts a
  FAIL, or a crash reports as a clean partial run.
- Running Windows PowerShell 5.1 from pwsh 7: clear `PSModulePath` for the child.
- A one-line script returned from a scriptblock unrolls: wrap with `@()` at the call site.
- A CI check step that is expected to fail for a while goes LAST in its job: a failed
  step makes GitHub skip every later step without `if:` (13 linux test steps were skipped).
- A text that runs under `irm | iex` must be one `& { }` block with `throw`, never `exit`;
  test it through `Invoke-Expression`, and find `exit` with the parser
  (`ExitStatementAst`), not a regex.
