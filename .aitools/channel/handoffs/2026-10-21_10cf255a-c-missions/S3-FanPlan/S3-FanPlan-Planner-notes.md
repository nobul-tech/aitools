# S3-FanPlan-Planner notes (2026-10-26)

Planner S3-FanPlan-Planner (level 2, under S3-FanPlan). Plan:
`S3-FanPlan-drafts/plans/rules-fanout-claude.md`. Regression test (new file,
not protected): `S3-FanPlan-drafts/tests/rules-fanout/test-rules-fanout.sh`.
Scratch (prototype, all copies): `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-plan/`.

## 1. What I read

- Mission packet; explorer brief; all seven findings files in full (Claude 725
  lines, Lib 453, Harness 418, Install 577, Checks 340, Ref 261 incl. section 9,
  Misc 184); re-checked the Ref file's length before finishing (unchanged).
- Rules: plan-execution-detail.md, managed-file-deployment.md (rule),
  deploy-paths.md, config-file-safety.md (worktree copies, read in full); the
  others in context (main checkout; Misc reports `diff -rq` main vs worktree
  empty). Skills loaded: /planning, /scratch, /tool-ops.
- Code read directly (not from findings): PR #112 head `setup-user-claude.sh`
  (423 lines) and `.ps1` (462) in full; PR #112 `build-deploy.sh` 1-60,
  228-257, 490-835, 1703-1732, 1936-1947; PR #110 head `setup-user-cursor.sh`
  385-899 and `.ps1` 495-884; PR #110 `step4-driver.ps1` and test 1-140,
  336-425; main `aitools-lib.sh` 2258-2337 and `.ps1` 2250-2309, 770-799;
  `tty_interactive` (`aitools-lib.sh:1357-1358`); PR #106 diff 95-174 (loop
  abort handling); PR #100 diff 1-170 (drafts); PR #112
  `tests/claude-mdm/test-claude-mdm.sh` 1-150, 280-309; main
  `tests/managed-files/test-managed-files.sh` 300-349, `pty-run.py` 1-30;
  `reference/managed-file-deployment.md` 26-75, 196-275, 300-405;
  `reference/harness.md` 120-180; `reference/tool-ops-claude-code.md` 40-84;
  `.claude/rules/hook-rollout.md` 105-112; README.md 60-99; PR #99 heads of
  `deploy-paths.md/.mdc`; PR #101 heads of `managed-file-deployment.mdc` and
  `reference/user-repo.md` 425-464; check.yml (main grep, #112 head 152-165,
  325-334).

## 2. What I verified (prototype; scratch copies only, isolated HOMEs)

- `apply-edit.pl` applies each old_string with an exactly-one-occurrence
  check. `proto-bases.sh`: A1-A4 apply to main, #103, #112, #116, #110 heads;
  B1/B2/B4/B5/B7 to all of those; B3/B6 only where #103 is in (MISS on main and
  #110); C1-C10 on main, #112, #111; C11 on main and #112 (C11b for #111);
  C12 on #112; C13/C14 on main; D1/D2 on #112 (MISS on #116).
- `apply-all.sh` on a fake checkout from #112: `bash -n` and the PowerShell
  parser pass on both libs and both scripts; check-post-push step 31's two perl
  extractions both give `added,created,failed,preserved,removed,skipped,updated,verified`;
  step 30's values are in both setup-user-claude files.
- `smoke.sh` (sh and ps): dry run -> `WARN|claude rules|dry run (no files written)`
  (WARN from the kept retired file), run -> `WARN|claude rules|4 added, 2 removed`
  with DETAIL rows, rerun -> `4 verified`, no harness dir -> `n/a (no harness
  rules)`; adopt targets logged as designed; rows identical sh/ps.
- `smoke-pty.sh` (sh and ps): accept & adopt wrote the dotprofile rule and the
  aitools working-tree rule; `[x]abort` -> exit 2, no `claude rules` row, local
  file kept. (In that smoke the dotprofile commit did not happen because the
  isolated HOME had no git identity: #103 reported an ACTION; the test file sets
  `GIT_CONFIG_GLOBAL` with an identity and its adopt case checks the commit:
  passed.)
- `proto-c.sh`: export of #112 + edits A, B, C: `tests/claude-mdm` 35/0/0
  (bash 5 + pwsh) and 35/0/0 with `/bin/bash` 3.2; no `USER_RULE` /
  `EMBED_DIR/rules` / `aitoolsEmbedRules` left in build-deploy.
- `proto-suites.sh` on the same tree: managed-files sh 57/0, ps1 39/0,
  adopt-push 28/0, rules-fanout-cursor 78/0/1, deploy-harness 45/0, profile
  test-lib 209/0. deploy-harness-mdm 28/2: the same 2 failures on an unedited
  export (`proto-baseline.sh`), because an export is not a git work tree.
- `proto-d.sh`: the drafted `tests/rules-fanout` suite 89/0/1 (bash 5 + pwsh
  7.6.3 parity), 37/0/16 (`/bin/bash` 3.2 `--bash-only`); `proto-d-neg.sh`:
  48 passed, 41 failed against the unedited #112 tree.
- `proto-d2.sh`: README and check.yml edits apply; check.yml parses (ruby
  YAML); no open PR touches README.md.
- `check-drafts.sh`: every OLD block of every protected draft occurs once in
  its stated base (harness.md Edit 2 is against #100's draft text, copied from
  `pr100.diff` 106-109: not on any branch).
- #106 behaviour (relayed correction): read in `session-harn/pr106.diff`
  95-174: only `deploy-harness.*` exit 2 calls `deploy_abort` + `break`; other
  scripts keep `ERROR ... script failed (exit N)` and continue.

## 3. What I could not pin

- D1/D2 when #116 merges before #112 (instruction given, no verbatim text).
- C11 on #111's head: C11b given verbatim, not applied in a full prototype.
- Batch B on a base that has #103 but also later lib changes from
  #113/#115/#116: B applies to #116's head (verified), not run there.
- Windows native, Linux, Git Bash: not run. pwsh ran on macOS only.
- The Claude Code memory docs were not re-read with chrome-devtools (the
  tool-ops draft is marked UNVERIFIED).

## 4. Deviations and choices

- The plan puts B, C and D on one branch/PR (three commits by three
  sub-agents): C's build-deploy change and B's script change must land
  together (pre-commit step 13, and the MDM test only passes with both), and
  the regression test belongs with the feature. Batch A is its own PR.
- Batch C has 3 files (build-deploy.sh, test-claude-mdm.sh, README.md): within
  the 2-3 limit; README is a two-hunk doc edit.
- No lib remover helper: removal is inline in setup-user-claude (Cursor's #110
  and deploy-harness's #100 have their own). The tracker gets `removed`; a lib
  remover would also be a new `MANAGED_FILE_RESULT` value and trigger the full
  interactive-menus 4-item contract. Listed as a possible follow-up, not
  proposed.
- No-manifest behaviour differs from Cursor's on purpose (Q3): Claude needs no
  source to select.
- The test file lives in the drafts folder under its repo path; it is not a
  protected file, so Batch D copies it verbatim.
- `read_rules_manifest` / `Read-RulesManifest` are #110's code byte for byte
  (risk R9 notes its case-sensitive `.md`).

## 5. INCIDENT markers (not filed)

- INCIDENT: `tests/rules-fanout-cursor/`, `tests/deploy-harness/`,
  `tests/deploy-harness-mdm/` are not in CI (re-confirmed; Checks I-2). The
  plan adds only `tests/rules-fanout/`.
- INCIDENT: `reference/user-repo.md` "Scope guidance" (project rules belong in
  the project) contradicts the 2026-10-22 decision to fan out aitools'
  `.claude/rules` into user scope; the draft rewrites it, the commander should
  see the contradiction (risk R1).
- INCIDENT: a user's own file whose name the manifest retires produces a
  `log_warn` on every run, promoting every later OK row of the run to WARN
  (Cursor #110 does the same). UX, low (Q10).

## 5b. Review amendments (2026-10-26, after S3-FanPlan-Review: APPROVE WITH CHANGES)

- Edits changed: B2/B7 (adopt checkout must have `.git`), B3/B6 (RC-2
  `MANIFEST_FAILED` + tracker `failed`; RC-1 backup-exists check; retired
  copy found case-insensitively and reported under its on-disk name), B6
  (re-check after `New-Item -Force`: the nocreate test showed PowerShell
  carrying on when a file blocks `~/.claude/rules`). Old_strings unchanged;
  `proto-bases.sh` re-run against origin/main 568fb5b: same matrix.
- Test file: temp checkout `git init`ed; new cases retired-bracket,
  retired-case, manifest-unreadable, nocreate, payload.
- New prototype base: `proto-wt.sh` creates a detached scratch worktree
  `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-plan/wt112main`
  (#112 head merged locally with origin/main; contains 9923a3c; no branch,
  never pushed). It is registered in `git worktree list`; remove it with
  `git -C /Users/new-jose/repos/aitools worktree remove --force <that path>`
  when no longer needed (left in place so the reviewer can re-run).
- Counts there: rules-fanout 110/0/1 (bash 5 + pwsh), 42/0/21 (bash 3.2);
  claude-mdm 35/0/0 x2; managed-files 57/0, 39/0; adopt-push 28/0;
  rules-fanout-cursor 78/0/1; deploy-harness 45/0; deploy-harness-mdm 30/0
  (the earlier 2 failures were the export, confirmed); profile test-lib 209/0.
- `proto-rc1.sh`: on the #112 export without 9923a3c the suite gives 107/3/1;
  the 3 failures are retired-bracket parity: PowerShell refused the removal
  (`Not removed: [r].md (retired rule): backup failed`), the file is kept.
- Not taken: native Windows CI (reason in plan Batch D), URP_RC=3 test.

## 6. Scratch artifacts (for harvesting)

`mkrepo.sh`, `apply-edit.pl`, `apply-all.sh`, `smoke.sh`, `smoke-pty.sh`,
`proto-c.sh`, `proto-suites.sh`, `proto-baseline.sh`, `proto-d.sh`,
`proto-d-neg.sh`, `proto-d2.sh`, `proto-bases.sh`, `check-drafts.sh`,
`assemble.pl`, `plan.tmpl.md`, `edits/*.old|new` (the verbatim edits the plan
embeds; regenerate the plan with
`perl assemble.pl plan.tmpl.md edits <plan path>` after changing an edit).
