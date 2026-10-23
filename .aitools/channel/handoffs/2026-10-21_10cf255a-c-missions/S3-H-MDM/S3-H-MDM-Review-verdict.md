VERDICT: CHANGES REQUESTED (3 blocking)

# S3-H-MDM-Review: independent review of PR #93 (commit dd562f6)

Reviewer: S3-H-MDM-Review (level-3 delegate, read-only). Scope: the dd562f6 diff (`scripts/build-deploy.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`) and the generated output. #88 and #87 were not reviewed. Line numbers refer to the worktree at dd562f6.

## What I verified myself (macOS, isolated HOMEs only)

- `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` returned **26 passed, 0 failed, 0 skipped**. This reproduces the PR's claim.
- Independent equivalence check. I built from a `git archive HEAD` copy of the repo into a fixture dotprofile with awkward rule names: `it's a rule.md` (a quote and a space), an empty file, a file with no trailing newline, a CRLF file, a file containing `$HOME`, a backtick and a backslash, and `café.md`. Dev and MDM results:
  - all six directories identical; summary rows identical; both exit 0; `136 added`
  - the same under macOS `/bin/bash` 3.2.57 for both the build and the run; only the `config.json.bak.<timestamp>` names differ
  - an MDM dry run took about 6.4 s
- The extraction guards hold. A reworded `# 3.` heading fails the build (exit 1, `start /^# 3\. The six directories/ matches 0 lines`). A reworded adopt line fails `replace_once` (exit 1).
- Observation, not a finding: CRLF source rules are deployed LF-normalised on both paths. This is library behaviour, the same on dev and MDM.

## Blocking

**B1. Embedded payload integrity is never checked, so a corrupted block deploys wrong content with an OK row and exit 0.**
- Evidence:
  - Each block's size and sha256 are written only as a comment (`scripts/build-deploy.sh:1670`).
  - `mdm_unpack` (`:1742`) and `Expand-MdmPayload` (`:1856`) decode whatever is there. `decode_base64` and `FromBase64String` accept arbitrary content.
  - `MDM_EMBEDDED_FILES` and `$mdmEmbeddedFiles` (`:1779`, `:1902`) are only logged and never compared with the number of files unpacked.
- Repro: I replaced the base64 of `dotprofile/claude/rules/dollar.md` in a generated copy with `QUJD`. The run returned exit 0 and `OK|harness files|136 added`, and `~/.aitools/rules/dollar.md` contained `ABC`.
- Why it matters: a 2.2 MB script passes through MDM upload, transport, git eol handling and possible hand edits. A file truncated inside a heredoc warns, and the bash script then ends with no deploy and possibly exit 0. Shipping wrong content silently goes against "no silent failures" (script-standards.md). The generated header (`:1695-1697`) also presents size and sha256 as if they protect the payload.
- Fix:
  - Pass the size and sha256 to `mdm_unpack` / `Expand-MdmPayload`. Verify after decoding: `Digest::SHA` in perl, `[Security.Cryptography.SHA256]` in PS1.
  - On a mismatch, log_error and count it as not unpacked. That already gives the ERROR row and exit 1.
  - Compare the number unpacked with `MDM_EMBEDDED_FILES`.
  - Optionally add an end-of-script sentinel check, so a truncated script fails instead of exiting 0.

**B2. The MDM deploy-harness is not self-contained as its header claims, and it exits 1 on every fresh endpoint.**
- Evidence:
  - The header says "Self-contained … No repo, dotprofile checkout or git is needed" (`:1695-1697`).
  - Section 1, copied from the dev path, runs `$SCRIPT_DIR/setup-user-config.sh`. That needs the siblings `setup-user-config.*`, `aitools-profile.*` and `aitools-json.*` (`:1484-1515`), plus bootstrap values in an existing `~/.aitools/config.json` (`scripts/setup-user-config.sh:245-271`).
- Repro: I ran the generated script with an empty HOME, which is what a fresh MDM endpoint looks like. It exited **1** with:
  - `ERROR|aitools config|missing bootstrap values`
  - `ERROR|harness files|config.json not generated`
  - `OK|harness files|136 added`
- The harness files deploy correctly, but Jamf and Intune report the script as failed on every first run. If the script is uploaded as a single file (the default for Jamf and Intune scripts), the writer is missing and the run still ends in ERROR and exit 1. How deploy/ is shipped to endpoints is unknown to me.
- The PR lists this as "the writer's contract (M3)". The dev path never meets this input, because the installer always runs first. "Equivalent results" therefore does not cover the normal MDM case.
- Fix: the commander decides. Suggested answer: in the MDM variant only, when `~/.aitools/config.json` is absent or has no bootstrap keys, skip the writer with an OK row `n/a (no bootstrap)`. This is the same shape as `write_environment_skip`. Also state in the header that deploy/ ships as a directory.
- Minimum fix if the commander keeps the ERROR: make the header and `deploy-paths.md` draft honest. Say that deploy/ must ship as a directory, that the installer bootstrap is required, and that exit 1 is expected without it.

**B3. A Windows build of deploy-harness is likely to fail, or to produce different output. (Reasoned, not run: I have no Windows host.)**
- build-deploy.sh runs on Windows in Git Bash (approved cross-language exception). It expects Strawberry Perl (`:36-39`).
- (a) Paths inside the manifest are MSYS paths written by bash:
  - `$lsf` = `$MDM_TMP/ls.N` from `mktemp -d`, i.e. `/tmp/...` (`:1615`)
  - `$SCRIPTS_DIR/<cli>`, i.e. `/c/...` (`:1651`)
  - MSYS converts command-line arguments for native programs, but not file contents. So native Strawberry Perl's `open` in `mdm_emit_payload` (`:1666`) gets `/tmp/tmp.X/ls.1` and should die with "cannot read", and the build exits 1.
  - Paths passed as arguments (`mdm_snapshot_dir`'s `$dir`) are converted, so they work.
- (b) Executable bits come from `-x $src` (`:1627`) and `[ -x ]` (`:1650`).
  - On Win32 Perl, `-x` reflects the file extension (.exe/.bat/.cmd/.com), not the git mode, and MSYS `[ -x ]` reflects the shebang.
  - A deploy-harness.sh built on Windows therefore embeds exec=0 for `100755` files. macOS endpoints would then get non-executable files where the dev path sets +x.
  - The committed deploy/ would also differ depending on which machine built it, so pre-push step 7 would flip between machines.
- Fix:
  - (a) Keep every path the perl side reads in perl's own arguments, or run them through `cygpath -m` on MINGW/MSYS before writing the manifest.
  - (b) Take the exec bit from `git ls-files -s -z` (mode `100755`), which is the platform-independent source of truth. Keep `-x` only for the non-git fallback, with the existing warning.
  - Add a Windows run of the test to the "Not run" list until someone runs it.

## Non-blocking

**N1. The .sh/.ps1 source-directory parity check only compares counts** (`:1557-1567`). Repro: I changed `.ps1` line 239's `registries` to `registriesX`, with the same count. The build returned exit 0, and the MDM .ps1 embeds the .sh's directories while the dev .ps1 reads different ones. Fix: also parse the `.ps1` `-SrcDir (Join-Path …)` chains, normalised to `aitools|dotprofile<TAB>rel`, and compare the lists.

**N2. deploy/ now depends on many more paths, and pre-push step 7 does not watch them.**
- The new dependencies:
  - `reference/`, `registries/`
  - `.claude/{rules,skills,hooks}/`, `shared/rules/`
  - `scripts/deploy-harness.*`, `scripts/aitools-profile.*`, `scripts/aitools-json.*`
  - `scripts/harness-db.py`, `scripts/read-session*.py`
  - the dotprofile's rules
- The step 7 trigger (`scripts/check-pre-push.sh:114`) watches only `setup-*`, `build-deploy`, `aitools-lib` and `shared/`. So the MDM snapshot goes stale silently. The PR lists this as a follow-up.
- Widening the trigger has a cost: `registries/` and `reference/` change in most commits, so step 7 would fail on most pushes until the dotprofile is rebuilt.
- Staleness policy is the commander's call. Suggested answer: widen the trigger, and make step 7 report a stale `deploy-harness.*` as a WARN naming the rebuild command. Keep FAIL for the extracted-logic scripts.

**N3. Size.** The generated `deploy-harness.sh` is 2,228,939 B and `.ps1` 2,259,347 B (S3-H-MDM's scratch build). Both are committed to the dotprofile and rewritten whenever any harness file changes.
- Intune's PowerShell platform-script size limit: I believe it is about 200 KB, but that is unverified, so check it with the chrome-devtools skill. Existing deploy scripts already exceed it (for example `setup-user-skills.ps1`, 322 KB).
- Whether Defender/AMSI flags a large base64 payload that writes to a temp directory: unknown.
- Neither is new in kind, but this PR makes both about 7x worse.

**N4. A failed build leaves a partial deploy/.** Repro: with the heading reworded, the build exits 1 and leaves 49 files, including a truncated `deploy-harness.sh` that still runs (config writer plus unpack, then exit 0 with nothing deployed). The cause is the existing `rm -rf "$DEPLOY_DIR"` before generation (`:260`), but the new cut points add failure modes. Suggest generating into a temp directory and swapping it in on success.

**N5. The MDM header drops the dev header's managed scope.** The `Managed:` / `Name conflicts` / `Preserved:` / `Overwrites:` block (`scripts/deploy-harness.sh:15-29`) is missing from the MDM header (`:1692-1717`), although config-file-safety.md asks for the managed/preserved scope in the header. This PR fixed the same drift for setup-user-cursor with `extract_span`. Do the same here (`'^# Managed \(' '^# Usage:'`).

**N6. The working tree is embedded.** Uncommitted edits in aitools or the dotprofile end up in a committed, distributed artifact. The dev path reads the working tree too, but there it is not shipped. Suggest a `blog_warn` when `git status --porcelain -- <dir>` is non-empty for a snapshotted directory.

**N7. `errf=$(mktemp)` in `extract_span` is unchecked** (`:309`). If mktemp fails, the redirect error hides the real extraction message. This is a minor script-standards point (a critical operation without a check).

## Claims not independently verified

- The generated .ps1 on Windows; the .ps1 `finally` cleanup on `exit 2`. My .ps1 coverage is only the test's pwsh pair case, which passed.
- The PR's "132 added on real repo content" run. My fixture run gives 136, which is consistent with 6 fixture rules.
