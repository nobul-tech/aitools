# S3-CursorVerify-Pwsh hand-back

Version 1.0, 2026-10-28, by S3-CursorVerify-Pwsh (level 2, delegated by S3-CursorVerify).
Contract: `../S3-CursorVerify-contract.md` v1.0. REF `9c2d0257a64d10be1be32a30c24b382a91f7689c`
(fixture clone HEAD after the fixture commit: `25df32c`). Platform: macOS (Darwin arm64),
pwsh 7, running the Windows-only `.ps1` scripts through drivers. Windows itself: **not run**.

## Summary

The PowerShell path works for most checks: all three rule sources and all skills fan out,
first source wins with one ERROR row per duplicate, bracket names deploy, update, retire and
come back, a rerun verifies everything, dry runs write nothing, per-file backups exist, the pty
review prompts and `[x]abort` (exit 2) behave as specified. Four gaps:

1. **G1 (contract fail, P4)**: a user-modified retired `.mdc` (`fx-retire2.mdc`) is **removed**
   (backup kept) instead of kept with WARN + ACTION.
2. **G2 (FX-Upper.MD)**: deploy-harness.ps1 deploys `FX-Upper.MD` and writes it into the rules
   manifest, but its own manifest name rule (case-sensitive `\.md\z`) rejects that line on every
   later run. Effects: a WARN plus a misleading ACTION ("Run aitools to rebuild") on every run,
   every OK row promoted to WARN, and the rule **can never be retired**: after its source was
   removed it stayed in `~/.aitools/rules` and `~/.cursor/rules` (variant PX-upper). The bash
   path is reported to drop `FX-Upper.MD` at deploy, so the two paths also differ.
3. **G3 (known OL, confirmed)**: no directory backup of `~/.cursor/rules` or `~/.cursor/skills`
   is ever made (`Backup-Dir`: "no top-level *.md file"). Per-file backups do exist.
4. **G4 (macOS-only artefact)**: the exec bit on `run.sh` is lost, because deploy-harness.ps1
   writes the harness copy 0644. This does not apply on Windows, but P6 trees will differ in
   mode from bash.

## Drivers used (how they differ from the real entry points)

| Script under test | Driver | Difference from the real entry point |
|---|---|---|
| `scripts/deploy-harness.ps1` | `scripts/deploy-harness.cvps.ps1`, written into the fixture clone's `scripts/` by `run-phase.sh` with perl. Run as `pwsh -NoProfile -File <copy> -SkipConfig [-DryRun]` | Only the OS-guard line changes (`-not $IsWindows` becomes `$false`). The diff is saved per phase as `out/<phase>/harness-copy.diff` (4 lines). The script still finds `aitools-lib.ps1` and `$repoDir` through its own path. `tests/hookin/hookin-driver.ps1` was **not** used: it goes through `Invoke-HarnessStep` in aitools-install.ps1, a different entry. |
| `scripts/setup-user-cursor.ps1` | `tests/rules-fanout-cursor/step4-driver.ps1` at REF, run from the fixture clone, unmodified: `pwsh -NoProfile -File step4-driver.ps1 <clone>/scripts/setup-user-cursor.ps1 [-DryRun]` | Runs steps 4 and 5 only. Steps 1-3 (rg and agent installers, cli-config.json, `Resolve-UserRepoPath`) are not run; they are out of scope on macOS. `-Force` and `AITOOLS_DRY_RUN` passthrough are not exercised. The exit footer gives the same codes (1 on errors, else 0) but has no "COMPLETED with warnings" line. |

Environment for every run (`run-phase.sh`): `HOME=USERPROFILE=<ROOT>/home`,
`AITOOLS_SUMMARY_FILE=<phase>/<script>.summary`, `NO_COLOR=1`, with `AITOOLS_FORCE`,
`AITOOLS_DRY_RUN`, `AITOOLS_LOG_DIR` and `AITOOLS_USER_REPO_PATH` unset. Stubs `rg` and `agent`
are on PATH. Stdin is `/dev/null` except in P5. Each runner checks that HOME is neither
`/Users/new-jose` nor outside the scratch dir before it calls a script.

ROOT = `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx`
(built with `build-fixture.sh build`, unmodified).

## Check x result

Evidence paths are relative to `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/out/`.
A copy of each is in this folder under `out/`.

| # | Phase | Check | Result | Evidence |
|---|---|---|---|---|
| 1 | P1 | Rules from all three sources reach `~/.cursor/rules/<stem>.mdc` | PASS: 35 harness rules give 35 `.mdc` files. The sources' union is 35 names (`check-sources.sh`): shared, aitools `.claude/rules` and dotprofile (`fx-dot.mdc`) are all present | P1/tree.txt, P1/check-p1.txt l.1-3 |
| 2 | P1 | Fan-out marker on every generated `.mdc` | PASS: only `user-own.mdc` lacks the marker | P1/check-p1.txt l.4-5 |
| 3 | P1 | Path-scoped rules are converted (`paths:` becomes `globs:` plus `alwaysApply: false`) | PASS (sample: `relay-outbound.mdc`) | ~/.cursor/rules/relay-outbound.mdc |
| 4 | P1 | Every skill reaches `~/.cursor/skills/<name>/**` | PASS: 29 skill names (equal to the source union), 37 files, the same set as `~/.aitools/skills` | P1/check-p1.txt l.36-41 |
| 5 | P1 | Exec bit kept on `fx-skill-a/scripts/run.sh` | **FAIL (G4)**: source 0755, `~/.aitools` 0644, `~/.cursor` 0644 | P1/check-p1.txt l.27-30 |
| 6 | P1 | First source wins for rules and skills | PASS: `fx-dup` comes from shared, `fx-dup2` from aitools, `fx-dupskill` from shared, `fx-dupskill2` from aitools, in both `~/.aitools` and `~/.cursor` | P1/check-p1.txt l.6-14 |
| 7 | P1 | One ERROR row per skipped duplicate | PASS: 5 rows for 5 duplicates (fx-dupskill in .claude/skills, fx-dup.md, fx-dup2.md, fx-dupskill and fx-dupskill2 in dotprofile). The harness exits 1 | P1/rows.txt l.1-5, P1/exit.txt |
| 8 | P1 | `user-own.mdc` and `user-skill/` byte-identical | PASS: content, mode and mtime equal P0, and still equal after P4 | P1/check-p1.txt l.31-35, P0/snap.txt, P4/snap.txt |
| 9 | P1 | Bracket names (`fx-[br].md`, skill `fx-[br]ack`) | PASS: deployed in P1, updated in PX-br-update, retired in PX-br (rule and skill, with backups), recreated in PX-br-restore | P1/tree.txt, PX-br/rows.txt, PX-br-restore/rows.txt, PX-br-update/rows.txt and tree.txt |
| 10 | P1 | What happens to `FX-Upper.MD` | **GAP (G2)**: deploy-harness.ps1 deploys `~/.aitools/rules/FX-Upper.MD` and writes manifest line `FX-Upper.MD<TAB>dotprofile`. setup-user-cursor deploys `FX-Upper.mdc` (marker names `FX-Upper.MD`), but rejects the manifest line (WARN "line ignored") and writes the ACTION row "Run aitools to rebuild ~/.aitools/rules and its manifest". From P2 on, deploy-harness also rejects it (WARN). PX-upper: with the source removed, the rule is not retired; it is "Preserved (no source -- kept)" and still in Cursor | P1/cursor.out, P2/harness.out, PX-upper/harness.out, PX-upper/tree.txt |
| 11 | P2 | Every item verified | PASS: harness "145 verified" (WARN from G2), cursor rules "35 verified", cursor skills "37 verified" | P2/rows.txt |
| 12 | P2 | No file under `~/.cursor` / `~/.aitools` changes (content, mode, mtime) | PASS for every file except the two manifests. Their mtime changes and their content is identical: deploy-harness.ps1 rewrites both manifests on every run (by design, its header l.28-31: "written every run (sole owner)"). I record this as a deviation from the contract's wording, not as a defect | `diff P1/snap.txt P2/snap.txt` (2 lines) |
| 13 | P2 | No new `*.bak.*` | PASS | P2/snap.txt |
| 14 | P3 | Dry run writes nothing under `~/.aitools` / `~/.cursor` | PASS: P2 and P3 snap.txt are identical, mtimes included. Logs are excluded | `diff P2/snap.txt P3/snap.txt` (empty) |
| 15 | P3 | Dry-run summary rows | PASS: `harness files` "dry-run: 0 create, 2 update"; `cursor rules` and `cursor skills` "dry run (no files written)" (WARN because of G2). The cursor dry run reads the unchanged `~/.aitools`, so it reports the two items as "Unchanged" | P3/rows.txt, P3/harness.out, P3/cursor.out |
| 16 | P3b | The two items are `updated` | PASS: harness "2 updated, 143 verified"; DETAIL `updated: fx-shared.mdc` and `updated: fx-skill-a/SKILL.md` | P3b/rows.txt |
| 17 | P3b | Per-file backup `<file>.bak.<UTC>` for each overwritten file | PASS: all four exist (`~/.aitools` and `~/.cursor` copies), and each sha equals the old content | `diff P3/tree.txt P3b/tree.txt` |
| 18 | P3b | Directory backup of `~/.cursor/rules` / `~/.cursor/skills` | **NOT MADE (G3)**: deploy.log has "Backup-Dir: .../.cursor/rules: not backed up (no top-level *.md file)" (and the same for skills) on every run; no `*.bak.*` sibling directory exists | fx/home/.aitools/logs/deploy.log l.178, 217, 321, 325, 681, 688; P3b/tree-ext.txt (empty) |
| 19 | P4 | `fx-retire.mdc` backed up, then removed (tracker `removed`) | PASS | P4/rows.txt l.11, P4/tree.txt |
| 20 | P4 | `skills/fx-retire-skill/` backed up, then removed | PASS: the backup is `~/.cursor/skills.bak.<UTC>/fx-retire-skill/`, and the harness copy is backed up to `~/.aitools/skills/fx-retire-skill.bak.<UTC>/` | P4/rows.txt l.14, P4/tree-ext.txt |
| 21 | P4 | User-modified `fx-retire2.mdc` KEPT, with a WARN/ACTION naming it | **FAIL (G1)**: "Removed fx-retire2.mdc (retired rule; aitools-fanout marker; backup kept)", DETAIL `removed: fx-retire2.mdc`, no ACTION row. The user's edit survives only in `fx-retire2.mdc.bak.<UTC>` (sha a7706a8b..., which holds the line "User edit: keep this rule.") | P4/cursor.out, P4/rows.txt l.12, P4/tree.txt |
| 22 | P4 | `user-own.mdc` and `user-skill/` untouched | PASS | P4/snap.txt |
| 23 | P4 | The manifests list the three names as `retired` | PASS | ~/.aitools/rules/.aitools-rules-manifest, ~/.aitools/skills/.aitools-skills-manifest |
| 24 | P5 | pty review prompt for the rule and for the skill (prompt text captured) | PASS: 2 prompts `choice [o/s/x]: `, for `fx-shared.mdc` and `fx-skill-b/SKILL.md`. Captured menu: `[o]verwrite : this machine gets the green + lines (backup kept)` / `[s]kip : nothing written; asked again next run` / `[x]abort : stop this script (exit 2)`. No `[a]`/`[m]`, because there is no adopt target | P5-s/cursor.out l.4-43, P5-s/pty-drive.txt |
| 25 | P5 | `s` keeps both local edits | PASS: sha before and after are equal (02f3ccf6..., 0925afd2...); rows `skipped:`, WARN "1 skipped (user review)" | P5-prep-sha.txt, P5-s/rows.txt |
| 26 | P5 | `x` gives exit 2 and no later item is written | PASS: exit 2 at the first prompt (`fx-shared.mdc`), "Aborted by user", no cursor rows. Before the run, two later items were removed (`web-sources.mdc`, `tool-ops/SKILL.md`); after the abort they were still absent, and the local edits were intact. The next real run (PX-br) recreated both | P5-x/pty-drive.txt, P5-x/rows.txt, P5-x/tree.txt, PX-br/rows.txt l.11, 15 |
| 27 | extra | Non-interactive run after a skip overwrites the local edits (with backups) | PASS: in PX-br, `updated: fx-shared.mdc` and `updated: fx-skill-b/SKILL.md`, and `.bak` copies hold the P5 edits | PX-br/tree.txt diff vs P5-x |

## Gaps, with fix suggestions (not fixed)

### G1: a user-modified retired `.mdc` is removed (severity: high, contract fail)

- Code: `scripts/setup-user-cursor.ps1:770-772`. `Test-CursorFanoutRule` (l.500-507) checks only
  that the marker line follows the frontmatter, and a user's edit leaves the marker in place.
  The header (l.27-32) documents this rule: "only if the fan-out created it (the aitools-fanout
  marker line ...)". The code follows its own spec, and that spec contradicts the contract's P4
  expectation ("KEPT (user-modified) with a WARN/ACTION naming it").
- Output: `[info] Removed fx-retire2.mdc (retired rule; aitools-fanout marker; backup kept)`.
- Impact: Cursor silently stops loading a rule the user edited. The edit survives only in
  `fx-retire2.mdc.bak.<UTC>`, and nothing tells the user.
- Fix: treat the marker as necessary but not sufficient. Remove only when the `.mdc` equals
  `ConvertTo-CursorRule <text> <name>` (the marker form) of the harness copy or of one of its
  `~/.aitools/rules/<name>.bak.*` backups. deploy-harness always leaves one when it retires a
  rule, so the comparison is always possible. Otherwise keep the file: LogWarn plus the
  existing `$rmKept` ACTION row. The bash twin (`cursor_rule_is_fanout`) needs the same change.
  Commander decision needed if the intended behaviour is "the marker wins".

### G2: `FX-Upper.MD` is accepted at deploy, rejected in the manifest, and never retired (severity: medium)

- `scripts/deploy-harness.ps1:242`: `$rel -notlike '*.md'` is case-insensitive, so `FX-Upper.MD`
  is planned, deployed and written to the manifest (`Get-HarnessManifestPlan` l.411-417 does not
  validate the winners' names).
- `scripts/deploy-harness.ps1:407` and `:428`: the previous-manifest check
  `$name -cnotmatch '\A[^/\\]+\.md\z'` is case-sensitive. The line is rejected
  (`[warn] Rules manifest ...: line ignored: FX-Upper.MD<TAB>dotprofile`) before the
  `claimed`/retire logic, so it can never retire the name.
- `scripts/aitools-lib.ps1:2733, 2753` (`Read-HarnessManifest`): the same case-sensitive pattern.
  setup-user-cursor.ps1:576-579 and :634 turn the rejected line into a WARN and the ACTION row
  "Run aitools to rebuild ~/.aitools/rules and its manifest", on every run, and running aitools
  does not fix it. `Write-Summary` (lib l.829-831) then turns every later OK row of the run into
  WARN.
- PX-upper (source removed from the dotprofile): `Preserved: .../.aitools/rules/FX-Upper.MD (no
  source -- kept)`, and `~/.cursor/rules/FX-Upper.mdc` is still verified and loaded. The
  manifest no longer lists it, so from then on it is an unlisted rule that the cursor fan-out
  keeps forever.
- Parity: the orchestrator pre-smoke (bash, 096a8bf) dropped `FX-Upper.MD` at deploy. The two
  paths disagree; the bash result at this REF is the bash verifier's to report.
- Fix, option (b) recommended: make the rules-manifest name rule case-insensitive
  (`(?i)\.md\z`, or `-notmatch`) in `Get-HarnessManifestPlan`, `Read-HarnessManifest` and the .sh
  twins (`read_harness_manifest`, deploy-harness.sh), and accept `*.MD` in deploy-harness.sh.
  This matches the "names compared case-insensitively (commander decision 2026-10-22)" cited in
  setup-user-cursor.ps1:600 and aitools-lib.ps1:2698 (I could not see the decision text itself).
  Option (a): skip non-lowercase `.md` at deploy in both scripts, with a WARN, not a detail log.

### G3: no directory backup of `~/.cursor/rules` / `~/.cursor/skills` (severity: low to medium)

- `scripts/aitools-lib.ps1:984-996` (`Backup-Dir` skip rule: needs a top-level `*.md`). It is
  called from setup-user-cursor.ps1:650 (rules; the directory holds only `.mdc`) and
  aitools-lib.ps1:3202 (skills; the directory holds only skill directories). It logs at detail
  level only.
- `.claude/rules/config-file-safety.md` "Directory deployment (additive pattern)" step 2:
  "Back up target directory". Per-file `.bak.<UTC>` backups are made for every overwrite and
  removal (checks 17, 19-21), so no data was lost in these runs.
- Fix: give `Backup-Dir` a `-Pattern` parameter (default `*.md`; the cursor rules caller passes
  `*.mdc`), or skip only empty directories; for skills, back up when any regular file exists
  under it. Mirror the change in `backup_dir` (.sh). Alternatively record the per-file-only
  policy for these two directories in config-file-safety.md.

### G4: exec bit not kept on the PowerShell path (severity: low; macOS-only artefact)

- `scripts/deploy-harness.ps1:338` writes every file through `Deploy-ManagedFile` (text write,
  new files 0644). The header (l.10-11) says only the .sh sets the executable bit.
  `Invoke-HarnessSkillsFanout` (aitools-lib.ps1:3366-3384) copies the bit from the harness copy,
  so the cursor copy is 0644 too.
- This does not apply on Windows. It matters only because the parity diff (P6) will show
  `0644` vs `0755` for `.aitools/skills/fx-skill-a/scripts/run.sh` and
  `.cursor/skills/fx-skill-a/scripts/run.sh`.
- Fix (optional): on non-Windows, mirror the source's UnixFileMode execute bits after a
  created, updated or verified result in deploy-harness.ps1 section 5, the same way the fan-out
  does. Or have the orchestrator mask modes for this file when it diffs.

### G5 (cosmetic, low): review header names the wrong source for Cursor

The P5 menu says `+++ repo  source (embedded)` and `green + = only in the repo`
(aitools-lib.ps1:1984-1986, 1990). For the Cursor fan-out the source is the `~/.aitools`
harness copy, not the repo. A label parameter, or "the harness" when `-AdoptPath` is empty,
would fix it.

## Contract change

- `tree.txt` paths are relative to `<ROOT>/home` (for example `.cursor/rules/x.mdc`), so the four
  roots are distinguishable. The modes are `%04o` of the lstat permission bits; directories and
  links get `-` for the sha. The bash generator should use the same convention, or the
  orchestrator normalizes before diffing.
- Added (not in the spec): `tree-ext.txt`, the same format for the sibling backup directories
  `<root>.bak.<UTC>/**` (where the retired-skill backup lands in P4), and `snap.txt` (real names,
  size, mtime) for the P2 and P3 "nothing changed" checks.
- `rows.txt` concatenates the harness summary rows, then the cursor summary rows, in run order
  (no separators); `.bak.<UTC>` is replaced by `.bak.TS`.
- Extra phases after P5, on the same ROOT (not in the contract; each has its own `out/` dir):
  PX-br (retire `fx-[br].md` and `fx-[br]ack` by a fixture commit, using my own script, not
  build-fixture.sh), PX-br-restore, PX-br-update, PX-upper (remove `FX-Upper.MD` from the fixture
  dotprofile).

## Per-phase outputs (absolute)

Scratch: `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/out/<phase>/`.
Tracked copies: `<this folder>/out/<phase>/`.

| Phase | tree.txt | rows.txt |
|---|---|---|
| P0 (pre-run) | .../session-cv-ps/out/P0/tree.txt | (none) |
| P1 | .../session-cv-ps/out/P1/tree.txt | .../session-cv-ps/out/P1/rows.txt |
| P2 | .../session-cv-ps/out/P2/tree.txt | .../session-cv-ps/out/P2/rows.txt |
| P3 | .../session-cv-ps/out/P3/tree.txt | .../session-cv-ps/out/P3/rows.txt |
| P3b | .../session-cv-ps/out/P3b/tree.txt | .../session-cv-ps/out/P3b/rows.txt |
| P4 | .../session-cv-ps/out/P4/tree.txt | .../session-cv-ps/out/P4/rows.txt |
| P5 (s) | .../session-cv-ps/out/P5-s/tree.txt | .../session-cv-ps/out/P5-s/rows.txt |
| P5 (x) | .../session-cv-ps/out/P5-x/tree.txt | .../session-cv-ps/out/P5-x/rows.txt |
| PX-br, PX-br-restore, PX-br-update, PX-upper | .../session-cv-ps/out/<phase>/tree.txt | .../session-cv-ps/out/<phase>/rows.txt |

(`...` = `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch`)

Exit codes: harness 1 in every phase (the 5 duplicates); cursor 0 in every phase except P5-x (2).

## Scripts (copied into `scripts/` here)

`run-phase.sh` (runner + isolation guard + harness copy), `gen-tree.pl`, `gen-rows.pl`,
`pty-drive.py` (raw-byte pty driver), `p3-edit.sh`, `p4-prep.sh`, `p5.sh`, `check-p1.sh`,
`check-sources.sh`, `p6x-retire-br.sh`, `p7x-br-update.sh`, `p8x-upper-retire.sh`,
`copy-evidence.sh`.

## Not run

- Windows (the real platform for the .ps1 scripts).
- Steps 1-3 of setup-user-cursor.ps1 (installers, cli-config.json).
- The real entry points' OS guard, and the `aitools` / `aitools-install` loops (Step 8b,
  `Deploy-Configs`).
- `-Force` / `AITOOLS_FORCE`, and the `[o]` answer in a pty.
- AI merge (no adopt target for Cursor, so it is not offered).
- The bash path (owned by S3-CursorVerify-Bash).
