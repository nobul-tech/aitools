# S3-M3-Claude report: PR #83 on the fixed lib contract, reviewed, logging-audited

**Summary.** PR #83 (`feature/m3-b4-setup-user-claude`) now merges PR #80's fixed head (28e0f5b) and origin/main. setup-user-claude.sh/.ps1 read only the `AITLIB_*` / `$script:AitLib*` results, copied right after each call. They read no config/profile JSON and have no alias, hostname or first-profile fallback. Logging was audited. An independent review (S3-M3-Claude-Review) gave "ship after fixes" with 0 blockers, 2 majors, 4 minors and 5 nits. Both majors are fixed, along with m1, n2, n5 and part of m4, in a87ffce, which is pushed.

## Commits (pushed to origin/feature/m3-b4-setup-user-claude)

| SHA | What |
|---|---|
| 301c9f9 | Merge #80 fixed head. Lib conflicts resolved by taking #80 whole. bc1f80f's `MACHINE_HOSTNAME` lib addition was dropped, because this branch does not edit the lib |
| f0ebd95 | Caller switch to the contract names, the batch 6 comment, the logging audit, and footer host detection in the caller |
| 08482fe | Merge origin/main (#78, #79). Conflict-free; clears pre-commit step 20 |
| a87ffce | Review fixes: M1, M2, m1, m4 (rules dir), n2, n5. Also commits the review handback file |

The PR body has been rewritten (the old one claimed a lib change). A fix-summary comment is at https://github.com/nobul-tech/aitools/pull/83#issuecomment-6352165159.

## Review

- URL: https://github.com/nobul-tech/aitools/pull/83#pullrequestreview-5621269178 (COMMENTED; verdict "ship after fixes" at 08482fe).
- Handback: `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Claude-Review/S3-M3-Claude-Review-pr83.md`.
- I verified it:
  - M2's data claim: `aitools-nobul-jose/profile.json` lines 5 and 72 hold email `jose@nobul.tech` and company `nobul.tech`.
  - m1's claim: `aitools-profile.sh:320-331` shows `short_host` lower-cases and does not fall back on macOS.
  - M1: reproduced as smoke case 6 before writing the fix.
- Fixed:
  - **M1:** rc 3 now deploys nothing: ERROR claude.md row, exit 1, no ACTION.
  - **M2:** single pass, longest value first, P-Q13 tie kept.
  - **m1:** "unknown" on failure; short, lower-case name.
  - **m4:** the rules dir mkdir/New-Item is now checked.
  - **n2:** single-pass forward interpolation.
  - **n5:** the dotprofile via is copied right after its own call.
- Not fixed (follow-ups in the PR body):
  - m2: build-deploy, which is B5.
  - m3: protected doc drift, which needs drafts.
  - Rest of m4: PowerShell `Get-ChildItem -ErrorAction Stop` outside try/catch (pre-existing).
  - n1: dry run writes no summary row.
  - n3: the PowerShell footer has no arch.
  - n4: bash creates `~/.claude` during a dry run.

## Verification (macOS; isolated HOME under `.scratch/session-Claude/`)

- **Syntax:** `bash -n` under bash 5 and /bin/bash 3.2 is clean, and the pwsh parser is clean.
- **Smoke** (`.scratch/session-Claude/smoke.sh`): 33/0 under bash 5 and again under /bin/bash 3.2. Cases:
  - id match with values `& $HOME \1 $1 @ /`;
  - no match (exit 1, ERROR plus one ACTION, no other machine's values);
  - no dotprofile (WARN);
  - second run verified;
  - rc 3 (personal CLAUDE.md unchanged);
  - PTY adopt with the live data shape (email token whole, next run verified);
  - token text inside a value;
  - footer host.
- **PowerShell filters** (`ps-filter-test.ps1`): the interpolation and the adopt filter, extracted from the script's AST and run under pwsh 7, pass 5/0.
- **Suites:**
  - test-profile 319/0;
  - test-config 89/0;
  - test-lib 108/0 (3.2 `--bash-only`: 44/0);
  - managed-files bash 42/0 (3.2: 42/0), PowerShell 24/0;
  - logging bash 24/0, PowerShell 15/0 (5 skipped).
- **Checks:**
  - check-pre-commit: step 6 is the known failure; step 13 is a WARN (B5); step 20 passes after the main merge.
  - check-pre-push: step 7 is the known failure.
  - CI on 08482fe was green per the reviewer.

## Not run

- setup-user-claude.ps1 end to end (it has a Windows-only guard).
- build-deploy.sh and the generated deploy/ scripts (B5).

## Needs from others (not edited by me)

- **Lib (#80 owner):** add `AITLIB_MACHINE_HOSTNAME` / `$script:AitLibMachineHostname`. It is one line each, from the `hostname` tag the wrapper already parses for its detail line. Until then the script detects the host with the resolver's source and form. That is a second copy of the detection.
- **tests/managed-files (#81 owner):**
  - The claude-md fixture at `test-managed-files.sh:263-264` is alias-keyed (`machineAlias: m1`, `profiles.m1`) and gated on `command -v node`. The script no longer uses node.
  - After the re-key it needs an id-keyed profile plus `AITOOLS_PROFILE_TEST_MACHINE_ID`.
  - A substring-value adopt case (M2) belongs there.
- **Resolver/lib (reviewer observation):** with a bad `AITOOLS_USER_REPO_PATH`, both wrappers log the same error. The ACTION "pick or register this machine's profile" is then misleading.

## INCIDENT markers (not filed)

- INCIDENT: the CLAUDE.md adopt filter reverse-tokenized by fixed order, and live data corrupts the template (`jose@{{PROFILE_COMPANY}}`). Fixed going forward in a87ffce. The live dotprofile template already contains `nobul-{{PROFILE_NAME}}/aitools` (aitools-nobul-jose/claude/CLAUDE.md:42-43, per the reviewer), probably from an earlier adopt, and still needs a manual repair. P-Q13 covers only the same-text tie.
- INCIDENT: `.claude/rules/managed-file-deployment.md` "Content sources" documents the hostname-then-first-profile fallback that #83 removes. This is protected rule drift; the fix needs a draft.
- INCIDENT: the mission prompt names `# --- BEGIN/END profile resolution (extracted by build-deploy) ---` markers. No such markers exist on main, on this branch or in build-deploy.sh (`git grep -i "profile resolution" -- scripts` is empty). The existing markers (preamble, post-write validation, rules deployment, rules deploy logic, exit) are intact.

## Open questions (with suggested answers)

1. Should the hostname go into the lib contract? Suggested: yes, in #80 now (two lines, already parsed). Otherwise in lib batch 3, after which #83's footer switches to it.
2. Should the live template's `nobul-{{PROFILE_NAME}}` be repaired? Suggested: yes, by hand in the dotprofile (N-Q2 auto-push applies). It does not belong in this PR.
3. Merge order: #83 contains #80's commits. Suggested: merge #80 first, then #83 (its diff then shrinks to the two scripts plus handoff files).

## Delegates

- S3-M3-Claude-Review (independent; no isolation; launched without my report). Output was verified as above.

## WRITE_BLOCKED

None.
