# S3-FanoutImpl-Harness hand-back (FO-2)

Delegate S3-FanoutImpl-Harness (level 2), for S3-FanoutImpl, under Session Commander 10cf255a-c. Date 2026-10-26/27 (UTC).

## Summary

1. deploy-harness.sh/.ps1 now collect skills from `shared/skills`, `.claude/skills` and `<dotprofile>/claude/skills` (first source wins, case-insensitive, ERROR row per duplicate) and write `~/.aitools/skills/.aitools-skills-manifest` every run.
2. #100's section 5b is generalised to both kinds: one planner and one writer take the kind. The listed-source bookkeeping is per kind (`<kind><TAB><label>`).
3. A retired skill's directory is backed up with `backup_dir` / `Backup-Dir`. The script finds the new `<name>.bak.<UTC>` directory and compares it with the directory before removing anything; a failure is log_error + ERROR row and the directory is kept.
4. tests/deploy-harness: 113 passed, 0 failed (bash 5 and /bin/bash 3.2). The new skills sequence runs on .sh and .ps1, and their traces are identical. A mutation test showed the parity check fails when it should.
5. CI is red on linux and macos for one reason that is not this PR's: build-deploy's 200,000-byte gate on `deploy/deploy-harness.ps1`. The base is already at 202,519 B; with this PR it is 210,015 B. A decision is needed (see open questions).

## PR

- https://github.com/nobul-tech/aitools/pull/119 (base `main`)
- Branch `feature/fanout-harness-skills`, head `f0e2c7d0ad5bdd0b6ee0b080c20af4e2a66c8c08`, one commit on `feature/fanout-base` d7f6855
- Review diff: `git diff d7f6855...f0e2c7d`
- CI note posted: https://github.com/nobul-tech/aitools/pull/119#issuecomment-6432095476

## Files changed

- `scripts/deploy-harness.sh`
- `scripts/deploy-harness.ps1` (CRLF kept: 709 CRLF, 0 LF lines)
- `tests/deploy-harness/test-deploy-harness.sh`
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`: the fixture dotprofile gets one skill, and two checks are added. These prove the new source is embedded by the MDM generator. The generator itself needed no change.
- `scripts/build-deploy.sh`: not changed. Its add_source / Add-Source parsers accept the new line, and parity holds.

## Manifest format shipped (contract 3.2)

```
# aitools skills manifest v1
<skill name><TAB><source>
```

- Path: `~/.aitools/skills/.aitools-skills-manifest` (`%USERPROFILE%\.aitools\skills\...`).
- Encoding: UTF-8, LF, no BOM.
- Sort order: by name, byte order (sh) / ordinal (ps).
- Sources: `shared` | `aitools` | `dotprofile` | `retired`.
- Name: the directory name as found on disk. A valid name matches `\A[^/\\.][^/\\]*\z` and has no `.bak.` (the same rule as FO-1's skills reader).
- An invalid line in the previous manifest is warned (`line ignored: ...`) and dropped. A previous manifest with another header gets a warning, nothing is retired, and the file is rewritten.
- Retire: a name in the previous manifest that no source has this run, and only when a source of the same kind for that name's source was listed this run. Otherwise the line is `keep` (source unchanged).
- Labels: `shared/skills`, `.claude/skills`, `dotprofile/skills`. The rules labels are unchanged (`shared/rules`, `.claude/rules`, `dotprofile`).
- Retired skill rows and messages: DETAIL row `retired: skills/<name>`; on failure ERROR row `retire failed: <name>`; ERROR row `skills manifest not written`. Log lines: `Retired skill: <name> (was <src>; ...)` and `Skills manifest: <name> kept as <src> ...`.
- A file or symlink at a retired skill's name: log_warn, left alone.
- Preserved scan: skips both manifests (and their `.tmp`) and every path with a `*.bak.*` component.

## Contract change

None to section 3.2. One implied addition: skill directories that fail the name rule (`.*`, `*.bak.*`) are no longer deployed into `~/.aitools/skills`. Before this PR they were. Now every deployed skill has a manifest line.

## Verification

- `bash tests/deploy-harness/test-deploy-harness.sh`: 113 passed, 0 failed, 0 skipped. The base had 76 passed (`.scratch/session-fohar/base-dh.log`).
- The same suite with `/bin/bash` 3.2.57 first on PATH: 113 passed.
- Mutation: `retired: skills/` changed to `skillz/` in the .ps1 made 2 checks fail (the ps1 retire check and the parity check). Reverted.
- `tests/deploy-harness-mdm` on the base before any change: 10 passed, 54 failed. All 54 failures come from the build stopping at the size gate (202,519 B).
- `tests/deploy-harness-mdm` with my change and the gate raised to 900000 in the worktree only (reverted; `git status` clean apart from my 4 files): 65 passed, 1 failed (only "scripts under the Intune limits").
- `bash -n` on the changed .sh files: OK. PowerShell parser on deploy-harness.ps1: OK.
- `check-pre-commit`: 11 PASS, 4 WARN, 1 FAIL. The FAIL is step 6, known (`harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` 100644).
- `check-pre-push`: 5 PASS, 4 WARN, 1 FAIL. The FAIL is step 7 ("rebuild into a dotprofile copy failed (exit 1)"), consistent with the size gate. Step 7 was a known FAIL in any case.
- CI on PR #119: windows passed, CodeQL passed. linux and macos failed in `tests/claude-mdm`, on the build-deploy size gate (210,015 B). Later steps were skipped.

## Not run

- Windows: no Windows machine in this session.
- `check-post-push`: never run before merge.
- tests/deploy-harness* in CI: FO-0 (S3-FanoutImpl-CI) adds those steps.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: the generated `deploy/deploy-harness.ps1` is over build-deploy's FAIL gate of 200,000 bytes on the integration base (202,519 B, d7f6855). `tests/claude-mdm` in CI therefore fails for every branch built on the base, and MERGE-ALL's merged main will fail too. The inlined `aitools-lib.ps1` is 166,024 B of it. Related: RECONCILE item #211 (`S3-Reconcile-Fix-Code-items.md` "#211").
- INCIDENT (low): `backup_dir` / `Backup-Dir` return no result. They also skip, silently, a directory without a top-level `*.md` (`scripts/aitools-lib.sh` `backup_dir`, the `file_count` check). `Backup-Dir` prunes with `-Path` (wildcards), so a name with `[ ]` can break pruning. deploy-harness works around the first two by verifying the backup itself.

## Open questions (with suggested answers)

1. The size gate: what makes CI green for FO-2 and every later FO batch? Suggested: move the inlined library out of `deploy-harness.ps1` into `deploy-harness.payload`, as #111 did for the snapshot. Until then, make the gate a WARN, as #211 suggested. This is a build-deploy change by whoever owns it (MERGE-ALL fix-forward or a new FO batch), not FO-2.
2. Removing the last dotprofile skill (git drops the empty `claude/skills`) makes that source "not found", so its skills are kept, not retired. Dotprofile rules behave the same way (#100 contract). Suggested: keep it, and document it in FO-7 skills.md. Alternatively, treat "dotprofile present, `claude/<kind>` absent" as listed with zero names, which would retire them.
3. build-deploy comments say "5b rules manifest" and "section 4 reads $DOTPROFILE/claude/rules". Suggested: update them in the build-deploy batch that fixes question 1.

## Sources

- Plan: `plans/skills-and-rules-fanout.md` v1.0, sections 3.2, FO-2 and 3.4.
- Brief: `S3-FanoutImpl-delegate-brief.md`.
- Size gate: `scripts/build-deploy.sh`, "3. deploy-harness size limits".
- CI logs: run 40436452483, jobs 121966134039 (linux) and 121966134381 (macos).
- Local logs: `/Users/new-jose/repos/aitools/.claude/worktrees/fo-harness/.scratch/session-fohar/` (base-dh.log, base-mdm.log, dh-run2.log, dh-bash32.log, dh-mutant.log, mdm-run1-limitlifted.log, pre-commit.log, pre-push.log, ci-linux.log, ci-macos.log).
