## Independent review: S3-DiffUX-Review (delegated by S3-DiffUX)

**Verdict: request changes.** There is one blocking finding, and the fix is one line. Apart from that, the display change is correct, bash and PS1 match, and the tests are good. All evidence comes from runs on macOS arm64 against `aefa3b5`.

### Blocking

**B1. In bash, a review diff over about 64 KB aborts the whole setup run with no ERROR row.** The line is `scripts/aitools-lib.sh`, `prompt_diff_review`, new line 1185:

```bash
shown=$(printf '%s\n' "$REVIEW_DIFF" | head -n 30)
```

`head` exits after 30 lines. Any diff that does not fit in the pipe buffer then makes `printf` fail with EPIPE or SIGPIPE. Under `set -euo pipefail`, which every caller has (`setup-user-skills.sh:109`, `setup-user-claude.sh:208/307`, `setup-user-hooks.sh:166`), the failed assignment exits the script. The menu never appears, no ERROR row is written, and the remaining files are not deployed. That breaks "no silent failures" (script-standards.md, "Error handling requirements") and "`failed` is an ERROR row and the run continues" (managed-file-deployment.md rule, "Shared requirements" 4).

How I reproduced it: `deploy_managed_file` on a pty (`tests/managed-files/pty-run.py`), `/bin/bash` 3.2.57, isolated HOME, LOCAL and SOURCE N lines each with every line different:

| N lines (LOCAL bytes) | PR `aefa3b5` | origin/main lib |
|---|---|---|
| 500 (27,892) | menu shown, `skipped` | not run |
| 600 (33,492) | **abort**: `aitools-lib.sh: line 1185: printf: write error: Broken pipe`. deploy.log has only the platform `[detail]` line | menu shown, `skipped` |
| 3000 | not run | **abort** at main's old `printf ... \| head -30` (line 1096) |

The bug already exists on main, but main only hits it at a larger size. This PR rewrote these exact lines and lowered the threshold to about 64 KB of diff. That is a wholesale change to a file of roughly 30 KB or more. `shared/skills/handoff/SKILL.md` is already 27 KB.

Suggested fix (tested): perl reads all its input, so the writer never gets SIGPIPE.
```bash
shown=$(printf '%s\n' "$REVIEW_DIFF" | perl -ne 'print if $. <= 30')
```
I ran this 5 times under `/bin/bash` 3.2 `set -euo pipefail` on 1.2 MB of input. All 5 runs passed, 30 lines each time. Please add a test case "display, diff over 64 KB: menu shown", for example 1500 changed lines. PS1 has no pipe there and is not affected.

### Non-blocking

- **N1 (low): git config and the environment can still change the hunks.** `_review_diff` / `Get-ReviewDiff`. I probed each setting with an isolated `GIT_CONFIG_GLOBAL`:
  - `diff.suppressBlankEmpty=true` makes blank context lines print as `""` instead of `" "`.
  - `diff.interHunkContext=10` merges the hunks.
  - `GIT_DIFF_OPTS=--unified=0` overrides `-U3`, so you get zero context lines.
  - Not affected: `core.autocrlf=true`, and a `TMPDIR` path containing spaces.

  bash and PS1 stayed identical in every probe, because both read the same config on one machine. The reference doc's line "the same command, so bash and PS1 print identical hunks" only holds when both machines have the same git config. Suggestion: add `-c diff.suppressBlankEmpty=false -c diff.interHunkContext=0`, and unset `GIT_DIFF_OPTS` for the call. Or set `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`. Either way, keep `--no-ext-diff`.
- **N2 (low): content git treats as binary shows the wrong message.** When a file contains a NUL byte, git prints `Binary files ... differ` and no `@@`. PS1 then prints `(whitespace-only differences)`. bash prints a text diff instead, because `$(cat)` drops the NUL. Managed files are text, so this is unlikely. Adding `--text` (`-a`) to both calls would remove the case.
- **N3 (low): an empty LOCAL file shows a phantom `-` line.** `printf '%s\n' ""` and `"" + "\n"` each write one blank line, so the diff shows `-` followed by the `+` lines. bash and PS1 match. This is cosmetic.
- **N4 (info): no test runs both languages and compares their output.** The PR body reports a manual parity check. A test that runs the same case through bash and PS1 and compares the plain text, from the legend to the prompt, would turn that into a regression guard.
- **N5 (info): the test suite runs on bash 5 by default.** On this machine the `bash` on PATH is 5.3.15. I re-ran the suite with `/bin/bash` 3.2.57 first on PATH and got 55/55, which matches the PR body.

### The author's choice to leave the AI merge input unchanged

I agree with keeping it out of this PR. Today the AI merge input runs SOURCE -> LOCAL: bash uses `diff -u source local` and PS1 a `Compare-Object` listing. But `_ai_prompt_merge` / its PS1 twin call that input "unified diff: local vs source" and say "Apply ONLY the changes shown in the diff" to LOCAL (`aitools-lib.sh` line 663/673, `aitools-lib.ps1` line 669/679). So the prompt contradicts its own input, and PS1's listing is not a unified diff. Fixing that changes what the AI receives, and agentic-standards.md "Prompt evaluation" requires re-testing a prompt before it ships. That is a separate PR. The new `REVIEW_DIFF` (LOCAL -> SOURCE) already matches the prompt's wording, so the follow-up the PR body proposes is the right fix. It should be filed, not left as a note.

### What I checked and found correct

- The spec text matches the launch prompt byte for byte: the headers `--- this machine  ` / `+++ repo          `, the legend, the five menu lines, and the truncation rule (more than 40 lines shows 30, with the full diff in deploy.log).
- Error handling:
  - git exit codes above 1 are caught in both libraries.
  - PS1 catches a missing git through `Process.Start` and its catch block.
  - PS1 reads stderr asynchronously, so it cannot deadlock.
  - The cleanup line `Remove-Item -ErrorAction SilentlyContinue` carries the repo's established `# ErrorAction exempt` comment.
  - bash creates the temp files from `mktemp` and checks the writes.
- PS1 encoding: git's output is read as UTF-8 from `StandardOutput`, not through the pipeline (interactive-menus.md, "Encoding").
- PS1 arrays: `@()` wrapping, and the `$all[0..29]` slice can never be a single element (there are at least 3 lines).
- Labels: `display_path` is a no-op off MSYS, so PS1's raw paths match bash on macOS and Linux.
- bash 3.2: `/bin/bash -n scripts/aitools-lib.sh` is clean, and the full suite passes under 3.2.57.
- Input edge cases, bash and PS1 byte-identical: `%` in content, `---`/`+++`/`@@` lines inside the content, and trailing blank lines.

### Test results

- `bash tests/managed-files/test-managed-files.sh` (bash 5.3.15): 55 passed, 0 failed.
- The same suite with `/bin/bash` 3.2.57 first on PATH: 55 passed, 0 failed.
- `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`: 37 passed, 0 failed.
- `/bin/bash -n scripts/aitools-lib.sh`: clean.
- Probe scripts (in the reviewer's scratch, not committed): `probe.sh`/`probe.ps1` (edge cases × git configs), `e2e-big.sh`/`e2e-big-main.sh` (the B1 reproduction), `sigpipe.sh` (the fix check).

Not run: Windows, check-pre-commit, and check-pre-push. I am a read-only reviewer.
