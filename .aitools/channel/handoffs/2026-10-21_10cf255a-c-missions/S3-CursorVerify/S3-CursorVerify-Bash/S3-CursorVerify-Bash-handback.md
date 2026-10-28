# S3-CursorVerify-Bash hand-back v1.0

Version 1.0, 2026-10-28, by S3-CursorVerify-Bash (level 2, delegated by
S3-CursorVerify). Bash path of `setup-user-cursor.sh` rules and skills fan-out,
verified end to end through `deploy-harness.sh`, contract
`S3-CursorVerify-contract.md` v1.0, phases P1-P5.

- REF: `9c2d0257a64d10be1be32a30c24b382a91f7689c` (fixture clone `fx/aitools`,
  fixture commit c7b728a; bash 3.2 fixture `fx32/aitools`, fixture commit 0a779f2).
- Platform: macOS (Darwin 27.0.0, arm64). Shells: `bash` = GNU bash 5.3.15
  (`/opt/homebrew/bin/bash`); `/bin/bash` = 3.2.57. perl `/usr/bin/perl`, node
  `/opt/homebrew/bin/node`, python3 `~/.local/bin/python3`.
- Every script ran from the fixture clone, `HOME=<ROOT>/home`, guarded in
  `cv-phase.sh` and `cv-pty.py` (refuse unless ROOT is under the session scratch
  and HOME is not `/Users/new-jose`). `rg` and `agent` stubbed. stdin `/dev/null`
  except P5. deploy-harness always `--skip-config`.

## Summary

1. The fan-out works: P1 put 34 rules (all three sources) into `~/.cursor/rules` with the marker and 37 skill files (exec bit kept) into `~/.cursor/skills`; first source won and each of the 5 duplicates gave one ERROR row; bracket names and user files were fine.
2. `FX-Upper.MD` never arrives anywhere: deploy-harness drops it with a detail log line only (deploy-harness.sh:249-253). Confirmed on REF.
3. P4 FAIL: a retired rule the user had edited (`fx-retire2.mdc`) was **removed** (backup kept), with no WARN and no ACTION. The marker test alone decides (setup-user-cursor.sh:790-794).
4. P2 is not write-free: `~/.cursor/cli-config.json.bak.<UTC>` is created on every run, even when nothing changed (setup-user-cursor.sh:197-199). Both manifests are also rewritten every run (same bytes, new mtime).
5. The pty prompt works for a rule and for a skill, `s` keeps both edits, and `x` exits 2 with nothing written afterwards. Dry runs write nothing. P1 under /bin/bash 3.2 matched bash 5 byte for byte.

## Check x result

Evidence paths are under `out/` in this folder (copied from the scratch
`/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/`).
Full logs (`deploy.log.copy`: that phase's lines only), console output
(`*.out`) and snapshots (`snap-*.txt`: content, mode and nanosecond mtime of
everything under `~/.cursor` and `~/.aitools` except logs) stay in the scratch
`out/<phase>/`.

| # | Phase | Check | Result | Evidence |
|---|---|---|---|---|
| 1 | P1 | Rules of all three sources -> `~/.cursor/rules/<stem>.mdc` | PASS for 34 of 35 stems; FAIL `FX-Upper.MD` (see 7) | `out/P1/checks.txt` lines 1-4, `rule-stems.diff` (`< fx-upper`); manifest has 34 lines (shared, aitools, dotprofile) |
| 2 | P1 | Fan-out marker after the frontmatter in every fanned-out `.mdc`; none in `user-own.mdc` | PASS | `out/P1/checks.txt` lines 5-6; e.g. `~/.cursor/rules/fx-[br].mdc` line 4 |
| 3 | P1 | Skills -> `~/.cursor/skills/<name>/**`, content and mode equal to `~/.aitools/skills` | PASS (37 files, 29 skills) | `out/P1/checks.txt` lines 11, 13 |
| 4 | P1 | Exec bit kept on `fx-skill-a/scripts/run.sh` | PASS (0755 in `~/.aitools` and `~/.cursor`) | `out/P1/tree.txt` lines 66, 175 |
| 5 | P1 | First source wins (rules `fx-dup` shared, `fx-dup2` aitools; skills `fx-dupskill` shared, `fx-dupskill2` aitools) | PASS | `out/P1/checks.txt` lines 7-10, 14-15 |
| 6 | P1 | One ERROR row per skipped duplicate (5) + `log_error` line each | PASS | `out/P1/rows.txt` lines 1-5; `out/P1/checks.txt` lines 16-26; deploy-harness exit 1 (`out/P1/exit.txt`) |
| 7 | P1 | `FX-Upper.MD` | FAIL (gap G1): not in `~/.aitools/rules`, not in the rules manifest, not in `~/.cursor/rules`; only trace is deploy.log `[deploy-harness] [detail] skip non-.md file in a rules source: dotprofile/FX-Upper.MD` | `out/P1/checks.txt` lines 29-33 |
| 8 | P1 | Bracket names `fx-[br].md` -> `fx-[br].mdc`, skill `fx-[br]ack` | PASS | `out/P1/checks.txt` lines 27-28; `out/P1/tree.txt` lines 119, 162-163 |
| 9 | P1-P5 | `user-own.mdc`, `user-skill/` untouched (content, mode, mtime) | PASS in every phase (no snapshot diff line for them; logged `Preserved unmanaged rule/skill`) | `out/P1/checks.txt` lines 34-36; scratch `out/<phase>/snap-before.txt` vs `snap-after.txt` |
| 10 | P2 | Rerun: every item verified | PASS (`144 verified`, `34 verified`, `37 verified`; tree identical to P1) | `out/P2/rows.txt`; `diff out/P1/tree.txt out/P2/tree.txt` empty |
| 11 | P2 | No file under `~/.cursor` or `~/.aitools` changes (content, mode, mtime) | FAIL (gap G4): both manifests (and their directories) get a new mtime, same sha | scratch `out/P2/snap-before.txt` vs `snap-after.txt` lines 80-81, 116-117 |
| 12 | P2 | No new `*.bak.*` | FAIL (gap G3): `~/.cursor/cli-config.json.bak.2026-10-28T224910Z` created, same sha as `cli-config.json` (`48c66585...`), log `Already up to date` | same diff, line 193; after 5 runs `~/.cursor` holds 5 identical `cli-config.json.bak.*` |
| 13 | P3 | Dry runs write nothing under `~/.aitools` or `~/.cursor` | PASS (snapshots identical, mtimes included) | scratch `out/P3/snap-before.txt` = `snap-after.txt`; `out/P3/commit.txt` |
| 14 | P3 | Dry-run summary rows | PASS: `OK harness files dry-run: 0 create, 2 update`, `OK cursor rules dry run (no files written)`, `OK cursor skills dry run (no files written)` | `out/P3/rows.txt` lines 6-8 |
| 15 | P3b | The two items `updated` | PASS: `updated: fx-shared.mdc`, `updated: fx-skill-a/SKILL.md` (and the two harness files) | `out/P3b/rows.txt` |
| 16 | P3b | Per-file backup `<file>.bak.<UTC>` for each overwritten file | PASS: `~/.cursor/rules/fx-shared.mdc.bak.TS`, `~/.cursor/skills/fx-skill-a/SKILL.md.bak.TS` (old sha), plus the two `~/.aitools` ones | `out/P3b/tree.txt`; deploy.log lines 45, 66 |
| 17 | P3b | Directory backup of `~/.cursor/rules` / `~/.cursor/skills` | NOT MADE (gap G5, as the OL predicted): `backup_dir: .../.cursor/rules: not backed up (no top-level *.md file)`, same for `skills` | scratch `out/P3b/deploy.log.copy` lines 43, 50 (also P1, P4) |
| 18 | P4 | `fx-retire.mdc` backed up then removed, tracker `removed` | PASS: `Removed fx-retire.mdc (retired rule; aitools-fanout marker; backup kept)`, row `removed: fx-retire.mdc` | `out/P4/rows.txt` line 10; deploy.log lines 46-47 |
| 19 | P4 | `skills/fx-retire-skill/` backed up then removed, tracker `removed` | PASS: copy in `~/.cursor/skills.bak.TS/fx-retire-skill/` (same sha), row `removed: fx-retire-skill` | `out/P4/bakdirs.txt`; `out/P4/rows.txt` line 13; deploy.log line 90 |
| 20 | P4 | `fx-retire2.mdc` (user-modified) KEPT with a WARN/ACTION naming it | FAIL (gap G2): removed, `Removed fx-retire2.mdc (retired rule; aitools-fanout marker; backup kept)`; `cursor.summary` has 0 WARN/ACTION rows; the user's line survives only in `fx-retire2.mdc.bak.2026-10-28T225025Z` | `out/P4/rows.txt` line 11; deploy.log line 49 |
| 21 | P4 | Manifests list the three names as `retired` | PASS: `fx-retire.md retired`, `fx-retire2.md retired`, `fx-retire-skill retired` | `~/.aitools/rules/.aitools-rules-manifest` lines 15-16, skills manifest line 12 |
| 22 | P4 | deploy-harness retires with backup | PASS: `fx-retire.md.bak.TS`, `fx-retire2.md.bak.TS` in `~/.aitools/rules`; `fx-retire-skill.bak.TS/` in `~/.aitools/skills` | `out/P4/tree.txt`; deploy.log lines 21-29 |
| 23 | P5 | Review menu prompts for the rule and the skill (prompt text captured) | PASS (2 prompts, `choice [o/s/x]:`, no adopt, `+++ repo source (embedded)`) | `out/P5/prompts.txt`; `out/P5/cursor-pty-transcript.txt` lines 10-26, 32-48 |
| 24 | P5 | `s` keeps both local edits | PASS (edit lines still present; rows `WARN ... 1 skipped (user review)` for both tools; exit 0) | `out/P5/edit-rule-survived.txt`, `edit-skill-survived.txt` (= 1); `out/P5/rows.txt` |
| 25 | P5 | `x` -> exit 2, no later item written | PASS: exit 2, `[error] Aborted by user`, no `cursor rules`/`cursor skills` row; `git-safety.mdc` (after `fx-shared.mdc` in the loop) and `fx-skill-a/SKILL.md` (skills step), moved aside before the run, were not written; the snapshot diff shows only the Step 3 `cli-config.json.bak` (written before the prompt) | `out/P5x/exit.txt`, `later-items.txt`, `rows.txt` (empty), transcript lines 10-26 |
| 26 | P1 | bash 3.2 (`/bin/bash` 3.2.57) P1 matches bash 5 | PASS: `tree.txt`, `rows.txt`, `exit.txt` identical; no shell error lines in either console output | `out/P1-bash32/`; `diff` of the three files empty |

## Gaps (not fixed)

### G1 `FX-Upper.MD` is dropped by deploy-harness (medium)

`scripts/deploy-harness.sh:249-253` (REF):

```bash
if [ "$layout" = "flat-md" ]; then
    case "$rel" in
        *.md) ;;
        *) log_detail "skip non-.md file in a rules source: $label/$rel"; continue ;;
```

Output: `[deploy-harness] [detail] skip non-.md file in a rules source: dotprofile/FX-Upper.MD`
(P1 deploy.log line 20). Nothing reaches the console, no row is written, and
the rule is in no manifest. This filter is case-sensitive, but the rest of the
chain is not: `rule_name_kind` (aitools-lib.sh:2680-2693, "compared
case-insensitively (commander decision 2026-10-22)") and the Cursor
`dest_name="${rule_base%.[mM][dD]}.mdc"` (setup-user-cursor.sh:713) already
accept `.MD`. The OL from the orchestrator pre-smoke at 096a8bf is confirmed on
REF.

Fix: change the filter to `*.[mM][dD])`. The manifest name checks must also
become case-insensitive, or the next run will report the new manifest line as
invalid: `%name_ok` rules regex `\A[^\/\\]+\.md\z` in `harness_manifest_plan`
(deploy-harness.sh:433) and `$name_re` in `read_harness_manifest`
(aitools-lib.sh:2742). The `.ps1` twins need the same change; I did not read
them. If upper-case extensions are meant to be excluded, make the skip a
`log_warn` plus a WARN row, so it is not silent.

### G2 A user-modified retired rule is removed (high, contract P4)

`scripts/setup-user-cursor.sh:790-794` (REF):

```bash
cursor_rule_is_fanout "$rm_path" || rm_rc=$?
if [ "$rm_rc" -eq 0 ]; then
    rm_why="aitools-fanout marker"
```

When the marker is there, the file is removed (lines 830-859). Its content is
never compared with the conversion of the harness copy. A user's appended line
does not touch the marker, so the edit is lost from Cursor, with only an info
log line and a `removed:` DETAIL row. This follows the script's own header
(lines 26-31: "only if the fan-out created it (the aitools-fanout marker line,
...)"), but not the contract's P4 expectation. It also differs from the skills
prune, which removes only on a content match (`fanout_dir_matches`,
aitools-lib.sh:3420-3437), so a user-modified retired skill would be kept. The
rules prune and the skills prune behave differently.

Fix: when the marker is present, also require that the content equals the
conversion of `~/.aitools/rules/<name>` or one of its `.bak.*` files. The
legacy comparison at setup-user-cursor.sh:804-818 already does this; reuse it.
On a mismatch, keep the file, `log_warn`, and add it to the existing
`RM_KEPT` ACTION row (line 862). Parity: `.ps1`.

### G3 `cli-config.json` is backed up on every run (low, contract P2)

`scripts/setup-user-cursor.sh:197-199`:
`if [ "$DRY_RUN" != "true" ]; then backup_file "$CLI_CONFIG"; fi` runs before
the merge, whatever the merge outcome. P2 created
`cli-config.json.bak.2026-10-28T224910Z` beside an unchanged file (`Already up
to date`). After 5 runs there were 5 identical backups (pruned at 20).
config-file-safety "Diff logging on overwrite": "Identical: skip the write".

Fix: back up only when the merge will write, for example inside the node block
just before `fs.writeFileSync`, or with a dry-run pass first. Outside the
fan-out steps, but it is the same script and contract P2.

### G4 Both manifests are rewritten on every run (low, contract P2)

`scripts/deploy-harness.sh:681-692` always runs `cp "$new" "$tmp"` and then
`mv -f`. The header (line 27) says this is by design ("written every run (sole
owner)"). P2 shows the same sha with a new mtime for both manifests and for
`~/.aitools/rules` and `~/.aitools/skills`. Fix: if `cmp -s "$new" "$manifest"`,
log "unchanged" and skip the write.

### G5 `backup_dir` never backs up the Cursor directories (low, known OL)

`backup_dir` (aitools-lib.sh:1083-1098) copies a directory only when it has a
top-level `*.md`. `~/.cursor/rules` holds only `.mdc` files, and
`~/.cursor/skills` holds only directories. So the calls at
setup-user-cursor.sh:678 and aitools-lib.sh:3207 never make a copy, which
contradicts plan section 3.4 ("backup: `backup_dir DEST` once per non-dry
run"). No data is lost: every overwrite and every removal kept a per-file
backup (P3b, P4), and a retired skill gets `~/.cursor/skills.bak.<UTC>/<name>/`.

Fix, either:
- (a) give `backup_dir` a pattern argument (`*.mdc` for rules, any regular file
  recursively for skills); or
- (b) accept per-file backups, and say so in plan 3.4 and the script headers.

### G6 `[REVIEW]` header ignores `NO_COLOR` (low, observation)

`aitools-lib.sh:1972` hard-codes `\033[33m[REVIEW]\033[0m`. With `NO_COLOR=1`
the transcript shows `ESC[33m[REVIEW]` (out/P5 transcript line 10). The diff
lines honour `_review_colour` (lines 1921-1924). The spec's "Colour" item
(reference/managed-file-deployment.md "Diff Mechanism Detail") names only the
diff lines and headers, so this may be out of its scope. Fix: guard it with
`_review_colour`.

Observations (not gaps):
- Non-interactive overwrites `log_warn` and so turn the step's OK row into
  WARN (`WARN harness files 2 updated, 142 verified`, P3b). This is the
  documented `write_summary` promotion (aitools-lib.sh:967-970).
- Per-file skill backups land inside the skill directory Cursor loads
  (`~/.cursor/skills/fx-skill-a/SKILL.md.bak.TS`), and retired-rule backups
  stay in `~/.cursor/rules` (`fx-retire.mdc.bak.TS`). Whether Cursor ignores
  them is unknown (not tested in Cursor).
- The pre-smoke at 096a8bf counted 36 rules and 39 skill files. REF has 34 and
  37. I did not look into why (a different ref).

## Phase outputs (absolute paths)

Primary (scratch, per the contract):

| Phase | tree.txt | rows.txt |
|---|---|---|
| P1 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P1/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P1/rows.txt |
| P2 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P2/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P2/rows.txt |
| P3 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P3/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P3/rows.txt |
| P3b | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P3b/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P3b/rows.txt |
| P4 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P4/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P4/rows.txt |
| P5 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P5/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P5/rows.txt |
| P5x | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P5x/tree.txt (and tree-restored.txt) | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out/P5x/rows.txt (empty: abort) |
| P1 bash 3.2 | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out-bash32/P1/tree.txt | /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out-bash32/P1/rows.txt |

Tracked copies (same files): `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify/S3-CursorVerify-Bash/out/<phase>/`.
Runners and generator: `.../S3-CursorVerify-Bash/scripts/` (`cvgen.pl`
generator: `tree`, `bakdirs`, `rows`, `snap`; `cv-phase.sh` P1-P4;
`cv-check-p1.sh`; `cv-pty.py` pty driver; `cv-p5.sh` P5/P5x;
`cv-copy-evidence.sh`).

## Contract change

The contract text is unchanged. These are interpretations and additions. The
Pwsh verifier and the P6 diff need them:

1. **tree.txt paths are relative to HOME**: `.cursor/rules/x.mdc`,
   `.aitools/skills/a/SKILL.md`. The four roots themselves are not listed. The
   mode column is 4-digit octal (`0644`). Directories and symlinks get `-`.
   The contract says only "relative path". The Pwsh generator must use the same
   base, or reuse `cvgen.pl`.
2. **rows.txt** is the deploy-harness rows followed by the setup-user-cursor
   rows, with no separator line.
3. **Extra files**:
   - `bakdirs.txt`: sibling directory backups such as `.cursor/skills.bak.TS/`.
     They are not under the four roots, so they are not in tree.txt.
   - `snap-*.txt` (scratch): mtimes, used for the P2/P3 "nothing written"
     checks.
   - `checks.txt` (P1).
4. **P5x**: the `x` run is in its own folder. Before it, I moved
   `~/.cursor/rules/git-safety.mdc` and `~/.cursor/skills/fx-skill-a/SKILL.md`
   aside, as proof that no later item is written. I restored them afterwards
   (`tree-restored.txt` is identical to `P5/tree.txt`). P5's tree.txt was taken
   after the `s` run.
5. **bash 3.2**: a second fixture, `fx32`, from the same builder and REF, P1
   only. The fixture builder was not edited.

## Final response shape

- **PR / commits / branch / files changed**: none. This was a verification-only
  mission. Files written: this hand-back folder (handback, `scripts/`, `out/`)
  and the scratch. `git status` of the source repo for
  scripts/shared/reference/.claude/rules/plans is clean; branch `main` was not
  switched.
- **Verification**:
  - `bash build-fixture.sh build <ROOT> 9c2d025...` for `fx` and `fx32`.
  - `bash cv-phase.sh <fx> <out> P1|P2|P3|P3b|P4`: exits harness 1 / cursor 0
    in every phase. Harness exit 1 comes only from the 5 duplicate ERRORs
    (`exit.txt`).
  - `bash cv-phase.sh <fx32> <out-bash32> P1 /bin/bash`: same exits.
  - `bash cv-p5.sh <fx> <out>`: pty `s` exit 0 with 2 prompts; pty `x` exit 2
    with 1 prompt.
  - `bash cv-check-p1.sh`: 17 PASS and 1 FAIL (FX-Upper).
  - `diff` of the snapshot and tree files, as cited in the table.
  - `bash -n` on the runners, `perl -c cvgen.pl`, `python3 -m py_compile cv-pty.py`.
- **Not run**:
  - the .ps1 path (S3-CursorVerify-Pwsh);
  - P2-P5 under bash 3.2;
  - Linux;
  - the MDM `deploy/` variant and build-deploy;
  - the Claude Code fan-out;
  - loading the generated `.mdc` / skills in a real Cursor;
  - the rerun after #123 merges (orchestrator, per contract).
- **WRITE_BLOCKED**: `WRITE_BLOCKED: Bash "cat .../out/P1/rows.txt" --
  PreToolUse:Bash hook error: [bash "/Users/new-jose/.claude/hooks/standing-order-guard.sh"]:
  USO: Dedicated tools --: Use the Read tool instead of 'cat' to read files.`
  This was a read, not a write. I used the Read tool, as the guard directs,
  and did not retry it as Bash.
- **CONFLICT**: none. Disclosure: I read `reference/script-standards-detail.md`
  only to line 400 of 1229. The rest covers code-writing patterns, and this
  mission wrote no reusable repo code. Every other listed file was read in
  full.
- **INCIDENT markers** (not filed):
  - `INCIDENT: deploy-harness rules filter is case-sensitive (*.md) while rule_name_kind and the Cursor fan-out are case-insensitive; FX-Upper.MD is silently dropped (deploy-harness.sh:249-253)` (G1).
  - `INCIDENT: setup-user-cursor retired-rule prune removes a user-modified fan-out file on the marker alone, with no WARN/ACTION; the skills prune requires a content match (setup-user-cursor.sh:790-794 vs aitools-lib.sh:3420-3437)` (G2).
  - `INCIDENT: setup-user-cursor backs up cli-config.json on every run, even when unchanged (setup-user-cursor.sh:197-199)` (G3).
  - `INCIDENT: backup_dir's top-level *.md precondition makes the Cursor rules/skills directory backups a no-op, against plan 3.4 (aitools-lib.sh:1095-1098)` (G5).
- **Open questions**:
  1. G2: should a marker file whose content the user changed be kept, as the
     contract says, or removed with a backup, as the script header says? I
     suggest keeping it with WARN and ACTION, the same as the skills prune
     (FD-4: "never overwritten or pruned unless the fan-out created it"), and
     never dropping an edit silently.
  2. G1: should upper-case `.MD` rules be deployed? I suggest yes. The
     commander's 2026-10-22 case-insensitive decision (cited in the lib) points
     that way, and the Cursor side already handles it.
  3. G4 and G3: is a P2 mtime change on the manifests, and a new
     `cli-config.json.bak`, acceptable? I suggest fixing both (cheap `cmp`
     guards) so that "verified" means nothing was written.
- **Delegates used**: none.
