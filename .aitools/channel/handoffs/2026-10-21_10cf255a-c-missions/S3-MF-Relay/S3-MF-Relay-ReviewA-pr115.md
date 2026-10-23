**Verdict: approve with minors** -- 0 B, 0 M, 1 m, 4 n. The PR fixes A-2, A-3 and the `run_child_relayed` part of A-4 as the audit describes. Rows, messages and counters are the same in bash and PowerShell, and the change is bash 3.2 safe. The one minor is a gap in the tests, not in the code.

# S3-MF-Relay-ReviewA: independent review of PR #115 (`fix/mf-lib-relay`)

Reviewer: S3-MF-Relay-ReviewA (independent; I wrote none of this code). I reviewed `origin/fix/mf-lib-runner-result..origin/fix/mf-lib-relay` (commit 4c55ec0): scripts/aitools-lib.sh, scripts/aitools-lib.ps1, tests/profile/test-lib.sh. The yardstick was the S3-MF-Audit findings (A-2, A-3, A-4, section 1) and the rules in the SC mission packet. I worked in a detached worktree at 4c55ec0 with an isolated HOME and AITOOLS_LOG_DIR under its scratch, on macOS arm64.

## Findings by audit item

**A-2 (resolver missing: no ACTION). Fixed in both languages.**
- lib.sh:371-376 and lib.ps1:288-293 now call `_aitlib_action_once` / `Write-AitLibActionOnce` with the dotprofile wrapper's text (lib.sh:324).
- When both wrappers fail in one run, the run summary gets one ACTION. Test `urp-rmp-missing` checks this and passes in both shells.

**A-3 (failed child: no summary row). Fixed.**
- Bash takes the optional leading `--summary-tool TOOL` (lib.sh:663-675). PS keeps its 4th parameter.
- With a tool, every failure path writes one row unless the child wrote an ERROR row of its own: non-zero exit, exit 2, error lines with exit 0, no command, mktemp failure (bash) and throw or parse error (PS). The code is at lib.sh:676-708 and lib.ps1:565-596.
- I ran the probes in `probe-relay.sh` (results below). They confirm the same rows and `errors=1` in both languages.
- One LogError per failed child still holds. In every relay case of the suite and of my probes, the parent ends with `errors=1`.

**A-4 (unchecked `rm -f "$rcf"`). Fixed.**
- `_aitlib_rm_tmp "$rcf" "$label"` (lib.sh:694) writes a detail line, not a warning, so D-TS12 holds.
- The default WHO keeps #113's messages unchanged (lib.sh:155-158).

**Checks with no finding**
- **Dynamic scope.** The new locals in the in-process PS relay carry the prefix (`$AitLibErrRows`, `$AitLibDetail`). `Write-AitLibChildRow` and `Get-AitLibSummaryErrorCount` run only before or after the child, so their unprefixed parameters cannot leak into it. The leak check in the test child covers the unprefixed names (test-lib.sh:717).
- **`LogDetail` and return values.** `LogDetail` writes nothing to the pipeline (lib.ps1:668-672), so `return 0` after it in `Get-AitLibSummaryErrorCount` returns a scalar.
- **`set -u` and bash 3.2.** `printf -v` needs bash 3.1 or later. Every `local` is assigned before it is read. `bash -n` is clean under 5.3 and /bin/bash 3.2.57, and test-lib passes 156/0 under 3.2.
- **Suppressions.** `rc="$(cat "$rcf")" || rc=""` is now commented and checked by the `case` that follows. An unreadable summary is a detail line in both languages.
- **Existing callers.** There are none: `git grep` finds no caller of `run_child_relayed` / `Invoke-ChildRelayed` outside the lib and the tests, as audit A-1 says. Calls without a tool behave as before. The exception is PS with an empty SCRIPT: it now gives `not run (no command given)` instead of a throw, which matches bash.
- **Comments.** They match the code. I checked the section comments at lib.sh:520-525 / lib.ps1:438-443 and the function headers.

## Assumptions (the PR's design choices)

- **Dedupe on "any ERROR row written during the child": agree.**
  - A-3's gap is a child that wrote no row. Without the dedupe, every well-behaved failing child would show two ERROR rows.
  - Matching on TOOL would not work: children name their rows after their own items (`profile.json`, `machine profile`), not after the caller's tool.
  - The cost is n1 below.
- **Exit 2 is the row `aborted (exit 2)`, still ERROR and still one counted error: agree.**
  - D-TS13 defines a bare exit 2 as a user abort.
  - interactive-menus.md "Abort" says `[x]abort` logs an error, so ERROR is the consistent category.
  - `AITLIB_CHILD_RC` / `$script:AitLibChildRc` still lets a caller tell an abort from a failure.
- **deploy.jsonl scope left alone: agree.** It is I-1, undecided, and belongs to FIX-2.

## Findings

### m1 -- the tests never exercise the "before" count (tests/profile/test-lib.sh:816; lib.sh:643, lib.ps1:544)

**Evidence**
- `relay_case` truncates the summary before every case (`: > "$H/summary.txt"`, test-lib.sh:816).
- I made a mutant lib that compares the after-count with 0 instead of BEFORE: lib.sh `-gt "$2"` became `-gt 0`, and lib.ps1 `-gt $Before` became `-gt 0` (script `negctl.sh`).
- The mutant still passes the new test-lib, **353 passed, 0 failed**. In real runs it would drop the relay row for every crashed child that runs after any earlier failed step, because the summary already holds an ERROR row by then.
- The real lib handles this correctly. My probe P1 seeds `ERROR|earlier step|failed before`, runs a crashing child, and gets both rows in bash and in PS.

**Fix:** add one case that seeds an ERROR row before a crashing child (CHILD_FAIL=3) and expects both rows. For example, give `relay_case` an optional seed argument.

### n1 -- an earlier ERROR row from the child hides its later crash in the panel (design consequence)

**Evidence**
- Probe P2: the child writes `ERROR|other tool|x`, then exits 127.
- In both languages the summary holds only `ERROR|other tool|x`. The crash appears only as the parent's log_error in deploy.log.

**Suggestion:** this is acceptable under the stated rule. Say it in the section comment ("...gets no second one, even when it failed for another reason"), so FIX-2 callers know.

### n2 -- the exit-2 log line still says "failed" (lib.sh:700, lib.ps1:585)

**Evidence:** the row says `aborted (exit 2)`, but the parent's error line says `<label> failed (exit 2)`.

**Suggestion:** use the same word in the log line, in both languages, for consistency with D-TS13. No behaviour change.

### n3 -- `relay-run-rm-fail` assumes a non-root user (test-lib.sh:902-909)

**Evidence:** the test relies on `chmod 555` making `rm -f` fail. Run as root, the removal succeeds and the detail-line assertion fails. The Claude Code web environment runs as root (managed-file-deployment.md, the settings.json hook path `/root/...`).

**Fix:** skip the case, with a note, when `id -u` is 0.

### n4 -- `_aitlib_summary_errors VAR` cannot set a variable named after its own locals (lib.sh:622-634)

**Evidence:** `printf -v "$1"` would assign the helper's local if a caller passed `_aitlib_se_n`, `_aitlib_se_l` or `_aitlib_se_f`. Today's two callers pass `errs0` and `_aitlib_cr_now`, so this is not a live bug.

**Suggestion:** a one-line comment noting the reserved names, or leave it as is.

## Verification

### Commands and results

- `bash -n` (GNU bash 5.3 and /bin/bash 3.2.57) on aitools-lib.sh and test-lib.sh: clean. pwsh `Parser::ParseFile` on aitools-lib.ps1: clean.
- The suites, each with bash 5 + pwsh and with `AITOOLS_TEST_BASH=/bin/bash /bin/bash ... --bash-only`, from a scratch cwd, isolated HOME and AITOOLS_LOG_DIR:

  | Suite | bash 5 + pwsh | /bin/bash 3.2 |
  |---|---|---|
  | test-lib | 353/0 | 156/0 |
  | test-user-init | 229/0 | 128/0 |
  | test-config | 269/0 | 174/0 |
  | test-profile | 689/0 | 498/0 |

  These match the PR's table.

### Negative controls

- The new test-lib against the pre-fix lib (`git archive origin/fix/mf-lib-runner-result scripts`): 316 passed, **37 failed**, which matches the PR's claim.
- The new test-lib against the mutant lib: 353 passed, **0 failed** (m1).

### Reviewer probes (`probe-relay.sh`, bash and PS)

| Probe | Setup | Result in both languages |
|---|---|---|
| P1 | summary seeded with an ERROR row, then a crashing child | seed row + `ERROR\|relay tool\|script failed (exit 1)`, `errors=1` |
| P2 | child writes its own row, then exits 127 | only the child's row (n1) |
| P3 | `--summary-tool ""` / an empty 4th parameter | no row, `rc=1 errors=1` |

### CI and what was not run

- CI at review time: windows pass, CodeQL pass, linux and macos pending.
- Not run: Windows and Git Bash locally, check-pre-commit and check-pre-push, build-deploy.sh.

INCIDENT: (none new.)
