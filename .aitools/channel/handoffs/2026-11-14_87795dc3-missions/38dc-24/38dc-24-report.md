# 38dc-24-report (v1.2): pipefail grep -q race removed; compliance step 7 fails on it

v1.2: re-check (https://github.com/nobul-tech/aitools/pull/168#issuecomment-6887251960, PASS with notes) applied: note 2 now in the rule, its Cursor twin, the step 7 comment and the PR body; notes 3-5 listed under Follow-ups.
v1.1: reviewer 9b19-2 notes 1 and 6 applied (the suite refuses Windows with the POSIX OS guard; the macOS claim is a source reading, not a reproduction); review https://github.com/nobul-tech/aitools/pull/168#issuecomment-6887022744 (PASS with notes).

**Intent**: **Purpose**: record what mission 38dc-24-pipefail-grepq-fix did, how it was verified, and what is still open. **Scope**: PR #168 (branch `fix/38dc-24-pipefail-grepq`). NOT the merge result (in the hand-back to M6-Polish). **Audience**: M6-Polish, the commander.

## Summary

- 49 pipelines ending in `grep -q` in 17 pipefail bash files now end in `grep PATTERN >/dev/null` (same pattern and flags).
- `check-script-compliance.sh` step 7 FAILs with `file:line` on the class in `scripts/*.sh`, `scripts/githooks/*`, `shared/hooks/*.sh`.
- New suite `tests/check-script-compliance/test-step7-grepq.sh` in CI (linux; macos bash 5 and 3.2).
- Docs: reference section "Pipelines into grep -q under pipefail", rule paragraph (+ Cursor twin), post-push checklist step 23, RELEASE_NOTES v0.77.15.
- No incident filed (commander, 2026-11-14: "8) dont file incident, just launch mission to fix this").

## Sites (file: lines, exposure, fix)

Exposure ranked by writer output before the first match. Fix in every row: drop `q` from the flags, add `>/dev/null` (existing `2>/dev/null` kept).

| File | Lines (main 5f962b1) | Exposure |
|------|----------------------|----------|
| scripts/build-deploy.sh | 490 | high: perl writes a whole source file into `grep -qxF "$EMBED_EOF"` |
| scripts/check-pre-commit.sh | 367, 385, 389, 393, 409 | high: perl scan of a hook into `grep -q .` (a race hid a violation) |
| scripts/check-pre-commit.sh | 201, 216, 250 | low: echo of captured text |
| scripts/aitools-dashboard.sh | 281; 357, 370 | high (`ss -tlnp`); low |
| scripts/check-post-push.sh | 425, 444, 581, 587, 665, 698, 700, 701 | low |
| scripts/check-pre-push.sh | 93, 199, 202, 222 | low |
| scripts/check-prereq-detection.sh | 170 | low |
| scripts/aitools-install.sh | 714 | low-medium (installer output) |
| scripts/aitools-lib.sh | 1591, 4154, 4502 | low-medium |
| scripts/githooks/pre-commit | 13 | low |
| scripts/setup-datadog.sh | 57, 61, 185 | medium (brew/winget output, several KB) |
| scripts/setup-gh-cli.sh | 73, 79 | medium |
| scripts/setup-go.sh | 51, 57 | medium |
| scripts/setup-pandoc.sh | 64, 70, 91, 102 | medium |
| scripts/setup-typst.sh | 45, 62, 68 | medium |
| scripts/setup-uv.sh | 30, 36 | medium |
| scripts/setup-vercelcli.sh | 75, 81 | medium |
| shared/hooks/tool-ops-session-audit.sh | 56 | low |

Not changed: `scripts/aitools` 2158, 2179, 2190 (no pipefail).

## Evidence that the fix form is safe on both greps

- GNU grep 3.11 `src/grep.c`: stdout `/dev/null` -> `dev_null_output` -> `done_on_match`; `finalize_input` -> `drain_input` reads the pipe to EOF (38dc-22, PR #164 comment 6884555109).
- BSD grep, Apple `text_cmds` `grep/util.c` `procfile()` (read in a browser 2026-11-14, raw.githubusercontent.com/apple-oss-distributions/text_cmds/main/grep/util.c): `for (lines = 0; lines == 0 || !(lflag || qflag); )` and `procmatches()` stops only for `-m`; `grep/grep.c` has no `/dev/null` handling. So without `-q`/`-l`/`-L`/`-m` it reads to EOF.
- CI run 43658571751 case D: linux GNU grep 3.11, `seq 1 300000 | grep -x 1 >/dev/null` 20/20 exit 0, `grep -qx 1` 20/20 exit 1 (SIGPIPE ignored on the runner, seq exits on EPIPE); macOS BSD grep 2.6.0-FreeBSD, bash 5.3 and 3.2: fix form 20/20 exit 0, `-q` form 0/20 failures. Because the `-q` form never failed on macOS, that run proves nothing about BSD grep: the BSD evidence is the source reading above, not a reproduction (reviewer 9b19-2, note 6).

## Verification

- Counted perl rewrite (refuses to write unless the exact count is made), six batches of 2-3 files, `git diff --numstat` and `bash -n` per batch; it reproduces PR #164's 12 edits byte for byte.
- Hook pre-deploy verification (isolated HOME): smoke and violation cases give the same JSONL line as main's hook.
- Static self-test of step 7's perl: 0 sites on the branch, 62 on pre-#164 main, planted cases pass, no self-flag.
- CI on 0c4ade2 (run 43658571751): linux, macos, windows, CodeQL all pass; compliance `13 PASS, 0 FAIL`, step 7 PASS; the new suite 22/22 on linux, macos bash 5, macos bash 3.2.
- check-pre-commit.ps1 (no -Fix): 0 FAIL. check-pre-push.ps1: 0 FAIL (after rewording a comment its secret scan read as `token:`).

## Delegates

- 9b19-1-step7-grepq: step 7, the suite, CI steps. Verified by reading its full diff and the suite, re-running its self-test, and CI output.
- 9b19-2-review-pr168: independent review, PASS with notes (comment 6887022744); notes 1, 2 and 6 fixed, notes 3-5 optional and left as follow-ups.

## Deviations

- CONFLICT: prompt "be an orchestrator -- batches of 2-3 files per fresh delegate" vs prompt operational learning "a mechanical edit across many files: do it with a counted perl script" -- resolved by tier 2 (both in the prompt), choosing accuracy: one counted rewrite script run by 38dc-24 in 2-3-file batches with verification between them; the non-mechanical work (step 7 and its tests) and the review went to fresh delegates.

## Operational learning

- The class bites in scratch scripts too: `git show ... | perl -ne '... exit'` failed under pipefail (exit 255) because perl exited early. Readers that exit early (`grep -q`, `head`, `grep -m`, perl `exit`) are all the same race.
- On GitHub Actions linux runners SIGPIPE is ignored: the writer exits 1 on EPIPE instead of 141, and the `-q` race is deterministic there (20/20), not rare.
- `gh pr checks --json bucket` polling in a run_in_background script is a clean way to wait for every job.

## Follow-ups (open)

- About 70 `| grep -q` sites in pipefail test suites under `tests/` (out of scope; owner 38dc-13).
- `| head -N` (about 35 sites) and `grep -m` have the same exposure; not checked by step 7.
- Review notes 3-5 (9b19-2, not applied): cite GNU grep NEWS 2.27; list the step 7 regex edge cases (`grep -- -q`, `grep -e -q` false positives; `grep -q"a"`, `grep "-q" a` missed; none in the repo); `packaging/` is outside the scan set, so "the class cannot return" holds for the scan set only.
- `check-script-compliance.ps1` step 7 skip message could say "bash-only; runs in the .sh twin (CI linux job)" (owner 38dc-23).
