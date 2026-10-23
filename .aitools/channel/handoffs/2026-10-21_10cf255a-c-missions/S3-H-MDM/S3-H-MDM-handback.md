# S3-H-MDM hand-back (2026-10-22)

S3-H-MDM to S3-Harness. PR: https://github.com/nobul-tech/aitools/pull/93. Branch: `feature/harness-mdm`. It merges #88 and #87, so merge it after them.

## Summary

1. `scripts/build-deploy.sh` generates `<dotprofile>/deploy/deploy-harness.sh` and `.ps1`, the MDM path of `scripts/deploy-harness.*`.
   - The build snapshots every source directory the dev script names: its `git ls-files -s -z` listing, plus the files' contents and git modes, plus the bin CLIs.
   - The generated script embeds that snapshot as base64 blocks, each checked against its size and sha256.
   - The rest of the generated script is the dev script's own code, cut at its section headings. Only section 2 (the dotprofile lookup) is replaced.
2. Dev and MDM produce equivalent results under isolated HOMEs on real repo content, for both .sh and .ps1.
   - Both paths add 132 files, and the six directories are byte-identical.
   - The 20 exec bits, config.json, summary rows and exit codes also match.
   - The MDM run had a failing `git` on PATH and never called it.
3. The `setup-user-cursor` MDM headers are now extracted from the source headers: four steps, plus the `~/.cursor/rules` scope.
   - Both headers say to run deploy-harness first.
   - `grep -c 'Step 4: Cursor user rules'` returns 1 on both generated scripts.
4. `deploy/` now also gets the config writer that deploy-harness calls: `setup-user-config`, `aitools-profile` and `aitools-json`, copied as-is with the library inlined. The build now generates 50 scripts.
5. Independent review: the first pass was CHANGES REQUESTED (3 blocking), all fixed in `3e1a97d`. The re-verify found NO BLOCKING FINDINGS.
   - Tests: `tests/deploy-harness-mdm` 29/29.

## Files changed

- `scripts/build-deploy.sh`
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (new)
- This folder:
  - `S3-H-MDM-handback.md`
  - `S3-H-MDM-Review-verdict.md`
  - `S3-H-MDM-Review-reverify.md`
  - `S3-H-MDM-drafts/dot-claude/rules/deploy-paths.md`

## How it works (for whoever touches it next)

- **Source list.**
  - The source directories are parsed from the `add_source "$REPO_DIR|$DOTPROFILE/..."` lines in `deploy-harness.sh`.
  - The build compares them with the `.ps1` `-SrcDir (Join-Path ...)` chains and fails on any difference.
  - The bin CLIs come from the `for cli in ...; do` line, compared with the `.ps1` `foreach ($cli in @(...))`.
- **Cut points.** `extract_span` requires each regex to match exactly one line:
  - `^set -euo pipefail$` / `^param\($` to `^# 2\. Dotprofile`
  - `^# 3\. The six directories` to EOF
  - the header scope: `^# Managed \(` to `^# Usage:`
- **Adopt.** `replace_once` swaps the adopt argument for `""`.
  - Rewording any of these source lines fails the build loudly.
- **The `git` function.**
  - At run time, a bash function (or PS function) named `git` answers `-C <stage dir> rev-parse --is-inside-work-tree` and `-C <stage dir> ls-files -z` from `<dir>/.aitools-mdm-ls-files`.
  - Every other call goes to the real git. The library uses git for its protected-file checks, but only on adopt, which MDM never offers.
- **Damage checks.**
  - A size or sha mismatch, or an unpacked count that differs from the embedded block count, gives `ERROR|harness files|N embedded file(s) damaged` and exit 1.
  - The .sh also requires an end marker, so a truncated copy fails with `script truncated`.
  - A truncated .ps1 fails to parse.
- **Non-git dotprofile at build time.**
  - This is the case for pre-push step 7, which builds into a `git archive` copy.
  - The build then lists files on disk in git's order, takes exec bits from `-x`, and warns.
  - The output is identical to a git build (tested). In the real pre-push run, step 7's rebuild succeeded and reached the diff.

## Where MDM ordering lives

`build-deploy.sh` defines no run order. The only order is the README's "Deploy to a machine (no repo needed)" list (README.md lines 69-90), which lists setup-user-claude first and has no deploy-harness.

- What I did: headers in the generated deploy-harness and setup-user-cursor scripts, and the "MDM run order" section in the deploy-paths.md draft.
- README is outside my scope, so it is a follow-up: add `deploy-harness` as the first line.

## setup-user-config in MDM

It was not in `deploy/`. Now it is, together with its two helpers.

- Remaining gap: on an endpoint where aitools-install has not run, the writer exits 1 with `missing bootstrap values`. That gives `ERROR|harness files|config.json not generated` and exit 1, while the harness files still deploy.
- The dev path behaves the same, but it never meets this case because the installer runs first.
- See open question 1.

## Verification

| Command | Result |
|---|---|
| `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 29 passed, 0 failed, 0 skipped; the reviewer reproduced 29/29 |
| scratch `build-isolated.sh` + `equiv.sh --fake-git` (real content, `git archive` dotprofile copy, isolated HOMEs) | dev rc=0, mdm rc=0; all six directories, 20 exec bits, config.json and summary rows the same; fake git never called |
| scratch `ps1-equiv.sh`, normal and `-DryRun` (pwsh, OS guards off in copies) | identical, `132 added` / `dry-run: 132 create`; 0 temp directories left |
| `bash -n` generated deploy-harness.sh; build-time pwsh parser on all 50 generated .ps1 | OK |
| `grep -c 'Step 4: Cursor user rules'` on generated setup-user-cursor.sh / .ps1 | 1 / 1 |
| `tests/deploy-harness/test-deploy-harness.sh` | 45/45 |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 78 pass, 1 skip (dupcase) |
| `check-pre-commit.sh` | FAIL step 6 only (known `harvesting/...build-deploy-prefix.sh` 100644); WARN 3, 5, 9, 11 |
| `check-pre-push.sh` | FAIL step 7 only (known stale dotprofile deploy/; its rebuild succeeded) |

On pre-commit step 11: the real dotprofile has uncommitted `deploy/*` and `profile.json` changes with mtime 2026-10-21 21:55 local, from before this session. Its deploy/ has no `deploy-harness.*`, so none of those changes are mine.

## Not run

- The generated .ps1 on Windows, and building on Windows.
  - B3 (MSYS paths, exec bits) was fixed by reasoning; the reviewer verified it by reading the code.
- A live MDM endpoint (Jamf or Intune), and Intune script size limits.
  - The generated scripts are about 2.2 MB each. The reviewer believes the limit is about 200 KB, but that is unverified.
- `build-deploy.sh` against the real HOME or dotprofile (never). The real dotprofile `deploy/` is stale until the commander rebuilds and commits it.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: `build-deploy.sh` runs `rm -rf "$DEPLOY_DIR"` before generating, so a failed build leaves a partial, git-tracked dotprofile `deploy/` (reviewer N4; pre-existing).
  - The new damage checks make a partial `deploy-harness.sh` fail with `script truncated`, but the other scripts are still partial.
  - Fix: generate into a temp directory and swap it in on success.
- INCIDENT: the pre-push step 7 trigger (`scripts/check-pre-push.sh` step 7, `deploy_sources` regex) does not cover the new deploy/ dependencies:
  - `reference/`, `registries/`
  - `.claude/{rules,skills}/`, `shared/rules/`
  - `scripts/deploy-harness.*`, `scripts/aitools-profile.*`, `scripts/aitools-json.*`
  - `scripts/harness-db.py`, `scripts/read-session*.py`
  - The effect is that `deploy-harness.*` goes stale with no FAIL (reviewer N2).
- INCIDENT: the README MDM order omits deploy-harness and lists only 7 of the deploy scripts (doc drift).
- INCIDENT (minor): build-deploy's embedded skills and setup-user-claude rules still use unchecked heredocs (`cat`). Only the new payload is integrity-checked.

## Open questions (with suggested answers)

1. **Fresh endpoint without the installer: should the MDM config writer be skipped?**
   - Today the run exits 1. Jamf and Intune would report every first run as failed, although the harness files deploy.
   - Suggested answer: yes, but only in the MDM variant. When `~/.aitools/config.json` is absent or lacks `reposPath`/`repoPath`, report `OK|harness files|config.json n/a (no bootstrap)` instead of running the writer. This needs one more replaced span (section 1), plus a test.
   - The reviewer agrees. This needs the commander's decision.
2. **Body markers in `scripts/deploy-harness.*`** (PR #88). I did not edit them. Today's cut points are the section headings, strictly asserted. For S3-Harness to decide whether #88 adds markers in a separate commit:
   - `# --- BEGIN dotprofile lookup (replaced by build-deploy) ---`: directly above the `# ===` line that precedes `# 2. Dotprofile`
   - `# --- END dotprofile lookup (replaced by build-deploy) ---`: directly above the `# ===` line that precedes `# 3. The six directories`
   - `# --- BEGIN scope (extracted by build-deploy) ---` / `# --- END scope (extracted by build-deploy) ---`: around the `# Managed (` ... `# Overwrites:` header lines
   - The same lines in the `.ps1`.
   - Suggested answer: add them after #88 merges, in a small follow-up PR that also switches build-deploy to `extract_between` on them. They are not needed for correctness now.
3. **Pre-push step 7 policy** (N2). Widening the trigger means most pushes FAIL until the dotprofile is rebuilt.
   - Suggested answer: widen the trigger, report a stale `deploy-harness.*` as WARN naming the rebuild command, and keep FAIL for the extracted-logic scripts.
4. **Size** (N3). Suggested answer: verify the Intune and Jamf limits with chrome-devtools before relying on the MDM path for Windows. If the limit is hit, ship the payload as a separate data file in deploy/ instead of inline.
5. **Symlinks** (reviewer residual). A tracked symlink (mode 120000) is embedded as its target's content with exec=0. None exist in the sources today.
   - Suggested answer: accept, since the dev path also reads through symlinks. Revisit if one appears.

## Protected-file drafts awaiting approval

- `.claude/rules/deploy-paths.md`, draft at `S3-H-MDM-drafts/dot-claude/rules/deploy-paths.md`. It adds:
  - a "MDM run order" section, including the directory and bootstrap requirement
  - deploy-harness as "extract + embed"
  - an auto-embedded sources bullet
  - a staleness note
- `.cursor/rules/deploy-paths.mdc` needs the same change. It was not drafted.

## Reviewer verdict

- S3-H-MDM-Review, first pass: **CHANGES REQUESTED (3 blocking, 7 non-blocking)**, https://github.com/nobul-tech/aitools/pull/93#pullrequestreview-5621367406, file `S3-H-MDM-Review-verdict.md`.
- Fixed in `3e1a97d`:
  - B1 (payload integrity)
  - B3 (Windows paths and exec bits)
  - N1, N5, N6, N7
  - B2: minimum honest fix
- Re-verify: **NO BLOCKING FINDINGS**, https://github.com/nobul-tech/aitools/pull/93#pullrequestreview-5621439226, file `S3-H-MDM-Review-reverify.md`.
- Still open: N2, N3 and N4 (the follow-ups above), and B2's behaviour decision (question 1).

## Delegates used

- S3-H-MDM-Review: level 3, general-purpose, no isolation. It did the review and the re-verify; GitHub refuses request-changes on your own PR, so both were posted as comment reviews.
