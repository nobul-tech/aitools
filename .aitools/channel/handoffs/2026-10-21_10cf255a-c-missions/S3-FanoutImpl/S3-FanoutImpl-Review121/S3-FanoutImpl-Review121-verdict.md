VERDICT: APPROVE

# PR #121 review (FO-3: Claude rules fan-out = FAN-PLAN B, C, D)

Reviewer: S3-FanoutImpl-Review121 (level 2, under S3-FanoutImpl, Session Commander 10cf255a-c), 2026-10-27.
Reviewed head: `66c58cb` (B `b27ab1a`, C `a0bd5e4`, D `bba5fad`, plus the FO-0/FO-0b/origin-main merges).
Checked against `plans/rules-fanout-claude.md` v1.0 sections 3, 4, 6 (B, C, D) and 12, and `plans/skills-and-rules-fanout.md` sections 1, 3.1 and FO-3.
I did not read the author's hand-back or scratch.

## Summary

The three commits apply FAN-PLAN verbatim. The only deviation is the allowed contract change (the lib's `fanout_text_equal` / `Test-FanoutTextEqual`), and its semantics are identical. Every suite passes locally on bash 5, `/bin/bash` 3.2 and pwsh. CI is green on the head (macos, linux, windows, CodeQL). My own probes beyond the suite found nothing blocking: the fd-3 menu, abort, CRLF, worktree adopt, the resolver error and MDM `.sh`/`.ps1` all pass. A local trial merge of the current FO-1/FO-0/FO-0b heads is clean and stays green. No protected file is edited. The PR body carries the commander's Q1/Q13 answer (FD-1), so the RC-3 gate is met.

## Plan conformance (scripted: every FAN-PLAN snippet counted in the head files)

- B1, B2, B4, B5, B7 new_string: each found exactly once. Old strings are gone, except B5, which is an insertion.
- B3 and B6 (rules logic spans), diffed against the plan: the only differences are the dropped local `rule_text_equal` / `Test-RuleTextEqual` definitions (replaced by a 3-line comment) and the 4 call sites renamed to `fanout_text_equal` / `Test-FanoutTextEqual`. Every other line is byte-identical, section 12 amendments included (RC-1 same-text backup check, RC-2 `MANIFEST_FAILED`, case-insensitive retired lookup, the `nocreate` re-check, the `.git` requirement).
- Lib helper vs plan helper: the same perl body (sh) and the same Latin1 + `-ceq` body (ps). The lib adds `-d` -> 2, which is harmless because the caller filters with `[ -f ]` / `Test-Path -PathType Leaf`. Only the detail-log text differs, as the PR body states.
- C1-C10, C11b, C12, C13, C14, D1, D2: each new_string found exactly once, and the old strings are gone. C11 is correctly not applied because #111 is in the base.
- D0 `tests/rules-fanout/test-rules-fanout.sh`: identical to the S3-FanPlan draft (`git diff --no-index` empty), mode 100755.
- No leftover rules embed: grep for `USER_RULE`, `EMBED_DIR/rules`, `aitoolsEmbedRules` and `Rules fallback` across scripts/ returns nothing.

## What I ran (macOS, isolated HOMEs; the suites isolate themselves)

| Check | Result |
|---|---|
| `tests/rules-fanout` bash 5.3 + pwsh | 110 / 0 / 1 (skip: case-only dup on APFS) |
| `tests/rules-fanout` `/bin/bash` 3.2 `--bash-only` | 42 / 0 / 21 |
| `tests/claude-mdm` bash 5; `/bin/bash` 3.2 | 35 / 0 / 0 each |
| `tests/managed-files` sh; ps1 | 57 / 0; 39 / 0 |
| `test-adopt-push` sh; ps1 | 28 / 0; 23 / 0 |
| `tests/hookin` | 39 / 0 |
| `tests/deploy-harness-mdm` | 64 / 0 |
| `tests/fanout-lib`; `tests/profile/test-lib.sh` | 284 / 0; 361 / 0 |
| `bash -n` and `/bin/bash -n` on setup-user-claude.sh, build-deploy.sh, both tests | pass |
| `_validate-ps1.ps1 scripts/setup-user-claude.ps1` | OK |
| check.yml parsed by ruby YAML | parses |
| `check-pre-commit.sh` | only step 6 FAILs (known: harvesting file 100644); step 11 WARN (live dotprofile dirty) |
| `check-pre-push.sh` | only step 7 FAILs (known: dotprofile deploy/ stale); WARN 1, 5, 6, 8 |
| Trial merge of #118 `3abc53f` + #117 `dbe8f46` + #120 `1d37d93` into `66c58cb` (local detached HEAD, never pushed) | clean; rules-fanout 110/0/1 and 42/0/21, claude-mdm 35/0/0 both bashes, fanout-lib 347/0, managed-files 57/0 |

## Probes beyond the suite (scratch `probe-dev.sh`, and a copy of the claude-mdm suite with probes appended)

1. **fd-3 loop prompts (bash, pty).** I edited two harness rules locally and fed `s\ns\n`. Two review menus appeared and both rules were skipped. The new rule was still added, and the row was `WARN|claude rules|2 skipped (user review)` (the lib's WARN form). **Negative control:** in a copy whose loop reads the here-string on stdin (two lines mutated), no menu appears and the local edits are overwritten. So fd 3 is what makes the menu prompt.
2. **Abort.** Input `x` on a pty: exit 2, no `claude rules` row, local files kept, in both sh and ps.
3. **Retired copy that differs from the harness copy only by trailing CRLF.** I used `gone rule\r\n\r\n` against the backup `gone rule\n`. The copy is removed, its backup is kept and the DETAIL row reads `removed:`. A copy with CRLF on every line is kept, with WARN and an ACTION row. Both sh and ps.
4. **Adopt from a git worktree.** In a worktree `.git` is a file, and `-e` / `Test-Path` are both true for it. So the worktree counts as the aitools checkout: adopt targets are `<worktree>/.claude/rules/p.md` and `<worktree>/shared/rules/s.md`. Accept & adopt on a pty writes the worktree's file and leaves the main checkout untouched. Both sh and ps.
5. **Dotprofile resolver error (URP_RC=3)**, injected with a failing resolver via `AITOOLS_PROFILE_SH` / `_PS1`. Exit 1 with rows `ERROR dotprofile`, ACTION and `ERROR claude.md not deployed: dotprofile unresolved`. There is no `claude rules` row and `~/.claude/rules` is untouched. Both sh and ps (FAN-PLAN section 4.9).
6. **Generated MDM scripts (built by the suite's own isolated build).**
   - `.sh` and `.ps1`, with the dotprofile on the machine:
     - without `~/.aitools/rules`: `OK n/a (no harness rules)`;
     - with it seeded: `OK 2 added, 1 removed`;
     - dotprofile adopt is mapped; shared adopt is `none` (deploy/ is not an aitools checkout);
     - the `.ps1` leaves no temp dir behind.
   - With no config.json (no dotprofile), the rules results are the same, with dotprofile adopt `none`. That run exits 1, but only because the build-time profile snapshot has no profile for this Mac (`machine profile: no profile matches`). That is existing resolver behaviour, not this PR.

## Findings

Blocking: none.

Non-blocking:

1. **The branch is behind its dependencies' review fixes.**
   - Since #121 merged them, #118 gained `3abc53f`, which changes lib functions this PR calls:
     - `backup_dir` / `Backup-Dir`: rewritten, with a new `BACKUP_DIR_OK` flag;
     - `fanout_text_equal`: new detail text;
     - `Record-DeployOutcome`: now `-CaseSensitive`.
   - #117 is now at `dbe8f46` and #120 at `1d37d93`.
   - My local trial merge is clean and green (table above). The merge orchestrator should still merge these heads (or origin/main once they land) into the branch and rerun rules-fanout and claude-mdm before `gh pr merge`, as section 5 of the FO plan requires.
2. **The "Merge gates" list in the PR body is incomplete.**
   - It names #106, #118 and FO-0, but the branch also carries #120 (FO-0b) and #100 (the manifest; without it pruning and adopt do nothing).
   - Suggest listing #117, #118, #120, #100 and #106 explicitly with their PR numbers.
3. **CI steps** (`.github/workflows/check.yml:210-214`, `:455-456`).
   - The new rules-fanout steps have no `if: ${{ !cancelled() }}`, the FO-0 pattern its neighbours below use. As written, a claude-mdm failure hides the rules-fanout result.
   - Consistent with the claude-mdm steps just above, so optional. Adding the guard costs two lines per job.
4. **Docs drift until FO-7** (protected files, not editable here, so FO-7's job). Once this merges, these statements are false:
   - `.claude/rules/deploy-paths.md:62` ("once it fans out"), `:120` ("and the rules fallback"), `:148` (`<userRepoPath>/claude/rules/*.md` embedded as fallback rules);
   - `.claude/rules/managed-file-deployment.md:52` (rules deployed from `<userRepoPath>/claude/rules/`);
   - `reference/user-repo.md:450` (the source).
   - Suggest merging FO-7 right behind FO-3, or tracking these lines in FO-7's PR.
5. **Worktree checkouts are adopt targets** (`scripts/setup-user-claude.sh:310`, `scripts/setup-user-claude.ps1:346`). The comment says "Only a git checkout counts"; a linked worktree counts too (probe 4).
   - This is reasonable: it is a working-tree change like the main checkout.
   - But an agent running setup-user-claude interactively from a `.claude/worktrees/*` copy adopts into that worktree, not into main.
   - Suggest one comment line saying so; no code change.
6. **Mixed line endings.** A retired copy with CRLF on every line (for example, one touched by a Windows editor) is kept and warns on every run (probe 3). This is conservative and matches FAN-PLAN R7/Q10. Recorded, no change requested.

## Not run

- Windows native (no Windows CI step for the fan-out: FAN-PLAN F4).
- Linux locally (CI linux is green, which covers `dupcase`).
- A real MDM endpoint; `check-post-push`; anything against the real HOME.
