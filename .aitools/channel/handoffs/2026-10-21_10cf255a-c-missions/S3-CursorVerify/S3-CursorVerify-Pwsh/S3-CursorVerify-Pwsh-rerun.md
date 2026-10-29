# S3-CursorVerify-Pwsh rerun at origin/main 207f1a6

Version 1.0, 2026-10-29, by S3-CursorVerify-Pwsh, at the request of S3-CursorVerify (PR #123
merged as `207f1a6c7db92227e9c3ae3c5d44e8e6f6b19126`; merged head 25a3286). Companion to
`S3-CursorVerify-Pwsh-handback.md` v1.0, which covers the 9c2d025 run and holds the gap
details G1-G5 with file:line references.

## Summary

The rerun on a fresh fixture at 207f1a6 gives **byte-identical** results to the 9c2d025 run.
In every phase (P0, P1, P2, P3, P3b, P4, P5-s, P5-x, PX-br, PX-br-restore, PX-br-update and
PX-upper), `tree.txt`, `tree-ext.txt`, `rows.txt` and `exit.txt` are unchanged. This is
consistent with the orchestrator's statement that the .ps1 code did not change. The only
difference between the two runs is the mtime of the two user files: each is the fixture's
build time, and that is checked within each run (P0 to P4). Every result in the first run's
table holds at 207f1a6, including the four gaps G1-G4.

## Setup

- Fixture: `build-fixture.sh build <ROOT> 207f1a6c...` (unmodified).
  ROOT = `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx-main`.
  Clone HEAD after the fixture commit is `1dd8297`, on top of `207f1a6 Merge pull request #123`
  (`out-main/rerun-all.txt` l.7-9).
- Drivers: the same as the first run.
  - `deploy-harness.cvps.ps1`: guard-line copy, made fresh in the fx-main clone; 4-line diff in
    `out-main/<phase>/harness-copy.diff`.
  - `tests/rules-fanout-cursor/step4-driver.ps1` from the fx-main clone, i.e. at 207f1a6.
- Runners: `scripts/main/*.sh`, copies of the first-run runners with only the ROOT and output
  paths retargeted (`scripts/make-main.sh`, a perl substitution). Run in sequence by
  `scripts/main/rerun-all.sh`; the full log is `out-main/rerun-all.txt`.
- Comparison: `scripts/main/compare.sh`; its output is `out-main/compare.txt`.

## Check x result (rerun)

The numbers match the check table in the hand-back.

| # | Check | Result at 207f1a6 | Same as 9c2d025 |
|---|---|---|---|
| 1 | Rules from all three sources -> `.mdc` (35 of 35) | PASS | yes |
| 2 | Fan-out marker on every generated `.mdc` | PASS | yes |
| 3 | `paths:` -> `globs:` conversion | PASS (P1 tree identical) | yes |
| 4 | Every skill fanned out (29 names, 37 files) | PASS | yes |
| 5 | Exec bit on `run.sh` | **FAIL (G4)**: 0644 in both `~/.aitools` and `~/.cursor` | yes |
| 6 | First source wins | PASS | yes |
| 7 | One ERROR row per duplicate (5); harness exits 1 | PASS | yes |
| 8 | `user-own.mdc` and `user-skill/` byte-identical (P0 to P4: content, mode, mtime) | PASS | yes |
| 9 | Bracket names: deploy, update, retire, restore | PASS | yes |
| 10 | `FX-Upper.MD` | **GAP (G2)**: deployed and fanned out; manifest line rejected (WARN and ACTION on every run); never retired after its source was removed (PX-upper: "Preserved ... FX-Upper.MD (no source -- kept)") | yes |
| 11 | P2: every item verified | PASS | yes |
| 12 | P2: nothing changes | PASS, except that both manifests are rewritten (mtime only, content identical; by design) | yes |
| 13 | P2: no new `*.bak.*` | PASS | yes |
| 14 | P3: dry run writes nothing | PASS (P2 and P3 snap.txt identical) | yes |
| 15 | P3: dry-run rows | PASS | yes |
| 16 | P3b: two items `updated` | PASS | yes |
| 17 | P3b: per-file backups | PASS | yes |
| 18 | P3b: directory backup of `~/.cursor/rules` and `~/.cursor/skills` | **NOT MADE (G3)**: "not backed up (no top-level *.md file)" on every run | yes |
| 19 | P4: `fx-retire.mdc` backed up and removed | PASS | yes |
| 20 | P4: `fx-retire-skill/` backed up and removed | PASS | yes |
| 21 | P4: user-modified `fx-retire2.mdc` kept with WARN/ACTION | **FAIL (G1)**: "Removed fx-retire2.mdc (retired rule; aitools-fanout marker; backup kept)" | yes |
| 22 | P4: user files untouched | PASS | yes |
| 23 | P4: manifests list the three names as `retired` | PASS (P4 tree identical, manifest sha identical) | yes |
| 24 | P5: pty prompt for the rule and for the skill | PASS: 2 prompts `choice [o/s/x]: ` | yes |
| 25 | P5: `s` keeps both local edits | PASS (sha 02f3ccf6..., 0925afd2... unchanged) | yes |
| 26 | P5: `x` exits 2 and no later item is written | PASS: exit 2, "Aborted by user"; the two removed later items stayed absent | yes |
| 27 | Non-interactive run after a skip overwrites (with backups) | PASS (PX-br) | yes |

## Differences against the 9c2d025 run

| Phase | tree.txt | tree-ext.txt | rows.txt | exit.txt |
|---|---|---|---|---|
| P0 | same | same | (none) | (none) |
| P1 | same | same | same | same |
| P2 | same | same | same | same |
| P3 | same | same | same | same |
| P3b | same | same | same | same |
| P4 | same | same | same | same |
| P5-s | same | same | same | same |
| P5-x | same | same | same | same |
| PX-br | same | same | same | same |
| PX-br-restore | same | same | same | same |
| PX-br-update | same | same | same | same |
| PX-upper | same | same | same | same |

Source: `out-main/compare.txt` l.1-46.

The only other differences:

- **`check-p1.txt`**: with the fixture paths normalized, only lines 33 and 35 differ. Those are
  the mtimes of `user-own.mdc` and `user-skill/SKILL.md`, which are each fixture's build time.
  Within this rerun they did not change from P0 to P4 (`compare.txt` l.47-52, 63-64).
- **`snap.txt`**: not diffed across runs, because it holds real names, timestamps and mtimes.
  Within the rerun it gives the same results as the first run: P1 -> P2 changes only the two
  manifest lines (mtime; the sha is the same), and P2 -> P3 shows no difference
  (`compare.txt` l.53-62).

The sha256 in `tree.txt` of every generated `.mdc`, skill file and manifest is identical across
the runs. The fixture content and the conversion are deterministic, and no file content
includes the REF or a timestamp.

## Evidence

- Scratch: `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/out-main/<phase>/{tree.txt,tree-ext.txt,rows.txt,exit.txt,...}`.
- Tracked copy: `<this folder>/out-main/<phase>/`, plus `out-main/compare.txt`,
  `out-main/rerun-all.txt` and `out-main/P5-prep-sha.txt`.
- Scripts: `<this folder>/scripts/main/` and `scripts/make-main.sh`. Every `.sh` in this folder
  is now mode 755 on disk. This includes the first run's `scripts/*.sh`: `cp` had left their
  working-tree copies at 0644, although the orchestrator's commit already records them as
  100755 (`git ls-files -s`). Check done with `find <folder> -name '*.sh' ! -perm -u+x`, which
  printed nothing.

## Not run

The same as the first run: Windows, setup-user-cursor steps 1-3, the real OS guard and the
installer loops, `-Force`, the `o` answer in a pty, AI merge, and the bash path. Nothing is
committed (as ordered).
