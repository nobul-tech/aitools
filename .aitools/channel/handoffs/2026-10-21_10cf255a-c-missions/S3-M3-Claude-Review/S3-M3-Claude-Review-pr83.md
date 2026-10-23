# S3-M3-Claude-Review: PR #83 review

Review URL: https://github.com/nobul-tech/aitools/pull/83#pullrequestreview-5621269178 (posted 2026-10-22T21:46:19Z, state COMMENTED)
Scratch evidence: `.scratch/session-ClRev/` (smoke.sh, smoke/report.txt, run-checks.sh, checks.log, markers.sh)

**Verdict: ship after fixes** (0 blocker, 2 major, 4 minor, 5 nit). Independent review by S3-M3-Claude-Review of head `08482fe`. This is a comment review: it does not approve and does not request changes.

The contract use is correct: the AITLIB_* / `$script:AitLib*` names are right, values are copied right after each call, the scripts add no ACTION rows of their own, and they read no config.json or profile.json and use no alias, hostname or first-profile fallback. Interpolation is literal-safe in bash 5.3 and 3.2. Tests and CI are green. One major finding (M1) is a gap in how rc 3 is handled. The other (M2) is pre-existing, but this PR rewrote the code involved and the live dotprofile data triggers it.

## Major

**M1. A dotprofile resolver error (rc 3) deploys the shared template over the personal CLAUDE.md.** `scripts/setup-user-claude.sh:71-73,107-123` and `scripts/setup-user-claude.ps1:70-71,91-110`.
When `resolve_user_repo_path` returns 3, `USER_REPO_PATH` is empty and the template falls through to `shared/claude-shared.md`. That is the shared-only path (rc 1), but rc 3 is an error, not "no dotprofile". Reference R18 (S4-Review draft "Which dotprofile") defines shared-only only for step 6, "None". Smoke case C used an isolated HOME that already held a good personal CLAUDE.md, with `AITOOLS_USER_REPO_PATH` set to a missing directory and stdin not a terminal:
```
ERROR|dotprofile|resolver failed
ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)
WARN|claude.md|updated
[warn] Diff in .../hA/.claude/CLAUDE.md -- overwriting (non-interactive)
CLAUDE.md now: "# Shared Claude Code Preferences" ... "- Name: {{PROFILE_NAME}}"
```
A transient or config-level dotprofile error therefore replaces the user's personal instructions with the unresolved shared template. A backup exists, and the run exits 1. The same thing happens under `--force` and in non-interactive runs. Before this PR it happened silently, so it is not a regression. This PR now receives an explicit error code and still takes the shared path.
Suggested fix (both shells): when `URP_RC`/`$urpRc` is 3, skip the CLAUDE.md deploy and the rules deploy. Write the caller's own outcome row, e.g. `write_summary ERROR "claude.md" "not deployed: dotprofile unresolved"` (an ERROR row, not an ACTION, so the wrapper's ACTION stays the only one). Keep the shared fallback for rc 1 only.

**M2. Reverse tokenization replaces a value that is a substring of a later value, corrupting the dotprofile template on adopt.** `scripts/setup-user-claude.sh:185-195`, `scripts/setup-user-claude.ps1:186-197`.
The order is fixed (USER_REPO_PATH, PROFILE_NAME, PROFILE_COMPANY, IDENTITY_GIT_NAME, IDENTITY_GIT_EMAIL). When one value contains another, the shorter one is replaced first and breaks the longer one's token. The live dotprofile has exactly this: profile `workstation` has company `nobul.tech`, and the git email is `jose@nobul.tech`. Smoke case E uses that data shape. After accept & adopt on that machine:
```
template: - Git: {{IDENTITY_GIT_NAME}} <jose@{{PROFILE_COMPANY}}>
other machine (company nobul-tech) renders: - Git: Jose <jose@nobul-tech>
```
So a wrong email reaches every other machine. The live template already contains `nobul-{{PROFILE_NAME}}/aitools` at `aitools-nobul-jose/claude/CLAUDE.md:42-43`. That looks like the same blind global replace on an earlier adopt; I did not trace its history. The order on main is the same for the four old tokens, so this is not a regression. The PR rewrote this filter, and P-Q13 only decides the same-text tie.
Suggested fix (both shells): replace in descending value length. Equal values keep the P-Q13 tie-break, so PROFILE_NAME comes before IDENTITY_GIT_NAME, with USER_REPO_PATH and the rest after them. Add a managed-files test case with a value that is a substring of another value.

## Minor

**m1. The footer hostname falls back to `uname -n` on macOS, contrary to P-Q5.** `scripts/setup-user-claude.sh:84-99`. P-Q5 says to use only the scutil name and to remove scripts that take hostnames from DNS. The resolver does not fall back on macOS: when scutil fails it records an error (`scripts/aitools-profile.sh:325-327`). The script shows the kernel/DNS name instead (e.g. "Mac"). The resolver also already emits a `hostname` result line, which the lib does not expose. Suggested: show `unknown` on scutil failure now, and use an `AITLIB_MACHINE_HOSTNAME` / `$script:AitLibMachineHostname` result once lib batch 3 lands, which removes this second copy of the detection. Nit: the resolver lower-cases the name (`short_host`) and the footer does not.

**m2. The MDM path diverges further.** `scripts/build-deploy.sh:319-322,343,381` still use `hostname -s`, the old footer and build-time interpolation, and do not handle `{{USER_REPO_PATH}}`. `.claude/rules/deploy-paths.md` requires the two paths to be equivalent. This is the known M3 B5 deferral (pre-commit step 13 WARN), so it is not a blocker. Name it in the PR's Follow-ups.

**m3. Documentation drift in protected files.** These need drafts, not edits on this branch:
- `reference/user-repo.md:175-176` still lists four tokens. `{{USER_REPO_PATH}}` is in the R18 draft (`S4-Review-drafts/reference/user-repo.md:262-264`), which lands in batch 8.
- `.claude/rules/managed-file-deployment.md` "Content sources" still says "Machine profile selection: config.json machineAlias -> profile.json profiles[alias]. Fallback: hostname match, then first profile". This PR removes that behaviour, so the rule now describes code that no longer exists.

**m4. The logging audit left unchecked operations in the rules block.** These are pre-existing:
- bash `mkdir -p "$RULES_DEST"` (`setup-user-claude.sh:319`) exits under `set -e` with no summary row.
- PowerShell `New-Item ... $rulesDest` (`setup-user-claude.ps1:336`) has no `-ErrorAction Stop` and is unchecked.
- PowerShell `Get-ChildItem -ErrorAction Stop` (`:291`, `:297`, `:325`, `:392`) is not in try/catch, so the script ends with no summary row.

This PR fixed the same pattern for `~/.claude` (sh:59-63, ps1:53-59). These lines sit inside the `rules deploy logic` markers, so a fix also reaches the MDM script.

## Nit

- n1. Dry run writes no summary row for claude.md (smoke case F: the summary is empty) in either shell (sh:199-221, ps1:201-225). Pre-existing. script-standards says every code path calls write_summary.
- n2. A value that contains token text is substituted twice: name `{{PROFILE_COMPANY}}` rendered as `ACME` (smoke case G). Both shells do the same (sh:148-152, ps1:136-138). It is an edge case. A single-pass regex alternation would fix it.
- n3. The PowerShell footer has no arch (ps1:166). R18 lists "OS, arch, hostname, the resolved profile alias, and shell". Pre-existing.
- n4. bash creates `~/.claude` in a dry run (sh:59) and PowerShell does not (ps1:52). Pre-existing parity gap.
- n5. `$AITLIB_USER_REPO_VIA` / `$script:AitLibUserRepoVia` is read after the second wrapper call (sh:82, ps1:79), not copied right after its own call. It is harmless today but goes against the stated copy-after-call rule.

## Verified clean

- The contract names are right in both shells, values are copied right after each call, and the scripts add no ACTION rows (grep finds `ACTION` only in comments). There are no `config.json`/`profile.json`/`machineAlias`/`node` reads left. The PowerShell `$machineAlias` is the caller's own copy.
- rc 0/1/3 for the machine profile: 0 gives the profile values and an OK row. 1 gives WARN "template tokens unresolved". 3 gives identity-level values only, the wrapper's ERROR and one ACTION, no values from another machine, and footer "profile unresolved". The run exits 1. Smoke cases A, B and D confirm this.
- Literal safety: values with `&`, `$HOME`, `\1`, `$1`, `@`, `/`, `$(echo pwned)` and backticks come out literally. Smoke case A was run in bash 5.3.15 and /bin/bash 3.2.57. PowerShell uses `String.Replace`, which is literal (read, not run).
- Adopt round trip: with the dotprofile under HOME, the repo line renders as `~/repos/aitools-x`. Adopt restores `{{USER_REPO_PATH}}` and every token, and the next run is `verified` (smoke H1-H3). P-Q13 order is present in both shells.
- Counters and summaries: `_claude_errs_before` correctly keeps resolver errors out of "validation failed". Every new exit path writes an ERROR row. The rule read failure now goes through log_error and tracker `failed`, and a push failure gets a WARN row. The only `2>/dev/null` lines (sh:353, sh:361, merged-rule push) are pre-existing and commented, and their result is checked through the if/else.
- The build-deploy markers are identical to main in both files (10 marker lines each). The new code inside the rules block works in the generated script: `${USER_REPO_PATH:-}` is guarded and `deploy_tracker_record` is inlined.
- The lib files are identical to #80 head `28e0f5b`: `git diff origin/feature/m3-b2-lib-wrappers -- scripts/aitools-lib.sh scripts/aitools-lib.ps1` is empty.

## Commands run (macOS, isolated HOMEs under `.scratch/session-ClRev/`)

| Command | Result |
|---|---|
| `bash -n` / `/bin/bash -n scripts/setup-user-claude.sh` | rc 0 / rc 0 |
| pwsh `Parser::ParseFile` on `setup-user-claude.ps1` | clean |
| `tests/managed-files/test-managed-files.sh` (bash 5.3 / /bin/bash 3.2) | 42 passed 0 failed / 42 passed 0 failed |
| `tests/managed-files/test-managed-files.ps1` | 24 passed 0 failed |
| `tests/profile/test-lib.sh` (bash 5.3 / /bin/bash 3.2) | 108 passed 0 failed / 108 passed 0 failed |
| smoke A-H (fixture dotprofiles, `AITOOLS_USER_REPO_PATH`, `AITOOLS_PROFILE_TEST_MACHINE_ID`, unmatched `AITOOLS_PROFILE_TEST_HOSTNAME`, PTY for adopt), in bash 5.3 and /bin/bash 3.2 | identical results, as quoted above |
| `gh pr checks 83` | all pass (linux, macos, windows, CodeQL) |

Not run: `setup-user-claude.ps1` end to end (it has a Windows-only OS guard). The PowerShell findings come from reading the code and parallel the bash smoke results. `build-deploy.sh` was not run (it writes the dotprofile `deploy/`).

Observation outside #83's scope, for #80/resolver: in case C both wrappers log the same "AITOOLS_USER_REPO_PATH does not exist" error. The ACTION "pick or register this machine's profile" is misleading when the cause is a bad dotprofile path.
