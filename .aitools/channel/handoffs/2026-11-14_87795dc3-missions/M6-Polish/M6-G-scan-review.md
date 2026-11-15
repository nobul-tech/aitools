# M6-G scan review v1.0 (2026-11-14)

**Intent**: **Purpose**: Record, hit by hit, the hand review of the secret and
personal-data scan over the 264 files harvested on 2026-11-14, so an
independent reviewer can re-check every classification. **Scope**: The scan
method, the per-file checks, every hit (file, line, pattern class, verdict,
reason). NOT the hit values (none are reproduced here). NOT the June 2026
files (not scanned). **Audience**: M6-Polish, the independent reviewer, the
commander.

Author: M6-G (delegated by M6-Polish). PR: nobul-tech/aitools#153, branch
`docs/m6-harvest`, head `45b091753b38b4203d91e74216d2b9d7693c34a5`.

## Method

- File list: `git -C C:/Users/jdpal/repos/aitools status --porcelain --untracked-files=all -- harvesting`, untracked names starting `harvesting/2026-11-14_`: **264** files. June files (`2026-06-21_*`, `2026-06-22_*`): **31**. Other untracked: 0.
- Scanner: a Perl script in M6-G's scratch (`.scratch/session-M6-G/scan.pl`, not committed). Per file: size (flag > 1 MB), binary (NUL byte), UTF-8 validity, then for every line the pattern classes below. Needles came from the dotprofile `profile.json` (hostnames, machine aliases) and `~/.aitools/config.json` (Drive paths and Drive accounts), plus generic Drive and `profile.json` key markers; the needle list stays in scratch.
- Control: a file with one fake value per pattern class was scanned first; every class fired.
- Second pass: a wider keyword scan (`token`, `secret`, `passw`, `credential`, `auth`, `cookie`, `private`, `.pem`, `.key`, `ssh-rsa`, `BEGIN `, `api-key`, `bearer`, `oauth`, `client_secret`, `webhook`, Slack/Discord webhook URLs, `xox?-`, `AIza...`, `phone`, `address`, `birth`, `ssn`, `passport`, `salary`, `account`). Every match was read: code and prose only, no credential or personal value.
- Accepted email identities (the commit identities in this repo's history, `git log --all --format=%ae%n%ce | sort -u`): 5 addresses; any other address is a hit.
- After copying, the scan was rerun on the 264 copies in the worktree: identical hit list.

## Per-file checks

| Check | Result |
|---|---|
| Size > 1 MB | 0 files (largest 237,062 bytes) |
| Binary (NUL byte) | 0 files |
| Not valid UTF-8 | 0 files |
| Empty | 1 file (`2026-11-14_session-M5-L2_eof-out.txt`, 0 bytes; harmless) |

## Hits by class

| Class | Hits | Real | False positive |
|---|---|---|---|
| GitHub token / prefix, `sk-` / `sk-ant-`, AWS key / secret, private-key block | 0 | 0 | 0 |
| Authorization, Bearer, password, passwd, secret, token, api_key, .netrc, connection string | 0 | 0 | 0 |
| Phone | 0 | 0 | 0 |
| IPv4 | 2 | 0 | 2 |
| Email (not a commit identity) | 5 | 0 | 5 |
| Needle | 44 | 0 | 44 |
| Hex >= 32 | 51 | 0 | 51 |
| High entropy >= 32 | 9 | 0 | 9 |
| **Total** | **111** | **0** | **111** |

## Every hit

File names are under `harvesting/`, prefix `2026-11-14_` omitted.

### IPv4 (2)

| File | Line | Verdict | Reason |
|---|---|---|---|
| session-M3b-C2_pty-merge-probe.ps1 | 21 | FP | loopback address in a `ping` delay of a fake `claude.cmd` fixture |
| session-M3b-C2_tcommon.ps1 | 29 | FP | same loopback `ping` delay |

### Email (5)

| File | Line | Verdict | Reason |
|---|---|---|---|
| session-M3b-C1_origin-aitools-lib.ps1 | 4402 | FP | public PyPI maintainer contact in a code comment of a copy of `scripts/aitools-lib.ps1`; the same comment is tracked in `scripts/aitools-lib.ps1` (`git grep` count 1) |
| session-M3b-C2_lib-nofinally.ps1 | 4579 | FP | same comment, another copy of the library |
| session-M3b-C2_origin-aitools-lib.ps1 | 4402 | FP | same comment |
| session-M3b-R_aitools-lib.ps1 | 4290 | FP | same comment |
| session-M4-E_time-build.sh | 14 | FP | fixture `git -c user.email=...` address in the RFC 2606 reserved `.invalid` domain |

### Needles (44)

No hostname, Drive path or Drive account needle matched any file.

| File | Line(s) | Needle class | Verdict | Reason |
|---|---|---|---|---|
| 1_session-M5-Fixes_pr-body.md | 13 | machine alias word | FP | prose "the commander's workstation"; generic word |
| session-M2-Reask_M2-Reask-Inv-inventory.md | 63, 137 | machine alias words (2 each) | FP | quotes the existing user-init prompt text `New alias (e.g., ..., ...)`, which is in tracked `scripts/aitools` / `scripts/aitools.ps1` |
| session-M3b-C1_origin-aitools.ps1 | 1134 | machine alias words (2) | FP | the same prompt string in a copy of `scripts/aitools.ps1` |
| session-M4-Winpty_pr-body.md | 50, 107, 114 | machine alias word | FP | prose "on the workstation"; the body of PR #148 in this public repo |
| session-M4-Winpty_run-local-verify.ps1 | 1 | machine alias word | FP | comment "on this workstation" |
| session-M5-D2_pr-144.json | 1 | machine alias word | FP | prose in public PR #144 body |
| session-M5-D2_pr-148.json | 1 | machine alias word | FP | prose in public PR #148 body |
| session-M1-Ship_M1-Ship-pr-body.md | 7 | dotprofile repo name | FP | repo name; already in many tracked files (`git grep` across `.aitools/`, `plans/`, `reference/`, `tests/`) |
| session-M3-A_build-deploy-iso.sh | 9 | dotprofile repo name | FP | local clone path (`/c/Users/<user>/repos/...`); usernames in paths are accepted (commander, delegation prompt) |
| session-M3-B_M3-Fixes-B-evidence.md | 20, 79 | dotprofile repo name | FP | same: repo name and local path |
| session-M3b-V_M3b-Finish-V-results.md | 114 | dotprofile repo name | FP | same |
| session-M4-D_build.sh | 7 | dotprofile repo name | FP | local path |
| session-M5-C2_run-postpush-isolated.sh | 11 | dotprofile repo name | FP | local path |
| session-M5-D2_pr-145.json | 1 | dotprofile repo name | FP | public PR #145 body (`<github-user>/<repo>` with two commit SHAs) |
| session-M3b-C1_origin-aitools.ps1 | 479 | Drive marker | FP | `--skip-drive-detection` help text in a copy of `scripts/aitools.ps1` |
| session-M3b-C1_origin-aitools.ps1 | 1026, 1027, 1694, 1695 | `profile.json` key marker | FP | code reading `identity.git.name` / `.email` keys (no values) |
| session-M3b-C1_origin-aitools.ps1 | 1071-1075 | `profile.json` key marker | FP | code iterating `profiles` keys (no values) |
| session-M3b-C1_origin-aitools.ps1 | 1287, 1749 | `profile.json` key marker | FP | code variable/argument names `machineId` / `MachineId` |
| session-M5-L2_mutant-install.sh | 65, 496, 498, 508, 509, 511, 512, 515, 519, 520, 521 | Drive marker | FP | Drive-detection code, comments and log messages of a copy of `scripts/aitools-install.sh` (generic glob `GoogleDrive-*`, no account or path value) |

### Hex >= 32 (51)

Verified by script (`verify-hex.pl` in scratch): 51 explained, 0 unexplained.

| File | Line | Count | Verdict | Reason |
|---|---|---|---|---|
| session-M3b-V_M3b-Finish-V-results.md | 3 | 1 | FP | 40-hex commit SHA, `git cat-file -e <sha>^{commit}` succeeds in this repo |
| session-M4-D_build.sh | 30 | 8 | FP | 64-hex PyPI wheel sha256 pins, each present in tracked `scripts/requirements-pywinpty.txt` |
| session-M5-D1_close-173.py | 27, 62 | 2 | FP | commit SHA (verified) |
| session-M5-D2_pr-143.json | 1 | 4 | FP | commit SHAs of public PR #143 (verified) |
| session-M5-D2_pr-144.json | 1 | 4 | FP | commit SHAs of PR #144 (verified) |
| session-M5-D2_pr-145.json | 1 | 5 | FP | commit SHAs of PR #145 (verified) |
| session-M5-D2_pr-146.json | 1 | 11 | FP | commit SHAs of PR #146 (verified) |
| session-M5-D2_pr-147.json | 1 | 5 | FP | commit SHAs of PR #147 (verified) |
| session-M5-D2_pr-148.json | 1 | 11 | FP | commit SHAs of PR #148 (verified) |

### High entropy >= 32 (9)

| File | Line | Verdict | Reason |
|---|---|---|---|
| 2_session-M5-Fixes_pr-body.md | 18 | FP | path `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/` |
| session-M2-D2_make-fake-ui.pl | 17 | FP | path `.scratch/session-M2-D1/fake-pty-run.py` |
| session-M2-D2_make-fake.pl | 31 | FP | same path |
| session-M4-Winpty_pr-body.md | 40 | FP | mission report path |
| session-M5-D2_pr-148.json | 1 | FP | the same mission report path, 3 occurrences |
| session-M5-Fixes_pr-body.md | 26 | FP | mission report directory path |
| session-M5-L1_wait-suites.sh | 4 | FP | Claude Code task output path under the user's temp dir (username path, accepted; session id not secret: it names public handoff folders) |

## Other observations (not hits)

- The six `pr-14x.json` files are `gh pr view --json` exports of public PRs: they contain the GitHub login, the commit email already public in this repo's history, and the account's public GraphQL node id. Public data; kept.
- The two `dot-commit-msg*.txt` files are the commit messages of two dotprofile commits (gitignoring `deploy/`); they describe the change only, no profile content.

## Verdict

264 files cleared, 0 excluded. No real or inconclusive hit.
