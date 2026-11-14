# e9d6-10-port-lib report: tests/profile/test-lib -- Windows .ps1 harness

Version 1.0 (2026-11-14). Author: e9d6-10-port-lib (delegated by 38dc-13-windows-ci-ps1-only).
Worktree W = C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13 (HEAD c64d2a4 when work started). Nothing committed (scope: no git writes).

## Summary

- New `tests/profile/test-lib.ps1`: the Windows harness, native pwsh, with every case `test-lib.sh` ran on Windows (ps and gitbash cases, relay cases, the golden parity check), same check names, same order, same golden file.
- Local run (CRLF form of the file, as CI checks it out): 201 ok, 0 FAIL, 1 skip; the check lines are identical, line for line and in order, to the Windows CI run of `test-lib.sh` on main (201 ok, 0 FAIL, 1 skip).
- `test-lib.sh` now refuses Windows (the contract guard, first after `set -euo pipefail`); every ps/gitbash branch, Windows helper and Windows-only case is removed; the macOS/Linux check lines are unchanged.
- Mutation-proved: 4 mutations (golden line, harness expectation, a Git Bash case's stub, the ported JSONL checker), each turned a PASS into a FAIL and the suite exited 1; files restored and hash-verified.
- Class (c): .ps1 equivalent written. 18 cases (36 checks, the via-pwsh-* lines of CI) need Git Bash because they test the Windows branch of aitools-lib.sh; they run through `Resolve-TestGitBash`.

## What Windows-reached code the suite tests

| Code | Windows path | Ported behaviours (case names) |
|---|---|---|
| `scripts/aitools-lib.ps1` `Resolve-UserRepoPath` with `scripts/aitools-profile.ps1` | every setup script, native pwsh | convention path (urp-found), shared-only (urp-none), override missing / stub (override-missing, override-stub), resolver exit 0/1 without result lines (broken-silent0-urp, broken-silent1-urp), throw and parse error (broken-throw-urp, broken-parse-urp), exits 3 and 4 mapped and logged (exit3-urp, exit4-urp), two errors one ACTION (urp-missing-twice) |
| `Resolve-MachineProfile` | same | id, hostname, none, no match, no match twice = one ACTION (rmp-id, rmp-hostname, rmp-none, rmp-nomatch, rmp-nomatch-twice); id-key results key/owner/legacy/hostname (rmpk-id-key, rmpk-legacy, rmpk-unregistered, rmpk-other, rmpk-none, rmpk-nomatch, rmpk-old-resolver); resolver missing writes the ACTION, one per run with the dotprofile wrapper's (rmp-missing, urp-rmp-missing); broken-silent1-rmp; exit3-rmp, exit4-rmp |
| `Get-ToolException` | same | eget-none, eget-unavailable, eget-found, broken-silent0-eget, exit3-eget, exit4-eget |
| `Set-ToolException` | same | push fails = warning + ACTION (eset-written), identical record and dry run do not warn (eset-unchanged, eset-dry-run), refused (eset-refused, exit3-eset), failed (broken-silent0-eset, exit4-eset) |
| Caller variables survive dot-sourcing the lib (PR #80 B1/M1) | setup-user-config.ps1 | caller-vars-survive (-UserRepoPath, -MachineAlias, -ProfileFile, $profileName) |
| `Invoke-AitLibProfile` (the runner) | user init (aitools.ps1) | result lines for register/migrate, exit 1-4 passed through, silent exits rewritten to 2, bare hostname only for hostname, missing resolver, throw = error line, the real resolver's register/migrate/hostname (run-* cases) |
| `scripts/aitools-lib.sh` `_aitlib_profile_run` Git Bash pwsh branch (aitools-lib.sh:196-224) | build-deploy.sh and the scripts/aitools bash entry point under Git Bash on Windows (e9d6-01 research, verified by 38dc-13) | via-pwsh-urp, UTF-8 non-ASCII identity value (via-pwsh-rmp-utf8), via-pwsh-rmpk-id-key, exit 4 mapping (via-pwsh-exit4-urp), via-pwsh-eset-refused, via-pwsh-stub, broken resolvers silent0/silent1/throw/parse (via-pwsh-broken-*), runner result/exit1/hostname/silent0/throw/missing (via-pwsh-run-*), path arguments converted with cygpath -w for --profile/--out/--config/--path and not --slug (via-pwsh-run-path-args), real register (via-pwsh-run-real-register) |
| `Write-JsonlRecord`, `Invoke-ChildRelayed`, `Send-ChildLog` | installers, deploy-harness, user init | record escaping (CR and ESC dropped; quote, backslash, tab, newline escaped; UTF-8) and golden parity with the bash record (relay-record + golden check); relay ok, own ERROR row not doubled, error lines with exit 0, crash exit 1, exit 127, abort exit 2, prior-row dedupe, no summary tool, throw, parse error, no command, captured output (relay-* cases) |

## How the port works (and every place it differs from the old Git Bash harness)

- Drivers `drive.ps1`, `drive.sh`, `relay.ps1`, `child.ps1`, `child-parse.ps1` and the resolver stubs are copied verbatim from the .sh heredocs and printf lines. Only change: the two non-ASCII characters of `relay.ps1` (é, ✓) are inserted by code (`[char]0xE9`, `[char]0x2713`) so the harness source stays ASCII (cross-platform.md "ASCII preference for PS1"); the written driver is byte-identical in content.
- Every child runs through `Invoke-TestScript` (stdin at EOF, variables set and restored). The ps cases run `& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File drive.ps1 ...`; the gitbash cases run `drive.sh` with `Resolve-TestGitBash` and MSYS paths (`ConvertTo-MsysPath`), USERPROFILE in Windows form (the pwsh the lib starts takes its $HOME from it), as the old harness did.
- Environment fixes, each commented in the harness:
  - Git Bash spells a temp root under %TEMP% as `/tmp/...` (`cygpath -u`; Git mounts /tmp there). The old harness's own `$WORK` was that spelling, so it never showed. My first run failed `via-pwsh-urp (gitbash): result` on it (got `path=/tmp/profile-lib-.../home/...`). Fixed by adding Git Bash's `cygpath -u` spelling to the spellings mapped back (`ConvertFrom-NativeWork`, the port of `from_native`).
  - `[Console]::OutputEncoding` is set to UTF-8 for the run and restored in `finally`: pwsh decodes a native child's output with it, and via-pwsh-rmp-utf8 compares a non-ASCII name (the old harness compared bytes in bash). Not proven necessary locally (this console is already UTF-8); the CI console code page is unknown, so it is set explicitly.
  - Variables a case must not inherit (AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS, AITOOLS_PROFILE_FILE, AITOOLS_PROFILE_SH/PS1, AITOOLS_DRY_RUN, AITOOLS_FORCE, AITOOLS_ENVIRONMENT, AITLIB_PROFILE_VIA_PWSH, SHOW_NOTES, RUN_ARGS, FAKEBIN, PRE_ROW, RO_DIR, AITOOLS_RUN_ID) are removed in each child unless the case sets them. The old harness inherited the caller's environment; CI sets none of them, so CI results are unaffected.
  - No `MSYS_NO_PATHCONV` / `MSYS2_ARG_CONV_EXCL`: there is no MSYS layer between native pwsh and its pwsh child.
- `check-jsonl.pl` is ported to `Get-JsonlCheck` (System.Text.Json, strict UTF-8): native pwsh has no guaranteed perl with JSON::PP (Git's perl is on Git Bash's PATH only). Same output lines; same key-order regex. Edge differences, reached by no case: a line whose top level is not an object counts invalid (JSON::PP would count a false value invalid and die on a non-hash), and a non-string msg is compared as its raw JSON text.
- Streams: `Invoke-TestScript` captures stdout and stderr together; the old harness dropped stderr (`2>/dev/null`). Results are taken only from lines matching the anchored result prefixes (`^(rc|path|...)=`, `^(rc|cw)=`), which log and error lines do not start with; "child lines on the console" looks for `second warning`, which the relay prints with Write-Host (stdout). See contract change request 1.
- Driver failure handling mirrors the .sh: a non-zero child exit replaces the output with `driver failed: N` before the result lines are selected.
- Skip lines: `skip relay-run-rm-fail (bash relay temp file: macOS/Linux)` is printed and counted as before. Without Git Bash, each gitbash case prints one `skip <name> (gitbash): Git for Windows bash not found ...` (counted); CI has Git Bash.
- Final line: `201 passed, 0 failed, 1 skipped (windows: ps1)` (contract form). The .sh's Windows run printed `201 passed, 0 failed` (its form has no skip count). The .sh's own final line is unchanged for macOS/Linux.

## CI vs local

- CI: `python W\.scratch\session-38dc-13\ci-section.py ...ci-windows-main.log tests/profile/test-lib.sh` -> `W\.scratch\session-e9d6-10\test-lib-ci.txt`.
- Local: `pwsh -NoProfile -File W\tests\profile\test-lib.ps1 > W\.scratch\session-e9d6-10\test-lib-run.log 2>&1` (LF form, exit 0) and again on the CRLF form -> `test-lib-run-crlf.log` (exit 0). Both compare identical. (The first run, before the `/tmp` spelling fix, had 200 ok and 1 FAIL: via-pwsh-urp (gitbash): result.)
- Compare (`W\.scratch\session-e9d6-10\compare.py`, check lines and section headers, difflib):

| | ok | FAIL | skip | lines compared |
|---|---|---|---|---|
| CI (test-lib.sh, Windows, main) | 201 | 0 | 1 | 204 |
| local (test-lib.ps1) | 201 | 0 | 1 | 204 |

Result: identical, in order. Differing lines: none among the check lines; the final count line differs only by the contract form (above).

## Mutation proofs

Script `W\.scratch\session-e9d6-10\mutate.ps1` (run by `mutate-all.ps1`, one after the other; log `mutations.log`, per-run logs `mutation-<x>.log`). Each restores the file's original bytes in a `finally` and checks the SHA-256.

| # | Mutation | Check that failed | Suite exit |
|---|---|---|---|
| a | golden `lib-relay-record.jsonl`: `"level":"warn"` -> `"level":"WARN"`, only between the suite's `relay helpers` line and the golden check (0.6 s) | `FAIL relay-record: record differs from golden lib-relay-record.jsonl` (200 passed, 1 failed) | 1 |
| b | harness expectation: rmpk-other `owner=other` -> `owner=this` | `FAIL rmpk-other (ps): got` (200 passed, 1 failed) | 1 |
| c | Git Bash case logic: the cygpath stub marks `-w` paths `V...` instead of `W...` | `FAIL via-pwsh-run-path-args (gitbash): got` (200 passed, 1 failed) | 1 |
| d | ported JSONL checker: expected key order `...,level,msg` -> `...,msg,level` | 11 `deploy.jsonl` checks, e.g. `FAIL relay-record (ps): deploy.jsonl 'records=1 invalid=1` (190 passed, 11 failed) | 1 |

After all four: golden sha256 8B940DA0DCA40031..., harness sha256 93A944577FA20CC9... (both the originals); then the harness was converted to CRLF (below) and run again.

## Syntax and guard

- `bash -n W/tests/profile/test-lib.sh`: no output, exit 0. No CR in the file.
- PowerShell parser (`W\.scratch\session-e9d6-10\parse.ps1`, `[System.Management.Automation.Language.Parser]::ParseFile`) on `test-lib.ps1`: `parse ok`.
- `-Help` prints the 34-line header; `--help` of the .sh now prints lines 2-50 (the header grew by one line).
- Guard (`W\.scratch\session-e9d6-10\guard-check.sh`, one plain run of `bash W/tests/profile/test-lib.sh` in Git Bash): exit=1, stdout 0 bytes, stderr `This script is for macOS/Linux. On Windows, run tests/profile/test-lib.ps1 with pwsh.`, 0 new entries in the temp directory (the guard runs before mktemp). Git Bash: 5.3.15(2)-release, BASH_VERSINFO[5]=x86_64-pc-cygwin, uname -s=MINGW64_NT-10.0-26300.
- The .ps1 guard is the contract text verbatim (regex form kept for tests/os-guards).

## Files changed

- `tests/profile/test-lib.ps1` (new, Windows harness).
- `tests/profile/test-lib.sh` (edited): guard added after `set -euo pipefail`; header platform paragraph rewritten (commander quote, which harness runs what), `--bash-only` text, `--help` range 2-49 -> 2-50; removed: the pwsh-on-PATH check, `impl_runs`, `WORK_SPELLINGS`, `from_native`, `to_native`, the `.ps1` resolver stubs (stub/silent0/silent1/throw/parse/exit3/exit4/oldres/res0/res1/host/exit2/args), the cygpath stub, the `drive.ps1`, `child.ps1`, `child-parse.ps1` and `relay.ps1` heredocs, the ps and gitbash branches of `run_case` and `relay_case` and their IMPLS parameter (relay_case's EXTRA-ENV moves from position 8 to 7; its three callers updated), the ps-only cases (broken-throw-urp, broken-parse-urp, run-missing ps, run-throw, relay-run-throw, relay-run-parse), the gitbash block (its `skip via-pwsh-*` line is kept, so macOS/Linux output is unchanged), the `LANG_RUN != sh` branch of relay-run-rm-fail, and the 14 dead ` AITOOLS_PROFILE_PS1=$WORK/*.ps1` words in bash cases' EXTRA-ENV (aitools-lib.sh reads AITOOLS_PROFILE_PS1 only in its pwsh branch, aitools-lib.sh:191 and :196, taken only on Windows or with AITLIB_PROFILE_VIA_PWSH=1, which no bash case sets). Kept: `drive.sh` unchanged (its FAKEBIN and args lines serve only the Git Bash case now, but the driver text stays identical to the copy in test-lib.ps1), `LANG_RUN` (still printed in the header line: `(macos: sh)` / `(linux: sh)`).
- macOS/Linux behaviour: every bash case, check name and printed line is as before (the removed cases printed nothing there; `run_case`/`relay_case` ran only their bash branch there). Not run past the guard here (forbidden on Windows): the macOS (/bin/bash 3.2 with --bash-only) and Linux CI jobs are the proof. bash 3.2: no new construct beyond `case` and `${BASH_VERSINFO[5]:-}`.
- `git -C W status --short tests/profile` after all runs: ` M tests/profile/test-lib.sh` and `?? tests/profile/test-lib.ps1`, nothing else.
- `git -C W diff -- tests/profile/golden`: empty.
- Line endings: `test-lib.ps1` is written CRLF (841/841 lines; `.gitattributes` gives `*.ps1` `eol=crlf`, so this is what a checkout produces); `test-lib.sh` has no CR. The final verification run used the CRLF file.
- Scratch: `W\.scratch\session-e9d6-10\` (parse.ps1, compare.py, guard-check.sh, mutate.ps1, mutate-all.ps1, wait-mutations.sh, drop-ps1-env.py, to-crlf.py, logs).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none in product code. Coverage gap (pre-existing, not lost by this port): `scripts/aitools` user init calls the bash relay `run_child_relayed` on Windows (scripts/aitools:1003, writer `pwsh ... setup-user-config.ps1` in its MINGW branch, :988-995), but neither the old harness nor this one runs the bash relay (`run_child_relayed`, `relay_child_log`, `jsonl_record` in aitools-lib.sh) under Git Bash; the bash relay cases ran only on macOS/Linux. See open question 1.
- CONFLICT: contract item 1 "Final line: `<n> passed, <n> failed, <n> skipped (...)` in the same form as the .sh's" vs the .sh's actual form `N passed, M failed` (no skip count) -- resolved by tier 2 (the prompt's explicit format): the .ps1 prints `201 passed, 0 failed, 1 skipped (windows: ps1)`; check lines keep the .sh's `  ok   ` / `  FAIL ` / `  skip ` form so they compare line for line with CI.
- CONFLICT: the exemplar's `-Help` skips header line 1 (`Select-Object -Skip 1`) vs contract item 1 "`-Help` prints the header" -- resolved by tier 2: `-Help` prints all 34 header lines.
- WRITE_BLOCKED: Write `C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\placeholder-never-written.txt` -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." This was my own erroneous call (a stray placeholder in the main checkout, outside my access); the denial was correct, nothing was written, and it was not retried.

## Contract change requests (tests/lib, for 38dc-13)

1. `Invoke-TestScript`: an option to capture stderr separately or drop it (e.g. `-ErrorFile`), so a port can reproduce `2>/dev/null` exactly. Today stdout and stderr share one file; harmless here (anchored result lines), but a suite that compares whole output would see stderr.
2. Temp-root spellings: `ConvertTo-GoldenText` maps the native, mixed and `/c/...` forms, but not Git Bash's `cygpath -u` form of a root under %TEMP% (`/tmp/...`) nor the JSON-escaped form (`C:\\...`). Locally (no RUNNER_TEMP) any Git Bash output that names the temp root would not normalize; in CI the root is under RUNNER_TEMP (D:\a\_temp per GitHub's runner layout, unverified here), which Git Bash spells `/d/a/_temp/...`, so CI passes. Suggest: platform-lib gets a helper that returns every spelling (native, mixed, MSYS, JSON-escaped, 8.3 short, and Git Bash `cygpath -u` when Git Bash exists), used by `ConvertTo-GoldenText` and by suites that map paths back (this suite's `ConvertFrom-NativeWork` is a local version).

## Open questions

1. Should the Windows harness also run the bash relay (`relay.sh` + `child.sh`, i.e. `run_child_relayed`, `relay_child_log`, `jsonl_record`) under Git Bash, since `scripts/aitools` user init reaches it on Windows? Suggested answer: yes, as a follow-up adding "gitbash" relay cases to test-lib.ps1 (new check lines, so outside this port's "same lines as CI" target); first confirm whether test-user-init's Windows harness already covers the user-init relay path (golden `userinit-relay-jsonl.txt` exists; e9d6-11's scope).
2. Should `drive.sh` in test-lib.sh drop its FAKEBIN/args lines, now used only by the Git Bash case in test-lib.ps1? Suggested answer: no; one driver text in both harnesses is easier to keep in step.

## New operational learning

- Git Bash spells a Windows temp root under %TEMP% as `/tmp/...` (cygpath -u; Git mounts /tmp at %TEMP%), and aitools-lib.sh's wrappers print that spelling. A native harness that maps its temp root back must ask Git Bash (`cygpath -u`) for it; the MSYS `/c/...` form alone misses it. Seen 2026-11-14, Git for Windows bash 5.3.15.
- `.ps1` files carry `eol=crlf` in .gitattributes (`git check-attr`), so a harness must work from a CRLF checkout: here-strings then contain CRLF, and any driver written from them for bash must be converted to LF (Write-LfFile here).
- A golden mutation can be kept to under a second by starting the suite with Start-Process, polling its redirected stdout for the line before the golden check, and restoring on the check's line (mutate.ps1 mode a: 0.6 s).
