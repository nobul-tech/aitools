## S3-M3-Install-Review: independent review of #79 at 69b6420

**Verdict: changes requested. 0 blockers, 1 major, 3 minors, 3 nits.**

Posted as a comment: GitHub refused `--request-changes` ("Can not request changes on your own pull request"). Treat this review as a change request.

The Review3 fixes m1, m3, m4 and m5 hold. The m2 fix counts the writer's warnings, but it counts one too many, and the new test asserts the wrong number.

**What I reviewed**
- The diff of 69b6420, read against the full files: `scripts/aitools-install.sh/.ps1`, `scripts/setup-user-config.sh/.ps1` and `tests/profile/test-config.sh`.
- Probes ran under scratch HOMEs (`.scratch/session-InstRev/` in worktree m3inst). Nothing touched the real HOME.

### Major

**M1. The writer's warnings are counted one too many. The test asserts the inflated count.**
- **Cause.**
  - Both relays count every `[warn]` line as one installer warning (aitools-install.sh:162, aitools-install.ps1:88).
  - The writer's footer line `COMPLETED with N warning(s)` is itself logged at level `warn` (setup-user-config.sh:332, .ps1:324).
  - So a writer that warns N times adds N+1 to the installer's WARNINGS.
- **Probe (`probe-count.sh`).** The fixture is a hostname-only profile, the same shape as C13. The writer logs exactly one real warning:
  ```
  [setup-user-config] [warn] config: matched by hostname only (legacy) -- run: aitools user init (registers machine.id)
  [setup-user-config] [warn] COMPLETED with 1 warning(s)
  COUNTS errors=0 warnings=2        (bash and PowerShell)
  ```
  The synthetic relay probe (`probe-bash.sh` P2) and the PowerShell child probe (`probe-ps.ps1` C) give the same +1.
- **Why the test passes.** test-config.sh:367 compares the installer's count with the number of writer `warn` records in deploy.jsonl. That number includes the footer record, so both sides carry the same +1.
- **Impact.**
  - The installer's footer reports the wrong count.
  - The PR's Follow-ups section tells deploy-harness to copy this relay, so the bug would spread to the second caller.
- **Suggested fix.**
  - Do not count the child's footer. Skip lines whose message matches `^(COMPLETED|FAILED) with ` in both relays. The alternative is to take N from the footer instead of counting lines.
  - Change the test to compare with the writer's own count: the N in its `COMPLETED with N warning(s)` line, or a fixture with a known count.

### Minor

**m1. The bash `jsonl_write` escapes only backslash, quote, tab and CR.**
- **Problem.** Any other control character (U+0000 to U+001F, including ESC and newline) produces an invalid JSONL line. PowerShell's `ConvertTo-Json` escapes all of them, so the two installers differ.
- **Probe (`probe-bash.sh` P1, same under bash 5.3.15 and 3.2.57).**
  ```
  VALID   : quote " back \ tab	end
  INVALID : {..."msg":"ctl <01>x esc <1b>[31m bs <08> ff <0c>"}
  INVALID : {..."msg":"nl1        <- a newline splits the record
  INVALID : nl2"}
  ```
  The PowerShell run of the same input is valid (`probe-ps.ps1`, "jsonl escaping").
- **Likelihood.** Low today: relayed lines are split per line, and the colour codes are stripped. But the commit message calls the function "JSON-escapes the message".
- **Suggested fix.** Map `\n` to `\\n`, then strip the rest with `m="${m//[[:cntrl:]]/}"`. Check that under bash 3.2.

**m2. `absolute_repos_path` does not normalise, so the m3 regression comes back when the working directory is `/`.**
- **Problem.** The function builds `printf '%s/%s' "$PWD" ...` (aitools-install.sh:186).
  - With PWD=/ a relative answer becomes `//repos`. The writer's double-slash check rejects that, and config.json is not written.
  - `../repos` stays as `/x/../repos`, while PowerShell's `GetFullPath` normalises it to `/repos`. The two installers store different values.
- **Probe (`probe-bash.sh` P4).**
  ```
  [repos] -> [//repos]   [../repos] -> [//../repos]   [a//b] -> [//a//b]
  writer --repos-path //repos: ERROR|aitools config|validation failed, exit 1
  PowerShell at /: [repos] -> [/repos]  [../repos] -> [/repos]  [a//b] -> [/a/b]
  ```
- **Likelihood.** A run from `/` is plausible under launchd or MDM, or after `cd /`.
- **Suggested fix.** Use `${PWD%/}` at minimum. Better: run `mkdir -p` first, then `REPOS_PATH=$(cd "$REPOS_PATH" && pwd -L)`, which normalises the same way GetFullPath does.

**m3. The relay helpers exist only inside the two installers, but deploy-harness is told to relay "the way run_config_writer / Invoke-ConfigWriter do".**
- **Problem.** The commander's requirement is that deploy-harness calls setup-user-config as the single non-interactive writer. That caller would need a third copy of this block, M1 included.
- **Suggested fix.** Move `jsonl_write` / `relay_child_log` (and the PowerShell pair) to aitools-lib once #80 merges (#80 owns the lib), or name that move in Follow-ups.

### Nit

1. **The dry-run wording is too strong.**
   - Where: the PR body ("A dry run writes nothing under `~/.aitools`"), the commit message ("including the directory itself") and the writer headers.
   - What happens: with the default log dir, a dry run on an empty HOME creates `~/.aitools/logs/deploy.log`, and so `~/.aitools` too. The headers do say "deploy.log still records the run".
   - Probe: `probe-dry.sh` lists `.aitools/logs/deploy.log` as the only file in both shells.
   - Suggested wording: "nothing except deploy.log".
2. **The bash relay buffers output.** `out=$(bash "$writer" ...)` prints nothing until the writer exits; PowerShell streams. The writer is fast, so this is cosmetic.
3. **The bash 3.2 test run does not run the writer under 3.2.** Under `AITOOLS_TEST_BASH=/bin/bash`, the installer-helper cases run the harness under 3.2, but `run_config_writer` calls `bash` from PATH, so the writer runs under bash 5. The writer's own 3.2 coverage comes from the earlier cases.

### Checked and fine
- **m1 (JSONL).**
  - Every structured writer line reaches deploy.jsonl with the writer's own ts, script and level.
  - Non-log lines are printed but not mirrored or counted.
  - Colour codes are stripped before matching (`probe-bash.sh` P2).
- **m2.** Warnings are relayed and counted in both shells; see M1 for the +1.
- **m3.**
  - A relative answer from the flag, the prompt or an old config value becomes absolute when the current directory is not `/`.
  - The writer's guard against relative paths stays (C14).
  - A failing writer counts as exactly 1 installer error, and its ERROR row is kept.
- **m4.** The comment says the function stays in the installers. In bash it sits directly above `validate_json_config` (sh:245-251, ps1:177-183).
- **m5.**
  - No `config.json.tmp.<pid>` is written beside config.json.
  - The bash temp dir and the PowerShell temp file are cleaned up: TMPDIR was empty after both runs (`probe-dry.sh`).
  - C8b (`~/.aitools` read-only) passes.
- **PowerShell `6>&1` in-process (`probe-ps.ps1`).**
  - `$LASTEXITCODE` after the pipeline is correct: a child that exits 1 gives 1. A child that ran a failing external command and then exited 0 gives 0.
  - On a throw, the lines before it are relayed, not lost. The ERROR row `script failed (exception)` and 1 error are recorded.
  - A child that ends without `exit` returns the last external exit code (5 in probe D). This is the same as Invoke-ValidatedScript, and the writer always exits explicitly.
- **Writer audit fixes.** The `mktemp -d` check, the `mkdir -p ~/.aitools` check (both shells) and the single perl call with its exit code checked are correct.
- **Interface table.** Arguments, environment variables, summary rows (including the OK to WARN promotion in `write_summary`), exit codes (0/1, never 2) and "never prompts" all match the code. The one exception is the dry-run wording (Nit 1).
- **bash 3.2.** The helper block behaves identically under /bin/bash 3.2.57 (`probe-bash.sh` run with `BASHX=/bin/bash`).

### Tests run (HOME, AITOOLS_LOG_DIR and AITOOLS_SUMMARY_FILE in scratch)

| Run | Result |
|---|---|
| `tests/profile/test-config.sh` (bash 5 + pwsh) | 112 passed, 0 failed |
| `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-config.sh --bash-only` | 67 passed, 0 failed |
| `tests/logging/test-logging.sh` (bash 5 / bash 3.2) | 24/0, 24/0 |
| `tests/logging/test-logging.ps1` | 15 passed, 0 failed, 5 skipped |
| `bash -n` and `/bin/bash -n` (both .sh files and the test); pwsh parser (both .ps1 files) | clean |

### Not run
- The full installer (incident #89).
- Windows.
- The Git Bash forwarding path.
- check-pre-commit and check-pre-push.
