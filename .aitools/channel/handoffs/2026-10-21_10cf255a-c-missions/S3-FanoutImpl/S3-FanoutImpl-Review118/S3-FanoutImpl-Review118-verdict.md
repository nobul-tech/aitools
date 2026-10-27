VERDICT: APPROVE WITH CHANGES

Independent review of #118 (FO-1, fan-out lib helpers) by S3-FanoutImpl-Review118, head `14f9fb1`, diff `git diff d7f6855...14f9fb1` (4 files: `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`, `tests/fanout-lib/test-fanout-lib.sh`, `.github/workflows/check.yml`). Checked against `plans/skills-and-rules-fanout.md` v1.0 sections 3.1, 3.3, 3.4 and FO-1, and `plans/rules-fanout-claude.md` v1.0 section 3 and Batch A. I did not read the author's hand-back or scratch.

No blocking findings. The two parity gaps below (N1, N2) are small and do not change a prune decision (each still means "do not remove"). They are cheap to fix in this PR, or FO-4 can take them, since FO-4 is the first caller of `fanout_dir_matches`.

## Contract conformance

| Item (3.3) | Result |
|---|---|
| A1 (sh tracker init/record) | verbatim: `_DT_REMOVED`, `removed)` row, `*)` -> `log_error` + failed + DETAIL |
| A2 tracker summary part | verbatim (`N removed` after `accepted`, before `verified`) |
| A3 (ps tracker) | verbatim, `default` block included |
| A4 tracker summary part | verbatim |
| A2/A4 helper bodies | `lower_name`, `in_list`, `rule_name_kind`, `Get-RuleNameKind` byte-identical to FAN-PLAN (and `lower_name`/`in_list` to `setup-user-cursor.sh:543-555`); `read_rules_manifest` / `Read-RulesManifest` became thin wrappers over `read_harness_manifest` / `Read-HarnessManifest`, as 3.3 requires |
| Headers | `RULES_MANIFEST_HEADER` / `SKILLS_MANIFEST_HEADER`, `$rulesManifestHeader` / `$skillsManifestHeader`: correct strings |
| `skill_name_kind` / `Get-SkillNameKind` | hidden / backup / skill, case-insensitive (ASCII) |
| `read_harness_manifest` / `Read-HarnessManifest` | name patterns `\A[^/\\]+\.md\z` and `\A[^/\\.][^/\\]*\z` exactly as 3.3; `.bak.`, unknown source, case-insensitive duplicate rejected; `rule<TAB>` first word for both kinds, `Rules` key for both (as 3.3 "Output as FAN-PLAN's reader") |
| `fanout_text_equal` / `Test-FanoutTextEqual` | FAN-PLAN `rule_text_equal` body plus an explicit `-d` -> 2 and a detail log on 2 |
| `fanout_dir_matches` / `Test-FanoutDirMatches` | matches 3.3 (real dir, every non-`*.bak.*` regular file equal at the same path in CAND, at least one such file); the extra rules (symlink or non-regular entry anywhere -> 1, files only in CAND ignored, 2 wins over 1) are conservative and stated in the PR body |
| Contract change (directory as manifest -> non-zero/throw instead of `header-bad`) | declared in the PR body; accepted. It is a better result (ERROR `cannot read rules manifest` rather than WARN `not v1`), and no cursor test covers a directory manifest (`grep manifest tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`) |
| Step 31 tracker parity | `added,created,failed,preserved,removed,skipped,updated,verified` from both perl extractions (`check-post-push.sh:802-803`) on the PR's libs |
| Error-handling block | no new `2>/dev/null`, `|| true` or `SilentlyContinue` in the libs; `|| rc=$?` captures the code, which is then returned; the perl stderr of `fanout_dir_matches` is captured and logged at detail level; every ps `catch` logs (`LogDetail`) and returns 2; the test's two `2>/dev/null` have comments and checks. PASS |
| CRLF / mode | `aitools-lib.ps1`: no LF-only lines; `tests/fanout-lib/test-fanout-lib.sh` 100755 |

## Findings

### Blocking

None.

### Non-blocking

**N1 -- sh/ps parity: a directory you can list but cannot enter gives 1 in sh, 2 in ps.** `scripts/aitools-lib.sh:2703-2705`. perl's `readdir` works on a mode-644 subdirectory, but `lstat` on each entry fails (EACCES); `-l $p` is then false, `-d _` false, `! -f _` true, so the entry is counted as "non-regular" (`$bad`, exit 1). PowerShell (`aitools-lib.ps1:2650-2663`) gets 2 from `Test-FanoutTextEqual`. The contract (3.3: "2 unreadable") and the function's own comment ("Exit 2 when an entry cannot be read") say 2. Probe: `T/sub` chmod 644 -> bash 5 `rc=1`, /bin/bash 3.2 `rc=1`, pwsh `rc=2`. Neither result prunes, but FO-4 reports 1 as a WARN "Kept" and 2 as `failed`, so the row would differ between platforms. Suggested fix, before the `-l` test:
`unless (lstat $p) { print STDERR "cannot stat $p: $!\n"; $err = 1; next }` then `if (-l _) { $bad = 1; next }`, plus a `dm-noexecsub` case (chmod 644 on a subdirectory) in the UNREAD block.

**N2 -- `Test-FanoutDirMatches` throws on an empty Candidate; sh returns 1.** `aitools-lib.ps1:2659` `Join-Path $Candidate $r` with `""` throws "Cannot bind argument to parameter 'Path' because it is an empty string" (probe `empty-cand`). The function is documented to return 0/1/2, and the ps callers will not wrap it in try/catch. An empty Target already returns 1 (`Test-Path -LiteralPath ""` is false). Suggested fix, first line of the function: `if ([string]::IsNullOrEmpty($Target) -or [string]::IsNullOrEmpty($Candidate)) { return 1 }`.

**N3 -- the ps comment is narrower than the sh comment.** `aitools-lib.ps1:2625` says "a symlink (reparse point) anywhere under Target"; the sh says "a symlink or another non-regular entry". The behaviour is the same (FIFO probe: 1 in both, pwsh did not block on the FIFO), so it is only the comment. Optional.

**N4 -- FO-1 says "merge FO-0's head first" (plan section 4, FO-1 Files); the branch does not.** `git log d7f6855..14f9fb1` has only the two FO-1 commits. `git merge-tree --write-tree HEAD origin/feature/fanout-ci` is clean, and FO-0's "every suite in CI" step will find `tests/fanout-lib/test-fanout-lib.sh` named in check.yml, so this does not block the PR. The merge orchestrator should still merge #117 before #118. The PR body should mention this deviation.

**N5 -- tracker case handling (pre-existing; the author found it).** Probe: `Removed`, `REMOVED` and `Added` are counted as `failed` with a `log_error` in sh, but as `removed` / `added` in ps (`switch ($Outcome)` at `aitools-lib.ps1:2475` is case-insensitive). A3 is verbatim, so I am not asking for a change here. Follow-up: `switch -CaseSensitive ($Outcome)` in a later batch, with a tracker parity case. All callers pass lower-case literals today.

**N6 -- non-ASCII names (follow-up, not today's data).** Probes: (a) duplicates that differ only in Unicode case (`É.md` / `é.md`): sh accepts both, ps marks the second as invalid (perl `lc` on raw bytes; the author disclosed this); (b) KELVIN SIGN U+212A: `x.baK.1` is `other`/`skill` in sh but `backup` in ps (`-like` folds Unicode); (c) invalid UTF-8 (`\xff.md`): sh passes the raw byte through, ps returns U+FFFD. Manifest names are ASCII today. If FO-2 ever lets non-ASCII names into a manifest, normalise in one place (e.g. reject non-ASCII names in the reader).

**N7 -- for FO-4: `.DS_Store` makes a retired skill directory "not ours".** `dm-hidden` gives 1 by design (correct by 3.3, and conservative). On macOS, opening `~/.claude/skills/<name>` in Finder once is enough to turn a prune into a "Kept" WARN + ACTION. That is acceptable, but the ACTION text FO-4 writes should not suggest that the user wrote the skill. Information only.

**N8 -- MDM size (out of scope, FO-0b).** The lib is inlined, so this PR adds about 9 KB to `deploy/deploy-harness.ps1` (202,519 -> 211,576 B per the PR body; limit 200,000). Whoever fixes the size gate has to budget for this PR's 9 KB and for FO-3/FO-4's.

## Fit for the later batches (plan 3.4)

- FO-3 retired-rule prune: `fanout_text_equal` covers both the "equal to `<name>` or any `<name>.bak.*`" test and the RC-1 "a `<file>.bak.*` with the same text exists" check. FAN-PLAN B's private `rule_text_equal` can be dropped (already listed as a follow-up).
- FO-4 retired-skill prune: `fanout_dir_matches DEST/<name> CAND` with CAND = `~/.aitools/skills/<name>` or each `<name>.bak.*` fits. Because the check is "TARGET is a subset of CAND", the same call with CAND = the new `DEST/<name>.bak.<UTC>` also verifies the backup before `rm -rf` (3.4 "verify ... with the same files"). Files the fan-out itself backed up inside DEST (`SKILL.md.bak.*`) are ignored as they should be.
- FO-4/FO-5 manifest: `read_harness_manifest FILE skills` gives `rule<TAB>name<TAB>source` (sh) and `.Rules` (ps) for skills. This is contract-mandated but easy to misread: FO-4's parser should match the first word `rule`, not `skill`.
- What 3.4 needs that FO-1 does not provide: case-insensitive lookup of `DEST/<name>` and the recursive list of files to deploy. Both belong in FO-4's `fanout_harness_skills` / `Invoke-HarnessSkillsFanout`, which is a lib function. No gap in the FO-1 API.

## Test adequacy

`tests/fanout-lib/test-fanout-lib.sh` covers every case FO-1 lists (tracker removed/unknown/blank/order/skip; name kinds with case, dots and bak; manifest ok, header-bad, cross-kind header, BOM, CRLF, lone CR, no LF, empty, directory, missing, unreadable, invalid lines, duplicates, rules-vs-skills names, kind case; text_equal; dir_matches match, extra, cand-extra, differ, inner CR, bak, empty, only-bak, empty sub, hidden, cand missing or a dir, target a file or missing, three symlink forms, four unreadable forms). It checks parity on every case. The `rr-*` cases compare the lib reader with the copies extracted from `setup-user-cursor.sh/.ps1` on output, stderr and exit code. Gaps: N1's 644 subdirectory, N2's empty arguments, and names with `[ ]` or spaces in dir_matches. My probe found the `[ ]`/space case correct in all three shells (`rc=0`). Windows-native pwsh and Git Bash are not run (the suite is not in the windows job).

## What I ran (macOS arm64, detached worktree at 14f9fb1, isolated HOME in every run)

- `bash tests/fanout-lib/test-fanout-lib.sh`: 284 passed, 0 failed, 0 skipped.
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/fanout-lib/test-fanout-lib.sh --bash-only`: 95 passed, 0 failed, 1 skipped.
- `tests/managed-files/test-managed-files.sh` 57/0, `.ps1` 39/0; `test-adopt-push.sh` 28/0, `.ps1` 23/0; `tests/profile/test-lib.sh` 361/0, `/bin/bash` 3.2 `--bash-only` 160/0; `tests/rules-fanout-cursor` 164/0/1 skipped; `tests/deploy-harness` 76/0.
- Step 31 extraction (both perl lines): both lists `added,created,failed,preserved,removed,skipped,updated,verified`. `bash -n scripts/aitools-lib.sh` OK; `pwsh -File scripts/_validate-ps1.ps1 scripts/aitools-lib.ps1` OK.
- Probe script (bash 5, /bin/bash 3.2, pwsh): names with `[1]`, spaces and `é` (0/0/0); a nested `sub.bak.1/` directory (1/1/1); CAND as a symlink to a matching tree (0/0/0); a FIFO (1/1/1; pwsh did not hang); a symlink to an empty directory (1/1/1); a 644 subdirectory (1/1/**2**, N1); empty arguments (1/1/1), empty Candidate (1/1/**throws**, N2); `fanout_text_equal "" ""` (2/2/2); tracker case (N5); Unicode names (N6); directory as manifest (sh `rc=255` with "is a directory", ps throws `MethodInvocationException`).
- CI run 40437712731: "Fan-out lib helper tests" passed on linux, macos (bash 5 + pwsh) and macos (/bin/bash 3.2). linux and macos are red only at "setup-user-claude dev + MDM tests" (claude-mdm size gate, FO-0b, out of scope); windows passed.
- `git merge-tree --write-tree HEAD origin/feature/fanout-ci`: clean (N4).

Not run: check-pre-commit and check-pre-push (the author reports them, with the known step 6 and step 7 FAILs), Windows native, check-post-push.
