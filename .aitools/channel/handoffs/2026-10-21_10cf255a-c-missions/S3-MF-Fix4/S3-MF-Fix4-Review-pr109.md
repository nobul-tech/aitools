# S3-MF-Fix4-Review: PR #109 review

**Intent**: **Purpose**: An independent verdict on PR #109 (fix/mf-audit-consumers): are audit findings A-22, A-23, A-24 and the cursor part of A-26 fixed, is bash/PS1 parity kept, did nothing else change behaviour, and do the tests pass. **Scope**: The diff origin/main...origin/fix/mf-audit-consumers at e9fd2ae, read against S3-MF-Audit-findings.md sections 7, 8 and 10. NOT other audit findings. NOT fixes. **Audience**: S3-MF-Fix4 (author), Jose.

Reviewer: S3-MF-Fix4-Review (independent; wrote none of this code). Review worktree: `.claude/worktrees/mf-fix4-review` (detached at origin/fix/mf-audit-consumers, e9fd2ae). Date: 2026-10-22. Line numbers are at e9fd2ae unless marked "main".

## Verdict

**APPROVE-equivalent.** No blocking findings. All four findings are fixed in both languages. Parity holds row for row, and the negative control shows the new test catches every finding. The non-blocking notes below can ship as follow-ups.

## Per-finding status

| finding | status | evidence |
|---|---|---|
| A-22 skills rc 3 parity | **Fixed** | skills.ps1:48-54 now writes the same `LogError` text and the same two rows as skills.sh:55-61 (`ERROR\|claude skills\|not deployed: dotprofile error`, `ERROR\|cursor skills\|not deployed: dotprofile error`). The non-canonical `skills` tool and the word "skipped" are gone. Discovery is gated in the same way: ps1:69-71 matches sh:74-76. The "no skills found" guard (ps1:87 / sh:97) and the reverse-discovery guard (ps1:179) also match. The ungated dotprofile-skills loop (ps1:79-85 / sh:84-95) does nothing on rc 3, because both libs clear the path and set it only on rc 0 (lib.sh:287, 299 / lib.ps1:219, 229). |
| A-23 cursor rc 3 counted | **Fixed** | cursor.sh:354-359 / cursor.ps1:273-278 now `log_error`/`LogError` "Dotprofile unresolved (resolver error above) -- <cli-config> not merged, so defaults cannot replace the profile preferences" and write `ERROR\|cursor cli\|not merged: dotprofile error`. This now has the same shape as settings.sh:72-75 ("Counted (S3-M3Lead decision)") and skills. I-4 is still undecided; the three consumers are now consistent with each other, so a different I-4 answer changes three places at once (as the PR body says). |
| A-24 check-lib rc 3 | **Fixed** | check-lib.sh:168-191 / check-lib.ps1:174-198 keep the rc (`USER_REPO_RC` / `$script:UserRepoRc`). `print_summary` / `PrintSummary` call the WARN-step helper first (sh:130 / ps1:130). It uses `step_warn`/`StepWarn`, so it is counted and written to checks.log and checks.jsonl (sh:71-84). The helper defaults to 0 when `resolve_config` never ran (sh:187 `${USER_REPO_RC:-0}`; ps1:174 sets 0 at dot-source), so check-script-compliance, which calls print_summary without resolve_config, is unaffected. Each check script calls print_summary once per run (check-pre-push.sh:41 is followed by `exit 0`). Exit codes do not change: they depend on FAIL_COUNT (check-pre-commit.sh:502). |
| A-26 cursor part (dry-run rows) | **Fixed** | cursor.sh:350-353 adds `OK\|cursor cli\|dry-run: would update` for `would-merge`; `unchanged` already wrote `verified` (sh:336-339). cursor.ps1:289-298 now writes both rows with the same mapping: unchanged and not corrupt gives verified, anything else gives would update. This matches the node test `before === after && !corrupt` (sh:290). The claude part of A-26 belongs to FIX-5 and is correctly left out. |

## Parity (line by line)

- **skills .sh vs .ps1** (rc 3 block, discovery gate, warn guard): same message text, same rows in the same order, same gating. Only the path separator in the "No skills found" message differs (`shared/skills/` vs `shared\skills\`), and that is pre-existing.
- **cursor .sh vs .ps1** (rc 3 and dry run): same rows, row order, levels and STATUS text. On rc 3 both branches take precedence over the dry run (node exits at sh:216-219 before the dryRun branch; ps1:273 is checked before ps1:279). On rc 3 both still back up the file and create `~/.cursor` first (sh:178-182 / ps1:209-219), the same in both and pre-existing. See n-1 for the message path form.
- **check-lib .sh vs .ps1**: same step number, label, detail and log text. The test asserts identical console output and checks.jsonl content for both.

## Behaviour outside the findings

Nothing else changed. The diff touches only the four regions above plus comments (`git diff --stat`: 5 scripts plus 1 new test). Exit codes are unchanged on every path: rc 3 already exited 1 through the lib's `log_error`, and the cursor rc 3 path now counts 2 errors instead of 1. The renamed PS variable (`$skillsSkipped` to `$skillsBlocked`) has no other references (grep over scripts/, tests/, reference/ and .claude/rules/ finds no leftover `skillsSkipped` or "skipped (dotprofile" text).

**build-deploy.sh: no port needed.** The cursor body is extracted whole (build-deploy.sh:835-866, 876-907). Only the two default lines inside the profile-preferences block are substituted (:838-841, :879-882), and the changed lines are outside that block (cursor.sh:211-234 / ps1:173-206). The skills rc 3 block is inside the "skill discovery" region (skills.sh:38-237 / ps1:31-222), which build-deploy replaces with embedded skills (:1265-1266, :1363-1364), so deploy/ has no copy of it. The dotprofile `deploy/` setup-user-cursor copies stay stale until they are regenerated (PR follow-up).

## Blocking findings

None.

## Non-blocking findings

- **n-1** cursor rc 3 message path form: sh uses `$(display_path "$CLI_CONFIG")` (cursor.sh:357), ps1 uses the full `$cliConfig` (cursor.ps1:276). The text is otherwise identical. This follows the existing convention in the same files (corrupt message cursor.sh:361 / ps1:302), and the test matches it with `.*cli-config.json` (test:136). Leave as is, or align both files together later.
- **n-2** PS helper name `Write-DotprofileResolutionStep` (check-lib.ps1:192) uses Verb-Noun style, while the rest of check-lib.ps1 uses `StepWarn`, `PrintSummary`, `ResolveConfig`, `CheckLogStep`. Cosmetic.
- **n-3** The WARN step is numbered "0" but prints last, after the highest step, because it is emitted from print_summary (check-lib.sh:130). It is readable as is; a comment would help the next reader.
- **n-4** The comment "a broken dotprofile never passes a check run" (check-lib.sh:167 / ps1:172-173) overstates it: the run still exits 0 with a WARN. "never passes clean" would be exact. Cosmetic.
- **n-5** `tests/b8-consumers/test-b8-consumers.sh` is not wired into CI (.github/workflows/check.yml runs tests/profile/test-lib.sh at :141, :144, :306; tests/rules-fanout-cursor is not wired either, so this matches existing practice). Suggest a follow-up to add it with the bash 3.2 leg.
- **n-6** (already in the PR follow-ups, pre-existing, outside the audit) cursor.sh:185-187 "node not found" logs a `log_warn` with no summary row. INCIDENT: summary coverage gap, setup-user-cursor.sh:186, not in S3-MF-Audit; owner to file.

## Commands run (macOS, isolated HOME and AITOOLS_LOG_DIR under `.scratch/session-f4rev/`)

Scripts: `.scratch/session-f4rev/run-tests.sh`, `.scratch/session-f4rev/neg-control.sh` (review worktree).

| command | result |
|---|---|
| `bash -n` (GNU 5.3.15) and `/bin/bash -n` (3.2.57) on setup-user-skills.sh, setup-user-cursor.sh, check-lib.sh, the new test | all rc 0 |
| pwsh 7.6.3 `Parser::ParseFile` on setup-user-skills.ps1, setup-user-cursor.ps1, check-lib.ps1 | all clean |
| `bash tests/b8-consumers/test-b8-consumers.sh` | 60 passed, 0 failed, 0 skipped |
| `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/b8-consumers/test-b8-consumers.sh` | 60 passed, 0 failed, 0 skipped |
| `tests/profile/test-lib.sh`, bash 5 and /bin/bash 3.2 | 209/0 and 209/0 |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, bash 5 and /bin/bash 3.2 | 78/0 (1 skip) and 78/0 (1 skip) |
| **Negative control**: the new test against `git archive origin/main scripts shared` (unfixed) | 36 passed, **24 failed**: skills ps1 rows, message and parity (A-22); cursor sh+ps1 rows, error level and count (A-23); cursor dry-run rows (A-26); check-lib sh+ps1 WARN step (A-24). This matches the PR body's claim. |

The rc 3 path is really reached. The skills case asserts the lib's own `ERROR|dotprofile|` row, which the lib writes only on rc 3 (lib.sh:286-311), and it passed. The cursor case asserts the `[error] Dotprofile unresolved ...` line in deploy.log, and the check-lib case asserts the WARN step; both pass on the PR and fail on main. The trigger is `AITOOLS_USER_REPO_PATH=<nonexistent>` (test:104, :127, :187).

## Not run

- Windows / Git Bash: the .ps1 files ran only as the test's guard-stripped copies under pwsh on macOS.
- tests/profile test-profile, test-config, test-user-init; tests/logging; tests/deploy-harness*. The author reports them green. They do not touch the changed regions except through the lib, which is unchanged.
- check-pre-commit / check-pre-push (review only, no commit).
- build-deploy.sh (the live dotprofile is read-only).
