# S3-Fan report v1.1 (2026-11-01)

## v1.1: fix-forward after CI run 41265193554

Windows results in that run:
- fanout-lib: 90 passed, 20 skipped
- rules-fanout-cursor: 145 passed, 6 skipped
- rules-fanout: 59 passed, 2 failed (the two "adopt map ps" aitools-checkout checks)

The cause was the test harness (category a). The adopt itself worked: in the same run, "adopt ps: aitools rule written to the aitools working tree" and the dotprofile adopt-map check both passed. Only the text of the logged checkout path differed from the needle. The needle was `cygpath -m` of the temp checkout, compared as a literal string. pwsh derives the checkout from `$PSScriptRoot`, and the console shows the runner temp root in 8.3 short form (`C:\Users\RUNNER~1\...`). One directory, two spellings. This was the path-form risk predicted in v1.0.

Fix (626cdab): `adopt_is RULE SOURCE WANT` reads the logged `adopt=` value. On Windows it compares the value and WANT after `cygpath -m -l` on both sides (long form); elsewhere it compares them as plain strings. It replaces the 4 path-bearing log checks (adopt map ×3, payload ×1), and prints the logged value on a mismatch.

macOS after the fix: bash 5 and /bin/bash 3.2 each 67 passed / 1 skipped, 2 runs each. No product diff needed.

# v1.0

Delegate S3-Fan, for Session Commander e99e5ef9-9. Mission: convert tests/fanout-lib, tests/rules-fanout and tests/rules-fanout-cursor to platform targeting.

## Summary

1. All three suites now run one language per platform: the .sh half on macOS/Linux, the .ps1 half on Windows (Git Bash driving native pwsh). No guard bypass is left in them.
2. Every sh-vs-ps parity check is now `golden_match`. There are 48 golden files, all written from the macOS bash run, with no `NAME.<platform>` variants.
3. Bypasses removed: the Perl-patched guard-off copy of setup-user-claude.ps1, `AITOOLS_PROFILE_TEST_ANY_OS=1`, and `step4-driver.ps1` (git rm). On Windows the cursor suite runs the whole setup-user-cursor.ps1, with stub rg.cmd and agent.cmd on PATH.
4. macOS compare runs, bash 5 and /bin/bash 3.2, 2-3 runs each: fanout-lib 127/127, rules-fanout 67 passed + 1 skipped, rules-fanout-cursor 160 passed + 1 skipped. No failures.
5. The Windows half has not been run (no emulation, by order). It needs 3 new windows steps in check.yml, listed below.

## Branch and SHAs

Branch `feature/ci-plat-fan`, based on origin/feature/ci-platform-targeting (a857c12), pushed. No PR opened.

| SHA | Suite |
|---|---|
| ddfd2bf | fanout-lib |
| 2f694d7 | rules-fanout |
| ccd8a79 | rules-fanout-cursor; also removes step4-driver.ps1 |

**Merge note:** merge this branch together with `feature/ci-plat-skill` (1ba9bb0). On base, tests/skills-fanout/test-skills-fanout.sh:657 still calls step4-driver.ps1. S3-Skill's 1ba9bb0 drops that call. Merged without it, the old skills-fanout would break.

## Files changed

- tests/fanout-lib/test-fanout-lib.sh
- tests/fanout-lib/golden/parity-{base,fifos,symlinks,special,unread}.results (5 files)
- tests/rules-fanout/test-rules-fanout.sh
- tests/rules-fanout/golden/: 21 `<case>.result` files, plus lib.summary and lib.kinds
- tests/rules-fanout-cursor/test-rules-fanout-cursor.sh
- tests/rules-fanout-cursor/convert-rule.ps1: header only (now Windows-only); parses with `_validate-ps1.ps1`
- tests/rules-fanout-cursor/step4-driver.ps1: deleted
- tests/rules-fanout-cursor/golden/: 19 `<case>.result` files, plus dangtarget.errors

## Per suite

### fanout-lib

Counts on macOS:
- Old, with `--bash-only`: 122 passed, 1 skipped, on both bash 5 and 3.2.
- New: 127 passed, 0 skipped, on both bash 5 and 3.2.

The old full run under pwsh on macOS can no longer be run: that is the emulation now banned.

Changes:
- The suite runs one driver: bash (aitools-lib.sh) or pwsh (aitools-lib.ps1).
- The case list has `#group NAME` markers, so there is one golden file per fixture group. Windows leaves out the groups it cannot make: symlinks (no dangling links in Git Bash), fifos, special (`* ?` in names), and unread (chmod 000).
- The fifos and special groups are switched off explicitly on Windows. Git Bash emulates both in ways native pwsh cannot see.
- On Windows, paths in the pwsh log are compared in native form with `/` separators.

A tampered golden line fails the group check (tested).

### rules-fanout

Counts on macOS:
- Old, with `--bash-only`: 44 passed, 23 skipped.
- New: 67 passed, 1 skipped (dupcase, because APFS is case-insensitive), on both bash 5 and 3.2.

Golden files:
- Each `<case>.result` holds the exit code, the ~/.claude/rules tree (path and md5) and the summary rows, for 21 cases.
- lib.summary and lib.kinds replace the old lib parity check.
- dupcase has no golden file. Only Linux runs it, and macOS cannot write it; its explicit checks still pin the result.

Fix along the way: the fanout-force case was flaky against its golden file. Two backup stamps could fall in the same second. The test now removes the edited run's backup before the `--force` run.

### rules-fanout-cursor

Counts on macOS:
- Old, with `--bash-only`: 140 passed, 22 skipped.
- New: 160 passed, 1 skipped (dupcase), on both bash 5 and 3.2.

Golden files: 19 `<case>.result` files, plus dangtarget.errors (the error-line count).

Converter checks:
- `conv` uses the converter of the language under test: the bash function on macOS/Linux, convert-rule.ps1 on Windows.
- The converter cases check against the existing .want texts, which both converters must give. So the old "parity ps1: <g>" block is gone.
- `conv` also writes the fan-out fixtures, so each platform seeds with its own converter.

Other changes:
- The `--force` log check now accepts each language's spelling: `(--force)` for sh, `(-Force)` for ps1.
- The three dangling-symlink cases (broken, drydup, dangtarget) are skipped where a dangling symlink cannot be made (Git Bash by default).

## check.yml steps (proposed; I did not edit check.yml)

On all three runners, keep `if: ${{ !cancelled() }}`. On windows add `shell: bash`.

**linux**
- `Fan-out lib helper tests (aitools-lib.sh)`: `bash tests/fanout-lib/test-fanout-lib.sh`
- `Claude rules fan-out tests (.sh)`: `bash tests/rules-fanout/test-rules-fanout.sh`
- `Cursor rules fan-out tests (.sh)`: `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`

**macos, bash 5**
- The same three run lines.
- Rename each step: drop "+ pwsh parity" and use "(.sh, bash 5)".

**macos, /bin/bash 3.2** (keep the existing steps)
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/fanout-lib/test-fanout-lib.sh --bash-only`
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/test-rules-fanout.sh --bash-only`
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh --bash-only`

**windows** (new, in the "Heavy suites, .ps1 half" block)
- `Fan-out lib helper tests (aitools-lib.ps1, native pwsh)`: `bash tests/fanout-lib/test-fanout-lib.sh`
- `Claude rules fan-out tests (.ps1, native pwsh)`: `bash tests/rules-fanout/test-rules-fanout.sh`
- `Cursor rules fan-out tests (.ps1, native pwsh)`: `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`
- Delete the comment at check.yml:776-778 ("tests/rules-fanout-cursor is not run here..."). It is now false.

## What I could not convert, and Windows risks

Everything was converted. These are the risks I could not check without a Windows run:

1. **Path forms.** On Windows, log checks compare `native_path` (cygpath -m) against pwsh's own paths, with `\` turned into `/`. If pwsh ever reports a different form (an 8.3 short name like RUNNER~1, or another drive-letter case), these checks fail:
   - rules-fanout: "adopt map" and "payload"
   - fanout-lib: the Test-FanoutTextEqual and Backup-Dir detail-log checks
2. **Run time.** The cursor suite on Windows starts pwsh about 35 times for convert-rule.ps1 and about 45 times for whole-script runs. rules-fanout starts it about 30 times. The Windows job may take several minutes; that per-case start cost was already deferred as a follow-up in the plan.
3. **Unproven Windows behaviour.** These have never run on Windows (the old parity ran pwsh on macOS):
   - whether the steps 1-3 rows of the whole setup-user-cursor.ps1 stay out of the golden rows (they should: the rows filter keeps only cursor rules and ACTION rows)
   - ps1 summary row order
   - the fanout-lib base group on NTFS

   Any divergence shows up as a golden diff in CI, with up to 30 lines printed.
4. **Fixture groups off on Windows** (reported as SKIP; parity for them is checked only between macOS and Linux):
   - fanout-lib: symlinks, fifos, special, unread
   - rules-fanout: broken, dupcase, unreadable
   - cursor: broken, drydup, dangtarget, dupcase, unreadable, unreadsrc

## Proposed diffs (not applied; outside my scope)

- **tests/lib/platform-lib.sh: shared `strip_cr` helper.** All three suites define the same one: `strip_cr() { perl -pi -e 's/\r//g' "$@" || printf 'warn: could not strip CRs from %s\n' "$*"; }`. Moving it into platform-lib would remove the copies.
- **tests/lib/platform-lib.sh: optional language override.** An `AITOOLS_TEST_LANG=sh` override, honoured only on Windows, would let a suite also run a cross-platform .sh library (aitools-lib.sh, which the plan's table marks "all") under Git Bash, against the same golden files. Sketch, after the `TEST_LANG` line: `if [ "$TEST_PLATFORM" = windows ] && [ "${AITOOLS_TEST_LANG:-}" = sh ]; then TEST_LANG=sh; fi`. fanout-lib would then need DRV to follow it (one line).
- **scripts/:** none needed.

## Status lines

- `CONFLICT: D-DEL4 (a code-change delegate opens its own PR) vs the commander's 2026-11-01 words "Branch + PR" / "Everything at once" -- resolved by tier 1 (the commander's newest words): pushed feature/ci-plat-fan, opened no PR.`
- WRITE_BLOCKED: none.
- INCIDENT: none filed. Observations:
  1. check.yml:776-778 is stale once this branch merges (see above).
  2. The fanout-force golden flake: a timing-dependent backup count, fixed in 2f694d7.
  3. Correction: the 2f694d7 commit body says "22 cases". The real number is 21 `.result` files. Not amended, because amending a pushed commit would need a force-push.
  4. step4-driver.ps1 is still named in archived handoff files under .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/. Those are history and were left unchanged.
- /delegate: not loaded, because I launched no delegates.
- /scratch: followed by hand. Scratch is /Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-fan/.scratch/session-S3-Fan/ (commit messages, run and repeat scripts, logs).

## Open questions (with suggested answers)

1. **Should Windows also run the bash driver of fanout-lib (aitools-lib.sh in Git Bash)?** Suggested: yes, as a follow-up through the platform-lib override above. aitools-lib.sh is cross-platform, and the logging and managed-files suites already source it in Git Bash. Not needed for #139.
2. **Should the golden checks for broken, unreadable, unreadsrc and dangtarget stay, given that Windows skips them?** Suggested: keep them. They still pin macOS = Linux, and they are ready if Windows gains native symlinks later.
3. **Should the step names on the macOS bash 5 steps change from "(bash 5 + pwsh parity)"?** Suggested: yes, to "(.sh, bash 5)", matching the b8-consumers step.
