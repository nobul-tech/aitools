# S3-MF-Fix5-Review: independent review of PR #112

**Intent**: **Purpose**: An independent verdict on PR #112: is each of the S3-MF-Audit findings A-19, A-20, A-25 and A-26 (claude part) fixed? Does the build-deploy.sh port match the scripts/ source? Do bash and PowerShell behave the same? **Scope**: the PR's own commits (`git diff 547079c db9ddf8`), its tests, and runs I did myself. NOT fixing code. NOT other audit findings. **Audience**: S3-MF-Fix5 (the author), who fixes any blocking findings; Jose, who merges.

Reviewer: S3-MF-Fix5-Review (I wrote none of this code). Reviewed head `db9ddf8` (PR head, confirmed with `gh pr view 112 --json headRefOid`), worktree `.claude/worktrees/mf-fix5-review`, macOS arm64, 2026-10-22. Commits reviewed: `286325e` and `db9ddf8`.

## Verdict

**CHANGES-REQUESTED.** One small blocking finding: B-1. A-19, A-20 and A-25 are fixed. A-26 (claude part) is fixed on every path the audit named. The bash read-failure check this PR adds cannot fire, and the PR body says it does.

## Per-finding status

| id | status | evidence |
|---|---|---|
| A-25 | **fixed** | sh: `setup-user-claude.sh:97` `MACHINE_HOST="${AITLIB_MACHINE_HOSTNAME:-}"`, "unknown" at :98; the scutil/uname copy is gone. ps1: `setup-user-claude.ps1:174-175` `$script:AitLibMachineHostname`, "unknown" fallback; the COMPUTERNAME copy is gone. The lib sets the value on every resolve result that has tags (`aitools-lib.sh:355`, `aitools-lib.ps1:286`), and the resolver writes `hostname` in every `resolve` result, rc 1 included (`aitools-profile.sh:871-883`, `put_head`). One case gives "unknown" where the old code still got a name: "resolver missing" (`aitools-lib.sh:339-342` returns before any tag is read). That case already logs an ERROR row, so this is acceptable (see N-4). |
| A-26 (claude) | **fixed** (see B-1 for the read-failure path) | sh `:219-236` and ps1 `:245-264`: one row each, `dry-run: would create` / `verified` / `dry-run: would update`. The comparison matches the lib: bash `deploy_managed_file` strips trailing CR/LF (`aitools-lib.sh:1913, 1920, 1970`). PS `Deploy-ManagedFile` uses `-replace '[\r\n]+$',''` and `-ceq` (`aitools-lib.ps1:1892, 1903-1904, 1951-1952`). The PR's sh `s/[\r\n]+\z//` and ps1 `-replace '[\r\n]+$',''` + `-ceq` are equivalent. The parity test compares rows between .sh and .ps1 (`test-claude-mdm.sh:178-181`). |
| A-19 | **fixed** | The embed block now ends with `try {` (`build-deploy.sh:616-618`). The three resolver-embedding .ps1 files end with `EMBED_FINALLY_PS1` (`:828, :933, :1278`). `Remove-AitoolsEmbed` runs at most once (`:604-607`). A post-build check fails the build if the finally line is missing or is not the last line, or if any other .ps1 has it (`:2247-2268`). My probes (below) also cover exit 2, a nested-function exit 2 and an uncaught throw, run with `-File` and in-process. All of them clean up and keep the exit code. |
| A-20 | **fixed** | blog_warn/blog_error use colour only when `[ -t 2 ]` (`build-deploy.sh:48-51`). The child resolver's stdout (the lib console, `aitools-lib.sh:682-692`, which writes to stdout) goes to `/dev/null` when stderr is not a terminal (`build-deploy.sh:205-214`), and its stderr is kept. Both entry points run the build with stderr not a terminal: `aitools:2055` (`>> "$LOG_FILE" 2>&1`) and `aitools.ps1:2004` (`2>&1 \| Out-String`). |

**Port (deploy-paths.md):** matches. Generated `setup-user-claude.sh` is a pure extract (`build-deploy.sh:650-731`). In a build from an archive copy of the live dotprofile (525ee49), it holds `MACHINE_HOST="${AITLIB_MACHINE_HOSTNAME:-}"` (generated line 8842) and both dry-run rows (8976, 8980). It has no footer scutil call: the scutil hits at 3267-3589 are the embedded resolver. Generated `setup-user-claude.ps1` holds `$machineHost = [string]$script:AitLibMachineHostname` (8940) and the dry-run rows (9025, 9029). Its only COMPUTERNAME hits are in the embedded resolver (3466-3663).

**Bash/PS parity:** same rows and footer source on the paths the tests cover. Exception: B-1, an unreadable CLAUDE.md in a dry run.

## Findings

### Blocking

**B-1. The bash dry-run read check never fires, and the PR says it does.** Files: `scripts/setup-user-claude.sh:221-224` (new) and `:208` (pre-existing).
- `perl -0777 -pe ... "$CLAUDE_MD"` exits **0** on a file it cannot open. It prints `Can't open ...: Permission denied.` to stderr and continues. Probe: `perl -p on unreadable file: rc=0 stdout=[]`. So the new `if ! _dr_existing=$(perl ...)` branch is dead code. If that line were reached, it would compare "" with the new content and write `dry-run: would update` with no warning: a silent failure on a changed line (USO "No silent failures"; script-standards.md "Error handling requirements").
- The line is never reached on an unreadable file anyway. `:208` `EXISTING_LINES=$(wc -l < "$CLAUDE_MD")` fails under `set -e` first.
- Probe result: bash exits 1 with a raw bash error line (`setup-user-claude.sh: line 208: ...: Permission denied`) and **no claude.md row**. PowerShell, on the same input, logs the LogWarn and writes `WARN|claude.md|dry-run: would update`, exit 0.
- The PR body says "An unreadable CLAUDE.md is now a log_warn / LogWarn in both languages". That is true for the .ps1 only.

Suggested fix, both in the dry-run branch:
- Guard `:208` the same way. For example: `if [ -r "$CLAUDE_MD" ]; then EXISTING_LINES=$(wc -l < "$CLAUDE_MD"); fi`, or put it in an `if !` with a detail line.
- Read with a perl that fails on open:
  `if ! _dr_existing=$(perl -0777 -e 'open(my $f, "<", $ARGV[0]) or die "$!\n"; local $/; my $c = <$f>; $c =~ s/[\r\n]+\z//; print $c' "$CLAUDE_MD" 2>&1); then log_warn "Cannot read ... for the dry-run comparison: $_dr_existing"; _dr_existing=""; fi`
  Or test `[ -r "$CLAUDE_MD" ]` first.
- Then add a test case with `chmod 000` on `~/.claude/CLAUDE.md` plus a dry run, asserting the row and the warn in both languages (the ps1 already passes it).
- Optional, ps1 `:233`: `(Get-Content $claudeMd).Count` has no `-ErrorAction`. It prints a host error before the guarded read. This is pre-existing, and the row is still written.

### Non-blocking

- **N-1. The test writes to the caller's real log directory.** `tests/claude-mdm/test-claude-mdm.sh:107` runs `aitools-profile.sh hostname` with the caller's HOME and AITOOLS_LOG_DIR. The resolver calls `logging_init` (`aitools-profile.sh:79`), so each run appends to the real `~/.aitools/logs/deploy.log`. I confirmed it: my isolated log dir has 2 `[aitools-profile]` lines after 2 runs. The header (`:18-19`) says "never the real HOME". Fix: run that line with `HOME="$TMP_ROOT/home-host" AITOOLS_LOG_DIR="$TMP_ROOT/home-host/logs"`.
- **N-2. The PR body still has a placeholder.** Under "Existing suites": "(results added when the local run completes)". Fill it in. My own results are below.
- **N-3. `_a19_static` is a weak check.** `test-claude-mdm.sh:211-223` checks `n_try -ge 1`, and every generated .ps1 has several column-0 `try {` lines from the inlined lib (claude 6, cursor 4, settings 4). The build's own check (`build-deploy.sh:2247-2268`) plus the pwsh parser check (`:234`) are what actually protect the structure. Optional: assert that the line after `# --- End of embedded profile resolver ---` (skipping its two comment lines) is `try {`.
- **N-4. A-25 corner case.** On "resolver missing" (`aitools-lib.sh:339-342`) the footer now says "unknown" where the old code still got scutil/COMPUTERNAME. This is by design (one P-Q5 source), and that path already writes `ERROR|machine profile|resolver missing`. No change needed. Mention it in the PR body if you want it recorded.
- **N-5. A warning in `finally` comes too late for the exit code.** On an early exit, `Remove-AitoolsEmbed` runs in `finally`, after the exit code has already been set. A failed removal there increments `$warnings` and logs a LogWarn, but the exit code and summary panel do not reflect it. That is acceptable (the exit was already chosen), but the comment at `build-deploy.sh:559-560` ("a failed removal is a counted warning") is only true for the call before the footer. Optional: reword the comment.
- **N-6.** The explicit `Remove-AitoolsEmbed` before `exit 1` in the generated claude .ps1 (`build-deploy.sh:779`) is now redundant (the flag makes it harmless). You can keep it or drop it.

## Commands run and results

All runs used an isolated HOME and AITOOLS_LOG_DIR under `.scratch/session-mf5rev/`, with cwd in scratch. The live dotprofile was only read, through `git archive`. Scripts: `.scratch/session-mf5rev/{run-tests,run-build,probe-a19,probe-a20,probe-a26,neg-control}.sh`.

| command | result |
|---|---|
| `bash tests/claude-mdm/test-claude-mdm.sh` (GNU bash 5.3.15, pwsh 7.6.3) | 32 passed, 0 failed, 0 skipped |
| `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/claude-mdm/test-claude-mdm.sh` (bash 3.2.57) | 32 passed, 0 failed, 0 skipped |
| `bash tests/managed-files/test-managed-files.sh` | 57 passed, 0 failed, 0 skipped |
| `bash -n` (bash 5 and /bin/bash 3.2) on setup-user-claude.sh, build-deploy.sh, test-claude-mdm.sh | all 0 |
| pwsh `Parser::ParseFile` on scripts/setup-user-claude.ps1 | clean |
| Negative control: the new test run against a `git archive 547079c` tree | 9 passed, 23 failed (matches the PR body's "fails 23 checks") |
| `build-deploy.sh` with `AITOOLS_USER_REPO_PATH` = archive copy of aitools-nobul-jose@525ee49, stderr to a file | exit 0; 0 ESC bytes in the output; no warn/error lines |
| Generated claude/cursor/settings .ps1 | last non-blank line is `} finally { Remove-AitoolsEmbed } ...`, finally count 1 each; every line CRLF (0 LF-only lines, so the mixed-ending note in the PR is resolved by the CRLF pass); pwsh parser clean on all three; every other deploy/*.ps1 has 0 finally lines |
| **Probe A-19** (not in the PR tests): copies of generated setup-user-claude.ps1 and setup-user-settings.ps1, OS guard off, a probe line after `Initialize-Logging` (inside the try): `exit 2`, `throw`, and `exit 2` inside a function | `-File`: rc 2 / 1 / 2. In-process (`& script` inside try/catch): LASTEXIT 2, throw caught, LASTEXIT 2. `ENV-RESTORED` and 0 `aitools-embed-*` left in TMPDIR in all 12 runs |
| **Probe A-20** (not in the PR tests), with macOS `script(1)` for a pty and the child resolver stubbed to fail. Case 1: stderr is the terminal, stdout a file. Case 2: stderr a file, stdout the terminal | Case 1: stdout file has 0 ESC; the terminal shows the coloured warn and the child's error line. Case 2: stderr file has 0 ESC and no child line, and the warn is plain. deploy.log has the child's error line once per run, 0 ESC. Build exit 0 in both cases |
| **Probe A-26** (not in the PR tests): dry run with `chmod 000 ~/.claude/CLAUDE.md` | sh: exit 1 at line 208, no claude.md row. ps1: LogWarn plus `WARN\|claude.md\|dry-run: would update`, exit 0. `perl -p` on an unopenable file: rc 0. See **B-1** |
| `gh pr checks 112` | windows pass; macos and linux **pending** at review time (result unknown); CodeQL pass |

## Not run

- Windows / Git Bash. Every .ps1 ran under pwsh 7.6.3 on macOS, with the OS guard disabled in copies; the generated ones as built hit their early exit.
- check-pre-commit.sh / check-pre-push.sh (review only, no commit).
- tests/profile/* suites (the PR does not touch the lib or the resolver).
- The macOS and Linux CI jobs had not finished.
- Regenerating the live dotprofile `deploy/`: by design, it was not touched.

## INCIDENT markers (not filed)

- `INCIDENT:` `.claude/rules/deploy-paths.md` "Scripts with deploy templates" still lists `setup-user-claude.sh/.ps1` as having duplicated "Template interpolation, footer generation" in build-deploy. `build-deploy.sh:650-651` says it is now a pure extract ("no duplicated logic, I6"), and the generated output confirms it. The rule is stale (protected file; this is spec drift and predates this PR). An agent following the rule would look for a template copy that no longer exists.
