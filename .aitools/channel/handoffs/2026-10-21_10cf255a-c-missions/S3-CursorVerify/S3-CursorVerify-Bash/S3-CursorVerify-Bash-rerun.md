# S3-CursorVerify-Bash rerun v1.0 (REF = origin/main 207f1a6)

Version 1.0, 2026-10-29, by S3-CursorVerify-Bash. This is the rerun of
contract phases P1-P5, plus P1 under /bin/bash 3.2, after PR #123 merged. The
orchestrator asked for it in a message on 2026-10-28.

## Setup

- REF: `207f1a6c7db92227e9c3ae3c5d44e8e6f6b19126` (origin/main, the #123 merge
  commit).
- Fixtures, all built fresh with the unmodified `build-fixture.sh`:
  - `fx-main` (fixture commit 4d006a0): P1-P5.
  - `fx32-main` (ebca24e): P1 under /bin/bash 3.2.57.
  - `fx-main-c` (1b0d290): a P1-only checker run (see "Correction" below).
- Outputs: `/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh/out-main/<phase>/`,
  `out-main-bash32/P1/` and `out-main-c/P1/`. Tracked copies are in
  `out-main/` of this folder.
- Runners: the same as the 9c2d025 run (`scripts/`), plus
  `cv-rerun-main.sh` (runs the chain and the diffs) and
  `cv-copy-evidence-main.sh`. Every `.sh` in this folder is mode 0755.
- Platform and isolation: unchanged from the hand-back v1.0 (macOS arm64; bash
  5.3.15 and /bin/bash 3.2.57; isolated HOME guarded in every runner; stdin
  /dev/null except P5).

## Code under test: what changed since 9c2d025

`git diff 9c2d025 207f1a6` on the three scripts under test touches only
`scripts/aitools-lib.sh` `_fanout_is_binary`: one anchored `(...)*` match
became a `\G` loop (8 lines added, 2 removed). setup-user-cursor.sh and
deploy-harness.sh are unchanged. There are no changes under `shared/rules`,
`shared/skills`, `.claude/rules`, `.claude/skills`, `reference`, `registries`
or `shared/hooks`. Identical output was therefore the expected result.

## Summary

1. All exit codes, `tree.txt` and `rows.txt` match the 9c2d025 run byte for byte, in every phase: P1, P2, P3, P3b, P4, P5 and P5x (`out-main/diff-vs-9c2d025.txt` has no difference lines).
2. P1 under /bin/bash 3.2 matches bash 5 (tree, rows and exit codes identical), and no console output in either shell shows a shell error.
3. The four gaps of the hand-back v1.0 are still there, unchanged:
   - G1: `FX-Upper.MD` is dropped, with a detail log line only.
   - G2: the user-edited `fx-retire2.mdc` is removed with no WARN or ACTION.
   - G3: a new `cli-config.json.bak` on the no-change rerun.
   - G4: both manifests get a new mtime on every run.

   G5 (no directory backup of the Cursor dirs) is also unchanged.
4. Everything else passes as before: the marker, skills with the exec bit, first source wins with 5 ERROR rows, bracket names, untouched user files, dry runs that write nothing, per-file backups, retirement with backups, the pty prompt for both the rule and the skill, and `x` giving exit 2.
5. Correction, in the rerun only: my chain script ran `cv-check-p1.sh` after P4, so that file checked the state after retirement. I kept it as `out-main/P1/checks-run-after-P4-INVALID.txt` and redid the P1 checks on a fresh fixture straight after P1 (`out-main/P1-checkrun/checks.txt`): 17 PASS and 1 FAIL (FX-Upper), the same as 9c2d025. Its tree is identical to `out-main/P1/tree.txt`.

## Check x result (rerun)

The rows have the same numbering and meaning as the table in
`S3-CursorVerify-Bash-handback.md`.

| # | Phase | Check | 9c2d025 | 207f1a6 | Evidence (`out-main/...`) |
|---|---|---|---|---|---|
| 1 | P1 | Rules of all three sources -> `.mdc` | PASS 34/35, FAIL FX-Upper | same | `P1-checkrun/checks.txt` lines 1-4 |
| 2 | P1 | Marker in every fanned-out `.mdc`; none in user-own | PASS | PASS | `P1-checkrun/checks.txt` |
| 3 | P1 | Skills copied, content and mode equal (37 files) | PASS | PASS | same |
| 4 | P1 | Exec bit on `fx-skill-a/scripts/run.sh` (0755) | PASS | PASS | `P1/tree.txt` |
| 5 | P1 | First source wins (rules, skills) | PASS | PASS | `P1-checkrun/checks.txt` |
| 6 | P1 | 5 duplicate ERROR rows + `log_error` lines | PASS | PASS | `P1/rows.txt` lines 1-5 |
| 7 | P1 | `FX-Upper.MD` | FAIL (G1) | FAIL (G1): deploy.log line 20 `skip non-.md file in a rules source: dotprofile/FX-Upper.MD` | `P1-checkrun/checks.txt` lines 29-33 |
| 8 | P1 | Bracket names | PASS | PASS | `P1-checkrun/checks.txt` |
| 9 | P1-P5 | User files untouched | PASS | PASS | snapshot diffs (scratch) |
| 10 | P2 | Rerun: every item verified | PASS | PASS (`144/34/37 verified`) | `P2/rows.txt` |
| 11 | P2 | No mtime change under `~/.aitools` | FAIL (G4) | FAIL (G4): both manifests, same sha, new mtime | `assertions.txt` lines 1-13 |
| 12 | P2 | No new `*.bak.*` | FAIL (G3) | FAIL (G3): `.cursor/cli-config.json.bak.2026-10-29T034152Z` (sha `48c66585...` = unchanged file) | `assertions.txt` lines 14-15 |
| 13 | P3 | Dry runs write nothing | PASS | PASS (empty snapshot diff) | `assertions.txt` line 16 |
| 14 | P3 | Dry-run summary rows | PASS | PASS | `P3/rows.txt` |
| 15 | P3b | Two items `updated` | PASS | PASS | `P3b/rows.txt` |
| 16 | P3b | Per-file `.bak.<UTC>` backups | PASS | PASS | `P3b/tree.txt` |
| 17 | P3b | Directory backup of `~/.cursor/rules` / `skills` | NOT MADE (G5) | NOT MADE (G5) | `P1-checkrun/checks.txt` lines 39-40 |
| 18 | P4 | `fx-retire.mdc` backed up and removed | PASS | PASS | `P4/rows.txt` |
| 19 | P4 | `fx-retire-skill/` backed up and removed | PASS | PASS | `P4/rows.txt`, `P4/bakdirs.txt` |
| 20 | P4 | User-modified `fx-retire2.mdc` KEPT + WARN/ACTION | FAIL (G2) | FAIL (G2): `Removed fx-retire2.mdc (retired rule; aitools-fanout marker; backup kept)`; 0 WARN/ACTION rows | `assertions.txt` lines 17-24 |
| 21 | P4 | Manifests list the three as `retired` | PASS | PASS | `P4/tree.txt` (same manifest sha as 9c2d025) |
| 22 | P4 | deploy-harness retires with backup | PASS | PASS | `P4/tree.txt` |
| 23 | P5 | Prompt for the rule and the skill | PASS | PASS (2 prompts) | `P5/prompts.txt`, `P5/cursor-pty-transcript.txt` |
| 24 | P5 | `s` keeps both edits | PASS | PASS | `P5/edit-*-survived.txt` = 1 |
| 25 | P5 | `x` -> exit 2, nothing later written | PASS | PASS | `P5x/exit.txt`, `P5x/later-items.txt`; `tree-restored.txt` = `P5/tree.txt` |
| 26 | P1 | bash 3.2 P1 matches bash 5 | PASS | PASS | `diff-vs-9c2d025.txt` lines 22-24 (no differences); `P1-bash32/checks.txt` 17 PASS / 1 FAIL |

## Differences against the 9c2d025 run

For P1, P2, P3, P3b, P4, P5 and P5x, `tree.txt`, `rows.txt` and `exit.txt` are
byte-identical (`out-main/diff-vs-9c2d025.txt`). The hashes match because no
source content changed. Backup stamps are normalized to `.bak.TS`.

The only differences are outside those files and are expected:
- Absolute paths in logs and transcripts (`fx` became `fx-main`).
- Timestamps in backup names, logs and mtimes.
- The fixture commit shas (they include the commit time).

The `_fanout_is_binary` change cannot show up in this fixture: every fixture
and real skill file is small, valid UTF-8, so both versions classify every
file as text. Not tested: a large multi-byte file, the case the fix targets
(PR 124 review NB1).

## Final response shape

- **PR / commits / branch**: none; I did not commit, as instructed.
- **Files written**:
  - This document.
  - `out-main/` (P1, P1-checkrun, P1-bash32, P2, P3, P3b, P4, P5, P5x,
    `diff-vs-9c2d025.txt`, `assertions.txt`).
  - `scripts/cv-rerun-main.sh` and `scripts/cv-copy-evidence-main.sh`.
  - Scratch directories `fx-main`, `fx32-main`, `fx-main-c`, `out-main*`.
- **Verification**:
  - `build-fixture.sh build` × 3 at 207f1a6.
  - `bash cv-rerun-main.sh`:
    - P1-P4: harness exit 1 (the 5 duplicate ERRORs), cursor exit 0.
    - pty `s` exit 0 with 2 prompts; pty `x` exit 2 with 1 prompt.
    - bash 3.2 P1: same exit codes.
  - `cv-phase.sh` and `cv-check-p1.sh` on `fx-main-c`: 17 PASS, 1 FAIL.
  - `diff` of the trees, rows and exit codes against `out/`: no difference.
  - `find <hand-back> -name '*.sh' ! -perm 0755`: none.
- **Not run**:
  - The .ps1 path.
  - P2-P5 under bash 3.2.
  - Linux.
  - MDM and build-deploy.
  - The Claude Code fan-out.
  - Real Cursor loading.
  - A large multi-byte skill file (the `_fanout_is_binary` fix itself).
- **WRITE_BLOCKED**: none in the rerun.
- **CONFLICT**: none.
- **INCIDENT markers**: the same four as hand-back v1.0 (G1, G2, G3, G5),
  still present at 207f1a6. Not filed.
- **Open questions**: unchanged from hand-back v1.0 (G2 keep vs remove; G1
  upper-case `.MD`; G3/G4 `cmp` guards), with the same suggested answers.
- **Delegates used**: none.
