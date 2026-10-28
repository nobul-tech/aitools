VERDICT: APPROVE WITH CHANGES

Independent review of PR #126 (FO-7 docs) by S3-FanoutImpl-Review126. Scope: the four doc commits 261b9d9, 1d6ba31, cd6ef6f, e3200ab on `feature/fanout-docs` (head e3200ab). I did not review the merges or any code, and I did not read the author's hand-back or scratch.

Code heads used for fact checks (fetched 2026-10-26): #118 ec6c4ac (newer than f69e2db), #119 fd660a9, #121 4339c08, #123 880749e, #124 282c28b, #125 7754c15. The docs head contains fd660a9, 880749e and 7754c15. It does not contain ec6c4ac, 4339c08 or 282c28b, so claims about those PRs were checked on those heads directly.

## Required changes (small; fix before merge)

**B1. Wrong summary-row text for setup-user-skills in fanned-out mode.**
- Where: `reference/skills.md` section 6.2, "setup-user-skills" row; `reference/script-standards-detail.md` "Tool names" table, `skills` row (added in e3200ab).
- The docs say `OK skills n/a (fanned out from ~/.aitools/skills)`.
- The code writes `n/a (fanned out)`: `write_summary OK "skills" "n/a (fanned out)"` in `scripts/setup-user-skills.sh` and `Write-Summary "OK" "skills" "n/a (fanned out)"` in `.ps1`. This holds at #125 7754c15 and on the docs head itself, and `tests/skills-legacy` asserts `OK|skills|n/a (fanned out)`.
- Fix: write `n/a (fanned out)` in both docs. The longer text is the log line, not the row. Plan FO-6 still has the old wording, but plans/ goes direct to main, so that is optional.

**B2. Retired skills: the docs say `backup_dir()`, but deploy-harness does its own copy.**
- Where: `reference/harness.md` "Skills manifest and retired skills", Retiring bullet ("is copied with `backup_dir()` to `<name>.bak.<UTC>/`"); `reference/skills.md` section 6.2, first row ("backed up (`backup_dir`, ...)").
- At #119 fd660a9, `retire_skill_dir` in `scripts/deploy-harness.sh` does three things:
  - it uses `cp -R "$d" "$bak"`, then `diff -r -q`, then `rm -rf`;
  - `prune_skill_backups` keeps 5;
  - a half-made backup is removed, or renamed to `<name>.bak.incomplete.<UTC>` with ERROR `bak cleanup failed: <name>`.
- Its header says "cp -R; any skill directory, no *.md precondition". The `.ps1` has only a comment, "as Backup-Dir keeps 5".
- This matters: `backup_dir` skips any directory without a top-level `*.md`, which is every skill directory. So the documented mechanism would copy nothing.
- Fix: describe it as a recursive copy beside the directory (newest 5 kept), compared with `diff -r`, an incomplete backup removed or renamed `.bak.incomplete.`, and an ERROR row. Do not name `backup_dir()`.

**B3. "Review after" and the review-diff line leave out e3200ab (D-DEL5 / FD-8).**
- e3200ab changes three protected files:
  - `.claude/rules/deploy-paths.md` and `.cursor/rules/deploy-paths.mdc`, "MDM run order": the skills fan-outs now write no row, and setup-user-skills owns the `claude skills` / `cursor skills` rows.
  - `reference/managed-file-deployment.md`, Functions table: the `n/a (nothing to deploy)` fallback.
- The PR body names only 261b9d9, 1d6ba31 and cd6ef6f. Its deploy-paths "Review after" entry still gives the superseded text "`n/a (no harness rules)` / `n/a (no harness skills)`".
- The "Review diff" line also stops at 1d6ba31 plus cd6ef6f.
- Fix: in the PR body, add e3200ab to the commit list and to the review-diff line, and correct the deploy-paths and managed-file-deployment "Review after" entries (old -> new).

## Non-blocking

- **N1. Stale "as Cursor does".** `reference/rules.md` section 7, "Known cost", last bullet, says "skip source `aitools` in the Claude fan-out, as Cursor does". Under R-6 Cursor no longer skips it. Suggested: "as Cursor did before R-6". Also say that, under R-6, Cursor now loads the same ~79 KB of project rules (its cost is not stated anywhere).
- **N2. #118 ec6c4ac is not documented.** The `Backup-Dir` row in `reference/managed-file-deployment.md` "Functions" does not mention two changes from that commit:
  - a half-made directory backup is now discarded, or renamed `<dir>.bak.incomplete.<UTC>`, which the prune never matches;
  - the top-level `*.md` test is now case-insensitive.

  The row's claims are still true; this is a re-anchor item once #118 merges.
- **N3. Stale PR heads in the PR body.** The "Verification" section cites #118 7b7e1fb, #121 4339c08 and #124 fcf6edc, but e3200ab was checked against #118 f69e2db and #124 282c28b. Update the heads in the body.
- **N4. CLAUDE.md row is not done yet.** Inventory row 52 (CLAUDE.md, `shared/` bullet) is correctly deferred (FD-8: direct to main), but `origin/main` CLAUDE.md still says "`aitools install` deploys to `~/.claude/` and `~/.cursor/`". Track it so it lands with the merge.
- **N5. Undocumented #124 logging-audit behaviour (2fdcefb).** These rows are not in `reference/skills.md` 6.3:
  - invalid manifest lines also write the rebuild ACTION;
  - an unlistable DEST writes an ACTION row and "preserved count unknown";
  - a dry run with DEST as a file reports ERROR `cannot create skills dir`.

  Nothing in 6.3 is false; these are optional additions.

## Inventory coverage (DocsScan inventory v1.0, rows 1-55)

Every row is applied or justified:
- **Applied:** 1-45, 47-51, 53-55, and the `.mdc` twins 1m-6m, 7m-11m and 13. The deploy-harness row that was missing from the managed-file-deployment `.mdc` has been added.
- **Justified:**
  - 46 (framework-managed-file-deployment): flag only, listed in the PR.
  - 52 (CLAUDE.md): FD-8, see N4.
  - 19 twin: optional; FanPlan C15 chose no twin edit.
  - 17 has no twin: the `.mdc` has no "Skill placement" section.
  - C1-C9: these belong to the code PRs.

## Doc standards

- `bash scripts/check-pre-commit.sh` in the review worktree (detached at e3200ab): 7 PASS, 12 SKIP, 1 WARN, 1 FAIL.
  - Step 16 (capability bypass): PASS.
  - Step 20 (path references): PASS.
  - Step 6 FAIL is the known `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` 100644.
  - Step 11 WARN is uncommitted changes in the dotprofile repo (not this PR).
- Governed JSON paths: none added in rules or references. The only `.json` hit is `tool-ops.json`, a file name in a table cell, which was already there and was not changed.
- Line numbers: none in the added lines of rules or references (grep over all four commits).
- `@` convention: rules use `@reference/skills.md` and `@reference/rules.md`; the `.mdc` twins use plain paths, as the existing `.mdc` files do.
- `.mdc` twins in step: managed-file-deployment, deploy-paths (including e3200ab), hook-rollout and documentation-standards all match their `.md`. A grep of `.cursor/rules` for "aitools repo only", "only available skill", "once it fans out", "not yet deployed" and "user-level rules only" found nothing (aitool-ops and aitool-eval have no `.mdc` twin).
- skills.md mirrors rules.md:
  - same sections 1-8 in the same order (Decisions, What a ... is, layering, anatomy, scopes, deployment, project ... at user scope, writing or changing);
  - then gaps and cross-references, with one extra section, 9 "Inside aitools";
  - same version line, decision table columns (ID, Decision, Date, By, Source), "Built" / "Where" table and "unknown" convention.

  The new intent is listed under "Review after".
- Glossary (checked against the `/glossary` skill's required fields): the 5 new terms have `definition` and `source`. Each has a matching line in `.claude/rules/glossary.md`, in alphabetical order. The `rule` and `skill` facets and the `skill` term are updated, and `meta.lastUpdated` is bumped.

## Claims sampled (23), with results

| # | Claim (doc: section) | Checked at | Result |
|---|---|---|---|
| 1 | skills.md 6.3: binary files byte-copied, `_fanout_copy_binary` / `Copy-FanoutBinary`, backup, no menu | #124 282c28b lib .sh/.ps1 | true |
| 2 | skills.md 6.3: a binary over a DEST symlink becomes a regular file; text written through a live link | 282c28b: `mv -f` / `File.Move(..., $true)`; deploy_managed_file "A live symlink is read and written" | true |
| 3 | skills.md 4.1/6.3: reserved names `synced`, `anthropic-skills*` never written or removed | 282c28b `_fanout_skill_reserved` / `Test-FanoutSkillReserved` | true |
| 4 | skills.md 6.3: retired backup to `<DEST>.bak.<UTC>/<name>/` beside DEST, newest 5 kept | 282c28b `_fanout_prune_dest_backups "$_fs_dest" 5` | true |
| 5 | skills.md 6.3: ACTION "... not updated (a symlink or a file, not a directory the fan-out owns): ... -- move them aside to get the aitools copy" | 282c28b sh:3335, ps1:3337 | true |
| 6 | skills.md 6.3: ACTION "<Tool> still loads retired skills in <DEST>: ... -- delete them unless you wrote them" | 282c28b sh:3436, ps1:3463 | true |
| 7 | skills.md 6.3: no `~/.aitools/skills` -> info log, no row | 282c28b `fanout_harness_skills` | true |
| 8 | skills.md 6.3: empty `~/.aitools/skills` -> `OK <tool> n/a (no harness skills)` | 282c28b sh:3149 | true |
| 9 | skills.md 6.3: manifest unreadable -> ERROR `cannot read skills manifest` | 282c28b | true |
| 10 | skills.md 6.2: `skills fan-out` span extracted by build-deploy; Claude call with `$RULES_AITOOLS_REPO` / `USER_REPO_PATH` | 282c28b setup-user-claude.sh:693-700, build-deploy.sh:724/816 | true |
| 11 | skills.md 6.2: Cursor step 5 `fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""` | #123 880749e setup-user-cursor.sh:893 | true |
| 12 | skills.md 6.2 / script-standards-detail: setup-user-skills row `n/a (fanned out from ~/.aitools/skills)` | #125 7754c15 and e3200ab | **false** (B1) |
| 13 | harness.md / skills.md 6.2: retired skill dirs backed up with `backup_dir()` | #119 fd660a9 `retire_skill_dir` | **false** (B2) |
| 14 | harness.md: planner and writer `harness_manifest_plan` / `Get-HarnessManifestPlan`, `write_harness_manifest` / `Write-HarnessManifest` | fd660a9 | true |
| 15 | harness.md: ERROR `harness files retire failed: <name>`; DETAIL `retired: rules/<name>`; `rules manifest not written` | fd660a9 (`TOOL="harness files"`, `"$Kind manifest not written"`) | true |
| 16 | harness.md / deploy-paths: dotprofile skills source and `.claude/hooks` source | fd660a9 deploy-harness.sh:305, 312; ps1:296 | true |
| 17 | harness.md: retired name that is a file or symlink is left alone with a warning | fd660a9 deploy-harness.sh:664 | true |
| 18 | managed-file-deployment.md: `# aitools skills manifest v1`; unknown outcome `log_error`, counted failed, case-sensitive | #118 ec6c4ac (`switch -CaseSensitive`, `*)` branch) | true |
| 19 | managed-file-deployment.md: tracker fallback `n/a (nothing to deploy)` | ec6c4ac sh:2628, ps1:2662 | true |
| 20 | rules.md 6.1: Claude/Cursor `n/a (no harness rules)`; Cursor deploy list on fd 3; adopt only from a git checkout | 880749e (`<&3`), 4339c08 (`-e "$SCRIPT_DIR/../.git"`) | true |
| 21 | deploy-paths / user-repo: MDM setup-user-claude embeds no rules | 4339c08 build-deploy.sh (rules only via the deploy-harness snapshot) | true |
| 22 | skills.md 4.1/7.1: 24 skills, 7 with `tests/expected-behaviors.md`, the 9 `.claude/skills` names | `git ls-tree` 672c1f9 | true |
| 23 | tool-ops-claude-code: new items #28/#29 free (main highest 27); rules.md: #100 = 89e2953 on main; `dotprofile_commit_push` exists | 672c1f9 / origin/main | true |

21 of 23 true. Two are false (B1, B2), and B3 is a PR-body gap.

-- S3-FanoutImpl-Review126 (level 2, under S3-FanoutImpl, Session Commander 10cf255a-c)
