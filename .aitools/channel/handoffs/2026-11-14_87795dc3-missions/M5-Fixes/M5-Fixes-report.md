# M5-Fixes report (v1.0)

Mission M5-Fixes, delegated by Session Commander 87795dc3-e (2026-11-14 UTC). Orchestrator: six batch delegates (M5-L1, M5-L2, M5-C1, M5-C2, M5-D1, M5-D2), three PRs, merged one at a time with merge commits after every check was green and mergeStateStatus CLEAN, main's CI watched on each merge commit.

## Summary

1. All 12 items and item 13 are done: 11 fixed in code or text, item 8 (#172 already closed, #173 closed), item 13 (#72 closed, #29 commented and left open with the exact remaining work).
2. Three PRs: #149 (library, items 1, 2, 5, 10), #150 (checks, items 9, 4, 3, 11, 12), #151 (docs, items 6, 7, 8, 13 + incident #174).
3. Item 6 turned out to be four Windows-only false positives in `scripts/check-path-refs.py` (text-mode stdin to `git check-ignore`) plus one real dead ref; every mission today had logged them as "pre-existing".
4. One CI fix by M5-Fixes itself: a static test in `tests/aitools-entry/test-console-mode-guard.ps1` still expected `Write-AiLog` to call `AppendAllText` (c1e534e).
5. One WRITE_BLOCKED (a RELEASE_NOTES row for item 4) is not applied: surfaced to the commander, not routed around.

## Items

| # | Item | Status | PR | Evidence |
|---|------|--------|----|----------|
| 1 | bash spinner survives Ctrl+C | fixed | #149 | `_start_spinner` watches its owner shell (`kill -0`), `_invoke_ai_merge` sets INT/TERM/EXIT traps around `invoke_ai` and restores the caller's; 16 checks in `tests/menus/test-menu-choice.sh` (9 fail on origin/main). PS spinner: runspace thread + `finally`, judged not affected (code reading) |
| 2 | PS `Log`/`LogDetail` throw on a locked deploy.log | fixed | #149 | `Add-AitLibLogText` / `_aitlib_log_append` swallow failed writes (logging.md section 5, quoted); `tests/logging` locked-file / unwritable cases (ps1 4, sh 12 fail on origin/main) |
| 3 | post-push step 7 rebuilds the real dotprofile | fixed | #150 | step retired to SKIP in both twins (pre-push step 7 does the isolated rebuild on every push); `shared/rules/tool-lifecycle.md` "Rebuild + propagate" and `reference/post-push-checklist.md` aligned; `tests/check-post-push/test-post-push-step7.sh` 10/0 (6 fail on the old twins) |
| 4 | CI suite check misses .ps1 suites | fixed | #150 | `scripts/check-ci-suites.pl` covers `test-*.ps1`; `tests/ci-suites/test-check-ci-suites.sh` 21/0 |
| 5 | relay prompt misses the cooked-mode read | fixed | #149 | `Read-RelayOutboundChoice` reads through `Read-MenuChoice`; file now ASCII (5.1 parsed it with 11 errors before); 24 checks in `tests/menus/test-menu-choice.ps1` incl. a ConPTY raw-console case |
| 6 | five dead path refs (pre-commit step 20) | fixed | #151 | 4 false positives: `check-path-refs.py` `git_ignored()` CRLF on Windows (both paths confirmed gitignored with `git check-ignore -v`); 1 real: CLAUDE.md relay-outbound ref -> "Channel exception" |
| 7 | RELEASE_NOTES entries for #144-#147 | fixed | #151 | v0.76.2 (one same-day entry between v0.76.1 and v0.77.0, 18 items); v0.77.1/2/3 for this mission |
| 8 | close incidents #172, #173 | #172 already closed (v0.76.1, PR #143), amended; #173 closed | #151 | #173 closedIn v0.76.2 (PR #144, merge c66d4b1); setup-user-shell.ps1 `Update-MarkedBlock` single owner, no `[regex]::Replace` |
| 9 | check-*.ps1 call the WSL bash | fixed | #150 | `ResolveGitBash` in `scripts/check-lib.ps1`; `tests/check-lib/test-resolve-git-bash.ps1` 17/0 (4 fail on the old scripts) |
| 10 | installer repos prompt on stdout | fixed | #149 | `prompt_repos_path` prints to /dev/tty; `step3-prompt-*` pty cases in `tests/profile/test-install.sh` (11 fail against the old printf) |
| 11 | step 29 misses helper prompts | fixed | #150 | `scripts/check-menu-parity.pl`; `tests/check-post-push/test-menu-parity.sh` 24/0 (old extraction misses both planted prompt mismatches) |
| 12 | tool-lifecycle says `pending` | fixed | #150 | registry: 57 tool-platform versions, 31 strings, 26 null, 0 pending; 4 n/a platforms null. Rule now says null. No registry change |
| 13 | issues #72, #29 | #72 closed; #29 open with comment | -- | #72: https://github.com/nobul-tech/aitools/issues/72#issuecomment-6872294548 (run 43557171983 verified green on 592c5b3; three-mutation test); #29: https://github.com/nobul-tech/aitools/issues/29#issuecomment-6872294831 (EOF cases missing for the JSON field prompt and the AI-merge preview/feedback reads) |

## PRs, merges, main CI

| PR | Merge commit | Main CI on the merge commit |
|----|--------------|-----------------------------|
| https://github.com/nobul-tech/aitools/pull/149 | 383c32193830c671956539a4060a227d20b07be0 | run 43565965314: linux, macos, windows success |
| https://github.com/nobul-tech/aitools/pull/150 | ec36ffa8b9776a9229be353627b46979226c67f1 | see final response (watched after this file was committed) |
| https://github.com/nobul-tech/aitools/pull/151 | this PR | see final response |

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED (M5-C1): Edit of `RELEASE_NOTES.md` adding the v0.77.2 row for item 4 -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." Not retried by the delegate and not applied by M5-Fixes (doing it would route around the denial). The exact text is in `M5-C1-report.md` "WRITE_BLOCKED". Later RELEASE_NOTES edits by M5-C2, M5-L1, M5-L2, M5-D2 and M5-Fixes' merge resolutions were not denied.
- WRITE_BLOCKED (M5-D1): a write to the main checkout's handoff path (its own path error); the file went to the worktree.
- CONFLICT (several delegates): auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops" -- resolved by the commander's CLAUDE.md: dedicated tools.
- CONFLICT (M5-L1): prompt's "e.g. a one-time console warning" vs logging.md section 5 ("swallowed") -- resolved by the prompt's own "implement exactly that": silent swallow.
- CONFLICT (M5-D1): /incident closed-entry fields vs prompt's "updated date" -- prompt; /incident "mention in release notes" vs prompt "NOT RELEASE_NOTES" -- prompt (M5-D2 then wrote the notes).
- CONFLICT (M5-C2): cross-platform.md cross-language approval vs a perl helper called from the .ps1 check -- followed existing precedent (post-push already calls perl/python); open question below.
- INCIDENT filed: #174 (high) -- log writers outside aitools-lib (`aitools-install.*`, `aitools-profile.*`, `check-lib.*`) are not fail-safe.
- INCIDENT candidates, not filed: `check-pre-commit.ps1` step 3 `-Fix` runs build-deploy with `2>$null | Out-Null` and no exit check, and its WARN suggests `-Fix`, which builds against the real HOME; post-push steps 2, 6, 14 and pre-commit steps 3, 10 still inspect the frozen aitools `deploy/`; `setup-pywinpty.ps1` SilentlyContinue without a result check (post-push step 23 FAIL, from #148); `scripts/hh.ps1` does not parse under Windows PowerShell 5.1 (UTF-8 em dashes, no BOM); pre-commit step 20's Windows-only false positives were recorded as "pre-existing" by PR #144, #147 and missions M2/M3b/M4.

## Delegates and how they were verified

| Delegate | Batch | Verification by M5-Fixes |
|----------|-------|--------------------------|
| M5-L1 | items 1, 2 | read the PS lib diff and the new `_start_spinner`; CI on all three platforms (found the stale static test, fixed in c1e534e). Delegate disclosed it did not read five mandated files in full |
| M5-L2 | items 5, 10 | read both code diffs; CI green |
| M5-C1 | items 9, 4 | read `ResolveGitBash` and `check-ci-suites.pl`; reran `test-check-ci-suites.sh` after the main merge (21/0) |
| M5-C2 | items 3, 11, 12 | read the step 7 / step 29 / rule-text diffs; reran `test-menu-parity.sh` after the main merge (24/0) |
| M5-D1 | items 6, 8, 13 | read the checker and CLAUDE.md diffs; confirmed both paths are gitignored; confirmed CI run 43557171983 green on 592c5b3 before posting its issue comments |
| M5-D2 | item 7, incident #174 | read the v0.76.2 bug-fix rows against the PR numbers; RELEASE_NOTES diff vs main is insertion-only |

## Open questions (each with a suggested answer)

1. Apply the blocked v0.77.2 item 4 row? Suggested: yes, the commander pastes the text from `M5-C1-report.md`.
2. Close #29 now? Suggested: no; add the three EOF cases (JSON field prompt, AI-merge preview, `[r]` feedback) to `tests/menus/test-menu-choice.sh` / `.ps1`, then close.
3. Does a perl/python helper called from a `.ps1` check need a cross-language table row? Suggested: add one "shared check helpers" row next time the table is reviewed.
4. Is `hh.ps1` meant to support Windows PowerShell 5.1? Suggested: no -- say "pwsh 7 only" in its header (PS 7 is the baseline).
5. v0.76.2 is a patch number for minor-sized content (forced by its position below v0.77.0). Suggested: keep; the entry explains it.

## Operational learning (new today)

- Python `subprocess.run(input=str, text=True)` on Windows writes CRLF; a `git ... --stdin` reader then misses every line but the last. Pass bytes.
- A pre-commit check that fails only on Windows can be a bug in the checker (pre-commit never runs in CI). Investigate before calling it "pre-existing".
- The WSL launcher a native pwsh finds here is `%LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe`; from a pwsh started by Git Bash, `Get-Command bash` finds Git's `usr\bin\bash.exe`, so the bug only shows in a native terminal.
- A background job of a non-interactive bash ignores SIGINT; a spinner must watch its owner (`kill -0`) and/or be stopped by traps.
- Windows PowerShell 5.1 reads a BOM-less `.ps1` as ANSI; an em dash's bytes include 0x94, which it treats as a quote. Keep 5.1-loaded files ASCII.
- A plain `[Console]::ReadLine()` on a raw ConPTY console never returns: a reliable test for the cooked-mode guard.
- Library changes can break static (AST) tests in other suites (`tests/aitools-entry`); run every suite that greps the changed function, not only the ones named after it.
- Several pushes to one branch queue several CI runs (no concurrency cancel); cancel superseded runs, then watch the run on the full head SHA.
- Quote git pathspecs in Git Bash (`'tests/*/test-*.ps1'`), or the shell expands them against the current directory.
- Check scripts honour `AITOOLS_LOG_DIR`; point it at scratch to keep checks.log out of `~/.aitools/logs`.
- RELEASE_NOTES conflicts between parallel PRs that each add a top entry: resolve by taking one side and inserting the other side's entry block (scratch `resolve-rn*.sh`), then `git diff --stat origin/main` must show insertions only.
