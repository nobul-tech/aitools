# M3-Fixes-B evidence v1.0 -- console input mode around aitools.ps1 Step 2 (fix 4)

Session M3-Fixes-B, 2026-11-13 (UTC 2026-11-14T00:06Z-00:14Z), Windows 11, pwsh 7, Git for Windows bash.
All paths below are relative to
`C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\.scratch\session-M3-B\`.

## Harness

- `conmode.cs.ps1` -- copied from the prior session scratch (P/Invoke: GetConsoleMode, SetConsoleMode,
  AttachConsole, CreateFileW CONIN$, ...).
- `driver-poll.ps1 -Label L -Target T -Variant V [-Extra X]` -- starts a minimized pwsh (its own new
  console) running T, AttachConsole to that console only, polls the CONIN$ input mode every 100 ms and
  logs every change to `poll-L.log`; the target writes `result-L.log`.
- `extract-guard.ps1` -- defines Save-ConsoleInputMode / Restore-ConsoleInputMode from the worktree
  `scripts/aitools.ps1` via the PowerShell AST (the harness runs the shipped code, not a copy).
- `target-sim.ps1` -- (a) a child process (`pwsh -File setraw.ps1`) sets the console input mode raw and
  exits without restoring it, inside the guarded region.
- `target-build.ps1` -- (b) the real Step 2 command (`& $bashExe .../scripts/build-deploy.sh 2>&1 | Out-String`,
  or with `$null |` in front), isolated: HOME and USERPROFILE = `home\`, AITOOLS_USER_REPO_PATH =
  `dotprofile` (a `git clone` of aitools-nobul-jose), AITOOLS_LOG_DIR = `logs-build-<variant>\`, build-deploy
  run from the worktree. deploy.log lines of the helpers: `logs-*\deploy.log`.

Baseline cooked mode in these consoles: 0x1F7.

## (a) Simulated child leaves the console raw

| Run (result-/poll- log) | Guard | Child | Mode before | After child exits | Final | Restore result |
|---|---|---|---|---|---|---|
| sim-noguard-2E8 | no | sets 0x2E8 via stdin | 0x1F7 | 0x2E8 | **0x2E8** | -- |
| sim-guard-2E8 | yes | sets 0x2E8 via stdin | 0x1F7 | 0x2E8 | **0x1F7** | restored |
| sim-noguard-208 | no | sets 0x208 via stdin | 0x1F7 | 0x208 | **0x208** | -- |
| sim-guard-208 | yes | sets 0x208 via stdin | 0x1F7 | 0x208 | **0x1F7** | restored |
| sim-nullstdin-noguard | no | stdin is a pipe; SetConsoleMode on its stdin | 0x1F7 | 0x1F7 (child: ok=False) | 0x1F7 | -- |
| sim-nullstdin-conin-noguard | no | stdin is a pipe; opens CONIN$, sets 0x2E8 | 0x1F7 | 0x2E8 | **0x2E8** | -- |
| sim-nullstdin-conin-guard | yes | stdin is a pipe; opens CONIN$, sets 0x2E8 | 0x1F7 | 0x2E8 | **0x1F7** | restored |

deploy.log (logs-sim-guard-2E8\deploy.log):
`[2026-11-14T00:06:56Z] [m3b-sim] [detail] console input mode 0x2E8 after sim-child, restored 0x1F7`

Save-ConsoleInputMode, warm (Add-Type of another type already loaded): 39-57 ms.

Finding: a pipe for the child's stdin stops a child that uses its stdin handle (MSYS does), but not
one that opens CONIN$ itself; the save/restore covers both.

## (b) Real Step 2 command (isolated build-deploy via Git Bash)

| Run | stdin of bash | Guard | Build time | Mode changes during the build (poll, 100 ms) | Mode after build | Restore | rc |
|---|---|---|---|---|---|---|---|
| build-noguard | console | no | 30364 ms | 47 (0x1F7 -> 0x2E9 -> 0x2E8, then 0x2E8/0xE7 toggling, 0x1F7 at the end) | 0x1F7 | -- | 0 |
| build-guard | console | yes | 28882 ms | 42 (same pattern) | 0x1F7 | unchanged | 0 |
| build-nullstdin | pipe (`$null \|`) | no | 26218 ms | **0** | 0x1F7 | -- | 1 (*) |
| build-nullstdin-2 | pipe | no | 26721 ms | **0** | 0x1F7 | -- | 0 |
| build-guard-nullstdin | pipe | yes | 26574 ms | **0** | 0x1F7 | unchanged | 0 |

Counts exclude the poller's first reading and the changes made by the probe `bash -c '[ -t 0 ]'` with
console stdin before READY (seen as 0x2E8/0x2E9 then back to 0x1F7 in the guard and null-stdin polls;
too short for the 100 ms poll in build-noguard). Raw totals in the poll logs: 48, 45, 3, 3, 3.
Probe in every run: `bash -c '[ -t 0 ]'` with console stdin = "stdin tty", with `$null |` = "stdin not-tty".

(*) `mv: cannot move '.../dotprofile/deploy' to '.../deploy.swap.bak.98Aish/old': Permission denied`
during the final swap; build-deploy kept the old deploy/ and its backup (safe-failure path). Not stdin
related: the same command (rerun, build-nullstdin-2) and guard-nullstdin succeeded; build-guard (console
stdin) exercised the same swap path and succeeded. Probable cause (unverified): a transient handle
(antivirus/indexer) on the freshly written tree.

Cold Save-ConsoleInputMode (first Add-Type in the process, compiles AitConsoleModeGuard): 294 ms
(build-guard), 311 ms (build-guard-nullstdin). Skipped entirely (no Add-Type) when stdin is redirected.

Build output equivalence (`compare-builds.sh`): guard (console stdin) vs guard-nullstdin (pipe) differ
only in lines explained by concurrent working-tree edits of the parallel missions
(setup-user-shell.ps1 size 225849 -> 239777, harness snapshot 108 -> 109 files, the backup count).
build-deploy.sh reads no stdin (its `read` loops all read files or pipes).

The "left raw after the build" condition from the commander's runs was not reproduced: in all three
console-stdin builds MSYS put 0x1F7 back at exit. The restore path is evidenced by (a).

## Isolation

Real dotprofile `C:\Users\jdpal\repos\aitools-nobul-jose`: `git status --short` = ` M profile.json`
before and after; `deploy/` mtime 2026-11-13 16:04:11.214 -0800 before and after (that rebuild predates
this mission's first build at 16:07:39; its cause is unknown). No key was sent to any console; the
driver attached only to consoles it started.

## Tests

- `tests/aitools-entry/test-console-mode-guard.ps1`: 18 passed, 0 failed, 0 skipped.
- Mutation check (`mutate.ps1`, copies under `mut\`): origin/main 941e64a -> 14 FAIL; `$null |` removed ->
  1 FAIL; Restore call removed -> 2 FAIL; Save replaced by `$null` -> 1 FAIL; unmodified -> 0 FAIL.
- `tests/logging/test-logging.ps1` (covers aitools.ps1): 20 passed, 0 failed.
- Parser: `scripts/aitools.ps1` OK (`parse-check.ps1`).
