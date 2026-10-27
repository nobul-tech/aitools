VERDICT: APPROVE

Independent review of #123 (FO-5) by S3-FanoutImpl-Review123. I reviewed head 880749e against plan `plans/skills-and-rules-fanout.md` v1.0, contract 3.1 (Cursor), contract 3.4 (skills consumer), FO-5 and FD-2. Scope: FO-5's own commits f67fde4, c5d1bd8 and c108954 (`setup-user-cursor.sh/.ps1`, `tests/rules-fanout-cursor`, the Cursor cases in `tests/skills-fanout`, the edits to `tests/fanout-lib`, `tests/deploy-harness-mdm` and `check.yml`). I did not review the lib or FO-4's function. I did not read the author's hand-back or scratch.

There are no blocking findings. The change meets contract 3.1 Cursor and FD-2:

- Every non-retired rule is fanned out, including aitools-source rules and rules the manifest does not list.
- Only retired names are pruned, and only with the marker or a legacy match, after a backup with the same text is confirmed.
- Removal uses the tracker outcome `removed`.
- The no-manifest, bad-header and unreadable-manifest cases give the rows the contract asks for.
- The script's own copies of the helpers are gone, and the lib's helpers are used.
- The bash deploy list is read on fd 3, so the review menu prompts.
- Step 5 calls `fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""` and its .ps1 twin.

## Findings

All findings are non-blocking.

1. **Misleading row text** (non-blocking). `scripts/setup-user-cursor.sh:869-872` and `.ps1:879-882` write `n/a (no harness rules)` when the run's only work was keeping a retired file. That row then reads `WARN|cursor rules|n/a (no harness rules)` beside the ACTION `Cursor still loads retired rules ...` (probe p3, test `bodymark`). The harness does have rules, so the text points the user the wrong way. Contract 3.1 allows n/a "when nothing to do", so this is cosmetic. Suggested text: `n/a (nothing to fan out)`. Alternatively, keep it and say in `reference/rules.md` (FO-7) what it means.

2. **Tautological test cases** (non-blocking). In `tests/fanout-lib/test-fanout-lib.sh:336-344`, `cursor_read_rules_manifest` is now `read_harness_manifest "$1" rules`, and that is exactly what `read_rules_manifest` is. The 12 `rr-*` cases therefore compare a function with itself and cannot fail. The grep guard that fails when the script defines its own reader again is the useful part. Suggestion: drop the `rr` cases, or keep them with a comment saying they are a smoke check only.

3. **Retired-name lookup is case-sensitive on a case-sensitive file system** (non-blocking, Linux only). `setup-user-cursor.sh:738-739` (`[ -f "$rm_path" ]`) and `.ps1:733-734` (`Test-Path`) look up `<retired name>.mdc` exactly. With a manifest line `Foo.md<TAB>retired` and `~/.cursor/rules/foo.mdc` on Linux, the file is neither pruned nor warned about. The skills contract (3.4) says DEST is "found case-insensitively", and the rules contract says nothing. On APFS and NTFS it works. Suggestion: list the directory once and match case-insensitively, or record this as a known limit in FO-7.

4. **Two writers for `~/.cursor/skills` until FO-6** (non-blocking; the PR already lists it). The PR's follow-up is right, and here is the concrete risk. `setup-user-skills.sh:6,108` lets the dotprofile win over `shared/`, while the fan-out lets `shared/` win (FD-4). So a skill name present in both would be overwritten back and forth on every run: one backup per run when non-interactive, two review menus per run when interactive. No such name exists today (the dotprofile has no `claude/skills`). Recommendation: merge FO-6 right after FO-5.

5. **Malformed PR body table** (non-blocking, cosmetic). In the Verification section, the "Final run, after merging FO-4 ..." paragraph sits inside a table after its header row, so the first table renders broken.

6. **Lib follow-ups** (outside this PR's scope; I agree with the PR's list). Add to it the stale comment at `scripts/aitools-lib.sh:2676-2678`: "setup-user-cursor's own copy of read_rules_manifest exits with perl's errno ...". The `aitools-lib.sh:2607` / `.ps1:2636` comments are already listed. An observation, not FO-5's: `write_summary` promotes every later OK row to WARN once any warning was logged (`aitools-lib.sh:957`). So `[s]kip` on a Cursor rule also turns the step-5 row into `WARN|cursor skills|1 verified` (pty probe A). This is existing behaviour, not a regression.

## What I ran

All runs were local on macOS arm64, in a detached worktree at 880749e. Every suite and probe used an isolated temp HOME. I never touched the real HOME.

| Suite or probe | Result |
|---|---|
| `tests/rules-fanout-cursor` (bash 5 + pwsh) | 198 passed, 0 failed, 1 skipped (dupcase: case-insensitive file system) |
| `tests/rules-fanout-cursor` (`/bin/bash` 3.2, `--bash-only`) | 133 passed, 0 failed, 19 skipped (parity) |
| `tests/skills-fanout` | 158 passed, 0 failed, 1 skipped (case-only duplicate) |
| `tests/fanout-lib` | 358 passed, 0 failed |
| `tests/b8-consumers` | 60 passed, 0 failed |
| `tests/deploy-harness-mdm` | 67 passed, 0 failed |
| `gh pr checks 123` | all pass: linux, macos, windows, CodeQL; `mergeStateStatus` CLEAN |

Independent probes. Each ran on the .sh, and on the .ps1 through `step4-driver.ps1`. Results were the same on both unless noted.

| Probe | Result |
|---|---|
| p1: aitools-source rule whose .mdc #110 pruned (only `a.mdc.bak.*` left) | re-added with the marker, `OK 2 added` |
| p2: #110-era marker .mdc of a retired rule | removed, `OK 1 removed`; the backup is byte-identical to the original (cmp) |
| p3: user .mdc at a retired name | kept; one WARN log line; ACTION `Cursor still loads retired rules ... old.mdc`; row `WARN n/a (no harness rules)` (finding 1) |
| p4: no manifest, plus an unmarked .mdc of an absent rule | everything fanned out, nothing removed |
| p5: bad header plus a retired line with a marker .mdc | nothing removed; WARN, ACTION `Run aitools to rebuild ...`, `WARN 1 added` |
| p6: unreadable manifest (file at chmod 000, not the suite's directory case) | `ERROR cannot read rules manifest`; failed item `.aitools-rules-manifest`; the fan-out continued; final `ERROR 1 failed`; exit 1 |
| p8: names `br[1].md`, `sp ace.md`, `q?.md` | fanned out (`OK 3 added`); after a local edit, the rerun backed up `br[1].mdc.bak.*` and restored it (`WARN 1 updated, 2 verified`) |
| p9: firecrawl-style symlinks in `~/.cursor/skills`: one relative, at a retired skill name; one absolute | both kept, targets untouched, logged "Preserved unmanaged skill" |
| p10: no `~/.aitools/skills` | no `cursor skills` row; log `No harness skills ... setup-user-skills deploys skills` (FO-4 contract change honoured) |

Pty probes (bash, `tests/managed-files/pty-run.py`), for the fd-3 fix:

| Probe | Result |
|---|---|
| Rules edit, `[s]kip` | prompted; edit kept; `WARN 1 skipped (user review)` |
| Rules edit, `[x]abort` | exit 2; no `cursor rules` row; edit kept |
| Rules edit, `[o]verwrite` | `OK 1 updated, 1 verified` |
| Skills edit, `[s]kip` | prompted; edit kept |
| Skills edit, `[x]abort` | exit 2; no `cursor skills` row |
| stdin a pipe, not a tty | no prompt, no hang; overwritten non-interactively |

I also checked:

- The diff has no new `2>/dev/null`, `|| true`, `SilentlyContinue` or empty catch. The one `|| true` (`setup-user-cursor.sh:844`) is a moved line that keeps its comment.
- The build-deploy cursor generator inlines the full lib (`inline_lib_bash` / `inline_lib_ps1`), so MDM gets `fanout_harness_skills`.

## Not run

- Native Windows. The .ps1 ran only on macOS pwsh through the driver. The CI windows job does not run `tests/rules-fanout-cursor` (`check.yml:620-622`).
- Linux locally. dupcase and finding 3 apply only on a case-sensitive file system.
- `check-pre-commit` / `check-pre-push`. This is a review, not a push.

S3-FanoutImpl-Review123 (level 2, under S3-FanoutImpl, Session Commander 10cf255a-c)
