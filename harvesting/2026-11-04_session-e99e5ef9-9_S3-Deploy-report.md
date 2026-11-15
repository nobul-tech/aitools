# S3-Deploy report v1.0 (2026-11-01)

## Summary
1. Both suites now run each script only where its OS guard allows: deploy-harness.sh on macOS/Linux, deploy-harness.ps1 on Windows (Git Bash driving native pwsh). Every Perl guard-stripped copy is gone.
2. Windows now runs the whole sequence of both suites against the .ps1. Before, only the manifest, skills and upper-case blocks and the MDM "ps1 pair" block ran against the .ps1.
3. Parity checks are now golden files: tests/deploy-harness/golden/ (2 trace files) and tests/deploy-harness-mdm/golden/ (4 row files with numbers written as N). All were written from the macOS bash run.
4. On macOS in compare mode both suites pass under bash 5 and /bin/bash 3.2: deploy-harness 106/106, MDM 59/59.
5. Windows has not been run. PR #139 CI is the first Windows run, and the open risks are listed below.

## Branch and SHAs
- Branch `feature/ci-plat-deploy` (from origin/feature/ci-platform-targeting at a857c12), pushed. No PR opened.
- c80d4f5 CI targeting B4: deploy-harness suite runs one language per platform
- 1dc45d4 CI targeting B4: deploy-harness MDM suite runs one language per platform

## Files changed
- tests/deploy-harness/test-deploy-harness.sh
- tests/deploy-harness/golden/skills.trace, skills-readonly.trace (new)
- tests/deploy-harness-mdm/test-deploy-harness-mdm.sh
- tests/deploy-harness-mdm/golden/eq-first.rows, eq-edit.rows, fresh.rows, dup.rows (new)

## Per suite
### deploy-harness
- Old macOS count, with pwsh hidden from PATH so no .ps1 ran: 101 passed, 4 skipped (the 4 ps1 blocks). With pwsh, CI also ran about 40 ps1 checks under emulation.
- New macOS count: bash 5 106/106/0 skipped; /bin/bash 3.2 106/106.
- Goldens: skills.trace (the shared skills sequence) and skills-readonly.trace (the chmod steps, compared only where those steps run). There are no NAME.<platform> variants. The skill named with glob characters is 'b[1] *?' on POSIX and 'b[1]' on Windows, because Windows file names cannot contain * or ?. The trace writes the name as <BN>, so one golden file serves both platforms.
- Reorder: the read-only steps (pb, rs, bakfail) moved to the end of the skills sequence, so the common trace does not depend on them.
- Added: "manifest LF, no BOM" now runs for both languages. A new step "same run: a listed source retires its removed rule" keeps the one check that only the ps1 block had.

### deploy-harness-mdm
- Old macOS count, with pwsh hidden: 54 passed, 2 skipped (the pwsh parse and the ps1 pair).
- New macOS count: bash 5 59/59; /bin/bash 3.2 59/59.
- Goldens: eq-first.rows, eq-edit.rows, fresh.rows, dup.rows. Each is the MDM summary rows, sorted, with every number written as N, because file counts follow the repo. There are no platform variants.
- build-deploy.sh builds on every platform, and the static greps on the generated files run on every platform. The parse check is bash -n on macOS/Linux and the pwsh parser on Windows.

## check.yml steps (proposed; the commander owns check.yml)
- linux: `- name: deploy-harness tests (bash 5, .sh)` run: `bash tests/deploy-harness/test-deploy-harness.sh`; `- name: deploy-harness MDM build tests (bash 5, .sh)` run: `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`
- macos bash 5: the same two steps (drop "+ pwsh" from the names).
- macos /bin/bash 3.2 (new): `- name: deploy-harness tests (macOS /bin/bash 3.2)` run: `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/deploy-harness/test-deploy-harness.sh`; `- name: deploy-harness MDM build tests (macOS /bin/bash 3.2)` run: `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`
- windows (new, `shell: bash`): `- name: deploy-harness tests (.ps1, native pwsh via Git Bash)` run: `bash tests/deploy-harness/test-deploy-harness.sh`; `- name: deploy-harness MDM build tests (.ps1, native pwsh via Git Bash)` run: `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`. The pty cases need pywinpty from tests/managed-files/requirements-windows.txt, installed before these steps. Without it they SKIP with the reason.

## Not converted or reduced, and why
- The chmod 555/000 failure cases (failed rule backup and retry, manifest write failure, skills partial / read-only / failed backup) run on macOS/Linux only. chmod does not block writes under Git Bash. Their ps1 counterparts used to run under emulation on macOS; now no platform runs those .ps1 branches. That is a coverage gap. Follow-up suggestion: a Windows-only variant that denies writes with icacls.
- The truncation cases stay .sh-only, as before: they test the bash truncation guard.
- The executable-bit checks run for the .sh only. The .ps1 header says only the .sh sets the bit, and Git Bash fakes the bit from file content.

## Windows risks (first native run, unverified)
1. MDM goldens eq-first, eq-edit and dup include the writer's own rows (`WARN|aitools config|updated`, `DETAIL|aitools config|googleDrives updated`). If setup-user-config.ps1 reports differently, those goldens fail. That would be a real parity finding: fix the script, or add a justified .windows variant.
2. deploy-harness "real writer" case: deploy-harness.ps1 calls setup-user-config.ps1 in-process with `&`. Neither its log prefix nor its exit propagation has been tested natively.
3. The pty cases (adopt, skip, abort exit 2, -Force) run pwsh under ConPTY. Adopt writes reference/harness.md back to the fixture repo.
4. `--bogus` is passed to the .ps1 as-is. It is expected to land in $args (the script has no CmdletBinding).
5. CRLF from autocrlf on the runner's checkout could affect `same_trees` and the cmp of git-safety.md between dev and MDM. Both sides read the same disk bytes, so I expect equality.

## Proposed diffs (not applied: platform-lib.sh and scripts/ are out of scope)
- tests/lib/platform-lib.sh: both suites now carry the same three helpers. Moving them into the lib would serve the other S3 delegates too:
  - `TEST_HAVE_READONLY` (false on Windows or when running as root)
  - `ps_flags` (maps --dry-run, --force, --help, --skip-config to -DryRun, -Force, -Help, -SkipConfig)
  - `strip_cr FILE`
- scripts/: no changes needed by these suites.

## WRITE_BLOCKED / CONFLICT / INCIDENT
- WRITE_BLOCKED: none.
- CONFLICT: D-DEL4 (a delegate opens its own PR) vs the commander 2026-11-01 ("Branch + PR", one PR #139; "Everything at once") -- resolved by tier 1: I pushed feature/ci-plat-deploy and opened no PR.
- INCIDENT: none filed. Process note: I did not invoke the /scratch skill. I used the scratch directory named in the brief by hand. I did not delegate, so /delegate was not loaded.
- Read honestly: I read every user rule in full. The worktree rules match the deployed copies except cross-platform.md, script-standards.md (diffs read), hook-lifecycle.md, hook-rollout.md and shared/rules/web-sources.md (diffs not read). I did not read reference/harness.md, reference/plan-execution-detail.md or the 6f5653a diff; I read the final exemplar instead.

## Open questions (with suggested answers)
1. Should the chmod failure paths of deploy-harness.ps1 get Windows coverage (icacls deny)? Suggested: yes, as a follow-up item. It is not a blocker for #139.
2. Should the MDM row goldens keep the writer rows, or filter to `harness files` and `config.json` rows only? Suggested: keep them, since they catch writer drift between the languages. If Windows legitimately differs, add a .windows variant with the reason in the suite header.
3. Should the helpers above move into platform-lib.sh? Suggested: yes, in B7 or when the commander merges the S3 branches.
