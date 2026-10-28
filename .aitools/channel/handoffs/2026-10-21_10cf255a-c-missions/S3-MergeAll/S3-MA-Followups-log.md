# S3-MA-Followups log

**Version:** v1.0 · **Written:** 2026-10-27 (UTC) · **By:** S3-MA-Followups (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)

## Result

PR #130 (https://github.com/nobul-tech/aitools/pull/130), branch `fix/merge-followups`,
head f496c86, merged with a merge commit at 2026-10-27T08:58:03Z as 49123fd. Every
PR check was green and mergeStateStatus was CLEAN before the merge. Main CI after the
merge: run 40477246055 (CI) success, run 40477245084 (Push on main) success.

## What shipped

1. Step 8b passes `--skip-config` / `-SkipConfig` to deploy-harness when Step 5 ran
   the config writer (`CONFIG_WRITER_RAN` in `scripts/aitools-install.sh`,
   `$configWriterRan` in `scripts/aitools-install.ps1`). `run_harness_step` /
   `Invoke-HarnessStep` take the deploy-harness arguments. When Step 5 skipped the
   writer (repos path unusable, writer missing), deploy-harness still runs it.
   Result: `aitools install` runs setup-user-config once; row OK `config.json`
   `n/a (written by installer)`.
2. Tests: `tests/hookin/test-hookin.sh` (install case expects one writer call and the
   n/a row; new "install no Step 5" case; new `ps step -SkipConfig` case; two static
   checks), `tests/hookin/hookin-driver.ps1` (`-SkipConfig`).
3. Approved protected drafts, applied as versions:
   - #103 / S3-MF-Adopt: `reference/managed-file-deployment.md` "Caller
     Responsibilities" N-Q2 bullet and the Return Values one-liner. Checked against
     `dotprofile_commit_push` in scripts/aitools-lib.sh (lines 1109-1207 at f496c86).
   - #108 / S3-MF-Fix6 (I-3): `reference/script-standards-detail.md` "Logging
     overrides" row and "Library-style tools" section. Exit codes checked against the
     scripts/aitools-profile.sh header (lines 29-36).
   - #105 rows 5-6 / S3-M3-Docs: `scripts/setup-user-config.sh/.ps1` header intent
     and config.json `meta.intent.scope`; row 6 wording as approved ("... or
     --no-machine when they leave this machine unregistered").

## Outside the approved text (review after)

- setup-user-config "Consumed by" line: it named the `aitools` sync deploy list as a
  caller; since #106 deploy-harness calls the writer. Corrected.
- script-standards-detail "Library-style tools": one closing sentence linking
  reference/logging.md section 7.

## Verification

Worktree before the PR, and the main checkout after the merge (same results):
`bash -n` and the pwsh parser on every touched script; tests/hookin 46/0/0;
tests/profile/test-config 319/0 (bash 3.2: 208/0); test-install 41/0 (bash 3.2:
22/0); test-user-init 252/0; tests/deploy-harness-mdm 65/0/0. check-pre-commit:
step 6 FAIL (known harvesting file mode). check-pre-push: step 7 FAIL (dotprofile
deploy/ stale, expected until the rebuild). bash 3.2: `"$@"` after `shift` with no
arguments under `set -u` checked on /bin/bash 3.2.57.

## Not run

Windows (pwsh cases ran on macOS only); a real `aitools install`; an independent
reviewer (this delegate cannot launch agents).

## Effect on machines

The `meta.intent.scope` change rewrites each machine's config.json once, with a
backup, on its next run.
