# M6-G report v1.0 (2026-11-14)

**Intent**: **Purpose**: Report mission M6-G: today's harvested artifacts
scanned for secrets and personal data, the cleared files committed to the
public repo in their own PR, and the evidence for each step. **Scope**: The
264 `harvesting/2026-11-14_*` files, the scan, the copy and hash check,
pre-commit, the PR and its CI. NOT the June 2026 files (listed only). NOT
the harvest manifest. **Audience**: M6-Polish (orchestrator), the
independent reviewer, the commander.

Author: M6-G, delegated by M6-Polish (level 2) under Session Commander
87795dc3-e. This file and `M6-G-scan-review.md` are written, not committed
(the harvest PR carries harvested artifacts only); the orchestrator commits
them.

## Summary

1. 264 files listed (`2026-11-14_*`, untracked in the main checkout), 264 committed, 0 excluded.
2. Perl scan (secrets, keys, credentials, connection strings, phones, IPs, emails outside the 5 public commit identities, dotprofile needles, hex and high-entropy strings; size, binary, UTF-8): 111 hits, all false positives after hand review; a control file proved every pattern fires.
3. Copies are byte-identical (SHA-256, 264/264); the rescan of the copies gives the same hits; 89 `.sh` staged at 100755 (repo convention).
4. check-pre-commit.ps1 (no -Fix): 10 PASS, 6 SKIP, 3 WARN, 0 FAIL.
5. PR https://github.com/nobul-tech/aitools/pull/153, branch `docs/m6-harvest`, head `45b091753b38b4203d91e74216d2b9d7693c34a5` (parent `846ab24`); CI: run "CI" success (linux, macos, windows), CodeQL success.

## Counts

| Item | Count |
|---|---|
| Listed (`2026-11-14_*`) | 264 |
| Committed | 264 |
| Excluded | 0 |
| June files left untracked (not scanned) | 31 |
| Other untracked harvesting files | 0 |

By extension: 118 `.ps1`, 89 `.sh`, 18 `.py`, 18 `.md`, 8 `.pl`, 6 `.json`, 4 `.txt`, 1 `.js`, 1 `.diff`, 1 `.tsv`.

## Scan and review

Method, every hit and its verdict: `M6-G-scan-review.md` (same directory). Summary by class:

| Class | Hits | Cleared as |
|---|---|---|
| Tokens/keys (GitHub, `sk-`, `sk-ant-`, AWS, private key), Authorization/Bearer, password/secret/token/api_key, .netrc, connection strings, phone | 0 | none |
| IPv4 | 2 | loopback in a test fixture |
| Email outside commit identities | 5 | 4 public PyPI maintainer contact in copies of `scripts/aitools-lib.ps1` (already tracked there); 1 `.invalid` test address |
| Dotprofile needles | 44 | no hostname/Drive path/Drive account matched; generic alias words in an existing prompt string and prose, the dotprofile repo name (already throughout the repo), profile.json key names in code, Drive-detection code |
| Hex >= 32 | 51 | 43 commit SHAs verified in the repo, 8 PyPI sha256 pins present in `scripts/requirements-pywinpty.txt` |
| High entropy | 9 | file paths |

Scratch evidence (worktree `.scratch/session-M6-G/`, not committed): `scan.pl`, `broad.pl`, `context.pl`, `verify-hex.pl`, `copy-verify.pl`, `list-nov14.txt`, `list-june.txt`, `scan-hits.txt`, `scan-files.txt`, `rescan/scan-hits.txt`, `hash-check.txt`, `precommit.log`, `commit-msg.txt`, `pr-body.md`, `control/`.

## Copy and hash check

- `copy-verify.pl` copied each file with `File::Copy` (source never moved or changed) and compared SHA-256 source vs copy: `files=264 copied=264 identical=264 errors_or_mismatches=0`; a verify-only rerun gives the same (`hash-check.txt`).
- Git blobs (`git ls-files --eol`): 261 blobs equal the file bytes; 3 are normalised by `.gitattributes` (`* text=auto eol=lf`): `2026-11-14_session-M3b-C2_lib-nofinally.ps1` and `2026-11-14_session-M3b-R_aitools-lib.ps1` (w/crlf, stored LF), `2026-11-14_session-M5-L2_trace.txt` (w/mixed, stored LF). Every `.ps1` checks out with CRLF (`*.ps1 eol=crlf`), so a fresh checkout's `.ps1` bytes differ from the LF originals; the content is the same.
- `harvest-manifest.json` is not staged or committed (gitignored, `.gitignore` line 63); `git diff --cached --name-only` equalled the 264-file list exactly before the commit.

## Exec bits (pre-commit step 6)

Step 6 (`scripts/check-pre-commit.ps1`) fails on any tracked `*.sh` not at 100755. Every tracked `harvesting/*.sh` on origin/main is 100755 and the index had no 100644 `.sh` (the "known pre-existing step 6 failure" is gone on this base). Followed the convention: `git update-index --chmod=+x --stdin` on the 89 harvested `.sh`; step 6 PASS.

## check-pre-commit.ps1

Run from the worktree, no `-Fix`, `AITOOLS_LOG_DIR` in scratch, after staging: 10 PASS, 6 SKIP, 3 WARN, 0 FAIL. Step 2 syntax (`.sh` and `.ps1`, all staged scripts parse) PASS; step 4 line endings PASS; step 6 PASS. WARN: step 5 platform note (in the commit message), step 9 release notes (out of scope), step 11 dotprofile has ` M profile.json` (pre-existing, not touched).

## CI

Head `45b091753b38b4203d91e74216d2b9d7693c34a5`, all 8 check runs completed (`gh api repos/nobul-tech/aitools/commits/<sha>/check-runs`, 2026-11-14T18:11Z):

| Run / job | Result |
|---|---|
| CI (https://github.com/nobul-tech/aitools/actions/runs/43622773084): linux | success |
| CI: macos | success |
| CI: windows | success |
| CodeQL | success |
| PR #153 code scanning (https://github.com/nobul-tech/aitools/actions/runs/43622770473): Analyze (actions, javascript-typescript, python, ruby) | success x4 |

No CI step tripped on a harvested file.

## June files (31, untracked, not scanned, not committed)

Prefix `harvesting/`:

- `2026-06-21_session-8f1728f5_`: `PROTECTED-CHANGES-FOR-REVIEW.md`, `diag-step32.py`, `dotprofile-commit-msg.txt`, `extract-plan-v1.py`, `final-verify.sh`, `full-fidelity.md`, `full-text.md`, `gh-issue-phase5.md`, `smoke-hooks.sh`, `test-step32.sh`, `test_ait_harvest.py`, `verify-adversarial.md`, `verify-coverage.md`, `verify-technical.md` (14)
- `2026-06-21_session-9vj7gwRVD8_`: `code-changes.md`, `investigation-findings.md`, `run-aitools-noargs.ps1`, `test-deploy-configs.ps1`, `test-deploy-realistic.ps1`, `test-deploy-with-diag.ps1`, `test-error-diagnostics.ps1`, `test-exit-code.ps1`, `test-fix.ps1`, `test-install.ps1`, `test-results.md`, `test-star-redirect.ps1` (12)
- `2026-06-22_session-cdded924-1_`: `.intelligence-last-check`, `events.jsonl`, `manifest-upstream.json`, `manifest-windows.json`, `merge-manifest.py` (5)

## Not run

- `check-pre-push`, `check-post-push` (no scripts/shared change).
- `ait-harvest.py` (no harvest, promote or prune); the manifest was not read or written.
- No content review of the June files.

## CONFLICT / WRITE_BLOCKED / INCIDENT

- CONFLICT: auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (commander's CLAUDE.md): Write/Edit/Read used for files; Bash for git, perl and gh only.
- CONFLICT: /harvest skill "Commit the artifact + manifest update" vs the commander's 2026-11-13 "gittinore the harvest manifest" (quoted in the prompt) -- resolved by tier 1: artifacts only.
- CONFLICT: /harvest steps that write outside the worktree (manifest edits, promotion) vs the prompt's access -- resolved by tier 2: skipped; only scan, copy, commit.
- Access deviation (recorded, not a conflict): read `~/.aitools/config.json` (read-only, first 22 lines) to take the Google Drive paths and Drive account emails as scan needles; the prompt asked for Drive paths as needles but `profile.json` holds none (it has no `googleDrives` and no machine ids). Values kept in scratch only.
- WRITE_BLOCKED: none.
- INCIDENT (candidate, not filed): the secondary Google Drive account email from `~/.aitools/config.json` (a non-commit-identity address) is already in tracked public files: `plans/user-repo-and-session-hooks.md`, `.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S2-Layout/inventory2.txt`, and several earlier `harvesting/` files including four `.tar` archives (`git grep -c` on origin/main). Not introduced by this PR. Suggested: commander decides whether it is acceptable; if not, remove it in a follow-up and consider history.

## Open questions

1. Commit the 31 June files too? Suggested: yes, in a separate PR after the same scan (they include `PROTECTED-CHANGES-FOR-REVIEW.md`, two manifest JSON copies and `events.jsonl`, which need a closer look).
2. Is the already-public secondary email (INCIDENT above) acceptable? Suggested: no; scrub it from tracked files in a follow-up PR (history rewrite only if the commander wants it).

## Operational learning

- Git Bash expands `$` inside double-quoted `perl -e` one-liners (`$c{$1}` became empty): use single quotes for Perl one-liners in the Bash tool.
- `perl -ne '... exit 0 ...; END { exit 1 }'` always exits 1: `exit` in an END block overrides the earlier exit code. Use `grep -q` for until-loops.
- `git update-index --chmod=+x --stdin` sets the bit for a list of paths in one call (pipe the list in); no `$(...)` needed.
- `git add --pathspec-from-file=<list>` stages an exact list without globs.
- On this base (846ab24) pre-commit step 6 passes: no tracked `.sh` is at 100644, so harvested `.sh` must go in at 100755.
