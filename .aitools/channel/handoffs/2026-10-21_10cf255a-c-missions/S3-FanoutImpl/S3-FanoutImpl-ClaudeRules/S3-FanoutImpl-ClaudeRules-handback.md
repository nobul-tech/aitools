# S3-FanoutImpl-ClaudeRules hand-back (FO-3)

Version 1.0, 2026-10-27 (UTC), S3-FanoutImpl-ClaudeRules (level 2, under
S3-FanoutImpl, Session Commander 10cf255a-c). No delegates used.

## Summary

1. FAN-PLAN Batches B, C, D (with the section 12 amendments) applied verbatim; every old_string matched exactly once, so nothing was re-pinned.
2. The contract change: the retired-rule comparison uses the lib's `fanout_text_equal` / `Test-FanoutTextEqual`. The local `rule_text_equal` / `Test-RuleTextEqual` are gone.
3. Merged `origin/feature/fanout-size-warn` (FO-0b) with `--no-ff` after the B commit. Without it, tests/claude-mdm fails 13 checks on the Intune size gate.
4. Suites pass: rules-fanout 110/0/1 on bash 5 + pwsh and 42/0/21 on /bin/bash 3.2. claude-mdm passes 35/0 on both bashes. managed-files, adopt-push, fanout-lib and deploy-harness-mdm also pass.
5. PR #121 is open against base main. CI run 40441560794 succeeded on macos, linux and windows. On linux the rules-fanout suite passed 114/0/0, with dupcase passing; on macos it passed 110/0/1 and 42/0/21.

## PR

- https://github.com/nobul-tech/aitools/pull/121
- Branch `feature/fanout-claude-rules`, head `66c58cb`
- GitHub reported the PR DIRTY/CONFLICTING and ran no CI workflow, even though a local `git merge-tree` against origin/main was clean (there are 3 merge bases). I merged `origin/main` into the branch with `--no-ff` (66c58cb). That merge brought in docs and handoffs only, no code. After it the PR became mergeable and CI ran. The same probably applies to #119, which is also DIRTY.
- Worktree `/Users/new-jose/repos/aitools/.claude/worktrees/fo-crules` (start `origin/feature/fanout-lib` 14f9fb1, then merged `origin/feature/fanout-ci`; 9923a3c ancestor check exit 0)

| Commit | What |
|---|---|
| 2220f0b | merge origin/feature/fanout-ci (FO-0) |
| b27ab1a | B: setup-user-claude.sh/.ps1 (B1-B7 + contract change) |
| (merge) | origin/feature/fanout-size-warn (FO-0b) |
| a0bd5e4 | C: build-deploy.sh (C1-C10, C11b), tests/claude-mdm (C12), README (C13, C14) |
| bba5fad | D: tests/rules-fanout/test-rules-fanout.sh (D0 verbatim, 100755), check.yml (D1, D2) |

## Files changed

scripts/setup-user-claude.sh, scripts/setup-user-claude.ps1, scripts/build-deploy.sh,
tests/claude-mdm/test-claude-mdm.sh, README.md, tests/rules-fanout/test-rules-fanout.sh (new),
.github/workflows/check.yml.

## Re-pinned old_strings

None. I checked every label with a scratch script (`.scratch/session-focr/apply-edits.py`, which extracts each ````text block from the plan and requires exactly one occurrence, CRLF-aware for .ps1). The labels were B1-B7, C1-C10, C11b, C12-C14, D1 and D2. I checked the C labels again after the size-warn merge.

## Deviations from FAN-PLAN

- **Contract change:** `fanout_text_equal` / `Test-FanoutTextEqual` from the lib replace FAN-PLAN's local helpers. Callers are unchanged apart from the name. When a file cannot be read, the detail log line now comes from the lib: `fanout_text_equal: cannot read ...` instead of `claude rules: cannot read ...`.
- **D0 test:** copied byte-identical (cmp clean). It needed no adaptation, because it asserts on rows, trees and log lines, not on the helper's name.
- **Branch and PR:** the branch is `feature/fanout-claude-rules`, not FAN-PLAN's `feature/claude-rules-fanout`. The PR was opened ready, not as a draft.
- **CI step condition:** I did not add `if: ${{ !cancelled() }}` to the new CI steps, to stay verbatim with D1/D2. FO-0 uses that condition on its own steps.
- **FX-74:** origin/main deploy-paths.md has no "MDM path limits" section, so README C13 keeps FAN-PLAN's text. It is listed in the PR body.

## Verification

| Command | Result |
|---|---|
| `bash -n` on the 4 touched .sh | pass |
| `_validate-ps1.ps1 setup-user-claude.ps1` | OK; `grep -c -v $'\r$'` = 0 (all CRLF) |
| `bash tests/rules-fanout/test-rules-fanout.sh` | 110/0/1 (skip: dupcase on APFS) |
| `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/... --bash-only` | 42/0/21 |
| `bash tests/claude-mdm/test-claude-mdm.sh` / `/bin/bash` 3.2 | 35/0/0 each (21/13 before the size-warn merge) |
| tests/managed-files sh / ps1 / test-adopt-push.sh | 57/0, 39/0, 28/0 |
| tests/fanout-lib | 284/0/0 |
| tests/deploy-harness-mdm | 64/0/0 |
| check.yml YAML parse (ruby) | ok |
| check-pre-commit (each commit) | step 6 FAIL pre-existing (harvesting file 100644); step 13 WARN on B only |
| check-pre-push | step 7 FAIL known (dotprofile deploy/ stale; the step stops at the staleness report, so its generated-script smoke did not run); WARN 1, 5, 6, 8 |

## Not run

Windows native; Linux locally (CI only); check-post-push; anything against the real HOME; a real MDM endpoint.

## WRITE_BLOCKED

None.

## INCIDENT markers

None filed. Observation only: FO-0's `%exempt` entry in check.yml still lists tests/deploy-harness-mdm because of the Intune guard. With FO-0b merged, that suite passes (64/0), so the exemption becomes stale once FO-0b merges. FO-0/FO-0b own the change.

## Open questions (with suggested answers)

- **Q: Should the new CI steps get `if: ${{ !cancelled() }}` like FO-0's steps?** Suggested: yes, in FO-4's check.yml edit or a follow-up. It keeps a later suite visible after an earlier failure.
- **Q: Who removes the deploy-harness-mdm exemption?** Suggested: whoever merges FO-0b (that branch makes the suite pass).
