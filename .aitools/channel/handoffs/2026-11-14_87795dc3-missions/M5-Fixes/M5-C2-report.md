# M5-C2 report: check-post-push step 7 retired (item 3), step 29 covers menu-read prompts (item 11), tool-lifecycle aligned (items 3 and 12)

Version 1.0 (2026-11-14). Author: M5-C2, delegated by M5-Fixes. Branch
`fix/m5-checks` (worktree `.claude/worktrees/m5-checks`), after M5-C1's 0c667a8.

**Intent**: **Purpose**: hand M5-Fixes the result of items 3, 11 and 12: what
changed, the evidence, what was not run, what is still open. **Scope**: items 3,
11, 12 only. NOT the Git Bash resolution or the CI suite check (M5-C1). NOT the
PR (M5-Fixes opens it). NOT the registry data. **Audience**: M5-Fixes, then the
commander.

## Summary

1. Item 3 fixed: check-post-push step 7 (both twins) is retired to a SKIP pointing to check-pre-push step 7; neither twin runs `build-deploy.sh` any more. Proven by a new suite that runs the step 7 section with a fake build-deploy under a temp HOME (10/10; 6 cases fail on the pre-fix twins).
2. Item 11 fixed: step 29 also compares the prompts of every `read_menu_choice` / `Read-MenuChoice` call, via one new script `scripts/check-menu-parity.pl` both twins call; new suite 24/24 including planted prompt mismatches that the old extraction misses.
3. Item 12 fixed: tool-lifecycle "Lifecycle field completeness" now says `null` (registry evidence: 0 of 57 versions use `pending`; the 4 `n/a` platforms carry `null`).
4. check-post-push.ps1 run once after the fix under an isolated HOME/USERPROFILE/APPDATA/LOCALAPPDATA and log dir with a scratch dotprofile clone: step 7 SKIP, step 29 PASS; real dotprofile `deploy/` and `~/.aitools/logs` unchanged.
5. Pushed: 4eb80ab (item 3), c3803f9 (item 11), c136c8c (item 12), plus the commit carrying this report. No WRITE_BLOCKED.

## Item 3: check-post-push step 7

Status: fixed (option b, retire).

The bug, as found on 0c667a8: `check-post-push.sh` step 7 ran `bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1` then `git diff deploy/`; `check-post-push.ps1` step 7 ran `& $bashExe (Join-Path $scriptDir "build-deploy.sh") 2>$null | Out-Null` then `InvokeGit diff deploy/`. With the caller's HOME the build replaces the real dotprofile `deploy/`; the diff looks at the frozen aitools `deploy/`, which build-deploy no longer writes (`.claude/rules/deploy-paths.md`), so the step always passed. `reference/post-push-checklist.md` step 7 already called the step retired and the code an "open defect".

Choice: (b). Reasoning: check-pre-push step 7 already does the isolated rebuild on every push (commander, 2026-10-26); its block is about 130 lines in the .sh twin (temp HOME, git archive of the dotprofile, node config rewrite, build, diff, four dry runs), entangled with pre-push's own logging and env scrubbing, so (a) is not "a small reuse": extracting it into check-lib would touch check-pre-push and its suite for no gain, and repeating the rebuild after the push adds minutes, not safety.

The fix:
- Both twins, step 7: one `step_skip` / `StepSkip "7" "deploy/ drift audit" "retired: check-pre-push step 7 rebuilds into a temp dotprofile copy"`, with a comment giving the reason; step number kept.
- `check-post-push.ps1`: comment "every bash step (2, 4, 6, 7)" -> "(2, 4, 6)"; SKIP texts of steps 2 and 6 "bash not found" -> "Git Bash not found" (M5-C1 follow-up 3). `check-lib.ps1` ResolveGitBash comment: "check-post-push steps 2, 4, 6 and 7" -> "2, 4 and 6".
- `shared/rules/tool-lifecycle.md` "Rebuild + propagate": rewritten (see Review after).
- `reference/post-push-checklist.md`: step 7 describes the SKIP and the history; step 2's pointer to "the incident note under step 7" replaced (steps 2, 6, 14 still check the frozen aitools `deploy/`: an open gap, see Follow-ups).

Evidence:
- `bash tests/check-post-push/test-post-push-step7.sh`: 10 passed, 0 failed, 0 skipped. Per twin: the step 7 section (cut between the `# 7.` and `# 9.` headings) runs with stub step functions, a temp HOME and a fake scripts dir whose `build-deploy.sh` only writes a marker: marker absent, exactly one result `SKIP 7 retired: check-pre-push step 7 ...`; plus a static scan that no non-comment line of either twin runs build-deploy. The .ps1 section runs in pwsh 7.6 with `$bashExe` set to a real bash, so the old code would really have run the fake build.
- Mutation (`.scratch/session-M5-C2/mutation-step7.sh`, `POST_PUSH_SH` / `POST_PUSH_PS1` = the 0c667a8 twins): 4 passed, 6 failed (marker created by both old twins, PASS 7 instead of SKIP 7, static hits `check-post-push.sh:204` and `check-post-push.ps1:236`), exit 1.

## Item 11: check-post-push step 29

Status: fixed.

The gap, as found: step 29 took the `[x]` letter of `printf` lines (bash) and `Console...Write` lines (PS1) only. The four `read_menu_choice` calls in `aitools-lib.sh` and four `Read-MenuChoice` calls in `aitools-lib.ps1` pass their menu in the prompt argument (`"  [y]es accept / [r]efine / [n]o reject: "`, `"  choice [o/a/m/s/x]: "`, `"  choice [o/s/x]: "`, and a run-time `"  choice [$(...)]: "`), so a mismatch there was never seen.

The fix: `scripts/check-menu-parity.pl BASH_LIB PS1_LIB` (new, 100755, `--help`), called by both twins (the step 32 / `check-hook-parity.py` pattern):
- Menu lines: the old comparison, unchanged except that full-line comments are skipped and the PS1 regex is case-insensitive (as `Select-String` was).
- Prompts: logical lines (`\` / backtick continuations joined, full-line comments dropped); bash calls found by a quote-aware tokenizer (`$(...)` nesting, trailing `#` comments, command position only, so `read_menu_choice()` and "# n (read_menu_choice returns ...)" do not count), 6th argument; PowerShell calls by name in any case (not `function Read-MenuChoice`), arguments scanned with string/`$(...)`/`@(...)` awareness, `-Prompt` value. A `$var` prompt takes the last literal assigned earlier in the file. Letters: `[x]` and `[a/b/c]`; one sorted set per call, `?` when none; the two files' sorted lists of sets must match (multiset difference reported: `prompts only in bash: [q,r,y]; prompts only in PS1: [n,r,y]`). Exit 0 / 1 (also when nothing is found in either file) / 2.
- Both twins: SKIP `perl not available` when perl is missing (same outcome both sides); on FAIL the script's detail lines are printed; PASS detail now `PS1 and bash menus match: menus a,m,o,s,x; prompts ?|a,m,o,s,x|n,r,y|o,s,x`.
- Blind spots documented in the script header: letters built at run time, variables assigned elsewhere / by concatenation, a call split without a continuation character, `-Prompt` abbreviated / `-Prompt:value` / positional / splatted, block comments and here-strings, only the last `[x]` per menu line, wrapper helpers.

Evidence:
- `bash tests/check-post-push/test-menu-parity.sh`: 24 passed, 0 failed, 0 skipped: current libs match with 4 calls per side; planted `[n]o` -> `[q]uit` in the bash `read_menu_choice` prompt FAILs, named; planted `[r]efine` -> `[e]dit` in the PS1 `-Prompt` FAILs, named; the pre-v0.77.2 extraction is shown to MATCH on both planted pairs (the gap closed); `[o/a/m/s/x]` -> `[o/a/s/x]` FAILs; a printf `[s]kip` -> `[k]eep` FAILs (menu letters); variable prompts (bash `local prompt=...`, PS `$prompt = '...'`, lower-case `read-menuchoice`) resolve and a mismatch through them FAILs; commented-out calls and trailing comments ignored; nothing found, usage, unreadable file, `--help`; step 29 section of each twin (bash; pwsh 7.6) PASS on the current pair and FAIL on the planted one. A planted anchor that disappears (M5-L1 edits the libs) fails the case loudly, never passes silently.
- The isolated check-post-push.ps1 run: step 29 PASS with that detail.

## Item 12: tool-lifecycle "Lifecycle field completeness"

Status: fixed (rule text only, no registry change).

Evidence, read through /tool-registry (read only; `.scratch/session-M5-C2/probe-versions.py` over this branch's registry): 19 tools, each with `versions.{macos,windows,linux}` objects = 57; `lastVerifiedVersion` is a string in 31, `null` in 26, `"pending"` in 0 (the string occurs nowhere under `tools.*.versions`). The 4 platforms with platform status `n/a` (nss-tools macos and windows, pywinpty macos and linux) carry `lastVerifiedVersion: null` and `lastVerified: null`; google-chrome macos and windows (platform status `null`) are `null` too. check-post-push step 21 treats a falsy version as "no <platform> version in registry" (SKIP), so `null` is also what the check expects; a `pending` string would be compared as a version.

## Branch, commits, files

- Branch `fix/m5-checks`, pushed: 4eb80ab (item 3), c3803f9 (item 11), c136c8c (item 12), then the report commit (RELEASE_NOTES "Verified on" + this file).
- Changed: `scripts/check-post-push.sh`, `scripts/check-post-push.ps1`, `scripts/check-lib.ps1` (comment), `.github/workflows/check.yml` (4 steps: both new suites in the linux and windows jobs), `reference/post-push-checklist.md` (steps 2, 7, 29), `shared/rules/tool-lifecycle.md`, `RELEASE_NOTES.md` (v0.77.2 items 2, 3, 4, three Files-created rows, Verified line).
- New (100755): `scripts/check-menu-parity.pl`, `tests/check-post-push/test-post-push-step7.sh`, `tests/check-post-push/test-menu-parity.sh`.

## Verification (commands and results)

All check runs had `AITOOLS_LOG_DIR` in `.scratch/session-M5-C2/` (nothing written to `~/.aitools/logs`).

| Command | Result |
|---|---|
| `parse-touched.sh` (bash -n / pwsh parser / perl -c on every touched script) | all OK |
| `bash tests/check-post-push/test-post-push-step7.sh` | 10 passed, 0 failed |
| same, against the 0c667a8 twins (`mutation-step7.sh`) | 6 failed, exit 1 (as intended) |
| `bash tests/check-post-push/test-menu-parity.sh` | 24 passed, 0 failed |
| `git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' \| perl scripts/check-ci-suites.pl .github/workflows/check.yml` | All 42 test suites are in CI or exempt |
| `"C:\Program Files\Git\bin\bash.exe" tests/os-guards/test-os-guards.sh` | 34 passed, 0 failed |
| `pwsh -NoProfile -File tests/check-lib/test-resolve-git-bash.ps1` | 17 passed, 0 failed |
| `check-pre-commit.ps1` (items 3, 11 staged) | 11 PASS, 4 SKIP, 3 WARN (3, 5, 11), 1 FAIL (step 20) |
| `check-pre-commit.ps1` (item 12 staged) | 7 PASS, 9 SKIP, 2 WARN, 1 FAIL (step 20) |
| `check-pre-push.ps1` before each push | 0 FAIL; step 7 PASS (fresh build OK, dry runs clean) |
| `check-post-push.ps1`, isolated (`run-postpush-isolated.sh`) | 20 PASS, 5 SKIP, 5 WARN, 3 FAIL; step 7 SKIP, step 29 PASS |

How check-post-push.ps1 was run (after reading every step of both twins for writes: logs go to `AITOOLS_LOG_DIR`; step 1 runs `git fetch origin main` in the worktree (the shared git dir's FETCH_HEAD and `origin/main` ref); step 21 runs `<tool> --version` commands; step 23 runs check-script-compliance.ps1, which only logs; nothing else writes): from Git Bash, `env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE HOME=<scratch>/pp/home USERPROFILE=<same, Windows form> APPDATA=<scratch>/pp/appdata LOCALAPPDATA=<scratch>/pp/localappdata AITOOLS_LOG_DIR=<scratch>/pp/logs pwsh -NoProfile -ExecutionPolicy Bypass -File <WT>\scripts\check-post-push.ps1`; `<scratch>/pp/home/.aitools/config.json` = repoPath WT, reposPath `<scratch>/pp`, userRepoPath `<scratch>/pp/dot` (a `git clone` of the dotprofile plus a copy of its `deploy/`). A probe first confirmed a pwsh started with `USERPROFILE` overridden sees it as `$HOME` (`[Environment]::GetFolderPath("UserProfile")` does not follow it; no check code uses it). Before/after snapshots (path, size, mtime of every file): real dotprofile `deploy/` (52 lines) unchanged, the copy's `deploy/` unchanged, real `~/.aitools/logs` unchanged, `git status --porcelain` of the real dotprofile unchanged.

Failures in that run, none from this mission: step 1 (branch HEAD != origin/main, known), step 3 (no `.claude.json` / `.cursor/mcp.json` in the isolated HOME), step 23 (check-script-compliance step 11: `setup-pywinpty.ps1:151` SilentlyContinue without a result check; pre-existing from #148). WARNs: 17 (no settings.json in the isolated HOME), 19, 20 (CLI 2.1.325 vs registry 2.1.309), 21 (16 tools "out of date"; likely skewed by the isolated APPDATA/LOCALAPPDATA, not investigated), 25.

Known pre-existing: pre-commit step 20 (the five dead path refs M5-D1 is fixing); step 11 WARN (uncommitted changes in the dotprofile, not mine; I never wrote there); step 3 WARN suggests `-Fix`, which runs build-deploy.sh against the real HOME: not run.

## Not run

- CI (first runs of both new suites on linux and windows, of `check-menu-parity.pl` on Linux, of the step 29 .sh twin on Linux).
- macOS bash 3.2 for the new suites (written 3.2-safe: no associative arrays, no `${var,,}`; not in the macos job).
- `check-post-push.sh` (POSIX-guarded; its step 7 and 29 sections are exercised by the suites).
- `tests/check-pre-push/test-pre-push-step7.sh`: no shared step-7 code was touched (check-pre-push is unchanged).

## Review after (old -> new)

- `shared/rules/tool-lifecycle.md` "Rebuild + propagate":
  - old: `3. \`bash scripts/check-post-push.sh\` — all checks pass` / `4. Commit + push both repos (aitools via a PR; dotprofile to its main)`
  - new: `3. Before each aitools push, the pre-push checklist (\`@reference/pre-push-checklist.md\`; macOS and Linux: \`bash scripts/check-pre-push.sh\`, Windows: \`pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-push.ps1\`). Its step 7 rebuilds \`deploy/\` into a temporary copy of the dotprofile under a temporary \`HOME\` and dry-runs the generated scripts.` / `4. Commit + push both repos (aitools via a PR; dotprofile to its main)` / `5. After the push, the post-push checklist (\`@reference/post-push-checklist.md\`; macOS and Linux: \`bash scripts/check-post-push.sh\`, Windows: \`pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-post-push.ps1\`). It never runs \`build-deploy.sh\` (its step 7 is retired); its step 1 fails until the change is on \`origin/main\`.`
- `shared/rules/tool-lifecycle.md` "Lifecycle field completeness":
  - old: "... invocation) and a last verified version per platform (`pending` when unverified). Verify them before committing."
  - new: "... invocation) and a last verified version and date per platform: `null` until verified on that platform, and `null` on a platform the tool does not support (platform status `n/a`). Verify them before committing."
- `reference/post-push-checklist.md`: step 2 parenthetical -> "as do steps 6 and 14, so these steps prove nothing about the dotprofile build (an open gap; check-pre-push step 7 is the check of the build, see step 7)"; step 7 "open defect" paragraph -> "Always SKIP (...)" plus history; step 29 "Collects every [letter] ... compares the two sorted sets" -> menu lines + prompts via `check-menu-parity.pl`.
- `check-post-push.sh/.ps1` step 7: build-deploy + `git diff deploy/` -> SKIP; step 29: inline extraction -> `check-menu-parity.pl` (+ prompts, + perl SKIP); `.ps1` steps 2 and 6 SKIP text "bash not found" -> "Git Bash not found".
- `check-lib.ps1` ResolveGitBash comment: post-push "steps 2, 4, 6 and 7" -> "steps 2, 4 and 6".
- `check.yml`: new steps "check-post-push step 7 tests" and "check-post-push step 29 menu parity tests" in the linux and windows jobs.
- `RELEASE_NOTES.md` v0.77.2: Bug fixes item 2 (High), Improvements item 3, Documentation item 4, Files created rows for the three new files, "Verified on" extended.

## WRITE_BLOCKED / CONFLICT / INCIDENT

WRITE_BLOCKED: none (the RELEASE_NOTES.md edits went through this time).

CONFLICT: `.claude/rules/cross-platform.md` "Cross-language script calls require explicit approval" vs this prompt's "(or a small script)" for the step 29 extraction -- resolved by tier 1 precedent in the commander-governed code, not by loosening the rule: `check-post-push.ps1` already calls perl inline (steps 26, 30, 31) and a shared python script (step 32, `check-hook-parity.py`), and the `.sh` twin does the same; the rule's approved/unrecorded tables list `.ps1` -> Git Bash calls, not perl helpers. I followed that precedent and record it here for review (open question 1).

CONFLICT: prompt "RELEASE_NOTES: number sequentially after its last item" (M5-C1's last item is 1) vs M5-C1's WRITE_BLOCKED item 2 that M5-Fixes will add -- resolved by tier 2 (the prompt): my items are 2, 3, 4; M5-Fixes renumbers when it inserts M5-C1's improvement row.

INCIDENT (not filed; for M5-Fixes triage):
- check-post-push steps 2, 6 and 14 still check the frozen aitools `deploy/` (bash -n, syntax, line endings), so they prove nothing about the dotprofile build; pre-commit steps 3 and 10 have the same gap (`deploy-paths.md` says so). Spec deviation, medium.
- check-script-compliance step 11 (run by post-push step 23) FAILs on `scripts/setup-pywinpty.ps1:151` (`SilentlyContinue` without a result check), from PR #148. Spec deviation, medium (script-standards "Error handling requirements").
- check-pre-commit step 3 WARN tells the user to "run with -Fix", which runs build-deploy.sh against the real HOME (also M5-C1's candidate about its unchecked exit code).

## Follow-ups

1. M5-Fixes: renumber RELEASE_NOTES v0.77.2 when adding M5-C1's WRITE_BLOCKED item 2 (my items become 3, 4, 5).
2. `reference/tool-support-decision-tree.md` plans to extend step 29 to `tool_method_menu` / `Read-ToolMethodChoice`: `check-menu-parity.pl` takes any file pair, so that is a second call with those files once the helpers exist.
3. The menu-read helper is also called outside the lib (`scripts/aitools` / `aitools.ps1`, `setup-user-hooks`, `setup-user-skills`); step 29 audits the lib pair only. Running `check-menu-parity.pl` on those pairs is a cheap extension (separate step or a loop).
4. Step 21's "16 out of date" under an isolated APPDATA was not investigated; rerun with the real environment to see whether it is real.

## Open questions

1. Does a perl helper called from a `.ps1` check need an entry in cross-platform.md's cross-language table? Suggested answer: no, record it as precedent instead: perl is a managed tool, already called inline by the same checks, and a shared helper is what keeps the twins identical; add one "Shared check helpers (perl/python, both twins)" row to the table when the table is next reviewed.
2. Should the step 29 prompt comparison be per function (pair each bash call with its PS1 twin) rather than a multiset? Suggested answer: not now; the multiset already catches every planted case, and pairing needs a function map between the libs that would drift on its own.

## New operational learning

- A pwsh started from Git Bash with `USERPROFILE` overridden sees it as `$HOME`; `[Environment]::GetFolderPath("UserProfile")` still returns the real profile. Isolated-HOME runs of `.ps1` checks are sound as long as the code uses `$HOME` (the check scripts do).
- PowerShell 7.6 does not turn redirected native stderr (`& perl ... 2>&1`) into a terminating error under `$ErrorActionPreference = "Stop"`; the `InvokeGit` comment in check-lib.ps1 describes older behaviour.
- Testing one step of a long check: cut its section between two `# N.` headings with perl and dot-source it under stub step functions; the .ps1 section runs the same way with `. $section` in a small runner. This also gives a real mutation test against an old commit (`git show <sha>:<path>`).
- The Edit tool takes an absolute path: one Edit nearly targeted the main checkout's `check.yml` (a no-op call with identical strings, rejected); `git -C <main> status` afterwards was clean. Always type the worktree path in full.
